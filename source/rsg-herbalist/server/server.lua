local RSGCore = exports['rsg-core']:GetCoreObject()

lib.locale()

local function Debug(msg)
    if Config.Debug then
        print('[rsg-herbalist] ' .. msg)
    end
end

local function Notify(src, title, description, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = description, type = nType or 'error', duration = 5000,
    })
end

local function ItemLabel(item)
    local def = RSGCore.Shared.Items[item]
    return def and def.label or item
end

-- Sums every stack (an item can be split across several slots).
local function PlayerItemCount(Player, itemName)
    local items = Player.PlayerData and Player.PlayerData.items
    if not items then return 0 end
    local total = 0
    for _, item in pairs(items) do
        if item and item.name == itemName then
            total = total + (item.amount or 0)
        end
    end
    return total
end

local function CanCarry(src, item, amount)
    local ok, result = pcall(function()
        return exports['rsg-inventory']:CanAddItem(src, item, amount)
    end)
    return not ok or result -- if the export is unavailable, fall back to AddItem's own result
end

----------------------------------------------------------------------------
-- Herb gathering
----------------------------------------------------------------------------

-- Composite (stripped of COMPOSITE_LOOTABLE_/_INTERACTABLE) -> inventory item.
local toItem = {
    AGARITA_DEF = 'herb_agarita',
    ALASKAN_GINSENG_ROOT_DEF = 'herb_alaskan_ginseng',
    AMERICAN_GINSENG_ROOT_DEF = 'herb_american_ginseng',
    BAY_BOLETE_DEF = 'herb_bay_boletus',
    BITTERWEED_DEF = 'herb_bitterweed',
    BLACK_BERRY_DEF = 'blackberry',
    BLACK_CURRANT_DEF = 'herb_black_current',
    BLOODFLOWER_DEF = 'herb_bloodflower',
    BURDOCK_ROOT_DEF = 'herb_burdock_root',
    CARDINAL_FLOWER_DEF = 'herb_cardinal_flower',
    CHANTERELLES_DEF = 'herb_chanterelles',
    CHOC_DAISY_DEF = 'herb_choc_daisy',
    COMMON_BULRUSH_DEF = 'herb_common_bullrush',
    CREEKPLUM_DEF = 'herb_creek_plum',
    CREEPING_THYME_DEF = 'herb_creeping_thyme',
    CROWS_GARLIC_DEF = 'herb_crows_garlic',
    DESERT_SAGE_DEF = 'herb_desert_sage',
    ENGLISH_MACE_DEF = 'herb_english_mace',
    EVERGREEN_HUCKLEBERRY_DEF = 'herb_evergreen_huckleberry',
    GOLDEN_CURRANT_DEF = 'herb_golden_currant',
    HARRIETUM_OFFICINALIS_DEF = 'herb_harrietum_officinalis',
    HUMMINGBIRD_SAGE_DEF = 'herb_hummingbird_sage',
    INDIAN_TOBACCO_DEF = 'herb_indian_tobacco',
    MILKWEED_DEF = 'herb_milkweed',
    OLEANDER_SAGE_DEF = 'herb_oleander_sage',
    OREGANO_DEF = 'herb_oregano',
    PARASOL_MUSHROOM_DEF = 'herb_parasol_mushroom',
    PRAIRIE_POPPY_DEF = 'herb_prairie_poppy',
    RAMS_HEAD_DEF = 'herb_rams_head',
    RED_RASPBERRY_DEF = 'raspberry',
    RED_SAGE_DEF = 'herb_red_sage',
    SALTBUSH_DEF = 'herb_saltbush',
    TEXAS_BONNET_DEF = 'herb_texas_blue_bonnet',
    VIOLET_SNOWDROP_DEF = 'herb_violet_snowdrop',
    WILD_CARROT_DEF = 'herb_wild_carrot',
    WILD_FEVERFEW_DEF = 'herb_wild_feverfew',
    WILD_MINT_DEF = 'herb_wild_mint',
    WILD_RHUBARB_DEF = 'herb_wild_rhubarb',
    WINTERGREEN_BERRY_DEF = 'herb_wintergreen_berry',
    WISTERIA_DEF = 'herb_wisteria',
    YARROW_DEF = 'herb_yarrow',
    -- orchids
    ORCHID_ACUNA_STAR_DEF = 'herb_acuna_star_orchid',
    ORCHID_CIGAR_DEF = 'herb_cigar_orchid',
    ORCHID_CLAM_SHELL_DEF = 'herb_clam_shell_orchid',
    ORCHID_DRAGONS_DEF = 'herb_dragons_mouth_orchid',
    ORCHID_GHOST_DEF = 'herb_ghost_orchid',
    ORCHID_LADY_NIGHT_DEF = 'herb_lady_of_the_night_orchid',
    ORCHID_LADY_SLIPPER_DEF = 'herb_lady_slipper',
    ORCHID_MOCCASIN_DEF = 'herb_moccasin_flower_orchid',
    ORCHID_NIGHT_SCENTED_DEF = 'herb_night_scented_orchid',
    ORCHID_QUEENS_DEF = 'herb_queens_orchid',
    ORCHID_RAT_TAIL_DEF = 'herb_rat_tail_orchid',
    ORCHID_SPARROWS_DEF = 'herb_sparrows_egg_orchid',
    ORCHID_SPIDER_DEF = 'herb_spider_orchid',
    ORCHID_VANILLA_DEF = 'herb_vanilla_orchid',
}

