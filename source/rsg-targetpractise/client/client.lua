lib.locale()

local G = TargetPractiseGeometry
local D = TargetPractiseDiagnostics
D.detectorVersion = D.codeVersion
local targets, objects, preview = {}, {}, nil
local placing, stopping, debugEnabled = false, false, Config.Debug
local markers = {}
local hashes = {}
for name, label in pairs(Config.Weapons) do hashes[GetHashKey(name)] = label end
local KNIFE = GetHashKey('WEAPON_THROWN_THROWING_KNIVES')
D.enable = function(enabled) debugEnabled = enabled end

local function runThread(name, callback)
    CreateThread(function()
        local ok, err = xpcall(callback, debug.traceback)
        if not ok then
            if name == 'detector' then D.stage = 'stopped-after-error' end
            D.recordError(name, err)
        end
    end)
end

local function notify(message, kind)
    lib.notify({ title = locale('notify_title'), description = message, type = kind or 'inform', duration = 5000 })
end

local function registerInteractions(pair, id)
    exports.ox_target:addLocalEntity(pair, {
        {
            name = 'rsg-targetpractise:leaderboard',
            label = locale('interaction_board'),
            icon = 'fa-solid fa-trophy',
            distance = Config.RemoveDistance,
            canInteract = function() return not placing end,
            onSelect = function() TriggerEvent('rsg-targetpractise:client:openLeaderboard') end
        },
        {
            name = 'rsg-targetpractise:pickup',
            label = locale('interaction_pack'),
            icon = 'fa-solid fa-box',
            distance = Config.RemoveDistance,
            canInteract = function()
                local target = targets[id]
                return not placing and target ~= nil and target.canRemove == true
            end,
            onSelect = function() TriggerServerEvent('rsg-targetpractise:server:remove', id) end
        }
    })
end

local function removePair(pair)
    if not pair then return end
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeLocalEntity(pair, { 'rsg-targetpractise:pickup', 'rsg-targetpractise:leaderboard' })
    end
    for _, entity in ipairs(pair) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end

