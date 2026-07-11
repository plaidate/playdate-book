-- The tour: four screens on the vendored Voxel core, 120 frames
-- each. Terrain authoring + a carve crater, the occlusion ghost,
-- a solved shell arc, and step-up/gravity physics on terraces.
-- Draw.frame (draw.lua) dispatches to the screens.

local gfx = playdate.graphics

Game = {
    screens = {},
    scr = 0,
    t = 0, -- frames on the current screen
    parts = {},
}

-- the demo walker: a chunky white figure, palette rule applied —
-- material 4 body so it pops against mid-gray (2) terrain
-- chunky enough that its ghost silhouette reads on the page
local WALKER = VoxModel.fromLayers({
    { "4.4.4", "4.4.4" },
    { "44444", "44444" },
    { "44444", "44444" },
    { "44444", "44444" },
    { ".444.", ".444." },
    { ".444.", ".444." },
    { "44444", "44444" },
})

local function drawParts()
    for i = 1, #Game.parts do
        Kit.drawPart(Game.parts[i])
    end
end

-- ------------------------------------------------ screen 1: vox
local ter = {}

Game.screens[1] = {
    enter = function()
        -- snip: demo-terrain
        -- the authoring helpers, composed: smooth radial mounds
        -- on a 2-course base, bright caps on true high ground,
        -- then the etched ground plane over the exposed course
        Vox.clear()
        local hm = Vox.bumpField(Vox.W, Vox.D, {
            base = 2,
            { 24, 22, 13, 7 },
            { 66, 40, 16, 9 },
            { 50, 12, 9, 4 },
        })
        Vox.fromHeightmap(hm)
        Vox.floorGrid(2, 1, 8, 1)
        Vox.buildBG()
        -- endsnip
        ter.craters = 0
        Game.parts = {}
    end,
    update = function(s, dt)
        if s.act then
            ter.craters = ter.craters + 1
            local cx, cy, cz = 66, 40, 8
            if ter.craters > 1 then cx, cy, cz = 24, 22, 6 end
            local rm = Vox.carve(cx, cy, cz, 5)
            Kit.burst(Game.parts, rm, 14)
            Snd.boom(220)
            Harness.count("carves")
            Harness.set("removed", #rm)
        end
        Kit.updateParts(Game.parts, dt)
    end,
    draw = function()
        Vox.drawBG()
        drawParts()
        Draw.hud("VOX: BUILD + CARVE",
            "CRATERS " .. ter.craters)
    end,
}

-- ------------------------------------------- screen 2: voxmodel
local gho = {}

Game.screens[2] = {
    enter = function()
        Vox.clear()
        Vox.floorGrid(2, 1, 8, 1)
        -- twin pillars, tall enough to hide a walker whole
        for x = 38, 42 do
            for y = 27, 29 do Vox.column(x, y, 11, 2) end
        end
        for x = 62, 66 do
            for y = 27, 29 do Vox.column(x, y, 11, 2) end
        end
        Vox.buildBG()
        gho.a = { x = 20, y = 24.5, z = 2, vz = 0, hw = 1 }
        gho.b = { x = 44, y = 24.5, z = 2, vz = 0, hw = 1 }
    end,
    update = function(s, dt)
        local dx = s.mx * 12 * dt
        VoxPhys.tryMove(gho.a, gho.a.x + dx, gho.a.y)
        VoxPhys.tryMove(gho.b, gho.b.x + dx, gho.b.y)
        VoxPhys.physZ(gho.a, dt, Config.GRAVITY)
        VoxPhys.physZ(gho.b, dt, Config.GRAVITY)
    end,
    -- snip: demo-ghost
    draw = function()
        Vox.drawBG()
        local tt = Game.t * Config.DT
        for _, w in ipairs({ gho.a, gho.b }) do
            Kit.shadow(w.x, w.y, w.hw, w.z)
            VoxModel.draw(WALKER, w.x, w.y, w.z)
            Vox.occlude(w.x - 2.5, w.x + 2.5, w.y,
                w.z, w.z + 7)
        end
        -- the ghost pass: only the right walker gets one, so
        -- the pillars tell the before/after story side by side
        VoxModel.drawGhost(WALKER, gho.b.x, gho.b.y, gho.b.z)
        Kit.marker(gho.b.x, gho.b.y, gho.b.z + 3, tt)
        Kit.text("NO GHOST", 132, 196)
        Kit.text("GHOST", 244, 196)
        Draw.hud("VOXMODEL: THE OCCLUSION GHOST",
            "X " .. math.floor(gho.a.x))
    end,
    -- endsnip
}

-- ------------------------------------------- screen 3: voxproj
local sh = {}

Game.screens[3] = {
    enter = function()
        Vox.clear()
        local hm = Vox.bumpField(Vox.W, Vox.D, {
            base = 2,
            { 48, 32, 14, 6 },
        })
        Vox.fromHeightmap(hm)
        Vox.floorGrid(2, 1, 8, 1)
        Vox.buildBG()
        -- snip: demo-solve
        -- one solve at screen start: the mortar aims through the
        -- same integrator its live shells will fly through
        sh.gun = { x = 10, y = 32, z = Vox.heightAt(10, 32) }
        sh.tgt = { x = 82, y = 32 }
        sh.az, sh.v = VoxProj.solve(sh.gun, sh.tgt, {
            vmin = 20, vmax = 60,
            elevCos = 0.7071, elevSin = 0.7071,
            muzzle = function(o)
                return o.x, o.y, o.z + 1.5
            end,
        })
        -- endsnip
        sh.p = nil
        sh.trail = {}
        sh.shots = 0
        Game.parts = {}
    end,
    update = function(s, dt)
        if s.act and not sh.p then
            sh.p = VoxProj.launch(sh.gun.x, sh.gun.y,
                sh.gun.z + 1.5, sh.az, sh.v, 0.7071, 0.7071)
            sh.shots = sh.shots + 1
            Snd.play("square", 300, 0.1, 0.3)
            Harness.count("shells")
        end
        if sh.p then
            if VoxProj.step(sh.p, dt, Config.GRAVITY) then
                local rm = Vox.carve(sh.p.x, sh.p.y, sh.p.z, 3)
                Kit.burst(Game.parts, rm, 12)
                Kit.shake(0.25)
                Snd.boom(200)
                Harness.count("impacts")
                sh.p = nil
            else
                local n = #sh.trail
                sh.trail[n + 1] = { sh.p.x, sh.p.y, sh.p.z }
            end
        end
        Kit.updateParts(Game.parts, dt)
        Kit.updateShake(dt)
    end,
    draw = function()
        Kit.applyShake()
        Vox.drawBG()
        -- the mortar and the mark it is solving for
        Vox.drawBlock(sh.gun.x, sh.gun.y, sh.gun.z, 3)
        Vox.drawBlock(sh.gun.x, sh.gun.y, sh.gun.z + 1, 4)
        Kit.marker(sh.tgt.x, sh.tgt.y,
            Vox.heightAt(sh.tgt.x, sh.tgt.y),
            Game.t * Config.DT)
        -- the traced trajectory: every other substepped sample
        gfx.setColor(gfx.kColorWhite)
        for i = 1, #sh.trail, 2 do
            local q = sh.trail[i]
            gfx.fillRect(
                math.floor(Vox.OX + q[1] * Vox.S + 0.5),
                math.floor(Vox.OY + q[2] * Vox.TY
                    - q[3] * Vox.TZ + 0.5), 2, 2)
        end
        if sh.p then
            Vox.drawBlock(sh.p.x - 0.5, sh.p.y, sh.p.z, 4)
            Vox.occlude(sh.p.x - 1, sh.p.x + 1, sh.p.y,
                sh.p.z, sh.p.z + 1)
        end
        drawParts()
        Kit.doneShake()
        Draw.hud("VOXPROJ: SOLVE + STEP",
            "SHELLS " .. sh.shots)
    end,
}

-- ------------------------------------------- screen 4: voxphys
local ph = {}

Game.screens[4] = {
    enter = function()
        Vox.clear()
        Vox.floorGrid(2, 1, 8, 1)
        -- four full-depth terraces, one voxel per step, then a
        -- four-voxel cliff back down to the ground course
        for x = 24, 55 do
            local h = 2 + math.floor((x - 24) / 8)
            local cap = h >= 5 and 3 or 2
            for y = 0, Vox.D - 1 do
                Vox.column(x, y, h, 2, cap)
            end
        end
        Vox.buildBG()
        ph.w = { x = 8, y = 32, z = 2, vz = 0, hw = 1 }
    end,
    update = function(s, dt)
        local w = ph.w
        VoxPhys.tryMove(w, w.x + s.mx * 16 * dt, w.y)
        VoxPhys.physZ(w, dt, Config.GRAVITY)
    end,
    draw = function()
        Vox.drawBG()
        local w = ph.w
        Kit.shadow(w.x, w.y, w.hw, w.z)
        VoxModel.draw(WALKER, w.x, w.y, w.z)
        Vox.occlude(w.x - 1.5, w.x + 1.5, w.y, w.z, w.z + 3)
        VoxModel.drawGhost(WALKER, w.x, w.y, w.z)
        Kit.marker(w.x, w.y, w.z + 3, Game.t * Config.DT)
        Draw.hud("VOXPHYS: STEP-UP + FALL",
            "Z " .. math.floor(w.z * 10) / 10 ..
            (w.grounded and "" or " AIR"))
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
