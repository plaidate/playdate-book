-- The runner: Chapter 14's movement distilled -- run, jump,
-- coyote and buffer frames -- plus a respawn when the pit wins.

local gfx <const> = playdate.graphics

Player = {}

local RUN_ACC  <const> = 900   -- px/s^2 toward max run speed
local FRICTION <const> = 700   -- px/s^2 toward rest, grounded
local MAX_RUN  <const> = 130   -- px/s
local JUMP_VEL <const> = -330  -- px/s at takeoff
local GRAV     <const> = 850   -- px/s^2
local MAX_FALL <const> = 340   -- terminal velocity, px/s
local COYOTE   <const> = 4     -- frames of grace off a ledge
local BUFFER   <const> = 4     -- frames a press is remembered

function Player.reset()
    Player.a = { x = 40, y = 180, hw = 6, hh = 7 }
    Player.vx, Player.vy = 0, 0
    Player.grounded = false
    Player.coyote, Player.buffer = 0, 0
end

function Player.update(inp)
    local p = Player

    if inp.left then
        p.vx = math.max(p.vx - RUN_ACC * DT, -MAX_RUN)
    elseif inp.right then
        p.vx = math.min(p.vx + RUN_ACC * DT, MAX_RUN)
    elseif p.grounded then
        local f = FRICTION * DT
        if p.vx > f then p.vx = p.vx - f
        elseif p.vx < -f then p.vx = p.vx + f
        else p.vx = 0 end
    end

    if p.grounded then p.coyote = COYOTE
    elseif p.coyote > 0 then p.coyote = p.coyote - 1 end
    if inp.jump then p.buffer = BUFFER
    elseif p.buffer > 0 then p.buffer = p.buffer - 1 end
    if p.buffer > 0 and p.coyote > 0 then
        p.vy = JUMP_VEL
        p.buffer, p.coyote = 0, 0
        p.grounded = false
        Harness.count("jumps")
    end

    p.vy = math.min(p.vy + GRAV * DT, MAX_FALL)

    local hitX, hitY = Phys.move(p.a, p.vx * DT, p.vy * DT)
    if hitX then p.vx = 0 end
    if hitY then
        if p.vy > 0 then p.grounded = true end
        p.vy = 0
    elseif p.vy ~= 0 then
        p.grounded = false
    end

    -- snip: fall
    -- The pit: the player fell out of the world. Respawn -- and
    -- COUNT it, because a "falls" that never moves would mean
    -- the pit is unreachable, and one that races upward would
    -- mean the bot can't cross it. Either number is a finding.
    if p.a.y > 260 then
        Harness.count("falls")
        Player.reset()
    end
    -- endsnip
end

function Player.draw()
    local a = Player.a
    gfx.fillRoundRect(a.x - a.hw, a.y - a.hh,
        a.hw * 2, a.hh * 2, 3)
    gfx.setColor(gfx.kColorWhite)
    local ex = Player.vx < 0 and a.x - 3 or a.x + 3
    gfx.fillRect(ex - 1, a.y - 4, 2, 2)
    gfx.setColor(gfx.kColorBlack)
end
