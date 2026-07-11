-- snip: config
-- Every tuning constant in one table (the Chapter 3 skeleton).
C = {
    DT = 1 / 30,
    W = 400,
    H = 240,

    TX = 200,           -- turret pivot
    TY = 232,
    BARREL = 26,        -- barrel length, px
    ARC = 80,           -- barrel swings +/- this from vertical
    COOLDOWN = 6,       -- frames between shots
    SHOT_SPEED = 320,   -- px per second

    TSIZE = 14,         -- target side, px
    FALL = 46,          -- base fall speed, px/s
    FALL_RAMP = 1.6,    -- extra px/s per point scored
    SPAWN_T = 1.5,      -- base seconds between targets
    SPAWN_RAMP = 0.03,  -- seconds shaved per point
    SPAWN_MIN = 0.55,   -- the spawn gap never drops below this
    SWAY = 18,          -- horizontal drift, px/s of amplitude

    GROUND = 228,       -- a target reaching here ends the run
    LOCKOUT = 0.5,      -- seconds before game over takes input
}
-- endsnip
