-- vendored from voxel/core/vox.lua (MIT)
-- Voxel core: the room engine. A Voxatron-style fixed room — a W x D x H
-- grid of shaded voxels in a 3/4 projection on the 1-bit screen.
--
--   world x -> screen x (S px per voxel)
--   world y (depth, 0 = back) -> screen y down (TY px per step)
--   world z (height, 0 = floor) -> screen y up (TZ px per step)
--
-- Each voxel draws as a TY-tall top face and a TZ-tall front face, shaded
-- with dither patterns by material (1 dark .. 4 white; front face uses the
-- next-darker pattern). Static terrain is rendered once into a background
-- image; Vox.carve() removes a sphere and repaints only the dirty column
-- strip. Dynamic things draw per frame with Vox.drawBlock, then call
-- Vox.occlude so terrain in front of them (pillars, walls) covers them.

local gfx = playdate.graphics

-- W/D/H/S/TY/TZ are load-time constants: the module captures them in
-- locals below, so reassigning the table fields does nothing. Do not
-- reassign them.
Vox = {
    W = 96, D = 64, H = 16,
    S = 4, TY = 2, TZ = 4,
    OX = 8, OY = 86,
    bg = nil,
}

-- dither patterns, 0 = black .. 4 = white
local PAT = {
    [0] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    [1] = { 0x88, 0x00, 0x22, 0x00, 0x88, 0x00, 0x22, 0x00 },
    [2] = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 },
    [3] = { 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF, 0x77, 0xFF },
    [4] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
}
Vox.PAT = PAT

local W, D, H = Vox.W, Vox.D, Vox.H
local S, TY, TZ = Vox.S, Vox.TY, Vox.TZ
local floor = math.floor
local map = {}    -- [(y*W + x)*H + z + 1] = material or nil
local colTop = {} -- [y*W + x + 1] = highest solid z >= 1 (0 if column is floor only)

function Vox.clear()
    map = {}
    colTop = {}
end

local function recalcColTop(x, y)
    local base = (y * W + x) * H
    for z = H - 1, 1, -1 do
        if map[base + z + 1] then
            colTop[y * W + x + 1] = z
            return
        end
    end
    colTop[y * W + x + 1] = 0
end

function Vox.set(x, y, z, m)
    if x < 0 or x >= W or y < 0 or y >= D or z < 0 or z >= H then return end
    map[(y * W + x) * H + z + 1] = m
    if z >= 1 then
        local ci = y * W + x + 1
        local ct = colTop[ci] or 0
        if m and z > ct then
            colTop[ci] = z
        elseif not m and z == ct then
            recalcColTop(x, y)
        end
    end
end

function Vox.get(x, y, z)
    if x < 0 or x >= W or y < 0 or y >= D or z < 0 or z >= H then return nil end
    return map[(y * W + x) * H + z + 1]
end

-- solid for movement/shots: outside the room horizontally or below the
-- floor counts as solid, above the ceiling is open
function Vox.solid(x, y, z)
    if z < 0 then return true end
    if z >= H then return false end
    if x < 0 or x >= W or y < 0 or y >= D then return true end
    return map[(y * W + x) * H + z + 1] ~= nil
end

-- standing height at integer column (top of the highest solid voxel + 1)
function Vox.heightAt(x, y)
    if x < 0 or x >= W or y < 0 or y >= D then return H end
    local base = (y * W + x) * H
    for z = H - 1, 0, -1 do
        if map[base + z + 1] then return z + 1 end
    end
    return 0
end

-- top of the column: standing height (as heightAt) plus the material of
-- the top voxel (nil on an empty column) — the "what am I standing on"
-- probe for goo, ice, pads and the like
function Vox.surfaceAt(x, y)
    local h = Vox.heightAt(x, y)
    return h, Vox.get(x, y, h - 1)
end

-- snip: authoring
-- ---- terrain authoring helpers -----------------------------------------
-- The package's palette rules in reusable form: mid-gray (2) ground, a
-- bright cap course (3) only where it must read as high ground, dark (1)
-- etch lines so white/black actors pop.

-- one column: fill z = 1..h with mat, top course gets capMat (default 3)
function Vox.column(x, y, h, mat, capMat)
    capMat = capMat or 3
    for z = 1, h do
        Vox.set(x, y, z, z == h and capMat or mat)
    end
