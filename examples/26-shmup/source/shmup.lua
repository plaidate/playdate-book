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

-- Wave 2 adds the campaign states. Autopilots key off these numbers
-- (Harness "state"): 1 title, 2 play, 3 over, 4 win, 5 briefing
-- (mash the start edge), 6 stage tally (auto), 7 initials entry
-- (mash start for "AAA", or steer with the d-pad edges).
local TITLE, PLAY, OVER, WIN = 1, 2, 3, 4
local BRIEF, TALLY, ENTRY = 5, 6, 7
local EXTEND_AT <const> = 20000
local fuelRate = 3.4

local state, score, booms, content
local useTerrain, useFuel, scene
local extended
local stages, stageI = nil, 1
local finalBossDown, lastDefeated = false, false
local tallyT, tallyBonus = 0, 0
local entry = nil     -- the initials widget when a score places
local pendingRank = nil
local afterBrief = nil
local prev = { start = false, bomb = false, left = false,
    right = false, up = false, down = false }

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
    Harness.set("stage", stageI)
    Harness.set("bombs", Player.bombs or 0)
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
-- THE win condition, per stage. If the stage has a FINAL boss, that boss is
-- the ending -- full stop (mid-bosses gate the road, not the stage). Only a
-- stage with no final boss falls back to "the spawn script ran out".
local function stageWon()
    if Waves.hasBoss then return finalBossDown end
    return Waves.finished()
end
-- endsnip

--------------------------------------------------------------------------------
-- The campaign (wave 2). content.stages = { { name=, sub=, brief=,
-- waves=, music=, terrain=, scene=, speed=, levelW= }, ... } -- plus
-- content.brief (the opening briefing), content.ending (the closing
-- one) and content.fanfare (stage-clear stinger). A game without
-- .stages is wrapped into one stage and plays exactly as v1.0 did.

local function loadStage(si)
    stageI = si
    local st = stages[si]
    Frame.init {
        mode = Frame.mode,
        speed = st.speed or 0,
        levelW = st.levelW,
        top = content.top,
        bottom = content.bottom,
    }
    if st.terrain then
        useTerrain = true
        Terrain.init(st.terrain)
        Terrain.reset()
    else
        useTerrain = false
        Terrain.active = false
    end
    scene = st.scene
    Bullets.clear()
    Enemies.clear()
    Power.clear()
    Boss.reset()
    Fx.reset()
    booms:clear()
    finalBossDown, lastDefeated = false, false
    if useFuel then Player.fuel = 100 end
    Player.x, Player.y = Frame.spawnPoint()
    if scene and scene.build then scene.build() end
    Waves.load(st.waves)
    if st.music or content.music then
        Music.set(st.music or content.music)
    end
    state = PLAY
end

