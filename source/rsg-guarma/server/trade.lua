-------------------------------------
-- island cargo
-------------------------------------
if not Config.Trade.enabled then return end

local RSGCore = exports['rsg-core']:GetCoreObject()
local busy = {} -- [citizenid] = true while a trade is running

local goods = {}
for _, good in ipairs(Config.Trade.goods) do
    goods[good.item] = good
    if good.sell <= good.buy then
        print(('^3[rsg-guarma] cargo "%s" sells for no more than it costs^7'):format(good.item))
    end
end

function Guarma.CargoCount(src)
    local total = 0
    for _, good in ipairs(Config.Trade.goods) do
        total = total + Guarma.ItemCount(src, good.item)
    end
    return total
end

-- sale value, using rsg-economy's market price and trade tax when it is running
local function QuoteSale(src, good, qty)
    if Guarma.IsRunning('rsg-economy') then
        local quote = exports['rsg-economy']:Quote(src, {
            region = Config.Trade.region, mode = 'sell', category = 'trade',
            base = good.sell, qty = qty, item = good.item,
        })
        if quote then return quote.total, quote end
    end
    return Guarma.Round(good.sell * qty)
end

-- cargo rows for the port worker at portId ('buy', 'sell' or nil when this port doesn't trade)
function Guarma.CargoList(src, portId)
    local mode = (portId == Config.Trade.buyPort and 'buy') or (portId == Config.Trade.sellPort and 'sell')
    if not mode then return nil end

    local Player = RSGCore.Functions.GetPlayer(src)
    local record = mode == 'buy' and Player and Guarma.GetRecord(Player.PlayerData.citizenid)
    if mode == 'buy' and not record then return nil end

    local items = {}
    for _, good in ipairs(Config.Trade.goods) do
        if RSGCore.Shared.Items[good.item] then
            items[#items + 1] = {
                item = good.item,
                label = Guarma.ItemLabel(good.item),
                price = mode == 'buy' and good.buy or QuoteSale(src, good, 1),
                owned = Guarma.ItemCount(src, good.item),
                left = record and math.max(0, Config.Trade.dailyLimit - (record.bought[good.item] or 0)) or nil,
            }
        end
    end
    return { mode = mode, items = items }
end

local function Buy(src, Player, good, qty)
    local cid = Player.PlayerData.citizenid
    local record = Guarma.GetRecord(cid)
    if not record then return 'trade_unavailable' end

    -- the record load can yield, so check the player again
    if RSGCore.Functions.GetPlayer(src) ~= Player then return 'trade_unavailable' end

    local bought = record.bought[good.item] or 0
    if bought + qty > Config.Trade.dailyLimit then return 'trade_limit' end
    if not exports['rsg-inventory']:CanAddItem(src, good.item, qty) then return 'no_space' end

    local cost = Guarma.Round(good.buy * qty)
    if not Player.Functions.RemoveMoney('cash', cost, 'guarma-cargo-buy') then return 'not_enough_cash' end
    if not exports['rsg-inventory']:AddItem(src, good.item, qty, nil, nil, 'guarma-cargo-buy') then
        Player.Functions.AddMoney('cash', cost, 'guarma-cargo-refund')
        return 'no_space'
    end

    record.bought[good.item] = bought + qty
    Guarma.SaveRecord(cid)
    Guarma.Notify(src, locale('cargo_title'), 'success', locale('cargo_bought', qty, Guarma.ItemLabel(good.item), cost))
end

local function Sell(src, Player, good, qty)
    if Guarma.ItemCount(src, good.item) < qty then return 'cargo_none' end
    local total, quote = QuoteSale(src, good, qty)
    if not exports['rsg-inventory']:RemoveItem(src, good.item, qty, nil, 'guarma-cargo-sell') then return 'cargo_none' end

    Player.Functions.AddMoney('cash', total, 'guarma-cargo-sell')
    if quote then exports['rsg-economy']:Record(src, quote) end
    Guarma.Notify(src, locale('cargo_title'), 'success', locale('cargo_sold', qty, Guarma.ItemLabel(good.item), total))
end

RSGCore.Functions.CreateCallback('rsg-guarma:server:trade', function(src, cb, portId, item, qty)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Guarma.CanAct(Player) then return cb(false) end

    local good = type(item) == 'string' and goods[item]
    qty = math.tointeger(tonumber(qty))
    if not good or not RSGCore.Shared.Items[item] or not qty or qty < 1 or qty > Config.Trade.dailyLimit then
        return cb(false)
    end
    if not Guarma.GetNearPort(src, portId) then
        Guarma.Notify(src, locale('too_far'), 'error')
        return cb(false)
    end

    local action = (portId == Config.Trade.buyPort and Buy) or (portId == Config.Trade.sellPort and Sell)
    local cid = Player.PlayerData.citizenid
    if not action or busy[cid] then return cb(false) end

    busy[cid] = true
    local ok, err = pcall(action, src, Player, good, qty)
    busy[cid] = nil

    if not ok then
        print(('^1[rsg-guarma] cargo trade failed: %s^7'):format(err))
        return cb(false)
    end
    if err then Guarma.Notify(src, locale(err), 'error') end
    cb(not err)
end)
