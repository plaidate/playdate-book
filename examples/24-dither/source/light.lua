-- vendored from dither/core/light.lua (MIT)
-- Dither core: dynamic lighting, quantized to K=3 levels (dark / dim /
-- lit). Per frame: Light.begin(ambient) .. Light.add(x, y, r [, f]) ..
-- Light.finish(); Light.at(x, y) answers "is this point lit" from the
-- SAME disc math the compositor draws, so pixels and logic agree.
--
-- snip: light-facts
-- SDK facts verified against Inside Playdate (SDK 2.7, 2025-05 copy):
--  * gfx.setStencilImage(image [, tile]) — while active, ALL drawing
--    (pattern fills included) lands only where the stencil is WHITE;
--    black blocks. gfx.clearStencil() clears it (clearStencilImage is
--    deprecated; there is no setStencilImage(nil) form). tile=true
--    needs image width % 32 == 0.
--  * gfx.setStencilPattern({r1..r8}) / (r1..r8) / (level [, ditherType])
--    — screen-tiled pattern stencils, same white-passes rule.
--  * image:drawFaded(x, y, alpha, ditherType) — alpha 1 = opaque,
--    0 = transparent; ditherType e.g. image.kDitherTypeBayer8x8.
--  * gfx.setPattern{r1..r8} fills are OPAQUE (draw black AND white);
--    the 16-number form {r1..r8, a1..a8} adds an alpha mask, giving
--    the black-only overlay fills the compositor needs (Shade.over).
--  * gfx.setDitherPattern(alpha [, type]) — with a white draw color
--    the alpha is inverted (documented SDK bug); we avoid it entirely
--    and use Shade's own byte ramps.
--  * pushContext saves the whole graphics state (stencil included);
--    stencils attach to the frame buffer, not to sprites/images.
-- => stencil-gated pattern fills WORK. The compositor below uses them;
--    the clip-rect-union fallback was not needed.
-- endsnip
--
-- Compositor: K-1 (=2) reusable 400x240 mask images allocated once.
-- For each darkness band q (ambient level up to dim): rebuild mask q
-- (clear + one white disc blit per light that reaches band q + one
-- black carve blit per light's brighter core), stencil it, and lay one
-- full-screen Shade.over fill. Dark-to-lit order; lit cores end up
-- carved from every mask and receive no fill at all.
--
-- Honest per-frame cost, L lights, night (ambient < 0.5): 2 mask
-- clears (400x240) + up to 2L+2L disc blits + 2 stenciled full-screen
-- pattern fills — roughly 2-4 ms on device at L<=4, ~0.5 ms in the
-- Simulator. Dusk (one band): about half. Ambient 1: exact no-op.

local gfx = playdate.graphics

Light = {}

local K <const> = 3       -- quantized levels: 0 dark, 1 dim, 2 lit
Light.K = K

-- shade level of the darkening fill per darkness band (tunable)
Light.DARK = { [0] = 12, [1] = 6 }

local W <const>, H <const> = 400, 240

-- K-1 reusable full-screen masks, allocated once at import
local masks = {}
for q = 0, K - 2 do
    masks[q] = gfx.image.new(W, H)
end

-- precomputed white radial discs (clear background) at a few sizes;
-- other radii scale-draw from the nearest base (solid discs scale
-- cleanly, only the edge aliases)
local DISC_R <const> = { 16, 32, 64, 128 }
local discs = {}
for i = 1, #DISC_R do
    local r = DISC_R[i]
    local img = gfx.image.new(2 * r, 2 * r)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(r, r, r)
    gfx.popContext()
    discs[i] = img
end

-- light pool, entries reused frame to frame (zero per-frame alloc)
local pool = {}
local nL = 0
local amb, qamb = 1, K - 1
local active = false
local stats = { lights = 0, blits = 0, fills = 0, ms = 0, ambient = 1 }

-- radius at which a light still reaches band q (0 = never):
-- lit (q=2) inside r*f, dim (q=1) inside r
local function radiusFor(l, q)
    if q >= K - 1 then return l.r * l.f end
    if q >= 1 then return l.r end
    return 0
end

local function blitDisc(cx, cy, r, black)
    local bi = #DISC_R
    for i = 1, #DISC_R do
        if DISC_R[i] >= r then bi = i break end
    end
    local base = DISC_R[bi]
    if black then
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    end
    discs[bi]:drawScaled(math.floor(cx - r + 0.5),
        math.floor(cy - r + 0.5), r / base)
    if black then
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
    stats.blits = stats.blits + 1
end

-- snip: light-begin
-- ambient 0..1; 1 = full day, the whole system no-ops
function Light.begin(ambient)
    amb = Util.clamp(ambient or 1, 0, 1)
    qamb = math.floor(amb * (K - 1))
    if qamb > K - 1 then qamb = K - 1 end
    active = qamb < K - 1
    nL = 0
    stats.lights, stats.blits, stats.fills = 0, 0, 0
    stats.ms, stats.ambient = 0, amb
end

-- add a light source: full-lit inside r*falloff, dim out to r
-- (falloff = lit-core fraction, default 0.5)
function Light.add(x, y, r, falloff)
    if not active then return end
    nL = nL + 1
    local l = pool[nL]
    if not l then
        l = {}
        pool[nL] = l
    end
    l.x, l.y, l.r = x, y, r
    l.f = falloff or 0.5
    stats.lights = nL
end
-- endsnip

-- snip: light-finish
-- composite darkness over the finished scene, dark bands to lit
function Light.finish()
    if not active then return end
    local t0 = playdate.getCurrentTimeMilliseconds()
    for q = qamb, K - 2 do
        if q == qamb or nL > 0 then
            local m = masks[q]
            gfx.pushContext(m)
            if q == qamb then
                gfx.clear(gfx.kColorWhite) -- base band covers all
            else
                gfx.clear(gfx.kColorBlack)
                for i = 1, nL do          -- lights that reach band q
                    local l = pool[i]
                    blitDisc(l.x, l.y, radiusFor(l, q), false)
                end
            end
            for i = 1, nL do              -- carve brighter regions
                local l = pool[i]
                blitDisc(l.x, l.y, radiusFor(l, q + 1), true)
            end
            gfx.popContext()
            gfx.setStencilImage(m)
            Shade.over(Light.DARK[q])
            gfx.fillRect(0, 0, W, H)
            gfx.clearStencil()
            stats.fills = stats.fills + 1
        end
    end
    gfx.setColor(gfx.kColorBlack) -- un-set the pattern
    stats.ms = playdate.getCurrentTimeMilliseconds() - t0
end
-- endsnip

-- snip: light-at
-- 0..1 light level at a point, from the same radii the masks use
function Light.at(x, y)
    if not active then return 1 end
    local q = qamb
    for i = 1, nL do
        local l = pool[i]
        local dx, dy = x - l.x, y - l.y
        local d2 = dx * dx + dy * dy
        local rc = l.r * l.f
        if d2 <= rc * rc then
            return 1 -- inside a lit core, can't get brighter
        elseif d2 <= l.r * l.r and q < 1 then
            q = 1
        end
    end
    return q / (K - 1)
end
-- endsnip

-- budget line for the harness: lights, blits, fills, ms, ambient
function Light.stats()
    return stats
end
