-- ============================================
-- RSG-SOCIETY INTEGRATION (player-owned stores)
-- Every player-owned store gets its own job (store_<id>) and a job society in rsg-society:
-- treasury, member list, ranks, storage and audit trail. The store's till is that treasury (Config.Society.SalesToSociety). The owner holds the boss grade, hired staff
-- hold the staff grade. Closing a store removes the society again and pays its balance to the owner.
-- Everything is best effort (pcall): a missing or stopped rsg-society never breaks a store.
-- ============================================
local RSGCore = exports['rsg-core']:GetCoreObject()

StoreSociety = {}

local CFG = Config.Society or {}

local function enabled()
    return CFG.Enabled ~= false and GetResourceState('rsg-society') == 'started'
end

local function jobName(npc)
    return (CFG.JobPrefix or 'store_') .. tostring(npc.id)
end

-- grade definitions: { [level] = { name, payment, isboss } }; the boss level is the highest isboss grade
local function gradeDefs()
    local src = type(CFG.Grades) == 'table' and #CFG.Grades > 0 and CFG.Grades
        or { { name = 'Staff', payment = 0 }, { name = 'Owner', payment = 0, isboss = true } }
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

local function ensureJob(npc)
    local name = jobName(npc)
    if jobExists(name) then return true end
    local grades = gradeDefs()
    local label = tostring((npc.shop and npc.shop.label) or npc.name or name):sub(1, 100)
    local ok, saved, err = pcall(function()
        return exports['rsg-core']:SaveJobDefinition({
            name = name, label = label, type = CFG.JobType or 'store',
            defaultDuty = true, offDutyPay = false, grades = grades,
        })
    end)
    if not ok or not saved then
        print(('^3[rsg-stores] could not create the job %s for rsg-society (%s)^7'):format(name, tostring(ok and err or saved)))
        return false
    end
    return true
end

--- Society name that holds this store's money (the till), or nil when the till is the database column.
function StoreSociety.Account(npc)
    if CFG.SalesToSociety == false or not enabled() or not npc or not npc.id or npc.kind ~= 'player' or not npc.owner then return nil end
    local name = jobName(npc)
    local ok, soc = pcall(function() return exports['rsg-society']:GetSociety(name) end)
    return ok and soc and name or nil
end

--- Moves whatever the database till holds into the society account (stores that traded before the society existed).
local function moveTill(npc, name)
    local till = tonumber(MySQL.scalar.await('SELECT balance FROM rsg_shops_npcs WHERE id = ?', { npc.id })) or 0
    if till < 0.01 then return end
    if (MySQL.update.await('UPDATE rsg_shops_npcs SET balance = balance - ? WHERE id = ? AND balance >= ?', { till, npc.id, till }) or 0) < 1 then return end
    local ok, done = pcall(function() return exports['rsg-society']:AddMoney(name, till, 'till moved') end)
    if not ok or not done then
        MySQL.update.await('UPDATE rsg_shops_npcs SET balance = balance + ? WHERE id = ?', { till, npc.id })
    end
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

--- Creates the job + society of a player-owned store and gives the owner (boss) and any staff their grade.
function StoreSociety.Open(npc)
    if not enabled() or not npc or not npc.id or npc.kind ~= 'player' or not npc.owner then return false end
    if not ensureJob(npc) then return false end
    local name = jobName(npc)
    local ok, res = pcall(function() return exports['rsg-society']:EnsureJobSociety(name) end)
    if not ok or res ~= true then
        print(('^3[rsg-stores] rsg-society did not create a society for %s^7'):format(name))
        return false
    end
    local _, boss = gradeDefs()
    giveJob(npc.owner.citizenid, name, boss)
    for cid in pairs(npc.staff or {}) do giveJob(cid, name, 0) end
    if StoreSociety.Account(npc) then moveTill(npc, name) end
    return true
end

--- Removes the society and the job of a store. The balance goes to Owner (a Player object) when given and online.
--- Returns the balance that was in the account and the amount paid out.
function StoreSociety.Close(npc, Owner)
    if not enabled() or not npc or not npc.id then return 0, 0 end
    local name = jobName(npc)
    local ok, removed, balance = pcall(function() return exports['rsg-society']:RemoveJobSociety(name) end)
    balance = ok and removed and tonumber(balance) or 0
    local paid = 0
    if balance > 0 and Owner and Owner.Functions then
        if Owner.Functions.AddMoney('cash', balance, 'rsg-stores-society-payout') then paid = balance end
    end
    if balance > 0 and paid == 0 then
        print(('^3[rsg-stores] society %s closed with $%.2f in the account that could not be paid out (owner offline)^7'):format(name, balance))
    end
    if jobExists(name) then
        pcall(function() exports['rsg-core']:DeleteJobDefinition(name) end)
    end
    return balance, paid
end

--- Called when admins edit a store: opens, closes or hands over the society as the owner changes.
function StoreSociety.Update(old, new)
    if not enabled() or not old or not new then return end
    local hadOwner = old.kind == 'player' and old.owner
    local hasOwner = new.kind == 'player' and new.owner
    if hadOwner and not hasOwner then
        local P = RSGCore.Functions.GetPlayerByCitizenId(old.owner.citizenid)
        return StoreSociety.Close(old, P)
    end
    if not hadOwner and hasOwner then return StoreSociety.Open(new) end
    if hadOwner and hasOwner then
        local name = jobName(new)
        if old.owner.citizenid ~= new.owner.citizenid then
            takeJob(old.owner.citizenid, name)
            local _, boss = gradeDefs()
            giveJob(new.owner.citizenid, name, boss)
        end
        StoreSociety.Rename(new)
    end
end

--- Keeps the job (and so the society) label in step with the store label.
function StoreSociety.Rename(npc)
    if not enabled() or not npc or not npc.id then return end
    local name = jobName(npc)
    local ok, def = pcall(function() return exports['rsg-core']:GetJobDefinition(name) end)
    local label = tostring((npc.shop and npc.shop.label) or npc.name or name):sub(1, 100)
    if not ok or type(def) ~= 'table' or def.label == label then return end
    pcall(function()
        exports['rsg-core']:SaveJobDefinition({
            name = name, label = label, type = def.type, icon = def.icon,
            defaultDuty = def.defaultDuty, offDutyPay = def.offDutyPay, grades = def.grades,
        })
    end)
end

function StoreSociety.StaffAdd(npc, cid)
    if not enabled() or not npc or not npc.id then return end
    if jobExists(jobName(npc)) then giveJob(cid, jobName(npc), 0) end
end

function StoreSociety.StaffRemove(npc, cid)
    if not enabled() or not npc or not npc.id then return end
    takeJob(cid, jobName(npc))
end

--- On start: every owned store that has no society yet gets one (stores opened before rsg-society was wired in).
function StoreSociety.Backfill(npcs)
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
        for _, npc in ipairs(npcs) do
            if npc.kind == 'player' and npc.owner and StoreSociety.Open(npc) then count = count + 1 end
        end
        if count > 0 then print(('[rsg-stores] %d store societies checked in rsg-society'):format(count)) end
    end)
end
