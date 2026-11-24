local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------
-- helpers
------------------------------------------
local function notify(src, title, description, ntype, duration)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = ntype or 'inform',
        duration = duration or 5000,
    })
end

-- Returns the Player when `src` is a law officer (and on duty, unless needDuty == false).
-- Tells the player why when it fails, so every caller behaves the same.
local function getLawman(src, needDuty)
    if type(src) ~= 'number' or src <= 0 then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local job = Player.PlayerData.job
    if job.type ~= 'leo' then
        notify(src, locale('cl_only_law'), nil, 'error')
        return nil
    end
    if needDuty ~= false and Config.RequireOnDuty and not job.onduty then
        notify(src, locale('sv_need_duty'), nil, 'error')
        return nil
    end
    return Player
end

-- Validates a target id sent by a client and (optionally) that it is close to `src`.
local function getTarget(src, targetId, maxDistance)
    local n = tonumber(targetId)
    local id = n and math.tointeger(n)
    if not id or id <= 0 or id == src then return nil end
    local Target = RSGCore.Functions.GetPlayer(id)
    if not Target then return nil end
    if maxDistance and maxDistance > 0 then
        local a = GetEntityCoords(GetPlayerPed(src))
        local b = GetEntityCoords(GetPlayerPed(id))
        if #(a - b) > maxDistance then
            notify(src, locale('sv_too_far'), nil, 'error')
            return nil
        end
    end
    return Target
end

-- true when the player stands near a law office of their own job
local function isAtOwnOffice(src, jobname)
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, office in ipairs(Config.LawOfficeLocations) do
        if office.jobaccess == jobname and #(coords - office.coords) <= 6.0 then
            return true
        end
    end
    return false
end

local function clearRestraints(Player)
    Player.Functions.SetMetaData('ishandcuffed', false)
    Player.Functions.SetMetaData('isescorted', false)
end

------------------------------------------
-- discord log (Config.Discord): lawLog('Title', lawmanSrc, { { 'Label', value }, ... })
------------------------------------------
local logQueue, logWaitUntil = {}, 0

