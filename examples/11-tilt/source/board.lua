-- Board: a walled tray and one steel marble. Tilt accelerates it,
-- rolling friction slows it, walls bounce it. The circle-vs-rect
-- push-out is distilled from Bearing's marble.

Board = {}

local ACCEL <const> = 400     -- px/s^2 per unit of tilt
local FRICTION <const> = 0.985
local BOUNCE <const> = 0.6    -- energy kept on a wall hit
local R <const> = 8           -- marble radius
local DT <const> = 1 / 30

-- solid rects { x, y, w, h }: the frame plus three inner walls
local WALLS <const> = {
    { 0, 0, 400, 8 }, { 0, 232, 400, 8 },
    { 0, 0, 8, 240 }, { 392, 0, 8, 240 },
    { 120, 60, 8, 120 },
    { 250, 8, 8, 110 },
    { 250, 170, 100, 8 },
}
Board.walls = WALLS
Board.R = R

function Board.reset()
    Board.x, Board.y = 60, 200
    Board.vx, Board.vy = 0, 0
    Board.trail = {}
    Board.bounces = 0
end

-- circle vs one rect: push out along the closest-point normal and
-- reflect the into-wall velocity component
local function resolve(w)
    local nx = math.max(w[1], math.min(Board.x, w[1] + w[3]))
    local ny = math.max(w[2], math.min(Board.y, w[2] + w[4]))
    local dx, dy = Board.x - nx, Board.y - ny
    local d2 = dx * dx + dy * dy
    if d2 >= R * R or d2 < 0.0001 then return end
    local d = math.sqrt(d2)
    local ux, uy = dx / d, dy / d
    Board.x = Board.x + ux * (R - d)
    Board.y = Board.y + uy * (R - d)
    local vn = Board.vx * ux + Board.vy * uy
    if vn < 0 then
        Board.vx = Board.vx - (1 + BOUNCE) * vn * ux
        Board.vy = Board.vy - (1 + BOUNCE) * vn * uy
        Board.bounces = Board.bounces + 1
        Harness.count("bounces")
    end
end

-- snip: roll
function Board.update(tx, ty)
    Board.vx = (Board.vx + tx * ACCEL * DT) * FRICTION
    Board.vy = (Board.vy + ty * ACCEL * DT) * FRICTION
    Board.x = Board.x + Board.vx * DT
    Board.y = Board.y + Board.vy * DT
    for _, w in ipairs(WALLS) do resolve(w) end

    -- breadcrumbs for the trail
    Board.trail[#Board.trail + 1] = { Board.x, Board.y }
    if #Board.trail > 45 then table.remove(Board.trail, 1) end
end
-- endsnip
