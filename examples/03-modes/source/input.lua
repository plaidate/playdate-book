-- snip: input
-- Input.gather() is the ONLY place the game touches the hardware.
-- Everything downstream consumes this snapshot table, and the
-- book's capture bot (or a game's autopilot) is consulted first.
Input = {}

local pd <const> = playdate

function Input.gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    return {
        left = pd.buttonIsPressed(pd.kButtonLeft),
        right = pd.buttonIsPressed(pd.kButtonRight),
        confirm = pd.buttonJustPressed(pd.kButtonA),
        pause = pd.buttonJustPressed(pd.kButtonB),
    }
end
-- endsnip
