-- vendored from tiles/core/tcam.lua (MIT)
-- Tiles core: the camera. Maps bigger than the screen scroll by routing
-- all world drawing through gfx.setDrawOffset — entities keep drawing in
-- world coordinates, the HUD draws after Cam.done(). The viewport is
-- clamped so the map always fills the screen (16px HUD row on top); for
-- screen-sized maps the clamp pins the camera and nothing changes.

local gfx = playdate.graphics

Cam = { x = 0, y = 0, sliding = false }

local sx, sy, sspd = 0, 0, 0

-- snip: cam-clamp
local function clampX(x)
    local lo = Map.ox
    local hi = math.max(lo, Map.ox + Map.W * Tiles.SIZE - 400)
    return Util.clamp(x, lo, hi)
end

local function clampY(y)
    local lo = Map.oy - 16
    local hi = math.max(lo, Map.oy + Map.H * Tiles.SIZE - 240)
    return Util.clamp(y, lo, hi)
end
-- endsnip

function Cam.reset()
    Cam.x, Cam.y = clampX(0), clampY(0)
end

-- snap the viewport onto a world point (room entry, respawn)
function Cam.center(wx, wy)
    Cam.x = clampX(wx - 200)
    Cam.y = clampY(wy - 128)
end

-- smooth-follow a world point; call once per frame. No-op mid-slide.
function Cam.follow(wx, wy, dt, rate)
    if Cam.sliding then return end
    local k = math.min(1, (rate or 6) * dt)
    Cam.x = Cam.x + (clampX(wx - 200) - Cam.x) * k
    Cam.y = Cam.y + (clampY(wy - 128) - Cam.y) * k
end

-- scripted glide until (wx, wy) is centered (cutscene pans, Zelda
-- room slides); speed in px/s. Kit.run advances it via Cam.update.
function Cam.slideTo(wx, wy, speed)
    sx, sy = clampX(wx - 200), clampY(wy - 128)
    sspd = speed or 240
    Cam.sliding = true
end

function Cam.update(dt)
    if not Cam.sliding then return end
    local dx, dy = sx - Cam.x, sy - Cam.y
    local d = math.sqrt(dx * dx + dy * dy)
    local step = sspd * dt
    if d <= step then
        Cam.x, Cam.y, Cam.sliding = sx, sy, false
    else
        Cam.x = Cam.x + dx / d * step
        Cam.y = Cam.y + dy / d * step
    end
end

-- start drawing the world (includes Kit's screen shake)
function Cam.apply()
    gfx.setDrawOffset(Kit.sx - math.floor(Cam.x + 0.5), Kit.sy - math.floor(Cam.y + 0.5))
end

-- back to screen space (HUD, overlays)
function Cam.done()
    gfx.setDrawOffset(0, 0)
end

-- world-space viewport rect, for culling
function Cam.view()
    return Cam.x, Cam.y, Cam.x + 400, Cam.y + 240
end
