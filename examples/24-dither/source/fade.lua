-- vendored from dither/core/fade.lua (MIT)
-- Dither core: transitions and atmospherics, all drawn AFTER the
-- scene. Dissolve = one full-screen black-overlay fill whose level
-- tracks t through the 17 ramp steps; iris = four solid side rects +
-- one scale-drawn "hole" image with a baked dithered rim; wipe = a
-- solid front with a banded dithered leading edge; haze = white wash.

local gfx = playdate.graphics

Fade = {}

local W <const>, H <const> = 400, 240

-- snip: fade-dissolve
-- full-screen Bayer dissolve; t 0 (clear) .. 1 (black)
function Fade.dissolve(t)
    local k = Shade.quant(t * 16)
    if k <= 0 then return end
    if k >= 16 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, W, H)
        return
    end
    Shade.over(k)
    gfx.fillRect(0, 0, W, H)
    gfx.setColor(gfx.kColorBlack)
end
-- endsnip

-- snip: fade-iris
-- iris hole image, built once on first use: a black square with a
-- transparent disc punched out and a dithered annulus rim (inner 86%
-- .. 100% of the radius). Scale-drawing it stretches the rim dither a
-- little at big radii — acceptable, it reads as a soft edge.
local IRIS_S <const> = 512
local irisImg

local function irisInit()
    irisImg = gfx.image.new(IRIS_S, IRIS_S, gfx.kColorBlack)
    local c = IRIS_S / 2
    gfx.pushContext(irisImg)
    gfx.setColor(gfx.kColorClear)
    gfx.fillCircleAtPoint(c, c, c)          -- punch the hole
    Shade.over(8)
    gfx.fillCircleAtPoint(c, c, c)          -- speckle the whole disc
    gfx.setColor(gfx.kColorClear)
    gfx.fillCircleAtPoint(c, c, c * 0.86)   -- re-clear inside the rim
    gfx.popContext()
end
-- endsnip

-- closing iris on (x, y): t 0 = fully open (no-op) .. 1 = all black
function Fade.iris(x, y, t)
    if t <= 0 then return end
    gfx.setColor(gfx.kColorBlack)
    if t >= 1 then
        gfx.fillRect(0, 0, W, H)
        return
    end
    if not irisImg then irisInit() end
    -- radius shrinks from the farthest-corner distance to 0
    local dx = math.max(x, W - x)
    local dy = math.max(y, H - y)
    local r = (1 - t) * math.sqrt(dx * dx + dy * dy)
    local x0, y0 = math.floor(x - r + 0.5), math.floor(y - r + 0.5)
    local x1, y1 = math.floor(x + r + 0.5), math.floor(y + r + 0.5)
    gfx.fillRect(0, 0, W, y0)               -- solid surround
    gfx.fillRect(0, y1, W, H - y1)
    gfx.fillRect(0, y0, x0, y1 - y0)
    gfx.fillRect(x1, y0, W - x1, y1 - y0)
    irisImg:drawScaled(x0, y0, (x1 - x0) / IRIS_S)
end

-- directional wipe: dir 'left'|'right'|'up'|'down' is the direction
-- the black front advances; t 0..1. Leading edge is a 24px band of
-- four stepped overlay fills.
local BAND <const> = 24
local STEPS <const> = { 13, 9, 5, 2 } -- band slices, solid side first

function Fade.wipe(dir, t)
    if t <= 0 then return end
    local vert = (dir == "up" or dir == "down")
    local span = vert and H or W
    local front = t * (span + BAND)
    local solid = front - BAND
    local function slab(a, b, level)
        a = math.floor(Util.clamp(a, 0, span) + 0.5)
        b = math.floor(Util.clamp(b, 0, span) + 0.5)
        if b <= a then return end
        if level then Shade.over(level)
        else gfx.setColor(gfx.kColorBlack) end
        -- 'right'/'down' advance from the origin edge; 'left'/'up'
        -- start at the far edge, so mirror the slab
        local lo = a
        if dir == "left" or dir == "up" then lo = span - b end
        if vert then gfx.fillRect(0, lo, W, b - a)
        else gfx.fillRect(lo, 0, b - a, H) end
    end
    slab(0, solid, nil)
    local sw = BAND / #STEPS
    for i = 1, #STEPS do
        slab(solid + (i - 1) * sw, solid + i * sw, STEPS[i])
    end
    gfx.setColor(gfx.kColorBlack)
end

-- horizontal atmospheric band for parallax skylines: a white wash
-- between y0 and y1 at the given shade level (0 = none, 16 = solid)
function Fade.haze(y0, y1, level)
    local k = Shade.quant(level)
    if k <= 0 or y1 <= y0 then return end
    Shade.wash(k)
    gfx.fillRect(0, y0, W, y1 - y0)
    gfx.setColor(gfx.kColorBlack)
end
