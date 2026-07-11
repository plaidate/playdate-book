-- Tile course for the robot to play: Chapter 14's map, rebuilt
-- with a PIT -- two columns with no floor at all. The pit is
-- both a hazard for the player and the trap that fed this
-- chapter's bug. Pre-rendered once, blitted each frame.

local gfx <const> = playdate.graphics

Map = {}

Map.TILE = 16
Map.W, Map.H = 25, 15

Map.grid = {}   -- grid[y][x]: 0 = empty, 1 = solid

local img = nil

-- pixel -> tile coordinates (tiles are 1-based)
function Map.tileAt(px, py)
    return math.floor(px / Map.TILE) + 1,
        math.floor(py / Map.TILE) + 1
end

-- snip: solid
-- Out of bounds counts as solid, so the edges are walls --
-- EXCEPT below the bottom row. Falling out through the pit is
-- supposed to happen, and the fall is what we want to count.
function Map.solid(tx, ty)
    if ty > Map.H then return false end       -- the pit exit
    if tx < 1 or tx > Map.W or ty < 1 then
        return true
    end
    return Map.grid[ty][tx] == 1
end
-- endsnip

function Map.build()
    local g = Map.grid
    for y = 1, Map.H do
        g[y] = {}
        for x = 1, Map.W do g[y][x] = 0 end
    end
    -- ground: two solid rows along the bottom
    for x = 1, Map.W do
        g[Map.H][x] = 1
        g[Map.H - 1][x] = 1
    end
    -- the pit: two columns with no floor
    for x = 10, 11 do
        g[Map.H][x] = 0
        g[Map.H - 1][x] = 0
    end
    -- a two-tile step to hop over
    for y = Map.H - 3, Map.H - 2 do g[y][15] = 1 end
    -- two floating ledges the bot must jump onto
    for x = 5, 7 do g[11][x] = 1 end
    for x = 18, 20 do g[11][x] = 1 end
    Map.prerender()
end

-- Draw the whole map into one image at load time; each frame
-- just blits it (Chapter 14's pre-render pattern).
function Map.prerender()
    img = gfx.image.new(400, 240, gfx.kColorWhite)
    gfx.pushContext(img)
    local t = Map.TILE
    for y = 1, Map.H do
        for x = 1, Map.W do
            if Map.grid[y][x] == 1 then
                local px, py = (x - 1) * t, (y - 1) * t
                gfx.setDitherPattern(0.5,
                    gfx.image.kDitherTypeBayer4x4)
                gfx.fillRect(px, py, t, t)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(px, py, t, t)
            end
        end
    end
    gfx.popContext()
end

function Map.draw()
    img:draw(0, 0)
end
