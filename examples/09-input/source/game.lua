-- Game: visualizer state. A ring buffer of snapshots feeds the
-- level-vs-edge trace, blips mark press edges on the lamps, and a
-- caption line narrates the most recent event.
-- Runner: the buffered-jump/coyote-time mini-demo along the bottom.

Game = {}

-- draw order for lamps and trace rows
Game.order = { "up", "down", "left", "right", "b", "a" }

Game.HISTORY = 110 -- frames the trace remembers (2 px each)

function Game.reset()
    Game.trace = {}   -- ring buffer of snapshots
    Game.head = 0
    Game.blips = {}   -- name -> frames since press edge
    Game.held = {}    -- name -> consecutive frames held
    Game.event = nil  -- caption for the last edge seen
    Game.eventT = 0
    Runner.reset()
end

function Game.update(s)
    Game.head = Game.head % Game.HISTORY + 1
    Game.trace[Game.head] = s

    for _, n in ipairs(Game.order) do
        if s[n .. "Just"] then
            Game.blips[n] = 0
            Game.event = string.upper(n) .. " just pressed"
            Game.eventT = 0
            Harness.count("presses")
        elseif s[n .. "Released"] then
            Game.event = string.upper(n) .. " just released"
            Game.eventT = 0
        elseif Game.blips[n] then
            Game.blips[n] = Game.blips[n] + 1
            if Game.blips[n] > 7 then Game.blips[n] = nil end
        end
        Game.held[n] = s[n] and (Game.held[n] or 0) + 1 or 0
    end
    Game.eventT = Game.eventT + 1
end

-- caption text for the strip under the trace
function Game.caption()
    local parts = {}
    if Game.event and Game.eventT < 45 then
        parts[#parts + 1] = Game.event
    end
    for _, n in ipairs(Game.order) do
        if Game.held[n] > 1 then
            parts[#parts + 1] = string.upper(n) .. " held " ..
                Game.held[n] .. "f"
        end
    end
    if #parts == 0 then return "waiting for input..." end
    return table.concat(parts, "   ")
end

-- ---- the runner ---------------------------------------------------

Runner = {}

-- snip: buffer
local FLOOR <const> = 222  -- resting bottom edge, in pixels
local GAP_L <const> = 230  -- the pit in the floor
local GAP_R <const> = 270
local BUFFER <const> = 6   -- frames a too-early press is remembered
local COYOTE <const> = 6   -- frames of grace after leaving a ledge

function Runner.reset()
    Runner.x, Runner.y = 20, FLOOR -- y is the runner's bottom edge
    Runner.vy = 0
    Runner.bufferT = 0  -- press stored while airborne
    Runner.coyoteT = 0  -- grace left after walking off the ledge
    Runner.label, Runner.labelT = nil, 0
end

local function overGap(x)
    local cx = x + 6 -- runner is 12 px wide; support at the centre
    return cx > GAP_L and cx < GAP_R
end

local function jump(label)
    Runner.vy = -5.5
    Runner.bufferT, Runner.coyoteT = 0, 0
    Runner.label, Runner.labelT = label, 30
    Harness.count(label)
end

function Runner.update(s)
    if Runner.bufferT > 0 then Runner.bufferT = Runner.bufferT - 1 end
    if Runner.coyoteT > 0 then Runner.coyoteT = Runner.coyoteT - 1 end
    if Runner.labelT > 0 then Runner.labelT = Runner.labelT - 1 end

    local wasGrounded = Runner.y >= FLOOR and not overGap(Runner.x)

    -- the jump button: act now, or remember the press
    if s.bJust then
        if wasGrounded then
            jump("jump")
        elseif Runner.coyoteT > 0 then
            jump("coyote jump")     -- just off the ledge: allow it
        else
            Runner.bufferT = BUFFER -- too early: queue the press
        end
    end

    Runner.x = Runner.x + 2
    if Runner.x > 400 then Runner.x = Runner.x - 400 end
    Runner.vy = Runner.vy + 0.4
    Runner.y = Runner.y + Runner.vy

    if Runner.y >= FLOOR and not overGap(Runner.x) then
        if Runner.vy > 0 then
            Runner.y, Runner.vy = FLOOR, 0    -- landed
            if Runner.bufferT > 0 then
                jump("buffered jump")         -- flush the queue
            end
        end
    elseif wasGrounded and Runner.vy > 0 then
        Runner.coyoteT = COYOTE -- walked off (not a jump): grace
    end

    if Runner.y > 260 then -- fell into the pit: back to the start
        Runner.x, Runner.y, Runner.vy = 20, FLOOR, 0
        Harness.count("falls")
    end
end
-- endsnip

Runner.FLOOR, Runner.GAP_L, Runner.GAP_R = FLOOR, GAP_L, GAP_R
