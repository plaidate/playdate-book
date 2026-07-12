-- Chapter 25: a guided tour of the Lore RPG engine. Fourteen core
-- modules are vendored verbatim from lore/core/ (MIT); the demo on
-- top is a scripted playthrough -- the engine's own thesis, since a
-- Lore autopilot IS a walkthrough. Lore's harness.lua is NOT
-- vendored: the book's harness (Chapter 18's, in bookharness.lua)
-- defines the same Harness surface Kit.run drives -- enabled,
-- count, set, frame -- so the vendored cabinet runs unmodified.
-- Kit.run also ASSIGNS Harness.extra (and, under the Simulator,
-- Harness.shotPath); the book harness declares neither and reads
-- neither, so both writes are inert.

-- snip: tour-imports
import "CoreLibs/graphics"
import "CoreLibs/crank"
import "shots"
import "bookharness"
-- the vendored engine, in core/lib.lua's dependency order
import "lutil"
import "lgfx"
import "lmap"
import "lcam"
import "lact"
import "lkit"
import "lstate"
import "lui"
import "lscript"
import "lparty"
import "lsnd"
import "lmusic"
import "lturn"
import "laction"
-- the demo
import "config"
import "game"
import "input"
import "draw"
-- endsnip

-- snip: tour-run
Kit.run{
    init = function()
        -- Kit.run seeds from the clock (right for a shipped game);
        -- the figure script wants determinism back
        if Harness.enabled and Shots and Shots.seed then
            math.randomseed(Shots.seed)
        end
        Game.init()
        Kit.push(G.field) -- init MUST push the first state
    end,
    extra = function(t)
        t.stack = #Kit.stack
        t.chunkBuilds = Map.builds
        t.cacheOk = Cache.ok and 1 or 0
    end,
}
-- endsnip
