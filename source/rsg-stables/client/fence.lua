-- rsg-stables: horse fence (sell wild / stolen horses for blood money)
lib.locale()

local cfg = Config.HorseFence
if not (cfg and cfg.enabled and cfg.locations and #cfg.locations > 0) then return end

local fencePeds, fenceBlips = {}, {}
local lastMount = 0

-- remember the last horse the player rode, so they can dismount and sell it
CreateThread(function()
    while true do
        local mount = GetMount(cache.ped)
        if mount ~= 0 then lastMount = mount end
        Wait(1000)
    end
end)

local function sellToFence(index)
    local horse = lastMount
    if horse == 0 or not DoesEntityExist(horse) or IsEntityDead(horse) then
        lib.notify({ description = locale('fence_no_horse'), type = 'error' })
        return
    end
    if GetMount(cache.ped) == horse then
        lib.notify({ description = locale('fence_dismount'), type = 'error' })
        return
    end
    if not NetworkGetEntityIsNetworked(horse) then
        lib.notify({ description = locale('fence_no_horse'), type = 'error' })
        return
    end
    local ok, res = lib.callback.await('rsg-stables:server:fenceHorse', false, index, NetworkGetNetworkIdFromEntity(horse))
    if ok then
        lastMount = 0
        lib.notify({ title = locale('fence_title'), description = locale('fence_sold', res.label, res.price), type = 'success' })
    else
        lib.notify({ title = locale('fence_title'), description = res, type = 'error' })
    end
end

local function spawnFence(index, loc)
    local model = cfg.pedModel
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then return end
    local c = loc.coords
    local ped = CreatePed(model, c.x, c.y, c.z - 1.0, c.w, false, false, 0, 0)
    SetModelAsNoLongerNeeded(model)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    fencePeds[index] = ped
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'rsg_stables_fence',
            icon = 'fas fa-horse',
            label = locale('fence_sell'),
            distance = 2.5,
            onSelect = function() sellToFence(index) end,
        },
    })
    if cfg.blip then
        local blip = BlipAddForCoords(1664425300, c.x, c.y, c.z)
        SetBlipSprite(blip, joaat('blip_shop_horse_fencing'), true)
        SetBlipName(blip, loc.label or locale('fence_title'))
        fenceBlips[#fenceBlips + 1] = blip
    end
end

CreateThread(function()
    for i, loc in ipairs(cfg.locations) do spawnFence(i, loc) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in pairs(fencePeds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    for _, b in ipairs(fenceBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
