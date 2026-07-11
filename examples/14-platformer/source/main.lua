-- Chapter 14: Movement, Collision, and Physics.
-- A compact tile platformer plus a substep-vs-tunneling demo.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "map"
import "phys"
import "player"
import "demo"

local gfx <const> = playdate.graphics

DT = 1 / 30  -- fixed timestep: all constants are per-second

local frame = 0
local mode = "play"

Map.build()
Player.reset()
Demo.reset()

-- snip: input
local function gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    local held = playdate.buttonIsPressed
    return {
        left  = held(playdate.kButtonLeft),
        right = held(playdate.kButtonRight),
        down  = held(playdate.kButtonDown),
        jump  = playdate.buttonJustPressed(playdate.kButtonA),
        demo  = playdate.buttonJustPressed(playdate.kButtonB),
    }
end
-- endsnip

function playdate.update()
    local inp = gather(frame)
    if inp.demo then
        mode = (mode == "play") and "demo" or "play"
        if mode == "demo" then Demo.reset() end
    end

    if mode == "play" then
        Player.update(inp)
        Map.draw()
        Player.draw()
        gfx.drawText("d-pad run  A jump  B demo", 8, 4)
        gfx.drawText("jumps " .. (Harness.counters.jumps or 0),
            330, 4)
    else
        Demo.update()
        Demo.draw()
    end
end

-- Standard harness wrapper (Chapter 18): pcall, shot capture,
-- heartbeat. In release builds it calls straight through.
local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
