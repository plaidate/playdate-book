-- One input seam. The shipped games consult Harness.autopilot
-- here; the book demo consults the figure script instead. The
-- screens read Input.state and never see the difference.

Input = {
    state = { mx = 0 },
    frame = 0,
}

function Input.poll()
    Input.frame = Input.frame + 1
    local s = Input.state
    local bot = Harness.input(Input.frame)
    if bot then
        s.mx = bot.mx or 0
        return
    end
    s.mx = (playdate.buttonIsPressed(playdate.kButtonRight)
        and 1 or 0)
        - (playdate.buttonIsPressed(playdate.kButtonLeft)
            and 1 or 0)
end
