-- Chapter 12: a soundboard. The d-pad selects a voice, A plays it,
-- and the screen draws the envelope the speaker is producing.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "sfx"

local gfx <const> = playdate.graphics
local DT <const> = 1 / 30

-- Envelope plot region.
local PX, PY = 116, 48
local PW, PH = 272, 130

local sel = 1        -- selected voice index
local noteT = nil    -- seconds since the voice was played, or nil
local frame = 0

-- snip: env-geom
-- The envelope timeline for one note of length len: attack and
-- decay run first, sustain holds until the note gates off at len,
-- then release rings out past the end of the note.
local function envTimes(v)
    local e = v.env
    local hold = math.max(0, v.len - e.a - e.d)
    return e.a, e.d, hold, e.r, e.a + e.d + hold + e.r
end

-- Envelope level (0..1) at time t, for the playhead dot.
local function envLevel(v, t)
    local a, d, hold, r = envTimes(v)
    local s = v.env.s
    if t < a then return t / a end
    t = t - a
    if t < d then return 1 - (1 - s) * t / d end
    t = t - d
    if t < hold then return s end
    t = t - hold
    if t < r then return s * (1 - t / r) end
    return 0
end
-- endsnip

-- snip: env-draw
local function drawEnvelope(v, t)
    local a, d, hold, r, total = envTimes(v)
    local s = v.env.s
    local function px(tt) return PX + tt / total * PW end
    local function py(lv) return PY + PH - lv * PH end
    gfx.drawRect(PX - 1, PY - 1, PW + 2, PH + 2)
    gfx.drawLine(px(0), py(0), px(a), py(1))
    gfx.drawLine(px(a), py(1), px(a + d), py(s))
    gfx.drawLine(px(a + d), py(s), px(a + d + hold), py(s))
    gfx.drawLine(px(a + d + hold), py(s), px(total), py(0))
    -- dotted separators and a label under each segment
    local marks = { 0, a, a + d, a + d + hold, total }
    local names = { "A", "D", "S", "R" }
    for i = 1, 4 do
        local mx = (px(marks[i]) + px(marks[i + 1])) / 2
        gfx.drawTextAligned(names[i], mx, PY + PH + 6,
            kTextAlignment.center)
    end
    for i = 2, 4 do
        for y = PY, PY + PH, 6 do
            gfx.drawPixel(px(marks[i]), y)
        end
    end
    -- playhead: a vertical line at t, a dot riding the curve
    if t and t <= total then
        local x = px(t)
        gfx.drawLine(x, PY, x, PY + PH)
        gfx.fillCircleAtPoint(x, py(envLevel(v, t)), 3)
    end
end
-- endsnip

local function drawValues(v)
    local e = v.env
    local txt = string.format(
        "a %.0fms  d %.0fms  s %.2f  r %.0fms  len %.0fms",
        e.a * 1000, e.d * 1000, e.s, e.r * 1000, v.len * 1000)
    gfx.drawTextAligned(txt, PX + PW / 2, 202,
        kTextAlignment.center)
end

local function drawBoard()
    gfx.drawText("*SOUNDBOARD*", 8, 8)
    for i, v in ipairs(Sfx.voices) do
        local y = 48 + (i - 1) * 26
        if i == sel then
            gfx.fillRect(4, y - 4, 100, 24)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.drawText(v.name, 10, y)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        else
            gfx.drawText(v.name, 10, y)
        end
    end
    gfx.drawText("d-pad select   Ⓐ play", 8, 220)
end

-- snip: input
local function input()
    local bot = Harness.input(frame)
    local up = bot and bot.up
        or playdate.buttonJustPressed(playdate.kButtonUp)
    local down = bot and bot.down
        or playdate.buttonJustPressed(playdate.kButtonDown)
    local a = bot and bot.a
        or playdate.buttonJustPressed(playdate.kButtonA)
    if up and sel > 1 then
        sel = sel - 1
        noteT = nil
    end
    if down and sel < #Sfx.voices then
        sel = sel + 1
        noteT = nil
    end
    if a then
        Sfx.play(Sfx.voices[sel])
        noteT = 0
    end
end
-- endsnip

function playdate.update()
    input()
    Sfx.update(DT)
    if noteT then
        noteT = noteT + DT
        local _, _, _, _, total = envTimes(Sfx.voices[sel])
        if noteT > total then noteT = nil end
    end
    gfx.clear(gfx.kColorWhite)
    drawBoard()
    drawEnvelope(Sfx.voices[sel], noteT)
    drawValues(Sfx.voices[sel])
end

-- The harness wraps the real update in a pcall and captures the
-- figures; in a release build it calls straight through (Ch. 18).
local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
