-- vendored from shmup/core/player.lua (MIT)
-- shmup core: the player ship. It asks the frame where to start, which way is
-- forward, and how far it may roam -- so the same ship code flies a vertical
-- shooter, a cave-flyer and a Uridium hull-runner. Losing a life grants brief
-- invulnerability (a blink), recentres, refills fuel, and knocks the weapon
-- back down a rung.

Player = {}

local SPEED <const> = 170
local BOMB_CD <const> = 0.35
local START_LIVES <const> = 3
local FIRE_CD <const> = { 0.16, 0.13, 0.11 }  -- quicker as the weapon levels up

function Player.reset()
    Player.x, Player.y = Frame.spawnPoint()
    Player.facing = 1
    Player.lives = START_LIVES
    Player.fireT, Player.bombT = 0, 0
    Player.invuln = 0
    Player.alive = true
    Player.r = 4
    Player.fuel = 100
    Player.weapon = 1
    Player.shield = false
end

function Player.loseLife()
    Player.lives = Player.lives - 1
    Player.invuln = 1.5
    Player.fuel = 100
    Player.weapon = math.max(1, Player.weapon - 1)
    Player.x, Player.y = Frame.respawnPoint(Player.x, Player.y)
    if Player.lives <= 0 then Player.alive = false end
    return Player.alive
end

function Player.vulnerable() return Player.alive and Player.invuln <= 0 end

function Player.upgrade() Player.weapon = math.min(3, Player.weapon + 1) end

function Player.update(dt, input)
    if not Player.alive then return end

    local dx, dy = 0, 0
    if input.left then dx = dx - 1 end
    if input.right then dx = dx + 1 end
    if input.up then dy = dy - 1 end
    if input.down then dy = dy + 1 end

    -- In the free frame the ship turns to face the way it flies, and the gun's
    -- forward follows the hull. In the scrollers forward is fixed and the d-pad
    -- is pure movement.
    if Frame.flips() and dx ~= 0 then Player.facing = dx end

    local minX, maxX, minY, maxY = Frame.bounds()
    Player.x = Lib.clamp(Player.x + dx * SPEED * dt, minX, maxX)
    Player.y = Lib.clamp(Player.y + dy * SPEED * dt, minY, maxY)

    Player.fireT = Player.fireT - dt
    if input.fire and Player.fireT <= 0 then
        Player.fireT = FIRE_CD[Player.weapon]
        local fx, fy = Frame.fireDir(Player.facing)
        Bullets.playerFire(Player.x + fx * 9, Player.y + fy * 9,
            Player.weapon, Player.facing)
        Snd.shoot()
    end

    -- Bombs only make sense where there is a floor to drop them on.
    Player.bombT = Player.bombT - dt
    if Terrain.active and input.bomb and Player.bombT <= 0 then
        Player.bombT = BOMB_CD
        Bullets.playerBomb(Player.x, Player.y + 6)
        Snd.bomb()
    end

    if Player.invuln > 0 then Player.invuln = Player.invuln - dt end
end

function Player.draw()
    if not Player.alive then return end
    if Player.invuln > 0 and (math.floor(Player.invuln * 12) % 2 == 0) then return end

    local sx = Frame.toScreenX(Player.x)
    local name = Frame.horizontal and "pship_h" or "player"
    Sprites.draw(name, sx, Player.y, false, Frame.flips() and Player.facing < 0)

    if Player.shield then Sprites.shield(sx, Player.y) end
end
