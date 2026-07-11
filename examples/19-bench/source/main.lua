-- Chapter 19: measure, don't guess. A live draw-cost ranking
-- plus a before/after of pre-rendered backgrounds.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "bench"
import "prerender"

local gfx <const> = playdate.graphics

DT = 1 / 30

local frame = 0
local screens <const> = { "bench", "tiles", "blit" }
local cur = 1

Pre.build()

local function gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    return {
        next = playdate.buttonJustPressed(playdate.kButtonB),
    }
end

-- snip: loop
function playdate.update()
    local inp = gather(frame)
    if inp.next then cur = cur % #screens + 1 end
    local screen = screens[cur]
    gfx.clear(gfx.kColorWhite)
    if screen == "bench" then
        Bench.update()
        Bench.draw()
    else
        Pre.update(screen)
        Pre.draw(screen)
    end
    gfx.drawText("Ⓑ next screen", 8, 222)
    Harness.set("screen", screen)
end
-- endsnip

-- snip: wrapper
-- Molt's meter on the book's wrapper: time the whole frame,
-- EMA it, and let the heartbeat carry the number out.
local realUpdate = playdate.update
local updMs = nil
function playdate.update()
    frame = frame + 1
    local t0 = playdate.getCurrentTimeMilliseconds()
    Harness.frame(frame, realUpdate)
    local d = playdate.getCurrentTimeMilliseconds() - t0
    updMs = (updMs or d) * 0.9 + d * 0.1
    Harness.set("updMs", math.floor(updMs * 10) / 10)
end
-- endsnip