-- run a briefing (beats + an optional stage card), then thenFn
local function briefInto(beats, card, thenFn)
    local list = {}
    if beats then
        for i = 1, #beats do list[#list + 1] = beats[i] end
    end
    if card then list[#list + 1] = card end
    if #list == 0 then
        thenFn()
        return
    end
    state = BRIEF
    Story.play(list, thenFn)
end

local function stageCard(si)
    local st = stages[si]
    if #stages == 1 and not st.name then return nil end
    return { card = true, title = st.name or ("STAGE " .. si),
        sub = st.sub }
end

local function gotoStage(si, withIntro)
    briefInto(withIntro and content.brief or stages[si].brief,
        stageCard(si), function() loadStage(si) end)
end

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

    -- normalize: a stage-less game IS a one-stage campaign
    stages = c.stages or { {
        waves = c.waves, music = c.music, terrain = c.terrain,
        scene = c.scene, speed = c.speed, levelW = c.levelW,
    } }
    stageI = 1

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
    Player.reset(content.bombs)
    Stars.init()
    pendingRank, entry = nil, nil
    gotoStage(1, true)
end

function Shmup.update(dt)
    local input = readInput()
    Music.update(dt)

    -- edges: humans give buttonJustPressed for start already; bots
    -- hold fields, so every state below consumes EDGES, never levels
    local startEdge = input.start and not prev.start
    local fireEdge = input.fire and not prev.fire
    local bombEdge = input.bomb and not prev.bomb
    local eL = input.left and not prev.left
    local eR = input.right and not prev.right
    local eU = input.up and not prev.up
    local eD = input.down and not prev.down
    prev.start, prev.fire, prev.bomb = input.start, input.fire, input.bomb
    prev.left, prev.right = input.left, input.right
    prev.up, prev.down = input.up, input.down

    if state == TITLE then
        Stars.update(dt)
        if startEdge then startGame() end
        report()
        return
    elseif state == BRIEF then
        Stars.update(dt)
        Story.update(dt, startEdge or fireEdge)
        report()
        return
    elseif state == TALLY then
        Stars.update(dt)
        tallyT = tallyT - dt
        if tallyT <= 0 or startEdge then
            gotoStage(stageI + 1)
        end
        report()
        return
    elseif state == ENTRY then
        Stars.update(dt)
        entry:update(dt, (eR and 1 or 0) - (eL and 1 or 0),
            (eD and 1 or 0) - (eU and 1 or 0), startEdge or fireEdge)
        if entry.done then
            entry = nil
            pendingRank = nil
            state = TITLE
        end
        report()
        return
    elseif state == OVER or state == WIN then
        Stars.update(dt)
        updateBooms(dt)
        Fx.update(dt)
        if startEdge then
            if pendingRank then
                entry = Kit.entry(score, pendingRank)
                state = ENTRY
            else
                state = TITLE
            end
        end
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

    -- boss-kill edge: mid-bosses count, only a FINAL boss ends a stage
    if Boss.defeated and not lastDefeated then
        Harness.count("bossKills")
        if not Boss.mid then finalBossDown = true end
    end
    lastDefeated = Boss.defeated

    -- the smart bomb (B where there is no floor to drop bombs on):
    -- clears every enemy bullet, sears the field, staggers the boss
    if bombEdge and not Terrain.active and Player.alive
        and Player.useBomb() then
        Bullets.ep:each(function(b) b.dead = true end)
        Enemies.pool:each(function(e)
            if not e.dead then
                e.hp = e.hp - 12
                if e.hp <= 0 then killEnemy(e) end
            end
        end)
        if Boss.active then Boss.damage(9) end
        Fx.shake(8)
        Shmup.boom(Player.x, Player.y - 24)
        Shmup.boom(Player.x - 40, Player.y - 60)
        Shmup.boom(Player.x + 40, Player.y - 60)
        Snd.bomb()
    end

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
        pendingRank = Kit.submit(score)
        Music.stop()
    elseif stageWon() then
        Harness.count("stagesCleared")
        if stageI < #stages then
            tallyBonus = Player.lives * 500 + (Player.bombs or 0) * 300
            addScore(tallyBonus)
            tallyT = 2.4
            state = TALLY
            if content.fanfare then
                Music.stinger(content.fanfare, true)
            end
        else
            -- the campaign is won HERE (the latch survives the
            -- ending briefing and the score table)
            wins = wins + 1
            pendingRank = Kit.submit(score)
            if content.fanfare then
                Music.stinger(content.fanfare, true)
            end
            if content.ending then
                briefInto(content.ending, nil,
                    function() state = WIN end)
            else
                Music.stop()
                state = WIN
            end
        end
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

    -- smart-bomb stock (only where B is the big one)
    if not Terrain.active then
        for i = 1, (Player.bombs or 0) do
            gfx.fillCircleAtPoint(102 + i * 9, 8, 3)
        end
    end

    -- the campaign readout
    if #stages > 1 then
        Kit.text("S" .. stageI .. "/" .. #stages, 300, 3)
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
    elseif state == BRIEF then
        Story.draw()
        return
    elseif state == TALLY then
        Kit.centered("STAGE " .. stageI .. " CLEAR", 84)
        Kit.centered(string.format("BONUS  %d", tallyBonus), 108)
        Kit.centered(string.format("SCORE  %06d", score), 128)
        return
    elseif state == ENTRY then
        if entry then entry:draw() end
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
