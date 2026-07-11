-- snip: alpha
-- alpha.lua runs in the SAME global environment as every other
-- file in the game. Nothing is returned, nothing is isolated.

AlphaLoads = (AlphaLoads or 0) + 1   -- counts how often this runs
SHARED = "set by alpha.lua"          -- a global: every file sees it

local secret = "only alpha.lua can read this"  -- locals stay private

Alpha = {}                           -- the module-table convention

function Alpha.report()
    return "AlphaLoads = " .. AlphaLoads
end
-- endsnip
