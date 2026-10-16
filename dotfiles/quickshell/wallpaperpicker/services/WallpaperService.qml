import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string stateDir:
        (
            Quickshell.env("XDG_STATE_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.local/state"
            )
        ) + "/doiz"

    property string stateFile:
        root.stateDir + "/wallpaper"

    property string wallpaperDir:
        Quickshell.env("DOIZ_WALLPAPER_DIR") ||
        (
            Quickshell.env("HOME") +
            "/Pictures/Wallpapers"
        )

    property string transition: "grow"
    property real duration: 0.6

    property var wallpapers: []
    property string selectedPath: ""

    property string themeScript:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/theme/scripts/apply-theme.py"

    property string videoWallpaperScript:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/hypr/scripts/video-wallpaper.sh"

    property string barPeekScript:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/hypr/scripts/bar-peek"

    property string cfgHome:
        Quickshell.env("XDG_CONFIG_HOME") ||
        (Quickshell.env("HOME") + "/.config")

    property string autoFile: root.cfgHome + "/mycfg/wallpaper-auto"
    property string autoScript: root.cfgHome + "/hypr/scripts/wallpaper-auto.sh"

    property bool autoOn: false
    property string autoMode: "random"
    property int autoMinutes: 30
    property string autoMedia: "all"

    readonly property var autoIntervals: [1, 5, 10, 15, 30, 60, 120, 240]

    function autoLabel(minutes) {
        return minutes < 60 ? minutes + " min" : (minutes / 60) + " h"
    }

    function saveAuto() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "mkdir -p \"$(dirname \"$1\")\"; printf '%s\\n%s\\n%s\\n%s\\n' \"$2\" \"$3\" \"$4\" \"$5\" > \"$1\"; " +
            "[ \"$2\" = on ] && setsid -f bash \"$6\" daemon >/dev/null 2>&1 </dev/null; exit 0",
            "doiz",
            root.autoFile,
            root.autoOn ? "on" : "off",
            root.autoMode,
            String(root.autoMinutes),
            root.autoMedia,
            root.autoScript
        ])
    }

    function toggleAuto() {
        root.autoOn = !root.autoOn
        root.saveAuto()
    }

    function cycleAutoInterval() {
        var i = root.autoIntervals.indexOf(root.autoMinutes)

        root.autoMinutes = root.autoIntervals[(i + 1) % root.autoIntervals.length]
        root.saveAuto()
    }

    function cycleAutoMode() {
        root.autoMode = root.autoMode === "random" ? "order" : "random"
        root.saveAuto()
    }

    function cycleAutoMedia() {
        var values = ["all", "image", "video"]

        root.autoMedia = values[(values.indexOf(root.autoMedia) + 1) % values.length]
        root.saveAuto()
    }

    Process {
        id: loadAuto

        command: [
            "sh",
            "-c",
            "[ -f \"$1\" ] && cat \"$1\" || true",
            "doiz",
            root.autoFile
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n")

                root.autoOn = (l[0] || "").trim() === "on"
                root.autoMode = (l[1] || "").trim() === "order" ? "order" : "random"

                var m = parseInt(l[2])

                root.autoMinutes = (isFinite(m) && m >= 1) ? m : 30

                var media = (l[3] || "").trim()

                root.autoMedia = (media === "image" || media === "video") ? media : "all"
            }
        }
    }

    property string videoThemeFrameScript:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/hypr/scripts/video-theme-frame.sh"

    property string videoStopScript:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/hypr/scripts/video-wallpaper-stop.sh"

    property string videoThumbScript:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/hypr/scripts/video-thumbnails.sh"

    property string colorScript:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/hypr/scripts/wallpaper-colors.py"

    property var videoThumbs: ({})
    property var pendingThumbs: ({})
    property var wallpaperColors: ({})
    property var pendingColors: ({})
    readonly property bool colorsBusy: colorScan.running

    function loadColors() {
        colorScan.running = false
        colorScan.running = true
    }

    function flushColors() {
        var next = {}
        var key

        for (key in root.wallpaperColors)
            next[key] = root.wallpaperColors[key]

        for (key in root.pendingColors)
            next[key] = root.pendingColors[key]

        root.pendingColors = ({})
        root.wallpaperColors = next
    }

    function loadVideoThumbs() {
        thumbnails.running = false
        thumbnails.running = true
    }

    function flushThumbs() {
        var next = {}
        var key

        for (key in root.videoThumbs)
            next[key] = root.videoThumbs[key]

        for (key in root.pendingThumbs)
            next[key] = root.pendingThumbs[key]

        root.pendingThumbs = ({})
        root.videoThumbs = next
    }

    property string videoFrameTemp:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") +
        "/doiz-video-wallpaper-theme-frame.jpg"

    property var videoExtensions: [
        "mp4",
        "webm",
        "mkv",
        "mov",
        "avi"
    ]

    function isVideo(path) {
        var value =
            String(path || "").toLowerCase()

        var dot =
            value.lastIndexOf(".")

        if (dot < 0)
            return false

        var ext =
            value.substring(dot + 1)

        return root.videoExtensions.indexOf(ext) >= 0
    }

    property bool daemonReady: false
    property bool applyPending: false
    property bool busy: false

    function refresh() {
        scanner.running = false
        scanner.running = true
    }

    function reload() {
        refresh()
    }

    function save() {
        saveState.running = false
        saveState.running = true
    }

    function setWallpaperDir(path) {
        var value =
            String(path || "").trim()

        if (!value)
            return

        root.wallpaperDir =
            value

        save()
        refresh()
    }

    function isValidTransition(value) {
        var values = [
            "none",
            "simple",
            "fade",
            "left",
            "right",
            "top",
            "bottom",
            "wipe",
            "wave",
            "grow",
            "center",
            "any",
            "outer",
            "random"
        ]

        return values.indexOf(
            String(value)
        ) >= 0
    }

    function setTransition(value) {
        var next =
            String(value || "").trim()

        if (!root.isValidTransition(next))
            next = "simple"

        root.transition =
            next

        root.save()

        console.log(
            "DoiZ transition changed:",
            root.transition
        )

        if (root.selectedPath) {
            root.themeSkip = true
            root.peekSkip = true
            root.apply(root.selectedPath)
        }
    }

    function setDuration(value) {
        var number =
            Number(value)

        if (!isFinite(number))
            return

        if (number < 0.1)
            number = 0.1

        if (number > 10)
            number = 10

        root.duration =
            number

        root.save()

        console.log(
            "DoiZ duration changed:",
            root.duration
        )

        if (root.selectedPath) {
            root.themeSkip = true
            root.peekSkip = true
            root.apply(root.selectedPath)
        }
    }

    function ensureDaemon() {
        if (root.daemonReady) {
            root.applyPending = false
            applyDelay.restart()
            return
        }

        root.applyPending = true

        daemonCheck.running = false
        daemonCheck.running = true
    }

    function apply(path) {
        var value =
            String(path || "").trim()

        if (!value)
            return

        root.selectedPath =
            value

        root.busy = true

        root.ensureDaemon()
    }

    function setWallpaper(path) {
        root.apply(path)
    }

    function runWallpaper() {
        if (!root.selectedPath)
            return

        Quickshell.execDetached([
            "sh",
            "-c",
            "mkdir -p \"$1\"; printf '%s\\n' \"$2\" > \"$1/current-wallpaper\"",
            "doiz",
            root.stateDir,
            root.selectedPath
        ])

        var currentTransition =
            String(root.transition)

        var currentDuration =
            Number(root.duration)

        if (!root.isValidTransition(
                currentTransition
            )) {
            currentTransition =
                "simple"
        }

        if (!isFinite(currentDuration))
            currentDuration = 0.6

        if (currentDuration < 0.1)
            currentDuration = 0.1

        if (currentDuration > 10)
            currentDuration = 10

        if (root.peekSkip) {
            root.peekSkip = false
        } else {
            Quickshell.execDetached([
                "bash",
                root.barPeekScript,
                (currentDuration + 0.3).toFixed(2)
            ])
        }

        if (root.isVideo(root.selectedPath)) {
            var videoArgs = [
                "env",
                "DOIZ_VIDEO_TRANSITION=" + currentTransition,
                "DOIZ_VIDEO_TRANSITION_DURATION=" + currentDuration.toFixed(2),
                "bash",
                root.videoWallpaperScript,
                root.selectedPath
            ]

            console.log(
                "DoiZ executing:",
                videoArgs.join(" ")
            )

            Quickshell.execDetached(videoArgs)

            videoThemeFrame.running = false
            videoThemeFrame.running = true

            return
        }

        var args = [
            "awww",
            "img",
            root.selectedPath,
            "--transition-type",
            currentTransition,
            "--transition-duration",
            currentDuration.toFixed(2),
            "--transition-step",
            "90",
            "--transition-fps",
            "60"
        ]

        console.log(
            "DoiZ executing:",
            args.join(" ")
        )

        var imageArgs = [
            "bash",
            "-c",
            "bash \"$1\" >/dev/null 2>&1; shift; exec \"$@\"",
            "doiz",
            root.videoStopScript
        ].concat(args)

        Quickshell.execDetached(imageArgs)

        root.requestTheme()
    }

    Process {
        id: loadState

        command: [
            "sh",
            "-c",
            "mkdir -p \"$1\"; [ -f \"$2\" ] && cat \"$2\" || true",
            "doiz",
            root.stateDir,
            root.stateFile
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines =
                    text.split("\n")

                for (
                    var i = 0;
                    i < lines.length;
                    i++
                ) {
                    var line =
                        lines[i]

                    if (
                        line.indexOf(
                            "directory="
                        ) === 0
                    ) {
                        root.wallpaperDir =
                            line.substring(10)
                    } else if (
                        line.indexOf(
                            "transition="
                        ) === 0
                    ) {
                        var savedTransition =
                            line.substring(11)

                        if (
                            root.isValidTransition(
                                savedTransition
                            )
                        ) {
                            root.transition =
                                savedTransition
                        } else {
                            root.transition =
                                "grow"
                        }
                    } else if (
                        line.indexOf(
                            "duration="
                        ) === 0
                    ) {
                        var value =
                            parseFloat(
                                line.substring(9)
                            )

                        if (isFinite(value)) {
                            if (value < 0.1)
                                value = 0.1

                            if (value > 10)
                                value = 10

                            root.duration =
                                value
                        }
                    }
                }

                root.refresh()
            }
        }
    }

    Process {
        id: saveState

        command: [
            "sh",
            "-c",
            "mkdir -p \"$1\"; printf 'directory=%s\\ntransition=%s\\nduration=%s\\n' \"$3\" \"$4\" \"$5\" > \"$2\"",
            "doiz",
            root.stateDir,
            root.stateFile,
            root.wallpaperDir,
            root.transition,
            root.duration.toFixed(1)
        ]
    }

    Process {
        id: scanner

        command: [
            "sh",
            "-c",
            "if [ -d \"$1\" ]; then find \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' \\) -print0 2>/dev/null | sort -z -f; fi",
            "doiz",
            root.wallpaperDir
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var parts =
                    text.split("\u0000")

                var result = []

                for (
                    var i = 0;
                    i < parts.length;
                    i++
                ) {
                    if (
                        parts[i].length > 0
                    ) {
                        result.push(
                            parts[i]
                        )
                    }
                }

                root.wallpapers =
                    result

                root.loadVideoThumbs()
            }
        }
    }

    Process {
        id: thumbnails

        command: [
            "bash",
            root.videoThumbScript,
            root.wallpaperDir
        ]

        stdout: SplitParser {
            onRead: function(line) {
                var tab =
                    line.indexOf("\t")

                if (tab <= 0)
                    return

                root.pendingThumbs[
                    line.substring(0, tab)
                ] = line.substring(tab + 1)

                thumbFlush.restart()
            }
        }

        onExited: {
            root.flushThumbs()
            root.loadColors()
        }
    }

    Process {
        id: colorScan

        command: [
            "python3",
            root.colorScript,
            root.wallpaperDir
        ]

        stdout: SplitParser {
            onRead: function(line) {
                var tab =
                    line.indexOf("\t")

                if (tab <= 0)
                    return

                root.pendingColors[
                    line.substring(0, tab)
                ] = line.substring(tab + 1)

                colorFlush.restart()
            }
        }

        onExited: {
            root.flushColors()
        }
    }

    Timer {
        id: colorFlush

        interval: 120

        repeat: false

        onTriggered: {
            root.flushColors()
        }
    }

    Timer {
        id: thumbFlush

        interval: 80

        repeat: false

        onTriggered: {
            root.flushThumbs()
        }
    }

    Process {
        id: daemonCheck

        command: [
            "sh",
            "-c",
            "if awww query >/dev/null 2>&1; then exit 0; fi; awww-daemon >/dev/null 2>&1 &"
        ]

        onExited: {
            root.daemonReady = true

            if (root.applyPending) {
                root.applyPending = false
                applyDelay.restart()
            }
        }
    }

    Timer {
        id: applyDelay

        interval: 0

        repeat: false

        onTriggered: {
            root.runWallpaper()
        }
    }

    property bool themeRerun: false
    property bool themeSkip: false
    property bool peekSkip: false

    function requestTheme() {
        if (root.themeSkip) {
            root.themeSkip = false
            root.busy = false
            return
        }

        if (themeApply.running)
            themeRerun = true
        else
            themeApply.running = true
    }

    Process {
        id: themeApply

        command: [
            "python3",
            root.themeScript,
            root.isVideo(root.selectedPath)
                ? root.videoFrameTemp
                : root.selectedPath
        ]

        onExited:
            function(exitCode, exitStatus) {
                if (root.themeRerun) {
                    root.themeRerun = false
                    Qt.callLater(function() {
                        themeApply.running = true
                    })
                    return
                }

                root.busy = false

                if (exitCode !== 0) {
                    console.log(
                        "DoiZ theme update failed:",
                        exitCode
                    )
                }
            }
    }

    Process {
        id: videoThemeFrame

        command: [
            "bash",
            root.videoThemeFrameScript,
            root.selectedPath,
            root.videoFrameTemp
        ]

        onExited: {
            root.requestTheme()
        }
    }

    Component.onCompleted: {
        loadState.running = true
        loadAuto.running = true
    }
}
