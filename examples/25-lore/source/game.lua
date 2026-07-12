-- The tour: one 120x90 chunked overworld, walked end to end by a
-- scripted playthrough. Screen 1 is the chunk cache (with a model
-- of the LRU that must agree with Map.builds); screen 2 is the
-- state stack (dialog, choice, pause menu over a live field);
-- screen 3 is an lturn battle; screen 4 is laction field combat.

local gfx = playdate.graphics

G = { t = 0 }

Game = { showCache = true }

-- ---- deterministic hash noise (worldgen never uses math.random) ---

local function hash(x, y)
    local n = (x * 73856093 + y * 19349663 + 4271) % 2147483647
    return ((n * 48271) % 2147483647) / 2147483647
end

-- ---- tile art: 16px, drawn into the chunk image at x, y -----------

local function grassArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 2)
    if hash(tx, ty + 999) < 0.35 then
        gfx.setColor(gfx.kColorBlack)
        local o = math.floor(hash(tx + 31, ty) * 10)
        gfx.fillRect(x + 3 + o, y + 5 + (o * 7) % 8, 1, 2)
    end
end

local function pathArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 0)
    gfx.setColor(gfx.kColorBlack)
    if hash(tx, ty) < 0.5 then
        gfx.drawPixel(x + 2 + math.floor(hash(tx, ty + 7) * 12),
            y + 2 + math.floor(hash(tx + 7, ty) * 12))
    end
end

local function waterArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 4)
    gfx.setColor(gfx.kColorWhite)
    local o = (tx + ty) % 2 * 4
    gfx.fillRect(x + 2 + o, y + 4, 5, 1)
    gfx.fillRect(x + 10 - o, y + 11, 5, 1)
end

local function treeArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 1)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x + 7, y + 10, 3, 5)
    gfx.fillCircleAtPoint(x + 8, y + 6, 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 6, y + 4)
end

local function mtnArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(x + 1, y + 14, x + 8, y + 2, x + 15, y + 14)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillTriangle(x + 6, y + 5, x + 8, y + 2, x + 10, y + 5)
end

-- the canopy: pre-rendered ONCE per legend def (transparent gaps),
-- then blitted per cell after the actors -- the walk-behind layer
local function canopyArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x + 4, y + 5, 5)
    gfx.fillCircleAtPoint(x + 12, y + 4, 5)
    gfx.fillCircleAtPoint(x + 8, y + 12, 6)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 3, y + 3)
    gfx.drawPixel(x + 11, y + 6)
    gfx.drawPixel(x + 7, y + 11)
end

local LEGEND = {
    ["g"] = { art = grassArt, speed = 1, zone = "meadow" },
    ["p"] = { art = pathArt, speed = 1.25 },
    ["w"] = { art = waterArt, water = true },
    ["t"] = { art = treeArt, solid = true },
    ["m"] = { art = mtnArt, solid = true },
    ["T"] = { art = canopyArt, overhead = true, under = "p",
        speed = 1.25 },
}

local function genRows()
    local grid = {}
    for ty = 1, C.WORLD_H do
        local r = {}
        for tx = 1, C.WORLD_W do
            local n = hash(tx // 8, ty // 8) * 0.7
                + hash(tx // 3 + 57, ty // 3 + 91) * 0.3
            if n < 0.2 then r[tx] = "w"
            elseif n > 0.84 then r[tx] = "m"
            elseif n > 0.66 then r[tx] = "t"
            else r[tx] = "g" end
        end
        grid[ty] = r
    end
    for tx = 1, C.WORLD_W do -- the road: two walkable rows
        grid[C.ROAD_Y][tx] = "p"
        grid[C.ROAD_Y + 1][tx] = "p"
    end
    for tx = C.CANOPY_X0, C.CANOPY_X1 do -- walk-behind band
        grid[C.ROAD_Y][tx] = "T"
    end
    local rows = {}
    for ty = 1, C.WORLD_H do rows[ty] = table.concat(grid[ty]) end
    return rows
end

-- ---- rigs (house palette: white player, dark NPCs + eye pixel) ----

local function playerArt(dir, frame)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(3, 1, 10, 10)
    gfx.fillRect(2, 8, 12, 9)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillEllipseInRect(4, 2, 8, 8)
    gfx.fillRect(3, 9, 10, 7)
    gfx.setColor(gfx.kColorBlack)
    if dir == Act.DOWN then
        gfx.fillRect(6, 5, 1, 2)
        gfx.fillRect(9, 5, 1, 2)
    elseif dir == Act.LEFT then
        gfx.fillRect(5, 5, 1, 2)
    elseif dir == Act.RIGHT then
        gfx.fillRect(10, 5, 1, 2)
    end
    local o = (frame == 1) and 0 or 2
    gfx.fillRect(4 + o, 16, 3, 3)
    gfx.fillRect(9 - o, 16, 3, 3)
end

local function npcArt(dir, frame)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(4, 2, 8, 8)
    gfx.fillRect(3, 9, 10, 7)
    gfx.setColor(gfx.kColorWhite)
    if dir == Act.LEFT then
        gfx.drawPixel(5, 5)
    else
        gfx.drawPixel(6, 5)
        gfx.drawPixel(9, 5)
    end
    gfx.setColor(gfx.kColorBlack)
    local o = (frame == 1) and 0 or 2
    gfx.fillRect(4 + o, 16, 3, 3)
    gfx.fillRect(9 - o, 16, 3, 3)
end

-- ---- content: one sheet, two grammars -----------------------------
-- artFn is parametric (w, h): lturn renders it at 48x48 into a
-- portrait slot, laction at 16x16 as a field sprite. One monster
-- definition, both battle engines.

local function miteArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.1, h * 0.35, w * 0.8, h * 0.5)
    gfx.drawLine(w * 0.2, h * 0.8, w * 0.08, h * 0.95)
    gfx.drawLine(w * 0.5, h * 0.85, w * 0.5, h * 0.98)
    gfx.drawLine(w * 0.8, h * 0.8, w * 0.92, h * 0.95)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(w * 0.35, h * 0.55, math.max(1, w * .05))
    gfx.fillCircleAtPoint(w * 0.65, h * 0.55, math.max(1, w * .05))
end

local function grubArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.06, h * 0.3, w * 0.88, h * 0.55)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, 3 do
        gfx.drawLine(w * (0.2 + i * 0.2), h * 0.32,
            w * (0.2 + i * 0.2), h * 0.84)
    end
    gfx.fillCircleAtPoint(w * 0.82, h * 0.46, math.max(1, w * .06))
