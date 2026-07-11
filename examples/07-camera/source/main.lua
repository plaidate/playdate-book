-- Chapter 7: Cameras and Big Worlds.
-- A rover drives across a 1600x480 pre-rendered world; the camera
-- lerps after it inside a deadzone; the HUD stays put. B shakes.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "world"

local gfx <const> = playdate.graphics

local frame = 0
local rover = { x = 120, y = 330 }

World.build()

-- snip: rover
local function moveRover(dx)
    rover.x = rover.x + dx
    if rover.x > World.W - 20 then rover.x = World.W - 20 end
    if rover.x < 20 then rover.x = 20 end
    -- hug the terrain with a little bob
    rover.y = 330 + math.sin(rover.x * 0.02) * 14
end

local function drawRover()
    -- world coordinates: the draw offset places it on screen
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(rover.x - 12, rover.y - 10, 24, 12, 3)
    gfx.fillCircleAtPoint(rover.x - 7, rover.y + 4, 4)
    gfx.fillCircleAtPoint(rover.x + 7, rover.y + 4, 4)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(rover.x + 6, rover.y - 6, 2)
end
-- endsnip

-- snip: frame
function playdate.update()
    local bot = Harness.input(frame)
    local dx = 0
    if bot then
        dx = bot.move or 0
        if bot.shake then Cam.shake(6) end
    else
        if playdate.buttonIsPressed(playdate.kButtonRight) then
            dx = 4
        elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
            dx = -4
        end
        if playdate.buttonJustPressed(playdate.kButtonB) then
            Cam.shake(6)
        end
    end

    moveRover(dx)
    Cam.follow(rover.x, rover.y)

    gfx.clear(gfx.kColorWhite)
    Cam.apply()                    -- world space from here
    World.img:draw(0, 0)           -- the whole terrain: one blit
    drawRover()
    Cam.done()                     -- back to screen space

    -- HUD: drawn last, never scrolls
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 18)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("cam " .. math.floor(Cam.x)
        .. "  rover " .. math.floor(rover.x), 6, 1)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
