-- vendored from dither/core/light.lua (MIT)
-- Dither core: dynamic lighting, quantized to K=3 levels (dark / dim /
-- lit). Per frame: Light.begin(ambient) .. Light.add(x, y, r [, f]) /
-- Light.cone(x, y, r, dir, spread [, f]) / Light.wall(x1, y1, x2, y2)
-- .. Light.finish(); Light.at(x, y) answers "is this point lit" from
-- the SAME disc/wedge/occluder math the compositor draws, so pixels
-- and logic agree.
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
--  * gfx.fillPolygon(x1, y1, ... xn, yn) takes bare coordinates — the
--    cone wedge and shadow quads unpack from pooled arrays, so no
--    polygon objects are allocated per frame.
--  * pushContext saves the whole graphics state (stencil included);
--    stencils attach to the frame buffer, not to sprites/images.
-- => stencil-gated pattern fills WORK. The compositor below uses them;
--    the clip-rect-union fallback was not needed.
-- endsnip
--
-- Compositor: K-1 (=2) reusable 400x240 mask images allocated once.
-- For each darkness band q (ambient level up to dim): rebuild mask q
-- (clear + one white disc/wedge blit per light that reaches band q,
-- each immediately followed by that light's black shadow quads, + one
-- black carve blit per light's brighter core), stencil it, and lay one
-- full-screen Shade.over fill. Dark-to-lit order; lit cores end up
-- carved from every mask and receive no fill at all.
--
-- Occluder caveat (documented, not a bug to rediscover): a light's
-- shadows are carved right after its own shape, so a light added
-- LATER re-lights an earlier light's shadow wherever it genuinely
-- reaches — correct — but an earlier light's contribution inside a
-- later light's shadow is lost. That error exists only where two
-- lights overlap AND the later one is occluded there, and it errs
-- dark. Light.at resolves each light independently, so the logic is
-- never darker than the pixels. If it matters, add the shadow-casting
-- light last.
--
-- Honest per-frame cost, L lights, night (ambient < 0.5): 2 mask
-- clears (400x240) + up to 2L+2L disc blits + 2 stenciled full-screen
-- pattern fills — roughly 2-4 ms on device at L<=4, ~0.5 ms in the
-- Simulator. Each wall within a light's reach adds one polygon fill
-- per band. Dusk (one band): about half. Ambient 1: exact no-op.

local gfx = playdate.graphics

Light = {}

local K <const> = 3       -- quantized levels: 0 dark, 1 dim, 2 lit
Light.K = K

-- shade level of the darkening fill per darkness band (tunable)
Light.DARK = { [0] = 12, [1] = 6 }

local W <const>, H <const> = 400, 240
local MAXW <const> = 64   -- occluder segments honoured per frame
local FAN <const> = 12    -- arc points per cone wedge

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
-- occluder pool, likewise
local walls = {}
local nW = 0
-- pooled coordinate arrays for fillPolygon (wedge fan, shadow quad)
local fan = {}
local quad = { 0, 0, 0, 0, 0, 0, 0, 0 }
local amb, qamb = 1, K - 1
local active = false
local stats = {
    lights = 0, walls = 0, blits = 0, fills = 0, ms = 0, ambient = 1,
}

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

-- filled wedge: apex at the light, arc of radius r spanning
-- dir +/- half. FAN+1 arc points; the whole polygon unpacks from one
-- pooled array, so a cone costs no allocation either.
local function fillWedge(l, r, white)
    fan[1], fan[2] = l.x, l.y
    local n = 2
    for i = 0, FAN do
        local a = l.dir - l.half + (2 * l.half) * i / FAN
        fan[n + 1] = l.x + math.cos(a) * r
        fan[n + 2] = l.y + math.sin(a) * r
        n = n + 2
    end
    gfx.setColor(white and gfx.kColorWhite or gfx.kColorBlack)
    gfx.fillPolygon(table.unpack(fan, 1, n))
    stats.blits = stats.blits + 1
end

local function drawShape(l, r, black)
    if r <= 0 then return end
    if l.kind == "cone" then
        fillWedge(l, r, not black)
    else
        blitDisc(l.x, l.y, r, black)
    end
end

-- snip: light-reach
-- squared distance from a point to a segment. The reach test MUST use
-- this, not the endpoints: a long wall can cross a small light with
-- both ends far outside it, and testing endpoints would skip its
-- shadow while Light.at/Light.blocked still honoured the wall — the
-- exact pixels-vs-logic disagreement this module promises not to have.
local function segDist2(px, py, x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    local len2 = dx * dx + dy * dy
    local cx, cy = x1, y1
    if len2 > 0 then
        local t = ((px - x1) * dx + (py - y1) * dy) / len2
        if t > 1 then t = 1 elseif t < 0 then t = 0 end
        cx, cy = x1 + dx * t, y1 + dy * t
    end
    local ax, ay = px - cx, py - cy
    return ax * ax + ay * ay
end
-- endsnip

-- snip: light-shadow
-- paint every wall's shadow for light l at radius r. Each segment
-- projects away from the light past its reach, giving a quad.
-- `white` is the shadow's colour IN THE MASK, always the opposite of
-- the light shape it follows: a shadowed pixel is one this light does
-- not reach.
local function paintShadows(l, r, white)
    if nW == 0 or r <= 0 then return end
    local far = r * 2.5
    local r2 = r * r
    gfx.setColor(white and gfx.kColorWhite or gfx.kColorBlack)
    for i = 1, nW do
        local w = walls[i]
        if segDist2(l.x, l.y, w.x1, w.y1, w.x2, w.y2) <= r2 then
            local d1x, d1y = w.x1 - l.x, w.y1 - l.y
            local d2x, d2y = w.x2 - l.x, w.y2 - l.y
            local m1 = math.sqrt(d1x * d1x + d1y * d1y)
            local m2 = math.sqrt(d2x * d2x + d2y * d2y)
            if m1 > 0.01 and m2 > 0.01 then
                quad[1], quad[2] = w.x1, w.y1
                quad[3], quad[4] = w.x1 + d1x / m1 * far, w.y1 + d1y / m1 * far
                quad[5], quad[6] = w.x2 + d2x / m2 * far, w.y2 + d2y / m2 * far
                quad[7], quad[8] = w.x2, w.y2
                gfx.fillPolygon(table.unpack(quad, 1, 8))
                stats.fills = stats.fills + 1
            end
        end
    end
end

-- one light's contribution to a band mask: its shape at radius r, plus
-- its shadows in the opposite colour. `white` = "this light reaches
-- band q here"; false is the carve meaning "brighter than band q".
local function paintLight(l, r, white)
    if r <= 0 then return end
    -- drawShape takes `black`, paintShadows takes `white`: passing the
    -- SAME flag to both would paint a shadow the same colour as the
    -- shape casting it, which is the whole bug this helper exists to
    -- make impossible. The shadow is always the opposite.
    drawShape(l, r, not white)
    paintShadows(l, r, not white)
end

-- endsnip
-- snip: light-begin
-- ambient 0..1; 1 = full day, the whole system no-ops
function Light.begin(ambient)
    amb = Util.clamp(ambient or 1, 0, 1)
    qamb = math.floor(amb * (K - 1))
    if qamb > K - 1 then qamb = K - 1 end
    active = qamb < K - 1
    nL, nW = 0, 0
    stats.lights, stats.walls = 0, 0
    stats.blits, stats.fills = 0, 0
    stats.ms, stats.ambient = 0, amb
end

local function newLight()
    nL = nL + 1
    local l = pool[nL]
    if not l then
        l = {}
        pool[nL] = l
    end
    stats.lights = nL
    return l
end

-- add a point light: full-lit inside r*falloff, dim out to r
-- (falloff = lit-core fraction, default 0.5)
function Light.add(x, y, r, falloff)
    if not active then return end
    local l = newLight()
    l.kind = "disc"
    l.x, l.y, l.r = x, y, r
    l.f = falloff or 0.5
end
-- endsnip

-- snip: light-cone
-- add a directional light: a wedge of radius r centred on heading
-- `dir` (radians) spanning `spread` radians in total, same lit-core
-- rule as a point light. Beams, torches, guard sight cones.
function Light.cone(x, y, r, dir, spread, falloff)
    if not active then return end
    local l = newLight()
    l.kind = "cone"
    l.x, l.y, l.r = x, y, r
    l.dir = dir
    l.half = (spread or 0.8) * 0.5
    l.f = falloff or 0.5
end

-- register a shadow-casting segment for THIS frame (walls, crates,
-- anything opaque). Order against Light.add does not matter.
function Light.wall(x1, y1, x2, y2)
    if not active or nW >= MAXW then return end
    nW = nW + 1
    local w = walls[nW]
    if not w then
        w = {}
        walls[nW] = w
    end
    w.x1, w.y1, w.x2, w.y2 = x1, y1, x2, y2
    stats.walls = nW
end

-- convenience: the four sides of an axis-aligned box
function Light.box(x, y, w, h)
    Light.wall(x, y, x + w, y)
    Light.wall(x + w, y, x + w, y + h)
    Light.wall(x + w, y + h, x, y + h)
    Light.wall(x, y + h, x, y)
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
                    paintLight(pool[i], radiusFor(pool[i], q), true)
                end
            end
            -- carve the brighter regions back out — but a shadow
            -- inside them is NOT brighter, so it is restored here and
            -- keeps this band's darkening fill
            for i = 1, nL do
                paintLight(pool[i], radiusFor(pool[i], q + 1), false)
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

-- ---- queries ---------------------------------------------------------

-- snip: light-blocked
-- does any registered wall block the segment (ax, ay) -> (bx, by)?
-- Standard segment/segment orientation test — the same occluders the
-- compositor carved, so AI line-of-sight matches what the player sees.
function Light.blocked(ax, ay, bx, by)
    local rx, ry = bx - ax, by - ay
    for i = 1, nW do
        local w = walls[i]
        local sx, sy = w.x2 - w.x1, w.y2 - w.y1
        local denom = rx * sy - ry * sx
        if denom ~= 0 then
            local qx, qy = w.x1 - ax, w.y1 - ay
            local t = (qx * sy - qy * sx) / denom
            local u = (qx * ry - qy * rx) / denom
            if t > 0.001 and t < 0.999 and u >= 0 and u <= 1 then
                return true
            end
        end
    end
    return false
end
-- endsnip

-- snip: light-at
-- 0..1 light level at a point, from the same radii the masks use.
-- Occluded lights do not count; each light resolves independently
-- (see the compositor caveat at the top of the file).
function Light.at(x, y)
    if not active then return 1 end
    local q = qamb
    for i = 1, nL do
        local l = pool[i]
        local dx, dy = x - l.x, y - l.y
        local d2 = dx * dx + dy * dy
        if d2 <= l.r * l.r then
            local ok = true
            if l.kind == "cone" then
                local a = math.atan(dy, dx) - l.dir
                while a > math.pi do a = a - 2 * math.pi end
                while a < -math.pi do a = a + 2 * math.pi end
                ok = math.abs(a) <= l.half
            end
            if ok and not Light.blocked(l.x, l.y, x, y) then
                local rc = l.r * l.f
                if d2 <= rc * rc then
                    return 1 -- inside a lit core, can't get brighter
                elseif q < 1 then
                    q = 1
                end
            end
        end
    end
    return q / (K - 1)
end
-- endsnip

-- budget line for the harness: lights, walls, blits, fills, ms, ambient
function Light.stats()
    return stats
end