-- Authoritative spawn list, built identically to the client (shared/spawns.lua).
local spawns = BuildHerbSpawns()
local defaultPlant = {}
for id, s in ipairs(spawns) do defaultPlant[id] = s.plant end
local suppressedUntil = {}  -- id -> os.time() the node regrows at
local lastGatherAt = {}
local lastSyncAt = {}

-- Warn once at start about plants that have no item mapping.
do
    local warned = {}
    for _, s in ipairs(spawns) do
        local key = StripComposite(s.plant)
        if not toItem[key] and not warned[key] then
            warned[key] = true
            print(('[rsg-herbalist] ^3warning: no item mapping for plant %s^7'):format(s.plant))
        end
    end
    Debug(('built %d spawn entries'):format(#spawns))
end

RegisterNetEvent('rsg-herbalist:server:gathered', function(id)
    local src = source
    local spawn = type(id) == 'number' and spawns[id]
    if not spawn then
        Webhook.FlagSuspicious(src, 'gather_unknown_spawn', 'id=' .. tostring(id))
        return
    end

    if suppressedUntil[id] then
        Debug(('already gathered id=%d'):format(id)) -- common race when two players pick at once
        return
    end

    local now = GetGameTimer()
    if lastGatherAt[src] and (now - lastGatherAt[src]) < Config.GatherCooldownMs then
        Webhook.FlagSuspicious(src, 'gather_cooldown', ('fired again %dms after previous gather'):format(now - lastGatherAt[src]))
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local dist = #(GetEntityCoords(ped) - spawn.coord)
    if dist > Config.ScopeRangeGather then
        Webhook.FlagSuspicious(src, 'gather_distance', ('dist=%.1f max=%.1f'):format(dist, Config.ScopeRangeGather))
        return
    end

    local item = toItem[StripComposite(spawn.plant)]
    if not item then return end

    lastGatherAt[src] = now

    if not CanCarry(src, item, 1) or not Player.Functions.AddItem(item, 1) then
        Notify(src, locale('inventory_full_title'), locale('inventory_full_description'))
        TriggerClientEvent('rsg-herbalist:client:ForceReload', src, id)
        return
    end

    suppressedUntil[id] = os.time() + Config.SuppressionWearoffSeconds
    TriggerClientEvent('rsg-herbalist:client:SetSuppressed', -1, id, true)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
    Webhook.LogGather(src, ItemLabel(item), ('#%d %s'):format(id, tostring(spawn.coord)))
end)

-- Regrowth: the server picks the node's next plant so every client agrees.
CreateThread(function()
    while true do
        Wait(60 * 1000)
        local now = os.time()
        for id, wearoff in pairs(suppressedUntil) do
            if wearoff <= now then
                suppressedUntil[id] = nil
                local spawn = spawns[id]
                local plants = Config.Zones[spawn.zone].plants
                local candidates = {}
                for _, p in ipairs(plants) do
                    if p ~= spawn.plant then candidates[#candidates + 1] = p end
                end
                if #candidates > 0 then
                    spawn.plant = candidates[math.random(#candidates)]
                end
                TriggerClientEvent('rsg-herbalist:client:SetSuppressed', -1, id, false, spawn.plant)
            end
        end
    end
end)

-- Clients request full state when their script starts (covers joins and resource restarts).
RegisterNetEvent('rsg-herbalist:server:requestSync', function()
    local src = source
    local now = GetGameTimer()
    if lastSyncAt[src] and now - lastSyncAt[src] < 10000 then return end
    lastSyncAt[src] = now

    local ids, overrides = {}, {}
    for id in pairs(suppressedUntil) do ids[#ids + 1] = id end
    for id, s in ipairs(spawns) do
        if s.plant ~= defaultPlant[id] then
            overrides[#overrides + 1] = { id, s.plant }
        end
    end
    TriggerClientEvent('rsg-herbalist:client:SyncState', src, ids, overrides)
end)

----------------------------------------------------------------------------
-- Tonic crafting
--
-- requestCraft only validates and starts the timer; ingredients are removed
-- and the output granted in finishCraft, after the server confirms the
-- recipe's duration has actually elapsed. Cancelling or disconnecting
-- mid-craft therefore costs nothing and needs no refund.
----------------------------------------------------------------------------

local tonicsById = {}
for _, tonic in ipairs(Config.Tonics) do
    tonicsById[tonic.id] = tonic
end

local lastCraftAt = {}
local pendingCraft = {}   -- src -> { id, startedAt }
local lastTonicUseAt = {}

local function HasHerbalistJob(Player)
    if not Config.LockTonicCraftingToJob then return true end
    local job = Player.PlayerData.job
    return job and job.name == Config.TonicCraftingJobName
end

local function HasIngredients(Player, tonic)
    for _, ingredient in ipairs(tonic.ingredients) do
        if PlayerItemCount(Player, ingredient.item) < ingredient.amount then
            return false
        end
    end
    return true
end

RSGCore.Functions.CreateUseableItem('mortarpestle', function(source)
    local src = source
    if not Config.TonicCraftingEnabled then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not HasHerbalistJob(Player) then
        Notify(src, locale('craft_locked_title'), locale('craft_locked_description'))
        return
    end
    if pendingCraft[src] then return end

    TriggerClientEvent('rsg-herbalist:client:OpenTonicCrafting', src)
end)

for itemName in pairs(Config.TonicEffects) do
    RSGCore.Functions.CreateUseableItem(itemName, function(source)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end

        local now = GetGameTimer()
        local cooldownMs = Config.TonicUseCooldownMs or 0
        if cooldownMs > 0 and lastTonicUseAt[src] and (now - lastTonicUseAt[src]) < cooldownMs then
            local remaining = math.ceil((cooldownMs - (now - lastTonicUseAt[src])) / 1000)
            Notify(src, locale('tonic_cooldown_title'), locale('tonic_cooldown_description', remaining))
            return
        end

        if not Player.Functions.RemoveItem(itemName, 1) then return end
        lastTonicUseAt[src] = now
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'remove', 1)
        TriggerClientEvent('rsg-herbalist:client:ApplyTonicEffect', src, itemName)
    end)
end

RegisterNetEvent('rsg-herbalist:server:requestCraft', function(tonicId)
    local src = source
    if not Config.TonicCraftingEnabled then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if pendingCraft[src] then
        Webhook.FlagSuspicious(src, 'craft_double_request', 'tonicId=' .. tostring(tonicId))
        return
    end

    local now = GetGameTimer()
    if lastCraftAt[src] and (now - lastCraftAt[src]) < Config.TonicCraftCooldownMs then
        Webhook.FlagSuspicious(src, 'craft_cooldown', ('fired again %dms after previous request'):format(now - lastCraftAt[src]))
        return
    end
    lastCraftAt[src] = now

    if not HasHerbalistJob(Player) then
        Webhook.FlagSuspicious(src, 'craft_job_lock', 'tonicId=' .. tostring(tonicId))
        Notify(src, locale('craft_locked_title'), locale('craft_locked_description'))
        return
    end

    local tonic = tonicsById[tonicId]
    if not tonic then
        Webhook.FlagSuspicious(src, 'craft_unknown_tonic', 'tonicId=' .. tostring(tonicId))
        return
    end

    if not HasIngredients(Player, tonic) then
        Notify(src, locale('craft_missing_title'), locale('craft_missing_description'))
        return
    end

    pendingCraft[src] = { id = tonicId, startedAt = now }
    TriggerClientEvent('rsg-herbalist:client:StartCraftProgress', src, tonic.durationMs)
end)

RegisterNetEvent('rsg-herbalist:server:finishCraft', function()
    local src = source
    local pending = pendingCraft[src]
    pendingCraft[src] = nil
    if not pending then return end

    local tonic = tonicsById[pending.id]
    local Player = RSGCore.Functions.GetPlayer(src)
    if not tonic or not Player then return end

    -- Client can't skip the craft timer (small tolerance for network jitter).
    local elapsed = GetGameTimer() - pending.startedAt
    if elapsed < tonic.durationMs - 1000 then
        Webhook.FlagSuspicious(src, 'craft_too_fast', ('elapsed=%dms required=%dms'):format(elapsed, tonic.durationMs))
        return
    end

    -- Re-check: the player may have dropped/traded ingredients mid-craft.
    if not HasIngredients(Player, tonic) then
        Notify(src, locale('craft_missing_title'), locale('craft_missing_description'))
        return
    end

    if not CanCarry(src, tonic.output.item, tonic.output.amount) then
        Notify(src, locale('inventory_full_title'), locale('craft_inventory_full_description'))
        return
    end

    local removed = {}
    for _, ingredient in ipairs(tonic.ingredients) do
        if not Player.Functions.RemoveItem(ingredient.item, ingredient.amount) then
            for _, r in ipairs(removed) do Player.Functions.AddItem(r.item, r.amount) end
            Notify(src, locale('craft_missing_title'), locale('craft_missing_description'))
            return
        end
        removed[#removed + 1] = ingredient
    end

    if not Player.Functions.AddItem(tonic.output.item, tonic.output.amount) then
        for _, r in ipairs(removed) do Player.Functions.AddItem(r.item, r.amount) end
        Notify(src, locale('inventory_full_title'), locale('craft_inventory_full_description'))
        Webhook.LogCraft(src, tonic, 'refunded')
        return
    end

    for _, ingredient in ipairs(tonic.ingredients) do
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[ingredient.item], 'remove', ingredient.amount)
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[tonic.output.item], 'add', tonic.output.amount)
    Webhook.LogCraft(src, tonic, 'success')
end)

RegisterNetEvent('rsg-herbalist:server:cancelCraft', function()
    pendingCraft[source] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastGatherAt[src] = nil
    lastSyncAt[src] = nil
    lastCraftAt[src] = nil
    pendingCraft[src] = nil
    lastTonicUseAt[src] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Webhook.LogResourceEvent('started')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Webhook.LogResourceEvent('stopped')
    end
end)
