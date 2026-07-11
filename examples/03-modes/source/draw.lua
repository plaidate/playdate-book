-- All rendering. Draw functions read G and never mutate it.

Draw = {}

local gfx <const> = playdate.graphics

-- snip: drawtitle
function Draw.title()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("*DODGE*", 200, 78, kTextAlignment.center)
    if G.best > 0 then
        gfx.drawTextAligned("best " .. G.best, 200, 106,
            kTextAlignment.center)
    end
    -- G.modeT drives the blink: on for half a second, off for half.
    if math.floor(G.modeT * 2) % 2 == 0 then
        gfx.drawTextAligned("press Ⓐ to play", 200, 150,
            kTextAlignment.center)
    end
end
-- endsnip

-- snip: drawplay
function Draw.play()
    gfx.clear(gfx.kColorWhite)
    local p = G.player
    local half = C.PLAYER_W / 2
    gfx.fillRect(p.x - half, C.PLAYER_Y, C.PLAYER_W, C.PLAYER_H)
    for _, b in ipairs(G.blocks) do
        gfx.fillRect(b.x, b.y, C.BLOCK, C.BLOCK)
    end
    gfx.drawText("SCORE " .. G.score, 4, 4)
end
-- endsnip

-- snip: overlays
-- Pause and game over draw ON TOP of the frozen play field, so
-- the player never loses sight of the run they are in.
function Draw.pauseOverlay()
    Draw.panel("PAUSED", "Ⓑ resumes")
end

function Draw.gameoverOverlay()
    Draw.panel("GAME OVER",
        "score " .. G.score .. "  Ⓐ for title")
end

function Draw.panel(heading, sub)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(100, 88, 200, 64)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(100, 88, 200, 64)
    gfx.drawTextAligned("*" .. heading .. "*", 200, 100,
        kTextAlignment.center)
    gfx.drawTextAligned(sub, 200, 124, kTextAlignment.center)
end
-- endsnip
