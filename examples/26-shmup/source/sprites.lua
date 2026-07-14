-- vendored from shmup/core/sprites.lua (MIT)
-- shmup core: procedural 1-bit sprites — code-drawn once at load, crisp solid
-- white on transparent (the OpenTyrian 1-bit lesson: solid shapes, not dither;
-- at bullet size the eye cannot resolve a pattern, it resolves the average, and
-- the average of a 50% dither is a grey smudge). Games add their own via
-- Sprites.define in a content.sprites hook.

import "CoreLibs/graphics"
local gfx <const> = playdate.graphics

Sprites = { imgs = {}, boom = {} }

function Sprites.define(name, w, h, drawFn)
    local img = gfx.image.new(w, h)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorWhite)
    drawFn(w, h)
    gfx.popContext()
    Sprites.imgs[name] = { img = img, w = w, h = h }
end

-- flash: the sprite is already solid white, so a hit cannot be shown by making
-- it whiter. It is shown by filling its silhouette solid -- the shape blooms
-- for two frames and reads instantly as "that one is taking damage".
-- flip: horizontal mirror, for the free frame's ship turning around.
function Sprites.draw(name, x, y, flash, flip)
    local s = Sprites.imgs[name]
    if not s then return end
    local dx, dy = x - s.w // 2, y - s.h // 2
    if flash then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(dx, dy, s.w, s.h)
        return
    end
    s.img:draw(dx, dy, flip and gfx.kImageFlippedX or gfx.kImageUnflipped)
end

function Sprites.shield(x, y)
    gfx.setColor(gfx.kColorWhite)
    gfx.setLineWidth(1)
    gfx.drawCircleAtPoint(x, y, 12)
end

function Sprites.init()
    -- player, upward (vertical frame)
    Sprites.define("player", 16, 15, function(w, h)
        gfx.fillTriangle(w / 2, 0, w / 2 - 3, h - 3, w / 2 + 3, h - 3)
        gfx.fillTriangle(0, h, 5, h - 6, 5, h)
        gfx.fillTriangle(w, h, w - 5, h - 6, w - 5, h)
        gfx.fillRect(w / 2 - 1, 2, 2, h - 4)
    end)

    -- player, rightward (side and free frames)
    Sprites.define("pship_h", 16, 14, function(w, h)
        gfx.fillTriangle(w, h / 2, 0, 3, 0, h - 3)
        gfx.fillTriangle(0, 0, 6, 5, 0, 5)
        gfx.fillTriangle(0, h, 6, h - 5, 0, h - 5)
        gfx.fillRect(2, h / 2 - 1, w - 5, 2)
    end)

    Sprites.define("grunt", 12, 12, function(w, h)
        gfx.fillTriangle(w / 2, h, 0, 2, w, 2)
        gfx.fillRect(w / 2 - 3, 0, 6, 3)
    end)

    Sprites.define("darter", 11, 13, function(w, h)
        gfx.fillTriangle(w / 2, h, 1, 0, w - 1, 0)
    end)

    Sprites.define("gunner", 20, 16, function(w, h)
        gfx.fillTriangle(w / 2, h, 2, 3, w - 2, 3)
        gfx.fillRect(0, 0, w, 5)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(w / 2 - 1, 1, 2, 3)
        gfx.setColor(gfx.kColorWhite)
    end)

    Sprites.define("shot", 3, 9, function(w, h) gfx.fillRect(0, 0, w, h) end)
    Sprites.define("shot_h", 9, 3, function(w, h) gfx.fillRect(0, 0, w, h) end)
    Sprites.define("orb", 6, 6, function(w, h)
        gfx.fillCircleAtPoint(w / 2, h / 2, w / 2)
    end)
    Sprites.define("bomb", 6, 7, function(w, h)
        gfx.fillCircleAtPoint(w / 2, h / 2 + 1, 2)
        gfx.fillRect(w / 2 - 1, 0, 2, 3)
    end)

    -- power-up capsules: a solid disc with a black glyph punched out of it.
    -- Solid enough to read at speed, distinct enough to tell apart in a glance.
    local function capsule(glyph)
        return function(w, h)
            gfx.fillCircleAtPoint(w / 2, h / 2, w / 2)
            gfx.setColor(gfx.kColorBlack)
            glyph(w, h)
            gfx.setColor(gfx.kColorWhite)
        end
    end
    Sprites.define("pow_gun", 14, 14, capsule(function(w, h)
        gfx.fillRect(w / 2 - 1, 5, 2, 5)              -- an up arrow: more gun
        gfx.fillTriangle(w / 2, 3, w / 2 - 4, 7, w / 2 + 4, 7)
    end))
    Sprites.define("pow_shield", 14, 14, capsule(function(w, h)
        gfx.drawCircleAtPoint(w / 2, h / 2, 4)        -- a ring: a shield
        gfx.fillCircleAtPoint(w / 2, h / 2, 2)
    end))
    Sprites.define("pow_life", 14, 14, capsule(function(w, h)
        gfx.fillRect(w / 2 - 1, 4, 2, 6)              -- a cross: an extra ship
        gfx.fillRect(w / 2 - 3, 6, 6, 2)
    end))

    Sprites.boom = {}
    for i = 1, 4 do
        local r = 2 + i * 4
        local sz = r * 2 + 2
        local img = gfx.image.new(sz, sz)
        gfx.pushContext(img)
        gfx.setColor(gfx.kColorWhite)
        gfx.setLineWidth(i < 3 and 3 or 2)
        gfx.drawCircleAtPoint(sz / 2, sz / 2, r)
        if i <= 2 then gfx.fillCircleAtPoint(sz / 2, sz / 2, 2) end
        gfx.popContext()
        Sprites.boom[i] = { img = img, sz = sz }
    end
    gfx.setLineWidth(1)
end

function Sprites.drawBoom(frame, x, y)
    local b = Sprites.boom[frame]
    if b then b.img:draw(x - b.sz // 2, y - b.sz // 2) end
end
