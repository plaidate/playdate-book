-- vendored from shmup/core/kit.lua (MIT)
-- shmup core: the cabinet — white HUD text on black, panels, and best-score
-- persistence. Same shapes as tiles/voxel/dither/lore's Kit, so a reader who
-- knows one engine's furniture knows this one's.

local gfx <const> = playdate.graphics

Kit = {}

function Kit.text(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Kit.centered(t, y)
    local w = gfx.getTextSize(t)
    Kit.text(t, (SCREEN_W - w) // 2, y)
end

-- A black plate with a white border. Everything in this engine is drawn on
-- black EXCEPT over the terrain, which is solid white -- and white HUD text on
-- a white cavern wall is invisible. The plate is not decoration; it is the
-- guarantee that the score can always be read.
function Kit.panel(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, h)
end

-- ---- the arcade score table (wave 2) ---------------------------------------
-- Top 5 with three-letter initials, persisted to "scores" ({v=1,
-- rows}). Kit.best mirrors rank 1 so v1.0 callers keep working; a
-- legacy "best" file seeds the table once. saveBest still exists and
-- now just answers "did that place?" (submission is explicit: the
-- OVER/WIN flow calls Kit.submit + the initials entry).

Kit.best = 0

local N <const> = 5
local rows = nil

local function loadRows()
    if rows then return end
    local env = playdate.datastore.read("scores")
    if env and env.v == 1 then
        rows = env.rows
    else
        rows = {}
        local old = playdate.datastore.read("best")
        if old and old.best and old.best > 0 then
            rows[1] = { ini = "OLD", score = old.best }
        end
    end
    for i = #rows + 1, N do rows[i] = { ini = "---", score = 0 } end
    Kit.best = rows[1].score
end

local function saveRows()
    playdate.datastore.write({ v = 1, rows = rows }, "scores")
    Kit.best = rows[1].score
end

function Kit.loadBest()
    loadRows()
    return Kit.best
end

function Kit.saveBest(score)
    loadRows()
    return score > 0 and score > Kit.best
end

function Kit.scores()
    loadRows()
    return rows
end

-- place a score; returns its rank (1..5) or nil
function Kit.submit(score)
    loadRows()
    for r = 1, N do
        if score > rows[r].score then
            table.insert(rows, r, { ini = "???", score = score })
            rows[N + 1] = nil
            Harness.count("hiscores")
            saveRows()
            return r
        end
    end
    return nil
end

function Kit.setInitials(rank, ini)
    loadRows()
    if rows[rank] then
        rows[rank].ini = ini
        saveRows()
    end
end

function Kit.drawScores(y, hilite)
    loadRows()
    Kit.centered("HIGH SCORES", y)
    for r = 1, N do
        local row = rows[r]
        local line = string.format("%s%d. %s  %06d%s",
            r == hilite and "*> " or "", r, row.ini, row.score,
            r == hilite and " <*" or "")
        Kit.centered(line, y + 6 + r * 17)
    end
end

-- ---- initials entry (crank or d-pad; A sets each letter) -------------------

local ALPHA <const> = "ABCDEFGHIJKLMNOPQRSTUVWXYZ.!0123456789"

local Entry = {}
Entry.__index = Entry

function Kit.entry(score, rank)
    return setmetatable({
        score = score, rank = rank,
        slot = 1, idx = { 1, 1, 1 }, done = false, t = 0,
    }, Entry)
end

-- dxE: -1/0/1 slot-move edge; dyD: letter scroll (edges + crank
-- ticks); confirm: fire/start edge
function Entry:update(dt, dxE, dyD, confirm)
    if self.done then return end
    self.t = self.t + dt
    if dxE ~= 0 then
        self.slot = Lib.clamp(self.slot + dxE, 1, 3)
    end
    if dyD ~= 0 then
        local i = self.idx[self.slot] - dyD
        self.idx[self.slot] = (i - 1) % #ALPHA + 1
    end
    if confirm then
        if self.slot < 3 then
            self.slot = self.slot + 1
        else
            local ini = ""
            for s = 1, 3 do
                local i = self.idx[s]
                ini = ini .. ALPHA:sub(i, i)
            end
            self.done = true
            Kit.setInitials(self.rank, ini)
        end
    end
end

function Entry:draw()
    Kit.panel(100, 56, 200, 128)
    Kit.centered("NEW HIGH SCORE", 64)
    Kit.centered(string.format("%06d", self.score), 82)
    for s = 1, 3 do
        local i = self.idx[s]
        local ch = ALPHA:sub(i, i)
        local x = 172 + (s - 1) * 24
        if s == self.slot and math.floor(self.t * 4) % 2 == 0 then
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(x - 5, 104, 20, 26)
        end
        Kit.text(ch, x, 110)
    end
    Kit.centered("d-pad picks, A sets", 162)
end
