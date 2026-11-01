lib.locale()

local Core = exports['rsg-core']:GetCoreObject()
local G = TargetPractiseGeometry
local targets, pending, shots, totals, throttles = {}, {}, {}, {}, {}
local hitMarks, boardViewers, debugPlayers = {}, {}, {}
local VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
local nextId, storageHealthy = 1, true
local revision, lastSync = 0, {}
local mutationBusy = false
local weaponHashes = {}
local weaponKinds = {}
local weaponItems = {}
for name, label in pairs(Config.Weapons) do
    local hash = G.signedHash(GetHashKey(name))
    weaponHashes[hash] = label
    weaponItems[hash] = name:lower()
    weaponKinds[hash] = (Config.WeaponKinds and Config.WeaponKinds[name])
        or (name:find('BOW', 1, true) and 'arrow')
        or ((name:find('THROWN', 1, true) or name:find('KNIFE', 1, true)) and 'knife')
        or 'other'
end
print('[rsg-targetpractise] Server scoring loaded: code ' .. VERSION)

local function distanceBonus(distance)
    local options = Config.Scoring.distanceBonus
    if type(options) ~= 'table' then return 0 end
    local start = tonumber(options.startDistance) or 5.0
    local step = tonumber(options.step) or 5.0
    local pointsPerStep = tonumber(options.pointsPerStep) or 1
    local maximum = tonumber(options.maxBonus) or 20
    if distance <= start or step <= 0 or pointsPerStep <= 0 or maximum <= 0 then return 0 end
    local steps = math.floor((distance - start) / step)
    return math.min(steps * math.floor(pointsPerStep), math.floor(maximum))
end

local function notify(src, message, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('notify_title'), description = message, type = kind or 'inform', duration = 5000
    })
end

local function admin(src)
    return Core.Functions.HasPermission(src, Config.AdminPermission)
        or Core.Functions.HasPermission(src, 'god')
end

local function allow(src, action, delay)
    throttles[src] = throttles[src] or {}
    local now = GetGameTimer()
    local last = throttles[src][action]
    if last and now - last < delay then return false end
    throttles[src][action] = now
    return true
end

