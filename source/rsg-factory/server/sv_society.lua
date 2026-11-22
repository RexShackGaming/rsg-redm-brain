-- ============================================
-- RSG-SOCIETY INTEGRATION (factories)
-- Every factory gets its own job (factory_<id>) and a job society in rsg-society the moment it is created:
-- treasury, member list, ranks, storage and audit trail. The owner holds the boss grade, trusted workers hold
-- the staff grade. With Config.Society.EarningsToSociety the factory's earnings (the fees other players pay)
-- are the society account. Deleting a factory removes the society again.
-- Everything is best effort (pcall): a missing or stopped rsg-society never breaks a factory.
-- ============================================
local RSGCore = exports['rsg-core']:GetCoreObject()

FactorySociety = {}

local CFG = Config.Society or {}

local function enabled()
    return CFG.Enabled ~= false and GetResourceState('rsg-society') == 'started'
end

local function jobName(f)
    return (CFG.JobPrefix or 'factory_') .. tostring(f.id)
end

-- grade definitions: { [level] = { name, payment, isboss } }; the boss level is the highest isboss grade
local function gradeDefs()
    local src = type(CFG.Grades) == 'table' and #CFG.Grades > 0 and CFG.Grades
        or { { name = 'Worker', payment = 0 }, { name = 'Owner', payment = 0, isboss = true } }
    local grades, boss = {}, 0
    for i, g in ipairs(src) do
        local pay = tonumber(g.payment) or 0
        grades[tostring(i - 1)] = { name = tostring(g.name or ('Grade ' .. i)):sub(1, 50), payment = pay >= 0 and pay or 0, isboss = g.isboss == true or nil }
        if g.isboss == true then boss = i - 1 end
    end
    return grades, boss
end

local function jobExists(name)
    local ok, def = pcall(function() return exports['rsg-core']:GetJobDefinition(name) end)
    return ok and def ~= nil and def ~= false
end

local function ensureJob(f)
    local name = jobName(f)
    if jobExists(name) then return true end
    local grades = gradeDefs()
    local ok, saved, err = pcall(function()
        return exports['rsg-core']:SaveJobDefinition({
            name = name, label = tostring(f.name or name):sub(1, 100), type = CFG.JobType or 'factory',
            defaultDuty = true, offDutyPay = false, grades = grades,
        })
    end)
    if not ok or not saved then
        print(('^3[rsg-factory] could not create the job %s for rsg-society (%s)^7'):format(name, tostring(ok and err or saved)))
        return false
    end
    return true
end

local function giveJob(cid, name, level)
    if not cid then return end
    local ok, held = pcall(function() return exports['rsg-core']:HasPlayerJob(cid, name) end)
    if ok and held then return end
    pcall(function() exports['rsg-core']:AddPlayerJob(cid, name, level, true) end)
end

local function takeJob(cid, name)
    if not cid then return end
    pcall(function() exports['rsg-core']:RemovePlayerJob(cid, name) end)
end

--- Society name that holds this factory's earnings, or nil when earnings stay in the factory (database column).
function FactorySociety.Account(f)
    if CFG.EarningsToSociety == false or not enabled() or not f or not f.id then return nil end
    local name = jobName(f)
    local ok, soc = pcall(function() return exports['rsg-society']:GetSociety(name) end)
    return ok and soc and name or nil
end

--- Whole dollars in the society account (0 when there is none).
function FactorySociety.Balance(f)
    local name = FactorySociety.Account(f)
    if not name then return 0 end
    local ok, bal = pcall(function() return exports['rsg-society']:GetBalance(name) end)
    return ok and math.floor(tonumber(bal) or 0) or 0
end

--- Adds earnings to the society account. false = no society, the caller keeps the money in the factory.
function FactorySociety.Credit(f, amount, reason)
    local name = FactorySociety.Account(f)
    if not name or amount < 1 then return false end
    local ok, done = pcall(function() return exports['rsg-society']:AddMoney(name, amount, reason or 'factory fee') end)
    return ok and done == true
end

--- Takes money out of the society account. false = not enough or no society.
function FactorySociety.Debit(f, amount, reason)
    local name = FactorySociety.Account(f)
    if not name or amount < 1 then return false end
    local ok, done = pcall(function() return exports['rsg-society']:RemoveMoney(name, amount, reason or 'factory payout') end)
    return ok and done == true
end

--- Moves whatever the database column holds into the society account (factories that earned before the society existed).
local function moveBank(f, name)
    local amount = tonumber(f.bank) or 0
    if amount < 1 or not FactorySociety.Account(f) then return end
    if (MySQL.update.await('UPDATE `rsg_factories` SET `bank` = `bank` - ? WHERE `id` = ? AND `bank` >= ?', { amount, f.id, amount }) or 0) < 1 then return end
    f.bank = math.max(0, f.bank - amount)
    local ok, done = pcall(function() return exports['rsg-society']:AddMoney(name, amount, 'factory earnings moved') end)
    if not ok or not done then
        MySQL.update.await('UPDATE `rsg_factories` SET `bank` = `bank` + ? WHERE `id` = ?', { amount, f.id })
        f.bank = f.bank + amount
    end
end