end

-- etched-grid floor: one full course of mat with etchMat lines every step
-- voxels (default 8) — the standard readable ground plane. z defaults to
-- 1 (a carvable course above the indestructible z=0 floor); pass z = 0
-- for a bare Rubble-style floor.
function Vox.floorGrid(mat, etchMat, step, z)
    step = step or 8
    z = z or 1
    for y = 0, D - 1 do
        for x = 0, W - 1 do
            Vox.set(x, y, z, (x % step == 0 or y % step == 0) and etchMat or mat)
        end
    end
end
-- endsnip

-- snip: heightmap
-- heightfield -> columns. hm[y][x] is 1-indexed (hm[1][1] = world 0,0);
-- heights are clamped to [opts.hmin or 1, opts.hmax or H-3] and floored,
-- then each column fills z = 0..h-1 with opts.mat (default 2). The cap
-- rule: columns at least opts.capMin (default 6) high get an opts.capMat
-- (default 3) top course, so only true high ground reads bright.
function Vox.fromHeightmap(hm, opts)
    opts = opts or {}
    local mat = opts.mat or 2
    local capMat = opts.capMat or 3
    local capMin = opts.capMin or 6
    local hmin = opts.hmin or 1
    local hmax = opts.hmax or H - 3
    for y = 0, D - 1 do
        local row = hm[y + 1]
        for x = 0, W - 1 do
            local hh = floor(Util.clamp(row[x + 1], hmin, hmax))
            local cap = hh >= capMin and capMat or mat
            for z = 0, hh - 1 do
                Vox.set(x, y, z, z == hh - 1 and cap or mat)
            end
        end
    end
end
-- endsnip

-- radial-bump heightfield: a w x d table hm[y][x] (1-indexed, for
-- Vox.fromHeightmap) starting at bumps.base (default 0). Each bump
-- { cx, cy, r, h } (world coords) adds a smooth h * (1 - d2/r2) mound;
-- negative h digs a hollow.
function Vox.bumpField(w, d, bumps)
    local hm = {}
    local base = bumps.base or 0
    for y = 1, d do
        local row = {}
        for x = 1, w do row[x] = base end
        hm[y] = row
    end
    for _, b in ipairs(bumps) do
        local cx, cy, r, h = b[1], b[2], b[3], b[4]
        local r2 = r * r
        for x = math.max(0, cx - r), math.min(w - 1, cx + r) do
            for y = math.max(0, cy - r), math.min(d - 1, cy + r) do
                local d2 = ((x - cx) ^ 2 + (y - cy) ^ 2) / r2
                if d2 < 1 then
                    local row = hm[y + 1]
                    row[x + 1] = row[x + 1] + h * (1 - d2)
                end
            end
        end
    end
    return hm
end

-- snip: draw-block
-- one voxel block drawn directly to the current context (floats fine)
function Vox.drawBlock(px, py, pz, m)
    local sx = floor(Vox.OX + px * S + 0.5)
    local sy = floor(Vox.OY + py * TY - pz * TZ + 0.5)
    gfx.setPattern(PAT[m])
    gfx.fillRect(sx, sy, S, TY)
    gfx.setPattern(PAT[m - 1])
    gfx.fillRect(sx, sy + TY, S, TZ)
end
-- endsnip

-- snip: render-strip
-- repaint columns x0..x1 of the static world into the current context.
-- Draws only visible faces (top face if nothing above, front face if
-- nothing in front), back to front so nearer voxels overwrite.
function Vox.renderStrip(x0, x1)
    if x0 < 0 then x0 = 0 end
    if x1 >= W then x1 = W - 1 end
    local cx = Vox.OX + x0 * S
    local cw = (x1 - x0 + 1) * S
    gfx.setClipRect(cx, 0, cw, 240)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(cx, 0, cw, 240)
    local OX, OY = Vox.OX, Vox.OY
    local WH = W * H
    for y = 0, D - 1 do
        local rowBase = y * W * H
        local sy0 = OY + y * TY
        for x = x0, x1 do
            local base = rowBase + x * H
            local sx = OX + x * S
            for z = 0, H - 1 do
                local m = map[base + z + 1]
                if m then
                    local sy = sy0 - z * TZ
                    if z == H - 1 or not map[base + z + 2] then
                        gfx.setPattern(PAT[m])
                        gfx.fillRect(sx, sy, S, TY)
                    end
                    if y == D - 1 or not map[base + WH + z + 1] then
                        gfx.setPattern(PAT[m - 1])
                        gfx.fillRect(sx, sy + TY, S, TZ)
                    end
                end
            end
        end
    end
    gfx.clearClipRect()
