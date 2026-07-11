-- Tile map: a small course built in code and pre-rendered once.
-- grid[y][x]: 0 = empty, 1 = solid, 2 = one-way platform.

local gfx <const> = playdate.graphics

Map = {}

Map.TILE = 16
Map.W, Map.H = 25, 15

local grid = {}
local img = nil

-- snip: tileat
-- pixel -> tile coordinates (tiles are 1-based)
function Map.tileAt(px, py)
    return math.floor(px / Map.TILE) + 1,
        math.floor(py / Map.TILE) + 1
end
-- endsnip

-- snip: queries
-- Out-of-bounds counts as solid, so the map edge is a wall and
-- nothing needs a special "did I leave the world" check.
function Map.solid(tx, ty)
    if tx < 1 or tx > Map.W or ty < 1 or ty > Map.H then
        return true
    end
    return grid[ty][tx] == 1
end

function Map.oneWay(tx, ty)
    if tx < 1 or tx > Map.W or ty < 1 or ty > Map.H then
        return false
    end
    return grid[ty][tx] == 2
end
-- endsnip

function Map.build()
    for y = 1, Map.H do
        grid[y] = {}
        for x = 1, Map.W do grid[y][x] = 0 end
    end
    -- ground: two solid rows along the bottom
    for x = 1, Map.W do
        grid[Map.H][x] = 1
        grid[Map.H - 1][x] = 1
    end
    -- a two-tile step to jump over
    for y = Map.H - 3, Map.H - 2 do
        grid[y][12] = 1
        grid[y][13] = 1
    end
    -- one-way platforms at two heights
    for x = 6, 8 do grid[9][x] = 2 end
    for x = 17, 19 do grid[8][x] = 2 end
    -- a taller pillar near the right edge
    for y = Map.H - 4, Map.H - 2 do grid[y][22] = 1 end
    Map.prerender()
end

-- snip: prerender
-- Draw the whole map into one image at load time; each frame
-- just blits it. Repainting 375 tiles per frame would burn the
-- budget for nothing -- the map never changes.
function Map.prerender()
    img = gfx.image.new(400, 240, gfx.kColorWhite)
    gfx.pushContext(img)
    local t = Map.TILE
    for y = 1, Map.H do
        for x = 1, Map.W do
            local px, py = (x - 1) * t, (y - 1) * t
            if grid[y][x] == 1 then
                gfx.setDitherPattern(0.5,
                    gfx.image.kDitherTypeBayer4x4)
                gfx.fillRect(px, py, t, t)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(px, py, t, t)
            elseif grid[y][x] == 2 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(px, py + 2, t, 3)
            end
        end
    end
    gfx.popContext()
end

function Map.draw()
    img:draw(0, 0)
end
-- endsnip
