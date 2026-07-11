-- vendored from phosphor/vec/mat.lua (MIT)
-- Phosphor core: 3x3 orientation matrices for full-attitude 3D.
--
-- Proj.model rotates a model about Y only — enough for ground games where
-- everything stands upright. Free-flight games (ships tumbling in space) need
-- objects at any attitude, so an object carries an orientation matrix here and
-- Proj.mesh draws it. Matrices are flat row-major 9-arrays:
--
--     { m11, m12, m13,
--       m21, m22, m23,
--       m31, m32, m33 }
--
-- Read column j as the object's local axis j expressed in the parent frame:
-- column 3 (m13,m23,m33) is where the object's nose (+Z) points. A vector is
-- transformed parent = M * local.

Mat = {}

function Mat.identity()
    return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
end

-- snip: mat-mulvec
-- parent-space vector for a local (x,y,z): returns x', y', z'
function Mat.mulVec(m, x, y, z)
    return m[1] * x + m[2] * y + m[3] * z,
           m[4] * x + m[5] * y + m[6] * z,
           m[7] * x + m[8] * y + m[9] * z
end
-- endsnip

-- snip: mat-mul
-- matrix product a*b (both 9-arrays). Allocates a new 9-array unless an
-- `out` table is supplied; products land in locals first, so out may
-- alias a or b (`Mat.mul(R, o.m, o.m)` is safe).
function Mat.mul(a, b, out)
    local m1 = a[1] * b[1] + a[2] * b[4] + a[3] * b[7]
    local m2 = a[1] * b[2] + a[2] * b[5] + a[3] * b[8]
    local m3 = a[1] * b[3] + a[2] * b[6] + a[3] * b[9]
    local m4 = a[4] * b[1] + a[5] * b[4] + a[6] * b[7]
    local m5 = a[4] * b[2] + a[5] * b[5] + a[6] * b[8]
    local m6 = a[4] * b[3] + a[5] * b[6] + a[6] * b[9]
    local m7 = a[7] * b[1] + a[8] * b[4] + a[9] * b[7]
    local m8 = a[7] * b[2] + a[8] * b[5] + a[9] * b[8]
    local m9 = a[7] * b[3] + a[8] * b[6] + a[9] * b[9]
    if not out then
        return { m1, m2, m3, m4, m5, m6, m7, m8, m9 }
    end
    out[1], out[2], out[3] = m1, m2, m3
    out[4], out[5], out[6] = m4, m5, m6
    out[7], out[8], out[9] = m7, m8, m9
    return out
end
-- endsnip

-- snip: mat-rotate
-- rotation matrices (right-handed, angle in radians) about each parent
-- axis; pass `out` to fill a reusable table instead of allocating
function Mat.rx(t, out)
    local s, c = math.sin(t), math.cos(t)
    if not out then return { 1, 0, 0, 0, c, -s, 0, s, c } end
    out[1], out[2], out[3] = 1, 0, 0
    out[4], out[5], out[6] = 0, c, -s
    out[7], out[8], out[9] = 0, s, c
    return out
end

function Mat.ry(t, out)
    local s, c = math.sin(t), math.cos(t)
    if not out then return { c, 0, s, 0, 1, 0, -s, 0, c } end
    out[1], out[2], out[3] = c, 0, s
    out[4], out[5], out[6] = 0, 1, 0
    out[7], out[8], out[9] = -s, 0, c
    return out
end

function Mat.rz(t, out)
    local s, c = math.sin(t), math.cos(t)
    if not out then return { c, -s, 0, s, c, 0, 0, 0, 1 } end
    out[1], out[2], out[3] = c, -s, 0
    out[4], out[5], out[6] = s, c, 0
    out[7], out[8], out[9] = 0, 0, 1
    return out
end

-- premultiply m by a rotation about a parent axis: returns rot(t) * m, i.e. the
-- orientation after rotating it by t in the parent frame. Pitch is rx, roll rz.
local spinTmp = {}
function Mat.spinX(m, t, out) return Mat.mul(Mat.rx(t, spinTmp), m, out) end
function Mat.spinY(m, t, out) return Mat.mul(Mat.ry(t, spinTmp), m, out) end
function Mat.spinZ(m, t, out) return Mat.mul(Mat.rz(t, spinTmp), m, out) end
-- endsnip

-- snip: mat-tidy
-- Re-orthonormalize to shed the rounding drift that accumulates when a matrix
-- is spun every frame (Elite's TIDY). Gram-Schmidt anchored on column 3 (nose).
function Mat.tidy(m)
    -- nose = column 3
    local nx, ny, nz = m[3], m[6], m[9]
    local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
    if nl < 1e-6 then return Mat.identity() end
    nx, ny, nz = nx / nl, ny / nl, nz / nl
    -- right = column 1, made orthogonal to nose
    local rx, ry, rz = m[1], m[4], m[7]
    local d = rx * nx + ry * ny + rz * nz
    rx, ry, rz = rx - d * nx, ry - d * ny, rz - d * nz
    local rl = math.sqrt(rx * rx + ry * ry + rz * rz)
    if rl < 1e-6 then return Mat.identity() end
    rx, ry, rz = rx / rl, ry / rl, rz / rl
    -- up = nose x right (column 2)
    local ux = ny * rz - nz * ry
    local uy = nz * rx - nx * rz
    local uz = nx * ry - ny * rx
    return { rx, ux, nx, ry, uy, ny, rz, uz, nz }
end
-- endsnip
