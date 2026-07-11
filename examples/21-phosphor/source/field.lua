-- vendored from phosphor/vec/field.lua (MIT)
-- Phosphor core: the playfield — screen wrapping and wrap-aware distance.

Field = {
    W = 400,
    H = 240,
}

-- snip: field-wrap
function Field.wrap(x, y)
    if x < 0 then x = x + Field.W elseif x >= Field.W then x = x - Field.W end
    if y < 0 then y = y + Field.H elseif y >= Field.H then y = y - Field.H end
    return x, y
end
-- endsnip

-- snip: field-dist
-- shortest wrapped distance squared
function Field.dist2(ax, ay, bx, by)
    local dx = math.abs(ax - bx)
    local dy = math.abs(ay - by)
    if dx > Field.W / 2 then dx = Field.W - dx end
    if dy > Field.H / 2 then dy = Field.H - dy end
    return dx * dx + dy * dy
end
-- endsnip

-- snip: field-offsets
-- call fn(ox, oy, ...) for every wrap offset under which an object of
-- radius r at (x, y) could be visible; fn is called at least once with
-- (0, 0). Extra arguments are passed through to fn so callers can use a
-- top-level function instead of building a closure — this runs in the
-- draw path of every wrapped game, so it allocates nothing.
function Field.offsets(x, y, r, fn, a, b, c, d, e)
    local oxp = (x < r) and Field.W or nil
    local oxn = (x > Field.W - r) and -Field.W or nil
    local oyp = (y < r) and Field.H or nil
    local oyn = (y > Field.H - r) and -Field.H or nil
    fn(0, 0, a, b, c, d, e)
    if oxp then fn(oxp, 0, a, b, c, d, e) end
    if oxn then fn(oxn, 0, a, b, c, d, e) end
    if oyp then
        fn(0, oyp, a, b, c, d, e)
        if oxp then fn(oxp, oyp, a, b, c, d, e) end
        if oxn then fn(oxn, oyp, a, b, c, d, e) end
    end
    if oyn then
        fn(0, oyn, a, b, c, d, e)
        if oxp then fn(oxp, oyn, a, b, c, d, e) end
        if oxn then fn(oxn, oyn, a, b, c, d, e) end
    end
end
-- endsnip

-- compatibility aliases (pre-library games used Util.*)
Util = Util or {}
Util.wrap = Field.wrap
Util.dist2 = Field.dist2
