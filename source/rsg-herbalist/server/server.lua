local RSGCore = exports['rsg-core']:GetCoreObject()

local function Debug(msg)
    if Config.Debug then
        print('[rsg-herbalist] ' .. msg)
    end
end

local Notify = Herbalist.Notify
local IsDead = Herbalist.IsDead

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
    return exports['rsg-inventory']:CanAddItem(src, item, amount) and true or false
end

local function GiveItem(src, item, amount, reason, info)
    return exports['rsg-inventory']:AddItem(src, item, amount, info, nil, reason) and true or false
end

local function TakeItem(src, item, amount, reason, slot)
    return exports['rsg-inventory']:RemoveItem(src, item, amount, slot, reason) and true or false
end

-- rsg-skills (optional): award XP and read perks, both on the server
local function skillXP(src, amount, reason)
    if not Config.Skills.Enabled or not amount or amount <= 0 then return end
    if GetResourceState('rsg-skills') ~= 'started' then return end
    exports['rsg-skills']:AddXP(src, Config.Skills.Skill, amount, reason)
end

local function skillPerk(src, perk)
    if not Config.Skills.Enabled or GetResourceState('rsg-skills') ~= 'started' then return 0 end
    return tonumber(exports['rsg-skills']:GetPerk(src, Config.Skills.Skill, perk)) or 0
end

-- Herbalism level, or nil when rsg-skills is off/not started (then no level gating applies).
local function HerbalismLevel(src)
    if not Config.Skills.Enabled or GetResourceState('rsg-skills') ~= 'started' then return nil end
    local ok, lvl = pcall(function() return exports['rsg-skills']:GetLevel(src, Config.Skills.Skill) end)
    return ok and tonumber(lvl) or nil
end

-- Field guide: per-player gather counts in player metadata (rsg-core saves it, no table needed).
function Herbalist.RecordFound(src, Player, item, amount)
    if not Config.FieldGuide.Enabled or not Player or not item then return end
    local current = Player.PlayerData.metadata and Player.PlayerData.metadata.herbalist_guide
    local guide = {}
    if type(current) == 'table' then for k, v in pairs(current) do guide[k] = v end end
    local isNew = guide[item] == nil
    guide[item] = (tonumber(guide[item]) or 0) + (amount or 1)
    Player.Functions.SetMetaData('herbalist_guide', guide)
    if isNew then
        Notify(src, locale('guide_new_title'), locale('guide_new_description', ItemLabel(item)), 'success')
        skillXP(src, Config.FieldGuide.DiscoveryXP, 'herb discovered')
    end
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
    WILD_CARROT_DEF = 'carrot',
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

-- Drop mappings to items that aren't registered (AddItem would always fail and the
-- player would see a misleading "inventory full"), then warn once about unmapped plants.
for key, item in pairs(toItem) do
    if not RSGCore.Shared.Items[item] then
        print(('[rsg-herbalist] ^3warning: item "%s" (plant %s) is not registered, skipping^7'):format(item, key))
        toItem[key] = nil
    end
end

-- Nodes whose plant has no registered item can never be gathered. Spawn ids must stay
-- identical on client and server, so instead of dropping them from the list we re-point
-- them at a gatherable plant from the same zone (sent to clients as a plant override),
-- or, if the zone has none, mark them disabled (sent as permanently suppressed).
local function isMapped(plant)
    return toItem[StripComposite(plant)] ~= nil
end

