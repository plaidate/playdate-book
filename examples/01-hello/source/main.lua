-- Chapter 1: Hello, Playdate.
-- A greeting bounces around the screen; the A button counts presses.

import "CoreLibs/graphics"
import "shots"
import "bookharness"

-- snip: setup
local gfx <const> = playdate.graphics

local msg <const> = "Hello, Playdate!"
local x, y = 40, 60      -- text position, in pixels
local dx, dy = 2, 2      -- velocity, in pixels per frame
local presses = 0        -- how many times A has been pressed
-- endsnip

local frame = 0

-- snip: update
function playdate.update()
    -- Input: was A just pressed this frame?
    local bot = Harness.input(frame)
    local aPressed = bot and bot.aPressed
        or playdate.buttonJustPressed(playdate.kButtonA)
    if aPressed then
        presses = presses + 1
        Harness.count("presses")
    end

    -- Move, and bounce off the screen edges.
    local w, h = gfx.getTextSize(msg)
    x = x + dx
    y = y + dy
    if x < 0 or x + w > 400 then dx = -dx end
    if y < 0 or y + h > 216 then dy = -dy end

    -- Draw everything, every frame.
    gfx.clear(gfx.kColorWhite)
    gfx.drawText(msg, x, y)
    gfx.drawLine(0, 220, 400, 220)
    gfx.drawTextAligned("A pressed " .. presses .. " times", 200, 224,
        kTextAlignment.center)
end
-- endsnip

-- snip: wrapper
-- The harness wraps the real update in a pcall and captures the
-- book's figures; in a release build it calls straight through
-- (Chapter 18 explains all of this).
local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
-- endsnip