end

local ITEMS = {
    herb = { name = "Herb", kind = "heal", power = 12, price = 6 },
    stick = { name = "Stick", kind = "weapon", power = 3,
        price = 5 },
}

local SKILLS = {
    gust = { name = "Gust", mp = 2, power = 9, kind = "dmg",
        target = "one", element = "wind" },
}

-- AGI 0 is not a typo: it pins the demo's one battle to a single
-- deterministic round (the walker always acts first and cannot
-- miss), so the battle figure lands on the frame it claims to.
local BESTIARY = {
    mite = {
        name = "Sod Mite", hp = 5, atk = 1, def = 0, agi = 0,
        xp = 6, gold = 3, ai = "basic", artFn = miteArt,
        elems = { wind = 1.5 },
    },
    -- the field foe: the SAME sheet, the other grammar. Tough
    -- enough to survive a charged swing, so the arc figure has
    -- something to be swung at.
    grub = {
        name = "Road Grub", hp = 90, atk = 4, def = 4, agi = 6,
        xp = 30, gold = 8, ai = "basic", artFn = grubArt,
        fspeed = 30,
    },
}

local SONGS = {
    field = {
        tempo = 100,
        patterns = {
            A = {
                bass = { 36, 0, 0, 0, 43, 0, 0, 0,
                    36, 0, 0, 0, 41, 0, 0, 0 },
                lead = { 60, 0, 64, 0, 67, 0, 64, 0,
                    60, 0, 64, 0, 65, 64, 62, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
            B = {
                bass = { 34, 0, 0, 0, 41, 0, 0, 0,
                    34, 0, 0, 0, 43, 0, 0, 0 },
                lead = { 62, 0, 65, 0, 69, 0, 65, 0,
                    62, 0, 65, 0, 67, 65, 64, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
        },
        order = { "A", "A", "B" },
    },
    battle = {
        tempo = 140,
        patterns = {
            A = {
                bass = { 33, 0, 33, 0, 33, 0, 33, 0,
                    31, 0, 31, 0, 36, 0, 35, 0 },
                lead = { 69, 0, 0, 68, 69, 0, 72, 0,
                    67, 0, 0, 66, 67, 0, 71, 0 },
                hat = { 1, 0, 1, 0, 1, 0, 1, 0,
                    1, 0, 1, 0, 1, 1, 1, 0 },
            },
        },
        order = { "A" },
    },
    fanfare = {
        tempo = 120,
        patterns = {
            A = {
                bass = { 48, 0, 0, 0, 48, 0, 0, 0,
                    43, 0, 0, 0, 48, 0, 0, 0 },
                lead = { 72, 0, 72, 0, 72, 0, 76, 0,
                    79, 0, 0, 0, 76, 0, 79, 0 },
            },
        },
        order = { "A", "A" },
    },
}

-- ---- a model of the chunk cache (screen one's readout) ------------
-- snip: demo-cache
-- lmap keeps its LRU pool private, so the demo mirrors it: replay
-- the SAME request stream (the chunks the camera covers, in the
-- same order) through the same 9-slot LRU and the model must
-- predict Map.builds exactly. Cache.ok going false would mean the
-- readout below is lying about the engine.
Cache = { slots = {}, tick = 0, blits = 0, builds = 0, ok = true }

function Cache.reset()
    for i = 1, Map.POOL do
        Cache.slots[i] = { key = -1, stamp = 0 }
    end
    Cache.tick, Cache.blits, Cache.builds = 0, 0, 0
end

local function touch(key)
    local best, bs
    for i = 1, Map.POOL do
        local r = Cache.slots[i]
        if r.key == key then
            r.stamp = Cache.tick
            return
        end
        if not bs or r.stamp < bs then best, bs = r, r.stamp end
    end
    best.key, best.stamp = key, Cache.tick -- evict the oldest
    Cache.builds = Cache.builds + 1
end

-- the chunk range lmap will ask for, from the same camera corner
function Cache.range(camx, camy)
    local mx = math.max(0, math.ceil(Map.W / Map.CW) - 1)
    local my = math.max(0, math.ceil(Map.H / Map.CH) - 1)
    local c0x = Util.clamp(math.floor(camx / Map.CPW), 0, mx)
    local c0y = Util.clamp(math.floor(camy / Map.CPH), 0, my)
    return c0x, Util.clamp(math.floor((camx + 399) / Map.CPW),
        c0x, mx),
        c0y, Util.clamp(math.floor((camy + 239) / Map.CPH),
            c0y, my)
end

function Cache.frame(camx, camy)
    Cache.tick = Cache.tick + 1
    local c0x, c1x, c0y, c1y = Cache.range(camx, camy)
    Cache.blits = 0
    for cy = c0y, c1y do
        for cx = c0x, c1x do
            touch(cy * 4096 + cx)
            Cache.blits = Cache.blits + 1
        end
    end
    Cache.ok = Cache.builds == Map.builds
end
-- endsnip

-- ---- the story ----------------------------------------------------
-- snip: demo-story
-- The playthrough: one coroutine, read top to bottom. Every call
-- blocks until the engine finishes it -- the dialog waits for A,
-- the choice waits for a pick, battle() waits for the scene to
-- pop. The autopilot supplies the A presses (input.lua); a thumb
-- would do just as well.
function Game.story()
    Script.run(function()
        face(G.warden, "left")
        face(G.player, "right")
        say("Warden", "This road runs east until the world does. "
            .. "Mind the sod mites in the grass.")
        local i = ask("Walk on?", { "Walk on", "Rest here" })
        if i == 1 then setflag("road_taken") end
        toast("A mite bristles in the verge!")
        local out = battle("mite")
        if out == "win" then setflag("mite_down") end
        State.save()
    end)
end
-- endsnip

-- ---- boot ---------------------------------------------------------

function Game.loadMap(name, tx, ty)
    G.mapName = name
    G.rows = G.rows or genRows()
    Map.load{ rows = G.rows, legend = LEGEND }
    Act.reset()
    Action.reset()
    Cache.reset()
    G.prig = G.prig or Act.rig(playerArt)
    G.nrig = G.nrig or Act.rig(npcArt)
    G.player = Act.new{
        kind = "player", x = Map.cx(tx), y = Map.cy(ty),
        hw = 5, hh = 5, speed = C.PLAYER_SPEED, sprite = G.prig,
    }
    G.warden = Act.new{
        kind = "warden", x = Map.cx(C.WARDEN_X),
        y = Map.cy(C.ROAD_Y + 1), hw = 5, hh = 5, speed = 40,
        sprite = G.nrig, behavior = { kind = "stand" },
    }
    Cam.reset()
    Cam.center(G.player.x, G.player.y)
    Script.followTarget = G.player
end

function Game.init()
    State.wipe() -- the tour always starts from a fresh ledger
    Party.defineItems(ITEMS)
    Party.defineSkills(SKILLS)
    Party.defineBestiary(BESTIARY)
    Party.add{
        id = "walker", name = "Walker", lvl = 1, hp = 40, mp = 6,
        atk = 8, def = 6, agi = 20,
        growth = { hp = 6, mp = 2, atk = 2, def = 1, agi = 1 },
        learn = { [2] = "gust" },
    }
    State.add("herb", 2)
    State.gold = 30
    Turn.defaults = { music = SONGS.battle, fanfare = SONGS.fanfare }
    Action.define{
        stick = { cooldown = 0.35, arc = { len = 14, wid = 18 },
            charge = { time = 0.5, mult = 2 } },
    }
    Script.loader = Game.loadMap
    Game.loadMap("world", C.START_X, C.ROAD_Y + 1)
    Music.play(SONGS.field)
    G.field = { kind = "field", update = Game.update,
        draw = Draw.frame }
end

-- ---- the field state ----------------------------------------------
-- snip: demo-field
-- The field is ONE state on the cabinet's stack. It only updates
-- while it is on top: push a dialog, a menu or a battle above it
-- and the world stops -- no pause flag, no mode enum, no
-- if-not-paused guards anywhere in this function.
function Game.update(dt)
    G.t = G.t + dt
    local p = G.player
    Act.walk(p, Input.mx, Input.my, dt)
    Act.updateAll(dt)
    Action.update(dt, Input.aHeld, p)
    Cam.update(dt)
    Cam.follow(p.x, p.y, dt)
    if Input.b then UI.menu() end
    if Input.frame > C.CACHE_OFF then Game.showCache = false end
end
-- endsnip

-- spawn the field foe the action leg hunts (screen four)
function Game.armAndSpawn()
    State.add("stick")
    Action.arm(G.player, "stick")
    G.foe = Action.spawn{
        id = "grub", x = G.player.x + 44, y = G.player.y,
        aggro = 90,
    }
end
