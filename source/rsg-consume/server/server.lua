-- =========================================================================================
-- Server-side usable item registration & consumption
-- =========================================================================================
local config = require 'shared.config'
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- Safety net: if the client never reports back (crash, desync) the lock is released after this
local CONSUME_TIMEOUT = 30000

---Active consumption per player. Acts as a one-time token: the return item / refund can only
---be claimed once, and only for the item the server actually removed.
---@type table<number, { item: string, category: string, expires: number }>
local pending = {}

local function notifyBusy(src)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('title_consume'),
        description = locale('busy'),
        type = 'error',
        duration = 3000,
    })
end

local function addItem(src, itemName, reason)
    if not RSGCore.Shared.Items[itemName] then return end
    if exports['rsg-inventory']:AddItem(src, itemName, 1, nil, nil, reason) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'add', 1)
    end
end

---Registers every item in a category as usable. The item is removed server-side
---BEFORE the client plays the animation, so the client never decides whether it is consumed.
local function registerConsumables(category, items)
    for itemName in pairs(items) do
        if not RSGCore.Shared.Items[itemName] then
            print(('^3[rsg-consume] Item "%s" (%s) is not in rsg-core shared items, skipping^7'):format(itemName, category))
        else
            RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
                local src = source
                if not RSGCore.Functions.GetPlayer(src) then return end

                local active = pending[src]
                if active and active.expires > GetGameTimer() then
                    return notifyBusy(src)
                end

                if not exports['rsg-inventory']:RemoveItem(src, itemName, 1, item and item.slot, 'rsg-consume') then return end

                pending[src] = { item = itemName, category = category, expires = GetGameTimer() + CONSUME_TIMEOUT }
                TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'remove', 1)
                TriggerClientEvent('rsg-consume:client:consume', src, itemName, category)
            end)
        end
    end
end

for category, items in pairs(config.Consumables) do
    registerConsumables(category, items)
end

---Client reports the consumption finished.
---consumed = true  -> give the configured return item (e.g. emptybottle)
---consumed = false -> client could not play it (busy / passed out / dead), refund the item
RegisterNetEvent('rsg-consume:server:finish', function(consumed)
    local src = source
    local active = pending[src]
    if not active then return end -- no token: spam / replay attempt
    pending[src] = nil

    if not RSGCore.Functions.GetPlayer(src) then return end

    if consumed then
        local data = config.Consumables[active.category][active.item]
        if data.giveItem then addItem(src, data.giveItem, 'rsg-consume-return') end
    else
        addItem(src, active.item, 'rsg-consume-refund')
    end
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
