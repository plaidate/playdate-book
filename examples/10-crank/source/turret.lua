-- Panel 2: 1:1 aim. The barrel IS the crank: absolute position maps
-- straight onto the barrel angle, zero pointing up -- the mapping
-- Lob's mortar and Rubble's aim ring use.

Turret = {}

local gfx <const> = playdate.graphics

local TX <const>, TY <const> = 200, 196 -- turret base

function Turret.reset()
    Turret.shots = {} -- live tracer rounds
    Turret.timer = 0
    Turret.angle = math.rad(-90)
end

-- snip: aim
function Turret.update(s)
    -- crank straight up (0 deg) = barrel straight up
    Turret.angle = math.rad(s.pos - 90)
    Turret.timer = Turret.timer + 1
    if Turret.timer % 10 == 0 then -- steady tracer fire
        local c = math.cos(Turret.angle)
        local si = math.sin(Turret.angle)
        Turret.shots[#Turret.shots + 1] = {
            x = TX + c * 30, y = TY + si * 30,
            dx = c * 6, dy = si * 6,
        }
        Harness.count("tracers")
    end
    for i = #Turret.shots, 1, -1 do
        local sh = Turret.shots[i]
        sh.x, sh.y = sh.x + sh.dx, sh.y + sh.dy
        if sh.x < -8 or sh.x > 408 or sh.y < -8 or sh.y > 248 then
            table.remove(Turret.shots, i)
        end
    end
end
-- endsnip

function Turret.draw(s)
    gfx.fillCircleAtPoint(TX, TY, 14)
    gfx.setLineWidth(4)
    gfx.drawLine(TX, TY,
        TX + math.cos(Turret.angle) * 30,
        TY + math.sin(Turret.angle) * 30)
    gfx.setLineWidth(1)
    for _, sh in ipairs(Turret.shots) do
        gfx.fillCircleAtPoint(sh.x, sh.y, 3)
    end
    gfx.drawTextAligned(
        string.format("crank %d deg -> barrel %d deg",
            math.floor(s.pos), math.floor(s.pos)),
        200, 40, kTextAlignment.center)
end
