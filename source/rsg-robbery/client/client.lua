local isHandcuffed = false

local animDict = "script_proc@robberies@homestead@lonnies_shack@deception"
if not HasAnimDictLoaded(animDict) then
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(0)
    end
end

exports['rsg-target']:addGlobalPlayer({
    {
        name = 'rob_player',
        label = locale('robbery.rob'),
        icon = 'fa-solid fa-handcuffs',
        distance = Config.RobDistance,
        canInteract = function(entity)
            if not entity or not IsPedAPlayer(entity) then return false end
            if isHandcuffed then return false end
            if IsPedCuffed(entity) then return false end
            return IsEntityPlayingAnim(entity, animDict, "hands_up_loop", 3)
        end,
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            TriggerServerEvent('rsg-robbery:server:robplayer', targetId)
        end
    },
    {
        name = 'uncuff_player',
        label = locale('robbery.uncuff'),
        icon = 'fa-solid fa-handcuffs',
        distance = Config.CuffDistance,
        canInteract = function(entity)
            if not entity or not IsPedAPlayer(entity) then return false end
            if isHandcuffed then return false end
            return IsPedCuffed(entity)
        end,
        onSelect = function(data)
            local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            TriggerServerEvent('rsg-robbery:server:uncuffplayer', targetId)
        end
    }
}, Config.RobDistance)

RegisterNetEvent('rsg-robbery:client:verifyhandsup', function(robberId)
    if IsEntityPlayingAnim(PlayerPedId(), animDict, "hands_up_loop", 3) then
        TriggerServerEvent('rsg-robbery:server:confirmrobbery', robberId)
    end
end)

RegisterNetEvent('rsg-robbery:client:getcuffed', function()
    if isHandcuffed then return end
    isHandcuffed = true
    SetEnableHandcuffs(PlayerPedId(), true)
    ClearPedTasksImmediately(PlayerPedId())
    if GetPedCurrentHeldWeapon(PlayerPedId()) ~= joaat("WEAPON_UNARMED") then
        SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
    end
    DisablePlayerFiring(PlayerPedId(), true)
    SetPedCanPlayGestureAnims(PlayerPedId(), false)
end)

RegisterNetEvent('rsg-robbery:client:uncuffed', function()
    if not isHandcuffed then return end
    isHandcuffed = false
    ClearPedTasksImmediately(PlayerPedId())
    SetEnableHandcuffs(PlayerPedId(), false)
    DisablePlayerFiring(PlayerPedId(), false)
    SetPedCanPlayGestureAnims(PlayerPedId(), true)
    FreezeEntityPosition(PlayerPedId(), false)

    TaskPlayAnim(PlayerPedId(), animDict, "hands_up_loop", 2.0, -2.0, -1, 67109393, 0.0, false, 1245184, false, "UpperbodyFixup_filter", false)
end)

CreateThread(function()
    while true do
        if isHandcuffed then
            DisableControlAction(0, 0x295175BF, true)
            DisableControlAction(0, 0x6E9734E8, true)
            DisableControlAction(0, 0xD8F73058, true)
            DisableControlAction(0, 0x4CC0E2FE, true)
            DisableControlAction(0, 0x5966D52A, true)
            DisableControlAction(0, 0xCEFD9220, true)
            DisableControlAction(0, 0x41AC83D1, true)
            DisableControlAction(0, 0x9D2AEA88, true)
            DisableControlAction(0, 0xE474F150, true)
            Wait(100)
        else
            Wait(2000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isHandcuffed then
            SetEnableHandcuffs(PlayerPedId(), false)
            DisablePlayerFiring(PlayerPedId(), false)
            SetPedCanPlayGestureAnims(PlayerPedId(), true)
            FreezeEntityPosition(PlayerPedId(), false)
        end
        exports['rsg-target']:removeGlobalPlayer('rob_player')
        exports['rsg-target']:removeGlobalPlayer('uncuff_player')
    end
end)
