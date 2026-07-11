-- Effects: screen shake, hit-flash, a shared particle pool
-- (phosphor style), eased popups (gfx.animator), and expanding
-- rings (playdate.timer value timers). One master switch turns
-- everything on or off so the difference is obvious.

local gfx <const> = playdate.graphics

Fx = {}

Fx.on = false            -- the master switch

local shakeT, shakeMag = 0, 0
local flashT = 0
local freezeT = 0
local parts = {}         -- shared particle pool
local popups = {}        -- eased score popups
local rings = {}         -- expanding collect rings

-- snip: shake
-- Screen shake is offset jitter: while shakeT > 0, the whole
-- scene draws at a small random offset. No SDK feature needed.
function Fx.shake(frames, mag)
    if not Fx.on then return end
    shakeT, shakeMag = frames, mag
end

function Fx.offset()
    if shakeT <= 0 then return 0, 0 end
    return math.random(-shakeMag, shakeMag),
        math.random(-shakeMag, shakeMag)
end
-- endsnip

-- snip: flash
-- Hit-flash: invert the whole screen for a few frames by
-- XOR-filling over the finished scene.
function Fx.flash(frames)
    if not Fx.on then return end
    flashT = frames
end

function Fx.drawFlash()
    if flashT > 0 then
        gfx.setColor(gfx.kColorXOR)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
    end
end
-- endsnip

-- snip: freeze
-- Freeze frames (hitstop): the world simply does not update
-- for a few frames. The scene still draws, so nothing flickers
-- -- time itself hiccups on impact.
function Fx.freeze(frames)
    if not Fx.on then return end
    freezeT = frames
end

function Fx.frozen()
    if freezeT > 0 then
        freezeT = freezeT - 1
        return true
    end
    return false
end
-- endsnip

-- snip: particles
function Fx.burst(x, y, n)
    if not Fx.on then return end
    for _ = 1, n do
        local a = math.random() * math.pi * 2
        local s = 60 + math.random() * 90
        parts[#parts + 1] = {
            x = x, y = y,
            vx = math.cos(a) * s,
            vy = math.sin(a) * s - 60,
            life = 0.3 + math.random() * 0.3,
        }
    end
end
-- endsnip

-- snip: popup
-- A score popup rides a gfx.animator from 0 to -34 pixels with
-- outCubic easing: it leaps up fast and settles gently.
function Fx.popup(x, y, text)
    if not Fx.on then return end
    popups[#popups + 1] = {
        x = x, y = y, text = text,
        anim = gfx.animator.new(600, 0, -34,
            playdate.easingFunctions.outCubic),
    }
end
-- endsnip

-- snip: ring
-- A collect ring rides a VALUE timer: playdate.timer.new with
-- start/end values animates timer.value from 4 to 22 over
-- 350ms. Requires playdate.timer.updateTimers() every frame.
function Fx.ring(x, y)
    if not Fx.on then return end
    rings[#rings + 1] = {
        x = x, y = y,
        t = playdate.timer.new(350, 4, 22,
            playdate.easingFunctions.outQuad),
        age = 0,
    }
end
-- endsnip

function Fx.update(dt)
    if shakeT > 0 then shakeT = shakeT - 1 end
    if flashT > 0 then flashT = flashT - 1 end
    for i = #parts, 1, -1 do
        local p = parts[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(parts, i)
        else
            p.vy = p.vy + 400 * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
    for i = #popups, 1, -1 do
        if popups[i].anim:ended() then table.remove(popups, i) end
    end
    for i = #rings, 1, -1 do
        local r = rings[i]
        r.age = r.age + 1
        if r.age > 12 then table.remove(rings, i) end
    end
end

function Fx.draw()
    gfx.setColor(gfx.kColorBlack)
    for _, p in ipairs(parts) do
        gfx.fillCircleAtPoint(p.x, p.y, 1.5)
    end
    for _, r in ipairs(rings) do
        gfx.drawCircleAtPoint(r.x, r.y, r.t.value)
    end
    for _, p in ipairs(popups) do
        gfx.drawTextAligned(p.text, p.x,
            p.y + p.anim:currentValue(), kTextAlignment.center)
    end
end
