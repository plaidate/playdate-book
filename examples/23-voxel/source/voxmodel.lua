-- vendored from voxel/core/voxmodel.lua (MIT)
-- Voxel core: tiny voxel models for actors, authored as layer strings.
--
--   VoxModel.fromLayers({
--       { "2.2", "2.2" },   -- z = 0, rows back -> front, chars = materials
--       { "222", "222" },   -- z = 1  ('.' = empty, 1..4 = Vox materials)
--   })
--
-- Voxels are centered on x/y and sorted back-to-front, bottom-to-top at
-- build time so VoxModel.draw is a straight painter loop of Vox.drawBlock.

VoxModel = {}

function VoxModel.fromLayers(layers)
    local vox = {}
    local maxc, maxr = 0, 0
    for zi, layer in ipairs(layers) do
        local z = zi - 1
        for r, row in ipairs(layer) do
            if r > maxr then maxr = r end
            for c = 1, #row do
                local ch = row:sub(c, c)
                if ch ~= "." then
                    if c > maxc then maxc = c end
                    vox[#vox + 1] = { c - 1, r - 1, z, tonumber(ch) }
                end
            end
        end
    end
    table.sort(vox, function(a, b)
        if a[2] ~= b[2] then return a[2] < b[2] end
        if a[3] ~= b[3] then return a[3] < b[3] end
        return a[1] < b[1]
    end)
    return {
        vox = vox,
        cx = (maxc - 1) / 2,
        cy = (maxr - 1) / 2,
        w = maxc,
        h = #layers,
    }
end

-- draw with feet at world (wx, wy, wz); wx/wy are the model's center
function VoxModel.draw(model, wx, wy, wz)
    local cx, cy = model.cx, model.cy
    for i = 1, #model.vox do
        local v = model.vox[i]
        Vox.drawBlock(wx + v[1] - cx, wy + v[2] - cy, wz + v[3], v[4])
    end
end

-- snip: ghost
-- ---- occlusion ghost -----------------------------------------------------
-- Redraw the model through a sparse mask AFTER Vox.occlude, so voxels the
-- terrain covered show a see-through silhouette instead of vanishing:
--
--   VoxModel.draw(m, x, y, z)
--   Vox.occlude(...)
--   VoxModel.drawGhost(m, x, y, z)
--
-- How it stays invisible where the actor is NOT occluded: each block
-- redraws with its OWN material pattern via setPattern's 16-row form
-- (rows 9..16 are an alpha mask), masked down to 1 pixel in 4. Playdate
-- patterns are phase-locked to the framebuffer, not the fill origin, so
-- the ghost's unmasked pixels write exactly the values the plain draw
-- already put there — a strict subset that matches — and only pixels the
-- occluding terrain overwrote actually change.
local ghostPats = nil

-- 1-in-4 dot grid (every other pixel of every other row)
local MASK = { 0xAA, 0x00, 0xAA, 0x00, 0xAA, 0x00, 0xAA, 0x00 }

local function buildGhostPats()
    ghostPats = {}
    for m = 0, 4 do
        local p = {}
        for r = 1, 8 do p[r] = Vox.PAT[m][r] end
        for r = 1, 8 do p[8 + r] = MASK[r] end
        ghostPats[m] = p
    end
end
-- endsnip

function VoxModel.drawGhost(model, wx, wy, wz)
    if not ghostPats then buildGhostPats() end
    local gfx = playdate.graphics
    local S, TY, TZ = Vox.S, Vox.TY, Vox.TZ
    local floor = math.floor
    local cx, cy = model.cx, model.cy
    for i = 1, #model.vox do
        local v = model.vox[i]
        local px = wx + v[1] - cx
        local py = wy + v[2] - cy
        local pz = wz + v[3]
        local m = v[4]
        local sx = floor(Vox.OX + px * S + 0.5)
        local sy = floor(Vox.OY + py * TY - pz * TZ + 0.5)
        gfx.setPattern(ghostPats[m])
        gfx.fillRect(sx, sy, S, TY)
        gfx.setPattern(ghostPats[m - 1])
        gfx.fillRect(sx, sy + TY, S, TZ)
    end
end
