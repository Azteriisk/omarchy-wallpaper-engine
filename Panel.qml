import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "azterisk.wallpaper-engine"
  ipcTarget: "azterisk.wallpaper-engine"
  manageIpc: false

  property bool isRunning: false
  property string currentTitle: ""
  property string currentPath: ""
  property int currentPid: 0
  property string currentTheme: "Matte Black"

  property var workshopItems: []
  property var assignedIds: []
  property var activeProperties: []
  property bool propertiesExpanded: true
  property bool loadingItems: false

  readonly property string scriptPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/azterisk.wallpaper-engine/scripts/omarchy-wpe"

  function refresh() {
    statusProc.running = true
    loadWorkshopList()
    loadAssignedList()
  }

  function loadWorkshopList() {
    if (!workshopListProc.running) {
      root.loadingItems = true
      workshopListProc.running = true
    }
  }

  function loadAssignedList() {
    if (!assignedListProc.running) {
      assignedListProc.running = true
    }
  }

  function loadProperties() {
    if (!propsProc.running) {
      propsProc.running = true
    }
  }

  function setProperty(propId, propValue) {
    // Update local state immediately for instant responsive UI feedback
    var updated = []
    for (var i = 0; i < root.activeProperties.length; i++) {
      var item = root.activeProperties[i]
      if (item.id === propId) {
        item.value = propValue
      }
      updated.push(item)
    }
    root.activeProperties = updated

    setPropProc.command = [root.scriptPath, "set-prop", "active", String(propId), String(propValue)]
    setPropProc.running = true
  }

  function toggleThemeAssignment(itemId) {
    actionProc.command = [root.scriptPath, "toggle-theme", String(root.currentTheme), String(itemId)]
    actionProc.running = true
  }

  function assignToCurrentTheme(itemId) {
    actionProc.command = [root.scriptPath, "assign", String(root.currentTheme), String(itemId)]
    actionProc.running = true
  }

  function unassignFromTheme(titlePattern) {
    actionProc.command = [root.scriptPath, "unassign", String(root.currentTheme), String(titlePattern)]
    actionProc.running = true
  }

  function runWallpaper(itemIdOrPath) {
    actionProc.command = [root.scriptPath, "run", String(itemIdOrPath)]
    actionProc.running = true
  }

  function setActiveWallpaper(itemId) {
    actionProc.command = [root.scriptPath, "set", String(itemId)]
    actionProc.running = true
  }

  function stopWallpaper() {
    actionProc.command = [root.scriptPath, "stop"]
    actionProc.running = true
  }

  function syncWallpaper() {
    actionProc.command = [root.scriptPath, "sync-current"]
    actionProc.running = true
  }

  // --- Backend Processes ---
  Process {
    id: statusProc
    command: [root.scriptPath, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || text.length > 32768) return
        try {
          var data = JSON.parse(text.trim())
          root.isRunning = Boolean(data.running)
          root.currentPid = Number(data.pid) || 0
          root.currentTitle = String(data.title || "").slice(0, 100)
          root.currentPath = String(data.item_dir || "").slice(0, 500)
          if (root.isRunning) root.loadProperties()
          else root.activeProperties = []
        } catch(e) {}
      }
    }
  }

  Process {
    id: propsProc
    command: [root.scriptPath, "get-props", "active"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || text.length > 65536) {
          root.activeProperties = []
          return
        }
        try {
          var rawList = JSON.parse(text.trim())
          if (!Array.isArray(rawList)) {
            root.activeProperties = []
            return
          }
          var cleanList = []
          var maxProps = Math.min(rawList.length, 50)
          for (var i = 0; i < maxProps; i++) {
            var p = rawList[i]
            if (!p || typeof p !== 'object') continue
            var cleanOpts = []
            if (Array.isArray(p.options)) {
              var maxOpts = Math.min(p.options.length, 20)
              for (var j = 0; j < maxOpts; j++) {
                var opt = p.options[j]
                if (opt && typeof opt === 'object') {
                  cleanOpts.push({
                    label: String(opt.label || opt.value || "").slice(0, 64),
                    value: String(opt.value || "").slice(0, 64)
                  })
                }
              }
            }
            cleanList.push({
              id: String(p.id || "").slice(0, 64),
              name: String(p.name || p.id || "").slice(0, 64),
              type: String(p.type || "text").slice(0, 32),
              min: Number(p.min) || 0,
              max: Number(p.max) || 100,
              fraction: Boolean(p.fraction),
              precision: Number(p.precision) || 0,
              step: Number(p.step) || 1,
              value: p.value,
              options: cleanOpts
            })
          }
          root.activeProperties = cleanList
        } catch(e) {
          root.activeProperties = []
        }
      }
    }
  }

  FileView {
    id: themeNameFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var val = text().trim().slice(0, 64)
      if (val.length > 0) root.currentTheme = val
    }
    onFileChanged: {
      var val = text().trim().slice(0, 64)
      if (val.length > 0) {
        root.currentTheme = val
        root.loadAssignedList()
      }
    }
  }

  Process {
    id: workshopListProc
    command: [root.scriptPath, "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loadingItems = false
        if (!text || text.length > 524288) {
          root.workshopItems = []
          return
        }
        try {
          var rawItems = JSON.parse(text.trim())
          if (!Array.isArray(rawItems)) {
            root.workshopItems = []
            return
          }
          var cleanItems = []
          var maxItems = Math.min(rawItems.length, 500)
          for (var k = 0; k < maxItems; k++) {
            var it = rawItems[k]
            if (!it || typeof it !== 'object') continue
            cleanItems.push({
              id: String(it.id || "").slice(0, 64),
              title: String(it.title || ("Item " + it.id)).slice(0, 100),
              type: String(it.type || "unknown").slice(0, 32),
              preview: String(it.preview || "").slice(0, 500),
              path: String(it.path || "").slice(0, 500)
            })
          }
          root.workshopItems = cleanItems
        } catch(e) {
          root.workshopItems = []
        }
      }
    }
    onExited: root.loadingItems = false
  }

  Process {
    id: assignedListProc
    command: [root.scriptPath, "assigned", String(root.currentTheme), "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || text.length > 65536) {
          root.assignedIds = []
          return
        }
        try {
          var rawAssigned = JSON.parse(text.trim()) || []
          if (!Array.isArray(rawAssigned)) {
            root.assignedIds = []
            return
          }
          var cleanAssigned = []
          var maxAssigned = Math.min(rawAssigned.length, 500)
          for (var a = 0; a < maxAssigned; a++) {
            cleanAssigned.push(String(rawAssigned[a]).slice(0, 64))
          }
          root.assignedIds = cleanAssigned
        } catch(e) {
          root.assignedIds = []
        }
      }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Process {
    id: setPropProc
  }

  Component.onCompleted: root.refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // --- Top Bar Widget Button ---
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.isRunning ? "󰸉" : "󰸊"
    foreground: root.isRunning ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
    tooltipText: root.isRunning ? ("Wallpaper Engine: " + root.currentTitle) : "Wallpaper Engine (Standby)"
    onPressed: function(b) {
      root.refresh()
      root.toggle()
    }
  }

  // --- Flyout / Popup Panel ---
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero Header ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              text: "󰸉"
              color: root.isRunning ? Color.accent : root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "Wallpaper Engine"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.isRunning ? ("LIVE · " + String(root.currentTitle).slice(0, 64)) : "STANDBY · STATIC BACKGROUND"
                color: root.isRunning ? Color.accent : Qt.darker(root.bar.foreground, 1.8)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.1
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          // ---------- Playback & Control Action Buttons ----------
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              text: root.isRunning ? "Stop Engine" : "Sync Current"
              fontSize: Style.font.caption
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.md
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              width: (parent.width - Style.space(8)) / 2
              onClicked: {
                if (root.isRunning) root.stopWallpaper()
                else root.syncWallpaper()
              }
            }

            Button {
              text: "Rescan Steam"
              fontSize: Style.font.caption
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.md
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              width: (parent.width - Style.space(8)) / 2
              onClicked: root.refresh()
            }
          }

          // ---------- Live Wallpaper Properties (Collapsible) ----------
          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.isRunning && root.activeProperties.length > 0

            Item {
              width: parent.width
              implicitHeight: Style.space(26)

              Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText
                  text: root.propertiesExpanded ? "▾" : "▸"
                  color: Color.accent
                  font.pixelSize: Style.font.title
                  font.family: root.bar.fontFamily
                }

                Text {
                  textFormat: Text.PlainText
                  text: "LIVE CONTROLS & SETTINGS (" + root.activeProperties.length + ")"
                  color: root.bar.foreground
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.family: root.bar.fontFamily
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.propertiesExpanded = !root.propertiesExpanded
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(12)
              visible: root.propertiesExpanded

              Repeater {
                model: root.activeProperties

                Item {
                  id: propContainer
                  property var propItem: modelData
                  width: parent.width
                  implicitHeight: propCol.implicitHeight
                  visible: propItem.type === "slider" || propItem.type === "combo" || propItem.type === "bool"

                  Column {
                    id: propCol
                    width: parent.width
                    spacing: Style.space(4)

                    // Slider controls
                    Item {
                      width: parent.width
                      implicitHeight: Style.space(18)
                      visible: propContainer.propItem.type === "slider"

                      Text {
                        textFormat: Text.PlainText
                        text: String(propContainer.propItem.name).slice(0, 64)
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: parent.width - Style.space(60)
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: {
                          var val = propSlider.dragging ? propSlider.liveValue : propContainer.propItem.value
                          if (propContainer.propItem.fraction) {
                            return Number(val).toFixed(propContainer.propItem.precision !== undefined ? propContainer.propItem.precision : 2)
                          }
                          return Math.round(Number(val))
                        }
                        color: Color.accent
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    WpeSlider {
                      id: propSlider
                      width: parent.width
                      bar: root.bar
                      minimum: propContainer.propItem.min !== undefined ? Number(propContainer.propItem.min) : 0
                      maximum: propContainer.propItem.max !== undefined ? Number(propContainer.propItem.max) : 100
                      value: propContainer.propItem.value !== undefined ? Number(propContainer.propItem.value) : 0
                      fraction: propContainer.propItem.fraction || false
                      precision: propContainer.propItem.precision !== undefined ? propContainer.propItem.precision : 2
                      step: propContainer.propItem.step !== undefined ? Number(propContainer.propItem.step) : (fraction ? 0.05 : 1)
                      visible: propContainer.propItem.type === "slider"
                      onMoved: function(v) {
                        var finalVal = propContainer.propItem.fraction ? Number(v.toFixed(precision)) : Math.round(v)
                        root.setProperty(propContainer.propItem.id, finalVal)
                      }
                    }

                    // Combo / Presets
                    Column {
                      width: parent.width
                      spacing: Style.space(4)
                      visible: propContainer.propItem.type === "combo" && propContainer.propItem.options && propContainer.propItem.options.length > 0

                      Text {
                        textFormat: Text.PlainText
                        text: String(propContainer.propItem.name).slice(0, 64) + ":"
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Flow {
                        width: parent.width
                        spacing: Style.space(4)

                        Repeater {
                          model: propContainer.propItem.options
                          Button {
                            required property var modelData
                            text: String(modelData.label || modelData.value || "").slice(0, 64)
                            fontSize: Style.font.fineprint
                            foreground: modelData.value === propContainer.propItem.value ? Color.accent : root.bar.foreground
                            bordered: true
                            onClicked: {
                              root.setProperty(propContainer.propItem.id, modelData.value)
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          // ---------- Theme Integration Info ----------
          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "CURRENT THEME: " + root.currentTheme.toUpperCase()
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Text {
              textFormat: Text.PlainText
              text: "Assign wallpapers to this theme so they appear in your Super+Ctrl+Space background switcher."
              color: Qt.darker(root.bar.foreground, 1.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              width: parent.width
            }
          }

          // ---------- Discovered Steam Workshop Wallpapers ----------
          PanelSeparator { foreground: root.bar.foreground }

          Item {
            width: parent.width
            implicitHeight: wsHeader.implicitHeight

            PanelSectionHeader {
              id: wsHeader
              text: "STEAM WORKSHOP WALLPAPERS (" + root.workshopItems.length + ")"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              textFormat: Text.PlainText
              visible: root.loadingItems
              text: "Scanning..."
              color: Color.accent
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Workshop list / empty state
          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              height: Style.space(60)
              visible: root.workshopItems.length === 0 && !root.loadingItems

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "No downloaded Wallpaper Engine items found.\nMake sure wallpapers are subscribed in Steam."
                color: Qt.darker(root.bar.foreground, 2.0)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
              }
            }

            Repeater {
              model: root.workshopItems
              delegate: Rectangle {
                id: itemCard
                required property var modelData
                width: panelColumn.width
                implicitHeight: Style.space(64)
                color: Qt.darker(root.bar.foreground, 8.5)
                radius: Style.space(6)
                border.color: (root.isRunning && root.currentPath === modelData.path) ? Color.accent : Qt.darker(root.bar.foreground, 4.0)
                border.width: 1

                readonly property bool isAssigned: root.assignedIds.indexOf(String(modelData.id)) !== -1
                readonly property bool isCurrentActive: root.isRunning && (root.currentPath === modelData.path)

                Row {
                  anchors.fill: parent
                  anchors.margins: Style.space(6)
                  spacing: Style.space(10)

                  // Preview Thumbnail Image
                  Rectangle {
                    width: Style.space(80)
                    height: parent.height
                    radius: Style.space(4)
                    color: "black"
                    clip: true

                    Image {
                      anchors.fill: parent
                      source: modelData.preview ? ("file://" + modelData.preview) : ""
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                    }
                  }

                  // Title & Metadata
                  Column {
                    width: parent.width - Style.space(80 + 10 + 90)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Text {
                      textFormat: Text.PlainText
                      text: String(itemCard.modelData.title || ("Item " + itemCard.modelData.id)).slice(0, 100)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: "ID: " + String(itemCard.modelData.id).slice(0, 64) + " · Type: " + String(itemCard.modelData.type).slice(0, 32) + (String(itemCard.modelData.type).toLowerCase() === 'web' ? " (CEF)" : "")
                      color: String(itemCard.modelData.type).toLowerCase() === 'web' ? Qt.darker(Color.accent, 1.3) : Qt.darker(root.bar.foreground, 2.0)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }

                  // Action Buttons
                  Column {
                    width: Style.space(90)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Button {
                      text: itemCard.isAssigned ? "✓ In Theme" : "+ Theme"
                      fontSize: Style.font.caption
                      foreground: itemCard.isAssigned ? Color.accent : root.bar.foreground
                      fontFamily: root.bar.fontFamily
                      horizontalPadding: Style.spacing.xs
                      verticalPadding: 2
                      width: parent.width
                      bordered: true
                      onClicked: root.toggleThemeAssignment(itemCard.modelData.id)
                    }

                    Button {
                      text: itemCard.isCurrentActive ? "● Active" : "▶ Set"
                      fontSize: Style.font.caption
                      foreground: itemCard.isCurrentActive ? Color.accent : root.bar.foreground
                      fontFamily: root.bar.fontFamily
                      horizontalPadding: Style.spacing.xs
                      verticalPadding: 2
                      width: parent.width
                      bordered: true
                      onClicked: root.setActiveWallpaper(itemCard.modelData.id)
                    }
                  }
                }
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(8)
          }
        }
      }
    }
  }
}
