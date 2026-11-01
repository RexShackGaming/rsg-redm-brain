local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']

-- Active smelt jobs keyed by server id: { recipe, amount, smelter, propCoords, startedAt, duration, citizenid }
local pending = {}
-- Jobs interrupted by a disconnect, refunded when the character logs back in (keyed by citizenid)
local owed = {}

local function itemLabel(item)
    local def = RSGCore.Shared.Items[item]
    return def and def.label or item
end

local function itemBox(src, item, action, amount)
    local def = RSGCore.Shared.Items[item]
    if def then TriggerClientEvent('rsg-inventory:client:ItemBox', src, def, action, amount) end
end

-- Unique list of every input item, used for UI counts
local oreList = {}
do
    local seen = {}
    for _, r in ipairs(Config.Recipes) do
        for _, inp in ipairs(r.inputs) do
            if not seen[inp.item] then
                seen[inp.item] = true
                oreList[#oreList + 1] = inp.item
            end
        end
    end
end

local function itemCount(Player, item)
    local total = 0
    for _, v in pairs(Player.PlayerData.items or {}) do
        if v and v.name == item then total = total + (v.amount or 0) end
    end
    return total
end

local function normaliseSmelter(smelterIndex)
    if smelterIndex == 'prop' then return 'prop' end
    local i = tonumber(smelterIndex)
    return (i and Config.Smelters[i]) and i or nil
end

local function nearSmelter(src, smelter, propCoords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)

    if smelter == 'prop' then
        -- World props aren't networked, so the reported prop position is checked
        -- against the player's real server-side position.
        if not Config.SmeltProps.enabled or type(propCoords) ~= 'vector3' and type(propCoords) ~= 'table' then return false end
        local x, y, z = tonumber(propCoords.x), tonumber(propCoords.y), tonumber(propCoords.z)
        if not (x and y and z) then return false end
        local reported = vector3(x, y, z)
        -- If the server lists its prop locations, the reported prop must be one of them
        local allowed = Config.SmeltProps.locations
        if allowed and #allowed > 0 then
            local match = false
            for _, loc in ipairs(allowed) do
                if #(reported - loc.xyz) <= (Config.SmeltProps.locationTolerance or 2.0) then match = true break end
            end
            if not match then return false end
        end
        return #(pos - reported) <= Config.MaxUseDistance
    end

    local data = Config.Smelters[smelter]
    return data and #(pos - data.coords.xyz) <= Config.MaxUseDistance or false
end

---------------------------------------------------------------------
-- Persistence (survives restarts and crashes): owed items + live jobs
---------------------------------------------------------------------
-- Stored in MySQL (oxmysql) instead of resource KVP, so no server "db" folder is created
local stateLoaded = false

local function saveState()
    if not stateLoaded then return end -- don't overwrite saved state before it has been loaded
    local live = {}
    for _, job in pairs(pending) do
        live[#live + 1] = { citizenid = job.citizenid, recipeIndex = job.recipeIndex, amount = job.amount, info = job.info }
    end
    MySQL.prepare('INSERT INTO rsg_smelting_state (id, data) VALUES (1, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { json.encode({ owed = owed, live = live }) })
end

local function addOwed(citizenid, item, amount)
    if not citizenid then return end
    owed[citizenid] = owed[citizenid] or {}
    table.insert(owed[citizenid], { item = item, amount = amount })
end

local function oweJobInputs(citizenid, job)
    for _, inp in ipairs(job.recipe.inputs) do
        addOwed(citizenid, inp.item, inp.amount * job.amount)
    end
end

-- Load at start: any job still "live" was interrupted by a crash/kill -> owe its inputs
MySQL.ready(function()
    MySQL.query.await('CREATE TABLE IF NOT EXISTS rsg_smelting_state (id TINYINT UNSIGNED NOT NULL PRIMARY KEY, data LONGTEXT NOT NULL)')
    local raw = MySQL.scalar.await('SELECT data FROM rsg_smelting_state WHERE id = 1')
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then
        for cid, items in pairs(data.owed or {}) do
            for _, it in ipairs(items) do addOwed(cid, it.item, it.amount) end
        end
        for _, j in ipairs(data.live or {}) do
            local recipe = Config.Recipes[j.recipeIndex]
            if recipe and j.citizenid then
                oweJobInputs(j.citizenid, { recipe = recipe, amount = j.amount })
                print(('[rsg-smelting] recovered interrupted smelt for %s (%dx %s)'):format(j.citizenid, j.amount, recipe.output))
            end
        end
    end
    stateLoaded = true
    saveState()
end)

-- Give back a job's inputs; anything that won't fit is kept as owed for the character
local function giveOrOwe(src, citizenid, item, total, reason)
    if Inventory:CanAddItem(src, item, total) and Inventory:AddItem(src, item, total, nil, nil, reason) then
        itemBox(src, item, 'add', total)
        return true
    end
    addOwed(citizenid, item, total)
    print(('[rsg-smelting] refund deferred for %s: %dx %s (inventory full)'):format(citizenid or src, total, item))
    Webhook.Send('refund_failed', src, {
        { locale('wh_f_item'), ('%dx %s'):format(total, itemLabel(item)) },
        { locale('wh_f_reason'), reason },
    }, locale('wh_desc_refund_failed'))
    return false
end

local function refund(src, job, reason)
    local allOk = true
    for _, inp in ipairs(job.recipe.inputs) do
        if not giveOrOwe(src, job.citizenid, inp.item, inp.amount * job.amount, reason) then allOk = false end
    end
    if not allOk then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('smelter_title'), description = locale('smelt_refund_deferred'), type = 'inform', duration = 6000 })
    end
    saveState()
end

-- Pay out anything owed to the character currently on this source
local function payOwed(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local items = owed[cid]
    if not items or #items == 0 then return end
    owed[cid] = nil
    local paid = {}
    for _, it in ipairs(items) do
        if Inventory:CanAddItem(src, it.item, it.amount) and Inventory:AddItem(src, it.item, it.amount, nil, nil, 'rsg-smelting:owed') then
            itemBox(src, it.item, 'add', it.amount)
            paid[#paid + 1] = ('%dx %s'):format(it.amount, itemLabel(it.item))
        else
            addOwed(cid, it.item, it.amount) -- still no room, keep it for next time
        end
    end
    saveState()
    if #paid > 0 then
        Webhook.Send('rejoin_refund', src, { { locale('wh_f_refunded'), table.concat(paid, '\n'), inline = false } })
        TriggerClientEvent('ox_lib:notify', src, { title = locale('smelter_title'), description = locale('smelt_refund_rejoin'), type = 'inform', duration = 5000 })
    end
end

-- Move a live job to owed (disconnect / logout / character mismatch)
local function shelveJob(src, job, event)
    oweJobInputs(job.citizenid, job)
    saveState()
    Webhook.Send(event or 'player_dropped', job.info, {
        { locale('wh_f_output'), ('%dx %s'):format(job.amount, locale(job.recipe.label)) },
        { locale('wh_f_held'), Webhook.Inputs(job.recipe, job.amount), inline = false },
    }, locale('wh_desc_dropped'))
end

lib.callback.register('rsg-smelting:server:getOreCounts', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return {} end
    payOwed(src) -- opening a smelter retries any deferred refund
    local counts = {}
    for _, item in ipairs(oreList) do
        counts[item] = itemCount(Player, item)
    end
    return counts
end)

local STALE_GRACE = 60 -- seconds after a job's end before it counts as abandoned

lib.callback.register('rsg-smelting:server:startSmelt', function(src, smelterIndex, recipeIndex, amount, propCoords)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false, locale('err_player') end

    local existing = pending[src]
    if existing then
        if existing.citizenid ~= Player.PlayerData.citizenid then
            -- job of another character on this source: hold it for that character
            pending[src] = nil
            shelveJob(src, existing)
        elseif os.time() - existing.startedAt > existing.duration + STALE_GRACE then
            -- client never called finishSmelt (crash/stall): refund the abandoned job
            pending[src] = nil
            refund(src, existing, 'rsg-smelting:stale')
            Webhook.Send('smelt_cancel', src, { { locale('wh_f_output'), ('%dx %s'):format(existing.amount, locale(existing.recipe.label)) }, { locale('wh_f_elapsed'), locale('wh_elapsed_val', os.time() - existing.startedAt, existing.duration) } })
        else
            return false, locale('err_busy')
        end
    end

    recipeIndex = tonumber(recipeIndex) or 0
    local recipe = Config.Recipes[recipeIndex]
    if not recipe then
        Webhook.Send('suspicious', src, { { locale('wh_f_check'), locale('wh_chk_recipe') }, { locale('wh_f_sent'), tostring(recipeIndex) } })
        return false, locale('err_recipe')
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > Config.MaxBatch then
        Webhook.Send('suspicious', src, { { locale('wh_f_check'), locale('wh_chk_amount') }, { locale('wh_f_sent'), tostring(amount) }, { locale('wh_f_max'), tostring(Config.MaxBatch) } })
        return false, locale('err_amount')
    end

    local smelter = normaliseSmelter(smelterIndex)
    if not smelter or not nearSmelter(src, smelter, propCoords) then
        Webhook.Send('suspicious', src, { { locale('wh_f_check'), locale('wh_chk_distance') }, { locale('wh_f_smelter'), smelter and Webhook.SmelterName(smelter) or tostring(smelterIndex) } })
        return false, locale('err_distance')
    end

    for _, inp in ipairs(recipe.inputs) do
        if itemCount(Player, inp.item) < inp.amount * amount then
            return false, locale('err_not_enough', itemLabel(inp.item))
        end
    end

    -- Take inputs up front so they can't be dropped/traded mid-smelt.
    -- If any removal fails, roll back what was already taken.
    local taken = {}
    for _, inp in ipairs(recipe.inputs) do
        local total = inp.amount * amount
        if not Inventory:RemoveItem(src, inp.item, total, nil, 'rsg-smelting:start') then
            for _, t in ipairs(taken) do Inventory:AddItem(src, t.item, t.total, nil, nil, 'rsg-smelting:rollback') end
            Webhook.Send('take_failed', src, { { locale('wh_f_item'), ('%dx %s'):format(total, itemLabel(inp.item)) }, { locale('wh_f_recipe'), locale(recipe.label) } })
            return false, locale('err_take_failed')
        end
        taken[#taken + 1] = { item = inp.item, total = total }
        itemBox(src, inp.item, 'remove', total)
    end

    pending[src] = {
        recipe = recipe,
        recipeIndex = recipeIndex,
        amount = amount,
        smelter = smelter,
        propCoords = propCoords,
        startedAt = os.time(),
        duration = math.floor(recipe.time * amount / 1000),
        citizenid = Player.PlayerData.citizenid,
        info = Webhook.PlayerInfo(src), -- snapshot for logs after disconnect
    }
    saveState()
    Webhook.Send('smelt_start', src, {
        { locale('wh_f_output'), ('%dx %s'):format(amount, locale(recipe.label)) },
        { locale('wh_f_smelter'), Webhook.SmelterName(smelter) },
        { locale('wh_f_duration'), locale('wh_seconds', pending[src].duration) },
        { locale('wh_f_inputs'), Webhook.Inputs(recipe, amount), inline = false },
    })
    return true
end)

lib.callback.register('rsg-smelting:server:finishSmelt', function(src, cancelled)
    local job = pending[src]
    if not job then return false end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    pending[src] = nil

    -- The job belongs to the character that started it, not to the server id
    if Player.PlayerData.citizenid ~= job.citizenid then
        shelveJob(src, job, 'suspicious')
        return false, locale('smelt_failed')
    end

    if cancelled then
        refund(src, job, 'rsg-smelting:cancel')
        Webhook.Send('smelt_cancel', src, { { locale('wh_f_output'), ('%dx %s'):format(job.amount, locale(job.recipe.label)) }, { locale('wh_f_elapsed'), locale('wh_elapsed_val', os.time() - job.startedAt, job.duration) } })
        return false, locale('smelt_cancelled')
    end

    -- Must have waited the full time (1s tolerance) and still be at the smelter
    local elapsed = os.time() - job.startedAt
    local tooFast = elapsed < job.duration - 1
    if tooFast or not nearSmelter(src, job.smelter, job.propCoords) then
        refund(src, job, 'rsg-smelting:failed')
        Webhook.Send(tooFast and 'suspicious' or 'smelt_failed', src, {
            { locale('wh_f_check'), tooFast and locale('wh_chk_too_early') or locale('wh_chk_left_area') },
            { locale('wh_f_output'), ('%dx %s'):format(job.amount, locale(job.recipe.label)) },
            { locale('wh_f_elapsed'), locale('wh_elapsed_val', elapsed, job.duration) },
            { locale('wh_f_smelter'), Webhook.SmelterName(job.smelter) },
        })
        return false, locale('smelt_failed')
    end

    local output = job.recipe.output
    if Inventory:CanAddItem(src, output, job.amount) and Inventory:AddItem(src, output, job.amount, nil, nil, 'rsg-smelting:finish') then
        saveState()
        itemBox(src, output, 'add', job.amount)
        Webhook.Send('smelt_complete', src, {
            { locale('wh_f_output'), ('%dx %s'):format(job.amount, locale(job.recipe.label)) },
            { locale('wh_f_smelter'), Webhook.SmelterName(job.smelter) },
            { locale('wh_f_consumed'), Webhook.Inputs(job.recipe, job.amount), inline = false },
        })
        return true, locale('smelt_success', job.amount, locale(job.recipe.label))
    end

    refund(src, job, 'rsg-smelting:nospace')
    Webhook.Send('smelt_nospace', src, { { locale('wh_f_output'), ('%dx %s'):format(job.amount, locale(job.recipe.label)) } })
    return false, locale('smelt_no_space')
end)

-- Disconnect mid-smelt: remember the job and refund on next login
AddEventHandler('playerDropped', function()
    local src = source
    local job = pending[src]
    if not job then return end
    pending[src] = nil
    shelveJob(src, job)
end)

-- Character logout without disconnect: hold the job for that character
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    src = tonumber(src) or source
    local job = pending[src]
    if not job then return end
    pending[src] = nil
    shelveJob(src, job)
end)

-- Client-callable, but it only pays what this character is already owed
RegisterNetEvent('RSGCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(2000, function() payOwed(src) end)
end)

-- Resource stopping mid-smelt: refund everyone still online (anything that
-- doesn't fit, and owed items, stay persisted for the next start)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, job in pairs(pending) do
        pending[src] = nil
        refund(src, job, 'rsg-smelting:stop')
        Webhook.Send('resource_stop', src, { { locale('wh_f_refunded'), Webhook.Inputs(job.recipe, job.amount), inline = false } })
    end
    saveState()
    Webhook.Flush()
end)
