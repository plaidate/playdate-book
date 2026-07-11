-- Figure script: look at the staged v1 save, migrate it, tour
-- the options screen (toggling both settings), then beat the
-- old high score in the game.
Shots = {
    seed = 17,
    last = 240,
    shots = {
        ["save-before"] = 30,   -- inspector: raw v1 save
        ["save-after"] = 70,    -- inspector: migrated v2 save
        ["save-options"] = 140, -- options on their own store
        ["save-game"] = 215,    -- high score beaten and saved
    },
    script = function(frame)
        return {
            aPressed = (frame == 40      -- migrate
                or frame == 110          -- sound off
                or frame == 170 or frame == 180
                or frame == 190 or frame == 200), -- score x4
            right = (frame == 120),      -- difficulty -> HARD
            bPressed = (frame == 100     -- -> options
                or frame == 160),        -- -> game
        }
    end,
}
