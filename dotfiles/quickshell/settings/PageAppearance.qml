import QtQuick
import QtQuick.Controls
import Quickshell
import "."

Item {
    id: page

    Live {
        id: live
    }

    Head {
        id: head

        width: parent.width
        title: "THEME"
        info: live.get("dark", "dark").toUpperCase()
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded

            contentItem: Rectangle {
                implicitWidth: 3
                radius: 2
                visible: parent && parent.size < 1
                color: Theme.accentColor
                opacity: 0.55
            }
        }

        Column {
            id: col

            width: parent.width - 6
            spacing: 6

            Sw {
                width: parent.width
                icon: "󰓑"
                title: "Dark mode"
                sub: "GTK, Qt, Firefox, Chromium, Electron and Thunar"
                checked: live.get("dark", "dark") === "dark"

                onToggled: {
                    Quickshell.execDetached(["bash", Theme.configHome + "/hypr/scripts/dark-mode.sh", "toggle"])
                    live.act(["get"])
                }
            }

            Sw {
                width: parent.width
                icon: "󰍜"
                title: "Top bar"
                sub: "Show or hide the top bar"
                checked: live.on("bar")

                onToggled: live.act(["bar", live.on("bar") ? "off" : "on"])
            }

            Sw {
                width: parent.width
                icon: "󰂵"
                title: "Glass"
                sub: "Translucent bar and UI (Glass Mode)"
                checked: live.get("glass", "off") === "on"

                onToggled: {
                    Quickshell.execDetached(["python3", Theme.configHome + "/theme/scripts/bar-glass.py", "toggle"])
                    live.act(["get"])
                }
            }

            Sld {
                width: parent.width
                title: "Glass opacity"
                unit: " %"
                from: 20
                to: 100
                value: Number(live.get("glass_level", 50))

                onCommitted: (v) => {
                    Quickshell.execDetached(["python3", Theme.configHome + "/theme/scripts/bar-glass.py", "alpha", String(v)])
                    live.act(["get"])
                }
            }

            Sw {
                width: parent.width
                icon: "󰍹"
                title: "Wallpaper colors"
                sub: "The bar, Quickshell, btop, cava and kitty follow the wallpaper"
                checked: live.on("dynamic")

                onToggled: live.act(["dynamic", live.on("dynamic") ? "off" : "on"])
            }

            Sw {
                width: parent.width
                icon: "󰝚"
                title: "Media popup"
                sub: "Player card that drops down when you hover the music module"
                checked: live.on("media_popup")

                onToggled: live.act(["set", "media_popup", live.on("media_popup") ? "0" : "1"])
            }

            Head {
                width: parent.width
                title: "DESKTOP CAVA"
                info: live.on("cava_desk") ? live.get("cava_desk_pos", "bottom").toUpperCase() : "OFF"
            }

            Sw {
                width: parent.width
                icon: "󰎇"
                title: "Desktop cava"
                sub: "Audio visualizer behind your windows (Super + C moves it)"
                checked: live.on("cava_desk")

                onToggled: live.act(["cavadesk", live.on("cava_desk") ? "off" : "on"])
            }

            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { key: "bottom", label: "BOTTOM" },
                        { key: "top", label: "TOP" }
                    ]

                    Btn {
                        required property var modelData

                        width: (parent.width - 6) / 2
                        enabled: live.on("cava_desk")
                        label: modelData.label
                        filled: live.on("cava_desk") && live.get("cava_desk_pos", "bottom") === modelData.key
                        tone: Theme.stateColor

                        onClicked: live.act(["cavadesk", "pos", modelData.key])
                    }
                }
            }

            Head {
                width: parent.width
                title: "WINDOWS"
            }

            Sld {
                width: parent.width
                title: "Corner radius"
                unit: " px"
                to: 24
                value: Number(live.get("rounding", 4))

                onCommitted: (v) => live.act(["set", "rounding", String(v)])
            }

            Sld {
                width: parent.width
                title: "Border size"
                unit: " px"
                to: 8
                value: Number(live.get("border_size", 3))

                onCommitted: (v) => live.act(["set", "border_size", String(v)])
            }

            Sld {
                width: parent.width
                title: "Inactive window opacity"
                unit: " %"
                from: 40
                to: 100
                value: Number(live.get("inactive_opacity", 100))

                onCommitted: (v) => live.act(["set", "inactive_opacity", String(v)])
            }

            Sw {
                width: parent.width
                icon: "󰅶"
                title: "Blur"
                sub: "Blur behind floating windows"
                checked: live.on("blur")

                onToggled: live.act(["set", "blur", live.on("blur") ? "0" : "1"])
            }

            Sw {
                width: parent.width
                icon: "󰂏"
                title: "Window shadow"
                checked: live.on("shadow")

                onToggled: live.act(["set", "shadow", live.on("shadow") ? "0" : "1"])
            }

            Btn {
                width: parent.width
                label: "RESET TO DEFAULTS"
                tone: Theme.badColor

                onClicked: live.act(["reset"])
            }
        }
    }
}
