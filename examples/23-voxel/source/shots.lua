-- Figure script: four 120-frame screens. Terrain authoring with
-- a carve crater and debris, the occlusion ghost behind twin
-- pillars, a solved shell arc with its trajectory traced, and
-- step-up/gravity physics on a terraced cliff.
Shots = {
    seed = 1,
    last = 480,
    shots = {
        ["vox-terrain"] = 50,
        ["vox-carve"] = 66,
        ["ghost-pillar"] = 178,
        ["proj-arc"] = 330,
        ["phys-steps"] = 430,
        ["phys-fall"] = 462,
    },
    script = function(f)
        local t = {}
        if f <= 120 then
            t.act = (f == 60 or f == 90)
        elseif f <= 240 then
            t.mx = 1
        elseif f <= 360 then
            t.act = (f == 245 or f == 302)
        else
            t.mx = 1
        end
        return t
    end,
}
