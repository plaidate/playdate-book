-- Simulation for the play mode: move the paddle, rain blocks,
-- detect the hit that ends the run.

Game = {}

-- snip: reset
-- Runs on every title -> play transition, so each run starts
-- from the same clean slate no matter how the last one ended.
function Game.reset()
    G.score = 0
    G.player.x = C.W / 2
    G.blocks = {}
    G.spawnT = 0
    G.spawned = 0
end
-- endsnip

-- snip: gameupdate
function Game.update(dt, inp)
    local p = G.player
    if inp.left then p.x = p.x - C.PLAYER_SPEED * dt end
    if inp.right then p.x = p.x + C.PLAYER_SPEED * dt end
    local half = C.PLAYER_W / 2
    p.x = math.max(half, math.min(C.W - half, p.x))

    G.spawnT = G.spawnT - dt
    if G.spawnT <= 0 then
        G.spawnT = C.SPAWN_T
        G.spawned = G.spawned + 1
        local x = math.random(C.W - C.BLOCK)
        if G.spawned % C.AIM_EVERY == 0 then
            x = p.x - C.BLOCK / 2    -- this one hunts the player
        end
        G.blocks[#G.blocks + 1] = { x = x, y = -C.BLOCK }
    end

    for i = #G.blocks, 1, -1 do
        local b = G.blocks[i]
        b.y = b.y + C.FALL_SPEED * dt
        if Game.hits(b, p) then
            G.best = math.max(G.best, G.score)
            G.setMode("gameover")
            Harness.count("deaths")
        elseif b.y > C.H then
            table.remove(G.blocks, i)
            G.score = G.score + 1
            Harness.count("dodged")
        end
    end
end
-- endsnip

-- snip: hits
function Game.hits(b, p)
    local half = C.PLAYER_W / 2
    return b.y + C.BLOCK > C.PLAYER_Y
        and b.y < C.PLAYER_Y + C.PLAYER_H
        and b.x + C.BLOCK > p.x - half
        and b.x < p.x + half
end
-- endsnip
