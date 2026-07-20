-- Tour tunables. Kit.run feeds Config.DT to Game.update every
-- frame, exactly as in the four shipped games.
Config = {
    DT = 1 / 30,
    SCREEN = 120, -- frames per tour screen
}

-- Kit.run ticks one core module the tour doesn't vendor: Music, the
-- wave-2 song player (core/tmus.lua). Same trick as Harness -> the
-- book harness: the loop meets Music at a named global, so a no-op
-- with the one method Kit.run calls (Music.update) satisfies it.
Music = { update = function() end }
