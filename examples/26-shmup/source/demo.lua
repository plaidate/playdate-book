-- Chapter 26's demo: the same engine, three frames.
--
-- Three tiny levels, one per scroll frame, played back to back by a scripted
-- bot. They share an enemy library and differ only in the fields that pick a
-- frame -- which is the chapter's whole argument, expressed as data.
--
-- The last phase is not a game at all: it is a diagram of the bug the terrain
-- rewrite fixed. The error it shows is under a pixel at 1:1, so the diagram
-- magnifies it -- which is exactly why the bug survived so long.

local gfx <const> = playdate.graphics

Demo = {}

--------------------------------------------------------------------------------
-- shared art

local function art()
    Sprites.define("dread", 96, 44, function(w, h)
        gfx.fillRect(8, 4, w - 16, h - 18)
        gfx.fillTriangle(0, 10, 8, 4, 8, h - 14)
        gfx.fillTriangle(w, 10, w - 8, 4, w - 8, h - 14)
        gfx.fillTriangle(w / 2 - 26, h - 14, w / 2 + 26, h - 14, w / 2, h)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(20, 10, 8, 7)
        gfx.fillRect(w - 28, 10, 8, 7)
        gfx.setColor(gfx.kColorWhite)
    end)
    Sprites.define("tank", 16, 10, function(w, h)
        gfx.fillRect(0, h - 3, w, 3)
        gfx.fillRect(2, 3, w - 4, 4)
        gfx.fillRect(w / 2 - 1, 0, 3, 4)
    end)
    Sprites.define("ufo", 16, 9, function(w, h)
        gfx.fillEllipseInRect(0, 3, w, 5)
        gfx.fillEllipseInRect(w / 2 - 3, 0, 6, 5)
    end)
    Sprites.define("defender", 12, 12, function(w, h)
        gfx.fillTriangle(0, h / 2, w, 1, w, h - 1)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(w - 5, h / 2 - 1, 3, 2)
        gfx.setColor(gfx.kColorWhite)
    end)
end

--------------------------------------------------------------------------------
-- The free frame's level: a hull with girders. The `scene` seam is how a game
-- hands the engine a static world of its own.

Hull = { girders = {} }

local HULL_T <const> = 20
local HULL_B <const> = 220

local function rectHit(cx, cy, r, rx, ry, rw, rh)
    local nx = Lib.clamp(cx, rx, rx + rw)
    local ny = Lib.clamp(cy, ry, ry + rh)
    return Lib.distSq(cx, cy, nx, ny) <= r * r
end

local HULL_SCENE = {
    build = function()
        local g = Hull.girders
        for i = #g, 1, -1 do g[i] = nil end
        local top = true
        for x = 420, 1500, 210 do
            g[#g + 1] = { x = x, w = 22, top = top, h = 60 }
            top = not top
        end
    end,
    hits = function(px, py, r)
        for _, p in ipairs(Hull.girders) do
            if math.abs(p.x - px) < 40 then
                local ry = p.top and HULL_T or (HULL_B - p.h)
                if rectHit(px, py, r, p.x - p.w / 2, ry, p.w, p.h) then return true end
            end
        end
        return false
    end,
    draw = function()
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, SCREEN_W, HULL_T)
        gfx.fillRect(0, HULL_B, SCREEN_W, SCREEN_H - HULL_B)
        gfx.setColor(gfx.kColorBlack)
        for sx = -(Frame.x % 24), SCREEN_W, 24 do
            gfx.drawLine(sx, 0, sx, HULL_T)
            gfx.drawLine(sx, HULL_B, sx, SCREEN_H)
        end
        gfx.setColor(gfx.kColorWhite)
        for _, p in ipairs(Hull.girders) do
            if Frame.visible(p.x, 30) then
                local y = p.top and HULL_T or (HULL_B - p.h)
                gfx.fillRect(Frame.toScreenX(p.x) - p.w / 2, y, p.w, p.h)
            end
        end
    end,
}

--------------------------------------------------------------------------------
-- snip: three-frames
-- Three levels. Read the first four lines of each and nothing else: the frame
-- is the only real difference between a Xevious, a Scramble and a Uridium.

local VERTICAL = {
    title = "VERTICAL",
    scroll = "vertical",              -- the world falls past a fixed player
    sprites = art,
    enemies = {
        grunt = { sprite = "grunt", hp = 1, r = 6, score = 100,
                  move = Movers.straight(78), drop = { "gun", 0.5 } },
        gunner = { sprite = "gunner", hp = 3, r = 9, score = 300,
                   move = Movers.dropHover(56, 55, 44, 1.2),
                   fire = Firers.spread(1.9, 3, 0.7, 115) },
    },
    bosses = {
        dread = {
            sprite = "dread", hp = 40, r = 26, score = 5000,
            from = { x = 200, y = -30 }, enter = { x = 200, y = 50 },
            phases = { {
                above = 0,
                move = function(b) b.x = 200 + math.sin(b.t) * 96 end,
                fire = function(b, dt)
                    local d = b.data
                    d.t = (d.t or 0) + dt
                    if d.t >= 1.3 then
                        d.t = 0
                        Bullets.eRing(b.x, b.y + 8, 9, 100)
                    end
                end,
            } },
        },
    },
    waves = {
        { t = 0.5, type = "grunt", x = 70, n = 5, dx = 62 },
        { t = 3.0, type = "gunner", x = 130 },
        { t = 3.0, type = "gunner", x = 270 },
        { t = 6.0, type = "grunt", x = 40, n = 6, dx = 64 },
        { t = 9.0, boss = "dread" },
    },
}

