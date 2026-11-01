lib.locale()

local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']

local PropsLoaded      = false
local ProcessingRockers = {} -- [propid] = citizenid of the player running it
local PendingOutputs   = {} -- [propid] = { cid = citizenid, gold = n, paydirt = n } (server-authoritative)
local Cooldowns        = {} -- [src] = { [key] = GetGameTimer() expiry }


---------------------------------------------
-- helpers
---------------------------------------------
local function Notify(src, title, description, nType, icon, duration)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = title,
        description = description,
        type        = nType or 'inform',
        icon        = icon,
        duration    = duration or Config.NotifyDuration,
        position    = Config.NotifyPosition,
    })
end

local function Debug(...)
    if Config.Debug then print('[rsg-goldclaim]', ...) end
end

--- returns true if the action is still on cooldown (and should be rejected)
local function OnCooldown(src, key, ms)
    Cooldowns[src] = Cooldowns[src] or {}
    local now = GetGameTimer()
    if (Cooldowns[src][key] or 0) > now then return true end
    Cooldowns[src][key] = now + ms
    return false
end

local function AddItem(src, item, amount, reason)
    if not Inventory:CanAddItem(src, item, amount) then
        Notify(src, locale('rocker_inventory_full'), nil, 'error', 'circle-xmark')
        return false
    end
    if Inventory:AddItem(src, item, amount, nil, nil, reason) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', amount)
        return true
    end
    return false
end

local function RemoveItem(src, item, amount, reason)
    if Inventory:RemoveItem(src, item, amount, nil, reason) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
        return true
    end
    return false
end

local function GetItemCount(Player, item)
    local count = 0
    for _, v in pairs(Player.PlayerData.items or {}) do
        if v and v.name == item then count = count + (v.amount or 0) end
    end
    return count
end

local function GetRockerPropById(propid)
    for i = 1, #Config.PlayerProps do
        if Config.PlayerProps[i].id == propid then
            return Config.PlayerProps[i], i
        end
    end
end

local function GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function IsNearCoords(src, coords, radius)
    local pos = GetPlayerCoords(src)
    return pos ~= nil and #(pos - coords) <= radius
end

local function IsNearProp(src, propData, radius)
    if not propData then return false end
    return IsNearCoords(src, vector3(propData.x, propData.y, propData.z), radius or Config.InteractDistance)
end

--- validates player + rocker + proximity; returns Player, propData
local function ValidateRockerAction(src, propid, radius)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    propid = tonumber(propid)
    if not propid then return end
    local propData = GetRockerPropById(propid)
    if not propData then return end
    if not IsNearProp(src, propData, radius) then
        Notify(src, locale('rocker_too_far'), nil, 'error', 'circle-xmark')
        local pos = GetPlayerCoords(src)
        local dist = pos and #(pos - vector3(propData.x, propData.y, propData.z)) or -1
        if dist > (radius or Config.InteractDistance) * 5 then -- way beyond any desync = likely exploit
            Webhook.Suspicious(src, locale('wh_reason_far_event'), {
                { locale('wh_event'), locale('wh_rocker_action') },
                { locale('wh_rocker_id'), propid }, { locale('wh_distance'), ('%.1fm'):format(dist) },
            })
        end
        return
    end
    return Player, propData, propid
end

-- oxmysql returns tinyint(1) as a boolean, normalise to 0/1
local function ToFlag(v)
    return (v == true or v == 1) and 1 or 0
end

local function RockerUpdateProps(target)
    TriggerClientEvent('rsg-goldclaim:rocker:client:updatePropData', target or -1, Config.PlayerProps)
end

--- removes a rocker from memory, the world and the database
local function RemoveRocker(propid)
    local _, index = GetRockerPropById(propid)
    if index then table.remove(Config.PlayerProps, index) end
    ProcessingRockers[propid] = nil
    PendingOutputs[propid] = nil
    TriggerClientEvent('rsg-goldclaim:rocker:client:removePropObject', -1, propid)
    MySQL.update('DELETE FROM player_goldrockers WHERE propid = ?', { propid })
end

