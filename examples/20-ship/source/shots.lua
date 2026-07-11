-- Figure script: play a real run. The bot aims the crank at the
-- lowest target and fires when lined up; at frame 260 it
-- holsters the turret and lets a target land, because the
-- game-over screen has to earn its shot too.
Shots = {
    seed = 20,
    last = 430,
    shots = {
        ["crankshot-title"] = 30,
        ["crankshot-play"] = 200,
        ["crankshot-over"] = 420,
    },
    script = function(frame)
        local b = { pos = 0 }
        if frame == 40 then b.confirm = true end
        if G.mode == "play" then
            Shots.gunner(b, frame)
        end
        return b
    end,
}

-- Aim at the lowest live target, leading its sway and fall by
-- the bullet's travel time; fire once the barrel agrees.
function Shots.gunner(b, frame)
    local best = nil
    for _, t in ipairs(G.targets) do
        if not best or t.y > best.y then best = t end
    end
    if not best then return end
    local dx, dy = best.x - C.TX, best.y - C.TY
    local tt = math.sqrt(dx * dx + dy * dy) / C.SHOT_SPEED
    local fall = C.FALL + C.FALL_RAMP * G.score
    local px = best.x
        + math.cos((G.t + tt) * 2 + best.ph) * C.SWAY * tt
    local py = best.y + fall * tt
    local want = math.deg(math.atan(py - C.TY,
        px - C.TX))                -- -180..180, -90 = up
    b.pos = want + 90              -- crank degrees, 0 = up
    if frame < 260 then
        b.fire = math.abs(want - G.aim) < 5
    end
end
