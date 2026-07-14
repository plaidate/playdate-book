-- vendored from shmup/core/bullets.lua (MIT)
-- shmup core: bullet pools and firing patterns. Two pools (player / enemy).
--
-- Player fire is written against the FRAME, not against an orientation: ask
-- the frame which way is forward, fan the shots along the perpendicular, and
-- the same three lines of code serve a vertical shooter, a side-scroller and a
-- ship that turns around. Enemy patterns: aimed / spread / ring. Bullets may
-- carry gravity (b.grav) so bombs arc.

import "CoreLibs/graphics"

Bullets = {}

local SPEED <const> = 540

function Bullets.init()
    Bullets.pp = Pool.new(64)
    Bullets.ep = Pool.new(200)
end

local function add(pool, x, y, vx, vy, sprite, r, dmg, grav)
    local b = pool:spawn()
    if not b then return end
    b.x, b.y, b.vx, b.vy = x, y, vx, vy
    b.sprite, b.r, b.dmg, b.grav = sprite, r, dmg or 1, grav
end

-- The weapon ladder. Level 1 is a single shot, 2 splits it into a twin, 3 adds
-- an angled pair. All of it is expressed in the frame's forward direction
-- (dx, dy) and its perpendicular (-dy, dx), so the ladder is written once and
-- works in all three frames.
function Bullets.playerFire(x, y, level, facing)
    local dx, dy = Frame.fireDir(facing)
    local px, py = -dy, dx                      -- perpendicular
    local sprite = (dy ~= 0) and "shot" or "shot_h"

    if level >= 2 then
        add(Bullets.pp, x + px * 5, y + py * 5, dx * SPEED, dy * SPEED, sprite, 3, 1)
        add(Bullets.pp, x - px * 5, y - py * 5, dx * SPEED, dy * SPEED, sprite, 3, 1)
    else
        add(Bullets.pp, x, y, dx * SPEED, dy * SPEED, sprite, 3, 1)
    end

    if level >= 3 then
        local s = SPEED * 0.85
        add(Bullets.pp, x, y, (dx + px * 0.36) * s, (dy + py * 0.36) * s, "orb", 3, 1)
        add(Bullets.pp, x, y, (dx - px * 0.36) * s, (dy - py * 0.36) * s, "orb", 3, 1)
    end
end

function Bullets.playerBomb(x, y)
    add(Bullets.pp, x, y, 90, 30, "bomb", 3, 1, 320)
end

function Bullets.eAimed(x, y, speed)
    local dx, dy = Player.x - x, Player.y - y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 0.01 then d = 0.01 end
    add(Bullets.ep, x, y, dx / d * speed, dy / d * speed, "orb", 3, 1)
end

-- center defaults to the frame's enemy-forward: down in a vertical game, left
-- in a horizontal one. Hardcoding pi/2 here is what had spread enemies in a
-- side-scroller politely hosing the floor.
function Bullets.eSpread(x, y, count, arc, speed, center)
    if count < 1 then return end
    center = center or Frame.enemyAngle()
    local a0 = center - arc / 2
    local step = count > 1 and arc / (count - 1) or 0
    for i = 0, count - 1 do
        local a = a0 + step * i
        add(Bullets.ep, x, y, math.cos(a) * speed, math.sin(a) * speed, "orb", 3, 1)
    end
end

function Bullets.eRing(x, y, count, speed, phase)
    local step = (2 * math.pi) / count
    phase = phase or 0
    for i = 0, count - 1 do
        local a = phase + step * i
        add(Bullets.ep, x, y, math.cos(a) * speed, math.sin(a) * speed, "orb", 3, 1)
    end
end

local function step(pool, dt)
    pool:update(function(b)
        if b.grav then b.vy = b.vy + b.grav * dt end
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        if Frame.spent(b.x, b.y) then b.dead = true end
    end)
end

function Bullets.update(dt)
    step(Bullets.pp, dt)
    step(Bullets.ep, dt)
end

function Bullets.draw()
    Bullets.pp:eachLive(function(b)
        Sprites.draw(b.sprite, Frame.toScreenX(b.x), b.y)
    end)
    Bullets.ep:eachLive(function(b)
        Sprites.draw(b.sprite, Frame.toScreenX(b.x), b.y)
    end)
end

function Bullets.clear()
    Bullets.pp:clear()
    Bullets.ep:clear()
end
