#!/usr/bin/env python3
"""
omarchy-wpe native Wayland Layer-Shell Web Wallpaper Runner
Features:
- True Wayland zwlr_layer_shell_v1 Layer.BOTTOM surface across monitors
- Real-time PipeWire audio capture + 64-band FFT streaming to wallpaperRegisterAudioListener
- Real-time Property IPC socket (/tmp/wpe-layer-web.sock) for dynamic live widget control
- Local HTTP server to support CORS, dynamic imports, and Next.js assets
- Wallpaper Engine JavaScript API bridge (wallpaperPropertyListener & wallpaperRegisterAudioListener)
"""
import sys
import os
os.environ["WEBKIT_DISABLE_DMABUF_RENDERER"] = "1"
import json
import signal
import threading
import time
import math
import struct
import subprocess
import socket
import http.server
import socketserver
import functools
import gi

try:
    gi.require_version('Gtk', '3.0')
    gi.require_version('GtkLayerShell', '0.1')
    gi.require_version('WebKit2', '4.1')
except ValueError as e:
    print(f"Error loading dependencies: {e}", file=sys.stderr)
    print("Ensure gtk-layer-shell and webkit2gtk-4.1 are installed: yay -S gtk-layer-shell", file=sys.stderr)
    sys.exit(1)

from gi.repository import Gtk, GtkLayerShell, WebKit2, Gdk, GLib

IPC_SOCKET_PATH = "/tmp/wpe-layer-web.sock"
PROPS_CONFIG_DIR = os.path.expanduser("~/.config/omarchy/wpe-user-props")
os.makedirs(PROPS_CONFIG_DIR, exist_ok=True)

httpd = None
webviews = []
audio_proc = None
running = True

def start_local_server(directory):
    global httpd
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=directory)
    httpd = socketserver.TCPServer(("127.0.0.1", 0), handler)
    port = httpd.server_address[1]
    server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    server_thread.start()
    return port

