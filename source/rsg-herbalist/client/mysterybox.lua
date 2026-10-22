----------------------------------------------------------------------------
-- Herb mystery box (client)
--
-- Renders whatever coord the server last sent, streams the prop in/out and
-- lets the player open it in range. The server decides location and loot.
----------------------------------------------------------------------------

local mb = Config.MysteryBox
if not mb or not mb.enabled then return end

local function Debug(msg)
    if Config.Debug then
        print('[rsg-herbalist:mysterybox] ' .. msg)
    end
end

local PROP_HASH = GetHashKey(mb.prop)
local SCOPE_RANGE_LOAD = mb.scopeRangeLoad or 100.0
local SCOPE_RANGE_UNLOAD = mb.scopeRangeUnload or 120.0
local PICKUP_RANGE = mb.pickupRange or 3.0

local boxCoord, boxEntity = nil, nil
local boxLoading, isOpening, promptShown = false, false, false

local function ShowOpenPrompt()
    if promptShown then return end
    promptShown = true
    lib.showTextUI(locale('open_mysterybox_prompt'), { position = 'right-center' })
end

local function HideOpenPrompt()
    if not promptShown then return end
    promptShown = false
    lib.hideTextUI()
end

local function LoadBoxEntity()
    if boxEntity or boxLoading or not boxCoord then return end
    boxLoading = true
    CreateThread(function()
        RequestModel(PROP_HASH)
        local deadline = GetGameTimer() + 10000
        while not HasModelLoaded(PROP_HASH) do
            if GetGameTimer() > deadline then
                Debug('box prop failed to load: ' .. tostring(mb.prop))
                boxLoading = false
                return
            end
            Wait(0)
        end

        if boxCoord and not boxEntity then
            local c = boxCoord
            local obj = CreateObject(PROP_HASH, c.x, c.y, c.z, false, false, false)
            if obj ~= 0 then
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                boxEntity = obj
            end
        end
        SetModelAsNoLongerNeeded(PROP_HASH)
        boxLoading = false
    end)
end

local function UnloadBoxEntity()
    if boxEntity and DoesEntityExist(boxEntity) then
        DeleteEntity(boxEntity)
    end
    boxEntity = nil
end

RegisterNetEvent('rsg-herbalist:client:SetMysteryBox', function(coord)
    UnloadBoxEntity()
    HideOpenPrompt()
    boxCoord = coord
end)

CreateThread(function()
    TriggerServerEvent('rsg-herbalist:server:requestMysteryBox')
end)

local function TryOpenBox()
    if isOpening or not boxCoord then return end
    isOpening = true
    HideOpenPrompt()

    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CROUCH_INSPECT', 0, true)
    local completed = ProgressOrWait(Config.GatherDurationMs, locale('opening_mysterybox'), Config.GatherProgressBarEnabled)
    ClearPedTasks(ped)

    if completed and boxCoord then
        TriggerServerEvent('rsg-herbalist:server:openMysteryBox')
    end
    isOpening = false
end

CreateThread(function()
    while true do
        local sleep = 1000
        if boxCoord then
            local ped = PlayerPedId()
            local dist = #(GetEntityCoords(ped) - boxCoord)

            if not boxEntity then
                if dist <= SCOPE_RANGE_LOAD then LoadBoxEntity() end
            elseif dist >= SCOPE_RANGE_UNLOAD then
                UnloadBoxEntity()
            end

            if boxEntity and dist <= PICKUP_RANGE and not isOpening and not IsPedOnMount(ped) then
                sleep = 0
                ShowOpenPrompt()
                if IsPickupControlPressed() then
                    TryOpenBox()
                end
            else
                HideOpenPrompt()
                if boxEntity and dist <= 20.0 then sleep = 250 end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        UnloadBoxEntity()
        HideOpenPrompt()
    end
end)
