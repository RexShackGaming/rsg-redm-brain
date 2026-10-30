-- ===================== WILD HORSE BREAKING =====================
-- Listens for the game's EVENT_HORSE_BROKEN (fired when the taming minigame finishes),
-- records the mount and registers it with the server so it can be claimed at a stable.
-- The server keeps its own record per player; the client copy only drives the prompt.

local brokenHorse = nil -- { entity = int, netId = int }

function GetBrokenWildHorse()
    if not brokenHorse then return nil end
    local ent = brokenHorse.entity
    if not DoesEntityExist(ent) or IsEntityDead(ent) then
        brokenHorse = nil
        return nil
    end
    local dist = #(GetEntityCoords(cache.ped) - GetEntityCoords(ent))
    if dist > ((Config.WildHorse and Config.WildHorse.horseDistance) or 15.0) then return nil end
    return ent
end

function ForgetBrokenWildHorse()
    brokenHorse = nil
end

CreateThread(function()
    if not (Config.WildHorse and Config.WildHorse.enabled) then return end
    while true do
        -- EVENT_HORSE_BROKEN only fires on a wild horse, so idle on foot or on an owned (stable) horse
        local riding = GetMount(cache.ped)
        if not IsPedOnMount(cache.ped) or riding == 0 or Entity(riding).state.rsgStablesOwned then
            Wait(500)
            goto continue
        end
        Wait(0)
        local size = GetNumberOfEvents(0)
        for i = 0, size - 1 do
            if GetEventAtIndex(0, i) == `EVENT_HORSE_BROKEN` then
                local mount = GetMount(cache.ped)
                if mount ~= 0 and DoesEntityExist(mount) and NetworkGetEntityIsNetworked(mount)
                    and (not brokenHorse or brokenHorse.entity ~= mount) then
                    local netId = NetworkGetNetworkIdFromEntity(mount)
                    brokenHorse = { entity = mount, netId = netId }
                    TriggerServerEvent('rsg-stables:server:wildHorseBroken', netId)
                    lib.notify({ description = locale('wild_horse_broken'), type = 'success' })
                end
            end
        end
        ::continue::
    end
end)