local function LoadProps()
    Config.PlayerProps = {}
    local result = MySQL.query.await('SELECT properties, licensed, claimname FROM player_goldrockers')
    for i = 1, #(result or {}) do
        local propData = json.decode(result[i].properties)
        if propData then
            propData.licensed  = ToFlag(result[i].licensed)
            propData.claimname = result[i].claimname
            propData.hash      = Config.GoldRocker
            Config.PlayerProps[#Config.PlayerProps + 1] = propData
            Debug('loaded rocker', propData.id)
        end
    end
end

---------------------------------------------
-- startup
---------------------------------------------
CreateThread(function()
    LoadProps()
    PropsLoaded = true
    RockerUpdateProps()
end)

lib.callback.register('rsg-goldclaim:server:getprops', function()
    while not PropsLoaded do Wait(100) end
    return Config.PlayerProps
end)

--- unclaimed outputs for this character (so they survive a relog)
lib.callback.register('rsg-goldclaim:server:getpending', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end
    local cid, list = Player.PlayerData.citizenid, {}
    for propid, p in pairs(PendingOutputs) do
        if p.cid == cid then list[#list + 1] = { propid = propid, gold = p.gold, paydirt = p.paydirt } end
    end
    return list
end)

AddEventHandler('playerDropped', function()
    local src = source
    Cooldowns[src] = nil
end)

---------------------------------------------
-- useable items
---------------------------------------------
RSGCore.Functions.CreateUseableItem('tool_goldrocker', function(source)
    TriggerClientEvent('rsg-goldclaim:rocker:client:createprop', source)
end)

RSGCore.Functions.CreateUseableItem('tool_rocker_shovel', function(source)
    TriggerClientEvent('rsg-goldclaim:rocker:client:useshovel', source)
end)

RSGCore.Functions.CreateUseableItem('tool_rocker_bucket_empty', function(source)
    TriggerClientEvent('rsg-goldclaim:rocker:client:usebucket', source)
end)

---------------------------------------------
-- gathering: dig paydirt / fill bucket
---------------------------------------------
RegisterNetEvent('rsg-goldclaim:rocker:server:digpaydirt', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if OnCooldown(src, 'gather', Config.ShovelDigTime - 500) then return end
    if GetItemCount(Player, 'tool_rocker_shovel') < 1 then return end

    AddItem(src, 'resource_paydirt', 1, 'rsg-goldclaim:dig')
end)

RegisterNetEvent('rsg-goldclaim:rocker:server:fillbucket', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if OnCooldown(src, 'gather', Config.BucketFillTime - 500) then return end
    if GetItemCount(Player, 'tool_rocker_bucket_empty') < 1 then return end

    if RemoveItem(src, 'tool_rocker_bucket_empty', 1, 'rsg-goldclaim:fillbucket') then
        if not AddItem(src, 'tool_rocker_bucket_full', 1, 'rsg-goldclaim:fillbucket') then
            AddItem(src, 'tool_rocker_bucket_empty', 1, 'rsg-goldclaim:refund')
        end
    end
end)

---------------------------------------------
-- callbacks
---------------------------------------------
lib.callback.register('rsg-goldclaim:server:countprops', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return 0 end
    local cid, count = Player.PlayerData.citizenid, 0
    for _, v in pairs(Config.PlayerProps) do
        if v.builder == cid then count = count + 1 end
    end
    return count
end)

lib.callback.register('rsg-goldclaim:server:getrockerdata', function(source, propid)
    propid = tonumber(propid)
    local propData = propid and GetRockerPropById(propid)
    if not propData or not IsNearProp(source, propData, Config.ClaimZoneRadius) then return nil end
    local result = MySQL.single.await('SELECT propid, citizenid, owner, licensed, claimname, paydirt, water, quality FROM player_goldrockers WHERE propid = ?', { propid })
    if result then
        result.processing = ProcessingRockers[propid] ~= nil
        result.licensed = ToFlag(result.licensed)
    end
    return result
end)

---------------------------------------------
-- place a new rocker
---------------------------------------------
RegisterNetEvent('rsg-goldclaim:rocker:server:newProp', function(location, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if OnCooldown(src, 'place', 3000) then return end

    if type(location) ~= 'vector3' and (type(location) ~= 'table' or type(location.x) ~= 'number') then return end
    location = vector3(location.x + 0.0, location.y + 0.0, location.z + 0.0)
    heading = (tonumber(heading) or 0.0) % 360.0

    if not IsNearCoords(src, location, Config.PlaceMaxDistance) then
        Notify(src, locale('rocker_too_far'), nil, 'error', 'circle-xmark')
        Webhook.Suspicious(src, locale('wh_reason_far_place'), {
            { locale('wh_requested_coords'), ('%.2f, %.2f, %.2f'):format(location.x, location.y, location.z) },
        })
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local count = 0
    for _, v in pairs(Config.PlayerProps) do
        if v.builder == citizenid then count = count + 1 end
        if #(location - vector3(v.x, v.y, v.z)) < Config.MinRockerSpacing then
            Notify(src, locale('rocker_too_close_other'), nil, 'error', 'circle-xmark')
            return
        end
    end
    if count >= Config.MaxGoldRockers then
        Notify(src, locale('rocker_max_equipment'), nil, 'error', 'circle-xmark')
        return
    end

    if not RemoveItem(src, 'tool_goldrocker', 1, 'rsg-goldclaim:place') then return end

    local charinfo = Player.PlayerData.charinfo
    local owner = ('%s %s'):format(charinfo.firstname, charinfo.lastname)
    local licensed, claimname = 0, nil

    if GetItemCount(Player, Config.LicenseItem) > 0 and RemoveItem(src, Config.LicenseItem, 1, 'rsg-goldclaim:license') then
        licensed = 1
        claimname = locale('rocker_claim_default_name', owner)
    end

    local propId
    repeat propId = math.random(111111, 999999) until not GetRockerPropById(propId)

    local PropData = {
        id        = propId,
        proptype  = 'tool_goldrocker',
        x         = location.x,
        y         = location.y,
        z         = location.z,
        h         = heading,
        hash      = Config.GoldRocker,
        builder   = citizenid,
        buildtime = os.time(),
        licensed  = licensed,
        claimname = claimname,
    }

    Config.PlayerProps[#Config.PlayerProps + 1] = PropData
    MySQL.insert('INSERT INTO player_goldrockers (properties, propid, citizenid, owner, proptype, licensed, claimname) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        json.encode(PropData), propId, citizenid, owner, 'tool_goldrocker', licensed, claimname,
    })
    RockerUpdateProps()

    local coordsText = ('%.2f, %.2f, %.2f'):format(location.x, location.y, location.z)
    Webhook.Log('rocker_placed', src, locale('wh_title_placed'), {
        { locale('wh_rocker_id'), propId }, { locale('wh_licensed'), licensed == 1 and locale('wh_yes') or locale('wh_no') },
        { locale('wh_claim_name'), claimname or locale('wh_na') }, { locale('wh_rocker_coords'), coordsText },
        { locale('wh_rockers_owned'), ('%s/%s'):format(count + 1, Config.MaxGoldRockers) },
    })
    if licensed == 0 then
        Webhook.Log('illegal_placed', src, locale('wh_title_illegal_placed'), {
            { locale('wh_rocker_id'), propId }, { locale('wh_rocker_coords'), coordsText },
        })
        Notify(src, locale('rocker_unlicensed_notice_title'), locale('rocker_unlicensed_notice_desc'), 'warning', 'triangle-exclamation', 10000)
    end
end)

---------------------------------------------
-- pack up (owner only, returns the rocker)
---------------------------------------------
RegisterNetEvent('rsg-goldclaim:rocker:server:destroyProp', function(propid)
    local src = source
    local Player, propData
    Player, propData, propid = ValidateRockerAction(src, propid)
    if not Player then return end
    if propData.builder ~= Player.PlayerData.citizenid then return end

    if OnCooldown(src, 'packup', 2000) then return end

    local row = MySQL.single.await('SELECT quality FROM player_goldrockers WHERE propid = ?', { propid })
    -- re-check after the await: a second request could have removed it meanwhile (item dupe)
    if not GetRockerPropById(propid) then return end
    if not row or row.quality < 100 then
        Notify(src, locale('rocker_needs_repair'), nil, 'error', 'circle-xmark')
        return
    end
    if not Inventory:CanAddItem(src, 'tool_goldrocker', 1) then
        Notify(src, locale('rocker_inventory_full'), nil, 'error', 'circle-xmark')
        return
    end

    RemoveRocker(propid)
    AddItem(src, 'tool_goldrocker', 1, 'rsg-goldclaim:packup')
    Webhook.Log('rocker_packed', src, locale('wh_title_packed'), {
        { locale('wh_rocker_id'), propid }, { locale('wh_claim_name'), propData.claimname or locale('wh_na') },
    })
    Notify(src, locale('rocker_packed_up'), nil, 'success', 'circle-check')
end)

---------------------------------------------
-- LEO destroy illegal claim (confiscate as evidence)
---------------------------------------------
RegisterNetEvent('rsg-goldclaim:rocker:server:leodestroy', function(propid)
    local src = source
    local Player, propData
    Player, propData, propid = ValidateRockerAction(src, propid)
    if not Player then return end

    local job = Player.PlayerData.job
    if not job or job.type ~= Config.LeoJobType then
        Webhook.Suspicious(src, locale('wh_reason_non_leo'), { { locale('wh_rocker_id'), propid }, { locale('wh_job'), job and job.name or locale('wh_none') } })
        return
    end
    if propData.licensed == 1 then return end

    RemoveRocker(propid)
    AddItem(src, 'tool_goldrocker', 1, 'rsg-goldclaim:confiscate')
    Webhook.Log('leo_destroyed', src, locale('wh_title_leo_destroyed'), {
        { locale('wh_rocker_id'), propid }, { locale('wh_owner_citizenid'), propData.builder },
        { locale('wh_officer_job'), ('%s (%s)'):format(job.label or job.name, job.grade and job.grade.name or '?') },
    })
    Notify(src, locale('rocker_claim_destroyed'), locale('rocker_evidence_collected'), 'success', 'circle-check')
end)

---------------------------------------------
-- add paydirt / water
---------------------------------------------
local function AddResource(src, propid, column, max, item, fullMsg, okMsg, returnItem, actionTime)
    local Player, _
    Player, _, propid = ValidateRockerAction(src, propid)
    if not Player then return end
    if OnCooldown(src, 'load', actionTime - 1000) then return end -- matches the client action time
    if GetItemCount(Player, item) < 1 then return end

    local row = MySQL.single.await(('SELECT %s AS amount FROM player_goldrockers WHERE propid = ?'):format(column), { propid })
    if not row then return end
    if row.amount >= max then
        Notify(src, locale(fullMsg), nil, 'error', 'circle-xmark')
        return
    end

    if not RemoveItem(src, item, 1, 'rsg-goldclaim:load') then return end
    -- conditional atomic increment: if another player filled it meanwhile, refund instead of losing the item
    local affected = MySQL.update.await(('UPDATE player_goldrockers SET %s = %s + 1 WHERE propid = ? AND %s < ?'):format(column, column, column), { propid, max })
    if not affected or affected < 1 then
        AddItem(src, item, 1, 'rsg-goldclaim:refund')
        Notify(src, locale(fullMsg), nil, 'error', 'circle-xmark')
        return
    end
    if returnItem then AddItem(src, returnItem, 1, 'rsg-goldclaim:load') end
    Notify(src, locale(okMsg), locale('rocker_level', math.min(row.amount + 1, max), max), 'success', 'circle-check', 3000)
end

RegisterNetEvent('rsg-goldclaim:rocker:server:addpaydirt', function(propid)
    AddResource(source, propid, 'paydirt', Config.MaxPaydirt, 'resource_paydirt', 'rocker_paydirt_full', 'rocker_paydirt_added', nil, Config.AddPaydirtTime)
end)

RegisterNetEvent('rsg-goldclaim:rocker:server:addwater', function(propid)
    AddResource(source, propid, 'water', Config.MaxWater, 'tool_rocker_bucket_full', 'rocker_water_full', 'rocker_water_added', 'tool_rocker_bucket_empty', Config.AddWaterTime)
end)

---------------------------------------------
-- process rocker (server-driven, one cycle per Config.ProcessingTime)
---------------------------------------------
RegisterNetEvent('rsg-goldclaim:rocker:server:processrocker', function(propid)
    local src = source
    local Player, propData
    Player, propData, propid = ValidateRockerAction(src, propid)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    if Config.OwnerOnlyProcessing and propData.builder ~= cid then
        Notify(src, locale('rocker_not_owner'), nil, 'error', 'circle-xmark')
        return
    end
    if ProcessingRockers[propid] then
        Notify(src, locale('rocker_already_processing_title'), locale('rocker_already_processing_desc'), 'error', 'circle-xmark')
        return
    end

    -- lock before the await so two rapid requests can't start two parallel processing loops
    ProcessingRockers[propid] = cid
    local row = MySQL.single.await('SELECT water, paydirt, quality FROM player_goldrockers WHERE propid = ?', { propid })
    local fail
    if not row or not GetRockerPropById(propid) then fail = true
    elseif row.quality <= 0 then fail = 'rocker_needs_repair'
    elseif row.water <= 0 then fail = 'rocker_processing_no_water'
    elseif row.paydirt <= 0 then fail = 'rocker_processing_no_paydirt' end
    if fail then
        ProcessingRockers[propid] = nil
        if fail ~= true then Notify(src, locale(fail), nil, 'error', 'circle-xmark') end
        return
    end
    Notify(src, locale('rocker_processing_started'), locale('rocker_processing_will_run', math.min(row.water, row.paydirt)), 'inform', 'coins')
    Webhook.Log('processing_started', src, locale('wh_title_processing'), {
        { locale('wh_rocker_id'), propid }, { locale('wh_cycles'), math.min(row.water, row.paydirt) },
        { locale('wh_water_paydirt'), ('%s / %s'):format(row.water, row.paydirt) }, { locale('wh_condition'), row.quality .. '%' },
    })

    CreateThread(function()
        while true do
            Wait(Config.ProcessingTime)

            -- stop if the rocker was removed or the player left / switched character
            -- (checked before consuming, so nothing is lost when a cycle is interrupted)
            local p = RSGCore.Functions.GetPlayer(src)
            if not GetRockerPropById(propid) or not p or p.PlayerData.citizenid ~= cid then break end

            -- consume one unit of each atomically; abort if either ran out or the rocker broke
            local affected = MySQL.update.await('UPDATE player_goldrockers SET water = water - 1, paydirt = paydirt - 1 WHERE propid = ? AND water > 0 AND paydirt > 0 AND quality > 0', { propid })
            if not affected or affected < 1 then break end

            local resultType = math.random(1, 100) <= Config.GoldChance and 'gold' or 'paydirt'
            local pending = PendingOutputs[propid]
            if not pending or pending.cid ~= cid then
                pending = { cid = cid, gold = 0, paydirt = 0 }
                PendingOutputs[propid] = pending
            end
            pending[resultType] = pending[resultType] + 1
            TriggerClientEvent('rsg-goldclaim:rocker:client:spawnoutputprop', src, propid, resultType)
        end

        ProcessingRockers[propid] = nil
        if GetPlayerPed(src) ~= 0 then
            TriggerClientEvent('rsg-goldclaim:rocker:client:processingcomplete', src, propid)
        end
    end)
end)

---------------------------------------------
-- pick up outputs (only honoured if the server produced them for this player)
---------------------------------------------
local function ConsumePending(src, propid, resultType)
    local Player, _
    Player, _, propid = ValidateRockerAction(src, propid, Config.PickupDistance)
    if not Player then return end
    local pending = PendingOutputs[propid]
    if not pending or pending.cid ~= Player.PlayerData.citizenid or pending[resultType] < 1 then return end
    pending[resultType] = pending[resultType] - 1
    return Player, propid, pending
end

RegisterNetEvent('rsg-goldclaim:rocker:server:pickupgold', function(propid)
    local src = source
    local Player, pending
    Player, propid, pending = ConsumePending(src, propid, 'gold')
    if not Player then return end

    local ore = Config.GoldOreItem
    local amount = math.random(Config.GoldOreAmount.min, Config.GoldOreAmount.max)

    if AddItem(src, ore, amount, 'rsg-goldclaim:pickupgold') then
        TriggerClientEvent('rsg-goldclaim:rocker:client:goldpickupresult', src, amount)
        Webhook.Log('gold_pickup', src, locale('wh_title_gold'), {
            { locale('wh_rocker_id'), propid }, { locale('wh_item'), RSGCore.Shared.Items[ore].label }, { locale('wh_amount'), amount },
        })
    else
        pending.gold = pending.gold + 1 -- inventory full: keep it claimable and respawn the prop
        TriggerClientEvent('rsg-goldclaim:rocker:client:spawnoutputprop', src, propid, 'gold', true)
    end
end)

RegisterNetEvent('rsg-goldclaim:rocker:server:pickuppaydirt', function(propid)
    local src = source
    local Player, pending
    Player, propid, pending = ConsumePending(src, propid, 'paydirt')
    if not Player then return end
    if not AddItem(src, 'resource_paydirt', 1, 'rsg-goldclaim:pickuppaydirt') then
        pending.paydirt = pending.paydirt + 1
        TriggerClientEvent('rsg-goldclaim:rocker:client:spawnoutputprop', src, propid, 'paydirt', true)
        return
    end
    Webhook.Log('paydirt_pickup', src, locale('wh_title_paydirt'), { { locale('wh_rocker_id'), propid } })
end)

---------------------------------------------
-- repair rocker
---------------------------------------------
RegisterNetEvent('rsg-goldclaim:rocker:server:repairrocker', function(propid)
    local src = source
    local Player, _
    Player, _, propid = ValidateRockerAction(src, propid)
    if not Player then return end
    if OnCooldown(src, 'repair', Config.RepairTime - 1000) then return end

    local row = MySQL.single.await('SELECT quality FROM player_goldrockers WHERE propid = ?', { propid })
    if not row or row.quality >= 100 then return end
    if GetItemCount(Player, 'resource_wood') < Config.RepairWoodAmount then
        Notify(src, locale('rocker_not_enough_wood', Config.RepairWoodAmount), nil, 'error', 'circle-xmark')
        return
    end

    if RemoveItem(src, 'resource_wood', Config.RepairWoodAmount, 'rsg-goldclaim:repair') then
        MySQL.update('UPDATE player_goldrockers SET quality = 100 WHERE propid = ?', { propid })
        Notify(src, locale('rocker_repaired'), nil, 'success', 'circle-check')
    end
end)

---------------------------------------------
-- rename claim (licensed owner only)
---------------------------------------------
RegisterNetEvent('rsg-goldclaim:rocker:server:renameclaim', function(propid, newname)
    local src = source
    local Player, propData
    Player, propData, propid = ValidateRockerAction(src, propid, Config.ClaimZoneRadius)
    if not Player then return end
    if propData.builder ~= Player.PlayerData.citizenid or propData.licensed ~= 1 then return end
    if OnCooldown(src, 'rename', 5000) then return end

    if type(newname) ~= 'string' then return end
    newname = newname:gsub('[%c<>]', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if #newname < 3 or #newname > Config.MaxClaimNameLength then
        Notify(src, locale('rocker_rename_invalid', Config.MaxClaimNameLength), nil, 'error', 'circle-xmark')
        return
    end

    MySQL.update('UPDATE player_goldrockers SET claimname = ? WHERE propid = ?', { newname, propid })
    Webhook.Log('claim_renamed', src, locale('wh_title_renamed'), {
        { locale('wh_rocker_id'), propid }, { locale('wh_old_name'), propData.claimname or locale('wh_na') }, { locale('wh_new_name'), newname },
    })
    propData.claimname = newname
    TriggerClientEvent('rsg-goldclaim:rocker:client:refreshclaim', -1, propid, newname)
    Notify(src, locale('rocker_claim_renamed'), newname, 'success', 'circle-check')
end)

---------------------------------------------
-- equipment degradation cron
---------------------------------------------
lib.cron.new(Config.CronJob, function()
    -- remove broken rockers first (they had a full cycle at 0% to be repaired)
    local broken = MySQL.query.await('SELECT propid, owner, citizenid FROM player_goldrockers WHERE quality <= 0') or {}
    for i = 1, #broken do
        local row = broken[i]
        RemoveRocker(row.propid)
        Webhook.Log('rocker_lost', nil, locale('wh_title_lost'), {
            { locale('wh_rocker_id'), row.propid }, { locale('wh_owner'), row.owner }, { locale('wh_citizenid'), row.citizenid },
        }, { description = locale('wh_lost_desc') })
    end

    -- independent roll per rocker, done in a single query
    MySQL.update('UPDATE player_goldrockers SET quality = quality - 1 WHERE quality > 0 AND RAND() * 100 < ?', { Config.DegradeChance })

    if #broken > 0 then RockerUpdateProps() end
    Debug('degradation cron ran')
end)
