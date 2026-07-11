-- The tour: four screens on the vendored Tiles core, 120 frames
-- each. Camera follow/clamp, a live Map.set carve, the BFS
-- distance field with a descending chaser, and the sprite/kit
-- showcase. Draw.frame (draw.lua) dispatches to the screens.

local gfx = playdate.graphics

Game = {
    screens = {},
    scr = 0,
    t = 0, -- frames on the current screen
    parts = {},
}

-- snip: demo-tiles
-- the demo tileset: LIGHT floor with an etched dot, DARK wall
-- with a white top bevel, MID crate — the palette that reads
Tiles.def(".", { kind = "floor", pat = Tiles.PAT.LIGHT,
    art = { "#" } })

local wallArt = { "oooooooooooooooo" }
for i = 2, 15 do wallArt[i] = "o..............#" end
wallArt[16] = "################"
Tiles.def("#", { solid = true, kind = "wall",
    pat = Tiles.PAT.DARK, art = wallArt })
-- endsnip

Tiles.def("x", { solid = true, kind = "crate",
    pat = Tiles.PAT.MID, art = {
        "################",
        "#o............o#",
        "#.o..........o.#",
        "#..o........o..#",
        "#...o......o...#",
        "#....o....o....#",
        "#.....o..o.....#",
        "#......oo......#",
        "#......oo......#",
        "#.....o..o.....#",
        "#....o....o....#",
        "#...o......o...#",
        "#..o........o..#",
        "#.o..........o.#",
        "#o............o#",
        "################",
    } })

-- palette rule: white hero with a black outline, dark foes with
-- a white eye — both read against a dithered floor
Game.spr = Spr.makeSet({
    hero = {
        "....####....",
        "...#oooo#...",
        "..#oo##oo#..",
        "..#oooooo#..",
        "..#o#oo#o#..",
        "..#oooooo#..",
        "...#oooo#...",
        "..##o##o##..",
        ".#oo####oo#.",
        ".#o##oo##o#.",
        "..#o#oo#o#..",
        "...##..##...",
    },
    ghost = {
        "...######...",
        "..########..",
        ".##########.",
        ".###o##o###.",
        ".##oo##oo##.",
        ".###o##o###.",
        ".##########.",
        ".##########.",
        ".##########.",
        ".#.##..##.#.",
        ".#.#....#.#.",
        "............",
    },
    crab = {
        "..#......#..",
        "...#....#...",
        "..########..",
        ".##o####o##.",
        "############",
        "#.########.#",
        "#..######..#",
        "...#....#...",
        "..#......#..",
        "............",
        "............",
        "............",
    },
    gem = {
        ".....##.....",
        "....#oo#....",
        "...#oooo#...",
        "..#oo##oo#..",
        ".#oo####oo#.",
        "#oo######oo#",
        ".#oo####oo#.",
        "..#oo##oo#..",
        "...#oooo#...",
        "....#oo#....",
        ".....##.....",
        "............",
    },
})

local function drawHero(a) Spr.draw(Game.spr.hero, a.x, a.y) end
local function drawGhost(a) Spr.draw(Game.spr.ghost, a.x, a.y) end

-- a bordered rows table; fill(x, y) returns the interior char
local function makeRows(w, h, fill)
    local rows = {}
    for y = 1, h do
        local r = {}
        for x = 1, w do
            if x == 1 or x == w or y == 1 or y == h then
                r[x] = "#"
            else
                r[x] = fill(x, y)
            end
        end
        rows[y] = table.concat(r)
    end
    return rows
end

-- ------------------------------------------------ screen 1: tcam
local cam = {}

Game.screens[1] = {
    enter = function()
        local rows = makeRows(40, 14, function(x, y)
            if (y == 4 or y == 10) and x % 5 == 0 then
                return "x"
            elseif y == 6 and x % 7 == 3 then
                return "x"
            end
            return "."
        end)
        Map.load(rows, 0, 16)
        Map.build()
        cam.p = { x = Map.cx(3), y = Map.cy(7), hw = 6, hh = 6 }
        Cam.center(cam.p.x, cam.p.y)
    end,
    -- snip: cam-demo
    update = function(s, dt)
        local sp = 150 * dt
        Phys.moveAssist(cam.p, s.mx * sp, s.my * sp)
        Cam.follow(cam.p.x, cam.p.y, dt)
    end,
    draw = function()
        Cam.apply()
        Map.draw()
        -- the camera's own center vs its follow target: the gap
        -- is the lerp's lag (or the clamp, at the map edge)
        local p = cam.p
        local ccx, ccy = Cam.x + 200, Cam.y + 128
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(ccx, ccy, p.x, p.y)
        gfx.drawRect(ccx - 4, ccy - 4, 8, 8)
        gfx.drawLine(p.x - 9, p.y, p.x + 9, p.y)
        gfx.drawLine(p.x, p.y - 9, p.x, p.y + 9)
        Spr.draw(Game.spr.hero, p.x, p.y)
        Kit.marker(p.x, p.y - 10, Game.t * Config.DT)
        Cam.done()
        Draw.hud("TCAM: FOLLOW + CLAMP",
            "CAM " .. math.floor(Cam.x) ..
            "  HERO " .. math.floor(p.x))
    end,
    -- endsnip
}

