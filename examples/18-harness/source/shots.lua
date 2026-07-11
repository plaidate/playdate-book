-- Figure script: hand the whole run to the autopilot, then flip
-- to the telemetry screen near the end.
Shots = {
    seed = 18,
    last = 280,
    shots = {
        ["course"] = 4,
        ["bot-run"] = 150,
        ["telemetry"] = 270,
    },
    script = function(frame)
        if frame >= 250 then
            return { tele = (frame == 250) }
        end
        return Pilot.think(frame)
    end,
}
