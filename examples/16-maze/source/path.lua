-- Two pathfinders over the same maze: a hand-rolled BFS and
-- the SDK's A* (playdate.pathfinder). Both return a full path,
-- {c, r} per cell, start first -- so we can draw the overlays.

Path = {}

local DIRS <const> = {
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
}

-- snip: bfs
-- BFS from (sc, sr) to the nearest cell where goalfn is true.
-- A queue with a head index (no removals), a parent map for
-- the walk-back, and early exit on the first goal reached.
function Path.bfs(sc, sr, goalfn)
    local function key(c, r) return r * 100 + c end
    local parent = { [key(sc, sr)] = -1 }
    local q, head = { { sc, sr } }, 1
    local goal
    while q[head] do
        local cc, cr = q[head][1], q[head][2]
        head = head + 1
        if goalfn(cc, cr)
            and not (cc == sc and cr == sr) then
            goal = { cc, cr }
            break
        end
        for _, d in ipairs(DIRS) do
            local nc, nr = cc + d[1], cr + d[2]
            if Maze.isOpen(nc, nr)
                and not parent[key(nc, nr)] then
                parent[key(nc, nr)] = key(cc, cr)
                q[#q + 1] = { nc, nr }
            end
        end
    end
    if not goal then return nil end
    -- walk the parent chain back to build the full path
    local path = {}
    local k = key(goal[1], goal[2])
    while k ~= -1 do
        table.insert(path, 1, { k % 100, k // 100 })
        k = parent[k]
    end
    return path       -- path[1] = start, path[2] = first step
end
-- endsnip

-- snip: grid
-- Build the SDK graph once per maze: one node per cell, walls
-- excluded via the 1/0 includedNodes array (row-major).
function Path.buildGraph()
    local included = {}
    for r = 1, Maze.ROWS do
        for c = 1, Maze.COLS do
            included[#included + 1] =
                Maze.isOpen(c, r) and 1 or 0
        end
    end
    Path.graph = playdate.pathfinder.graph.new2DGrid(
        Maze.COLS, Maze.ROWS, false, included)
end
-- endsnip

-- snip: astar
-- A* between two cells. findPath returns pathfinder.node
-- objects carrying x, y -- convert back to our {c, r} form.
function Path.astar(sc, sr, tc, tr)
    local g = Path.graph
    local a = g:nodeWithXY(sc, sr)
    local b = g:nodeWithXY(tc, tr)
    if not a or not b then return nil end
    local nodes = g:findPath(a, b)
    if not nodes then return nil end
    local path = {}
    for i, n in ipairs(nodes) do
        path[i] = { n.x, n.y }
    end
    return path
end
-- endsnip
