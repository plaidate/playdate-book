-- Actors: a pellet-eating player bot and two chasing ghosts,
-- one on hand-rolled BFS, one on playdate.pathfinder A*.
-- All movement is cell-to-cell with smooth interpolation.

local gfx <const> = playdate.graphics

Actors = {}

local player, ghostA, ghostB, moth
local pellets          -- pellets[r][c] = true
local pelletsLeft = 0

local function newActor(c, r, speed)
    return {
        c = c, r = r, nc = c, nr = r,
        prog = 0, speed = speed, moving = false,
        path = nil,
    }
end

local function seedPellets()
    pellets = {}
    pelletsLeft = 0
    for r = 1, Maze.ROWS do
        pellets[r] = {}
        for c = 1, Maze.COLS do
            if Maze.isOpen(c, r)
                and not (c == 2 and r == 2) then
                pellets[r][c] = true
                pelletsLeft = pelletsLeft + 1
            end
        end
    end
end

function Actors.reset()
    local s = Maze.spawns
    player = newActor(s[1][1], s[1][2], 5)
    ghostA = newActor(s[2][1], s[2][2], 7)
    ghostB = newActor(s[3][1], s[3][2], 7)
    moth = { x = 350, y = 30, h = math.pi / 2, flee = 0 }
    seedPellets()
end

-- snip: stuck
-- Goal-progress stuck detection (the PLAYDATE-GUIDE lesson):
-- movement-based checks fail for wall-followers, so track the
-- best path length seen instead. No improvement for eight
-- decisions = boxed in = take a random wander burst.
local bestLen, staleCount, wander = math.huge, 0, 0

