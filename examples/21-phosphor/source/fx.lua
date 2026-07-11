-- vendored from phosphor/vec/fx.lua (MIT)
-- Phosphor core: explosions and flair — point particles, tumbling line
-- debris, and full-screen flash. One shared pool per game.

local gfx <const> = playdate.graphics

Fx = {}

local particles = {}
local debris = {}
local flashT = 0

function Fx.reset()
    particles = {}
    debris = {}
    flashT = 0
end

-- snip: fx-burst
local MAX_POOL <const> = 400 -- soft cap: bursts beyond this are dropped

function Fx.burst(x, y, n, speed)
    speed = speed or 70
    for _ = 1, n do
        if #particles >= MAX_POOL then return end
        local a = math.random() * math.pi * 2
        local s = speed * (0.4 + math.random() * 1.0)
        particles[#particles + 1] = {
            x = x, y = y,
            vx = math.cos(a) * s, vy = math.sin(a) * s,
            life = 0.25 + math.random() * 0.4,
        }
    end
end
-- endsnip

function Fx.debris(x, y, n, speed)
    speed = speed or 45
    for _ = 1, n do
        if #debris >= MAX_POOL then return end
        local a = math.random() * math.pi * 2
        local s = speed * (0.5 + math.random())
        debris[#debris + 1] = {
            x = x, y = y,
            vx = math.cos(a) * s, vy = math.sin(a) * s,
            angle = math.random() * 360, spin = math.random(-180, 180),
            len = 3 + math.random(5),
            life = 0.8 + math.random() * 0.7,
        }
    end
end

function Fx.flash(seconds)
    flashT = math.max(flashT, seconds or 0.25)
end

-- snip: fx-pool
function Fx.update(dt)
    -- swap-remove: pools are order-independent (points and line debris),
    -- so an expired slot takes the last element instead of shifting the
    -- tail -- table.remove here is O(n) per expiry and multi-kill frames
    -- were shifting hundreds of slots
    local n = #particles
    local i = 1
    while i <= n do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            particles[i] = particles[n]
            particles[n] = nil
            n = n - 1
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            i = i + 1
        end
    end
    n = #debris
    i = 1
    while i <= n do
        local d = debris[i]
        d.life = d.life - dt
        if d.life <= 0 then
            debris[i] = debris[n]
            debris[n] = nil
            n = n - 1
        else
            d.x = d.x + d.vx * dt
            d.y = d.y + d.vy * dt
            d.angle = d.angle + d.spin * dt
            i = i + 1
        end
    end
    if flashT > 0 then flashT = flashT - dt end
end
-- endsnip

-- snip: fx-draw
-- true on frames the whole screen should render inverted/white
function Fx.flashing(frame)
    return flashT > 0 and frame % 2 == 0
end

function Fx.draw()
    for _, p in ipairs(particles) do
        gfx.drawPixel(p.x, p.y)
    end
    for _, d in ipairs(debris) do
        local rad = math.rad(d.angle)
        local dx, dy = math.cos(rad) * d.len, math.sin(rad) * d.len
        gfx.drawLine(d.x - dx, d.y - dy, d.x + dx, d.y + dy)
    end
end
-- endsnip
