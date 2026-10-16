import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property int lockSec: 0
    property int offSec: 300
    property int suspendSec: 600
    property int blurPct: 100
    readonly property string blurPath: Theme.configHome + "/mycfg/lock-blur"

    readonly property bool hasHero: true

    function fmt(n) {
        n = Math.round(n)
        return n >= 60 ? Math.floor(n / 60) + "m" + (n % 60 ? " " + (n % 60) + "s" : "") : n + "s"
    }

    function save() {
        Quickshell.execDetached(["python3", Theme.configHome + "/hypr/scripts/doiz-idle", "set",
                                 String(page.lockSec), String(page.offSec), String(page.suspendSec)])
    }

    Column {
        id: top

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Hero {
            width: parent.width
            icon: "󰌾"
            title: "LOCK & IDLE"
            subtitle: "Lock " + (page.lockSec > 0 ? page.fmt(page.lockSec) : "never") + "  ·  Off " + (page.offSec > 0 ? page.fmt(page.offSec) : "never")
                      + "  ·  Sleep " + (page.suspendSec > 0 ? page.fmt(page.suspendSec) : "never")
            showTrack: false
            interactive: false
        }

        Head {
            width: parent.width
            title: "IDLE TIMEOUTS"
        }

        Sld {
            width: parent.width
            title: "Lock screen after (0 = never)"
            unit: "s"
            from: 0
            to: 1800
            step: 10
            value: page.lockSec
            onCommitted: (v) => {
                page.lockSec = v > 0 ? Math.max(v, 10) : 0
                if (page.offSec > 0 && page.offSec <= page.lockSec) page.offSec = page.lockSec + 10
                if (page.suspendSec > 0 && page.suspendSec <= Math.max(page.offSec, page.lockSec)) page.suspendSec = Math.max(page.offSec, page.lockSec) + 10
                page.save()
            }
        }

        Sld {
            width: parent.width
            title: "Screen off after (0 = never)"
            unit: "s"
            from: 0
            to: 3600
            step: 10
            value: page.offSec
            onCommitted: (v) => {
                page.offSec = v > 0 ? Math.max(v, page.lockSec + 10) : 0
                if (page.suspendSec > 0 && page.suspendSec <= Math.max(page.offSec, page.lockSec)) page.suspendSec = Math.max(page.offSec, page.lockSec) + 10
                page.save()
            }
        }

        Head {
            width: parent.width
            title: "LOCK SCREEN"
        }

        Sld {
            width: parent.width
            title: "Background blur"
            unit: " %"
            from: 0
            to: 100
            step: 5
            value: page.blurPct
            onCommitted: (v) => {
                page.blurPct = v
                Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
                                         "sh", page.blurPath, String(v)])
            }
        }

        Sld {
            width: parent.width
            title: "Sleep after (0 = never)"
            unit: "s"
            from: 0
            to: 7200
            step: 30
            value: page.suspendSec
            onCommitted: (v) => {
                page.suspendSec = v > 0 ? Math.max(v, page.offSec + 10, page.lockSec + 10) : 0
                page.save()
            }
        }
    }

    FileView {
        path: page.blurPath
        onLoaded: {
            var b = parseFloat(text())
            page.blurPct = isNaN(b) ? 100 : Math.max(0, Math.min(100, b))
        }
        onLoadFailed: page.blurPct = 100
    }

    Process {
        running: true
        command: ["python3", Theme.configHome + "/hypr/scripts/doiz-idle", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                var m = this.text.match(/LOCK=(\d+)/)
                var o = this.text.match(/OFF=(\d+)/)
                var u = this.text.match(/SUSPEND=(\d+)/)
                if (m) page.lockSec = parseInt(m[1])
                if (o) page.offSec = parseInt(o[1])
                if (u) page.suspendSec = parseInt(u[1])
            }
        }
    }
}
