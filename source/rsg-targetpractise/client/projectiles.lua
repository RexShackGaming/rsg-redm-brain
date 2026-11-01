TargetPractiseProjectiles = {}
local P = TargetPractiseProjectiles
local G = TargetPractiseGeometry

function P.release(previousWeapon, previousAmmo, weapon, ammo, previousAmmoNow, shooting, wasShooting, allowed)
    if allowed[previousWeapon] and type(previousAmmo) == 'number'
        and type(previousAmmoNow) == 'number' and previousAmmoNow < previousAmmo then
        return previousWeapon
    end
    if allowed[weapon] and shooting and not wasShooting then return weapon end
    if allowed[weapon] and weapon == previousWeapon and type(previousAmmo) == 'number'
        and type(ammo) == 'number' and ammo < previousAmmo then return weapon end
end

function P.capture(seen, entity, position, origin, speed, attached)
    if type(entity) ~= 'number' or entity == 0 or seen[entity] or attached
        or not G.point(position) or not G.point(origin)
        or not G.finite(speed) or speed < Config.Projectiles.minimumSpeed
        or G.distance(position, origin) > Config.Projectiles.captureDistance then return nil end
    seen[entity] = true
    return { entity = entity, position = { x = position.x, y = position.y, z = position.z } }
end

function P.segment(track, position)
    if not G.point(position) then return nil end
    local from = track.position
    track.position = { x = position.x, y = position.y, z = position.z }
    local distance = G.distance(from, position)
    if distance < 0.001 or distance > Config.Projectiles.maxStep then return nil end
    local delta = G.sub(position, from)
    -- Cover the knife tip ahead of its entity origin, not a camera aim ray.
    local scale = Config.Projectiles.probeExtension / distance
    return from, {
        x = position.x + delta.x * scale,
        y = position.y + delta.y * scale,
        z = position.z + delta.z * scale
    }
end

function P.modelKey(model)
    if type(model) ~= 'number' or model ~= model or model % 1 ~= 0 then return nil end
    return model % 4294967296 -- Model hashes may be returned signed or unsigned.
end

-- A flying projectile can become a different lodged object. Ignore only
-- catalogued projectile props, only beside this fresh impact, within this
-- existing short segment. The caller must still identify the actual face.
function P.probeSurface(from, to, impact, ignored, cast, modelOf, models, tolerance)
    if not G.point(from) or not G.point(to) or not G.point(impact) then
        return false, nil, nil, 0, 'invalid probe coordinates'
    end
    local length = G.distance(from, to)
    if length < 0.001 then return false, nil, nil, 0, 'empty probe segment' end
    local direction = G.sub(to, from)
    direction = { x = direction.x/length, y = direction.y/length, z = direction.z/length }
    local skipped, seen = 0, {}
    for _ = 1, 7 do -- At most six projectile occluders; never an unbounded recast.
        local hit, endpoint, entity = cast(from, to, ignored)
        if not hit or not G.point(endpoint) then
            return false, endpoint, entity, skipped, 'no backing surface'
        end
        if type(entity) ~= 'number' or entity == 0 then
            return true, endpoint, entity, skipped, 'world or unclassified surface'
        end
        local key = P.modelKey(modelOf(entity))
        if key == nil or not models[key] then
            return true, endpoint, entity, skipped, 'surface found'
        end
        if G.distance(endpoint, impact) > tolerance then
            return false, endpoint, entity, skipped, 'projectile collider is outside impact tolerance'
        end
        if skipped >= 6 or seen[entity] then
            return false, endpoint, entity, skipped, 'projectile skip limit or repeated collider'
        end
        skipped, seen[entity] = skipped + 1, true
        -- No forward epsilon: even an extremely thin non-projectile collider
        -- immediately behind the knife must remain eligible for the next cast.
        from = { x = endpoint.x, y = endpoint.y, z = endpoint.z }
        local remaining = G.sub(to, from)
        if remaining.x*direction.x + remaining.y*direction.y + remaining.z*direction.z <= 0 then
            return false, endpoint, entity, skipped, 'end of probe segment'
        end
        ignored = entity
    end
    return false, nil, nil, skipped, 'probe exhausted'
end
