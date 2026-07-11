-- The deferred-call queue: the house alternative to
-- playdate.timer.performAfterDelay. Frame-exact, deterministic,
-- and driven by the game loop itself.

Util = {}

-- snip: after
local queue = {}

-- run fn after `frames` frames
function Util.after(frames, fn)
    queue[#queue + 1] = { at = frames, fn = fn }
end

-- call once per update, before game logic
function Util.tick()
    for i = #queue, 1, -1 do
        local q = queue[i]
        q.at = q.at - 1
        if q.at <= 0 then
            table.remove(queue, i)
            q.fn()
        end
    end
end
-- endsnip
