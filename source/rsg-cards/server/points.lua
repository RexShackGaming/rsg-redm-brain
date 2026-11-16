local RSGCore = exports['rsg-core']:GetCoreObject()

-- World locations of the collectable cards.
-- The database table `rsg_cards_points` is the source of truth. On the first start (empty table) it is filled
-- from Config.CardPoints in shared/cards_points.lua; after that admins add, move and remove cards in game
-- with rsg-gizmo (/cardplace, /cardmove, /cardremove) and the changes are saved here.
CardsServer.points = {}          -- [id] = { id, item, coords = vector4, exact }
CardsServer.pointsEditable = false

local loaded = false

local function pointData(point)
    local c = point.coords
    return { id = point.id, item = point.item, x = c.x, y = c.y, z = c.z, w = c.w, exact = point.exact == true }
end

local function isFinite(value)
    return type(value) == 'number' and value == value and value > -1e6 and value < 1e6
end

local function broadcast(id)
    local point = CardsServer.points[id]
    TriggerClientEvent('rsg-cards:client:setPoint', -1, id, point and pointData(point) or nil)
end

local function pointForItem(item)
    for _, point in pairs(CardsServer.points) do
        if point.item == item then return point end
    end
end

---------------------------------------------------------------------
-- LOADING
---------------------------------------------------------------------
local function useConfigPoints()
    CardsServer.points = {}
    for index, point in ipairs(Config.CardPoints) do
        CardsServer.points[index] = { id = index, item = point.item, coords = point.coords, exact = false }
    end
    CardsServer.pointsEditable = false
end