end
-- endsnip

-- build (or rebuild) the full background image; the 400x240 image is
-- allocated once and repainted in place on later rebuilds
function Vox.buildBG()
    if not Vox.bg then
        Vox.bg = gfx.image.new(400, 240, gfx.kColorBlack)
    end
    gfx.pushContext(Vox.bg)
    Vox.renderStrip(0, W - 1)
    gfx.popContext()
end

function Vox.drawBG()
    Vox.bg:draw(0, 0)
end

-- repaint columns of the background image after Vox.set changes (carve
-- calls this itself; games that add terrain call it directly)
function Vox.repaint(x0, x1)
    if not Vox.bg then return end
    gfx.pushContext(Vox.bg)
    Vox.renderStrip(x0, x1)
    gfx.popContext()
end

-- snip: carve
-- remove a sphere of voxels (the floor z=0 is indestructible), repaint the
-- dirty strip, return the removed voxels as {x,y,z,m} for particle bursts
function Vox.carve(cx, cy, cz, r)
    cx, cy, cz = floor(cx + 0.5), floor(cy + 0.5), floor(cz + 0.5)
    local removed = {}
    local r2 = r * r
    for x = math.max(0, cx - r), math.min(W - 1, cx + r) do
        for y = math.max(0, cy - r), math.min(D - 1, cy + r) do
            local base = (y * W + x) * H
            local touched = false
            for z = math.max(1, cz - r), math.min(H - 1, cz + r) do
                local dx, dy, dz = x - cx, y - cy, z - cz
                if dx * dx + dy * dy + dz * dz <= r2 then
                    local m = map[base + z + 1]
                    if m then
                        map[base + z + 1] = nil
                        touched = true
                        removed[#removed + 1] = { x, y, z, m }
                    end
                end
            end
            if touched then recalcColTop(x, y) end
        end
    end
    if #removed > 0 then Vox.repaint(cx - r - 1, cx + r + 1) end
    return removed
end
-- endsnip

-- snip: occlude
-- after drawing a dynamic thing spanning world x [wx0,wx1] at depth wy,
-- redraw any terrain in front of it (y > wy, z >= 1) so pillars and walls
-- correctly cover it. The flat floor never occludes, so columns with
-- colTop == 0 are skipped and this is cheap.
function Vox.occlude(wx0, wx1, wy, wz0, wz1)
    wz1 = wz1 or wz0 + 4
    local x0 = math.max(0, floor(wx0))
    local x1 = math.min(W - 1, floor(wx1))
    local OX, OY = Vox.OX, Vox.OY
    local entBottom = OY + wy * TY - wz0 * TZ + TY + TZ
    local entTop = OY + wy * TY - wz1 * TZ
    local WH = W * H
    for y = floor(wy) + 1, D - 1 do
        local sy0 = OY + y * TY
        if sy0 - H * TZ > entBottom then break end
        -- only heights whose faces can overlap the actor's screen span
        local zlo = math.ceil((sy0 - entBottom) / TZ)
        if zlo < 1 then zlo = 1 end
        local zhi = floor((sy0 + TY + TZ - entTop) / TZ)
        for x = x0, x1 do
            local ct = colTop[y * W + x + 1] or 0
            if ct > zhi then ct = zhi end
            if ct >= zlo then
                local base = (y * W + x) * H
                local sx = OX + x * S
                for z = zlo, ct do
                    local m = map[base + z + 1]
                    if m then
                        local sy = sy0 - z * TZ
                        if z == H - 1 or not map[base + z + 2] then
                            gfx.setPattern(PAT[m])
                            gfx.fillRect(sx, sy, S, TY)
                        end
                        if y == D - 1 or not map[base + WH + z + 1] then
                            gfx.setPattern(PAT[m - 1])
                            gfx.fillRect(sx, sy + TY, S, TZ)
                        end
                    end
                end
            end
        end
    end
end
-- endsnip
