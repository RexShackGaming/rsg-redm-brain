-- rsg-economy: mayor elections (registration -> voting -> result), one election per town at a time
-- Players act through server/actions.lua callbacks; everything is validated here.
RSGEcon = RSGEcon or {}
local RSGCore = exports['rsg-core']:GetCoreObject()
local DAY = 86400

local function cfg() return Config.Elections or {} end
local function validRegion(r) return type(r) == 'string' and Config.Regions[r] ~= nil end
local function ready() return RSGEcon.Ready or RSGEcon.WaitReady() end

-- single line of plain text, at most `max` characters; nil when it is not valid UTF-8
local function clean(s, max)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('%c', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    local len = utf8.len(s)
    if not len then return nil end
    if len > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

local function charName(P)
    local ci = P.PlayerData.charinfo or {}
    return clean(('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), 100) or '?'
end

local function licenseOf(P)
    return P.PlayerData.license or RSGCore.Functions.GetIdentifier(P.PlayerData.source, 'license')
end

local function announce(key, ...)
    TriggerClientEvent('RSGCore:Client:Notify', -1, {
        title = locale('notify_title'), description = locale(key, ...), type = 'inform', duration = 7000,
    })
end

------------------------------------------
-- storage
------------------------------------------
local function setPhase(region, phase, phaseEnd)
    if phase then
        RSGEcon.Elections[region] = { phase = phase, phase_end = phaseEnd }
        MySQL.insert.await('INSERT INTO rsg_economy_election (region, phase, phase_end) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE phase = VALUES(phase), phase_end = VALUES(phase_end)', { region, phase, phaseEnd })
    else
        RSGEcon.Elections[region] = nil
        MySQL.query.await('DELETE FROM rsg_economy_election WHERE region = ?', { region })
    end
end

-- election over: no candidates, no votes, no phase
local function wipe(region)
    MySQL.query.await('DELETE FROM rsg_economy_vote WHERE region = ?', { region })
    MySQL.query.await('DELETE FROM rsg_economy_candidate WHERE region = ?', { region })
    setPhase(region, nil)
end

local function retryLater(region)
    RSGEcon.SetMeta('er_' .. region, os.time() + DAY)
end

local function setMayor(region, citizenid, name)
    local now = os.time()
    local termEnd = now + math.max(1, tonumber(cfg().TermDays) or 14) * DAY
    RSGEcon.Mayors[region] = { citizenid = citizenid, name = name, since = now, term_end = termEnd }
    MySQL.insert.await('INSERT INTO rsg_economy_mayor (region, citizenid, name, since, term_end) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), name = VALUES(name), since = VALUES(since), term_end = VALUES(term_end)', { region, citizenid, name, now, termEnd })
    TriggerEvent('rsg-economy:server:mayorChanged', region, citizenid, name)
    return termEnd
end

------------------------------------------
-- phases
------------------------------------------
local function finishCandidacy(region)
    local e = RSGEcon.Elections[region]
    if not e then return end
    local previous = e.phase
    e.phase = 'closing' -- players cannot register or vote while this runs
    local ok, err = pcall(function()
        local label = RSGEcon.RegionLabel(region)
        local n = tonumber(MySQL.scalar.await('SELECT COUNT(1) FROM rsg_economy_candidate WHERE region = ?', { region })) or 0
        if n < math.max(1, tonumber(cfg().MinCandidates) or 1) then
            wipe(region)
            retryLater(region)
            announce('notify_election_cancelled', label)
            return
        end
        setPhase(region, 'voting', os.time() + math.max(1, tonumber(cfg().VotingDays) or 3) * DAY)
        announce('notify_election_voting', label)
    end)
    if not ok then
        print(('[rsg-economy] ^1election (%s) could not close candidacy: %s^7'):format(region, tostring(err)))
        if RSGEcon.Elections[region] then RSGEcon.Elections[region].phase = previous end
    end
end

local function finishVoting(region)
    local e = RSGEcon.Elections[region]
    if not e then return end
    local previous = e.phase
    e.phase = 'closing'
    local ok, err = pcall(function()
        local label = RSGEcon.RegionLabel(region)
        -- most votes wins; a tie goes to whoever registered first
        local rows = MySQL.query.await([[
            SELECT c.id, c.citizenid, c.name, COUNT(v.candidate) AS votes
            FROM rsg_economy_candidate c
            LEFT JOIN rsg_economy_vote v ON v.candidate = c.id
            WHERE c.region = ?
            GROUP BY c.id, c.citizenid, c.name, c.registered
            ORDER BY votes DESC, c.registered ASC, c.id ASC
            LIMIT 1]], { region })
        local winner = rows and rows[1]
        if not winner or (tonumber(winner.votes) or 0) < 1 then
            wipe(region)
            retryLater(region)
            announce('notify_election_cancelled', label)
            return
        end
        local termEnd = setMayor(region, winner.citizenid, winner.name)
        wipe(region)
        announce('notify_election_result', winner.name, label)
        if GetResourceState('rsg-telegram') == 'started' then
            pcall(function()
                exports['rsg-telegram']:SendTelegram(winner.citizenid, locale('tg_elected_subject', label),
                    locale('tg_elected_body', label, os.date('!%Y-%m-%d', termEnd)), { senderName = locale('tg_sender') })
            end)
        end
    end)
    if not ok then
        print(('[rsg-economy] ^1election (%s) could not be counted: %s^7'):format(region, tostring(err)))
        if RSGEcon.Elections[region] then RSGEcon.Elections[region].phase = previous end
    end
end

------------------------------------------
-- admin / script API
------------------------------------------
function RSGEcon.StartElection(region)
    if not validRegion(region) then return false, 'unknown' end
    if not cfg().Enabled then return false, 'disabled' end
    if not ready() then return false, 'notready' end
    if RSGEcon.Elections[region] then return false, 'running' end
    wipe(region) -- clears anything left over
    setPhase(region, 'candidacy', os.time() + math.max(1, tonumber(cfg().CandidacyDays) or 2) * DAY)
    announce('notify_election_open', RSGEcon.RegionLabel(region))
    return true
end

-- ends the current phase now (registration -> voting, voting -> result)
function RSGEcon.AdvanceElection(region)
    local e = validRegion(region) and RSGEcon.Elections[region]
    if not e then return false, 'none' end
    if e.phase == 'candidacy' then finishCandidacy(region)
    elseif e.phase == 'voting' then finishVoting(region)
    else return false, 'busy' end
    return true
end

function RSGEcon.CancelElection(region)
    if not validRegion(region) or not RSGEcon.Elections[region] then return false, 'none' end
    wipe(region)
    return true
end

local function nameOf(citizenid)
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    local ci = P and P.PlayerData.charinfo
    if not ci then
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
        if row and row.charinfo then
            ci = type(row.charinfo) == 'string' and json.decode(row.charinfo) or row.charinfo
        end
    end
    if type(ci) ~= 'table' then return nil end
    return clean(('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), 100)
end

function RSGEcon.SetMayor(region, citizenid)
    if not validRegion(region) then return false, 'unknown' end
    if type(citizenid) ~= 'string' or #citizenid < 1 or #citizenid > 50 then return false, 'citizen' end
    if not ready() then return false, 'notready' end
    local name = nameOf(citizenid)
    if not name then return false, 'citizen' end
    setMayor(region, citizenid, name)
    return true, name
end

function RSGEcon.ClearMayor(region)
    if not validRegion(region) or not RSGEcon.Mayors[region] then return false, 'none' end
    RSGEcon.Mayors[region] = nil
    MySQL.query.await('DELETE FROM rsg_economy_mayor WHERE region = ?', { region })
    TriggerEvent('rsg-economy:server:mayorChanged', region, nil, nil)
    return true
end

------------------------------------------
-- player actions (return ok, message)
------------------------------------------
function RSGEcon.ElectionRegister(src, region, platform)
    if not cfg().Enabled or not validRegion(region) then return false, locale('msg_failed') end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return false, locale('msg_failed') end
    local e = RSGEcon.Elections[region]
    if not e or e.phase ~= 'candidacy' then return false, locale('msg_election_closed') end
    platform = clean(platform, tonumber(cfg().PlatformLength) or 140)
    if not platform then return false, locale('msg_failed') end

    local cid = P.PlayerData.citizenid
    if MySQL.scalar.await('SELECT 1 FROM rsg_economy_candidate WHERE region = ? AND citizenid = ?', { region, cid }) then
        return false, locale('msg_already_candidate')
    end
    local count = tonumber(MySQL.scalar.await('SELECT COUNT(1) FROM rsg_economy_candidate WHERE region = ?', { region })) or 0
    if count >= (tonumber(cfg().MaxCandidates) or 8) then return false, locale('msg_candidates_full') end

    -- the phase may have changed while the database answered
    local now = RSGEcon.Elections[region]
    if not now or now.phase ~= 'candidacy' then return false, locale('msg_election_closed') end

    local fee = tonumber(cfg().CandidateFee) or 0
    if fee > 0 and not P.Functions.RemoveMoney(Config.MoneyType, fee, 'election-candidate-fee') then
        return false, locale('msg_no_money')
    end
    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO rsg_economy_candidate (region, citizenid, name, platform, registered) VALUES (?, ?, ?, ?, ?)',
        { region, cid, charName(P), platform, os.time() })
    if not ok or not id then
        if fee > 0 then P.Functions.AddMoney(Config.MoneyType, fee, 'election-candidate-fee-refund') end
        return false, locale('msg_already_candidate')
    end
    if fee > 0 then
        RSGEcon.DepositTreasury(region, fee, 'candidate fee', RSGEcon.ActorName(src), 'deposit', true)
        RSGEcon.SaveTreasuryNow(region)
    end
    return true, locale('msg_registered', RSGEcon.RegionLabel(region))
end

function RSGEcon.ElectionWithdraw(src, region)
    if not cfg().Enabled or not validRegion(region) then return false, locale('msg_failed') end
    local P = RSGCore.Functions.GetPlayer(src)
    local e = RSGEcon.Elections[region]
    if not P or not e or (e.phase ~= 'candidacy' and e.phase ~= 'voting') then return false, locale('msg_election_closed') end
    local id = MySQL.scalar.await('SELECT id FROM rsg_economy_candidate WHERE region = ? AND citizenid = ?', { region, P.PlayerData.citizenid })
    if not id then return false, locale('msg_not_candidate') end
    MySQL.query.await('DELETE FROM rsg_economy_vote WHERE region = ? AND candidate = ?', { region, id }) -- those voters can vote again
    MySQL.query.await('DELETE FROM rsg_economy_candidate WHERE id = ?', { id })
    return true, locale('msg_candidacy_withdrawn')
end

function RSGEcon.ElectionVote(src, region, candidateId)
    if not cfg().Enabled or not validRegion(region) then return false, locale('msg_failed') end
    local P = RSGCore.Functions.GetPlayer(src)
    local e = RSGEcon.Elections[region]
    if not P or not e or e.phase ~= 'voting' then return false, locale('msg_voting_closed') end
    candidateId = tonumber(candidateId)
    if not candidateId or candidateId < 1 or candidateId % 1 ~= 0 then return false, locale('msg_failed') end
    if not MySQL.scalar.await('SELECT 1 FROM rsg_economy_candidate WHERE id = ? AND region = ?', { candidateId, region }) then
        return false, locale('msg_no_candidate')
    end
    local license = licenseOf(P)
    if not license then return false, locale('msg_failed') end
    -- one vote per account and town (the primary key refuses a second one, even from another character)
    local ok, inserted = pcall(MySQL.insert.await, 'INSERT INTO rsg_economy_vote (region, license, voter, candidate, voted) VALUES (?, ?, ?, ?, ?)',
        { region, license, P.PlayerData.citizenid, candidateId, os.time() })
    if not ok or inserted == nil then return false, locale('msg_already_voted') end
    return true, locale('msg_voted')
end

-- everything the Elections tab shows
function RSGEcon.ElectionView(src, region)
    if not validRegion(region) then return nil end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return nil end
    local e = RSGEcon.Elections[region]
    local mayor = RSGEcon.GetMayor(region)
    local cid = P.PlayerData.citizenid
    local c = cfg()
    local out = {
        region = region, enabled = c.Enabled == true,
        fee = tonumber(c.CandidateFee) or 0, maxPlatform = tonumber(c.PlatformLength) or 140,
        mayor = mayor and { name = mayor.name, termEnd = mayor.term_end, mine = mayor.citizenid == cid } or nil,
        phase = e and e.phase or nil, phaseEnd = e and e.phase_end or nil,
        candidates = {}, registered = false, votedFor = nil,
    }
    if e and (e.phase == 'candidacy' or e.phase == 'voting') then
        local showCounts = e.phase == 'voting' and not c.HideCounts
        local rows = MySQL.query.await([[
            SELECT c.id, c.citizenid, c.name, c.platform, COUNT(v.candidate) AS votes
            FROM rsg_economy_candidate c
            LEFT JOIN rsg_economy_vote v ON v.candidate = c.id
            WHERE c.region = ?
            GROUP BY c.id, c.citizenid, c.name, c.platform, c.registered
            ORDER BY c.registered, c.id]], { region }) or {}
        for _, r in ipairs(rows) do
            local mine = r.citizenid == cid
            if mine then out.registered = true end
            out.candidates[#out.candidates + 1] = {
                id = r.id, name = r.name, platform = r.platform, mine = mine,
                votes = showCounts and (tonumber(r.votes) or 0) or nil,
            }
        end
        local license = licenseOf(P)
        if license then
            out.votedFor = MySQL.scalar.await('SELECT candidate FROM rsg_economy_vote WHERE region = ? AND license = ?', { region, license })
        end
    end
    return out
end

------------------------------------------
-- timer: moves elections along and starts new ones
------------------------------------------
local function tick()
    if not cfg().Enabled then return end
    local now = os.time()
    for region in pairs(Config.Regions) do
        local e = RSGEcon.Elections[region]
        if e then
            if now >= e.phase_end then
                if e.phase == 'candidacy' then finishCandidacy(region)
                elseif e.phase == 'voting' then finishVoting(region) end
            end
        elseif cfg().AutoStart then
            local mayor = RSGEcon.GetMayor(region)
            local lead = (math.max(1, tonumber(cfg().CandidacyDays) or 2) + math.max(1, tonumber(cfg().VotingDays) or 3)) * DAY
            local retry = tonumber(RSGEcon.Meta['er_' .. region]) or 0
            -- no mayor, or the term ends before a new election could finish
            if now >= retry and (not mayor or mayor.term_end - now <= lead) then
                RSGEcon.StartElection(region)
            end
        end
    end
end

CreateThread(function()
    while not RSGEcon.WaitReady() do Wait(1000) end
    while true do
        local ok, err = pcall(tick)
        if not ok then print(('[rsg-economy] ^1election timer failed: %s^7'):format(tostring(err))) end
        Wait(30 * 1000)
    end
end)

exports('StartElection', RSGEcon.StartElection)
exports('SetMayor', RSGEcon.SetMayor)
exports('ClearMayor', RSGEcon.ClearMayor)
