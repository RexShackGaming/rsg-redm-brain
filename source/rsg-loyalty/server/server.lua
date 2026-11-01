local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

---------------------------------------------------------------------
-- Constants / state
---------------------------------------------------------------------
local EARN_INTERVAL = 55000            -- min ms between earn ticks (client pings every 60s)
local LEADERBOARD_CACHE_MS = 30000     -- leaderboard DB results are shared by everyone for 30s

local COOLDOWN_MS = {
    redeem      = 2000,
    data        = 2000,
    leaderboard = 5000,
    admin       = 1000,
}
local cooldowns = { redeem = {}, data = {}, leaderboard = {}, admin = {} }

-- [src] = { citizenid, earned, nextEarn, maxNotified }
local sessions = {}

local leaderboardCache = {}

local ENABLED = Config.Enabled ~= false
if not ENABLED then
    print('^3[rsg-loyalty]^7 Loyalty system is disabled (Config.Enabled = false).')
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function onCooldown(kind, src)
    local now = GetGameTimer()
    local last = cooldowns[kind][src]
    if last and (now - last) < COOLDOWN_MS[kind] then
        return true
    end
    cooldowns[kind][src] = now
    return false
end

local function notify(src, description, nType)
    if src == 0 then
        print(('[rsg-loyalty] %s'):format(description))
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('loyalty_title'),
        description = description,
        type = nType or 'inform',
        duration = Config.UI.NotificationDuration or 5000,
    })
end

local function getCharName(Player)
    local info = Player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname, info.lastname)
end

-- positive whole number no larger than max, or nil
local function sanitizePoints(value, max)
    value = math.tointeger(tonumber(value))
    if not value or value <= 0 or (max and value > max) then return nil end
    return value
end

local function isAdmin(src)
    return src == 0 or RSGCore.Functions.HasPermission(src, 'admin')
end

-- server-side check that the player is standing at a loyalty NPC
local function isNearLoyaltyNpc(src)
    if Config.UI.EnableCommand then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local maxDist = Config.Loyalty.MaxRedeemDistance or 5.0
    for _, loc in ipairs(Config.LoyaltyLocations) do
        if #(pos - loc.npccoords.xyz) <= maxDist then return true end
    end
    return false
end

