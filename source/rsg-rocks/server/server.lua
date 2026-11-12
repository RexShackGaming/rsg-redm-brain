local RSGCore = exports['rsg-core']:GetCoreObject()

local mineCooldowns     = {} -- [citizenid][zoneId] = endTime (per character, survives reconnects)
local workSessions      = {} -- [src] = { kind, key, startTime }
local MiningZones       = {}
local zoneGlobalDeplete = {} -- [zoneId] = endTime (GetGameTimer)

local DRILLABLE = { resource_rock = true, resource_salt_rock = true }
local XP        = Config.MiningXP or {}
local XP_KEY    = XP.metaKey or 'miningxp'

---------------------------------
-- helpers
---------------------------------
local function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function IsNearWorkshop(coords)
    if not coords then return false end
    for _, tent in ipairs(Config.WorkshopTents) do
        if #(coords - tent.coords.xyz) <= Config.WorkshopDistanceTolerance then
            return true
        end
    end
    return false
end

local function Notify(src, title, description, nType, duration)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = duration or Config.NotificationDuration,
    })
end

local function ItemLabel(name)
    local item = RSGCore.Shared.Items[name]
    return item and item.label or name
end

local function WeightedPick(pool)
    if not pool or #pool == 0 then return nil end
    local total = 0
    for i = 1, #pool do total = total + (tonumber(pool[i].weight) or 1) end
    local roll, acc = math.random() * total, 0
    for i = 1, #pool do
        acc = acc + (tonumber(pool[i].weight) or 1)
        if roll <= acc then return pool[i].item end
    end
    return pool[#pool].item
end

local function GetXP(Player)
    return tonumber((Player.PlayerData.metadata or {})[XP_KEY]) or 0
end

local function GetMiningLevel(xp)
    local level = 1
    for lvl, need in pairs(XP.levels or {}) do
        local n = tonumber(lvl)
        if n and n > level and xp >= (need or 0) then level = n end
    end
    return level
end

local function AddMiningXP(Player, amount)
    if not XP.enabled or not amount or amount <= 0 then return end
    local xp = GetXP(Player)
    local before = GetMiningLevel(xp)
    xp = xp + amount
    Player.Functions.SetMetaData(XP_KEY, xp)
    local after = GetMiningLevel(xp)
    if after > before then
        Notify(Player.PlayerData.source, locale('mining_title'), locale('xp_level_up', after), 'success')
    end
end

local function YieldAmount(rewardData, level)
    local minA, maxA = rewardData.minAmount, rewardData.maxAmount
    if XP.enabled and level > 1 then
        local bonus = (XP.yieldBonusPerLevel or 0) * (level - 1)
        maxA = math.max(minA, math.floor(maxA * (1 + bonus) + 0.5))
    end
    return math.random(minA, maxA)
end

local function PickaxeQuality(item)
    return tonumber((item.info or {}).quality) or Config.PickaxeMaxQuality or 100
end

-- Pickaxe the player can mine with. With durability on, a pickaxe at 0 quality doesn't
-- count (it stays in the inventory when Config.PickaxeBreakAtZero = false, e.g. to be
-- repaired / sharpened by another script).
-- returns item | nil, hasWornOut (has pickaxes, but all at 0 quality)
local function FindPickaxe(Player)
    local wornOut = false
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == Config.RequiredItem and (item.amount or 1) > 0 then
            if not Config.PickaxeDurability or PickaxeQuality(item) > 0 then return item, false end
            wornOut = true
        end
    end
    return nil, wornOut
end

local function DegradePickaxe(src, Player)
    if not Config.PickaxeDurability then return end

    local item = FindPickaxe(Player) -- the usable one, never a 0-quality spare
    if not item then return end

    local info = item.info or {}
    local quality = PickaxeQuality(item)
    local dmin = Config.PickaxeDegradeMin or 1
    local dmax = math.max(dmin, Config.PickaxeDegradeMax or 3)
    quality = math.max(0, quality - math.random(dmin, dmax))

    if quality <= 0 and Config.PickaxeBreakAtZero then
        exports['rsg-inventory']:RemoveItem(src, Config.RequiredItem, 1, item.slot, 'rsg-rocks-pickaxe-break')
        Notify(src, locale('mining_title'), locale('pickaxe_broke'), 'error')
        return
    end

    info.quality = quality
    exports['rsg-inventory']:SetItemInfo(src, item.slot, info)
end

-- Server-side timed work session (mining / drilling / smelting).
-- Start* events open it, the matching finish event must arrive within the time window.
local function StartSession(src, kind, key)
    workSessions[src] = { kind = kind, key = key, startTime = GetGameTimer() }
end

local function ConsumeSession(src, kind, key, duration, tolerance)
    local s = workSessions[src]
    workSessions[src] = nil
    if not s or s.kind ~= kind or s.key ~= key then return false end
    local elapsed = GetGameTimer() - s.startTime
    return elapsed >= (duration - tolerance) and elapsed <= (duration + Config.MiningSessionGrace)
end

---------------------------------
-- zones
---------------------------------
local function ZonesForClient()
    local now = GetGameTimer()
    local list = {}
    for id, zone in pairs(MiningZones) do
        local depleteUntil = zoneGlobalDeplete[id] or 0
        list[#list + 1] = {
            id = id,
            x = zone.coords.x, y = zone.coords.y, z = zone.coords.z,
            radius = zone.radius,
            heading = zone.heading or 0.0,
            type = zone.type,
            depleteRemaining = depleteUntil > now and (depleteUntil - now) or 0,
        }
    end
    return list
end

local function SyncZones(target)
    TriggerClientEvent('rsg-rocks:client:SetZones', target or -1, ZonesForClient())
end

local function CountZones()
    local n = 0
    for _ in pairs(MiningZones) do n = n + 1 end
    return n
end

local function IsZoneDepleted(zoneId, now)
    return Config.GlobalDepleteEnabled and zoneGlobalDeplete[zoneId] and now < zoneGlobalDeplete[zoneId]
end

local function CitizenId(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid
end

local function IsOnCooldown(src, zoneId, now)
    local cid = CitizenId(src)
    local cds = cid and mineCooldowns[cid]
    return cds and cds[zoneId] and now < cds[zoneId]
end

local function IsNearZone(src, zone)
    local coords = GetPlayerCoords(src)
    return coords and #(coords - zone.coords) <= (zone.radius + Config.MineDistanceTolerance)
end

local function EnsureDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_rocks_zones` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `radius` FLOAT NOT NULL DEFAULT 2.0,
            `heading` FLOAT NOT NULL DEFAULT 0.0,
            `ore_type` VARCHAR(32) NOT NULL DEFAULT 'rock',
            `label` VARCHAR(64) DEFAULT NULL,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_enabled` (`enabled`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- older installs: add the heading column (rock rotation from rsg-gizmo)
    local col = MySQL.single.await([[SELECT COUNT(*) AS c FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_rocks_zones' AND COLUMN_NAME = 'heading']])
    if col and tonumber(col.c) == 0 then
        MySQL.query.await('ALTER TABLE `rsg_rocks_zones` ADD COLUMN `heading` FLOAT NOT NULL DEFAULT 0.0 AFTER `radius`')
        print('[rsg-rocks] Added heading column to rsg_rocks_zones')
    end

    if Config.AutoSeedDefaultZones == false then return end

    local countRow = MySQL.single.await('SELECT COUNT(*) AS c FROM `rsg_rocks_zones`')
    if countRow and tonumber(countRow.c) > 0 then return end

    local DefaultZones = {
        { x = 2791.4697265625, y = 1345.1380615234375, z = 71.91378021240234, radius = 2.0, ore_type = 'rock' },
        { x = 2793.626708984375, y = 1336.0570068359375, z = 71.92117309570312, radius = 2.0, ore_type = 'rock' },
        { x = 2780.24169921875, y = 1335.8101806640625, z = 71.5442886352539, radius = 2.0, ore_type = 'rock' },
        { x = 2767.23388671875, y = 1337.0699462890625, z = 70.95378112792969, radius = 2.0, ore_type = 'saltrock' },
        { x = 2765.5029296875, y = 1335.658447265625, z = 70.78048706054688, radius = 2.0, ore_type = 'rock' },
        { x = 2761.82861328125, y = 1331.6224365234375, z = 70.52594757080078, radius = 2.0, ore_type = 'rock' },
        { x = 2752.021484375, y = 1332.12109375, z = 70.63470458984375, radius = 2.0, ore_type = 'rock' },
        { x = 2741.38134765625, y = 1319.45458984375, z = 70.48382568359375, radius = 2.0, ore_type = 'saltrock' },
        { x = 2745.58837890625, y = 1325.2091064453125, z = 70.48372650146484, radius = 2.0, ore_type = 'rock' },
        { x = 2761.119384765625, y = 1310.7445068359375, z = 70.49114227294922, radius = 2.0, ore_type = 'rock' },
        { x = 2760.796142578125, y = 1304.12744140625, z = 70.49578857421875, radius = 2.0, ore_type = 'rock' },
        { x = 2755.88916015625, y = 1301.888427734375, z = 70.4975811819336, radius = 2.0, ore_type = 'saltrock' },
        { x = 2738.291748046875, y = 1309.3807373046875, z = 70.39374542236328, radius = 2.0, ore_type = 'rock' },
        { x = 2735.927978515625, y = 1309.5782470703125, z = 70.37593078613281, radius = 2.0, ore_type = 'rock' },
        { x = 2718.755859375, y = 1307.8685302734375, z = 70.2322006225586, radius = 2.0, ore_type = 'rock' },
        { x = 2713.54052734375, y = 1308.1812744140625, z = 70.25575256347656, radius = 2.0, ore_type = 'saltrock' },
        { x = 2711.83154296875, y = 1314.4696044921875, z = 70.2629165649414, radius = 2.0, ore_type = 'rock' },
        { x = 2716.714599609375, y = 1314.705810546875, z = 70.26507568359375, radius = 2.0, ore_type = 'rock' },
        { x = 2727.734375, y = 1319.8328857421875, z = 70.22930908203125, radius = 2.0, ore_type = 'rock' },
        { x = 2731.578369140625, y = 1318.081298828125, z = 70.22589111328125, radius = 2.0, ore_type = 'saltrock' },
        { x = 2736.048583984375, y = 1322.33984375, z = 70.19818878173828, radius = 2.0, ore_type = 'rock' },
        { x = 2733.84033203125, y = 1328.4901123046875, z = 70.18203735351562, radius = 2.0, ore_type = 'rock' },
        { x = 2728.3525390625, y = 1329.7330322265625, z = 70.15768432617188, radius = 2.0, ore_type = 'rock' },
        { x = 2731.616455078125, y = 1332.7449951171875, z = 70.17938232421875, radius = 2.0, ore_type = 'saltrock' },
        { x = 2739.888427734375, y = 1339.1622314453125, z = 69.70467376708984, radius = 2.0, ore_type = 'rock' },
        { x = 2742.882568359375, y = 1347.59521484375, z = 68.63679504394531, radius = 2.0, ore_type = 'rock' },
        { x = 2749.873779296875, y = 1347.125244140625, z = 69.15619659423828, radius = 2.0, ore_type = 'rock' },
        { x = 2765.419921875, y = 1351.198974609375, z = 71.07604217529297, radius = 2.0, ore_type = 'saltrock' },
        { x = 2761.34619140625, y = 1358.7442626953125, z = 70.99369049072266, radius = 2.0, ore_type = 'rock' },
        { x = 2765.982177734375, y = 1366.232177734375, z = 71.02310943603516, radius = 2.0, ore_type = 'rock' },
        { x = 2763.967529296875, y = 1364.6925048828125, z = 71.0881118774414, radius = 2.0, ore_type = 'rock' },
        { x = 2779.3095703125, y = 1371.5987548828125, z = 68.38038635253906, radius = 2.0, ore_type = 'saltrock' },
        { x = 2778.156005859375, y = 1381.4931640625, z = 68.48554992675781, radius = 2.0, ore_type = 'rock' },
        { x = 2779.03076171875, y = 1377.4268798828125, z = 68.3793716430664, radius = 2.0, ore_type = 'rock' },
        { x = 2772.770751953125, y = 1368.3590087890625, z = 68.31623840332031, radius = 2.0, ore_type = 'rock' },
        { x = 2753.31103515625, y = 1368.2064208984375, z = 68.40861511230469, radius = 2.0, ore_type = 'saltrock' },
        { x = 2746.0869140625, y = 1366.9554443359375, z = 68.78707122802734, radius = 2.0, ore_type = 'rock' },
        { x = 2740.212158203125, y = 1369.9141845703125, z = 69.02835083007812, radius = 2.0, ore_type = 'rock' },
        { x = 2737.818115234375, y = 1356.1986083984375, z = 68.78072357177734, radius = 2.0, ore_type = 'rock' },
        { x = 2740.609130859375, y = 1377.5894775390625, z = 69.14989471435547, radius = 2.0, ore_type = 'saltrock' },
        { x = 2743.1064453125, y = 1384.3988037109375, z = 69.06208038330078, radius = 2.0, ore_type = 'rock' },
        { x = 2742.830810546875, y = 1396.9949951171875, z = 69.29539489746094, radius = 2.0, ore_type = 'rock' },
        { x = 2724.53515625, y = 1391.2403564453125, z = 69.29977416992188, radius = 2.0, ore_type = 'rock' },
        { x = 2724.401611328125, y = 1397.712890625, z = 69.2967300415039, radius = 2.0, ore_type = 'saltrock' },
        { x = -5962.111328125, y = -3218.07666015625, z = -21.03051567077636, radius = 2.0, ore_type = 'rock' },
        { x = -5961.6826171875, y = -3211.577392578125, z = -21.02172470092773, radius = 2.0, ore_type = 'rock' },
        { x = -5967.36083984375, y = -3204.54345703125, z = -20.88662719726562, radius = 2.0, ore_type = 'rock' },
        { x = -5960.54248046875, y = -3192.346923828125, z = -21.10622787475586, radius = 2.0, ore_type = 'saltrock' },
        { x = -5958.52783203125, y = -3188.994873046875, z = -21.13970375061035, radius = 2.0, ore_type = 'rock' },
        { x = -5955.8564453125, y = -3180.30517578125, z = -21.84871482849121, radius = 2.0, ore_type = 'rock' },
        { x = -5961.78515625, y = -3173.27001953125, z = -22.58561706542968, radius = 2.0, ore_type = 'rock' },
        { x = -5966.97900390625, y = -3172.76513671875, z = -23.5033893585205, radius = 2.0, ore_type = 'saltrock' },
        { x = -5969.8837890625, y = -3170.76806640625, z = -24.24051094055175, radius = 2.0, ore_type = 'rock' },
        { x = -5975.6240234375, y = -3167.875732421875, z = -25.00465202331543, radius = 2.0, ore_type = 'rock' },
        { x = -5979.07958984375, y = -3165.752685546875, z = -25.97180366516113, radius = 2.0, ore_type = 'rock' },
        { x = -5981.2080078125, y = -3161.576904296875, z = -26.08867454528808, radius = 2.0, ore_type = 'saltrock' },
        { x = -5976.26123046875, y = -3219.142822265625, z = -21.04885864257812, radius = 2.0, ore_type = 'rock' },
        { x = -5969.7919921875, y = -3214.953369140625, z = -21.09965133666992, radius = 2.0, ore_type = 'rock' },
        { x = -5972.939453125, y = -3205.176025390625, z = -18.96175765991211, radius = 2.0, ore_type = 'rock' },
        { x = -5962.1748046875, y = -3222.4931640625, z = -21.0845890045166, radius = 2.0, ore_type = 'saltrock' },
        { x = -5962.7822265625, y = -3224.797607421875, z = -21.09444236755371, radius = 2.0, ore_type = 'rock' },
        { x = -5957.90869140625, y = -3234.35009765625, z = -19.95751953125, radius = 2.0, ore_type = 'rock' },
        { x = -5955.3564453125, y = -3243.451904296875, z = -21.04887962341308, radius = 2.0, ore_type = 'rock' },
        { x = -5964.81689453125, y = -3195.2392578125, z = -21.07339096069336, radius = 2.0, ore_type = 'rock' },
        { x = -1433.65, y = 1177.55, z = 226.37, radius = 2.0, ore_type = 'rock' },
        { x = -1447.15, y = 1196.31, z = 226.36, radius = 2.0, ore_type = 'rock' },
        { x = -1442.54, y = 1209.02, z = 226.37, radius = 2.0, ore_type = 'rock' },
        { x = -1426.14, y = 1217.07, z = 223.32, radius = 2.0, ore_type = 'saltrock' },
        { x = -1413.81, y = 1214.39, z = 222.43, radius = 2.0, ore_type = 'rock' },
        { x = -1409.68, y = 1202.37, z = 223.66, radius = 2.0, ore_type = 'rock' },
        { x = -1428.74, y = 1202.25, z = 225.5, radius = 2.0, ore_type = 'rock' },
        { x = -1419.31, y = 1187.75, z = 225.48, radius = 2.0, ore_type = 'rock' },
        { x = -1410.18, y = 1189.06, z = 225.49, radius = 2.0, ore_type = 'saltrock' },
        { x = -1403.09, y = 1176.55, z = 222.13, radius = 2.0, ore_type = 'rock' },
        { x = -1391.44, y = 1172.18, z = 222.17, radius = 2.0, ore_type = 'rock' },
        { x = -1393.17, y = 1185.74, z = 221.96, radius = 2.0, ore_type = 'rock' },
        { x = -1387.19, y = 1182.66, z = 222.09, radius = 2.0, ore_type = 'saltrock' },
        { x = -1412.58, y = 1182.56, z = 225.53, radius = 2.0, ore_type = 'rock' },
    }

    -- single multi-row insert instead of one query per row
    local placeholders, params = {}, {}
    for i = 1, #DefaultZones do
        local z = DefaultZones[i]
        placeholders[i] = '(?, ?, ?, ?, ?, 1)'
        params[#params + 1] = z.x
        params[#params + 1] = z.y
        params[#params + 1] = z.z
        params[#params + 1] = z.radius
        params[#params + 1] = z.ore_type
    end
    MySQL.insert.await(
        'INSERT INTO `rsg_rocks_zones` (`x`, `y`, `z`, `radius`, `ore_type`, `enabled`) VALUES ' .. table.concat(placeholders, ', '),
        params
    )
    print(('[rsg-rocks] Seeded %s default mining zones'):format(#DefaultZones))
end

local function LoadZonesFromDb()
    local rows = MySQL.query.await(
        'SELECT `id`, `x`, `y`, `z`, `radius`, `heading`, `ore_type` FROM `rsg_rocks_zones` WHERE `enabled` = 1'
    ) or {}
    MiningZones = {}
    for _, row in ipairs(rows) do
        local id = tonumber(row.id)
        MiningZones[id] = {
            id = id,
            coords = vector3(tonumber(row.x), tonumber(row.y), tonumber(row.z)),
            radius = tonumber(row.radius) or 2.0,
            heading = tonumber(row.heading) or 0.0,
            type = row.ore_type or 'rock',
        }
    end
    print(('[rsg-rocks] Loaded %s mining zones from database'):format(#rows))
    SyncZones()
end

CreateThread(function()
    if Config.AutoCreateDatabase ~= false then
        local ok, err = pcall(EnsureDatabase)
        if not ok then print(('[rsg-rocks] Database setup failed: %s'):format(err)) end
    end
    LoadZonesFromDb()
end)

---------------------------------
-- callbacks
---------------------------------
-- clients request zones once their character has loaded (covers late joins and resource restarts)
RSGCore.Functions.CreateCallback('rsg-rocks:server:GetZones', function(source, cb)
    -- also return this character's remaining personal cooldowns (after a reconnect / relog)
    local now, cooldowns = GetGameTimer(), {}
    local cid = CitizenId(source)
    for id, untilT in pairs(cid and mineCooldowns[cid] or {}) do
        if untilT > now then cooldowns[#cooldowns + 1] = { id = id, ms = untilT - now } end
    end
    cb(ZonesForClient(), cooldowns)
end)

---------------------------------
-- mining
---------------------------------
RegisterNetEvent('rsg-rocks:server:StartMining', function(zoneKey)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    zoneKey = tonumber(zoneKey)
    local zone = zoneKey and MiningZones[zoneKey]
    if not zone or not Config.Rewards[zone.type] then return end

    local now = GetGameTimer()
    if IsZoneDepleted(zoneKey, now) or IsOnCooldown(src, zoneKey, now) then return end
    if not IsNearZone(src, zone) then return end
    local pickaxe, wornOut = FindPickaxe(Player)
    if not pickaxe then
        if wornOut then Notify(src, locale('mining_title'), locale('pickaxe_worn'), 'error') end
        return
    end

    StartSession(src, 'mine', zoneKey)
end)

RegisterNetEvent('rsg-rocks:server:MineReward', function(zoneKey)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    zoneKey = tonumber(zoneKey)
    local zone = zoneKey and MiningZones[zoneKey]
    if not zone then return end
    local rewardData = Config.Rewards[zone.type] -- ore type always comes from the server zone
    if not rewardData then return end

    if not ConsumeSession(src, 'mine', zoneKey, Config.MiningTime, Config.MiningTimeTolerance) then return end

    local now = GetGameTimer()
    if IsZoneDepleted(zoneKey, now) or IsOnCooldown(src, zoneKey, now) then return end
    if not IsNearZone(src, zone) then return end
    if not FindPickaxe(Player) then return end

    local itemName = rewardData.item
    if not RSGCore.Shared.Items[itemName] then return end
    local amount = YieldAmount(rewardData, GetMiningLevel(GetXP(Player)))

    if not exports['rsg-inventory']:CanAddItem(src, itemName, amount) then
        Notify(src, locale('mining_title'), locale('inventory_full'), 'error')
        return
    end
    if not exports['rsg-inventory']:AddItem(src, itemName, amount, nil, nil, 'rsg-rocks-mine') then return end

    local cid = Player.PlayerData.citizenid
    local cds = mineCooldowns[cid] or {}
    for id, untilT in pairs(cds) do if untilT <= now then cds[id] = nil end end -- prune expired
    cds[zoneKey] = now + Config.CooldownTime
    mineCooldowns[cid] = cds
    TriggerClientEvent('rsg-rocks:client:SetCooldown', src, zoneKey, Config.CooldownTime)

    if Config.GlobalDepleteEnabled then
        local duration = Config.GlobalDepleteTime or 120000
        zoneGlobalDeplete[zoneKey] = now + duration
        TriggerClientEvent('rsg-rocks:client:ZoneDepleted', -1, zoneKey, duration)
    end

    DegradePickaxe(src, Player)
    AddMiningXP(Player, XP.perMine)
    Notify(src, locale('mining_title'), locale('collected', amount, ItemLabel(itemName)), 'success')
end)

RegisterNetEvent('rsg-rocks:server:CancelWork', function()
    workSessions[source] = nil
end)

---------------------------------
-- drilling
---------------------------------
RegisterNetEvent('rsg-rocks:server:StartDrill', function(item)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    if not DRILLABLE[item] then return end
    if not IsNearWorkshop(GetPlayerCoords(src)) then return end
    if not exports['rsg-inventory']:HasItem(src, item, 1) then return end
    StartSession(src, 'drill', item)
end)

-- drill a single rock; returns output item, gem (or nil) / false when it can't continue
local function DrillOne(src, item)
    if not exports['rsg-inventory']:HasItem(src, item, 1) then return false, 'no_rocks' end
    local randomItem = WeightedPick(item == 'resource_rock' and Config.RockOutputs or Config.SaltRockOutputs)
    if not randomItem or not RSGCore.Shared.Items[randomItem] then return false end
    if not exports['rsg-inventory']:CanAddItem(src, randomItem, 1) then return false, 'inventory_full' end
    if not exports['rsg-inventory']:RemoveItem(src, item, 1, nil, 'rsg-rocks-drill') then return false end
    if not exports['rsg-inventory']:AddItem(src, randomItem, 1, nil, nil, 'rsg-rocks-drill') then
        exports['rsg-inventory']:AddItem(src, item, 1, nil, nil, 'rsg-rocks-drill-rollback')
        return false, 'inventory_full'
    end

    local gem
    if item == 'resource_rock' and math.random(100) <= Config.GemChance then
        local pick = WeightedPick(Config.GemOutputs)
        if pick and RSGCore.Shared.Items[pick] and exports['rsg-inventory']:CanAddItem(src, pick, 1)
            and exports['rsg-inventory']:AddItem(src, pick, 1, nil, nil, 'rsg-rocks-gem') then
            gem = pick
        end
    end
    return randomItem, gem
end

RegisterNetEvent('rsg-rocks:server:FinishDrill', function(item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not DRILLABLE[item] then return end
    if not ConsumeSession(src, 'drill', item, Config.DrillTime, Config.DrillTimeTolerance)
        or not IsNearWorkshop(GetPlayerCoords(src)) then
        Notify(src, locale('drill_title'), locale('work_failed'), 'error')
        TriggerClientEvent('rsg-rocks:client:StopDrillBatch', src)
        return
    end

    local out, gem = DrillOne(src, item)
    if not out then
        Notify(src, locale('drill_title'), locale(gem or 'no_rocks'), 'error')
        TriggerClientEvent('rsg-rocks:client:StopDrillBatch', src)
        return
    end

    Notify(src, locale('drill_title'), locale('received', 1, ItemLabel(out)), 'success')
    if gem then Notify(src, locale('drill_title'), locale('received_rare', 1, ItemLabel(gem)), 'success') end
    AddMiningXP(Player, XP.perDrill)
end)

---------------------------------
-- smelting
---------------------------------
local function GetRecipe(index)
    if not Config.SmeltingEnabled or not Config.SmeltRecipes then return nil end
    index = tonumber(index)
    return index and Config.SmeltRecipes[index], index
end

RegisterNetEvent('rsg-rocks:server:StartSmelt', function(recipeIndex)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    local recipe, index = GetRecipe(recipeIndex)
    if not recipe then return end
    if not IsNearWorkshop(GetPlayerCoords(src)) then return end
    if not exports['rsg-inventory']:HasItem(src, recipe.input, tonumber(recipe.inputAmount) or 1) then return end
    StartSession(src, 'smelt', index)
end)

RegisterNetEvent('rsg-rocks:server:FinishSmelt', function(recipeIndex)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local recipe, index = GetRecipe(recipeIndex)
    if not recipe then return end
    if not ConsumeSession(src, 'smelt', index, recipe.time or 8000, Config.DrillTimeTolerance) then return end
    if not IsNearWorkshop(GetPlayerCoords(src)) then return end

    local input, inAmt = recipe.input, tonumber(recipe.inputAmount) or 1
    local output, outAmt = recipe.output, tonumber(recipe.outputAmount) or 1
    if not RSGCore.Shared.Items[input] or not RSGCore.Shared.Items[output] then return end
    if inAmt < 1 or outAmt < 1 or inAmt > 50 or outAmt > 50 then return end

    if not exports['rsg-inventory']:HasItem(src, input, inAmt) then
        Notify(src, locale('smelt_title'), locale('smelt_missing'), 'error')
        return
    end
    if not exports['rsg-inventory']:CanAddItem(src, output, outAmt) then
        Notify(src, locale('smelt_title'), locale('inventory_full'), 'error')
        return
    end
    if not exports['rsg-inventory']:RemoveItem(src, input, inAmt, nil, 'rsg-rocks-smelt') then return end

    if exports['rsg-inventory']:AddItem(src, output, outAmt, nil, nil, 'rsg-rocks-smelt') then
        Notify(src, locale('smelt_title'), locale('smelt_success', outAmt, ItemLabel(output)), 'success')
        AddMiningXP(Player, XP.perSmelt)
    else
        exports['rsg-inventory']:AddItem(src, input, inAmt, nil, nil, 'rsg-rocks-smelt-rollback')
        Notify(src, locale('smelt_title'), locale('inventory_full'), 'error')
    end
end)

---------------------------------
-- admin
---------------------------------
local function IsAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission or 'admin')
        or RSGCore.Functions.HasPermission(src, 'god')
end

local function DenyIfNotAdmin(src)
    if IsAdmin(src) then return false end
    Notify(src, locale('admin_title'), locale('no_permission'), 'error')
    return true
end

local function FindNearestZone(coords, maxDist)
    local nearestId, nearestDist = nil, maxDist or 5.0
    for id, zone in pairs(MiningZones) do
        local dist = #(coords - zone.coords)
        if dist < nearestDist then nearestId, nearestDist = id, dist end
    end
    return nearestId
end

-- coords = rock prop position from rsg-gizmo; the zone is stored 1.5m above it
-- (rocks spawn at zone z - 1.5), heading = prop yaw
RegisterNetEvent('rsg-rocks:server:AdminAddRock', function(oreType, radius, coords, heading)
    local src = source
    if not IsAdmin(src) then return end

    if oreType ~= 'rock' and oreType ~= 'saltrock' then return end
    radius = tonumber(radius) or 2.0
    if radius < 0.5 or radius > 10.0 then return end
    if type(coords) ~= 'vector3' then return end

    local ok = exports['rsg-gizmo']:IsPlacementValid(src, coords, Config.AdminPlaceDistance or 15.0)
    if not ok then
        Notify(src, locale('admin_title'), locale('admin_too_far'), 'error')
        return
    end
    heading = (tonumber(heading) or 0.0) % 360.0
    local x, y, z = coords.x, coords.y, coords.z + 1.5

    local insertId = MySQL.insert.await(
        'INSERT INTO `rsg_rocks_zones` (`x`, `y`, `z`, `radius`, `heading`, `ore_type`, `enabled`) VALUES (?, ?, ?, ?, ?, ?, 1)',
        { x, y, z, radius, heading, oreType }
    )
    if not insertId then
        Notify(src, locale('admin_title'), locale('admin_add_fail'), 'error')
        return
    end

    MiningZones[insertId] = { id = insertId, coords = vector3(x, y, z), radius = radius, heading = heading, type = oreType }
    SyncZones()
    Notify(src, locale('admin_title'), locale('admin_add_ok', oreType, insertId), 'success')
end)

RSGCore.Commands.Add('rockadmin', 'Mining rocks admin help', {}, false, function(source)
    if DenyIfNotAdmin(source) then return end
    Notify(source, locale('admin_title'), locale('admin_help', CountZones()), 'inform', 10000)
end, 'admin')

RSGCore.Commands.Add('addrock', 'Place a mining rock (placement mode)', {
    { name = 'type', help = 'rock or saltrock' },
    { name = 'radius', help = 'radius (default 2.0)' },
}, false, function(source, args)
    if DenyIfNotAdmin(source) then return end
    local oreType = (args[1] or 'rock'):lower()
    if oreType ~= 'rock' and oreType ~= 'saltrock' then
        Notify(source, locale('admin_title'), locale('admin_bad_type'), 'error')
        return
    end
    local radius = tonumber(args[2]) or 2.0
    if radius < 0.5 or radius > 10.0 then
        Notify(source, locale('admin_title'), locale('admin_bad_radius'), 'error')
        return
    end
    TriggerClientEvent('rsg-rocks:client:StartPlaceRock', source, oreType, radius)
end, 'admin')

RSGCore.Commands.Add('delrock', 'Delete nearest mining rock (or by id)', {
    { name = 'id', help = 'optional zone id' },
}, false, function(source, args)
    if DenyIfNotAdmin(source) then return end
    local zoneId = tonumber(args[1])
    if not zoneId then
        local coords = GetPlayerCoords(source)
        if not coords then return end
        zoneId = FindNearestZone(coords, Config.AdminDeleteDistance)
    end
    if not zoneId then
        Notify(source, locale('admin_title'), locale('admin_del_none'), 'error')
        return
    end
    -- delete from DB even when the zone is disabled (not loaded in memory)
    local affected = MySQL.update.await('DELETE FROM `rsg_rocks_zones` WHERE `id` = ?', { zoneId })
    if not affected or affected < 1 then
        Notify(source, locale('admin_title'), locale('admin_zone_missing', zoneId), 'error')
        return
    end
    MiningZones[zoneId] = nil
    zoneGlobalDeplete[zoneId] = nil
    SyncZones()
    Notify(source, locale('admin_title'), locale('admin_del_ok', zoneId), 'success')
end, 'admin')

RSGCore.Commands.Add('togglerock', 'Enable/disable a mining rock without deleting it', {
    { name = 'id', help = 'zone id (or nearest if omitted)' },
}, false, function(source, args)
    if DenyIfNotAdmin(source) then return end

    local zoneId = tonumber(args[1])
    if not zoneId then
        -- nearest rock from the full table so disabled rocks can be re-enabled too
        local coords = GetPlayerCoords(source)
        local rows = coords and MySQL.query.await('SELECT `id`, `x`, `y`, `z` FROM `rsg_rocks_zones`') or {}
        local bestDist = Config.AdminDeleteDistance or 5.0
        for _, row in ipairs(rows) do
            local d = #(coords - vector3(tonumber(row.x), tonumber(row.y), tonumber(row.z)))
            if d < bestDist then zoneId, bestDist = tonumber(row.id), d end
        end
        if not zoneId then
            Notify(source, locale('admin_title'), locale('admin_del_none'), 'error')
            return
        end
    end

    local row = MySQL.single.await('SELECT `enabled` FROM `rsg_rocks_zones` WHERE `id` = ?', { zoneId })
    if not row then
        Notify(source, locale('admin_title'), locale('admin_zone_missing', zoneId), 'error')
        return
    end

    local enable = tonumber(row.enabled) ~= 1
    MySQL.update.await('UPDATE `rsg_rocks_zones` SET `enabled` = ? WHERE `id` = ?', { enable and 1 or 0, zoneId })

    if enable then
        LoadZonesFromDb()
        Notify(source, locale('admin_title'), locale('admin_toggle_on', zoneId), 'success')
    else
        MiningZones[zoneId] = nil
        zoneGlobalDeplete[zoneId] = nil
        SyncZones()
        Notify(source, locale('admin_title'), locale('admin_toggle_off', zoneId), 'success')
    end
end, 'admin')

RSGCore.Commands.Add('reloadrocks', 'Reload mining zones from the database', {}, false, function(source)
    if DenyIfNotAdmin(source) then return end
    LoadZonesFromDb()
    Notify(source, locale('admin_title'), locale('admin_reload_ok', CountZones()), 'success')
end, 'admin')

RSGCore.Commands.Add('nearbrocks', 'List mining rocks near you', {
    { name = 'range', help = 'range meters (default 25)' },
}, false, function(source, args)
    if DenyIfNotAdmin(source) then return end
    local range = math.min(tonumber(args[1]) or 25.0, 500.0)
    local coords = GetPlayerCoords(source)
    if not coords then return end

    local found = {}
    for id, zone in pairs(MiningZones) do
        local dist = #(coords - zone.coords)
        if dist <= range then found[#found + 1] = { id = id, dist = dist, type = zone.type } end
    end
    if #found == 0 then
        Notify(source, locale('admin_title'), locale('admin_nearby_none', range), 'inform')
        return
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    local lines = {}
    for i = 1, math.min(#found, 8) do
        lines[i] = ('#%s %s (%.1fm)'):format(found[i].id, found[i].type, found[i].dist)
    end
    Notify(source, locale('admin_title'), table.concat(lines, ' | '), 'inform', 10000)
end, 'admin')

RSGCore.Commands.Add('miningxp', 'Show your mining XP and level', {}, false, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    if not XP.enabled then
        Notify(source, locale('mining_title'), locale('xp_disabled'), 'inform')
        return
    end
    local xp = GetXP(Player)
    Notify(source, locale('mining_title'), locale('xp_status', GetMiningLevel(xp), xp), 'inform')
end)

AddEventHandler('playerDropped', function()
    -- cooldowns are kept per citizenid; drop the character's entry only once everything has expired
    local cid = CitizenId(source)
    local cds = cid and mineCooldowns[cid]
    if cds then
        local now = GetGameTimer()
        for id, untilT in pairs(cds) do if untilT <= now then cds[id] = nil end end
        if next(cds) == nil then mineCooldowns[cid] = nil end
    end
    workSessions[source] = nil
end)

---------------------------------
-- miner's hat: use the item to put it on / take it off
---------------------------------
if Config.MiningHat and Config.MiningHat.enabled and Config.MiningHat.item then
    RSGCore.Functions.CreateUseableItem(Config.MiningHat.item, function(source)
        TriggerClientEvent('rsg-rocks:client:ToggleMiningHat', source)
    end)
end
