local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Mines      = {}   -- [mineId] = { citizenid, expires, supplies = {}, storage = {}, workers = {} }
local Candidates = {}   -- [mineId] = { list = {}, refreshAt = os.time() }
local MineCfg    = {}
for _, m in ipairs(Config.Mines) do MineCfg[m.id] = m end

---------------------------------
-- helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('mining'), description = desc, type = ntype or 'inform',
        position = Config.NotifyPosition, duration = 5000, icon = 'gem'
    })
end

local function newMine()
    return { citizenid = nil, expires = 0, wages = 0, supplies = { bread = 0, water = 0, pickaxe = 0 }, storage = {}, workers = {} }
end

local function saveMine(id)
    local m = Mines[id]
    MySQL.prepare('INSERT INTO rsg_mining (mine, citizenid, expires, wages, supplies, storage) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), expires = VALUES(expires), wages = VALUES(wages), supplies = VALUES(supplies), storage = VALUES(storage)',
        { id, m.citizenid, m.expires, m.wages, json.encode(m.supplies), json.encode(m.storage) })
end

local WORKER_UPDATE = 'UPDATE rsg_mining_workers SET skill = ?, food = ?, water = ?, pickaxe = ?, status = ? WHERE id = ?'

local function workerParams(w)
    return { w.skill, w.food, w.water, w.pickaxe, w.status, w.id }
end

