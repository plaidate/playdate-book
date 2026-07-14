-- vendored from shmup/core/boss.lua (MIT)
-- shmup core: the boss — a small state machine, not an enemy with a lot of HP.
--
-- The "big enemy" model works for about ten minutes. Then you want the thing to
-- enter from off-screen without being culled, to be immune while it enters, to
-- change its fire pattern as it is hurt, to hold the level open until it dies,
-- and to BE the ending. None of that is more hit points; all of it is phases.
--
-- A game defines one with Boss.define:
--
--   Boss.define("dreadnought", {
--     sprite = "dread", hp = 60, r = 30, score = 5000,
--     enter  = { x = 200, y = 60 },     -- where it settles (frame coords)
--     from   = { x = 200, y = -60 },    -- where it comes in from
--     phases = {                        -- picked by remaining HP fraction
--       { above = 0.6, move = ..., fire = function(b, dt) ... end },
--       { above = 0.0, fire = ... },    -- the desperate one
--     },
--   })
--
-- and arms it from the wave script: { t = 40, boss = "dreadnought" }.
--
-- THE RULE: the boss owns the win condition. If a level has one, the level is
-- cleared when it dies -- never when the spawn script happens to run dry.

Boss = {}

local specs = {}
local ENTER_SPEED <const> = 60
local DIE_TIME <const> = 1.6

function Boss.define(name, spec) specs[name] = spec end

function Boss.reset()
    Boss.active = false
    Boss.defeated = false
    Boss.state = nil
    Boss.spec = nil
    Boss.hp, Boss.maxHp = 0, 0
    Boss.x, Boss.y = 0, 0
    Boss.hit = 0
    Boss.t = 0
    -- The boss is not a pool slot, but its phase closures want the same scratch
    -- table the Movers get -- so it carries one, cleared in place on every arm.
    Boss.data = Boss.data or {}
    for k in pairs(Boss.data) do Boss.data[k] = nil end
end

function Boss.arm(name, x, y)
    local sp = specs[name]
    if not sp then return end
    for k in pairs(Boss.data) do Boss.data[k] = nil end
    Boss.spec = sp
    Boss.maxHp = sp.hp or 40
    Boss.hp = Boss.maxHp
    -- It is NOT an enemy in the pool, so nothing culls it on the way in. A boss
    -- garbage-collected during its own entrance is a memorable bug to find and
    -- an embarrassing one to explain.
    local from = sp.from or { x = sp.enter.x, y = -60 }
    Boss.x, Boss.y = from.x, from.y
    Boss.tx, Boss.ty = (x or sp.enter.x), (y or sp.enter.y)
    if x then Boss.x = x end
    Boss.active = true
    Boss.defeated = false
    Boss.state = "enter"
    Boss.t = 0
    Boss.hit = 0
    Snd.alarm()
end

-- Immune while entering, gone once dead: one predicate, so no caller has to
-- remember the rule.
function Boss.vulnerable()
    return Boss.active and Boss.state == "fight"
end

-- snip: boss-phase
local function phase()
    local sp = Boss.spec
    local frac = Boss.hp / Boss.maxHp
    for _, p in ipairs(sp.phases) do
        if frac > (p.above or 0) then return p end
    end
    return sp.phases[#sp.phases]
end

function Boss.damage(dmg)
    if not Boss.vulnerable() then return false end
    Boss.hp = Boss.hp - dmg
    Boss.hit = 0.08
    if Boss.hp <= 0 then
        Boss.hp = 0
        Boss.state = "dying"
        Boss.t = 0
        Fx.shake(7)
        Snd.bossDie()
        return true
    end
    Snd.hit()
    return false
end
-- endsnip

function Boss.update(dt)
    if not Boss.active then return end
    local prevT = Boss.t
    Boss.t = Boss.t + dt
    if Boss.hit > 0 then Boss.hit = Boss.hit - dt end

    if Boss.state == "enter" then
        Boss.x = Lib.approach(Boss.x, Boss.tx, ENTER_SPEED * dt)
        Boss.y = Lib.approach(Boss.y, Boss.ty, ENTER_SPEED * dt)
        if math.abs(Boss.x - Boss.tx) < 0.5 and math.abs(Boss.y - Boss.ty) < 0.5 then
            Boss.state = "fight"
            Boss.t = 0
        end
        return
    end

    if Boss.state == "fight" then
        local p = phase()
        if p.move then p.move(Boss, dt) end
        if p.fire then p.fire(Boss, dt) end
        return
    end

    if Boss.state == "dying" then
        -- A cascade of explosions across the hull, and then the level is over.
        -- The pause is the point: it is the one moment in the game when nothing
        -- is trying to kill you.
        if math.floor(Boss.t / 0.12) ~= math.floor(prevT / 0.12) then
            local r = Boss.spec.r or 30
            Shmup.boom(Boss.x + math.random(-r, r), Boss.y + math.random(-r, r))
        end
        if Boss.t >= DIE_TIME then
            Boss.active = false
            Boss.defeated = true
        end
    end
end

function Boss.hits(x, y, r)
    if not Boss.vulnerable() then return false end
    return Lib.circlesHit(x, y, r, Boss.x, Boss.y, Boss.spec.r or 30)
end

function Boss.draw()
    if not Boss.active then return end

-- snip: boss-noflash
    -- NO hit flash. The enemies get one -- fill the silhouette solid, it blooms
    -- for two frames and reads as damage -- but a boss is under sustained fire:
    -- it takes a hit roughly eight times a second, so the "flash" never lets
    -- go, and the thing you carefully drew renders as a featureless white
    -- rectangle for the entire fight. (This was invisible in every counter. It
    -- took one look at a screenshot.) Damage is legible from the health bar,
    -- the impact sound, and the bullets winking out against the hull.
    Sprites.draw(Boss.spec.sprite, Frame.toScreenX(Boss.x), Boss.y)
-- endsnip

    if Boss.state == "dying" then return end

    -- The health bar is the fight's clock. Without it the player cannot tell
    -- progress from stalemate, and a boss that feels like a stalemate is a boss
    -- they quit to the launcher on.
    local w = 240
    local x = (SCREEN_W - w) // 2
    Kit.panel(x - 2, 224, w + 4, 12)
    local gfx = playdate.graphics
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, 227, math.floor(w * Boss.hp / Boss.maxHp), 6)
end

Boss.reset()
