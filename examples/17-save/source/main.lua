-- Chapter 17: Saving and Data. Three screens: a save
-- inspector (with a staged v1 -> v2 migration), an options
-- screen on its own store, and a tiny game that persists a
-- high score.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "save"
import "options"
import "inspector"
import "game"

local gfx <const> = playdate.graphics

DT = 1 / 30

local frame = 0
local mode = "inspector"
local migrated = false

-- snip: stage
-- Stage a vintage save so the migration has something to do.
-- Smoke builds always start from v1 (the shoot script wipes
-- the data directory); a human's existing save is respected.
if Harness.enabled
    or playdate.datastore.read("progress") == nil then
    playdate.datastore.write({ hi = 90, name = "AAA" },
        "progress")
    playdate.datastore.delete("options")
end
-- endsnip

Options.load()

local function gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    local just = playdate.buttonJustPressed
    return {
        aPressed = just(playdate.kButtonA),
        bPressed = just(playdate.kButtonB),
        right = just(playdate.kButtonRight),
    }
end

local ORDER <const> = { "inspector", "options", "game" }
local modeIdx = 1

function playdate.update()
    local inp = gather(frame)
    if inp.bPressed then
        modeIdx = modeIdx % #ORDER + 1
        mode = ORDER[modeIdx]
        if mode == "game" and migrated then Game.enter() end
    end

    if mode == "inspector" then
        if inp.aPressed and not migrated then
            Save.load()        -- read, migrate, write back
            migrated = true
            Harness.count("migrations")
        end
        Inspector.draw(migrated)
    elseif mode == "options" then
        Options.handle(inp)
        Options.draw()
    else
        if not migrated then   -- the game needs Save.data
            Save.load()
            migrated = true
        end
        Game.handle(inp)
        Game.update()
        Game.draw()
    end
end

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
