local RSGCore = exports['rsg-core']:GetCoreObject()

local busy = false
local heldProp = nil

-- fee / verification are decided by the shared config (the server enforces them)
local FEE_ACTIVE = Config.PumpFee.Enabled and Config.PumpVerify.Enabled

---------------------------------
-- helpers
---------------------------------
local function notify(msg, typ)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = msg, type = typ or 'error' })
end

-- cosmetic only: a missing/slow dict must never block the action itself
local function playAnim(anim, duration)
    if not DoesAnimDictExist(anim.dict) then
        print(('[rsg-canteen] invalid anim dict: %s'):format(anim.dict))
        return
    end
    if not pcall(RSGCore.Functions.RequestAnimDict, anim.dict) then
        print(('[rsg-canteen] anim dict failed to load: %s'):format(anim.dict))
        return
    end
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip, 8.0, -8.0, duration, 1, 0, false, false, false)
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
    if not pcall(RSGCore.Functions.RequestModel, model) then
        print(('[rsg-canteen] prop model failed to load: %s'):format(Config.CanteenProp))
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    heldProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false, false, true)
    local bone = GetEntityBoneIndexByName(ped, Config.PropBone)
    local o, r = Config.PropOffset, Config.PropRotation
    AttachEntityToEntity(heldProp, ped, bone, o.x, o.y, o.z, r.x, r.y, r.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function progress(label, duration, disableMove)
    return RSGCore.Functions.ProgressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = disableMove, car = true, combat = true },
    })
end

-- runs an action with the busy flag held and always releases it, even if something errors
local function guarded(fn)
    busy = true
    local ok, err = pcall(fn)
    busy = false
    if not ok then
        print(('^1[rsg-canteen] %s^7'):format(err))
        ClearPedTasks(PlayerPedId())
        removeProp()
    end
    return ok
end

local function canUseNow()
    local ped = PlayerPedId()
    return not (IsPedDeadOrDying(ped, true) or IsPedSwimming(ped) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false))
end

-- the inventory is read from target/prompt loops, so cache the result briefly
local cache = { at = 0, has = false, dirty = false }
local function canteenState()
    local now = GetGameTimer()
    if now - cache.at > 1000 then
        cache.has, cache.dirty = false, false
        for _, item in pairs(RSGCore.Functions.GetPlayerData().items or {}) do
            if Config.Canteens[item.name] then
                cache.has = true
                if item.info and item.info.dirty == true then cache.dirty = true end
            end
        end
        cache.at = now
    end
    return cache.has, cache.dirty
end

local function hasCanteen() return (canteenState()) end
local function hasDirtyCanteen() local _, dirty = canteenState() return dirty end

-- shared flow: server callback -> animation + progress bar -> finish event.
-- opts: callback, a, b (callback args), finish (event), anim, time, label, disableMove, prop, stillValid
local function doAction(opts)
    if busy then return end
    if not canUseNow() then return notify(locale('cannot_now')) end

    local ok = guarded(function()
        local started = RSGCore.Functions.AwaitCallback(opts.callback, 5000, opts.a, opts.b)
        if not started then return end

        if opts.prop then attachProp() end
        playAnim(opts.anim, opts.time)
        local done = progress(opts.label, opts.time, opts.disableMove)
        ClearPedTasks(PlayerPedId())
        removeProp()
        TriggerServerEvent(opts.finish, done and (not opts.stillValid or opts.stillValid()))
    end)
    -- an error mid-flow: release the server-side pending action right away
    if not ok then TriggerServerEvent(opts.finish, false) end
end

---------------------------------
-- fill at pump
---------------------------------
local function doFill(coords, fromWater, stillValid)
    doAction({
        callback = 'rsg-canteen:server:startFill', a = coords, b = fromWater,
        finish = 'rsg-canteen:server:finishFill',
        anim = Config.FillAnim, time = Config.FillTime, label = locale('progress_fill'),
        disableMove = true, stillValid = stillValid,
    })
end

local function fillCanteen(data)
    if not data.entity or not DoesEntityExist(data.entity) then return end
    doFill(GetEntityCoords(data.entity), false)
end

exports['rsg-target']:addModel(Config.PumpModels, {
    {
        name = 'rsg_canteen_fill',
        icon = 'fa-solid fa-bottle-water',
        label = FEE_ACTIVE and locale('target_fill_fee', ('%.2f'):format(Config.PumpFee.Price)) or locale('target_fill'),
        distance = Config.TargetDistance,
        canInteract = function()
            return not busy and hasCanteen()
        end,
        onSelect = fillCanteen,
    }
})

---------------------------------
-- purify at a fire
---------------------------------
local purifyActive = Config.Purify.Enabled and Config.DirtyWater.Enabled

