-- Chapter 23: a guided tour of the Voxel core/ engine.
-- Four screens, 120 frames each: terrain authoring plus a carve
-- crater with debris, the occlusion ghost behind twin pillars,
-- a solved artillery arc with a traced trajectory, and actor
-- physics climbing terraces and falling off a cliff. Engine
-- files are vendored verbatim from voxel/core/ (MIT). voxel's
-- own harness.lua is NOT vendored: the book's harness (Chapter
-- 18's, in bookharness.lua) defines the same Harness global
-- surface that Kit.run drives — enabled, count, set, and frame
-- — so the vendored loop runs unmodified.

-- snip: tour-imports
import "CoreLibs/graphics"
import "shots"
import "bookharness"
-- the vendored engine, in core/lib.lua's dependency order
import "cutil"
import "vox"
import "voxmodel"
import "voxphys"
import "voxproj"
import "kit"
import "vsnd"
import "vmusic"
-- the demo
import "config"
import "game"
import "input"
import "draw"
-- endsnip

-- snip: tour-run
Kit.run({
    init = function()
        -- Kit.run seeds from the clock (right for a shipped
        -- game); the figure script wants determinism back
        if Harness.enabled and Shots and Shots.seed then
            math.randomseed(Shots.seed)
        end
        Game.init()
    end,
    extra = function(t)
        t.screen = Game.scr
    end,
})
-- endsnip
