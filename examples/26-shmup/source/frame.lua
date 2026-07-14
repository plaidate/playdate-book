-- vendored from shmup/core/frame.lua (MIT)
-- shmup core: THE SCROLL FRAME — the engine's one big idea.
--
-- A shoot-'em-up is defined by what is nailed down and what moves. Everything
-- else (bullets, pools, collision, waves, score) is the same code in every
-- game of the genre. So the frame owns exactly four questions, and nothing
-- else in core/ is allowed to answer them:
--
--   1. where do frame coordinates land on the screen?   toScreenX / toScreenY
--   2. how does the world advance each frame?           advance
--   3. where is the player allowed to be?               bounds
--   4. which way is forward?                            fireDir
--
-- Three modes cover the genre:
--
--   "vertical"  the world scrolls down past a screen-locked player  (Xevious)
--   "side"      the world scrolls left at a rate you cannot change  (Scramble)
--   "free"      the level is a fixed-width place with two ends and
--               the camera chases the player through it             (Uridium)
--
-- Entities always live in FRAME coordinates. For "vertical" and "side" that is
-- identical to screen coordinates, so the scrollers pay nothing for the
-- abstraction -- the transform is a branch on a local. For "free" it is a
-- subtraction of the camera.

Frame = {}

function Frame.init(cfg)
    cfg = cfg or {}
    Frame.mode = cfg.mode or "vertical"
    Frame.free = Frame.mode == "free"
    Frame.horizontal = Frame.mode == "side" or Frame.free
    Frame.speed = cfg.speed or 0          -- world advance, px/s (side, vertical)
    Frame.levelW = cfg.levelW or SCREEN_W -- level extent (free)
    Frame.top = cfg.top or 10             -- the player's vertical box
    Frame.bottom = cfg.bottom or (SCREEN_H - 10)
    Frame.reset()
end

function Frame.reset()
    Frame.x = 0       -- camera left edge, frame coords (free; always 0 otherwise)
    Frame.scroll = 0  -- how far the world has advanced (side, vertical)
end

-- snip: frame-questions
-- ---- 1. the transform ----
-- In free mode this is all that stands between a world coordinate and a pixel.
-- In the scrollers it is the identity, and the branch predicts.
function Frame.toScreenX(x) return Frame.free and x - Frame.x or x end
function Frame.toScreenY(y) return y end

-- ---- 2. the advance ----
function Frame.advance(dt, px)
    if Frame.free then
        Frame.x = Lib.clamp(px - SCREEN_W / 2, 0,
            math.max(0, Frame.levelW - SCREEN_W))
    else
        Frame.scroll = Frame.scroll + Frame.speed * dt
    end
end

-- ---- 3. the player's box ----
function Frame.bounds()
    if Frame.free then
        return 12, Frame.levelW - 12, Frame.top, Frame.bottom
    end
    return 8, SCREEN_W - 8, Frame.top, Frame.bottom
end
-- endsnip

-- Where the player starts.
function Frame.spawnPoint()
    if Frame.free then return 120, (Frame.top + Frame.bottom) / 2 end
    if Frame.horizontal then return 56, SCREEN_H / 2 end
    return SCREEN_W / 2, SCREEN_H - 30
end

-- Where the player comes BACK. In the scrollers this is the same place --
-- the world has moved on, so there is nowhere else for it to be. In the free
-- frame it emphatically is not: the level is a place, and respawning at the
-- start of it after dying at the far end means flying the whole ship again,
-- past enemies that are already dead, to reach a boss whose health bar is
-- still where you left it. You come back a little short of where you fell.
function Frame.respawnPoint(x, y)
    if not Frame.free then return Frame.spawnPoint() end
    local rx = Lib.clamp(x - 140, 12, Frame.levelW - 12)
    return rx, (Frame.top + Frame.bottom) / 2
end

-- snip: frame-forward
-- ---- 4. forward ----
-- The scrollers have a fixed forward. Free mode does not: the ship turns
-- around, so forward is the player's facing and the sprite flips to match.
function Frame.fireDir(facing)
    if Frame.free then return facing or 1, 0 end
    if Frame.horizontal then return 1, 0 end
    return 0, -1
end

function Frame.flips() return Frame.free end
-- endsnip

-- ...and which way is forward for THEM. A spread pattern fired by an enemy
-- should fan out along the axis the player is coming from, which is the
-- opposite of the player's forward: downward in a vertical game, leftward in a
-- horizontal one. The old Firers.spread hardcoded pi/2, so a spread enemy in a
-- horizontal game dutifully hosed the floor.
function Frame.enemyAngle()
    return Frame.horizontal and math.pi or math.pi / 2
end

--------------------------------------------------------------------------------
-- snip: frame-spentcull
-- Two questions that are easy to conflate, and expensive to conflate.

-- SPENT: this projectile can never matter again. Measured against the visible
-- box, because a bullet exists only to reach something you can see.
function Frame.spent(x, y)
    local m = Lib.KILL_MARGIN
    local sx = Frame.toScreenX(x)
    return sx < -m or sx > SCREEN_W + m or y < -m or y > SCREEN_H + m
end

-- CULL: this enemy should stop existing. In the scrollers, leaving the screen
-- means leaving the game -- the world behind you is gone forever. In free mode
-- the level is a PLACE: its defenders are still standing there when you fly
-- back, so nothing is culled for being off-camera. Cull on camera in free mode
-- and the level quietly empties out behind the player.
function Frame.cull(x, y)
    if Frame.free then return false end
    local m = Lib.KILL_MARGIN
    return x < -m or x > SCREEN_W + m or y < -m or y > SCREEN_H + m
end
-- endsnip

-- worth drawing?
function Frame.visible(x, margin)
    if not Frame.free then return true end
    local sx = x - Frame.x
    margin = margin or 24
    return sx > -margin and sx < SCREEN_W + margin
end

-- How far through the level are we? Free mode measures the camera against the
-- level; the scrollers have no end but the wave script, so they defer to it.
function Frame.progress()
    if Frame.free then
        return Lib.clamp(Frame.x / math.max(1, Frame.levelW - SCREEN_W), 0, 1)
    end
    return Waves.progress()
end