local function saveWorkers(list)
    local batch = {}
    for _, w in ipairs(list) do
        if w.id then batch[#batch + 1] = workerParams(w) end -- skip hires still awaiting their insert id
    end
    if #batch > 0 then MySQL.prepare(WORKER_UPDATE, batch) end
end

local function isHolder(src, id)
    local Player = RSGCore.Functions.GetPlayer(src)
    local m = Mines[id]
    if not Player or not m then return false end
    return m.citizenid == Player.PlayerData.citizenid and m.expires > os.time()
end

-- server-side proximity check: stops the ledger being used from anywhere on the map
local function isNear(src, id)
    local cfg = MineCfg[id]
    local ped = GetPlayerPed(src)
    if not cfg or ped == 0 then return false end
    local c = cfg.foreman
    return #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= Config.ManageDistance
end

local lastAction = {}
local function onCooldown(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < Config.ActionCooldown then return true end
    lastAction[src] = now
    return false
end

AddEventHandler('playerDropped', function() lastAction[source] = nil end)

-- every ledger action goes through here.
-- returns true when allowed, otherwise the value the callback should hand back:
--   { busy = true } -> client ignores it (spam click), false -> client closes the ledger
local function guard(src, id)
    if type(id) ~= 'string' or not MineCfg[id] then return false end
    if onCooldown(src) then return { busy = true } end
    if not isNear(src, id) then notify(src, locale('too_far'), 'error') return false end
    if not isHolder(src, id) then notify(src, locale('not_holder'), 'error') return false end
    return true
end

local function wageFor(skill)
    return math.ceil(Config.WageBase + (tonumber(skill) or 1) * Config.WagePerSkill)
end

local function payrollPerShift(m)
    local t = 0
    for _, w in ipairs(m.workers) do t = t + wageFor(w.skill) end
    return t
end

local function storageTotal(m)
    local t = 0
    for _, v in pairs(m.storage) do t = t + v end
    return t
end

local function generateCandidates(id)
    local list = {}
    for i = 1, Config.CandidateCount do
        local skill = math.random(Config.MinSkill, Config.CandidateSkillMax)
        list[i] = {
            key   = ('%s_%d_%d'):format(id, os.time(), i),
            name  = Config.FirstNames[math.random(#Config.FirstNames)] .. ' ' .. Config.LastNames[math.random(#Config.LastNames)],
            skill = skill,
            cost  = Config.HireBaseCost + skill * Config.HireCostPerSkill,
            wage  = wageFor(skill),
        }
    end
    Candidates[id] = { list = list, refreshAt = os.time() + Config.CandidateRefresh * 60 }
end

local function getCandidates(id)
    if not Candidates[id] or Candidates[id].refreshAt <= os.time() then generateCandidates(id) end
    return Candidates[id]
end

-- total held across every stack (GetItemByName only returns one slot)
local function itemCount(src, Player, item)
    local ok, n = pcall(function() return exports['rsg-inventory']:GetItemCount(src, item) end)
    if ok and n then return n end
    local total = 0
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name == item then total = total + (it.amount or 0) end
    end
    return total
end

local function itemImage(item)
    local shared = RSGCore.Shared.Items[item]
    return shared and shared.image or (item .. '.png')
end

local function buildData(src, id)
    local Player = RSGCore.Functions.GetPlayer(src)
    local m, cfg = Mines[id], MineCfg[id]
    local inv = {}
    for k, s in pairs(Config.Supplies) do
        inv[k] = itemCount(src, Player, s.item)
    end
    local storage = {}
    for item, amt in pairs(m.storage) do
        if amt > 0 then
            local shared = RSGCore.Shared.Items[item]
            storage[#storage + 1] = { item = item, label = shared and shared.label or item, amount = amt, image = itemImage(item) }
        end
    end
    local supplyCfg = {}
    for k, s in pairs(Config.Supplies) do supplyCfg[k] = { item = s.item, label = s.label, image = itemImage(s.item) } end
    local cand = getCandidates(id)
    for _, w in ipairs(m.workers) do w.wage = wageFor(w.skill) end
    return {
        id = id, label = cfg.label,
        expires = m.expires, now = os.time(),
        maxWorkers = cfg.maxWorkers, storageCap = cfg.storageCap, storageUsed = storageTotal(m),
        supplies = m.supplies, inventory = inv, supplyCfg = supplyCfg, imagePath = Config.ImagePath,
        workers = m.workers, candidates = cand.list, candidateRefresh = cand.refreshAt - os.time(),
        storage = storage, canRenew = Config.AllowRenew, leasePrice = cfg.leasePrice,
        leaseHours = Config.LeaseDurationHours, workInterval = Config.WorkInterval,
        wages = m.wages, payroll = payrollPerShift(m), maxPayroll = Config.MaxPayroll,
        canWithdraw = Config.AllowWithdraw, moneyType = Config.MoneyType,
    }
end

---------------------------------
-- database
---------------------------------
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS rsg_mining (
        mine VARCHAR(50) NOT NULL PRIMARY KEY,
        citizenid VARCHAR(50) NULL,
        expires INT NOT NULL DEFAULT 0,
        wages INT NOT NULL DEFAULT 0,
        supplies LONGTEXT NULL,
        storage LONGTEXT NULL
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS rsg_mining_workers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        mine VARCHAR(50) NOT NULL,
        name VARCHAR(100) NOT NULL,
        skill FLOAT NOT NULL DEFAULT 1,
        food INT NOT NULL DEFAULT 100,
        water INT NOT NULL DEFAULT 100,
        pickaxe INT NOT NULL DEFAULT 0,
        status VARCHAR(50) NOT NULL DEFAULT 'idle'
    )]])

    -- upgrade older installs (information_schema check works on both MySQL and MariaDB)
    local hasWages = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_mining' AND COLUMN_NAME = 'wages']])
    if (tonumber(hasWages) or 0) == 0 then
        MySQL.query.await('ALTER TABLE rsg_mining ADD COLUMN wages INT NOT NULL DEFAULT 0')
    end

    for id in pairs(MineCfg) do Mines[id] = newMine() end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_mining') or {}) do
        if Mines[row.mine] then
            local m = Mines[row.mine]
            m.citizenid = row.citizenid
            m.expires   = row.expires or 0
            m.wages     = row.wages or 0
            m.supplies  = json.decode(row.supplies or '{}') or {}
            m.storage   = json.decode(row.storage or '{}') or {}
            for k in pairs(Config.Supplies) do m.supplies[k] = m.supplies[k] or 0 end
            -- already expired before this restart: don't re-announce it
            m.expiredNotified = m.expires <= os.time()
        end
    end
    for _, w in ipairs(MySQL.query.await('SELECT * FROM rsg_mining_workers') or {}) do
        if Mines[w.mine] then table.insert(Mines[w.mine].workers, w) end
    end
end)

---------------------------------
-- lease
---------------------------------
lib.callback.register('rsg-mining:server:getMineData', function(src, id)
    if type(id) ~= 'string' or not MineCfg[id] or not Mines[id] then return { error = locale('invalid') } end
    if not isNear(src, id) then return { error = locale('too_far') } end
    if isHolder(src, id) then return { data = buildData(src, id) } end
    local m = Mines[id]
    if m.citizenid and m.expires > os.time() then return { error = locale('leased_other') } end
    return { noLease = true, price = MineCfg[id].leasePrice, hours = Config.LeaseDurationHours, label = MineCfg[id].label }
end)

lib.callback.register('rsg-mining:server:buyLease', function(src, id)
    if type(id) ~= 'string' then return false end
    local Player = RSGCore.Functions.GetPlayer(src)
    local m, cfg = Mines[id], MineCfg[id]
    if not Player or not m or not cfg or onCooldown(src) then return false end
    if not isNear(src, id) then notify(src, locale('too_far'), 'error') return false end
    if m.citizenid and m.expires > os.time() then notify(src, locale('leased_other'), 'error') return false end
    if not Player.Functions.RemoveMoney(Config.MoneyType, cfg.leasePrice, 'mining-lease') then
        notify(src, locale('no_money'), 'error') return false
    end
    local cid = Player.PlayerData.citizenid
    if m.citizenid ~= cid then
        -- new holder: fresh mine
        MySQL.prepare('DELETE FROM rsg_mining_workers WHERE mine = ?', { id })
        local fresh = newMine()
        m.supplies, m.storage, m.workers, m.wages = fresh.supplies, fresh.storage, {}, 0
    end
    m.citizenid = cid
    m.expires   = os.time() + Config.LeaseDurationHours * 3600
    m.expiredNotified = false
    saveMine(id)
    notify(src, locale('lease_bought', cfg.label), 'success')
    Webhook.Log('lease_bought', { src = src, mine = cfg.label, value = cfg.leasePrice, fields = {
        { name = locale('wh_price'), value = '$' .. cfg.leasePrice, inline = true },
        { name = locale('wh_expires'), value = ('<t:%d:R>'):format(m.expires), inline = true },
    } })
    return true
end)

lib.callback.register('rsg-mining:server:renewLease', function(src, id)
    if not Config.AllowRenew then return false end
    local ok = guard(src, id)
    if ok ~= true then return ok end
    local Player = RSGCore.Functions.GetPlayer(src)
    local m, cfg = Mines[id], MineCfg[id]
    local newExpiry = m.expires + Config.LeaseDurationHours * 3600
    if newExpiry - os.time() > Config.MaxLeaseHours * 3600 then notify(src, locale('lease_max'), 'error') return buildData(src, id) end
    if not Player.Functions.RemoveMoney(Config.MoneyType, cfg.leasePrice, 'mining-lease-renew') then
        notify(src, locale('no_money'), 'error') return buildData(src, id)
    end
    m.expires = newExpiry
    saveMine(id)
    notify(src, locale('lease_renewed', Config.LeaseDurationHours), 'success')
    Webhook.Log('lease_renewed', { src = src, mine = cfg.label, value = cfg.leasePrice, fields = {
        { name = locale('wh_price'), value = '$' .. cfg.leasePrice, inline = true },
        { name = locale('wh_expires'), value = ('<t:%d:R>'):format(m.expires), inline = true },
    } })
    return buildData(src, id)
end)

---------------------------------
-- worker needs
---------------------------------
-- pull bread / water / a fresh pickaxe from stores when a worker has run out
local function resupply(m, w)
    if w.food <= 0 and m.supplies.bread > 0 then
        m.supplies.bread = m.supplies.bread - 1
        w.food = math.min(100, w.food + Config.BreadRestore)
    end
    if w.water <= 0 and m.supplies.water > 0 then
        m.supplies.water = m.supplies.water - 1
        w.water = math.min(100, w.water + Config.WaterRestore)
    end
    if w.pickaxe <= 0 and m.supplies.pickaxe > 0 then
        m.supplies.pickaxe = m.supplies.pickaxe - 1
        w.pickaxe = 100
    end
end

-- the need that stops a worker, or nil when fed, watered and equipped
local function needStatus(w)
    if w.food <= 0 then return 'hungry' end
    if w.water <= 0 then return 'thirsty' end
    if w.pickaxe <= 0 then return 'no_pickaxe' end
end

local NEED = { hungry = true, thirsty = true, no_pickaxe = true }

---------------------------------
-- workers
---------------------------------
lib.callback.register('rsg-mining:server:hire', function(src, id, key)
    local ok = guard(src, id)
    if ok ~= true then return ok end
    local Player = RSGCore.Functions.GetPlayer(src)
    local m, cfg = Mines[id], MineCfg[id]
    if type(key) ~= 'string' then return buildData(src, id) end
    if #m.workers >= cfg.maxWorkers then notify(src, locale('max_workers'), 'error') return buildData(src, id) end
    local cand, idx = getCandidates(id), nil
    for i, c in ipairs(cand.list) do if c.key == key then idx = i break end end
    if not idx then notify(src, locale('candidate_gone'), 'error') return buildData(src, id) end
    local c = cand.list[idx]
    if not Player.Functions.RemoveMoney(Config.MoneyType, c.cost, 'mining-hire') then
        notify(src, locale('no_money'), 'error') return buildData(src, id)
    end
    table.remove(cand.list, idx)
    -- add to the crew before the DB await so a second request can't slip past the worker cap
    local w = { mine = id, name = c.name, skill = c.skill, food = 100, water = 100, pickaxe = 0, status = 'idle' }
    resupply(m, w) -- new hires arrive without a pickaxe; hand one over if stores have it
    w.status = needStatus(w) or 'idle'
    table.insert(m.workers, w)
    w.id = MySQL.insert.await('INSERT INTO rsg_mining_workers (mine, name, skill, food, water, pickaxe, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { id, w.name, w.skill, w.food, w.water, w.pickaxe, w.status })
    saveMine(id) -- stores may have handed over a pickaxe
    notify(src, locale('hired', c.name), 'success')
    Webhook.Log('worker_hired', { src = src, mine = cfg.label, value = c.cost, fields = {
        { name = locale('wh_worker'), value = c.name, inline = true },
        { name = locale('wh_skill'), value = c.skill, inline = true },
        { name = locale('wh_cost'), value = '$' .. c.cost, inline = true },
        { name = locale('wh_crew'), value = ('%d / %d'):format(#m.workers, cfg.maxWorkers), inline = true },
    } })
    return buildData(src, id)
end)

lib.callback.register('rsg-mining:server:fire', function(src, id, wid)
    local ok = guard(src, id)
    if ok ~= true then return ok end
    wid = tonumber(wid)
    if not wid then return buildData(src, id) end
    local m = Mines[id]
    for i, w in ipairs(m.workers) do
        if w.id == wid then
            table.remove(m.workers, i)
            MySQL.prepare('DELETE FROM rsg_mining_workers WHERE id = ?', { wid })
            notify(src, locale('fired', w.name), 'inform')
            Webhook.Log('worker_fired', { src = src, mine = MineCfg[id].label, fields = {
                { name = locale('wh_worker'), value = w.name, inline = true },
                { name = locale('wh_skill'), value = w.skill, inline = true },
            } })
            break
        end
    end
    return buildData(src, id)
end)

---------------------------------
-- payroll
---------------------------------
lib.callback.register('rsg-mining:server:addWages', function(src, id, amount)
    local ok = guard(src, id)
    if ok ~= true then return ok end
    local m = Mines[id]
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then notify(src, locale('invalid'), 'error') return buildData(src, id) end
    local room = Config.MaxPayroll - m.wages
    if room < 1 then notify(src, locale('payroll_full'), 'error') return buildData(src, id) end
    amount = math.min(amount, room)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player.Functions.RemoveMoney(Config.MoneyType, amount, 'mining-payroll') then
        notify(src, locale('no_money'), 'error') return buildData(src, id)
    end
    m.wages = m.wages + amount
    for _, w in ipairs(m.workers) do
        if w.status == 'strike' then w.status = needStatus(w) or 'idle' end
    end
    saveWorkers(m.workers)
    saveMine(id)
    notify(src, locale('wages_added', amount), 'success')
    Webhook.Log('wages_added', { src = src, mine = MineCfg[id].label, value = amount, fields = {
        { name = locale('wh_amount'), value = '$' .. amount, inline = true },
        { name = locale('wh_fund'), value = '$' .. m.wages, inline = true },
    } })
    return buildData(src, id)
end)

lib.callback.register('rsg-mining:server:withdrawWages', function(src, id, amount)
    if not Config.AllowWithdraw then return false end
    local ok = guard(src, id)
    if ok ~= true then return ok end
    local m = Mines[id]
    amount = math.min(math.floor(tonumber(amount) or 0), m.wages)
    if amount < 1 then notify(src, locale('invalid'), 'error') return buildData(src, id) end
    local Player = RSGCore.Functions.GetPlayer(src)
    m.wages = m.wages - amount
    saveMine(id)
    Player.Functions.AddMoney(Config.MoneyType, amount, 'mining-payroll-withdraw')
    notify(src, locale('wages_withdrawn', amount), 'success')
    Webhook.Log('wages_withdrawn', { src = src, mine = MineCfg[id].label, value = amount, fields = {
        { name = locale('wh_amount'), value = '$' .. amount, inline = true },
        { name = locale('wh_fund'), value = '$' .. m.wages, inline = true },
    } })
    return buildData(src, id)
end)

---------------------------------
-- supplies & storage
---------------------------------
lib.callback.register('rsg-mining:server:deposit', function(src, id, key, amount)
    local ok = guard(src, id)
    if ok ~= true then return ok end
    local s = Config.Supplies[key]
    amount = math.floor(tonumber(amount) or 0)
    if not s or amount < 1 then notify(src, locale('invalid'), 'error') return buildData(src, id) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if itemCount(src, Player, s.item) < amount then notify(src, locale('not_enough_items'), 'error') return buildData(src, id) end
    if exports['rsg-inventory']:RemoveItem(src, s.item, amount, nil, 'mining-supplies') then
        local shared = RSGCore.Shared.Items[s.item]
        if shared then TriggerClientEvent('rsg-inventory:client:ItemBox', src, shared, 'remove', amount) end
        local m = Mines[id]
        m.supplies[key] = (m.supplies[key] or 0) + amount
        -- stalled workers grab what they need straight away and wait for the next shift
        for _, w in ipairs(m.workers) do
            if NEED[w.status] then
                resupply(m, w)
                w.status = needStatus(w) or 'idle'
            end
        end
        saveWorkers(m.workers)
        saveMine(id)
        notify(src, locale('deposited', amount, s.label), 'success')
        Webhook.Log('supplies_added', { src = src, mine = MineCfg[id].label, value = amount, fields = {
            { name = locale('wh_item'), value = ('%dx %s'):format(amount, s.label), inline = true },
            { name = locale('wh_in_stores'), value = m.supplies[key], inline = true },
        } })
    end
    return buildData(src, id)
end)

-- largest amount (<= want) of an item the player can carry, checked via rsg-inventory
local function maxCarry(src, item, want)
    local inv = exports['rsg-inventory']
    if inv:CanAddItem(src, item, want) then return want end
    local lo, hi = 0, want - 1
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        if inv:CanAddItem(src, item, mid) then lo = mid else hi = mid - 1 end
    end
    return lo
end

-- returns amount collected; partial = true when some was left behind for lack of space
local function collectItem(src, m, item)
    local stored = m.storage[item] or 0
    local shared = RSGCore.Shared.Items[item]
    if stored < 1 or not shared then return 0, false end
    local amt = maxCarry(src, item, stored)
    if amt < 1 then return 0, true end
    if not exports['rsg-inventory']:AddItem(src, item, amt, nil, nil, 'mining-collect') then return 0, true end
    local left = stored - amt
    m.storage[item] = left > 0 and left or nil
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, shared, 'add', amt)
    return amt, left > 0, shared.label
end

lib.callback.register('rsg-mining:server:collect', function(src, id, item)
    local ok = guard(src, id)
    if ok ~= true then return ok end
    local m = Mines[id]
    if type(item) ~= 'string' then return buildData(src, id) end
    local items = {}
    if item == '__all' then for k in pairs(m.storage) do items[#items + 1] = k end else items[1] = item end
    local got, full, lines, msgs = 0, false, {}, {}
    for _, it in ipairs(items) do
        local r, partial, label = collectItem(src, m, it)
        got = got + r
        if partial then full = true end
        if r > 0 then
            lines[#lines + 1] = ('%dx %s'):format(r, label)
            msgs[#msgs + 1] = locale('collected', r, label)
        end
    end
    if got > 0 then
        notify(src, table.concat(msgs, '\n'), 'success') -- one toast instead of one per item
        saveMine(id)
        Webhook.Log('ore_collected', { src = src, mine = MineCfg[id].label, value = got,
            description = table.concat(lines, '\n'),
            fields = { { name = locale('wh_total'), value = got, inline = true } } })
    end
    if full then notify(src, locale('inv_full'), 'error') end
    if got == 0 and not full then notify(src, locale('nothing_collect'), 'error') end
    return buildData(src, id)
end)

---------------------------------
-- work cycle
---------------------------------
-- roll ore for one worker's shift; returns the new storage total
local function mineOre(m, cfg, skill, used)
    for _, ore in ipairs(cfg.ores) do
        if used >= cfg.storageCap then break end
        if skill >= (ore.minSkill or 0) then
            local chance = ore.chance * (1 + (skill - 1) * Config.SkillChanceBonus)
            if math.random() * 100 <= chance then
                local amt = math.random(ore.min, ore.max) + math.floor((skill - 1) * Config.SkillAmountBonus)
                amt = math.min(amt, cfg.storageCap - used)
                if amt > 0 then
                    m.storage[ore.item] = (m.storage[ore.item] or 0) + amt
                    used = used + amt
                end
            end
        end
    end
    return used
end

local function workCycle()
    local now = os.time()
    for id, m in pairs(Mines) do
        if m.citizenid and m.expires > now and #m.workers > 0 then
            local cfg = MineCfg[id]
            local used, struck = storageTotal(m), 0

            for _, w in ipairs(m.workers) do
                local wage = wageFor(w.skill)
                if m.wages < wage then
                    if w.status ~= 'strike' then struck = struck + 1 end
                    w.status = 'strike'
                else
                    resupply(m, w)
                    local need = needStatus(w)
                    if need then w.status = need
                    elseif used >= cfg.storageCap then w.status = 'storage_full'
                    else
                        -- wages are only paid for shifts actually worked
                        m.wages   = m.wages - wage
                        w.status  = 'working'
                        used      = mineOre(m, cfg, w.skill, used)
                        w.food    = math.max(0, w.food - Config.FoodDrain)
                        w.water   = math.max(0, w.water - Config.WaterDrain)
                        w.pickaxe = math.max(0, w.pickaxe - Config.PickaxeWear)
                        w.skill   = math.min(Config.MaxSkill, math.floor((w.skill + Config.SkillGainPerCycle) * 100 + 0.5) / 100)
                        -- ran out this shift: restock from stores now, otherwise stop until supplies arrive
                        resupply(m, w)
                        w.status = needStatus(w) or 'working'
                    end
                end
            end

            saveWorkers(m.workers)
            saveMine(id)

            if struck > 0 then
                local Player = RSGCore.Functions.GetPlayerByCitizenId(m.citizenid)
                if Player then notify(Player.PlayerData.source, locale('workers_strike', struck, cfg.label), 'warning') end
                Webhook.Log('workers_strike', { citizenid = m.citizenid, mine = cfg.label, fields = {
                    { name = locale('wh_on_strike'), value = ('%d / %d'):format(struck, #m.workers), inline = true },
                    { name = locale('wh_fund'), value = '$' .. m.wages, inline = true },
                    { name = locale('wh_per_shift'), value = '$' .. payrollPerShift(m), inline = true },
                } })
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.WorkInterval * 60000)
        workCycle()
    end
end)

-- lease expiry
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, m in pairs(Mines) do
            if m.citizenid and m.expires > 0 and m.expires <= now and (#m.workers > 0 or not m.expiredNotified) then
                local crew = #m.workers
                m.expiredNotified = true
                if crew > 0 then
                    m.workers = {}
                    MySQL.prepare('DELETE FROM rsg_mining_workers WHERE mine = ?', { id })
                end
                Webhook.Log('lease_expired', { citizenid = m.citizenid, mine = MineCfg[id].label, fields = {
                    { name = locale('wh_workers_released'), value = crew, inline = true },
                    { name = locale('wh_payroll_left'), value = '$' .. m.wages, inline = true },
                } })
                local Player = RSGCore.Functions.GetPlayerByCitizenId(m.citizenid)
                if Player then notify(Player.PlayerData.source, locale('lease_expired', MineCfg[id].label), 'warning') end
            end
        end
    end
end)
