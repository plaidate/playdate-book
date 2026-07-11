-- The tunneling demo: two identical bullets fly at a thin wall
-- at 24 px/frame. The top one integrates naively (one big step
-- per frame) and skips straight through; the bottom one moves
-- in 1px substeps and stops dead at the wall.

local gfx <const> = playdate.graphics

Demo = {}

local SPEED <const> = 720          -- px/s = 24 px per frame
local WALL <const> = 200           -- wall spans x 200..215
local WALLW <const> = 16           -- one tile thin

local naive, sub

function Demo.reset()
    naive = { x = 28, y = 70, hw = 3, trail = {} }
    sub = { x = 28, y = 170, hw = 3, trail = {} }
end

local function hitsWall(x, hw)
    return x + hw > WALL and x - hw < WALL + WALLW
end

-- snip: demo
function Demo.update()
    local dx = SPEED * DT
    -- naive: one 24px teleport per frame. The bullet occupies
    -- x=196 one frame and x=220 the next; no position it ever
    -- OCCUPIES overlaps the wall, so the overlap test never
    -- fires and the bullet sails through 16px of "solid".
    if naive.x < 380 then
        naive.trail[#naive.trail + 1] = naive.x
        -- it even tests its destination -- but 196 jumps to
        -- 220, and neither box touches the wall at 200..215
        if not hitsWall(naive.x + dx, naive.hw) then
            naive.x = naive.x + dx
        end
    end
    -- substepped: at most 1px per test, so every pixel of the
    -- travel is checked and the wall cannot be skipped
    sub.trail[#sub.trail + 1] = sub.x
    local rem = dx
    while rem > 0 and sub.x < 380 do
        local step = math.min(1, rem)
        if hitsWall(sub.x + step, sub.hw) then break end
        sub.x = sub.x + step
        rem = rem - step
    end
end
-- endsnip

function Demo.draw()
    gfx.clear(gfx.kColorWhite)
    gfx.drawTextAligned("*24 px/frame vs a 16 px wall*",
        200, 8, kTextAlignment.center)
    -- the wall, spanning both lanes
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(WALL, 40, WALLW, 170)
    -- ghost trails: one hollow square per past frame
    for _, b in ipairs({ naive, sub }) do
        for _, x in ipairs(b.trail) do
            gfx.drawRect(x - b.hw, b.y - b.hw,
                b.hw * 2, b.hw * 2)
        end
        gfx.fillRect(b.x - b.hw, b.y - b.hw,
            b.hw * 2, b.hw * 2)
    end
    gfx.drawText("no substeps: through the wall", 24, 88)
    gfx.drawText("1px substeps: stopped", 24, 188)
    gfx.drawTextAligned("B: back to the course", 200, 222,
        kTextAlignment.center)
end
