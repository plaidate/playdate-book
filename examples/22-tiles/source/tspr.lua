-- vendored from tiles/core/tspr.lua (MIT)
-- Tiles core: string-art sprites. Actors are small code-drawn images —
-- '.' transparent, '#' black, 'o' white — following the palette rule:
-- white player with black outline, dark enemies with a white eye pixel,
-- so everything reads against dithered floors.

local gfx = playdate.graphics

Spr = {}

-- snip: spr-make
function Spr.make(rows)
    local h = #rows
    local w = #rows[1]
    local img = gfx.image.new(w, h) -- transparent
    gfx.pushContext(img)
    for y = 1, h do
        local row = rows[y]
        for x = 1, w do
            local c = row:sub(x, x)
            if c == "#" then
                gfx.setColor(gfx.kColorBlack)
                gfx.drawPixel(x - 1, y - 1)
            elseif c == "o" then
                gfx.setColor(gfx.kColorWhite)
                gfx.drawPixel(x - 1, y - 1)
            end
        end
    end
    gfx.popContext()
    return img
end
-- endsnip

-- table of name -> rows, returns name -> image
function Spr.makeSet(tbl)
    local set = {}
    for name, rows in pairs(tbl) do
        set[name] = Spr.make(rows)
    end
    return set
end

-- draw centered on (x, y); flip is an optional gfx.kImageFlipped* constant
function Spr.draw(img, x, y, flip)
    img:draw(math.floor(x - img.width / 2 + 0.5),
        math.floor(y - img.height / 2 + 0.5), flip)
end

-- ---- flipbook animation (wave-2) ------------------------------------------
-- an = Spr.anim({imgA, imgB, ...}, fps); Spr.tick(an, dt) advances,
-- Spr.frame(an) is the current image. Walk cycles, torch flicker,
-- boss idles — two lines per animated thing.

function Spr.anim(frames, fps)
    return { frames = frames, fps = fps or 6, t = 0 }
end

function Spr.tick(an, dt)
    an.t = an.t + dt
end

function Spr.frame(an)
    local i = math.floor(an.t * an.fps) % #an.frames + 1
    return an.frames[i]
end
