-- The bouncing-collect scene: a ball bounces along the floor
-- collecting coins. Every effect routes through Fx, so one
-- switch turns the same scene from flat to juicy.

local gfx <const> = playdate.graphics

Scene = {}

local FLOOR <const> = 208
local G <const> = 480        -- gravity, px/s^2
local BOUNCE <const> = -240  -- floor bounce velocity, px/s

local ball
local coins
local score = 0
local squashT = 0

function Scene.reset()
    ball = { x = 60, y = FLOOR - 8, r = 8, vx = 80, vy = BOUNCE }
    coins = {}
    for i = 1, 5 do
        coins[i] = { x = 40 + i * 56, y = FLOOR - 12, alive = true }
    end
end

-- snip: bounce
local function collectNear(x)
    for _, c in ipairs(coins) do
        if c.alive and math.abs(c.x - x) < 45 then
            c.alive = false
            score = score + 100
            Harness.count("coins")
            Fx.burst(c.x, c.y, 14)
            Fx.popup(c.x, c.y - 14, "*+100*")
            Util.after(45, function() c.alive = true end)
            return true
        end
    end
    return false
end

function Scene.update()
    local b = ball
    b.x = b.x + b.vx * DT
    if b.x < 16 or b.x > 384 then b.vx = -b.vx end
    b.vy = b.vy + G * DT
    b.y = b.y + b.vy * DT
    if b.y >= FLOOR - b.r then
        b.y = FLOOR - b.r
        b.vy = BOUNCE
        squashT = 5
        Harness.count("bounces")
        Fx.shake(6, 3)
        Fx.ring(b.x, FLOOR - 4)
        if collectNear(b.x) then
            Fx.flash(2)
            Fx.freeze(3)
        end
    end
    if squashT > 0 then squashT = squashT - 1 end
end
-- endsnip

-- snip: squash
local function drawBall(b)
    local w, h = b.r * 2, b.r * 2
    if Fx.on and squashT > 0 then
        w, h = w * 1.5, h * 0.6       -- squash on landing
    elseif Fx.on and math.abs(b.vy) > 180 then
        w, h = w * 0.7, h * 1.35      -- stretch at speed
    end
    gfx.fillEllipseInRect(b.x - w / 2,
        b.y + b.r - h, w, h)
end
-- endsnip

function Scene.draw(blinkOn)
    local ox, oy = Fx.offset()
    gfx.setDrawOffset(ox, oy)
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(0, FLOOR, 400, FLOOR)
    gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
    gfx.fillRect(0, FLOOR + 1, 400, 240 - FLOOR)
    gfx.setColor(gfx.kColorBlack)
    for _, c in ipairs(coins) do
        if c.alive then
            gfx.drawCircleAtPoint(c.x, c.y, 5)
            gfx.fillCircleAtPoint(c.x, c.y, 2)
        end
    end
    drawBall(ball)
    Fx.draw()
    gfx.drawText("SCORE " .. score, 8, 4)
    local label = Fx.on and "*FX ON*  (A)" or "FX OFF  (A)"
    if not Fx.on or blinkOn then
        gfx.drawTextAligned(label, 392, 4, kTextAlignment.right)
    end
    gfx.drawText("B gallery", 8, 222)
    Fx.drawFlash()
    gfx.setDrawOffset(0, 0)
end
