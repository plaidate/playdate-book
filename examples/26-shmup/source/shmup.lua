-- vendored from shmup/core/shmup.lua (MIT)
-- shmup core: the engine. Ties the subsystems together, owns the state machine
-- (title/play/over/win), runs collision, and drives the cabinet.
--
-- A game is a Content table and nothing else:
--
--   content = {
--     scroll   = "vertical" | "side" | "free",  -- WHICH FRAME. The one choice
--                                               -- that changes everything.
--     title    = "NOVA STRIKE",
--     speed    = 66,      -- world speed         (side)
--     levelW   = 2400,    -- level extent        (free)
--     top, bottom,        -- the player's box    (optional)
--     sprites  = function() Sprites.define(...) end,   -- game art hook
--     terrain  = { ... },              -- optional Scramble cavern (side)
--     scene    = { build=, update=, draw=, hits= },    -- optional static level
--     fuel     = true,                 -- optional depleting gauge
--     music    = { bpm =, bass =, ... },
--     enemies  = { name = { sprite, hp, r, score, fuel, drop, move, fire } },
--     bosses   = { name = { sprite, hp, r, score, enter, from, phases } },
--     waves    = { { t, type, x, y, n, dx, dy }, { t, boss = "name" } },
--     enemyCap = 64,
--   }

import "CoreLibs/graphics"
local gfx <const> = playdate.graphics

Shmup = {}

local TITLE, PLAY, OVER, WIN = 1, 2, 3, 4
local EXTEND_AT <const> = 20000
local fuelRate = 3.4

local state, score, booms, content
local useTerrain, useFuel, scene
local extended

-- Latches, not levels. The smoke test asks "did the bot ever WIN?", and the
-- answer has to survive the bot pressing A on the victory screen and starting a
-- fresh run: a counter that only reports the CURRENT state answers "no" a
-- second later, and a green smoke run that quietly forgot it won is worse than
-- no smoke run at all.
local wins, deaths = 0, 0

local function report()
    Harness.set("state", state)
    Harness.set("wins", wins)
    Harness.set("deaths", deaths)
    Harness.set("score", score)
    Harness.set("best", Kit.best)
end

--------------------------------------------------------------------------------
local function readInput()
    if Harness.enabled and Harness.autopilot then return Harness.autopilot() end
    local pd = playdate
    return {
        left  = pd.buttonIsPressed(pd.kButtonLeft),
        right = pd.buttonIsPressed(pd.kButtonRight),
        up    = pd.buttonIsPressed(pd.kButtonUp),
        down  = pd.buttonIsPressed(pd.kButtonDown),
        fire  = pd.buttonIsPressed(pd.kButtonA),
        bomb  = pd.buttonIsPressed(pd.kButtonB),
        start = pd.buttonJustPressed(pd.kButtonA),
    }
end

function Shmup.boom(x, y)
    local b = booms:spawn()
    if b then b.x, b.y, b.t = x, y, 0 end
    Snd.boom()
end

local function updateBooms(dt)
    booms:update(function(b)
        b.t = b.t + dt
        if 1 + math.floor(b.t / 0.05) > #Sprites.boom then b.dead = true end
    end)
end

local function addScore(n)
    score = score + n
    if not extended and score >= EXTEND_AT then
        extended = true
        Player.lives = Player.lives + 1
        Snd.extend()
    end
end

-- What killed us, counted by cause. Every hit on the player goes through
-- hurtPlayer, so this is free -- and without it, tuning a bot is guesswork: you
-- can see THAT it died at 93% of the level and not WHY, and you will spend an
-- afternoon hardening its bullet-dodging when it was flying into the wall.
Shmup.causes = { terrain = 0, scene = 0, bullet = 0, enemy = 0, boss = 0, fuel = 0 }
local cause = "?"

-- One hit on the player. A shield eats it; otherwise it costs a life. Exactly
-- one place knows whether a hit was survivable.
local function hurtPlayer(x, y)
    Shmup.causes[cause] = (Shmup.causes[cause] or 0) + 1
    if Player.shield then
        Player.shield = false
        Player.invuln = 1.0
        Fx.shake(4)
        Snd.hit()
        return
    end
    Shmup.boom(x or Player.x, y or Player.y)
    Fx.shake(6)
    Snd.die()
    if not Player.loseLife() then state = OVER end
end

local function killEnemy(e)
    e.dead = true
    addScore(e.spec.score or 100)
    if useFuel and e.spec.fuel then
        Player.fuel = math.min(100, Player.fuel + e.spec.fuel)
    end
    Power.maybeDrop(e.spec, e.x, e.y)
    Shmup.boom(e.x, e.y)
end

