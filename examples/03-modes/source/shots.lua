-- Figure script: drive the whole mode loop in one deterministic
-- run. The bot starts the game, dodges for the play shot, pauses
-- and resumes, then steers INTO a block so the run ends at a
-- known point, and finally confirms its way back to the title.
Shots = {
    seed = 7,
    last = 390,
    shots = {
        ["modes-title"] = 30,
        ["modes-play"] = 150,
        ["modes-pause"] = 200,
        ["modes-gameover"] = 330,
        ["modes-title-again"] = 380,
    },
    script = function(frame)
        local b = {}
        if frame == 60 then b.confirm = true end
        if frame == 180 or frame == 220 then b.pause = true end
        if G.mode == "play" then
            if frame < 180 then
                Shots.dodge(b)
            elseif frame > 220 then
                Shots.seek(b)
            end
        elseif G.mode == "gameover" then
            b.confirm = frame > 335 and frame % 5 == 0
        end
        return b
    end,
}

-- Sidestep the lowest block that threatens the paddle.
function Shots.dodge(b)
    local px, danger = G.player.x, nil
    for _, bl in ipairs(G.blocks) do
        if bl.y > 90 and bl.y < C.PLAYER_Y
            and math.abs(bl.x + C.BLOCK / 2 - px) < 44 then
            if not danger or bl.y > danger.y then danger = bl end
        end
    end
    if not danger then return end
    local goRight = danger.x + C.BLOCK / 2 < px
    if px < 50 then goRight = true end
    if px > C.W - 50 then goRight = false end
    b.right = goRight
    b.left = not goRight
end

-- Chase the lowest block still above the paddle, to end the run.
function Shots.seek(b)
    local bestY, bx = nil, nil
    for _, bl in ipairs(G.blocks) do
        if bl.y < C.PLAYER_Y and (not bestY or bl.y > bestY) then
            bestY, bx = bl.y, bl.x + C.BLOCK / 2
        end
    end
    if not bx then return end
    b.left = bx < G.player.x - 2
    b.right = bx > G.player.x + 2
end
