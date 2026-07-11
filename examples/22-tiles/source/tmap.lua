-- vendored from tiles/core/tmap.lua (MIT)
-- Tiles core: the tileset and the tile map — the NES/GB half of the engine.
--
-- Tiles are 16x16, so the 400x240 screen is exactly 25x15 tiles; house
-- convention is a 16px HUD row plus a 25x14 playfield. A tile type is
-- defined ONCE by character (pattern fill + string-art overlay, rendered
-- to an image at def time), maps are arrays of strings with one char per
-- tile, and the whole map renders ONCE into a background image. Changing
-- a tile repaints just that 16x16 cell — static terrain costs one blit
-- per frame regardless of complexity, same performance model as Vox.

local gfx = playdate.graphics

Tiles = {
    SIZE = 16,
    defs = {},
}

-- standard dither fills, light to dark (bit set = white)
Tiles.PAT = {
    WHITE = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    LIGHT = { 0xFF, 0xDD, 0xFF, 0xFF, 0xFF, 0x77, 0xFF, 0xFF },
    MID   = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 },
    DARK  = { 0x11, 0x00, 0x44, 0x00, 0x11, 0x00, 0x44, 0x00 },
    BLACK = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
}

-- snip: tile-def
-- Tiles.def("#", { solid = true, kind = "wall", pat = Tiles.PAT.MID,
--                  art = { 16 strings of 16 chars } })
-- pat fills the tile; art overlays pixels: '#' black, 'o' white, '.' skip.
-- Extra fields (kind, lethal, ...) ride along on the def for games to
-- query via Map.def().
function Tiles.def(ch, opt)
    local S = Tiles.SIZE
    local img = gfx.image.new(S, S, gfx.kColorWhite)
    gfx.pushContext(img)
    gfx.setPattern(opt.pat or Tiles.PAT.WHITE)
    gfx.fillRect(0, 0, S, S)
    if opt.art then
        for y = 1, math.min(#opt.art, S) do
            local row = opt.art[y]
            for x = 1, math.min(#row, S) do
                local c = row:sub(x, x)
                if c == "#" then
                    gfx.setColor(gfx.kColorBlack)
                    gfx.drawPixel(x - 1, y - 1)
                elseif c == "o" then
                    gfx.setColor(gfx.kColorWhite)
                    gfx.drawPixel(x - 1, y - 1)
                end
            end
        end
    end
    gfx.popContext()
    local d = {}
    for k, v in pairs(opt) do d[k] = v end
    d.ch, d.img, d.art, d.pat = ch, img, nil, nil
    Tiles.defs[ch] = d
    return d
end
-- endsnip

Map = {
    W = 0, H = 0,
    ox = 0, oy = 0, -- screen px of the map's top-left
    grid = {},
    bg = nil,
}

-- rows: array of strings, one char per tile (chars registered via Tiles.def)
function Map.load(rows, ox, oy)
    Map.W, Map.H = #rows[1], #rows
    Map.ox, Map.oy = ox or 0, oy or (240 - Map.H * Tiles.SIZE)
    Map.grid = {}
    for y = 1, Map.H do
        assert(#rows[y] == Map.W,
            "Map.load: row " .. y .. " is " .. #rows[y] .. " chars, expected " .. Map.W)
        Map.grid[y] = {}
        for x = 1, Map.W do
            Map.grid[y][x] = rows[y]:sub(x, x)
        end
    end
    Map.bg = nil
end

function Map.get(tx, ty)
    local row = Map.grid[ty]
    return row and row[tx]
end

function Map.def(tx, ty)
    local ch = Map.get(tx, ty)
    return ch and Tiles.defs[ch]
end

-- out of bounds counts as solid
function Map.solid(tx, ty)
    local d = Map.def(tx, ty)
    if not d then return true end
    return d.solid == true
end

-- snip: map-set
function Map.set(tx, ty, ch)
    assert(Tiles.defs[ch], "Map.set: undefined tile char '" .. tostring(ch) .. "'")
    if not Map.grid[ty] or not Map.grid[ty][tx] then return end
    Map.grid[ty][tx] = ch
    if Map.bg then Map.repaint(tx, ty) end
end
-- endsnip

-- snip: map-build
function Map.build()
    local S = Tiles.SIZE
    Map.bg = gfx.image.new(Map.W * S, Map.H * S, gfx.kColorBlack)
    gfx.pushContext(Map.bg)
    for y = 1, Map.H do
        for x = 1, Map.W do
            local d = Tiles.defs[Map.grid[y][x]]
            if d then d.img:draw((x - 1) * S, (y - 1) * S) end
        end
    end
    gfx.popContext()
end

function Map.repaint(tx, ty)
    local S = Tiles.SIZE
    local d = Tiles.defs[Map.grid[ty][tx]]
    if not d or not Map.bg then return end
    gfx.pushContext(Map.bg)
    d.img:draw((tx - 1) * S, (ty - 1) * S)
    gfx.popContext()
end
-- endsnip

function Map.draw(dx, dy)
    Map.bg:draw(Map.ox + (dx or 0), Map.oy + (dy or 0))
end

-- tile containing a screen pixel
function Map.tileAt(px, py)
    local S = Tiles.SIZE
    return math.floor((px - Map.ox) / S) + 1, math.floor((py - Map.oy) / S) + 1
end

-- screen px center of a tile
function Map.cx(tx) return Map.ox + (tx - 1) * Tiles.SIZE + 8 end
function Map.cy(ty) return Map.oy + (ty - 1) * Tiles.SIZE + 8 end

function Map.each(fn)
    for y = 1, Map.H do
        for x = 1, Map.W do
            fn(x, y, Map.grid[y][x])
        end
    end
end

-- count tiles matching a char
function Map.count(ch)
    local n = 0
    Map.each(function(_, _, c) if c == ch then n = n + 1 end end)
    return n
end
