-- Chapter 8: rotation matrices, perspective projection, and the
-- three wireframe models. Same shape as phosphor's vec/mat.lua
-- and vec/proj.lua, trimmed to what one screen needs.

local gfx <const> = playdate.graphics

-- snip: mat
-- 3x3 rotation matrices as flat row-major 9-arrays.
Mat = {}

function Mat.rx(t)
    local s, c = math.sin(t), math.cos(t)
    return { 1, 0, 0, 0, c, -s, 0, s, c }
end

function Mat.ry(t)
    local s, c = math.sin(t), math.cos(t)
    return { c, 0, s, 0, 1, 0, -s, 0, c }
end

function Mat.mul(a, b)
    local m = {}
    for r = 0, 2 do
        for c = 1, 3 do
            m[r * 3 + c] = a[r * 3 + 1] * b[c]
                + a[r * 3 + 2] * b[c + 3]
                + a[r * 3 + 3] * b[c + 6]
        end
    end
    return m
end

function Mat.apply(m, x, y, z)
    return m[1] * x + m[2] * y + m[3] * z,
        m[4] * x + m[5] * y + m[6] * z,
        m[7] * x + m[8] * y + m[9] * z
end
-- endsnip

-- snip: proj
-- Perspective projection: camera at the origin looking down +Z.
-- A point projects by dividing x and y by its depth.
Proj = {
    cx = 200, cy = 120,   -- screen center
    focal = 210,          -- ~60 degree FOV on a 400px screen
    near = 0.5,           -- nothing closer than this draws
}

function Proj.point(x, y, z)
    if z < Proj.near then return nil end
    local k = Proj.focal / z
    return Proj.cx + x * k, Proj.cy - y * k
end
-- endsnip

-- snip: models
-- A model is a flat vertex array {x,y,z, x,y,z, ...} plus a flat
-- edge array of 1-based vertex index pairs {a,b, a,b, ...}.
Models = {}

Models.cube = {
    name = "cube",
    verts = {
        -1, -1, -1, 1, -1, -1, 1, 1, -1, -1, 1, -1,
        -1, -1, 1, 1, -1, 1, 1, 1, 1, -1, 1, 1,
    },
    edges = {
        1, 2, 2, 3, 3, 4, 4, 1,     -- back face
        5, 6, 6, 7, 7, 8, 8, 5,     -- front face
        1, 5, 2, 6, 3, 7, 4, 8,     -- the connecting struts
    },
}

Models.pyramid = {
    name = "pyramid",
    verts = {
        -1, -1, -1, 1, -1, -1, 1, -1, 1, -1, -1, 1,
        0, 1.2, 0,
    },
    edges = { 1, 2, 2, 3, 3, 4, 4, 1, 1, 5, 2, 5, 3, 5, 4, 5 },
}

-- Icosahedron: three golden-ratio rectangles; the 30 edges are
-- found by distance (every edge has squared length 4).
local function icosahedron()
    local p = (1 + math.sqrt(5)) / 2
    local v = {
        -1, p, 0, 1, p, 0, -1, -p, 0, 1, -p, 0,
        0, -1, p, 0, 1, p, 0, -1, -p, 0, 1, -p,
        p, 0, -1, p, 0, 1, -p, 0, -1, -p, 0, 1,
    }
    local e = {}
    for i = 1, 12 do
        for j = i + 1, 12 do
            local ax, ay, az = v[i*3-2], v[i*3-1], v[i*3]
            local bx, by, bz = v[j*3-2], v[j*3-1], v[j*3]
            local d = (ax-bx)^2 + (ay-by)^2 + (az-bz)^2
            if math.abs(d - 4) < 0.001 then
                e[#e + 1] = i
                e[#e + 1] = j
            end
        end
    end
    -- normalize the radius to match the cube's (sqrt 3)
    local s = math.sqrt(3) / math.sqrt(1 + p * p)
    for i = 1, #v do v[i] = v[i] * s end
    return { name = "icosahedron", verts = v, edges = e }
end
Models.icosa = icosahedron()
-- endsnip

-- snip: draw-model
-- Rotate every vertex by m, push the model out to depth z, then
-- draw each edge -- skipping any edge that crosses the near
-- plane (phosphor's Proj.line clips these by interpolation).
local sx, sy = {}, {}   -- projected-vertex scratch, reused

function Models.draw(model, m, z, scale)
    local v = model.verts
    local n = 0
    for i = 1, #v - 2, 3 do
        local x, y, d = Mat.apply(m,
            v[i] * scale, v[i + 1] * scale, v[i + 2] * scale)
        n = n + 1
        sx[n], sy[n] = Proj.point(x, y, d + z)
    end
    local e = model.edges
    for i = 1, #e - 1, 2 do
        local a, b = e[i], e[i + 1]
        if sx[a] and sx[b] then
            gfx.drawLine(sx[a], sy[a], sx[b], sy[b])
        end
    end
end
-- endsnip

-- snip: stars
-- Three parallax layers. Each star is {x, y, layer}; the crank
-- angle pans the sky, near layers moving more than far ones.
Stars = { list = {}, SPEED = { 0.4, 0.9, 1.8 } }

function Stars.init(n)
    for i = 1, n do
        Stars.list[i] = {
            math.random(0, 399), math.random(0, 239),
            math.random(1, 3),
        }
    end
end

function Stars.draw(yawDeg)
    gfx.setColor(gfx.kColorWhite)
    for _, s in ipairs(Stars.list) do
        local x = (s[1] - yawDeg * Stars.SPEED[s[3]]) % 400
        if s[3] == 3 then
            gfx.fillCircleAtPoint(x, s[2], 1)
        else
            gfx.drawPixel(x, s[2])
        end
    end
end
-- endsnip
