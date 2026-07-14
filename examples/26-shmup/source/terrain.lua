-- vendored from shmup/core/terrain.lua (MIT)
-- shmup core: a scrolling cavern for "side" games (Scramble-style). Ground and
-- ceiling are white silhouettes; the ship flies the black gap between them.
--
-- THE ONE RULE: there is a single sampled profile, and the renderer and the
-- collider both read it. The old code drew a polygon sampled every 16px (a
-- chain of chords) and collided against the exact continuous sine that
-- generated it -- two different curves. Between samples the true curve bows
-- away from the chord, so the wall you SEE was not the wall you HIT: near a
-- crest the ship died in visibly empty black, in a trough it flew through
-- white. The error was under a pixel, which is exactly why it was poison --
-- invisible in a screenshot, absent from every counter, and felt by the player
-- as an unfair death they cannot explain and you cannot reproduce.
--
-- Now: sample() fills two arrays, draw() fills the polygons from them, and
-- hits() linearly interpolates WITHIN them. Coarsen STEP and both halves
-- coarsen together. They cannot disagree -- there is no second source of truth
-- for them to disagree about.

import "CoreLibs/graphics"
local gfx <const> = playdate.graphics

Terrain = { active = false }

local STEP <const> = 8
local N <const> = SCREEN_W // STEP + 1  -- 51 samples at x = 0, 8, ... 400

local gy, cy = {}, {}       -- the profile: ground top, ceiling bottom
local gpoly, cpoly = {}, {} -- flat {x1,y1,x2,y2,...} draw buffers, reused
local gBase, gAmp, cBase, cAmp

-- The generator. Called ONLY by sample(). Nothing else may evaluate it, or we
-- are back to two sources of truth.
local function genGround(wx)
    return gBase - gAmp * (0.6 * math.sin(wx * 0.020)
        + 0.4 * math.sin(wx * 0.052 + 1.3))
end

local function genCeil(wx)
    return cBase + cAmp * (0.6 * math.sin(wx * 0.017 + 2.0)
        + 0.4 * math.sin(wx * 0.061))
end

function Terrain.init(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    gBase = cfg.groundBase or (SCREEN_H - 32)
    gAmp = cfg.groundAmp or 22
    cBase = cfg.ceilBase or 26
    cAmp = cfg.ceilAmp or 16
    Terrain.active = true
    Terrain.sample()
end

-- snip: terrain-sample
-- Rebuild the profile for the frame's current scroll: 51 samples, once a frame.
function Terrain.sample()
    local scroll = Frame.scroll
    for i = 1, N do
        local wx = scroll + (i - 1) * STEP
        gy[i] = genGround(wx)
        cy[i] = genCeil(wx)
    end
end
-- endsnip

function Terrain.reset() Terrain.sample() end
function Terrain.update(dt) Terrain.sample() end
function Terrain.speed() return Frame.speed end

-- snip: terrain-read
-- Read the profile the way the renderer draws it: lerp between samples.
local function lerpAt(prof, sx)
    local t = sx / STEP
    local i = math.floor(t) + 1
    if i < 1 then return prof[1] elseif i >= N then return prof[N] end
    return Lib.lerp(prof[i], prof[i + 1], t - (i - 1))
end

function Terrain.groundY(sx) return lerpAt(gy, sx) end
function Terrain.ceilY(sx) return lerpAt(cy, sx) end

function Terrain.hits(x, y, r)
    return (y + r >= lerpAt(gy, x)) or (y - r <= lerpAt(cy, x))
end
-- endsnip

-- The draw buffers are preallocated and refilled in place: two 106-element
-- tables per frame was a steady drip of garbage for no reason at all.
function Terrain.draw()
    gfx.setColor(gfx.kColorWhite)

    local k = 0
    for i = 1, N do
        gpoly[k + 1] = (i - 1) * STEP
        gpoly[k + 2] = gy[i]
        k = k + 2
    end
    gpoly[k + 1] = SCREEN_W; gpoly[k + 2] = SCREEN_H
    gpoly[k + 3] = 0;        gpoly[k + 4] = SCREEN_H
    gfx.fillPolygon(table.unpack(gpoly, 1, k + 4))

    k = 0
    for i = 1, N do
        cpoly[k + 1] = (i - 1) * STEP
        cpoly[k + 2] = cy[i]
        k = k + 2
    end
    cpoly[k + 1] = SCREEN_W; cpoly[k + 2] = 0
    cpoly[k + 3] = 0;        cpoly[k + 4] = 0
    gfx.fillPolygon(table.unpack(cpoly, 1, k + 4))
end
