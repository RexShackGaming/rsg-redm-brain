local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Labs = {}        -- [citizenid] = lab data
local Dirty = {}       -- [citizenid] = true when needs saving
local Candidates = {}  -- [citizenid] = { list = {}, at = os.time() }
local Cooldown = {}
local Viewing = {}     -- [src] = true while the lab UI is open (only those get tick refreshes)

---------------------------------
-- helpers
---------------------------------
local function round(n) return math.floor(n * 100 + 0.5) / 100 end

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = desc, type = ntype or 'inform' })
end

local function newLab()
    return {
        stock = { raw = 0, dried = 0, processed = 0, brick = 0, bag = 0, seed = 0 },
        progress = { dryer = 0.0, processor = 0.0, bag = 0.0, brick = 0.0 },
        pantry = { food = 0, water = 0 },
        payroll = 0.0,
        employees = {},
        nextId = 1,
    }
end

-- older saves are missing packer fields
local function migrateLab(lab)
    local base = newLab()
    for k, v in pairs(base.stock) do lab.stock[k] = lab.stock[k] or v end
    for k, v in pairs(base.progress) do lab.progress[k] = lab.progress[k] or v end
    for _, e in ipairs(lab.employees) do
        if e.role == 'packer' and not Config.Packing[e.pack or ''] then e.pack = 'bag' end
    end
    return lab
end

local function getLab(cid)
    if Labs[cid] then return Labs[cid] end
    local row = MySQL.single.await('SELECT data FROM rsg_drugs_labs WHERE citizenid = ?', { cid })
    local data = row and json.decode(row.data)
    Labs[cid] = migrateLab(type(data) == 'table' and data or newLab())
    return Labs[cid]
end

