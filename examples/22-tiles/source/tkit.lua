-- vendored from tiles/core/tkit.lua (MIT)
-- Tiles core: shared game scaffolding — white HUD text, panels, cached
-- big text, 2D debris particles, screen shake and the painter-sorted
-- draw list. Same shapes as voxel's Kit, minus the projection.

local gfx = playdate.graphics

Kit = {}

local cache = {}

function Kit.bigText(text)
    local img = cache[text]
    if not img then
        local w, h = gfx.getTextSize(text)
        img = gfx.image.new(w, h)
        gfx.pushContext(img)
        gfx.drawText(text, 0, 0)
        gfx.popContext()
        cache[text] = img
    end
    return img
end

function Kit.panel(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, h)
end

function Kit.text(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Kit.centered(t, y)
    local w = gfx.getTextSize(t)
    Kit.text(t, math.floor((400 - w) / 2), y)
end

function Kit.bigCentered(text, y, scale)
    local img = Kit.bigText(text)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    img:drawScaled(math.floor((400 - img.width * scale) / 2), y, scale)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- title screen: big name + instruction lines (last line is the prompt)
function Kit.title(name, lines)
    local h = 78 + #lines * 18 + 14
    Kit.panel(46, 42, 308, h)
    Kit.bigCentered(name, 50, 3)
    for i, line in ipairs(lines) do
        Kit.centered(line, 94 + i * 18)
    end
end

-- game-over screen: big reason + sub lines
function Kit.over(reason, lines)
    Kit.panel(78, 70, 244, 50 + #lines * 18)
    Kit.bigCentered(reason, 80, 2)
    for i, line in ipairs(lines) do
        Kit.centered(line, 98 + i * 18)
    end
end

-- debris particles: 2x2 squares with velocity and a lifetime
function Kit.spawnPart(list, x, y, spread, up)
    if #list > 60 then return end
    list[#list + 1] = {
        x = x, y = y,
        vx = (math.random() - 0.5) * (spread or 90),
        vy = (math.random() - 0.5) * (spread or 90) - (up or 0),
        t = 0.35 + math.random() * 0.35,
        white = math.random() < 0.5,
    }
end

function Kit.burst(list, x, y, n, spread, up)
    for _ = 1, n do Kit.spawnPart(list, x, y, spread, up) end
end

function Kit.updateParts(list, dt, gravity)
    for i = #list, 1, -1 do
        local q = list[i]
        q.t = q.t - dt
        q.vy = q.vy + (gravity or 0) * dt
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        if q.t <= 0 then table.remove(list, i) end
    end
end

function Kit.drawParts(list)
    for i = 1, #list do
        local q = list[i]
        gfx.setColor(q.white and gfx.kColorWhite or gfx.kColorBlack)
        gfx.fillRect(math.floor(q.x), math.floor(q.y), 2, 2)
    end
end

-- screen shake: Kit.shake(0.25) on impacts, Kit.updateShake(dt) once per
-- frame, then add Kit.sx/Kit.sy to the map/actor draw offsets
Kit.shakeT, Kit.sx, Kit.sy = 0, 0, 0

function Kit.shake(t)
    Kit.shakeT = math.max(Kit.shakeT, t)
end

function Kit.updateShake(dt)
    Kit.shakeT = math.max(0, Kit.shakeT - dt)
    if Kit.shakeT > 0 then
        Kit.sx = math.random(-2, 2)
        Kit.sy = math.random(-2, 2)
    else
        Kit.sx, Kit.sy = 0, 0
    end
end

function Kit.applyShake()
    gfx.setDrawOffset(Kit.sx, Kit.sy)
end

function Kit.doneShake()
    gfx.setDrawOffset(0, 0)
end

-- ---- transitions: dither fade + white flash (wave-2 arcade kit) -----------
-- Kit.fadeTo(level01, cb): glide a black-speckle overlay 0 (clear) ..
-- 1 (black); Kit.run ticks it and draws it AFTER Draw.frame, so games
-- just call fadeTo (or the tscript fadeTo primitive). Kit.flash(secs)
-- is the one-beat white flash (lightning, boss phase turns).

local OVER = {} -- overlay patterns: 8 bitmap rows 0x00 + 8 alpha rows
do
    -- alpha = the inverse of the opaque fills' white bits, light->dark
    local src = {
        { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }, -- clear
        { 0xFF, 0xDD, 0xFF, 0xFF, 0xFF, 0x77, 0xFF, 0xFF },
        { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 },
        { 0x11, 0x00, 0x44, 0x00, 0x11, 0x00, 0x44, 0x00 },
        { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, -- black
    }
    for k = 1, 5 do
        local p = {}
        for y = 1, 8 do
            p[y] = 0x00
            p[y + 8] = ~src[k][y] & 0xFF
        end
        OVER[k] = p
    end
end

Kit.fadeLevel = 0
local fadeTarget, fadeCb, fadeSpeed = 0, nil, 2.5
local flashT = 0

function Kit.fadeTo(t01, cb, speed)
    fadeTarget = Util.clamp(t01, 0, 1)
    fadeCb = cb
    fadeSpeed = speed or 2.5
end

function Kit.fading()
    return Kit.fadeLevel ~= fadeTarget
end

function Kit.flash(secs)
    flashT = secs or 0.12
end

function Kit.updateFx(dt)
    if flashT > 0 then flashT = flashT - dt end
    local d = fadeTarget - Kit.fadeLevel
    if d ~= 0 then
        local step = fadeSpeed * dt
        if math.abs(d) <= step then
            Kit.fadeLevel = fadeTarget
            local cb = fadeCb
            fadeCb = nil
            if cb then cb() end
        else
            Kit.fadeLevel = Kit.fadeLevel + (d > 0 and step or -step)
        end
    end
end

function Kit.drawFx()
    if flashT > 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
    end
    if Kit.fadeLevel > 0.05 then
        local k = Util.clamp(math.floor(Kit.fadeLevel * 4 + 0.5) + 1,
            1, 5)
        gfx.setPattern(OVER[k])
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
    end
end

-- ---- HUD helpers ----------------------------------------------------------

-- a row of 8px hearts (filled/hollow) — the action-game HUD staple
function Kit.hearts(x, y, hp, max)
    for i = 1, max do
        local hx = x + (i - 1) * 11
        local filled = i <= hp
        gfx.setColor(filled and gfx.kColorWhite or gfx.kColorBlack)
        gfx.fillRect(hx + 1, y + 1, 3, 3)
        gfx.fillRect(hx + 5, y + 1, 3, 3)
        gfx.fillRect(hx, y + 3, 9, 3)
        gfx.fillTriangle(hx + 1, y + 6, hx + 8, y + 6, hx + 4, y + 9)
        gfx.setColor(gfx.kColorWhite)
        if not filled then
            gfx.drawRect(hx + 1, y + 2, 7, 4)
        end
    end
    gfx.setColor(gfx.kColorBlack)
end

-- a bordered meter (charge, fuse, boss hp)
function Kit.meter(x, y, w, cur, max)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, 8)
    local fw = math.floor((w - 4) * Util.clamp(cur / max, 0, 1))
    if fw > 0 then gfx.fillRect(x + 2, y + 2, fw, 4) end
    gfx.setColor(gfx.kColorBlack)
end

-- bold player locator: bobbing black-outlined white chevron above (x, y),
-- drawn after everything else so the player never vanishes into dither
function Kit.marker(x, y, t)
    local sy = math.floor(y + math.sin((t or 0) * 5) * 2 + 0.5)
    x = math.floor(x + 0.5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(x - 5, sy - 8, x + 5, sy - 8, x, sy)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillTriangle(x - 3, sy - 7, x + 3, sy - 7, x, sy - 2)
end

-- snip: kit-sorted
-- run a painter list of {y=, fn=, arg=}; insertion order breaks y ties
-- (table.sort is unstable) so equal-y actors never Z-flicker
function Kit.drawSorted(list)
    for i = 1, #list do list[i].seq = list[i].seq or i end
    table.sort(list, function(a, b)
        if a.y == b.y then return a.seq < b.seq end
        return a.y < b.y
    end)
    for i = 1, #list do
        local d = list[i]
        d.fn(d.arg)
    end
end
-- endsnip

-- snip: kit-run
-- Kit.run{ init=, extra=, shotPath= }: the shared main loop. Owns the
-- refresh rate, the random seed, the Harness wiring and the frame counter;
-- per frame it polls input, updates the game and pending callbacks, draws,
-- and folds updMs/drwMs EMAs into the smoke counters.
function Kit.run(opts)
    playdate.display.setRefreshRate(SMOKE_BUILD and 0 or 30)
    -- smoke runs are SEEDED (make <g>-smoke SEED=n): unpinned smoke
    -- passes are not evidence — every run must replay identically
    math.randomseed(SMOKE_BUILD and (SMOKE_SEED or 1)
        or playdate.getSecondsSinceEpoch())
    if opts.init then opts.init() end
    if Harness.enabled then
        Harness.extra = opts.extra
        if playdate.simulator then
            Harness.shotPath = opts.shotPath
        end
    end
    local frame = 0
    local updMs, drwMs = 0, 0
    local function tick()
        Input.poll()
        playdate.resetElapsedTime()
        Game.update(Config.DT)
        Util.runPending(Config.DT)
        Music.update(Config.DT)  -- music + transitions run under
        Kit.updateFx(Config.DT)  -- every game mode, engine-owned
        Cam.update(Config.DT)
        updMs = updMs * 0.95 + playdate.getElapsedTime() * 50
        playdate.resetElapsedTime()
        Draw.frame()
        Kit.drawFx()
        drwMs = drwMs * 0.95 + playdate.getElapsedTime() * 50
        Harness.set("updMs", math.floor(updMs * 10) / 10)
        Harness.set("drwMs", math.floor(drwMs * 10) / 10)
    end
    function playdate.update()
        frame = frame + 1
        Harness.frame(frame, tick)
    end
end
-- endsnip
