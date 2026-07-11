-- Chapter 7: the world and the camera.
-- The terrain is procedural and pre-rendered ONCE into a big
-- image at boot; every frame after that it costs one blit.

local gfx <const> = playdate.graphics

World = { W = 1600, H = 480, img = nil }

-- snip: world-gen
function World.build()
    World.img = gfx.image.new(World.W, World.H, gfx.kColorWhite)
    gfx.pushContext(World.img)

    -- sky band, ground band
    gfx.setDitherPattern(0.92, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, World.W, 300)
    gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer4x4)
    gfx.fillRect(0, 300, World.W, World.H - 300)

    -- rolling hill line
    gfx.setColor(gfx.kColorBlack)
    local py = 300
    for x = 0, World.W, 8 do
        local y = 300 - 40 * math.abs(math.sin(x * 0.004))
        gfx.drawLine(x - 8, py, x, y)
        py = y
    end

    -- trees, seeded so the world is the same every run
    for i = 1, 60 do
        local x = math.random(20, World.W - 20)
        local y = math.random(320, World.H - 30)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(x, y, x, y - 14)
        gfx.fillCircleAtPoint(x, y - 20, 8)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x - 3, y - 23, 3)
    end

    -- numbered marker posts every 200 px: panning is visible
    for m = 0, World.W // 200 do
        local x = m * 200
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x - 2, 240, 4, 80)
        gfx.fillRoundRect(x - 16, 216, 32, 24, 4)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned(tostring(m), x, 220,
            kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end

    gfx.popContext()
end
-- endsnip

-- snip: cam
Cam = {
    x = 0, y = 0,          -- world coord of the screen's top-left
    DEAD_W = 120, DEAD_H = 70,
    shakeT = 0, shakeMag = 0,
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Smooth-follow a world point with a deadzone: the camera only
-- moves when the target pushes outside the center box, and then
-- lerps toward the corrected spot.
function Cam.follow(tx, ty)
    local goalX, goalY = Cam.x, Cam.y
    local left = Cam.x + 200 - Cam.DEAD_W / 2
    local right = Cam.x + 200 + Cam.DEAD_W / 2
    local top = Cam.y + 120 - Cam.DEAD_H / 2
    local bot = Cam.y + 120 + Cam.DEAD_H / 2
    if tx < left then goalX = Cam.x - (left - tx) end
    if tx > right then goalX = Cam.x + (tx - right) end
    if ty < top then goalY = Cam.y - (top - ty) end
    if ty > bot then goalY = Cam.y + (ty - bot) end
    goalX = clamp(goalX, 0, World.W - 400)
    goalY = clamp(goalY, 0, World.H - 240)
    Cam.x = Cam.x + (goalX - Cam.x) * 0.15
    Cam.y = Cam.y + (goalY - Cam.y) * 0.15
end

function Cam.shake(mag)
    Cam.shakeT, Cam.shakeMag = 12, mag
end

-- Route world drawing through the draw offset. Everything drawn
-- until Cam.done() is in world coordinates.
function Cam.apply()
    local sx, sy = 0, 0
    if Cam.shakeT > 0 then
        Cam.shakeT = Cam.shakeT - 1
        local m = Cam.shakeMag * Cam.shakeT / 12
        sx = (math.random() * 2 - 1) * m
        sy = (math.random() * 2 - 1) * m
    end
    gfx.setDrawOffset(sx - math.floor(Cam.x + 0.5),
        sy - math.floor(Cam.y + 0.5))
end

-- back to screen space (HUD, overlays)
function Cam.done()
    gfx.setDrawOffset(0, 0)
end
-- endsnip
