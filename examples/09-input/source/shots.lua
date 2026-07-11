-- Figure script: a scripted thumb. Holds and taps paint the trace,
-- then B exercises the runner: a coyote jump off the ledge at 105,
-- a plain jump at 150, and a press at 174 that lands in the buffer
-- window and fires on touchdown at ~177.
Shots = {
    seed = 1,
    last = 240,
    shots = {
        ["input-edge"]   = 50,  -- A's press frame: lamp + blip
        ["input-held"]   = 95,  -- A held 26 frames: lamp, no blip
        ["input-trace"]  = 112, -- the full level-vs-edge timeline
        ["input-coyote"] = 115, -- mid-air over the pit, label up
        ["input-buffer"] = 182, -- rising off the buffered press
    },
    script = function(f)
        return {
            right = f >= 10 and f <= 40,
            up    = f >= 45 and f <= 46,
            down  = f >= 58 and f <= 59,
            left  = f >= 63 and f <= 64,
            a     = (f >= 50 and f <= 51)
                or (f >= 70 and f <= 100),
            b     = f == 105 or f == 150 or f == 174,
        }
    end,
}
