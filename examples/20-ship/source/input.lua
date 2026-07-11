-- snip: input
-- One snapshot per frame. `pos` is the absolute crank position
-- in degrees; the bot supplies its own, which is all it takes
-- to automate a crank game.
Input = {}

local pd <const> = playdate

function Input.gather(frame)
    local bot = Harness.input(frame)
    if bot then return bot end
    return {
        pos = pd.getCrankPosition(),
        fire = pd.buttonIsPressed(pd.kButtonA),
        confirm = pd.buttonJustPressed(pd.kButtonA),
    }
end
-- endsnip
