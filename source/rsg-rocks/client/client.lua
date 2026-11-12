local RSGCore = exports['rsg-core']:GetCoreObject()

local isBusy           = false
local zoneCooldowns    = {} -- [zoneId] = GetGameTimer end (personal, set by server)
local zoneDepleteUntil = {} -- [zoneId] = GetGameTimer end (global, set by server)
local spawnedObjects   = {}
local targetHandles    = {} -- [zoneId] = { kind = 'sphere'|'entity', handle|entity }
local MiningZones      = {}

local AttemptMine -- forward declaration

local function Notify(description, nType)
    RSGCore.Functions.Notify({
        title = locale('mining_title'),
        description = description,
        type = nType or 'inform',
        duration = Config.NotificationDuration,
    })
end

local function CanMine()
    local ped = PlayerPedId()
    return not (IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsPedFalling(ped)
        or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped))
end

-- returns ms until the rock can be mined again (0 = ready)
local function ZoneWaitTime(zoneId)
    local now = GetGameTimer()
    return math.max(0, (zoneDepleteUntil[zoneId] or 0) - now, (zoneCooldowns[zoneId] or 0) - now)
end

local function RemoveTarget(zoneId)
    local t = targetHandles[zoneId]
    if not t then return end
    if t.kind == 'sphere' then
        exports['rsg-target']:removeZone(t.handle)
    elseif DoesEntityExist(t.entity) then
        exports['rsg-target']:removeLocalEntity(t.entity)
    end
    targetHandles[zoneId] = nil
end

local function DespawnZone(zoneId)
    RemoveTarget(zoneId)
    local obj = spawnedObjects[zoneId]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    spawnedObjects[zoneId] = nil
end

local function DespawnAll()
    for id in pairs(targetHandles) do RemoveTarget(id) end
    for id in pairs(spawnedObjects) do DespawnZone(id) end
end

local function MineOption(zoneId, zone)
    return {
        name = 'rsg-rocks:mine:' .. zoneId,
        icon = 'fa-solid fa-hammer',
        label = locale('target_mine'),
        distance = math.max(zone.radius + 1.0, 2.5),
        canInteract = function() return not isBusy end,
        onSelect = function()
            local wait = ZoneWaitTime(zoneId)
            if wait > 0 then
                Notify(locale('cooldown_remaining', math.ceil(wait / 1000)), 'inform')
                return
            end
            AttemptMine(zoneId)
        end,
    }
end

local function SpawnZone(zoneId, zone)
    if targetHandles[zoneId] then return end

    if not Config.SpawnRockProps then
        local handle = exports['rsg-target']:addSphereZone({
            name = 'rsg-rocks:sphere:' .. zoneId,
            coords = zone.coords,
            radius = zone.radius,
            debug = Config.DebugTarget,
            options = { MineOption(zoneId, zone) },
        })
        if handle then targetHandles[zoneId] = { kind = 'sphere', handle = handle } end
        return
    end

    local modelHash = RSGCore.Functions.RequestModel(Config.RockModel)
    if not modelHash then return end
    local c = zone.coords
    local obj = CreateObject(modelHash, c.x, c.y, c.z - 1.5, false, false, false)
    if not DoesEntityExist(obj) then return end
    SetEntityHeading(obj, zone.heading or 0.0)
    FreezeEntityPosition(obj, true)
    spawnedObjects[zoneId] = obj
    exports['rsg-target']:addLocalEntity(obj, { MineOption(zoneId, zone) })
    targetHandles[zoneId] = { kind = 'entity', entity = obj }
end

-- only respawn zones that were removed or changed (admin edits no longer respawn every rock)
local function ApplyZoneList(list)
    if type(list) ~= 'table' then return end
    local now, new = GetGameTimer(), {}
    zoneDepleteUntil = {}
    for _, row in ipairs(list) do
        local id = tonumber(row.id)
        if id then
            new[id] = {
                coords = vector3(row.x, row.y, row.z),
                radius = tonumber(row.radius) or 2.0,
                heading = tonumber(row.heading) or 0.0,
                type = row.type,
            }
            local rem = tonumber(row.depleteRemaining) or 0
            if rem > 0 then zoneDepleteUntil[id] = now + rem end
        end
    end
    for id, old in pairs(MiningZones) do
        local n = new[id]
        if not n or n.coords ~= old.coords or n.radius ~= old.radius or n.heading ~= old.heading or n.type ~= old.type then
            DespawnZone(id)
        end
    end
    MiningZones = new
end

local function RequestZones()
    RSGCore.Functions.TriggerCallback('rsg-rocks:server:GetZones', function(list, cooldowns)
        ApplyZoneList(list)
        zoneCooldowns = {}
        local now = GetGameTimer()
        for _, c in ipairs(cooldowns or {}) do
            local id, ms = tonumber(c.id), tonumber(c.ms) or 0
            if id and ms > 0 then zoneCooldowns[id] = now + ms end
        end
    end)
