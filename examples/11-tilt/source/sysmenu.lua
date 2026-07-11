-- Sysmenu: the game's three System Menu additions and the custom
-- pause card that sits beside them.

Sysmenu = {}

local gfx <const> = playdate.graphics

-- snip: menu-items
function Sysmenu.setup()
    local menu = playdate.getSystemMenu()

    -- a plain action item
    menu:addMenuItem("recenter tilt", function()
        Game.calibrate()
    end)

    -- a checkmark item: the callback gets the new boolean
    menu:addCheckmarkMenuItem("show trail", true, function(on)
        Game.showTrail = on
    end)

    -- an options item: the callback gets the chosen string
    menu:addOptionsMenuItem("marble", { "steel", "wood", "lead" },
        "steel", function(choice)
            Game.marble = choice
        end)
end
-- endsnip

-- snip: pause-image
-- The pause card is 400x240, but the System Menu slides over the
-- right half: keep everything that matters in the left 200 px.
function Sysmenu.pauseImage()
    local img = gfx.image.new(400, 240, gfx.kColorWhite)
    gfx.pushContext(img)
    gfx.fillRect(0, 0, 200, 240)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("*TILT TRAY*", 100, 24,
        kTextAlignment.center)
    gfx.drawTextAligned("tilt to roll", 100, 70,
        kTextAlignment.center)
    gfx.drawTextAligned("B: scoreboard", 100, 92,
        kTextAlignment.center)
    gfx.drawTextAligned("bounces so far: " .. Board.bounces,
        100, 136, kTextAlignment.center)
    gfx.drawTextAligned("marble: " .. Game.marble, 100, 158,
        kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawCircleAtPoint(100, 205, 14) -- the marble, as a logo
    gfx.setColor(gfx.kColorBlack)
    gfx.popContext()
    return img
end

function playdate.gameWillPause()
    -- built fresh each pause, so the stats are current
    playdate.setMenuImage(Sysmenu.pauseImage())
end

function playdate.gameWillResume()
    Game.calibrate() -- hands moved while the menu was open
end
-- endsnip
