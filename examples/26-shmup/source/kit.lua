-- vendored from shmup/core/kit.lua (MIT)
-- shmup core: the cabinet — white HUD text on black, panels, and best-score
-- persistence. Same shapes as tiles/voxel/dither/lore's Kit, so a reader who
-- knows one engine's furniture knows this one's.

local gfx <const> = playdate.graphics

Kit = {}

function Kit.text(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Kit.centered(t, y)
    local w = gfx.getTextSize(t)
    Kit.text(t, (SCREEN_W - w) // 2, y)
end

-- A black plate with a white border. Everything in this engine is drawn on
-- black EXCEPT over the terrain, which is solid white -- and white HUD text on
-- a white cavern wall is invisible. The plate is not decoration; it is the
-- guarantee that the score can always be read.
function Kit.panel(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, h)
end

-- ---- best-score persistence ----------------------------------------------
-- Write-on-record: saveBest only touches the datastore when the score actually
-- beats the stored best, so a losing run costs zero writes.
Kit.best = 0

function Kit.loadBest()
    local saved = playdate.datastore.read("best")
    Kit.best = (saved and saved.best) or 0
    return Kit.best
end

function Kit.saveBest(score)
    if score > Kit.best and score > 0 then
        Kit.best = score
        playdate.datastore.write({ best = score }, "best")
        return true
    end
    return false
end
