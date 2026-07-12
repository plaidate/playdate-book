-- vendored from dither/core/scaler.lua (MIT)
-- Dither core: Super Scaler pseudo-3D (Space Harrier / After Burner /
-- OutRun lineage). Distance is scale AND tone: world objects project
-- to screen position + scale, draw from mip ladders precomputed at
-- load, and pick up a depth-haze shade; the ground is a perspective
-- floor of horizontal pattern-fill bands. Intended frame order:
--   sky (Shade.vgrad) -> Para.draw (skylines + Fade.haze) ->
--   Scaler.floor -> Scaler.clear/queue.../flush -> near-plane actors
--   -> Light pass -> Fade transitions / HUD.
--
-- SDK facts verified against Inside Playdate (SDK 2.7, 2025-05 copy):
--  * image:scaledImage(scale [, yscale]) returns a NEW image scaled
--    by scale — used once per ladder step, at build time only.
--  * image:drawScaled(x, y, scale [, yscale]) draws upper-left
--    anchored — used only past a ladder's top step (near flybys).
--  * image:drawFaded(x, y, alpha, ditherType) — alpha 1 = opaque,
--    0 = transparent; Bayer8x8 dither is the depth haze.
--  * gfx.setPattern{r1..r8} fills are OPAQUE (paint black AND white)
--    — exactly right for floor bands: they ARE the ground.
--
-- Costs. Ladder memory ~ w0*h0*maxScale^2*steps/3 pixels (linear
-- steps: sum of (i/n)^2 ~ n/3); a 32x32 base, 12 steps, maxScale 3
-- is ~37k px ~ 4.6 KB bitmap + mask. Floor budget: horizon 120,
-- band = 2 -> 60 pattern fills/frame stripes-only; checker adds
-- per-cell fills, hard-capped by opts.budget (default 96). Zero
-- per-frame allocation in project/queue/flush/floor: the depth queue
-- and its sort are pooled, floor bend offsets live in one persistent
-- array, all images exist before the first frame.

local gfx = playdate.graphics

Scaler = {}

local W <const>, H <const> = 400, 240
local DITHER <const> = gfx.image.kDitherTypeBayer8x8
local MINCELL <const> = 8 -- px; thinner checker cells merge to stripe

-- the camera: x lateral, y height above the ground, z forward
Scaler.cam = { x = 0, y = 40, z = 0 }
Scaler.f = 180        -- focal length, px
Scaler.horizon = 120  -- screen y of the vanishing line
Scaler.cx = 200       -- screen x of the camera axis
Scaler.near = 1       -- min dz that still projects

local stats = { sprites = 0, fills = 0 }

-- snip: scaler-project
-- ---- projection -----------------------------------------------------
-- world (wx, wy, wz) -> screen sx, sy + scale, or nil behind camera.
-- wy is height above the ground plane (wy 0 sits ON the floor).
function Scaler.project(wx, wy, wz)
    local cam = Scaler.cam
    local dz = wz - cam.z
    if dz < Scaler.near then return nil end
    local s = Scaler.f / dz
    return Scaler.cx + (wx - cam.x) * s,
        Scaler.horizon + (cam.y - wy) * s, s
end
-- endsnip

-- snip: scaler-ladder
-- ---- mip ladders ------------------------------------------------------
-- steps scaled copies of img built ONCE, linear in scale up to
-- maxScale (step i = maxScale*i/steps; scale 1 = img's own size, so
-- pass big art + maxScale 1 for crisp, small art + maxScale > 1 for
-- the chunky arcade blow-up).
function Scaler.ladder(img, steps, maxScale)
    local l = {
        imgs = {}, ws = {}, hs = {},
        n = steps, step = maxScale / steps, maxScale = maxScale,
        w0 = img.width, h0 = img.height,
    }
    for i = 1, steps do
        local s = l.step * i
        local si = (s == 1) and img or img:scaledImage(s)
        l.imgs[i] = si
        l.ws[i], l.hs[i] = si.width, si.height
    end
    return l
