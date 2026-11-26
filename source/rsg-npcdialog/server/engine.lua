-- Requirement checks and cost / reward application. Server only.
Engine = { Conditions = {} }

local RSGCore = exports['rsg-core']:GetCoreObject()
local warned = {}

local function started(res)
    if GetResourceState(res) == 'started' then return true end
    if not warned[res] then
        warned[res] = true
        print(('^3[rsg-npcdialog] a dialog uses %s but it is not started^7'):format(res))
    end
    return false
end

local function itemLabel(name)
    local s = RSGCore.Shared.Items[name]
    return s and s.label or name
end

local function totals(entries, key)
    local out = {}
    for _, e in ipairs(entries or {}) do out[e[key]] = (out[e[key]] or 0) + e.amount end
    return out
end

local function hasItems(src, entries)
    for name, amount in pairs(totals(entries, 'name')) do
        if (exports['rsg-inventory']:GetItemCount(src, name) or 0) < amount then
            return false, locale('req_item', amount, itemLabel(name))
        end
    end
    return true
end

local function hasMoney(Player, entries)
    for mtype, amount in pairs(totals(entries, 'type')) do
        if (Player.Functions.GetMoney(mtype) or 0) < amount then
            return false, locale('req_money', amount, locale('money_' .. mtype))
        end
    end
    return true
end

local function inRange(v, rule)
    return v ~= nil and (rule.min == nil or v >= rule.min) and (rule.max == nil or v <= rule.max)
end

local function meets(src, Player, progress, r, npcId)
    local data = Player.PlayerData

    for _, kind in ipairs({ 'job', 'gang' }) do
        if r[kind] then
            local cur = data[kind]
            local min = cur and r[kind][cur.name]
            local level = cur and cur.grade and tonumber(cur.grade.level) or 0
            if not min or level < min then return false, locale('req_' .. kind) end
        end
    end
    if r.onduty and not (data.job and data.job.onduty) then return false, locale('req_onduty') end
    if r.anyJob then -- any job the player holds, not only the current one
        local pass = false
        for name, min in pairs(r.anyJob) do
            local called, held, grade = pcall(function() return exports['rsg-core']:HasPlayerJob(src, name) end)
            if called and held and (tonumber(grade) or 0) >= min then pass = true break end
        end
        if not pass then return false, locale('req_job') end
    end
    for _, q in ipairs(r.quests or {}) do
        local state = Quests.State(src, Player, progress, q.id)
        local pass = state == q.state
        if q.state == 'active' then pass = state == 'active' or state == 'ready' end
        if q.state == 'completed' then pass = state ~= nil and Quests.EverCompleted(Player, q.id) end
        if q.state == 'notcompleted' then pass = state ~= nil and not Quests.EverCompleted(Player, q.id) end
        if not pass then return false, locale('req_unavailable') end
    end

    for _, f in ipairs(r.flags or {}) do
        if not progress.flag[f] then return false, locale('req_unavailable') end
    end
    for _, f in ipairs(r.notFlags or {}) do
        if progress.flag[f] then return false, locale('req_unavailable') end
    end

    if r.time then
        local hour = World.Hour()
        if not hour or not World.InHours(hour, r.time.from, r.time.to) then
            return false, locale('req_time', ('%02d:00'):format(r.time.from), ('%02d:00'):format(r.time.to))
        end
    end
    if r.weather then
        local now, pass = World.Weather(), false
        for _, w in ipairs(r.weather) do
            if w == now then pass = true break end
        end
        if not pass then return false, locale('req_weather') end
    end

    local ok, why = hasMoney(Player, r.money)
    if not ok then return false, why end
    ok, why = hasItems(src, r.items)
    if not ok then return false, why end

    for _, s in ipairs(r.skills or {}) do
        if not started('rsg-skills') or not exports['rsg-skills']:HasLevel(src, s.skill, s.level) then
            return false, locale('req_skill', s.skill, s.level)
        end
    end
    if r.honor then
        if not started('rsg-reputation') or not inRange(exports['rsg-reputation']:GetHonor(src), r.honor) then
            return false, locale('req_honor')
        end
    end
    for _, s in ipairs(r.standing or {}) do
        if not started('rsg-reputation') or not inRange(exports['rsg-reputation']:GetStanding(src, s.region), s) then
            return false, locale('req_standing')
        end
    end

    for _, c in ipairs(r.custom or {}) do
        local fn = Engine.Conditions[c.name]
        if not fn then return false, locale('req_unavailable') end
        local called, pass, reason = pcall(fn.cb, src, c.arg, npcId)
        if not called or pass ~= true then
            return false, (called and type(reason) == 'string') and reason or locale('req_unavailable')
        end
    end
    return true
end

