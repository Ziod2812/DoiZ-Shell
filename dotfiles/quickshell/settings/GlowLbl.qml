import QtQuick
import QtQuick.Effects
import "."

Lbl {
    id: g

    property color glowColor: Theme.stateColor
    property bool live: true
    property real strength: 0.9

    opacity: g.live ? 0.65 + 0.35 * Theme.beat : 1

    layer.enabled: g.live
    layer.effect: MultiEffect {
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: g.glowColor
        shadowBlur: 1.0
        shadowOpacity: Theme.beat * g.strength
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
