-- vendored from tiles/core/tphys.lua (MIT)
-- Tiles core: actor movement against the tile map. Actors are AABBs
-- ({x, y} center px, {hw, hh} half extents) moved with 1px sub-steps and
-- axis separation. moveAssist adds the classic corner nudge (GB Zelda /
-- Bomberman feel): blocked on one axis but nearly aligned with an open
-- corridor -> slide toward alignment instead of grinding on the corner.

Phys = {}

-- shared by bfs/firstStep/descend so the hot paths allocate nothing
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- default solidity = the map's; games pass their own isSolid(tx, ty) to
-- add bombs, doors, water etc.
local function defaultSolid(tx, ty)
    return Map.solid(tx, ty)
end

-- is the box at (x, y) overlapping any solid tile?
function Phys.blocked(x, y, hw, hh, isSolid)
    isSolid = isSolid or defaultSolid
    local tx0, ty0 = Map.tileAt(x - hw, y - hh)
    local tx1, ty1 = Map.tileAt(x + hw - 0.01, y + hh - 0.01)
    for ty = ty0, ty1 do
        for tx = tx0, tx1 do
            if isSolid(tx, ty) then return true end
        end
    end
    return false
end

-- snip: phys-move
-- axis-separated 1px-substep move; mutates a.x/a.y, returns hitX, hitY
function Phys.move(a, dx, dy, isSolid)
    local hitX, hitY = false, false
    local sx = Util.sign(dx)
    local rem = math.abs(dx)
    while rem > 0 do
        local step = math.min(1, rem)
        if Phys.blocked(a.x + sx * step, a.y, a.hw, a.hh, isSolid) then
            hitX = true
            break
        end
        a.x = a.x + sx * step
        rem = rem - step
    end
    local sy = Util.sign(dy)
    rem = math.abs(dy)
    while rem > 0 do
        local step = math.min(1, rem)
        if Phys.blocked(a.x, a.y + sy * step, a.hw, a.hh, isSolid) then
            hitY = true
            break
        end
        a.y = a.y + sy * step
        rem = rem - step
    end
    return hitX, hitY
end
-- endsnip

-- snip: move-assist
-- move with corner assist: when blocked on the move axis but the tile
-- ahead at the actor's center row/column is open, nudge perpendicular
-- toward that row/column center (capped at the move speed, so corners
-- feel smooth, never faster)
function Phys.moveAssist(a, dx, dy, isSolid)
    local hitX, hitY = Phys.move(a, dx, dy, isSolid)
    local solidFn = isSolid or defaultSolid
    -- assist deliberately applies to cardinal input only (dy == 0 / dx == 0)
    if hitX and dy == 0 and dx ~= 0 then
        local tx, ty = Map.tileAt(a.x, a.y)
        if not solidFn(tx + Util.sign(dx), ty) then
            local off = Map.cy(ty) - a.y
            if off ~= 0 then
                Phys.move(a, 0, Util.clamp(off, -math.abs(dx), math.abs(dx)), isSolid)
                Phys.move(a, dx, 0, isSolid) -- retry the swallowed forward motion
            end
        end
    elseif hitY and dx == 0 and dy ~= 0 then
        local tx, ty = Map.tileAt(a.x, a.y)
        if not solidFn(tx, ty + Util.sign(dy)) then
            local off = Map.cx(tx) - a.x
            if off ~= 0 then
                Phys.move(a, Util.clamp(off, -math.abs(dy), math.abs(dy)), 0, isSolid)
                Phys.move(a, 0, dy, isSolid) -- retry the swallowed forward motion
            end
        end
    end
    return hitX, hitY
end
-- endsnip

-- the tile the actor's center is in
function Phys.cell(a)
    return Map.tileAt(a.x, a.y)
end

-- true when the actor is close to a cell center (for grid-locked turns)
function Phys.aligned(a, tol)
    tol = tol or 2
    local tx, ty = Map.tileAt(a.x, a.y)
    return math.abs(a.x - Map.cx(tx)) <= tol and math.abs(a.y - Map.cy(ty)) <= tol
end

-- snip: bfs
-- BFS over walkable tiles from (sx, sy); isOpen(tx, ty) says where you
-- can walk. Returns dist[ty][tx] (nil = unreachable). Shared by enemy
-- chase AI and every autopilot.
function Phys.bfs(sx, sy, isOpen)
    local dist = {}
    for y = 1, Map.H do dist[y] = {} end
    dist[sy][sx] = 0
    -- parallel coordinate queues: no per-cell table allocations
    local qx, qy, head, tail = { sx }, { sy }, 1, 1
    while head <= tail do
        local cx, cy = qx[head], qy[head]
        head = head + 1
        local d = dist[cy][cx] + 1
        for i = 1, 4 do
            local nx, ny = cx + DIRS[i][1], cy + DIRS[i][2]
            if nx >= 1 and nx <= Map.W and ny >= 1 and ny <= Map.H
                and dist[ny][nx] == nil and isOpen(nx, ny) then
                dist[ny][nx] = d
                tail = tail + 1
                qx[tail], qy[tail] = nx, ny
            end
        end
    end
    return dist
end
-- endsnip

-- snip: walkers
-- given a field rooted at the WALKER, trace back from a chosen target
-- (tx,ty) to the cell at distance 1 — the walker's first step. Returns
-- nx, ny or nil when already there / unreachable.
function Phys.firstStep(dist, tx, ty)
    local d = dist[ty] and dist[ty][tx]
    if not d or d == 0 then return nil end
    while d > 1 do
        local moved = false
        for i = 1, 4 do
            local nx, ny = tx + DIRS[i][1], ty + DIRS[i][2]
            if dist[ny] and dist[ny][nx] == d - 1 then
                tx, ty, d = nx, ny, d - 1
                moved = true
                break
            end
        end
        if not moved then return nil end
    end
    return tx, ty
end

-- first step from (sx,sy) toward smaller values in a BFS field rooted at
-- the target; returns dx, dy or nil when already there / unreachable
function Phys.descend(dist, sx, sy)
    local best = dist[sy] and dist[sy][sx]
    if not best then return nil end
    local bx, by
    for i = 1, 4 do
        local nx, ny = sx + DIRS[i][1], sy + DIRS[i][2]
        local d = dist[ny] and dist[ny][nx]
        if d and d < best then
            best, bx, by = d, DIRS[i][1], DIRS[i][2]
        end
    end
    return bx, by
end
-- endsnip