--- Creates the job + society of a factory and gives the owner (boss) and trusted workers their grade.
function FactorySociety.Open(f)
    if not enabled() or not f or not f.id then return false end
    if not ensureJob(f) then return false end
    local name = jobName(f)
    local ok, res = pcall(function() return exports['rsg-society']:EnsureJobSociety(name) end)
    if not ok or res ~= true then
        print(('^3[rsg-factory] rsg-society did not create a society for %s^7'):format(name))
        return false
    end
    local _, boss = gradeDefs()
    if f.owner then giveJob(f.owner, name, boss) end
    for _, t in ipairs((f.settings and f.settings.trusted) or {}) do giveJob(t.cid, name, 0) end
    moveBank(f, name)
    return true
end

--- Removes the job from everyone who holds it (owner, trusted workers and anyone hired in the society menu).
function FactorySociety.ClearPeople(f)
    if not enabled() or not f or not f.id then return end
    local name = jobName(f)
    local seen = {}
    local ok, members = pcall(function() return exports['rsg-society']:GetMembers(name) end)
    if ok and type(members) == 'table' then
        for _, m in ipairs(members) do
            seen[m.citizenid] = true
            takeJob(m.citizenid, name)
        end
    end
    if f.owner and not seen[f.owner] then takeJob(f.owner, name) end
    for _, t in ipairs((f.settings and f.settings.trusted) or {}) do
        if not seen[t.cid] then takeJob(t.cid, name) end
    end
end

--- A player bought the factory: they become the boss.
function FactorySociety.OwnerSet(f, cid)
    if not enabled() or not f or not cid then return end
    if not FactorySociety.Open(f) then return end
    local _, boss = gradeDefs()
    local name = jobName(f)
    -- already holding the job at a lower grade (e.g. a worker who bought it): add the boss grade through the core
    pcall(function() exports['rsg-core']:RemovePlayerJob(cid, name) end)
    giveJob(cid, name, boss)
end

--- Ownership moved from one player to another (transfer): the old owner leaves, the new one becomes boss.
function FactorySociety.OwnerChange(f, oldCid, newCid)
    if not enabled() or not f then return end
    local name = jobName(f)
    takeJob(oldCid, name)
    for _, t in ipairs((f.settings and f.settings.trusted) or {}) do takeJob(t.cid, name) end
    -- the new owner starts without the old owner's trusted workers
    FactorySociety.OwnerSet({ id = f.id, name = f.name, owner = newCid, settings = { trusted = {} } }, newCid)
end

function FactorySociety.StaffAdd(f, cid)
    if not enabled() or not f or not f.id or not f.owner then return end
    if jobExists(jobName(f)) then giveJob(cid, jobName(f), 0) end
end

function FactorySociety.StaffRemove(f, cid)
    if not enabled() or not f or not f.id then return end
    takeJob(cid, jobName(f))
end

--- Keeps the job (and so the society) label in step with the factory name.
function FactorySociety.Rename(f)
    if not enabled() or not f or not f.id then return end
    local name = jobName(f)
    local ok, def = pcall(function() return exports['rsg-core']:GetJobDefinition(name) end)
    local label = tostring(f.name or name):sub(1, 100)
    if not ok or type(def) ~= 'table' or def.label == label then return end
    pcall(function()
        exports['rsg-core']:SaveJobDefinition({
            name = name, label = label, type = def.type, icon = def.icon,
            defaultDuty = def.defaultDuty, offDutyPay = def.offDutyPay, grades = def.grades,
        })
    end)
end

--- Removes the society and the job of a factory. The balance goes to Owner (a Player object) when given.
--- Returns the balance that was in the account and the amount paid out.
function FactorySociety.Close(f, Owner)
    if not enabled() or not f or not f.id then return 0, 0 end
    local name = jobName(f)
    FactorySociety.ClearPeople(f)
    local ok, removed, balance = pcall(function() return exports['rsg-society']:RemoveJobSociety(name) end)
    balance = ok and removed and tonumber(balance) or 0
    local paid = 0
    if balance > 0 and Owner and Owner.Functions then
        if Owner.Functions.AddMoney('cash', balance, 'rsg-factory-society-payout') then paid = balance end
    end
    if balance > 0 and paid == 0 then
        print(('^3[rsg-factory] society %s closed with $%.2f in the account that could not be paid out (no owner online)^7'):format(name, balance))
    end
    if jobExists(name) then
        pcall(function() exports['rsg-core']:DeleteJobDefinition(name) end)
    end
    return balance, paid
end

--- On start: every factory gets a society (factories created before rsg-society was wired in).
function FactorySociety.Backfill(factories)
    if CFG.Enabled == false then return end
    CreateThread(function()
        local waited = 0
        while waited < 30000 do
            local okR, ready = pcall(function() return exports['rsg-society']:IsReady() end)
            if okR and ready then break end
            Wait(500)
            waited = waited + 500
        end
        if not enabled() then return end
        local count = 0
        for _, f in pairs(factories) do
            if FactorySociety.Open(f) then count = count + 1 end
        end
        if count > 0 then print(('[rsg-factory] %d factory societies checked in rsg-society'):format(count)) end
    end)
end
