local RSGCore = exports['rsg-core']:GetCoreObject()

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
        refill = data.refill,
    }
end

------------------------------------------
-- ammo checks
------------------------------------------
local function canAddAmmo(ammoType, amount)
    local def = ammoTypes[ammoType]
    if not def then
        RSGCore.Functions.Notify({ title = locale('ammo_unknown'), type = 'error', duration = 5000 })
        return false
    end
    if GetPedAmmoByType(PlayerPedId(), def.hash) + amount > def.maxAmmo then
        RSGCore.Functions.Notify({ title = locale('ammo_max_reached'), type = 'error', duration = 5000 })
        return false
    end
    return true
end

RSGCore.Functions.CreateClientCallback('rsg-ammo:client:CanAddAmmo', function(cb, ammoType, amount)
    if opening or LocalPlayer.state.inv_busy then return cb(false) end
    cb(canAddAmmo(ammoType, amount))
end)

RegisterNetEvent('rsg-ammo:client:AddAmmo', function(ammoType, amount)
    local def = ammoTypes[ammoType]
    if not def then return end

    local ped = PlayerPedId()
    local toAdd = math.min(amount, def.maxAmmo - GetPedAmmoByType(ped, def.hash))
    if toAdd <= 0 then return end

    AddAmmoToPedByType(ped, def.hash, toAdd)
    RSGCore.Functions.Notify({ title = locale('ammo_replenished', toAdd), type = 'success', duration = 5000 })
end)

------------------------------------------
-- open ammo box
------------------------------------------
RegisterNetEvent('rsg-ammo:client:openAmmoBox', function(ammoBoxItem)
    if opening then return end
    opening = true
    LocalPlayer.state:set('inv_busy', true, true)

    local itemData = RSGCore.Shared.Items[ammoBoxItem]
    local done = RSGCore.Functions.ProgressBar({
        duration = Config.OpenAmmoBoxTime,
        label = locale('opening_box', itemData and itemData.label or ammoBoxItem),
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, mount = true, combat = true },
    })

    TriggerServerEvent(done and 'rsg-ammo:server:openAmmoBox' or 'rsg-ammo:server:cancelOpen')
    LocalPlayer.state:set('inv_busy', false, true)
    opening = false
end)

------------------------------------------
-- save loop (only sends changed values)
------------------------------------------
local function saveAmmo()
    if not initialized then return end
    local ped = PlayerPedId()
    local update
    for ammoType, def in pairs(ammoTypes) do
        local amount = GetPedAmmoByType(ped, def.hash)
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

CreateThread(function()
    while true do
        Wait(Config.SaveAmmoInterval)
        if LocalPlayer.state.isLoggedIn then saveAmmo() end
    end
end)

------------------------------------------
-- restore saved ammo on load
------------------------------------------
local function onPlayerLoaded()
    initialized = false
    local row = RSGCore.Functions.AwaitCallback('rsg-ammo:server:initializeDb')
    if not row then return end

    local ped = PlayerPedId()
    for ammoType, def in pairs(ammoTypes) do
        local amount = math.min(tonumber(row[def.dbColumn]) or 0, def.maxAmmo)
        if amount > 0 then
            local weapon = throwableWeapons[ammoType]
            if weapon and not HasPedGotWeapon(ped, weapon, 0, false) then
                GiveWeaponToPed(ped, weapon, 0, false, true)
            end
        end
        -- always set (incl. 0) so ammo from a previous character on the same ped doesn't carry over
        if GetPedAmmoByType(ped, def.hash) ~= amount then
            SetPedAmmoByType(ped, def.hash, amount)
        end
        ammoCache[ammoType] = amount
    end
    initialized = true
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', onPlayerLoaded)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    saveAmmo() -- flush changes since the last interval before logout / character switch
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
