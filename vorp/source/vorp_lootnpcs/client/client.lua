--THREAD
local Game <const> = Import 'events' --[[@as EVENTS]]
local lootedNpcs <const> = {}
local EVENT_GROUP <const> = 0
local GAME_EVENT <const> = 'EVENT_LOOT_COMPLETE'

-- Register event with automatic data parsing
local event <const> = Game.Events:Register(GAME_EVENT, EVENT_GROUP, function(data)
    local looter <const> = data[1]
    local entity <const> = data[2]
    local is_looted <const> = data[3]
    if is_looted == 1 and CACHE.Ped == looter then
        if IsPedHuman(entity) then
            if Citizen.InvokeNative(0x8DE41E9902E85756, entity) then -- _IS_ENTITY_FULLY_LOOTED
                local netid <const> = NetworkGetNetworkIdFromEntity(entity)
                if not lootedNpcs[netid] then
                    lootedNpcs[netid] = true
                    TriggerServerEvent("npcloot:give_reward", netid)
                else
                    print("already looted")
                end
            end
        end
    end
end, false) -- Auto-start

-- optimise the game events
RegisterNetEvent('vorp:SelectedCharacter', function()
    event:Start()
end)

AddEventHandler('vorp_core:Client:OnPlayerDeath', function()
    event:Pause()
end)

RegisterNetEvent('vorp_core:Client:OnPlayerRevive', function()
    event:Resume()
end)

RegisterNetEvent("npcloot:looted", function(netid)
    lootedNpcs[netid] = nil
end)
