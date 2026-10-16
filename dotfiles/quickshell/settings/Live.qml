import QtQuick
import Quickshell.Io
import "."

Item {
    id: st

    property var vals: ({})
    property int version: 0

    function get(key, fallback) {
        var v = st.vals[key]
        return v === undefined ? fallback : v
    }

    function on(key) {
        return st.get(key, "0") === "1"
    }

    function act(args) {
        Theme.run(args)
        refreshTimer.restart()
    }

    function refresh() {
        if (!proc.running)
            proc.running = true
    }

    Process {
        id: proc

        command: ["python3", Theme.setScript, "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = {}
                var lines = this.text.split("\n")

                for (var i = 0; i < lines.length; i++) {
                    var k = lines[i].indexOf("=")

                    if (k > 0)
                        out[lines[i].substring(0, k)] = lines[i].substring(k + 1)
                }

                st.vals = out
                st.version++
            }
        }
    }

    Timer {
        id: refreshTimer

        interval: 700

        onTriggered: st.refresh()
    }

    Timer {
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: st.refresh()
    }
}
