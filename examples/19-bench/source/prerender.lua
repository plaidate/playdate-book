-- Before/after: the same 375-tile floor drawn tile by tile
-- every frame, versus pre-rendered once and blitted. The ms
-- readout on each screen is the whole argument.

local gfx <const> = playdate.graphics

Pre = {}

local TILE <const> = 16
local W <const>, H <const> = 25, 15
local ms <const> = playdate.getCurrentTimeMilliseconds

local bg = nil
local emaTiles, emaBlit = nil, nil
local px = 0    -- a moving marker so the scene is visibly live

-- snip: tiles
-- the "before": every tile, every frame
local function drawTiles()
    for y = 1, H do
        for x = 1, W do
            local sx, sy = (x - 1) * TILE, (y - 1) * TILE
            if (x + y) % 2 == 0 then
                gfx.setDitherPattern(0.5,
                    gfx.image.kDitherTypeBayer4x4)
                gfx.fillRect(sx, sy, TILE, TILE)
                gfx.setColor(gfx.kColorBlack)
            end
            gfx.drawRect(sx, sy, TILE, TILE)
        end
    end
end
-- endsnip

-- snip: prerender
-- the "after": the same tiles drawn ONCE into an image at load;
-- from then on a frame's background is a single blit
function Pre.build()
    bg = gfx.image.new(400, 240, gfx.kColorWhite)
    gfx.pushContext(bg)
    drawTiles()
    gfx.popContext()
end
-- endsnip

-- snip: ab
function Pre.update(mode)
    local t0 = ms()
    if mode == "tiles" then
        drawTiles()
    else
        bg:draw(0, 0)
    end
    local d = ms() - t0
    if mode == "tiles" then
        emaTiles = (emaTiles or d) * 0.9 + d * 0.1
    else
        emaBlit = (emaBlit or d) * 0.9 + d * 0.1
    end
end
-- endsnip

function Pre.draw(mode)
    -- the marker proves the scene really repaints every frame
    px = (px + 3) % 400
    gfx.fillCircleAtPoint(px, 200, 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(60, 92, 280, 52)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(60, 92, 280, 52)
    local label, ema
    if mode == "tiles" then
        label, ema = "375 tiles drawn per frame", emaTiles
    else
        label, ema = "one pre-rendered blit", emaBlit
    end
    gfx.drawTextAligned("*" .. label .. "*", 200, 102,
        kTextAlignment.center)
    gfx.drawTextAligned(string.format("%.1f ms", ema or 0),
        200, 124, kTextAlignment.center)
end
