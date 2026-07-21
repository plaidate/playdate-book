-- The tour: five screens on the vendored Dither core, 120
-- frames each. The 17-level ramp chart, the 3-band light
-- compositor with live Light.at probes, the Super Scaler pond,
-- the Bayer transitions, and the cone-plus-occluder screen.
-- Draw.frame (draw.lua) dispatches to the screens.

local gfx = playdate.graphics
local floor = math.floor
local sin, cos = math.sin, math.cos

Game = {
    screens = {},
    scr = 0,
    t = 0, -- frames on the current screen
}

-- a small keeper figure, palette rule applied: white body, dark
-- outline, and a Cast.blob shadow anchoring it to the ground
local function figure(x, y)
    Cast.blob(x, y + 4, 16, 10)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x, y - 13, 6)
    gfx.fillEllipseInRect(x - 6, y - 10, 12, 13)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y - 13, 5)
    gfx.fillEllipseInRect(x - 5, y - 9, 10, 11)
    gfx.setColor(gfx.kColorBlack)
end

-- a lantern glyph: white glass in a dark case, sitting where a
-- cone light's apex is
local function lamp(x, y)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x, y, 7)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y, 5)
    gfx.setColor(gfx.kColorBlack)
end

-- ----------------------------------------------- screen 1: shade
Game.screens[1] = {
    enter = function() end,
    update = function() end,
    draw = function()
        -- snip: demo-ramp
        -- 17 swatches per ramp, labeled: the engine's own gray
        -- chart. Below them, one banded gradient -- 17 opaque
        -- fills, no per-pixel work.
        gfx.drawText("BAYER", 10, 18)
        gfx.drawText("NOISE", 10, 110)
        for k = 0, 16 do
            local x = 10 + k * 22
            Shade.fill(x, 38, 20, 52, k)
            Shade.fill(x, 130, 20, 52, k, "noise")
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(x, 38, 20, 52)
            gfx.drawRect(x, 130, 20, 52)
            local lx = (k < 10) and x + 6 or x + 2
            gfx.drawText(tostring(k), lx, 92)
            gfx.drawText(tostring(k), lx, 184)
        end
        Shade.hgrad(10, 208, 374, 26, 0, 16)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(10, 208, 374, 26)
        -- endsnip
        Draw.hud("SHADE: THE 17-LEVEL RAMPS", "0..16")
    end,
}

-- ----------------------------------------------- screen 2: light
local li = {}

