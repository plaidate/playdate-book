-- vendored from phosphor/vec/shapes.lua (MIT)
-- Phosphor core: polyline shape models, drawn transformed.
--
-- A shape is a list of polylines; a polyline is a flat array {x1,y1,x2,y2,...}
-- in model space. Shapes.draw transforms by position/rotation/scale and draws
-- with gfx.drawLine. Field-wrapped drawing comes free via Shapes.drawWrapped.

local gfx <const> = playdate.graphics

Shapes = {}

function Shapes.new(polys)
    return polys
end

-- snip: shapes-draw
function Shapes.draw(shape, x, y, angleDeg, scale)
    scale = scale or 1
    local c, s = 1, 0
    if angleDeg and angleDeg ~= 0 then
        local rad = math.rad(angleDeg)
        c, s = math.cos(rad), math.sin(rad)
    end
    for p = 1, #shape do
        local poly = shape[p]
        local px, py
        for i = 1, #poly - 1, 2 do
            local mx, my = poly[i] * scale, poly[i + 1] * scale
            local rx = x + mx * c - my * s
            local ry = y + mx * s + my * c
            if px then
                gfx.drawLine(px, py, rx, ry)
            end
            px, py = rx, ry
        end
    end
end

local function drawOffset(ox, oy, shape, x, y, angleDeg, scale)
    Shapes.draw(shape, x + ox, y + oy, angleDeg, scale)
end

function Shapes.drawWrapped(shape, x, y, angleDeg, scale, r)
    Field.offsets(x, y, r or 24, drawOffset, shape, x, y, angleDeg, scale)
end
-- endsnip

-- snip: shapes-blob
-- a closed irregular polygon (asteroids, debris chunks): n vertices,
-- radius jittered between rMin..rMax fractions of r
function Shapes.blob(r, n, rMin, rMax)
    n = n or 11
    rMin = rMin or 0.72
    rMax = rMax or 1.17
    local poly = {}
    for i = 0, n do
        local a = (i % n) / n * 2 * math.pi
        local rad = (i == n) and poly.firstR or r * (rMin + math.random() * (rMax - rMin))
        if i == 0 then poly.firstR = rad end
        poly[#poly + 1] = math.cos(a) * rad
        poly[#poly + 1] = math.sin(a) * rad
    end
    poly.firstR = nil
    -- close the loop exactly
    poly[#poly - 1] = poly[1]
    poly[#poly] = poly[2]
    return { poly }
end
-- endsnip

-- regular n-gon outline (radius r), optionally spiky (alternating radii)
function Shapes.gon(r, n, r2)
    local poly = {}
    for i = 0, n do
        local a = (i % n) / n * 2 * math.pi
        local rad = (r2 and i % 2 == 1) and r2 or r
        poly[#poly + 1] = math.cos(a) * rad
        poly[#poly + 1] = math.sin(a) * rad
    end
    return { poly }
end
