-- vendored from phosphor/vec/beams.lua (MIT)
-- Phosphor core: a vector stroke font, so HUDs and titles are real beam
-- lines like the cabinets drew — scalable and weightable, no raster font.
--
-- Glyphs live on a 4x6 grid, each as one or more polylines ("x,y x,y ..."
-- strings, parsed once at load). Beams.print draws at any pixel height.

local gfx <const> = playdate.graphics

Beams = {}

-- snip: beams-glyphs
local DEFS <const> = {
    A = { "0,6 0,2 2,0 4,2 4,6", "0,4 4,4" },
    B = { "0,0 0,6", "0,0 3,0 4,1 4,2 3,3 0,3", "3,3 4,4 4,5 3,6 0,6" },
    C = { "4,1 3,0 1,0 0,1 0,5 1,6 3,6 4,5" },
    D = { "0,0 0,6", "0,0 3,0 4,1 4,5 3,6 0,6" },
    E = { "4,0 0,0 0,6 4,6", "0,3 3,3" },
-- endsnip
    F = { "4,0 0,0 0,6", "0,3 3,3" },
    G = { "4,1 3,0 1,0 0,1 0,5 1,6 3,6 4,5 4,3 2,3" },
    H = { "0,0 0,6", "4,0 4,6", "0,3 4,3" },
    I = { "1,0 3,0", "2,0 2,6", "1,6 3,6" },
    J = { "4,0 4,5 3,6 1,6 0,5" },
    K = { "0,0 0,6", "4,0 0,3 4,6" },
    L = { "0,0 0,6 4,6" },
    M = { "0,6 0,0 2,3 4,0 4,6" },
    N = { "0,6 0,0 4,6 4,0" },
    O = { "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0" },
    P = { "0,6 0,0 3,0 4,1 4,2 3,3 0,3" },
    Q = { "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0", "2,4 4,6" },
    R = { "0,6 0,0 3,0 4,1 4,2 3,3 0,3", "2,3 4,6" },
    S = { "4,1 3,0 1,0 0,1 0,2 4,4 4,5 3,6 1,6 0,5" },
    T = { "0,0 4,0", "2,0 2,6" },
    U = { "0,0 0,5 1,6 3,6 4,5 4,0" },
    V = { "0,0 2,6 4,0" },
    W = { "0,0 1,6 2,2 3,6 4,0" },
    X = { "0,0 4,6", "4,0 0,6" },
    Y = { "0,0 2,3 4,0", "2,3 2,6" },
    Z = { "0,0 4,0 0,6 4,6" },
    ["0"] = { "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0", "0,5 4,1" },
    ["1"] = { "1,1 2,0 2,6", "1,6 3,6" },
    ["2"] = { "0,1 1,0 3,0 4,1 4,2 0,6 4,6" },
    ["3"] = { "0,0 4,0 2,2 4,4 4,5 3,6 1,6 0,5" },
    ["4"] = { "3,6 3,0 0,4 4,4" },
    ["5"] = { "4,0 0,0 0,2 3,2 4,3 4,5 3,6 1,6 0,5" },
    ["6"] = { "3,0 1,0 0,1 0,5 1,6 3,6 4,5 4,4 3,3 0,3" },
    ["7"] = { "0,0 4,0 1,6" },
    ["8"] = { "1,3 0,2 0,1 1,0 3,0 4,1 4,2 3,3 1,3 0,4 0,5 1,6 3,6 4,5 4,4 3,3" },
    ["9"] = { "1,6 3,6 4,5 4,1 3,0 1,0 0,1 0,2 1,3 4,3" },
    ["."] = { "2,5 2,6" },
    [","] = { "2,5 1,6" },
    ["-"] = { "1,3 3,3" },
    [":"] = { "2,1 2,2", "2,4 2,5" },
    ["!"] = { "2,0 2,4", "2,5 2,6" },
    ["?"] = { "0,1 1,0 3,0 4,1 4,2 2,3 2,4", "2,5 2,6" },
    [">"] = { "1,1 3,3 1,5" },
    ["/"] = { "4,0 0,6" },
    ["+"] = { "2,1 2,5", "0,3 4,3" },
    ["'"] = { "2,0 2,1" },
}

-- parse to flat polylines once
local GLYPHS = {}
for ch, strokes in pairs(DEFS) do
    local g = {}
    for _, str in ipairs(strokes) do
        local poly = {}
        for px, py in str:gmatch("(%d+),(%d+)") do
            poly[#poly + 1] = tonumber(px)
            poly[#poly + 1] = tonumber(py)
        end
        g[#g + 1] = poly
    end
    GLYPHS[ch] = g
end

-- advance width: glyph cell is 4 wide + 2 of spacing, in grid units
local ADV <const> = 6
local GRID <const> = 6 -- glyph height in grid units

function Beams.width(s, size)
    return #s * ADV * (size / GRID) - 2 * (size / GRID)
end

-- snip: beams-print
-- draw s with cap height `size` px; opts: align ("left"|"center"|"right"),
-- weight (line width)
function Beams.print(s, x, y, size, opts)
    opts = opts or {}
    local k = size / GRID
    s = string.upper(s)
    if opts.align == "center" then
        x = x - Beams.width(s, size) / 2
    elseif opts.align == "right" then
        x = x - Beams.width(s, size)
    end
    if opts.weight then gfx.setLineWidth(opts.weight) end
    for i = 1, #s do
        local g = GLYPHS[s:sub(i, i)]
        if g then
            for p = 1, #g do
                local poly = g[p]
                local px, py
                for j = 1, #poly - 1, 2 do
                    local rx = x + poly[j] * k
                    local ry = y + poly[j + 1] * k
                    if px then gfx.drawLine(px, py, rx, ry) end
                    px, py = rx, ry
                end
            end
        end
        x = x + ADV * k
    end
    if opts.weight then gfx.setLineWidth(opts.restore or 1) end
end
-- endsnip
