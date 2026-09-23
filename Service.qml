import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property bool isRunning: false
  property string currentTitle: ""
  property string currentPath: ""
  property int currentPid: 0
  property bool loaded: false

  readonly property string scriptPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/azterisk.wallpaper-engine/scripts/omarchy-wpe"

  function refresh() {
    if (!statusProc.running) {
      statusProc.running = true
    }
  }

  function syncBackground() {
    if (!syncProc.running) {
      syncProc.running = true
    }
  }

  function stop() {
    stopProc.running = true
  }

  function run(itemTarget) {
    runProc.command = [root.scriptPath, "run", String(itemTarget)]
    runProc.running = true
  }

  Process {
    id: statusProc
    command: [root.scriptPath, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text.trim())
          root.isRunning = data.running || false
          root.currentPid = data.pid || 0
          root.currentTitle = data.title || ""
          root.currentPath = data.item_dir || ""
          root.loaded = true
        } catch(e) {
          root.loaded = true
        }
      }
    }
  }

  Process {
    id: syncProc
    command: [root.scriptPath, "sync-current"]
    onExited: root.refresh()
  }

  Process {
    id: stopProc
    command: [root.scriptPath, "stop"]
    onExited: root.refresh()
  }

  Process {
    id: runProc
    onExited: root.refresh()
  }

  function updateState(rawText) {
    if (!rawText) return
    try {
      var data = JSON.parse(rawText.trim())
      root.isRunning = Boolean(data.active || data.running)
      root.currentPid = Number(data.pid) || 0
      root.currentTitle = String(data.title || "")
      root.currentPath = String(data.item_dir || "")
      root.loaded = true
    } catch(e) {
      root.loaded = true
    }
  }

  FileView {
    id: wpeStateFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/wpe-state.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.updateState(text())
    onFileChanged: root.updateState(text())
  }

  property string lastBg: ""

  Process {
    id: checkBgProc
    command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var current = text.trim()
        if (current !== root.lastBg) {
          root.lastBg = current
          root.syncBackground()
        }
      }
    }
  }

  FileView {
    id: bgWatcher
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    watchChanges: true
    printErrors: false
    onLoaded: {
      if (!checkBgProc.running) checkBgProc.running = true
    }
    onFileChanged: {
      if (!checkBgProc.running) checkBgProc.running = true
    }
  }

  // Lightweight watchdog: only active while wallpaper is actually running
  Timer {
    interval: 30000
    repeat: true
    running: root.isRunning
    onTriggered: {
      if (!statusProc.running) statusProc.running = true
    }
  }

  Component.onCompleted: {
    if (!checkBgProc.running) checkBgProc.running = true
    root.refresh()
  }

  IpcHandler {
    target: "wallpaper-engine"

    function status(): string {
      return JSON.stringify({
        running: root.isRunning,
        title: root.currentTitle,
        path: root.currentPath,
        pid: root.currentPid
      })
    }

    function refresh(): void {
      root.refresh()
    }

    function sync(): void {
      root.syncBackground()
    }

    function stop(): void {
      root.stop()
    }

    function run(target: string): void {
      root.run(target)
    }
  }
}