if purifyActive then
    exports['rsg-target']:addModel(Config.Purify.Models, {
        {
            name = 'rsg_canteen_purify',
            icon = 'fa-solid fa-fire-flame-curved',
            label = locale('target_purify'),
            distance = Config.TargetDistance,
            canInteract = function()
                return not busy and hasDirtyCanteen()
            end,
            onSelect = function(data)
                if not data.entity or not DoesEntityExist(data.entity) then return end
                doAction({
                    callback = 'rsg-canteen:server:startPurify', a = GetEntityCoords(data.entity),
                    finish = 'rsg-canteen:server:finishPurify',
                    anim = Config.FillAnim, time = Config.Purify.Time, label = locale('progress_purify'),
                    disableMove = true,
                })
            end,
        }
    })
end

---------------------------------
-- give another player a drink
---------------------------------
if Config.Share.Enabled then
    exports['rsg-target']:addGlobalPlayer({
        {
            name = 'rsg_canteen_share',
            icon = 'fa-solid fa-hand-holding-droplet',
            label = locale('target_share'),
            distance = Config.Share.Distance,
            canInteract = function()
                return not busy and hasCanteen()
            end,
            onSelect = function(data)
                if not data.entity or not DoesEntityExist(data.entity) then return end
                local index = NetworkGetPlayerIndexFromPed(data.entity)
                if index == -1 then return end
                doAction({
                    callback = 'rsg-canteen:server:startShare', a = GetPlayerServerId(index),
                    finish = 'rsg-canteen:server:finishShare',
                    anim = Config.DrinkAnim, time = Config.Share.Time, label = locale('progress_share'),
                    disableMove = true, prop = true,
                })
            end,
        }
    })
end

---------------------------------
-- fill at river / lake
---------------------------------
local waterPrompt

local function inFillableWater()
    local ped = PlayerPedId()
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
    doFill(GetEntityCoords(PlayerPedId()), true, inFillableWater)
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
            if not busy and inFillableWater() and hasCanteen() then
                createWaterPrompt()
                local nextCheck = 0
                while not busy do
                    -- the hold check needs every frame, the water/inventory re-check does not
                    local now = GetGameTimer()
                    if now >= nextCheck then
                        if not inFillableWater() or not hasCanteen() then break end
                        nextCheck = now + 250
                    end
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
local function drink()
    attachProp()
    playAnim(Config.DrinkAnim, Config.DrinkTime)
    local done = progress(locale('progress_drink'), Config.DrinkTime, false)
    ClearPedTasks(PlayerPedId())
    removeProp()
    TriggerServerEvent('rsg-canteen:server:finishDrink', done)
end

-- sent by the server after the canteen item was used; the server owns the use count and thirst
RegisterNetEvent('rsg-canteen:client:drink', function()
    if busy then
        TriggerServerEvent('rsg-canteen:server:finishDrink', false)
        return
    end
    if not canUseNow() then
        notify(locale('cannot_now'))
        TriggerServerEvent('rsg-canteen:server:finishDrink', false)
        return
    end
    if not guarded(drink) then
        TriggerServerEvent('rsg-canteen:server:finishDrink', false)
    end
end)

-- dirty water sickness (amount and floor are decided by the server)
RegisterNetEvent('rsg-canteen:client:sick', function(damage, minHealth)
    if GetInvokingResource() then return end
    damage, minHealth = tonumber(damage), tonumber(minHealth)
    if not damage or not minHealth then return end
    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then return end
    local health = GetEntityHealth(ped)
    -- never push the player below the configured floor
    local applied = math.min(damage, health - minHealth)
    if applied > 0 then
        ApplyDamageToPed(ped, applied, false, true, true)
    end
end)

---------------------------------
-- admin: register the nearest pump (server verification)
---------------------------------
RegisterNetEvent('rsg-canteen:client:addPump', function()
    if GetInvokingResource() then return end
    local c = GetEntityCoords(PlayerPedId())
    for _, name in ipairs(Config.PumpModels) do
        local entity = GetClosestObjectOfType(c.x, c.y, c.z, 3.0, joaat(name), false, false, false)
        if entity ~= 0 and DoesEntityExist(entity) then
            TriggerServerEvent('rsg-canteen:server:addPump', GetEntityCoords(entity), name)
            return
        end
    end
    notify(locale('pump_none_near'))
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports['rsg-target']:removeModel(Config.PumpModels, 'rsg_canteen_fill')
    if purifyActive then exports['rsg-target']:removeModel(Config.Purify.Models, 'rsg_canteen_purify') end
    if Config.Share.Enabled then exports['rsg-target']:removeGlobalPlayer('rsg_canteen_share') end
    removeProp()
    deleteWaterPrompt()
    if busy then ClearPedTasks(PlayerPedId()) end
end)
