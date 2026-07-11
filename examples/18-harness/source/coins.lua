-- Coins for the robot to chase. A new coin drops onto a random
-- column's floor every couple of seconds. The pit columns have
-- no floor -- which is where this chapter's bug lived.

local gfx <const> = playdate.graphics

Coins = {}

local SPAWN_T <const> = 2.0    -- seconds between coins
local MAX <const> = 6          -- live coins at once

local timer = 0

function Coins.reset()
    Coins.list = {}
    timer = 0.5
end

-- snip: spawn
-- Find the floor of a random column and hang a coin just above
-- it. A pit column has NO floor: the bounded scan runs off the
-- bottom of the grid, so we skip the spawn -- and count the
-- skip, because a counter that never moves is a question.
function Coins.spawn()
    local tx = math.random(Map.W)
    local ty = 1
    while ty <= Map.H and not Map.solid(tx, ty) do
        ty = ty + 1
    end
    if ty > Map.H then
        Harness.count("spawnSkips")    -- pit column, no floor
        return
    end
    Coins.list[#Coins.list + 1] = {
        x = (tx - 1) * Map.TILE + 8,
        y = (ty - 1) * Map.TILE - 8,
    }
    Harness.count("spawns")
end
-- endsnip

-- snip: collect
function Coins.update()
    timer = timer - DT
    if timer <= 0 and #Coins.list < MAX then
        timer = SPAWN_T
        Coins.spawn()
    end
    local p = Player.a
    for i = #Coins.list, 1, -1 do
        local c = Coins.list[i]
        if math.abs(c.x - p.x) < 10
            and math.abs(c.y - p.y) < 12 then
            table.remove(Coins.list, i)
            Harness.count("coins")
        end
    end
end
-- endsnip

function Coins.draw()
    for _, c in ipairs(Coins.list) do
        gfx.drawCircleAtPoint(c.x, c.y, 4)
        gfx.fillCircleAtPoint(c.x, c.y, 1)
    end
end
