-- Chapter 10: the crank. Three proven mappings on one handle,
-- cycled with A: a detented selector (getCrankTicks), a 1:1 aim
-- turret (getCrankPosition), and a wind-and-release lob
-- (getCrankChange). Undocked-crank UI via playdate.ui.crankIndicator.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank" -- REQUIRED for playdate.getCrankTicks
import "shots"
import "bookharness"
import "input"
import "selector"
import "turret"
import "lob"

local gfx <const> = playdate.graphics

local TITLES <const> = {
    "1/3 DETENTED SELECTOR",
    "2/3 ONE-TO-ONE AIM",
    "3/3 WIND AND RELEASE",
}

local frame = 0
Selector.reset()
Turret.reset()
Lob.reset()

-- snip: panels
local panels = { Selector, Turret, Lob }
local cur = 1

function playdate.update()
    local s = Input.gather(frame, 12) -- 12 detents per revolution
    if s.aJust then
        cur = cur % #panels + 1
        panels[cur].reset()
        Harness.count("panelSwaps")
    end
    panels[cur].update(s)

    gfx.clear(gfx.kColorWhite)
    gfx.drawText("*" .. TITLES[cur] .. "*", 8, 2)
    gfx.drawTextAligned("A: next demo", 392, 2,
        kTextAlignment.right)
    panels[cur].draw(s)

    if s.docked then -- nudge the player toward the handle
        playdate.ui.crankIndicator:draw()
    end
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
