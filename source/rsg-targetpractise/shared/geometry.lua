TargetPractiseGeometry = {}
local G = TargetPractiseGeometry

function G.finite(n)
    return type(n) == 'number' and n == n and math.abs(n) < 1000000
end

function G.point(p)
    if type(p) ~= 'table' and type(p) ~= 'vector3' then return false end
    return G.finite(p.x) and G.finite(p.y) and G.finite(p.z)
end

function G.add(a, b)
    return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

function G.sub(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function G.distance(a, b)
    local d = G.sub(a, b)
    return math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
end

function G.multiply(a, b)
    return {
        x = a.w*b.x + a.x*b.w + a.y*b.z - a.z*b.y,
        y = a.w*b.y - a.x*b.z + a.y*b.w + a.z*b.x,
        z = a.w*b.z + a.x*b.y - a.y*b.x + a.z*b.w,
        w = a.w*b.w - a.x*b.x - a.y*b.y - a.z*b.z
    }
end

function G.inverse(q)
    return { x = -q.x, y = -q.y, z = -q.z, w = q.w }
end

function G.rotate(q, p)
    local r = G.multiply(G.multiply(q, { x = p.x, y = p.y, z = p.z, w = 0 }), G.inverse(q))
    return { x = r.x, y = r.y, z = r.z }
end

function G.yaw(degrees)
    local half = math.rad(degrees) / 2
    return { x = 0.0, y = 0.0, z = math.sin(half), w = math.cos(half) }
end

local source = Config.Source.quaternion
local length = math.sqrt(source.x^2 + source.y^2 + source.z^2 + source.w^2)
G.sourceQuaternion = { x = source.x/length, y = source.y/length, z = source.z/length, w = source.w/length }
local q = G.sourceQuaternion
G.sourceHeading = math.deg(math.atan(2*(q.w*q.z + q.x*q.y), 1-2*(q.y*q.y + q.z*q.z)))
G.tilt = G.multiply(G.yaw(-G.sourceHeading), q)
G.faceOffset = G.rotate(G.inverse(q), G.sub(Config.Source.face, Config.Source.frame))

function G.pose(target)
    local rotation = G.multiply(G.yaw(target.heading), G.tilt)
    return G.add(target.position, G.rotate(rotation, G.faceOffset)), rotation
end

function G.faceLocal(target, world)
    local position, rotation = G.pose(target)
    return G.rotate(G.inverse(rotation), G.sub(world, position))
end

function G.faceWorld(target, offset)
    local position, rotation = G.pose(target)
    return G.add(position, G.rotate(rotation, offset))
end

function G.score(localPoint)
    if not G.point(localPoint) then return nil end
    local d = G.sub(localPoint, Config.Scoring.center)
    if math.abs(d.y) > Config.Scoring.depthTolerance then return nil end
    local radius = math.sqrt(d.x*d.x + d.z*d.z)
    local bullseyeRadius = Config.Scoring.bullseyeRadius or 0
    if bullseyeRadius > 0 and radius <= bullseyeRadius + 1e-9 then
        return Config.Scoring.bullseyePoints or 10, radius, true
    end
    for _, ring in ipairs(Config.Scoring.rings) do
        if radius <= ring.radius + 1e-9 then return ring.points, radius, false end
    end
    return nil, radius, false
end

local scoringMode = Config.Scoring.mode or 'hit'
assert(scoringMode == 'hit' or scoringMode == 'rings', '[rsg-targetpractise] Scoring mode must be hit or rings')
local hitModeEnabled = scoringMode == 'hit'

function G.hitMode()
    return hitModeEnabled
end

-- Weapon hashes can arrive signed or unsigned depending on the native/runtime.
function G.signedHash(value)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then return nil end
    value = value % 4294967296
    if value >= 2147483648 then value = value - 4294967296 end
    return value
end

function G.hitInBounds(target, world)
    if not G.point(world) then return false end
    local faceOrigin = G.pose(target)
    return G.distance(faceOrigin, world) <= (Config.Scoring.hitSanityDistance or 3.0)
end