---Fails closed: a missing resource, condition, progress table or an erroring export means "not met".
---@return boolean ok, string|nil reason
function Engine.Meets(src, Player, progress, r, npcId)
    if not r then return true end
    local called, ok, why = pcall(meets, src, Player, progress, r, npcId)
    if not called then
        print('^1[rsg-npcdialog] requirement check failed: ' .. tostring(ok) .. '^7')
        return false, locale('req_unavailable')
    end
    return ok, why
end

-- with money items on, cash is carried in the inventory: rsg-core cannot report a failed delivery,
-- so check there is room before paying
local MONEY_ITEMS = { cash = { 'dollar', 'cent' }, bloodmoney = { 'blood_dollar', 'blood_cent' } }

local function canCarryMoney(src, entries)
    local money, gold = RSGCore.Config.Money, RSGCore.Config.Gold
    for mtype, amount in pairs(totals(entries, 'type')) do
        local names = money and money.EnableMoneyItems and MONEY_ITEMS[mtype]
        if mtype == 'gold' and gold and gold.EnableGoldItems then
            if not exports['rsg-inventory']:CanAddItem(src, money.GoldItem, amount) then return false end
        elseif names then
            local cents = math.floor(amount * 100 + 0.5)
            local parts = { cents // 100, cents % 100 }
            for i, name in ipairs(names) do
                if parts[i] > 0 and not exports['rsg-inventory']:CanAddItem(src, name, parts[i]) then return false end
            end
        end
    end
    return true
end

---Takes the costs and gives item / money rewards as one step: if anything fails, it is all undone.
---@return boolean ok, string|nil reason
function Engine.Transact(src, Player, cost, reward, reason)
    cost, reward = cost or {}, reward or {}

    -- reject bad item names before anything is taken
    for _, group in ipairs({ cost.items or {}, reward.items or {} }) do
        for _, it in ipairs(group) do
            if not RSGCore.Shared.Items[it.name] then
                print(('^1[rsg-npcdialog] unknown item "%s" in a dialog^7'):format(it.name))
                return false, locale('sv_failed')
            end
        end
    end

    local ok, why = hasMoney(Player, cost.money)
    if not ok then return false, why end
    ok, why = hasItems(src, cost.items)
    if not ok then return false, why end

    local undo = {}
    local function rollback(msg)
        for i = #undo, 1, -1 do undo[i]() end
        return false, msg
    end

    for _, m in ipairs(cost.money or {}) do
        if not Player.Functions.RemoveMoney(m.type, m.amount, reason) then return rollback(locale('sv_failed')) end
        undo[#undo + 1] = function() Player.Functions.AddMoney(m.type, m.amount, reason .. '-refund') end
    end
    for _, it in ipairs(cost.items or {}) do
        if not exports['rsg-inventory']:RemoveItem(src, it.name, it.amount, nil, reason) then return rollback(locale('sv_failed')) end
        undo[#undo + 1] = function() exports['rsg-inventory']:AddItem(src, it.name, it.amount, nil, nil, reason .. '-refund') end
    end
    -- checked after the costs are removed, so the space they free counts
    for name, amount in pairs(totals(reward.items, 'name')) do
        if not exports['rsg-inventory']:CanAddItem(src, name, amount) then return rollback(locale('sv_inventory_full')) end
    end
    for _, it in ipairs(reward.items or {}) do
        if not exports['rsg-inventory']:AddItem(src, it.name, it.amount, nil, nil, reason) then
            return rollback(locale('sv_inventory_full'))
        end
        undo[#undo + 1] = function() exports['rsg-inventory']:RemoveItem(src, it.name, it.amount, nil, reason .. '-refund') end
    end
    if not canCarryMoney(src, reward.money) then return rollback(locale('sv_inventory_full')) end
    for _, m in ipairs(reward.money or {}) do
        if not Player.Functions.AddMoney(m.type, m.amount, reason) then return rollback(locale('sv_failed')) end
        undo[#undo + 1] = function() Player.Functions.RemoveMoney(m.type, m.amount, reason .. '-refund') end
    end
    return true
end

-- a broken optional resource must not stop the rest of a reply being saved
local function award(fn)
    local ok, err = pcall(fn)
    if not ok then print('^1[rsg-npcdialog] skill / reputation reward failed: ' .. tostring(err) .. '^7') end
end

---Skill XP and reputation. Run after a successful Transact.
function Engine.Progression(src, reward, reason)
    if not reward then return end
    if reward.skillXP and started('rsg-skills') then
        for _, s in ipairs(reward.skillXP) do
            award(function() exports['rsg-skills']:AddXP(src, s.skill, s.amount, reason) end)
        end
    end
    if (reward.honor or reward.standing) and started('rsg-reputation') then
        if reward.honor then
            award(function() exports['rsg-reputation']:AddHonor(src, reward.honor, reason) end)
        end
        for _, s in ipairs(reward.standing or {}) do
            award(function() exports['rsg-reputation']:AddStanding(src, s.region, s.amount, reason) end)
        end
    end
end
