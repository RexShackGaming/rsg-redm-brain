lib.locale()

---------------------------------------------
-- trapper blips
---------------------------------------------
local trapperBlips = {}

CreateThread(function()
    local sprite = joaat(Config.BlipSprite)
    for _, v in ipairs(Config.Vendors) do
        if v.showblip then
            local blip = BlipAddForCoords(1664425300, v.blipcoords)
            SetBlipSprite(blip, sprite, true)
            SetBlipScale(blip, Config.BlipScale)
            SetBlipName(blip, v.blipname)
            trapperBlips[#trapperBlips + 1] = blip
        end
    end
end)

------------------------------------
-- skinning (native skinning event)
------------------------------------
local SKIN_EVENT = 1376140891 -- EVENT_LOOT_COMPLETE
local SKIN_EVENT_COOLDOWN = 1000 -- client throttle; the server enforces the real cooldown

local AnimalSkinLookup = {}
for _, animal in ipairs(Config.Animals) do
    AnimalSkinLookup[animal.modelhash] = animal
end

local lastSkinTime = 0

local function onSkinned(carcass, animal)
    Wait(1000) -- let the game finish spawning the carried skin
    local holding = Citizen.InvokeNative(0xD806CD2A4F2C2996, cache.ped) -- GetFirstEntityPedIsCarrying
    if holding and holding ~= 0 then
        DeleteEntity(holding)
    end

    -- only the carcass is sent; the server works out the rewards itself
    local netId = NetworkGetEntityIsNetworked(carcass) and NetworkGetNetworkIdFromEntity(carcass) or 0
    TriggerServerEvent('rsg-hunting:server:giverewards', netId)

    if Config.DeleteCarcass then
        Wait(1000)
        if DoesEntityExist(carcass) then DeletePed(carcass) end
    end
end

CreateThread(function()
    while true do
        Wait(0)
        local size = GetNumberOfEvents(0)
        for index = 0, size - 1 do
            if GetEventAtIndex(0, index) == SKIN_EVENT then
                local view = exports[GetCurrentResourceName()]:DataViewNativeGetEventData(0, index, 3)
                local looter, carcass, completed = view['0'], view['2'], view['4'] == 1

                if completed and looter == cache.ped then
                    local now = GetGameTimer()
                    if now - lastSkinTime >= SKIN_EVENT_COOLDOWN then
                        local animal = AnimalSkinLookup[GetEntityModel(carcass)]
                        if animal and animal.skinable then
                            lastSkinTime = now
                            CreateThread(function() onSkinned(carcass, animal) end)
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(trapperBlips) do
        RemoveBlip(blip)
    end
end)
