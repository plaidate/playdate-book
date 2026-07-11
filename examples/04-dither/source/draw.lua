-- Chapter 4: everything drawn here comes from the primitive set.
-- Draw is a global module table: `import` shares one global
-- environment, so this is how the shipped games split files.

local gfx <const> = playdate.graphics

Draw = {}

-- snip: gray-helper
local DTH <const> = gfx.image.kDitherTypeBayer4x4

local function blk() gfx.setColor(gfx.kColorBlack) end
local function wht() gfx.setColor(gfx.kColorWhite) end

-- d is DARKNESS (0 white .. 1 black). setDitherPattern's argument
-- is transparency (low value = darker), so invert d to get the
-- intuitive scale.
local function gray(d)
    gfx.setDitherPattern(1 - d, DTH)
end
-- endsnip

-- a small labelled caption under a demo cell
local function label(s, cx, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    blk()
    gfx.drawTextAligned(s, cx, y, kTextAlignment.center)
end

local function title(s)
    blk()
    gfx.drawTextAligned("*" .. s .. "*", 200, 6,
        kTextAlignment.center)
end

-- Screen 1: the dither ladder. Nine swatches of gray(d) for d in
-- eighths from 0 (white) to 1 (black).
-- snip: ladder
local LABELS <const> = {
    "0", "1/8", "1/4", "3/8", "1/2", "5/8", "3/4", "7/8", "1",
}

function Draw.ladder()
    title("gray(d): darkness 0 .. 1, Bayer 4x4")
    local w, h, y = 38, 120, 50
    for i = 0, 8 do
        local x = 21 + i * 40
        gray(i / 8)
        gfx.fillRect(x, y, w, h)
        blk()
        gfx.drawRect(x, y, w, h)
        label(LABELS[i + 1], x + w / 2, y + h + 8)
    end
    label("d = darkness; the API argument is 1 - d", 200, 204)
end
-- endsnip

-- Screen 2: hand-built setPattern fills vs setDitherPattern types
-- at the same darkness.
-- snip: patterns
-- an 8-byte pattern is 8 rows of 8 pixels; bit set = white
local PAT <const> = {
    LIGHT = { 0xFF, 0xDD, 0xFF, 0xFF, 0xFF, 0x77, 0xFF, 0xFF },
    MID   = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 },
    DARK  = { 0x11, 0x00, 0x44, 0x00, 0x11, 0x00, 0x44, 0x00 },
    STRIPE = { 0x0F, 0x0F, 0x0F, 0x0F, 0xF0, 0xF0, 0xF0, 0xF0 },
}

local TYPES <const> = {
    { "Bayer 2x2", gfx.image.kDitherTypeBayer2x2 },
    { "Bayer 4x4", gfx.image.kDitherTypeBayer4x4 },
    { "Bayer 8x8", gfx.image.kDitherTypeBayer8x8 },
    { "Floyd-S.", gfx.image.kDitherTypeFloydSteinberg },
    { "Atkinson", gfx.image.kDitherTypeAtkinson },
    { "Screen", gfx.image.kDitherTypeScreen },
}

function Draw.patterns()
    title("setPattern vs setDitherPattern")
    local names = { "LIGHT", "MID", "DARK", "STRIPE" }
    for i, name in ipairs(names) do
        local x = 24 + (i - 1) * 92
        gfx.setPattern(PAT[name])
        gfx.fillRect(x, 40, 68, 48)
        blk()
        gfx.drawRect(x, 40, 68, 48)
        label(name, x + 34, 92)
    end
    for i, t in ipairs(TYPES) do
        local x = 16 + (i - 1) * 62
        gfx.setDitherPattern(0.5, t[2])
        gfx.fillRect(x, 128, 52, 48)
        blk()
        gfx.drawRect(x, 128, 52, 48)
        label(t[1], x + 26, 180)
    end
    label("top: 8-byte patterns    bottom: 50% by type", 200, 204)
end
-- endsnip

-- Screen 3: the primitive set, one cell each.
-- snip: primitives
local function cell(i, name, fn)
    local col, row = (i - 1) % 4, (i - 1) // 4
    local x, y = 8 + col * 98, 28 + row * 92
    gfx.setClipRect(x, y, 90, 64)   -- demos cannot leak out
    fn(x, y)
    gfx.clearClipRect()
    blk()
    gfx.setLineWidth(1)
    gfx.drawRect(x, y, 90, 64)
    label(name, x + 45, y + 68)
end

