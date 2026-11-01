local RSGCore = exports['rsg-core']:GetCoreObject()

local Models = {}    -- [model] = { id, model, label, description, price, enabled }
local Yards = {}     -- [id] = { id, name, coords = vector4, spawn = vector4|nil, dock = { coords = vector4, radius }|nil, models = { [model] = true }|nil }
local Active = {}    -- [src] = { ownedId, netId, yard }
local Cooldowns = {}
local Offers = {}     -- [targetSrc] = true while a transfer offer is waiting for an answer

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function notify(src, msg, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('notify_title'), description = msg, type = ntype or 'inform', duration = 5000 })
end

-- rsg-core callback with a plain return value (handlers run in their own thread, so awaits are safe)
local function callback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(src, cb, ...) cb(fn(src, ...)) end)
end

local function onCooldown(src)
    local now = GetGameTimer()
    if Cooldowns[src] and now - Cooldowns[src] < Config.Cooldown then return true end
    Cooldowns[src] = now
    return false
end

local function isAdmin(src)
    if RSGCore.Functions.HasPermission(src, Config.AdminPermission) or IsPlayerAceAllowed(src, 'command') then return true end
    -- the admin panel is never opened for non-admins, so this is a modified client
    BoatLog('exploit', src, locale('wh_admin_no_perm'), {}, locale('wh_admin_no_perm_desc'))
    return false
end

local function v4(t) return t and t.x and vector4(t.x + 0.0, t.y + 0.0, t.z + 0.0, (t.w or 0.0) + 0.0) or nil end
local function t4(v) return v and { x = v.x, y = v.y, z = v.z, w = v.w } or nil end

local function pedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return vector4(c.x, c.y, c.z, GetEntityHeading(ped) % 360.0)
end

local function nearYard(src, yard, radius)
    local ped = GetPlayerPed(src)
    if not yard or not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - yard.coords.xyz) <= (radius or Config.ActionRadius)
end

local function cleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' or #name > 64 then return nil end
    return name
end

-- nil models list = every boat is allowed at this yard
local function allowedAt(yard, model)
    return not yard.models or yard.models[model] == true
end

