lib.locale()

-- Active ambush state
local Active = nil  -- { id, peds = {}, horses = {}, blips = {}, looted = {}, started, wonAt }

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

local function groundAt(x, y, zGuess)
    for _, h in ipairs({ zGuess + 50.0, zGuess + 150.0, 1000.0 }) do
        local ok, z = GetGroundZFor_3dCoord(x, y, h, false)
        if ok then return z end
    end
    return zGuess
end

local function giveWeapon(ped, weapon)
    -- GIVE_WEAPON_TO_PED (RedM signature)
    Citizen.InvokeNative(0x5E3BDDBCB83F3D84, ped, joaat(weapon), 200, true, true, 1, false, 0.5, 1.0, 752097756, false, 0.0, false)
end

local function setupBandit(ped, gang, relHash, playerPed)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, relHash)
    giveWeapon(ped, gang.weapons[math.random(#gang.weapons)])

    -- combat tuning taken from ambush_odr_road_robbery.c / ambush_bnd_*.c
    SetPedAccuracy(ped, math.random(gang.accuracy[1], gang.accuracy[2]))
    SetPedShootRate(ped, math.random(gang.shootRate[1], gang.shootRate[2]))
    SetPedCombatAttributes(ped, 5, true)    -- ALWAYS_FIGHT
    SetPedCombatAttributes(ped, 46, true)   -- CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED
    SetPedCombatAttributes(ped, 58, true)   -- DISABLE_FLEE_FROM_COMBAT
    SetPedCombatMovement(ped, 2)            -- as ambush_bnd_cliff1.c
    SetPedConfigFlag(ped, 6, true)          -- DontInfluenceWantedLevel (as ambush_odr_road_robbery.c)
    SetPedKeepTask(ped, true)

    if Config.UseBlips then
        local blip = BlipAddForEntity(joaat('BLIP_STYLE_ENEMY'), ped) -- as ambush_*.c
        Active.blips[#Active.blips + 1] = blip
    end

    TaskCombatPed(ped, playerPed, 0, 0)
end

local function addLootTarget(ped)
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'rsg_ambush_loot',
            icon = 'fa-solid fa-hand',
            label = locale('loot_target'),
            distance = Config.LootDistance,
            canInteract = function(entity)
                return Active ~= nil and IsEntityDead(entity) and not Active.looted[entity] and not IsEntityDead(cache.ped)
            end,
            onSelect = function(data)
                if not Active or Active.looted[data.entity] or lib.progressActive() then return end
                local ped = data.entity
                if lib.progressBar({
                    duration = Config.LootTime,
                    label = locale('loot_progress'),
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, combat = true },
                    anim = { scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
                }) then
                    if not Active or not DoesEntityExist(ped) then return end
                    Active.looted[ped] = true
                    local ok = lib.callback.await('rsg-ambush:server:loot', false, Active.id, NetworkGetNetworkIdFromEntity(ped))
                    if not ok then
                        lib.notify({ title = locale('loot_title'), description = locale('loot_none'), type = 'inform' })
                    end
                end
            end
        }
    })
end

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
local function cleanup(silent)
    if not Active then return end
    for _, blip in ipairs(Active.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    for _, ped in ipairs(Active.peds) do
        if DoesEntityExist(ped) then
            exports.ox_target:removeLocalEntity(ped, 'rsg_ambush_loot')
            DeleteEntity(ped)
        end
    end
    for _, horse in ipairs(Active.horses) do
        if DoesEntityExist(horse) then DeleteEntity(horse) end
    end
    TriggerServerEvent('rsg-ambush:server:finish', Active.id)
    Active = nil
    if not silent then
        lib.notify({ title = locale('ambush_title'), description = locale('ambush_over'), type = 'inform' })
    end
end

---------------------------------------------------------------------
-- Spawn the ambush
---------------------------------------------------------------------
local function startAmbush(data)
    local gang = Config.Gangs[data.gang]
    if not gang then return end

    local playerPed = cache.ped
    local pCoords = GetEntityCoords(playerPed)
    local fwd = GetEntityForwardVector(IsPedOnMount(playerPed) and GetMount(playerPed) or playerPed)
    local dist = math.random(math.floor(Config.SpawnDistance.min), math.floor(Config.SpawnDistance.max)) + 0.0
    local centre = pCoords + fwd * dist

    local relHash = joaat(gang.relGroup)
    SetRelationshipBetweenGroups(6, relHash, joaat('PLAYER'))  -- HATE
    SetRelationshipBetweenGroups(6, joaat('PLAYER'), relHash)

    Active = { id = data.id, peds = {}, horses = {}, blips = {}, looted = {}, started = GetGameTimer() }

    local count = math.random(gang.count[1], gang.count[2])
    local netIds = {}

    for i = 1, count do
        local angle = (i / count) * 2.0 * math.pi
        local x = centre.x + math.cos(angle) * Config.SpawnSpread
        local y = centre.y + math.sin(angle) * Config.SpawnSpread
        local z = groundAt(x, y, centre.z)
        local heading = GetHeadingFromVector_2d(pCoords.x - x, pCoords.y - y)

        local model = loadModel(gang.models[math.random(#gang.models)])
        if model then
            local ped
            if math.random(1, 100) <= gang.mountedChance then
                local horseModel = loadModel(Config.Horses[math.random(#Config.Horses)])
                if horseModel then
                    local horse = CreatePed(horseModel, x, y, z, heading, true, true, false, false)
                    Citizen.InvokeNative(0x283978A15512B2FE, horse, true)
                    SetEntityAsMissionEntity(horse, true, true)
                    Active.horses[#Active.horses + 1] = horse
                    ped = CreatePedOnMount(horse, model, -1, true, true, false, false)
                    SetModelAsNoLongerNeeded(horseModel)
                end
            end
            if not ped or ped == 0 then
                ped = CreatePed(model, x, y, z, heading, true, true, false, false)
            end
            SetModelAsNoLongerNeeded(model)

            if ped and ped ~= 0 then
                Active.peds[#Active.peds + 1] = ped
                setupBandit(ped, gang, relHash, playerPed)
                addLootTarget(ped)
                local t = GetGameTimer() + 2000
                while not NetworkGetEntityIsNetworked(ped) and GetGameTimer() < t do Wait(10) end
                netIds[#netIds + 1] = NetworkGetNetworkIdFromEntity(ped)
            end
        end
    end

    if #Active.peds == 0 then cleanup(true) return end

    TriggerServerEvent('rsg-ambush:server:registerPeds', Active.id, netIds)
    lib.notify({ title = locale('ambush_title'), description = locale('ambush_start', locale('gang_' .. data.gang)), type = 'warning', duration = 7000 })
end

local function tryAmbush(force)
    if Active then return end
    local ped = cache.ped
    if IsEntityDead(ped) then return end
    if not force then
        if Config.RequireMounted and not IsPedOnMount(ped) then return end
        local mover = IsPedOnMount(ped) and GetMount(ped) or ped
        if GetEntitySpeed(mover) < Config.MinPlayerSpeed then return end
        if Config.BlockInTowns and inTown(GetEntityCoords(ped)) then return end
        local chance = Config.Debug and 100 or Config.TriggerChance
        if math.random(1, 100) > chance then return end
    end
    local data = lib.callback.await('rsg-ambush:server:requestAmbush', false)
    if data then startAmbush(data) end
end

---------------------------------------------------------------------
-- Threads
---------------------------------------------------------------------
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
        if Active then
            local ped = cache.ped
            local pCoords = GetEntityCoords(ped)
            local alive, far = 0, true
            for _, b in ipairs(Active.peds) do
                if DoesEntityExist(b) then
                    if not IsEntityDead(b) then alive = alive + 1 end
                    if #(pCoords - GetEntityCoords(b)) < Config.DespawnDistance then far = false end
                end
            end

            if alive == 0 and not Active.wonAt then
                Active.wonAt = GetGameTimer()
                for _, blip in ipairs(Active.blips) do
                    if DoesBlipExist(blip) then RemoveBlip(blip) end
                end
                Active.blips = {}
                lib.notify({ title = locale('ambush_title'), description = locale('ambush_won'), type = 'success' })
            end

            local now = GetGameTimer()
            if IsEntityDead(ped)
                or far
                or now - Active.started > Config.MaxDuration * 1000
                or (Active.wonAt and now - Active.wonAt > Config.CorpseTime * 1000) then
                cleanup(false)
            end
            Wait(1000)
        else
            Wait(3000)
        end
    end
end)

RegisterNetEvent('rsg-ambush:client:force', function()
    if Config.Debug then tryAmbush(true) end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() cleanup(true) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then cleanup(true) end
end)
