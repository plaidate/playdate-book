-- Input: the crank, bot-or-hardware. The bot supplies a per-frame
-- delta in degrees (bot.crank); we integrate it into an absolute
-- position and derive detent ticks with the same fixed-boundary
-- rule the SDK uses, so a scripted run exercises the identical
-- panel code a human's crank does.

Input = {}

local pd <const> = playdate

local botPos = 0     -- synthetic absolute position, in degrees
local prevA = false  -- for the bot's A edge

-- snip: crank-read
-- One snapshot per frame:
--   pos    absolute degrees, 0 = crank straight up
--   change delta degrees since last frame (signed)
--   ticks  detents crossed this frame (getCrankTicks)
--   aJust  the panel-advance button
--   docked true when the crank is folded into the body
function Input.gather(frame, ticksPerRev)
    local bot = Harness.input(frame)
    local s = {}
    if bot then
        local change = bot.crank or 0
        botPos = (botPos + change) % 360
        s.pos, s.change = botPos, change
        s.ticks = Input.botTicks(change, ticksPerRev)
        s.aJust = (bot.a and not prevA) or false
        prevA = bot.a or false
        s.docked = false
    else
        s.pos = pd.getCrankPosition()
        s.change = pd.getCrankChange()
        -- getCrankTicks REQUIRES import "CoreLibs/crank"
        s.ticks = pd.getCrankTicks(ticksPerRev)
        s.aJust = pd.buttonJustPressed(pd.kButtonA)
        s.docked = pd.isCrankDocked()
    end
    return s
end
-- endsnip

-- snip: synth-ticks
-- Mirror of the SDK's tick rule: boundaries sit at fixed absolute
-- angles, every 360/n degrees; a tick fires when one is crossed.
local acc = 0
function Input.botTicks(change, ticksPerRev)
    acc = acc + change
    local per = 360 / ticksPerRev
    local ticks = 0
    while acc >= per do acc = acc - per; ticks = ticks + 1 end
    while acc <= -per do acc = acc + per; ticks = ticks - 1 end
    return ticks
end
-- endsnip
