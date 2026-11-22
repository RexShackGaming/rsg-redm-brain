local RSGCore = exports['rsg-core']:GetCoreObject()

local PLAYER_GROUP = joaat('PLAYER')

-- Active ambush state
-- { id, gangDef, peds = {}, horses = {}, info = { [ped] = {...} }, blips = { [ped] = blip }, looted = {},
--   started, wonAt, diedAt, spawning, rel, wave = { count, delay, done } }
local Active = nil
local Searching = false

local function notify(desc, ntype, title, duration)
    RSGCore.Functions.Notify({ title = title or locale('ambush_title'), description = desc, type = ntype, duration = duration or 5000 })
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function inTown(coords)
    -- ZONE::_GET_MAP_ZONE_AT_COORDS (seen in decompiled scripts), type 1 = town
    local zone = Citizen.InvokeNative(0x43AD8FC02B429D33, coords.x, coords.y, coords.z, 1)
    return zone and zone ~= 0 and zone ~= false
end

-- Ground height at x,y if the point is somewhere bandits should stand: not water, not too steep, not inside an
-- interior. Returns nil when the point is unsafe (or no ground was found). `relaxed` allows steeper ground (snipers).
local function safeGround(x, y, zGuess, relaxed)
    local checks = Config.SpawnChecks
    for _, h in ipairs({ zGuess + 50.0, zGuess + 150.0, 1000.0 }) do
        local found, gz, normal = GetGroundZAndNormalFor_3dCoord(x, y, h)
        if found then
            local minNormal = relaxed and math.min(0.6, checks.MinNormalZ) or checks.MinNormalZ
            if normal and normal.z < minNormal then return nil end
            local water, waterZ = GetWaterHeight(x, y, gz)
            if water and waterZ - gz > checks.MaxWaterDepth then return nil end
            if checks.AvoidInteriors and GetInteriorAtCoords(x, y, gz + 1.0) ~= 0 then return nil end
            return gz
        end
    end
    return nil
end

