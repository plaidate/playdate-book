-- Figure script: a tour, not four screens. The demo plays three levels back to
-- back -- one per scroll frame -- on the same engine, then draws the terrain
-- diagram. The phase boundaries are in main.lua; these are the moments worth
-- photographing inside them.
Shots = {
    seed = 3,
    last = 1320,
    shots = {
        ["shmup-vertical"] = 150,   -- waves falling past a screen-locked ship
        ["shmup-boss"] = 400,       -- the dreadnought, mid-ring
        ["shmup-side"] = 700,       -- the cavern: fly the gap, ride the ground
        ["shmup-free"] = 880,     -- the hull: the camera chases the player
        ["shmup-profile"] = 1300,   -- drawn wall vs hit wall, magnified
    },
}
