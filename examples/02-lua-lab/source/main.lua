-- Chapter 2: Lua the Playdate Way.
-- A four-page lab. Each page draws on-screen proof of one claim
-- about the runtime; flip pages with left/right on the d-pad.

import "CoreLibs/graphics"
import "CoreLibs/object"
import "shots"
import "bookharness"

-- snip: imports
import "alpha"   -- defines Alpha, sets the global SHARED
import "alpha"   -- a second import runs NOTHING (page 1 proves it)
import "beta"    -- defines Beta; reads SHARED while loading
import "lab"     -- the page framework and all four proofs
-- endsnip

local frame = 0

local function tick()
    local bot = Harness.input(frame)
    local right = bot and bot.right
        or playdate.buttonJustPressed(playdate.kButtonRight)
    local left = bot and bot.left
        or playdate.buttonJustPressed(playdate.kButtonLeft)
    if right then
        Lab.turn(1)
        Harness.count("turns")
    end
    if left then Lab.turn(-1) end
    Lab.draw()
end

function playdate.update()
    frame = frame + 1
    Harness.frame(frame, tick)
end
