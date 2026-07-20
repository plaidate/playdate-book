-- vendored from lore/core/lparty.lua (MIT)
-- Lore core: the character sheet, shared by BOTH battle grammars
-- (lturn scenes and laction field combat) — that sharing is the
-- design point. State.party holds the live member tables, so the
-- sheet rides every save (save-safe by construction: scalars,
-- string-keyed dicts, contiguous arrays only); per-member growth
-- and learn tables live in a runtime registry so saves stay lean.
--
-- MEMBER SCHEMA (State.party[i]):
--   { id=, name=, lvl=, xp=, hp=, maxhp=, mp=, maxmp=,
--     atk=, def=, agi=,            -- BASE stats (no equipment)
--     equip = { weapon=id, armor=id, acc=id },
--     skills = { skill ids },      -- contiguous array
--     status = {} }                -- "poison"/"sleep"/"guard" and
--                                  -- battle buffs "atkup"/"atkdown"/
--                                  -- "defup"/"defdown" -> rounds left
--
-- Party.add(def): def = the schema fields plus growth = {hp, mp,
-- atk, def, agi} (added per level) and learn = {[lvl] = skillId}.
-- Call it every boot: if a loaded save already holds the member it
-- only re-registers growth/learn and returns the live table.
--
-- CONTENT REGISTRIES (the game supplies plain tables):
--   Party.defineItems(t)    id -> { name, kind = "heal"|"cure"|
--     "key"|"weapon"|"armor"|"acc"|"ether"|"revive", power, price,
--     target = "one"|"all" } (weapon/armor power = the equipment
--     stat mod; acc power mods `stat` = "atk"|"def"|"agi"|"crit"
--     (crit: +power/16 crit chance); ether power = mp restored;
--     revive power = hp fraction 0..1)
--   Party.defineSkills(t)   id -> { name, mp, power, kind = "dmg"|
--     "heal"|"buff"|"debuff"|"revive", target = "one"|"all"|"self"|
--     "party", element, buff = "atkup"|"defup"|"atkdown"|"defdown",
--     rounds }
--   Party.defineBestiary(t) id -> { name, hp, atk, def, agi, xp,
--     gold, mp, skills = {ids}, ai = "basic"|"caster"|"sly",
--     artFn = fn(w, h),  -- draw a w x h portrait into the current
--                        -- context (48x48 in lturn, 16x16 field)
--     elems = { element -> dmg multiplier }, fspeed = field px/s,
--     drop = { item=, chance = 0..1 },
--     lore = "a bestiary-page line", aiFn = fn(slot) -> "fight" |
--       ("skill", id) | "heal" (scripted boss brains, lturn) }
--
-- snip: party-formulas
-- THE FORMULAS (canonical; both battle modules call these):
--   physical  dmg = floor((atk*2 - def) * U[0.875..1.125]), min 1;
--             crit 1/16 -> x1.5 (before floor); miss chance =
--             clamp(dAgi / (aAgi*16), 0, 0.5) — equal AGI = 1/16,
--             agile foes dodge more. Guard halves the final hit.
--   skill     amt = floor(power * U[0.875..1.125] * elem), min 1,
--             elem = target.elems[skill.element] or 1; skills never
--             miss. Heals use the same variance (no element).
--   xp        Party.next(lvl) = 10*lvl*lvl total xp reaches lvl+1
--             (10, 40, 90...). A level adds growth, refills hp/mp
--             by the gained amount, learns learn[lvl].
--   poison    max(1, floor(maxhp/16)) per battle round or per 8
--             field steps; never drops a member below 1 hp.
--   sleep     skip the turn; 1/3 wake roll per own turn, certain
--             wake after 3. Guard lasts until the next command.
-- endsnip
--
-- Wires the lui seams: UI.useItem (heal tops up the most-hurt
-- member, cure clears poison) and UI.innHeal (full restore).

Party = {
    items = {},
    skills = {},
    bestiary = {},
}

local defs = {} -- member id -> { growth=, learn= } (not saved)

