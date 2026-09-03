// Bar.qml — SwayFX
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property color fg:       "#cdd6f4"
    property color accent:   "#89b4fa"
    property color muted:    "#6c7086"
    property color surface:  "#313244"
    property color barColor: Qt.rgba(0.118, 0.118, 0.180, 0.85)

    readonly property int barH: 36
    readonly property int rootR: 16

    property var workspaces: []
    property var procList: []
    property bool procOpen: false
    property bool procVisible: false

    FileView {
        path: `${Quickshell.env("HOME")}/.config/theme/accent`
        watchChanges: true
        onLoaded: {
            const c = text().trim()
            if (c.length === 7 && c.startsWith("#"))
                root.accent = c
        }
        onFileChanged: reload()
    }

    Behavior on accent { ColorAnimation { duration: 180 } }

    onProcOpenChanged: {
        if (root.procOpen) {
            root.procVisible = true
            root.refreshProcs()
        } else {
            procHideTimer.restart()
        }
    }

    Timer {
        id: procHideTimer
        interval: 220
        onTriggered: if (!root.procOpen) root.procVisible = false
    }

    function refreshWorkspaces() {
        wsProc.running = false
        wsProc.running = true
    }

    function refreshProcs() {
        procProc.running = false
        procProc.running = true
    }

    function paintRoots() {
        leftRoot.requestPaint()
        rightRoot.requestPaint()
    }

    onBarColorChanged: paintRoots()

    anchors { top: true; left: true; right: true }
    implicitHeight: barH + rootR + (procVisible ? 290 : 0)
    color: "transparent"
    exclusiveZone: barH
    exclusionMode: ExclusionMode.Normal
    focusable: root.procOpen

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.procOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Rectangle {
        id: barBody
        z: 2
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.barH
        color: root.barColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 14

            Item {
                id: wsBox
                Layout.alignment: Qt.AlignVCenter
                width: wsRow.implicitWidth
                height: 16

                Rectangle {
                    id: wsIndicator
                    width: 16
                    height: 16
                    radius: 8
                    color: root.accent
                    y: 0
                    x: {
                        let i = 0
                        const list = root.workspaces
                        if (list && list.length) {
                            for (let k = 0; k < list.length; k++) {
                                if (list[k].focused) {
                                    i = k
                                    break
                                }
                            }
                        }
                        return i * (16 + 8)
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Row {
                    id: wsRow
                    spacing: 8
                    z: 1

                    Repeater {
                        model: root.workspaces.length ? root.workspaces : [1, 2, 3, 4, 5]

                        Item {
                            property var ws: (typeof modelData === "object")
                                ? modelData
                                : ({ num: modelData, focused: index === 0, visible: true })

                            width: 16
                            height: 16

                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
                                color: root.fg
                                opacity: {
                                    if (ws.focused) return 0
                                    if (ws.visible) return 0.35
                                    return 0.15
                                }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached([
                                    "swaymsg", "workspace", String(ws.num)
                                ])
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                height: 26
                radius: 9
                color: Qt.rgba(0.19, 0.19, 0.27, 0.9)
                implicitWidth: actions.implicitWidth + 18

                Row {
                    id: actions
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        text: root.procOpen ? "󰅙" : "󰺐"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: root.procOpen ? root.accent : root.fg
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.procOpen = !root.procOpen
                        }
                    }

                    Text {
                        text: "󰒓"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: root.fg
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "qs", "ipc", "call", "controlcenter", "toggle"
                            ])
                        }
                    }

                    Text {
                        text: "󰌾"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: root.accent
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "sh", "-c", "pgrep -x hyprlock >/dev/null || hyprlock"
                            ])
                        }
                    }
                }
            }
        }

        Rectangle {
            id: clockChip
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            radius: 9
            color: root.surface
            border.width: 1
            border.color: root.accent
            width: Math.max(56, clockText.implicitWidth + 18)
            z: 3

            Behavior on border.color { ColorAnimation { duration: 180 } }

            Text {
                id: clockText
                anchors.centerIn: parent
                color: root.fg
                font.pixelSize: 13
                font.weight: Font.DemiBold
                text: Qt.formatDateTime(new Date(), "HH:mm")
            }
        }
    }

    Canvas {
        id: leftRoot
        z: 2
        width: root.rootR
        height: root.rootR
        anchors.top: barBody.bottom
        anchors.left: parent.left
        onPaint: {
            const ctx = getContext("2d")
            const r = width
            ctx.reset()
            ctx.clearRect(0, 0, r, r)
            ctx.fillStyle = root.barColor
            ctx.fillRect(0, 0, r, r)
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(r, r, r, 0, Math.PI * 2)
            ctx.fill()
        }
        Component.onCompleted: requestPaint()
    }

    Canvas {
        id: rightRoot
        z: 2
        width: root.rootR
        height: root.rootR
        anchors.top: barBody.bottom
        anchors.right: parent.right
        onPaint: {
            const ctx = getContext("2d")
            const r = width
            ctx.reset()
            ctx.clearRect(0, 0, r, r)
            ctx.fillStyle = root.barColor
            ctx.fillRect(0, 0, r, r)
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(0, r, r, 0, Math.PI * 2)
            ctx.fill()
        }
        Component.onCompleted: requestPaint()
    }

    Item {
        id: procPopup
        visible: root.procVisible
        enabled: root.procOpen
        width: 340
        height: 270
        anchors.top: barBody.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 10
        z: 5

        opacity: root.procOpen ? 1 : 0
        scale: root.procOpen ? 1 : 0.96
        transform: Translate { y: root.procOpen ? 0 : -8 }

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180 } }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(0.118, 0.118, 0.180, 0.94)
            border.width: 1
            border.color: root.accent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Apps & VPN"
                    color: root.fg
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                Text {
                    text: "󰑓"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: root.muted
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshProcs()
                    }
                }
                Text {
                    text: "󰅖"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    color: root.muted
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.procOpen = false
                    }
                }
            }

            ListView {
                id: procView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 5
                model: root.procList

                delegate: Rectangle {
                    required property var modelData
                    width: procView.width
                    height: 40
                    radius: 10
                    color: root.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: modelData.vpn ? "󰖂" : "󰀻"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: modelData.vpn ? root.accent : root.fg
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: modelData.name
                                color: root.fg
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "pid " + modelData.pid
                                      + "  ·  " + modelData.cpu + "%"
                                      + "  ·  " + modelData.mem + "%"
                                color: root.muted
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            text: "󰅙"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 14
                            color: "#f38ba8"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached([
                                        "kill", "-15", String(modelData.pid)
                                    ])
                                    Qt.callLater(() => root.refreshProcs())
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: procView.count === 0
                    text: "No user apps"
                    color: root.muted
                    font.pixelSize: 12
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: root.procOpen
        onClicked: root.procOpen = false
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
    }

    Process {
        id: wsProc
        command: ["bash", "-c", "swaymsg -t get_workspaces -r 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.workspaces = data.map(w => ({
                        num: w.num,
                        name: w.name,
                        focused: w.focused,
                        visible: w.visible
                    })).sort((a, b) => a.num - b.num)
                } catch (e) {
                    root.workspaces = [1, 2, 3, 4, 5]
                }
            }
        }
    }

    Timer {
        interval: 350
        running: true
        repeat: true
        onTriggered: root.refreshWorkspaces()
    }

    Process {
        id: procProc
        command: ["bash", "-c", `
ps -u "$USER" -o pid=,comm=,%cpu=,%mem= --sort=-%cpu 2>/dev/null | awk '
BEGIN {
  ignore = "^(systemd|systemd-.*|dbus-daemon|dbus-broker|pipewire.*|wireplumber|xdg-.*|sh|bash|zsh|fish|tmux|screen|ssh-agent|gpg-agent|gvfsd.*|at-spi.*|chrome_crashpad|crashpad_handler|qs|quickshell|sway|swaybar|swaybg|swayidle|swaylock|mako|kitty|foot|alacritty|ps|awk|sed|grep)$"
  vpn = "^(openvpn|ovpn|wg|wg-quick|wireguard|nm-openvpn|nm-pptp|nm-l2tp|nm-vpnc|nordvpn|mullvad|protonvpn|openconnect|sstpc|strongswan|charon|tailscaled|tailscale)$"
}
{
  pid=$1; cpu=$(NF-1); mem=$NF
  name=$2
  for(i=3;i<=NF-2;i++) name=name" "$i
  if (name \~ ignore) next
  isvpn = (name \~ vpn) ? 1 : 0
  if (cpu+0 < 0.1 && mem+0 < 0.5 && !isvpn) next
  printf "%s|%s|%s|%s|%d\\n", pid, name, cpu, mem, isvpn
}' | head -n 25
`]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length)
                const list = []
                for (const line of lines) {
                    const p = line.split("|")
                    if (p.length < 5) continue
                    list.push({
                        pid: p[0].trim(),
                        name: p[1].trim(),
                        cpu: p[2].trim(),
                        mem: p[3].trim(),
                        vpn: p[4].trim() === "1"
                    })
                }
                list.sort((a, b) => (b.vpn - a.vpn) || (parseFloat(b.cpu) - parseFloat(a.cpu)))
                root.procList = list
            }
        }
    }

    Timer {
        interval: 2000
        running: root.procOpen
        repeat: true
        onTriggered: root.refreshProcs()
    }
}
