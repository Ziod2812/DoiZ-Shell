
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root

    property var windows: []

    function refresh() {
        var result = []

        for (var i = 0; i < ToplevelManager.toplevels.values.length; i++) {
            var window = ToplevelManager.toplevels.values[i]

            if (!window)
                continue

            if (window.title === undefined && window.appId === undefined)
                continue

            result.push(window)
        }

        root.windows = result
    }

    function activate(window) {
        if (!window)
            return

        window.activate()
    }

    Connections {
        target: ToplevelManager.toplevels

        function onObjectInsertedPost() {
            root.refresh()
        }

        function onObjectRemovedPost() {
            root.refresh()
        }
    }

    Component.onCompleted: {
        refresh()
    }
}

