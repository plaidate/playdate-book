-- vendored from lore/core/lstate.lua (MIT)
-- Lore core: the story ledger. Everything a save file remembers lives
-- here: flags, named counters, the party roster (opaque tables — wave
-- 3 owns the schema), the inventory (item id -> count), gold, opened
-- chests/doors keyed "map:x:y" (the vault lesson: datastore JSON
-- stringifies integer keys, so every set is STRING-keyed at write and
-- read), and quest stages. State.save/load round-trip a versioned
-- envelope {v=1, ...} through playdate.datastore — all keys JSON-safe
-- (dict keys are strings, arrays are contiguous). State.autosave is
-- the hook lscript's warp() fires on map changes (default: save).

State = {
    FILE = "save",  -- slot files are FILE .. slot ("save1".."save3")
    SLOTS = 3,
    slot = 1,       -- the active slot; save/load default to it
    flags = {},
    counters = {},
    party = {},     -- array of opaque member tables (wave-3 schema)
    inv = {},       -- item id (string) -> count
    gold = 0,
    openedSet = {}, -- "map:x:y" -> true
    quests = {},    -- quest id -> stage number
    meta = {},      -- game-owned save-file card (place, chapter...);
                    -- scalars only, shown by State.slotSummary
}

-- ---- flags ----------------------------------------------------------------

function State.set(flag, v)
    if v == nil then v = true end
    if v == false then v = nil end
    if v and not State.flags[flag] then Harness.count("flagsSet") end
    State.flags[flag] = v
end

function State.get(flag)
    return State.flags[flag]
end

function State.has(flag)
    return State.flags[flag] ~= nil
end

-- ---- named counters (kills, steps, deaths...) -----------------------------

function State.bump(name, n)
    local v = (State.counters[name] or 0) + (n or 1)
    State.counters[name] = v
    return v
end

function State.counterOf(name)
    return State.counters[name] or 0
end

-- ---- inventory ------------------------------------------------------------

function State.add(item, n)
    State.inv[item] = (State.inv[item] or 0) + (n or 1)
end

-- take n (default 1); false and no change if short
function State.take(item, n)
    n = n or 1
    local have = State.inv[item] or 0
    if have < n then return false end
    if have == n then
        State.inv[item] = nil -- absent, not 0: keeps the JSON lean
    else
        State.inv[item] = have - n
    end
    return true
end

function State.count(item)
    return State.inv[item] or 0
end

-- ---- gold -----------------------------------------------------------------

function State.giveGold(n)
    State.gold = State.gold + n
end

function State.takeGold(n)
    if State.gold < n then return false end
    State.gold = State.gold - n
    return true
end

-- snip: state-keys
-- ---- chest/door persistence (string keys: the vault lesson) ---------------

local function okey(map, tx, ty)
    return map .. ":" .. tx .. ":" .. ty
end

function State.opened(map, tx, ty)
    return State.openedSet[okey(map, tx, ty)] == true
end

function State.markOpened(map, tx, ty)
    local k = okey(map, tx, ty)
    if not State.openedSet[k] then Harness.count("chestsOpened") end
    State.openedSet[k] = true
end
-- endsnip

-- ---- quest stages ---------------------------------------------------------

-- State.stage("main") reads (0 if unset); State.stage("main", 2) sets
function State.stage(quest, set)
    if set ~= nil then State.quests[quest] = set end
    return State.quests[quest] or 0
end

-- ---- save / load (slotted) ------------------------------------------------

local function fname(slot)
    return State.FILE .. (slot or State.slot)
end

-- save into a slot (default: the active one). Clock rides along via
-- its counters seam so day/night survives a save.
-- snip: state-save
function State.save(slot)
    if slot then State.slot = slot end
    if Clock and Clock.enabled then Clock.store() end
    playdate.datastore.write({
        v = 1,
        flags = State.flags,
        counters = State.counters,
        party = State.party,
        inv = State.inv,
        gold = State.gold,
        opened = State.openedSet,
        quests = State.quests,
        meta = State.meta,
    }, fname(slot))
    Harness.count("saves")
end

-- replaces the live ledger from disk; false (untouched) if no/old save
function State.load(slot)
    local env = playdate.datastore.read(fname(slot))
    if not env or env.v ~= 1 then return false end
    if slot then State.slot = slot end
    State.flags = env.flags or {}
    State.counters = env.counters or {}
    State.party = env.party or {}
    State.inv = env.inv or {}
    State.gold = env.gold or 0
    State.openedSet = env.opened or {}
    State.quests = env.quests or {}
    State.meta = env.meta or {}
    if Clock then Clock.load() end
    return true
end
-- endsnip

-- with a slot: that slot; without: any slot (the title's Continue)
function State.hasSave(slot)
    if slot then
        return playdate.datastore.read(fname(slot)) ~= nil
    end
    for s = 1, State.SLOTS do
        if playdate.datastore.read(fname(s)) ~= nil then
            return true
        end
    end
    return false
end

-- the save-file card for slot pickers: nil for an empty slot, else
-- { name=, lvl=, gold=, meta= } (lead member's name/level)
function State.slotSummary(slot)
    local env = playdate.datastore.read(fname(slot))
    if not env or env.v ~= 1 then return nil end
    local lead = env.party and env.party[1]
    return {
        name = lead and lead.name or "-",
        lvl = lead and lead.lvl or 1,
        gold = env.gold or 0,
        meta = env.meta or {},
    }
end

-- with a slot: wipe that slot; without: wipe them all
function State.wipe(slot)
    if slot then
        playdate.datastore.delete(fname(slot))
        return
    end
    for s = 1, State.SLOTS do
        playdate.datastore.delete(State.FILE .. s)
    end
end

-- the map-change hook (lscript's warp calls it); games may override
State.autosave = function()
    State.save()
end