local function loadModel(name)
    local hash = GetHashKey(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + Config.ModelTimeoutMs
    while not HasModelLoaded(hash) do
        if stopping or GetGameTimer() > deadline then
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
        Wait(25)
    end
    return hash
end

local function applyPose(pair, target)
    local face, rotation = G.pose(target)
    SetEntityCoordsNoOffset(pair[1], target.position.x + 0.0, target.position.y + 0.0, target.position.z + 0.0, false, false, false)
    SetEntityCoordsNoOffset(pair[2], face.x + 0.0, face.y + 0.0, face.z + 0.0, false, false, false)
    for _, entity in ipairs(pair) do
        SetEntityQuaternion(entity, rotation.x + 0.0, rotation.y + 0.0, rotation.z + 0.0, rotation.w + 0.0)
    end
end

local function createPair(target, ghost)
    local frameHash = loadModel(Config.FrameModel)
    if not frameHash then return nil end
    local faceHash = loadModel(Config.FaceModel)
    if not faceHash then
        SetModelAsNoLongerNeeded(frameHash)
        return nil
    end
    local p = target.position
    -- Local replicas: the server synchronizes placement records, never client entity handles.
    local pair = {
        CreateObject(frameHash, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false, false),
        CreateObject(faceHash, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false, false)
    }
    SetModelAsNoLongerNeeded(frameHash)
    SetModelAsNoLongerNeeded(faceHash)
    if stopping or pair[1] == 0 or pair[2] == 0 then removePair(pair) return nil end
    for _, entity in ipairs(pair) do
        SetEntityAsMissionEntity(entity, true, true)
        FreezeEntityPosition(entity, true)
        SetEntityCollision(entity, not ghost, not ghost)
        if ghost then SetEntityAlpha(entity, 150, false) end
    end
    applyPose(pair, target)
    return pair
end

RegisterNetEvent('rsg-targetpractise:client:sync', function(list)
    D.count('sync_packets')
    local updated = {}
    for _, target in ipairs(list) do updated[target.id] = target end
    for id, pair in pairs(objects) do
        if not updated[id] then removePair(pair) objects[id] = nil end
    end
    targets = updated
end)

RegisterNetEvent('rsg-targetpractise:client:scoreRejected', function(reason)
    D.count('server_rejections')
    D.lastResult = 'server: ' .. tostring(reason)
    if debugEnabled then print('[rsg-targetpractise] Server rejected score: ' .. tostring(reason)) end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'ox_target' then return end
    for id, pair in pairs(objects) do registerInteractions(pair, id) end
end)

runThread('streamer', function()
    TriggerServerEvent('rsg-targetpractise:server:sync')
    while not stopping do
        local position = GetEntityCoords(PlayerPedId())
        for id, target in pairs(targets) do
            if G.distance(position, target.position) <= Config.StreamDistance then
                if not objects[id] then
                    local pair = createPair(target, false)
                    if pair and targets[id] and not stopping then
                        objects[id] = pair
                        D.count('target_pairs_created')
                        registerInteractions(pair, id)
                    else
                        removePair(pair)
                    end
                end
            elseif objects[id] then
                removePair(objects[id])
                objects[id] = nil
            end
        end
        Wait(1000)
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('rsg-targetpractise:server:sync')
end)

local function placementUI(action, data)
    SendNUIMessage({ action = action, data = data, locales = action == 'placementShow' and TargetPractiseLocale.ui() or nil })
end

local function finishPlacement(result)
    removePair(preview)
    preview, placing = nil, false
    placementUI('placementHide', { result = result })
end

RegisterNetEvent('rsg-targetpractise:client:place', function()
    if placing then return end
    placing = true
    CreateThread(function()
        local ped = PlayerPedId()
        local target = { position = GetEntityCoords(ped), heading = GetEntityHeading(ped) }
        preview = createPair(target, true)
        if not preview then
            finishPlacement('cancel')
            TriggerServerEvent('rsg-targetpractise:server:cancel')
            return notify(locale('model_failed'), 'error')
        end
        local height, validGround = 0.0, false
        local deadline = GetGameTimer() + Config.Placement.timeoutSeconds * 1000
        placementUI('placementShow', { timeout = Config.Placement.timeoutSeconds, heightRange = Config.Placement.heightRange })
        local lastSent, lastKey = 0, nil
        while placing and not stopping do
            Wait(0)
            ped = PlayerPedId()
            local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.Placement.distance, 0.0)
            local found, ground = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 3.0, false)
            validGround = found
            local dt = math.min(GetFrameTime(), 0.05)
            for _, control in pairs(Config.Controls) do DisableControlAction(0, control, true) end
            DisableControlAction(0, 0x07CE1E61, true) -- Attack
            DisableControlAction(0, 0xF84FA74F, true) -- Aim
            if IsDisabledControlPressed(0, Config.Controls.left) then target.heading = target.heading + Config.Placement.rotationSpeed * dt end
            if IsDisabledControlPressed(0, Config.Controls.right) then target.heading = target.heading - Config.Placement.rotationSpeed * dt end
            if IsDisabledControlPressed(0, Config.Controls.up) then height = math.min(Config.Placement.heightRange, height + Config.Placement.heightSpeed * dt) end
            if IsDisabledControlPressed(0, Config.Controls.down) then height = math.max(-Config.Placement.heightRange, height - Config.Placement.heightSpeed * dt) end
            target.position = { x = pos.x, y = pos.y, z = (found and ground or pos.z) + height }
            applyPose(preview, target)
            local keys = {
                left = IsDisabledControlPressed(0, Config.Controls.left),
                right = IsDisabledControlPressed(0, Config.Controls.right),
                up = IsDisabledControlPressed(0, Config.Controls.up),
                down = IsDisabledControlPressed(0, Config.Controls.down)
            }
            local now = GetGameTimer()
            local key = ('%s%s%s%s%s'):format(tostring(keys.left), tostring(keys.right), tostring(keys.up), tostring(keys.down), tostring(validGround))
            if now - lastSent >= 100 or key ~= lastKey then
                lastSent, lastKey = now, key
                placementUI('placementUpdate', {
                    heading = math.floor((target.heading % 360) + 0.5),
                    height = height,
                    valid = validGround,
                    remaining = math.max(0, math.ceil((deadline - now) / 1000)),
                    keys = keys
                })
            end
            if IsDisabledControlJustPressed(0, Config.Controls.confirm) then
                if validGround then
                    TriggerServerEvent('rsg-targetpractise:server:place', target.position, target.heading)
                    finishPlacement('confirm')
                    return
                end
                placementUI('placementFlash', { key = 'confirm', error = true })
                notify(locale('ground_missing'), 'error')
            end
            if IsDisabledControlJustPressed(0, Config.Controls.cancel) or IsEntityDead(ped)
                or GetGameTimer() > deadline then
                finishPlacement('cancel')
                TriggerServerEvent('rsg-targetpractise:server:cancel')
                return
            end
        end
    end)
