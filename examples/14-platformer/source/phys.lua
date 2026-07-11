-- Physics: AABB actors ({x, y} center, {hw, hh} half extents)
-- moved against the tile grid with axis separation and 1px
-- substeps. Distilled from tiles/core/tphys.lua.

Phys = {}

local function sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 end
    return 0
end

-- snip: blocked
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
-- endsnip

-- snip: oneway
-- Moving down by `step`: do the actor's feet cross the top edge
-- of a one-way platform tile this substep? Only then does the
-- platform act solid -- from below or from the side it is air.
local function landsOnPlatform(x, y, hw, hh, step)
    local t = Map.TILE
    local feet = y + hh
    local rowOld = math.floor((feet - 0.01) / t)
    local rowNew = math.floor((feet + step - 0.01) / t)
    if rowNew == rowOld then return false end
    local ty = rowNew + 1
    local tx0 = math.floor((x - hw) / t) + 1
    local tx1 = math.floor((x + hw - 0.01) / t) + 1
    for tx = tx0, tx1 do
        if Map.oneWay(tx, ty) then return true end
    end
    return false
end
-- endsnip

-- is the actor standing on a one-way platform (and not on
-- solid ground)? Used to decide whether "down" can drop through.
function Phys.onOneWay(a)
    return landsOnPlatform(a.x, a.y, a.hw, a.hh, 1)
        and not Phys.blocked(a.x, a.y + 1, a.hw, a.hh)
end

-- snip: move
-- Axis-separated move in 1px substeps. Mutates a.x/a.y and
-- returns hitX, hitY. Substeps mean a fast actor can never skip
-- a tile: it advances at most one pixel per collision test.
-- `dropping` disables one-way platforms (drop-through).
function Phys.move(a, dx, dy, dropping)
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
        local hit = Phys.blocked(a.x, a.y + sy * step, a.hw, a.hh)
        if not hit and sy > 0 and not dropping then
            hit = landsOnPlatform(a.x, a.y, a.hw, a.hh, step)
        end
        if hit then
            hitY = true
            break
        end
        a.y = a.y + sy * step
        rem = rem - step
    end
    return hitX, hitY
end
-- endsnip
