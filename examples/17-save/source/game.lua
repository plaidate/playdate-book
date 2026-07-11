-- A game just big enough to need saving: press A on the beat
-- marker to score. Beating the high score writes the progress
-- store; every press appends a line to a plain-text log file.

local gfx <const> = playdate.graphics

Game = {}

local score = 0
local t = 0

function Game.enter()
    score = 0
    Save.data.plays = Save.data.plays + 1
    Save.store()
end

-- snip: play
function Game.handle(inp)
    if inp.aPressed then
        score = score + 10 * Options.difficulty
        Harness.count("points", 10 * Options.difficulty)
        Game.log(score)
        local high = Save.data.high
        if score > high.score then
            high.score = score
            high.name = "YOU"
            Save.store()       -- persist the moment it happens
        end
    end
end
-- endsnip

-- snip: log
-- Arbitrary files go through playdate.file. Datastores are
-- one-table-per-file; a grow-only log wants append instead.
function Game.log(score)
    local f = playdate.file.open("runlog.txt",
        playdate.file.kFileAppend)
    if not f then return end
    f:write(json.encode({ score = score }) .. "\n")
    f:close()
end
-- endsnip

function Game.update()
    t = t + 1
end

function Game.draw()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("*SCORE DRILL*", 200, 20,
        kTextAlignment.center)
    -- a marker slides back and forth; purely decorative
    local mx = 200 + 120 * math.sin(t * 0.12)
    gfx.drawLine(80, 90, 320, 90)
    gfx.fillCircleAtPoint(mx, 90, 6)
    gfx.drawTextAligned("A scores 10 x difficulty ("
        .. Options.difficulty .. ")", 200, 120,
        kTextAlignment.center)
    gfx.drawTextAligned("score  " .. score, 200, 150,
        kTextAlignment.center)
    local high = Save.data.high
    gfx.drawTextAligned("high   " .. high.score
        .. "  " .. high.name, 200, 170,
        kTextAlignment.center)
    gfx.drawText("B next screen", 8, 222)
end
