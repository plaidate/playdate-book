-- One input seam for humans and for the tour. Input.mx/my are held
-- axes; Input.a/b/up/down are EDGE-TRIGGERED one-poll flags (the
-- lui window contract); Input.aHeld is the held button laction
-- charges on. In a figure build the tour synthesizes all of them:
-- it starts the playthrough script, then steers every window that
-- opens above the field by reading st.kind/st.sel/st.rows -- the
-- same introspection surface a shipped game's autopilot uses.

Input = {
    frame = 0,
    mx = 0, my = 0,
    a = false, b = false, aHeld = false,
    up = false, down = false, left = false, right = false,
}

local Auto = { step = 0, armed = false }

local function realPoll()
    local pd = playdate
    Input.mx, Input.my = Util.dpad()
    Input.a = pd.buttonJustPressed(pd.kButtonA)
    Input.aHeld = pd.buttonIsPressed(pd.kButtonA)
    Input.b = pd.buttonJustPressed(pd.kButtonB)
    Input.up = pd.buttonJustPressed(pd.kButtonUp)
    Input.down = pd.buttonJustPressed(pd.kButtonDown)
end

local function clearEdges()
    Input.mx, Input.my = 0, 0
    Input.a, Input.b, Input.aHeld = false, false, false
    Input.up, Input.down = false, false
end

-- ---- the window driver --------------------------------------------
-- snip: demo-drive
-- Every window -- dialog, choice, pause menu, item list, AND the
-- battle command window -- answers to the same four flags and
-- exposes the same {kind, sel, rows}. So one driver steers all of
-- them; it presses A on a dialog exactly the way a thumb does.
-- The frame gates are the figure script holding a window open long
-- enough to photograph it.
local gap = 0

local function press(name)
    Input[name] = true
end

-- walk the cursor to row `want`, then confirm; true once confirmed
local function seek(st, want)
    if st.sel < want then
        press("down")
    elseif st.sel > want then
        press("up")
    else
        press("a")
        return true
    end
    return false
end

local function drive(top, f)
    local k = top.kind
    if k == "dialog" then
        if f < C.UI_GO then return false end
        press("a")
    elseif k == "bcmd" or k == "btarget" then
        if f < C.BATTLE_GO then return false end
        press("a") -- row 1 is Fight; one foe needs no target
    elseif k == "choose" then
        if Auto.step ~= 2 then
            if f < C.UI_GO then return false end
            press("a")
        else
            if f < C.CHOOSE_BACK then return false end
            if seek(top, 3) then Auto.step = 3 end -- Back
        end
    elseif k == "menu" then
        if Auto.step == 0 then
            if f < C.MENU_A then return false end
            press("a") -- row 1 is Items
            Auto.step = 1
        else
            press("b")
        end
    elseif k == "list" then
        if Auto.step == 1 then
            if f < C.LIST_A then return false end
            press("a")
            Auto.step = 2
        else
            press("b")
        end
    else
        press("b")
    end
    return true
end

local function uiDrive(top, f)
    gap = gap + 1
    if gap < 6 then return end
    if drive(top, f) then gap = 0 end
end
-- endsnip

-- ---- the field legs: walk, then charge-and-release ----------------

local function fieldAuto(f)
    if f <= C.WALK_END then
        Input.mx = 1 -- east along the road, crossing chunk seams
        return
    end
    if f == C.STORY_F then
        Game.story()
        return
    end
    if f == C.MENU_F then
        press("b") -- B opens the pause menu, exactly as a thumb does
        return
    end
    if f == C.ACTION_F and not Auto.armed then
        Auto.armed = true
        Game.armAndSpawn()
        return
    end
    if f < C.CHARGE_F then return end
    local e = G.foe
    if e then -- close to arc range, then hold A to charge
        local dx = e.x - G.player.x
        if math.abs(dx) > 24 then Input.mx = Util.sign(dx) end
    end
    if f < C.SWING_F then
        Input.aHeld = true -- charging: the ring fills in 0.5 s
    else -- release, recharge, release ... 20-frame cycles
        Input.aHeld = (f - C.SWING_F) % 20 ~= 0
    end
end

function Input.poll()
    Input.frame = Input.frame + 1
    if not Harness.enabled then
        realPoll()
        return
    end
    clearEdges()
    local f = Input.frame
    local top = Kit.top()
    if top and top.ui then
        uiDrive(top, f)
    elseif Turn.active or Script.active then
        -- the battle's timers / the script's coroutine own the beat
    elseif G.player then
        fieldAuto(f)
    end
end
