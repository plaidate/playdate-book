-- Chapter 8: Vector Graphics and Faking 3D.
-- Crank-spun wireframe solids over a parallax starfield. The
-- crank is yaw; a slow pitch runs on its own. A changes solids.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "wire"

local gfx <const> = playdate.graphics

local frame = 0
local ORDER <const> = { "cube", "pyramid", "icosa" }
local pick = 1

Stars.init(90)

-- snip: update
function playdate.update()
    local bot = Harness.input(frame)
    local crank
    if bot then
        crank = bot.crank
        pick = math.min(3, math.ceil(frame / 80))
    else
        crank = playdate.getCrankPosition()
        if playdate.buttonJustPressed(playdate.kButtonA) then
            pick = pick % 3 + 1
        end
    end

    local yaw = math.rad(crank)
    local pitch = frame * 0.008
    local m = Mat.mul(Mat.rx(pitch), Mat.ry(yaw))

    gfx.clear(gfx.kColorBlack)
    Stars.draw(crank)

    gfx.setColor(gfx.kColorWhite)
    gfx.setLineWidth(1)
    local model = Models[ORDER[pick]]
    Models.draw(model, m, 4.2, 1.1)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("*" .. model.name .. "*", 8, 8)
    gfx.drawTextAligned(
        string.format("crank %d deg", crank % 360),
        392, 8, kTextAlignment.right)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
