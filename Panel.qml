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
    themeNameProc.running = true
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

    setPropProc.command = ["bash", "-c", root.scriptPath + " set-prop active \"" + propId + "\" \"" + propValue + "\""]
    setPropProc.running = true
  }

  function toggleThemeAssignment(itemId) {
    actionProc.command = ["bash", "-c", root.scriptPath + " toggle-theme \"" + root.currentTheme + "\" \"" + itemId + "\""]
    actionProc.running = true
  }

  function assignToCurrentTheme(itemId) {
    actionProc.command = ["bash", "-c", root.scriptPath + " assign \"" + root.currentTheme + "\" \"" + itemId + "\""]
    actionProc.running = true
  }

  function unassignFromTheme(titlePattern) {
    actionProc.command = ["bash", "-c", root.scriptPath + " unassign \"" + root.currentTheme + "\" \"" + titlePattern + "\""]
    actionProc.running = true
  }

  function runWallpaper(itemIdOrPath) {
    actionProc.command = ["bash", "-c", root.scriptPath + " run \"" + itemIdOrPath + "\""]
    actionProc.running = true
  }

  function setActiveWallpaper(itemId) {
    actionProc.command = ["bash", "-c", root.scriptPath + " set \"" + itemId + "\""]
    actionProc.running = true
  }

  function stopWallpaper() {
    actionProc.command = ["bash", "-c", root.scriptPath + " stop"]
    actionProc.running = true
  }

  function syncWallpaper() {
    actionProc.command = ["bash", "-c", root.scriptPath + " sync-current"]
    actionProc.running = true
  }

  // --- Backend Processes ---
  Process {
    id: statusProc
    command: ["bash", "-c", root.scriptPath + " status --json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text.trim())
          root.isRunning = data.running || false
          root.currentPid = data.pid || 0
          root.currentTitle = data.title || ""
          root.currentPath = data.item_dir || ""
          if (root.isRunning) root.loadProperties()
          else root.activeProperties = []
        } catch(e) {}
      }
    }
  }

  Process {
    id: propsProc
    command: ["bash", "-c", root.scriptPath + " get-props active"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var list = JSON.parse(text.trim())
          root.activeProperties = Array.isArray(list) ? list : []
        } catch(e) {
          root.activeProperties = []
        }
      }
    }
  }

  Process {
    id: themeNameProc
    command: ["cat", Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var val = text.trim()
        if (val.length > 0) root.currentTheme = val
      }
    }
  }

  Process {
    id: workshopListProc
    command: ["bash", "-c", root.scriptPath + " list --json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loadingItems = false
        try {
          var items = JSON.parse(text.trim())
          root.workshopItems = Array.isArray(items) ? items : []
        } catch(e) {
          root.workshopItems = []
        }
      }
    }
    onExited: root.loadingItems = false
  }

  Process {
    id: assignedListProc
    command: ["bash", "-c", root.scriptPath + " assigned \"" + root.currentTheme + "\" --json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.assignedIds = JSON.parse(text.trim()) || []
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
                text: "Wallpaper Engine"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.isRunning ? ("LIVE · " + root.currentTitle) : "STANDBY · STATIC BACKGROUND"
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
                  text: root.propertiesExpanded ? "▾" : "▸"
                  color: Color.accent
                  font.pixelSize: Style.font.title
                  font.family: root.bar.fontFamily
                }

                Text {
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
                        text: propContainer.propItem.name
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: parent.width - Style.space(60)
                      }

                      Text {
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
                        text: propContainer.propItem.name + ":"
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
                            text: modelData.label || modelData.value
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
                      text: itemCard.modelData.title || ("Item " + itemCard.modelData.id)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      text: "ID: " + itemCard.modelData.id + " · Type: " + itemCard.modelData.type + (String(itemCard.modelData.type).toLowerCase() === 'web' ? " (CEF)" : "")
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
