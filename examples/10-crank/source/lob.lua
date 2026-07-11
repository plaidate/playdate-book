-- Panel 3: wind and release. Forward cranking charges the meter;
-- when the crank goes still, the stored power releases as a lobbed
-- shell at the target. Lob and Bulwark proved the feel.

Lob = {}

local gfx <const> = playdate.graphics

local STILL <const> = 5     -- quiet frames that mean "released"
local GROUND <const> = 200
local TARGET <const> = 354  -- where a full-power shell lands

function Lob.reset()
    Lob.power = 0
    Lob.still = 0
    Lob.shell = nil
    Lob.splash = nil -- landing marker { x, t, hit }
end

-- snip: wind
function Lob.update(s)
    if s.change > 0.5 then           -- winding forward
        Lob.power = math.min(100, Lob.power + s.change * 0.25)
        Lob.still = 0
    elseif Lob.power > 0 and not Lob.shell then
        Lob.still = Lob.still + 1
        if Lob.still >= STILL then   -- hands off: release!
            local v = 2 + Lob.power * 0.05
            Lob.shell = { x = 40, y = GROUND,
                dx = v * 0.8, dy = -v }
            Harness.count("lobs")
            Lob.power = 0
        end
    end
    local sh = Lob.shell
    if sh then
        sh.dy = sh.dy + 0.25         -- gravity
        sh.x, sh.y = sh.x + sh.dx, sh.y + sh.dy
        if sh.y >= GROUND then       -- touchdown
            local hit = math.abs(sh.x - TARGET) < 16
            Lob.splash = { x = sh.x, t = 40, hit = hit }
            if hit then Harness.count("hits") end
            Lob.shell = nil
        end
    end
    if Lob.splash then
        Lob.splash.t = Lob.splash.t - 1
        if Lob.splash.t <= 0 then Lob.splash = nil end
    end
end
-- endsnip

function Lob.draw(s)
    gfx.drawLine(0, GROUND, 400, GROUND)
    -- mortar and target
    gfx.fillRect(32, GROUND - 12, 16, 12)
    gfx.drawCircleAtPoint(TARGET, GROUND, 14)
    gfx.drawCircleAtPoint(TARGET, GROUND, 7)
    -- the power meter
    gfx.drawRect(40, 50, 200, 14)
    gfx.fillRect(40, 50, Lob.power * 2, 14)
    gfx.drawText(string.format("power %d", math.floor(Lob.power)),
        250, 50)
    if Lob.shell then
        gfx.fillCircleAtPoint(Lob.shell.x, Lob.shell.y, 4)
        gfx.drawText("*RELEASED!*", 40, 72)
    elseif Lob.power > 0 then
        gfx.drawText("*WINDING...*", 40, 72)
    end
    if Lob.splash then
        gfx.drawCircleAtPoint(Lob.splash.x, GROUND - 2,
            (40 - Lob.splash.t) / 3 + 4)
        if Lob.splash.hit then
            gfx.drawTextAligned("*HIT!*", TARGET, GROUND - 40,
                kTextAlignment.center)
        end
    end
end