# Pure Python 512-point FFT implementation for fast audio spectrum computation
def fft_radix2(x):
    N = len(x)
    if N <= 1:
        return x
    even = fft_radix2(x[0::2])
    odd = fft_radix2(x[1::2])
    T = [math.e ** (-2j * math.pi * k / N) * odd[k] for k in range(N // 2)]
    return [even[k] + T[k] for k in range(N // 2)] + [even[k] - T[k] for k in range(N // 2)]

def compute_64_bands(samples, sample_rate=44100):
    N = len(samples)
    if N != 1024:
        return [0.0] * 64
    
    # Apply Hanning window
    windowed = [samples[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (N - 1))) for i in range(N)]
    complex_fft = fft_radix2(windowed)
    mags = [abs(c) / (N / 2) for c in complex_fft[:N // 2]]
    
    num_bins = len(mags)
    bin_width = sample_rate / N
    min_freq = 25.0
    max_freq = 15000.0
    
    bands = [0.0] * 64
    for i in range(64):
        f_low = min_freq * ((max_freq / min_freq) ** (i / 64.0))
        f_high = min_freq * ((max_freq / min_freq) ** ((i + 1) / 64.0))
        
        idx_low = max(0, min(num_bins - 1, int(f_low / bin_width)))
        idx_high = max(idx_low + 1, min(num_bins, int(f_high / bin_width) + 1))
        
        sub = mags[idx_low:idx_high]
        avg = sum(sub) / len(sub) if sub else 0.0
        
        # Human perceptual power scaling (sqrt + treble acoustic compensation)
        eq_boost = 1.0 + (i / 64.0) * 3.0
        val = math.sqrt(avg * 10.0) * eq_boost
        bands[i] = max(0.0, min(1.0, val))
    return bands

def get_default_sink():
    try:
        sink = subprocess.check_output(['pactl', 'get-default-sink'], stderr=subprocess.DEVNULL).decode().strip()
        if sink:
            return sink
    except Exception:
        pass
    return "0"

def audio_capture_worker():
    global audio_proc, running, webviews
    sink = get_default_sink()
    cmd = ['pw-record', '--rate', '44100', '--channels', '2', '--format', 's16']
    if sink and sink != "0":
        cmd.extend(['--target', sink, '--properties', 'stream.capture.sink=true'])
    else:
        cmd.extend(['--properties', 'stream.capture.sink=true'])
    cmd.append('-')

    try:
        audio_proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
    except Exception as e:
        print(f"Error starting PipeWire audio record on {sink}: {e}", file=sys.stderr)
        return

    chunk_samples = 1024
    chunk_bytes = chunk_samples * 4 # 1024 samples stereo 16-bit
    
    while running and audio_proc and audio_proc.poll() is None:
        try:
            raw = audio_proc.stdout.read(chunk_bytes)
            if not raw or len(raw) < chunk_bytes:
                time.sleep(0.01)
                continue
            
            samples = struct.unpack(f'<{len(raw)//2}h', raw)
            left = [s / 32768.0 for s in samples[0::2]]
            right = [s / 32768.0 for s in samples[1::2]]
            
            left_bands = compute_64_bands(left)
            right_bands = compute_64_bands(right)
            bands128 = left_bands + right_bands
            audio_json = json.dumps(bands128)
            
            js = f"if(window.__feedWpeAudio) window.__feedWpeAudio({audio_json});"
            def push_js(script=js):
                for wv in webviews:
                    try:
                        wv.run_javascript(script, None, None, None)
                    except Exception:
                        pass
                return False

            GLib.idle_add(push_js)
            time.sleep(0.025) # Smooth ~40 FPS audio FFT stream
        except Exception as ex:
            time.sleep(0.05)

def property_ipc_worker():
    global running, webviews
    if os.path.exists(IPC_SOCKET_PATH):
        try:
            os.unlink(IPC_SOCKET_PATH)
        except Exception:
            pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(IPC_SOCKET_PATH)
    server.listen(5)
    server.settimeout(1.0)

    while running:
        try:
            conn, _ = server.accept()
            data = conn.recv(8192).decode('utf-8')
            conn.close()
            if not data:
                continue
            
            # Expected format: JSON payload containing properties
            try:
                payload = json.loads(data)
                payload_json = json.dumps(payload)
                js = f"""
                if (window.wallpaperPropertyListener && typeof window.wallpaperPropertyListener.applyUserProperties === 'function') {{
                    try {{
                        window.wallpaperPropertyListener.applyUserProperties({payload_json});
                    }} catch(e) {{
                        console.error('IPC property error:', e);
                    }}
                }}
                """
                def apply_prop(script=js):
                    for wv in webviews:
                        try:
                            wv.run_javascript(script, None, None, None)
                        except Exception:
                            pass
                    return False

                GLib.idle_add(apply_prop)
            except Exception as pe:
                print(f"Error parsing IPC property payload: {pe}", file=sys.stderr)
        except socket.timeout:
            continue
        except Exception:
            if running:
                time.sleep(0.1)

    try:
        os.unlink(IPC_SOCKET_PATH)
    except Exception:
        pass

def main():
    global webviews, running
    if len(sys.argv) < 2:
        print("Usage: wpe-layer-web.py <path-to-wallpaper-dir-or-html>", file=sys.stderr)
        sys.exit(1)

    # Process singleton lock
    try:
        import fcntl
        global lock_fd
        lock_fd = open("/tmp/wpe-layer-web.lock", "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except Exception:
        # Another instance is already starting or running
        sys.exit(0)

    target_path = os.path.abspath(sys.argv[1])
    target_dir = target_path
    html_file = "index.html"
    item_id = os.path.basename(target_dir.rstrip('/'))
    merged_properties = {}

    if os.path.isfile(target_path):
        target_dir = os.path.dirname(target_path)
        html_file = os.path.basename(target_path)
        item_id = os.path.basename(target_dir.rstrip('/'))
    elif os.path.isdir(target_path):
        proj_path = os.path.join(target_path, "project.json")
        if os.path.exists(proj_path):
            try:
                with open(proj_path, "r", encoding="utf-8") as f:
                    proj = json.load(f)
                    html_file = proj.get("file", "index.html")
                    raw_props = proj.get("general", {}).get("properties", {})
                    # Clone default properties
                    for k, v in raw_props.items():
                        merged_properties[k] = {"value": v.get("value")}
            except Exception:
                html_file = "index.html"

    # Merge saved user overrides if any
    saved_props_file = os.path.join(PROPS_CONFIG_DIR, f"{item_id}.json")
    if os.path.exists(saved_props_file):
        try:
            with open(saved_props_file, "r", encoding="utf-8") as sf:
                user_overrides = json.load(sf)
                for k, v in user_overrides.items():
                    merged_properties[k] = {"value": v}
        except Exception:
            pass

    properties_json_str = json.dumps(merged_properties)
    port = start_local_server(target_dir)
    target_url = f"http://127.0.0.1:{port}/{html_file}"

    # Configure WebKit Settings for Maximum GPU Acceleration
    settings = WebKit2.Settings()
    settings.set_enable_webgl(True)
    settings.set_enable_javascript(True)
    settings.set_enable_media_stream(True)
    settings.set_enable_smooth_scrolling(False)
    settings.set_enable_page_cache(False)
    settings.set_hardware_acceleration_policy(WebKit2.HardwareAccelerationPolicy.ALWAYS)
    settings.set_media_playback_requires_user_gesture(False)
    settings.set_allow_file_access_from_file_urls(True)
    settings.set_allow_universal_access_from_file_urls(True)

    bridge_script_content = f"""
    (function() {{
        window.__globalWallpaperAudio = new Array(128).fill(0);
        window.wallpaperAudioListeners = window.wallpaperAudioListeners || [];
        window.wallpaperRegisterAudioListener = function(cb) {{
            if (typeof cb === 'function') {{
                window.wallpaperAudioListeners.push(cb);
            }}
        }};
        
        window.__feedWpeAudio = function(arr) {{
            window.__globalWallpaperAudio = arr;
            if (window.wallpaperAudioListeners) {{
                for (var i = 0; i < window.wallpaperAudioListeners.length; i++) {{
                    try {{ window.wallpaperAudioListeners[i](arr); }} catch(e) {{}}
                }}
            }}
        }};
        
        var userProperties = {properties_json_str};
        
        function tryApplyProperties() {{
            if (window.wallpaperPropertyListener && typeof window.wallpaperPropertyListener.applyUserProperties === 'function') {{
                try {{
                    window.wallpaperPropertyListener.applyUserProperties(userProperties);
                }} catch(e) {{}}
            }}
        }}

        if (document.readyState === 'complete') {{
            tryApplyProperties();
        }} else {{
            window.addEventListener('load', function() {{
                setTimeout(tryApplyProperties, 100);
            }});
        }}
        
        var checkCount = 0;
        var checker = setInterval(function() {{
            checkCount++;
            if (window.wallpaperPropertyListener && typeof window.wallpaperPropertyListener.applyUserProperties === 'function') {{
                tryApplyProperties();
                clearInterval(checker);
            }}
            if (checkCount > 60) clearInterval(checker);
        }}, 100);
    }})();
    """

    display = Gdk.Display.get_default()
    if not display:
        print("Error: Could not open default Wayland/GDK display", file=sys.stderr)
        sys.exit(1)

    num_monitors = display.get_n_monitors()
    windows = []

    for i in range(num_monitors):
        monitor = display.get_monitor(i)
        win = Gtk.Window()
        win.set_decorated(False)

        # Initialize as Wayland Layer Shell surface
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_monitor(win, monitor)
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_namespace(win, f"omarchy-wpe-web-{i}")
        GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)

        # Anchor to all 4 edges
        for edge in [GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT]:
            GtkLayerShell.set_anchor(win, edge, True)

        user_content_mgr = WebKit2.UserContentManager()
        user_script = WebKit2.UserScript(
            bridge_script_content,
            WebKit2.UserContentInjectedFrames.ALL_FRAMES,
            WebKit2.UserScriptInjectionTime.START,
            [], []
        )
        user_content_mgr.add_script(user_script)

        webview = WebKit2.WebView.new_with_user_content_manager(user_content_mgr)
        webview.set_settings(settings)
        webview.set_background_color(Gdk.RGBA(0, 0, 0, 1.0))
        webview.load_uri(target_url)

        win.add(webview)
        win.show_all()
        windows.append(win)
        webviews.append(webview)

    # Start PipeWire audio streaming thread
    audio_thread = threading.Thread(target=audio_capture_worker, daemon=True)
    audio_thread.start()

    # Start Real-time Property IPC thread
    ipc_thread = threading.Thread(target=property_ipc_worker, daemon=True)
    ipc_thread.start()

    def shutdown(*_):
        global httpd, running, audio_proc
        running = False
        if audio_proc:
            try:
                audio_proc.kill()
            except Exception:
                pass
        if httpd:
            threading.Thread(target=httpd.shutdown).start()
        Gtk.main_quit()

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    Gtk.main()

if __name__ == "__main__":
    main()
