-- vendored from lore/core/laction.lua (MIT)
-- Lore core: field combat (Secret of Mana grammar). Same lparty
-- sheet + math as lturn — the player IS Party.member(1): field hits
-- read and write that member's hp, weapon atk comes off its equip.
-- That sharing is THE design point.
--
-- WEAPONS: Action.define{ id = { cooldown = s between swings,
--   arc = { len=, wid= },  -- the rect hitbox thrown in front of
--                          -- the facing edge: len px along facing,
--                          -- wid px across it (pooled, no alloc)
--   charge = { time = s of hold for full charge,
--              mult = damage multiplier at full } } }
-- Damage power itself comes from ITEMS (kind="weapon" power) via
-- Party.atkOf, so Action.arm(player, id) also mirrors the id into
-- member.equip.weapon — the sheet, the menu and both battle
-- grammars all see the same stick.
--
-- THE SWING: the game passes the held button into Action.update(dt,
-- held). Holding charges (Action.charge01 feeds a HUD meter; crank
-- turns add charge too — one full revolution = one full charge, the
-- optional wind-up); releasing swings if off cooldown. A hit rolls
-- Party.attack(atkOf(member1), bestiary def) scaled by 1 ..
-- charge.mult, knocks the foe back via Act.move, freezes the world
-- for 2 frames of hitstop, pops the number, shakes. Foe iframes
-- 0.25 s; player iframes 1 s.
--
-- ENEMIES: Action.spawn{ id=, x=, y=, aggro=px, respawn=s,
-- onDeath=fn(e) } builds a field foe from the bestiary (artFn drawn
-- 16x16 once per id). AI loop: idle drift -> chase inside the aggro
-- radius -> telegraph (flash ring, 0.3 s) -> lunge (3x speed burst)
-- -> recover -> chase. Contact deals Party.attack damage to member
-- 1 with knockback + shake. Death: particle burst, XP (level-up
-- lines toast) + gold + drop roll (heal pickups as touch actors),
-- optional respawn timer back at the spawn cell. Player at 0 hp ->
-- Action.onDown(member) — game-owned; the default restores full hp
-- with a blackout toast (override for real death).
--
-- WIRING: Action.update(dt, held, player) from the game's field
-- update (player sticky — pass it at least once so foes can hunt
-- before a weapon is armed); Action.draw() (telegraph rings,
-- overhead HP bars, swing flash, debris) inside the game's
-- world-space draw bracket. Action.reset() on map change.
-- Counters: swings, actionKills, dashes, shots.
--
-- WAVE 4: Action.dash(mx, my) — a 3x i-framed burst on a 0.7 s
-- cooldown (game binds the button). Weapon defs may add projectile
-- = { speed=, range= }: a FULLY charged swing also throws (SoM
-- spears). Bestiary defs may add ranged = { cd=, speed=, range= }:
-- those foes stop mid-chase, telegraph a sight line, and spit a
-- shot the dash dodges. Action.spawn gains onHurt(e, f) — the boss
-- phase-turn hook. Foes met/beaten land in the bestiary journal.

local gfx = playdate.graphics

Action = {
    weapons = {},
    weapon = nil, -- armed weapon id
    charge01 = 0,
    parts = {},   -- debris list (Kit particles)
    onDown = function(m)
        m.hp = m.maxhp
        Kit.toast("You black out... and come to.")
    end,
}

local wdef = nil
local player = nil
local charging, chargeT = false, 0
local cool, pIT, hitstop, swingT = 0, 0, 0, 0
local dashT, dashCd = 0, 0
local dashDX, dashDY = 0, 0
local foes = {}
local fimg = {}     -- bestiary id -> 16x16 field image
local drops = {}
local respawnQ = {}
local hb = { x = 0, y = 0, w = 0, h = 0 } -- pooled hitbox
local luLines = {}  -- reused level-up line buffer
local dropImg = nil

-- pooled projectiles: the player's thrown weapon and foe spit
local SHOTN = 8
local pshots, eshots = {}, {}
for i = 1, SHOTN do
    pshots[i] = { t = 0 } -- {t, x, y, dx, dy} (t = range left, px)
    eshots[i] = { t = 0 }
end

