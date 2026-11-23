local RSGCore = exports['rsg-core']:GetCoreObject()
------------------------------------------
-- hunting contracts: a trapper gives a player one contract at a time
-- ("skin 3 deer"), skinning progress is counted on the server, and the
-- player returns to any trapper to be paid. stored in hunting_contracts
------------------------------------------
HuntingContracts = {}

local QRANK = { poor = 0, good = 1, perfect = 2 }
local cache = {} -- [citizenid] = row | false (no contract)

local function enabled()
    return Config.Contracts and Config.Contracts.Enabled and HuntingDB.ready
end

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('contract_title'), description = desc, type = ntype or 'inform', duration = 8000 })
end

local function load(cid)
    if cache[cid] == nil then
        local row = MySQL.single.await('SELECT * FROM hunting_contracts WHERE citizenid = ?', { cid })
        if row then
            row.model, row.need, row.got = tonumber(row.model), tonumber(row.need), tonumber(row.got)
            row.reward, row.xp = tonumber(row.reward) or 0, tonumber(row.xp) or 0
            row.expires, row.claimed_at = tonumber(row.expires) or 0, tonumber(row.claimed_at) or 0
        end
        if cache[cid] == nil then cache[cid] = row or false end -- another request may have filled it while we waited
    end
    return cache[cid] or nil
end

local function save(row)
    cache[row.citizenid] = row
    MySQL.query('REPLACE INTO hunting_contracts (citizenid, model, need, got, quality, reward, xp, expires, status, claimed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { row.citizenid, row.model, row.need, row.got, row.quality, row.reward, row.xp, row.expires, row.status, row.claimed_at })
end

local function qualitySuffix(q)
    return (q and q ~= '') and locale('contract_q_' .. q) or ''
end

local function minutesLeft(t) return math.max(1, math.ceil(t / 60)) end

-- a new contract the player is allowed to take (hunting level, quality needs trusted client quality)
local function issue(src, cid)
    local cfg = Config.Contracts
    local level = HuntingXP.GetLevelData(HuntingXP.GetXP(src)).level or 1
    local options = {}
    for _, p in ipairs(cfg.Pool or {}) do
        local quality = p.quality or ''
        if level >= (p.minLevel or 1) and (quality == '' or Config.TrustClientQuality) then options[#options + 1] = p end
    end
    if #options == 0 then return nil end

    local p = options[math.random(#options)]
    local need = math.random(p.need[1], p.need[2])
    return {
        citizenid = cid, model = p.model, need = need, got = 0, quality = p.quality or '',
        reward = math.floor((p.reward or 0) * need * 100 + 0.5) / 100,
        xp = math.floor((p.xp or 0) * need),
        expires = os.time() + (cfg.Duration or 120) * 60,
        status = 'active', claimed_at = 0,
    }
end

-- called after a skin was paid out
function HuntingContracts.OnSkin(src, model, quality)
    if not enabled() then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local row = load(Player.PlayerData.citizenid)
    if not row or row.status ~= 'active' or row.model ~= model or row.got >= row.need or os.time() >= row.expires then return end
    if row.quality ~= '' and (QRANK[quality] or 0) < (QRANK[row.quality] or 0) then return end

    row.got = row.got + 1
    save(row)
    local name = HuntingJournal.Name(model)
    notify(src, locale(row.got >= row.need and 'contract_ready' or 'contract_step', row.got, row.need, name), 'success')
end

-- the trapper conversation: pay a finished contract, show progress, or hand out a new one
function HuntingContracts.Interact(src)
    if not enabled() then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local row = load(cid)
    local now = os.time()
    local cfg = Config.Contracts
    local expiredNote = false

    if row and row.status == 'active' then
        local name = HuntingJournal.Name(row.model)
        if row.got >= row.need then
            -- claim first (no yield before this), then pay
            row.status, row.claimed_at = 'claimed', now
            save(row)
            if row.reward > 0 then Player.Functions.AddMoney('cash', row.reward, 'rsg-hunting-contract') end
            if row.xp > 0 then HuntingXP.Award(src, row.xp) end
            notify(src, locale('contract_done', ('%.2f'):format(row.reward), row.xp), 'success')
            HuntingWebhook.Send('trapper', {
                title = locale('wh_contract_title'),
                description = locale('wh_contract_desc', row.need, name, ('%.2f'):format(row.reward)),
                src = src,
            })
            return
        elseif now < row.expires then
            notify(src, locale('contract_progress', row.got, row.need, name .. qualitySuffix(row.quality), minutesLeft(row.expires - now), ('%.2f'):format(row.reward)))
            return
        end
        row.status = 'expired'
        expiredNote = true
    end

    if row and row.status == 'claimed' then
        local wait = (row.claimed_at + (cfg.Cooldown or 0) * 60) - now
        if wait > 0 then
            notify(src, locale('contract_cooldown', minutesLeft(wait)))
            return
        end
    end

    local new = issue(src, cid)
    if not new then
        if row and expiredNote then save(row) end
        notify(src, locale('contract_none_available'))
        return
    end
    save(new)
    if expiredNote then notify(src, locale('contract_expired')) end
    notify(src, locale('contract_new', new.need, HuntingJournal.Name(new.model), qualitySuffix(new.quality), cfg.Duration or 120, ('%.2f'):format(new.reward), new.xp))
end
