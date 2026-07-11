-- The microbenchmark: time N calls of each draw operation every
-- frame, smooth with an EMA, and rank the results live.

local gfx <const> = playdate.graphics

Bench = {}

local N <const> = 200        -- calls per op, per frame
local ALPHA <const> = 0.1    -- EMA smoothing factor
local ms <const> = playdate.getCurrentTimeMilliseconds

-- the workbench: a clipped square all ops draw into
local X <const>, Y <const> = 268, 96
local SIDE <const> = 120

-- a 32x32 sprite for the image ops, built once at load
local sprite = gfx.image.new(32, 32, gfx.kColorWhite)
gfx.pushContext(sprite)
gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
gfx.fillCircleAtPoint(16, 16, 14)
gfx.setColor(gfx.kColorBlack)
gfx.drawCircleAtPoint(16, 16, 14)
gfx.fillRect(12, 12, 8, 8)
gfx.popContext()

-- snip: ops
-- Every op draws into the same clipped workbench, at positions
-- that vary with `i`, so no op wins by drawing in one spot.
-- pre/post run once per batch, outside the timer's concern.
local ops = {
    { name = "fillRect", fn = function(i)
        gfx.fillRect(X + i % 80, Y + i * 7 % 80, 32, 32)
    end },
    { name = "pattern fill",
      pre = function()
        gfx.setDitherPattern(0.5,
            gfx.image.kDitherTypeBayer4x4)
      end,
      post = function() gfx.setColor(gfx.kColorBlack) end,
      fn = function(i)
        gfx.fillRect(X + i % 80, Y + i * 7 % 80, 32, 32)
    end },
    { name = "image draw", fn = function(i)
        sprite:draw(X + i % 80, Y + i * 7 % 80)
    end },
    { name = "drawScaled x2", fn = function(i)
        sprite:drawScaled(X + i % 50, Y + i * 7 % 50, 2)
    end },
    { name = "drawRotated", fn = function(i)
        sprite:drawRotated(X + 30 + i % 60,
            Y + 30 + i * 7 % 60, i * 3 % 360)
    end },
    { name = "drawText", fn = function(i)
        gfx.drawText("SCORE 1234", X + i % 40, Y + i * 7 % 90)
    end },
}
-- endsnip

-- snip: measure
-- Time a batch of N calls, then fold it into a rolling average.
-- getCurrentTimeMilliseconds resolves whole milliseconds, so a
-- single sample is mostly noise -- the EMA is the meter.
function Bench.update()
    gfx.setClipRect(X, Y, SIDE, SIDE)
    for _, op in ipairs(ops) do
        if op.pre then op.pre() end
        local t0 = ms()
        for i = 1, N do op.fn(i) end
        local d = ms() - t0
        if op.post then op.post() end
        op.ema = (op.ema or d) * (1 - ALPHA) + d * ALPHA
        Harness.set(op.name, math.floor(op.ema * 10) / 10)
    end
    gfx.clearClipRect()
    table.sort(ops, function(a, b) return a.ema < b.ema end)
end
-- endsnip

-- snip: table
function Bench.draw()
    gfx.drawText("*draw cost, ranked*", 12, 8)
    gfx.drawText(N .. " calls per op, per frame (EMA)", 12, 30)
    local y = 60
    for rank, op in ipairs(ops) do
        gfx.drawText(rank .. ". " .. op.name, 20, y)
        gfx.drawTextAligned(
            string.format("%.1f ms", op.ema or 0),
            244, y, kTextAlignment.right)
        y = y + 22
    end
    gfx.drawRect(X - 4, Y - 4, SIDE + 8, SIDE + 8)
    gfx.drawText("workbench", X - 4, Y - 26)
end
-- endsnip