local function saveLab(cid)
    if not Labs[cid] then return end
    MySQL.insert.await('INSERT INTO rsg_drugs_labs (citizenid, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { cid, json.encode(Labs[cid]) })
    Dirty[cid] = nil
end

local function makeCandidate()
    local skill = math.random(1, 5)
    local roles = { 'dryer', 'processor', 'packer' }
    return {
        name  = Config.FirstNames[math.random(#Config.FirstNames)] .. ' ' .. Config.LastNames[math.random(#Config.LastNames)],
        role  = roles[math.random(#roles)],
        skill = skill,
        wage  = Config.Skill[skill].wage,
        rate  = Config.Skill[skill].rate,
    }
end

local function getCandidates(cid)
    local c = Candidates[cid]
    if not c or os.time() - c.at > Config.CandidateRefreshMinutes * 60 then
        c = { list = {}, at = os.time() }
        for i = 1, Config.CandidateCount do c.list[i] = makeCandidate() end
        Candidates[cid] = c
    end
    return c.list
end

local NpcPos = vector3(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)

local function nearLab(src)
    local dist = #(GetEntityCoords(GetPlayerPed(src)) - NpcPos)
    if dist <= Config.NPC.interactDistance + 2.0 then return true end
    notify(src, locale('too_far'), 'error')
    DrugsLog('security', 'Lab request out of range', src, { { 'Distance', ('%.1fm'):format(dist) } })
    return false
end

-- validates player + distance + cooldown, returns Player, cid, lab
local function validate(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local now = GetGameTimer()
    if Cooldown[src] and now - Cooldown[src] < 300 then return end
    Cooldown[src] = now
    if not nearLab(src) then return end
    local cid = Player.PlayerData.citizenid
    return Player, cid, getLab(cid)
end

local NextTick = os.time() + Config.TickSeconds

local function buildPayload(cid)
    local lab = getLab(cid)
    local Owner = RSGCore.Functions.GetPlayerByCitizenId(cid)
    return {
        lab = lab,
        xp = Config.XP.Enabled and Owner and DrugsXP.Info(Owner) or nil,
        brickLock = (not lab.canBrick) and DrugsXP.BrickLevelLabel() or nil,
        candidates = getCandidates(cid),
        config = {
            maxEmployees = Config.MaxEmployees, maxStorage = Config.MaxStorage,
            hireFee = Config.HireFee, tick = Config.TickSeconds,
            skills = Config.Skill, roles = Config.Roles,
            items = Config.Items, packing = Config.Packing, seedChance = Config.SeedChance,
        },
        nextTickIn = math.max(0, NextTick - os.time()),
    }
end

local function countItem(src, name)
    return exports['rsg-inventory']:GetItemCount(src, name) or 0
end

local function itemLabel(name)
    local it = RSGCore.Shared.Items[name]
    return it and it.label or name
end

---------------------------------
-- callbacks
---------------------------------
lib.callback.register('rsg-drugs:server:getLab', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not nearLab(src) then return end
    local cid = Player.PlayerData.citizenid
    local lab = getLab(cid)
    Viewing[src] = true
    -- pay XP banked while the owner was offline
    if (lab.pendingXp or 0) > 0 then
        local xp = lab.pendingXp
        lab.pendingXp = 0
        Dirty[cid] = true
        DrugsXP.Add(src, xp, 'produce')
    end
    lab.canBrick = DrugsXP.CanPackBricks(Player)
    return buildPayload(cid)
end)

RegisterNetEvent('rsg-drugs:server:closed', function() Viewing[source] = nil end)

lib.callback.register('rsg-drugs:server:action', function(src, action, data)
    local Player, cid, lab = validate(src)
    if not Player then return end
    data = type(data) == 'table' and data or {}

    if action == 'hire' then
        local idx = tonumber(data.index)
        local list = getCandidates(cid)
        local cand = idx and list[idx]
        -- the list may have refreshed since the UI rendered: never hire (and charge for) someone else
        if not cand or (data.name and data.name ~= cand.name) then
            if cand == nil and idx then DrugsLog('security', 'Hire: invalid candidate index', src, { { 'Index', idx } }) end
            return buildPayload(cid)
        end
        if #lab.employees >= Config.MaxEmployees then notify(src, locale('max_staff'), 'error') return buildPayload(cid) end
        if not Player.Functions.RemoveMoney('cash', Config.HireFee, 'rsg-drugs-hire') then
            notify(src, locale('no_money'), 'error') return buildPayload(cid)
        end
        lab.employees[#lab.employees + 1] = {
            id = lab.nextId, name = cand.name, role = cand.role, skill = cand.skill,
            wage = cand.wage, rate = cand.rate, hunger = 100, thirst = 100, unpaid = 0, strike = false,
            pack = cand.role == 'packer' and 'bag' or nil,
        }
        lab.nextId = lab.nextId + 1
        table.remove(list, idx)
        list[#list + 1] = makeCandidate()
        notify(src, locale('hired', cand.name), 'success')
        DrugsLog('lab', 'Worker hired', src, { { 'Worker', cand.name }, { 'Role', Config.Roles[cand.role].label }, { 'Skill', Config.Skill[cand.skill].label }, { 'Wage', ('$%.2f/shift'):format(cand.wage) }, { 'Fee', ('$%.2f'):format(Config.HireFee) }, { 'Crew', ('%d/%d'):format(#lab.employees, Config.MaxEmployees) } })

    elseif action == 'fire' then
        local id = tonumber(data.id)
        for i, e in ipairs(lab.employees) do
            if e.id == id then
                table.remove(lab.employees, i)
                notify(src, locale('fired', e.name), 'inform')
                DrugsLog('lab', 'Worker fired', src, { { 'Worker', e.name }, { 'Role', Config.Roles[e.role] and Config.Roles[e.role].label or e.role }, { 'Owed shifts', e.unpaid or 0 } })
                break
            end
        end

    elseif action == 'assign' then
        -- packers: choose what they pack
        local id, pack = tonumber(data.id), tostring(data.pack or '')
        if not Config.Packing[pack] then return buildPayload(cid) end
        if pack == 'brick' and not DrugsXP.CanPackBricks(Player) then
            notify(src, locale('brick_level_locked', DrugsXP.BrickLevelLabel()), 'error')
            return buildPayload(cid)
        end
        for _, e in ipairs(lab.employees) do
            if e.id == id and e.role == 'packer' and e.pack ~= pack then
                e.pack = pack
                DrugsLog('lab', 'Packer reassigned', src, { { 'Worker', e.name }, { 'Now packing', Config.Packing[pack].label } })
                break
            end
        end

    elseif action == 'deposit' then
        -- kind: raw | food | water
        local amount = math.floor(tonumber(data.amount) or 0)
        if amount < 1 or amount > 1000 then return buildPayload(cid) end
        if data.kind == 'raw' then
            if lab.stock.raw + amount > Config.MaxStorage then notify(src, locale('storage_full'), 'error') return buildPayload(cid) end
            if countItem(src, Config.Items.raw) < amount then notify(src, locale('no_item'), 'error') return buildPayload(cid) end
            if not exports['rsg-inventory']:RemoveItem(src, Config.Items.raw, amount, nil, 'rsg-drugs-deposit') then return buildPayload(cid) end
            lab.stock.raw = lab.stock.raw + amount
            notify(src, locale('deposited', amount, itemLabel(Config.Items.raw)), 'success')
            if amount >= ConfigDiscord.MinDeposit then DrugsLog('lab', 'Weed deposited', src, { { 'Item', itemLabel(Config.Items.raw) }, { 'Amount', amount }, { 'Lab stock', lab.stock.raw } }) end
        elseif data.kind == 'food' or data.kind == 'water' then
            local tbl = data.kind == 'food' and Config.Food or Config.Water
            local item = tostring(data.item or '')
            local value = tbl[item]
            if not value then return buildPayload(cid) end
            if lab.pantry[data.kind] + amount * value > Config.MaxStorage then notify(src, locale('storage_full'), 'error') return buildPayload(cid) end
            if countItem(src, item) < amount then notify(src, locale('no_item'), 'error') return buildPayload(cid) end
            if not exports['rsg-inventory']:RemoveItem(src, item, amount, nil, 'rsg-drugs-pantry') then return buildPayload(cid) end
            lab.pantry[data.kind] = lab.pantry[data.kind] + amount * value
            notify(src, locale('deposited', amount, itemLabel(item)), 'success')
            if amount >= ConfigDiscord.MinDeposit then DrugsLog('lab', 'Pantry stocked', src, { { 'Item', itemLabel(item) }, { 'Amount', amount }, { 'Pantry ' .. data.kind, lab.pantry[data.kind] } }) end
        end

    elseif action == 'withdraw' then
        local kind = data.kind
        if kind ~= 'dried' and kind ~= 'processed' and kind ~= 'brick' and kind ~= 'bag' and kind ~= 'seed' then return buildPayload(cid) end
        local amount = math.floor(tonumber(data.amount) or 0)
        amount = math.min(amount, lab.stock[kind])
        if amount < 1 then return buildPayload(cid) end
        local item = Config.Items[kind]
        if not exports['rsg-inventory']:CanAddItem(src, item, amount) then notify(src, locale('inv_full'), 'error') return buildPayload(cid) end
        -- only take stock out of the lab once the item actually landed in the inventory
        if not exports['rsg-inventory']:AddItem(src, item, amount, nil, nil, 'rsg-drugs-withdraw') then
            notify(src, locale('inv_full'), 'error') return buildPayload(cid)
        end
        lab.stock[kind] = lab.stock[kind] - amount
        notify(src, locale('withdrew', amount, itemLabel(item)), 'success')
        if amount >= ConfigDiscord.MinWithdraw then DrugsLog('lab', 'Product collected', src, { { 'Item', itemLabel(item) }, { 'Amount', amount }, { 'Left in lab', lab.stock[kind] } }) end

    elseif action == 'payroll' then
        local amount = round(tonumber(data.amount) or 0)
        if amount <= 0 or amount > 10000 then return buildPayload(cid) end
        if not Player.Functions.RemoveMoney('cash', amount, 'rsg-drugs-payroll') then
            notify(src, locale('no_money'), 'error') return buildPayload(cid)
        end
        lab.payroll = round(lab.payroll + amount)
        notify(src, locale('paid', amount), 'success')
        DrugsLog('lab', 'Payroll funded', src, { { 'Added', ('$%.2f'):format(amount) }, { 'Wage chest', ('$%.2f'):format(lab.payroll) } })
    end

    Dirty[cid] = true
    return buildPayload(cid)
end)

-- player's pantry options (items they actually hold)
lib.callback.register('rsg-drugs:server:getSupplies', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local out = { raw = countItem(src, Config.Items.raw), food = {}, water = {} }
    for item, value in pairs(Config.Food) do
        local c = countItem(src, item)
        if c > 0 then out.food[#out.food + 1] = { item = item, label = itemLabel(item), count = c, value = value } end
    end
    for item, value in pairs(Config.Water) do
        local c = countItem(src, item)
        if c > 0 then out.water[#out.water + 1] = { item = item, label = itemLabel(item), count = c, value = value } end
    end
    return out
end)

---------------------------------
-- work loop
---------------------------------
-- jail wipes drug XP: also drop XP the lab banked for that owner
DrugsXP.OnReset = function(cid)
    local lab = Labs[cid]
    if lab and (lab.pendingXp or 0) > 0 then lab.pendingXp = 0; Dirty[cid] = true end
end

local function tickLab(cid, lab)
    if #lab.employees == 0 then return end
    local Owner = RSGCore.Functions.GetPlayerByCitizenId(cid)
    local src = Owner and Owner.PlayerData.source
    local output = { dryer = 0.0, processor = 0.0 }
    local packOut = { bag = 0.0, brick = 0.0 }
    local made = {} -- [stock key] = units finished this tick (for XP)
    -- brick packing needs the owner's level; offline owners use the last known value
    if Owner then lab.canBrick = DrugsXP.CanPackBricks(Owner) end

    for _, e in ipairs(lab.employees) do
        -- needs
        e.hunger = math.max(0, e.hunger - Config.HungerDrain)
        e.thirst = math.max(0, e.thirst - Config.ThirstDrain)
        while e.hunger < Config.AutoFeedBelow and lab.pantry.food > 0 do
            lab.pantry.food = lab.pantry.food - 1
            e.hunger = math.min(100, e.hunger + Config.MealRestore)
        end
        while e.thirst < Config.AutoFeedBelow and lab.pantry.water > 0 do
            lab.pantry.water = lab.pantry.water - 1
            e.thirst = math.min(100, e.thirst + Config.DrinkRestore)
        end
        -- wages (back pay owed included)
        local owed = e.wage * (1 + e.unpaid)
        if lab.payroll >= owed then
            lab.payroll = round(lab.payroll - owed)
            e.unpaid = 0
        elseif lab.payroll >= e.wage then
            lab.payroll = round(lab.payroll - e.wage)
        else
            e.unpaid = e.unpaid + 1
        end

        local unhappy = e.hunger <= 0 or e.thirst <= 0 or e.unpaid >= Config.UnpaidStrikeTicks
        if unhappy and not e.strike then
            e.strike = true
            if src then notify(src, locale('strike', e.name), 'warning') end
        elseif not unhappy and e.strike and e.unpaid == 0 then
            e.strike = false
            if src then notify(src, locale('strike_end', e.name), 'success') end
        end

        if not e.strike then
            -- tired/hungry staff work slower
            local mood = (e.hunger < 25 or e.thirst < 25 or e.unpaid > 0) and 0.5 or 1.0
            if e.role == 'packer' then
                local p = Config.Packing[e.pack or ''] and e.pack or 'bag'
                packOut[p] = packOut[p] + e.rate * mood
            else
                output[e.role] = output[e.role] + e.rate * mood
            end
        end
    end

    for role, amount in pairs(output) do
        local r = Config.Roles[role]
        lab.progress[role] = (lab.progress[role] or 0) + amount
        local whole = math.floor(lab.progress[role])
        whole = math.min(whole, lab.stock[r.from], Config.MaxStorage - lab.stock[r.to])
        if whole > 0 then
            lab.stock[r.from] = lab.stock[r.from] - whole
            lab.stock[r.to] = lab.stock[r.to] + whole
            lab.progress[role] = lab.progress[role] - whole
            made[r.to] = (made[r.to] or 0) + whole
            -- drying can turn up a seed now and then
            if role == 'dryer' and (Config.SeedChance or 0) > 0 then
                local found = 0
                for _ = 1, whole do
                    if math.random() * 100 < Config.SeedChance then found = found + 1 end
                end
                found = math.min(found, Config.MaxStorage - lab.stock.seed)
                if found > 0 then lab.stock.seed = lab.stock.seed + found end
            end
        end
        -- don't bank progress when there's nothing to work on
        if lab.stock[r.from] == 0 then lab.progress[role] = math.min(lab.progress[role], 1.0) end
    end

    if not lab.canBrick then packOut.brick = 0 end -- brick packers sit idle until the owner levels up

    -- packing: work points build progress, each finished unit consumes `uses` processed weed
    for prod, work in pairs(packOut) do
        local pk = Config.Packing[prod]
        if work > 0 and lab.stock.processed >= pk.uses then
            lab.progress[prod] = (lab.progress[prod] or 0) + work / pk.work
            local whole = math.floor(lab.progress[prod])
            whole = math.min(whole, math.floor(lab.stock.processed / pk.uses), Config.MaxStorage - lab.stock[prod])
            if whole > 0 then
                lab.stock.processed = lab.stock.processed - whole * pk.uses
                lab.stock[prod] = lab.stock[prod] + whole
                lab.progress[prod] = lab.progress[prod] - whole
                made[prod] = (made[prod] or 0) + whole
            end
            if lab.stock.processed < pk.uses then lab.progress[prod] = math.min(lab.progress[prod], 0.99) end
        end
    end

    -- production XP (one notification per tick)
    if Config.XP.Enabled then
        local xp = 0
        for k, n in pairs(made) do xp = xp + n * (Config.XP.Produce[k] or 0) end
        if xp > 0 then
            if src then DrugsXP.Add(src, xp, 'produce')
            else lab.pendingXp = (lab.pendingXp or 0) + xp end
        end
    end

    Dirty[cid] = true
    if src and Viewing[src] then TriggerClientEvent('rsg-drugs:client:refresh', src, buildPayload(cid)) end
end

CreateThread(function()
    -- build the database table automatically if it doesn't exist
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_drugs_labs` (
            `citizenid` VARCHAR(50) NOT NULL,
            `data` LONGTEXT NOT NULL,
            PRIMARY KEY (`citizenid`)
        )
    ]])
    -- load every lab so production runs while owners are offline
    local rows = MySQL.query.await('SELECT citizenid, data FROM rsg_drugs_labs') or {}
    for _, r in ipairs(rows) do
        local data = json.decode(r.data)
        -- don't overwrite a lab a player already opened (and changed) while this was loading
        if not Labs[r.citizenid] and type(data) == 'table' then Labs[r.citizenid] = migrateLab(data) end
    end
    while true do
        Wait(Config.TickSeconds * 1000)
        NextTick = os.time() + Config.TickSeconds -- set before ticking so refresh payloads carry the new countdown
        for cid, lab in pairs(Labs) do tickLab(cid, lab) end
        for cid in pairs(Dirty) do saveLab(cid) end
    end
end)

AddEventHandler('playerDropped', function() Cooldown[source] = nil; Viewing[source] = nil end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for cid in pairs(Dirty) do saveLab(cid) end
end)
