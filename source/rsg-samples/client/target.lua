--------------------------------------------------------------------------------------------
-- RSG SAMPLES — Client: ox_target leaderboard zone + map blip
--------------------------------------------------------------------------------------------

local blip

CreateThread(function()
    local loc = Config.LeaderboardLocation

    exports.ox_target:addSphereZone({
        coords  = loc.coords,
        radius  = loc.radius,
        debug   = Config.DebugClient,
        options = {
            {
                label    = locale('target_leaderboard'),
                icon     = 'fas fa-book-open',
                distance = 2.5,
                onSelect = function()
                    TriggerServerEvent('rsg-samples:server:requestMenu')
                end,
            },
        },
    })

    if not Config.ShowBlip then return end

    local sprite = type(Config.BlipSprite) == 'string' and joaat(Config.BlipSprite) or Config.BlipSprite
    blip = BlipAddForCoords(1664425300, loc.coords.x, loc.coords.y, loc.coords.z)
    SetBlipSprite(blip, sprite, true)
    SetBlipScale(blip, Config.BlipScale)
    if Config.BlipColor and Config.BlipColor ~= '' then
        BlipAddModifier(blip, joaat(Config.BlipColor))
    end
    SetBlipName(blip, locale('blip_label'))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and blip then
        RemoveBlip(blip)
    end
end)
