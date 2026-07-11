-- The easing gallery: twelve playdate.easingFunctions plotted
-- as curves. Time runs left to right, value bottom to top.

local gfx <const> = playdate.graphics

Gallery = {}

local names <const> = {
    "linear", "inQuad", "outQuad", "inOutQuad",
    "inCubic", "outCubic", "inQuart", "outBack",
    "inOutBack", "outBounce", "outElastic", "inExpo",
}

-- snip: gallery
function Gallery.draw()
    gfx.clear(gfx.kColorWhite)
    for i, name in ipairs(names) do
        local fn = playdate.easingFunctions[name]
        local col = (i - 1) % 4
        local row = (i - 1) // 4
        local x0 = 8 + col * 99
        local y0 = 12 + row * 76
        local w, h = 84, 46
        gfx.drawRect(x0, y0, w, h)
        local px, py
        for s = 0, 40 do
            local t = s / 40
            -- every easing takes (t, b, c, d): time, begin,
            -- change, duration. b=0, c=1, d=1 plots 0..1.
            local v = fn(t, 0, 1, 1)
            local x = x0 + t * w
            local y = y0 + h - v * h
            -- back/elastic overshoot the box; let them, a bit
            y = math.max(y0 - 10, math.min(y0 + h + 10, y))
            if px then gfx.drawLine(px, py, x, y) end
            px, py = x, y
        end
        gfx.drawTextAligned(name, x0 + w // 2,
            y0 + h + 2, kTextAlignment.center)
    end
end
-- endsnip