local function fireShot(list, x, y, dx, dy, range, atk)
    local best = list[1]
    for i = 1, SHOTN do
        if list[i].t <= 0 then
            best = list[i]
            break
        end
        if list[i].t < best.t then best = list[i] end
    end
    best.x, best.y, best.dx, best.dy = x, y, dx, dy
    best.t, best.atk = range, atk
end

function Action.define(t)
    for k, v in pairs(t) do Action.weapons[k] = v end
end

function Action.arm(p, id)
    player = p
    Action.weapon = id
    wdef = Action.weapons[id]
    assert(wdef, "Action.arm: unknown weapon " .. tostring(id))
    local m = Party.member(1)
    if m then m.equip.weapon = id end
end

function Action.reset()
    foes, drops, respawnQ = {}, {}, {}
    charging, chargeT = false, 0
    cool, pIT, hitstop, swingT = 0, 0, 0, 0
    dashT, dashCd = 0, 0
    for i = 1, SHOTN do
        pshots[i].t, eshots[i].t = 0, 0
    end
    Action.charge01 = 0
    Action.parts = {}
end

-- despawn a live field foe WITHOUT the kill flow (no xp/gold/drop —
-- scripted retreats, parley survivors, zone resets)
function Action.despawn(e)
    for i = 1, #foes do
        if foes[i] == e then
            table.remove(foes, i)
            Act.remove(e)
            return true
        end
    end
    return false
end

-- dash cooldown readout for HUDs: 1 = ready, 0 = just used
function Action.dashReady01()
    return 1 - Util.clamp(dashCd / 0.7, 0, 1)
end

-- a short i-framed burst in the facing (or moving) direction; the
-- game binds it (B, double-tap, down+A — its call). Cooldown 0.7 s.
function Action.dash(mx, my)
    if dashCd > 0 or not player then return false end
    if mx and (mx ~= 0 or my ~= 0) then
        dashDX, dashDY = mx, my
    else
        dashDX, dashDY = Act.DX[player.dir], Act.DY[player.dir]
    end
    local d = math.sqrt(dashDX * dashDX + dashDY * dashDY)
    dashDX, dashDY = dashDX / d, dashDY / d
    dashT, dashCd = 0.16, 0.7
    pIT = math.max(pIT, 0.35)
    Harness.count("dashes")
    Snd.play("saw", 500, 0.06, 0.12)
    return true
end

-- ---- art (built once per id) ----------------------------------------------

local function fieldImg(id)
    local img = fimg[id]
    if not img then
        img = gfx.image.new(16, 16)
        gfx.pushContext(img)
        Party.bestiary[id].artFn(16, 16)
        gfx.popContext()
        fimg[id] = img
    end
    return img
end

local function makeDropImg()
    local img = gfx.image.new(9, 9)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(4, 4, 4)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(4, 4, 2)
    gfx.popContext()
    return img
end

-- ---- spawning -------------------------------------------------------------

