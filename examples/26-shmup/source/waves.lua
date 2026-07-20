-- vendored from shmup/core/waves.lua (MIT)
-- shmup core: the spawn timeline. A level is an ordered list of entries:
--
--   { t = 5.5,   type = "darter", x = 60, n = 5, dx = 70 }  -- n copies, spaced
--   { t = 40,    boss = "dreadnought" }                     -- arm the boss
--   { at = 1900, boss = "core" }                            -- ...at a PLACE
--
-- `t` is seconds since the level started. `at` is a player x. Both exist
-- because the frame decides which one means anything: in a scroller the world
-- comes to you at a fixed rate, so a time IS a distance and the clock is the
-- only sensible index. In the free frame the world does not move at all -- you
-- can hover, or fly backwards -- so a clock indexes nothing, and the only
-- honest trigger is where the player actually is.
--
-- n copies are spaced by (dx, dy). Vertical games default y to just above the
-- top edge; horizontal games pass an x at the right edge. There is no scripting
-- language here on purpose: a wave is data, and a level you can read in one
-- screenful is a level you can tune.

Waves = {}

function Waves.load(script)
    Waves.script = script or {}
    Waves.i = 1
    Waves.t = 0
    Waves.done = false
    Waves.hasBoss = false
    for _, w in ipairs(Waves.script) do
        -- a MID-boss ({ t=, boss=, mid = true }) gates the road, not
        -- the ending: only a final boss owns the win condition
        if w.boss and not w.mid then Waves.hasBoss = true end
    end
end

-- snip: waves-ready
local function ready(w)
    if w.at then return Player.x >= w.at end
    return (w.t or 0) <= Waves.t
end

function Waves.update(dt)
    if Waves.done then return end
    Waves.t = Waves.t + dt
    local s = Waves.script
    while Waves.i <= #s and ready(s[Waves.i]) do
        local w = s[Waves.i]
        if w.boss then
            Boss.arm(w.boss, w.x, w.y, w.mid)
        else
            local n = w.n or 1
            local dx, dy = w.dx or 0, w.dy or 0
            local bx, by = w.x or (SCREEN_W / 2), w.y or -16
            for k = 0, n - 1 do
                Enemies.spawn(w.type, bx + dx * k, by + dy * k)
            end
        end
        Waves.i = Waves.i + 1
    end
    if Waves.i > #s then Waves.done = true end
end
-- endsnip

-- Exhausted the script and swept the screen. This is NOT the win condition when
-- there is a boss -- see Shmup.won(). A level that declares victory the instant
-- its last scripted grunt drifts off the bottom is a level that ends by
-- accident, and the player reads an accident as a bug.
function Waves.finished()
    return Waves.done and Enemies.count() == 0
end

function Waves.progress()
    local n = #Waves.script
    if n == 0 then return 0 end
    return Lib.clamp((Waves.i - 1) / n, 0, 1)
end