function Draw.primitives()
    title("the primitive set")
    cell(1, "line + width", function(x, y)
        blk()
        for i = 0, 3 do
            gfx.setLineWidth(1 + i * 2)
            gfx.drawLine(x + 10, y + 10 + i * 13,
                x + 80, y + 16 + i * 13)
        end
        gfx.setLineWidth(1)
    end)
    cell(2, "rect + round", function(x, y)
        blk()
        gfx.drawRect(x + 8, y + 8, 34, 48)
        gray(0.5)
        gfx.fillRoundRect(x + 48, y + 8, 34, 48, 8)
        blk()
        gfx.drawRoundRect(x + 48, y + 8, 34, 48, 8)
    end)
    cell(3, "circle/ellipse", function(x, y)
        gray(0.25)
        gfx.fillCircleAtPoint(x + 24, y + 32, 20)
        blk()
        gfx.drawCircleAtPoint(x + 24, y + 32, 20)
        gfx.drawEllipseInRect(x + 50, y + 12, 34, 40)
    end)
    cell(4, "arc", function(x, y)
        blk()
        gfx.setLineWidth(3)
        -- degrees, clockwise, 0 = twelve o'clock
        gfx.drawArc(x + 45, y + 32, 22, 0, 270)
        gfx.setLineWidth(1)
        gfx.drawArc(x + 45, y + 32, 14, 180, 90)
    end)
    cell(5, "triangle", function(x, y)
        gray(0.75)
        gfx.fillTriangle(x + 12, y + 54, x + 45, y + 8,
            x + 78, y + 54)
        blk()
        gfx.drawTriangle(x + 12, y + 54, x + 45, y + 8,
            x + 78, y + 54)
    end)
    cell(6, "polygon", function(x, y)
        gray(0.5)
        gfx.fillPolygon(x + 12, y + 30, x + 34, y + 8,
            x + 78, y + 22, x + 60, y + 56, x + 24, y + 50)
        blk()
        gfx.drawPolygon(x + 12, y + 30, x + 34, y + 8,
            x + 78, y + 22, x + 60, y + 56, x + 24, y + 50)
    end)
    cell(7, "stroke loc.", function(x, y)
        blk()
        gfx.setLineWidth(5)
        gfx.setStrokeLocation(gfx.kStrokeInside)
        gfx.drawRect(x + 10, y + 12, 30, 40)
        gfx.setStrokeLocation(gfx.kStrokeOutside)
        gfx.drawRect(x + 52, y + 12, 30, 40)
        gfx.setStrokeLocation(gfx.kStrokeCentered)
        gfx.setLineWidth(1)
    end)
    cell(8, "clip rect", function(x, y)
        gfx.setClipRect(x + 12, y + 10, 50, 44)
        blk()
        gfx.fillCircleAtPoint(x + 62, y + 32, 26)
        gfx.clearClipRect()
        blk()
        gfx.drawRect(x + 12, y + 10, 50, 44)
    end)
end
-- endsnip

-- Screen 4: a UI kit built from the pieces above -- the same
-- panel / ribbon / meter trio the shipped games use.
-- snip: uikit
local function panel(x, y, w, h)
    wht(); gfx.fillRoundRect(x, y, w, h, 6)
    blk(); gfx.drawRoundRect(x, y, w, h, 6)
end

-- black rounded bar with knocked-out white text
local function ribbon(text, cy)
    local tw, th = gfx.getTextSize(text)
    local pad = 12
    blk()
    gfx.fillRoundRect(200 - tw / 2 - pad, cy - th / 2 - 5,
        tw + pad * 2, th + 10, 5)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(text, 200, cy - th / 2,
        kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function meter(x, y, w, frac, lab)
    if lab then blk(); gfx.drawText(lab, x, y - 16) end
    blk(); gfx.drawRoundRect(x, y, w, 9, 2)
    local fw = math.max(0, (w - 4) * math.min(frac, 1))
    if fw > 0 then gfx.fillRoundRect(x + 2, y + 2, fw, 5, 1) end
end

function Draw.uikit()
    gray(0.25)                        -- a field behind the UI
    gfx.fillRect(0, 0, 400, 240)
    ribbon("*THE UI KIT*", 30)
    panel(60, 56, 280, 120)
    blk()
    gfx.drawText("A panel, a ribbon, two meters.", 76, 68)
    meter(76, 110, 248, 0.65, "health")
    meter(76, 148, 248, 0.30, "charge")
    ribbon("Ⓐ next screen", 208)
end
-- endsnip

-- snip: reset
-- Reset shared state before handing the frame back: the next
-- caller expects solid black, hairlines, copy mode.
function Draw.reset()
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.setStrokeLocation(gfx.kStrokeCentered)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.clearClipRect()
end
-- endsnip
