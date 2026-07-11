-- Chapter 15: Game Feel. A bouncing-collect scene with every
-- effect behind one switch, plus an easing-curve gallery.

import "CoreLibs/graphics"
import "CoreLibs/easing"
import "CoreLibs/timer"
import "CoreLibs/animator"
import "CoreLibs/animation"
import "shots"
import "bookharness"
import "util"
import "fx"
import "scene"
import "gallery"

local gfx <const> = playdate.graphics

DT = 1 / 30

local frame = 0
local mode = "scene"

-- snip: blinker
-- the FX ON label blinks via the SDK's blinker helper
local blinker = gfx.animation.blinker.new(300, 200, true)
blinker:startLoop()
-- endsnip

Scene.reset()

local function gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    return {
        toggleFx =
            playdate.buttonJustPressed(playdate.kButtonA),
        gallery =
            playdate.buttonJustPressed(playdate.kButtonB),
    }
end

-- snip: update
function playdate.update()
    -- both SDK helpers need their update calls every frame;
    -- forget these and timers/blinkers silently never fire
    playdate.timer.updateTimers()
    gfx.animation.blinker.updateAll()
    Util.tick()

    local inp = gather(frame)
    if inp.toggleFx then Fx.on = not Fx.on end
    if inp.gallery then
        mode = (mode == "scene") and "gallery" or "scene"
    end

    if mode == "scene" then
        if not Fx.frozen() then   -- hitstop skips the sim
            Scene.update()
            Fx.update(DT)
        end
        Scene.draw(blinker.on)
    else
        Gallery.draw()
    end
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
