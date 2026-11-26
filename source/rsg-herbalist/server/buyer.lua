----------------------------------------------------------------------------
-- Herb buyer (server-authoritative)
--
-- NPC that buys tonics, teas and dried herbs at fixed prices from Config.Buyer.
-- The client only sends a slot and an amount; the item, tier, price and
-- distance are all read/decided here.
----------------------------------------------------------------------------

local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = Config.Buyer
if not cfg or not cfg.Enabled then return end

local Notify = Herbalist.Notify
local IsDead = Herbalist.IsDead
local STATE_KEY = 'buyers_v1'
local placedLoaded = false

local placed = {}      -- admin-placed buyers: { x, y, z, w }
local lastSaleAt = {}
local lastRequestAt = {}

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

local function loadPlaced(raw)
    local ok, data = pcall(json.decode, raw or '')
    if not ok or type(data) ~= 'table' then return end
    for _, b in ipairs(data) do
        if type(b.x) == 'number' and type(b.y) == 'number' and type(b.z) == 'number' and type(b.w) == 'number' then
            placed[#placed + 1] = { x = b.x, y = b.y, z = b.z, w = b.w }
        end
    end
end

local function savePlaced()
    Herbalist.SaveState(STATE_KEY, placed)
end

-- static config spots first, then admin-placed ones
local function allBuyers()
    local list = {}
    for _, loc in ipairs(cfg.locations or {}) do
        local c = loc.coords
        list[#list + 1] = { x = c.x, y = c.y, z = c.z, w = c.w }
    end
    for _, b in ipairs(placed) do list[#list + 1] = b end
    return list
end

local function broadcastBuyers(target)
    TriggerClientEvent('rsg-herbalist:client:SetBuyers', target or -1, allBuyers())
end

local function nearBuyer(src, maxDist)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    for _, b in ipairs(allBuyers()) do
        if #(pos - vector3(b.x, b.y, b.z)) <= maxDist then return b end
    end
    return nil
end

local function itemLabel(name)
    local def = RSGCore.Shared.Items[name]
    return def and def.label or name
end

-- rsg-economy (optional): town tax + standing price modifier, same approach as rsg-fishmonger
local function economyQuote(src, buyer, base)
    if not cfg.UseEconomy or GetResourceState('rsg-economy') ~= 'started' then return nil end
    local ok, q = pcall(function()
        local region = exports['rsg-economy']:GetRegionAt(vector3(buyer.x, buyer.y, buyer.z))
        if not region then return nil end
        return exports['rsg-economy']:Quote(src, { region = region, mode = 'sell', base = base, qty = 1, market = false })
    end)
    if ok and type(q) == 'table' and type(q.total) == 'number' and q.total >= 0 and q.total < math.huge then return q end
    return nil
end

local function unitPrice(name, info)
    local base = cfg.prices[name]
    if not base then return nil end
    local tierKey = type(info) == 'table' and info.tonic_tier
    local tier = tierKey and GetTonicTierByKey(tierKey)
    return base * (tier and tier.priceMult or 1.0)
end

local function buildRows(src, Player, buyer)
    local q = economyQuote(src, buyer, 1000)
    local factor = q and (q.total / 1000) or 1.0
    local rows = {}
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name and it.amount and it.amount > 0 then
            local unit = unitPrice(it.name, it.info)
            if unit then
                rows[#rows + 1] = {
                    slot = tonumber(it.slot),
                    name = it.name,
                    tier = type(it.info) == 'table' and it.info.tonic_tier or nil,
                    amount = it.amount,
                    unit = round2(unit * factor),
                }
            end
        end
    end
    table.sort(rows, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return rows
end

RSGCore.Functions.CreateCallback('rsg-herbalist:server:getBuyerStock', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    local buyer = Player and nearBuyer(source, cfg.MaxUseDistance + 3.0)
    if not Player or not buyer then return cb(nil) end
    cb(buildRows(source, Player, buyer))
end)

RegisterNetEvent('rsg-herbalist:server:requestBuyers', function()
    local src = source
    local now = GetGameTimer()
    if lastRequestAt[src] and now - lastRequestAt[src] < 5000 then return end
    lastRequestAt[src] = now
    broadcastBuyers(src)
end)

RegisterNetEvent('rsg-herbalist:server:sell', function(slot, amount)
    local src = source
    local now = GetGameTimer()
    if lastSaleAt[src] and now - lastSaleAt[src] < cfg.SaleCooldownMs then return end
    lastSaleAt[src] = now

    slot, amount = math.tointeger(tonumber(slot)), math.tointeger(tonumber(amount))
    if not slot or not amount or amount < 1 then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or IsDead(Player) then return end

    local buyer = nearBuyer(src, cfg.MaxUseDistance + 3.0)
    if not buyer then
        Webhook.FlagSuspicious(src, 'sell_distance', 'slot=' .. slot)
        return
    end

    local item
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and tonumber(it.slot) == slot then item = it break end
    end
    local unit = item and unitPrice(item.name, item.info)
    if not item or not unit then
        Webhook.FlagSuspicious(src, 'sell_invalid_item', 'slot=' .. slot)
        return
    end

    amount = math.min(amount, item.amount, cfg.MaxPerSale)
    local total = round2(unit * amount)
    local quote = economyQuote(src, buyer, total)
    if quote then total = round2(quote.total) end
    if total <= 0 then return end

    local name, info = item.name, item.info
    if not exports['rsg-inventory']:RemoveItem(src, name, amount, slot, 'rsg-herbalist:sell') then
        Notify(src, locale('buyer_title'), locale('buyer_error_description'))
        return
    end
    if not Player.Functions.AddMoney(cfg.MoneyType, total, 'rsg-herbalist:sell') then
        exports['rsg-inventory']:AddItem(src, name, amount, info, nil, 'rsg-herbalist:sell-rollback')
        Notify(src, locale('buyer_title'), locale('buyer_error_description'))
        return
    end
    if quote then pcall(function() exports['rsg-economy']:Record(src, quote) end) end

    Notify(src, locale('buyer_title'), locale('buyer_sold_description', amount, itemLabel(name), ('%.2f'):format(total)), 'success')
    Webhook.LogSale(src, itemLabel(name), amount, total)
    TriggerClientEvent('rsg-herbalist:client:BuyerStock', src, buildRows(src, Player, buyer))
end)

----------------------------------------------------------------------------
-- Admin placement: stand where the buyer should be and run the command.
----------------------------------------------------------------------------

RegisterCommand('addherbbuyer', function(source)
    if source == 0 or not RSGCore.Functions.HasPermission(source, cfg.AdminPermission) then return end
    if not placedLoaded then return end
    if #placed >= cfg.MaxPlaced then return end
    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    placed[#placed + 1] = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
    savePlaced()
    broadcastBuyers()
    Notify(source, locale('buyer_title'), locale('buyer_added'), 'success')
end, false)

RegisterCommand('removeherbbuyer', function(source)
    if source == 0 or not RSGCore.Functions.HasPermission(source, cfg.AdminPermission) then return end
    if not placedLoaded then return end
    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local pos = GetEntityCoords(ped)
    local bestIdx, bestDist
    for i, b in ipairs(placed) do
        local d = #(pos - vector3(b.x, b.y, b.z))
        if d <= 5.0 and (not bestDist or d < bestDist) then bestIdx, bestDist = i, d end
    end
    if not bestIdx then
        Notify(source, locale('buyer_title'), locale('buyer_none_near'))
        return
    end
    table.remove(placed, bestIdx)
    savePlaced()
    broadcastBuyers()
    Notify(source, locale('buyer_title'), locale('buyer_removed'), 'success')
end, false)

AddEventHandler('playerDropped', function()
    lastSaleAt[source] = nil
    lastRequestAt[source] = nil
end)

Herbalist.LoadState(STATE_KEY, function(raw)
    loadPlaced(raw)
    placedLoaded = true
    broadcastBuyers()
end)
