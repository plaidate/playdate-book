-- Figure script for the book's capture pipeline (Appendix D).
-- The harness presses A once a second; we shoot an early frame and a late one.
Shots = {
    seed = 1,
    last = 240,
    shots = {
        ["hello-early"] = 20,
        ["hello-later"] = 230,
    },
    script = function(frame)
        return { aPressed = (frame % 30 == 0) }
    end,
}
