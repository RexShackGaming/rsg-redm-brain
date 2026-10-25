-- Drug reputation (XP). Shared by server.lua (lab) and addiction.lua (NPC sales) via the DrugsXP global.
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

DrugsXP = {}

local function levelFor(xp)
    local lvl = 1
    for i, l in ipairs(Config.XP.Levels) do
        if xp >= l.xp then lvl = i else break end
    end
    return lvl
end

DrugsXP.OnReset = nil -- set by server.lua: function(citizenid) (clears XP banked in the lab)

local function wipe(Player)
    local xp = tonumber(Player.Functions.GetRep(Config.XP.RepName)) or 0
    if xp > 0 then
        Player.Functions.RemoveRep(Config.XP.RepName, xp) -- RemoveRep clamps at 0
        DrugsLog('xp', 'Drug XP reset', Player.PlayerData.source, { { 'XP removed', xp }, { 'Reason', 'Jail sentence or ResetXP export' } })
    end
    if DrugsXP.OnReset then DrugsXP.OnReset(Player.PlayerData.citizenid) end
    return xp
end

local function inJail(Player)
    return (tonumber(Player.PlayerData.metadata.injail) or 0) > 0
end

-- every XP read goes through here, so a jailed player's XP is wiped even if the
-- client never fires rsg-prison's (client-triggered) startSentence event
local function getXP(Player)
    local xp = tonumber(Player.Functions.GetRep(Config.XP.RepName)) or 0
    if xp > 0 and Config.XP.ResetOnJail and inJail(Player) then
        wipe(Player)
        TriggerClientEvent('ox_lib:notify', Player.PlayerData.source, { title = locale('xp_title'), description = locale('xp_jail_reset'), type = 'error', duration = 8000 })
        return 0
    end
    return xp
end

-- { xp, level, label, from, to }  (to = nil at max level)
function DrugsXP.Info(Player)
    local xp = getXP(Player)
    local lvl = levelFor(xp)
    local cur, nxt = Config.XP.Levels[lvl], Config.XP.Levels[lvl + 1]
    return { xp = xp, level = lvl, label = cur.label, from = cur.xp, to = nxt and nxt.xp or nil }
end

-- only ever called from trusted server code with amounts taken from Config.XP
function DrugsXP.Add(src, amount, reason)
    if not Config.XP.Enabled then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    if Config.XP.ResetOnJail and inJail(Player) then return false end -- no XP while doing time
    local before = getXP(Player)
    Player.Functions.AddRep(Config.XP.RepName, amount)
    local after = before + amount
    if Config.XP.Notify then
        local key = reason and ('xp_reason_' .. reason)
        local why = key and locale(key) or ''
        if why == key then why = '' end -- unknown reason from another resource
        TriggerClientEvent('ox_lib:notify', src, { title = locale('xp_title'), description = locale('xp_gain', amount, why), type = 'inform', duration = 3000 })
    end
    local lb, la = levelFor(before), levelFor(after)
    if la > lb then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('xp_title'), description = locale('xp_level', la, Config.XP.Levels[la].label), type = 'success', duration = 7000 })
        DrugsLog('xp', 'Level up', src, { { 'Level', ('%d - %s'):format(la, Config.XP.Levels[la].label) }, { 'Total XP', after }, { 'Source', reason or '-' } })
    end
    return true
end

-- true when the player's level is high enough to pack weed bricks
function DrugsXP.CanPackBricks(Player)
    if not Config.XP.Enabled then return true end
    return DrugsXP.Info(Player).level >= (Config.XP.BrickMinLevel or 1)
end

function DrugsXP.BrickLevelLabel()
    local l = Config.XP.Levels[Config.XP.BrickMinLevel or 1]
    return l and l.label or tostring(Config.XP.BrickMinLevel)
end

-- wipe drug XP (returns the amount removed)
function DrugsXP.Reset(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return 0 end
    return wipe(Player)
end

-- Jail: wipe straight away when rsg-prison starts a sentence (getXP above is the backstop).
-- getXP only wipes when metadata.injail > 0, so a spoofed trigger does nothing.
RegisterNetEvent('rsg-prison:server:startSentence', function()
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player and Config.XP.Enabled then getXP(Player) end
end)

-- for other server resources (e.g. a brick delivery script)
exports('AddXP', function(src, amount, reason) return DrugsXP.Add(src, amount, reason) end)
exports('ResetXP', function(src) return DrugsXP.Reset(src) end)
exports('GetXP', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and DrugsXP.Info(Player) or nil
end)
