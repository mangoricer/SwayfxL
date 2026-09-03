// Launcher.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property color bg:      "#1e1e2e"
    property color fg:      "#cdd6f4"
    property color accent:  "#89b4fa"
    property color muted:   "#6c7086"
    property color surface: "#313244"
    property color borderC: "#3e394c"

    property bool shown: false
    property bool panelVisible: false

    property var allApps: []
    property var filtered: []
    property int selected: 0

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

    Timer {
        id: hideTimer
        interval: 320
        onTriggered: if (!root.shown) root.panelVisible = false
    }

    onShownChanged: {
        if (root.shown) {
            root.panelVisible = true
            if (!root.allApps.length)
                appsProc.running = true
            else
                root.applyFilter("")
            root.selected = 0
            Qt.callLater(() => {
                searchField.text = ""
                searchField.forceActiveFocus()
            })
        } else {
            hideTimer.restart()
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.shown = !root.shown }
        function open(): void   { root.shown = true }
        function close(): void  { root.shown = false }
    }

    function applyFilter(q) {
        q = (q || "").trim().toLowerCase()
        const list = []
        const isCmd = q.startsWith(">") || q.startsWith("!")

        if (isCmd) {
            const cmd = searchField.text.trim().replace(/^[>!]\s*/, "")
            if (cmd.length) {
                list.push({
                    name: "Run: " + cmd,
                    exec: cmd,
                    terminal: false,
                    generic: "shell",
                    icon: "",
                    raw: true
                })
            }
        }

        for (let i = 0; i < root.allApps.length; i++) {
            const a = root.allApps[i]
            if (!q || isCmd) {
                if (!isCmd) {
                    list.push(a)
                } else {
                    const qq = q.slice(1)
                    if (a.name.toLowerCase().indexOf(qq) !== -1
                        || (a.generic && a.generic.toLowerCase().indexOf(qq) !== -1))
                        list.push(a)
                }
            } else if (a.name.toLowerCase().indexOf(q) !== -1
                    || (a.generic && a.generic.toLowerCase().indexOf(q) !== -1)
                    || a.exec.toLowerCase().indexOf(q) !== -1) {
                list.push(a)
            }
            if (list.length >= 40) break
        }

        if (!list.length && q.length && !isCmd) {
            list.push({
                name: "Run: " + searchField.text.trim(),
                exec: searchField.text.trim(),
                terminal: false,
                generic: "shell",
                icon: "",
                raw: true
            })
        }

        root.filtered = list
        root.selected = 0
        listView.positionViewAtIndex(0, ListView.Beginning)
    }

    function launchSelected() {
        if (!root.filtered.length) return
        const item = root.filtered[root.selected]
        if (!item) return

        let cmd = (item.exec || "").replace(/%[a-zA-Z]/g, "").trim()
        root.shown = false

        if (item.raw || item.generic === "shell") {
            Quickshell.execDetached(["bash", "-lc", cmd])
            return
        }
        if (item.terminal) {
            const safe = cmd.replace(/'/g, "'\\''")
            Quickshell.execDetached([
                "bash", "-lc",
                `kitty -e bash -lc '\( {safe}' 2>/dev/null || foot bash -lc ' \){safe}' 2>/dev/null || ${cmd}`
            ])
            return
        }
        Quickshell.execDetached(["bash", "-lc", cmd])
    }

    anchors { left: true; right: true; bottom: true }
    margins { bottom: 28 }
    implicitHeight: 420
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: root.shown
    visible: root.panelVisible

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: root.shown = false
    }

    Item {
        id: panel
        width: Math.min(560, parent.width - 40)
        height: 400
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        enabled: root.shown

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        transform: Translate {
            y: root.shown ? 0 : 80
            Behavior on y {
                NumberAnimation {
                    duration: 320
                    easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 260
                easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Qt.rgba(0.118, 0.118, 0.180, 0.96)
            border.width: 2
            border.color: root.accent
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // search
            Rectangle {
                Layout.fillWidth: true
                height: 46
                radius: 12
                color: root.surface
                border.width: 1
                border.color: searchField.activeFocus ? root.accent : root.borderC

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "󰍉"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: root.accent
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: root.fg
                        font.pixelSize: 14
                        clip: true
                        focus: true
                        onTextChanged: root.applyFilter(text)

                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Escape) {
                                root.shown = false
                                e.accepted = true
                            } else if (e.key === Qt.Key_Down) {
                                if (root.selected < root.filtered.length - 1)
                                    root.selected++
                                listView.positionViewAtIndex(root.selected, ListView.Contain)
                                e.accepted = true
                            } else if (e.key === Qt.Key_Up) {
                                if (root.selected > 0)
                                    root.selected--
                                listView.positionViewAtIndex(root.selected, ListView.Contain)
                                e.accepted = true
                            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                root.launchSelected()
                                e.accepted = true
                            } else if (e.key === Qt.Key_Tab) {
                                if (root.selected < root.filtered.length - 1)
                                    root.selected++
                                else
                                    root.selected = 0
                                listView.positionViewAtIndex(root.selected, ListView.Contain)
                                e.accepted = true
                            }
                        }
                    }
                }
            }

            // list
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filtered
                currentIndex: root.selected
                highlightMoveDuration: 120

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: listView.width
                    height: 48
                    radius: 10
                    color: index === root.selected ? root.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            width: 32
                            height: 32
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: index === root.selected
                                       ? Qt.rgba(0, 0, 0, 0.15)
                                       : root.surface
                                visible: !(modelData.icon && modelData.icon.length)
                            }

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                anchors.margins: 1
                                source: modelData.icon && modelData.icon.length
                                        ? "file://" + modelData.icon
                                        : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: modelData.raw ? "󰆍" : (modelData.terminal ? "󰆍" : "󰀻")
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: index === root.selected ? root.bg : root.fg
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: modelData.name
                                color: index === root.selected ? root.bg : root.fg
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.generic || modelData.exec
                                color: index === root.selected
                                       ? Qt.rgba(0.1, 0.1, 0.14, 0.85)
                                       : root.muted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selected = index
                        onClicked: {
                            root.selected = index
                            root.launchSelected()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    text: "Nothing found"
                    color: root.muted
                    font.pixelSize: 13
                }
            }
        }
    }

    Process {
        id: appsProc
        command: ["bash", "-c", `
resolve_icon() {
  local icon="$1"
  [ -z "$icon" ] && return
  if [ -f "$icon" ]; then echo "$icon"; return; fi
  if [ -f "/usr/share/pixmaps/$icon" ]; then echo "/usr/share/pixmaps/$icon"; return; fi
  for ext in png svg xpm; do
    if [ -f "/usr/share/pixmaps/$icon.$ext" ]; then echo "/usr/share/pixmaps/$icon.$ext"; return; fi
  done
  for theme in hicolor Papirus Papirus-Dark Adwaita breeze breeze-dark; do
    for size in 48x48 64x64 32x32 128x128 scalable; do
      for appdir in apps categories places status devices; do
        for ext in png svg; do
          p="/usr/share/icons/$theme/$size/$appdir/$icon.$ext"
          [ -f "$p" ] && echo "$p" && return
          p="$HOME/.local/share/icons/$theme/$size/$appdir/$icon.$ext"
          [ -f "$p" ] && echo "$p" && return
        done
      done
    done
  done
  f=$(find /usr/share/icons/hicolor/48x48 /usr/share/icons/hicolor/64x64 /usr/share/pixmaps \
      "$HOME/.local/share/icons" -type f \\( -name "$icon.png" -o -name "$icon.svg" \\) 2>/dev/null | head -n1)
  [ -n "$f" ] && echo "$f"
}

dirs="$HOME/.local/share/applications:/usr/share/applications:/usr/local/share/applications"
IFS=':'
for d in $dirs; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 2 -type f -name '*.desktop' 2>/dev/null
done | while read -r f; do
  grep -q '^NoDisplay=true' "$f" 2>/dev/null && continue
  grep -q '^Hidden=true' "$f" 2>/dev/null && continue
  name=$(grep -m1 '^Name=' "$f" 2>/dev/null | sed 's/^Name=//')
  exec=$(grep -m1 '^Exec=' "$f" 2>/dev/null | sed 's/^Exec=//')
  gen=$(grep -m1 '^GenericName=' "$f" 2>/dev/null | sed 's/^GenericName=//')
  term=$(grep -m1 '^Terminal=' "$f" 2>/dev/null | sed 's/^Terminal=//')
  icon=$(grep -m1 '^Icon=' "$f" 2>/dev/null | sed 's/^Icon=//')
  [ -z "$name" ] || [ -z "$exec" ] && continue
  icon_path=$(resolve_icon "$icon")
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$exec" "$term" "$gen" "$icon_path"
done | sort -u -t "$(printf '\t')" -k1,1
`]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length)
                const apps = []
                for (const line of lines) {
                    const p = line.split("\t")
                    if (p.length < 2) continue
                    apps.push({
                        name: p[0],
                        exec: p[1],
                        terminal: (p[2] || "").toLowerCase() === "true",
                        generic: p[3] || "",
                        icon: (p[4] || "").trim(),
                        raw: false
                    })
                }
                root.allApps = apps
                root.applyFilter(searchField.text)
            }
        }
    }
}