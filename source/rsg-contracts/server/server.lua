local RSGCore = exports['rsg-core']:GetCoreObject()

local Contracts = {}  -- [id] = open contract (offered, active, review, disputed)
local Ready = false
local Busy = false    -- one change at a time: database calls yield, so this stops two actions racing
local Cooldown = {}

local function Notify(src, key, kind, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title'), description = locale(key, ...), type = kind or 'error', duration = 5000,
    })
end

local function Log(text)
    TriggerEvent('rsg-log:server:CreateLog', 'default', 'Contracts', 'green', text)
end

local function Locked(fn)
    while Busy do Wait(25) end
    Busy = true
    local ok, a, b = pcall(fn)
    Busy = false
    if not ok then
        print(('^1[rsg-contracts] %s^7'):format(tostring(a)))
        return false, 'failed'
    end
    return a, b
end

local function Cid(Player) return Player.PlayerData.citizenid end

local function CharName(Player)
    local ci = Player.PlayerData.charinfo or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or ''))
end

local function Usable(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local meta = Player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return nil end
    return Player
end

local function Near(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 or GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= Config.SignDistance
end

local function AtOffice(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or GetPlayerRoutingBucket(src) ~= 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, o in ipairs(Config.Offices) do
        if #(pos - o.coords) <= Config.OfficeDistance then return true end
    end
    return false
end

local function IsArbiter(Player)
    local job = Player.PlayerData.job or {}
    if not job.onduty then return false end
    return Config.ArbiterJobTypes[job.type or ''] == true or Config.ArbiterJobs[job.name or ''] == true
end

local function Online(cid)
    local Player = RSGCore.Functions.GetPlayerByCitizenId(cid)
    return Player and Player.PlayerData.source, Player
end

local function Tell(cid, key, kind, ...)
    local src = Online(cid)
    if src then Notify(src, key, kind, ...) end
end

local function TakeCash(Player, cents, reason)
    if cents <= 0 then return true end
    if not Player.Functions.RemoveMoney('cash', cents / 100, reason) then return false end
    return true
end

local function Save(Player) Player.Functions.Save() end

--------------------------------------------------------------------------------
-- Settlement: the status change and every payout are written in one transaction
--------------------------------------------------------------------------------
local function Cash(cid, cents) return { cid = cid, cents = cents } end

local function Close(c, outcome, claims)
    local queries = {
        { query = 'UPDATE rsg_contracts SET status = ?, outcome = ? WHERE id = ?', values = { 'closed', outcome, c.id } },
    }
    for _, cl in ipairs(claims) do
        if (cl.cents or 0) > 0 or (cl.amount or 0) > 0 then
            queries[#queries + 1] = {
                query = 'INSERT INTO rsg_contract_claims (citizenid, contract_id, cents, item, amount, info) VALUES (?, ?, ?, ?, ?, ?)',
                -- empty strings instead of nil, so the parameter list has no holes
                values = { cl.cid, c.id, cl.cents or 0, cl.item or '', cl.amount or 0, json.encode(cl.info or {}) },
            }
        end
    end
    if not MySQL.transaction.await(queries) then return false end
    Contracts[c.id] = nil
    Log(('Contract #%d closed (%s). Buyer %s, worker %s, pay $%.2f, deposit $%.2f'):format(
        c.id, outcome, c.buyer_cid, c.worker_cid, c.pay_cents / 100, c.deposit_cents / 100))
    TriggerEvent('rsg-contracts:server:closed', c, outcome)
    for _, cl in ipairs(claims) do
        if (cl.cents or 0) > 0 or (cl.amount or 0) > 0 then Tell(cl.cid, 'claim_waiting', 'inform', c.id) end
    end
    return true
end

local function Honor(c, cid, change)
    if change == 0 or c.pay_cents < Config.HonorMinPay * 100 then return end
    if GetResourceState('rsg-reputation') ~= 'started' then return end
    local src = Online(cid)
    if src then exports['rsg-reputation']:AddHonor(src, change, 'contract') end
end

local function PayWorker(c, outcome)
    local ok = Close(c, outcome, { Cash(c.worker_cid, c.pay_cents + c.deposit_cents) })
    if ok then Honor(c, c.worker_cid, Config.HonorCompleted) end
    return ok
end

-- worker failed: the buyer gets the payment back and keeps the deposit
local function Broken(c, outcome)
    local ok = Close(c, outcome, { Cash(c.buyer_cid, c.pay_cents + c.deposit_cents) })
    if ok then Honor(c, c.worker_cid, Config.HonorBroken) end
    return ok
end

-- no one is at fault: each side gets their own money back
local function Unwind(c, outcome)
    -- the worker only pays the deposit when signing
    local deposit = c.status == 'offered' and 0 or c.deposit_cents
    return Close(c, outcome, { Cash(c.buyer_cid, c.pay_cents), Cash(c.worker_cid, deposit) })
end

local function SetStatus(c, status, due)
    local n = MySQL.update.await('UPDATE rsg_contracts SET status = ?, due_at = ?, cancel_by = NULL WHERE id = ?',
        { status, due, c.id })
    if not n or n < 1 then return false end
    c.status, c.due_at, c.cancel_by = status, due, nil
    return true
end

local function Expire(c)
    if c.status == 'offered' then return Unwind(c, 'offer_expired') end
    if c.status == 'active' then return Broken(c, 'deadline_missed') end
    if c.status == 'review' then return PayWorker(c, 'review_expired') end
    if c.status == 'disputed' then
        if Config.DisputeDefault == 'worker' then return PayWorker(c, 'dispute_expired') end
        if Config.DisputeDefault == 'buyer' then
            return Close(c, 'dispute_expired', { Cash(c.buyer_cid, c.pay_cents), Cash(c.worker_cid, c.deposit_cents) })
        end
        local half = c.pay_cents // 2
        return Close(c, 'dispute_expired', {
            Cash(c.buyer_cid, c.pay_cents - half), Cash(c.worker_cid, half + c.deposit_cents),
        })
    end
end

--------------------------------------------------------------------------------
-- Actions. Each returns true, or false and a locale key.
--------------------------------------------------------------------------------
local function WholeNumber(v, min, max)
    v = tonumber(v)
    if not v or v ~= math.floor(v) or not (v >= min and v <= max) then return nil end
    return math.tointeger(v)
end

local function Cents(v, min, max)
    v = tonumber(v)
    if not v or not (v >= min and v <= max) then return nil end -- also rejects NaN
    return math.floor(v * 100 + 0.5)
end

local function Text(v, max, required)
    if type(v) ~= 'string' or #v > max * 4 then return nil end
    v = v:gsub('[%c]', ' '):match('^%s*(.-)%s*$')
    local len = utf8.len(v)
    if not len or len > max or (required and len == 0) then return nil end
    return v
end

local function Orderable(name)
    if type(name) ~= 'string' then return nil end
    local def = RSGCore.Shared.Items[name]
    if not def or Config.BlacklistItems[name] or Config.BlacklistTypes[def.type or ''] then return nil end
    return def
end

local Actions = {}

function Actions.create(src, Player, data)
    local target = math.tointeger(tonumber(data.target))
    local worker = target and target ~= src and Usable(target)
    if not worker or not Near(src, target) then return false, 'no_player' end
    if Cid(worker) == Cid(Player) then return false, 'no_player' end

    local kind = data.type
    if kind ~= 'supply' and kind ~= 'job' then return false, 'invalid' end
    local title = Text(data.title, Config.MaxTitle, true)
    local details = Text(data.details or '', Config.MaxDetails, kind == 'job')
    local pay = Cents(data.pay, Config.MinPay, Config.MaxPay)
    local deposit = Cents(data.deposit or 0, 0, Config.MaxDeposit)
    local hours = WholeNumber(data.hours, Config.MinHours, Config.MaxHours)
    if not title or not details or not pay or not deposit or not hours then return false, 'invalid' end

    local item, quantity = '', 0
    if kind == 'supply' then
        quantity = WholeNumber(data.quantity, 1, Config.MaxQuantity)
        if not quantity or not Orderable(data.item) then return false, 'invalid_item' end
        item = data.item
    end

    local open = 0
    for _, c in pairs(Contracts) do
        if c.buyer_cid == Cid(Player) then open = open + 1 end
        if c.status == 'offered' and c.worker_cid == Cid(worker) and c.buyer_cid == Cid(Player) then
            return false, 'offer_pending'
        end
    end
    if open >= Config.MaxOpen then return false, 'too_many' end
    if not TakeCash(Player, pay, 'contract-payment-held') then return false, 'no_cash' end

    local c = {
        type = kind, status = 'offered', buyer_cid = Cid(Player), buyer_name = CharName(Player),
        worker_cid = Cid(worker), worker_name = CharName(worker), title = title, details = details,
        item = item, quantity = quantity, pay_cents = pay, deposit_cents = deposit, hours = hours,
        due_at = os.time() + math.floor(Config.OfferHours * 3600),
    }
    local ok, id = pcall(function()
        return MySQL.insert.await([[INSERT INTO rsg_contracts (type, status, buyer_cid, buyer_name, worker_cid, worker_name,
            title, details, item, quantity, pay_cents, deposit_cents, hours, due_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)]],
            { c.type, c.status, c.buyer_cid, c.buyer_name, c.worker_cid, c.worker_name, c.title, c.details,
              c.item, c.quantity, c.pay_cents, c.deposit_cents, c.hours, c.due_at })
    end)
    if not ok or not id then
        Player.Functions.AddMoney('cash', pay / 100, 'contract-payment-returned')
        return false, 'failed'
    end
    c.id = id
    Contracts[id] = c
    Save(Player)
    Notify(target, 'offer_received', 'inform', c.buyer_name, tostring(Config.Command or '-'))
    return true, 'offer_sent'
end

local function GivePaper(src, c)
    if not Config.PaperItem or not RSGCore.Shared.Items[Config.PaperItem] then return end
    if not exports['rsg-inventory']:CanAddItem(src, Config.PaperItem, 1) then return Notify(src, 'no_room_paper') end
    exports['rsg-inventory']:AddItem(src, Config.PaperItem, 1,
        { contractId = c.id, description = ('#%d %s'):format(c.id, c.title) }, nil, 'contract-signed')
end

function Actions.sign(src, Player, data, c)
    if c.status ~= 'offered' or c.worker_cid ~= Cid(Player) then return false, 'invalid' end
    if os.time() >= c.due_at then return false, 'expired' end
    local buyerSrc = Online(c.buyer_cid)
    if not buyerSrc or not Near(src, buyerSrc) then return false, 'buyer_not_near' end
    if not TakeCash(Player, c.deposit_cents, 'contract-deposit-held') then return false, 'no_cash' end
    local ok, done = pcall(SetStatus, c, 'active', os.time() + c.hours * 3600)
    if not ok or not done then
        if c.deposit_cents > 0 then Player.Functions.AddMoney('cash', c.deposit_cents / 100, 'contract-deposit-returned') end
        return false, 'failed'
    end
    Save(Player)
    GivePaper(src, c)
    GivePaper(buyerSrc, c)
    Notify(buyerSrc, 'signed_notice', 'success', c.worker_name, c.id)
    return true, 'signed'
end

function Actions.decline(_, Player, _, c)
    local cid = Cid(Player)
    if c.status ~= 'offered' or (cid ~= c.worker_cid and cid ~= c.buyer_cid) then return false, 'invalid' end
    if not Unwind(c, cid == c.buyer_cid and 'offer_withdrawn' or 'offer_declined') then return false, 'failed' end
    return true, 'done'
end

function Actions.deliver(src, Player, _, c)
    if c.status ~= 'active' or c.type ~= 'supply' or c.worker_cid ~= Cid(Player) then return false, 'invalid' end
    if os.time() >= c.due_at then return false, 'expired' end
    if not AtOffice(src) then return false, 'need_office' end

    local stacks = {}
    for key, it in pairs(Player.PlayerData.items or {}) do
        local quality = it and it.info and tonumber(it.info.quality)
        if it and it.name == c.item and (not quality or quality > 0) then
            stacks[#stacks + 1] = { slot = math.tointeger(tonumber(it.slot) or tonumber(key)), amount = it.amount, info = it.info or {} }
        end
    end
    table.sort(stacks, function(a, b) return a.slot < b.slot end)

    local need, plan = c.quantity, {}
    for _, s in ipairs(stacks) do
        if need <= 0 then break end
        local n = math.min(need, s.amount)
        plan[#plan + 1] = { slot = s.slot, amount = n, info = json.decode(json.encode(s.info)) or {} }
        need = need - n
    end
    if need > 0 then return false, 'not_enough_items' end

    local taken = {}
    local function GiveBack()
        for _, t in ipairs(taken) do
            if not exports['rsg-inventory']:AddItem(src, c.item, t.amount, t.info, nil, 'contract-delivery-returned') then
                print(('^1[rsg-contracts] could not return %dx %s to %s (contract #%d)^7'):format(t.amount, c.item, c.worker_cid, c.id))
            end
        end
    end
    for _, p in ipairs(plan) do
        if not exports['rsg-inventory']:RemoveItem(src, c.item, p.amount, p.slot, 'contract-delivery') then
            GiveBack()
            return false, 'failed'
        end
        taken[#taken + 1] = p
    end

    local claims = { Cash(c.worker_cid, c.pay_cents + c.deposit_cents) }
    for _, t in ipairs(taken) do
        claims[#claims + 1] = { cid = c.buyer_cid, item = c.item, amount = t.amount, info = t.info }
    end
    local ok, closed = pcall(Close, c, 'delivered', claims)
    if not ok or not closed then
        GiveBack()
        return false, 'failed'
    end
    Save(Player)
    Honor(c, c.worker_cid, Config.HonorCompleted)
    return true, 'delivered'
end

-- job: the worker says it is finished
function Actions.finish(_, Player, _, c)
    if c.status ~= 'active' or c.type ~= 'job' or c.worker_cid ~= Cid(Player) then return false, 'invalid' end
    if os.time() >= c.due_at then return false, 'expired' end
    if not SetStatus(c, 'review', os.time() + math.floor(Config.ReviewHours * 3600)) then return false, 'failed' end
    Tell(c.buyer_cid, 'review_notice', 'inform', c.id)
    return true, 'done'
end

-- the buyer is happy: allowed while active too
function Actions.approve(_, Player, _, c)
    if c.type ~= 'job' or (c.status ~= 'active' and c.status ~= 'review') or c.buyer_cid ~= Cid(Player) then
        return false, 'invalid'
    end
    if not PayWorker(c, 'approved') then return false, 'failed' end
    return true, 'done'
end

function Actions.dispute(_, Player, _, c)
    if c.status ~= 'review' or c.buyer_cid ~= Cid(Player) then return false, 'invalid' end
    if os.time() >= c.due_at then return false, 'expired' end
    if not SetStatus(c, 'disputed', os.time() + math.floor(Config.DisputeHours * 3600)) then return false, 'failed' end
    Tell(c.worker_cid, 'dispute_notice', 'error', c.id)
    for _, id in ipairs(GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(tonumber(id))
        if P and IsArbiter(P) then Notify(tonumber(id), 'dispute_new', 'inform', c.id) end
    end
    return true, 'done'
end

function Actions.giveup(_, Player, _, c)
    if c.status ~= 'active' or c.worker_cid ~= Cid(Player) then return false, 'invalid' end
    if not Broken(c, 'gave_up') then return false, 'failed' end
    return true, 'done'
end

-- both sides must ask before an active contract is cancelled
function Actions.cancel(_, Player, _, c)
    local cid = Cid(Player)
    if c.status ~= 'active' or (cid ~= c.worker_cid and cid ~= c.buyer_cid) then return false, 'invalid' end
    if c.cancel_by == cid then return false, 'cancel_waiting' end
    if c.cancel_by then
        if not Unwind(c, 'mutual_cancel') then return false, 'failed' end
        return true, 'done'
    end
    local n = MySQL.update.await('UPDATE rsg_contracts SET cancel_by = ? WHERE id = ?', { cid, c.id })
    if not n or n < 1 then return false, 'failed' end
    c.cancel_by = cid
    Tell(cid == c.buyer_cid and c.worker_cid or c.buyer_cid, 'cancel_request', 'inform', c.id)
    return true, 'cancel_sent'
end

function Actions.rule(_, Player, data, c)
    local cid = Cid(Player)
    if c.status ~= 'disputed' or not IsArbiter(Player) or cid == c.buyer_cid or cid == c.worker_cid then
        return false, 'invalid'
    end
    local ok
    if data.winner == 'worker' then ok = PayWorker(c, 'ruled_worker')
    elseif data.winner == 'buyer' then ok = Broken(c, 'ruled_buyer')
    else return false, 'invalid' end
    if not ok then return false, 'failed' end
    Log(('Contract #%d dispute decided for the %s by %s (%s)'):format(c.id, data.winner, CharName(Player), cid))
    return true, 'done'
end

function Actions.collect(src, Player)
    if not AtOffice(src) then return false, 'need_office' end
    local rows = MySQL.query.await('SELECT * FROM rsg_contract_claims WHERE citizenid = ? ORDER BY id', { Cid(Player) }) or {}
    if #rows == 0 then return false, 'nothing' end
    local left = 0
    for _, row in ipairs(rows) do
        local isItem = row.item and row.item ~= ''
        if isItem and not exports['rsg-inventory']:CanAddItem(src, row.item, row.amount) then
            left = left + 1
        -- delete first: a claim can never be paid twice
        elseif MySQL.update.await('DELETE FROM rsg_contract_claims WHERE id = ?', { row.id }) == 1 then
            local given
            if isItem then
                local info = row.info and json.decode(row.info) or nil
                if info and not next(info) then info = nil end
                given = exports['rsg-inventory']:AddItem(src, row.item, row.amount, info, nil, 'contract-collect')
            else
                given = Player.Functions.AddMoney('cash', row.cents / 100, 'contract-collect')
            end
            if not given then
                left = left + 1
                MySQL.insert.await('INSERT INTO rsg_contract_claims (citizenid, contract_id, cents, item, amount, info) VALUES (?,?,?,?,?,?)',
                    { row.citizenid, row.contract_id, row.cents, row.item or '', row.amount, row.info or '{}' })
            end
        end
    end
    Save(Player)
    if left > 0 then return false, 'collect_partial' end
    return true, 'collected'
end

--------------------------------------------------------------------------------
-- Data for the window
--------------------------------------------------------------------------------
local function ItemLabel(name)
    local def = RSGCore.Shared.Items[name]
    return def and def.label or name
end

local function View(c, cid)
    return {
        id = c.id, type = c.type, status = c.status, title = c.title, details = c.details,
        buyer = c.buyer_name, worker = c.worker_name,
        role = (cid == c.buyer_cid and 'buyer') or (cid == c.worker_cid and 'worker') or 'other',
        item = c.item ~= '' and c.item and ItemLabel(c.item) or nil, quantity = c.quantity,
        pay = c.pay_cents / 100, deposit = c.deposit_cents / 100, hours = c.hours,
        secondsLeft = math.max(0, c.due_at - os.time()),
        cancel = c.cancel_by and (c.cancel_by == cid and 'mine' or 'theirs') or nil,
    }
end

local function State(src, Player)
    local cid = Cid(Player)
    local arbiter = IsArbiter(Player)
    local mine, disputes = {}, {}
    for _, c in pairs(Contracts) do
        if c.buyer_cid == cid or c.worker_cid == cid then
            mine[#mine + 1] = View(c, cid)
        elseif arbiter and c.status == 'disputed' then
            disputes[#disputes + 1] = View(c, cid)
        end
    end
    local function ById(a, b) return a.id > b.id end
    table.sort(mine, ById)
    table.sort(disputes, ById)
    local claims = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_contract_claims WHERE citizenid = ? ORDER BY id', { cid }) or {}) do
        local isItem = row.item and row.item ~= ''
        claims[#claims + 1] = {
            contract = row.contract_id, cash = not isItem and row.cents / 100 or nil,
            item = isItem and ItemLabel(row.item) or nil, amount = row.amount,
        }
    end
    local nearby = {}
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        if other ~= src and Near(src, other) then
            local P = Usable(other)
            -- server id only: names are shown once an offer exists, so strangers stay anonymous
            if P then nearby[#nearby + 1] = other end
        end
    end
    return { contracts = mine, disputes = disputes, arbiter = arbiter, claims = claims, atOffice = AtOffice(src), nearby = nearby }
end

local function Throttled(src, key, ms)
    local now = GetGameTimer()
    Cooldown[src] = Cooldown[src] or {}
    if Cooldown[src][key] and now - Cooldown[src][key] < ms then return true end
    Cooldown[src][key] = now
    return false
end

RSGCore.Functions.CreateCallback('rsg-contracts:server:getState', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Ready or not Player or Throttled(source, 'state', 250) then return cb(nil) end
    cb(State(source, Player))
end)

-- the item list is only needed when writing a supply order
RSGCore.Functions.CreateCallback('rsg-contracts:server:getItems', function(source, cb)
    if Throttled(source, 'items', 2000) then return cb(nil) end
    local list = {}
    for name, def in pairs(RSGCore.Shared.Items) do
        if Orderable(name) then list[#list + 1] = { value = name, label = def.label or name } end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    cb(list)
end)

-- details printed on a paper copy: only for someone holding that paper
RSGCore.Functions.CreateCallback('rsg-contracts:server:getPaper', function(source, cb, id)
    local Player = RSGCore.Functions.GetPlayer(source)
    id = math.tointeger(tonumber(id))
    if not Ready or not Player or not id or Throttled(source, 'paper', 500) then return cb(nil) end
    local holds = false
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and it.name == Config.PaperItem and it.info and tonumber(it.info.contractId) == id then holds = true break end
    end
    if not holds then return cb(nil) end
    local c = Contracts[id] or MySQL.single.await('SELECT * FROM rsg_contracts WHERE id = ?', { id })
    if not c then return cb(nil) end
    local view = View(c, '')
    view.outcome = c.outcome
    if not Contracts[id] then view.status = 'closed' end
    cb(view)
end)

RSGCore.Functions.CreateCallback('rsg-contracts:server:action', function(source, cb, name, data)
    local handler = type(name) == 'string' and rawget(Actions, name)
    if not Ready or not handler or Throttled(source, 'action', 750) then return cb({ ok = false }) end
    data = type(data) == 'table' and data or {}
    local ok, key = Locked(function()
        -- fetched inside the lock so the data is current
        local Player = Usable(source)
        if not Player then return false, 'invalid' end
        local c
        if name ~= 'create' and name ~= 'collect' then
            c = Contracts[math.tointeger(tonumber(data.id)) or -1]
            if not c then return false, 'gone' end
        end
        return handler(source, Player, data, c)
    end)
    if key then Notify(source, key, ok and 'success' or 'error') end
    local Player = RSGCore.Functions.GetPlayer(source)
    cb({ ok = ok == true, state = Player and State(source, Player) or nil })
end)

if Config.PaperItem then
    RSGCore.Functions.CreateUseableItem(Config.PaperItem, function(source, item)
        local id = item and item.info and item.info.contractId
        if id then TriggerClientEvent('rsg-contracts:client:paper', source, id) end
    end)
end

AddEventHandler('playerDropped', function() Cooldown[source] = nil end)

MySQL.ready(function()
    CreateThread(function()
        if Config.AutoDatabase and not EnsureDatabase() then return end
        local rows = MySQL.query.await("SELECT * FROM rsg_contracts WHERE status <> 'closed'")
        if not rows then return end
        for _, row in ipairs(rows) do
            row.due_at = tonumber(row.due_at)
            row.item = row.item or ''
            Contracts[row.id] = row
        end
        Ready = true
        while true do
            local now = os.time()
            local due = {}
            for id, c in pairs(Contracts) do
                if now >= c.due_at then due[#due + 1] = id end
            end
            for _, id in ipairs(due) do
                Locked(function()
                    local c = Contracts[id]
                    if c and os.time() >= c.due_at then Expire(c) end
                    return true
                end)
            end
            Wait(30000)
        end
    end)
end)
