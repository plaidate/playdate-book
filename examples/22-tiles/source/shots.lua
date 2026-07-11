-- Figure script: four 120-frame screens. The scrolling camera
-- (mid-follow, then clamped at the map edge), a live Map.set
-- tunnel carve, the BFS distance field with a descending chaser,
-- and the sprite gallery with a debris-and-shake moment.
Shots = {
    seed = 1,
    last = 480,
    shots = {
        ["cam-follow"] = 60,
        ["cam-clamp"] = 116,
        ["map-carve"] = 220,
        ["bfs-field"] = 310,
        ["spr-gallery"] = 400,
        ["kit-burst"] = 424,
    },
    script = function(f)
        local t = {}
        if f <= 120 then
            t.mx = 1
        elseif f <= 240 then
            t.act = (f % 2 == 0)
        elseif f <= 360 then
            local ph = (f - 241) % 60
            t.my = ph < 30 and -1 or 1
        else
            t.act = (f == 420 or f == 450)
        end
        return t
    end,
}
