-- Figure script: run right across the course, jumping on cue;
-- then switch to the tunneling demo and let the bullets fly.
Shots = {
    seed = 14,
    last = 210,
    shots = {
        ["course"] = 8,        -- the whole course, at rest
        ["jump-arc"] = 90,     -- near the apex of the 2nd jump
        ["tunneling"] = 196,   -- both bullets past/at the wall
    },
    script = function(frame)
        if frame >= 180 then
            return { demo = (frame == 180) }
        end
        return {
            right = frame > 10,
            jump = (frame == 30 or frame == 80
                or frame == 130),
        }
    end,
}
