-- Chapter 16: Enemies, Pathfinding, and Bots. A maze chase:
-- the player bot vacuums pellets via BFS while one ghost
-- chases on hand-rolled BFS and the other on the SDK's A*.
-- Both ghosts draw their current plan on the maze.

import "CoreLibs/graphics"
import "shots"
import "bookharness"
import "maze"
import "path"
import "actors"

local gfx <const> = playdate.graphics

DT = 1 / 30

local frame = 0

local function rebuild()
    Maze.generate()
    Path.buildGraph()
    Actors.reset()
end

rebuild()

local function gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    return {
        newMaze = playdate.buttonJustPressed(playdate.kButtonB),
    }
end

function playdate.update()
    local inp = gather(frame)
    if inp.newMaze then rebuild() end
    Actors.update()
    gfx.clear(gfx.kColorWhite)
    Maze.draw()
    Actors.draw()
end

local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