local function collide()
    -- player shots and bombs vs enemies, the boss, and the ground
    Bullets.pp:each(function(b)
        if b.dead then return end
        if useTerrain and b.grav and Terrain.hits(b.x, b.y, 2) then
            b.dead = true
            Shmup.boom(b.x, b.y)
            return
        end
        if Boss.hits(b.x, b.y, b.r) then
            b.dead = true
            if Boss.damage(b.dmg) then addScore(Boss.spec.score or 5000) end
            return
        end
        Enemies.pool:each(function(e)
            if b.dead or e.dead then return end
            if Lib.circlesHit(b.x, b.y, b.r, e.x, e.y, e.r) then
                b.dead = true
                e.hp = e.hp - b.dmg
                e.hit = 0.06
                if e.hp <= 0 then killEnemy(e) else Snd.hit() end
            end
        end)
    end)

    Power.collect()

    if not Player.vulnerable() then return end

    if useTerrain and Terrain.hits(Player.x, Player.y, Player.r) then
        cause = "terrain"
        hurtPlayer()
        return
    end

    if scene and scene.hits and scene.hits(Player.x, Player.y, Player.r) then
        cause = "scene"
        hurtPlayer()
        return
    end

    Bullets.ep:each(function(b)
        if b.dead or not Player.vulnerable() then return end
        if Lib.circlesHit(b.x, b.y, b.r, Player.x, Player.y, Player.r) then
            b.dead = true
            cause = "bullet"
            hurtPlayer()
        end
    end)

    Enemies.pool:each(function(e)
        if e.dead or not Player.vulnerable() then return end
        if Lib.circlesHit(e.x, e.y, e.r, Player.x, Player.y, Player.r) then
            e.dead = true
            Shmup.boom(e.x, e.y)
            cause = "enemy"
            hurtPlayer(e.x, e.y)
        end
    end)

    if Boss.active and Player.vulnerable()
        and Lib.circlesHit(Boss.x, Boss.y, Boss.spec.r or 30,
            Player.x, Player.y, Player.r) then
        cause = "boss"
        hurtPlayer()
    end
end

-- snip: shmup-won
-- THE win condition. If the level has a boss, the boss IS the ending -- full
-- stop. Only a level with no boss falls back to "the spawn script ran out".
local function won()
    if Waves.hasBoss then return Boss.defeated end
    return Waves.finished()
end
-- endsnip

--------------------------------------------------------------------------------
function Shmup.new(c)
    content = c
    local mode = c.scroll or "vertical"
    if mode == "horizontal" then mode = "side" end   -- the old spelling

    Frame.init {
        mode = mode,
        speed = c.speed or 0,
        levelW = c.levelW,
        top = c.top,
        bottom = c.bottom,
    }

    useTerrain = c.terrain ~= nil
    useFuel = c.fuel and true or false
    fuelRate = c.fuelRate or 3.4
    scene = c.scene

    Sprites.init()
    if c.sprites then c.sprites() end
    Bullets.init()
    Enemies.init(c.enemyCap or 64)
    Power.init()
    booms = Pool.new(24)

    for name, spec in pairs(c.enemies or {}) do Enemies.define(name, spec) end
    for name, spec in pairs(c.bosses or {}) do Boss.define(name, spec) end

    if useTerrain then Terrain.init(c.terrain) end

    Kit.loadBest()
    Stars.init()
    Boss.reset()
    Player.reset()
    score = 0
    extended = false
    state = TITLE
end

local function startGame()
    score = 0
    extended = false
    Frame.reset()
    Player.reset()
    Bullets.clear()
    Enemies.clear()
    Power.clear()
    Boss.reset()
    Fx.reset()
    booms:clear()
    Stars.init()
    if useTerrain then Terrain.reset() end
    if scene and scene.build then scene.build() end
    Waves.load(content.waves)
    if content.music then Music.set(content.music) end
    state = PLAY
end

function Shmup.update(dt)
    local input = readInput()
    Music.update(dt)

    if state == TITLE then
        Stars.update(dt)
        if input.start then startGame() end
        report()
        return
    elseif state == OVER or state == WIN then
        Stars.update(dt)
        updateBooms(dt)
        Fx.update(dt)
        if input.start then state = TITLE end
        report()
        return
    end

    -- Hitstop: the world holds still for a few frames on a big kill. The DRAW
    -- still runs; only the simulation pauses.
    Fx.update(dt)
    if Fx.frozen() then return end

    -- The frame advances FIRST. Everything downstream -- the terrain profile,
    -- the world-to-screen transform, what counts as offscreen -- is a question
    -- about where the world is *right now*.
    Frame.advance(dt, Player.x)

    Stars.update(dt)
    if useTerrain then Terrain.update(dt) end
    if scene and scene.update then scene.update(dt) end
    Bullets.update(dt)
    Enemies.update(dt)
    Power.update(dt)
    Boss.update(dt)
    Player.update(dt, input)
    Waves.update(dt)
    collide()
    updateBooms(dt)

    if useFuel and Player.alive then
        Player.fuel = Player.fuel - fuelRate * dt
        if Player.fuel <= 0 then
            Player.fuel = 0
            cause = "fuel"
            hurtPlayer()
        end
    end

    if not Player.alive then
        state = OVER
        deaths = deaths + 1
        Kit.saveBest(score)
        Music.stop()
    elseif won() then
        state = WIN
        wins = wins + 1
        Kit.saveBest(score)
        Music.stop()
    end

    Harness.set("lives", Player.lives)
    Harness.set("enemies", Enemies.count())
    Harness.set("weapon", Player.weapon)
    Harness.set("bossHp", Boss.active and math.floor(Boss.hp) or -1)
    Harness.set("progress", math.floor(Frame.progress() * 100))
    report()
