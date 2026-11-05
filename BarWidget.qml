import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.yassinesawahi.voice"

  // All the logic lives in the voice foreman's `vf-ctl`; this widget only reads and flips switches.
  // Set the path in the widget settings, or leave it empty to find `vf-ctl` on PATH.
  readonly property string ctlPath: String(root.settings.ctlPath || "").trim() || "vf-ctl"

  readonly property var glyphs: ({
    phone: String.fromCodePoint(0xF03F2),   // nf-md-phone
    talk: String.fromCodePoint(0xF03F6),    // nf-md-phone_in_talk
    off: String.fromCodePoint(0xF0F19),     // nf-md-phone_off
    alert: String.fromCodePoint(0xF0026)    // nf-md-alert
  })

  // Latest `vf-ctl` reading; null until the first one lands.
  property var status: null
  property bool popupOpen: false
  property bool refreshQueued: false

  readonly property bool powerOn: !!root.status && root.status.power
  readonly property bool callsOn: !!root.status && root.status.calls
  readonly property bool awayOnly: !!root.status && root.status.mode === "away"
  readonly property bool live: !!root.status && (root.status.in_call || root.status.ringing)
  readonly property bool atDesk: !!root.status && !!root.status.desk
  readonly property bool phoneDown: !!root.status && !!root.status.phone && root.status.phone.reachable === false

  function clock(epoch) {
    return epoch ? Qt.formatTime(new Date(epoch * 1000), "HH:mm") : ""
  }

  readonly property string stateLine: {
    var s = root.status
    if (!s) return "Reading…"
    if (!s.power) return "Off · no calls either way"
    if (s.desk) return "Talking at the PC"
    if (s.in_call) return "On a call right now"
    if (s.ringing) return "Calling your phone…"
    if (s.callback) return "Calling you back at " + root.clock(s.callback)
    if (s.calls && s.quiet_now) return "Do Not Disturb or quiet hours: holding "
      + (s.pending ? s.pending + (s.pending === 1 ? " thing" : " things") : "news") + " until it ends"
    if (s.next_call) return "Calling you at " + root.clock(s.next_call) + " about " + s.pending
      + (s.pending === 1 ? " thing" : " things")
    if (!s.calls) return "Answers when you call; won't call you"
    if (s.mode === "away") return "Calls you about your sessions when you're away from the PC"
    return "Calls you when a session finishes or needs you"
  }

  readonly property string phoneLine: {
    var p = root.status && root.status.phone
    if (!p || p.reachable === null) return ""
    return (p.reachable ? "Phone answering" : root.glyphs.alert + "  Phone not answering")
      + " · checked " + root.clock(p.checked)
  }

  readonly property string tooltipLabel: {
    if (!root.status) return "Omarchy Voice"
    return "Omarchy · " + root.stateLine + "\nMiddle-click to turn calls " + (root.callsOn ? "off" : "on")
  }

  function refresh() {
    if (readProc.running) root.refreshQueued = true
    else readProc.running = true
  }

  function applyReading(text) {
    try { root.status = JSON.parse(text) } catch (e) {}
  }

  // Runs `vf-ctl <args…>`; it prints the new status, so the widget updates as soon as it's done.
  function run(args) {
    if (actionProc.running) return
    actionProc.command = [root.ctlPath].concat(args)
    actionProc.running = true
  }

  function toggleCalls() { root.run(["calls", "toggle"]) }
  function togglePower() { root.run(["power", root.powerOn ? "off" : "on"]) }
  function setMode(mode) { root.run(["mode", mode]) }
  function callMe() { root.run(["call-me"]) }
  function toggleDesk() { root.run(["desk", "toggle"]) }

  // Contract KeyboardPanel expects on its `owner`.
  function close() {
    root.popupOpen = false
  }

  function toggle() {
    root.popupOpen = !root.popupOpen
    if (root.popupOpen) root.refresh()
  }

  // Only the copy that's on screen takes IPC (the floating bar can mount a hidden second copy).
  readonly property bool onScreen: {
    var w = button.QsWindow.window
    return !!w && w.visible && root.visible && root.width > 0 && root.height > 0
  }

  // `omarchy-shell io.github.yassinesawahi.voice <fn>`: bindable to keys.
  IpcHandler {
    target: "io.github.yassinesawahi.voice"
    enabled: root.onScreen

    function toggle() { root.toggle() }
    function close() { root.close() }
    function refresh() { root.refresh() }
    function toggleCalls() { root.toggleCalls() }
    function togglePower() { root.togglePower() }
    function callMe() { root.callMe() }
    function toggleDesk() { root.toggleDesk() }
  }

  Process {
    id: readProc
    command: [root.ctlPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyReading(text)
    }
    onExited: {
      if (!root.refreshQueued) return
      root.refreshQueued = false
      Qt.callLater(root.refresh)
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyReading(text)
    }
  }

  Timer {
    interval: root.popupOpen || root.live ? 3000 : 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    tooltipText: root.tooltipLabel
    fixedWidth: root.vertical ? -1 : glyph.width + button.scaledHorizontalMargin * 2
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1

    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh()
      else if (b === Qt.MiddleButton) root.toggleCalls()
      else root.toggle()
    }

    OpticalGlyph {
      id: glyph
      anchors.centerIn: parent
      width: Style.bar.iconCanvas
      height: Style.bar.iconCanvas
      text: root.live ? root.glyphs.talk : root.powerOn && root.callsOn ? root.glyphs.phone : root.glyphs.off
      fontFamily: button.fontFamily
      fontSize: Style.bar.iconFont
      // Lit during a call, and when the phone stops answering, so neither goes unnoticed.
      color: root.live || root.powerOn && root.phoneDown ? root.bar.urgent : button.foreground
      opacity: root.powerOn ? 1 : 0.5
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(col.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        readonly property color dim: Qt.darker(root.bar.foreground, 1.4)

        PanelSectionHeader {
          text: "OMARCHY ON THE PHONE"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        // State and the power switch.
        Item {
          width: parent.width
          height: Math.max(heroGlyph.implicitHeight, heroText.implicitHeight, powerButton.implicitHeight)

          Text {
            id: heroGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: glyph.text
            color: glyph.color
            opacity: root.powerOn ? 1 : 0.5
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title * 1.4
          }

          Column {
            id: heroText
            anchors.left: heroGlyph.right
            anchors.leftMargin: Style.space(10)
            anchors.right: powerButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.powerOn ? "Omarchy is on" : "Omarchy is off"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: root.stateLine
              textFormat: Text.PlainText
              color: col.dim
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Button {
            id: powerButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.powerOn ? "Turn off" : "Turn on"
            selected: root.powerOn
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.togglePower()
          }
        }

        // Talk at the PC: the camera's mic and the speakers, no phone call.
        Item {
          width: parent.width
          height: Math.max(deskText.implicitHeight, deskButton.implicitHeight)
          visible: root.powerOn

          Column {
            id: deskText
            anchors.left: parent.left
            anchors.right: deskButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Talk at the PC"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.atDesk ? "Say bye, or end it here. \"Call me\" moves it to your phone."
                : root.status && root.status.in_call ? "Moves this phone call to the PC's mic and speakers"
                : "Through the PC's mic and speakers, no phone call"
              color: col.dim
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Button {
            id: deskButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.atDesk ? "End" : root.status && root.status.in_call ? "Move here" : "Talk here"
            selected: root.atDesk
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.toggleDesk()
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        // Calls to your phone: on/off, and when.
        Item {
          width: parent.width
          height: Math.max(callsText.implicitHeight, callsButton.implicitHeight)
          opacity: root.powerOn ? 1 : 0.5

          Column {
            id: callsText
            anchors.left: parent.left
            anchors.right: callsButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Call my phone"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              width: parent.width
              text: "When a Claude session finishes or needs you"
              color: col.dim
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Button {
            id: callsButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.callsOn ? "On" : "Off"
            selected: root.callsOn
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.toggleCalls()
          }
        }

        Row {
          spacing: Style.space(8)
          opacity: root.powerOn && root.callsOn ? 1 : 0.5

          Button {
            text: "Always"
            selected: !root.awayOnly
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.setMode("always")
          }
          Button {
            text: "Only when I'm away"
            selected: root.awayOnly
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.setMode("away")
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Item {
          width: parent.width
          height: Math.max(phoneText.implicitHeight, callMeButton.implicitHeight)

          Text {
            id: phoneText
            anchors.left: parent.left
            anchors.right: callMeButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.phoneLine
            textFormat: Text.PlainText
            color: root.phoneDown ? root.bar.urgent : col.dim
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Button {
            id: callMeButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.powerOn && root.callsOn
            text: "Call me now"
            bordered: true
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.callMe()
          }
        }

        Text {
          width: parent.width
          text: "Call Omarchy from your SIP phone app. Middle-click the bar icon to turn calls on or off."
          color: col.dim
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