end)

RegisterCommand('targetremove', function()
    if placing then return end
    local position, nearest, distance = GetEntityCoords(PlayerPedId()), nil, Config.RemoveDistance
    for id, target in pairs(targets) do
        local d = G.distance(position, target.position)
        if d < distance then nearest, distance = id, d end
    end
    if not nearest then return notify(locale('nearby_missing'), 'error') end
    TriggerServerEvent('rsg-targetpractise:server:remove', nearest)
end, false)

local impactError, projectileError
local function impactCoord(ped)
    if impactError then return false end
    local ok, found, point = pcall(Citizen.InvokeNative, 0x6C4D0409BA1A2BC2, ped,
        Citizen.PointerValueVector(), Citizen.ReturnResultAnyway())
    if not ok then
        impactError = found
        D.recordError('ped-impact-native', found)
        return false
    end
    return found == true or found == 1, point
end

local function ownKnife(ped, weapon)
    if projectileError then return nil end
    -- RedM: mustBeOwnedByThisPed=true. Never adopt another player's projectile.
    local ok, found, point, entity = pcall(Citizen.InvokeNative, 0x9578986A6105A6AD, ped, weapon,
        Config.Scoring.maxDistance + 0.0, Citizen.PointerValueVector(), Citizen.PointerValueInt(),
        false, true, Citizen.ReturnResultAnyway())
    if not ok then
        projectileError = found
        D.recordError('owned-projectile-native', found)
        return nil
    end
    D.lastProjectile = ('flag=%s entity=%s coords=%s'):format(tostring(found), tostring(entity), tostring(G.point(point)))
    if (found == true or found == 1) and entity and entity ~= 0 and DoesEntityExist(entity) then
        D.count('owned_knives_found')
        return entity, point
    end
end

D.provider = function()
    local ped = PlayerPedId()
    local position = GetEntityCoords(ped)
    local records, streamed, nearest = 0, 0, nil
    for id, target in pairs(targets) do
        records = records + 1
        if objects[id] and DoesEntityExist(objects[id][1]) and DoesEntityExist(objects[id][2]) then
            streamed = streamed + 1
        end
        local reference = G.hitMode() and G.pose(target) or G.faceWorld(target, Config.Scoring.center)
        local distance = G.distance(position, reference)
        if not nearest or distance < nearest then nearest = distance end
    end
    local ok, result, weapon = pcall(GetCurrentPedWeapon, ped, true, 0, false)
    local ammoOK, ammo = false, nil
    if ok and type(weapon) == 'number' then ammoOK, ammo = pcall(GetAmmoInPedWeapon, ped, weapon) end
    return {
        'score_mode=' .. (G.hitMode() and 'hit (one point)' or 'rings'),
        ('target_records=%d streamed_pairs=%d nearest_m=%s'):format(records, streamed, nearest and ('%.2f'):format(nearest) or 'none'),
        ('weapon_call_ok=%s result=%s hash=%s'):format(tostring(ok), tostring(result), tostring(weapon)),
        ('weapon_allowed=%s ammo_call_ok=%s ammo=%s'):format(tostring(hashes[weapon] ~= nil), tostring(ammoOK), tostring(ammo)),
        ('score_center=(%.4f,%.4f,%.4f) depth_tolerance=%.4f'):format(
            Config.Scoring.center.x, Config.Scoring.center.y, Config.Scoring.center.z, Config.Scoring.depthTolerance),
        'placing=' .. tostring(placing),
        'projectile_settings=' .. tostring(type(Config.Projectiles) == 'table')
    }
end

