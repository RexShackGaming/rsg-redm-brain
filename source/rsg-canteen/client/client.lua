local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local busy = false
local heldProp = nil

---------------------------------
-- helpers
---------------------------------
local function playAnim(anim, duration)
    if not DoesAnimDictExist(anim.dict) then
        print(('[rsg-canteen] invalid anim dict: %s'):format(anim.dict))
        return
    end
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -8.0, duration, 1, 0, false, false, false)
    RemoveAnimDict(anim.dict)
end

local function removeProp()
    if heldProp and DoesEntityExist(heldProp) then
        DeleteObject(heldProp)
    end
    heldProp = nil
end

local function attachProp()
    local model = joaat(Config.CanteenProp)
    if not IsModelValid(model) then
        print(('[rsg-canteen] invalid prop model: %s'):format(Config.CanteenProp))
        return
    end
    lib.requestModel(model)
    local coords = GetEntityCoords(cache.ped)
    heldProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false, false, true)
    local bone = GetEntityBoneIndexByName(cache.ped, Config.PropBone)
    local o, r = Config.PropOffset, Config.PropRotation
    AttachEntityToEntity(heldProp, cache.ped, bone, o.x, o.y, o.z, r.x, r.y, r.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function progress(label, duration, disableMove)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = disableMove, car = true, combat = true },
    })
end

---------------------------------
-- fill at pump
---------------------------------
local function fillCanteen(data)
    if busy then return end
    busy = true

    local pumpCoords = GetEntityCoords(data.entity)
    local ok = lib.callback.await('rsg-canteen:server:startFill', false, pumpCoords)
    if ok then
        playAnim(Config.FillAnim, Config.FillTime)
        local done = progress(locale('progress_fill'), Config.FillTime, true)
        ClearPedTasks(cache.ped)
        TriggerServerEvent('rsg-canteen:server:finishFill', done)
    end

    busy = false
end

exports.ox_target:addModel(Config.PumpModels, {
    {
        name = 'rsg_canteen_fill',
        icon = 'fa-solid fa-bottle-water',
        label = locale('target_fill'),
        distance = Config.TargetDistance,
        canInteract = function()
            return not busy and RSGCore.Functions.HasItem(Config.CanteenItem, 1)
        end,
        onSelect = fillCanteen,
    }
})

---------------------------------
-- fill at river / lake
---------------------------------
local waterPrompt

local function inFillableWater()
    local ped = cache.ped
    if not IsEntityInWater(ped) or IsPedSwimming(ped) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then
        return false
    end
    local zones = Config.WaterFill.AllowedZones
    if #zones == 0 then return true end
    local c = GetEntityCoords(ped)
    local zone = Citizen.InvokeNative(0x5BA7A68A346A5A91, c.x, c.y, c.z) -- GetWaterMapZoneAtCoords
    for i = 1, #zones do
        if zones[i] == zone then return true end
    end
    return false
end

local function fillFromWater()
    if busy then return end
    busy = true

    local ok = lib.callback.await('rsg-canteen:server:startFill', false, GetEntityCoords(cache.ped), true)
    if ok then
        playAnim(Config.FillAnim, Config.FillTime)
        local done = progress(locale('progress_fill'), Config.FillTime, true)
        ClearPedTasks(cache.ped)
        TriggerServerEvent('rsg-canteen:server:finishFill', done and inFillableWater())
    end

    busy = false
end

-- the prompt only exists while standing in fillable water; a permanently
-- registered (even hidden) prompt suppresses native prompts like skinning/carry
local function createWaterPrompt()
    if waterPrompt then return end
    waterPrompt = PromptRegisterBegin()
    PromptSetControlAction(waterPrompt, Config.WaterFill.Key)
    PromptSetText(waterPrompt, VarString(10, 'LITERAL_STRING', locale('target_fill_water')))
    PromptSetEnabled(waterPrompt, true)
    PromptSetVisible(waterPrompt, true)
    PromptSetHoldMode(waterPrompt, true)
    PromptRegisterEnd(waterPrompt)
end

local function deleteWaterPrompt()
    if not waterPrompt then return end
    PromptDelete(waterPrompt)
    waterPrompt = nil
end

if Config.WaterFill.Enabled then
    CreateThread(function()
        while true do
            if not busy and inFillableWater() and RSGCore.Functions.HasItem(Config.CanteenItem, 1) then
                createWaterPrompt()
                while not busy and inFillableWater() do
                    if PromptHasHoldModeCompleted(waterPrompt) then
                        deleteWaterPrompt()
                        fillFromWater()
                        break
                    end
                    Wait(0)
                end
                deleteWaterPrompt()
            end
            Wait(Config.WaterFill.CheckEvery)
        end
    end)
end

---------------------------------
-- drink
---------------------------------
RegisterNetEvent('rsg-canteen:client:drink', function()
    if busy then
        TriggerServerEvent('rsg-canteen:server:finishDrink', false)
        return
    end
    busy = true

    attachProp()
    playAnim(Config.DrinkAnim, Config.DrinkTime)
    local done = progress(locale('progress_drink'), Config.DrinkTime, false)
    ClearPedTasks(cache.ped)
    removeProp()

    TriggerServerEvent('rsg-canteen:server:finishDrink', done)
    busy = false
end)

---------------------------------
-- thirst (validated + sent by server after a drink)
---------------------------------
RegisterNetEvent('rsg-canteen:client:addThirst', function(amount)
    if GetInvokingResource() then return end
    local thirst = (LocalPlayer.state.thirst or 0) + amount
    TriggerEvent('hud:client:UpdateThirst', math.max(0, math.min(Config.MaxThirst, thirst)))
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.ox_target:removeModel(Config.PumpModels, 'rsg_canteen_fill')
    removeProp()
    deleteWaterPrompt()
end)