end
-- endsnip

-- procedural art: render drawFn(w, h) into a fresh base image, then
-- build its ladder (extra args pass through to Scaler.ladder)
function Scaler.ladderFromFn(drawFn, baseW, baseH, steps, maxScale)
    local base = gfx.image.new(baseW, baseH)
    gfx.pushContext(base)
    drawFn(baseW, baseH)
    gfx.popContext()
    return Scaler.ladder(base, steps, maxScale)
end

-- draw a ladder centered-bottom on (sx, sy) at scale: nearest step
-- <= scale (below the smallest step the smallest draws — classic
-- pop-in). shade > 0 hazes via drawFaded; 16 = gone. Past the top
-- step the top image scale-draws live (near flybys; unshaded — near
-- sprites have no haze anyway).
function Scaler.draw(l, sx, sy, scale, shade)
    local k = shade and Shade.quant(shade) or 0
    if k >= 16 then return end
    local i = math.floor(scale / l.step + 1e-6)
    if i < 1 then i = 1 end
    if i <= l.n then
        local x = math.floor(sx - l.ws[i] * 0.5 + 0.5)
        local y = math.floor(sy - l.hs[i] + 0.5)
        if k > 0 then
            l.imgs[i]:drawFaded(x, y, 1 - k / 16, DITHER)
        else
            l.imgs[i]:draw(x, y)
        end
    else
        local up = scale / l.maxScale
        local x = math.floor(sx - l.ws[l.n] * up * 0.5 + 0.5)
        local y = math.floor(sy - l.hs[l.n] * up + 0.5)
        l.imgs[l.n]:drawScaled(x, y, up)
    end
end

-- ---- depth queue -------------------------------------------------------
-- Scaler.clear() .. queue(ladder, wx, wy, wz [, meta]) .. flush():
-- projects at queue time (culling behind-camera and off-screen-x),
-- sorts far-to-near, draws back to front. Entries pooled.
local qpool = {}
local qn = 0

function Scaler.clear()
    qn = 0
end

-- ladder: a Scaler.ladder table, or a function(sx, sy, scale, shade,
-- meta) for custom depth-sorted drawers (fn entries skip the x-cull)
function Scaler.queue(ladder, wx, wy, wz, meta)
    local sx, sy, s = Scaler.project(wx, wy, wz)
    if not sx then return end
    if type(ladder) ~= "function" then
        local hw = ladder.w0 * s * 0.5
        if sx + hw < 0 or sx - hw > W then return end
    end
    qn = qn + 1
    local e = qpool[qn]
    if not e then
        e = {}
        qpool[qn] = e
    end
    e.l, e.sx, e.sy, e.s = ladder, sx, sy, s
    e.dz = wz - Scaler.cam.z
    e.meta = meta
end

-- snip: scaler-flush
-- shadeByZ (optional): function(dz) -> haze shade level 0..16 (see
-- Scaler.linearHaze). Insertion sort, descending dz with strict
-- comparison = stable: equal-z entries keep queue order, no flicker.
function Scaler.flush(shadeByZ)
    for i = 2, qn do
        local e = qpool[i]
        local j = i - 1
        while j >= 1 and qpool[j].dz < e.dz do
            qpool[j + 1] = qpool[j]
            j = j - 1
        end
        qpool[j + 1] = e
    end
    for i = 1, qn do
        local e = qpool[i]
        local k = shadeByZ and shadeByZ(e.dz) or 0
        if type(e.l) == "function" then
            e.l(e.sx, e.sy, e.s, k, e.meta)
        else
            Scaler.draw(e.l, e.sx, e.sy, e.s, k)
        end
    end
    stats.sprites = qn
    qn = 0
end
-- endsnip

-- snip: scaler-haze
-- linear depth-haze mapper: shade 0 out to z0, rising to lmax at z1.
-- Build ONCE at init and hand the same closure to every flush.
function Scaler.linearHaze(z0, z1, lmax)
    local span = z1 - z0
    return function(dz)
        if dz <= z0 then return 0 end
        if dz >= z1 then return lmax end
        return (dz - z0) * lmax / span
    end
