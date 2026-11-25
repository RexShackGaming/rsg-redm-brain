local RSGCore = exports['rsg-core']:GetCoreObject()

local Callback = DrugsCallback -- server/utils.lua

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

-- server-side copy of who is clean / in rehab. The loops below use it instead of the replicated statebag, which
-- a modified client can overwrite on its own player to hide its addiction and skip the craving tick.
local Flags = {} -- [src] = { active = anything above 0, rehab = in rehab }

local function setFlags(src, d)
    local active = (tonumber(d.rehab) or 0) > 0
    if not active then
        for _, sub in pairs(d.subs) do
            if (tonumber(sub.level) or 0) > 0 or (tonumber(sub.craving) or 0) > 0 then active = true break end
        end
    end
    Flags[src] = { active = active, rehab = (tonumber(d.rehab) or 0) > 0 }
end

local function saveData(P, d)
    setFlags(P.PlayerData.source, d)
    P.Functions.SetMetaData('addiction', d)
    StateOf(P.PlayerData.source).state:set('addiction', d, true)
end

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('addiction_title'), description = desc, type = ntype or 'inform', duration = 5000 })
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
                local relief = (cfg.boost and cfg.boost.stressRelief) or cfg.stressRelief
                if relief and relief > 0 and GetResourceState('rsg-hud') == 'started' then
                    exports['rsg-hud']:RelieveStress(src, relief)
                end
            end)
        else
            hookedItem[itemName] = key
        end
    end
end