end

--------------------------------------------------------------------------------
local function drawHUD()
    -- Over terrain (solid white) a bare white score is invisible, so the strip
    -- gets a black plate. Cheap insurance, and free in the space games.
    if useTerrain or scene then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, SCREEN_W, 16)
    end

    Kit.text(string.format("%06d", score), 6, 3)

    for i = 1, Player.lives do
        Sprites.imgs.player.img:draw(SCREEN_W - 6 - i * 14, 2)
    end

    -- The weapon ladder as pips: three dots is a language the player learns in
    -- one power-up.
    gfx.setColor(gfx.kColorWhite)
    for i = 1, 3 do
        local x = 66 + i * 8
        if i <= Player.weapon then
            gfx.fillRect(x, 6, 5, 5)
        else
            gfx.drawRect(x, 6, 5, 5)
        end
    end

    if useFuel then
        local w = 100
        local x = (SCREEN_W - w) // 2
        local y = useTerrain and 6 or (SCREEN_H - 9)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(x, y, w, 5)
        gfx.fillRect(x, y, math.floor(w * Player.fuel / 100), 5)
    elseif Frame.free then
        -- The position bar IS the free frame's HUD: it is the only way to see
        -- that a level with two ends has ends.
        local w = 120
        local x = (SCREEN_W - w) // 2
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(x, 5, w, 5)
        gfx.fillRect(x + math.floor((w - 6) * Frame.progress()), 4, 6, 7)
    end
end

function Shmup.draw()
    Stars.draw()

    if state == TITLE then
        Kit.centered(content.title or "SHMUP", 76)
        if content.subtitle then Kit.centered(content.subtitle, 100) end
        if Kit.best > 0 then
            Kit.centered(string.format("BEST %06d", Kit.best), 122)
        end
        Kit.centered("PRESS A", 150)
        return
    end

    Fx.push()
    if useTerrain then Terrain.draw() end
    if scene and scene.draw then scene.draw() end
    Enemies.draw()
    Boss.draw()
    Power.draw()
    Bullets.draw()
    Player.draw()
    booms:each(function(b)
        Sprites.drawBoom(1 + math.floor(b.t / 0.05), Frame.toScreenX(b.x), b.y)
    end)
    Fx.pop()

    drawHUD()

    if state == OVER then
        Kit.centered("GAME OVER", 96)
        Kit.centered("PRESS A", 128)
    elseif state == WIN then
        Kit.centered(content.winText or "CLEAR!", 96)
        Kit.centered(string.format("SCORE %06d", score), 118)
        Kit.centered("PRESS A", 146)
    end
end

--------------------------------------------------------------------------------
-- The cabinet. A game's main.lua is now: import the engine, import its content,
-- call this. Everything below here used to be copy-pasted into every game.
function Shmup.run(c, opts)
    opts = opts or {}
    playdate.display.setRefreshRate(SMOKE_BUILD and 0 or 30)

-- snip: smoke-seed
    -- A shipped game seeds from the clock. A SMOKE build must not: seeded from
    -- the clock, every run is a different game, so a green run proves nothing
    -- and a red one is indistinguishable from bad luck. (This engine's bot
    -- passed seven runs in eight, which is the worst possible result: too good
    -- to look broken, too flaky to trust.) The Makefile writes SMOKE_SEED and
    -- tools/smoke.sh sweeps a few of them, so a failure is a fact you can
    -- reproduce by name rather than a mood.
    if SMOKE_BUILD then
        math.randomseed(SMOKE_SEED or 1)
    else
        math.randomseed(playdate.getSecondsSinceEpoch())
    end
-- endsnip

    Shmup.new(c)

    if Harness.enabled then
        Harness.autopilot = opts.autopilot
        Harness.extra = opts.extra
        if SMOKE_SHOT_PATH and playdate.simulator then
            Harness.shotPath = SMOKE_SHOT_PATH
        end
    end

    playdate.getSystemMenu():addMenuItem("restart", function()
        state = TITLE
        Music.stop()
    end)

    local frame = 0
    local updMs, drwMs = 0, 0
    local DT <const> = 1 / 30

    local function tick()
        playdate.resetElapsedTime()
        Shmup.update(DT)
        updMs = updMs * 0.95 + playdate.getElapsedTime() * 50
        playdate.resetElapsedTime()
        Shmup.draw()
        drwMs = drwMs * 0.95 + playdate.getElapsedTime() * 50
        Harness.set("updMs", math.floor(updMs * 10) / 10)
        Harness.set("drwMs", math.floor(drwMs * 10) / 10)
    end

    function playdate.update()
        frame = frame + 1
        Harness.frame(frame, tick)
    end
end
