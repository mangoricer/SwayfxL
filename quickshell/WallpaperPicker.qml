// WallpaperPicker.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool shown: false

    IpcHandler {
        target: "wallpapers"
        function toggle(): void {
            root.shown = !root.shown
            if (root.shown) loader.active = true
        }
        function open(): void {
            root.shown = true
            loader.active = true
        }
        function close(): void { root.shown = false }
    }

    Loader {
        id: loader
        active: false
        sourceComponent: pickerComp
        onLoaded: item.shown = root.shown
    }

    Connections {
        target: root
        function onShownChanged() {
            if (loader.item)
                loader.item.shown = root.shown
            if (!root.shown)
                unloadTimer.restart()
        }
    }

    Timer {
        id: unloadTimer
        interval: 400
        onTriggered: if (!root.shown) loader.active = false
    }

    Component {
        id: pickerComp

        PanelWindow {
            id: win

            property bool shown: false
            property bool panelVisible: false

            property color fg:      "#cdd6f4"
            property color accent:  "#89b4fa"
            property color muted:   "#6c7086"
            property color surface: "#313244"

            property var walls: []
            property int index: 0
            property bool useAwww: true    
            property bool busy: false

            readonly property string currentPath: walls.length ? walls[index] : ""

            FileView {
                path: `${Quickshell.env("HOME")}/.config/theme/accent`
                watchChanges: true
                onLoaded: {
                    const c = text().trim()
                    if (c.length === 7 && c.startsWith("#"))
                        win.accent = c
                }
                onFileChanged: reload()
            }

            FileView {
                path: `${Quickshell.env("HOME")}/.config/theme/wall-backend`
                watchChanges: true
                onLoaded: {
                    const v = text().trim()
                    if (v === "sway" || v === "awww")
                        win.useAwww = (v === "awww")
                }
                onFileChanged: reload()
            }

            Timer {
                id: hideTimer
                interval: 300
                onTriggered: if (!win.shown) win.panelVisible = false
            }

            onShownChanged: {
                if (win.shown) {
                    win.panelVisible = true
                    scanProc.running = true
                    Qt.callLater(() => keyCatcher.forceActiveFocus())
                } else {
                    hideTimer.restart()
                }
            }

            function saveBackend() {
                Quickshell.execDetached([
                    "bash", "-c",
                    `mkdir -p "\( HOME/.config/theme" && echo ' \){win.useAwww ? "awww" : "sway"}' > "$HOME/.config/theme/wall-backend"`
                ])
            }

            function applyCurrent() {
                if (!currentPath.length) return
                const p = currentPath

                if (win.useAwww) {
                    Quickshell.execDetached([
                        "bash", "-c",
                        `pgrep -x awww-daemon >/dev/null || awww-daemon &
                         sleep 0.15
                         awww img --transition-type fade --transition-duration 0.6 '${p.replace(/'/g, "'\\''")}'`
                    ])
                } else {
                    Quickshell.execDetached([
                        "swaymsg", "output", "*", "bg", p, "fill"
                    ])
                }

                Quickshell.execDetached([
                    "bash", "-c",
                    `mkdir -p "\( HOME/.config/theme" && printf '%s\n' ' \){p.replace(/'/g, "'\\''")}' > "$HOME/.config/theme/wallpaper"`
                ])
                root.shown = false
            }

            function goNext() {
                if (!walls.length || busy) return
                busy = true
                animDir = 1
                fadeOut.restart()
            }

            function goPrev() {
                if (!walls.length || busy) return
                busy = true
                animDir = -1
                fadeOut.restart()
            }

            property int animDir: 1

            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            focusable: shown
            visible: panelVisible

            WlrLayershell.namespace: "quickshell-wallpapers"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: "#99000000"
                opacity: win.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
                MouseArea {
                    anchors.fill: parent
                    enabled: win.shown
                    onClicked: root.shown = false
                }
            }

            Rectangle {
                id: sheet
                width: Math.min(parent.width * 0.72, 900)
                height: Math.min(parent.height * 0.70, 540)
                anchors.centerIn: parent
                radius: 22
                color: Qt.rgba(0.12, 0.12, 0.18, 0.96)
                border.width: 2
                border.color: win.accent

                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.92
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Wallpapers"
                            color: win.fg
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 28
                            radius: 8
                            color: win.surface
                            border.width: 1
                            border.color: win.useAwww ? win.accent : "#3e394c"
                            implicitWidth: backendLabel.implicitWidth + 20

                            Text {
                                id: backendLabel
                                anchors.centerIn: parent
                                text: win.useAwww ? "awww" : "sway"
                                color: win.useAwww ? win.accent : win.muted
                                font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    win.useAwww = !win.useAwww
                                    win.saveBackend()
                                }
                            }
                        }

                        Text {
                            text: walls.length ? `${index + 1} / ${walls.length}` : "empty"
                            color: win.muted
                            font.pixelSize: 12
                        }
                        Text {
                            text: "󰅖"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 18
                            color: win.muted
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.shown = false
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Image {
                            id: srcImg
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: false
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            source: currentPath ? "file://" + currentPath : ""
                        }

                        Rectangle {
                            id: roundMask
                            anchors.fill: srcImg
                            radius: 18
                            visible: false
                        }

                        OpacityMask {
                            id: masked
                            anchors.fill: srcImg
                            source: srcImg
                            maskSource: roundMask
                            opacity: 1
                            x: 0

                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: "transparent"
                                border.width: 2
                                border.color: win.accent
                            }
                        }

                        Text {
                            anchors.left: masked.left
                            anchors.bottom: masked.bottom
                            anchors.margins: 14
                            color: win.fg
                            font.pixelSize: 12
                            style: Text.Outline
                            styleColor: "#80000000"
                            text: currentPath ? currentPath.split("/").pop() : "No images in \~/Изображения/Wallpapers"
                        }

                        SequentialAnimation {
                            id: fadeOut
                            NumberAnimation {
                                target: masked
                                property: "opacity"
                                to: 0
                                duration: 120
                            }
                            NumberAnimation {
                                target: masked
                                property: "x"
                                to: win.animDir * -40
                                duration: 1
                            }
                            ScriptAction {
                                script: {
                                    if (win.animDir > 0)
                                        win.index = (win.index + 1) % win.walls.length
                                    else
                                        win.index = (win.index - 1 + win.walls.length) % win.walls.length
                                    masked.x = win.animDir * 40
                                }
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: masked
                                    property: "opacity"
                                    to: 1
                                    duration: 160
                                }
                                NumberAnimation {
                                    target: masked
                                    property: "x"
                                    to: 0
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                            ScriptAction { script: win.busy = false }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 12
                            color: win.surface
                            Text { anchors.centerIn: parent; text: "← Prev"; color: win.fg; font.pixelSize: 13 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.goPrev()
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 12
                            color: win.accent
                            Text {
                                anchors.centerIn: parent
                                text: "Apply  ↵"
                                color: "#1e1e2e"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.applyCurrent()
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 12
                            color: win.surface
                            Text { anchors.centerIn: parent; text: "Next →"; color: win.fg; font.pixelSize: 13 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.goNext()
                            }
                        }
                    }
                }

                Item {
                    id: keyCatcher
                    anchors.fill: parent
                    focus: win.shown
                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Escape) { root.shown = false; e.accepted = true }
                        else if (e.key === Qt.Key_Right) { win.goNext(); e.accepted = true }
                        else if (e.key === Qt.Key_Left) { win.goPrev(); e.accepted = true }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            win.applyCurrent(); e.accepted = true
                        }
                    }
                }
            }

            Process {
                id: scanProc
                command: ["bash", "-c", `
dir="$HOME/Изображения/Wallpapers"
[ -d "$dir" ] || dir="$HOME/Pictures/Wallpapers"
[ -d "$dir" ] || dir="$HOME/Wallpapers"
find "$dir" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | sort
`]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        win.walls = text.trim().split("\n").filter(l => l.length)
                        if (win.index >= win.walls.length)
                            win.index = 0
                    }
                }
            }
        }
    }
}

