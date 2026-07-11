-- Chapter 6: The Sprite System.
-- A player square driven among walls and sensors, cycling the
-- four collision response types. A cycles modes; d-pad moves.

import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "shots"
import "bookharness"
import "playground"

local gfx <const> = playdate.graphics

local frame = 0
local phase = 0

-- snip: background
gfx.sprite.setBackgroundDrawingCallback(function(x, y, w, h)
    -- only the dirty rect (x,y,w,h) needs repainting; drawing it
    -- all is correct too, just slower
    gfx.setDitherPattern(0.9, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(x, y, w, h)
end)
-- endsnip

Playground.setup()

-- snip: update
function playdate.update()
    local bot = Harness.input(frame)
    local wantPhase, dx, dy
    if bot then
        wantPhase, dx, dy = bot.phase, bot.dx, bot.dy
    else
        wantPhase = Playground.mode
        if playdate.buttonJustPressed(playdate.kButtonA) then
            wantPhase = Playground.mode % 4 + 1
        end
        dx = (playdate.buttonIsPressed(playdate.kButtonRight)
            and 2 or 0)
            - (playdate.buttonIsPressed(playdate.kButtonLeft)
            and 2 or 0)
        dy = (playdate.buttonIsPressed(playdate.kButtonDown)
            and 2 or 0)
            - (playdate.buttonIsPressed(playdate.kButtonUp)
            and 2 or 0)
    end
    if wantPhase ~= phase then
        phase = wantPhase
        Playground.reset(phase)
    end

    Playground.move(dx, dy)
    gfx.sprite.update()      -- the sprite system draws here
    Playground.overlay()     -- immediate-mode debug on top
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
