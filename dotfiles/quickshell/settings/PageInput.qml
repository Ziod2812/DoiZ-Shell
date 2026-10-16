import QtQuick
import QtQuick.Controls
import "."

Item {
    id: page

    readonly property var layouts: ["us", "vn", "gb", "fr", "de", "es", "ru", "jp"]

    Live {
        id: live
    }

    Head {
        id: head

        width: parent.width
        title: "KEYBOARD AND MOUSE"
        info: live.get("kb_layout", "us").toUpperCase()
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: col.height + 8
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

            Head {
                width: parent.width
                title: "KEYBOARD LAYOUT"
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: page.layouts

                    delegate: Btn {
                        required property string modelData

                        readonly property bool current: live.get("kb_layout", "us") === modelData

                        label: modelData.toUpperCase()
                        filled: current
                        tone: current ? Theme.goodColor : Theme.textColor

                        onClicked: live.act(["set", "kb_layout", modelData])
                    }
                }
            }

            Sw {
                width: parent.width
                icon: "󰌌"
                title: "Num Lock on startup"
                checked: live.on("numlock")

                onToggled: live.act(["set", "numlock", live.on("numlock") ? "0" : "1"])
            }

            Head {
                width: parent.width
                title: "MOUSE AND TOUCHPAD"
            }

            Sld {
                width: parent.width
                title: "Pointer speed"
                unit: ""
                from: -100
                to: 100
                step: 5
                value: Number(live.get("sensitivity", 0))

                onCommitted: (v) => live.act(["set", "sensitivity", String(v)])
            }

            Sw {
                width: parent.width
                icon: "󰍹"
                title: "Focus follows mouse"
                checked: live.get("follow_mouse", "1") !== "0"

                onToggled: live.act(["set", "follow_mouse", live.get("follow_mouse", "1") === "0" ? "1" : "0"])
            }

            Sw {
                width: parent.width
                icon: "󰍹"
                title: "Natural scrolling"
                sub: "Touchpad"
                checked: live.on("natural_scroll")

                onToggled: live.act(["set", "natural_scroll", live.on("natural_scroll") ? "0" : "1"])
            }

            Sw {
                width: parent.width
                icon: "󰍹"
                title: "Tap to click"
                sub: "Touchpad"
                checked: live.on("tap_to_click")

                onToggled: live.act(["set", "tap_to_click", live.on("tap_to_click") ? "0" : "1"])
            }
        }
    }
}
