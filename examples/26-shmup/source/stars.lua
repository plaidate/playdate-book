-- vendored from shmup/core/stars.lua (MIT)
-- shmup core: parallax starfield. Two layers of white points on solid black.
-- It does not need to be told which way to scroll -- it asks the frame.
--
-- In the scrollers the stars move and the camera does not, so each layer
-- advances by its own speed. In the free frame it is the other way round: the
-- stars hang fixed in a far-off sky and the CAMERA moves, so they are drawn at
-- an offset proportional to the camera position. Same field, same two layers,
-- opposite mechanism -- which is the whole frame idea in miniature.

import "CoreLibs/graphics"
local gfx <const> = playdate.graphics

Stars = {}

local layers = {}

local function makeLayer(count, speed, size, depth)
    local pts = {}
    for i = 1, count do
        pts[i] = { x = math.random(0, SCREEN_W - 1),
                   y = math.random(0, SCREEN_H - 1) }
    end
    return { pts = pts, speed = speed, size = size, depth = depth }
end

function Stars.init()
    layers = {
        makeLayer(48, 22, 1, 0.25),
        makeLayer(24, 60, 2, 0.55),
    }
end

function Stars.update(dt)
    if Frame.free then return end   -- the sky is still; the camera does the work

    local horiz = Frame.horizontal
    for _, L in ipairs(layers) do
        local d = L.speed * dt
        for _, p in ipairs(L.pts) do
            if horiz then
                p.x = p.x - d
                if p.x < 0 then
                    p.x = p.x + SCREEN_W
                    p.y = math.random(0, SCREEN_H - 1)
                end
            else
                p.y = p.y + d
                if p.y >= SCREEN_H then
                    p.y = p.y - SCREEN_H
                    p.x = math.random(0, SCREEN_W - 1)
                end
            end
        end
    end
end

function Stars.draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)

    local free = Frame.free
    local cam = Frame.x
    for _, L in ipairs(layers) do
        local s = L.size
        local off = free and (cam * L.depth) or 0
        for _, p in ipairs(L.pts) do
            local x = free and ((p.x - off) % SCREEN_W) or p.x
            if s == 1 then
                gfx.drawPixel(x, p.y)
            else
                gfx.fillRect(x, p.y, s, s)
            end
        end
    end
end
