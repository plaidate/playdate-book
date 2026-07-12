-- vendored from dither/core/cutil.lua (MIT)
-- Dither core: clamp and the delayed-call scheduler shared by every game.

Util = {}

function Util.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local pending = {}

function Util.after(delay, fn)
    pending[#pending + 1] = { t = delay, fn = fn }
end

function Util.runPending(dt)
    for i = #pending, 1, -1 do
        local p = pending[i]
        p.t = p.t - dt
        if p.t <= 0 then
            table.remove(pending, i)
            p.fn()
        end
    end
end
