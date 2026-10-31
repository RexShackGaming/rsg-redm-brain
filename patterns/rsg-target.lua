-- Reference: rsg-target zone with server validation
-- rsg-target replaces ox_target (it provides ox_target). Always call exports['rsg-target'] and add 'rsg-target' to dependencies.

local zoneId = exports['rsg-target']:addSphereZone({
    coords = Config.ShopCoords,
    radius = 1.5,
    debug = Config.Debug,
    options = {
        {
            name = 'rsg-example:open',
            icon = 'fa-solid fa-store',
            label = locale('open_shop'),
            distance = 2.0,
            onSelect = function()
                TriggerEvent('rsg-example:client:openShop')
            end,
        },
    },
})

-- Entity models: exports['rsg-target']:addModel({ `p_bountyboard01x` }, { options... })
-- Verify prop names in data/ before using them.

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() then exports['rsg-target']:removeZone(zoneId) end
end)
