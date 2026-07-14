-- vendored from shmup/core/snd.lua (MIT)
-- shmup core: synth SFX. No audio files -- one playdate.sound.synth per wave
-- shape covers the whole game, and a small round-robin pool per wave lets
-- effects overlap instead of cutting each other off. (A shmup fires a LOT of
-- bullets. A single shared synth turns rapid fire into one long stutter, as
-- each shot steals the voice from the one before it.)

Snd = {}

local snd <const> = playdate.sound

local WAVES <const> = {
    square = snd.kWaveSquare,
    tri    = snd.kWaveTriangle,
    saw    = snd.kWaveSawtooth,
    noise  = snd.kWaveNoise,
}

local POOL <const> = 3
local pools, idx = {}, {}

local function voice(wave)
    local p = pools[wave]
    if not p then
        p = {}
        for i = 1, POOL do p[i] = snd.synth.new(WAVES[wave]) end
        pools[wave], idx[wave] = p, 0
    end
    idx[wave] = idx[wave] % POOL + 1
    return p[idx[wave]]
end

local function play(wave, freq, dur, vol)
    voice(wave):playNote(freq, vol or 0.2, dur or 0.08)
end

-- A falling sweep, for explosions. Two notes from two voices in the round-robin
-- and the ear fills in the middle.
local function sweep(wave, f0, f1, dur, vol)
    voice(wave):playNote(f0, vol or 0.25, dur)
    voice(wave):playNote(f1, (vol or 0.25) * 0.6, dur * 0.7)
end

function Snd.shoot() play("square", 880, 0.045, 0.10) end
function Snd.hit() play("square", 300, 0.05, 0.13) end
function Snd.bomb() play("tri", 180, 0.10, 0.15) end
function Snd.boom() sweep("noise", 420, 90, 0.22, 0.28) end
function Snd.die() sweep("saw", 400, 60, 0.5, 0.33) end
function Snd.bossDie() sweep("noise", 500, 40, 0.9, 0.38) end
function Snd.extend() play("tri", 1320, 0.12, 0.28) end

function Snd.powerup()
    play("tri", 660, 0.07, 0.26)
    play("tri", 990, 0.09, 0.26)
end

function Snd.alarm()
    play("square", 494, 0.14, 0.28)
    play("square", 370, 0.16, 0.28)
end
