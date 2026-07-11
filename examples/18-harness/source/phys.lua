-- Chapter 14's mover, minus the one-way platforms: AABB actors
-- ({x, y} center, {hw, hh} half extents) against the tile grid,
-- axis-separated, 1px substeps.

Phys = {}

local function sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
end

-- is the box at (x, y) overlapping any solid tile?
function Phys.blocked(x, y, hw, hh)
    local tx0, ty0 = Map.tileAt(x - hw, y - hh)
    local tx1, ty1 = Map.tileAt(x + hw - 0.01, y + hh - 0.01)
    for ty = ty0, ty1 do
        for tx = tx0, tx1 do
            if Map.solid(tx, ty) then return true end
        end
    end
    return false
end

-- Axis-separated move in 1px substeps. Mutates a.x/a.y and
-- returns hitX, hitY (Chapter 14).
function Phys.move(a, dx, dy)
    local hitX, hitY = false, false
    local sx, rem = sign(dx), math.abs(dx)
    while rem > 0 do
        local step = math.min(1, rem)
        if Phys.blocked(a.x + sx * step, a.y, a.hw, a.hh) then
            hitX = true
            break
        end
        a.x = a.x + sx * step
        rem = rem - step
    end
    local sy = sign(dy)
    rem = math.abs(dy)
    while rem > 0 do
        local step = math.min(1, rem)
        if Phys.blocked(a.x, a.y + sy * step, a.hw, a.hh) then
            hitY = true
            break
        end
        a.y = a.y + sy * step
        rem = rem - step
    end
    return hitX, hitY
end
