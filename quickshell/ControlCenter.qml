// ControlCenter.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
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
    property string activePanel: ""
    property string sidePanelId: ""  
    property string autoEditOld: ""
    property string powerProfile: "balanced"

    readonly property string autoScript: `${Quickshell.env("HOME")}/.config/quickshell/scripts/autostart.sh`

    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }

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

    Timer {
        id: hideTimer
        interval: 450
        onTriggered: if (!root.shown) root.panelVisible = false
    }

    onShownChanged: {
        if (root.shown) {
            root.panelVisible = true
            profileProc.running = true
            notifProc.running = true
        } else {
            root.activePanel = ""
            root.sidePanelId = ""
            root.autoEditOld = ""
            hideTimer.restart()
        }
    }

    onActivePanelChanged: {
        if (root.activePanel === "") {
            sideHideTimer.restart()
        } else {
            sideHideTimer.stop()
            if (root.sidePanelId !== "" && root.sidePanelId !== root.activePanel) {
                sideSwitchTimer.restart()
            } else {
                root.sidePanelId = root.activePanel
            }
        }
    }

    Timer {
        id: sideHideTimer
        interval: 220
        onTriggered: if (root.activePanel === "") root.sidePanelId = ""
    }

    Timer {
        id: sideSwitchTimer
        interval: 180
        onTriggered: root.sidePanelId = root.activePanel
    }

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { root.shown = !root.shown }
        function open(): void   { root.shown = true }
        function close(): void  { root.shown = false }
    }

    function startLock() {
        root.shown = false
        Quickshell.execDetached(["hyprlock"])
    }

    function reloadAutostart() {
        reloadAutoTimer.restart()
    }

    Timer {
        id: reloadAutoTimer
        interval: 300
        onTriggered: {
            autoProc.running = false
            autoProc.running = true
        }
    }

    function autoCommit() {
        const t = autoInput.text.trim()
        if (!t.length) return
        if (root.autoEditOld !== "") {
            Quickshell.execDetached(["bash", root.autoScript, "edit", root.autoEditOld, t])
            root.autoEditOld = ""
        } else {
            Quickshell.execDetached(["bash", root.autoScript, "add", t])
        }
        autoInput.text = ""
        root.reloadAutostart()
        Qt.callLater(() => Quickshell.execDetached(["swaymsg", "reload"]))
    }

    function parseNotifs(raw) {
        raw = (raw || "").trim()
        if (!raw) {
            notifList.model = []
            return
        }
        if (raw.startsWith("[") || raw.startsWith("{")) {
            try {
                let data = JSON.parse(raw)
                if (!Array.isArray(data)) {
                    data = Object.keys(data).map(k => {
                        const n = data[k] || {}
                        return {
                            id: n.id || k,
                            app: n["app-name"] || n.app_name || n.application || "",
                            summary: n.summary || n.title || "",
                            body: n.body || n.content || ""
                        }
                    })
                } else {
                    data = data.map(n => ({
                        id: n.id || "",
                        app: n["app-name"] || n.app_name || n.application || "",
                        summary: n.summary || n.title || "",
                        body: n.body || ""
                    }))
                }
                notifList.model = data.reverse()
                return
            } catch (e) {}
        }
        const items = []
        for (const line of raw.split("\n")) {
            const s = line.trim()
            if (!s) continue
            items.push({ id: "", app: "", summary: s.substring(0, 90), body: "" })
        }
        notifList.model = items
    }

    anchors { top: true; right: true; bottom: true }
    margins { top: 12; right: 0; bottom: 12 }

    implicitWidth: 680
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: root.shown
    visible: root.panelVisible

    WlrLayershell.namespace: "quickshell-control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ════════ MAIN ════════
    Item {
        id: panel
        width: 330
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        enabled: root.shown

        x: root.shown ? 0 : width + 80
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.97

        Behavior on x {
            NumberAnimation {
                duration: 420
                easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on opacity { NumberAnimation { duration: 280 } }
        Behavior on scale   { NumberAnimation { duration: 300 } }

        Rectangle {
            anchors.fill: parent
            color: root.bg
            radius: 18
            Rectangle {
                width: 22
                height: parent.height
                anchors.right: parent.right
                color: root.bg
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 1.0
            shadowHorizontalOffset: -6
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "Control Center"
                color: root.fg
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            GridLayout {
                columns: 2
                rowSpacing: 10
                columnSpacing: 10
                Layout.fillWidth: true

                Repeater {
                    model: [
                        { id: "wifi",  icon: "󰤨", label: "Wi-Fi" },
                        { id: "bt",    icon: "󰂯", label: "Bluetooth" },
                        { id: "color", icon: "󰉼", label: "Colors" },
                        { id: "power", icon: "󰐥", label: "Power" },
                        { id: "auto",  icon: "󰑓", label: "Autostart" },
                        { id: "lock",  icon: "󰌾", label: "Lock" }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 58
                        radius: 14
                        color: modelData.id === "lock"
                               ? root.surface
                               : (root.activePanel === modelData.id ? root.accent : root.surface)
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 20
                                color: (modelData.id !== "lock" && root.activePanel === modelData.id)
                                       ? root.bg : root.fg
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: 11
                                color: root.muted
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.id === "lock")
                                    root.startLock()
                                else
                                    root.activePanel = root.activePanel === modelData.id ? "" : modelData.id
                            }
                        }
                    }
                }
            }

            // Volume
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                RowLayout {
                    Text { text: "󰕾"; font.family: "Symbols Nerd Font"; font.pixelSize: 15; color: root.fg }
                    Text { text: "Volume"; color: root.muted; font.pixelSize: 12; Layout.fillWidth: true }
                    Text {
                        text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                        color: root.fg; font.pixelSize: 12
                    }
                }
                Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    from: 0; to: 1; stepSize: 0.01; live: true
                    value: Pipewire.defaultAudioSink?.audio?.volume ?? 0.5
                    onMoved: if (Pipewire.defaultAudioSink?.audio)
                        Pipewire.defaultAudioSink.audio.volume = value
                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - 4
                        width: volumeSlider.availableWidth; height: 8; radius: 4; color: root.surface
                        Rectangle { width: volumeSlider.visualPosition * parent.width; height: 8; radius: 4; color: root.accent }
                    }
                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - 22)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - 11
                        width: 22; height: 22; radius: 11; color: root.fg
                    }
                }
            }

            // Brightness
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                RowLayout {
                    Text { text: "󰃟"; font.family: "Symbols Nerd Font"; font.pixelSize: 15; color: root.fg }
                    Text { text: "Brightness"; color: root.muted; font.pixelSize: 12; Layout.fillWidth: true }
                    Text { text: Math.round(brightnessSlider.value) + "%"; color: root.fg; font.pixelSize: 12 }
                }
                Slider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    from: 5; to: 100; stepSize: 1; value: 70; live: true
                    onMoved: Quickshell.execDetached(["brightnessctl", "set", Math.round(value) + "%"])
                    background: Rectangle {
                        x: brightnessSlider.leftPadding
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - 4
                        width: brightnessSlider.availableWidth; height: 8; radius: 4; color: root.surface
                        Rectangle { width: brightnessSlider.visualPosition * parent.width; height: 8; radius: 4; color: root.accent }
                    }
                    handle: Rectangle {
                        x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - 22)
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - 11
                        width: 22; height: 22; radius: 11; color: root.fg
                    }
                }
            }

            // Performance
            Text { text: "Performance"; color: root.muted; font.pixelSize: 12 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [
                        { name: "Power", icon: "󰌪", profile: "power-saver" },
                        { name: "Balanced", icon: "󰊚", profile: "balanced" },
                        { name: "Perf", icon: "󰓅", profile: "performance" }
                    ]
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 12
                        color: root.powerProfile === modelData.profile ? root.accent : root.surface
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: modelData.icon
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                color: root.powerProfile === modelData.profile ? root.bg : root.fg
                            }
                            Text {
                                text: modelData.name
                                font.pixelSize: 11
                                color: root.powerProfile === modelData.profile ? root.bg : root.fg
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["powerprofilesctl", "set", modelData.profile])
                                root.powerProfile = modelData.profile
                                Qt.callLater(() => {
                                    profileProc.running = false
                                    profileProc.running = true
                                })
                            }
                        }
                    }
                }
            }

            Process {
                id: profileProc
                command: ["powerprofilesctl", "get"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        const p = text.trim()
                        if (p.length) root.powerProfile = p
                    }
                }
            }

            Timer {
                interval: 2500
                running: root.shown
                repeat: true
                onTriggered: {
                    profileProc.running = false
                    profileProc.running = true
                }
            }

            // Notifications
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Notifications"
                    color: root.muted
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                Text {
                    text: "Clear"
                    color: root.accent
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["makoctl", "dismiss", "-a"])
                            notifReload.restart()
                        }
                    }
                }
            }

            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 100
                clip: true
                spacing: 6
                model: []

                delegate: Rectangle {
                    required property var modelData
                    width: notifList.width
                    height: Math.max(48, nCol.implicitHeight + 14)
                    radius: 12
                    color: root.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        ColumnLayout {
                            id: nCol
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.app || "Notification"
                                color: root.accent
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text.length > 0
                            }
                            Text {
                                text: modelData.summary || ""
                                color: root.fg
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.body || ""
                                color: root.muted
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                Layout.fillWidth: true
                                visible: text.length > 0
                            }
                        }

                        Text {
                            text: "󰅖"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 15
                            color: root.muted
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.id)
                                        Quickshell.execDetached(["makoctl", "dismiss", "-n", String(modelData.id)])
                                    else
                                        Quickshell.execDetached(["makoctl", "dismiss"])
                                    notifReload.restart()
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: notifList.count === 0
                    text: "No notifications"
                    color: root.muted
                    font.pixelSize: 12
                }
            }

            Process {
                id: notifProc
                command: ["bash", "-c", "makoctl list -j 2>/dev/null || makoctl list 2>/dev/null"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: root.parseNotifs(text)
                }
            }

            Timer {
                id: notifReload
                interval: 400
                onTriggered: {
                    notifProc.running = false
                    notifProc.running = true
                }
            }

            Timer {
                interval: 2500
                running: root.shown
                repeat: true
                onTriggered: {
                    notifProc.running = false
                    notifProc.running = true
                }
            }
        }
    }

    // ════════ SIDE  ════════
    Rectangle {
        id: sidePanel
        width: 310
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: panel.left
        anchors.rightMargin: 12
        color: root.bg
        radius: 18

        readonly property bool open: root.shown && root.sidePanelId !== ""
        enabled: open

        opacity: open ? 1 : 0
        scale: open ? 1 : 0.96
        transform: Translate {
            x: sidePanel.open ? 0 : 24
            Behavior on x {
                NumberAnimation {
                    duration: 220
                    easing.type: sidePanel.open ? Easing.OutCubic : Easing.InCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: sidePanel.open ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        visible: opacity > 0.01 || root.activePanel !== ""

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.9
            shadowHorizontalOffset: -4
        }

        // WIFI
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.sidePanelId === "wifi"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            RowLayout {
                Text { text: "Wi-Fi"; color: root.fg; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Text {
                    text: "󰑓"; font.family: "Symbols Nerd Font"; font.pixelSize: 16; color: root.muted
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiProc.running = true
                    }
                }
            }
            ListView {
                id: wifiList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: []
                delegate: Rectangle {
                    required property var modelData
                    width: wifiList.width
                    height: 46
                    radius: 12
                    color: root.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        Text {
                            text: modelData.connected ? "󰤨" : "󰤯"
                            font.family: "Symbols Nerd Font"; font.pixelSize: 17
                            color: modelData.connected ? root.accent : root.fg
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: modelData.ssid; color: root.fg; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.connected ? "Connected" : modelData.signal + "%"; color: root.muted; font.pixelSize: 11 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!modelData.connected)
                            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid])
                    }
                }
            }
            Process {
                id: wifiProc
                command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list 2>/dev/null"]
                running: root.sidePanelId === "wifi"
                stdout: StdioCollector {
                    onStreamFinished: {
                        const list = []
                        for (let line of text.trim().split("\n")) {
                            if (!line) continue
                            const p = line.split(":")
                            if (p.length >= 2 && p[1].trim() !== "")
                                list.push({ connected: p[0] === "yes", ssid: p[1], signal: p[2] || "?" })
                        }
                        wifiList.model = list
                    }
                }
            }
        }

        // BT
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.sidePanelId === "bt"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            RowLayout {
                Text { text: "Bluetooth"; color: root.fg; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Text {
                    text: "󰑓"; font.family: "Symbols Nerd Font"; font.pixelSize: 16; color: root.muted
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btProc.running = true
                    }
                }
            }
            ListView {
                id: btList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: []
                delegate: Rectangle {
                    required property var modelData
                    width: btList.width
                    height: 46
                    radius: 12
                    color: root.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        Text { text: "󰂯"; font.family: "Symbols Nerd Font"; font.pixelSize: 17; color: root.fg }
                        Text { text: modelData.name; color: root.fg; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bluetoothctl", "connect", modelData.mac])
                    }
                }
            }
            Process {
                id: btProc
                command: ["bash", "-c", "bluetoothctl devices 2>/dev/null"]
                running: root.sidePanelId === "bt"
                stdout: StdioCollector {
                    onStreamFinished: {
                        const list = []
                        for (let line of text.trim().split("\n")) {
                            const m = line.match(/Device\s+([0-9A-F:]{17})\s+(.+)/i)
                            if (m) list.push({ mac: m[1], name: m[2] })
                        }
                        btList.model = list
                    }
                }
            }
        }

        // COLORS
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            visible: root.sidePanelId === "color"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Text { text: "Accent Color"; color: root.fg; font.pixelSize: 15; font.weight: Font.DemiBold }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 86; height: 86; radius: 20
                color: Qt.rgba(
                    (rSlider.value / 255) * (valueSlider.value / 100),
                    (gSlider.value / 255) * (valueSlider.value / 100),
                    (bSlider.value / 255) * (valueSlider.value / 100), 1)
                border.color: "#3e394c"
                border.width: 2
            }

            // R G B V
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Text { text: "R"; color: "#f38ba8"; font.weight: Font.Bold }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(rSlider.value); color: root.muted }
                }
                Slider {
                    id: rSlider
                    Layout.fillWidth: true; Layout.preferredHeight: 26
                    from: 0; to: 255; stepSize: 1; value: 137; live: true
                    background: Rectangle {
                        x: rSlider.leftPadding; y: rSlider.topPadding + rSlider.availableHeight / 2 - 4
                        width: rSlider.availableWidth; height: 8; radius: 4; color: root.surface
                        Rectangle { width: rSlider.visualPosition * parent.width; height: 8; radius: 4; color: "#f38ba8" }
                    }
                    handle: Rectangle {
                        x: rSlider.leftPadding + rSlider.visualPosition * (rSlider.availableWidth - 22)
                        y: rSlider.topPadding + rSlider.availableHeight / 2 - 11
                        width: 22; height: 22; radius: 11; color: root.fg
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Text { text: "G"; color: "#a6e3a1"; font.weight: Font.Bold }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(gSlider.value); color: root.muted }
                }
                Slider {
                    id: gSlider
                    Layout.fillWidth: true; Layout.preferredHeight: 26
                    from: 0; to: 255; stepSize: 1; value: 180; live: true
                    background: Rectangle {
                        x: gSlider.leftPadding; y: gSlider.topPadding + gSlider.availableHeight / 2 - 4
                        width: gSlider.availableWidth; height: 8; radius: 4; color: root.surface
                        Rectangle { width: gSlider.visualPosition * parent.width; height: 8; radius: 4; color: "#a6e3a1" }
                    }
                    handle: Rectangle {
                        x: gSlider.leftPadding + gSlider.visualPosition * (gSlider.availableWidth - 22)
                        y: gSlider.topPadding + gSlider.availableHeight / 2 - 11
                        width: 22; height: 22; radius: 11; color: root.fg
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Text { text: "B"; color: "#89b4fa"; font.weight: Font.Bold }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(bSlider.value); color: root.muted }
                }
                Slider {
                    id: bSlider
                    Layout.fillWidth: true; Layout.preferredHeight: 26
                    from: 0; to: 255; stepSize: 1; value: 250; live: true
                    background: Rectangle {
                        x: bSlider.leftPadding; y: bSlider.topPadding + bSlider.availableHeight / 2 - 4
                        width: bSlider.availableWidth; height: 8; radius: 4; color: root.surface
                        Rectangle { width: bSlider.visualPosition * parent.width; height: 8; radius: 4; color: "#89b4fa" }
                    }
                    handle: Rectangle {
                        x: bSlider.leftPadding + bSlider.visualPosition * (bSlider.availableWidth - 22)
                        y: bSlider.topPadding + bSlider.availableHeight / 2 - 11
                        width: 22; height: 22; radius: 11; color: root.fg
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Text { text: "V"; color: root.fg; font.weight: Font.Bold }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(valueSlider.value) + "%"; color: root.muted }
                }
                Slider {
                    id: valueSlider
                    Layout.fillWidth: true; Layout.preferredHeight: 26
                    from: 10; to: 100; stepSize: 1; value: 100; live: true
                    background: Rectangle {
                        x: valueSlider.leftPadding; y: valueSlider.topPadding + valueSlider.availableHeight / 2 - 4
                        width: valueSlider.availableWidth; height: 8; radius: 4; color: root.surface
                        Rectangle { width: valueSlider.visualPosition * parent.width; height: 8; radius: 4; color: root.fg }
                    }
                    handle: Rectangle {
                        x: valueSlider.leftPadding + valueSlider.visualPosition * (valueSlider.availableWidth - 22)
                        y: valueSlider.topPadding + valueSlider.availableHeight / 2 - 11
                        width: 22; height: 22; radius: 11; color: root.fg
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 14
                color: root.accent
                Text {
                    anchors.centerIn: parent
                    text: "Apply Color"
                    color: root.bg
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const factor = valueSlider.value / 100
                        const r = Math.min(255, Math.round(rSlider.value * factor))
                        const g = Math.min(255, Math.round(gSlider.value * factor))
                        const b = Math.min(255, Math.round(bSlider.value * factor))
                        const hex = "#" +
                            r.toString(16).padStart(2, "0") +
                            g.toString(16).padStart(2, "0") +
                            b.toString(16).padStart(2, "0")
                        root.accent = hex
                        Quickshell.execDetached(["bash", "-c", `
color='${hex}'
mkdir -p "$HOME/.config/theme"
echo "$color" > "$HOME/.config/theme/accent"
MAKO="$HOME/.config/mako/config"
ROFI_THEME="$HOME/.config/rofi/themes/nord-me.rasi"
[ -f "$MAKO" ] && sed -i -e "s|^border-color=.*|border-color=$color|" "$MAKO" && makoctl reload 2>/dev/null || true
[ -f "$ROFI_THEME" ] && sed -i "s/accent: #[0-9a-fA-F]\\{6\\}/accent: $color/" "$ROFI_THEME"

notify-send "Accent" "$color"
`])
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // POWER
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.sidePanelId === "power"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Text { text: "Power"; color: root.fg; font.pixelSize: 15; font.weight: Font.DemiBold }
            Repeater {
                model: [
                    { name: "Lock", icon: "󰌾", act: "lock" },
                    { name: "Logout", icon: "󰍃", cmd: "swaymsg exit" },
                    { name: "Suspend", icon: "󰒲", cmd: "systemctl suspend" },
                    { name: "Reboot", icon: "󰜉", cmd: "systemctl reboot" },
                    { name: "Shutdown", icon: "󰐥", cmd: "systemctl poweroff" }
                ]
                Rectangle {
                    Layout.fillWidth: true
                    height: 46
                    radius: 12
                    color: root.surface
                    Row {
                        anchors.centerIn: parent
                        spacing: 12
                        Text { text: modelData.icon; font.family: "Symbols Nerd Font"; font.pixelSize: 17; color: root.fg }
                        Text { text: modelData.name; color: root.fg; font.pixelSize: 14 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.act === "lock") root.startLock()
                            else Quickshell.execDetached(["sh", "-c", modelData.cmd])
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // AUTOSTART
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.sidePanelId === "auto"
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Text { text: "Autostart"; color: root.fg; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { text: "Sway QS_AUTOSTART block"; color: root.muted; font.pixelSize: 11 }

            ListView {
                id: autoList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: []
                delegate: Rectangle {
                    required property var modelData
                    width: autoList.width
                    height: 48
                    radius: 12
                    color: root.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: root.fg
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "󰏫"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 15
                            color: root.accent
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.autoEditOld = modelData
                                    autoInput.text = modelData.replace(/^exec(_always)?\s+/, "")
                                    autoInput.forceActiveFocus()
                                }
                            }
                        }
                        Text {
                            text: "󰆴"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 15
                            color: "#f38ba8"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["bash", root.autoScript, "del", modelData])
                                    root.reloadAutostart()
                                    Qt.callLater(() => Quickshell.execDetached(["swaymsg", "reload"]))
                                }
                            }
                        }
                    }
                }
            }

            TextField {
                id: autoInput
                Layout.fillWidth: true
                color: root.fg
                placeholderText: root.autoEditOld !== "" ? "edit command…" : "new command…"
                background: Rectangle {
                    color: root.surface
                    radius: 12
                    border.color: root.borderC
                    border.width: 1
                }
                Keys.onReturnPressed: root.autoCommit()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 12
                    color: root.accent
                    Text {
                        anchors.centerIn: parent
                        text: root.autoEditOld !== "" ? "Save" : "+ Add"
                        color: root.bg
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.autoCommit()
                    }
                }
                Rectangle {
                    visible: root.autoEditOld !== ""
                    width: 40
                    height: 40
                    radius: 12
                    color: root.surface
                    Text { anchors.centerIn: parent; text: "✕"; color: root.fg }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.autoEditOld = ""
                            autoInput.text = ""
                        }
                    }
                }
            }

            Process {
                id: autoProc
                command: ["bash", root.autoScript, "list"]
                running: root.sidePanelId === "auto"
                stdout: StdioCollector {
                    onStreamFinished: {
                        const raw = text.trim()
                        if (!raw || raw === "NO_CONFIG") {
                            autoList.model = []
                            return
                        }
                        autoList.model = raw.split("\n").filter(l => l.trim().length)
                    }
                }
            }
        }
    }
}
