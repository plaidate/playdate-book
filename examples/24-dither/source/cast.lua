-- vendored from dither/core/cast.lua (MIT)
-- Dither core: cheap shadows. Cast.blob is the anchoring drop shadow
-- (dithered ellipse overlay); Cast.silhouette draws an image's opaque
-- shape as flat dithered black — kDrawModeFillBlack gated by a
-- setStencilPattern dither (verified: pattern stencils gate image
-- draws; drawing lands only on the stencil's white bits).

local gfx = playdate.graphics

Cast = {}

-- snip: cast-blob
-- dithered ellipse ground shadow centered on (x, y), w wide; only the
-- black speckle draws, so the ground shows through
function Cast.blob(x, y, w, level)
    local h = math.max(3, math.floor(w * 0.4 + 0.5))
    Shade.over(level)
    gfx.fillEllipseInRect(math.floor(x - w / 2 + 0.5),
        math.floor(y - h / 2 + 0.5), w, h)
    gfx.setColor(gfx.kColorBlack) -- un-set the pattern
end
-- endsnip

-- snip: cast-sil
-- draw img's opaque pixels as a flat dithered black shape at (x, y).
-- level 16 = solid silhouette, lower = ghostlier. The stencil pattern
-- must be white where we WANT black drawn, so level k uses ramp entry
-- 16-k (white coverage k/16).
function Cast.silhouette(img, x, y, level)
    local k = Shade.quant(level)
    if k <= 0 then return end
    gfx.setStencilPattern(Shade.ramp("bayer")[16 - k])
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    img:draw(x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.clearStencil()
end
-- endsnip
