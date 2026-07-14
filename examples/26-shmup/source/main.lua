-- Chapter 26: a guided tour of the Shmup engine. Sixteen core modules are
-- vendored verbatim from shmup/core/ (MIT); the demo on top plays three levels
-- back to back -- one per scroll frame -- and then draws a diagram.
--
-- Shmup's own harness.lua is NOT vendored: the book's harness (Chapter 18's, in
-- bookharness.lua) exposes the same Harness surface the engine drives --
-- enabled, set, frame -- so the vendored engine runs unmodified. The engine's
-- cabinet (Shmup.run) is not used here either, because the tour has to swap the
-- whole game out from under itself every few hundred frames, which is not a
-- thing a cabinet should make easy.

import "CoreLibs/graphics"
import "shots"
import "bookharness"

-- snip: tour-imports
-- the vendored engine, in dependency order
import "lib"
import "frame"
import "kit"
import "snd"
import "music"
import "fx"
import "sprites"
import "stars"
import "terrain"
import "bullets"
import "enemies"
import "power"
import "boss"
import "player"
import "waves"
import "shmup"
-- the demo
import "demo"
-- endsnip

local DT <const> = 1 / 30
local PLAY <const> = 2   -- Shmup's state enum: TITLE, PLAY, OVER, WIN

-- Phase boundaries, in frames. Each of the first three loads a different level
-- into the SAME engine; the fourth is the terrain diagram.
local SIDE_AT <const> = 470
local FREE_AT <const> = 790
local DIAG_AT <const> = 1120

--------------------------------------------------------------------------------
-- snip: tour-bot
-- One bot, three frames. It reads Frame.mode and plays accordingly -- which is
-- the clearest possible statement of what a frame actually changes. Not the
-- rules, not the enemies, not the bullets: just where you are allowed to be,
-- and what "forward" means.
local cmd = { left = false, right = false, up = false, down = false,
              fire = false, bomb = false, start = false }

local function dodgeVertical()
    local shift = 0
    local ep = Bullets.ep
    for i = 1, ep.n do
        local b = ep.items[i]
        if not b.dead and b.vy > 20 then
            local t = (Player.y - b.y) / b.vy           -- when it reaches our row
            if t > 0 and t < 1.1 then
                local dx = (b.x + b.vx * t) - Player.x  -- where it will be then
                if math.abs(dx) < 24 then
                    shift = shift + (dx >= 0 and -1 or 1)
                end
            end
        end
    end
    return Lib.sign(shift)
end

local function nearestEnemyX()
    if Boss.active then return Boss.x end
    local best, bd
    local pool = Enemies.pool
    for i = 1, pool.n do
        local e = pool.items[i]
        if not e.dead then
            local d = math.abs(e.x - Player.x) + math.max(0, Player.y - e.y) * 0.35
            if not bd or d < bd then bd, best = d, e end
        end
    end
    return best and best.x or 200
end

local function playVertical()
    local sh = dodgeVertical()
    if sh ~= 0 then
        cmd.left, cmd.right = sh < 0, sh > 0
    else
        local tx = nearestEnemyX()
        cmd.left, cmd.right = tx < Player.x - 4, tx > Player.x + 4
    end
    cmd.up, cmd.down = Player.y > 214, Player.y < 206
end

local function playSide()
    -- Steer by the SAME sampled profile the collider reads. Fly the middle of
    -- the gap a little way ahead, because at 66 px/s the wall you have to clear
    -- is one you can already see.
    local ahead = math.min(SCREEN_W - 1, Player.x + 46)
    local ceil, ground = Terrain.ceilY(ahead), Terrain.groundY(ahead)
    local want = (ceil + ground) / 2

    -- Everything coming at us: bullets solved forward to our column, hulls by
    -- proximity. The gap is the hard constraint, so whatever we decide gets
    -- clamped back inside it -- there is no dodge worth flying into a wall for.
    local shift = 0
    local ep = Bullets.ep
    for i = 1, ep.n do
        local b = ep.items[i]
        if not b.dead and b.vx < -20 then
            local t = (b.x - Player.x) / -b.vx
            if t > 0 and t < 1.2 then
                local dy = (b.y + b.vy * t) - Player.y
                if math.abs(dy) < 26 then
                    shift = shift + (dy >= 0 and -1 or 1)
                end
            end
        end
    end

    local pool = Enemies.pool
    for i = 1, pool.n do
        local e = pool.items[i]
        if not e.dead then
            local dx = e.x - Player.x
            if dx > -14 and dx < 76 and math.abs(e.y - Player.y) < 26 then
                shift = shift + (e.y >= Player.y and -2 or 2)
            end
        end
    end

    if shift ~= 0 then want = Player.y + Lib.sign(shift) * 46 end

    want = Lib.clamp(want, ceil + 16, ground - 16)
    cmd.up, cmd.down = Player.y > want + 3, Player.y < want - 3
    cmd.left, cmd.right = Player.x > 110, Player.x < 98
    cmd.bomb = true
end

local function playFree()
    -- A girder does not dictate an altitude, it forbids a BAND: work out the
    -- open corridor, then aim freely inside it.
    local lo, hi = 28, 212
    for _, p in ipairs(Hull.girders) do
        local dx = p.x - Player.x
        if dx > -26 and dx < 96 then
            if p.top then lo = 20 + p.h + 14 else hi = 220 - p.h - 14 end
        end
    end

    local want = Player.y
    local best, bd
    local pool = Enemies.pool
    for i = 1, pool.n do
        local e = pool.items[i]
        if not e.dead then
            local dx = e.x - Player.x
            if dx > 40 and dx < 260 and (not bd or dx < bd) then bd, best = dx, e end
        end
    end
    if best then want = best.y end

    want = Lib.clamp(want, lo, hi)
    cmd.up, cmd.down = Player.y > want + 3, Player.y < want - 3
    cmd.right = true          -- the level has a far end. Go to it.
end

Harness.autopilot = function()
    cmd.left, cmd.right, cmd.up, cmd.down = false, false, false, false
    cmd.fire, cmd.bomb, cmd.start = false, false, false

    local st = Harness.counters.state or 1
    if st ~= PLAY then
        cmd.start = true      -- press A on the title, and after any ending
        return cmd
    end

    if Frame.mode == "vertical" then
        playVertical()
    elseif Frame.mode == "side" then
        playSide()
    else
        playFree()
    end

    cmd.fire = true
    return cmd
end
-- endsnip

--------------------------------------------------------------------------------
-- snip: tour-loop
local phase = 0

local function phaseAt(frame)
    if frame >= DIAG_AT then return 4 end
    if frame >= FREE_AT then return 3 end
    if frame >= SIDE_AT then return 2 end
    return 1
end

local frame = 0
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, function()
        local p = phaseAt(frame)
        if p ~= phase then
            phase = p
            -- The whole game is swapped out here and the engine does not
            -- notice, because a level IS its content table.
            if p <= 3 then Shmup.new(Demo.levels[p]) end
        end

        if phase == 4 then
            Demo.drawProfile()
            return
        end

        Shmup.update(DT)
        Shmup.draw()
    end)
end
-- endsnip
