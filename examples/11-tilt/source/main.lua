-- Chapter 11: tilt, menus, and system UI. A marble rolls a walled
-- tray under accelerometer control; B flips to a gridview
-- scoreboard; the System Menu gets three custom items and a
-- procedural pause card (hold left to preview it in-game).

import "CoreLibs/graphics"
import "CoreLibs/ui" -- gridview lives here
import "shots"
import "bookharness"
import "board"
import "scores"
import "sysmenu"

local gfx <const> = playdate.graphics
local pd <const> = playdate

Game = {
    mode = "board", -- "board" | "scores"
    showTrail = true,
    marble = "steel",
}

local frame = 0
local smoothX, smoothY = 0, 0
local zeroX, zeroY = 0, 0
local tiltX, tiltY = 0, 0

-- the accelerometer is off by default; start it once at boot
pd.startAccelerometer()
Board.reset()
Scores.setup()
Sysmenu.setup()

function Game.calibrate()
    -- current smoothed reading becomes the new "flat"
    zeroX, zeroY = smoothX, smoothY
end

-- snip: tilt
-- In the Simulator the accelerometer reads the window's tilt
-- sliders, which a headless run never moves -- so the bot supplies
-- tilt through the same seam the buttons use.
local function readTilt(bot)
    local x = bot and bot.tiltX
        or select(1, pd.readAccelerometer())
    local y = bot and bot.tiltY
        or select(2, pd.readAccelerometer())
    x, y = x or 0, y or 0
    -- low-pass: keep 80% of the old value, take 20% of the new
    smoothX = smoothX + (x - smoothX) * 0.2
    smoothY = smoothY + (y - smoothY) * 0.2
    -- calibration: tilt is measured from the player's "flat"
    return smoothX - zeroX, smoothY - zeroY
end
-- endsnip

-- buttons through the same seam (the Chapter 9 pattern, minimal)
local prev = {}
local function gather(bot)
    local s = {}
    local names = { "a", "b", "up", "down", "left" }
    local codes = { pd.kButtonA, pd.kButtonB, pd.kButtonUp,
        pd.kButtonDown, pd.kButtonLeft }
    for i, n in ipairs(names) do
        if bot then
            s[n] = bot[n] or false
        else
            s[n] = pd.buttonIsPressed(codes[i])
        end
        s[n .. "Just"] = s[n] and not prev[n]
        prev[n] = s[n]
    end
    s.preview = (bot and bot.showPause) or s.left
    return s
end

local function drawBoard(s)
    gfx.clear(gfx.kColorWhite)
    for _, w in ipairs(Board.walls) do
        gfx.fillRect(w[1], w[2], w[3], w[4])
    end
    if Game.showTrail then
        for i = 1, #Board.trail, 3 do
            local p = Board.trail[i]
            gfx.fillCircleAtPoint(p[1], p[2], 1)
        end
    end
    gfx.fillCircleAtPoint(Board.x, Board.y, Board.R)
    gfx.setColor(gfx.kColorWhite) -- glint, for 1-bit visibility
    gfx.fillCircleAtPoint(Board.x - 3, Board.y - 3, 2)
    gfx.setColor(gfx.kColorBlack)
    -- the tilt vector, scaled up so it reads on screen
    gfx.drawLine(Board.x, Board.y, Board.x + tiltX * 60,
        Board.y + tiltY * 60)
    gfx.drawText(string.format("tilt %+.2f %+.2f  bounces %d",
        tiltX, tiltY, Board.bounces), 14, 12)
    gfx.drawTextAligned("B: scores", 386, 12, kTextAlignment.right)
end

-- the pause card, previewed in-game (the real one appears only
-- when the player opens the System Menu)
local function drawPreview()
    Sysmenu.pauseImage():draw(0, 0)
    gfx.setDitherPattern(0.5) -- mark the half the menu covers
    gfx.fillRect(200, 0, 200, 240)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("system menu", 300, 110,
        kTextAlignment.center)
    gfx.drawTextAligned("slides in here", 300, 128,
        kTextAlignment.center)
end

-- snip: update
function playdate.update()
    local bot = Harness.input(frame)
    local s = gather(bot)

    if s.bJust then
        Game.mode = Game.mode == "board" and "scores" or "board"
    end

    if Game.mode == "scores" then
        Scores.update(s)
        Scores.draw()
    else
        tiltX, tiltY = readTilt(bot)
        Board.update(tiltX, tiltY)
        if s.preview then
            drawPreview()
        else
            drawBoard(s)
        end
    end
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
