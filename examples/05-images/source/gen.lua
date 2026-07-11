-- Chapter 5: procedural asset generation. Every image in this
-- example is drawn from primitives into offscreen images at boot,
-- with pushContext/popContext -- no bitmap files in the bundle.

local gfx <const> = playdate.graphics

Gen = {}

-- A four-frame walking robot as an imagetable. Each frame is a
-- 32x32 image; only the leg angles differ between frames.
-- snip: gen-walker
local function walkerFrame(phase)
    local img = gfx.image.new(32, 32)   -- transparent
    gfx.pushContext(img)                -- draws now hit img
    gfx.setColor(gfx.kColorBlack)
    -- legs: two lines swinging in opposite phase
    local swing = math.sin(phase) * 7
    gfx.setLineWidth(3)
    gfx.drawLine(16, 20, 16 - swing, 31)
    gfx.drawLine(16, 20, 16 + swing, 31)
    gfx.setLineWidth(1)
    -- body and eye
    gfx.fillRoundRect(8, 4, 16, 18, 4)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(19, 10, 3)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(20, 10, 1)
    gfx.popContext()                    -- back to the screen
    return img
end

function Gen.walker()
    local table = gfx.imagetable.new(4) -- empty, 4 slots
    for i = 1, 4 do
        local phase = (i - 1) / 4 * 2 * math.pi
        table:setImage(i, walkerFrame(phase))
    end
    return table
end
-- endsnip

-- Three 16x16 terrain tiles for the tilemap: sky, grass, dirt.
-- snip: gen-tiles
local function tile(fn)
    local img = gfx.image.new(16, 16, gfx.kColorWhite)
    gfx.pushContext(img)
    fn()
    gfx.popContext()
    return img
end

function Gen.tiles()
    local t = gfx.imagetable.new(3)
    t:setImage(1, tile(function() end))          -- sky: white
    t:setImage(2, tile(function()                -- grass
        gfx.setDitherPattern(0.75,
            gfx.image.kDitherTypeBayer4x4)
        gfx.fillRect(0, 0, 16, 16)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 16, 3)
    end))
    t:setImage(3, tile(function()                -- dirt
        gfx.setDitherPattern(0.4,
            gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, 16, 16)
    end))
    return t
end
-- endsnip

-- Text rendered into an image, so it can be scaled: the system
-- font has one size, but images scale.
-- snip: gen-title
function Gen.title(text)
    local w, h = gfx.getTextSize(text)
    local img = gfx.image.new(w, h)
    gfx.pushContext(img)
    gfx.drawText(text, 0, 0)
    gfx.popContext()
    return img
end
-- endsnip
