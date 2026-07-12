-- Chapter 24: a guided tour of the Dither core/ engine. Four
-- screens, 120 frames each: the 17-level ramp chart, the 3-band
-- light compositor with live Light.at probes, the Super Scaler
-- pond, and the Bayer transitions. Engine files are vendored
-- verbatim from dither/core/ (MIT). dither's own harness.lua is
-- NOT vendored: the book's harness (Chapter 18's, in
-- bookharness.lua) defines the same Harness global surface that
-- Kit.run drives -- enabled, count, set, and frame -- so the
-- vendored cabinet runs unmodified.

-- snip: tour-imports
import "CoreLibs/graphics"
import "shots"
import "bookharness"
-- the vendored engine, in core/lib.lua's dependency order
import "cutil"
import "shade"
import "light"
import "cast"
import "fade"
import "para"
import "scaler"
import "kit"
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
