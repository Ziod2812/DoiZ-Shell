import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "services"
import "components"

PanelWindow {
    id: root

    property real glassA: 1.0
    property color panelColor: Qt.rgba(basePanelColor.r, basePanelColor.g, basePanelColor.b, Math.min(basePanelColor.a, root.glassA))
    property color cardColor: Qt.rgba(baseCardColor.r, baseCardColor.g, baseCardColor.b, Math.min(baseCardColor.a, root.glassA))
    property color hoverColor: Qt.rgba(baseHoverColor.r, baseHoverColor.g, baseHoverColor.b, Math.min(baseHoverColor.a, root.glassA))

    FileView {
        id: doizGlassFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/mycfg/bar-glass"
        onLoaded: {
            var l = text().split("\n")
            var p = parseFloat(l[1])
            if (isNaN(p)) p = 50
            root.glassA = l[0].trim() === "on" ? Math.max(0.2, Math.min(1, p / 100)) : 1.0
        }
        onLoadFailed: root.glassA = 1.0
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: doizGlassFile.reload()
    }

    property bool open: true
    property int mode: 0

    property real introP: 0
    property real introS: 0
    property real stagP: 0
    property real outP: 0
    property real tabP: 1
    property int tabDir: 1
    property double lastChange: 0
    property bool launching: false
    property bool lingering: false

    function seg(i) {
        return Math.max(0, Math.min(1, (root.stagP - i * 0.09) / 0.5))
    }

    function playIntro() {
        outAnim.stop()
        root.lingering = false
        root.launching = false
        root.outP = 0
        root.introP = 0
        root.introS = 0
        root.stagP = 0
        introAnim.restart()
        introScaleAnim.restart()
        stagAnim.restart()
    }

    function launch() {
        root.launching = true
        root.close()
    }

    NumberAnimation { id: introAnim; target: root; property: "introP"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { id: introScaleAnim; target: root; property: "introS"; from: 0; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    NumberAnimation { id: stagAnim; target: root; property: "stagP"; from: 0; to: 1; duration: 520 }
    NumberAnimation { id: outAnim; target: root; property: "outP"; from: 0; to: 1; duration: 190; easing.type: Easing.InOutCubic; onStopped: { if (!root.open && root.outP >= 1) root.lingering = false } }
    NumberAnimation { id: tabAnim; target: root; property: "tabP"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }

    property string query: ""
    property int selectedIndex: 0
    readonly property int panelW: 720
    readonly property int panelH: 560

    property color basePanelColor: Theme.background
    property color baseCardColor: Theme.surface
    property color baseHoverColor: Theme.selected
    property color lineColor: Theme.border
    property color titleColor: Theme.foreground
    property color textColor: Theme.subtext
    property color mutedColor: Theme.muted
    property color accentColor: Theme.accent
    property color infoColor: Theme.blue
    property color warningColor: Theme.yellow
    property color connectedColor: Theme.green
    property string fontName: Theme.fontFamily

    visible: true
    mask: (root.open || root.lingering) ? null : emptyMask

    Region {
        id: emptyMask
    }
    focusable: true
    aboveWindows: true

    screen:
        Quickshell.screens.length > 0
        ? Quickshell.screens[0]
        : null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer:
        WlrLayer.Overlay

    WlrLayershell.keyboardFocus:
        root.open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    WlrLayershell.namespace:
        "doiz-launcher"

    AppService {
        id: appService
    }

    RunService {
        id: runService
    }

    WindowService {
        id: windowService
    }

    function tint(c, alpha) {
        return Qt.rgba(
            c.r,
            c.g,
            c.b,
            alpha
        )
    }

    function score(text, q) {
        text = String(
            text || ""
        ).toLowerCase()

        q = String(
            q || ""
        ).toLowerCase()

        if (!q)
            return 0

        var pos = 0
        var gaps = 0

        for (
            var i = 0;
            i < q.length;
            i++
        ) {
            var found =
                text.indexOf(
                    q[i],
                    pos
                )

            if (found < 0)
                return -1

            gaps += found - pos
            pos = found + 1
        }

        var exact =
            text.indexOf(q)

        var prefix =
            exact === 0
            ? 120
            : 0

        return 1000
            - gaps
            - text.length * 0.15
            + prefix
            - (exact < 0 ? 20 : 0)
    }

    function ranked(source, builder) {
        var q =
            root.query
            .trim()
            .toLowerCase()

        var result = []

        if (!source)
            return result

        for (
            var i = 0;
            i < source.length;
            i++
        ) {
            var item =
                source[i]

            var text =
                builder(item)

            var value =
                root.score(
                    text,
                    q
                )

            if (
                !q ||
                value >= 0
            ) {
                result.push({
                    item: item,
                    score: value
                })
            }
        }

        result.sort(
            function(a, b) {
                if (
                    b.score !==
                    a.score
                ) {
                    return (
                        b.score -
                        a.score
                    )
                }

                return builder(
                    a.item
                ).localeCompare(
                    builder(
                        b.item
                    ),
                    undefined,
                    {
                        sensitivity:
                            "base"
                    }
                )
            }
        )

        return result.map(
            function(entry) {
                return entry.item
            }
        )
    }

    function filteredApps() {
        return root.ranked(
            appService.applications || [],
            function(app) {
                return String(
                    app.name || ""
                )
                    + " "
                    + String(
                        app.genericName || ""
                    )
                    + " "
                    + String(
                        app.comment || ""
                    )
                    + " "
                    + String(
                        app.id || ""
                    )
            }
        )
    }

    function filteredRuns() {
        return root.ranked(
            runService.commands || [],
            function(command) {
                return String(
                    command || ""
                )
            }
        )
    }

    function filteredWindows() {
        return root.ranked(
            windowService.windows || [],
            function(item) {
                if (!item)
                    return ""

                return String(
                    item.title || ""
                )
                    + " "
                    + String(
                        item.appId || ""
                    )
            }
        )
    }

    function currentItems() {
        if (root.mode === 0)
            return root.filteredApps()

        if (root.mode === 1)
            return root.filteredRuns()

        if (root.mode === 2)
            return root.filteredWindows()

        return []
    }

    function resetSearch() {
        root.query = ""
        root.selectedIndex = 0

        if (
            search &&
            search.input
        ) {
            search.input.text = ""
            search.input.forceActiveFocus()
        }
    }

    function setMode(value, dir) {
        var nextMode =
            Number(value)

        if (!isFinite(nextMode))
            nextMode = 0

        nextMode =
            Math.max(
                0,
                Math.min(
                    2,
                    Math.floor(
                        nextMode
                    )
                )
            )

        if (nextMode !== root.mode) {
            root.tabDir = dir !== undefined ? dir : (nextMode > root.mode ? 1 : -1)
            tabAnim.restart()
        }

        root.mode =
            nextMode

        root.resetSearch()

        if (root.mode === 1)
            runService.refresh()

        if (root.mode === 2)
            windowService.refresh()
    }

    function close() {
        if (!root.open)
            return

        root.lastChange = Date.now()
        introAnim.stop()
        introScaleAnim.stop()
        stagAnim.stop()
        tabAnim.stop()
        root.tabP = 1
        root.open = false
        root.lingering = true
        outAnim.restart()
    }

    function show() {
        var wasShown = root.open && root.outP === 0 && root.introP >= 1

        root.lastChange = Date.now()
        root.open = true

        if (!wasShown)
            root.playIntro()

        root.selectedIndex = 0
        root.query = ""

        if (
            search &&
            search.input
        ) {
            search.input.text = ""
            search.input.forceActiveFocus()
        }

        appService.refresh()
        runService.refresh()
        windowService.refresh()
    }

    function runCurrent() {
        if (root.mode === 0) {
            var apps =
                root.filteredApps()

            if (
                apps.length <= 0 ||
                root.selectedIndex < 0 ||
                root.selectedIndex >= apps.length
            ) {
                return
            }

            var app =
                apps[
                    root.selectedIndex
                ]

            root.launch()

            if (app)
                app.execute()

            return
        }

        if (root.mode === 1) {
            var commands =
                root.filteredRuns()

            if (
                commands.length <= 0 ||
                root.selectedIndex < 0 ||
                root.selectedIndex >= commands.length
            ) {
                return
            }

            var command =
                String(
                    commands[
                        root.selectedIndex
                    ] || ""
                )

            if (
                command.length <= 0
            ) {
                return
            }

            root.launch()

            Qt.callLater(
                function() {
                    Quickshell.execDetached(
                        [command]
                    )
                }
            )

            return
        }

        if (root.mode === 2) {
            var windows =
                root.filteredWindows()

            if (
                windows.length <= 0 ||
                root.selectedIndex < 0 ||
                root.selectedIndex >= windows.length
            ) {
                return
            }

            var windowItem =
                windows[
                    root.selectedIndex
                ]

            if (!windowItem)
                return

            root.launch()

            Qt.callLater(
                function() {
                    windowItem.activate()
                }
            )

            return
        }
    }

    function moveSelection(delta) {
        var items =
            root.currentItems()

        var count =
            items.length

        if (count <= 0) {
            root.selectedIndex = 0
            return
        }

        var next =
            root.selectedIndex +
            Number(delta)

        while (next < 0)
            next += count

        while (next >= count)
            next -= count

        root.selectedIndex =
            next
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            console.log("launcher toggle open=" + root.open + " t=" + Date.now())

            if (Date.now() - root.lastChange < 500)
                return

            if (root.open)
                root.close()
            else
                root.show()
        }

        function show(): void {
            root.show()
        }

        function hide(): void {
            root.close()
        }

        function apps(): void {
            root.mode = 0
            root.show()
        }

        function run(): void {
            root.mode = 1
            root.show()
        }

        function windows(): void {
            root.mode = 2
            root.show()
        }

        function wallpaper(): void {
            root.close()

            Quickshell.execDetached([
                "bash",
                (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
                    + "/hypr/scripts/doiz-wallpaperpicker.sh"
            ])
        }
    }

    Item {
        id: shortcutHandler

        anchors.fill: parent

        Shortcut {
            sequence: "Escape"
            enabled: root.open

            onActivated: {
                root.close()
            }
        }

        Shortcut {
            sequence: "Down"
            enabled: root.open

            onActivated: {
                root.moveSelection(1)
            }
        }

        Shortcut {
            sequence: "Up"
            enabled: root.open

            onActivated: {
                root.moveSelection(-1)
            }
        }

        Shortcut {
            sequence: "Tab"
            enabled: root.open

            onActivated: {
                root.setMode(
                    (root.mode + 1) % 3,
                    1
                )
            }
        }

        Shortcut {
            sequence: "Return"
            enabled: root.open

            onActivated: {
                root.runCurrent()
            }
        }

        Shortcut {
            sequence: "Enter"
            enabled: root.open

            onActivated: {
                root.runCurrent()
            }
        }
    }

    MouseArea {
        id: outsideMouse

        anchors.fill: parent

        visible: root.open

        onClicked: {
            var localX =
                mouse.x - panel.x

            var localY =
                mouse.y - panel.y

            if (
                localX < 0 ||
                localY < 0 ||
                localX > panel.width ||
                localY > panel.height
            ) {
                root.close()
            }
        }
    }

    Rectangle {
        id: panel
        GradBorder {
            rr: 12
            c1: root.accentColor
            c2: Qt.lighter(root.accentColor, 1.3)
            c3: root.accentColor
            c4: Qt.lighter(root.accentColor, 1.3)
            cycle: 9000
        }

        width: root.panelW
        height: root.panelH

        Behavior on width {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        anchors.centerIn: parent

        visible: root.open || (root.lingering && root.outP < 1)

        color:
            root.panelColor

        radius: 12

        border.width: 1

        border.color:
            root.tint(
                root.accentColor,
                0.35
            )

        opacity: root.introP * (1 - root.outP * root.outP)

        scale: (0.93 + 0.07 * root.introS)
               * (1 + 0.012 * Math.sin(root.tabP * Math.PI))

        transform: [
            Translate {
                y: -16 * (1 - root.introS)
            },
            Scale {
                origin.x: panel.width / 2
                origin.y: panel.height / 2
                xScale: 1 - 0.12 * root.outP
                yScale: 1 - 0.97 * root.outP
            }
        ]

        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                mouse.accepted = true
            }
        }

        Column {
            id: mainColumn

            anchors.fill: parent
            anchors.margins: 12

            spacing: 8

            Item {
                width: parent.width
                height: 40
                opacity: root.seg(0)
                transform: Translate { y: 14 * (1 - root.seg(0)) }

                Rectangle {
                    id: launcherIcon

                    anchors.left: parent.left
                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: 40
                    height: 40

                    radius: 8

                    color:
                        root.tint(
                            root.accentColor,
                            0.16
                        )

                    Text {
                        anchors.fill: parent

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            root.mode === 0
                            ? "󰀻"
                            : root.mode === 1
                                ? "󰆍"
                                : "󰖯"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 21
                    }
                }

                Column {
                    anchors.left:
                        launcherIcon.right

                    anchors.leftMargin:
                        10

                    anchors.verticalCenter:
                        parent.verticalCenter

                    spacing: 2

                    Text {
                        text: "LAUNCHER"

                        color:
                            root.titleColor

                        font.family:
                            root.fontName

                        font.pixelSize: 13

                        font.weight:
                            Font.Bold
                    }

                    Text {
                        text:
                            root.mode === 0
                            ? "Applications"
                            : root.mode === 1
                                ? "Run command"
                                : "Windows"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.DemiBold
                    }
                }

                Rectangle {
                    anchors.right:
                        parent.right

                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: 54
                    height: 40

                    radius: 8

                    color:
                        root.cardColor

                    Text {
                        anchors.fill: parent

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            root.mode === 0
                            ? "APPS"
                            : root.mode === 1
                                ? "RUN"
                                : "WIN"

                        color:
                            root.textColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.Bold
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1

                color:
                    root.lineColor
            }

            SearchBar {
                id: search

                width: parent.width
                opacity: root.seg(1)
                transform: Translate { y: 14 * (1 - root.seg(1)) }

                onAccepted: {
                    root.runCurrent()
                }

                onTextChanged: {
                    root.query = text
                    root.selectedIndex = 0
                }
            }

            ModeSwitcher {
                width: parent.width
                opacity: root.seg(2)
                transform: Translate { y: 14 * (1 - root.seg(2)) }

                currentMode:
                    root.mode

                onModeSelected:
                    function(mode) {
                        root.setMode(mode)
                    }
            }

            Rectangle {
                width: parent.width
                height: 1

                color:
                    root.lineColor
            }

            Item {
                id: contentArea

                width: parent.width

                height:
                    parent.height
                    - search.height
                    - 141

                clip: true

                opacity: root.seg(3) * (0.25 + 0.75 * root.tabP)
                transform: Translate {
                    y: 14 * (1 - root.seg(3))
                    x: root.tabDir * 32 * (1 - root.tabP)
                }

                ListView {
                    id: appsList

                    anchors.fill: parent

                    visible:
                        root.mode === 0

                    clip: true

                    spacing: 5

                    currentIndex:
                        root.selectedIndex

                    model:
                        root.filteredApps()

                    delegate: AppItem {
                        width:
                            appsList.width

                        app:
                            modelData

                        selected:
                            index ===
                            root.selectedIndex

                        onTriggered: {
                            root.selectedIndex =
                                index

                            root.runCurrent()
                        }
                    }

                    ScrollBar.vertical:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded

                            contentItem:
                                Rectangle {
                                    implicitWidth: 3
                                    radius: 2

                                    color:
                                        root.accentColor

                                    opacity: 0.55
                                }
                        }
                }

                ListView {
                    id: runList

                    anchors.fill: parent

                    visible:
                        root.mode === 1

                    clip: true

                    spacing: 5

                    currentIndex:
                        root.selectedIndex

                    model:
                        root.filteredRuns()

                    delegate: RunItem {
                        width:
                            runList.width

                        command:
                            String(modelData)

                        selected:
                            index ===
                            root.selectedIndex

                        onTriggered: {
                            root.selectedIndex =
                                index

                            root.runCurrent()
                        }
                    }

                    ScrollBar.vertical:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded

                            contentItem:
                                Rectangle {
                                    implicitWidth: 3
                                    radius: 2

                                    color:
                                        root.accentColor

                                    opacity: 0.55
                                }
                        }
                }

                ListView {
                    id: windowsList

                    anchors.fill: parent

                    visible:
                        root.mode === 2

                    clip: true

                    spacing: 5

                    currentIndex:
                        root.selectedIndex

                    model:
                        root.filteredWindows()

                    delegate: WindowItem {
                        width:
                            windowsList.width

                        windowItem:
                            modelData

                        selected:
                            index ===
                            root.selectedIndex

                        onTriggered: {
                            root.selectedIndex =
                                index

                            root.runCurrent()
                        }
                    }

                    ScrollBar.vertical:
                        ScrollBar {
                            policy:
                                ScrollBar.AsNeeded

                            contentItem:
                                Rectangle {
                                    implicitWidth: 3
                                    radius: 2

                                    color:
                                        root.accentColor

                                    opacity: 0.55
                                }
                        }
                }

            }

            Item {
                width: parent.width
                height: 18
                opacity: root.seg(4)

                Text {
                    id: footerHint

                    anchors.right:
                        parent.right

                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        "ENTER SELECT  ·  TAB SWITCH  ·  ESC CLOSE"

                    color:
                        root.mutedColor

                    font.family:
                        root.fontName

                    font.pixelSize: 7

                    font.weight:
                        Font.DemiBold
                }
            }
        }
    }

    Component.onCompleted: {
        root.show()
    }
}