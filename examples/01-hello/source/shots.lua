-- Figure script for the book's capture pipeline (Appendix D).
-- The bot presses A once a second; we shoot three named frames.
Shots = {
    seed = 1,
    last = 240,
    shots = {
        ["hello-early"] = 20,
        ["hello-mid"] = 120,
        ["hello-later"] = 230,
    },
    script = function(frame)
        return { aPressed = (frame % 30 == 0) }
    end,
}
