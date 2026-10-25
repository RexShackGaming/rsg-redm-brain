local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local lastUse = {}   -- [src] = os.time()
local hookedItem = {} -- [itemName] = substance key (items consumed by rsg-consume)

---------------------------------------------------------------------
-- Data helpers (stored in player metadata 'addiction', mirrored to a replicated statebag)
---------------------------------------------------------------------
local function defaultData()
    local d = { rehab = 0, subs = {} }
    for key in pairs(Config.Addiction.Substances) do
        d.subs[key] = { level = 0, craving = 0 }
    end
    return d
end

local function getData(Player)
    local d = Player.PlayerData.metadata.addiction
    if type(d) ~= 'table' or type(d.subs) ~= 'table' then d = defaultData() end
    for key in pairs(Config.Addiction.Substances) do
        d.subs[key] = d.subs[key] or { level = 0, craving = 0 }
    end
    d.rehab = tonumber(d.rehab) or 0
    return d
end

local StateOf = Player -- keep the CFX Player() statebag accessor before local 'Player' vars shadow it

local function saveData(P, d)
    P.Functions.SetMetaData('addiction', d)
    StateOf(P.PlayerData.source).state:set('addiction', d, true)
end

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('addiction_title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local function clamp(v) return math.max(0, math.min(100, v)) end

local function isHooked(key, sub)
    return sub.level >= Config.Addiction.Substances[key].threshold
end

---------------------------------------------------------------------
-- Core: register a use (only called from trusted server paths)
---------------------------------------------------------------------
local function applyUse(src, key, amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local cfg = Config.Addiction.Substances[key]
    if not cfg then return false end
    amount = tonumber(amount) or 0
    if amount ~= amount or amount < 0 or amount > 100 then return false end

    local d = getData(Player)
    local sub = d.subs[key]
    local wasHooked = isHooked(key, sub)
    sub.level = clamp(sub.level + amount)
    sub.craving = 0
    saveData(Player, d)

    if not wasHooked and isHooked(key, sub) then
        notify(src, locale('hooked', cfg.label), 'warning')
    end
    return true
end
exports('AddUse', applyUse)

exports('GetAddiction', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and getData(Player) or nil
end)

exports('IsInRehab', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and getData(Player).rehab > 0 or false
end)

---------------------------------------------------------------------
-- Items
---------------------------------------------------------------------
for key, cfg in pairs(Config.Addiction.Substances) do
    for itemName in pairs(cfg.items) do
        if cfg.registerItems then
            RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
                local src = source
                local Player = RSGCore.Functions.GetPlayer(src)
                if not Player then return end
                if getData(Player).rehab > 0 then return notify(src, locale('in_rehab_block'), 'error') end
                local now = os.time()
                -- cooldown also covers the smoke animation so a second use can't eat an item mid-anim
                local cd = math.max(Config.Addiction.UseCooldown, math.ceil((cfg.useTime or 0) / 1000))
                if lastUse[src] and now - lastUse[src] < cd then return notify(src, locale('busy'), 'error') end
                lastUse[src] = now
                if not exports['rsg-inventory']:RemoveItem(src, itemName, 1, item and item.slot, 'rsg-drugs-addiction') then return end
                applyUse(src, key, cfg.items[itemName])
                TriggerClientEvent('rsg-drugs:client:useSubstance', src, key)
                -- stress relief happens server-side through rsg-hud
                local relief = cfg.boost and cfg.boost.stressRelief
                if relief and relief > 0 and GetResourceState('rsg-hud') == 'started' then
                    exports['rsg-hud']:RelieveStress(src, relief)
                end
            end)
        else
            hookedItem[itemName] = key
        end
    end
end

-- Hook for items consumed by rsg-consume (client relays its consume event).
-- Feeding only resets craving and RAISES addiction, so a spoofed call can't benefit beyond rate-limit.
RegisterNetEvent('rsg-drugs:server:consumed', function(itemName)
    local src = source
    if type(itemName) ~= 'string' then return end
    local key = hookedItem[itemName]
    if not key then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local now = os.time()
    if lastUse[src] and now - lastUse[src] < Config.Addiction.UseCooldown then return end
    lastUse[src] = now
    if getData(Player).rehab > 0 then return end
    applyUse(src, key, Config.Addiction.Substances[key].items[itemName])
end)

---------------------------------------------------------------------
-- Rehab belongings (confiscated on admission, returned on release)
---------------------------------------------------------------------
local Conf = Config.Addiction.Rehab.Confiscate or {}

local function confiscate(Player)
    if not Conf.Enabled then return end
    local src = Player.PlayerData.source
    local stash = Player.PlayerData.metadata.rehabitems
    stash = type(stash) == 'table' and stash or { items = {}, equipped = {} }
    -- remember equipped guns before removing them (rsg-weapons clears this as they leave the inventory)
    for serial in pairs(Player.PlayerData.metadata.equippedweapons or {}) do stash.equipped[#stash.equipped + 1] = tostring(serial) end
    local taken = 0
    local items = {}
    for _, it in pairs(Player.PlayerData.items or {}) do items[#items + 1] = it end
    for _, it in ipairs(items) do
        if it and it.name and not (Conf.KeepItems or {})[it.name] and (it.amount or 0) > 0 then
            if exports['rsg-inventory']:RemoveItem(src, it.name, it.amount, it.slot, 'rsg-drugs-rehab-confiscate') then
                stash.items[#stash.items + 1] = { name = it.name, amount = it.amount, info = it.info, slot = it.slot }
                taken = taken + it.amount
            end
        end
    end
    Player.Functions.SetMetaData('rehabitems', stash)
    TriggerClientEvent('rsg-drugs:client:disarm', src)
    if taken > 0 then
        notify(src, locale('rehab_items_taken'), 'inform')
        DrugsLog('rehab', 'Belongings confiscated', src, { { 'Stacks', #stash.items }, { 'Items', taken }, { 'Equipped guns', #stash.equipped } })
    end
end

-- safe to call any time: does nothing without a stash; keeps anything that wouldn't fit for next time
local function returnBelongings(Player)
    local stash = Player.PlayerData.metadata.rehabitems
    if type(stash) ~= 'table' or type(stash.items) ~= 'table' then return end
    local src = Player.PlayerData.source
    local left, given = {}, 0
    for _, it in ipairs(stash.items) do
        local ok = false
        if RSGCore.Shared.Items[it.name] and exports['rsg-inventory']:CanAddItem(src, it.name, it.amount) then
            ok = exports['rsg-inventory']:AddItem(src, it.name, it.amount, it.info, it.slot, 'rsg-drugs-rehab-return')
            if not ok then ok = exports['rsg-inventory']:AddItem(src, it.name, it.amount, it.info, nil, 'rsg-drugs-rehab-return') end
        elseif not RSGCore.Shared.Items[it.name] then
            ok = true -- item was removed from the server: nothing to give back
        end
        if ok then given = given + it.amount else left[#left + 1] = it end
    end
    Player.Functions.SetMetaData('rehabitems', #left > 0 and { items = left, equipped = {} } or nil)
    if #left > 0 then notify(src, locale('rehab_items_partial'), 'warning')
    elseif given > 0 then notify(src, locale('rehab_items_returned'), 'success') end
    DrugsLog('rehab', 'Belongings returned', src, { { 'Items returned', given }, { 'Still held (no room)', #left } })

    -- re-equip guns that were equipped on admission (looked up by serial in the restored inventory)
    if Conf.ReEquipWeapons and #(stash.equipped or {}) > 0 then
        local want, list = {}, {}
        for _, s in ipairs(stash.equipped) do want[s] = true end
        local Fresh = RSGCore.Functions.GetPlayer(src) or Player
        for _, it in pairs(Fresh.PlayerData.items or {}) do
            if it and type(it.info) == 'table' and it.info.serie and want[tostring(it.info.serie)] then list[#list + 1] = it end
        end
        if #list > 0 then TriggerClientEvent('rsg-drugs:client:reequip', src, list) end
    end
end

-- give a released player any belongings still held (e.g. after making room)
exports('ReturnRehabItems', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and getData(Player).rehab <= 0 then returnBelongings(Player) return true end
    return false
end)

---------------------------------------------------------------------
-- Rehab
---------------------------------------------------------------------
local function startRehab(src, minutes)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local d = getData(Player)
    d.rehab = math.floor(minutes * 60)
    d.rehabTotal = d.rehab -- for the HUD progress bar
    saveData(Player, d)
    confiscate(Player)
    local spawn = Config.Addiction.Rehab.Spawns[math.random(#Config.Addiction.Rehab.Spawns)]
    TriggerClientEvent('rsg-drugs:client:teleport', src, spawn)
    notify(src, locale('rehab_start', minutes), 'warning')
    return true
end

local function finishRehab(Player)
    local src = Player.PlayerData.source
    DrugsLog('rehab', 'Released from rehab', src, { { 'Status', 'Clean' } })
    local d = defaultData()
    saveData(Player, d)
    TriggerClientEvent('rsg-drugs:client:teleport', src, Config.Addiction.Rehab.Release)
    SetTimeout(2500, function() -- after the teleport fade
        local P = RSGCore.Functions.GetPlayer(src)
        if P then returnBelongings(P) end
    end)
    notify(src, locale('rehab_done'), 'success')
end

local function isRehabJob(Player)
    local job = Player.PlayerData.job
    return job and job.onduty ~= false and (Config.Addiction.Rehab.AllowedJobTypes[job.type] or Config.Addiction.Rehab.AllowedJobs[job.name]) and true or false
end

-- returns allowed, isAdmin
local function canAdmit(Player)
    if isRehabJob(Player) then return true, false end
    if RSGCore.Functions.HasPermission(Player.PlayerData.source, Config.Addiction.Rehab.AdminPermission) then return true, true end
    return false, false
end

local function hasAnyAddiction(d)
    for key, sub in pairs(d.subs) do
        if Config.Addiction.Substances[key] and (sub.level or 0) > 0 then return true end
    end
    return false
end

-- Rehab bonus for lawmen / medics
local lastNpcReward = {}
local function payRehabReward(Officer)
    local r = Config.Addiction.Rehab.Reward
    if not r or not r.Enabled or (r.Amount or 0) <= 0 then return end
    Officer.Functions.AddMoney(r.MoneyType or 'cash', r.Amount, 'rehab-admission-bonus')
    DrugsLog('rehab', 'Rehab bonus paid', Officer.PlayerData.source, { { 'Amount', ('$%s (%s)'):format(r.Amount, r.MoneyType or 'cash') } })
    notify(Officer.PlayerData.source, locale('rehab_reward', r.Amount), 'success')
end

---------------------------------------------------------------------
-- NPC addicts are tracked on the server by network id so clients can't
-- claim an NPC is hooked (forced sales) or farm rehab bonuses.
---------------------------------------------------------------------
local NpcAddicts = {} -- [netId] = { seller = citizenid }
local NpcRefused = {} -- [netId] = true
local NpcSold = {}    -- [netId] = os.time() of last sale (non-addicts buy once, addicts after AddictRebuyMinutes)

local function npcFromNet(src, netId, maxDist)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return end
    if #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(src))) > maxDist then return end
    return ent, netId
end

RegisterNetEvent('rsg-drugs:server:npcRehab', function(netId)
    local src = source
    local Officer = RSGCore.Functions.GetPlayer(src)
    if not Officer or not isRehabJob(Officer) then return end
    local ent; ent, netId = npcFromNet(src, netId, 4.0)
    local rec = netId and NpcAddicts[netId]
    if not ent or not rec then return end
    NpcAddicts[netId] = nil
    Entity(ent).state:set('rsgAddict', nil, true)
    -- no bonus for sending your own customers to rehab
    if rec.seller == Officer.PlayerData.citizenid then
        DrugsLog('security', 'Officer sent own customer to rehab', src, { { 'NPC net id', netId }, { 'Result', 'No bonus' } })
        return
    end
    DrugsLog('rehab', 'NPC sent to rehab', src, { { 'NPC net id', netId } })
    local now = os.time()
    local cd = Config.Addiction.Rehab.Reward and Config.Addiction.Rehab.Reward.NpcCooldown or 60
    if lastNpcReward[src] and now - lastNpcReward[src] < cd then return end
    lastNpcReward[src] = now
    payRehabReward(Officer)
end)

-- Selling weed bags to NPCs (netId = 0 when the ped isn't networked)
local lastSell = {}
lib.callback.register('rsg-drugs:server:sellWeedBag', function(src, netId)
    local S = Config.Addiction.Selling
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local now = os.time()
    if lastSell[src] and now - lastSell[src] < S.Cooldown then
        notify(src, locale('sell_cooldown'), 'error')
        return false
    end
    lastSell[src] = now
    if getData(Player).rehab > 0 then notify(src, locale('in_rehab_block'), 'error') return false end
    local ent; ent, netId = npcFromNet(src, netId, 4.0)
    if not ent and S.RequireNetworkedPed ~= false then notify(src, locale('sell_no_buyer'), 'error') return false end
    if netId and NpcRefused[netId] then notify(src, locale('sell_refused'), 'error') return 'refused' end
    if netId and NpcSold[netId] then
        if not NpcAddicts[netId] then notify(src, locale('sell_already'), 'error') return 'done' end
        local wait = (S.AddictRebuyMinutes or 5) * 60 - (os.time() - NpcSold[netId])
        if wait > 0 then notify(src, locale('sell_addict_wait', math.ceil(wait / 60)), 'error') return 'wait' end
    end
    local item = exports['rsg-inventory']:GetItemByName(src, S.Item)
    if not item or (item.amount or 0) < 1 then notify(src, locale('sell_no_item'), 'error') return false end

    local isAddict = netId and NpcAddicts[netId] ~= nil
    if isAddict or math.random(100) <= S.BuyChance then
        if not exports['rsg-inventory']:RemoveItem(src, S.Item, 1, item.slot, 'rsg-drugs-npc-sale') then return false end
        if netId then NpcSold[netId] = os.time() end
        local price = math.random(S.PriceMin, S.PriceMax)
        Player.Functions.AddMoney(S.MoneyType or 'cash', price, 'rsg-drugs-npc-sale')
        notify(src, locale('sell_success', price), 'success')
        DrugsLog('sales', 'Weed bag sold', src, { { 'Price', ('$%s (%s)'):format(price, S.MoneyType or 'cash') }, { 'Buyer', isAddict and 'Addict' or 'Ambient NPC' } })
        DrugsXP.Add(src, Config.XP.Sell[S.Item], 'sell')
        if not ent then return 'sold', nil end -- not networked: client decides the (visual-only) addiction
        if not isAddict and math.random(100) <= (Config.Addiction.NPC.SaleChance or 100) then
            NpcAddicts[netId] = { seller = Player.PlayerData.citizenid }
            Entity(ent).state:set('rsgAddict', 'weed', true)
            isAddict = true
        end
        return 'sold', isAddict
    end

    if netId then NpcRefused[netId] = true end
    notify(src, locale('sell_refused'), 'error')
    DrugsLog('sales', 'Sale refused - law alerted', src, { { 'Item', S.Item } })
    local c = GetEntityCoords(GetPlayerPed(src))
    local off = S.AlertOffset or 0.0
    local spot = vector3(c.x + math.random(-100, 100) / 100 * off, c.y + math.random(-100, 100) / 100 * off, c.z)
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(id)
        local job = P and P.PlayerData.job
        if job and job.onduty ~= false and (S.AlertJobTypes[job.type] or S.AlertJobs[job.name]) then
            TriggerClientEvent('rsg-drugs:client:sellAlert', id, spot)
        end
    end
    return 'refused'
end)

-- forget NPCs that despawned
CreateThread(function()
    while true do
        Wait(300000)
        for _, tbl in ipairs({ NpcAddicts, NpcRefused, NpcSold }) do
            for netId in pairs(tbl) do
                local ent = NetworkGetEntityFromNetworkId(netId)
                if not ent or ent == 0 or not DoesEntityExist(ent) then tbl[netId] = nil end
            end
        end
    end
end)

RegisterNetEvent('rsg-drugs:server:checkIn', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local ped = GetPlayerPed(src)
    local ci = Config.Addiction.Rehab.CheckIn
    if #(GetEntityCoords(ped) - vector3(ci.coords.x, ci.coords.y, ci.coords.z)) > (ci.interactDistance or 4.0) then
        DrugsLog('security', 'Rehab check-in out of range', src)
        return notify(src, locale('rehab_checkin_far'), 'error')
    end
    local d = getData(Player)
    if d.rehab > 0 then return notify(src, locale('rehab_already'), 'error') end
    if not hasAnyAddiction(d) then return notify(src, locale('rehab_checkin_none'), 'inform') end
    if startRehab(src, Config.Addiction.Rehab.VoluntaryMinutes) then
        DrugsLog('rehab', 'Voluntary rehab check-in', src, { { 'Minutes', Config.Addiction.Rehab.VoluntaryMinutes } })
    end
end)

-- Rehab timer + escape check (online players only, so time is actually served).
-- GetPlayer() returns a fresh copy across resources, so the countdown lives here and is
-- written back to metadata every 30s and when the player leaves.
local RehabLeft = {} -- [src] = seconds left
local RehabSaved = {} -- [src] = GetGameTimer() of last save
CreateThread(function()
    local step = 5
    while true do
        Wait(step * 1000)
        local now = GetGameTimer()
        for _, src in ipairs(RSGCore.Functions.GetPlayers()) do
            local Player = RSGCore.Functions.GetPlayer(src)
            if Player then
                local d = getData(Player)
                if d.rehab > 0 then
                    if (tonumber(d.rehabTotal) or 0) < d.rehab then d.rehabTotal = d.rehab; saveData(Player, d) end
                    RehabLeft[src] = math.min(RehabLeft[src] or d.rehab, d.rehab) - step
                    d.rehab = RehabLeft[src]
                    if d.rehab <= 0 then
                        RehabLeft[src], RehabSaved[src] = nil, nil
                        finishRehab(Player)
                    else
                        local coords = GetEntityCoords(GetPlayerPed(src))
                        if #(coords - Config.Addiction.Rehab.Centre) > Config.Addiction.Rehab.Radius then
                            TriggerClientEvent('rsg-drugs:client:teleport', src, Config.Addiction.Rehab.Spawns[1])
                            notify(src, locale('rehab_escape'), 'error')
                            DrugsLog('rehab', 'Rehab escape attempt', src, { { 'Time left', ('%d min'):format(math.ceil(d.rehab / 60)) } })
                        end
                        if now - (RehabSaved[src] or 0) >= 30000 then
                            RehabSaved[src] = now
                            saveData(Player, d)
                        end
                    end
                else
                    RehabLeft[src], RehabSaved[src] = nil, nil
                end
            end
        end
    end
end)

-- keep served time when the player logs out mid-stint
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local left = RehabLeft[src]
    local Player = left and RSGCore.Functions.GetPlayer(src)
    if Player then local d = getData(Player); d.rehab = math.max(1, left); saveData(Player, d) end
    RehabLeft[src], RehabSaved[src] = nil, nil
end)
AddEventHandler('playerDropped', function()
    local src = source
    local left = RehabLeft[src]
    local Player = left and RSGCore.Functions.GetPlayer(src)
    if Player then local d = getData(Player); d.rehab = math.max(1, left); saveData(Player, d) end
    RehabLeft[src], RehabSaved[src] = nil, nil
end)

---------------------------------------------------------------------
-- Addiction tick: craving grows while hooked; level decays while not hooked
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.Addiction.TickInterval * 1000)
        for _, src in ipairs(RSGCore.Functions.GetPlayers()) do
            local Player = RSGCore.Functions.GetPlayer(src)
            if Player then
                local d = getData(Player)
                if RehabLeft[src] then d.rehab = RehabLeft[src] end -- live countdown, not the last saved value
                local changed = false
                for key, sub in pairs(d.subs) do
                    local cfg = Config.Addiction.Substances[key]
                    if cfg then
                        if isHooked(key, sub) then
                            if d.rehab <= 0 and sub.craving < 100 then
                                sub.craving = clamp(sub.craving + cfg.cravingRate)
                                changed = true
                            end
                        elseif sub.level > 0 or sub.craving > 0 then
                            sub.level = clamp(sub.level - cfg.decay)
                            sub.craving = 0
                            changed = true
                        end
                    end
                end
                if changed then saveData(Player, d) end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Load / unload
---------------------------------------------------------------------
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    local d = getData(Player)
    saveData(Player, d)
    if d.rehab <= 0 and Player.PlayerData.metadata.rehabitems then
        SetTimeout(8000, function() -- after rsg-weapons restores its own loadout
            local P = RSGCore.Functions.GetPlayer(src)
            if P then returnBelongings(P) end
        end)
    end
    if d.rehab > 0 then
        SetTimeout(3000, function()
            TriggerClientEvent('rsg-drugs:client:teleport', src, Config.Addiction.Rehab.Spawns[math.random(#Config.Addiction.Rehab.Spawns)])
            notify(src, locale('rehab_left', math.ceil(d.rehab / 60)), 'warning')
        end)
    end
end)

AddEventHandler('playerDropped', function() lastUse[source] = nil; lastNpcReward[source] = nil; lastSell[source] = nil end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, src in ipairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then saveData(Player, getData(Player)) end
    end
end)

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
RSGCore.Commands.Add('addiction', locale('cmd_addiction'), {}, false, function(source)
    TriggerClientEvent('rsg-drugs:client:openUI', source)
end, 'user')

RSGCore.Commands.Add('rehab', locale('cmd_rehab'), {
    { name = 'id', help = locale('arg_id') }, { name = 'minutes', help = locale('arg_minutes') },
}, false, function(source, args)
    local src = source
    local Officer = RSGCore.Functions.GetPlayer(src)
    if not Officer then return end
    local ok, isAdmin = canAdmit(Officer)
    if not ok then return notify(src, locale('no_permission'), 'error') end
    local target = tonumber(args[1])
    local Target = target and RSGCore.Functions.GetPlayer(target)
    if not Target then return notify(src, locale('invalid_target'), 'error') end
    local td = getData(Target)
    if td.rehab > 0 then return notify(src, locale('rehab_already'), 'error') end
    if not isAdmin then
        -- lawmen/medics can only admit actual addicts (stops griefing and reward farming)
        if not hasAnyAddiction(td) then return notify(src, locale('rehab_not_addict'), 'error') end
        if target ~= src then
            local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target)))
            if dist > Config.Addiction.Rehab.MaxAdmitDistance then return notify(src, locale('addiction_too_far'), 'error') end
        end
    end
    local minutes = math.floor(tonumber(args[2]) or Config.Addiction.Rehab.DefaultMinutes)
    minutes = math.max(1, math.min(Config.Addiction.Rehab.MaxMinutes, minutes))
    if startRehab(target, minutes) then
        notify(src, locale('rehab_admitted_other', minutes), 'success')
        DrugsLog('rehab', 'Player admitted to rehab', src, { { 'Patient', ('%s (ID %s)'):format(GetPlayerName(target) or '?', target) }, { 'Patient CID', Target.PlayerData.citizenid }, { 'Minutes', minutes }, { 'By', isAdmin and 'Admin' or (Officer.PlayerData.job.label or Officer.PlayerData.job.name) } })
        if not isAdmin and target ~= src then payRehabReward(Officer) end
    end
end, 'user')

RSGCore.Commands.Add('clearaddiction', locale('cmd_clear'), {
    { name = 'id', help = locale('arg_id') },
}, true, function(source, args)
    local Target = RSGCore.Functions.GetPlayer(tonumber(args[1]) or -1)
    if not Target then return notify(source, locale('invalid_target'), 'error') end
    local wasInRehab = getData(Target).rehab > 0
    saveData(Target, defaultData())
    if wasInRehab then
        TriggerClientEvent('rsg-drugs:client:teleport', Target.PlayerData.source, Config.Addiction.Rehab.Release)
        SetTimeout(2500, function()
            local P = RSGCore.Functions.GetPlayer(Target.PlayerData.source)
            if P then returnBelongings(P) end
        end)
    end
    notify(source, locale('cleared'), 'success')
    DrugsLog('admin', '/clearaddiction', source, { { 'Target', ('%s (ID %s)'):format(GetPlayerName(Target.PlayerData.source) or '?', Target.PlayerData.source) }, { 'Target CID', Target.PlayerData.citizenid } })
end, Config.Addiction.Rehab.AdminPermission)

RSGCore.Commands.Add('setaddiction', locale('cmd_set'), {
    { name = 'id', help = locale('arg_id') }, { name = 'substance', help = locale('arg_substance') }, { name = 'level', help = locale('arg_level') },
}, true, function(source, args)
    local Target = RSGCore.Functions.GetPlayer(tonumber(args[1]) or -1)
    local key, level = args[2], tonumber(args[3])
    if not Target or not Config.Addiction.Substances[key] or not level then return notify(source, locale('invalid_target'), 'error') end
    local d = getData(Target)
    d.subs[key].level = clamp(level)
    saveData(Target, d)
    notify(source, locale('set_ok'), 'success')
    DrugsLog('admin', '/setaddiction', source, { { 'Target', ('%s (ID %s)'):format(GetPlayerName(Target.PlayerData.source) or '?', Target.PlayerData.source) }, { 'Target CID', Target.PlayerData.citizenid }, { 'Substance', key }, { 'Level', clamp(level) } })
end, Config.Addiction.Rehab.AdminPermission)
