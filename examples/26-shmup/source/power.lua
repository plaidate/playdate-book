-- vendored from shmup/core/power.lua (MIT)
-- shmup core: power-ups. An enemy type with a `drop` field leaves a capsule
-- behind when it dies; flying into the capsule collects it.
--
--   grunt  = { ..., drop = "gun" }               -- always drops
--   gunner = { ..., drop = { "shield", 0.5 } }   -- drops half the time
--
-- Capsules drift with the world (so they read as scenery, not as enemies) and
-- they expire, because a power-up you can farm is a difficulty setting the
-- player did not know they were choosing.

Power = {}

local KINDS <const> = {
    gun    = { sprite = "pow_gun" },
    shield = { sprite = "pow_shield" },
    life   = { sprite = "pow_life" },
}

local LIFETIME <const> = 9

function Power.init() Power.pool = Pool.new(8) end
function Power.clear() Power.pool:clear() end

function Power.maybeDrop(spec, x, y)
    local d = spec.drop
    if not d then return end
    local kind, chance = d, 1
    if type(d) == "table" then kind, chance = d[1], d[2] or 1 end
    if not KINDS[kind] or math.random() > chance then return end

    local p = Power.pool:spawn()
    if not p then return end
    p.x, p.y, p.kind, p.t = x, y, kind, 0
end

function Power.update(dt)
    Power.pool:update(function(p)
        p.t = p.t + dt
        -- Drift with the world: in a side-scroller the capsule slides left with
        -- the terrain, in a vertical shooter it falls with the starfield, and in
        -- free mode it hangs exactly where it was dropped, because in free mode
        -- the world is not going anywhere.
        if Frame.mode == "side" then
            p.x = p.x - Frame.speed * dt
            -- ...and it FLOATS. A capsule dropped by a ground unit is born at
            -- the ground unit's altitude, which in a cavern game means inside
            -- the wall: it then slid left through solid rock for nine seconds
            -- and expired, having been visible to nobody and collectable by
            -- no one. Every power-up a tank or a fuel dump ever dropped was
            -- unreachable. It rises out of the wreck, and the profile that
            -- draws the cavern is the profile that keeps it in the open air.
            p.y = p.y - 26 * dt
            if Terrain.active then
                p.y = math.max(p.y, Terrain.ceilY(p.x) + 12)
                p.y = math.min(p.y, Terrain.groundY(p.x) - 12)
            end
        elseif Frame.mode == "vertical" then
            p.y = p.y + 40 * dt
        end
        if p.t > LIFETIME or Frame.spent(p.x, p.y) then p.dead = true end
    end)
end

function Power.collect()
    if not Player.alive then return end
    Power.pool:each(function(p)
        if p.dead then return end
        if Lib.circlesHit(p.x, p.y, 8, Player.x, Player.y, Player.r + 4) then
            p.dead = true
            if p.kind == "gun" then
                Player.upgrade()
            elseif p.kind == "shield" then
                Player.shield = true
            elseif p.kind == "life" then
                Player.lives = math.min(9, Player.lives + 1)
            end
            Snd.powerup()
        end
    end)
end

function Power.draw()
    Power.pool:eachLive(function(p)
        -- Blink out over the last two seconds: the capsule tells you it is going.
        if p.t > LIFETIME - 2 and math.floor(p.t * 8) % 2 == 0 then return end
        Sprites.draw(KINDS[p.kind].sprite, Frame.toScreenX(p.x), p.y)
    end)
end
