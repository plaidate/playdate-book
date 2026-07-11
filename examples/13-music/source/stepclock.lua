-- Chapter 13, engine two: the house step clock. Accumulate elapsed
-- time; fire every step boundary the clock has crossed. It cannot
-- drift, because the step number is a pure function of total
-- elapsed time -- there is nothing to drift against.

StepClock = { playing = false, t = 0, lastStep = -1 }

local snd = playdate.sound

local stepDur = 1 / Song.stepsPerSecond()
local bass, lead, hat

function StepClock.build(channel)
    local function patch(wave, a, d, s, r)
        local sy = snd.synth.new(wave)
        sy:setADSR(a, d, s, r)
        channel:addSource(sy)
        return sy
    end
    bass = patch(snd.kWaveTriangle, .002, .06, .6, .10)
    lead = patch(snd.kWaveSquare, .002, .05, .5, .08)
    hat = patch(snd.kWaveNoise, .001, .03, .1, .03)
end

-- snip: clock-trigger
local function trigger(s)   -- s is a song step, 1..Song.steps
    local b = Song.bass[s]
    if b ~= 0 then
        bass:playNote(Song.midihz(b), 0.5, stepDur * 1.8)
    end
    local l = Song.lead[s]
    if l ~= 0 then
        lead:playNote(Song.midihz(l), 0.28, stepDur * 1.6)
    end
    local h = Song.hat[s]
    if h ~= 0 then
        hat:playNote(Song.midihz(h), 0.25, stepDur * 0.5)
    end
    if s % 16 == 1 then Harness.count("clockBars") end
end
-- endsnip

-- snip: clock-loop
function StepClock.start()
    StepClock.t = 0
    StepClock.lastStep = -1
    StepClock.playing = true
end

function StepClock.stop()
    StepClock.playing = false
end

function StepClock.update(dt)
    if not StepClock.playing then return end
    StepClock.t = StepClock.t + dt
    local step = math.floor(StepClock.t / stepDur)
    while StepClock.lastStep < step do
        StepClock.lastStep = StepClock.lastStep + 1
        trigger(StepClock.lastStep % Song.steps + 1)
    end
end
-- endsnip

function StepClock.step()
    if StepClock.lastStep < 0 then return 1 end
    return StepClock.lastStep % Song.steps + 1
end

function StepClock.seek(s)
    StepClock.lastStep = s - 1
    StepClock.t = (s - 1) * stepDur
end
