-- vendored from shmup/core/fx.lua (MIT)
-- shmup core: juice. Screen shake and hitstop -- the two cheapest ways to make
-- a 1-bit explosion land, and the two most easily overdone.
--
-- Shake is a decaying random offset applied with setDrawOffset, so it moves the
-- whole world at no cost. Hitstop freezes the simulation for a few frames on a
-- big kill: the game stops dead for sixty milliseconds and the player feels the
-- impact in their hands rather than merely seeing it on the screen.

Fx = {}

local gfx <const> = playdate.graphics

function Fx.reset()
    Fx.shakeAmp = 0
    Fx.freezeT = 0
    Fx.dx, Fx.dy = 0, 0
end

function Fx.shake(amp)
    if amp > Fx.shakeAmp then Fx.shakeAmp = amp end
end

function Fx.freeze(t)
    if t > Fx.freezeT then Fx.freezeT = t end
end

-- True if the simulation should skip this frame. The DRAW still runs -- freezing
-- the picture as well as the physics just looks like a dropped frame.
function Fx.frozen() return Fx.freezeT > 0 end

function Fx.update(dt)
    if Fx.freezeT > 0 then Fx.freezeT = Fx.freezeT - dt end

    if Fx.shakeAmp > 0.4 then
        Fx.shakeAmp = Fx.shakeAmp * 0.82
        local a = math.ceil(Fx.shakeAmp)
        Fx.dx = math.random(-a, a)
        Fx.dy = math.random(-a, a)
    else
        Fx.shakeAmp = 0
        Fx.dx, Fx.dy = 0, 0
    end
end

-- Wrap the world draw: push the offset, draw, pop. The HUD is drawn AFTER
-- Fx.pop() so the score does not wobble -- a shaking HUD reads as a rendering
-- bug, while a shaking world reads as an explosion.
function Fx.push()
    if Fx.dx ~= 0 or Fx.dy ~= 0 then gfx.setDrawOffset(Fx.dx, Fx.dy) end
end

function Fx.pop() gfx.setDrawOffset(0, 0) end

Fx.reset()
