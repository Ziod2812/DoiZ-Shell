local mouse = {
    swipe_fingers = 3,
    swipe_invert = true,
}

hl.config({
    gestures = {
        workspace_swipe_invert = mouse.swipe_invert,
    },
})

hl.gesture({
    fingers = mouse.swipe_fingers,
    direction = "horizontal",
    action = "workspace",
})

return mouse