end
-- endsnip

-- ---- the ground ---------------------------------------------------------
-- Perspective floor as horizontal bands below the horizon. Per band:
-- world distance z = cam.y * f / (sy - horizon), stripe phase from
-- (z + cam.z) — so driving forward scrolls the stripes free — and,
-- with opts.checker, lateral cells from cam.x. The OutRun bend:
-- opts.curve px of lateral drift is double-accumulated per band
-- going UP from the near edge (quadratic road bend); it shifts the
-- checker cells and is exposed via Scaler.bendAt(sy) so a game's
-- road art can follow the same curve.
--
-- opts:
--   stripes = repeating z-stripe shade levels, e.g. {5, 7} (required)
--   size    = world units per stripe/cell (default 64)
--   y0, y1  = top/bottom screen rows (default horizon+1 .. 240)
--   band    = rows per fill band (default 2)
--   curve   = bend, px of lateral drift per band (default 0)
--   checker = true: alternate shade by lateral cell too, per-cell
--             fills nearest-first; cells under 8 px and anything
--             past the budget fall back to one stripe fill per band
--   budget  = max pattern fills this call (default 96)
--   ramp    = Shade ramp name (default "bayer")
local bendX = {}
for y = 0, H do
    bendX[y] = 0
end

function Scaler.floor(opts)
    local cam = Scaler.cam
    local f, hy, cx = Scaler.f, Scaler.horizon, Scaler.cx
    local stripes = opts.stripes
    local ns = #stripes
    local size = opts.size or 64
    local band = opts.band or 2
    local curve = opts.curve or 0
    local budget = opts.budget or 96
    local ramp = opts.ramp
    local checker = opts.checker
    local ytop = math.max(opts.y0 or hy + 1, hy + 1)
    local yb = math.min(opts.y1 or H, H) -- band bottom, exclusive
    local fy = cam.y * f
    local fills = 0
    local dx, xoff = 0, 0
-- snip: floor-z
    while yb > ytop do
        local bh = math.min(band, yb - ytop)
        local yt = yb - bh
        local dz = fy / (yt + bh * 0.5 - hy)
        local zi = math.floor((dz + cam.z) / size)
-- endsnip
        local done = false
        if checker then
            local cw = size * f / dz -- lateral cell width, px
            if cw >= MINCELL and fills + W / cw + 2 <= budget then
                local wx0 = cam.x - (cx + xoff) * dz / f
                local k = math.floor(wx0 / size)
                local x = cx + xoff + (k * size - cam.x) * f / dz
                while x < W do
                    local xr = x + cw
                    local a = x < 0 and 0 or math.floor(x)
                    local b = xr > W and W or math.floor(xr)
                    if b > a then
                        Shade.set(stripes[(zi + k) % ns + 1], ramp)
                        gfx.fillRect(a, yt, b - a, bh)
                        fills = fills + 1
                    end
                    x = xr
                    k = k + 1
                end
                done = true
            end
        end
-- snip: floor-bend
        if not done then
            Shade.set(stripes[zi % ns + 1], ramp)
            gfx.fillRect(0, yt, W, bh)
            fills = fills + 1
        end
        for r = yt, yb - 1 do
            bendX[r] = xoff
        end
        dx = dx + curve -- the bend accumulates toward the horizon
        xoff = xoff + dx
        yb = yt
-- endsnip
    end
    gfx.setColor(gfx.kColorBlack) -- un-set the pattern
    stats.fills = fills
end

-- lateral bend offset (px) the last floor() applied at screen row sy
function Scaler.bendAt(sy)
    if sy < 0 then
        sy = 0
    elseif sy > H then
        sy = H
    end
    return bendX[sy]
end

-- budget line for the harness: queued sprites + floor fills
function Scaler.stats()
    return stats
end