end

RegisterNetEvent('rsg-rocks:client:SetZones', ApplyZoneList)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', RequestZones)

RegisterNetEvent('rsg-rocks:client:ZoneDepleted', function(zoneId, remainingMs)
    zoneId, remainingMs = tonumber(zoneId), tonumber(remainingMs) or 0
    if zoneId and remainingMs > 0 then zoneDepleteUntil[zoneId] = GetGameTimer() + remainingMs end
end)

RegisterNetEvent('rsg-rocks:client:SetCooldown', function(zoneId, remainingMs)
    zoneId, remainingMs = tonumber(zoneId), tonumber(remainingMs) or 0
    if zoneId and remainingMs > 0 then zoneCooldowns[zoneId] = GetGameTimer() + remainingMs end
end)

CreateThread(function()
    if LocalPlayer.state.isLoggedIn then RequestZones() end -- resource restart while in-game
end)

-- scenario-spawned pickaxe props can stay attached to the ped after the task ends
local function RemoveAttachedPickaxes(ped)
    local model = joaat(Config.PickaxeModel)
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == model and IsEntityAttachedToEntity(obj, ped) then
            SetEntityAsMissionEntity(obj, true, true)
            DeleteObject(obj)
        end
    end
end

-- has a pickaxe / has one that can still mine (quality above 0 when durability is on)
local function PickaxeState()
    local has = false
    for _, item in pairs((RSGCore.Functions.GetPlayerData() or {}).items or {}) do
        if item and item.name == Config.RequiredItem and (item.amount or 1) > 0 then
            has = true
            local quality = tonumber((item.info or {}).quality) or Config.PickaxeMaxQuality or 100
            if not Config.PickaxeDurability or quality > 0 then return true, true end
        end
    end
    return has, false
end

AttemptMine = function(zoneKey)
    if isBusy then
        Notify(locale('busy'), 'inform')
        return
    end
    if not CanMine() then return end
    -- client check is for UX only; the server re-checks the pickaxe on start and reward
    local hasPickaxe, usable = PickaxeState()
    if not usable then
        Notify(locale(hasPickaxe and 'pickaxe_worn' or 'no_pickaxe'), 'error')
        return
    end
    isBusy = true

    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    TriggerServerEvent('rsg-rocks:server:StartMining', zoneKey)

    local pickaxe
    if IsPedMale(ped) then
        TaskStartScenarioInPlace(ped, joaat(Config.MiningScenario), Config.MiningTime, true, false, false, false)
    else
        -- female peds have no pickaxe scenario: attach a prop and play the wall anim
        local modelHash = RSGCore.Functions.RequestModel(Config.PickaxeModel)
        if modelHash then
            local c = GetEntityCoords(ped)
            pickaxe = CreateObject(modelHash, c.x, c.y, c.z, true, true, false)
            AttachEntityToEntity(pickaxe, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Finger00'),
                -0.35, -0.21, -0.39, -8.0, 47.0, 11.0, true, false, true, false, 0, true)
            SetModelAsNoLongerNeeded(modelHash)
        end
        if RSGCore.Functions.RequestAnimDict(Config.MiningAnimDict) then
            TaskPlayAnim(ped, Config.MiningAnimDict, Config.MiningAnimClip, 3.0, 3.0, -1, 1, 0, false, false, false)
        end
    end

    local success = RSGCore.Functions.ProgressBar({
        duration = Config.MiningTime,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, mount = true, combat = true, mouse = false },
        label = locale('target_mine'),
    })

    ClearPedTasksImmediately(ped)
    if pickaxe and DoesEntityExist(pickaxe) then DeleteEntity(pickaxe) end
    RemoveAttachedPickaxes(ped)

    if success then
        TriggerServerEvent('rsg-rocks:server:MineReward', zoneKey)
    else
        TriggerServerEvent('rsg-rocks:server:CancelWork')
        Notify(locale('mining_cancelled'), 'warning')
    end
    isBusy = false
end

-- streaming loop: spawn props/targets near the player, clean up far/removed zones
CreateThread(function()
    local spawnDist = Config.RockSpawnDistance or 120.0
    local despawnDist = spawnDist + 10.0 -- hysteresis

    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearest = math.huge

        for id, rock in pairs(MiningZones) do
            local dist = #(playerCoords - rock.coords)
            if dist < nearest then nearest = dist end
            if dist < spawnDist then
                SpawnZone(id, rock)
            elseif dist > despawnDist and targetHandles[id] then
                DespawnZone(id)
            end
        end

        local hat = Config.MiningHat
        if hat and hat.enabled then
            if hat.debug then print(('[rsg-rocks] nearest rock %.1fm'):format(nearest)) end
            -- enter/exit hysteresis so the hat doesn't flicker at the edge
            if nearest <= hat.enterDistance then
                RocksSetInMine(true)
            elseif nearest > hat.exitDistance then
                RocksSetInMine(false)
            end
        end

        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    DespawnAll()
end)
