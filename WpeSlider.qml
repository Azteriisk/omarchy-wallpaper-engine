import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property QtObject bar: null
  property real value: 0
  property real minimum: 0
  property real maximum: 100
  property real step: 1
  property bool integer: false
  property bool fraction: false
  property int precision: 2
  property color trackColor: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "#333"
  property color fillColor: Color.accent
  property color knobColor: bar ? bar.foreground : Color.foreground
  property bool dragging: false
  property real trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.12))
  property real knobSize: Math.max(14, Math.round(Style.spacing.controlHeight * 0.40))
  property real liveValue: value

  onValueChanged: if (!dragging) liveValue = value

  signal moved(real value)
  signal released(real value)

  implicitWidth: Style.space(200)
  implicitHeight: Math.max(Style.space(22), knobSize + Style.spacing.sm)

  readonly property real range: Math.max(0.0001, maximum - minimum)
  readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
  readonly property bool _hot: mouseArea.containsMouse || root.dragging

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.trackHeight
    radius: height / 2
    color: root.trackColor
  }

  Rectangle {
    id: fill
    anchors.verticalCenter: track.verticalCenter
    anchors.left: track.left
    height: track.height
    radius: track.radius
    color: root.fillColor
    width: track.width * root.progress

    Behavior on width {
      enabled: !root.dragging
      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
  }

  BorderSurface {
    id: knob
    width: root.knobSize
    height: root.knobSize
    radius: root.knobSize / 2
    color: root.knobColor
    borderSpec: Border.flat(root.bar ? root.bar.background : "#101315", Math.max(1, Style.space(2)))
    anchors.verticalCenter: track.verticalCenter
    x: Math.max(0, Math.min(track.width - width, track.width * root.progress - width / 2))
    scale: root._hot ? 1.2 : 1.0

    Behavior on x {
      enabled: !root.dragging
      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
      NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    function valueFromX(x) {
      var clamped = Math.max(0, Math.min(track.width, x))
      var raw = root.minimum + (clamped / track.width) * root.range
      if (root.step > 0) {
        raw = Math.round((raw - root.minimum) / root.step) * root.step + root.minimum
      }
      if (root.fraction) {
        raw = Number(raw.toFixed(root.precision > 0 ? root.precision : 2))
      } else {
        raw = Math.round(raw)
      }
      return Math.max(root.minimum, Math.min(root.maximum, raw))
    }

    onPressed: function(mouse) {
      root.dragging = true
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }

    onPositionChanged: function(mouse) {
      if (!root.dragging) return
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }

    onReleased: function(mouse) {
      root.dragging = false
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.released(next)
    }

    // Explicitly reject and ignore mouse wheel scroll events so parent ScrollView scrolls naturally!
    onWheel: function(wheel) {
      wheel.accepted = false
    }
  }
}
