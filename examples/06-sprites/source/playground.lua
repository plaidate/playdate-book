-- Chapter 6: the collision playground. Walls, a sensor zone, a
-- ghost wall in an unmasked group, and a player square that is
-- driven into them under each collision response type.

local gfx <const> = playdate.graphics

Playground = {}

local MODES <const> = {
    gfx.sprite.kCollisionTypeSlide,
    gfx.sprite.kCollisionTypeFreeze,
    gfx.sprite.kCollisionTypeOverlap,
    gfx.sprite.kCollisionTypeBounce,
}
local NAMES <const> = { "slide", "freeze", "overlap", "bounce" }

local TAG_WALL <const> = 1
local TAG_SENSOR <const> = 2

Playground.mode = 1
Playground.trail = {}

local player

-- a filled-rect sprite, the all-purpose test body
local function boxSprite(w, h, dark)
    local img = gfx.image.new(w, h)
    gfx.pushContext(img)
    if dark then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, w, h)
    else
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
        gfx.fillRect(0, 0, w, h)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(0, 0, w, h)
    end
    gfx.popContext()
    local s = gfx.sprite.new(img)
    s:setCollideRect(0, 0, w, h)
    return s
end

-- snip: setup
function Playground.setup()
    -- arena walls and the center wall: group 1
    local walls = {
        { 200, 36, 400, 8 },    -- top
        { 200, 236, 400, 8 },   -- bottom
        { 4, 136, 8, 200 },     -- left
        { 396, 136, 8, 200 },   -- right
        { 270, 136, 20, 190 },  -- the test wall
    }
    for _, w in ipairs(walls) do
        local s = boxSprite(w[3], w[4], true)
        s:setGroups({ 1 })
        s:setTag(TAG_WALL)
        s:moveTo(w[1], w[2])
        s:add()
    end

    -- the sensor zone: group 2, never solid (see the response
    -- function below), reported through overlaps instead
    local sensor = boxSprite(60, 60, false)
    sensor:setGroups({ 2 })
    sensor:setTag(TAG_SENSOR)
    sensor:moveTo(150, 100)
    sensor:add()

    -- the ghost wall: group 3. The player's mask only covers
    -- groups 1 and 2, so this one is invisible to its physics.
    local ghost = boxSprite(16, 120, false)
    ghost:setGroups({ 3 })
    ghost:moveTo(215, 130)
    ghost:add()

    Playground.buildPlayer()
end
-- endsnip

-- snip: player
function Playground.buildPlayer()
    player = boxSprite(20, 20, true)
    player:setCollidesWithGroups({ 1, 2 })
    player:setZIndex(10)
    player:moveTo(50, 90)
    player:add()

    -- called by moveWithCollisions for each candidate overlap
    function player:collisionResponse(other)
        if other:getTag() == TAG_SENSOR then
            return gfx.sprite.kCollisionTypeOverlap
        end
        return MODES[Playground.mode]
    end
end
-- endsnip

Playground.vx, Playground.vy = 4, 2

function Playground.reset(mode)
    Playground.mode = mode
    Playground.trail = {}
    Playground.vx, Playground.vy = 4, 2
    player:moveTo(50, 90)
end

-- snip: move
function Playground.move(dx, dy)
    local goalX, goalY
    if NAMES[Playground.mode] == "bounce" then
        goalX = player.x + Playground.vx
        goalY = player.y + Playground.vy
    else
        goalX, goalY = player.x + dx, player.y + dy
    end

    local ax, ay, cols, n = player:moveWithCollisions(goalX, goalY)
    for i = 1, n do
        local c = cols[i]
        if c.type == gfx.sprite.kCollisionTypeBounce then
            -- keep moving: reflect velocity off the hit normal
            if c.normal.x ~= 0 then
                Playground.vx = -Playground.vx
            end
            if c.normal.y ~= 0 then
                Playground.vy = -Playground.vy
            end
            Harness.count("bounces")
        elseif c.other:getTag() == TAG_SENSOR then
            Harness.count("sensorTouches")
        end
    end

    local t = Playground.trail
    t[#t + 1] = { player.x, player.y }
end
-- endsnip

-- snip: overlay
-- Debug overlay, drawn immediate-mode after sprite.update(). We
-- dirty the whole screen each frame so the sprite system repaints
-- under it; a real game would keep this to a HUD strip.
function Playground.overlay()
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)
    for _, p in ipairs(Playground.trail) do
        gfx.fillCircleAtPoint(p[1], p[2], 2)
    end
    local overlaps = player:overlappingSprites()
    gfx.drawText("*response: " .. NAMES[Playground.mode] .. "*",
        8, 8)
    gfx.drawTextAligned("overlapping: " .. #overlaps, 392, 8,
        kTextAlignment.right)
end
-- endsnip

Playground.playerSprite = function() return player end
