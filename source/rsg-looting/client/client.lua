lib.locale()

local ROB_DICT = 'script_rc@cldn@ig@rsc2_ig1_questionshopkeeper'
local ROB_ANIM = 'inspectfloor_player'
local HANDSUP_DICT = 'script_proc@robberies@homestead@lonnies_shack@deception'
local HANDSUP_ANIM = 'hands_up_loop'

---------------------------------------------------------------------
-- NPC looting (native prompt or ox_target, see Config.LootMethod)
---------------------------------------------------------------------
local looting = false

local function canLoot(entity)
    return not looting and not IsPedAPlayer(entity)
        and Citizen.InvokeNative(0xB980061DA992779D, entity) -- IS_PED_HUMAN: no animals
        and IsEntityDead(entity)
        and NetworkGetEntityIsNetworked(entity) and not Entity(entity).state.rsgLooted
        and not IsEntityDead(cache.ped) and not IsPedInAnyVehicle(cache.ped, true)
end

local function lootBody(target)
    if not canLoot(target) then return end
    looting = true
    local done = lib.progressBar({
        duration = Config.LootTime,
        label = locale('loot_progress'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = ROB_DICT, clip = ROB_ANIM, flag = 1 },
    })
    if done and DoesEntityExist(target) then
        local ok = lib.callback.await('rsg-looting:server:lootReward', false, NetworkGetNetworkIdFromEntity(target))
        if ok and Config.LawAlert then
            TriggerServerEvent('rsg-lawman:server:lawmanAlert', locale('law_alert'))
        end
    end
    looting = false
end

if Config.LootMethod == 'native' then
    -----------------------------------------------------------------
    -- native RDR2 loot prompt: reward once the game marks the body looted
    -----------------------------------------------------------------
    local INPUT_LOOT = 0x41AC83D1

    local function isNativeLooted(ped)
        return Citizen.InvokeNative(0x8DE41E9902E85756, ped) -- _IS_ENTITY_FULLY_LOOTED
    end

    local function waitForNativeLoot(target)
        looting = true
        local timeout = GetGameTimer() + 8000 -- native loot anim is ~2-4s
        while GetGameTimer() < timeout and DoesEntityExist(target) do
            if isNativeLooted(target) then
                local ok = lib.callback.await('rsg-looting:server:lootReward', false, NetworkGetNetworkIdFromEntity(target))
                if ok and Config.LawAlert then
                    TriggerServerEvent('rsg-lawman:server:lawmanAlert', locale('law_alert'))
                end
                break
            end
            Wait(100)
        end
        looting = false
    end

    CreateThread(function()
        while true do
            Wait(0)
            if not looting and IsControlJustPressed(0, INPUT_LOOT) then
                local ped = lib.getClosestPed(GetEntityCoords(cache.ped), Config.LootDistance)
                if ped and canLoot(ped) and not isNativeLooted(ped) then
                    CreateThread(function() waitForNativeLoot(ped) end)
                end
            end
        end
    end)
else
    -----------------------------------------------------------------
    -- ox_target option + progress bar
    -----------------------------------------------------------------
    exports.ox_target:addGlobalPed({
        name = 'rsg-looting:loot',
        icon = 'fa-solid fa-hand',
        label = locale('loot_prompt'),
        distance = Config.LootDistance,
        canInteract = function(entity) return canLoot(entity) end,
        onSelect = function(data) lootBody(data.entity) end,
    })

    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then
            exports.ox_target:removeGlobalPed('rsg-looting:loot')
        end
    end)
end

---------------------------------------------------------------------
-- rob other player
---------------------------------------------------------------------
-- asked by the server on the VICTIM's client, so the robber can't fake it
lib.callback.register('rsg-looting:client:isHandsUp', function()
    return IsEntityPlayingAnim(PlayerPedId(), HANDSUP_DICT, HANDSUP_ANIM, 3)
end)

local function notify(key, nType)
    lib.notify({ title = locale('rob_title'), description = locale(key), type = nType or 'error', duration = 5000 })
end

local robbing = false

RegisterNetEvent('rsg-looting:client:RobPlayer', function()
    if robbing then return end
    local myPed = PlayerPedId()
    if IsEntityDead(myPed) or IsPedInAnyVehicle(myPed, true) then return end

    local player = lib.getClosestPlayer(GetEntityCoords(PlayerPedId()), Config.RobDistance)
    if not player then
        return notify('rob_not_nearby')
    end

    local targetId = GetPlayerServerId(player)
    if not lib.callback.await('rsg-looting:server:canRob', false, targetId) then
        return notify('rob_not_valid')
    end

    robbing = true
    local done = lib.progressBar({
        duration = math.random(5000, 7000),
        label = locale('rob_progress'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = ROB_DICT, clip = ROB_ANIM, flag = 16 },
    })

    robbing = false
    if not done then return notify('rob_cancelled') end
    TriggerServerEvent('rsg-looting:server:robPlayer', targetId)
end)
