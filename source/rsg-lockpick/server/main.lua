local RSGCore = exports['rsg-core']:GetCoreObject()

local tickets = {}      -- [src] = active ticket
local lastIssued = {}   -- [src] = ms of the last ticket
local lastAlert = {}    -- [src] = ms of the last lawman alert
local ticketCounter = 0

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function notify(src, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title'),
        description = description,
        type = ntype or 'inform',
        duration = 5000,
    })
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function callCb(cb, ...)
    if not cb then return end
    local ok, err = pcall(cb, ...)
    if not ok then print(('^1[rsg-lockpick]^7 caller callback error: %s'):format(tostring(err))) end
end

CreateThread(function()
    Wait(2000)
    if Config.Item.Enabled and not RSGCore.Shared.Items[Config.Item.Name] then
        print(('^3[rsg-lockpick]^7 item \'%s\' is not in RSGCore.Shared.Items; add it or set Config.Item.Name / Config.Item.Enabled'):format(Config.Item.Name))
    end
end)

---------------------------------------------------------------------------
-- rsg-skills (optional)
---------------------------------------------------------------------------
local function skillsRunning()
    return Config.Skill.Enabled and GetResourceState('rsg-skills') == 'started'
end

local function registerSkill()
    if not skillsRunning() then return end
    local def = Config.Skill.Definition
    local ok, err = pcall(function()
        exports['rsg-skills']:RegisterSkill(Config.Skill.Name, {
            label = locale('skill_label'),
            description = locale('skill_desc'),
            order = def.order,
            maxLevel = def.maxLevel,
            perks = def.perks,
        })
    end)
    if not ok then print(('^1[rsg-lockpick]^7 could not register skill: %s'):format(tostring(err))) end
end

local function getPerk(src, perk)
    if not skillsRunning() then return 0 end
    local ok, v = pcall(function() return exports['rsg-skills']:GetPerk(src, Config.Skill.Name, perk) end)
    return ok and tonumber(v) or 0
end

local function awardXP(src, success)
    if not skillsRunning() then return end
    local amount = success and Config.Skill.XP.Success or Config.Skill.XP.Fail
    if not amount or amount <= 0 then return end
    -- fixed, server-side amounts: raw skips multipliers, so the config is the single source
    pcall(function() exports['rsg-skills']:AddXP(src, Config.Skill.Name, amount, 'lockpick', { raw = true }) end)
end

AddEventHandler('rsg-skills:server:ready', registerSkill)
AddEventHandler('onResourceStart', function(res)
    if res == 'rsg-skills' then SetTimeout(500, registerSkill) end
end)
CreateThread(function() Wait(1500) registerSkill() end)

---------------------------------------------------------------------------
-- Lockpick item: quality, difficulty, wear
---------------------------------------------------------------------------
local function getPick(src)
    if not Config.Item.Enabled then return nil end
    return exports['rsg-inventory']:GetItemByName(src, Config.Item.Name)
end

local function pickQuality(item)
    return clamp(tonumber(item and item.info and item.info.quality) or 100, 0, 100)
end

local function applyWear(src, ticket, outcome)
    if not Config.Item.Enabled or not ticket.slot or outcome == 'cancel' then return end
    local item = getPick(src)
    if not item then return end

    local w = Config.Item.Wear
    local loss = outcome == 'success' and w.Success or w.Fail
    local destroyed = outcome == 'fail' and math.random() < w.BreakChanceOnFail
    local quality = pickQuality(item) - loss

    if destroyed or quality <= 0 then
        local amount = tonumber(item.amount) or 1
        exports['rsg-inventory']:RemoveItem(src, Config.Item.Name, 1, item.slot, 'lockpick-broke')
        if amount > 1 then -- the next pick in the stack starts fresh
            local info = item.info or {}
            info.quality = 100
            exports['rsg-inventory']:SetItemInfo(src, item.slot, info)
        end
        notify(src, locale('lockpick_broke'), 'error')
    else
        local info = item.info or {}
        info.quality = quality
        exports['rsg-inventory']:SetItemInfo(src, item.slot, info)
    end
end

---------------------------------------------------------------------------
-- Lawman alert (rsg-lawman)
---------------------------------------------------------------------------
local function maybeAlert(src, ticket, outcome)
    local a = Config.Alert
    if not a.Enabled or outcome == 'cancel' or ticket.data.alert == false then return end
    if GetResourceState('rsg-lawman') ~= 'started' then return end

    local chance = tonumber(ticket.data.alert)
    if not chance then
        chance = outcome == 'success' and a.ChanceOnSuccess or a.ChanceOnFail
    end
    if math.random() > chance then return end

    local now = GetGameTimer()
    if lastAlert[src] and now - lastAlert[src] < a.MinGap then return end
    lastAlert[src] = now

    local coords = GetEntityCoords(GetPlayerPed(src))
    local text = locale('alert_text')
    for _, v in pairs(RSGCore.Functions.GetRSGPlayers()) do
        local job = v.PlayerData.job
        if job and job.type == a.JobType and job.onduty then
            TriggerClientEvent('rsg-lawman:client:lawmanAlert', v.PlayerData.source, coords, text)
        end
    end
end

