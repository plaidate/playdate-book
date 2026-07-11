-- Chapter 9: the input layer. A live visualizer: lamps show level
-- state with edge blips, a logic-analyzer trace separates levels
-- from edges, and an auto-runner along the bottom demonstrates
-- jump buffering and coyote time. D-pad and A light lamps; B is
-- the runner's jump button.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "input"
import "game"
import "draw"

local frame = 0
Game.reset()

-- snip: update
function playdate.update()
    local s = Input.gather(frame) -- ONE snapshot per frame
    Game.update(s)
    Runner.update(s)
    Draw.frame(s)
end
-- endsnip

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
