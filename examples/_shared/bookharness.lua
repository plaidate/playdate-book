-- The book's test-and-figure harness, adapted from the 47-line smoke harness
-- used across the plaidate games (see Chapter 18). The staging Makefile
-- (example.mk) generates bookflag.lua defining SMOKE_BUILD and SHOT_PREFIX;
-- in release builds SMOKE_BUILD is false and everything here is a no-op.
--
-- Each example's shots.lua defines a global `Shots` table:
--   Shots = {
--       seed  = 1,                        -- math.randomseed for determinism
--       last  = 240,                      -- run this many frames, then report done
--       shots = { title = 20, ... },      -- figure-name -> frame to capture
--       script = function(frame) ... end, -- synthetic input for this frame
--   }

import "bookflag"

Harness = {
    enabled = SMOKE_BUILD,
    counters = {},
    errWritten = false,
}

local lastNeeded = 0

if Harness.enabled and Shots then
    if Shots.seed then math.randomseed(Shots.seed) end
    lastNeeded = Shots.last or 0
    if Shots.shots then
        for _, f in pairs(Shots.shots) do
            if f > lastNeeded then lastNeeded = f end
        end
    end
end

function Harness.count(key, n)
    if not Harness.enabled then return end
    Harness.counters[key] = (Harness.counters[key] or 0) + (n or 1)
end

function Harness.set(key, val)
    if not Harness.enabled then return end
    Harness.counters[key] = val
end

-- Synthetic input for this frame, or nil when a human is playing.
-- Examples consult this at the top of their input gathering, exactly like
-- the autopilot seam in the shipped games.
function Harness.input(frame)
    if not Harness.enabled or not Shots or not Shots.script then return nil end
    return Shots.script(frame)
end

local function heartbeat(frame, done)
    local t = {}
    for k, v in pairs(Harness.counters) do t[k] = v end
    t.frame = frame
    t.done = done or nil
    playdate.datastore.write(t, "smoke")
end

function Harness.frame(frame, updateFn)
    if not Harness.enabled then
        updateFn()
        return
    end
    if frame == 1 then
        playdate.display.setRefreshRate(0) -- unthrottled; runs are frame-indexed
    end
    local ok, err = pcall(updateFn)
    if not ok and not Harness.errWritten then
        Harness.errWritten = true -- keep the FIRST error; later frames repeat symptoms
        playdate.datastore.write({ err = tostring(err) }, "err")
    end
    -- Capture after the frame has drawn, so the shot shows this frame's output.
    if Shots and Shots.shots and playdate.simulator then
        for name, f in pairs(Shots.shots) do
            if f == frame then
                playdate.simulator.writeToFile(playdate.graphics.getDisplayImage(),
                    SHOT_PREFIX .. name .. ".png")
            end
        end
    end
    if frame >= lastNeeded then
        if not Harness.doneWritten then
            Harness.doneWritten = true
            heartbeat(frame, true)
        end
    elseif frame % 90 == 0 then
        heartbeat(frame, false)
    end
end