local function playerNext()
    if wander > 0 then
        wander = wander - 1
        local opts = {}
        for _, d in ipairs({ { 1, 0 }, { -1, 0 },
            { 0, 1 }, { 0, -1 } }) do
            local nc, nr = player.c + d[1], player.r + d[2]
            if Maze.isOpen(nc, nr) then
                opts[#opts + 1] = { nc, nr }
            end
        end
        return opts[math.random(#opts)]
    end
    local path = Path.bfs(player.c, player.r,
        function(c, r) return pellets[r][c] end)
    if not path then return nil end
    if #path < bestLen then
        bestLen, staleCount = #path, 0
    else
        staleCount = staleCount + 1
        if staleCount >= 8 then
            staleCount, bestLen = 0, math.huge
            wander = 3
            Harness.count("wanders")
        end
    end
    return path[2]
end
-- endsnip

-- snip: chase
local function ghostNext(g, useAstar)
    if useAstar then
        g.path = Path.astar(g.c, g.r, player.c, player.r)
    else
        g.path = Path.bfs(g.c, g.r, function(c, r)
            return c == player.c and r == player.r
        end)
    end
    if g.path and g.path[2] then return g.path[2] end
    return nil
end
-- endsnip

local function actorPx(a)
    local x0, y0 = Maze.px(a.c, a.r)
    if not a.moving then return x0, y0 end
    local x1, y1 = Maze.px(a.nc, a.nr)
    local t = a.prog / a.speed
    return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
end

-- snip: steer
-- Steering for non-grid enemies: the moth ignores walls and
-- flies by heading. Seek = turn toward the target, capped at
-- a max turn rate; flee = seek with the vector reversed;
-- wander = random jitter on top so the flight looks alive.
local MOTH_SPD <const> = 55    -- px/s
local TURN <const> = 0.09      -- max turn, radians per frame

local function steerMoth()
    local px, py = actorPx(player)
    local dx, dy = px - moth.x, py - moth.y
    if moth.flee > 0 then
        moth.flee = moth.flee - 1
        dx, dy = -dx, -dy      -- flee: seek, reversed
    elseif dx * dx + dy * dy < 900 then
        moth.flee = 45         -- spooked: run for 1.5s
        Harness.count("spooks")
    end
    local want = math.atan(dy, dx)
    local diff = want - moth.h
    -- wrap to [-pi, pi] so it turns the short way round
    while diff > math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end
    diff = math.max(-TURN, math.min(TURN, diff))
    moth.h = moth.h + diff + (math.random() - 0.5) * 0.06
    moth.x = moth.x + math.cos(moth.h) * MOTH_SPD * DT
    moth.y = moth.y + math.sin(moth.h) * MOTH_SPD * DT
    moth.x = math.max(10, math.min(390, moth.x))
    moth.y = math.max(10, math.min(198, moth.y))
end
-- endsnip

local function stepActor(a, decide)
    if a.moving then
        a.prog = a.prog + 1
        if a.prog >= a.speed then
            a.c, a.r = a.nc, a.nr
            a.moving = false
        end
        return
    end
    local nxt = decide()
    if nxt then
        a.nc, a.nr = nxt[1], nxt[2]
        a.prog = 0
        a.moving = true
    end
end

function Actors.update()
    stepActor(player, playerNext)
    stepActor(ghostA, function()
        return ghostNext(ghostA, false)
    end)
    stepActor(ghostB, function()
        return ghostNext(ghostB, true)
    end)
    steerMoth()

    -- eat the pellet under the player
    if pellets[player.r][player.c] then
        pellets[player.r][player.c] = nil
        pelletsLeft = pelletsLeft - 1
        Harness.count("pellets")
        bestLen = math.huge   -- new goal, reset progress
        if pelletsLeft == 0 then
            Harness.count("clears")
            seedPellets()
        end
    end

    -- a ghost on the player's cell = a catch; ghosts go home
    for _, g in ipairs({ ghostA, ghostB }) do
        if g.c == player.c and g.r == player.r then
            Harness.count("catches")
            local s = Maze.spawns
            ghostA.c, ghostA.r = s[2][1], s[2][2]
            ghostA.nc, ghostA.nr = s[2][1], s[2][2]
            ghostA.moving = false
            ghostB.c, ghostB.r = s[3][1], s[3][2]
            ghostB.nc, ghostB.nr = s[3][1], s[3][2]
            ghostB.moving = false
        end
    end
end

-- snip: overlay
-- Draw each ghost's CURRENT plan on the maze: solid dots for
-- the BFS ghost, hollow rings for the A* ghost. Watching the
-- two overlays diverge and reconverge is the whole figure.
local function drawPath(path, hollow)
    if not path then return end
    for i = 2, #path do
        local x, y = Maze.px(path[i][1], path[i][2])
        if hollow then
            gfx.drawCircleAtPoint(x, y, 3)
        else
            gfx.fillCircleAtPoint(x, y, 2)
        end
    end
end
-- endsnip

function Actors.draw()
    gfx.setColor(gfx.kColorBlack)
    -- pellets
    for r = 1, Maze.ROWS do
        for c = 1, Maze.COLS do
            if pellets[r][c] then
                local x, y = Maze.px(c, r)
                gfx.fillCircleAtPoint(x, y, 1)
            end
        end
    end
    drawPath(ghostA.path, false)
    drawPath(ghostB.path, true)
    -- ghosts: black blobs with one white eye
    for _, g in ipairs({ ghostA, ghostB }) do
        local x, y = actorPx(g)
        gfx.fillRoundRect(x - 6, y - 6, 12, 12, 4)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x + 1, y - 3, 2, 2)
        gfx.setColor(gfx.kColorBlack)
    end
    -- the moth: a fluttering X gliding over the walls
    do
        local mx, my = moth.x, moth.y
        local s = 4
        gfx.drawLine(mx - s, my - s, mx + s, my + s)
        gfx.drawLine(mx - s, my + s, mx + s, my - s)
    end
    -- player: white with a black outline (it must pop)
    local x, y = actorPx(player)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(x, y, 6)
    gfx.fillCircleAtPoint(x, y, 2)
    -- HUD
    local hud = Maze.ROWS * Maze.TILE + 4
    gfx.drawText("pellets " .. pelletsLeft .. "  catches "
        .. (Harness.counters.catches or 0), 8, hud)
    gfx.drawTextAligned("dots=BFS  rings=A-star",
        392, hud, kTextAlignment.right)
end
