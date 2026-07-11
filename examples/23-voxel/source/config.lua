-- Tour tunables. Kit.run feeds Config.DT to Game.update every
-- frame, and Kit.updateParts reads Config.GRAVITY, exactly as
-- in the ten shipped games.
Config = {
    DT = 1 / 30,
    GRAVITY = 34,  -- voxels/s^2, the package-wide default
    SCREEN = 120,  -- frames per tour screen
}