local SIDE = {
    title = "SIDE",
    scroll = "side",                  -- the world slides left, at ITS pace
    speed = 66,                       -- ...this fast, and you cannot argue
    fuel = true,
    sprites = art,
    terrain = { groundBase = SCREEN_H - 26, groundAmp = 22,
                ceilBase = 34, ceilAmp = 12 },
    enemies = {
        tank = { sprite = "tank", hp = 2, r = 8, score = 200, fuel = 40,
                 move = Movers.groundLeft(7) },     -- rides at Frame.speed
        ufo  = { sprite = "ufo", hp = 1, r = 7, score = 250,
                 move = Movers.leftSine(130, 42, 2.4),
                 fire = Firers.aimed(1.8, 120) },
    },
    waves = {
        { t = 0.5, type = "ufo",  x = 420, y = 70 },
        { t = 2.0, type = "tank", x = 420, y = 200 },
        { t = 4.0, type = "ufo",  x = 420, y = 110, n = 3, dy = -26 },
        { t = 7.0, type = "tank", x = 420, y = 200, n = 2, dx = -90 },
        { t = 10.0, type = "ufo", x = 420, y = 90, n = 4, dy = 20 },
    },
}

local FREE = {
    title = "FREE",
    scroll = "free",                  -- the world stands still. YOU move.
    levelW = 1800,                    -- ...and it has two ends
    top = HULL_T + 8, bottom = HULL_B - 8,
    sprites = art,
    scene = HULL_SCENE,
    enemies = {
        defender = { sprite = "defender", hp = 1, r = 6, score = 200,
                     move = Movers.station(26, 2.2),
                     fire = Firers.aimedNear(1.9, 130, 220) },
    },
    waves = {
        { t = 0, type = "defender", x = 520,  y = 90 },
        { t = 0, type = "defender", x = 700,  y = 170 },
        { t = 0, type = "defender", x = 940,  y = 100 },
        { t = 0, type = "defender", x = 1180, y = 160 },
        { t = 0, type = "defender", x = 1420, y = 110 },
    },
}
-- endsnip

Demo.levels = { VERTICAL, SIDE, FREE }

--------------------------------------------------------------------------------
-- snip: profile-diagram
-- The bug, magnified. The cavern used to be DRAWN as a polygon sampled every
-- 16 px and COLLIDED against the exact continuous sine that generated it. Those
-- are not the same curve: between samples the true curve bows away from the
-- straight chord, so the wall you saw was not the wall you hit.
--
-- At 1:1 the gap is under a pixel, which is why nobody caught it by looking --
-- and why the ship just occasionally died in visibly empty black. Here the
-- vertical axis is stretched so you can see what the ship could feel.

local STEP_OLD <const> = 16      -- the old draw sampled the wall this coarsely
local MAGX <const> = 20
local MAGY <const> = 46

local function curve(x)  -- the same generator core/terrain.lua samples
    return 120 - 22 * (0.6 * math.sin(x * 0.020) + 0.4 * math.sin(x * 0.052 + 1.3))
end

function Demo.drawProfile()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)

    -- Zoom in on ONE 16px span -- the crest where the wall bends hardest, since
    -- that is where a chord strays furthest from the curve it is pretending to
    -- be. Showing the whole wall would show nothing: at 1:1 the two lines are
    -- the same line. That is the entire problem with this class of bug.
    local x0, flat = 0, 1e9
    for x = 0, 400 do
        local slope = math.abs(curve(x + 9) - curve(x + 7))
        if slope < flat then flat, x0 = slope, x end
    end

    local ox, oy = 44, 150
    local base = curve(x0)
    local function px(x) return ox + (x - x0) * MAGX end
    local function py(x) return oy + (curve(x) - base) * MAGY end

    -- what the COLLIDER read: the true curve, at every pixel
    for i = 0, STEP_OLD * MAGX do
        gfx.drawPixel(ox + i, py(x0 + i / MAGX))
    end

    -- what the RENDERER drew: one straight chord between the two samples
    gfx.setLineWidth(1)
    gfx.drawLine(px(x0), py(x0), px(x0 + STEP_OLD), py(x0 + STEP_OLD))
    gfx.fillRect(px(x0) - 2, py(x0) - 2, 5, 5)
    gfx.fillRect(px(x0 + STEP_OLD) - 2, py(x0 + STEP_OLD) - 2, 5, 5)

    -- the gap between them, at its widest
    local mid = x0 + STEP_OLD / 2
    local chordY = (py(x0) + py(x0 + STEP_OLD)) / 2
    local trueY = py(mid)
    for y = math.min(chordY, trueY), math.max(chordY, trueY), 2 do
        gfx.drawPixel(px(mid), y)
    end

    local gap = math.abs(curve(mid) - (curve(x0) + curve(x0 + STEP_OLD)) / 2)
    Kit.text("one 16px sample span, magnified", 20, 16)
    Kit.text("chord = what you SAW", 20, 40)
    Kit.text("curve = what you HIT", 20, 58)
    Kit.text(string.format("gap: %.2f px -- a death you cannot explain",
        gap), 20, 208)
end
-- endsnip
