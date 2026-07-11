-- Scores: a gridview scoreboard (toggled with B), saved through the
-- datastore, plus the keyboard rename flow for the selected row.

Scores = {}

local gfx <const> = playdate.graphics

local DEFAULTS <const> = {
    { name = "ARCHER", score = 9200 },
    { name = "WEASEL", score = 8100 },
    { name = "KILLDEER", score = 7350 },
    { name = "CLAM", score = 6800 },
    { name = "ANEMONE", score = 6200 },
    { name = "SQUIRL", score = 5400 },
    { name = "MOSQUITO", score = 4750 },
    { name = "PANDA", score = 3900 },
    { name = "CHITIN", score = 3200 },
    { name = "MARBLE", score = 2500 },
    { name = "PEBBLE", score = 1800 },
    { name = "DUST", score = 900 },
}

function Scores.load()
    local saved = playdate.datastore.read("scores")
    Scores.rows = (saved and saved.rows) or DEFAULTS
end

function Scores.save()
    playdate.datastore.write({ rows = Scores.rows }, "scores")
end

-- snip: gridview
function Scores.setup()
    Scores.load()
    -- cellWidth 0 = rows span the grid's full width (a list view)
    local gv = playdate.ui.gridview.new(0, 24)
    gv:setNumberOfRows(#Scores.rows)
    gv:setCellPadding(0, 0, 2, 2)
    gv:setSelectedRow(1)

    function gv:drawCell(section, row, column, selected, x, y, w, h)
        if selected then
            gfx.fillRoundRect(x, y, w, h, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        local r = Scores.rows[row]
        gfx.drawText(string.format("%2d  %s", row, r.name),
            x + 8, y + 3)
        gfx.drawTextAligned(tostring(r.score), x + w - 8, y + 3,
            kTextAlignment.right)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end

    Scores.view = gv
end
-- endsnip

function Scores.update(s)
    if s.downJust then Scores.view:selectNextRow(true) end
    if s.upJust then Scores.view:selectPreviousRow(true) end
    if s.aJust then Scores.rename() end
end

function Scores.draw()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("*BEST ROLLS*", 200, 8,
        kTextAlignment.center)
    gfx.drawRect(48, 30, 304, 184)
    Scores.view:drawInRect(50, 32, 300, 180)
    gfx.drawTextAligned("up/down: select   A: rename   B: back",
        200, 222, kTextAlignment.center)
end

-- snip: keyboard
-- Rename the selected row with the system keyboard. The keyboard
-- takes over input focus; our update loop keeps running behind it.
function Scores.rename()
    local row = Scores.view:getSelectedRow()
    playdate.keyboard.textChangedCallback = function()
        Scores.pending = playdate.keyboard.text
    end
    -- the callback receives true if the player chose OK
    playdate.keyboard.keyboardWillHideCallback = function(ok)
        local text = Scores.pending
        if ok and text and #text > 0 then
            Scores.rows[row].name =
                string.upper(string.sub(text, 1, 8))
            Scores.save()
        end
        Scores.pending = nil
    end
    playdate.keyboard.show(Scores.rows[row].name)
end
-- endsnip

-- snip: lifecycle
-- The OS gives no "save now?" prompt: write when it warns you.
function playdate.gameWillTerminate()
    Scores.save()
end

function playdate.deviceWillSleep()
    Scores.save()
end

function playdate.deviceWillLock()
    Scores.save()
end
-- endsnip