-- ------------------------------------------------ screen 2: tmap
local carve = {}

local function carvePath()
    local path = {}
    for x = 3, 22 do path[#path + 1] = { x, 4 } end
    for y = 5, 10 do path[#path + 1] = { 22, y } end
    for x = 21, 3, -1 do path[#path + 1] = { x, 10 } end
    for y = 9, 6, -1 do path[#path + 1] = { 3, y } end
    return path
end

Game.screens[2] = {
    enter = function()
        Map.load(makeRows(25, 14, function() return "x" end),
            0, 16)
        Map.build()
        carve.path = carvePath()
        carve.i = 0
        Game.parts = {}
    end,
    -- snip: carve
    update = function(s, dt)
        if s.act and carve.i < #carve.path then
            carve.i = carve.i + 1
            local c = carve.path[carve.i]
            Map.set(c[1], c[2], ".") -- repaints ONE 16px cell
            Kit.burst(Game.parts,
                Map.cx(c[1]), Map.cy(c[2]), 4, 80)
            Snd.play("noise", 500, 0.03, 0.1)
            Harness.count("carves")
        end
        Kit.updateParts(Game.parts, dt)
    end,
    -- endsnip
    draw = function()
        Map.draw()
        if carve.i > 0 then
            local c = carve.path[carve.i]
            Spr.draw(Game.spr.hero,
                Map.cx(c[1]), Map.cy(c[2]))
        end
        Kit.drawParts(Game.parts)
        Draw.hud("TMAP: ONE-CELL REPAINT",
            "CELLS " .. carve.i)
    end,
}

-- ----------------------------------------------- screen 3: tphys
local bfs = {}

local function bfsOpen(tx, ty)
    return not Map.solid(tx, ty)
end

-- the field, visualized: a black mark per reachable cell, larger
-- nearer the player — descending the gradient IS walking toward
-- bigger marks
local function drawField(dist)
    gfx.setColor(gfx.kColorBlack)
    for ty = 1, Map.H do
        for tx = 1, Map.W do
            local d = dist[ty][tx]
            if d and d > 0 then
                local sz =
                    Util.clamp(8 - math.floor(d / 3), 1, 8)
                gfx.fillRect(Map.cx(tx) - sz / 2,
                    Map.cy(ty) - sz / 2, sz, sz)
            end
        end
    end
end

-- the chaser's route: follow the gradient all the way down
local function drawRoute(dist, x, y)
    local tx, ty = Map.tileAt(x, y)
    local px, py = Map.cx(tx), Map.cy(ty)
    for _ = 1, 60 do
        local dx, dy = Phys.descend(dist, tx, ty)
        if not dx then break end
        tx, ty = tx + dx, ty + dy
        local nx, ny = Map.cx(tx), Map.cy(ty)
        gfx.drawLine(px, py, nx, ny)
        px, py = nx, ny
    end
end

Game.screens[3] = {
    enter = function()
        local rows = makeRows(25, 14, function(x, y)
            if x % 2 == 1 and y % 2 == 1 then return "#" end
            return "."
        end)
        Map.load(rows, 0, 16)
        Map.build()
        bfs.p = { x = Map.cx(20), y = Map.cy(7), hw = 6, hh = 6 }
        bfs.c = { x = Map.cx(2), y = Map.cy(2), hw = 6, hh = 6 }
        bfs.ptx, bfs.pty = 0, 0
        bfs.dist = nil
        Game.parts = {}
    end,
    -- snip: chase
    update = function(s, dt)
        Phys.moveAssist(bfs.p, s.mx * 60 * dt, s.my * 60 * dt)
        -- recompute the field only when the player changes cell
        local ptx, pty = Phys.cell(bfs.p)
        if ptx ~= bfs.ptx or pty ~= bfs.pty then
            bfs.ptx, bfs.pty = ptx, pty
            bfs.dist = Phys.bfs(ptx, pty, bfsOpen)
            Harness.count("fields")
        end
        -- the chaser walks cell centers, descending the field
        local c = bfs.c
        if not c.ntx then
            local ctx, cty = Map.tileAt(c.x, c.y)
            local dx, dy = Phys.descend(bfs.dist, ctx, cty)
            if dx then c.ntx, c.nty = ctx + dx, cty + dy end
        end
        if c.ntx then
            local gx, gy = Map.cx(c.ntx), Map.cy(c.nty)
            local sp = 110 * dt
            c.x = c.x + Util.clamp(gx - c.x, -sp, sp)
            c.y = c.y + Util.clamp(gy - c.y, -sp, sp)
            if math.abs(gx - c.x) < 0.5
                and math.abs(gy - c.y) < 0.5 then
                c.ntx = nil
            end
        end
        -- endsnip
        if Util.dist2(c.x, c.y, bfs.p.x, bfs.p.y) < 144 then
            Kit.burst(Game.parts, c.x, c.y, 10, 120)
            Kit.shake(0.3)
            Snd.boom(220, 3)
            Harness.count("catches")
            c.x, c.y = Map.cx(2), Map.cy(13)
            c.ntx = nil
        end
        Kit.updateParts(Game.parts, dt)
        Kit.updateShake(dt)
    end,
    draw = function()
        Kit.applyShake()
        Map.draw()
        drawField(bfs.dist)
        drawRoute(bfs.dist, bfs.c.x, bfs.c.y)
        -- painter order: insertion breaks the tie when equal-y
        Kit.drawSorted({
            { y = bfs.p.y, fn = drawHero, arg = bfs.p },
            { y = bfs.c.y, fn = drawGhost, arg = bfs.c },
        })
        Kit.drawParts(Game.parts)
        Kit.doneShake()
        Draw.hud("TPHYS: BFS FIELD + DESCEND",
            "FIELDS " .. (Harness.counters.fields or 0))
    end,
}

-- ------------------------------------------ screen 4: tspr + kit
local gal = {}

Game.screens[4] = {
    enter = function()
        Map.load(makeRows(25, 14, function() return "." end),
            0, 16)
        Map.build()
        gal.items = {
            { "HERO", Game.spr.hero, 70 },
            { "GHOST", Game.spr.ghost, 158 },
            { "CRAB", Game.spr.crab, 246 },
            { "GEM", Game.spr.gem, 334 },
        }
        gal.n = 0
        gal.bursts = 0
        Game.parts = {}
    end,
    update = function(s, dt)
        if s.act then
            gal.n = gal.n % #gal.items + 1
            gal.bursts = gal.bursts + 1
            local it = gal.items[gal.n]
            Kit.burst(Game.parts, it[3], 110, 12, 130, 40)
            Kit.shake(0.3)
            Snd.boom(200, 3)
            Harness.count("bursts")
        end
        Kit.updateParts(Game.parts, dt, 140)
        Kit.updateShake(dt)
    end,
    draw = function()
        Kit.applyShake()
        Map.draw()
        for i = 1, #gal.items do
            local it = gal.items[i]
            local img = it[2]
            img:drawScaled(it[3] - img.width * 2,
                110 - img.height * 2, 4)
            Spr.draw(img, it[3], 160)
            Kit.panel(it[3] - 27, 172, 54, 20)
            local w = gfx.getTextSize(it[1])
            Kit.text(it[1], it[3] - w / 2, 174)
        end
        Kit.marker(gal.items[1][3], 78, Game.t * Config.DT)
        Kit.drawParts(Game.parts)
        Kit.doneShake()
        Draw.hud("TSPR + TKIT: THE PALETTE RULE",
            "BURSTS " .. gal.bursts)
    end,
}

-- ------------------------------------------------------ the loop
function Game.init()
    Game.scr = 0
    Game.t = 0
end

function Game.update(dt)
    local f = Input.frame
    local scr = (math.floor((f - 1) / Config.SCREEN)
        % #Game.screens) + 1
    if scr ~= Game.scr then
        Game.scr = scr
        Game.t = 0
        Kit.shakeT, Kit.sx, Kit.sy = 0, 0, 0
        Game.screens[scr].enter()
    end
    Game.t = Game.t + 1
    Game.screens[scr].update(Input.state, dt)
end