local function modelArray(set)
    if not set then return nil end
    local list = {}
    for m in pairs(set) do list[#list + 1] = m end
    table.sort(list)
    return list
end

local function getSpawn(yard)
    if yard.spawn then return yard.spawn end
    local c = yard.coords
    local h = math.rad(c.w)
    local o = Config.FallbackSpawnOffset
    local x = c.x + (o.x * math.cos(h) - o.y * math.sin(h))
    local y = c.y + (o.x * math.sin(h) + o.y * math.cos(h))
    return vector4(x, y, c.z + o.z, c.w)
end

local function getDock(yard)
    return yard.dock or { coords = yard.coords, radius = Config.Dock.radius }
end

local function dockPayload(yard)
    local d = getDock(yard)
    return { x = d.coords.x, y = d.coords.y, z = d.coords.z, w = d.coords.w, r = d.radius, set = yard.dock ~= nil }
end

-- what every client needs: NPC/blip position and dock zone per yard
local function publicYards()
    local list = {}
    for _, y in pairs(Yards) do
        list[#list + 1] = { id = y.id, name = y.name, coords = t4(y.coords), dock = dockPayload(y) }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function adminYards()
    local list = publicYards()
    for _, y in ipairs(list) do y.spawn = t4(Yards[y.id].spawn); y.models = modelArray(Yards[y.id].models) end
    return list
end

local function broadcastYards() TriggerClientEvent('rsg-boats:client:yards', -1, publicYards()) end

local function yardHasBoatsOut(id)
    for _, a in pairs(Active) do if a.yard == id then return true end end
    return false
end

local function saveYard(y)
    MySQL.update.await('UPDATE rsg_boats_yards SET name = ?, coords = ?, spawn = ?, dock = ?, models = ? WHERE id = ?', {
        y.name, json.encode(t4(y.coords)),
        y.spawn and json.encode(t4(y.spawn)) or nil,
        y.dock and json.encode({ x = y.dock.coords.x, y = y.dock.coords.y, z = y.dock.coords.z, w = y.dock.coords.w, r = y.dock.radius }) or nil,
        y.models and json.encode(modelArray(y.models)) or nil,
        y.id,
    })
end

---------------------------------------------------------------------
-- loading
---------------------------------------------------------------------
local function loadModels()
    Models = {}
    local rows = MySQL.query.await('SELECT * FROM rsg_boats_models ORDER BY price ASC') or {}
    for _, r in ipairs(rows) do
        r.enabled = r.enabled == 1 or r.enabled == true
        Models[r.model] = r
    end
end

local function setting(k)
    local v = MySQL.scalar.await('SELECT v FROM rsg_boats_settings WHERE k = ?', { k })
    return v and json.decode(v) or nil
end

local function loadYards()
    Yards = {}
    local rows = MySQL.query.await('SELECT * FROM rsg_boats_yards ORDER BY id ASC') or {}

    -- first run: build yard #1 from the old single-yard settings (or the config default)
    if #rows == 0 then
        local old = setting('yard')
        local coords = old and json.encode(old) or json.encode(t4(Config.Yard.coords))
        local spawn, dock = setting('spawn'), setting('dock')
        MySQL.insert.await('INSERT INTO rsg_boats_yards (name, coords, spawn, dock) VALUES (?, ?, ?, ?)', {
            Config.Yard.defaultName, coords, spawn and json.encode(spawn) or nil, dock and json.encode(dock) or nil,
        })
        MySQL.query.await("DELETE FROM rsg_boats_settings WHERE k IN ('yard', 'spawn', 'dock')")
        rows = MySQL.query.await('SELECT * FROM rsg_boats_yards ORDER BY id ASC') or {}
    end

    for _, r in ipairs(rows) do
        local c, s, d = json.decode(r.coords or ''), r.spawn and json.decode(r.spawn), r.dock and json.decode(r.dock)
        local ml = r.models and json.decode(r.models)
        local set = nil
        if type(ml) == 'table' then set = {} for _, m in ipairs(ml) do set[m] = true end end
        if c and c.x then
            Yards[r.id] = {
                models = set,
                id = r.id, name = r.name, coords = v4(c), spawn = v4(s),
                dock = d and d.x and { coords = v4(d), radius = tonumber(d.r) or Config.Dock.radius } or nil,
            }
        end
    end
end

CreateThread(function()
    InstallDatabase()
    loadModels()
    loadYards()
    broadcastYards()
end)

callback('rsg-boats:server:getYards', function() return publicYards() end)

-- true when this boat may be launched/sold at yardId
local function storedHere(row, yardId)
    if not Config.LockToYard then return true end
    return row.yard == nil or row.yard == yardId or not Yards[row.yard]
end

local function modelList(onlyEnabled)
    local list = {}
    for _, m in pairs(Models) do
        if not onlyEnabled or m.enabled then list[#list + 1] = m end
    end
    table.sort(list, function(a, b) return a.price < b.price end)
    return list
end

---------------------------------------------------------------------
-- shop
---------------------------------------------------------------------
callback('rsg-boats:server:getShopData', function(src, yardId)
    local Player = RSGCore.Functions.GetPlayer(src)
    local yard = Yards[tonumber(yardId) or -1]
    if not Player or not yard then return nil end
    local owned = MySQL.query.await('SELECT id, model, label, yard FROM rsg_boats_owned WHERE citizenid = ? ORDER BY id ASC',
        { Player.PlayerData.citizenid }) or {}
    for _, b in ipairs(owned) do
        local m = Models[b.model]
        b.sellPrice = m and math.floor(m.price * Config.SellBackRate) or 0
        b.out = Active[src] and Active[src].ownedId == b.id or false
        b.here = storedHere(b, yard.id)
        b.storedAt = (not b.here and Yards[b.yard]) and Yards[b.yard].name or nil
        b.yard = nil
    end
    return {
        yard = yard.id,
        name = yard.name,
        models = (function()
            local l = {}
            for _, m in ipairs(modelList(true)) do if allowedAt(yard, m.model) then l[#l + 1] = m end end
            return l
        end)(),
        owned = owned,
        cash = Player.PlayerData.money[Config.MoneyType] or 0,
        hasActive = Active[src] ~= nil,
        canTransfer = Config.Transfer.enabled,
    }
end)

callback('rsg-boats:server:buy', function(src, yardId, model)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(model) ~= 'string' then return false end
    if onCooldown(src) then notify(src, locale('slow_down'), 'error') return false end
    local yard = Yards[tonumber(yardId) or -1]
    if not nearYard(src, yard) then notify(src, locale('too_far'), 'error') return false end

    local m = Models[model]
    if not m or not m.enabled or not allowedAt(yard, model) then notify(src, locale('no_boat_model'), 'error') return false end

    if Config.MaxBoats > 0 then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_boats_owned WHERE citizenid = ?', { Player.PlayerData.citizenid })
        if (tonumber(count) or 0) >= Config.MaxBoats then notify(src, locale('max_boats', Config.MaxBoats), 'error') return false end
    end

    if not Player.Functions.RemoveMoney(Config.MoneyType, m.price, 'boat-purchase') then
        notify(src, locale('no_money'), 'error')
        return false
    end

    MySQL.insert.await('INSERT INTO rsg_boats_owned (citizenid, model, label, yard) VALUES (?, ?, ?, ?)',
        { Player.PlayerData.citizenid, m.model, m.label, yard.id })
    notify(src, locale('bought', m.label, m.price), 'success')
    BoatLog('buy', src, locale('wh_boat_bought'), { { locale('wh_f_boat'), ('%s (%s)'):format(m.label, m.model) }, { locale('wh_f_price'), '$' .. m.price }, { locale('wh_f_yard'), yard.name } })
    return true
end)

callback('rsg-boats:server:launch', function(src, yardId, ownedId)
    local Player = RSGCore.Functions.GetPlayer(src)
    local yard = Yards[tonumber(yardId) or -1]
    ownedId = tonumber(ownedId)
    if not Player or not ownedId or not yard then return false end
    if onCooldown(src) then notify(src, locale('slow_down'), 'error') return false end
    if not nearYard(src, yard) then notify(src, locale('too_far'), 'error') return false end
    if Active[src] then notify(src, locale('already_out'), 'error') return false end

    local row = MySQL.single.await('SELECT id, model, label, yard FROM rsg_boats_owned WHERE id = ? AND citizenid = ?',
        { ownedId, Player.PlayerData.citizenid })
    if not row then notify(src, locale('not_owned'), 'error') return false end
    if not storedHere(row, yard.id) then notify(src, locale('stored_elsewhere', Yards[row.yard].name), 'error') return false end

    local spawn = getSpawn(yard)
    local entry = { ownedId = row.id, netId = nil, yard = yard.id, model = row.model, spawn = spawn }
    Active[src] = entry
    -- a client that never reports its boat (crash, modified client) must not lock the slot forever
    SetTimeout(30000, function()
        if Active[src] == entry and not entry.netId then Active[src] = nil end
    end)
    BoatLog('launch', src, locale('wh_boat_launched'), { { locale('wh_f_boat'), ('%s #%s'):format(row.label, row.id) }, { locale('wh_f_yard'), yard.name } })
    return { model = row.model, label = row.label, spawn = spawn }
end)

-- client reports the boat it spawned; only accepted once, only for the right model,
-- near the launch point and not already claimed by someone else (stops a client claiming someone else's entity)
RegisterNetEvent('rsg-boats:server:launched', function(netId)
    local src = source
    local a = Active[src]
    if not a or a.netId or type(netId) ~= 'number' or netId == 0 then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local function reject(why)
        BoatLog('exploit', src, locale('wh_rejected_claim'), { { locale('wh_f_reason'), why }, { locale('wh_f_net_id'), netId }, { locale('wh_f_expected_model'), a.model } },
            locale('wh_rejected_claim_desc'))
    end
    if (GetEntityModel(ent) & 0xFFFFFFFF) ~= (joaat(a.model) & 0xFFFFFFFF) then return reject(locale('wh_reason_wrong_model')) end
    if #(GetEntityCoords(ent) - a.spawn.xyz) > 25.0 then return reject(locale('wh_reason_too_far')) end
    for other, oa in pairs(Active) do
        if other ~= src and oa.netId == netId then return reject(locale('wh_reason_taken', other)) end
    end
    a.netId = netId
end)

RegisterNetEvent('rsg-boats:server:launchFailed', function()
    local src = source
    if Active[src] and not Active[src].netId then Active[src] = nil end
end)

-- fromDock = false: shop 'Store Boat' button at yardId; true: dock prompt at yardId's dock
callback('rsg-boats:server:store', function(src, yardId, fromDock)
    local Player = RSGCore.Functions.GetPlayer(src)
    local yard = Yards[tonumber(yardId) or -1]
    if not Player or not yard then return false end
    if onCooldown(src) then notify(src, locale('slow_down'), 'error') return false end
    local a = Active[src]
    if not a then notify(src, locale('no_boat_out'), 'error') return false end

    local ent = a.netId and NetworkGetEntityFromNetworkId(a.netId) or 0
    local exists = ent and ent ~= 0 and DoesEntityExist(ent)

    if fromDock then
        local dock = getDock(yard)
        local pos = exists and GetEntityCoords(ent) or GetEntityCoords(GetPlayerPed(src))
        local flat = #(vector2(pos.x, pos.y) - vector2(dock.coords.x, dock.coords.y))
        if flat > dock.radius + 5.0 then notify(src, locale('dock_too_far'), 'error') return false end
    else
        if not nearYard(src, yard) then notify(src, locale('too_far'), 'error') return false end
        if exists and #(GetEntityCoords(ent) - yard.coords.xyz) > Config.StoreRadius then
            notify(src, locale('boat_too_far'), 'error')
            return false
        end
    end

    if a.model and not allowedAt(yard, a.model) then
        notify(src, locale('dock_not_allowed', yard.name), 'error')
        return false
    end

    if exists then DeleteEntity(ent) end
    MySQL.update.await('UPDATE rsg_boats_owned SET yard = ? WHERE id = ? AND citizenid = ?',
        { yard.id, a.ownedId, Player.PlayerData.citizenid })
    Active[src] = nil
    notify(src, locale('stored_at', yard.name), 'success')
    BoatLog('store', src, locale('wh_boat_stored'), { { locale('wh_f_boat'), ('%s #%s'):format(a.model, a.ownedId) }, { locale('wh_f_yard'), yard.name }, { locale('wh_f_method'), fromDock and locale('wh_dock_prompt') or locale('wh_shop') } })
    return dockPayload(yard)
end)

callback('rsg-boats:server:sell', function(src, yardId, ownedId)
    local Player = RSGCore.Functions.GetPlayer(src)
    ownedId = tonumber(ownedId)
    if not Player or not ownedId then return false end
    if onCooldown(src) then notify(src, locale('slow_down'), 'error') return false end
    local yard = Yards[tonumber(yardId) or -1]
    if not nearYard(src, yard) then notify(src, locale('too_far'), 'error') return false end
    if Active[src] and Active[src].ownedId == ownedId then notify(src, locale('already_out'), 'error') return false end

    local row = MySQL.single.await('SELECT id, model, label, yard FROM rsg_boats_owned WHERE id = ? AND citizenid = ?',
        { ownedId, Player.PlayerData.citizenid })
    if not row then notify(src, locale('not_owned'), 'error') return false end
    if not storedHere(row, yard.id) then notify(src, locale('stored_elsewhere', Yards[row.yard].name), 'error') return false end

    local affected = MySQL.update.await('DELETE FROM rsg_boats_owned WHERE id = ? AND citizenid = ?',
        { row.id, Player.PlayerData.citizenid })
    if not affected or affected < 1 then return false end

    if Config.Storage.enabled then
        -- anything left in the boat's storage goes with the boat
        pcall(function() exports['rsg-inventory']:ClearStash('boat_' .. row.id) end)
    end

    local m = Models[row.model]
    local refund = m and math.floor(m.price * Config.SellBackRate) or 0
    if refund > 0 then Player.Functions.AddMoney(Config.MoneyType, refund, 'boat-sell') end
    notify(src, locale('sold', row.label, refund), 'success')
    BoatLog('sell', src, locale('wh_boat_sold'), { { locale('wh_f_boat'), ('%s #%s'):format(row.label, row.id) }, { locale('wh_f_refund'), '$' .. refund }, { locale('wh_f_yard'), yard.name } })
    return true
end)

---------------------------------------------------------------------
-- transfer ownership
---------------------------------------------------------------------
callback('rsg-boats:server:transfer', function(src, yardId, ownedId, targetId)
    if not Config.Transfer.enabled then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    local yard = Yards[tonumber(yardId) or -1]
    ownedId, targetId = tonumber(ownedId), tonumber(targetId)
    if not Player or not yard or not ownedId or not targetId then return false end
    if onCooldown(src) then notify(src, locale('slow_down'), 'error') return false end
    if not nearYard(src, yard) then notify(src, locale('too_far'), 'error') return false end
    if targetId == src then notify(src, locale('transfer_self'), 'error') return false end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then notify(src, locale('transfer_no_player'), 'error') return false end
    if Config.MaxBoats > 0 then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_boats_owned WHERE citizenid = ?', { Target.PlayerData.citizenid })
        if (tonumber(count) or 0) >= Config.MaxBoats then notify(src, locale('transfer_target_full'), 'error') return false end
    end
    local sp, tp = GetPlayerPed(src), GetPlayerPed(targetId)
    if #(GetEntityCoords(sp) - GetEntityCoords(tp)) > Config.Transfer.maxDistance then
        notify(src, locale('transfer_too_far'), 'error')
        return false
    end
    if Active[src] and Active[src].ownedId == ownedId then notify(src, locale('already_out'), 'error') return false end

    local row = MySQL.single.await('SELECT id, model, label, yard FROM rsg_boats_owned WHERE id = ? AND citizenid = ?',
        { ownedId, Player.PlayerData.citizenid })
    if not row then notify(src, locale('not_owned'), 'error') return false end
    if not storedHere(row, yard.id) then notify(src, locale('stored_elsewhere', Yards[row.yard].name), 'error') return false end

    local fromName = ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    local toName = ('%s %s'):format(Target.PlayerData.charinfo.firstname, Target.PlayerData.charinfo.lastname)

    if Config.Transfer.requireAccept then
        if Offers[targetId] then notify(src, locale('transfer_busy', toName), 'error') return false end
        notify(src, locale('transfer_waiting', toName), 'inform')
        Offers[targetId] = true
        local accepted = RSGCore.Functions.AwaitClientCallback('rsg-boats:client:transferOffer', targetId,
            (Config.Transfer.acceptTimeout + 2) * 1000, fromName, row.label, yard.name)
        Offers[targetId] = nil
        if accepted ~= true then notify(src, locale('transfer_declined', toName), 'error') return false end
        Target = RSGCore.Functions.GetPlayer(targetId)
        if not Target then notify(src, locale('transfer_no_player'), 'error') return false end
        -- the owner may have launched this boat while the offer was open
        if Active[src] and Active[src].ownedId == row.id then notify(src, locale('already_out'), 'error') return false end
        if Config.MaxBoats > 0 then
            local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_boats_owned WHERE citizenid = ?', { Target.PlayerData.citizenid })
            if (tonumber(count) or 0) >= Config.MaxBoats then notify(src, locale('transfer_target_full'), 'error') return false end
        end
    end

    -- re-check ownership after the wait, and move it in one statement
    local affected = MySQL.update.await('UPDATE rsg_boats_owned SET citizenid = ? WHERE id = ? AND citizenid = ?',
        { Target.PlayerData.citizenid, row.id, Player.PlayerData.citizenid })
    if not affected or affected < 1 then notify(src, locale('not_owned'), 'error') return false end

    notify(src, locale('transfer_done', row.label, toName), 'success')
    BoatLog('transfer', src, locale('wh_boat_transferred'), {
        { locale('wh_f_boat'), ('%s #%s'):format(row.label, row.id) }, { locale('wh_f_yard'), yard.name },
        { locale('wh_f_to'), ('%s (%s, ID %s)'):format(toName, Target.PlayerData.citizenid, targetId), false },
    })
    notify(targetId, locale('transfer_received', fromName, row.label, yard.name), 'success')
    return true
end)

---------------------------------------------------------------------
-- boat storage (owner only, boat must be out and nearby)
---------------------------------------------------------------------
local function inventoryBusy(src)
    local ok, busy = pcall(function() return Player(src).state.inv_busy end)
    return ok and busy
end

local function openBoatStash(src, a)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local row = MySQL.single.await('SELECT model, label FROM rsg_boats_owned WHERE id = ? AND citizenid = ?',
        { a.ownedId, Player.PlayerData.citizenid })
    if not row then return false end
    local m = Models[row.model]
    exports['rsg-inventory']:OpenInventory(src, 'boat_' .. a.ownedId, {
        label = locale('storage_label', row.label),
        slots = m and m.slots or Config.Storage.defaultSlots,
        maxweight = m and m.weight or Config.Storage.defaultWeight,
    })
    return true
end

callback('rsg-boats:server:openStorage', function(src, netId)
    if not Config.Storage.enabled then return false end
    if onCooldown(src) then return false end
    local a = Active[src]
    if not a or not a.netId or a.netId ~= netId then notify(src, locale('storage_not_yours'), 'error') return false end

    local ent = NetworkGetEntityFromNetworkId(a.netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > Config.Storage.distance + 5.0 then
        notify(src, locale('storage_too_far'), 'error')
        return false
    end
    if inventoryBusy(src) then notify(src, locale('storage_busy'), 'error') return false end
    BoatLog('storage', src, locale('wh_storage_opened'), { { locale('wh_f_stash'), 'boat_' .. a.ownedId } })
    return openBoatStash(src, a)
end)

-- Opening the normal inventory (rsg-inventory key) while sitting in your own boat:
-- rsg-inventory opens it with an empty GROUND panel; the client spots that and asks us
-- to re-open it with the boat's storage on the right. No changes to rsg-inventory needed.
RegisterNetEvent('rsg-boats:server:inBoatInventory', function(netId)
    local src = source
    if not Config.Storage.enabled or not Config.Storage.showInBoat then return end
    local a = Active[src]
    local function dbg(msg) if Config.Debug then print(('[rsg-boats] inBoatInventory %s: %s'):format(src, msg)) end end
    if not a then return dbg('no boat out') end
    if a.netId ~= netId then return dbg(('netId mismatch (launched %s, sitting in %s)'):format(tostring(a.netId), tostring(netId))) end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return dbg('boat entity not found on server') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > 6.0 then return dbg('too far from boat') end
    dbg('opening boat_' .. a.ownedId)
    openBoatStash(src, a)
end)

---------------------------------------------------------------------
-- admin
---------------------------------------------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_help'), {}, false, function(source)
    TriggerClientEvent('rsg-boats:client:openAdmin', source)
end, Config.AdminPermission)

local function adminData()
    return { models = modelList(false), yards = adminYards() }
end

callback('rsg-boats:server:getAdminData', function(src)
    if not isAdmin(src) then return nil end
    return adminData()
end)

-- yards ---------------------------------------------------------------
callback('rsg-boats:server:createYard', function(src, name)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    name = cleanName(name)
    if not name then notify(src, locale('yard_bad_name'), 'error') return false end
    local pos = pedPos(src)
    if not pos then return false end
    local id = MySQL.insert.await('INSERT INTO rsg_boats_yards (name, coords) VALUES (?, ?)', { name, json.encode(t4(pos)) })
    if not id then return false end
    Yards[id] = { id = id, name = name, coords = pos }
    broadcastYards()
    notify(src, locale('yard_created', name), 'success')
    BoatLog('admin', src, locale('wh_yard_created'), { { locale('wh_f_yard'), ('%s #%s'):format(name, id) }, { locale('wh_f_coords'), ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z) } })
    local d = adminData(); d.select = id
    return d
end)

callback('rsg-boats:server:renameYard', function(src, id, name)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    local y = Yards[tonumber(id) or -1]
    name = cleanName(name)
    if not y then return false end
    if not name then notify(src, locale('yard_bad_name'), 'error') return false end
    local old = y.name
    y.name = name
    saveYard(y)
    broadcastYards()
    notify(src, locale('yard_renamed'), 'success')
    BoatLog('admin', src, locale('wh_yard_renamed'), { { locale('wh_f_from'), old }, { locale('wh_f_to'), name }, { locale('wh_f_yard_id'), y.id } })
    return adminData()
end)

callback('rsg-boats:server:moveYard', function(src, id)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    local y = Yards[tonumber(id) or -1]
    if not y then return false end
    if yardHasBoatsOut(y.id) then notify(src, locale('yard_boats_out'), 'error') return false end
    local pos = pedPos(src)
    if not pos then return false end
    y.coords, y.spawn, y.dock = pos, nil, nil -- launch point + dock belonged to the old spot
    saveYard(y)
    broadcastYards()
    notify(src, locale('yard_saved'), 'success')
    BoatLog('admin', src, locale('wh_yard_moved'), { { locale('wh_f_yard'), ('%s #%s'):format(y.name, y.id) }, { locale('wh_f_coords'), ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z) } })
    return adminData()
end)

callback('rsg-boats:server:deleteYard', function(src, id)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    local y = Yards[tonumber(id) or -1]
    if not y then return false end
    if yardHasBoatsOut(y.id) then notify(src, locale('yard_boats_out'), 'error') return false end
    MySQL.update.await('DELETE FROM rsg_boats_yards WHERE id = ?', { y.id })
    MySQL.update.await('UPDATE rsg_boats_owned SET yard = NULL WHERE yard = ?', { y.id }) -- boats there can be collected anywhere
    Yards[y.id] = nil
    broadcastYards()
    notify(src, locale('yard_deleted', y.name), 'success')
    BoatLog('admin', src, locale('wh_yard_deleted'), { { locale('wh_f_yard'), ('%s #%s'):format(y.name, y.id) } })
    return adminData()
end)

-- list = array of model names, or nil/empty with all = true for every boat
callback('rsg-boats:server:setYardModels', function(src, id, all, list)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    local y = Yards[tonumber(id) or -1]
    if not y then return false end
    if all then
        y.models = nil
    else
        if type(list) ~= 'table' then return false end
        local set = {}
        for _, m in ipairs(list) do if type(m) == 'string' and Models[m] then set[m] = true end end
        if not next(set) then notify(src, locale('yard_models_none'), 'error') return false end
        y.models = set
    end
    saveYard(y)
    notify(src, locale('yard_models_saved'), 'success')
    BoatLog('admin', src, locale('wh_yard_boats_changed'), { { locale('wh_f_yard'), ('%s #%s'):format(y.name, y.id) }, { locale('wh_f_allowed'), y.models and table.concat(modelArray(y.models), ', ') or locale('wh_all_boats'), false } })
    return adminData()
end)

callback('rsg-boats:server:saveSpawn', function(src, pos)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    if type(pos) ~= 'table' then return false end
    local y = Yards[tonumber(pos.yard) or -1]
    local x, yy, z, w = tonumber(pos.x), tonumber(pos.y), tonumber(pos.z), tonumber(pos.w) or 0.0
    if not y or not x or not yy or not z then return false end
    if #(vector3(x, yy, z) - y.coords.xyz) > Config.MaxPointDistance then
        notify(src, locale('too_far'), 'error')
        return false
    end
    y.spawn = vector4(x, yy, z, w % 360.0)
    saveYard(y)
    notify(src, locale('spawn_saved'), 'success')
    BoatLog('admin', src, locale('wh_launch_point_set'), { { locale('wh_f_yard'), ('%s #%s'):format(y.name, y.id) }, { locale('wh_f_coords'), ('%.2f, %.2f, %.2f  H %.1f'):format(x, yy, z, y.spawn.w) } })
    return true
end)

callback('rsg-boats:server:saveDock', function(src, data)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    if type(data) ~= 'table' then return false end
    local y = Yards[tonumber(data.yard) or -1]
    if not y then return false end
    local r = tonumber(data.r)
    if not r or r < Config.Dock.minRadius or r > Config.Dock.maxRadius then
        notify(src, locale('dock_bad_radius', Config.Dock.minRadius, Config.Dock.maxRadius), 'error')
        return false
    end
    local pos = data.usePed and pedPos(src) or getDock(y).coords
    if not pos then return false end
    if #(pos.xyz - y.coords.xyz) > Config.MaxPointDistance then
        notify(src, locale('too_far'), 'error')
        return false
    end
    y.dock = { coords = pos, radius = r + 0.0 }
    saveYard(y)
    broadcastYards()
    notify(src, locale('dock_saved'), 'success')
    BoatLog('admin', src, locale('wh_dock_set'), { { locale('wh_f_yard'), ('%s #%s'):format(y.name, y.id) }, { locale('wh_f_radius'), ('%.1f m'):format(r) }, { locale('wh_f_coords'), ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z) } })
    return adminData()
end)

-- models --------------------------------------------------------------
callback('rsg-boats:server:saveModel', function(src, data)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    if type(data) ~= 'table' then return false end

    local model = type(data.model) == 'string' and data.model:gsub('%s+', '') or ''
    local label = cleanName(data.label) or ''
    local desc  = type(data.description) == 'string' and data.description:gsub('[<>]', ''):sub(1, 255) or ''
    local price = math.floor(tonumber(data.price) or -1)
    local enabled = data.enabled and 1 or 0
    local slots = math.floor(tonumber(data.slots) or -1)
    local weight = math.floor((tonumber(data.weight) or -1) * 1000) -- panel sends kg
    if slots < 1 or slots > Config.Storage.maxSlots or weight < 1000 or weight > Config.Storage.maxWeight then
        notify(src, locale('admin_bad_storage', Config.Storage.maxSlots, Config.Storage.maxWeight / 1000), 'error')
        return false
    end
    if model == '' or #model > 64 or not model:match('^[%w_]+$') or label == '' or price < 0 or price > 1000000 then
        notify(src, locale('admin_invalid'), 'error')
        return false
    end

    MySQL.query.await([[INSERT INTO rsg_boats_models (model, label, description, price, enabled, slots, weight) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), description = VALUES(description), price = VALUES(price),
        enabled = VALUES(enabled), slots = VALUES(slots), weight = VALUES(weight)]],
        { model, label, desc, price, enabled, slots, weight })
    loadModels()
    notify(src, locale('admin_saved'), 'success')
    BoatLog('admin', src, locale('wh_model_saved'), { { locale('wh_f_model'), ('%s (%s)'):format(label, model) }, { locale('wh_f_price'), '$' .. price }, { locale('wh_f_for_sale'), enabled == 1 and locale('wh_yes') or locale('wh_no') }, { locale('wh_f_storage'), locale('wh_storage_value', slots, weight / 1000) } })
    return modelList(false)
end)

callback('rsg-boats:server:deleteModel', function(src, model)
    if not isAdmin(src) then notify(src, locale('no_permission'), 'error') return false end
    if type(model) ~= 'string' then return false end
    MySQL.update.await('DELETE FROM rsg_boats_models WHERE model = ?', { model })
    loadModels()
    for _, y in pairs(Yards) do
        if y.models and y.models[model] then y.models[model] = nil saveYard(y) end
    end
    notify(src, locale('admin_deleted'), 'success')
    BoatLog('admin', src, locale('wh_model_deleted'), { { locale('wh_f_model'), model } })
    return modelList(false)
end)

---------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------
local function clearActive(src)
    local a = Active[src]
    if a and a.netId then
        local ent = NetworkGetEntityFromNetworkId(a.netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    Active[src] = nil
    Cooldowns[src] = nil
    Offers[src] = nil
end

AddEventHandler('playerDropped', function() clearActive(source) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) clearActive(src) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Active) do clearActive(src) end
end)
