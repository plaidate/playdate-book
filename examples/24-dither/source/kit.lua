-- vendored from dither/core/kit.lua (MIT)
-- Dither core: the fleet cabinet — white HUD text, panels, cached big
-- text, 2D debris particles with floor bounce, screen shake, mode and
-- banner timers, best-score persistence and the Kit.run main loop.
-- Same shapes as tiles/voxel's Kit; games lean on this instead of
-- duplicating it.

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

-- ---- debris particles ---------------------------------------------
-- 2x2 squares with velocity, a lifetime and (optionally) a floor to
-- bounce off with friction. 60 cap per list.

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

-- floorY (optional): particles bounce there, vy * -0.4, vx * 0.6
function Kit.updateParts(list, dt, gravity, floorY)
    for i = #list, 1, -1 do
        local q = list[i]
        q.t = q.t - dt
        q.vy = q.vy + (gravity or 0) * dt
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        if floorY and q.y > floorY and q.vy > 0 then
            q.y = floorY
            q.vy = -q.vy * 0.4
            q.vx = q.vx * 0.6
        end
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

-- ---- screen shake ---------------------------------------------------
-- Kit.shake(0.25) on impacts, Kit.updateShake(dt) once per frame, then
-- either add Kit.sx/Kit.sy to draw offsets or bracket the scene with
-- Kit.applyShake() / Kit.doneShake()
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

-- bold player locator: bobbing black-outlined white chevron above
-- (x, y), drawn after everything so the player never sinks into dither
function Kit.marker(x, y, t)
    local sy = math.floor(y + math.sin((t or 0) * 5) * 2 + 0.5)
    x = math.floor(x + 0.5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(x - 5, sy - 8, x + 5, sy - 8, x, sy)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillTriangle(x - 3, sy - 7, x + 3, sy - 7, x, sy - 2)
end

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

-- ---- modes -----------------------------------------------------------
-- Kit.setMode("play", 1.2) sets Kit.mode and a countdown Kit.modeT that
-- Kit.run ticks toward 0 — replaces hand-rolled title/over/banner
-- timers. Games keep their own draw code and check Kit.mode/Kit.modeT.
Kit.mode = "title"
Kit.modeT = 0

function Kit.setMode(m, bannerT)
    Kit.mode = m
    Kit.modeT = bannerT or 0
end

-- ---- best-score persistence -------------------------------------------
-- Write-on-record: saveBest only touches the datastore when the score
-- beats the loaded best (and is nonzero); returns true on a new record.
Kit.best = 0

function Kit.loadBest()
    local saved = playdate.datastore.read("best")
    Kit.best = (saved and saved.best) or 0
    return Kit.best
end

function Kit.saveBest(score)
    if score > Kit.best and score > 0 then
        Kit.best = score
        playdate.datastore.write({ best = score }, "best")
        return true
    end
    return false
end

-- ---- HUD furniture ----------------------------------------------------
-- A dithered bar is the fleet's resource readout: wick, fuel, oxygen,
-- alarm. frac 0..1; the fill uses the Shade ramp so a half-empty bar
-- reads as gray, not as a lie about a 1-bit screen.
function Kit.meter(x, y, w, h, frac, level)
    frac = Util.clamp(frac or 0, 0, 1)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x - 1, y - 1, w + 2, h + 2)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x - 1, y - 1, w + 2, h + 2)
    local fw = math.floor(w * frac + 0.5)
    if fw > 0 then
        Shade.set(level or 0) -- 0 = solid white fill
        gfx.fillRect(x, y, fw, h)
        gfx.setColor(gfx.kColorBlack)
    end
end

-- vertical menu: rows is an array of strings (or {label=, sub=}),
-- sel is 1-based. Returns the panel height so callers can centre it.
function Kit.list(title, rows, sel, x, y, w)
    local rh = 20
    local h = 30 + #rows * rh + 6
    Kit.panel(x, y, w, h)
    Kit.text(title, x + 10, y + 6)
    for i = 1, #rows do
        local r = rows[i]
        local label = type(r) == "table" and r.label or r
        local ry = y + 28 + (i - 1) * rh
        if i == sel then
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(x + 6, ry - 2, w - 12, rh - 2)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.drawText(label, x + 14, ry)
            if type(r) == "table" and r.sub then
                local sw = gfx.getTextSize(r.sub)
                gfx.drawText(r.sub, x + w - 14 - sw, ry)
            end
        else
            Kit.text(label, x + 14, ry)
            if type(r) == "table" and r.sub then
                local sw = gfx.getTextSize(r.sub)
                Kit.text(r.sub, x + w - 14 - sw, ry)
            end
        end
    end
    return h
end

-- the three save cards, drawn from Save.summary — the shared
-- Continue/New Game screen. sel 1..Save.SLOTS.
function Kit.slots(sel, x, y, w)
    local rows = {}
    for s = 1, Save.SLOTS do
        local m = Save.summary(s)
        rows[s] = {
            label = "Slot " .. s,
            sub = m and ((m.place or "-") .. "  " .. (m.pct or 0) .. "%")
                or "empty",
        }
    end
    return Kit.list("SELECT SLOT", rows, sel, x or 110, y or 60, w or 180)
end

-- ---- the cabinet ---------------------------------------------------------
-- Kit.run{ init=, extra=, shotPath= }: the shared main loop. Owns the
-- refresh rate, the random seed, the Harness wiring and the frame
-- counter; per frame it polls input, ticks Kit.modeT, updates the game
-- and pending callbacks, draws, and folds updMs/drwMs EMAs into the
-- smoke counters. Note: in dither the Makefile already injects
-- SMOKE_SHOT_PATH via smokeflag.lua and harness.lua picks it up, so
-- opts.shotPath is an optional override, not a requirement.
--
-- Seeding: smoke builds seed from SMOKE_SEED (the Makefile writes it
-- from `make <g>-smoke SEED=n`), so a smoke run is REPRODUCIBLE — an
-- autopilot that passes at seed 1 and fails at seed 4 is a real bug,
-- not weather. Release builds seed from the clock as before.
function Kit.run(opts)
    playdate.display.setRefreshRate(SMOKE_BUILD and 0 or 30)
    if SMOKE_BUILD and SMOKE_SEED then
        math.randomseed(SMOKE_SEED)
        Harness.set("seed", SMOKE_SEED)
    else
        math.randomseed(playdate.getSecondsSinceEpoch())
    end
    if opts.init then opts.init() end
    if Harness.enabled then
        Harness.extra = opts.extra
        if opts.shotPath and playdate.simulator then
            Harness.shotPath = opts.shotPath
        end
    end
    local frame = 0
    local updMs, drwMs = 0, 0
    local function tick()
        local dt = (C and C.DT) or 1 / 30
        Input.poll()
        playdate.resetElapsedTime()
        Kit.modeT = math.max(0, Kit.modeT - dt)
        Game.update(dt)
        Util.runPending(dt)
        updMs = updMs * 0.95 + playdate.getElapsedTime() * 50
        playdate.resetElapsedTime()
        Draw.frame()
        drwMs = drwMs * 0.95 + playdate.getElapsedTime() * 50
        Harness.set("updMs", math.floor(updMs * 10) / 10)
        Harness.set("drwMs", math.floor(drwMs * 10) / 10)
    end
    function playdate.update()
        frame = frame + 1
        Harness.frame(frame, tick)
    end
end