---------------------------------------------------------------------------
-- Ticket lifecycle
---------------------------------------------------------------------------
-- Difficulty is decided here, never by the client: preset + caller options + skill perks + pick condition.
local function buildOptions(src, data, item)
    local o = Config.Build(data.preset, data.options)

    o.solvePadding = o.solvePadding + getPerk(src, 'lockpick_sweet_spot')
    o.pins = o.pins + getPerk(src, 'lockpick_extra_pick')

    local reduction = clamp(getPerk(src, 'lockpick_pick_damage'), 0, 90)
    o.pinDamage = o.pinDamage * (1 - reduction / 100)

    if item and Config.Item.QualityDamageScale and Config.Item.QualityDamageScale > 0 then
        o.pinDamage = o.pinDamage * (1 + (100 - pickQuality(item)) / 100 * Config.Item.QualityDamageScale)
    end

    return Config.Clamp(o)
end

local function resolveTicket(src, ticket, outcome, reason)
    if tickets[src] == ticket then tickets[src] = nil end
    local success = outcome == 'success'

    if outcome ~= 'cancel' then
        applyWear(src, ticket, outcome)
        awardXP(src, success)
        maybeAlert(src, ticket, outcome)
    end

    callCb(ticket.cb, success, reason or outcome)
    TriggerEvent('rsg-lockpick:server:finished', src, success, ticket.data)
end

-- StartAttempt(src, data, cb) -> started (boolean), ticketId | reason
--   data = {
--     preset = 'easy' | 'medium' | 'hard',   (optional)
--     options = { pins = 2, ... },            (optional overrides)
--     coords = vector3, radius = 3.0,         (optional: player must stay near this point)
--     alert = false | 0.0-1.0,                (optional: lawman alert override)
--     noItem = true,                          (optional: do not require/wear the lockpick item)
--   }
--   cb(success, reason) is called on the server with the validated result.
local function StartAttempt(src, data, cb)
    src = tonumber(src)
    data = type(data) == 'table' and data or {}

    local function refuse(reason)
        callCb(cb, false, reason)
        return false, reason
    end

    if not src or not RSGCore.Functions.GetPlayer(src) then return refuse('no_player') end
    if tickets[src] then return refuse('busy') end

    local now = GetGameTimer()
    if lastIssued[src] and now - lastIssued[src] < Config.Server.Cooldown then
        notify(src, locale('slow_down'), 'error')
        return refuse('cooldown')
    end

    local coords
    if data.coords then
        coords = vector3(data.coords.x, data.coords.y, data.coords.z)
        local radius = tonumber(data.radius) or Config.Server.DefaultRadius
        data.radius = radius
        if #(GetEntityCoords(GetPlayerPed(src)) - coords) > radius + Config.Server.DistanceSlack then
            return refuse('too_far')
        end
    end

    local item
    local useItem = Config.Item.Enabled and not data.noItem
    if useItem then
        item = getPick(src)
        if not item and Config.Item.Require then
            notify(src, locale('need_lockpick'), 'error')
            return refuse('no_item')
        end
    end

    ticketCounter = ticketCounter + 1
    local ticket = {
        id = ('%d-%d'):format(ticketCounter, math.random(100000, 999999)),
        cb = cb,
        data = data,
        issuedAt = now,
        expires = now + Config.Server.TicketTTL,
        coords = coords,
        slot = (useItem and item) and item.slot or nil,
    }
    tickets[src] = ticket
    lastIssued[src] = now

    TriggerClientEvent('rsg-lockpick:client:ticketStart', src, ticket.id, buildOptions(src, data, item))
    return true, ticket.id
end

exports('StartAttempt', StartAttempt)

exports('CancelAttempt', function(src)
    src = tonumber(src)
    local ticket = src and tickets[src]
    if not ticket then return false end
    TriggerClientEvent('rsg-lockpick:client:ticketCancel', src)
    resolveTicket(src, ticket, 'cancel', 'cancelled')
    return true
end)

exports('HasActiveAttempt', function(src)
    return tickets[tonumber(src)] ~= nil
end)

RegisterNetEvent('rsg-lockpick:server:ticketResult', function(ticketId, outcome)
    local src = source
    local ticket = tickets[src]
    if not ticket or type(ticketId) ~= 'string' or ticket.id ~= ticketId then return end
    if outcome ~= 'success' and outcome ~= 'fail' and outcome ~= 'cancel' then return end

    local now = GetGameTimer()
    if now > ticket.expires then
        return resolveTicket(src, ticket, 'cancel', 'expired')
    end

    local reason = outcome
    if outcome == 'success' then
        if now - ticket.issuedAt < Config.Server.MinSolveTime then
            outcome, reason = 'fail', 'too_fast'
            print(('^3[rsg-lockpick]^7 %s (%d) reported a solve in %d ms, counted as a failure'):format(GetPlayerName(src) or '?', src, now - ticket.issuedAt))
        elseif ticket.coords then
            local limit = (ticket.data.radius or Config.Server.DefaultRadius) + Config.Server.DistanceSlack
            if #(GetEntityCoords(GetPlayerPed(src)) - ticket.coords) > limit then
                outcome, reason = 'fail', 'too_far'
            end
        end
    end

    resolveTicket(src, ticket, outcome, reason)
end)

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(10000)
        local now = GetGameTimer()
        for src, ticket in pairs(tickets) do
            if now > ticket.expires then
                TriggerClientEvent('rsg-lockpick:client:ticketCancel', src)
                resolveTicket(src, ticket, 'cancel', 'expired')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local ticket = tickets[src]
    if ticket then resolveTicket(src, ticket, 'cancel', 'dropped') end
    lastIssued[src] = nil
    lastAlert[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, ticket in pairs(tickets) do
        tickets[src] = nil
        callCb(ticket.cb, false, 'stopped')
    end
end)
