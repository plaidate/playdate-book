-- Tour tunables. Kit.run feeds C.DT to Game.update every frame,
-- exactly as in the three shipped games.
C = {
    DT = 1 / 30,
    SCREEN = 120,   -- frames per tour screen
    AMBIENT = 0.15, -- screen two's night (quantizes to full dark)
    HORIZON = 110,  -- screen three's vanishing line
    CAMY = 60,      -- Scaler camera height over the water
    SPD = 150,      -- forward speed, world units/s
}