function Party.defineItems(t) Party.items = t end
function Party.defineSkills(t) Party.skills = t end
function Party.defineBestiary(t) Party.bestiary = t end

-- ---- roster ---------------------------------------------------------------

function Party.add(def)
    defs[def.id] = {
        growth = def.growth or {},
        learn = def.learn or {},
    }
    for i = 1, #State.party do
        if State.party[i].id == def.id then
            return State.party[i] -- loaded from a save
        end
    end
    local m = {
        id = def.id, name = def.name or def.id,
        lvl = def.lvl or 1, xp = def.xp or 0,
        maxhp = def.hp or 10, hp = def.hp or 10,
        maxmp = def.mp or 0, mp = def.mp or 0,
        atk = def.atk or 5, def = def.def or 5, agi = def.agi or 5,
        equip = {}, skills = {}, status = {},
    }
    if def.skills then
        for i = 1, #def.skills do m.skills[i] = def.skills[i] end
    end
    State.party[#State.party + 1] = m
    return m
end

function Party.member(i)
    return State.party[i]
end

function Party.alive(m)
    return m ~= nil and m.hp > 0
end

function Party.anyAlive()
    for i = 1, #State.party do
        if State.party[i].hp > 0 then return true end
    end
    return false
end

-- ---- derived stats (base + equipment mods via ITEMS) ----------------------

local function modOf(id, kind)
    local d = id and Party.items[id]
    if d and d.kind == kind then return d.power or 0 end
    return 0
end

local function accMod(m, stat)
    local d = m.equip.acc and Party.items[m.equip.acc]
    if d and d.kind == "acc" and d.stat == stat then
        return d.power or 0
    end
    return 0
end

function Party.atkOf(m)
    return m.atk + modOf(m.equip.weapon, "weapon")
        + accMod(m, "atk")
end

function Party.defOf(m)
    return m.def + modOf(m.equip.armor, "armor")
        + accMod(m, "def")
end

function Party.agiOf(m)
    return m.agi + accMod(m, "agi")
end

-- crit-passive gear: an acc with stat = "crit" adds `power` extra
-- 1/16ths of crit chance (power 1 doubles the base 1/16)
function Party.critBonus(m)
    return accMod(m, "crit")
end

-- battle buff/debuff multiplier for "atk" or "def": statuses set by
-- buff/debuff skills, rounds counted down by lturn at round end.
-- Works for members AND foe slots (anything with a status table).
function Party.buffMult(who, stat)
    local st = who.status
    if not st then return 1 end
    local mul = 1
    if st[stat .. "up"] then mul = mul * 1.5 end
    if st[stat .. "down"] then mul = mul * 0.67 end
    return mul
end

-- ---- the damage math ------------------------------------------------------

-- snip: party-attack
-- one physical attack roll -> dmg, crit, miss (see header formulas).
-- critB (optional) = extra 1/16ths of crit chance (crit gear).
function Party.attack(atk, dfn, aAgi, dAgi, guarded, critB)
    local miss = Util.clamp(dAgi / math.max(1, aAgi * 16), 0, 0.5)
    if math.random() < miss then return 0, false, true end
    local dmg = (atk * 2 - dfn) * (0.875 + math.random() * 0.25)
    local crit = math.random(16) <= 1 + (critB or 0)
    if crit then dmg = dmg * 1.5 end
    if guarded then dmg = dmg * 0.5 end
    dmg = math.floor(dmg)
    if dmg < 1 then dmg = 1 end
    return dmg, crit, false
end
-- endsnip

-- skill amount vs a target def (elems multiplier table); heals pass
-- a nil target. Never misses, min 1.
function Party.skillPower(sk, target)
    local mul = 1
    if sk.element and target and target.elems then
        mul = target.elems[sk.element] or 1
    end
    local amt = sk.power * (0.875 + math.random() * 0.25) * mul
    amt = math.floor(amt)
    if amt < 1 then amt = 1 end
    return amt
end

-- ---- xp / level-ups -------------------------------------------------------

-- snip: party-xp
-- total xp at which lvl+1 is reached
function Party.next(lvl)
    return 10 * lvl * lvl
end
-- endsnip

-- give n xp to every living member; level-up/learned lines append
-- to out (caller-owned array); returns out
function Party.giveXP(n, out)
    out = out or {}
    for i = 1, #State.party do
        local m = State.party[i]
        if m.hp > 0 then
            m.xp = m.xp + n
            local d = defs[m.id]
            while m.xp >= Party.next(m.lvl) do
                m.lvl = m.lvl + 1
                local g = (d and d.growth) or {}
                m.maxhp = m.maxhp + (g.hp or 0)
                m.hp = math.min(m.maxhp, m.hp + (g.hp or 0))
                m.maxmp = m.maxmp + (g.mp or 0)
                m.mp = math.min(m.maxmp, m.mp + (g.mp or 0))
                m.atk = m.atk + (g.atk or 0)
                m.def = m.def + (g.def or 0)
                m.agi = m.agi + (g.agi or 0)
                Harness.count("levelUps")
                out[#out + 1] = m.name .. " grew to LV "
                    .. m.lvl .. "!"
                local sid = d and d.learn[m.lvl]
                if sid then
                    m.skills[#m.skills + 1] = sid
                    local sk = Party.skills[sid]
                    out[#out + 1] = m.name .. " learned "
                        .. ((sk and sk.name) or sid) .. "!"
                end
            end
        end
    end
    return out
end

-- ---- status effects -------------------------------------------------------

function Party.setStatus(m, name, v)
    m.status[name] = v or 1
end

function Party.hasStatus(m, name)
    return m.status[name] ~= nil
end

function Party.cure(m, name)
    m.status[name] = nil
end

-- one poison tick; never drops below 1 hp. Returns damage dealt.
function Party.poisonTick(m)
    if not m.status.poison or m.hp <= 1 then return 0 end
    local d = math.max(1, math.floor(m.maxhp / 16))
    if m.hp - d < 1 then d = m.hp - 1 end
    m.hp = m.hp - d
    return d
end

-- field hook: lenc calls it once per player step; poison ticks on
-- every 8th step
local stepN = 0

function Party.stepTick()
    stepN = stepN + 1
    if stepN % 8 ~= 0 then return end
    for i = 1, #State.party do
        Party.poisonTick(State.party[i])
    end
end

-- ---- healing --------------------------------------------------------------

function Party.heal(m, n)
    m.hp = math.min(m.maxhp, m.hp + n)
end

function Party.restoreAll()
    for i = 1, #State.party do
        local m = State.party[i]
        m.hp, m.mp = m.maxhp, m.maxmp
        for k in pairs(m.status) do m.status[k] = nil end
    end
end

-- ---- the lui seams --------------------------------------------------------

-- menu Use: heal items top up the proportionally most-hurt living
-- member; cures clear poison. true = consume the item.
UI.useItem = function(id)
    local it = Party.items[id]
    if not it then
        Kit.toast("Nothing happened.")
        return false
    end
    if it.kind == "heal" then
        local best
        for i = 1, #State.party do
            local m = State.party[i]
            if m.hp > 0 and m.hp < m.maxhp and (not best
                or m.hp / m.maxhp < best.hp / best.maxhp) then
                best = m
            end
        end
        if not best then
            Kit.toast("No one needs it.")
            return false
        end
        Party.heal(best, it.power or 10)
        Kit.toast(best.name .. " recovers.")
        return true
    elseif it.kind == "ether" then
        local best
        for i = 1, #State.party do
            local m = State.party[i]
            if m.hp > 0 and m.maxmp > 0 and m.mp < m.maxmp
                and (not best
                or m.mp / m.maxmp < best.mp / best.maxmp) then
                best = m
            end
        end
        if not best then
            Kit.toast("No one needs it.")
            return false
        end
        best.mp = math.min(best.maxmp, best.mp + (it.power or 8))
        Kit.toast(best.name .. "'s spirit returns.")
        return true
    elseif it.kind == "revive" then
        for i = 1, #State.party do
            local m = State.party[i]
            if m.hp <= 0 then
                m.hp = math.max(1,
                    math.floor(m.maxhp * (it.power or 0.5)))
                Kit.toast(m.name .. " is back on their feet!")
                return true
            end
        end
        Kit.toast("No one has fallen.")
        return false
    elseif it.kind == "cure" then
        for i = 1, #State.party do
            local m = State.party[i]
            if m.status.poison then
                Party.cure(m, "poison")
                Kit.toast(m.name .. " is cured.")
                return true
            end
        end
        Kit.toast("No one is poisoned.")
        return false
    end
    Kit.toast("Nothing happened.")
    return false
end

-- the inn restores everyone
UI.innHeal = function()
    Party.restoreAll()
    Kit.toast("You feel rested.")
end

-- ---- the bestiary journal -------------------------------------------------
-- Both battle grammars record what the party has met and beaten
-- (string counters, so it rides the save): seen_<id> / kill_<id>.
-- Party.installBestiary() (OPT-IN) adds the pause-menu "Bestiary"
-- window: unseen foes are "???", seen ones show the portrait, stats
-- and kill count — a collect-them-all reason to fight everything.

function Party.recordSeen(id)
    State.counters["seen_" .. id] = 1
end

function Party.recordKill(id)
    State.bump("kill_" .. id)
end

function Party.seen(id)
    return (State.counters["seen_" .. id] or 0) > 0
end

function Party.kills(id)
    return State.counters["kill_" .. id] or 0
end

local gfx = playdate.graphics
local bimg = nil -- pooled 48x48 portrait for the detail page

local function openBestiaryDetail(id)
    local d = Party.bestiary[id]
    bimg = bimg or gfx.image.new(48, 48)
    bimg:clear(gfx.kColorClear)
    if d.artFn then
        gfx.pushContext(bimg)
        d.artFn(48, 48)
        gfx.popContext()
    end
    local st = {
        ui = true, kind = "bestiaryDetail", translucent = true,
        sel = 1, n = 1, rows = { d.name },
    }
    st.update = function(dt)
        if Input.a or Input.b then Kit.pop() end
    end
    st.draw = function()
        UI.panel(70, 40, 260, 160)
        Gfx.text(d.name, 86, 48)
        Gfx.fill(86, 72, 52, 52, 3)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(86, 72, 52, 52)
        bimg:draw(88, 74)
        Gfx.text("HP  " .. d.hp, 160, 72)
        Gfx.text("ATK " .. d.atk, 160, 90)
        Gfx.text("DEF " .. d.def, 160, 108)
        Gfx.text("AGI " .. d.agi, 240, 72)
        Gfx.text("XP  " .. (d.xp or 0), 240, 90)
        Gfx.text("Beaten: " .. Party.kills(id), 86, 140)
        if d.lore then
            local buf = {}
            local n = UI.wrap(d.lore, 228, buf)
            for i = 1, math.min(n, 2) do
                Gfx.text(buf[i], 86, 158 + (i - 1) * 18)
            end
        end
    end
    Kit.push(st)
end

local function openBestiary()
    local ids = {}
    for id, d in pairs(Party.bestiary) do
        ids[#ids + 1] = id
    end
    table.sort(ids, function(a, b)
        return (Party.bestiary[a].name or a)
            < (Party.bestiary[b].name or b)
    end)
    local rows, seenN = {}, 0
    for i = 1, #ids do
        if Party.seen(ids[i]) then
            seenN = seenN + 1
            rows[i] = Party.bestiary[ids[i]].name
        else
            rows[i] = "???"
        end
    end
    UI.list{
        title = "Bestiary  " .. seenN .. "/" .. #ids,
        tag = "bestiary", rows = rows,
        onA = function(i, st)
            if Party.seen(ids[i]) then
                openBestiaryDetail(ids[i])
            end
        end,
    }
end

-- OPT-IN: put "Bestiary" in the pause menu (call once at boot)
function Party.installBestiary()
    UI.addMenuSection("Bestiary", openBestiary)
end
