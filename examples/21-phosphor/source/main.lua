-- Chapter 21: a guided tour of the Phosphor vec/ engine.
-- Four screens, 90 frames each: the spring grid, full-attitude
-- projection, the wrap-aware field, and the fx pool. The engine
-- files are vendored verbatim from phosphor/vec/ (MIT).

-- snip: tour-imports
import "CoreLibs/graphics"
import "shots"
import "bookharness"
-- the vendored engine, in vec/lib.lua's dependency order
import "vec"
import "field"
import "grid"
import "shapes"
import "mat"
import "proj"
import "beams"
import "fx"
-- endsnip

local gfx <const> = playdate.graphics
local DT <const> = 1 / 30

local frame = 0

-- a dart for the projection screen: five verts, nine edges
local SHIP_V <const> = {
    0, 0, 3, -2, 0, -2, 2, 0, -2,
    0, 1.1, -1.6, 0, -1.1, -1.6,
}
local SHIP_E <const> = {
    1, 2, 1, 3, 1, 4, 1, 5,
    2, 4, 3, 4, 2, 5, 3, 5, 2, 3,
}

local M = Mat.identity()

-- field-screen actors: a hunter chases the target the short
-- way round the torus
local hunter = { x = 352, y = 96 }
local TARGET <const> = { x = 6, y = 150 }
local tgon = Shapes.gon(12, 5)
local hshape = Shapes.new({
    { 10, 0, -8, 6, -4, 0, -8, -6, 10, 0 },
})

-- snip: wrap-demo
-- shortest signed vector from a to b on the torus: take each
-- axis the short way round, exactly as Field.dist2 does
local function wrapDelta(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    if dx > Field.W / 2 then dx = dx - Field.W
    elseif dx < -Field.W / 2 then dx = dx + Field.W end
    if dy > Field.H / 2 then dy = dy - Field.H
    elseif dy < -Field.H / 2 then dy = dy + Field.H end
    return dx, dy
end
-- endsnip

local BOOMS <const> = {
    { x = 150, y = 130 }, { x = 260, y = 90 },
}
local boomN = 0

local screens = {}

screens[1] = {
    name = "SPRING GRID",
    cap = "ONE PUSH DENTS - COUPLING RIPPLES",
    enter = function()
        Grid.init({ spacing = 20 })
    end,
    update = function(t, act)
        if act.push then
            Grid.push(200, 118, 320, 90)
            Harness.count("pushes")
        end
        Grid.update(DT)
    end,
    draw = function(t)
        Grid.draw()
    end,
}

screens[2] = {
    name = "MAT + PROJ",
    cap = "SPUN EVERY FRAME - TIDIED EVERY 30",
    enter = function()
        M = Mat.identity()
        Proj.setCamera(0, 0, 0, 0, 0)
    end,
    update = function(t, act)
        Mat.spinY(M, 0.031, M) -- out aliases m: in-place, no GC
        Mat.spinX(M, 0.017, M)
        if t > 0 and t % 30 == 0 then
            M = Mat.tidy(M)
            Harness.count("tidies")
        end
    end,
    draw = function(t)
        Proj.mesh(SHIP_V, SHIP_E,
            { x = 0, y = 0, z = 7 }, M, 1.4)
    end,
}

screens[3] = {
    name = "WRAP FIELD",
    cap = "SOLID - TORUS PATH   DASHED - NAIVE",
    enter = function()
        hunter.x, hunter.y = 352, 96
    end,
    update = function(t, act)
        local dx, dy = wrapDelta(hunter.x, hunter.y,
            TARGET.x, TARGET.y)
        local nx, ny, d = Vec.norm(dx, dy)
        if d > 8 then
            hunter.x = hunter.x + nx * 48 * DT
            hunter.y = hunter.y + ny * 48 * DT
            hunter.x, hunter.y =
                Field.wrap(hunter.x, hunter.y)
        end
    end,
    draw = function(t)
        local hx, hy = hunter.x, hunter.y
        local dx, dy = wrapDelta(hx, hy, TARGET.x, TARGET.y)
        -- the wrapped shortest path, drawn again shifted a
        -- field-width so it re-enters at the opposite seam
        gfx.drawLine(hx, hy, hx + dx, hy + dy)
        if hx + dx > Field.W then
            gfx.drawLine(hx - Field.W, hy,
                hx - Field.W + dx, hy + dy)
        elseif hx + dx < 0 then
            gfx.drawLine(hx + Field.W, hy,
                hx + Field.W + dx, hy + dy)
        end
        -- the naive path, dashed: right across the middle
        local ndx, ndy = TARGET.x - hx, TARGET.y - hy
        local nlen = Vec.len(ndx, ndy)
        local steps = math.floor(nlen / 7)
        for i = 0, steps - 1, 2 do
            local a, b = i / steps, (i + 1) / steps
            gfx.drawLine(hx + ndx * a, hy + ndy * a,
                hx + ndx * b, hy + ndy * b)
        end
        Shapes.drawWrapped(tgon, TARGET.x, TARGET.y, t, 1, 14)
        Shapes.drawWrapped(hshape, hx, hy,
            Vec.angleOf(dx, dy), 1, 12)
        local wrapd = math.sqrt(Field.dist2(hx, hy,
            TARGET.x, TARGET.y))
        Beams.print("NAIVE " .. math.floor(nlen + 0.5)
            .. "  WRAP " .. math.floor(wrapd + 0.5),
            200, 206, 9, { align = "center" })
    end,
}

screens[4] = {
    name = "FX POOL",
    cap = "BURST - DEBRIS - FLASH",
    enter = function()
        Fx.reset()
        boomN = 0
    end,
    update = function(t, act)
        if act.boom then
            boomN = boomN % #BOOMS + 1
            local b = BOOMS[boomN]
            Fx.burst(b.x, b.y, 30, 90)
            Fx.debris(b.x, b.y, 12, 60)
            Fx.flash(0.2)
            Harness.count("booms")
        end
        Fx.update(DT)
    end,
    draw = function(t)
        Fx.draw()
    end,
}

local function drawFrame(scr, t)
    local s = screens[scr]
    gfx.clear(Fx.flashing(frame) and gfx.kColorWhite
        or gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    s.draw(t)
    gfx.drawRect(0, 0, Field.W, Field.H) -- the cabinet bezel
    Beams.print(s.name, 200, 8, 10, { align = "center" })
    Beams.print(s.cap, 200, 225, 7, { align = "center" })
end

local lastScr = 0

-- snip: tour-loop
function playdate.update()
    local act = Harness.input(frame)
    if not act then
        local a = playdate.buttonJustPressed(
            playdate.kButtonA)
        act = { push = a, boom = a }
    end
    local scr = (math.floor((frame - 1) / 90)
        % #screens) + 1
    local t = (frame - 1) % 90
    if scr ~= lastScr then
        lastScr = scr
        if screens[scr].enter then screens[scr].enter() end
    end
    screens[scr].update(t, act)
    drawFrame(scr, t)
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
