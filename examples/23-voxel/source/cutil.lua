-- vendored from voxel/core/cutil.lua (MIT)
-- Voxel core: clamp and the delayed-call scheduler shared by every game.

Util = {}

function Util.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local pending = {}

function Util.after(delay, fn)
    pending[#pending + 1] = { t = delay, fn = fn }
end

-- clears in place (not pending = {}) so a clear from INSIDE a runPending
-- callback empties the same table the loop is walking instead of leaving
-- the loop reading a stale one
function Util.clearPending()
    for i = #pending, 1, -1 do pending[i] = nil end
end

function Util.runPending(dt)
    for i = #pending, 1, -1 do
        local p = pending[i]
        if p then -- a callback may have cleared the list mid-walk
            p.t = p.t - dt
            if p.t <= 0 then
                table.remove(pending, i)
                p.fn()
            end
        end
    end
end
