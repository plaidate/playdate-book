-- One input seam. The shipped games consult Harness.autopilot
-- here; the book demo consults the figure script instead. Either
-- way the game reads Input.state and never sees the difference.

Input = {
    state = { mx = 0, my = 0, act = false },
    frame = 0,
}

-- snip: input-poll
function Input.poll()
    Input.frame = Input.frame + 1
    local s = Input.state
    local bot = Harness.input(Input.frame)
    if bot then
        s.mx, s.my = bot.mx or 0, bot.my or 0
        s.act = bot.act or false
        return
    end
    s.mx, s.my = Util.dpad()
    s.act = playdate.buttonJustPressed(playdate.kButtonA)
end
-- endsnip
