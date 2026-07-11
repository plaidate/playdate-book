-- Input: one snapshot table per frame, bot first. The bot (scripted
-- input from shots.lua, or a real autopilot) supplies level state
-- through the same fields a human's buttons fill, and the edges are
-- derived from last frame's levels -- so scripted input gets
-- "just pressed" for free. Chapter 18 builds a whole test rig on
-- this seam.

Input = {}

-- snip: map
local pd <const> = playdate

-- logical name -> SDK button constant
local MAP <const> = {
    up    = pd.kButtonUp,
    down  = pd.kButtonDown,
    left  = pd.kButtonLeft,
    right = pd.kButtonRight,
    b     = pd.kButtonB,
    a     = pd.kButtonA,
}
-- endsnip

local prev = {} -- last frame's levels, for edge derivation

-- snip: gather
-- Returns one table per frame: for each button, its level state
-- (`s.a`), its press edge (`s.aJust`), and its release edge
-- (`s.aReleased`).
function Input.gather(frame)
    local bot = Harness.input(frame)   -- nil for human play
    local s = {}
    for name, button in pairs(MAP) do
        if bot then
            s[name] = bot[name] or false
        else
            s[name] = pd.buttonIsPressed(button)
        end
        -- edge = level now, and not level a frame ago
        s[name .. "Just"] = s[name] and not prev[name]
        s[name .. "Released"] = prev[name] and not s[name]
        prev[name] = s[name]
    end
    return s
end
-- endsnip