local function ray(from, to, ignored)
    local handle = Citizen.InvokeNative(0x7EE9F5D83DD4F90E,
        from.x + 0.0, from.y + 0.0, from.z + 0.0, to.x + 0.0, to.y + 0.0, to.z + 0.0,
        -1, ignored, 4, Citizen.ResultAsInteger())
    local deadline = GetGameTimer() + 200
    repeat
        local state, hit, endpoint, _, entity = GetShapeTestResult(handle)
        if state == 2 then
            local model = 'none'
            if entity and entity ~= 0 and type(GetEntityModel) == 'function' then
                local ok, value = pcall(GetEntityModel, entity)
                model = ok and tostring(value) or 'unavailable'
            end
            D.lastProbe = ('hit=%s entity=%s model=%s ignored=%s'):format(
                tostring(hit), tostring(entity), model, tostring(ignored))
            return hit == 1 or hit == true, endpoint, entity
        end
        if state == 0 then D.lastProbe = 'invalid shape-test handle' return false end
        Wait(0)
    until stopping or GetGameTimer() > deadline
    D.lastProbe = 'shape-test timeout'
    return false
end

local function debugImpact(impact, reason, target)
    D.lastResult = reason
    if target then
        local point = G.faceLocal(target, impact)
        if G.hitMode() then
            D.lastResult = ('%s local=(%.4f,%.4f,%.4f)'):format(reason, point.x, point.y, point.z)
        else
            local offset = G.sub(point, Config.Scoring.center)
            local radius = math.sqrt(offset.x * offset.x + offset.z * offset.z)
            D.lastResult = ('%s local=(%.4f,%.4f,%.4f) depth_delta=%.4f depth_limit=%.4f radius=%.4f'):format(
                reason, point.x, point.y, point.z, math.abs(offset.y), Config.Scoring.depthTolerance, radius)
        end
    end
    if not debugEnabled then return end
    markers[#markers + 1] = { position = impact, expires = GetGameTimer() + Config.DebugImpactMs }
    local p = target and G.faceLocal(target, impact) or impact
    print(('[rsg-targetpractise] %s | %s coords x=%.4f y=%.4f z=%.4f'):format(
        reason, target and 'face-local' or 'world', p.x, p.y, p.z))
end

local function targetForEntity(entity)
    for id, pair in pairs(objects) do
        if entity == pair[2] then return targets[id], 'face' end
        if entity == pair[1] then return targets[id], 'frame' end
    end
end

-- Verified against rdr3_discoveries-master/objects/object_list.lua.
-- Do not add generic props, walls, or target models to this allowlist.
local probeProjectileModels = {
    [1597043588] = true, -- w_melee_knife05 (the blocker in the supplied report)
    [1146914213] = true, -- w_sp_bowarrow_arrow
    [3328922390] = true -- w_sp_bowarrow_arrow_smallgame (-966044906 signed)
}

local function probeModel(entity)
    if not entity or entity == 0 then return nil end
    local ok, model = pcall(GetEntityModel, entity)
    return ok and model or nil
end

local function checkImpact(shot, impact, confirmedEntity)
    if not G.point(impact) then return end
    local entity = confirmedEntity
    if entity == nil then
        local direction = G.sub(impact, shot.origin)
        local length = G.distance(impact, shot.origin)
        if length < 0.01 then return end
        local reach = Config.Scoring.impactRayDistance / length
        local delta = { x = direction.x*reach, y = direction.y*reach, z = direction.z*reach }
        local ignored = PlayerPedId()
        if shot.ignoredProjectile and DoesEntityExist(shot.ignoredProjectile) then
            ignored = shot.ignoredProjectile
        elseif shot.weapon == KNIFE then
            -- A lodged own knife must not block the short target verification probe.
            local ownEntity = ownKnife(PlayerPedId(), shot.weapon)
            if ownEntity then ignored = ownEntity end
        end
        local hit, endpoint, hitEntity, skips, reason = TargetPractiseProjectiles.probeSurface(
            G.sub(impact, delta), G.add(impact, delta), impact, ignored,
            ray, probeModel, probeProjectileModels, Config.Scoring.impactRayTolerance)
        for _ = 1, skips do D.count('projectile_probe_skips') end
        D.lastProbe = ('%s projectile_skips=%d result=%s'):format(tostring(D.lastProbe), skips, reason)
        if not hit or not G.point(endpoint)
            or G.distance(endpoint, impact) > Config.Scoring.impactRayTolerance then
            D.count('face_probe_misses')
            debugImpact(impact, 'Rejected: impact probe did not confirm a nearby surface; ' .. tostring(D.lastProbe))
            return
        end
        impact, entity = endpoint, hitEntity
    end
    local target, kind = targetForEntity(entity)
    if not target or kind ~= 'face' then
        if kind == 'frame' then D.count('frame_collisions') end
        debugImpact(impact, kind == 'frame' and 'Rejected: support frame hit, not target face'
            or ('Rejected: entity %s is not a streamed target face'):format(tostring(entity)), target)
        return
    end
    D.count('confirmed_face_hits')
    if not G.hitMode() and not G.score(G.faceLocal(target, impact)) then
        debugImpact(impact, 'Confirmed face but outside configured rings/depth', target)
        return
    end
    debugImpact(impact, G.hitMode() and 'Confirmed target face: one-point hit mode'
        or 'Confirmed target face: ring mode', target)
    TriggerServerEvent('rsg-targetpractise:server:hit', shot.sequence, target.id, {
        x = impact.x, y = impact.y, z = impact.z
    })
    D.count('hits_submitted')
    if debugEnabled then print(('[rsg-targetpractise] Submitted shot #%d against target #%d'):format(shot.sequence, target.id)) end
end

runThread('detector', function()
    local sequence, active, lastImpact, initialized = 0, nil, nil, false
    local previousWeapon, previousAmmo, wasShooting, lastShot = nil, nil, false, -100000
    local knife = KNIFE
    local seen, lastCleanup, knifeWindow = {}, 0, 0
    local P = TargetPractiseProjectiles
    assert(type(P) == 'table' and type(P.release) == 'function', 'client/projectiles.lua was not loaded; check deployed fxmanifest and files')
    local function beginShot(weapon, position, now, reason)
        if now - lastShot < Config.Scoring.shotCooldownMs then return nil end
        sequence, lastShot = sequence + 1, now
        local shot = {
            sequence = sequence, weapon = weapon, origin = position,
            expires = now + Config.Scoring.shotWindowMs
        }
        TriggerServerEvent('rsg-targetpractise:server:shot', sequence, weapon)
        D.count('shots_registered')
        if debugEnabled then print(('[rsg-targetpractise] Shot #%d: %s (%s)'):format(sequence, hashes[weapon], reason)) end
        return shot
    end
    while not stopping do
        D.tick('checking-target-range')
        local ped = PlayerPedId()
        local position = GetEntityCoords(ped)
        local nearby = false
        for id, target in pairs(targets) do
            if objects[id] and G.distance(position, target.position) < Config.Scoring.maxDistance + 5.0 then nearby = true break end
        end
        if nearby and not placing and not IsEntityDead(ped) then
            D.stage = 'reading-weapon'
            local _, weapon = GetCurrentPedWeapon(ped, true, 0, false)
            D.count('weapon_samples')
            local now = GetGameTimer()
            if not hashes[weapon] and not hashes[previousWeapon] and not active and now > knifeWindow then
                -- Nothing scorable in hand or in flight: poll slowly instead of every frame.
                D.stage = 'idle-no-scored-weapon'
                lastImpact, initialized = nil, false
                Wait(250)
                goto continue
            end
            if hashes[weapon] then D.count('allowed_weapon_samples') end
            local ammo = hashes[weapon] and GetAmmoInPedWeapon(ped, weapon) or nil
            local shooting = IsPedShooting(ped)
            if shooting then D.count('shooting_frames') end
            if debugEnabled and weapon ~= previousWeapon then
                print(('[rsg-targetpractise] Equipped weapon=%s (%s), ammo=%s'):format(
                    tostring(weapon), hashes[weapon] or 'not scored', tostring(ammo)))
            end
            local previousAmmoNow = hashes[previousWeapon] and GetAmmoInPedWeapon(ped, previousWeapon) or nil
            local released = P.release(previousWeapon, previousAmmo, weapon, ammo,
                previousAmmoNow, shooting, wasShooting, hashes)
            local found, impact = impactCoord(ped)
            local changed = found and G.point(impact) and (not lastImpact
                or G.distance(impact, lastImpact) > Config.Scoring.impactChangeEpsilon)
            if initialized and released and now - lastShot >= Config.Scoring.shotCooldownMs then
                D.count('release_events')
                active = beginShot(released, position, now, 'shooting/ammo release')
            end
            -- Only query the projectile native while knives are equipped or one was just thrown.
            if hashes[knife] and (weapon == knife or previousWeapon == knife) then
                knifeWindow = now + Config.Scoring.shotWindowMs
            end
            if now <= knifeWindow then
                D.stage = 'querying-own-projectile'
                local entity, projectilePosition = ownKnife(ped, knife)
                if entity and G.point(projectilePosition) then
                    local attached = IsEntityAttached(entity)
                    local track = P.capture(seen, entity, projectilePosition, position,
                        GetEntitySpeed(entity), attached == true or attached == 1)
                    if track then
                        if not active or active.weapon ~= knife or now > active.expires then
                            active = beginShot(knife, position, now, 'own moving knife projectile')
                        end
                        if active and active.weapon == knife then
                            active.projectile = track
                            active.ignoredProjectile = track.entity
                            D.count('knives_tracked')
                            if debugEnabled then print(('[rsg-targetpractise] Tracking own knife entity %d'):format(entity)) end
                        end
                    end
                end
            end
            if active and active.projectile and now <= active.expires then
                local track = active.projectile
                if DoesEntityExist(track.entity) then
                    local from, to = P.segment(track, GetEntityCoords(track.entity))
                    if from then
                        local hit, endpoint, entity = ray(from, to, track.entity)
                        if hit then
                            D.count('flight_collisions')
                            local shot = active
                            active = nil
                            if debugEnabled then print(('[rsg-targetpractise] Knife flight collision: entity %s'):format(tostring(entity))) end
                            checkImpact(shot, endpoint, entity)
                        end
                    end
                else
                    -- If this game build removes the projectile early, allow the native-impact fallback.
                    active.projectile = nil
                    if debugEnabled then print('[rsg-targetpractise] Tracked knife disappeared; waiting for ped impact fallback.') end
                end
            end
            if changed then
                D.count('ped_impact_changes')
                lastImpact = impact
                if initialized and active and not active.projectile and now <= active.expires then
                    local shot = active
                    active = nil -- Every fresh impact ends this shot, including misses.
                    checkImpact(shot, impact)
                end
            elseif not found then
                -- An invalid -> valid transition is a fresh impact even at the same coordinate.
                lastImpact = nil
            end
            if active and now > active.expires then
                if debugEnabled then print('[rsg-targetpractise] Shot expired: no confirmed face collision or fresh ped impact.') end
                active = nil
            end
            if now - lastCleanup > 5000 then
                for entity in pairs(seen) do
                    if not DoesEntityExist(entity) then seen[entity] = nil end
                end
                lastCleanup = now
            end
            previousWeapon, previousAmmo, wasShooting, initialized = weapon, ammo, shooting, true
            D.stage = 'monitoring'
            Wait(0)
        else
            D.stage = not nearby and 'idle-no-streamed-target-in-range' or (placing and 'placing' or 'player-dead')
            D.count('idle_ticks')
            active, lastImpact, initialized = nil, nil, false
            previousWeapon, previousAmmo, wasShooting = nil, nil, false
            Wait(250)
        end
        ::continue::
    end
end)

RegisterNetEvent('rsg-targetpractise:client:scored', function(points, radius, total, impact, mode, bullseye, weaponKind, weaponLabel, distance, bonus)
    D.count('scores_accepted')
    if bullseye then
        D.count('bullseyes')
        SendNUIMessage({
            action = 'announce',
            title = locale('bullseye_title'),
            label = locale('bullseye_points', points),
            lines = {
                locale('bullseye_weapon', weaponLabel and locale(weaponLabel) or locale('unknown_weapon')),
                locale('bullseye_distance', distance or 0)
            },
            color = '#f5c542',
            duration = 3200
        })
        if bonus and bonus > 0 then
            notify(locale('bullseye_scored_bonus', points, bonus, total.points, total.bullseyes or 0), 'success')
        else
            notify(locale('bullseye_scored', points, total.points, total.bullseyes or 0), 'success')
        end
    elseif mode == 'hit' or (mode == nil and G.hitMode()) then
        notify(locale('hit_registered', total.points, total.hits), 'success')
    elseif bonus and bonus > 0 then
        notify(locale('hit_scored_bonus', points, bonus, radius * 100, total.points, total.hits), 'success')
    else
        notify(locale('hit_scored', points, radius * 100, total.points, total.hits), 'success')
    end
    debugImpact(impact, 'Server accepted score')
end)

RegisterNetEvent('rsg-targetpractise:client:debug', function(enabled)
    if type(enabled) == 'boolean' then debugEnabled = enabled else debugEnabled = not debugEnabled end
    local key = debugEnabled and (G.hitMode() and 'debug_hit_enabled' or 'debug_enabled') or 'debug_disabled'
    notify(locale(key))
end)

local function line(a, b, r, g, blue)
    Citizen.InvokeNative(0xB3426BCC, a.x + 0.0, a.y + 0.0, a.z + 0.0,
        b.x + 0.0, b.y + 0.0, b.z + 0.0, r, g, blue, 255)
end

runThread('debug-draw', function()
    while not stopping do
        if debugEnabled then
            local position = GetEntityCoords(PlayerPedId())
            for id, target in pairs(targets) do
                if objects[id] and G.distance(position, target.position) < 30.0 then
                    local c = G.hitMode() and { x = 0.0, y = 0.0, z = 0.0 } or Config.Scoring.center
                    for _, ring in ipairs(G.hitMode() and {} or Config.Scoring.rings) do
                        local previous
                        for segment = 0, 48 do
                            local angle = segment * math.pi * 2 / 48
                            local p = G.faceWorld(target, {
                                x = c.x + math.cos(angle)*ring.radius,
                                y = c.y - Config.Scoring.depthTolerance,
                                z = c.z + math.sin(angle)*ring.radius
                            })
                            if previous then line(previous, p, 255, 190, 30) end
                            previous = p
                        end
                    end
                    local bullseyeRadius = Config.Scoring.bullseyeRadius or 0
                    if not G.hitMode() and bullseyeRadius > 0 then
                        local previous
                        for segment = 0, 48 do
                            local angle = segment * math.pi * 2 / 48
                            local p = G.faceWorld(target, {
                                x = c.x + math.cos(angle)*bullseyeRadius,
                                y = c.y - Config.Scoring.depthTolerance,
                                z = c.z + math.sin(angle)*bullseyeRadius
                            })
                            if previous then line(previous, p, 245, 197, 66) end
                            previous = p
                        end
                    end
                    local center = G.faceWorld(target, c)
                    line(center, G.faceWorld(target, G.add(c, { x = 0.3, y = 0.0, z = 0.0 })), 255, 0, 0)
                    line(center, G.faceWorld(target, G.add(c, { x = 0.0, y = 0.3, z = 0.0 })), 0, 255, 0)
                    line(center, G.faceWorld(target, G.add(c, { x = 0.0, y = 0.0, z = 0.3 })), 0, 100, 255)
                end
            end
            for i = #markers, 1, -1 do
                local marker = markers[i]
                if marker.expires < GetGameTimer() then
                    table.remove(markers, i)
                else
                    local p = marker.position
                    line(G.add(p, { x = -0.05, y = 0.0, z = -0.05 }), G.add(p, { x = 0.05, y = 0.0, z = 0.05 }), 0, 255, 255)
                    line(G.add(p, { x = -0.05, y = 0.0, z = 0.05 }), G.add(p, { x = 0.05, y = 0.0, z = -0.05 }), 0, 255, 255)
                end
            end
            Wait(0)
        else
            markers = {}
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopping = true
    if placing then finishPlacement('cancel') end
    for _, pair in pairs(objects) do removePair(pair) end
end)
D.mainReady = true
print(('[rsg-targetpractise] DETECTOR READY code=%s mode=%s'):format(
    D.detectorVersion, G.hitMode() and 'hit' or 'rings'))