-- Deletes entities. Control of every networked entity is requested first and waited for once (not
-- once per entity), then everything is deleted. `immediate` skips the wait (resource stop).
local function deleteEntities(list, immediate)
    local pending = {}
    for _, ent in ipairs(list) do
        if DoesEntityExist(ent) and NetworkGetEntityIsNetworked(ent) and not NetworkHasControlOfEntity(ent) then
            NetworkRequestControlOfEntity(ent)
            pending[#pending + 1] = ent
        end
    end
    if not immediate and #pending > 0 then
        local deadline = GetGameTimer() + 1000
        while GetGameTimer() < deadline do
            local waiting = false
            for _, ent in ipairs(pending) do
                if DoesEntityExist(ent) and not NetworkHasControlOfEntity(ent) then waiting = true break end
            end
            if not waiting then break end
            Wait(25)
        end
    end
    for _, ent in ipairs(list) do
        if DoesEntityExist(ent) then
            SetEntityAsMissionEntity(ent, true, true)
            DeleteEntity(ent)
        end
    end
end

local function giveWeapon(ped, weapon)
    -- GIVE_WEAPON_TO_PED (RedM signature)
    Citizen.InvokeNative(0x5E3BDDBCB83F3D84, ped, joaat(weapon), 200, true, true, 1, false, 0.5, 1.0, 752097756, false, 0.0, false)
end

local function removeBlip(amb, ped)
    local blip = amb.blips[ped]
    if not blip then return end
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    amb.blips[ped] = nil
end

local function playWarning()
    local s = Config.WarningSound
    if type(s) ~= 'table' or not s.name or not s.ref then return end
    Citizen.InvokeNative(0x0F2A2175734926D8, s.name, s.ref) -- load the frontend sound (as in the rdr3_discoveries example)
    PlaySoundFrontend(s.name, s.ref, true, 0)
end

local function forwardOf(ped)
    return GetEntityForwardVector(IsPedOnMount(ped) and GetMount(ped) or ped)
end

---------------------------------------------------------------------
-- Bandit reactions
---------------------------------------------------------------------
local function lowHealth(ped)
    local max = GetPedMaxHealth(ped)
    return max > 0 and (GetEntityHealth(ped) / max) <= Config.LowHealth
end

local function beginFlee(amb, ped, info, playerPed)
    info.out, info.fleeing = true, true
    removeBlip(amb, ped)
    SetPedCombatAttributes(ped, 58, false) -- allow fleeing again
    SetPedCombatAttributes(ped, 17, true)  -- ALWAYS_FLEE
    TaskSmartFleePed(ped, playerPed, 150.0, -1, 0, 3.0, 0)
end

local function beginSurrender(amb, ped, info, playerPed, now)
    info.out, info.surrenderedAt = true, now
    removeBlip(amb, ped)
    RemoveAllPedWeapons(ped, true, true)
    TaskHandsUp(ped, Config.SurrenderTime * 1000, playerPed, -1, 0)
end

local function setupBandit(amb, ped, gang, relHash, playerPed, role)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, relHash)
    giveWeapon(ped, role == 'sniper' and gang.sniper.weapon or gang.weapons[math.random(#gang.weapons)])

    -- combat tuning taken from ambush_odr_road_robbery.c / ambush_bnd_*.c
    SetPedAccuracy(ped, math.random(gang.accuracy[1], gang.accuracy[2]))
    SetPedShootRate(ped, math.random(gang.shootRate[1], gang.shootRate[2]))
    SetPedCombatAttributes(ped, 5, true)    -- ALWAYS_FIGHT
    SetPedCombatAttributes(ped, 46, true)   -- CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED
    SetPedCombatAttributes(ped, 58, true)   -- DISABLE_FLEE_FROM_COMBAT
    if role == 'sniper' then
        SetPedCombatMovement(ped, 0)        -- stationary: holds the high ground
        SetPedCombatRange(ped, 3)           -- very far
    else
        SetPedCombatMovement(ped, 2)        -- as ambush_bnd_cliff1.c
    end
    SetPedConfigFlag(ped, 6, true)          -- DontInfluenceWantedLevel (as ambush_odr_road_robbery.c)
    SetPedKeepTask(ped, true)

    -- how this bandit reacts when badly hurt (snipers always hold their ground)
    local info = { role = role }
    if role ~= 'sniper' then
        local roll = math.random(1, 100)
        local surrender, flee = gang.surrenderChance or 0, gang.fleeChance or 0
        if roll <= surrender then info.reaction = 'surrender'
        elseif roll <= surrender + flee then info.reaction = 'flee' end
    end
    amb.info[ped] = info

    if Config.UseBlips then
        amb.blips[ped] = BlipAddForEntity(joaat('BLIP_STYLE_ENEMY'), ped) -- as ambush_*.c
    end

    TaskCombatPed(ped, playerPed, 0, 0)
end

local function addLootTarget(ped)
    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = 'rsg_ambush_loot',
            icon = 'fa-solid fa-hand',
            label = locale('loot_target'),
            distance = Config.LootDistance,
            canInteract = function(entity)
                return Active ~= nil and IsEntityDead(entity) and not Active.looted[entity] and not Searching and not IsEntityDead(PlayerPedId())
            end,
            onSelect = function(data)
                local amb, body = Active, data.entity
                if not amb or amb.looted[body] or Searching then return end
                Searching = true
                local done = RSGCore.Functions.ProgressBar({
                    duration = Config.LootTime,
                    label = locale('loot_progress'),
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, combat = true },
                    anim = { scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
                })
                if done and Active == amb and DoesEntityExist(body) and not amb.looted[body] then
                    local result = RSGCore.Functions.AwaitCallback('rsg-ambush:server:loot', 10000, amb.id, NetworkGetNetworkIdFromEntity(body))
                    if Active == amb then
                        if result then amb.looted[body] = true end -- only lock the body once the server accepted it
                        if result == 'empty' then
                            notify(locale('loot_none'), 'inform', locale('loot_title'))
                        elseif not result then
                            notify(locale('loot_failed'), 'error', locale('loot_title'))
                        end
                    end
                end
                Searching = false
            end
        }
    })
