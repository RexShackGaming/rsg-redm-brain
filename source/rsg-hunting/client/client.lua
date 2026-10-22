local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

---------------------------------------------
-- blips
---------------------------------------------
CreateThread(function()
    for _, v in pairs(Config.Vendors) do
        if v.showblip then
            local TrapperBlip = BlipAddForCoords(1664425300, v.blipcoords)
            SetBlipSprite(TrapperBlip, joaat(Config.BlipSprite), true)
            SetBlipScale(TrapperBlip, Config.BlipScale)
            SetBlipName(TrapperBlip, v.blipname)
        end
    end
end)

------------------------------------
-- skinning animal lookup cache (O(1) instead of scanning Config.Animals
-- for every skinning event)
------------------------------------
local AnimalSkinLookup = {}

CreateThread(function()
    for i = 1, #Config.Animals do
        local animal = Config.Animals[i]
        AnimalSkinLookup[animal.modelhash] = animal
    end
end)

------------------------------------
-- skinning workings and reward
------------------------------------
local lastSkinTime = 0
local SKIN_EVENT_COOLDOWN = 1000 -- client-side throttle; server enforces the real cooldown

CreateThread(function()
    while true do
        Wait(2)
        local size = GetNumberOfEvents(0)
        if size > 0 then
            for index = 0, size - 1 do
                local event = GetEventAtIndex(0, index)
                if event == 1376140891 then
                    local view = exports['rsg-hunting']:DataViewNativeGetEventData(0, index, 3)
                    local pedGathered = view['2']
                    local ped = view['0']
                    -- bool letting us know if the skinning animation/longpress actually completed
                    local completed = view['4'] == 1

                    -- only react to our own skinning action, and only once it actually finished
                    if completed and ped == cache.ped then
                        local currentTime = GetGameTimer()
                        if currentTime - lastSkinTime >= SKIN_EVENT_COOLDOWN then
                            lastSkinTime = currentTime

                            local model = GetEntityModel(pedGathered)
                            local animal = AnimalSkinLookup[model]

                            if animal then
                                -- run the reward/cleanup steps on their own thread so the short
                                -- waits below don't stall detection of the next skinning event
                                CreateThread(function()
                                    Wait(1000) -- let the game finish spawning the carried skin item
                                    local holding = Citizen.InvokeNative(0xD806CD2A4F2C2996, cache.ped)
                                    if holding then
                                        DeleteEntity(holding)
                                    end

                                    TriggerServerEvent('rsg-hunting:server:giverewards', {
                                        animal.rewarditem1,
                                        animal.rewarditem2,
                                        animal.rewarditem3,
                                        animal.rewarditem4,
                                        animal.rewarditem5,
                                    })

                                    if animal.skinable and Config.DeleteCarcass then
                                        Wait(1000)
                                        DeletePed(pedGathered)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)