local disabledSet = {}
local disabledIds = {}
do
    local warned, reassigned = {}, 0
    for id, s in ipairs(spawns) do
        if not isMapped(s.plant) then
            local key = StripComposite(s.plant)
            if not warned[key] then
                warned[key] = true
                print(('[rsg-herbalist] ^3warning: no item mapping for plant %s^7'):format(s.plant))
            end
            local replacement
            for _, p in ipairs(Config.Zones[s.zone].plants) do
                if isMapped(p) then replacement = p break end
            end
            if replacement then
                s.plant = replacement
                reassigned = reassigned + 1
            else
                disabledSet[id] = true
                disabledIds[#disabledIds + 1] = id
            end
        end
    end
    if reassigned > 0 or #disabledIds > 0 then
        print(('[rsg-herbalist] ^3%d node(s) re-pointed to a gatherable plant, %d disabled (no registered item)^7'):format(reassigned, #disabledIds))
    end
    Debug(('built %d spawn entries'):format(#spawns))
end

-- Persistence: regrow timers and regrown plants survive restarts (MySQL, rsg_herbalist_state).
local STATE_KEY = 'nodes_v1'
local nodesDirty = false
local nodesLoaded = false

local function SaveNodes()
    if not nodesLoaded or not nodesDirty then return end
    nodesDirty = false
    local data = { count = #spawns, suppressed = {}, plants = {} }
    for id, wearoff in pairs(suppressedUntil) do data.suppressed[#data.suppressed + 1] = { id, wearoff } end
    for id, s in ipairs(spawns) do
        if s.plant ~= defaultPlant[id] then data.plants[#data.plants + 1] = { id, s.plant } end
    end
    Herbalist.SaveState(STATE_KEY, data)
end

local function RestoreNodes(raw)
    local ok, data = pcall(json.decode, raw or '')
    -- ids are positions in the spawn list, so ignore saved state if the list changed size
    if ok and type(data) == 'table' and data.count == #spawns then
        for _, e in ipairs(data.plants or {}) do
            local s = spawns[e[1]]
            if s and type(e[2]) == 'string' and not disabledSet[e[1]] and isMapped(e[2]) then
                for _, p in ipairs(Config.Zones[s.zone].plants) do
                    if p == e[2] then s.plant = e[2] break end
                end
            end
        end
        local restored = 0
        for _, e in ipairs(data.suppressed or {}) do
            if spawns[e[1]] and not disabledSet[e[1]] and type(e[2]) == 'number' then
                suppressedUntil[e[1]] = e[2]
                restored = restored + 1
            end
        end
        Debug(('restored %d regrow timers'):format(restored))
    end
end

local function NodeState()
    local ids, overrides = {}, {}
    for id in pairs(suppressedUntil) do ids[#ids + 1] = id end
    for i = 1, #disabledIds do ids[#ids + 1] = disabledIds[i] end
    for id, s in ipairs(spawns) do
        if s.plant ~= defaultPlant[id] then
            overrides[#overrides + 1] = { id, s.plant }
        end
    end
    return ids, overrides
end

-- gathering is rejected until the saved state is in
Herbalist.LoadState(STATE_KEY, function(raw)
    RestoreNodes(raw)
    nodesLoaded = true
    TriggerClientEvent('rsg-herbalist:client:SyncState', -1, NodeState())
end)

-- Every herb the field guide lists: gatherable plants plus the mystery box pools.
local guideItems = {}
do
    local seen = {}
    local function add(item)
        if item and not seen[item] and RSGCore.Shared.Items[item] then
            seen[item] = true
            guideItems[#guideItems + 1] = item
        end
    end
    for _, item in pairs(toItem) do add(item) end
    local mb = Config.MysteryBox
    if mb then
        for _, item in ipairs(mb.herbPool or {}) do add(item) end
        for _, item in ipairs(mb.orchidPool or {}) do add(item) end
    end
    table.sort(guideItems)
end

RSGCore.Functions.CreateCallback('rsg-herbalist:server:getGuide', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Config.FieldGuide.Enabled or not Player then return cb(nil) end
    local found = Player.PlayerData.metadata and Player.PlayerData.metadata.herbalist_guide
    cb({ items = guideItems, found = type(found) == 'table' and found or {} })
end)

RegisterNetEvent('rsg-herbalist:server:gathered', function(id)
    local src = source
    if not nodesLoaded then return end
    Debug(('gather request src=%s id=%s'):format(src, tostring(id)))
    local spawn = type(id) == 'number' and spawns[id]
    if not spawn then
        Webhook.FlagSuspicious(src, 'gather_unknown_spawn', 'id=' .. tostring(id))
        return
    end

    if disabledSet[id] then Debug(('rejected id=%d: node disabled (no registered item)'):format(id)) return end

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
    if not Player or IsDead(Player) then Debug('rejected: no player or dead') return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local dist = #(GetEntityCoords(ped) - spawn.coord)
    if dist > Config.ScopeRangeGather then
        Webhook.FlagSuspicious(src, 'gather_distance', ('dist=%.1f max=%.1f'):format(dist, Config.ScopeRangeGather))
        return
    end

    local item = toItem[StripComposite(spawn.plant)]
    if not item then
        Debug(('rejected id=%d: plant %s has no item'):format(id, spawn.plant))
        TriggerClientEvent('rsg-herbalist:client:ForceReload', src, id)
        return
    end

    lastGatherAt[src] = now

    if not CanCarry(src, item, 1) or not GiveItem(src, item, 1, 'rsg-herbalist:gather') then
        Debug(('rejected id=%d: could not add %s'):format(id, item))
        Notify(src, locale('inventory_full_title'), locale('inventory_full_description'))
        TriggerClientEvent('rsg-herbalist:client:ForceReload', src, id)
        return
    end

    Herbalist.RecordFound(src, Player, item, 1)
    suppressedUntil[id] = os.time() + Config.SuppressionWearoffSeconds
    nodesDirty = true
    TriggerClientEvent('rsg-herbalist:client:SetSuppressed', -1, id, true)
    Webhook.LogGather(src, ItemLabel(item), ('#%d %s'):format(id, tostring(spawn.coord)))

    -- rsg-skills: XP and the extra_yield perk (chance of one more herb)
    skillXP(src, Config.Skills.GatherXP, 'herb gathered')
    if Config.Skills.ExtraYield and math.random(100) <= skillPerk(src, 'extra_yield') and CanCarry(src, item, 1) then
        if GiveItem(src, item, 1, 'rsg-herbalist:skill-bonus') then
            Herbalist.RecordFound(src, Player, item, 1)
        end
    end
end)

-- Regrowth: the server picks the node's next plant so every client agrees.
CreateThread(function()
    while true do
        Wait(60 * 1000)
        local now = os.time()
        for id, wearoff in pairs(suppressedUntil) do
            if wearoff <= now then
                suppressedUntil[id] = nil
                nodesDirty = true
                local spawn = spawns[id]
                local plants = Config.Zones[spawn.zone].plants
                local candidates = {}
                for _, p in ipairs(plants) do
                    if p ~= spawn.plant and isMapped(p) then candidates[#candidates + 1] = p end
                end
                if #candidates > 0 then
                    spawn.plant = candidates[math.random(#candidates)]
                end
                TriggerClientEvent('rsg-herbalist:client:SetSuppressed', -1, id, false, spawn.plant)
            end
        end
        SaveNodes()
    end
end)

-- Clients request full state when their script starts (covers joins and resource restarts).
RegisterNetEvent('rsg-herbalist:server:requestSync', function()
    local src = source
    local now = GetGameTimer()
    if lastSyncAt[src] and now - lastSyncAt[src] < 10000 then return end
    lastSyncAt[src] = now

    TriggerClientEvent('rsg-herbalist:client:SyncState', src, NodeState())
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
    if HerbalistRecipeValid(tonic, RSGCore.Shared.Items) then
        tonicsById[tonic.id] = tonic
    else
        print(('[rsg-herbalist] ^3warning: recipe "%s" skipped, an ingredient or output item is not registered^7'):format(tonic.id))
    end
end

local lastCraftAt = {}
local pendingCraft = {}   -- src -> { id, startedAt }
local lastTonicUseAt = {}

-- A craft the client never finished or cancelled (crash, killed thread) must not
-- lock the player out forever: a pending craft expires shortly after its duration.
local CRAFT_EXPIRY_GRACE_MS = 15000

local function IsCraftPending(src)
    local pending = pendingCraft[src]
    if not pending then return false end
    local tonic = tonicsById[pending.id]
    if tonic and GetGameTimer() - pending.startedAt > tonic.durationMs + CRAFT_EXPIRY_GRACE_MS then
        pendingCraft[src] = nil
        return false
    end
    return true
end

local function HasHerbalistJob(Player)
    if not Config.LockTonicCraftingToJob then return true end
    local name = Config.TonicCraftingJobName
    local job = Player.PlayerData.job
    if job and job.name == name then return true end
    -- multi-job (rsg-core): a job the player holds but isn't currently on also counts
    if Config.LockAllowAnyHeldJob then
        local ok, held = pcall(function() return exports['rsg-core']:HasPlayerJob(Player.PlayerData.source, name) end)
        return ok and held == true
    end
    return false
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
    if not Player or IsDead(Player) then return end

    if not HasHerbalistJob(Player) then
        Notify(src, locale('craft_locked_title'), locale('craft_locked_description'))
        return
    end
    if IsCraftPending(src) then return end

    TriggerClientEvent('rsg-herbalist:client:OpenTonicCrafting', src, HerbalismLevel(src))
end)

for itemName in pairs(Config.TonicEffects) do
    RSGCore.Functions.CreateUseableItem(itemName, function(source, usedItem)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or IsDead(Player) then return end

        local now = GetGameTimer()
        local effect = Config.TonicEffects[itemName]
        local group = effect.group or 'tonic'
        local cooldownMs = effect.cooldownMs or Config.TonicUseCooldownMs or 0
        local lastUse = lastTonicUseAt[src] and lastTonicUseAt[src][group]
        if cooldownMs > 0 and lastUse and (now - lastUse) < cooldownMs then
            local remaining = math.ceil((cooldownMs - (now - lastUse)) / 1000)
            Notify(src, locale('tonic_cooldown_title'), locale('tonic_cooldown_description', remaining))
            return
        end

        -- remove the exact stack that was used (tiers stack separately) and read its tier
        local tierKey = type(usedItem) == 'table' and type(usedItem.info) == 'table' and usedItem.info.tonic_tier
        local tier = tierKey and GetTonicTierByKey(tierKey)
        local slot = type(usedItem) == 'table' and math.tointeger(tonumber(usedItem.slot)) or nil
        if not TakeItem(src, itemName, 1, 'rsg-herbalist:drink-tonic', slot) then return end
        lastTonicUseAt[src] = lastTonicUseAt[src] or {}
        lastTonicUseAt[src][group] = now
        TriggerClientEvent('rsg-herbalist:client:ApplyTonicEffect', src, itemName, tier and tier.boost or 1.0)
    end)
end

RegisterNetEvent('rsg-herbalist:server:requestCraft', function(tonicId)
    local src = source
    if not Config.TonicCraftingEnabled then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or IsDead(Player) then return end

    if IsCraftPending(src) then
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

    -- The mortarpestle item is the only way in, so a request without one never came from the menu.
    if PlayerItemCount(Player, 'mortarpestle') < 1 then
        Webhook.FlagSuspicious(src, 'craft_no_mortarpestle', 'tonicId=' .. tostring(tonicId))
        return
    end

    tonicId = type(tonicId) == 'string' and tonicId or nil
    local tonic = tonicId and tonicsById[tonicId]
    if not tonic then
        Webhook.FlagSuspicious(src, 'craft_unknown_tonic', 'tonicId=' .. tostring(tonicId))
        return
    end

    local level = HerbalismLevel(src)
    if level and level < (tonic.minLevel or 1) then
        Notify(src, locale('craft_level_title'), locale('craft_level_description', tonic.minLevel or 1))
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

    local function Refund(removed)
        for _, r in ipairs(removed) do GiveItem(src, r.item, r.amount, 'rsg-herbalist:craft-refund') end
    end

    local removed = {}
    for _, ingredient in ipairs(tonic.ingredients) do
        if not TakeItem(src, ingredient.item, ingredient.amount, 'rsg-herbalist:craft') then
            Refund(removed)
            Notify(src, locale('craft_missing_title'), locale('craft_missing_description'))
            return
        end
        removed[#removed + 1] = ingredient
    end

    local tier = tonic.quality ~= false and GetTonicTier(HerbalismLevel(src)) or nil
    local info = tier and { tonic_tier = tier.key } or nil
    if not GiveItem(src, tonic.output.item, tonic.output.amount, 'rsg-herbalist:craft', info) then
        Refund(removed)
        Notify(src, locale('inventory_full_title'), locale('craft_inventory_full_description'))
        Webhook.LogCraft(src, tonic, 'refunded')
        return
    end

    local doneText = tier
        and locale('craft_done_tier_description', tonic.output.amount, ItemLabel(tonic.output.item), locale(tier.label))
        or locale('craft_done_description', tonic.output.amount, ItemLabel(tonic.output.item))
    Notify(src, locale('craft_done_title'), doneText, 'success')
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
        SaveNodes()
        Webhook.LogResourceEvent('stopped')
    end
end)
