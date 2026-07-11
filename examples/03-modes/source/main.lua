-- Chapter 3: the update loop and the mode machine.
-- A complete, minimal game: dodge the falling blocks.
-- This file is the template every later example in the book follows.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "config"
import "gamestate"
import "input"
import "game"
import "draw"

-- snip: boot
playdate.display.setRefreshRate(30)
-- The harness seeds math.random itself (figures are deterministic);
-- a human-played build gets a fresh world each launch.
if not Harness.enabled then
    math.randomseed(playdate.getSecondsSinceEpoch())
end
-- endsnip

-- snip: modes
-- One function per mode. Each consumes this frame's input
-- snapshot, mutates G, and draws. G.mode picks which one runs.
local modes = {}

function modes.title(inp)
    if inp.confirm then
        Game.reset()
        G.setMode("play")
    end
    Draw.title()
end

function modes.play(inp)
    Game.update(C.DT, inp)
    if inp.pause then G.setMode("pause") end
    Draw.play()
end

function modes.pause(inp)
    -- No Game.update: the world is frozen, but still drawn.
    if inp.pause or inp.confirm then G.setMode("play") end
    Draw.play()
    Draw.pauseOverlay()
end

function modes.gameover(inp)
    -- The lockout stops a frantic last dodge from skipping the
    -- score screen before the player has seen it.
    if G.modeT > C.LOCKOUT and inp.confirm then
        G.setMode("title")
    end
    Draw.play()
    Draw.gameoverOverlay()
end
-- endsnip

-- snip: loop
local frame = 0

local function tick()
    G.t = G.t + C.DT
    G.modeT = G.modeT + C.DT
    modes[G.mode](Input.gather(frame))
    Harness.set("mode", G.mode)
end

function playdate.update()
    frame = frame + 1
    Harness.frame(frame, tick)
end
-- endsnip
