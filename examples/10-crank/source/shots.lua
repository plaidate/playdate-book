-- Figure script: one scripted wrist. A slow 3 deg/frame crawl
-- clicks through the selector, a 4 deg/frame sweep aims the turret
-- (A advances panels at 90 and 180), then a hard 8 deg/frame wind
-- charges the lob, which releases when the crank goes still at 235
-- and fires at ~240, landing on the target at ~296.
Shots = {
    seed = 1,
    last = 310,
    shots = {
        ["crank-detent"]  = 70,  -- selector mid-click, needle bold
        ["crank-aim"]     = 150, -- barrel at 150 deg, tracers out
        ["crank-wind"]    = 220, -- meter charging, WINDING label
        ["crank-release"] = 260, -- shell mid-arc
        ["crank-hit"]     = 302, -- splash ring on the target
    },
    script = function(f)
        local crank = 0
        if f <= 90 then
            crank = 3
        elseif f <= 180 then
            crank = 4
        elseif f >= 185 and f <= 235 then
            crank = 8
        end
        return { crank = crank, a = (f == 90 or f == 180) }
    end,
}
