-- Draw: lamps (level state + edge blips), the logic-analyzer trace
-- (level bars vs edge ticks), the caption line, and the runner strip.

Draw = {}

local gfx <const> = playdate.graphics

-- lamp geometry: d-pad cross plus B/A, mirroring the device
local LAMPS <const> = {
    up    = { x = 52, y = 46, r = 13, sq = true },
    down  = { x = 52, y = 110, r = 13, sq = true },
    left  = { x = 20, y = 78, r = 13, sq = true },
    right = { x = 84, y = 78, r = 13, sq = true },
    b     = { x = 118, y = 112, r = 12 },
    a     = { x = 148, y = 96, r = 12 },
}

local TRACE_X <const> = 178 -- left edge of the trace strip
local TRACE_W <const> = 220 -- Game.HISTORY * 2 px
local ROW_H <const> = 21

local function lampShape(l, filled)
    if l.sq then
        local draw = filled and gfx.fillRect or gfx.drawRect
        draw(l.x, l.y, l.r * 2, l.r * 2)
    else
        local draw = filled and gfx.fillCircleAtPoint
            or gfx.drawCircleAtPoint
        draw(l.x + l.r, l.y + l.r, l.r)
    end
end

local function lamps(s)
    for name, l in pairs(LAMPS) do
        lampShape(l, s[name])
        if s[name] then -- knockout label on a lit lamp
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawTextAligned(string.upper(string.sub(name, 1, 1)),
            l.x + l.r, l.y + l.r - 8, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        local blip = Game.blips[name]
        if blip then -- press edge: an expanding ring, 8 frames
            gfx.setLineWidth(2)
            gfx.drawCircleAtPoint(l.x + l.r, l.y + l.r,
                l.r + 4 + blip * 2)
            gfx.setLineWidth(1)
        end
    end
end

-- snip: trace
-- The trace: one column per remembered frame, newest at the right.
-- A short bar means "level high" (buttonIsPressed would be true);
-- a full-height tick marks the press edge; a half tick the release.
local function traceRow(row, name, y)
    gfx.drawText(string.upper(string.sub(name, 1, 1)),
        TRACE_X - 16, y + 2)
    for i = 0, Game.HISTORY - 1 do
        local slot = (Game.head - i - 1) % Game.HISTORY + 1
        local s = Game.trace[slot]
        if not s then break end
        local x = TRACE_X + TRACE_W - 2 - i * 2
        if s[name] then
            gfx.fillRect(x, y + ROW_H - 8, 2, 6) -- level bar
        end
        if s[name .. "Just"] then
            gfx.fillRect(x, y + 1, 2, ROW_H - 3) -- press tick
        elseif s[name .. "Released"] then
            gfx.fillRect(x, y + 1, 2, 8)         -- release tick
        end
    end
end
-- endsnip

local function trace()
    gfx.drawRect(TRACE_X - 2, 22, TRACE_W + 4,
        ROW_H * #Game.order + 4)
    for row, name in ipairs(Game.order) do
        traceRow(row, name, 24 + (row - 1) * ROW_H)
    end
end

local function runnerStrip()
    local F = Runner.FLOOR
    gfx.drawLine(0, F, Runner.GAP_L, F)
    gfx.drawLine(Runner.GAP_R, F, 400, F)
    -- the pit
    gfx.drawLine(Runner.GAP_L, F, Runner.GAP_L, 238)
    gfx.drawLine(Runner.GAP_R, F, Runner.GAP_R, 238)
    gfx.fillRect(Runner.x, Runner.y - 12, 12, 12)
    gfx.drawText("B jumps - buffer " .. Runner.bufferT ..
        "  coyote " .. Runner.coyoteT, 8, 226)
    if Runner.labelT > 0 then
        gfx.drawTextAligned("*" .. string.upper(Runner.label) .. "!*",
            300, 226, kTextAlignment.center)
    end
end

function Draw.frame(s)
    gfx.clear(gfx.kColorWhite)
    gfx.drawText("*THE INPUT LAYER*", 8, 2)
    gfx.drawText("bar=level tall=press short=rel.",
        TRACE_X - 16, 2)
    lamps(s)
    trace()
    gfx.drawText(Game.caption(), 8, 154)
    gfx.drawLine(0, 170, 400, 170)
    runnerStrip()
end
