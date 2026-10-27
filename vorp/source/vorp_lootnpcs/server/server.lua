local LIB <const>    = Import({ '/config', '/translation' })
local Config <const> = LIB.Config --[[@as vorp_loot]]
local T              = LIB.Translation[Config.Lang] --[[@as vorp_loot_translation]]
if not T then
    print("Language: " .. Config.Lang .. " not found, using English as default")
    T = LIB.Translation.English --[[@as vorp_loot_translation]]
end


local Core = exports.vorp_core:GetCore()
local lootedNpcs <const> = {}

RegisterServerEvent('npcloot:give_reward', function(netid)
    local _source = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    local entity <const> = NetworkGetEntityFromNetworkId(netid)
    if not DoesEntityExist(entity) then
        return print("entity does not exist with netid possible cheat? player: " .. GetPlayerName(_source) .. " ID: " .. _source)
    end

    local playerCoords <const> = GetEntityCoords(GetPlayerPed(_source))
    local entityCoords <const> = GetEntityCoords(entity)
    if #(playerCoords - entityCoords) > 5.0 then
        return print("player is too far away from the entity possible cheat? player: " .. GetPlayerName(_source) .. " ID: " .. _source)
    end

    if lootedNpcs[netid] then
        return print("entity already looted possible cheat? player: " .. GetPlayerName(_source) .. " ID: " .. _source)
    end

    lootedNpcs[netid] = true

    -- only allow looting for a certain amount of time this netid
    SetTimeout(Config.timeout * 60000, function()
        lootedNpcs[netid] = nil
        if GetPlayerName(_source) then -- check if player is still online
            TriggerClientEvent("npcloot:looted", _source, netid)
        end
    end)

    local character <const> = user.getUsedCharacter

    if Config.canReceiveWeapons then
        local chance <const> = math.random(1, Config.chanceGettingWeapon)
        if chance < Config.receiveWeapon then
            local ammo <const> = { ["nothing"] = 0 }
            local reward1 <const> = Config.weapons
            local chance1 <const> = math.random(1, #reward1)

            local canCarryWeapons <const> = exports.vorp_inventory:canCarryWeapons(_source, 1, nil, Config.weapons[chance1].name)
            if not canCarryWeapons then
                return Core.NotifyRightTip(_source, T.invFullWeapon, 3000)
            end

            exports.vorp_inventory:createWeapon(_source, Config.weapons[chance1].name, ammo, {})

            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.youGot .. Config.weapons[chance1].label, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, "" .. T.youGot .. "" .. Config.weapons[chance1].label .. "", "BLIPS", "blip_ambient_bounty_target", 3000, "COLOR_GREEN")
            end
        else -- info on finding nothing
            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.noWeapon, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, "" .. T.noWeapon .. "", "BLIPS", "blip_destroy", 3000, "COLOR_RED")
            end
        end
    end

    if Config.canReceiveMoney then
        local chance1 <const> = math.random(1, Config.chanceGettingMoney)
        if chance1 < Config.receiveMoney then
            local item_type <const> = math.random(1, #Config.money)
            character.addCurrency(0, Config.money[item_type])

            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.youGot .. string.format("%.2f", Config.money[item_type]) .. T.currency, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, T.youGot .. string.format("%.2f", Config.money[item_type]) .. T.currency, "BLIPS", "blip_ambient_bounty_target", 3000, "COLOR_GREEN")
            end
        else -- info on finding nothing
            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.noMoney, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, "" .. T.noMoney .. "", "BLIPS", "blip_destroy", 3000, "COLOR_RED")
            end
        end
    end


    if Config.canReceiveGold then
        local chance2 <const> = math.random(1, Config.chanceGettingGold)
        if chance2 < Config.receiveGold then
            local item_type <const> = math.random(1, #Config.gold)
            character.addCurrency(1, Config.gold[item_type])
            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.youGot .. Config.gold[item_type] .. T.nugget, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, T.youGot .. Config.gold[item_type] .. T.nugget, "BLIPS", "blip_ambient_bounty_target", 3000, "COLOR_GREEN")
            end
        else
            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.noGold, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, "" .. T.noGold .. "", "BLIPS", "blip_destroy", 3000, "COLOR_RED")
            end
        end
    end

    if Config.canReceiveItems then
        local chance3 <const> = math.random(1, Config.chanceGettingItem)
        if chance3 < Config.receiveItem then
            local chance4 <const> = math.random(1, #Config.items)
            local count <const> = 1
            local canCarryInv <const> = exports.vorp_inventory:canCarryItem(_source, Config.items[chance4].name, count)
            if not canCarryInv then
                return print("cant carry")
            end

            exports.vorp_inventory:addItem(_source, Config.items[chance4].name, count)

            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.youGot .. Config.items[chance4].label, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, T.youGot .. Config.items[chance4].label, "BLIPS", "blip_ambient_bounty_target", 3000, "COLOR_GREEN")
            end
        else
            if Config.useNotifyRight then
                Core.NotifyRightTip(_source, T.noItem, 3000)
            else
                Core.NotifyLeft(_source, T.notifytitle, "" .. T.noItem .. "", "BLIPS", "blip_destroy", 3000, "COLOR_RED")
            end
        end
    end
end)
