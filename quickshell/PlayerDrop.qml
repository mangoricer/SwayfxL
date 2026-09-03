// PlayerDrop.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland

PanelWindow {
    id: root

    property color bg:        "#1e1e2e"
    property color fg:        "#cdd6f4"
    property color accent:    "#89b4fa"
    property color muted:     "#6c7086"
    property color coverBg:   "#11111b"
    property color cavaColor: accent

    readonly property int widgetW: 300
    readonly property int widgetH: 118
    readonly property int coverSize: 68
    readonly property int holeSize: 16
    readonly property int r: 18

    property bool shown: false
    property bool panelVisible: false

    readonly property MprisPlayer player: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; ++i)
            if (list[i].identity.toLowerCase().includes("spotify"))
                return list[i]
        return list.length > 0 ? list[0] : null
    }

    readonly property bool hasPlayer: !!player
    readonly property bool playing:   hasPlayer && player.isPlaying
    readonly property string title:   hasPlayer ? (player.trackTitle  || "Unknown") : "Nothing playing"
    readonly property string artist:  hasPlayer ? (player.trackArtist || "") : ""
    readonly property string artUrl:  hasPlayer ? (player.trackArtUrl || "") : ""

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

    Behavior on accent { ColorAnimation { duration: 200 } }

    Timer {
        id: hideTimer
        interval: 480
        onTriggered: {
            if (!root.shown)
                root.panelVisible = false
        }
    }

    onShownChanged: {
        if (root.shown)
            root.panelVisible = true
        else
            hideTimer.restart()
    }

    IpcHandler {
        target: "playerdrop"
        function toggle(): void { root.shown = !root.shown }
        function open(): void   { root.shown = true }
        function close(): void  { root.shown = false }
    }

    anchors { top: true; left: true }
    margins { top: 14; left: 0 }

    implicitWidth:  widgetW + 40
    implicitHeight: widgetH + 30

    visible: root.panelVisible
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: root.shown

    WlrLayershell.namespace: "quickshell-player-drop"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
        id: slide
        width: widgetW
        height: widgetH
        anchors.top: parent.top
        enabled: root.shown

        x: root.shown ? 0 : -width - 30
        opacity: root.shown ? 1 : 0

        Behavior on x {
            NumberAnimation {
                duration: 450
                easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 280 }
        }

        Rectangle {
            anchors.fill: parent
            color: root.bg
            radius: root.r

            Rectangle {
                width: root.r + 2
                height: parent.height
                anchors.left: parent.left
                color: root.bg
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.9
            shadowVerticalOffset: 5
            shadowHorizontalOffset: 4
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                Item {
                    Layout.preferredWidth: coverSize
                    Layout.preferredHeight: coverSize

                    Rectangle {
                        id: coverMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: coverMask
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.darker(root.bg, 1.5)
                        visible: !coverImg.visible

                        Text {
                            anchors.centerIn: parent
                            text: "♪"
                            font.pixelSize: 26
                            color: root.muted
                        }
                    }

                    Rectangle {
                        width: holeSize
                        height: holeSize
                        radius: holeSize / 2
                        anchors.centerIn: parent
                        color: root.coverBg
                        border.color: "#00000066"
                        border.width: 1
                        z: 10
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: "#3e394c"
                        border.width: 1.5
                        z: 11
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.title
                        color: root.fg
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        maximumLineCount: 1
                    }

                    Text {
                        text: root.artist
                        color: root.muted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text.length > 0
                    }

                    Row {
                        spacing: 16
                        Layout.topMargin: 4

                        Text {
                            text: "󰒮"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: root.accent
                            opacity: (player && player.canGoPrevious) ? 1 : 0.35

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                enabled: player && player.canGoPrevious
                                onClicked: player.previous()
                            }
                        }

                        Text {
                            text: root.playing ? "󰏤" : "󰐊"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 17
                            color: root.accent

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                enabled: player && player.canTogglePlaying
                                onClicked: player.togglePlaying()
                            }
                        }

                        Text {
                            text: "󰒭"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: root.accent
                            opacity: (player && player.canGoNext) ? 1 : 0.35

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                enabled: player && player.canGoNext
                                onClicked: player.next()
                            }
                        }
                    }
                }
            }

            Item {
                id: cavaBox
                Layout.fillWidth: true
                Layout.preferredHeight: cavaHeight
                clip: true

                property real cavaHeight: (root.playing && root.shown) ? 20 : 0
                property var levels: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

                Behavior on cavaHeight {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                opacity: (root.playing && root.shown) ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                Row {
                    id: cavaRow
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        model: 24

                        Rectangle {
                            width: Math.max(2, (cavaRow.width - 23 * 3) / 24)
                            height: Math.max(2, parent.height * ((cavaBox.levels[index] || 0) / 100))
                            anchors.bottom: parent.bottom
                            radius: 2
                            color: root.cavaColor
                            opacity: 0.9

                            Behavior on height {
                                NumberAnimation {
                                    duration: 55
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }

                Process {
                    id: cavaProc
                    command: [
                        "cava",
                        "-p",
                        `${Quickshell.env("HOME")}/.config/cava/playerdrop`
                    ]
                    running: root.playing && root.shown && root.panelVisible

                    stdout: SplitParser {
                        onRead: data => {
                            const clean = data.trim().replace(/;/g, " ")
                            const parts = clean.split(/\s+/).map(v => parseInt(v, 10)).filter(v => !isNaN(v))
                            if (parts.length > 0) {
                                const out = []
                                for (let i = 0; i < 24; i++)
                                    out.push(parts[i % parts.length] || 0)
                                cavaBox.levels = out
                            }
                        }
                    }
                }
            }
        }
    }
}
