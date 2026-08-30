# Omarchy Wallpaper Engine Plugin (azterisk.wallpaper-engine)

A modular Omarchy desktop plugin and background switcher integration for Steam Wallpaper Engine on Hyprland (Wayland).

## Key Features

- Dual-Backend Support (All Wallpaper Engine Types):
  - Scene Wallpapers: Native OpenGL shaders, 2D/3D particle meshes, and puppet animations via linux-wallpaperengine.
  - Video Wallpapers: Hardware-accelerated (NVDEC/VAAPI) MPV playback.
  - Web and HTML5 Wallpapers: Native Wayland Layer-Shell client (wpe-layer-web.py) with WebKitGTK and local CORS/Next.js chunk serving.
- Real-Time PipeWire Audio Visualizers:
  - Live 128-band stereo FFT frequency analysis streamed directly from your active PipeWire audio output monitor sink.
  - Isolated from physical microphone inputs so only desktop audio and music trigger the visualizer.
- Live Parameter Controls and In-Widget Drawer:
  - Collapsible LIVE CONTROLS AND SETTINGS drawer in your top bar widget.
  - Real-time sliders with float precision (3D Tilt Angle, Sine Wave Count, Wave Height Multiplier, Audio Sensitivity, 3-Band EQ) and Preset Theme buttons updating live over Unix IPC sockets.
  - Dedicated slider component (WpeSlider) with mouse-wheel isolation so scrolling the panel never accidentally moves sliders.
- Omarchy Theme Scoping and Seamless Background Switcher:
  - Wallpapers assigned to a theme appear in your standard background switcher (Super + Ctrl + Space or omarchy background).
  - Automatic synchronization when changing themes (omarchy theme set <Theme>).
  - Selecting a static wallpaper cleanly stops live processes to save GPU and battery.

## Prerequisites and Dependencies

### 1. Arch Linux and Omarchy Packages:
```bash
# Core Scene and Video wallpaper runner
yay -S linux-wallpaperengine-git

# Web/HTML5 Layer-Shell and Audio FFT dependencies
sudo pacman -S gtk-layer-shell webkit2gtk-4.1 pipewire-tools
```

### 2. Steam and Wallpaper Engine:
Ensure Steam is installed and you have subscribed to wallpapers via Wallpaper Engine (Steam App ID 431960). The plugin automatically detects Steam workshop paths on all mounted drives.

## Installation

### Method 1: Omarchy Plugin Manager (Recommended)
```bash
omarchy plugin add https://github.com/Azteriisk/omarchy-wallpaper-engine.git --enable --yes
```

### Method 2: Git Clone and Setup
```bash
git clone https://github.com/Azteriisk/omarchy-wallpaper-engine.git ~/.config/omarchy/plugins/azterisk.wallpaper-engine
cd ~/.config/omarchy/plugins/azterisk.wallpaper-engine
./install.sh
```

The installer will:
1. Link the omarchy-wpe binary to your ~/.local/bin/.
2. Register the theme-change hook in ~/.config/omarchy/hooks/theme-set.d/.
3. Add the Wallpaper Engine widget to your Omarchy top bar.
4. Reload the Omarchy shell automatically.

## Usage and CLI Reference

### Command Line (omarchy-wpe)

```bash
# List all discovered Wallpaper Engine wallpapers in your Steam libraries
omarchy-wpe list

# Run a wallpaper directly by Workshop ID or path (across all monitors)
omarchy-wpe run 3780178472

# Assign a wallpaper to your active Omarchy theme
omarchy-wpe assign "Matte Black" 3780178472

# Toggle theme assignment
omarchy-wpe toggle-theme "Matte Black" 3780178472

# Get/set live properties in real time
omarchy-wpe get-props active
omarchy-wpe set-prop active tilt_angle 35
omarchy-wpe set-prop active theme tokyo_neon

# Stop active wallpaper
omarchy-wpe stop

# Check running status
omarchy-wpe status
```

### Background Switcher Grid (Super + Ctrl + Space)
Press Super + Ctrl + Space to open the Omarchy background grid. Any Wallpaper Engine wallpapers assigned to your current theme appear with [WPE] badges and full graphical thumbnails.

## Performance Notes and Details

### Web and HTML5 Wallpapers on Linux:
While Scene (OpenGL) and Video (MPV) wallpapers run at native 120Hz to 240Hz with full hardware acceleration, complex Web/Canvas wallpapers (such as intricate Fourier or particle visualizers) have known performance challenges on Linux compared to Windows.

- 2D Canvas ctx.shadowBlur on Cairo / WebKitGTK:
  On Windows (Chromium / Direct2D), heavy canvas blur passes are executed on GPU compute shaders. On Linux (Cairo / WebKitGTK 2D canvas), large shadowBlur values fall back to CPU software rasterizer Gaussian convolutions across millions of pixels.
  - Tip: For web visualizers, keep bloom and glowBlur at 0 or low values (< 5) in the widget settings to maintain 60 to 120+ FPS.
- NVIDIA Wayland Driver and WebKit Crash Alerts:
  Due to an upstream bug in proprietary NVIDIA drivers on Wayland, WebKit's background rendering process (WebKitWebProcess) may intermittently crash when continuously rendering web wallpapers. The plugin includes a built-in helper to silence noisy desktop crash push notifications:
  ```bash
  omarchy-toggle-webkit-crash-alerts
  ```
  Running the command toggles suppression on or off.
- Audio Capture: Audio streaming requires PipeWire (pw-record). Latency is typically under 25ms.

## Uninstallation

To cleanly remove the plugin, hooks, and symlinks:
```bash
cd ~/.config/omarchy/plugins/azterisk.wallpaper-engine
./uninstall.sh
```

## Author and License

- Author: [Azteriisk](https://github.com/Azteriisk)
- License: MIT
