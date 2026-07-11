-- Draw.frame: clear, then let the current screen paint itself.
-- Screens bracket the world in Kit.applyShake/doneShake and end
-- with Draw.hud, so the HUD row lands on top, unshaken.

local gfx = playdate.graphics

Draw = {}

function Draw.hud(title, info)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 16)
    Kit.text(title, 4, 0)
    if info then
        local w = gfx.getTextSize(info)
        Kit.text(info, 396 - w, 0)
    end
end

function Draw.frame()
    gfx.clear(gfx.kColorBlack)
    local s = Game.screens[Game.scr]
    if s then s.draw() end
end
