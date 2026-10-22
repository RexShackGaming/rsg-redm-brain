local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

------------------------------------------
-- build a set of every item the skinning system is allowed to hand out
-- (this is what stops a modified client from sending arbitrary item
-- names to rsg-hunting:server:giverewards and duping loot)
------------------------------------------
local ValidRewardItems = {}

CreateThread(function()
    for _, animal in ipairs(Config.Animals) do
        for i = 1, 5 do
            local item = animal['rewarditem' .. i]
            if item then
                ValidRewardItems[item] = true
            end
        end
    end
end)

------------------------------------------
-- anti-spam: one skinning payout per player per cooldown window
------------------------------------------
local PlayerCooldowns = {}
local REWARD_COOLDOWN = Config.Performance and Config.Performance.ServerProcessCooldown or 2000
local MAX_REWARDS_PER_CALL = 5 -- rewarditem1..5

local function isOnCooldown(src)
    local now = GetGameTimer()
    local last = PlayerCooldowns[src]
    if last and (now - last) < REWARD_COOLDOWN then
        return true
    end
    PlayerCooldowns[src] = now
    return false
end

------------------------------------------
-- give rewards
------------------------------------------
RegisterNetEvent('rsg-hunting:server:giverewards', function(rewards)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(rewards) ~= 'table' then return end

    if isOnCooldown(src) then
        if Config.Debug then
            print(('[rsg-hunting] giverewards: %s is on cooldown'):format(GetPlayerName(src) or src))
        end
        return
    end

    -- reject anything that isn't a real, configured skinning reward so a
    -- tampered client can't request arbitrary items
    local toGive = {}
    local count = 0
    for _, itemName in ipairs(rewards) do
        count = count + 1
        if count > MAX_REWARDS_PER_CALL then
            print(('[rsg-hunting] giverewards: %s sent too many reward slots, dropping the rest'):format(GetPlayerName(src) or src))
            break
        end

        if type(itemName) ~= 'string' then
            -- silently ignore, nil slots are expected
        elseif not ValidRewardItems[itemName] or not RSGCore.Shared.Items[itemName] then
            print(('[rsg-hunting] giverewards: %s sent an invalid reward item "%s" - ignored'):format(GetPlayerName(src) or src, tostring(itemName)))
        else
            toGive[#toGive + 1] = itemName
        end
    end

    if #toGive == 0 then return end

    for _, itemName in ipairs(toGive) do
        if not exports['rsg-inventory']:CanAddItem(src, itemName, 1) then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('inventory_full'),
                type = 'error',
                duration = 8000
            })
            return
        end
    end

    for _, itemName in ipairs(toGive) do
        Player.Functions.AddItem(itemName, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'add', 1)
    end
end)

--------------------------------------
-- cleanup on player disconnect
--------------------------------------
AddEventHandler('playerDropped', function()
    PlayerCooldowns[source] = nil
end)
