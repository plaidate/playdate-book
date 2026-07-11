-- The player: run/jump physics tuned for feel, plus a position
-- trail so the jump arc is visible on screen (and in figures).

local gfx <const> = playdate.graphics

Player = {}

-- snip: constants
local RUN_ACC   <const> = 900   -- px/s^2 toward max run speed
local FRICTION  <const> = 700   -- px/s^2 toward rest, grounded
local MAX_RUN   <const> = 130   -- px/s
local JUMP_VEL  <const> = -310  -- px/s at takeoff
local GRAV_UP   <const> = 780   -- px/s^2 while rising
local GRAV_DOWN <const> = 1500  -- px/s^2 while falling
local APEX_BAND <const> = 40    -- |vy| under this = apex hang
local APEX_GRAV <const> = 430   -- px/s^2 inside the band
local MAX_FALL  <const> = 340   -- terminal velocity, px/s
local COYOTE    <const> = 4     -- frames of grace off a ledge
local BUFFER    <const> = 4     -- frames a press is remembered
-- endsnip

local TRAIL <const> = 90        -- trail length, in frames

function Player.reset()
    Player.a = { x = 40, y = 180, hw = 6, hh = 7 }
    Player.vx, Player.vy = 0, 0
    Player.grounded = false
    Player.coyote, Player.buffer = 0, 0
    Player.drop = 0
    Player.trail = {}
end

function Player.update(inp)
    local p = Player

    -- snip: run
    -- horizontal: accelerate toward the held direction;
    -- friction pulls toward rest when idle on the ground
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
    -- endsnip

    -- snip: jump
    -- coyote frames refill while grounded; a jump press is
    -- buffered so a slightly-early press still fires on landing
    if p.grounded then p.coyote = COYOTE
    elseif p.coyote > 0 then p.coyote = p.coyote - 1 end
    if inp.jump then p.buffer = BUFFER
    elseif p.buffer > 0 then p.buffer = p.buffer - 1 end

    if inp.jump and inp.down and p.grounded
        and Phys.onOneWay(p.a) then
        p.drop = 8            -- fall through the platform
        p.grounded = false
        p.buffer = 0
    elseif p.buffer > 0 and p.coyote > 0 then
        p.vy = JUMP_VEL
        p.buffer, p.coyote = 0, 0
        p.grounded = false
        Harness.count("jumps")
    end
    if p.drop > 0 then p.drop = p.drop - 1 end
    -- endsnip

    -- snip: gravity
    -- asymmetric gravity: floaty rise, heavy fall, and a low-
    -- gravity band around the apex so the peak hangs a moment
    local g = GRAV_DOWN
    if p.vy < 0 then g = GRAV_UP end
    if not p.grounded and math.abs(p.vy) < APEX_BAND then
        g = APEX_GRAV
    end
    p.vy = math.min(p.vy + g * DT, MAX_FALL)
    -- endsnip

    -- snip: respond
    local hitX, hitY = Phys.move(p.a, p.vx * DT, p.vy * DT,
        p.drop > 0)
    if hitX then p.vx = 0 end
    if hitY then
        if p.vy > 0 then p.grounded = true end
        p.vy = 0              -- landed, or bonked a ceiling
    elseif p.vy ~= 0 then
        p.grounded = false    -- walked off a ledge, or airborne
    end
    -- endsnip

    -- snip: trail
    -- record the arc: one dot per frame, oldest dropped
    p.trail[#p.trail + 1] = { p.a.x, p.a.y }
    if #p.trail > TRAIL then table.remove(p.trail, 1) end
    -- endsnip
end

function Player.draw()
    local p = Player
    gfx.setColor(gfx.kColorBlack)
    for i = 1, #p.trail, 2 do
        local t = p.trail[i]
        gfx.fillCircleAtPoint(t[1], t[2], 1)
    end
    local a = p.a
    gfx.fillRoundRect(a.x - a.hw, a.y - a.hh,
        a.hw * 2, a.hh * 2, 3)
    gfx.setColor(gfx.kColorWhite)
    local ex = p.vx < 0 and a.x - 3 or a.x + 3
    gfx.fillRect(ex - 1, a.y - 4, 2, 2)
    gfx.setColor(gfx.kColorBlack)
end