local function lawLog(title, src, fields)
    local D = Config.Discord
    if not D or not D.Enabled or type(D.Webhook) ~= 'string' or D.Webhook == '' then return end
    local out = {}
    local Player = src and RSGCore.Functions.GetPlayer(src)
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        out[1] = { name = 'Lawman', value = (('%s %s (%s)'):format(ci.firstname or '', ci.lastname or '', Player.PlayerData.citizenid)):sub(1, 1024), inline = true }
    end
    for _, f in ipairs(fields or {}) do
        if #out >= 20 then break end
        out[#out + 1] = { name = tostring(f[1]):sub(1, 256), value = tostring(f[2] == nil and '-' or f[2]):sub(1, 1024), inline = true }
    end
    if #logQueue >= 50 then table.remove(logQueue, 1) end -- never grow unbounded if Discord is down
    logQueue[#logQueue + 1] = {
        title = tostring(title):sub(1, 256),
        color = D.Color or 9807270,
        fields = out,
        footer = { text = 'rsg-lawman' },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
end

CreateThread(function()
    while true do
        Wait(3000)
        local D = Config.Discord
        if D and D.Enabled and type(D.Webhook) == 'string' and D.Webhook ~= '' and #logQueue > 0 and GetGameTimer() >= logWaitUntil then
            local batch = {}
            for i = 1, math.min(10, #logQueue) do batch[i] = table.remove(logQueue, 1) end
            PerformHttpRequest(D.Webhook, function(status, resp)
                if status == 429 then
                    local ok, data = pcall(json.decode, resp or '')
                    local retry = (ok and type(data) == 'table' and tonumber(data.retry_after)) or 5
                    logWaitUntil = GetGameTimer() + math.ceil(retry * 1000) + 250
                    for i = #batch, 1, -1 do table.insert(logQueue, 1, batch[i]) end
                elseif status < 200 or status >= 300 then
                    print(('^1[rsg-lawman] Discord webhook failed (HTTP %s). Check Config.Discord.Webhook.^7'):format(status))
                end
            end, 'POST', json.encode({ username = D.Username, avatar_url = (D.Avatar ~= '' and D.Avatar) or nil, embeds = batch }), { ['Content-Type'] = 'application/json' })
        end
    end
end)

------------------------------------------
-- lawman alerts (shared by the net event, /testalert and the SendAlert export)
------------------------------------------
local ALERT_MAX_TEXT = 150   -- characters
local ALERT_MAX_DIST = 250.0 -- a client-sent alert position may not be further than this from the sender

local function broadcastAlert(coords, text, alertType)
    if not Config.AlertTypes[alertType] then alertType = 'default' end
    for _, v in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            TriggerClientEvent('rsg-lawman:client:lawmanAlert', v.PlayerData.source, coords, text, alertType)
        end
    end
end

-- server-side API for other resources: exports['rsg-lawman']:SendAlert(coords, text, alertType?)
exports('SendAlert', function(coords, text, alertType)
    if type(text) ~= 'string' or text == '' then return false end
    if type(coords) ~= 'vector3' then return false end
    broadcastAlert(coords, text:sub(1, ALERT_MAX_TEXT), alertType)
    return true
end)

local alertLast = {} -- [src] = GetGameTimer() of the last accepted alert
local ALERT_MIN_GAP = 4000

RegisterNetEvent('rsg-lawman:server:lawmanAlert', function(text, coords, alertType)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end

    -- the client supplies the text and position, so never trust them as sent
    if type(text) ~= 'string' then return end
    text = text:gsub('%c', ''):sub(1, ALERT_MAX_TEXT)
    if text == '' then return end

    local now = GetGameTimer()
    if alertLast[src] and now - alertLast[src] < ALERT_MIN_GAP then return end
    alertLast[src] = now

    local pedcoords = GetEntityCoords(GetPlayerPed(src))
    local alertCoords = pedcoords
    if type(coords) == 'vector3' then
        alertCoords = coords
    elseif type(coords) == 'table' and type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number' then
        alertCoords = vector3(coords.x, coords.y, coords.z)
    end
    if #(alertCoords - pedcoords) > ALERT_MAX_DIST then alertCoords = pedcoords end

    -- only the automatic client alert types may be chosen by a client; 'report' is reserved for /911
    if alertType ~= 'gunshot' and alertType ~= 'death' then alertType = 'default' end
    broadcastAlert(alertCoords, text, alertType)
end)

RSGCore.Commands.Add('testalert', locale('sv_test'), {}, false, function(source)
    if source <= 0 then return end
    broadcastAlert(GetEntityCoords(GetPlayerPed(source)), locale('sv_test_a'))
end, 'admin')

------------------------------------------
-- law on-duty callback
------------------------------------------
RSGCore.Functions.CreateCallback('rsg-lawman:server:getlaw', function(source, cb)
    local lawcount = 0
    for _, v in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            lawcount = lawcount + 1
        end
    end
    cb(lawcount)
end)

------------------------------------------
-- law badge
------------------------------------------
RSGCore.Commands.Add('lawbadge', locale('sv_lawbadge'), {}, false, function(source)
    if not getLawman(source) then return end
    TriggerClientEvent('rsg-lawman:client:lawbadge', source)
end)

------------------------------------------
-- search players inventory
------------------------------------------
RSGCore.Commands.Add('searchplayer', locale('sv_searchplayer'), {}, false, function(source)
    if source <= 0 then return end
    TriggerClientEvent('rsg-lawman:client:searchplayer', source)
end)

local searchBusy = {}

-- The closest player to `src`, when the lawman may search / frisk them. The target is always worked out here.
local function getSearchTarget(src, requireRestrained)
    local player, distance = RSGCore.Functions.GetClosestPlayer(src)
    if player == -1 or distance > Config.SearchDistance + 1.0 then
        notify(src, locale('sv_error'), locale('sv_error_a'), 'error', 7000)
        return nil
    end
    local Target = RSGCore.Functions.GetPlayer(player)
    if not Target then return nil end

    if requireRestrained then
        local meta = Target.PlayerData.metadata
        local restrained = meta.ishandcuffed or meta.isdead or meta.inlaststand
        if not restrained then
            -- hands up / hogtied / lassoed can only be seen by the target's own client
            local answer = RSGCore.Functions.AwaitClientCallback('rsg-lawman:client:isSearchable', player, 2000)
            restrained = answer == true
        end
        if not restrained then
            notify(src, locale('cl_search'), nil, 'error')
            return nil
        end
    end
    return Target, player
end

RegisterNetEvent('rsg-lawman:server:SearchPlayer', function()
    local src = source
    if searchBusy[src] then return end
    if not getLawman(src) then return end

    searchBusy[src] = true
    local Target, player = getSearchTarget(src, Config.SearchRequireRestrained)
    searchBusy[src] = nil
    if not Target then return end

    exports['rsg-inventory']:OpenInventoryById(src, player)
    notify(player, locale('sv_info'), locale('sv_info_a'), 'inform', 7000)
end)

------------------------------------------
-- frisk and seize
------------------------------------------
-- contraband the target carries: weapons (minus ignored categories) and Config.Frisk.ExtraItems
local function contrabandOf(Target)
    local F = Config.Frisk
    local found, list = {}, {}
    for _, item in pairs(Target.PlayerData.items or {}) do
        local def = RSGCore.Shared.Items[item.name]
        local flagged = F.ExtraItems[item.name]
            or (F.Weapons and def and def.type == 'weapon' and not F.IgnoreCategories[def.category or ''])
        if flagged then
            local entry = found[item.name]
            if not entry then
                entry = { name = item.name, label = (def and def.label) or item.name, amount = 0 }
                found[item.name] = entry
                list[#list + 1] = entry
            end
            entry.amount = entry.amount + (tonumber(item.amount) or 1)
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

RegisterNetEvent('rsg-lawman:server:frisk', function()
    local src = source
    if not Config.Frisk.Enabled or searchBusy[src] then return end
    if not getLawman(src) then return end

    searchBusy[src] = true
    local Target = getSearchTarget(src, Config.Frisk.RequireRestrained)
    searchBusy[src] = nil
    if not Target then return end

    local list = contrabandOf(Target)
    for i = #list, Config.Frisk.MaxListed + 1, -1 do list[i] = nil end
    TriggerClientEvent('rsg-lawman:client:friskResult', src, list)
end)

RegisterNetEvent('rsg-lawman:server:seize', function(itemName)
    local src = source
    if type(itemName) ~= 'string' or not Config.Frisk.Enabled or searchBusy[src] then return end
    if not getLawman(src) then return end

    searchBusy[src] = true
    local Target, player = getSearchTarget(src, Config.Frisk.RequireRestrained)
    searchBusy[src] = nil
    if not Target then return end

    local allowed = false
    for _, entry in ipairs(contrabandOf(Target)) do
        if entry.name == itemName then allowed = true break end
    end
    if not allowed then return end

    local slots = {}
    for slot, item in pairs(Target.PlayerData.items or {}) do
        if item.name == itemName then slots[#slots + 1] = { slot = item.slot or slot, amount = tonumber(item.amount) or 1, info = item.info } end
    end

    local total = 0
    for _, it in ipairs(slots) do
        if not exports['rsg-inventory']:CanAddItem(src, itemName, it.amount) then
            notify(src, locale('sv_inv_full'), nil, 'error')
            break
        end
        if exports['rsg-inventory']:RemoveItem(player, itemName, it.amount, it.slot, 'rsg-lawman-seize') then
            if exports['rsg-inventory']:AddItem(src, itemName, it.amount, it.info, nil, 'rsg-lawman-seize') then
                total = total + it.amount
            else
                exports['rsg-inventory']:AddItem(player, itemName, it.amount, it.info, nil, 'rsg-lawman-seize-return') -- give it back
            end
        end
    end

    if total > 0 then
        local label = (RSGCore.Shared.Items[itemName] or {}).label or itemName
        notify(src, locale('sv_seized', total, label), nil, 'success')
        lawLog('Items seized', src, { { 'Item', ('%sx %s'):format(total, itemName) }, { 'From', Target.PlayerData.citizenid } })
    end
end)

------------------------------------------
-- unjail
------------------------------------------
RSGCore.Commands.Add('unjail', locale('sv_unjail'), { { name = 'id', help = locale('sv_unjail_a') } }, true,
    function(source, args)
        local src = source
        if not getLawman(src) then return end

        local TargetPlayer = RSGCore.Functions.GetPlayer(tonumber(args[1]) or -1)
        if not TargetPlayer then
            notify(src, locale('sv_unjail_f'), locale('sv_unjail_g'), 'error')
            return
        end

        TargetPlayer.Functions.SetMetaData('injail', 0) -- server-side release so rsg-prison accepts it
        TriggerClientEvent('rsg-prison:client:freedom', TargetPlayer.PlayerData.source)
        notify(src, locale('sv_unjail_b'), locale('sv_unjail_c'), 'success')
        notify(TargetPlayer.PlayerData.source, locale('sv_unjail_d'), locale('sv_unjail_e'), 'success')
    end)

------------------------------------------
-- jail
------------------------------------------
local lastArrest = {} -- [lawman src] = { [target citizenid] = os.time() }

local function arrestReputation(lawman, target, minutes)
    local cfg = Config.Reputation
    if not cfg or not cfg.Enabled then return end
    if GetResourceState('rsg-reputation') ~= 'started' then return end
    if (tonumber(minutes) or 0) < (cfg.MinMinutes or 1) then return end
    local src = lawman.PlayerData.source
    if src == target.PlayerData.source then return end
    local cid = target.PlayerData.citizenid
    lastArrest[src] = lastArrest[src] or {}
    if lastArrest[src][cid] and os.time() - lastArrest[src][cid] < (cfg.Cooldown or 600) then return end
    lastArrest[src][cid] = os.time()
    pcall(function() exports['rsg-reputation']:ApplyAction(src, cfg.Action or 'arrest') end)
end

local function jailPlayer(targetId, byPlayer, minutes)
    local Lawman = getLawman(byPlayer)
    if not Lawman then return end

    minutes = tonumber(minutes)
    minutes = minutes and math.floor(minutes)
    if not minutes or minutes <= 0 then
        notify(byPlayer, locale('sv_jail_c'), locale('sv_jail_d'))
        return
    end
    if minutes > Config.MaxJailTime then
        notify(byPlayer, locale('sv_jail_c'), locale('sv_jail_max', Config.MaxJailTime), 'error')
        return
    end

    local Target = getTarget(byPlayer, targetId, Config.JailDistance)
    if not Target then return end

    -- jailing an inmate again must not shorten (or reset) the sentence they already have
    if (tonumber(Target.PlayerData.metadata.injail) or 0) > 0 then
        notify(byPlayer, locale('sv_already_jailed'), nil, 'error')
        return
    end

    local currentDate = os.date('*t')
    if currentDate.day == 31 then currentDate.day = 30 end

    Target.Functions.SetMetaData('injail', minutes)
    Target.Functions.SetMetaData('criminalrecord', { ['hasRecord'] = true, ['date'] = currentDate })
    clearRestraints(Target)
    TriggerClientEvent('rsg-lawman:client:sendtojail', Target.PlayerData.source, minutes)
    arrestReputation(Lawman, Target, minutes)
    notify(byPlayer, locale('sv_injail') .. ' ' .. minutes, nil, 'success')
    lawLog('Player jailed', byPlayer, { { 'Minutes', minutes }, { 'Prisoner', Target.PlayerData.citizenid } })
end

RSGCore.Commands.Add('jail', locale('sv_jail'),
    { { name = 'id', help = locale('sv_jail_a') }, { name = 'time', help = locale('sv_jail_b') } }, true,
    function(source, args)
        jailPlayer(args[1], source, args[2])
    end)

RegisterNetEvent('rsg-lawman:server:jailplayer', function(playerId, minutes)
    jailPlayer(playerId, source, minutes)
end)

-- opens the minutes dialog for the closest player (also bound to Config.JailNearKey on the client)
RSGCore.Commands.Add('jailnear', locale('key_jailnear'), {}, false, function(source)
    if not getLawman(source) then return end
    TriggerClientEvent('rsg-lawman:client:jailplayer', source)
end)

------------------------------------------
-- handcuffs
------------------------------------------
RSGCore.Commands.Add('cuff', locale('sv_cuff'), { { name = 'mode', help = locale('sv_cuff_mode') } }, false, function(source, args)
    if not getLawman(source) then return end
    TriggerClientEvent('rsg-lawman:client:cuffplayer', source, args[1] == 'hard')
end)

RSGCore.Functions.CreateUseableItem('handcuffs', function(source)
    if not getLawman(source) then return end
    TriggerClientEvent('rsg-lawman:client:cuffplayer', source)
end)

-- the server decides cuff / uncuff from the target's metadata and tells the client the state explicitly
RegisterNetEvent('rsg-lawman:server:cuffplayer', function(playerId, isSoftcuff, hard)
    local src = source
    local Lawman = getLawman(src)
    if not Lawman then return end
    local Target = getTarget(src, playerId, Config.ActionDistance)
    if not Target then return end
    if not exports['rsg-inventory']:HasItem(src, 'handcuffs', 1) then return end

    local cuffed = not Target.PlayerData.metadata.ishandcuffed
    Target.Functions.SetMetaData('ishandcuffed', cuffed)
    if not cuffed then Target.Functions.SetMetaData('isescorted', false) end
    TriggerClientEvent('rsg-lawman:client:getcuffed', Target.PlayerData.source, src, isSoftcuff == true, cuffed, hard == true)
end)

-- Kept for other resources (rsg-adminmenu cuffs through the client event) and for state restore after relog.
-- A client can only ever change its own flag.
RegisterNetEvent('rsg-lawman:server:sethandcuffstatus', function(isHandcuffed)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or type(isHandcuffed) ~= 'boolean' then return end
    Player.Functions.SetMetaData('ishandcuffed', isHandcuffed)
end)

------------------------------------------
-- escort
------------------------------------------
RSGCore.Commands.Add('escort', locale('sv_escort'), {}, false, function(source)
    if not getLawman(source) then return end
    TriggerClientEvent('rsg-lawman:client:escortplayer', source)
end)

RegisterNetEvent('rsg-lawman:server:setescortstatus', function(isEscorted)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or type(isEscorted) ~= 'boolean' then return end
    Player.Functions.SetMetaData('isescorted', isEscorted)
end)

RegisterNetEvent('rsg-lawman:server:escortplayer', function(playerId)
    local src = source
    local Lawman = getLawman(src)
    if not Lawman then return end
    local Target = getTarget(src, playerId, Config.ActionDistance)
    if not Target then return end

    local meta = Target.PlayerData.metadata
    local targetSrc = Target.PlayerData.source
    if meta.isescorted then
        Target.Functions.SetMetaData('isescorted', false)
        TriggerClientEvent('rsg-lawman:client:getescorted', targetSrc, src, false)
    elseif meta.ishandcuffed or meta.isdead then
        Target.Functions.SetMetaData('isescorted', true)
        TriggerClientEvent('rsg-lawman:client:getescorted', targetSrc, src, true)
    else
        notify(src, locale('sv_handcuffedordead'), nil, 'error')
    end
end)

---------------------------------
-- law storage (one stash per law job)
---------------------------------
RegisterNetEvent('rsg-lawman:server:storage', function()
    local src = source
    local Player = getLawman(src, false)
    if not Player then return end
    local jobname = Player.PlayerData.job.name
    if not isAtOwnOffice(src, jobname) then return end -- the job comes from the server, never from the client
    local data = { label = locale('sv_storage'), maxweight = Config.StorageMaxWeight, slots = Config.StorageMaxSlots }
    exports['rsg-inventory']:OpenInventory(src, 'lawstorage' .. jobname, data)
end)

---------------------------------
-- outlaw status (server-side API only)
---------------------------------
-- exports['rsg-lawman']:AddOutlawStatus(src, amount) - never reachable from a client
exports('AddOutlawStatus', function(src, amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    amount = tonumber(amount)
    if not Player or not amount then return false end
    MySQL.update('UPDATE players SET outlawstatus = GREATEST(0, outlawstatus + ?) WHERE citizenid = ?',
        { math.floor(amount), Player.PlayerData.citizenid })
    return true
end)

---------------------------------
-- fines (rsg-society)
---------------------------------
RSGCore.Commands.Add('fine', locale('sv_fine'), {
    { name = 'id', help = locale('sv_jail_a') },
    { name = 'amount', help = locale('sv_fine_amount') },
    { name = 'reason', help = locale('sv_fine_reason') },
}, true, function(source, args)
    local src = source
    if not Config.Fines.Enabled then return end
    local Lawman = getLawman(src)
    if not Lawman then return end

    local amount = tonumber(args[2])
    amount = amount and math.floor(amount)
    local Target = getTarget(src, args[1], Config.JailDistance)
    if not Target then return end
    if not amount or amount <= 0 or GetResourceState('rsg-society') ~= 'started' then
        notify(src, locale('sv_fine_failed'), nil, 'error')
        return
    end

    local reason = table.concat(args, ' ', 3):gsub('%c', ''):sub(1, Config.Fines.MaxReasonLength)
    local jobname = Lawman.PlayerData.job.name
    local ok, result = pcall(function()
        return exports['rsg-society']:IssueFine(src, Target.PlayerData.source, jobname, amount, reason)
    end)
    if ok and result == true then
        notify(src, locale('sv_fine_ok', amount), nil, 'success')
        lawLog('Fine issued', src, { { 'Amount', '$' .. amount }, { 'Reason', reason }, { 'Target', Target.PlayerData.citizenid } })
    else
        notify(src, locale('sv_fine_failed'), nil, 'error')
    end
end)

---------------------------------
-- frisk command
---------------------------------
RSGCore.Commands.Add('frisk', locale('sv_frisk'), {}, false, function(source)
    if not Config.Frisk.Enabled or not getLawman(source) then return end
    TriggerClientEvent('rsg-lawman:client:frisk', source)
end)

---------------------------------
-- /911 crime report
---------------------------------
local reportLast = {}

RSGCore.Commands.Add('911', locale('sv_911'), { { name = 'message', help = locale('sv_911_a') } }, true, function(source, args)
    local src = source
    if not Config.Report.Enabled or src <= 0 or not RSGCore.Functions.GetPlayer(src) then return end

    local now = os.time()
    if reportLast[src] and now - reportLast[src] < Config.Report.Cooldown then
        notify(src, locale('sv_911_wait'), nil, 'error')
        return
    end

    local text = table.concat(args, ' '):gsub('%c', ''):sub(1, Config.Report.MaxLength)
    if text == '' then return end

    local onDuty = 0
    for _, v in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then onDuty = onDuty + 1 end
    end
    if onDuty == 0 then
        notify(src, locale('sv_911_nolaw'), nil, 'error')
        return
    end

    reportLast[src] = now
    broadcastAlert(GetEntityCoords(GetPlayerPed(src)), text, 'report')
    notify(src, locale('sv_911_sent'), nil, 'success')
end)

---------------------------------
-- holding cells (Config.HoldingCells)
---------------------------------
local held = {} -- [target src] = { job = jobname }

local function releaseFromCell(targetSrc)
    local info = held[targetSrc]
    held[targetSrc] = nil
    local Target = RSGCore.Functions.GetPlayer(targetSrc)
    if not Target then return end
    Target.Functions.SetMetaData('inholdcell', false)
    local cfg = info and Config.HoldingCells[info.job]
    TriggerClientEvent('rsg-lawman:client:releasedFromCell', targetSrc, cfg and cfg.release or nil)
end

RSGCore.Commands.Add('holdcell', locale('sv_hold'), { { name = 'id', help = locale('sv_jail_a') } }, true, function(source, args)
    local src = source
    local Lawman = getLawman(src)
    if not Lawman then return end

    local jobname = Lawman.PlayerData.job.name
    local cfg = Config.HoldingCells[jobname]
    if not cfg or not cfg.cell then
        notify(src, locale('sv_hold_none'), nil, 'error')
        return
    end
    if not isAtOwnOffice(src, jobname) then
        notify(src, locale('sv_hold_none'), nil, 'error')
        return
    end

    local Target = getTarget(src, args[1], Config.ActionDistance)
    if not Target then return end
    if not Target.PlayerData.metadata.ishandcuffed then
        notify(src, locale('sv_hold_cuffs'), nil, 'error')
        return
    end

    local targetSrc = Target.PlayerData.source
    held[targetSrc] = { job = jobname }
    Target.Functions.SetMetaData('inholdcell', jobname)
    TriggerClientEvent('rsg-lawman:client:heldInCell', targetSrc, cfg.cell)
    notify(src, locale('sv_hold_ok'), nil, 'success')
    lawLog('Held in cell', src, { { 'Prisoner', Target.PlayerData.citizenid }, { 'Office', jobname }, { 'Minutes', cfg.minutes or 5 } })

    SetTimeout((cfg.minutes or 5) * 60000, function()
        if held[targetSrc] then releaseFromCell(targetSrc) end
    end)
end)

RSGCore.Commands.Add('releasecell', locale('sv_release'), { { name = 'id', help = locale('sv_jail_a') } }, true, function(source, args)
    local Lawman = getLawman(source)
    if not Lawman then return end
    local n = tonumber(args[1])
    local id = n and math.tointeger(n)
    if id and held[id] and held[id].job == Lawman.PlayerData.job.name then
        releaseFromCell(id)
    end
end)

-- a player who was in a cell when the server restarted or they dropped is let out on login
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData.metadata.inholdcell then return end
    local src = Player.PlayerData.source
    SetTimeout(5000, function()
        local live = RSGCore.Functions.GetPlayer(src)
        if not live or not live.PlayerData.metadata.inholdcell then return end
        held[src] = { job = live.PlayerData.metadata.inholdcell }
        releaseFromCell(src)
    end)
end)

---------------------------------
-- outlaw status cools down
---------------------------------
CreateThread(function()
    local D = Config.OutlawDecay
    if not D or not D.Enabled then return end
    while true do
        Wait(math.max(1, D.Interval) * 60000)
        MySQL.update('UPDATE players SET outlawstatus = GREATEST(0, outlawstatus - ?) WHERE outlawstatus > 0', { math.floor(D.Amount) })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    alertLast[src] = nil
    lastArrest[src] = nil
    searchBusy[src] = nil
    reportLast[src] = nil
    held[src] = nil
end)
