-- Chapter 4: Drawing in One Bit.
-- Four demo screens: the dither ladder, pattern fills, the
-- primitive set, and a small UI kit. A cycles them.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "draw"

local gfx <const> = playdate.graphics

local frame = 0
local screen = 1
local SCREENS <const> = 4

-- snip: dispatch
function playdate.update()
    local bot = Harness.input(frame)
    if bot and bot.screen then
        screen = bot.screen
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        screen = screen % SCREENS + 1
    end

    gfx.clear(gfx.kColorWhite)
    if screen == 1 then Draw.ladder()
    elseif screen == 2 then Draw.patterns()
    elseif screen == 3 then Draw.primitives()
    else Draw.uikit() end
    Draw.reset()
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
