-- Settings persistence: a second store, separate from
-- progress. Settings change often and lose little if wiped;
-- progress changes rarely and loses everything. Never let one
-- write clobber the other.

local gfx <const> = playdate.graphics

Options = {}

-- snip: oload
function Options.load()
    local d = playdate.datastore.read("options") or {}
    -- booleans need `~= false`, not `or`: `d.sound or true`
    -- is ALWAYS true (false or true == true)
    Options.sound = d.sound ~= false      -- default: on
    Options.difficulty = d.difficulty or 2
end

function Options.store()
    playdate.datastore.write({
        sound = Options.sound,
        difficulty = Options.difficulty,
    }, "options", true)
    Harness.count("optSaves")
end
-- endsnip

local DIFF <const> = { "EASY", "NORMAL", "HARD" }

function Options.handle(inp)
    if inp.aPressed then
        Options.sound = not Options.sound
        Options.store()
    end
    if inp.right then
        Options.difficulty = Options.difficulty % 3 + 1
        Options.store()
    end
end

function Options.draw()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("*OPTIONS*", 200, 24,
        kTextAlignment.center)
    local snd = Options.sound and "ON" or "OFF"
    gfx.drawText("sound         " .. snd, 120, 80)
    gfx.drawText("difficulty    "
        .. DIFF[Options.difficulty], 120, 110)
    gfx.drawTextAligned(
        "A toggle sound   right cycle difficulty",
        200, 170, kTextAlignment.center)
    gfx.drawTextAligned("saved to options.json on change",
        200, 195, kTextAlignment.center)
    gfx.drawText("B next screen", 8, 222)
end
