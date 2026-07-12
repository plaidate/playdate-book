-- vendored from dither/core/shade.lua (MIT)
-- Dither core: the ramp system. 17 pattern levels (0 = white .. 16 =
-- black) derived from the Bayer 8x8 threshold matrix (plus a fixed
-- blue-noise ramp). Three forms per level: opaque (set/fill/grads),
-- black-speckle overlay (over) and white-speckle overlay (wash).
-- Everything precomputed at import; zero allocation at draw time.

local gfx = playdate.graphics

Shade = {}

Shade.LEVELS = 16 -- levels run 0..16 inclusive

-- snip: bayer
-- Bayer 8x8 threshold matrix (values 0..63), built recursively:
-- B2 = [[0,2],[3,1]], B2n[y][x] = 4*Bn[y%n][x%n] + B2[y*2//n][x*2//n]
local BAYER = {}
do
    local b = { { 0 } }
    local n = 1
    while n < 8 do
        local m = {}
        for y = 0, 2 * n - 1 do
            m[y + 1] = {}
            for x = 0, 2 * n - 1 do
                local q = b[y % n + 1][x % n + 1] * 4
                local sub = (y >= n and 1 or 0) * 2 + (x >= n and 1 or 0)
                -- quadrant order 0,2 / 3,1
                local add = (sub == 0 and 0) or (sub == 1 and 2)
                    or (sub == 2 and 3) or 1
                m[y + 1][x + 1] = q + add
            end
        end
        b = m
        n = n * 2
    end
    BAYER = b
end
-- endsnip

-- Fixed 8x8 blue-noise-ish rank table (0..63), annealed offline for
-- hierarchical spread — softer texture than Bayer's crosshatch.
local NOISE = {
    { 30, 17,  2, 63, 29, 16, 52, 43 },
    { 39, 51, 33, 13, 44,  7, 26, 61 },
    {  4, 23,  9, 55, 38, 21, 34, 12 },
    { 19, 59, 47, 27,  3, 58, 48, 54 },
    { 41,  1, 35, 18, 42, 14,  8, 28 },
    { 32, 15, 53, 60, 31, 46, 24, 62 },
    {  6, 45, 25, 10,  5, 20, 36, 50 },
    { 22, 57, 37, 49, 40, 56,  0, 11 },
}

-- snip: make-ramp
-- Build the three pattern tables for one threshold matrix. Playdate
-- patterns: row bytes, bit set = white pixel. Level k blackens pixels
-- whose threshold < k*4, so k/16 is the exact black coverage.
local function makeRamp(thr)
    local pat, over, wash = {}, {}, {}
    for k = 0, 16 do
        local cut = k * 4
        local p, o, w = {}, {}, {}
        for y = 1, 8 do
            local row = 0xFF
            for x = 1, 8 do
                if thr[y][x] < cut then
                    row = row & ~(1 << (8 - x))
                end
            end
            local inv = ~row & 0xFF
            p[y] = row
            o[y] = 0x00      -- overlay bitmap: drawn pixels are black
            o[y + 8] = inv   -- alpha: opaque only where ramp is black
            w[y] = 0xFF      -- wash bitmap: drawn pixels are white
            w[y + 8] = inv   -- same coverage, painted white
        end
        pat[k], over[k], wash[k] = p, o, w
    end
    return { pat = pat, over = over, wash = wash }
end
-- endsnip

local ramps = {
    bayer = makeRamp(BAYER),
    noise = makeRamp(NOISE),
}

-- quantize a fractional level to the ramp's 0..16 steps
function Shade.quant(level)
    local k = math.floor(level + 0.5)
    if k < 0 then return 0 elseif k > 16 then return 16 end
    return k
end

-- pattern-level table for a named ramp ('bayer' | 'noise'), indexable
-- 0..16 — hand these straight to gfx.setPattern / setStencilPattern
function Shade.ramp(name)
    return ramps[name].pat
end

-- snip: shade-api
-- opaque gray: paints both black and white pixels (terrain, panels)
function Shade.set(level, ramp)
    gfx.setPattern(ramps[ramp or "bayer"].pat[Shade.quant(level)])
end

-- black-speckle overlay: only the black pixels draw, the scene shows
-- through the rest (darkening: lights, shadows, dissolves)
function Shade.over(level, ramp)
    gfx.setPattern(ramps[ramp or "bayer"].over[Shade.quant(level)])
end

-- white-speckle overlay at the same coverage (haze, glare)
function Shade.wash(level, ramp)
    gfx.setPattern(ramps[ramp or "bayer"].wash[Shade.quant(level)])
end
-- endsnip

function Shade.fill(x, y, w, h, level, ramp)
    Shade.set(level, ramp)
    gfx.fillRect(x, y, w, h)
end

function Shade.disc(x, y, r, level, ramp)
    Shade.set(level, ramp)
    gfx.fillCircleAtPoint(x, y, r)
end

-- snip: shade-vgrad
-- banded vertical gradient: the span quantizes into <= 17 bands, one
-- opaque pattern fill each (top = l0, bottom = l1)
function Shade.vgrad(x, y, w, h, l0, l1, ramp)
    local span = math.abs(l1 - l0)
    local n = math.floor(span + 0.5) + 1
    if n > h then n = h end
    if n > 17 then n = 17 end
    if n < 1 then n = 1 end
    for i = 0, n - 1 do
        local y0 = y + math.floor(h * i / n)
        local y1 = y + math.floor(h * (i + 1) / n)
        local t = (n == 1) and 0 or (i / (n - 1))
        Shade.set(l0 + (l1 - l0) * t, ramp)
        gfx.fillRect(x, y0, w, y1 - y0)
    end
end
-- endsnip

-- banded horizontal gradient (left = l0, right = l1)
function Shade.hgrad(x, y, w, h, l0, l1, ramp)
    local span = math.abs(l1 - l0)
    local n = math.floor(span + 0.5) + 1
    if n > w then n = w end
    if n > 17 then n = 17 end
    if n < 1 then n = 1 end
    for i = 0, n - 1 do
        local x0 = x + math.floor(w * i / n)
        local x1 = x + math.floor(w * (i + 1) / n)
        local t = (n == 1) and 0 or (i / (n - 1))
        Shade.set(l0 + (l1 - l0) * t, ramp)
        gfx.fillRect(x0, y, x1 - x0, h)
    end
end
