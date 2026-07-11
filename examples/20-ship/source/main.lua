-- Crankshot: the book's last example is a whole game -- small,
-- but FINISHED. Three modes, crank aim, sound, a saved record,
-- a difficulty ramp, and full launcher art in source/launcher/.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "config"
import "gamestate"
import "input"
import "save"
import "sfx"
import "game"
import "draw"

playdate.display.setRefreshRate(30)
if not Harness.enabled then
    math.randomseed(playdate.getSecondsSinceEpoch())
end
Save.load()

-- snip: modes
local modes = {}

function modes.title(inp)
    Game.aim(inp.pos)    -- the turret answers even on the title
    if inp.confirm then
        Game.reset()
        G.setMode("play")
    end
    Draw.title()
end

function modes.play(inp)
    Game.update(C.DT, inp)
    Draw.play()
end

function modes.gameover(inp)
    if G.modeT > C.LOCKOUT and inp.confirm then
        G.setMode("title")
    end
    Draw.gameover()
end
-- endsnip

-- snip: loop
local frame = 0

local function tick()
    G.t = G.t + C.DT
    G.modeT = G.modeT + C.DT
    modes[G.mode](Input.gather(frame))
    Harness.set("mode", G.mode)
    Harness.set("score", G.score)
end

function playdate.update()
    frame = frame + 1
    Harness.frame(frame, tick)
end
-- endsnip
