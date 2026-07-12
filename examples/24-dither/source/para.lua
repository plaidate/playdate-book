-- vendored from dither/core/para.lua (MIT)
-- Dither core: parallax with atmospheric depth. Register layers once
-- (back first) with Para.layer(imgOrFn, speed, shade [, y]); per frame
-- Para.draw(camx) draws back-to-front — images x-tile via repeated
-- draws and fade with drawFaded(1 - shade/16, Bayer8x8) so distance
-- reads as tone; fn layers get Shade.set(shade) then fn(ox).

local gfx = playdate.graphics

Para = {}

local W <const> = 400
local DITHER <const> = gfx.image.kDitherTypeBayer8x8

local layers = {}
local nLayers = 0

function Para.clear()
    nLayers = 0
end

-- imgOrFn: a gfx.image (tiled in x) or a function(ox) that draws
-- itself with the layer's pattern already set. speed: camx multiplier
-- (0 = pinned sky .. 1 = foreground). shade: 0 = full contrast ..
-- 16 = gone. y: top of an image layer (default 0).
function Para.layer(imgOrFn, speed, shade, y)
    nLayers = nLayers + 1
    local l = layers[nLayers]
    if not l then
        l = {}
        layers[nLayers] = l
    end
    l.speed, l.y = speed, y or 0
    l.shade = Shade.quant(shade or 0)
    l.alpha = 1 - l.shade / 16
    if type(imgOrFn) == "function" then
        l.fn, l.img, l.w = imgOrFn, nil, 0
    else
        l.img, l.fn = imgOrFn, nil
        l.w = imgOrFn.width
    end
end

-- snip: para-draw
function Para.draw(camx)
    for i = 1, nLayers do
        local l = layers[i]
        local ox = -camx * l.speed
        if l.fn then
            Shade.set(l.shade)
            l.fn(ox)
            gfx.setColor(gfx.kColorBlack) -- un-set the pattern
        elseif l.shade < 16 then
            local x = math.floor(ox) % l.w
            if x > 0 then x = x - l.w end
            while x < W do
                if l.shade == 0 then
                    l.img:draw(x, l.y)
                else
                    l.img:drawFaded(x, l.y, l.alpha, DITHER)
                end
                x = x + l.w
            end
        end
    end
end
-- endsnip