local function playerPosition(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function save()
    if not Config.PersistTargets then return true end
    if not storageHealthy then return false end
    local list = {}
    for _, target in pairs(targets) do list[#list + 1] = target end
    local ok, encoded = pcall(json.encode, { version = 1, nextId = nextId, targets = list })
    if not ok then
        print(('[rsg-targetpractise] Target JSON encoding failed: %s'):format(tostring(encoded)))
        return false
    end
    local resource = GetCurrentResourceName()
    local wrote, result = pcall(SaveResourceFile, resource, Config.StorageFile, encoded, #encoded)
    if not wrote then
        print(('[rsg-targetpractise] SaveResourceFile raised an error for %s/%s: %s'):format(
            resource, Config.StorageFile, tostring(result)))
        return false
    end
    -- Verify the actual persisted bytes instead of assuming a native return type.
    local readOK, saved = pcall(LoadResourceFile, resource, Config.StorageFile)
    if readOK and saved == encoded then return true end
    print(('[rsg-targetpractise] Save verification failed for %s/%s. Native returned %s (%s); read-back %s.'):format(
        resource, Config.StorageFile, tostring(result), type(result),
        readOK and (saved == nil and 'file missing' or 'contents differ') or 'raised an error'))
    return false
end

local function active(target)
    return target and (target.state == nil or target.state == 'active')
end

local function integer(value)
    return G.finite(value) and value >= 1 and value % 1 == 0
end

local function itemValid()
    return type(Config.Item) == 'string' and Core.Shared.Items[Config.Item] ~= nil
end

local function itemReady(src)
    if not itemValid() then notify(src, locale('invalid_item'), 'error') return false end
    if not Config.PersistTargets then notify(src, locale('persistence_required'), 'error') return false end
    return true
end

local function hasTargetItem(src)
    if not itemReady(src) then return false end
    local item = exports['rsg-inventory']:GetItemByName(src, Config.Item)
    if not item or not integer(item.amount) then
        notify(src, locale('item_missing'), 'error')
        return false
    end
    return true
end

local function quarantine(id, reason)
    storageHealthy = false
    print(('[rsg-targetpractise] TRANSACTIONS DISABLED: target #%s: %s. Reconcile inventory and JSON while stopped; do not auto-refund or blindly reactivate pending records.'):format(
        tostring(id), reason))
end

local function transaction(src, callback)
    if not Core.Functions.GetPlayer(src) then return end
    if not storageHealthy then return notify(src, locale('storage_error'), 'error') end
    if mutationBusy then return notify(src, locale('transaction_busy'), 'error') end
    mutationBusy = true
    local ok, err = xpcall(callback, debug.traceback)
    mutationBusy = false
    if not ok then
        quarantine('unknown', tostring(err))
        notify(src, locale('transaction_review'), 'error')
    end
end

local function load()
    if not Config.PersistTargets then return end
    local raw = LoadResourceFile(GetCurrentResourceName(), Config.StorageFile)
    local ok, data = pcall(json.decode, raw or '')
    if not ok or type(data) ~= 'table' or data.version ~= 1
        or type(data.targets) ~= 'table' or not G.finite(data.nextId)
        or data.nextId < 1 or data.nextId % 1 ~= 0 then
        storageHealthy = false
    else
        local loaded, count, highest = {}, 0, 0
        for _, target in pairs(data.targets) do
            count = count + 1
            if type(target) ~= 'table' or not G.finite(target.id) or target.id < 1
                or target.id % 1 ~= 0 or loaded[target.id] or not G.point(target.position)
                or not G.finite(target.heading) or type(target.owner) ~= 'string'
                or type(target.adminPlaced) ~= 'boolean' or not G.finite(target.bucket)
                or target.bucket < 0 or target.bucket % 1 ~= 0 or count > Config.Placement.maxTotal then
                storageHealthy = false
                break
            end
            if target.state ~= nil and target.state ~= 'active'
                and target.state ~= 'placing' and target.state ~= 'removing' then
                storageHealthy = false
                break
            end
            loaded[target.id] = target
            highest = math.max(highest, target.id)
        end
        if storageHealthy then
            targets, nextId = loaded, math.max(data.nextId, highest + 1)
            for id, target in pairs(targets) do
                if not active(target) then quarantine(id, 'unfinished ' .. target.state .. ' transaction at startup') end
            end
        end
    end
    if not storageHealthy then
        print('[rsg-targetpractise] Invalid/missing storage or pending transaction. Item mutations disabled; review data/targets.json and transaction logs before restarting.')
    end
end

local function sync(src)
    local visible = {}
    local bucket = GetPlayerRoutingBucket(src)
    local player = Core.Functions.GetPlayer(src)
    local citizenid = player and player.PlayerData.citizenid
    local isAdmin = player ~= nil and admin(src)
    for _, target in pairs(targets) do
        if active(target) and target.bucket == bucket then
            -- Only send what the client needs; never leak owner citizen IDs.
            visible[#visible + 1] = {
                id = target.id, position = target.position, heading = target.heading,
                canRemove = isAdmin or (citizenid ~= nil and target.owner == citizenid)
            }
        end
    end
    lastSync[src] = revision .. ':' .. bucket
    TriggerClientEvent('rsg-targetpractise:client:sync', src, visible)
end

-- Targets changed: bump the revision and push to everyone.
local function broadcast()
    revision = revision + 1
    for _, id in ipairs(GetPlayers()) do sync(tonumber(id)) end
end

local function sendLeaderboard(src)
    local player = Core.Functions.GetPlayer(src)
    if not player then boardViewers[src] = nil return end
    local online = {}
    for _, id in ipairs(GetPlayers()) do
        local other = Core.Functions.GetPlayer(tonumber(id))
        if other then
            online[other.PlayerData.citizenid] = TargetPractiseLeaderboard.name(other.PlayerData.charinfo)
        end
    end
    local rows, records = TargetPractiseLeaderboard.build(totals, online, player.PlayerData.citizenid)
    TriggerClientEvent('rsg-targetpractise:client:leaderboard', src, {
        rows = rows,
        records = records,
        face = {
            bullseyeRadius = Config.Scoring.bullseyeRadius or 0,
            rings = Config.Scoring.rings or {},
            marks = hitMarks[player.PlayerData.citizenid] or {}
        },
        scope = locale('ui_session'),
        refreshMs = Config.LeaderboardRefreshMs
    })
end

RegisterNetEvent('rsg-targetpractise:server:leaderboard', function(open)
    local src = source
    if open == false then boardViewers[src] = nil return end
    if open ~= true or not allow(src, 'leaderboard', 1000) then return end
    if not Core.Functions.GetPlayer(src) then return end
    boardViewers[src] = true
    sendLeaderboard(src)
end)

local function beginPlacement(src, isAdmin)
    local player = Core.Functions.GetPlayer(src)
    if not player or not allow(src, 'begin', 1000) then return end
    if not storageHealthy then return notify(src, locale('storage_error'), 'error') end
    if pending[src] and pending[src].expires > os.time() then
        return notify(src, locale('placement_pending'), 'error')
    end
    if isAdmin and not admin(src) then return end
    if not isAdmin and not hasTargetItem(src) then return end
    pending[src] = {
        admin = isAdmin, owner = player.PlayerData.citizenid,
        bucket = GetPlayerRoutingBucket(src),
        expires = os.time() + Config.Placement.timeoutSeconds
    }
    TriggerClientEvent('rsg-targetpractise:client:place', src)
end

Core.Functions.CreateUseableItem(Config.Item, function(src) beginPlacement(src, false) end)
Core.Commands.Add('admintarget', locale('command_admin'), {}, false, function(src)
    if src > 0 then beginPlacement(src, true) end
end, Config.AdminPermission)

RegisterNetEvent('rsg-targetpractise:server:cancel', function()
    if Core.Functions.GetPlayer(source) then pending[source] = nil end
end)

RegisterNetEvent('rsg-targetpractise:server:place', function(position, heading)
    local src = source
    local player = Core.Functions.GetPlayer(src)
    if not player then return end
    local request = pending[src]
    pending[src] = nil
    if not request or request.expires < os.time() then return end
    if not allow(src, 'place', 1000) then return end
    if not G.point(position) or not G.finite(heading) then return end
    local current = playerPosition(src)
    local bucket = GetPlayerRoutingBucket(src)
    if request.owner ~= player.PlayerData.citizenid or request.bucket ~= bucket
        or (request.admin and not admin(src)) or not current
        or G.distance(current, position) > Config.Placement.maxDistance then
        return notify(src, locale('placement_rejected'), 'error')
    end
    local count, own = 0, 0
    for _, target in pairs(targets) do
        count = count + 1
        if target.owner == request.owner then own = own + 1 end
        if target.bucket == bucket and G.distance(position, target.position) < Config.Placement.minimumSpacing then
            return notify(src, locale('placement_spacing'), 'error')
        end
    end
    if count >= Config.Placement.maxTotal or own >= Config.Placement.maxPerPlayer then
        return notify(src, locale('placement_limit'), 'error')
    end
    transaction(src, function()
        if not request.admin and not hasTargetItem(src) then return end
        local id = nextId
        nextId = nextId + 1
        local target = {
            id = id, owner = request.owner, bucket = bucket, adminPlaced = request.admin,
            position = { x = position.x, y = position.y, z = position.z },
            heading = heading % 360, state = request.admin and 'active' or 'placing'
        }
        targets[id] = target
        -- Durable intent BEFORE inventory mutation. Never refund an uncertain debit.
        if not save() then
            target.state = 'placing'
            quarantine(id, 'placement intent could not be verified; inventory was not changed')
            return notify(src, locale('transaction_review'), 'error')
        end
        if not request.admin then
            local removed = exports['rsg-inventory']:RemoveItem(src, Config.Item, 1, nil, 'rsg-targetpractise-place')
            if removed ~= true then
                targets[id] = nil
                if not save() then
                    targets[id] = target
                    quarantine(id, 'failed item debit cleanup could not be verified')
                end
                return notify(src, locale('item_missing'), 'error')
            end
            target.state = 'active'
            if not save() then
                target.state = 'placing'
                quarantine(id, 'placement finalization failed after item debit; no automatic refund')
                return notify(src, locale('transaction_review'), 'error')
            end
        end
        broadcast()
        notify(src, locale('target_placed', id), 'success')
    end)
end)

CreateThread(function()
    while true do
        Wait(next(boardViewers) and Config.LeaderboardRefreshMs or 1000)
        for src in pairs(boardViewers) do sendLeaderboard(src) end
    end
end)

RegisterNetEvent('rsg-targetpractise:server:remove', function(id)
    local src = source
    local player = Core.Functions.GetPlayer(src)
    if not player then return end
    if not allow(src, 'remove', 1000) or not integer(id) then return end
    local target, position = targets[id], playerPosition(src)
    if not active(target) or not position or target.bucket ~= GetPlayerRoutingBucket(src)
        or G.distance(position, target.position) > Config.RemoveDistance + 0.5 then return end
    if target.owner ~= player.PlayerData.citizenid and not admin(src) then
        return notify(src, locale('removal_denied'), 'error')
    end
    transaction(src, function()
        if not target.adminPlaced then
            if not itemReady(src) then return end
            if exports['rsg-inventory']:CanAddItem(src, Config.Item, 1) ~= true then
                return notify(src, locale('inventory_full'), 'error')
            end
        end
        target.state = 'removing'
        -- A durable tombstone precedes item credit, blocking duplicate claims.
        if not save() then
            quarantine(id, 'pickup intent could not be verified; no item awarded')
            broadcast()
            return notify(src, locale('transaction_review'), 'error')
        end
        broadcast()
        if not target.adminPlaced then
            local added = exports['rsg-inventory']:AddItem(src, Config.Item, 1, nil, nil, 'rsg-targetpractise-pickup')
            if added ~= true then
                target.state = 'active'
                if not save() then
                    target.state = 'removing'
                    quarantine(id, 'failed item credit rollback could not be verified')
                end
                broadcast()
                return notify(src, locale('inventory_full'), 'error')
            end
        end
        targets[id] = nil
        if not save() then
            targets[id] = target
            quarantine(id, 'pickup finalization failed; never retry credit without reconciliation')
            return notify(src, locale('transaction_review'), 'error')
        end
        broadcast()
        notify(src, target.adminPlaced and locale('admin_removed') or locale('target_packed'), 'success')
    end)
end)

RegisterNetEvent('rsg-targetpractise:server:sync', function()
    local src = source
    if allow(src, 'sync', 2000) then sync(src) end
end)

RegisterNetEvent('rsg-targetpractise:server:diagnostic', function()
    local src = source
    if not Core.Functions.GetPlayer(src) or not allow(src, 'diagnostic', 1000) then return end
    local count, bucket = 0, GetPlayerRoutingBucket(src)
    for _, target in pairs(targets) do
        if active(target) and target.bucket == bucket then count = count + 1 end
    end
    TriggerClientEvent('rsg-targetpractise:client:diagnosticServer', src, {
        code = VERSION, version = VERSION,
        targets = count, bucket = bucket, storage = storageHealthy,
        mode = G.hitMode() and 'hit' or 'rings'
    })
end)

RegisterNetEvent('rsg-targetpractise:server:shot', function(sequence, weapon)
    local src = source
    weapon = G.signedHash(weapon)
    if not integer(sequence) or not weapon or not weaponHashes[weapon] or not allow(src, 'shot', Config.Scoring.shotCooldownMs) then return end
    local player, position = Core.Functions.GetPlayer(src), playerPosition(src)
    if not player or not position then return end
    if Config.RequireWeaponItem and not exports['rsg-inventory']:HasItem(src, weaponItems[weapon], 1) then return end
    shots[src] = {
        sequence = sequence, weapon = weapon, time = GetGameTimer(), position = position,
        owner = player.PlayerData.citizenid, bucket = GetPlayerRoutingBucket(src)
    }
end)

local function rejectScore(src, reason)
    if debugPlayers[src] or Config.Debug then
        TriggerClientEvent('rsg-targetpractise:client:scoreRejected', src, reason)
    end
end

RegisterNetEvent('rsg-targetpractise:server:hit', function(sequence, id, impact)
    local src = source
    if not allow(src, 'hit', 100) or not integer(sequence) or not integer(id) or not G.point(impact) then
        return rejectScore(src, 'invalid hit arguments or hit cooldown')
    end
    local shot, target, player = shots[src], targets[id], Core.Functions.GetPlayer(src)
    if not shot or not active(target) or not player or shot.sequence ~= sequence then
        return rejectScore(src, 'missing/consumed shot, missing active target, or wrong shot sequence')
    end
    shots[src] = nil -- Consume once, including rejected geometry; no retry/replay scoring.
    local now = GetGameTimer()
    if now - shot.time > Config.Scoring.shotWindowMs
        or shot.owner ~= player.PlayerData.citizenid
        or shot.bucket ~= target.bucket or shot.bucket ~= GetPlayerRoutingBucket(src) then
        return rejectScore(src, 'shot expired or player/routing bucket changed')
    end
    local hitMode = G.hitMode()
    local center = hitMode and G.pose(target) or G.faceWorld(target, Config.Scoring.center)
    local range = G.distance(shot.position, center)
    if range > Config.Scoring.maxDistance then
        return rejectScore(src, ('shot exceeds maximum sanity range: %.2fm > %.2fm'):format(range, Config.Scoring.maxDistance))
    end
    if not hitMode and range < Config.Scoring.minDistance then
        return rejectScore(src, ('ring-mode shot is too close: %.2fm < %.2fm'):format(range, Config.Scoring.minDistance))
    end
    local localPoint = G.faceLocal(target, impact)
    local points, radius, bullseye
    local bonus = 0
    local weaponKind = weaponKinds[shot.weapon] or 'other'
    if hitMode then
        if not G.hitInBounds(target, impact) then
            return rejectScore(src, 'reported impact is outside the broad target-object sanity bound')
        end
        points = 1 -- Server-fixed; never accept client-supplied points.
        bullseye = false
    else
        local base
        base, radius, bullseye = G.score(localPoint)
        if base then
            bonus = distanceBonus(range)
            points = base + bonus
        end
    end
    if not points then
        return rejectScore(src, ('outside rings/depth: local x=%.4f y=%.4f z=%.4f'):format(localPoint.x, localPoint.y, localPoint.z))
    end
    local citizenid = player.PlayerData.citizenid
    local total = totals[citizenid] or {
        points = 0, hits = 0, best = 0, bullseyes = 0, arrows = 0, knives = 0,
        arrowDistance = 0, knifeDistance = 0
    }
    total.points, total.hits = total.points + points, total.hits + 1
    total.bullseyes = (total.bullseyes or 0) + (bullseye and 1 or 0)
    if weaponKind == 'arrow' then
        total.arrows = (total.arrows or 0) + 1
        total.arrowDistance = math.max(total.arrowDistance or 0, range)
    elseif weaponKind == 'knife' then
        total.knives = (total.knives or 0) + 1
        total.knifeDistance = math.max(total.knifeDistance or 0, range)
    end
    total.name = TargetPractiseLeaderboard.name(player.PlayerData.charinfo)
    total.best = math.max(total.best or 0, points)
    totals[citizenid] = total
    if not hitMode then
        local marks = hitMarks[citizenid]
        if not marks then marks = {} hitMarks[citizenid] = marks end
        marks[#marks + 1] = {
            x = localPoint.x - Config.Scoring.center.x,
            z = localPoint.z - Config.Scoring.center.z,
            points = points, bonus = bonus,
            distance = math.floor(range * 10 + 0.5) / 10,
            bullseye = bullseye == true, weaponKind = weaponKind
        }
        if #marks > 80 then table.remove(marks, 1) end
    end
    TriggerClientEvent('rsg-targetpractise:client:scored', src, points, radius or 0, total, impact,
        hitMode and 'hit' or 'rings', bullseye == true, weaponKind, weaponHashes[shot.weapon],
        range, bonus)
    -- Local server event only. Never RegisterNetEvent this integration hook.
    TriggerEvent('rsg-targetpractise:server:acceptedHit', {
        source = src, citizenid = citizenid, name = player.PlayerData.charinfo,
        targetId = id, weapon = shot.weapon, weaponKind = weaponKind, points = points, radius = radius,
        bullseye = bullseye == true, distance = range, distanceBonus = bonus, timestamp = os.time(),
        impact = impact, scoringMode = hitMode and 'hit' or 'rings'
    })
end)

Core.Commands.Add('targetdebug', locale('command_debug'), {}, false, function(src)
    if src > 0 and admin(src) then
        local previous = debugPlayers[src]
        if previous == nil then previous = Config.Debug end
        debugPlayers[src] = not previous
        TriggerClientEvent('rsg-targetpractise:client:debug', src, debugPlayers[src])
    end
end, Config.AdminPermission)

Core.Commands.Add('targetscore', locale('command_score'), {}, false, function(src)
    local player = Core.Functions.GetPlayer(src)
    if not player or not allow(src, 'score', 1000) then return end
    local total = totals[player.PlayerData.citizenid] or { points = 0, hits = 0, bullseyes = 0 }
    notify(src, locale('session_total', total.points, total.hits, total.bullseyes or 0))
end, 'user')

AddEventHandler('playerDropped', function()
    local src = source
    pending[src], shots[src], throttles[src] = nil, nil, nil
    boardViewers[src], debugPlayers[src], lastSync[src] = nil, nil, nil
end)

load()
CreateThread(function()
    while true do
        Wait(5000)
        -- Only resync players whose routing bucket changed (or who missed the last revision).
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if lastSync[src] ~= revision .. ':' .. GetPlayerRoutingBucket(src) then sync(src) end
        end
        for src, request in pairs(pending) do
            if request.expires < os.time() then pending[src] = nil end
        end
    end
end)
