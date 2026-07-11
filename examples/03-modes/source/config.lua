-- snip: config
-- Every tuning constant in one global table. C.DT is the fixed
-- timestep: the display runs at 30 fps, so one update is 1/30 s.
C = {
    DT = 1 / 30,
    W = 400,
    H = 240,

    PLAYER_W = 24,       -- paddle size, px
    PLAYER_H = 10,
    PLAYER_Y = 222,      -- top of the paddle
    PLAYER_SPEED = 160,  -- px per second

    BLOCK = 16,          -- falling block side, px
    FALL_SPEED = 150,    -- px per second
    SPAWN_T = 0.6,       -- seconds between blocks
    AIM_EVERY = 3,       -- every Nth block spawns over the player

    LOCKOUT = 0.4,       -- seconds before game over accepts input
}
-- endsnip
