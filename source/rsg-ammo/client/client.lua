local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local ammoTypes = {}
local ammoCache = {}
local initialized = false
local opening = false

-- throwables need their weapon in the ped's inventory before ammo can be set
local throwableWeapons = {
    AMMO_MOLOTOV                = `weapon_thrown_molotov`,
    AMMO_TOMAHAWK               = `weapon_thrown_tomahawk`,
    AMMO_TOMAHAWK_ANCIENT       = `weapon_thrown_tomahawk_ancient`,
    AMMO_DYNAMITE               = `weapon_thrown_dynamite`,
    AMMO_POISONBOTTLE           = `weapon_thrown_poisonbottle`,
    AMMO_THROWING_KNIVES        = `weapon_thrown_throwing_knives`,
    AMMO_THROWING_KNIVES_DRAIN  = `weapon_thrown_throwing_knives`,
    AMMO_THROWING_KNIVES_POISON = `weapon_thrown_throwing_knives`,
    AMMO_BOLAS                  = `weapon_thrown_bolas`,
    AMMO_BOLAS_HAWKMOTH         = `weapon_thrown_bolas_hawkmoth`,
    AMMO_BOLAS_INTERTWINED      = `weapon_thrown_bolas_intertwined`,
    AMMO_BOLAS_IRONSPIKED       = `weapon_thrown_bolas_ironspiked`,
    AMMO_HATCHET                = `weapon_melee_hatchet`,
    AMMO_HATCHET_HUNTER         = `weapon_melee_hatchet_hunter`,
    AMMO_HATCHET_CLEAVER        = `weapon_melee_cleaver`,
}

for ammoType, data in pairs(Config.AmmoTypes) do
    ammoTypes[ammoType] = {
        hash = joaat(ammoType),
        dbColumn = ammoType:lower(),
        maxAmmo = data.maxAmmo,
    }
end

------------------------------------------
-- ammo checks
------------------------------------------
local function canAddAmmo(ammoType, amount)
    local def = ammoTypes[ammoType]
    if not def then
        lib.notify({ title = locale('ammo_unknown'), type = 'error', duration = 5000 })
        return false
    end
    if GetPedAmmoByType(cache.ped, def.hash) + amount > def.maxAmmo then
        lib.notify({ title = locale('ammo_max_reached'), type = 'error', duration = 5000 })
        return false
    end
    return true
end

lib.callback.register('rsg-ammo:client:CanAddAmmo', function(ammoType, amount)
    if opening or LocalPlayer.state.inv_busy then return false end
    return canAddAmmo(ammoType, amount)
end)

RegisterNetEvent('rsg-ammo:client:AddAmmo', function(ammoType, amount)
    local def = ammoTypes[ammoType]
    if not def then return end

    local current = GetPedAmmoByType(cache.ped, def.hash)
    local toAdd = math.min(amount, def.maxAmmo - current)
    if toAdd <= 0 then return end

    AddAmmoToPedByType(cache.ped, def.hash, toAdd)
    lib.notify({ title = locale('ammo_replenished', toAdd), type = 'success', duration = 5000 })
end)

------------------------------------------
-- open ammo box
------------------------------------------
RegisterNetEvent('rsg-ammo:client:openAmmoBox', function(ammoBoxItem)
    if opening then return end
    opening = true
    LocalPlayer.state:set('inv_busy', true, true)

    local itemData = RSGCore.Shared.Items[ammoBoxItem]
    local done = lib.progressBar({
        duration = Config.OpenAmmoBoxTime,
        label = locale('opening_box', itemData and itemData.label or ammoBoxItem),
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = true, combat = true },
    })

    TriggerServerEvent(done and 'rsg-ammo:server:openAmmoBox' or 'rsg-ammo:server:cancelOpen')
    LocalPlayer.state:set('inv_busy', false, true)
    opening = false
end)

------------------------------------------
-- save loop (only sends changed values)
------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.SaveAmmoInterval)
        if initialized and LocalPlayer.state.isLoggedIn then
            local update
            for ammoType, def in pairs(ammoTypes) do
                local amount = GetPedAmmoByType(cache.ped, def.hash)
                if amount ~= ammoCache[ammoType] then
                    update = update or {}
                    update[def.dbColumn] = amount
                    ammoCache[ammoType] = amount
                end
            end
            if update then
                TriggerServerEvent('rsg-ammo:server:updateDb', update)
            end
        end
    end
end)

------------------------------------------
-- restore saved ammo on load
------------------------------------------
local function onPlayerLoaded()
    initialized = false
    local row = lib.callback.await('rsg-ammo:server:initializeDb', false)
    if not row then return end

    for ammoType, def in pairs(ammoTypes) do
        local amount = tonumber(row[def.dbColumn]) or 0
        if amount > 0 then
            local weapon = throwableWeapons[ammoType]
            if weapon and not HasPedGotWeapon(cache.ped, weapon, 0, false) then
                GiveWeaponToPed(cache.ped, weapon, 0, false, true)
            end
            SetPedAmmoByType(cache.ped, def.hash, math.min(amount, def.maxAmmo))
        end
        ammoCache[ammoType] = amount
    end
    initialized = true
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', onPlayerLoaded)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    initialized = false
    ammoCache = {}
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName and LocalPlayer.state.isLoggedIn then
        onPlayerLoaded()
    end
end)

exports('GetAmmoTypes', function()
    return ammoTypes
end)
