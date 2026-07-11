-- Progress persistence: the "progress" datastore, with schema
-- versioning and step-by-step migration. Molt's nil-coalescing
-- load pattern, plus a version field.

Save = {}

Save.data = nil     -- nil until Save.load() runs

-- snip: load
function Save.load()
    local d = playdate.datastore.read("progress") or {}
    d.version = d.version or 1     -- pre-versioning saves = v1
    Save.migrate(d)
    -- nil-coalescing defaults: every field the game reads gets
    -- a fallback, so an empty table is a valid save
    d.high = d.high or { score = 0, name = "???" }
    d.plays = d.plays or 0
    Save.data = d
    Save.store()                   -- persist the migrated form
end
-- endsnip

-- snip: migrate
-- One `if` per version bump, applied in order, so a v1 save
-- walks 1 -> 2 (-> 3 -> ...) no matter how old it is.
function Save.migrate(d)
    if d.version == 1 then
        -- v1 kept a bare hi/name pair at the top level
        d.high = { score = d.hi or 0, name = d.name or "???" }
        d.hi, d.name = nil, nil
        d.version = 2
    end
    -- when v3 arrives: if d.version == 2 then ... end
end
-- endsnip

-- snip: store
function Save.store()
    -- pretty-print so the datastore file is diffable and the
    -- inspector screen has something readable to show
    playdate.datastore.write(Save.data, "progress", true)
    Harness.count("saves")
end
-- endsnip
