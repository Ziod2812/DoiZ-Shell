import QtQuick
import Quickshell
import Quickshell.Io
import "."

ShellRoot {
    id: root

    property int page: 0

    IpcHandler {
        target: "settings"

        function toggle(): void {
            Qt.quit()
        }

        function show(): void {
        }

        function hide(): void {
            Qt.quit()
        }

        function open(name: string): void {
            for (var i = 0; i < Theme.pages.length; i++) {
                if (Theme.pages[i].key === name) {
                    root.page = i
                    return
                }
            }
        }
    }

    SettingsPanel {
        page: root.page

        onPageRequested: (index) => root.page = index
        onCloseRequested: Qt.quit()
    }
}
