-- Chapter 5: Images, Imagetables, and Fonts.
-- A walker animated from a generated imagetable crosses a tilemap
-- strip; scaled and rotated stamps decorate the sky. B (or the
-- script) switches to a draw-mode gallery.

import "CoreLibs/graphics"
import "CoreLibs/animation"
import "shots"
import "bookharness"
import "gen"

local gfx <const> = playdate.graphics

local frame = 0
local gallery = false

-- snip: scene-setup
local walkerTable = Gen.walker()
local walkLoop = gfx.animation.loop.new(100, walkerTable, true)
local titleImg = Gen.title("*IMAGES*")
local stampImg = walkerTable:getImage(1)

local tilemap = gfx.tilemap.new()
tilemap:setImageTable(Gen.tiles())
tilemap:setSize(25, 3)
for x = 1, 25 do
    tilemap:setTileAtPosition(x, 1, 2)   -- grass row
    tilemap:setTileAtPosition(x, 2, 3)   -- dirt rows
    tilemap:setTileAtPosition(x, 3, 3)
end
-- endsnip

local walkerX = -32

-- snip: scene-draw
local function scene()
    gfx.clear(gfx.kColorWhite)
    tilemap:draw(0, 192)                 -- one call, 75 tiles

    -- the animation loop picks the frame; we place it
    walkerX = walkerX + 2
    if walkerX > 400 then walkerX = -32 end
    walkLoop:draw(walkerX, 160)

    -- the same frame stamped scaled and rotated
    local tw = titleImg:getSize()
    titleImg:drawScaled(200 - tw * 1.5, 16, 3)
    stampImg:drawScaled(40, 84, 2)
    stampImg:drawRotated(200, 100, frame * 3)
    stampImg:drawRotated(310, 96, -frame * 2, 1.5)
    stampImg:draw(120, 96, gfx.kImageFlippedX)
end
-- endsnip

-- snip: modes-draw
local MODES <const> = {
    { "copy", gfx.kDrawModeCopy },
    { "fillWhite", gfx.kDrawModeFillWhite },
    { "fillBlack", gfx.kDrawModeFillBlack },
    { "XOR", gfx.kDrawModeXOR },
    { "inverted", gfx.kDrawModeInverted },
}

local function modesGallery()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("*setImageDrawMode*", 200, 8,
        kTextAlignment.center)
    for i, m in ipairs(MODES) do
        local x = 12 + (i - 1) * 78
        -- half the cell is black so both halves are visible
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x, 60, 64, 32)
        gfx.drawRect(x, 60, 64, 64)
        gfx.setImageDrawMode(m[2])
        stampImg:drawScaled(x + 4, 62, 1.8)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.drawTextAligned(m[1], x + 32, 132,
            kTextAlignment.center)
    end
    gfx.drawTextAligned(
        "same image, five modes, half-black background",
        200, 200, kTextAlignment.center)
end
-- endsnip

function playdate.update()
    local bot = Harness.input(frame)
    if bot then
        gallery = bot.gallery
        -- the loop runs on wall-clock time; pin it to the frame
        -- counter under the bot so figures are deterministic
        walkLoop.frame = (frame // 6) % 4 + 1
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        gallery = not gallery
    end
    if gallery then modesGallery() else scene() end
end

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
