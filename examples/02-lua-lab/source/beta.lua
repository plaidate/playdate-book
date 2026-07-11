-- snip: beta
-- beta.lua imports nothing, yet it sees alpha.lua's global the
-- moment it loads, because import ran alpha.lua's code first.

Beta = {}
Beta.sawAtLoad = SHARED              -- captured while loading

function Beta.report()
    return 'Beta.sawAtLoad = "' .. tostring(Beta.sawAtLoad) .. '"'
end
-- endsnip