local function toClient(row)
    if not row then return nil end
    return { loyalty_points = row.loyalty_points, lifetime_points = row.lifetime_points }
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `rsg_loyalty` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL UNIQUE,
            `charname` VARCHAR(50) NOT NULL,
            `loyalty_points` INT NOT NULL DEFAULT 0,
            `lifetime_points` INT NOT NULL DEFAULT 0,
            `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `loyalty_points_idx` (`loyalty_points`),
            KEY `lifetime_points_idx` (`lifetime_points`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(result)
        if result then
            print('^2[rsg-loyalty]^7 Database table `rsg_loyalty` is ready.')
        else
            print('^1[rsg-loyalty]^7 Failed to create `rsg_loyalty` table. Check your database connection.')
        end
    end)
end)

local function getLoyalty(citizenid)
    return MySQL.single.await('SELECT loyalty_points, lifetime_points FROM `rsg_loyalty` WHERE citizenid = ?', { citizenid })
end

-- create the row if missing and keep the character name current
local function ensureLoyalty(citizenid, charname)
    MySQL.insert.await(
        'INSERT INTO `rsg_loyalty` (citizenid, charname) VALUES (?, ?) ON DUPLICATE KEY UPDATE charname = VALUES(charname)',
        { citizenid, charname }
    )
    return getLoyalty(citizenid)
end

local function addPoints(citizenid, points)
    local changed = MySQL.update.await(
        'UPDATE `rsg_loyalty` SET loyalty_points = loyalty_points + ?, lifetime_points = lifetime_points + ? WHERE citizenid = ?',
        { points, points, citizenid }
    )
    return (changed or 0) > 0
end

-- give spent points back without inflating lifetime points
local function refundPoints(citizenid, points)
    MySQL.update.await('UPDATE `rsg_loyalty` SET loyalty_points = loyalty_points + ? WHERE citizenid = ?', { points, citizenid })
end

-- atomic: only succeeds if the player has enough points
local function removePoints(citizenid, points)
    local changed = MySQL.update.await(
        'UPDATE `rsg_loyalty` SET loyalty_points = loyalty_points - ? WHERE citizenid = ? AND loyalty_points >= ?',
        { points, citizenid, points }
    )
    return (changed or 0) > 0
end

local LEADERBOARD_COLUMNS = { loyalty_points = true, lifetime_points = true }

-- global so server/discord.lua can use it
function GetLoyaltyLeaderboard(column)
    if not LEADERBOARD_COLUMNS[column] then return {} end
    local cached = leaderboardCache[column]
    local now = GetGameTimer()
    if cached and (now - cached.time) < LEADERBOARD_CACHE_MS then
        return cached.rows
    end
    local rows = MySQL.query.await(
        ('SELECT charname, %s FROM `rsg_loyalty` ORDER BY %s DESC LIMIT 10'):format(column, column)
    ) or {}
    leaderboardCache[column] = { time = now, rows = rows }
    return rows
end

local function pushLoyalty(src, citizenid)
    local data = getLoyalty(citizenid)
    if data then
        TriggerClientEvent('rsg-loyalty:client:updateLoyaltyData', src, toClient(data))
    end
end

---------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------
RegisterNetEvent('rsg-loyalty:server:playerLoaded', function()
    if not ENABLED then return end
    local src = source
    if onCooldown('data', src) then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- only start a new session for a new character; re-triggering this
    -- event must not reset the per-session earning cap
    local session = sessions[src]
    if not session or session.citizenid ~= citizenid then
        local minPlaytime = (Config.Loyalty.MinPlaytimeBeforeEarning or 0) * 1000
        sessions[src] = {
            citizenid = citizenid,
            earned = 0,
            nextEarn = GetGameTimer() + minPlaytime + EARN_INTERVAL,
            maxNotified = false,
        }
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then sessions[src].lastPos = GetEntityCoords(ped) end
    end

    local data = ensureLoyalty(citizenid, getCharName(Player))
    TriggerClientEvent('rsg-loyalty:client:updateLoyaltyData', src, toClient(data))
end)

local function clearPlayer(src)
    sessions[src] = nil
    for _, list in pairs(cooldowns) do
        list[src] = nil
    end
end

AddEventHandler('playerDropped', function()
    clearPlayer(source)
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    clearPlayer(src)
end)

---------------------------------------------------------------------
-- Data requests
---------------------------------------------------------------------
RegisterNetEvent('rsg-loyalty:server:getLoyaltyData', function()
    if not ENABLED then return end
    local src = source
    if onCooldown('data', src) then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    pushLoyalty(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('rsg-loyalty:server:getLeaderboard', function()
    if not ENABLED then return end
    local src = source
    if onCooldown('leaderboard', src) then return end
    if not RSGCore.Functions.GetPlayer(src) then return end

    TriggerClientEvent('rsg-loyalty:client:leaderboardData', src, {
        topCurrent = GetLoyaltyLeaderboard('loyalty_points'),
        topLifetime = GetLoyaltyLeaderboard('lifetime_points'),
    })
end)

---------------------------------------------------------------------
-- Earning (client only pings; the server decides the amount)
---------------------------------------------------------------------
RegisterNetEvent('rsg-loyalty:server:earnPoints', function()
    if not ENABLED or Config.Loyalty.EnableEarning == false then return end
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local session = sessions[src]
    if not session or session.citizenid ~= Player.PlayerData.citizenid then return end

    local now = GetGameTimer()
    if now < session.nextEarn then return end
    session.nextEarn = now + EARN_INTERVAL

    -- anti-AFK: position is read on the server, so the client can't fake it
    if Config.Loyalty.RequireMovement then
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        local pos = GetEntityCoords(ped)
        local last = session.lastPos
        session.lastPos = pos
        if not last or #(pos - last) < (Config.Loyalty.MinMoveDistance or 5.0) then return end
    end

    local remaining = Config.Loyalty.MaxPointsPerSession - session.earned
    local points = math.min(Config.Loyalty.PointsPerMinute, remaining)
    if points <= 0 then
        if not session.maxNotified then
            session.maxNotified = true
            notify(src, locale('session_max'), 'inform')
        end
        return
    end

    local citizenid = session.citizenid
    if not addPoints(citizenid, points) then return end
    session.earned = session.earned + points

    LogPointsEarned(citizenid, getCharName(Player), points)
    pushLoyalty(src, citizenid)
end)

---------------------------------------------------------------------
-- Redemption
---------------------------------------------------------------------
local REWARD_LISTS = {
    cash = function() return Config.CashRewards end,
    item = function() return Config.ItemRewards end,
}

RegisterNetEvent('rsg-loyalty:server:redeem', function(rewardType, rewardIndex)
    if not ENABLED then return end
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if onCooldown('redeem', src) then
        return notify(src, locale('redeem_cooldown'), 'error')
    end

    if not isNearLoyaltyNpc(src) then
        return notify(src, locale('too_far_from_store'), 'error')
    end

    local getList = REWARD_LISTS[rewardType]
    rewardIndex = math.tointeger(tonumber(rewardIndex))
    local reward = getList and rewardIndex and getList()[rewardIndex]
    if not reward then
        return notify(src, locale('invalid_reward'), 'error')
    end

    if rewardType == 'item' then
        if not RSGCore.Shared.Items[reward.item] then
            print(('^1[rsg-loyalty]^7 Config error: item reward "%s" does not exist in shared items'):format(tostring(reward.item)))
            return notify(src, locale('invalid_reward'), 'error')
        end
        if not exports['rsg-inventory']:CanAddItem(src, reward.item, reward.amount) then
            return notify(src, locale('pocket_full'), 'error')
        end
    end

    local citizenid = Player.PlayerData.citizenid
    local charname = getCharName(Player)
    local label = locale(reward.label)

    -- atomic deduction: fails if not enough points (also blocks double-spend races)
    if not removePoints(citizenid, reward.points) then
        return notify(src, locale('insufficient_points'), 'error')
    end

    local given
    if rewardType == 'cash' then
        given = Player.Functions.AddMoney('cash', reward.amount, 'loyalty-redeem')
    else
        given = exports['rsg-inventory']:AddItem(src, reward.item, reward.amount, nil, nil, 'loyalty-redeem')
        if given then
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[reward.item], 'add', reward.amount)
        end
    end

    if not given then
        refundPoints(citizenid, reward.points)
        LogRedemptionFailed(citizenid, charname, rewardType, label, locale('error_processing'))
        notify(src, locale('error_processing'), 'error')
        return pushLoyalty(src, citizenid)
    end

    LogRedemptionSuccess(citizenid, charname, rewardType, label, reward.amount, reward.points)

    local message = rewardType == 'cash'
        and locale('cash_redeemed', label, reward.amount)
        or locale('item_redeemed', label, reward.amount)
    notify(src, message, 'success')
    pushLoyalty(src, citizenid)
end)

---------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------
-- mode: 'add' | 'remove'
local function adminAdjust(src, targetId, points, mode)
    if not ENABLED then
        return notify(src, locale('loyalty_disabled'), 'error')
    end
    if not isAdmin(src) then
        return notify(src, locale('no_permission'), 'error')
    end
    if src ~= 0 and onCooldown('admin', src) then
        return notify(src, locale('admin_cooldown'), 'error')
    end

    targetId = tonumber(targetId)
    points = sanitizePoints(points, Config.Loyalty.MaxAdminAwardPoints or 10000)
    if not targetId or not points then
        return notify(src, locale('invalid_player_or_points', Config.Loyalty.MaxAdminAwardPoints or 10000), 'error')
    end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then
        return notify(src, locale('player_not_found'), 'error')
    end

    local citizenid = Target.PlayerData.citizenid
    local targetName = getCharName(Target)
    local Admin = src ~= 0 and RSGCore.Functions.GetPlayer(src)
    local adminName = Admin and getCharName(Admin) or locale('console')

    if mode == 'add' then
        if not addPoints(citizenid, points) then
            return notify(src, locale('award_fail'), 'error')
        end
        notify(src, locale('award_success', points, targetName), 'success')
        notify(targetId, locale('award_notification', points), 'success')
        LogAdminPointAward(adminName, targetName, points)
    else
        if not removePoints(citizenid, points) then
            return notify(src, locale('remove_fail'), 'error')
        end
        notify(src, locale('remove_success', points, targetName), 'success')
        notify(targetId, locale('remove_notification', points), 'inform')
        LogAdminPointRemoval(adminName, targetName, points)
    end

    pushLoyalty(targetId, citizenid)
end

RegisterCommand('awardloyalty', function(source, args)
    if not args[1] or not args[2] then
        return notify(source, locale('usage_awardloyalty'), 'inform')
    end
    adminAdjust(source, args[1], args[2], 'add')
end, false)

RegisterCommand('removeloyalty', function(source, args)
    if not args[1] or not args[2] then
        return notify(source, locale('usage_removeloyalty'), 'inform')
    end
    adminAdjust(source, args[1], args[2], 'remove')
end, false)

-- for external admin menus; same permission/validation as the commands
RegisterNetEvent('rsg-loyalty:server:adminAwardPoints', function(targetId, points)
    local src = source
    if not isAdmin(src) then return end
    adminAdjust(src, targetId, points, 'add')
end)

RegisterCommand('checkloyalty', function(source, args)
    if not isAdmin(source) then
        return notify(source, locale('no_permission'), 'error')
    end
    if not ENABLED then
        return notify(source, locale('loyalty_disabled'), 'error')
    end

    local targetId = tonumber(args[1])
    if not targetId then
        return notify(source, locale('usage_checkloyalty'), 'inform')
    end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then
        return notify(source, locale('player_not_found'), 'error')
    end

    local data = getLoyalty(Target.PlayerData.citizenid)
    if not data then
        return notify(source, locale('no_loyalty_data'), 'error')
    end

    notify(source, locale('check_loyalty_result', getCharName(Target), data.loyalty_points, data.lifetime_points), 'inform')
end, false)

RegisterCommand('postleaderboard', function(source)
    if not isAdmin(source) then
        return notify(source, locale('no_permission'), 'error')
    end
    if not ENABLED then
        return notify(source, locale('loyalty_disabled'), 'error')
    end
    if not IsWebhookConfigured() then
        return notify(source, locale('postleaderboard_no_webhook'), 'error')
    end
    SendLeaderboardWebhook()
    notify(source, locale('postleaderboard_success'), 'success')
end, false)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
local function isExportAllowed()
    if not ENABLED then return false end
    if Config.Exports.AllowAllResources then return true end
    local resource = GetInvokingResource()
    if not resource then return false end
    for _, allowed in ipairs(Config.Exports.AllowedResources) do
        if resource == allowed then return true end
    end
    return false
end

exports('getLoyaltyPoints', function(citizenid)
    local data = getLoyalty(citizenid)
    return data and data.loyalty_points or 0
end)

exports('getLifetimeLoyaltyPoints', function(citizenid)
    local data = getLoyalty(citizenid)
    return data and data.lifetime_points or 0
end)

exports('addLoyaltyPoints', function(citizenid, points)
    points = sanitizePoints(points)
    if not points or type(citizenid) ~= 'string' or not isExportAllowed() then return false end
    return addPoints(citizenid, points)
end)

exports('removeLoyaltyPoints', function(citizenid, points)
    points = sanitizePoints(points)
    if not points or type(citizenid) ~= 'string' or not isExportAllowed() then return false end
    return removePoints(citizenid, points)
end)
