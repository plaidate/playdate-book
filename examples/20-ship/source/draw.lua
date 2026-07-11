-- All rendering. Reads G, never mutates it.

Draw = {}

local gfx <const> = playdate.graphics

-- snip: drawtitle
function Draw.title()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("*CRANKSHOT*", 200, 60,
        kTextAlignment.center)
    gfx.drawTextAligned("crank to aim, Ⓐ to fire", 200, 92,
        kTextAlignment.center)
    if G.best > 0 then
        gfx.drawTextAligned("best " .. G.best, 200, 118,
            kTextAlignment.center)
    end
    if math.floor(G.modeT * 2) % 2 == 0 then
        gfx.drawTextAligned("press Ⓐ to start", 200, 160,
            kTextAlignment.center)
    end
    Draw.turret()
end
-- endsnip

function Draw.play()
    gfx.clear(gfx.kColorWhite)
    gfx.drawLine(0, C.GROUND, C.W, C.GROUND)
    local h = C.TSIZE / 2
    for _, t in ipairs(G.targets) do
        gfx.fillRect(t.x - h, t.y - h, C.TSIZE, C.TSIZE)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(t.x - 2, t.y - 2, 4, 4)
        gfx.setColor(gfx.kColorBlack)
    end
    for _, s in ipairs(G.shots) do
        gfx.fillCircleAtPoint(s.x, s.y, 2)
    end
    Draw.turret()
    gfx.drawText("SCORE " .. G.score, 4, 4)
    if G.best > 0 then
        gfx.drawTextAligned("BEST " .. G.best, 396, 4,
            kTextAlignment.right)
    end
end

-- snip: turret
function Draw.turret()
    local r = math.rad(G.aim or -90)
    gfx.fillCircleAtPoint(C.TX, C.TY, 12)
    gfx.setLineWidth(4)
    gfx.drawLine(C.TX, C.TY,
        C.TX + math.cos(r) * C.BARREL,
        C.TY + math.sin(r) * C.BARREL)
    gfx.setLineWidth(1)
end
-- endsnip

-- snip: gameover
-- Drawn over the frozen field, so the player sees the run that
-- killed them -- and whether it was worth it.
function Draw.gameover()
    Draw.play()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(92, 74, 216, 92)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(92, 74, 216, 92)
    gfx.drawTextAligned("*GAME OVER*", 200, 86,
        kTextAlignment.center)
    gfx.drawTextAligned("score " .. G.score, 200, 112,
        kTextAlignment.center)
    if G.newBest then
        gfx.drawTextAligned("*NEW BEST!*", 200, 136,
            kTextAlignment.center)
    else
        gfx.drawTextAligned("best " .. G.best, 200, 136,
            kTextAlignment.center)
    end
end
-- endsnip
