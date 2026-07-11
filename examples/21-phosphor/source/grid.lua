-- vendored from phosphor/vec/grid.lua (MIT)
-- Phosphor core: a warping spring grid — the deforming vector lattice that
-- twin-stick arena shooters are built on. Every point is anchored to its
-- home by a weak spring and coupled to its four neighbours, so an impulse
-- dents the mesh and ripples outward before settling. Gameplay pushes and
-- pulls the mesh (the ship's wake, shots, bombs, gravity wells) via
-- Grid.push / Grid.pull; Grid.draw strokes it as horizontal/vertical beams.
--
-- One shared lattice per game (like Fx). Grid.init sizes it to the field.

local gfx <const> = playdate.graphics

Grid = {}

local cols, rows, spacing, ox, oy
local px, py, hx, hy, vx, vy -- flat arrays, 1-based
local STIFF, COUPLE, DAMP, MAXOFF

local function idx(c, r) return r * cols + c + 1 end -- c,r zero-based

function Grid.init(opts)
    opts = opts or {}
    spacing = opts.spacing or 32
    STIFF = opts.stiff or 26    -- home-spring strength (1/s^2)
    COUPLE = opts.couple or 70  -- neighbour coupling (1/s^2)
    DAMP = opts.damp or 0.88    -- velocity retained per frame
    MAXOFF = opts.maxoff or (spacing * 1.8)
    -- a one-cell margin so the outer beams sit just off the field edges
    cols = math.floor(Field.W / spacing) + 3
    rows = math.floor(Field.H / spacing) + 3
    ox = (Field.W - (cols - 1) * spacing) / 2
    oy = (Field.H - (rows - 1) * spacing) / 2
    px, py, hx, hy, vx, vy = {}, {}, {}, {}, {}, {}
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local i = idx(c, r)
            local x, y = ox + c * spacing, oy + r * spacing
            hx[i], hy[i], px[i], py[i], vx[i], vy[i] = x, y, x, y, 0, 0
        end
    end
end

function Grid.reset()
    for i = 1, cols * rows do
        px[i], py[i], vx[i], vy[i] = hx[i], hy[i], 0, 0
    end
end

-- snip: grid-push
-- radial impulse: positive strength shoves points away from (x,y), negative
-- sucks them in. Falls off linearly to zero at `radius`. Touches only the
-- lattice points inside the affected rectangle.
function Grid.push(x, y, strength, radius)
    local c0 = math.max(0, math.floor((x - ox - radius) / spacing))
    local c1 = math.min(cols - 1, math.ceil((x - ox + radius) / spacing))
    local r0 = math.max(0, math.floor((y - oy - radius) / spacing))
    local r1 = math.min(rows - 1, math.ceil((y - oy + radius) / spacing))
    local r2 = radius * radius
    for r = r0, r1 do
        for c = c0, c1 do
            local i = idx(c, r)
            local dx, dy = px[i] - x, py[i] - y
            local d2 = dx * dx + dy * dy
            if d2 < r2 then
                local d = math.sqrt(d2) + 1e-3
                local f = strength * (1 - d / radius) / d
                vx[i] = vx[i] + dx * f
                vy[i] = vy[i] + dy * f
            end
        end
    end
end
-- endsnip

function Grid.pull(x, y, strength, radius)
    Grid.push(x, y, -strength, radius)
end

-- snip: grid-update
function Grid.update(dt)
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local i = idx(c, r)
            -- neighbour average (Laplacian smoothing → ripples travel)
            local sx, sy, n = 0, 0, 0
            if c > 0 then local j = i - 1; sx, sy, n = sx + px[j], sy + py[j], n + 1 end
            if c < cols - 1 then local j = i + 1; sx, sy, n = sx + px[j], sy + py[j], n + 1 end
            if r > 0 then local j = i - cols; sx, sy, n = sx + px[j], sy + py[j], n + 1 end
            if r < rows - 1 then local j = i + cols; sx, sy, n = sx + px[j], sy + py[j], n + 1 end
            local ax = STIFF * (hx[i] - px[i])
            local ay = STIFF * (hy[i] - py[i])
            if n > 0 then
                ax = ax + COUPLE * (sx / n - px[i])
                ay = ay + COUPLE * (sy / n - py[i])
            end
            local nvx = (vx[i] + ax * dt) * DAMP
            local nvy = (vy[i] + ay * dt) * DAMP
            local nx = px[i] + nvx * dt
            local ny = py[i] + nvy * dt
            -- clamp how far a point may stray so a wild force can't explode it
            local dx, dy = nx - hx[i], ny - hy[i]
            local off2 = dx * dx + dy * dy
            if off2 > MAXOFF * MAXOFF then
                local s = MAXOFF / math.sqrt(off2)
                nx, ny = hx[i] + dx * s, hy[i] + dy * s
                nvx, nvy = nvx * 0.5, nvy * 0.5
            end
            px[i], py[i], vx[i], vy[i] = nx, ny, nvx, nvy
        end
    end
end
-- endsnip

-- stroke the mesh with the current colour/line settings
function Grid.draw()
    for r = 0, rows - 1 do
        local base = r * cols
        for c = 0, cols - 2 do
            local i = base + c + 1
            gfx.drawLine(px[i], py[i], px[i + 1], py[i + 1])
        end
    end
    for c = 0, cols - 1 do
        for r = 0, rows - 2 do
            local i = idx(c, r)
            gfx.drawLine(px[i], py[i], px[i + cols], py[i + cols])
        end
    end
end
