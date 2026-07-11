-- Chapter 13, engine one: the SDK sequencer. Notes are loaded into
-- tracks up front; the audio engine advances them off the update
-- loop, in the sound thread's own time.

SeqEngine = {}

local snd = playdate.sound

local function patch(wave, a, d, s, r, vol)
    local sy = snd.synth.new(wave)
    sy:setADSR(a, d, s, r)
    sy:setVolume(vol)
    return sy
end

-- snip: seq-build
function SeqEngine.build(channel)
    local seq = snd.sequence.new()
    seq:setTempo(Song.stepsPerSecond())  -- steps/sec, NOT bpm
    local function addTrack(notes, synth, vel, len)
        local track = snd.track.new()
        local inst = snd.instrument.new(synth)
        channel:addSource(inst)
        track:setInstrument(inst)
        for s = 1, Song.steps do
            if notes[s] ~= 0 then
                track:addNote(s, notes[s], len, vel)
            end
        end
        seq:addTrack(track)
    end
    addTrack(Song.bass,
        patch(snd.kWaveTriangle, .002, .06, .6, .10, .50), 1, 2)
    addTrack(Song.lead,
        patch(snd.kWaveSquare, .002, .05, .5, .08, .28), 1, 2)
    addTrack(Song.hat,
        patch(snd.kWaveNoise, .001, .03, .1, .03, .50), 0.5, 1)
    seq:setLoops(1, Song.steps, 0)   -- loopCount 0 = forever
    SeqEngine.seq = seq
end
-- endsnip

-- snip: seq-run
function SeqEngine.start()
    SeqEngine.seq:play()
end

function SeqEngine.stop()
    SeqEngine.seq:stop()
    SeqEngine.seq:allNotesOff()
end

-- Current step, wrapped into the loop: always 1..Song.steps.
function SeqEngine.step()
    local s = math.floor(SeqEngine.seq:getCurrentStep())
    return (s - 1) % Song.steps + 1
end

function SeqEngine.seek(s)
    SeqEngine.seq:goToStep(s)
end
-- endsnip
