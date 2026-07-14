-- vendored from shmup/core/enemies.lua (MIT)
-- shmup core: enemy pool + reusable movement (Movers) and fire (Firers)
-- behaviours. A game registers types with Enemies.define; each type is data:
--
--   { sprite, hp, r, score, fuel, drop, move = fn(e, dt), fire = fn(e, dt) }
--
-- Movers and Firers are closures over their parameters, so a type composes one
-- of each and the game never writes an update loop. The behaviours are grouped
-- by the frame they belong to.

Enemies = {}
Movers = {}
Firers = {}

local types = {}

function Enemies.init(cap)
    Enemies.pool = Pool.new(cap or 64)
    types = {}
end

function Enemies.define(name, spec) types[name] = spec end
function Enemies.spec(name) return types[name] end

-- Returns the slot, so a wave (or a level builder) can decorate it. e.data is
-- the behaviour's scratch space: reused, never reallocated.
function Enemies.spawn(name, x, y)
    local sp = types[name]
    if not sp then return nil end
    local e = Enemies.pool:spawn()
    if not e then return nil end
    e.type, e.spec = name, sp
    e.x, e.y = x, y
    e.hp = sp.hp or 1
    e.r = sp.r or 6
    e.age, e.fireT, e.hit = 0, 0, 0
    return e
end

function Enemies.update(dt)
    Enemies.pool:update(function(e)
        e.age = e.age + dt
        if e.hit > 0 then e.hit = e.hit - dt end
        -- In free mode the level is long and mostly off-camera: a defender
        -- parked 1500px away does not need to think. In the scrollers
        -- everything in the pool is on (or just off) the screen anyway.
        if Frame.visible(e.x, 80) then
            if e.spec.move then e.spec.move(e, dt) end
            if e.spec.fire then e.spec.fire(e, dt) end
        end
        if Frame.cull(e.x, e.y) then e.dead = true end
    end)
end

function Enemies.draw()
    Enemies.pool:eachLive(function(e)
        if Frame.visible(e.x) then
            Sprites.draw(e.spec.sprite, Frame.toScreenX(e.x), e.y, e.hit > 0)
        end
    end)
end

function Enemies.count() return Enemies.pool.n end
function Enemies.clear() Enemies.pool:clear() end

-- ---- vertical frame: they come down at you ----
function Movers.straight(speed)
    return function(e, dt) e.y = e.y + speed * dt end
end

function Movers.sine(speed, amp, freq)
    return function(e, dt)
        local d = e.data
        d.x0 = d.x0 or e.x
        e.y = e.y + speed * dt
        e.x = d.x0 + math.sin(e.age * freq) * amp
    end
end

function Movers.dropHover(targetY, dropSpeed, driftAmp, driftFreq)
    return function(e, dt)
        local d = e.data
        d.x0 = d.x0 or e.x
        if e.y < targetY then
            e.y = math.min(e.y + dropSpeed * dt, targetY)
        else
            e.x = d.x0 + math.sin(e.age * driftFreq) * driftAmp
        end
    end
end

-- ---- side frame: the world comes at you ----
function Movers.left(speed)
    return function(e, dt) e.x = e.x - (speed or Frame.speed) * dt end
end

function Movers.leftSine(speed, amp, freq)
    return function(e, dt)
        local d = e.data
        d.y0 = d.y0 or e.y
        e.x = e.x - speed * dt
        e.y = d.y0 + math.sin(e.age * freq) * amp
    end
end

-- Ride the scrolling ground. This speed MUST be the world's speed or the unit
-- slides along the terrain as if on ice -- so it IS the world's speed, and a
-- game cannot pass a different one. It used to be a plain argument, with a
-- comment in the game's content file begging you to keep the two numbers in
-- sync. Comments do not keep numbers in sync.
function Movers.groundLeft(yoff)
    yoff = yoff or 8
    return function(e, dt)
        e.x = e.x - Frame.speed * dt
        if Terrain.active then e.y = Terrain.groundY(e.x) - yoff end
    end
end

-- A ground rocket: rises while the world carries it left.
function Movers.rocketUp(riseSpeed)
    return function(e, dt)
        e.x = e.x - Frame.speed * dt
        e.y = e.y - riseSpeed * dt
    end
end

-- ---- free frame: the level stands still and you fly through it ----
-- A defender bobbing on station. It holds its post whichever way you approach.
function Movers.station(amp, freq)
    return function(e, dt)
        local d = e.data
        d.y0 = d.y0 or e.y
        d.ph = d.ph or (e.x * 0.05)     -- deterministic phase from position
        e.y = d.y0 + math.sin(e.age * freq + d.ph) * amp
    end
end

-- Patrols a stretch of the level, turning at the ends of its beat.
function Movers.patrol(speed, range)
    return function(e, dt)
        local d = e.data
        d.x0 = d.x0 or e.x
        d.dir = d.dir or 1
        e.x = e.x + speed * d.dir * dt
        if e.x > d.x0 + range then
            d.dir = -1
        elseif e.x < d.x0 - range then
            d.dir = 1
        end
    end
end

-- ---- fire behaviours ----
function Firers.none() return function() end end

function Firers.aimed(interval, speed)
    return function(e, dt)
        e.fireT = e.fireT + dt
        if e.fireT >= interval then e.fireT = 0; Bullets.eAimed(e.x, e.y, speed) end
    end
end

function Firers.spread(interval, count, arc, speed, center)
    return function(e, dt)
        e.fireT = e.fireT + dt
        if e.fireT >= interval then
            e.fireT = 0
            Bullets.eSpread(e.x, e.y, count, arc, speed, center)
        end
    end
end

function Firers.ring(interval, count, speed)
    return function(e, dt)
        e.fireT = e.fireT + dt
        if e.fireT >= interval then e.fireT = 0; Bullets.eRing(e.x, e.y, count, speed) end
    end
end

-- Only fires when the player is actually within reach. A free-frame defender
-- on a plain interval timer spends the whole level shooting at nobody, and the
-- bullets it wastes are bullets the pool then cannot give to the enemy you ARE
-- fighting.
function Firers.aimedNear(interval, speed, range)
    local r2 = range * range
    return function(e, dt)
        e.fireT = e.fireT + dt
        if e.fireT >= interval
            and Lib.distSq(e.x, e.y, Player.x, Player.y) <= r2 then
            e.fireT = 0
            Bullets.eAimed(e.x, e.y, speed)
        end
    end
end