function Action.spawn(o)
    local d = Party.bestiary[o.id]
    assert(d, "Action.spawn: no bestiary entry '"
        .. tostring(o.id) .. "'")
    local e = Act.new{
        kind = "afoe", x = o.x, y = o.y, hw = 6, hh = 6,
        speed = d.fspeed or 40, img = fieldImg(o.id),
    }
    e.fd = {
        id = o.id, hp = d.hp, maxhp = d.hp,
        atk = d.atk, def = d.def, agi = d.agi,
        xp = d.xp or 0, gold = d.gold or 0, drop = d.drop,
        aggro = o.aggro or 80, st = "idle", t = 0,
        iT = 0, lx = 0, ly = 0, wx = 0, wy = 0,
        sx = o.x, sy = o.y, respawn = o.respawn,
        onDeath = o.onDeath, onHurt = o.onHurt,
        ranged = d.ranged, shotCd = 0,
    }
    Party.recordSeen(o.id)
    foes[#foes + 1] = e
    return e
end

-- ---- collision helpers ----------------------------------------------------

local function overlap(a, b)
    return math.abs(a.x - b.x) < a.hw + b.hw
        and math.abs(a.y - b.y) < a.hh + b.hh
end

local function boxHits(r, e)
    return e.x + e.hw > r.x and e.x - e.hw < r.x + r.w
        and e.y + e.hh > r.y and e.y - e.hh < r.y + r.h
end

-- ---- damage ---------------------------------------------------------------

-- damage the player from a source at (sx, sy) — contact or a shot
local function hurtPlayerAt(atk, agi, sx, sy)
    local m = Party.member(1)
    if not m then return end
    local dmg, _, miss = Party.attack(atk, Party.defOf(m),
        agi, Party.agiOf(m), m.status.guard ~= nil)
    pIT = 1.0
    if miss then
        UI.popup(player.x, player.y - 18, "miss")
        return
    end
    m.hp = math.max(0, m.hp - dmg)
    UI.popup(player.x, player.y - 18, "-" .. dmg)
    Kit.shake(0.2)
    Snd.play("noise", 260, 0.08, 0.25)
    local dx = player.x - sx
    local dy = player.y - sy
    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
    Act.move(player, dx / d * 10, dy / d * 10) -- knockback
    if m.hp <= 0 then Action.onDown(m) end
end

local function hurtPlayer(e)
    local f = e.fd
    hurtPlayerAt(f.atk, f.agi, e.x, e.y)
end

local function killFoe(i, e)
    local f = e.fd
    Harness.count("actionKills")
    Party.recordKill(f.id)
    Kit.burst(Action.parts, e.x, e.y, 10, 90)
    Snd.boom(200, 2)
    State.giveGold(f.gold)
    for k = #luLines, 1, -1 do luLines[k] = nil end
    Party.giveXP(f.xp, luLines)
    for k = 1, #luLines do Kit.toast(luLines[k]) end
    if f.drop and math.random() < (f.drop.chance or 0) then
        dropImg = dropImg or makeDropImg()
        local d = Act.new{
            kind = "drop", x = e.x, y = e.y, hw = 4, hh = 4,
            img = dropImg,
        }
        d.item = f.drop.item
        drops[#drops + 1] = d
    end
    if f.respawn then
        respawnQ[#respawnQ + 1] = {
            id = f.id, x = f.sx, y = f.sy, t = f.respawn,
            respawn = f.respawn, aggro = f.aggro,
            onDeath = f.onDeath,
        }
    end
    if f.onDeath then f.onDeath(e) end
    Act.remove(e)
    table.remove(foes, i)
end

-- ---- the swing ------------------------------------------------------------

-- snip: action-swing
local function swing()
    cool = wdef.cooldown or 0.35
    swingT = 0.1
    Harness.count("swings")
    Snd.play("square", 700, 0.05, 0.15)
    local dx, dy = Act.DX[player.dir], Act.DY[player.dir]
    local len = (wdef.arc and wdef.arc.len) or 14
    local wid = (wdef.arc and wdef.arc.wid) or 18
    if dx ~= 0 then
        hb.w, hb.h = len, wid
        hb.x = player.x + (dx > 0 and player.hw or -player.hw - len)
        hb.y = player.y - wid / 2
    else
        hb.w, hb.h = wid, len
        hb.x = player.x - wid / 2
        hb.y = player.y + (dy > 0 and player.hh or -player.hh - len)
    end
    local mult = 1
    if wdef.charge then
        mult = 1 + (wdef.charge.mult - 1) * Action.charge01
    end
    local m = Party.member(1)
    for i = 1, #foes do
        local e = foes[i]
        local f = e.fd
        if f.iT <= 0 and boxHits(hb, e) then
            local dmg, crit, miss = Party.attack(Party.atkOf(m),
                f.def, Party.agiOf(m), f.agi, false,
                Party.critBonus(m))
            if miss then
                UI.popup(e.x, e.y - 16, "miss")
            else
                dmg = math.floor(dmg * mult)
                f.hp = f.hp - dmg
                f.iT = 0.25
                UI.popup(e.x, e.y - 16,
                    (crit and "*-" or "-") .. dmg)
                Kit.shake(0.12)
                hitstop = 2
                Act.move(e, dx * 10, dy * 10) -- knockback
                f.st, f.t = "recover", 0.3
                Snd.play("noise", 400, 0.06, 0.25)
                if f.onHurt then f.onHurt(e, f) end
            end
        end
    end
-- endsnip
    -- a fully-charged throwing weapon also flies (SoM spears)
    if wdef.projectile and Action.charge01 >= 0.99 then
        local pr = wdef.projectile
        local spd = pr.speed or 180
        fireShot(pshots, player.x, player.y, dx * spd, dy * spd,
            pr.range or 120, math.floor(
                Party.atkOf(m) * ((wdef.charge and wdef.charge.mult)
                    or 1.5)))
        Harness.count("shots")
        Snd.play("square", 950, 0.05, 0.15)
    end
end

-- ---- enemy field AI -------------------------------------------------------

local function updFoe(e, dt)
    local f = e.fd
    if f.iT > 0 then f.iT = f.iT - dt end
    if f.shotCd > 0 then f.shotCd = f.shotCd - dt end
    local px, py = player.x, player.y
    local d2 = Util.dist2(e.x, e.y, px, py)
    if f.st == "aim" then -- ranged telegraph, then spit
        f.t = f.t - dt
        if f.t <= 0 then
            local dx, dy = px - e.x, py - e.y
            local d = math.max(1, math.sqrt(dx * dx + dy * dy))
            local r = f.ranged
            fireShot(eshots, e.x, e.y,
                dx / d * (r.speed or 90), dy / d * (r.speed or 90),
                r.range or 140, f.atk)
            f.shotCd = r.cd or 2.2
            f.st, f.t = "recover", 0.5
            Snd.play("square", 340, 0.06, 0.18)
        end
        return
    end
    if f.st == "idle" then
        f.t = f.t - dt
        if f.t <= 0 then
            f.t = 0.8 + math.random()
            f.wx = math.random(-1, 1)
            f.wy = math.random(-1, 1)
        end
        Act.move(e, f.wx * e.speed * 0.4 * dt,
            f.wy * e.speed * 0.4 * dt)
        if d2 < f.aggro * f.aggro then f.st = "chase" end
    elseif f.st == "chase" then
        local dx, dy = px - e.x, py - e.y
        local d = math.max(1, math.sqrt(d2))
        Act.move(e, dx / d * e.speed * dt, dy / d * e.speed * dt)
        local r = f.ranged
        if r and f.shotCd <= 0 and d2 > 44 * 44
            and d2 < (r.range or 140) * (r.range or 140) then
            f.st, f.t = "aim", 0.4
        elseif d2 < 28 * 28 then
            f.st, f.t = "tel", 0.3
        elseif d2 > f.aggro * f.aggro * 4 then
            f.st = "idle"
        end
    elseif f.st == "tel" then
        f.t = f.t - dt
        if f.t <= 0 then
            local dx, dy = px - e.x, py - e.y
            local d = math.max(1, math.sqrt(dx * dx + dy * dy))
            f.lx, f.ly = dx / d, dy / d
            f.st, f.t = "lunge", 0.18
        end
    elseif f.st == "lunge" then
        f.t = f.t - dt
        Act.move(e, f.lx * e.speed * 3 * dt,
            f.ly * e.speed * 3 * dt)
        if f.t <= 0 then f.st, f.t = "recover", 0.5 end
    elseif f.st == "recover" then
        f.t = f.t - dt
        if f.t <= 0 then f.st = "chase" end
    end
    if pIT <= 0 and f.st ~= "recover" and overlap(e, player) then
        hurtPlayer(e)
    end
end

-- ---- per-frame ------------------------------------------------------------

function Action.update(dt, held, p)
    if p then player = p end
    if not player then return end
    if hitstop > 0 then
        hitstop = hitstop - 1
        return
    end
    if cool > 0 then cool = cool - dt end
    if pIT > 0 then pIT = pIT - dt end
    if swingT > 0 then swingT = swingT - dt end
    if dashCd > 0 then dashCd = dashCd - dt end
    if dashT > 0 then -- the dash burst rides over normal movement
        dashT = dashT - dt
        Act.move(player, dashDX * player.speed * 3 * dt,
            dashDY * player.speed * 3 * dt)
    end
    Kit.updateParts(Action.parts, dt, 140)
    -- the player's flying weapons
    for i = 1, SHOTN do
        local s = pshots[i]
        if s.t > 0 then
            local step = math.sqrt(s.dx * s.dx + s.dy * s.dy) * dt
            s.x = s.x + s.dx * dt
            s.y = s.y + s.dy * dt
            s.t = s.t - step
            local tx, ty = Map.tileAt(s.x, s.y)
            if Map.solid(tx, ty) then s.t = 0 end
            if s.t > 0 then
                for j = 1, #foes do
                    local e = foes[j]
                    local f = e.fd
                    if f.iT <= 0
                        and math.abs(e.x - s.x) < e.hw + 3
                        and math.abs(e.y - s.y) < e.hh + 3 then
                        local dmg = math.max(1,
                            math.floor((s.atk * 2 - f.def)
                                * (0.875 + math.random() * 0.25)))
                        f.hp = f.hp - dmg
                        f.iT = 0.25
                        UI.popup(e.x, e.y - 16, "-" .. dmg)
                        Kit.shake(0.1)
                        f.st, f.t = "recover", 0.3
                        Snd.play("noise", 380, 0.06, 0.22)
                        if f.onHurt then f.onHurt(e, f) end
                        s.t = 0
                        break
                    end
                end
            end
        end
    end
    -- foe spit
    for i = 1, SHOTN do
        local s = eshots[i]
        if s.t > 0 then
            local step = math.sqrt(s.dx * s.dx + s.dy * s.dy) * dt
            s.x = s.x + s.dx * dt
            s.y = s.y + s.dy * dt
            s.t = s.t - step
            local tx, ty = Map.tileAt(s.x, s.y)
            if Map.solid(tx, ty) then s.t = 0 end
            if s.t > 0 and pIT <= 0
                and math.abs(player.x - s.x) < player.hw + 3
                and math.abs(player.y - s.y) < player.hh + 3 then
                hurtPlayerAt(s.atk, 1, s.x, s.y)
                s.t = 0
            end
        end
    end
-- snip: action-charge
    if wdef and player then
        if held then
            charging = true
            chargeT = chargeT + dt
        end
        if charging then -- crank wind-up: 1 rev = 1 full charge
            local crank = playdate.getCrankChange()
            if crank and crank ~= 0 then
                local full = (wdef.charge and wdef.charge.time) or 1
                chargeT = chargeT + math.abs(crank) / 360 * full
            end
        end
        local full = (wdef.charge and wdef.charge.time) or 1
        Action.charge01 = Util.clamp(chargeT / full, 0, 1)
        if charging and not held then
            if cool <= 0 then swing() end
            charging, chargeT = false, 0
            Action.charge01 = 0
        end
    end
-- endsnip
    for i = #foes, 1, -1 do
        local e = foes[i]
        updFoe(e, dt)
        if e.fd.hp <= 0 then killFoe(i, e) end
    end
    for i = #drops, 1, -1 do
        local d = drops[i]
        if overlap(d, player) then
            State.add(d.item, 1)
            Kit.toast("Got a " .. d.item .. ".")
            Act.remove(d)
            table.remove(drops, i)
        end
    end
    for i = #respawnQ, 1, -1 do
        local r = respawnQ[i]
        r.t = r.t - dt
        if r.t <= 0 then
            Action.spawn(r)
            table.remove(respawnQ, i)
        end
    end
end

-- world space, after actors (the game's draw bracket calls it)
function Action.draw()
    for i = 1, #foes do
        local e = foes[i]
        local f = e.fd
        if f.st == "tel" and math.floor(f.t * 20) % 2 == 0 then
            gfx.setColor(gfx.kColorWhite)
            gfx.drawCircleAtPoint(math.floor(e.x),
                math.floor(e.y), 10)
        end
        if f.st == "aim" and math.floor(f.t * 20) % 2 == 0 then
            gfx.setColor(gfx.kColorWhite) -- ranged telegraph: sight
            gfx.drawLine(math.floor(e.x), math.floor(e.y),
                math.floor(e.x + (player.x - e.x) * 0.35),
                math.floor(e.y + (player.y - e.y) * 0.35))
        end
        if f.hp < f.maxhp then
            UI.hpBar(math.floor(e.x) - 12,
                math.floor(e.y) - e.hh - 14, 24, f.hp, f.maxhp)
        end
    end
    if swingT > 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(hb.x, hb.y, hb.w, hb.h)
    end
    for i = 1, SHOTN do -- flying weapons: white core, black rim
        local s = pshots[i]
        if s.t > 0 then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(math.floor(s.x),
                math.floor(s.y), 3)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(math.floor(s.x),
                math.floor(s.y), 2)
        end
        local q = eshots[i]
        if q.t > 0 then
            gfx.setColor(gfx.kColorWhite)
            gfx.drawCircleAtPoint(math.floor(q.x),
                math.floor(q.y), 3)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(math.floor(q.x),
                math.floor(q.y), 2)
        end
    end
    Kit.drawParts(Action.parts)
end
