-- vendored from phosphor/vec/vec.lua (MIT)
-- Phosphor core: 2D vector math, clamp, and the delayed-call scheduler.
-- Util is kept as a compatibility alias so games written before the library
-- (and code style across the package) stay uniform.

Vec = {}
Util = Util or {}

-- snip: vec-ops
function Vec.len(x, y)
    return math.sqrt(x * x + y * y)
end

function Vec.norm(x, y)
    local l = Vec.len(x, y)
    if l < 1e-6 then return 0, 0, 0 end
    return x / l, y / l, l
end

-- NOTE: Vec.rot alone takes RADIANS; every other Vec angle API is in
-- degrees. Prefer Vec.rotDeg unless you already have radians in hand.
function Vec.rot(x, y, rad)
    local c, s = math.cos(rad), math.sin(rad)
    return x * c - y * s, x * s + y * c
end

function Vec.rotDeg(x, y, deg)
    return Vec.rot(x, y, math.rad(deg))
end
-- endsnip

-- snip: vec-angles
function Vec.fromAngle(deg, mag)
    local rad = math.rad(deg)
    return math.cos(rad) * (mag or 1), math.sin(rad) * (mag or 1)
end

function Vec.angleOf(x, y)
    return math.deg(math.atan(y, x))
end

-- shortest signed difference between two angles, degrees
function Vec.angleDiff(from, to)
    return (to - from + 540) % 360 - 180
end
-- endsnip

function Vec.lerp(a, b, t)
    return a + (b - a) * t
end

function Util.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local pending = {}

function Util.after(delay, fn)
    pending[#pending + 1] = { t = delay, fn = fn }
end

function Util.runPending(dt)
    for i = #pending, 1, -1 do
        local p = pending[i]
        p.t = p.t - dt
        if p.t <= 0 then
            table.remove(pending, i)
            p.fn()
        end
    end
end

function Util.clearPending()
    pending = {}
end
