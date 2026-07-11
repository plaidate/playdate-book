-- Figure script: a scripted wrist and thumb. Tilt right rolls the
-- marble across the tray, tilt up bounces it off the inner wall,
-- B opens the scoreboard (down-taps walk the selection to row 6),
-- B returns, and showPause previews the procedural pause card.
Shots = {
    seed = 1,
    last = 280,
    shots = {
        ["tilt-roll"]   = 40,  -- mid-roll, tilt arrow + trail
        ["tilt-bounce"] = 85,  -- after wall ricochets, trail bent
        ["tilt-scores"] = 160, -- gridview, row 6 selected/scrolled
        ["tilt-pause"]  = 200, -- pause-card preview
    },
    script = function(f)
        local tiltX, tiltY = 0, 0
        if f <= 45 then
            tiltX = 0.5
        elseif f <= 95 then
            tiltY = -0.35
        elseif f >= 225 and f <= 265 then
            tiltX, tiltY = -0.5, 0.3
        end
        return {
            tiltX = tiltX,
            tiltY = tiltY,
            b = f == 100 or f == 170,
            down = f == 110 or f == 118 or f == 126
                or f == 134 or f == 142,
            showPause = f >= 180 and f <= 220,
        }
    end,
}
