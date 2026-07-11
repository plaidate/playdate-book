-- vendored from voxel/core/voxproj.lua (MIT)
-- Voxel core: parabolic projectile integrator for artillery shells.
-- Games own the launch offsets and what happens on impact; this owns the
-- flight math so every shell in the package flies the same way.

VoxProj = {}

function VoxProj.launch(x, y, z, az, v, elevCos, elevSin)
    local ca, sa = math.cos(az), math.sin(az)
    local hv = v * elevCos
    return { x = x, y = y, z = z, vx = hv * ca, vy = hv * sa, vz = v * elevSin, t = 8 }
end

-- snip: proj-step
-- advance one frame; returns true on impact with terrain or the room
-- bounds. Internally substeps so no substep moves more than 0.5 voxels
-- (n = ceil(speed*dt/0.5)), checking Vox.solid at every substep endpoint —
-- fast shells can't tunnel through thin walls between frames.
function VoxProj.step(p, dt, gravity, windX)
    local wind = windX or 0
    local sp = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz)
    local n = math.ceil(sp * dt / 0.5)
    if n < 1 then n = 1 end
    local h = dt / n
    for _ = 1, n do
        p.vx = p.vx + wind * h
        p.vz = p.vz - gravity * h
        p.x = p.x + p.vx * h
        p.y = p.y + p.vy * h
        p.z = p.z + p.vz * h
        if Vox.solid(math.floor(p.x), math.floor(p.y), math.floor(p.z)) then
            return true
        end
    end
    return false
end
-- endsnip

-- Bracket-and-smear aim solver: sweep launch speeds along the straight
-- azimuth to the target, simulate each shot to impact, keep the speed
-- whose crater lands nearest, then smear azimuth and speed by err (an AI
-- shrinks err every shot: classic bracketing). Simulation flies through
-- the substepped VoxProj.step above — the SAME integrator as live shells —
-- so solved shots land where real ones do.
--
--   opts.vmin, opts.vmax      launch speed bounds (required)
--   opts.elevCos, opts.elevSin fixed elevation (required)
--   opts.gravity              (default Config.GRAVITY)
--   opts.wind                 horizontal wind (default 0)
--   opts.err                  aim error; smears az by err*errAz radians
--                             and speed by err*errV (default 0 = perfect)
--   opts.errAz                azimuth smear scale (default 0.03)
--   opts.errV                 speed smear scale (default (vmax-vmin)*0.04)
--   opts.iters                speed samples across [vmin,vmax] (default 10)
--   opts.simSteps             max simulated frames per sample (default 300)
--   opts.muzzle               fn(origin, az) -> launch x, y, z
--                             (default origin.x, origin.y, origin.z)
--
-- returns az, v (smeared, v clamped to [vmin, vmax])
-- snip: proj-solve
function VoxProj.solve(origin, target, opts)
    local az = math.atan(target.y - origin.y, target.x - origin.x)
    local vmin, vmax = opts.vmin, opts.vmax
    local gravity = opts.gravity or Config.GRAVITY
    local wind = opts.wind or 0
    local iters = opts.iters or 10
    local simSteps = opts.simSteps or 300
    local bestV, bestMiss = (vmin + vmax) / 2, math.huge
    for i = 0, iters do
        local v = vmin + (vmax - vmin) * i / iters
        local lx, ly, lz
        if opts.muzzle then
            lx, ly, lz = opts.muzzle(origin, az)
        else
            lx, ly, lz = origin.x, origin.y, origin.z
        end
        local p = VoxProj.launch(lx, ly, lz, az, v, opts.elevCos, opts.elevSin)
        for _ = 1, simSteps do
            if VoxProj.step(p, 1 / 30, gravity, wind) then break end
        end
        local miss = (p.x - target.x) ^ 2 + (p.y - target.y) ^ 2
        if miss < bestMiss then bestMiss, bestV = miss, v end
    end
    local err = opts.err or 0
    local function n() return math.random() + math.random() - 1 end
    az = az + n() * err * (opts.errAz or 0.03)
    local v = Util.clamp(bestV + n() * err * (opts.errV or (vmax - vmin) * 0.04),
        vmin, vmax)
    return az, v
end
-- endsnip
