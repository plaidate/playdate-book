-- Chapter 13: one 8-bar loop, two engines. B swaps between the SDK
-- sequence and the step clock; A plays a blip that ducks the music.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "song"
import "seqengine"
import "stepclock"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound
local DT <const> = 1 / 30

local frame = 0

-- snip: channels
-- All music sources live on one channel, so a single volume knob
-- can duck them under gameplay SFX. The blip stays on the default
-- global channel at full volume.
local music = snd.channel.new()
SeqEngine.build(music)
StepClock.build(music)

local blip = snd.synth.new(snd.kWaveSquare)
blip:setADSR(0.002, 0.03, 0.4, 0.1)
-- endsnip

local engine = "sequence"
local duck = 0
SeqEngine.start()

-- snip: switch
local function setEngine(name)
    if engine == name then return end
    if engine == "sequence" then SeqEngine.stop()
    else StepClock.stop() end
    engine = name
    if engine == "sequence" then SeqEngine.start()
    else StepClock.start() end
    Harness.count("switches")
end
-- endsnip

local function curStep()
    if engine == "sequence" then return SeqEngine.step() end
    return StepClock.step()
end

local function seek(s)
    if engine == "sequence" then SeqEngine.seek(s)
    else StepClock.seek(s) end
end

-- snip: duck
local function playBlip()
    blip:playNote(1319, 0.5, 0.1)
    duck = 1
    Harness.count("blips")
end

local function updateDuck()
    duck = math.max(0, duck - DT / 0.5)  -- recover over 0.5 s
    music:setVolume(1 - 0.7 * duck)      -- dip to 0.3, ride back
end
-- endsnip

local function input()
    local bot = Harness.input(frame)
    local a = bot and bot.a
        or playdate.buttonJustPressed(playdate.kButtonA)
    local b = bot and bot.b
        or playdate.buttonJustPressed(playdate.kButtonB)
    if a then playBlip() end
    if b then
        setEngine(engine == "sequence" and "clock" or "sequence")
    end
    if bot and bot.seek then seek(bot.seek) end
end

-- snip: grid
local GX, GY = 64, 78     -- grid origin
local CW, CH = 20, 30     -- cell size
local ROWS = {
    { name = "hat",  notes = Song.hat },
    { name = "lead", notes = Song.lead },
    { name = "bass", notes = Song.bass },
}

-- Draw the current bar as a 16 x 3 grid, with the playhead boxed
-- around the column both engines report as "now".
local function drawGrid(step)
    local bar = (step - 1) // 16          -- 0..7
    local col = (step - 1) % 16 + 1
    for r, row in ipairs(ROWS) do
        local y = GY + (r - 1) * (CH + 6)
        gfx.drawText(row.name, 8, y + 8)
        for c = 1, 16 do
            local x = GX + (c - 1) * CW
            gfx.drawRect(x, y, CW - 2, CH)
            if row.notes[bar * 16 + c] ~= 0 then
                gfx.fillRect(x + 3, y + 3, CW - 8, CH - 6)
            end
        end
    end
    local x = GX + (col - 1) * CW
    local h = 3 * (CH + 6) - 6
    gfx.drawRect(x - 2, GY - 2, CW + 2, h + 4)
    gfx.drawRect(x - 3, GY - 3, CW + 4, h + 6)
    return bar
end
-- endsnip

local function drawHud(bar, step)
    local label = engine == "sequence"
        and "ENGINE: SDK SEQUENCE" or "ENGINE: STEP CLOCK"
    gfx.drawText("*" .. label .. "*", 8, 8)
    local ch = Song.chords[bar // 2 + 1]
    gfx.drawText(string.format("bar %d/8   chord %s   step %d",
        bar + 1, ch.name, step), 8, 30)
    gfx.drawText("Ⓐ blip (ducks music)   Ⓑ switch engine", 8, 220)
    -- a small meter so the ducking is visible in figures
    gfx.drawText("music", 262, 30)
    gfx.drawRect(320, 34, 60, 8)
    gfx.fillRect(320, 34, 60 * (1 - 0.7 * duck), 8)
end

function playdate.update()
    input()
    StepClock.update(DT)
    updateDuck()
    gfx.clear(gfx.kColorWhite)
    local step = curStep()
    local bar = drawGrid(step)
    drawHud(bar, step)
end

-- The harness wraps the real update in a pcall and captures the
-- figures; in a release build it calls straight through (Ch. 18).
local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
