import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var commands: []

    Process {
        id: scanProcess

        command: [
            "sh",
            "-lc",
            "IFS=:; for dir in $PATH; do [ -d \"$dir\" ] || continue; find -L \"$dir\" -maxdepth 1 -type f -perm -111 -printf '%f\\n' 2>/dev/null; done | sort -fu"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var result = []
                var seen = {}
                var lines = text.split("\n")

                for (var i = 0; i < lines.length; i++) {
                    var command = lines[i].trim()

                    if (!command)
                        continue

                    if (seen[command])
                        continue

                    seen[command] = true
                    result.push(command)
                }

                result.sort(function(a, b) {
                    return a.localeCompare(
                        b,
                        undefined,
                        {
                            sensitivity: "base"
                        }
                    )
                })

                root.commands = result
            }
        }
    }

    function refresh() {
        scanProcess.running = false
        scanProcess.running = true
    }

    Component.onCompleted: {
        refresh()
    }
}