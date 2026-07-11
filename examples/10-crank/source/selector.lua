-- Panel 1: a detented selector. Twelve ticks per revolution means
-- a decisive 30-degree click per menu step -- the same feel as
-- Bulwark's piece rotation and Chitin's fighter select.

Selector = {}

local gfx <const> = playdate.graphics

local ITEMS <const> = {
    "SQUARE WAVE", "SAWTOOTH", "TRIANGLE", "NOISE BURST",
    "SINE SWEEP", "PULSE 25%", "PULSE 12%", "SILENCE",
}

function Selector.reset()
    Selector.i = 1
    Selector.flash = 0
end

-- snip: detent
function Selector.update(s)
    if s.ticks ~= 0 then
        local n = #ITEMS
        Selector.i = (Selector.i - 1 + s.ticks) % n + 1
        Selector.flash = 6 -- brief highlight: one click, one step
        Harness.count("detents", math.abs(s.ticks))
    end
    if Selector.flash > 0 then Selector.flash = Selector.flash - 1 end
end
-- endsnip

function Selector.draw(s)
    -- the list
    for i, name in ipairs(ITEMS) do
        local y = 36 + (i - 1) * 22
        if i == Selector.i then
            gfx.fillRoundRect(20, y - 2, 160, 20, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.drawText(name, 28, y)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        else
            gfx.drawText(name, 28, y)
        end
    end
    -- the dial: 12 detent notches and the crank needle
    local cx, cy, r = 300, 120, 56
    gfx.drawCircleAtPoint(cx, cy, r)
    for k = 0, 11 do
        local a = math.rad(k * 30 - 90)
        gfx.drawLine(cx + math.cos(a) * (r - 6),
            cy + math.sin(a) * (r - 6),
            cx + math.cos(a) * r, cy + math.sin(a) * r)
    end
    local a = math.rad(s.pos - 90)
    gfx.setLineWidth(Selector.flash > 0 and 3 or 1)
    gfx.drawLine(cx, cy, cx + math.cos(a) * (r - 10),
        cy + math.sin(a) * (r - 10))
    gfx.setLineWidth(1)
    gfx.drawTextAligned(
        string.format("position %d deg", math.floor(s.pos)),
        cx, cy + r + 10, kTextAlignment.center)
    gfx.drawTextAligned("12 ticks/rev = 30 deg per step",
        cx, cy + r + 28, kTextAlignment.center)
end
