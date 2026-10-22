local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local ANTIDOTE_ITEM = 'tonic_antidote'
local ANTIDOTE_MIN_MS = 3000       -- antidote cure only honoured after the drink animation could have finished
local ANTIDOTE_WINDOW_MS = 30000   -- ...and only within this window
local EXPLOIT_LOG_COOLDOWN = 30000 -- per-player throttle on exploit webhooks

local CAUSE_LABELS = {
    snake  = 'wh_cause_snake',
    ammo   = 'wh_cause_ammo',
    weapon = 'wh_cause_weapon',
}

local pendingAntidote = {} -- [src] = GetGameTimer() when antidote was consumed
local poisonedAt = {}      -- [src] = os.time() when poisoned/resumed, for duration logging
local lastExploitLog = {}

local function isPoisoned(Player)
    return Player.PlayerData.metadata.poisoned == true
end

local function notify(src, key, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_antidote_title'),
        description = locale(key),
        type = nType,
        duration = 5000
    })
end

local function durationField(src)
    local t = poisonedAt[src]
    if not t then return nil end
    local secs = os.time() - t
    return { name = locale('wh_field_poisoned_for'), value = locale('wh_duration', secs // 60, secs % 60) }
end

local function logExploit(src, reason)
    local now = GetGameTimer()
    if lastExploitLog[src] and now - lastExploitLog[src] < EXPLOIT_LOG_COOLDOWN then return end
    lastExploitLog[src] = now
    SendPoisonLog('exploitAttempt', {
        title = locale('wh_exploit_title'),
        description = reason,
        src = src,
    })
end

--- Returns the validated cure reason, or nil if the cure is not legitimate.
local function resolveCureReason(src)
    local usedAt = pendingAntidote[src]
    if usedAt then
        local elapsed = GetGameTimer() - usedAt
        if elapsed >= ANTIDOTE_MIN_MS and elapsed <= ANTIDOTE_WINDOW_MS then
            return 'antidoteUsed'
        end
    end

    local ped = GetPlayerPed(src)
    if ped ~= 0 and GetEntityHealth(ped) <= 0 then
        return 'death'
    end
end

RSGCore.Functions.CreateUseableItem(ANTIDOTE_ITEM, function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not isPoisoned(Player) then
        SendPoisonLog('antidoteDenied', { title = locale('wh_antidote_denied_title'), description = locale('wh_antidote_denied_not_poisoned'), src = src })
        return notify(src, 'sv_antidote_not_needed', 'error')
    end

    if pendingAntidote[src] and GetGameTimer() - pendingAntidote[src] < ANTIDOTE_WINDOW_MS then
        SendPoisonLog('antidoteDenied', { title = locale('wh_antidote_denied_title'), description = locale('wh_antidote_denied_in_progress'), src = src })
        return notify(src, 'sv_antidote_in_progress', 'inform')
    end

    if exports['rsg-inventory']:RemoveItem(src, item.name, 1, item.slot, 'rsg-poison:antidote') then
        pendingAntidote[src] = GetGameTimer()
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item.name], 'remove', 1)
        TriggerClientEvent('rsg-poison:client:useAntidote', src)
    end
end)

-- Persist poison state in metadata so it survives logoff, kicks and restarts.
RegisterNetEvent('rsg-poison:server:setPoisoned', function(state, cause)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if state == true then
        if isPoisoned(Player) then return end -- ignore repeats (blocks webhook spam)
        pendingAntidote[src] = nil
        poisonedAt[src] = os.time()
        Player.Functions.SetMetaData('poisoned', true)

        local causeLabel = CAUSE_LABELS[cause] and locale(CAUSE_LABELS[cause])
        if not causeLabel then
            causeLabel = locale('wh_unknown')
            logExploit(src, locale('wh_exploit_invalid_cause', tostring(cause):sub(1, 50)))
        end

        SendPoisonLog('poisoned', {
            title = locale('wh_poisoned_title'),
            description = locale('wh_poisoned_desc'),
            src = src,
            fields = { { name = locale('wh_field_cause'), value = causeLabel } },
        })
        return
    end

    if not isPoisoned(Player) then return end

    local reason = resolveCureReason(src)
    if reason then
        local hadAntidote = pendingAntidote[src] ~= nil
        local duration = durationField(src)
        pendingAntidote[src] = nil
        poisonedAt[src] = nil
        Player.Functions.SetMetaData('poisoned', false)

        if reason == 'death' then
            SendPoisonLog('death', {
                title = locale('wh_death_title'),
                description = locale('wh_death_desc'),
                src = src,
                fields = { duration },
            })
            if hadAntidote then
                SendPoisonLog('antidoteWasted', {
                    title = locale('wh_antidote_wasted_title'),
                    description = locale('wh_antidote_wasted_desc'),
                    src = src,
                })
            end
        else
            SendPoisonLog('antidoteUsed', {
                title = locale('wh_antidote_used_title'),
                description = locale('wh_antidote_used_desc'),
                src = src,
                fields = { duration },
            })
        end
        return
    end

    -- Forged cure: keep them poisoned, resync the client, and flag it
    TriggerClientEvent('rsg-poison:client:resumePoison', src)
    logExploit(src, locale('wh_exploit_forged_cure'))
end)

-- Client pulls its saved state on load / resource restart
lib.callback.register('rsg-poison:server:getPoisonState', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not isPoisoned(Player) then return false end

    poisonedAt[source] = poisonedAt[source] or os.time()
    SendPoisonLog('resumed', {
        title = locale('wh_resumed_title'),
        description = locale('wh_resumed_desc'),
        src = source,
    })
    return true
end)

AddEventHandler('playerDropped', function()
    pendingAntidote[source] = nil
    poisonedAt[source] = nil
    lastExploitLog[source] = nil
end)
