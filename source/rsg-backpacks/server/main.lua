local RSGCore = exports['rsg-core']:GetCoreObject()

local STASH_PREFIX = 'backpack_'

local Busy = {}
local OpenStash = {} -- [src] = serial of the backpack stash this player legitimately opened

---------------------------------------------
-- SERIALS
---------------------------------------------
local LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'

local function randomDigits(n)
    local out = {}
    for i = 1, n do out[i] = tostring(math.random(0, 9)) end
    return table.concat(out)
end

local function randomLetters(n)
    local out = {}
    for i = 1, n do
        local idx = math.random(1, #LETTERS)
        out[i] = LETTERS:sub(idx, idx)
    end
    return table.concat(out)
end

local function GenerateSerial()
    return randomDigits(4) .. randomLetters(3) .. randomDigits(3) .. randomLetters(3)
end

-- Insert a brand new backpack row with a unique serial (awaited, unique-checked, retried)
local function CreateBackpackRow(itemName, model, citizenId)
    for _ = 1, 10 do
        local serial = GenerateSerial()
        local exists = MySQL.scalar.await('SELECT 1 FROM player_backpack WHERE serial = ?', { serial })
        if not exists then
            local ok, id = pcall(MySQL.insert.await,
                'INSERT INTO player_backpack (serial, citizenid, owner, backpackitem, model) VALUES (?, ?, ?, ?, ?)',
                { serial, citizenId, citizenId, itemName, model })
            if ok and id then
                return serial
            end
        end
    end
    return nil
end

-- undo a row created for a serial that could not be written to the item
local function DeleteSerial(serial)
    MySQL.update.await('DELETE FROM player_backpack WHERE serial = ?', { serial })
end

---------------------------------------------
-- USE ITEM
---------------------------------------------
-- all backpack items the player carries: { { name, amount, slot, info }, ... }
local function GetCarriedBackpacks(Player)
    local list = {}
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and BP.BackpackByItem[it.name] then
            list[#list + 1] = { name = it.name, amount = it.amount or 1, slot = it.slot, info = it.info }
        end
    end
    return list
end

local function CountCarried(list)
    local n = 0
    for _, it in ipairs(list) do n = n + it.amount end
    return n
end

local function HandleUse(src, Player, cfg, item)
    if Config.OneBackpackOnly and CountCarried(GetCarriedBackpacks(Player)) > 1 then
        BP.Notify(src, 'error', 'backpack_title', 'backpack_only_one')
        return
    end

    local citizenId = Player.PlayerData.citizenid
    local info = type(item.info) == 'table' and item.info or {}
    local serial = info.serie

    if type(serial) ~= 'string' or serial == '' then
        -- first use: assign a serial to this exact item slot
        serial = CreateBackpackRow(cfg.item, cfg.model, citizenId)
        if not serial then
            BP.Notify(src, 'error', 'error_title', 'backpack_serial_failed')
            return
        end

        local newInfo = {}
        for k, v in pairs(info) do newInfo[k] = v end
        newInfo.serie = serial

        -- write the serial straight into the item in its slot (no remove/add, so the item can never be lost)
        local okSet, set = pcall(function()
            return exports['rsg-inventory']:SetItemData(src, cfg.item, 'info', newInfo, item.slot)
        end)
        if not okSet or set == false then
            DeleteSerial(serial)
            BP.Notify(src, 'error', 'error_title', 'backpack_serial_failed')
            return
        end
    else
        -- serial already on the item: make sure it is a known backpack
        if #serial > 32 or not serial:match('^[%w]+$') then
            BP.Notify(src, 'error', 'error_title', 'backpack_not_found')
            return
        end

        local row = MySQL.single.await('SELECT owner FROM player_backpack WHERE serial = ?', { serial })
        if not row then
            -- legacy item / lost row: re-register it so the stash stays reachable
            MySQL.insert.await(
                'INSERT IGNORE INTO player_backpack (serial, citizenid, owner, backpackitem, model) VALUES (?, ?, ?, ?, ?)',
                { serial, citizenId, citizenId, cfg.item, cfg.model })
        elseif row.owner ~= citizenId then
            MySQL.update.await('UPDATE player_backpack SET owner = ? WHERE serial = ?', { citizenId, serial })
        end
    end

    -- wear the prop (client visual) and open the stash straight from the server
    TriggerClientEvent('rsg-backpacks:client:wear', src, cfg.item, serial)
    OpenStash[src] = serial
    exports['rsg-inventory']:OpenInventory(src, STASH_PREFIX .. serial, {
        label = locale('backpack_title'),
        maxweight = cfg.maxweight,
        slots = cfg.slots,
    })
end

local function RegisterUseableBackpacks()
    for _, cfg in ipairs(Config.backpackType) do
        RSGCore.Functions.CreateUseableItem(cfg.item, function(source, item)
            local src = source
            local Player = RSGCore.Functions.GetPlayer(src)
            if not Player or type(item) ~= 'table' or not BP.DatabaseReady then return end
            if Busy[src] or BP.RateLimited(src, 'use', Config.ActionCooldown) then return end

            Busy[src] = true
            local ok, err = pcall(HandleUse, src, Player, cfg, item)
            Busy[src] = nil

            if not ok then
                print(('^1[rsg-backpacks] use error: %s^0'):format(tostring(err)))
            end
        end)
    end
end

CreateThread(RegisterUseableBackpacks)

AddEventHandler('playerDropped', function()
    Busy[source] = nil
    OpenStash[source] = nil
end)

---------------------------------------------
-- NESTED BACKPACK BLOCK
-- A backpack can never stay inside a backpack stash (including itself).
-- rsg-inventory has no item-move hook, so any backpack found in a backpack stash is
-- moved back to the player who put it there. Runs after every move into a backpack
-- stash and again when the stash is closed (catches other scripts / legacy data).
-- For an instant, lossless block see the optional rsg-inventory patch in the README.
---------------------------------------------
local Sweeping = {}

local function IsBackpackStash(name)
    return type(name) == 'string' and name:sub(1, #STASH_PREFIX) == STASH_PREFIX
end

local function SaveStash(stashName, inv)
    pcall(function()
        MySQL.prepare.await(
            'INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
            { stashName, json.encode(inv.items), json.encode(inv.items) })
    end)
end

local function SweepNestedBackpacks(stashName, src)
    if Sweeping[stashName] then return end

    -- only the player who opened this stash through the server may trigger a sweep (and receive
    -- what is swept out). Stops spoofed events naming someone else's stash. Holding the backpack is
    -- NOT required: a backpack dropped into its own stash is no longer held, and must still come back.
    if not src or OpenStash[src] ~= stashName:sub(#STASH_PREFIX + 1) then return end
    if not RSGCore.Functions.GetPlayer(src) then return end

    local okInv, inv = pcall(function()
        return exports['rsg-inventory']:GetInventory(stashName)
    end)
    if not okInv or type(inv) ~= 'table' or type(inv.items) ~= 'table' then return end

    -- collect first, then modify (never mutate a table while iterating it)
    local found = {}
    for _, it in pairs(inv.items) do
        if it and BP.BackpackByItem[it.name] then
            found[#found + 1] = { name = it.name, amount = it.amount, slot = it.slot, info = it.info }
        end
    end
    if #found == 0 then return end

    Sweeping[stashName] = true
    local changed = false

    for _, it in ipairs(found) do
        if exports['rsg-inventory']:RemoveItem(stashName, it.name, it.amount, it.slot, 'rsg-backpacks-nested-block') then
            local returned = exports['rsg-inventory']:CanAddItem(src, it.name, it.amount)
                and exports['rsg-inventory']:AddItem(src, it.name, it.amount, nil, it.info, 'rsg-backpacks-nested-block')

            if returned then
                changed = true
            else
                -- could not hand it back: restore it so the item is never lost
                exports['rsg-inventory']:AddItem(stashName, it.name, it.amount, it.slot, it.info, 'rsg-backpacks-nested-restore')
            end
        end
    end

    Sweeping[stashName] = nil

    BP.Notify(src, 'error', 'backpack_title', 'backpack_nested_blocked')
    if changed then
        SaveStash(stashName, inv)
        TriggerClientEvent('rsg-inventory:client:updateInventory', src)
    end
end

-- the backpack was given away / dropped while its stash is still open: close it
local function CloseIfNotHeld(src)
    local serial = OpenStash[src]
    local Player = serial and RSGCore.Functions.GetPlayer(src)
    if not Player or BP.GetHeldBackpack(Player, serial) then return end
    OpenStash[src] = nil
    pcall(function() exports['rsg-inventory']:CloseInventory(src, STASH_PREFIX .. serial) end)
end

---------------------------------------------
-- ONE BACKPACK LIMIT
-- A backpack moved into the player's inventory (from a stash, drop, glovebox...) while they
-- already carry one is sent straight back where it came from. Any other way of ending up with
-- two (given by a player / admin / script) is caught by the periodic check: the player is warned
-- and cannot use a backpack until they are back to one.
---------------------------------------------
local function EnforceOneBackpack(src, fromInventory, toSlot)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local carried = GetCarriedBackpacks(Player)
    if CountCarried(carried) <= 1 then return end

    -- the extra one is the backpack that just landed in toSlot
    local extra
    for _, it in ipairs(carried) do
        if it.slot == toSlot then extra = it break end
    end
    if not extra or type(fromInventory) ~= 'string' or fromInventory == 'player' then return end

    if exports['rsg-inventory']:RemoveItem(src, extra.name, extra.amount, extra.slot, 'rsg-backpacks-one-limit') then
        if not exports['rsg-inventory']:AddItem(fromInventory, extra.name, extra.amount, nil, extra.info, 'rsg-backpacks-one-limit') then
            -- source could not take it back: give it back to the player so nothing is lost
            exports['rsg-inventory']:AddItem(src, extra.name, extra.amount, nil, extra.info, 'rsg-backpacks-one-limit-restore')
        end
    end
    BP.Notify(src, 'error', 'backpack_title', 'backpack_only_one')
    TriggerClientEvent('rsg-inventory:client:updateInventory', src)
end

RegisterNetEvent('rsg-inventory:server:SetInventoryData', function(fromInventory, toInventory, _, toSlot)
    local src = source
    local checkLimit = Config.OneBackpackOnly and toInventory == 'player' and fromInventory ~= 'player'
    if not OpenStash[src] and not checkLimit then return end

    SetTimeout(250, function()
        if OpenStash[src] then
            if Config.BlockNestedBackpacks and IsBackpackStash(toInventory) then
                SweepNestedBackpacks(toInventory, src)
            end
            CloseIfNotHeld(src)
        end
        if checkLimit then
            EnforceOneBackpack(src, fromInventory, tonumber(toSlot))
        end
    end)
end)

-- catch-all: warn players who got a second backpack another way (give, admin, other scripts)
if Config.OneBackpackOnly then CreateThread(function()
    while true do
        Wait(15000)
        for _, src in ipairs(GetPlayers()) do
            src = tonumber(src)
            local Player = RSGCore.Functions.GetPlayer(src)
            if Player and CountCarried(GetCarriedBackpacks(Player)) > 1 then
                BP.Notify(src, 'warning', 'backpack_title', 'backpack_drop_extra')
            end
        end
    end
end) end

-- backpack stash closed
RegisterNetEvent('rsg-inventory:server:closeInventory', function(inventory)
    local src = source
    if not IsBackpackStash(inventory) or OpenStash[src] ~= inventory:sub(#STASH_PREFIX + 1) then return end
    SetTimeout(500, function()
        if OpenStash[src] ~= inventory:sub(#STASH_PREFIX + 1) then return end
        if Config.BlockNestedBackpacks then SweepNestedBackpacks(inventory, src) end
        OpenStash[src] = nil
    end)
end)

---------------------------------------------
-- RECOVERY: return backpacks already trapped inside the player's own backpack stashes
-- (e.g. from before the nested block worked). Runs on character load and via /backpackrecover.
-- The "nothing found" message is only shown for the command.
---------------------------------------------
local function GiveBack(src, it)
    return exports['rsg-inventory']:CanAddItem(src, it.name, it.amount or 1)
        and exports['rsg-inventory']:AddItem(src, it.name, it.amount or 1, nil, it.info, 'rsg-backpacks-recover')
end

-- moves backpacks out of one stash into the player's inventory; anything that does not fit stays put
local function RecoverFromStash(src, stashName)
    local recovered = 0
    local okInv, inv = pcall(function() return exports['rsg-inventory']:GetInventory(stashName) end)

    if okInv and type(inv) == 'table' and type(inv.items) == 'table' then
        -- stash loaded in memory: go through rsg-inventory
        local found = {}
        for _, it in pairs(inv.items) do
            if it and BP.BackpackByItem[it.name] then
                found[#found + 1] = { name = it.name, amount = it.amount, slot = it.slot, info = it.info }
            end
        end
        for _, it in ipairs(found) do
            if exports['rsg-inventory']:CanAddItem(src, it.name, it.amount)
                and exports['rsg-inventory']:RemoveItem(stashName, it.name, it.amount, it.slot, 'rsg-backpacks-recover') then
                if GiveBack(src, it) then
                    recovered = recovered + it.amount
                else
                    exports['rsg-inventory']:AddItem(stashName, it.name, it.amount, it.slot, it.info, 'rsg-backpacks-recover-restore')
                end
            end
        end
        if recovered > 0 then SaveStash(stashName, inv) end
        return recovered
    end

    -- not loaded: edit the saved stash row (item is given first, then removed from the row)
    local raw = MySQL.scalar.await('SELECT items FROM inventories WHERE identifier = ?', { stashName })
    local items = raw and json.decode(raw)
    if type(items) ~= 'table' then return 0 end

    local keep = {}
    for _, it in pairs(items) do
        if type(it) == 'table' and BP.BackpackByItem[it.name] and GiveBack(src, it) then
            recovered = recovered + (it.amount or 1)
        else
            keep[#keep + 1] = it
        end
    end
    if recovered > 0 then
        MySQL.update.await('UPDATE inventories SET items = ? WHERE identifier = ?', { json.encode(keep), stashName })
    end
    return recovered
end

local function RecoverTrapped(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return 0 end

    local rows = MySQL.query.await('SELECT serial FROM player_backpack WHERE owner = ?', { Player.PlayerData.citizenid }) or {}
    local recovered = 0

    for _, row in ipairs(rows) do
        local stashName = STASH_PREFIX .. row.serial
        if not Sweeping[stashName] then
            Sweeping[stashName] = true
            local ok, n = pcall(RecoverFromStash, src, stashName)
            Sweeping[stashName] = nil
            if ok then recovered = recovered + n else print(('^1[rsg-backpacks] recover error: %s^0'):format(tostring(n))) end
        end
    end

    if recovered > 0 then
        BP.Notify(src, 'success', 'backpack_title', 'backpack_recovered', recovered)
        TriggerClientEvent('rsg-inventory:client:updateInventory', src)
    end
    return recovered
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if not src or not Config.BlockNestedBackpacks then return end
    SetTimeout(5000, function()
        if BP.DatabaseReady then pcall(RecoverTrapped, src) end
    end)
end)

lib.addCommand('backpackrecover', { help = locale('cmd_recover_help') }, function(source)
    if not BP.DatabaseReady or BP.RateLimited(source, 'recover', 10000) then return end
    local ok, count = pcall(RecoverTrapped, source)
    if ok and count == 0 then
        BP.Notify(source, 'inform', 'backpack_title', 'backpack_nothing_recovered')
    end
end)

-- export used by the optional rsg-inventory patch / other resources
exports('IsBackpackItem', function(itemName)
    return type(itemName) == 'string' and BP.BackpackByItem[itemName] ~= nil
end)
