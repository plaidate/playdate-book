-- snip: save
-- The whole persistence layer (Chapter 17): one record.
Save = {}

function Save.load()
    local d = playdate.datastore.read("save") or {}
    G.best = d.best or 0
end

function Save.store()
    playdate.datastore.write({ best = G.best }, "save")
    Harness.count("saves")
end
-- endsnip
