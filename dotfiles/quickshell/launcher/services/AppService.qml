import QtQuick
import Quickshell

Item {
    id: root

    readonly property var applications: DesktopEntries.applications.values

    function refresh() {
        return
    }
}