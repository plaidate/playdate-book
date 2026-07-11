-- vendored from voxel/core/kit.lua (MIT)
-- Voxel core: shared game scaffolding — white HUD text, panels, cached
-- big text, actor shadows, debris particles, the painter-sorted draw
-- list, screen shake, mode/banner timers, best-score persistence and the
-- Kit.run main loop. Games built after the first five lean on this
-- instead of duplicating it.

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

-- actor shadow. Pass the actor z to put the shadow on the surface at or
-- below the actor (VoxPhys.supportAt); without z it falls back to the
-- column TOP, which draws a tunneled actor's shadow on the roof above.
function Kit.shadow(x, y, hw, z)
    local g
    if z then
        g = VoxPhys.supportAt(x, y, hw, z + 0.001)
    else
        g = Vox.heightAt(math.floor(x), math.floor(y))
    end
    gfx.setPattern(Vox.PAT[1])
    local sx = math.floor(Vox.OX + (x - hw) * Vox.S + 0.5)
    local sy = math.floor(Vox.OY + y * Vox.TY - g * Vox.TZ + 0.5)
    gfx.fillRect(sx, sy, math.floor(hw * 2 * Vox.S + 0.5), Vox.TY)
end

-- m_or_opts is a material, or an opts table: { m=, count=, speed=,
-- vzMin=, vzMax= } (defaults match the plain-material call)
function Kit.spawnPart(list, x, y, z, m_or_opts)
    local m, count, speed, vzMin, vzMax = m_or_opts, 1, 13, 4, 13
    if type(m_or_opts) == "table" then
        local o = m_or_opts
        m = o.m or 4
        count = o.count or 1
        speed = o.speed or 13
        vzMin = o.vzMin or 4
        vzMax = o.vzMax or 13
    end
    for _ = 1, count do
        if #list > 40 then return end
        list[#list + 1] = {
            x = x, y = y, z = z,
            vx = (math.random() - 0.5) * speed,
            vy = (math.random() - 0.5) * speed,
            vz = vzMin + math.random() * (vzMax - vzMin),
            t = 0.6 + math.random() * 0.4,
            m = m,
        }
    end
end

-- snip: kit-parts
-- debris burst from Vox.carve()'s removed list
function Kit.burst(list, removed, n)
    for _ = 1, math.min(#removed, n) do
        local v = removed[math.random(#removed)]
        Kit.spawnPart(list, v[1], v[2], v[3], v[4])
    end
end

function Kit.updateParts(list, dt, gravity)
    gravity = gravity or Config.GRAVITY
    for i = #list, 1, -1 do
        local q = list[i]
        q.t = q.t - dt
        q.vz = q.vz - gravity * dt
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        q.z = q.z + q.vz * dt
        local g = Vox.heightAt(math.floor(q.x), math.floor(q.y))
        if q.z < g then
            q.z = g
            q.vz = -q.vz * 0.4
            q.vx, q.vy = q.vx * 0.6, q.vy * 0.6
        end
        if q.t <= 0 then table.remove(list, i) end
    end
end

function Kit.drawPart(q)
    Vox.drawBlock(q.x - 0.5, q.y, q.z, q.m)
    Vox.occlude(q.x - 1, q.x + 1, q.y, q.z, q.z + 1)
end
-- endsnip

-- snip: kit-marker
-- bold player locator: bobbing black-outlined white chevron above the
-- actor, drawn after everything so it survives occlusion
function Kit.marker(wx, wy, wz, t)
    local sx = math.floor(Vox.OX + wx * Vox.S + Vox.S / 2 + 0.5)
    local sy = math.floor(Vox.OY + wy * Vox.TY - wz * Vox.TZ + 0.5)
        - 8 + math.floor(math.sin((t or 0) * 5) * 2 + 0.5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(sx - 5, sy - 8, sx + 5, sy - 8, sx, sy)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillTriangle(sx - 3, sy - 7, sx + 3, sy - 7, sx, sy - 2)
end
-- endsnip

-- ---- painter list -------------------------------------------------------
-- Persistent, pooled painter list: Kit.sortClear() each frame, then
-- Kit.sortAdd(y, fn, arg [, z]) per drawable, then Kit.sortDraw(). No
-- per-frame table churn; sorted by y with a stable z-then-insertion-order
-- tiebreak (table.sort is unstable) so equal-y actors never Z-flicker.

local pool = {}  -- entry pool, stable storage, grows to the high-water mark
local order = {} -- the array handed to table.sort (refs into pool)
local poolN = 0

local function painterLess(a, b)
    if a.y ~= b.y then return a.y < b.y end
    if a.z ~= b.z then return a.z < b.z end
    return a.seq < b.seq
end

function Kit.sortClear()
    poolN = 0
end

function Kit.sortAdd(y, fn, arg, z)
    poolN = poolN + 1
    local e = pool[poolN]
    if not e then
        e = {}
        pool[poolN] = e
    end
    e.y, e.z, e.fn, e.arg, e.seq = y, z or 0, fn, arg, poolN
end

function Kit.sortDraw()
    for i = 1, poolN do order[i] = pool[i] end
    for i = #order, poolN + 1, -1 do order[i] = nil end
    table.sort(order, painterLess)
    for i = 1, poolN do
        local d = order[i]
        d.fn(d.arg)
    end
end

-- run a painter list of {y=, fn=, arg=} (older games; new code uses
-- sortClear/sortAdd/sortDraw directly)
function Kit.drawSorted(list)
    Kit.sortClear()
    for i = 1, #list do
        local d = list[i]
        Kit.sortAdd(d.y, d.fn, d.arg, d.z)
    end
    Kit.sortDraw()
end

-- ---- screen shake ---------------------------------------------------------
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

-- ---- modes ----------------------------------------------------------------
-- Tiny mode/banner helper: Kit.setMode("play", 1.2) sets Kit.mode and a
-- countdown Kit.modeT that Kit.run ticks toward 0 — replaces the
-- hand-rolled title/over/banner timers. Games keep their own draw code
-- and check Kit.mode / Kit.modeT in update.
Kit.mode = "title"
Kit.modeT = 0

function Kit.setMode(m, bannerT)
    Kit.mode = m
    Kit.modeT = bannerT or 0
end

-- snip: kit-best
-- ---- best-score persistence ------------------------------------------------
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
-- endsnip

-- snip: kit-run
-- ---- the cabinet ------------------------------------------------------------
-- Kit.run{ init=, extra=, shotPath= }: the shared main loop. Owns the
-- refresh rate, the random seed, the Harness wiring and the frame counter;
-- per frame it polls input, updates the game and pending callbacks, draws,
-- and folds updMs/drwMs EMAs into the smoke counters.
function Kit.run(opts)
    playdate.display.setRefreshRate(SMOKE_BUILD and 0 or 30)
    math.randomseed(playdate.getSecondsSinceEpoch())
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
        Kit.modeT = math.max(0, Kit.modeT - Config.DT)
        Game.update(Config.DT)
        Util.runPending(Config.DT)
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
-- endsnip