end

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
-- State is cleared first, then the entities are deleted from a local snapshot: deleting can yield, and
-- the monitor thread, OnPlayerUnload and onResourceStop must not be able to re-enter half way through.
-- `aborted` tells the server the gang never got placed, so the player's cooldown is not used up.
local function cleanup(silent, immediate, aborted)
    local amb = Active
    if not amb then return end
    Active, Searching = nil, false

    for ped in pairs(amb.blips) do removeBlip(amb, ped) end

    local entities = {}
    for _, ped in ipairs(amb.peds) do
        if DoesEntityExist(ped) then
            exports['rsg-target']:removeLocalEntity(ped, 'rsg_ambush_loot')
            entities[#entities + 1] = ped
        end
    end
    for _, horse in ipairs(amb.horses) do entities[#entities + 1] = horse end
    deleteEntities(entities, immediate)

    -- put the gang <-> player relationship back the way it was before the ambush
    local rel = amb.rel
    if rel then
        SetRelationshipBetweenGroups(rel.toPlayer, rel.group, PLAYER_GROUP)
        SetRelationshipBetweenGroups(rel.fromPlayer, PLAYER_GROUP, rel.group)
    end

    TriggerServerEvent('rsg-ambush:server:finish', amb.id, aborted == true)
    if not silent then notify(locale('ambush_over'), 'inform') end
end

---------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------
-- A safe centre for a group, ahead of the player (or behind for reinforcements). Several tries, sideways each time.
local function pickCentre(pCoords, fwd, behind)
    local right = vector3(fwd.y, -fwd.x, 0.0)
    for attempt = 1, Config.SpawnChecks.Attempts do
        local dist = math.random(math.floor(Config.SpawnDistance.min), math.floor(Config.SpawnDistance.max)) + 0.0
        local lateral = attempt == 1 and 0.0 or (math.random() * 2.0 - 1.0) * 35.0
        local base = behind and (pCoords - fwd * dist) or (pCoords + fwd * dist)
        local x, y = base.x + right.x * lateral, base.y + right.y * lateral
        local z = safeGround(x, y, pCoords.z)
        if z then return vector3(x, y, z) end
    end
    return nil
end

-- the highest safe point 40-70 m from the centre, at least a few metres above it (for the sniper)
local function findHighGround(centre)
    local bx, by, bz
    for _ = 1, 10 do
        local a = math.random() * 2.0 * math.pi
        local r = 40.0 + math.random() * 30.0
        local x, y = centre.x + math.cos(a) * r, centre.y + math.sin(a) * r
        local z = safeGround(x, y, centre.z, true)
        if z and z > centre.z + 3.0 and (not bz or z > bz) then bx, by, bz = x, y, z end
    end
    return bx, by, bz
end

-- Spawns one bandit (optionally mounted). Everything created is added to the ambush straight away so
-- cleanup always sees it. Returns nothing when the ambush was cancelled or the model failed to load.
local function spawnBandit(amb, gang, relHash, playerPed, x, y, z, heading, role)
    local model = loadModel(gang.models[math.random(#gang.models)])
    if not model or Active ~= amb then return end

    local ped, horse
    if role ~= 'sniper' and #Config.Horses > 0 and math.random(1, 100) <= gang.mountedChance then
        local horseModel = loadModel(Config.Horses[math.random(#Config.Horses)])
        if Active ~= amb then return end
        if horseModel then
            horse = CreatePed(horseModel, x, y, z, heading, true, true, false, false)
            SetModelAsNoLongerNeeded(horseModel)
            if horse and horse ~= 0 then
                Citizen.InvokeNative(0x283978A15512B2FE, horse, true)
                SetEntityAsMissionEntity(horse, true, true)
                amb.horses[#amb.horses + 1] = horse
                ped = CreatePedOnMount(horse, model, -1, true, true, false, false)
            end
        end
    end
    if not ped or ped == 0 then
        if horse and horse ~= 0 then -- rider failed: don't leave a riderless horse standing there
            DeleteEntity(horse)
            amb.horses[#amb.horses] = nil
        end
        ped = CreatePed(model, x, y, z, heading, true, true, false, false)
    end
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then return end

    amb.peds[#amb.peds + 1] = ped
    setupBandit(amb, ped, gang, relHash, playerPed, role)
    addLootTarget(ped)
end

-- Places `count` bandits around `centre`. Each one gets a safe point of its own (a few tries around the ring); a
-- bandit with no safe point is skipped. The last one may become the sniper on high ground.
local function spawnGroup(amb, gang, count, centre, pCoords, playerPed, relHash, allowSniper)
    local sniperSlot = (allowSniper and gang.sniper and math.random(1, 100) <= (gang.sniper.chance or 0)) and count or nil
    for i = 1, count do
        if Active ~= amb then return end
        local x, y, z, role
        if i == sniperSlot then
            x, y, z = findHighGround(centre)
            if x then role = 'sniper' end
        end
        if not x then
            local angle = (i / count) * 2.0 * math.pi
            for attempt = 1, 3 do
                local spread = Config.SpawnSpread * (1.0 + (attempt - 1) * 0.5)
                local a = angle + (attempt - 1) * 0.6
                local px, py = centre.x + math.cos(a) * spread, centre.y + math.sin(a) * spread
                local pz = safeGround(px, py, centre.z)
                if pz then x, y, z = px, py, pz break end
            end
        end
        if x then
            local heading = GetHeadingFromVector_2d(pCoords.x - x, pCoords.y - y)
            spawnBandit(amb, gang, relHash, playerPed, x, y, z, heading, role)
        end
    end
end

-- network ids (from list index `from`) of the entities that are, or become within the deadline, networked
local function collectNetIds(list, deadline, from)
    local ids = {}
    for i = from or 1, #list do
        local ent = list[i]
        while DoesEntityExist(ent) and not NetworkGetEntityIsNetworked(ent) and GetGameTimer() < deadline do Wait(10) end
        if DoesEntityExist(ent) and NetworkGetEntityIsNetworked(ent) then ids[#ids + 1] = NetworkGetNetworkIdFromEntity(ent) end
    end
    return ids
end

-- the second group rides in from behind the player
local function spawnReinforcements(amb)
    notify(locale('ambush_reinforcements'), 'warning', nil, 6000)
    playWarning()

    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)
    local startPed, startHorse = #amb.peds + 1, #amb.horses + 1
    local centre = pickCentre(pCoords, forwardOf(playerPed), true)
    if centre then
        spawnGroup(amb, amb.gangDef, amb.wave.count, centre, pCoords, playerPed, amb.rel.group, false)
    end
    if Active ~= amb then return end

    local deadline = GetGameTimer() + 3000
    local pedIds = collectNetIds(amb.peds, deadline, startPed)
    local horseIds = collectNetIds(amb.horses, deadline, startHorse)
    if Active ~= amb then return end

    amb.spawning = false
    TriggerServerEvent('rsg-ambush:server:registerPeds', amb.id, pedIds, horseIds, 2)
end

local function startAmbush(data)
    local gang = Config.Gangs[data.gang]
    if not gang or Active then
        TriggerServerEvent('rsg-ambush:server:finish', data.id, true) -- tell the server we won't run it
        return
    end

    local relHash = joaat(gang.relGroup)
    -- `spawning` keeps the monitor thread away until every bandit exists
    local amb = {
        id = data.id, gangDef = gang, peds = {}, horses = {}, info = {}, blips = {}, looted = {},
        started = GetGameTimer(), spawning = true,
        wave = data.wave and { count = data.wave.count, delay = data.wave.delay, done = false } or nil,
        rel = {
            group = relHash,
            toPlayer = GetRelationshipBetweenGroups(relHash, PLAYER_GROUP),
            fromPlayer = GetRelationshipBetweenGroups(PLAYER_GROUP, relHash),
        },
    }
    Active = amb

    -- a warning first: a sound and a notice, then a few seconds to react before the bandits show up
    local warning = tonumber(Config.WarningSeconds) or 0
    if warning > 0 then
        notify(locale('ambush_warning'), 'warning', nil, warning * 1000 + 2000)
        playWarning()
        Wait(warning * 1000)
        if Active ~= amb then return end
    end

    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)
    local centre = pickCentre(pCoords, forwardOf(playerPed), false)
    if not centre then cleanup(true, false, true) return end -- nowhere safe to place them

    SetRelationshipBetweenGroups(6, relHash, PLAYER_GROUP)  -- HATE
    SetRelationshipBetweenGroups(6, PLAYER_GROUP, relHash)

    local count = math.max(1, math.min(12, math.floor(tonumber(data.count) or math.random(gang.count[1], gang.count[2]))))
    spawnGroup(amb, gang, count, centre, pCoords, playerPed, relHash, true)
    if Active ~= amb then return end

    if #amb.peds == 0 then cleanup(true, false, true) return end

    local deadline = GetGameTimer() + 3000
    local pedIds = collectNetIds(amb.peds, deadline)
    local horseIds = collectNetIds(amb.horses, deadline)
    if Active ~= amb then return end

    amb.spawning = false
    TriggerServerEvent('rsg-ambush:server:registerPeds', amb.id, pedIds, horseIds, 1)
    notify(locale('ambush_start', locale('gang_' .. data.gang)), 'warning', nil, 7000)
end

local function tryAmbush(force)
    if Active then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    if not force then
        if not IsPlayerControlOn(PlayerId()) then return end -- cutscene / scripted sequence
        if Config.RequireMounted and not IsPedOnMount(ped) then return end
        local mover = IsPedOnMount(ped) and GetMount(ped) or ped
        if GetEntitySpeed(mover) < Config.MinPlayerSpeed then return end
        if Config.BlockInTowns and inTown(GetEntityCoords(ped)) then return end
    end
    -- the server rolls the chance (honor, area and cooldown included) and answers with the gang
    local data = RSGCore.Functions.AwaitCallback('rsg-ambush:server:requestAmbush', 10000, force == true)
    if data then startAmbush(data) end
end

---------------------------------------------------------------------
-- Monitoring
---------------------------------------------------------------------
-- One look at one bandit; returns true while it still counts as a threat. Hurt bandits flee or surrender,
-- surrendered ones run once their time is up, fleeing ones that get far enough away have escaped.
local function tickBandit(amb, b, playerPed, dist, now, playerDead)
    if IsEntityDead(b) then
        removeBlip(amb, b)
        return false
    end
    local info = amb.info[b]
    if not info then return true end

    if info.out then
        if info.surrenderedAt and now - info.surrenderedAt > Config.SurrenderTime * 1000 then
            info.surrenderedAt = nil
            beginFlee(amb, b, info, playerPed)
        elseif info.fleeing and dist > Config.FleeEscapeDistance then
            exports['rsg-target']:removeLocalEntity(b, 'rsg_ambush_loot')
            deleteEntities({ b }, true)
        end
        return false
    end

    if playerDead then -- the player is down: the gang rides off
        beginFlee(amb, b, info, playerPed)
        return false
    end
    if info.reaction and lowHealth(b) then
        if info.reaction == 'surrender' then beginSurrender(amb, b, info, playerPed, now) else beginFlee(amb, b, info, playerPed) end
        return false
    end
    return true
end

-- roll for an ambush
CreateThread(function()
    while true do
        Wait(Config.CheckInterval * 1000)
        if LocalPlayer.state.isLoggedIn then tryAmbush(false) end
    end
end)

-- monitor an active ambush
CreateThread(function()
    while true do
        local amb = Active
        if amb and not amb.spawning then
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local now = GetGameTimer()
            local playerDead = IsEntityDead(ped)
            if playerDead and not amb.diedAt then amb.diedAt = now end

            local alive, far = 0, true
            for _, b in ipairs(amb.peds) do
                if DoesEntityExist(b) then
                    local dist = #(pCoords - GetEntityCoords(b))
                    if dist < Config.DespawnDistance then far = false end
                    if tickBandit(amb, b, ped, dist, now, playerDead) then alive = alive + 1 end
                end
            end

            local wave = amb.wave
            local elapsed = now - amb.started
            if wave and not wave.done and not playerDead
                and (elapsed >= wave.delay * 1000 or (alive <= 1 and elapsed >= 10000)) then
                -- reinforcements: the monitor stays out of the way until they exist
                wave.done = true
                amb.spawning = true
                CreateThread(function() spawnReinforcements(amb) end)
            elseif alive == 0 and not amb.wonAt and not amb.diedAt and not (wave and not wave.done) then
                amb.wonAt = now
                notify(locale('ambush_won'), 'success')
                TriggerServerEvent('rsg-ambush:server:claimWin', amb.id) -- the server checks the bodies and pays
            end

            if (amb.diedAt and now - amb.diedAt > Config.DeathCleanupDelay * 1000)
                or far
                or elapsed > Config.MaxDuration * 1000
                or (amb.wonAt and now - amb.wonAt > Config.CorpseTime * 1000) then
                cleanup(false)
            end
            Wait(1000)
        else
            Wait(amb and 500 or 3000)
        end
    end
end)

RegisterNetEvent('rsg-ambush:client:force', function()
    if Config.Debug then tryAmbush(true) end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() cleanup(true) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then cleanup(true, true) end
end)
