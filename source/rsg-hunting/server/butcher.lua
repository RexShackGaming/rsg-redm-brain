local RSGCore = exports['rsg-core']:GetCoreObject()

-- Performance optimization variables
local AnimalValidationCache = {}
local QualityMultipliers = {
    poor = Config.PoorMultiplier or 1,
    good = Config.GoodMultiplier or 2,
    perfect = Config.PerfectMultiplier or 3
}
local ItemQuantities = {
    poor = 1,
    good = 2,
    perfect = 3
}
local LocaleCache = {}
local PlayerCooldowns = {} -- Anti-spam protection
local PROCESS_COOLDOWN = Config.Performance and Config.Performance.ServerProcessCooldown or 2000

-- Initialize caches
CreateThread(function()
    Wait(1000) -- Ensure config is loaded

    -- Build animal validation cache for O(1) lookup
    for i = 1, #Config.Animal do
        local animal = Config.Animal[i]
        AnimalValidationCache[animal.model] = {
            name = animal.name,
            rewardmoney = animal.rewardmoney,
            rewarditem1 = animal.rewarditem1,
            rewarditem2 = animal.rewarditem2,
            rewarditem3 = animal.rewarditem3
        }
    end

    -- Load locale strings from JSON file
    local localeData = nil
    local success, result = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), 'locales/en.json'))

    if success and result then
        localeData = result
        LocaleCache.lang_1 = localeData['sv_lang_1'] or ' Sold a poor '
        LocaleCache.lang_2 = localeData['sv_lang_2'] or ' Sold a good '
        LocaleCache.lang_3 = localeData['sv_lang_3'] or ' Sold a perfect '
        LocaleCache.lang_4 = localeData['sv_lang_4'] or ' for $'

        print('[rsg-hunting] Butcher locale strings loaded successfully from en.json')
    else
        -- Fallback locale strings
        LocaleCache.lang_1 = ' Sold a poor '
        LocaleCache.lang_2 = ' Sold a good '
        LocaleCache.lang_3 = ' Sold a perfect '
        LocaleCache.lang_4 = ' for $'
        print('[rsg-hunting] Warning: Could not load butcher locale file, using fallback strings')
    end

    print('[rsg-hunting] Butcher server cache initialized with ' .. #Config.Animal .. ' animals')

    -- Start performance monitoring if debug is enabled
    if Config.Debug then
        StartButcherPerformanceMonitoring()
    end
end)

-- Performance monitoring system
local PerformanceStats = {
    totalRewards = 0,
    totalPlayers = 0,
    cacheHits = 0,
    cacheMisses = 0,
    startTime = GetGameTimer()
}

function StartButcherPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(60000) -- Report every minute
            local uptime = (GetGameTimer() - PerformanceStats.startTime) / 1000
            local rewardsPerMinute = (PerformanceStats.totalRewards / uptime) * 60
            local totalLookups = PerformanceStats.cacheHits + PerformanceStats.cacheMisses
            local cacheHitRate = totalLookups > 0 and (PerformanceStats.cacheHits / totalLookups * 100) or 0

            print(string.format('[rsg-hunting] Butcher performance stats - Uptime: %.1fs, Rewards/min: %.1f, Cache Hit Rate: %.1f%%, Active Players: %d',
                uptime, rewardsPerMinute, cacheHitRate, #GetPlayers()))

            -- Clean up old cooldown entries
            CleanupButcherPlayerCooldowns()
        end
    end)
end

-- Memory management
function CleanupButcherPlayerCooldowns()
    local currentTime = GetGameTimer()
    local cleaned = 0
    local maxEntries = Config.Performance and Config.Performance.MaxPlayerCooldowns or 100

    -- Remove old entries
    for playerId, lastTime in pairs(PlayerCooldowns) do
        if (currentTime - lastTime) > (PROCESS_COOLDOWN * 10) then -- 10x cooldown time
            PlayerCooldowns[playerId] = nil
            cleaned = cleaned + 1
        end
    end

    -- If still too many entries, remove oldest ones
    local count = 0
    for _ in pairs(PlayerCooldowns) do count = count + 1 end

    if count > maxEntries then
        local entries = {}
        for playerId, lastTime in pairs(PlayerCooldowns) do
            table.insert(entries, {id = playerId, time = lastTime})
        end

        table.sort(entries, function(a, b) return a.time < b.time end)

        for i = 1, count - maxEntries do
            PlayerCooldowns[entries[i].id] = nil
            cleaned = cleaned + 1
        end
    end

    if Config.Debug and cleaned > 0 then
        print('[rsg-hunting] Butcher cleaned up ' .. cleaned .. ' old cooldown entries')
    end
end

-- Optimized validation functions with performance tracking
local function IsValidButcherAnimal(model)
    local result = AnimalValidationCache[model]
    if Config.Debug then
        if result then
            PerformanceStats.cacheHits = PerformanceStats.cacheHits + 1
        else
            PerformanceStats.cacheMisses = PerformanceStats.cacheMisses + 1
        end
    end
    return result
end

local function IsValidButcherQuality(quality)
    return QualityMultipliers[quality] ~= nil
end

-- Player cooldown management
local function IsButcherPlayerOnCooldown(src)
    local currentTime = GetGameTimer()
    local lastProcess = PlayerCooldowns[src]

    if lastProcess and (currentTime - lastProcess) < PROCESS_COOLDOWN then
        return true
    end

    PlayerCooldowns[src] = currentTime
    return false
end

-- Optimized reward processing function
local function ProcessButcherReward(src, animalData, quality)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    local multiplier = QualityMultipliers[quality]
    local quantity = ItemQuantities[quality]
    local finalMoney = animalData.rewardmoney * multiplier

    -- Add money
    Player.Functions.AddMoney('cash', finalMoney)

    -- Add items efficiently
    local itemsToAdd = {}
    if animalData.rewarditem1 then
        itemsToAdd[#itemsToAdd + 1] = { item = animalData.rewarditem1, count = quantity }
    end
    if animalData.rewarditem2 then
        itemsToAdd[#itemsToAdd + 1] = { item = animalData.rewarditem2, count = quantity }
    end
    if animalData.rewarditem3 then
        itemsToAdd[#itemsToAdd + 1] = { item = animalData.rewarditem3, count = quantity }
    end

    -- Batch add items and trigger client events
    for _, itemData in ipairs(itemsToAdd) do
        Player.Functions.AddItem(itemData.item, itemData.count)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemData.item], 'add', itemData.count)
    end

    -- Log the transaction if enabled
    if not Config.Performance or Config.Performance.LoggingEnabled then
        local qualityLabels = { poor = '1', good = '2', perfect = '3' }
        local logMessage = GetPlayerName(src) .. (LocaleCache['lang_' .. (qualityLabels[quality] or '1')] or ' sold a ' .. quality .. ' ') .. animalData.name .. (LocaleCache.lang_4 or ' for $') .. finalMoney
        TriggerEvent('rsg-log:server:CreateLog', Config.WebhookName, Config.WebhookTitle, Config.WebhookColour, logMessage, false)
    end

    -- Update performance stats
    if Config.Debug then
        PerformanceStats.totalRewards = PerformanceStats.totalRewards + 1
    end

    return true
end

RegisterServerEvent('rsg-hunting:server:butcher:reward')
AddEventHandler('rsg-hunting:server:butcher:reward', function(model, quality, name)
    local src = source

    -- Anti-spam protection
    if IsButcherPlayerOnCooldown(src) then
        if Config.Debug then
            print('[rsg-hunting] Butcher: player ' .. GetPlayerName(src) .. ' is on cooldown')
        end
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Quick parameter validation
    if not model or not quality or not name or type(model) ~= 'number' or type(quality) ~= 'string' or type(name) ~= 'string' then
        print('[rsg-hunting] Butcher: invalid parameters from player: ' .. GetPlayerName(src))
        return
    end

    -- Fast cache lookup for animal validation
    local animalData = IsValidButcherAnimal(model)
    if not animalData then
        print('[rsg-hunting] Butcher: invalid animal model from player: ' .. GetPlayerName(src) .. ' Model: ' .. tostring(model))
        return
    end

    -- Validate quality
    if not IsValidButcherQuality(quality) then
        print('[rsg-hunting] Butcher: invalid quality from player: ' .. GetPlayerName(src) .. ' Quality: ' .. tostring(quality))
        return
    end

    -- Process the reward
    local success = ProcessButcherReward(src, animalData, quality)

    if Config.Debug and success then
        print('[rsg-hunting] Butcher: processed ' .. quality .. ' ' .. animalData.name .. ' for ' .. GetPlayerName(src))
    end
end)

--------------------------------------
-- cleanup on player disconnect
--------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    -- Clean up player cooldown data
    if PlayerCooldowns[src] then
        PlayerCooldowns[src] = nil
    end
end)
