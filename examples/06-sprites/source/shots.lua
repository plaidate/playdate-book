-- Figure script: four 75-frame phases, one per collision response
-- type. The player is driven diagonally into the wall each time;
-- the shot at the end of each phase shows the trail it left.
Shots = {
    seed = 1,
    last = 300,
    shots = {
        ["sprite-slide"] = 70,
        ["sprite-freeze"] = 145,
        ["sprite-overlap"] = 220,
        ["sprite-bounce"] = 295,
    },
    script = function(frame)
        local phase = math.min(4, math.ceil(frame / 75))
        return { phase = phase, dx = 4, dy = 1 }
    end,
}
