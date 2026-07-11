-- The autopilot: enemy AI pointed at the player's chair
-- (Chapter 16). It chases coins, and it wears the scars every
-- shipped autopilot earned: goal-progress stuck detection and
-- a wander-burst for when it boxes itself in.

Pilot = {}

local bestDist = nil    -- closest we have been to the target
local stuckFor = 0      -- frames without goal progress
local burst = 0         -- frames of wander-burst left
local burstDir = 1

function Pilot.reset()
    bestDist, stuckFor, burst = nil, 0, 0
end

-- snip: seek
-- Chase the nearest coin; patrol right when there are none.
local function target()
    local p, best, bd = Player.a, nil, nil
    for _, c in ipairs(Coins.list) do
        local d = math.abs(c.x - p.x) + math.abs(c.y - p.y)
        if not bd or d < bd then best, bd = c, d end
    end
    return best, bd
end
-- endsnip

-- snip: probes
-- Look where we are GOING, not where we are: a wall just ahead
-- means jump now; a column with no floor at all means the pit.
local function wallAhead(p, dir)
    local tx, ty = Map.tileAt(p.x + dir * 20, p.y)
    return Map.solid(tx, ty)
end

local function pitAhead(p, dir)
    local tx = Map.tileAt(p.x + dir * 24, p.y)
    for ty = 1, Map.H do
        if Map.solid(tx, ty) then return false end
    end
    return true
end
-- endsnip

-- snip: think
function Pilot.think(frame)
    local b = {}
    local p = Player.a
    local coin, dist = target()

    if burst > 0 then              -- committed wander-burst
        burst = burst - 1
        b.left = burstDir < 0
        b.right = burstDir > 0
        b.jump = true
        return b
    end

    local dir = 1
    if coin then
        if math.abs(coin.x - p.x) > 4 then
            dir = coin.x > p.x and 1 or -1
            b.left = dir < 0
            b.right = dir > 0
        end
        -- jump for coins overhead, for walls, and for the pit
        b.jump = (coin.y < p.y - 20
                and math.abs(coin.x - p.x) < 30)
            or wallAhead(p, dir)
            or pitAhead(p, dir)
    else
        b.right = true             -- patrol until one spawns
        b.jump = wallAhead(p, 1) or pitAhead(p, 1)
    end

    -- Stuck means no GOAL progress, not "not moving": a bot
    -- pacing under an unreachable coin moves constantly while
    -- getting nowhere. Track the best distance ever reached.
    if coin and dist then
        if not bestDist or dist < bestDist - 1 then
            bestDist, stuckFor = dist, 0
        else
            stuckFor = stuckFor + 1
        end
    else
        bestDist, stuckFor = nil, 0
    end
    if stuckFor > 90 then          -- three seconds of nothing
        burst = 25
        burstDir = (math.random(2) == 1) and 1 or -1
        bestDist, stuckFor = nil, 0
        Harness.count("bursts")
    end
    return b
end
-- endsnip
