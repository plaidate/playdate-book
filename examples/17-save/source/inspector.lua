-- The save inspector: renders the two datastores as the JSON
-- actually on disk, plus the game's file listing. Being able
-- to SEE the save is half of debugging persistence.

local gfx <const> = playdate.graphics

Inspector = {}

-- snip: inspect
local function drawStore(name, x, y)
    gfx.drawText("*" .. name .. ".json*", x, y)
    y = y + 18
    local d = playdate.datastore.read(name)
    local txt = d and json.encodePretty(d) or "(missing)"
    txt = txt:gsub("\t", "  ")
    for line in (txt .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            gfx.drawText(line, x, y)
            y = y + 15
        end
    end
    return y
end

function Inspector.draw(migrated)
    gfx.clear(gfx.kColorWhite)
    gfx.drawText("*SAVE INSPECTOR*  Data/<bundleID>/", 8, 4)
    drawStore("progress", 8, 26)
    drawStore("options", 210, 26)
    local files = table.concat(playdate.file.listFiles(), " ")
    gfx.drawText("files: " .. files, 8, 184)
    if migrated then
        gfx.drawText("schema v2 (migrated)", 8, 204)
    else
        gfx.drawText("A: load + migrate", 8, 204)
    end
    gfx.drawText("B next screen", 8, 222)
end
-- endsnip
