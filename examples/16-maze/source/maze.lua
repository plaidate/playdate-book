-- The maze: a random tile grid, guaranteed connected by flood
-- fill (clamjumper's trick), pre-rendered once. Pellets sit on
-- every open cell.

local gfx <const> = playdate.graphics

Maze = {}

Maze.TILE = 16
Maze.COLS, Maze.ROWS = 25, 13

local grid       -- grid[r][c] = true when open
local img

function Maze.isOpen(c, r)
    if c < 1 or c > Maze.COLS or r < 1 or r > Maze.ROWS then
        return false
    end
    return grid[r][c]
end

-- pixel center of cell (c, r)
function Maze.px(c, r)
    return (c - 1) * Maze.TILE + 8, (r - 1) * Maze.TILE + 8
end

-- snip: flood
-- flood fill from (sc, sr): which open cells are reachable?
local function floodFrom(sc, sr)
    local seen = { [sr * 100 + sc] = true }
    local q, head = { { sc, sr } }, 1
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    while q[head] do
        local cc, cr = q[head][1], q[head][2]
        head = head + 1
        for _, d in ipairs(dirs) do
            local nc, nr = cc + d[1], cr + d[2]
            if Maze.isOpen(nc, nr)
                and not seen[nr * 100 + nc] then
                seen[nr * 100 + nc] = true
                q[#q + 1] = { nc, nr }
            end
        end
    end
    return seen
end
-- endsnip

-- snip: generate
-- Scatter walls, then SEAL any open cell the player can't
-- reach. The surviving open set is always one connected region,
-- so no actor or pellet can ever be walled off.
function Maze.generate()
    for attempt = 1, 20 do
        grid = {}
        for r = 1, Maze.ROWS do
            grid[r] = {}
            for c = 1, Maze.COLS do
                local border = (r == 1 or r == Maze.ROWS
                    or c == 1 or c == Maze.COLS)
                grid[r][c] = not border
                    and math.random() >= 0.24
            end
        end
        -- force the spawn corners (and elbows) open
        for _, s in ipairs(Maze.spawns) do
            grid[s[2]][s[1]] = true
            grid[s[2]][s[1] + s[3]] = true
            grid[s[2] + s[4]][s[1]] = true
        end
        local seen = floodFrom(2, 2)
        for r = 1, Maze.ROWS do
            for c = 1, Maze.COLS do
                if grid[r][c] and not seen[r * 100 + c] then
                    grid[r][c] = false   -- seal it off
                end
            end
        end
        local ok = true
        for _, s in ipairs(Maze.spawns) do
            if not grid[s[2]][s[1]] then ok = false end
        end
        if ok then break end
    end
    Maze.prerender()
end
-- endsnip

-- spawn corners: {c, r, elbow dc, elbow dr}
Maze.spawns = {
    { 2, 2, 1, 1 },                        -- player
    { Maze.COLS - 1, 2, -1, 1 },           -- ghost A
    { 2, Maze.ROWS - 1, 1, -1 },           -- ghost B
}

function Maze.prerender()
    img = gfx.image.new(400, Maze.ROWS * Maze.TILE,
        gfx.kColorWhite)
    gfx.pushContext(img)
    local t = Maze.TILE
    for r = 1, Maze.ROWS do
        for c = 1, Maze.COLS do
            if not grid[r][c] then
                local x, y = (c - 1) * t, (r - 1) * t
                gfx.setDitherPattern(0.4,
                    gfx.image.kDitherTypeBayer4x4)
                gfx.fillRect(x, y, t, t)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(x, y, t, t)
            end
        end
    end
    gfx.popContext()
end

function Maze.draw()
    img:draw(0, 0)
end