-- Hook for items consumed by rsg-consume (3.3.0+): rsg-consume fires this on the server once the item was
-- really consumed, so there is no client relay to spoof. Feeding only resets craving and RAISES addiction.
AddEventHandler('rsg-consume:server:consumed', function(src, itemName)
    if type(src) ~= 'number' or type(itemName) ~= 'string' then return end
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
    local items = {}
    for _, it in pairs(Player.PlayerData.items or {}) do items[#items + 1] = it end
    -- write the stash FIRST: if the server dies half way, the player still has a record of what was taken
    local pending, base = {}, #stash.items
    for _, it in ipairs(items) do
        if it and it.name and not (Conf.KeepItems or {})[it.name] and (it.amount or 0) > 0 then
            pending[#pending + 1] = { name = it.name, amount = it.amount, info = it.info, slot = it.slot }
        end
    end
    for _, e in ipairs(pending) do stash.items[#stash.items + 1] = e end
    Player.Functions.SetMetaData('rehabitems', stash)
    local taken, failed = 0, false
    for _, e in ipairs(pending) do
        if exports['rsg-inventory']:RemoveItem(src, e.name, e.amount, e.slot, 'rsg-drugs-rehab-confiscate') then
            taken = taken + e.amount
        else
            e.failed, failed = true, true
        end
    end
    if failed then -- whatever stayed in the inventory is not in the stash
        local keep = {}
        for i, e in ipairs(stash.items) do if i <= base or not e.failed then keep[#keep + 1] = e end end
        stash.items = keep
        Player.Functions.SetMetaData('rehabitems', stash)
    end
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
local lastAdmitReward = {} -- [src] = os.time() of the last bonus for admitting a player
local function payRehabReward(Officer)
    local r = Config.Addiction.Rehab.Reward
    if not r or not r.Enabled or (r.Amount or 0) <= 0 then return end
    Officer.Functions.AddMoney(r.MoneyType or 'cash', r.Amount, 'rehab-admission-bonus')
    DrugsLog('rehab', 'Rehab bonus paid', Officer.PlayerData.source, { { 'Amount', ('$%s (%s)'):format(r.Amount, r.MoneyType or 'cash') } })
    notify(Officer.PlayerData.source, locale('rehab_reward', r.Amount), 'success')
    DrugsRep.Apply(Officer.PlayerData.source, 'rehab')
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

---------------------------------------------------------------------
-- Helpers for server/corner.lua (corner selling). They keep the NPC state above private to this file.
---------------------------------------------------------------------
DrugsNpc = {}

-- the networked ambient ped for a net id, if it is within maxDist of the player
function DrugsNpc.FromNet(src, netId, maxDist) return npcFromNet(src, netId, maxDist) end

-- can this NPC be sold to? 'ok' | 'refused' | 'done' (bought already) | 'wait' (a regular who isn't ready yet), minutes
function DrugsNpc.Status(netId)
    if NpcRefused[netId] then return 'refused' end
    if NpcSold[netId] then
        if not NpcAddicts[netId] then return 'done' end
        local wait = (Config.Corner.AddictRebuyMinutes or 5) * 60 - (os.time() - NpcSold[netId])
        if wait > 0 then return 'wait', math.ceil(wait / 60) end
    end
    return 'ok'
end

-- this NPC won't deal again (it reported the player)
function DrugsNpc.Refused(netId) NpcRefused[netId] = true end

-- call after a real sale. canHook = this product can get the buyer hooked. Returns true when the buyer is an addict now.
-- is this ped part of the game's ambient population (not something a client spawned itself)? Checked on the server
-- with GetEntityPopulationType against Config.Addiction.NPC.AmbientPopTypes. When that is false/nil the check is off.
function DrugsNpc.IsAmbient(ent)
    local types = Config.Addiction.NPC.AmbientPopTypes
    if not types then return true end
    local ok, pt = pcall(GetEntityPopulationType, ent)
    if Config.Corner.Approach.Debug then print(('^3[rsg-drugs corner]^7 buyer population type: %s'):format(tostring(ok and pt or 'n/a'))) end
    if not ok or type(pt) ~= 'number' then return true end
    return types[pt] == true
end

function DrugsNpc.Sold(Player, ent, netId, canHook)
    NpcSold[netId] = os.time()
    if NpcAddicts[netId] then return true end
    if canHook and DrugsNpc.IsAmbient(ent) and math.random(100) <= (Config.Addiction.NPC.SaleChance or 100) then
        NpcAddicts[netId] = { seller = Player.PlayerData.citizenid }
        Entity(ent).state:set('rsgAddict', 'weed', true)
        return true
    end
    return false
end

-- true while the player is serving a rehab stint
function DrugsInRehab(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player ~= nil and getData(Player).rehab > 0
end

-- a buyer reported the player: on-duty law gets a notification and a pulsing hotspot near (not exactly at) the spot
function DrugsAlertLaw(src, exact)
    local A = Config.Corner.Alert
    local c = GetEntityCoords(GetPlayerPed(src))
    local off = exact and 0.0 or (A.Offset or 0.0)
    local spot = vector3(c.x + math.random(-100, 100) / 100 * off, c.y + math.random(-100, 100) / 100 * off, c.z)
    for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(id)
        local job = P and P.PlayerData.job
        if job and job.onduty ~= false and (A.JobTypes[job.type] or A.Jobs[job.name]) then
            TriggerClientEvent('rsg-drugs:client:sellAlert', id, spot, exact and (A.ExactRadius or 15.0) or nil)
        end
    end
end

-- net ids get reused: forget an NPC the moment it is removed so a new ped can't inherit its state
AddEventHandler('entityRemoved', function(entity)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId <= 0 then return end
    NpcAddicts[netId], NpcRefused[netId], NpcSold[netId] = nil, nil, nil
end)

-- safety sweep for NPCs that despawned without the event above
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
            -- cheap pre-check from our own flags: only copy the full player object for people in rehab
            local f = Flags[src]
            local active = RehabLeft[src] or not f or f.rehab
            local Player = active and RSGCore.Functions.GetPlayer(src)
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
local function saveRehabProgress(src)
    local left = RehabLeft[src]
    local Player = left and RSGCore.Functions.GetPlayer(src)
    if Player then local d = getData(Player); d.rehab = math.max(1, left); saveData(Player, d) end
    RehabLeft[src], RehabSaved[src] = nil, nil
end
AddEventHandler('RSGCore:Server:OnPlayerUnload', saveRehabProgress)

---------------------------------------------------------------------
-- Addiction tick: craving grows while hooked; level decays while not hooked
---------------------------------------------------------------------
-- withdrawal stress: the highest stage across substances (same rule as the client effects) adds its stress through
-- rsg-hud once per tick, scaled so it matches the old once-per-EffectInterval rate
local function withdrawalStress(src, d)
    if GetResourceState('rsg-hud') ~= 'started' then return end
    local best = 0
    for key, sub in pairs(d.subs) do
        local cfg = Config.Addiction.Substances[key]
        if cfg and isHooked(key, sub) then
            for i = #Config.Addiction.Stages, 1, -1 do
                if (sub.craving or 0) >= Config.Addiction.Stages[i].craving then best = math.max(best, i) break end
            end
        end
    end
    if best > 1 and d.rehab > 0 then best = 1 end -- supervised detox keeps it mild
    local stage = Config.Addiction.Stages[best]
    if not stage or (stage.stress or 0) <= 0 then return end
    local per = math.max(1, math.floor(Config.Addiction.TickInterval * 1000 / Config.Addiction.EffectInterval))
    pcall(function() exports['rsg-hud']:GainStress(src, stage.stress * per) end)
end

CreateThread(function()
    while true do
        Wait(Config.Addiction.TickInterval * 1000)
        for _, src in ipairs(RSGCore.Functions.GetPlayers()) do
            -- skip clean players (no full player copy needed)
            local f = Flags[src]
            local idle = f and not f.active and not RehabLeft[src]
            local Player = not idle and RSGCore.Functions.GetPlayer(src)
            if Player then
                local d = getData(Player)
                if RehabLeft[src] then d.rehab = RehabLeft[src] end -- live countdown, not the last saved value
                withdrawalStress(src, d) -- decided here, not by the client
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

AddEventHandler('playerDropped', function()
    local src = source
    saveRehabProgress(src)
    lastUse[src], lastNpcReward[src], lastAdmitReward[src], Flags[src] = nil, nil, nil, nil
end)

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
        if not isAdmin and target ~= src then
            -- one bonus per cooldown per officer: stops two friends farming each other through rehab
            local now = os.time()
            local cd = Config.Addiction.Rehab.Reward and Config.Addiction.Rehab.Reward.PlayerCooldown or 300
            if not lastAdmitReward[src] or now - lastAdmitReward[src] >= cd then
                lastAdmitReward[src] = now
                payRehabReward(Officer)
            else
                DrugsLog('security', 'Rehab bonus on cooldown', src, { { 'Patient CID', Target.PlayerData.citizenid } })
            end
        end
    end
end, 'user')

RSGCore.Commands.Add('clearaddiction', locale('cmd_clear'), {
    { name = 'id', help = locale('arg_id') },
}, true, function(source, args)
    local Target = RSGCore.Functions.GetPlayer(tonumber(args[1]) or -1)
    if not Target then return notify(source, locale('invalid_target'), 'error') end
    local wasInRehab = getData(Target).rehab > 0
    RehabLeft[Target.PlayerData.source], RehabSaved[Target.PlayerData.source] = nil, nil
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
    if not Target or not Config.Addiction.Substances[key] or not level or level ~= level then return notify(source, locale('invalid_target'), 'error') end
    local d = getData(Target)
    d.subs[key].level = clamp(level)
    saveData(Target, d)
    notify(source, locale('set_ok'), 'success')
    DrugsLog('admin', '/setaddiction', source, { { 'Target', ('%s (ID %s)'):format(GetPlayerName(Target.PlayerData.source) or '?', Target.PlayerData.source) }, { 'Target CID', Target.PlayerData.citizenid }, { 'Substance', key }, { 'Level', clamp(level) } })
end, Config.Addiction.Rehab.AdminPermission)
