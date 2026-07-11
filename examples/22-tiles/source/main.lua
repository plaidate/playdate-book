-- Chapter 22: a guided tour of the Tiles core/ engine.
-- Four screens, 120 frames each: the scrolling camera, a live
-- Map.set carve, the BFS distance field, and the sprite/kit
-- showcase. Engine files are vendored verbatim from tiles/core/
-- (MIT). tiles' own harness.lua is NOT vendored: the book's
-- harness (Chapter 18's, in bookharness.lua) defines the same
-- Harness global surface that Kit.run drives — enabled, count,
-- set, and frame — so the vendored loop runs unmodified.

-- snip: tour-imports
import "CoreLibs/graphics"
import "shots"
import "bookharness"
-- the vendored engine, in core/lib.lua's dependency order
import "tutil"
import "tmap"
import "tspr"
import "tphys"
import "tkit"
import "tcam"
import "tsnd"
-- the demo
import "config"
import "game"
import "input"
import "draw"
-- endsnip

-- snip: tour-run
Kit.run{
    init = function()
        -- Kit.run seeds from the clock (right for a shipped
        -- game); the figure script wants determinism back
        if Harness.enabled and Shots and Shots.seed then
            math.randomseed(Shots.seed)
        end
        Game.init()
    end,
}
-- endsnip
