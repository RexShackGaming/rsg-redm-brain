local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

------------------------------------------
-- butcher: the client only sends the carried carcass's network id;
-- the server checks the carcass, works out the reward and deletes it
------------------------------------------
local AnimalByModel = {}
for _, animal in ipairs(Config.Animal) do
    AnimalByModel[animal.model] = animal
end

local QualityMultiplier = {
    poor    = Config.PoorMultiplier or 1,
    good    = Config.GoodMultiplier or 2,
    perfect = Config.PerfectMultiplier or 3,
}
local ItemQuantity = { poor = 1, good = 2, perfect = 3 }

local BUTCHER_RANGE = 8.0  -- player must be this close to a butcher
local CARCASS_RANGE = 4.0  -- carcass must be this close to the player
local COOLDOWN = Config.ServerCooldown or 2000

local Cooldowns = {}
local SoldCarcasses = {} -- [netId] = os.time()

CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        for id, t in pairs(SoldCarcasses) do
            if now - t > 1800 then SoldCarcasses[id] = nil end
        end
    end
end)

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('butcher_title'), description = desc, type = ntype, duration = 6000 })
end

local function nearButcher(coords)
    for _, b in ipairs(Config.ButcherLocations) do
        if #(coords - b.coords) <= BUTCHER_RANGE or #(coords - b.npccoords.xyz) <= BUTCHER_RANGE then
            return true
        end
    end
    return false
end

local function suspicious(src, why)
    print(('[rsg-hunting] butcher sale rejected for %s (%s): %s'):format(GetPlayerName(src) or '?', src, why))
    HuntingWebhook.Security(src, locale('wh_where_butcher'), why)
end

lib.callback.register('rsg-hunting:server:sellCarcass', function(src, netId, quality)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    local now = GetGameTimer()
    if Cooldowns[src] and now - Cooldowns[src] < COOLDOWN then return false end
    Cooldowns[src] = now

    netId = math.tointeger(tonumber(netId))
    if not netId or netId <= 0 then return false end
    if SoldCarcasses[netId] then suspicious(src, locale('reason_already_sold')) return false end
    if not QualityMultiplier[quality] then quality = 'poor' end

    local carcass = NetworkGetEntityFromNetworkId(netId)
    if not carcass or carcass == 0 or not DoesEntityExist(carcass) or GetEntityType(carcass) ~= 1 then
        notify(src, locale('butcher_failed'), 'error')
        return false
    end
    if IsPedAPlayer(carcass) then suspicious(src, locale('reason_sell_player')) return false end
    if GetEntityHealth(carcass) > 0 then
        notify(src, locale('butcher_not_dead'), 'error')
        return false
    end

    local animal = AnimalByModel[GetEntityModel(carcass)]
    if not animal then
        notify(src, locale('butcher_unknown_animal'), 'error')
        return false
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    if #(playerCoords - GetEntityCoords(carcass)) > CARCASS_RANGE then suspicious(src, locale('reason_carcass_far')) return false end
    if not nearButcher(playerCoords) then suspicious(src, locale('reason_not_at_butcher')) return false end

    -- items first: if there's no room, keep the carcass and stop
    local qty = ItemQuantity[quality]
    local items = {}
    for i = 1, 3 do
        local name = animal['rewarditem' .. i]
        if name and RSGCore.Shared.Items[name] then
            if not exports['rsg-inventory']:CanAddItem(src, name, qty) then
                notify(src, locale('inventory_full'), 'error')
                return false
            end
            items[#items + 1] = name
        end
    end

    -- claim + remove the carcass before paying
    SoldCarcasses[netId] = os.time()
    DeleteEntity(carcass)

    local bonus = (HuntingXP.GetPerks(src).butcherBonus or 0) / 100
    local cash = math.floor(animal.rewardmoney * QualityMultiplier[quality] * (1 + bonus) * 100 + 0.5) / 100
    if cash > 0 then
        Player.Functions.AddMoney('cash', cash, 'rsg-hunting-butcher')
    end
    for _, name in ipairs(items) do
        exports['rsg-inventory']:AddItem(src, name, qty, nil, nil, 'rsg-hunting-butcher')
    end

    notify(src, locale('butcher_sold', animal.name, locale('quality_' .. quality), ('%.2f'):format(cash)), 'success')

    local itemText = {}
    for _, name in ipairs(items) do itemText[#itemText + 1] = ('%sx %s'):format(qty, RSGCore.Shared.Items[name].label or name) end
    HuntingWebhook.Sale('butcher', src, locale('wh_butcher_title', animal.name, locale('quality_' .. quality)), {
        { name = locale('wh_animal'), value = animal.name },
        { name = locale('wh_quality'), value = locale('quality_' .. quality) },
        { name = locale('wh_cash'), value = ('$%.2f'):format(cash) },
        { name = locale('wh_items'), value = #itemText > 0 and table.concat(itemText, ', ') or '-', inline = false },
        { name = locale('wh_butcher_perk'), value = ('+%s%%'):format(math.floor(bonus * 100 + 0.5)) },
    }, cash)

    if Config.EnableLogging then
        TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour,
            ('%s (%s) sold a %s %s for $%.2f'):format(GetPlayerName(src), Player.PlayerData.citizenid, quality, animal.name, cash), false)
    end

    local xpCfg = Config.HuntingXP
    if xpCfg and xpCfg.Enabled and xpCfg.ButcherXP then
        local mult = xpCfg.ButcherQualityMultiplier and xpCfg.ButcherQualityMultiplier[quality] or 1
        HuntingXP.Award(src, HuntingXP.GetAnimalXP(animal.model) * mult)
    end

    return true
end)

AddEventHandler('playerDropped', function()
    Cooldowns[source] = nil
end)
