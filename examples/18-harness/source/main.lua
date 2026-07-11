-- Chapter 18: the Chapter 14 platformer, played by a robot.
-- pcall + heartbeat + autopilot: the game tests itself.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "map"
import "phys"
import "player"
import "coins"
import "pilot"

local gfx <const> = playdate.graphics

DT = 1 / 30

local frame = 0
local screen = "play"      -- "play" | "tele"

Map.build()
Player.reset()
Coins.reset()
Pilot.reset()

-- snip: gather
-- The seam (Chapter 9): the bot is consulted first, so one
-- build serves a human with a d-pad and a robot with a script.
local function gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    local held = playdate.buttonIsPressed
    return {
        left = held(playdate.kButtonLeft),
        right = held(playdate.kButtonRight),
        jump = held(playdate.kButtonA),
        tele = playdate.buttonJustPressed(playdate.kButtonB),
    }
end
-- endsnip

-- snip: hud
-- The counters double as a live HUD: when a number on screen
-- stops moving, you SEE the bug the heartbeat would report.
-- (In a release build the harness never counts, so this HUD is
-- a smoke-build instrument, not player UI.)
local function drawHud()
    local c = Harness.counters
    gfx.drawText(
        ("coins %d/%d  jumps %d  falls %d  skips %d"):format(
            c.coins or 0, c.spawns or 0, c.jumps or 0,
            c.falls or 0, c.spawnSkips or 0),
        8, 2)
end
-- endsnip

-- snip: telemetry
-- The heartbeat, on screen: every counter the harness holds,
-- exactly what lands in smoke.json every 90 frames.
local function drawTelemetry(frame)
    gfx.clear(gfx.kColorWhite)
    gfx.drawText("*telemetry* -- the smoke heartbeat", 12, 8)
    local keys = {}
    for k in pairs(Harness.counters) do keys[#keys + 1] = k end
    table.sort(keys)
    local y = 38
    for _, k in ipairs(keys) do
        gfx.drawText(k, 32, y)
        gfx.drawTextAligned(tostring(Harness.counters[k]),
            240, y, kTextAlignment.right)
        y = y + 20
    end
    gfx.drawText("frame " .. frame, 32, y + 10)
    gfx.drawText("Ⓑ back to the game", 240, 222)
end
-- endsnip

function playdate.update()
    local inp = gather(frame)
    if inp.tele then
        screen = (screen == "play") and "tele" or "play"
    end
    if screen == "tele" then
        drawTelemetry(frame)
        return
    end
    Player.update(inp)
    Coins.update()
    Map.draw()
    Coins.draw()
    Player.draw()
    drawHud()
end

-- snip: wrapper
-- The standard wrapper: every frame goes through the harness,
-- which pcalls the real update, captures shots, and reports.
local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
-- endsnip
