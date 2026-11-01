local RSGCore = exports['rsg-core']:GetCoreObject()
local cooldowns = {}

local function notify(src, title, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = title, description = description, type = ntype, duration = 5000 })
end

local function decode(str)
    if type(str) ~= 'string' or str == '' then return nil end
    local ok, data = pcall(json.decode, str)
    return ok and type(data) == 'table' and data or nil
end

RSGCore.Functions.CreateCallback('rsg-barbers:server:purchase', function(source, cb, barberid, payload)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb({ ok = false, reason = 'error' }) end

    local now = os.time()
    if cooldowns[src] and now - cooldowns[src] < Config.Cooldown then return cb({ ok = false, reason = 'busy' }) end
    cooldowns[src] = now

    local loc = type(barberid) == 'string' and Barber.GetLocation(barberid)
    if not loc or type(payload) ~= 'table' then return cb({ ok = false, reason = 'error' }) end

    if #(GetEntityCoords(GetPlayerPed(src)) - loc.seat.xyz) > Config.MaxDistance then
        return cb({ ok = false, reason = 'too_far' })
    end

    local citizenid = Player.PlayerData.citizenid
    local row = MySQL.single.await('SELECT skin FROM playerskins WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { citizenid })
    local skin = row and decode(row.skin)
    if not skin then return cb({ ok = false, reason = 'error' }) end

    local isMale = (tonumber(Player.PlayerData.charinfo and Player.PlayerData.charinfo.gender) or 0) == 0
    local gender = isMale and 'male' or 'female'
    local changed = false

    -- hair / beard: client sends model+texture indexes, server resolves the hash
    local categories = isMale and { 'hair', 'beard' } or { 'hair' }
    for _, cat in ipairs(categories) do
        local sel = payload[cat]
        if type(sel) == 'table' then
            local hash = Barber.ResolveHash(gender, cat, sel.model, sel.texture)
            if not hash then return cb({ ok = false, reason = 'error' }) end
            if hash ~= Barber.StoredHash(gender, cat, skin[cat]) then
                skin[cat] = { hash = hash }
                changed = true
            end
        end
    end

    -- makeup: whitelisted keys with integer ranges from config
    for _, def in ipairs(Config.Makeup) do
        local value = payload[def.key]
        if value ~= nil and (isMale or not def.maleOnly) then
            value = math.tointeger(tonumber(value))
            if not value or value < def.min or value > def.max then return cb({ ok = false, reason = 'error' }) end
            if tonumber(skin[def.key]) ~= value then
                skin[def.key] = value
                changed = true
            end
        end
    end

    if not changed then return cb({ ok = false, reason = 'no_changes' }) end

    local price = Barber.GetPrice(loc)
    if price > 0 and not Player.Functions.RemoveMoney('cash', price, 'barber-' .. loc.barberid) then
        return cb({ ok = false, reason = 'no_money', price = price })
    end

    local affected = MySQL.update.await('UPDATE playerskins SET skin = ? WHERE citizenid = ?', { json.encode(skin), citizenid })
    if not affected or affected == 0 then
        if price > 0 then Player.Functions.AddMoney('cash', price, 'barber-refund') end
        return cb({ ok = false, reason = 'error' })
    end

    notify(src, locale('purchased_title'), locale('purchased', price), 'success')
    cb({ ok = true })
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
