-- Simulation: crank-aimed shots vs descending targets.

Game = {}

-- snip: reset
function Game.reset()
    G.score = 0
    G.newBest = false
    G.shots = {}
    G.targets = {}
    G.spawnT = 0.8
    G.cool = 0
end
-- endsnip

-- snip: aim
-- 1:1 aim: crank angle -> barrel angle, clamped to the sky.
-- getCrankPosition() reads 0 at straight up, so pos 0 aims the
-- barrel straight up and cranking right leans it right.
function Game.aim(pos)
    local a = ((pos + 180) % 360) - 180    -- -180..180, 0 = up
    if a > C.ARC then a = C.ARC end
    if a < -C.ARC then a = -C.ARC end
    G.aim = a - 90                         -- degrees; -90 = up
end
-- endsnip

-- snip: ramp
-- The whole difficulty curve: two numbers that move with score.
local function fallSpeed()
    return C.FALL + C.FALL_RAMP * G.score
end

local function spawnGap()
    return math.max(C.SPAWN_MIN,
        C.SPAWN_T - C.SPAWN_RAMP * G.score)
end
-- endsnip

-- snip: update
function Game.update(dt, inp)
    Game.aim(inp.pos)

    G.cool = math.max(0, G.cool - 1)
    if inp.fire and G.cool == 0 then
        local r = math.rad(G.aim)
        G.shots[#G.shots + 1] = {
            x = C.TX + math.cos(r) * C.BARREL,
            y = C.TY + math.sin(r) * C.BARREL,
            dx = math.cos(r) * C.SHOT_SPEED * dt,
            dy = math.sin(r) * C.SHOT_SPEED * dt,
        }
        G.cool = C.COOLDOWN
        Sfx.fire()
        Harness.count("shots")
    end

    G.spawnT = G.spawnT - dt
    if G.spawnT <= 0 then
        G.spawnT = spawnGap()
        G.targets[#G.targets + 1] = {
            x = math.random(20, C.W - 20),
            y = -C.TSIZE,
            ph = math.random() * 6.28,    -- sway phase
        }
        Harness.count("targets")
    end

    for i = #G.shots, 1, -1 do
        local s = G.shots[i]
        s.x, s.y = s.x + s.dx, s.y + s.dy
        if s.x < -8 or s.x > C.W + 8 or s.y < -8 then
            table.remove(G.shots, i)
        end
    end

    for i = #G.targets, 1, -1 do
        local t = G.targets[i]
        t.y = t.y + fallSpeed() * dt
        t.x = t.x + math.cos(G.t * 2 + t.ph) * C.SWAY * dt
        if Game.shotHits(t) then
            table.remove(G.targets, i)
            G.score = G.score + 1
            Sfx.hit()
            Harness.count("hits")
        elseif t.y + C.TSIZE / 2 > C.GROUND then
            Game.over()
            return
        end
    end
end
-- endsnip

-- snip: hits
function Game.shotHits(t)
    local h = C.TSIZE / 2
    for i = #G.shots, 1, -1 do
        local s = G.shots[i]
        if s.x > t.x - h and s.x < t.x + h
            and s.y > t.y - h and s.y < t.y + h then
            table.remove(G.shots, i)
            return true
        end
    end
    return false
end
-- endsnip

-- snip: over
-- Game over is where the datastore earns its keep: persist the
-- record the moment it is set, not "sometime later".
function Game.over()
    if G.score > G.best then
        G.best = G.score
        G.newBest = true
        Save.store()
        Sfx.best()
    else
        Sfx.lose()
    end
    G.setMode("gameover")
    Harness.count("gameovers")
end
-- endsnip
