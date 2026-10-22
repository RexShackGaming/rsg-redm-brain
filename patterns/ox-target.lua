-- Reference: ox_target zone with server validation
lib.locale()

local zoneId = exports.ox_target:addSphereZone({
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

-- Entity models: exports.ox_target:addModel({ `p_bountyboard01x` }, { options... })
-- Verify prop names in data/ before using them.

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() then exports.ox_target:removeZone(zoneId) end
end)
