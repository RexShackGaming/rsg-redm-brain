local Core = exports.vorp_core:GetCore()
local inventory = exports.vorp_inventory

RegisterServerEvent("vorp_weapons:addcomp", function(weaponid, added)
    local components = json.encode(added)
    if weaponid then
        local Parameters = { id = weaponid, comp = components }
        MySQL.query("UPDATE loadout Set comps=@comp WHERE id=@id", Parameters)
    end
end)

RegisterServerEvent("syn_weapons:weaponused", function(data)
    local _source = source
    local id = data.id
    local hash = data.hash
    MySQL.query('SELECT comps, used2 FROM loadout WHERE id = @id ', { id = id }, function(result)
        if result[1] then
            local components = json.decode(result[1].comps)
            TriggerClientEvent("vorp_weapons:givecomp", _source, components, id, hash)
        end
    end)
end)

RegisterServerEvent("vorp_weapons:checkmoney", function(sum)
    local _source = source
    local Character = Core.getUser(source).getUsedCharacter
    local currency = Config.General.customizationcurrency == 0 and Character.money or Character.gold

    if currency < sum then
        TriggerClientEvent("vorp_weapons:nomods", _source)
        Core.NotifyRightTip(_source, Config.Language.cantafford, 3000)
        return
    end

    Character.removeCurrency(0, sum)
    Core.NotifyRightTip(_source, Config.Language.craftingwepmods, 5000)
    TriggerClientEvent("vorp_weapons:applymods", _source)
end)


Core.Callback.Register("vorp_weapons:getjob", function(source, cb)
    local User = Core.getUser(source)
    local Character = User.getUsedCharacter
    local job = Character.job
    local rank = Character.jobGrade
    return cb({ job, rank })
end)


CreateThread(function()
    for _, value in pairs(Config.ammo) do
        for _, m in pairs(value) do
            -- adds ammo to the gunbelt
            inventory:registerUsableItem(m.item, function(data)
                local _source = data.source
                local ammo = inventory:getUserAmmo(_source)
                local count = ammo[m.key] or 0
                if count >= m.maxammo or (m.qt + count) > m.maxammo then
                    return Core.NotifyObjective(_source, "cant use more ammo, max allowed reached", 5000)
                end

                local result = inventory:addBullets(_source, m.key, m.qt)
                if result then
                    inventory:subItemById(_source, data.item.id)
                end
            end, GetCurrentResourceName())
        end
    end
end)

local function contain(table, element)
    for _, v in pairs(table) do
        if v == element then
            return false
        end
    end
    return true
end

function SendWebhookMessage(webhook, message)
    if webhook ~= nil and webhook ~= "" and webhook ~= 0 then
        PerformHttpRequest(webhook, function()
            end,
            'POST',
            json.encode({ content = message }),
            {
                ['Content-Type'] = 'application/json'
            }
        )
    end
end

RegisterServerEvent("vorp_weapons:itemscheck", function(item, materials, craftcost)
    local _source = source
    local checkingtable = {}
    local accepted
    local Character = Core.getUser(_source).getUsedCharacter
    local charmoney = Character.money
    local playername = Character.firstname .. ' ' .. Character.lastname

    for k, v in pairs(materials) do
        local count = inventory:getItemCount(_source, nil, v.name)
        if count - v.amount >= 0 then
            accepted = "true"
        else
            accepted = "false"
        end
        table.insert(checkingtable, accepted)
    end

    local function subItems()
        for k, v in pairs(materials) do
            inventory:subItem(_source, v.name, v.amount)
        end
    end

    local function canCarryItems()
        local canCarry = inventory:canCarryItem(_source, item, 1)
        if not canCarry then
            return false
        end
        return true
    end

    if not canCarryItems() then
        TriggerClientEvent("vorp_weapons:itemcheckfailed", _source)
        return Core.NotifyRightTip(_source, Config.Language.cantcarryitem, 3000)
    end

    if not contain(checkingtable, "false") then
        TriggerClientEvent("vorp_weapons:itemcheckfailed", _source)
        Core.NotifyRightTip(_source, Config.Language.nomaterial, 3000)
        return
    end

    if Config.craftingcost then
        if charmoney >= craftcost then
            Character.removeCurrency(0, craftcost)
        else
            TriggerClientEvent("vorp_weapons:itemcheckfailed", _source)
            Core.NotifyRightTip(_source, Config.Language.nomoneycraft, 3000)
            return
        end
    end

    TriggerClientEvent("vorp_weapons:itemcheckpassed", _source)
    inventory:addItem(_source, item, 1)
    Core.NotifyRightTip(_source, Config.Language.crafting, 3000)
    local message = Config.Language.vorp_weapons .. playername .. Config.Language.crafted .. item
    local adminwebhook = "" -- add here admin webhook
    SendWebhookMessage(adminwebhook, message)
    subItems()
end)

RegisterServerEvent("vorp_weapons:itemscheck2", function(label, item, materials, craftcost)
    local _source = source
    local checkingtable = {}
    local accepted
    local Character = Core.getUser(_source).getUsedCharacter
    local charmoney = Character.money
    local playername = Character.firstname .. ' ' .. Character.lastname

    for k, v in pairs(materials) do
        Wait(100)
        local count = inventory:getItemCount(_source, nil, v.name)
        if count - v.amount >= 0 then
            accepted = "true"
        else
            accepted = "false"
        end
        table.insert(checkingtable, accepted)
    end

    if not contain(checkingtable, "false") then
        TriggerClientEvent("vorp_weapons:itemcheckfailed", _source)
        Core.NotifyRightTip(_source, Config.Language.nomaterial, 3000)
        return
    end

    local function subItem()
        for k, v in pairs(materials) do
            inventory:subItem(_source, v.name, v.amount)
        end
    end

    local function CanCarryWep()
        local canCarry = inventory:canCarryWeapons(_source, 1, nil, item:upper())
        if not canCarry then
            return false
        end
        return true
    end

    if not CanCarryWep() then
        TriggerClientEvent("vorp_weapons:itemcheckfailed", _source)
        Core.NotifyRightTip(_source, Config.Language.cantcarrywep, 3000)
        return
    end

    if Config.General.craftingcost then
        if charmoney >= craftcost then
            Character.removeCurrency(0, craftcost)
        else
            TriggerClientEvent("vorp_weapons:itemcheckfailed", _source)
            Core.NotifyRightTip(_source, Config.Language.nomoneycraft, 5000)
            return
        end
    end

    local ammo = { ["nothing"] = 0 }
    local components = { ["nothing"] = 0 }
    TriggerClientEvent("vorp_weapons:itemcheckpassed2", _source)
    inventory:createWeapon(_source, item, ammo, components)
    Core.NotifyRightTip(_source, Config.Language.crafting, 5000)
    local message = Config.Language.vorp_weapons .. playername .. Config.Language.crafted .. label
    local adminwebhook = "" -- add here webhook
    SendWebhookMessage(adminwebhook, message)
    subItem()
end)