local function seedFromConfig()
    local values, params = {}, {}
    for _, point in ipairs(Config.CardPoints) do
        if Cards.Info[point.item] and not Cards.Info[point.item].deck then
            values[#values + 1] = '(?, ?, ?, ?, ?, 0, ?)'
            local c = point.coords
            params[#params + 1] = point.item
            params[#params + 1] = c.x
            params[#params + 1] = c.y
            params[#params + 1] = c.z
            params[#params + 1] = c.w
            params[#params + 1] = 'config'
        end
    end
    if #values == 0 then return end
    MySQL.query.await(
        'INSERT INTO `rsg_cards_points` (`item`, `x`, `y`, `z`, `heading`, `exact`, `created_by`) VALUES ' .. table.concat(values, ', '),
        params)
    print(('^2[rsg-cards] %d card locations copied from shared/cards_points.lua into the database^7'):format(#values))
end

local function loadPoints()
    if Config.Editor.SeedFromConfig then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM `rsg_cards_points`')
        if (tonumber(count) or 0) == 0 then seedFromConfig() end
    end

    CardsServer.points = {}
    for _, row in ipairs(MySQL.query.await('SELECT `id`, `item`, `x`, `y`, `z`, `heading`, `exact` FROM `rsg_cards_points` ORDER BY `id`') or {}) do
        local info = Cards.Info[row.item]
        if info and not info.deck then
            CardsServer.points[row.id] = {
                id = row.id, item = row.item,
                coords = vector4(row.x + 0.0, row.y + 0.0, row.z + 0.0, row.heading + 0.0),
                exact = row.exact == 1 or row.exact == true,
            }
        end
    end
    CardsServer.pointsEditable = Config.Editor.Enabled == true
end

CardsServer.whenReady(function()
    local ok, err = pcall(loadPoints)
    if not ok then
        print(('^1[rsg-cards] could not load card locations from the database (%s), using shared/cards_points.lua^7'):format(err))
        useConfigPoints()
    end
    loaded = true
end)

-- every point, for a client that just loaded in
RSGCore.Functions.CreateCallback('rsg-cards:server:getPoints', function(source, cb)
    for _ = 1, 50 do
        if loaded then break end
        Wait(200)
    end
    local list = {}
    for _, point in pairs(CardsServer.points) do list[#list + 1] = pointData(point) end
    cb(list)
end)

---------------------------------------------------------------------
-- ADMIN EDITING
---------------------------------------------------------------------
local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.Editor.Permission)
end

-- accepts 'grl_c1' or 'card_cigcard_grl_c1'; returns the item name of a single card or nil
local function resolveItem(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower()
    if not name:find('^card_cigcard_') then name = 'card_cigcard_' .. name end
    local info = Cards.Info[name]
    if info and not info.deck then return name end
end

-- common checks for the three edit events; returns the Player or nil
local function allowed(src, throttleKey)
    if not CardsServer.pointsEditable then
        CardsServer.notify(src, locale('editor_unavailable'), 'error')
        return nil
    end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not isAdmin(src) then return nil end
    if not CardsServer.throttle(src, throttleKey, 1) then return nil end
    return Player
end

local function validPlacement(src, x, y, z, heading)
    if not (isFinite(x) and isFinite(y) and isFinite(z) and isFinite(heading)) then return false end
    return CardsServer.isNear(src, vector3(x, y, z), Config.Editor.Distance)
end

local function describe(point)
    return ('%s (#%d)'):format(CardsServer.itemLabel(point.item), point.id)
end

RegisterNetEvent('rsg-cards:server:pointAdd', function(item, x, y, z, heading)
    local src = source
    local Player = allowed(src, 'pointEdit')
    if not Player then return end
    item = resolveItem(item)
    if not item then return CardsServer.notify(src, locale('editor_unknown_card'), 'error') end
    if not validPlacement(src, x, y, z, heading) then return end

    local existing = pointForItem(item)
    if existing then return CardsServer.notify(src, locale('editor_exists', describe(existing)), 'error') end

    local id = MySQL.insert.await(
        'INSERT INTO `rsg_cards_points` (`item`, `x`, `y`, `z`, `heading`, `exact`, `created_by`) VALUES (?, ?, ?, ?, ?, 1, ?)',
        { item, x, y, z, heading, Player.PlayerData.citizenid })
    if not id then return end

    CardsServer.points[id] = { id = id, item = item, coords = vector4(x, y, z, heading), exact = true }
    broadcast(id)
    CardsServer.notify(src, locale('editor_added', describe(CardsServer.points[id])), 'success')
    CardsServer.log(('**Card location added**\n%s\n%s at %.2f, %.2f, %.2f'):format(CardsServer.playerTag(Player), item, x, y, z))
end)

RegisterNetEvent('rsg-cards:server:pointMove', function(id, x, y, z, heading)
    local src = source
    local Player = allowed(src, 'pointEdit')
    if not Player then return end
    id = tonumber(id)
    local point = id and CardsServer.points[id]
    if not point or not validPlacement(src, x, y, z, heading) then return end

    MySQL.update.await('UPDATE `rsg_cards_points` SET `x` = ?, `y` = ?, `z` = ?, `heading` = ?, `exact` = 1 WHERE `id` = ?', { x, y, z, heading, id })
    point.coords, point.exact = vector4(x, y, z, heading), true
    broadcast(id)
    CardsServer.notify(src, locale('editor_moved', describe(point)), 'success')
    CardsServer.log(('**Card location moved**\n%s\n%s to %.2f, %.2f, %.2f'):format(CardsServer.playerTag(Player), point.item, x, y, z))
end)

RegisterNetEvent('rsg-cards:server:pointRemove', function(id)
    local src = source
    local Player = allowed(src, 'pointEdit')
    if not Player then return end
    id = tonumber(id)
    local point = id and CardsServer.points[id]
    if not point or not CardsServer.isNear(src, point.coords, Config.Editor.Distance + 5.0) then return end

    MySQL.update.await('DELETE FROM `rsg_cards_points` WHERE `id` = ?', { id })
    CardsServer.points[id] = nil
    broadcast(id)
    CardsServer.notify(src, locale('editor_removed', describe(point)), 'success')
    CardsServer.log(('**Card location removed**\n%s\n%s'):format(CardsServer.playerTag(Player), point.item))
end)

---------------------------------------------------------------------
-- COMMANDS (admin)
---------------------------------------------------------------------
if Config.Editor.Enabled then
    RSGCore.Commands.Add('cardplace', locale('command_cardplace'),
        { { name = 'card', help = locale('command_cardplace_card') } }, true, function(source, args)
            local item = resolveItem(args[1])
            if not item then return CardsServer.notify(source, locale('editor_unknown_card'), 'error') end
            TriggerClientEvent('rsg-cards:client:editorPlace', source, item)
        end, Config.Editor.Permission)

    RSGCore.Commands.Add('cardmove', locale('command_cardmove'), {}, false, function(source)
        TriggerClientEvent('rsg-cards:client:editorMove', source)
    end, Config.Editor.Permission)

    RSGCore.Commands.Add('cardremove', locale('command_cardremove'), {}, false, function(source)
        TriggerClientEvent('rsg-cards:client:editorRemove', source)
    end, Config.Editor.Permission)

    RSGCore.Commands.Add('cardedit', locale('command_cardedit'), {}, false, function(source)
        TriggerClientEvent('rsg-cards:client:editorToggle', source)
    end, Config.Editor.Permission)

    -- cards that have no world location
    RSGCore.Commands.Add('cardmissing', locale('command_cardmissing'), {}, false, function(source)
        local placed = {}
        for _, point in pairs(CardsServer.points) do placed[point.item] = true end
        local missing = {}
        for _, name in ipairs(Cards.List) do
            if not placed[name] then missing[#missing + 1] = name:gsub('^card_cigcard_', '') end
        end
        if #missing == 0 then return CardsServer.notify(source, locale('editor_none_missing'), 'success') end
        CardsServer.notify(source, locale('editor_missing', table.concat(missing, ', ', 1, math.min(#missing, 12))), 'inform')
    end, Config.Editor.Permission)
end
