----------------------------------------------------------------------------
-- Herb mystery box (server-authoritative)
--
-- One box exists at a time. It relocates every relocateAfterSeconds, or
-- immediately after it's looted.
----------------------------------------------------------------------------

local RSGCore = exports['rsg-core']:GetCoreObject()
local mb = Config.MysteryBox

local function Debug(msg)
    if Config.Debug then
        print('[rsg-herbalist:mysterybox] ' .. msg)
    end
end

if not mb or not mb.enabled or not mb.coords or #mb.coords == 0 then return end

-- Drop any pool entries that aren't registered items so loot is never silently lost.
local function ValidatePool(pool, name)
    local valid = {}
    for _, item in ipairs(pool) do
        if RSGCore.Shared.Items[item] then
            valid[#valid + 1] = item
        else
            print(('[rsg-herbalist] ^3warning: Config.MysteryBox.%s contains unknown item "%s"^7'):format(name, item))
        end
    end
    return valid
end

local herbPool = ValidatePool(mb.herbPool, 'herbPool')
local orchidPool = ValidatePool(mb.orchidPool, 'orchidPool')

local currentCoord, currentIndex, relocateAt = nil, nil, nil
local lastOpenAt = {}
local lastRequestAt = {}

local function Notify(src, title, description, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title, description = description, type = nType or 'error', duration = 5000,
    })
end

local function RelocateBox()
    local idx = math.random(#mb.coords)
    if #mb.coords > 1 and idx == currentIndex then
        idx = (idx % #mb.coords) + 1
    end
    currentIndex = idx
    currentCoord = mb.coords[idx]
    relocateAt = os.time() + mb.relocateAfterSeconds
    Debug('box relocated to index=' .. idx)
    TriggerClientEvent('rsg-herbalist:client:SetMysteryBox', -1, currentCoord)
end

RegisterNetEvent('rsg-herbalist:server:requestMysteryBox', function()
    local src = source
    local now = GetGameTimer()
    if lastRequestAt[src] and now - lastRequestAt[src] < 10000 then return end
    lastRequestAt[src] = now
    TriggerClientEvent('rsg-herbalist:client:SetMysteryBox', src, currentCoord)
end)

AddEventHandler('playerDropped', function()
    lastOpenAt[source] = nil
    lastRequestAt[source] = nil
end)

CreateThread(function()
    RelocateBox()
    while true do
        Wait(60 * 1000)
        if os.time() >= relocateAt then
            RelocateBox()
        end
    end
end)

local function RollLoot()
    local loot = {}
    if #orchidPool > 0 then
        loot[#loot + 1] = orchidPool[math.random(#orchidPool)]
    end
    if #herbPool > 0 then
        for _ = 1, math.random(mb.herbCountMin, mb.herbCountMax) do
            loot[#loot + 1] = herbPool[math.random(#herbPool)]
        end
    end
    return loot
end

RegisterNetEvent('rsg-herbalist:server:openMysteryBox', function()
    local src = source
    if not currentCoord then return end

    local now = GetGameTimer()
    if lastOpenAt[src] and (now - lastOpenAt[src]) < Config.GatherCooldownMs then
        Webhook.FlagSuspicious(src, 'mysterybox_cooldown', ('fired again %dms after previous attempt'):format(now - lastOpenAt[src]))
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or (Player.PlayerData.metadata and Player.PlayerData.metadata.isdead) then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local dist = #(GetEntityCoords(ped) - currentCoord)
    if dist > mb.scopeRangeGather then
        Webhook.FlagSuspicious(src, 'mysterybox_distance', ('dist=%.1f max=%.1f'):format(dist, mb.scopeRangeGather))
        return
    end
    lastOpenAt[src] = now

    local loot = RollLoot()

    -- Don't consume the box if the player can't carry its contents.
    -- CanAddItem is per item, so also check the haul's combined weight.
    local counts, totalWeight = {}, 0
    for _, item in ipairs(loot) do
        counts[item] = (counts[item] or 0) + 1
        totalWeight = totalWeight + (RSGCore.Shared.Items[item].weight or 0)
    end
    local canCarry = exports['rsg-inventory']:GetFreeWeight(src) >= totalWeight
    for item, amount in pairs(counts) do
        if not canCarry then break end
        canCarry = exports['rsg-inventory']:CanAddItem(src, item, amount) and true or false
    end
    if not canCarry then
        Notify(src, locale('inventory_full_title'), locale('mysterybox_inventory_full_description'))
        return
    end

    -- Claim the box before touching inventory so it can't be looted twice.
    currentCoord = nil
    TriggerClientEvent('rsg-herbalist:client:SetMysteryBox', -1, nil)

    local granted = {}
    for item, amount in pairs(counts) do
        if exports['rsg-inventory']:AddItem(src, item, amount, nil, nil, 'rsg-herbalist:mysterybox') then
            granted[#granted + 1] = ('%dx %s'):format(amount, RSGCore.Shared.Items[item].label or item)
        end
    end

    Notify(src, locale('mysterybox_found_title'), locale('mysterybox_found_description'), 'success')

    if #granted > 0 then
        Webhook.LogMysteryBox(src, granted)
    end

    RelocateBox()
end)