-- the probes: Light.at answers from the same discs the masks
-- blit, so the label can never disagree with the pixels
-- snip: demo-probe
local function probe(name, x, y)
    local v = Light.at(x, y)
    local tag = (v >= 1 and "LIT") or (v > 0 and "DIM")
        or "DARK"
    local s = string.format("%s %.1f %s", name, v, tag)
    local w, h = gfx.getTextSize(s)
    -- the label sits right of the crosshair, or left of it when that
    -- would run off the screen: a probe is only useful if you can
    -- read what it says
    local lx = (x + 11 + w <= 400) and (x + 9) or (x - 9 - w)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x - 5, y - 2, 10, 4)
    gfx.fillRect(x - 2, y - 5, 4, 10)
    gfx.fillRect(lx - 2, y - 9, w + 4, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(x - 4, y, x + 4, y)
    gfx.drawLine(x, y - 4, x, y + 4)
    Kit.text(s, lx, y - 9)
    gfx.setColor(gfx.kColorBlack)
end
-- endsnip

Game.screens[2] = {
    enter = function()
        li.ax, li.ay = 40, 150 -- probe A, walked by the script
    end,
    update = function(s, dt)
        li.ax = Util.clamp(li.ax + s.mx * 60 * dt, 30, 300)
        local t = Game.t
        li.l1x = 120 + 30 * cos(t * 0.05)
        li.l1y = 140 + 20 * sin(t * 0.05)
        li.l2x = 270 + 24 * cos(t * 0.07 + 2)
        li.l2y = 110 + 18 * sin(t * 0.07 + 2)
        li.l3x = 180 + 40 * cos(t * 0.04 + 4)
        li.l3y = 200 + 16 * sin(t * 0.04 + 4)
        -- lights cast in update, so Light.at (a probe, or an AI)
        -- answers from this frame's sources -- the glim pattern
        Light.begin(C.AMBIENT)
        Light.add(li.l1x, li.l1y, 52)
        Light.add(li.l2x, li.l2y, 34)
        Light.add(li.l3x, li.l3y, 30)
    end,
    draw = function()
        Shade.fill(0, 16, 400, 224, 5, "noise")
        Shade.disc(90, 190, 22, 7, "noise")
        Shade.disc(300, 170, 26, 7, "noise")
        figure(140, 176)
        Light.finish() -- darkness composites over the scene
        probe("A", li.ax, li.ay)
        probe("B", 340, 205)
        Draw.hud("LIGHT: 3 BANDS, 3 MOVING LIGHTS",
            "LIGHTS " .. Light.stats().lights)
    end,
}

-- ---------------------------------------------- screen 3: scaler
local sc = {}
local LAD = {}  -- kind -> mip ladder
local HAZE      -- depth-shade closure for Scaler.flush
local FLOOR = { stripes = { 3, 7 }, size = 40, band = 2,
    curve = 0 }
local LANES = { -2, 2, -1, 3, 0, -3, 1, 2, -2, 1 }

local function reedFn(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(w // 2 - 1, 6, 3, h - 6)        -- stem
    gfx.fillEllipseInRect(w // 2 - 4, 0, 8, 12)  -- seed head
end

local function padFn(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(0, 0, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawEllipseInRect(2, 1, w - 4, h - 2)
end

-- parallax treelines: fn layers draw with their shade preset
local function farTrees(ox)
    local o = floor(ox) % 48 - 48
    gfx.fillRect(0, C.HORIZON - 12, 400, 12)
    for x = o, 400, 48 do
        gfx.fillCircleAtPoint(x + 20, C.HORIZON - 12, 10)
    end
end

local function nearTrees(ox)
    local o = floor(ox) % 30 - 30
    gfx.fillRect(0, C.HORIZON - 6, 400, 6)
    for x = o, 400, 30 do
        gfx.fillCircleAtPoint(x + 12, C.HORIZON - 6, 7)
    end
end

-- depth-queue drawer: root each sprite on the meandering water
-- (the floor's bend at its row), then x-cull and ladder-draw
local function drawObj(sx, sy, s, k, o)
    local l = LAD[o.kind]
    sx = sx + Scaler.bendAt(floor(sy))
    local hw = l.w0 * s * 0.5
    if sx + hw < 0 or sx - hw > 400 then return end
    Scaler.draw(l, sx, sy, s, k)
end

Game.screens[3] = {
    enter = function()
        Scaler.cam.x, Scaler.cam.y, Scaler.cam.z = 0, C.CAMY, 0
        Scaler.horizon = C.HORIZON
        Para.clear()
        Para.layer(farTrees, 0.05, 5)
        Para.layer(nearTrees, 0.12, 9)
        sc.obs = {}
        local i = 0
        for z = 140, 2200, 48 do
            i = i + 1
            local lane = LANES[(i - 1) % #LANES + 1]
            sc.obs[#sc.obs + 1] = {
                x = lane * 46,
                z = z,
                kind = (i % 4 == 0) and "pad" or "reed",
            }
        end
        sc.t = 0
    end,
    update = function(s, dt)
        sc.t = sc.t + dt
        Scaler.cam.z = Scaler.cam.z + C.SPD * dt
        sc.curve = sin(sc.t * 0.5) * 0.065
        for i = #sc.obs, 1, -1 do
            -- cull before f/dz balloons a passed sprite into a
            -- screen-filler (the skimmer lesson, sec. above)
            if sc.obs[i].z < Scaler.cam.z + 55 then
                table.remove(sc.obs, i)
            end
        end
    end,
    draw = function()
        -- snip: demo-scaler
        -- the Scaler frame order: sky -> Para -> haze -> floor
        -- -> depth queue -> near actors
        Shade.vgrad(0, 0, 400, C.HORIZON, 9, 2)  -- dusk sky
        Para.draw(Scaler.cam.x)
        Fade.haze(C.HORIZON - 12, C.HORIZON, 4)  -- horizon mist
        FLOOR.curve = sc.curve
        Scaler.floor(FLOOR)                      -- the water
        Scaler.clear()
        for i = 1, #sc.obs do
            local o = sc.obs[i]
            Scaler.queue(drawObj, o.x, 0, o.z, o)
        end
        Scaler.flush(HAZE)
        -- endsnip
        -- a hovering dart at the player plane, its blob shadow
        -- on the water telling you its height
        local pz = Scaler.cam.z + 90
        local px, py = Scaler.project(Scaler.cam.x, 24, pz)
        local _, gy = Scaler.project(Scaler.cam.x, 0, pz)
        Cast.blob(px, gy + 1, 16, 9)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillTriangle(px - 9, py - 8, px + 9, py - 8, px, py)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillTriangle(px - 6, py - 7, px + 6, py - 7, px,
            py - 2)
        gfx.setColor(gfx.kColorBlack)
        local st = Scaler.stats()
        Draw.hud("SCALER: THE BEND",
            "SPR " .. st.sprites .. " FILLS " .. st.fills)
    end,
}

-- ------------------------------------------------ screen 4: fade
local function glade()
    Shade.vgrad(0, 16, 400, 84, 12, 9)         -- night sky
    Fade.haze(84, 100, 3)                      -- mist
    Shade.fill(0, 100, 400, 140, 5, "noise")   -- mossy floor
    Shade.disc(300, 190, 28, 7, "noise")
    Shade.disc(90, 150, 20, 7, "noise")
    figure(200, 170)
end

Game.screens[4] = {
    enter = function() end,
    update = function() end,
    draw = function()
        glade()
        -- snip: demo-fade
        -- iris in on the keeper, then dissolve out: both
        -- transitions ride the same 17 Bayer thresholds the
        -- terrain fills use
        local t = Game.t
        if t <= 50 then
            Fade.iris(200, 170, 1 - t / 50)
        elseif t > 60 then
            Fade.dissolve((t - 60) / 60)
        end
        -- endsnip
        Draw.hud("FADE: IRIS IN, DISSOLVE OUT", "T " .. t)
    end,
}

-- ------------------------------------------- screen 5: occluders
local oc = {}
local WX, WY0, WY1 = 180, 70, 160            -- the wall segment
local CR = { x = 250, y = 185, w = 46, h = 34 }  -- the crate

Game.screens[5] = {
    enter = function()
        oc.lx, oc.ly = 50, 210 -- where the lantern stands
        oc.dir = -0.35
    end,
    update = function(s, dt)
        -- snip: demo-cone
        -- One sweeping wedge, one wall, one crate. Occluders are
        -- registered BEFORE the light whose shadows the player
        -- reads -- light.lua carves each light's shadows right
        -- after its own shape, so that light wants to be last.
        oc.dir = -0.35 + 0.22 * sin(Game.t * 0.045)
        Light.begin(C.AMBIENT)
        Light.wall(WX, WY0, WX, WY1)
        Light.box(CR.x, CR.y, CR.w, CR.h)
        Light.cone(oc.lx, oc.ly, 320, oc.dir, 1.0, 0.55)
        -- endsnip
    end,
    draw = function()
        Shade.fill(0, 16, 400, 224, 5, "noise")
        Shade.disc(120, 118, 26, 7, "noise")
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(WX - 2, WY0, 5, WY1 - WY0)
        gfx.fillRect(CR.x, CR.y, CR.w, CR.h)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(WX - 2, WY0, 5, WY1 - WY0)
        gfx.drawRect(CR.x, CR.y, CR.w, CR.h)
        gfx.setColor(gfx.kColorBlack)
        figure(255, 124) -- standing in the wall's shadow
        lamp(oc.lx, oc.ly)
        Light.finish()
        probe("A", 250, 60)  -- shadowed: inside the beam, unlit
        probe("B", 190, 185) -- lit core, past the wall's end
        Draw.hud("LIGHT: A CONE AND TWO OCCLUDERS",
            "WALLS " .. Light.stats().walls)
    end,
}

-- ------------------------------------------------------ the loop
function Game.init()
    Game.scr = 0
    Game.t = 0
    LAD.reed = Scaler.ladderFromFn(reedFn, 12, 40, 10, 2)
    LAD.pad = Scaler.ladderFromFn(padFn, 30, 9, 8, 2)
    HAZE = Scaler.linearHaze(120, 560, 12)
end

function Game.update(dt)
    local f = Input.frame
    local scr = (floor((f - 1) / C.SCREEN)
        % #Game.screens) + 1
    if scr ~= Game.scr then
        Game.scr = scr
        Game.t = 0
        Game.screens[scr].enter()
        Harness.count("screens")
    end
    Game.t = Game.t + 1
    Game.screens[scr].update(Input.state, dt)
end
