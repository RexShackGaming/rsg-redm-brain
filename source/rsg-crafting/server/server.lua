local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']
lib.locale()

local LATENCY_GRACE   = 1500   -- ms tolerance for network delay on finish
local SESSION_TIMEOUT = 30000  -- ms after craft time before an abandoned session is discarded

-- [source] = { index, qty, crafttime, startedAt }
local activeSessions = {}

---------------------------------------------
-- helpers
---------------------------------------------
local function notify(src, description, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('notify_title'), description = description, type = ntype or 'inform', duration = 5000,
    })
end

local function itemLabel(item)
    local data = RSGCore.Shared.Items[item]
    return data and data.label or item
end

local function getXP(Player)
    return Player.Functions.GetRep(Config.XPType) or 0
end

local function hasRequiredJob(Player, requiredJob)
    if not requiredJob then return true end
    local job = Player.PlayerData.job
    return job ~= nil and (job.name == requiredJob or job.type == requiredJob)
end

local function hasBook(src)
    return (Inventory:GetItemCount(src, Config.BookItem) or 0) > 0
end

local function isValidRecipe(recipe)
    if type(recipe) ~= 'table' then return false, 'recipe must be a table' end
    if not RSGCore.Shared.Items[recipe.receive] then return false, 'unknown item: ' .. tostring(recipe.receive) end
    if type(recipe.giveamount) ~= 'number' or recipe.giveamount < 1 then return false, 'invalid giveamount' end
    if type(recipe.ingredients) ~= 'table' or #recipe.ingredients == 0 then return false, 'no ingredients' end
    local seen = {}
    for _, ing in ipairs(recipe.ingredients) do
        if type(ing) ~= 'table' or not RSGCore.Shared.Items[ing.item] then return false, 'unknown ingredient: ' .. tostring(ing and ing.item) end
        if seen[ing.item] then return false, 'duplicate ingredient: ' .. ing.item end
        seen[ing.item] = true
        if type(ing.amount) ~= 'number' or ing.amount < 1 then return false, 'invalid amount for ' .. ing.item end
    end
    if recipe.requireditems ~= nil then
        if type(recipe.requireditems) ~= 'table' then return false, 'requireditems must be a table' end
        local seenTool = {}
        for _, req in ipairs(recipe.requireditems) do
            if type(req) ~= 'table' or not RSGCore.Shared.Items[req.item] then return false, 'unknown required item: ' .. tostring(req and req.item) end
            if seenTool[req.item] then return false, 'duplicate required item: ' .. req.item end
            if seen[req.item] then return false, 'required item is also an ingredient: ' .. req.item end
            seenTool[req.item] = true
            if req.amount ~= nil and (type(req.amount) ~= 'number' or req.amount < 1) then return false, 'invalid amount for required item ' .. req.item end
        end
    end
    return true
end

-- [index] = true for recipes that passed validation (built once on start)
local validRecipes = {}

local function getRecipe(index)
    if type(index) ~= 'number' or not validRecipes[index] then return nil end
    return Config.Crafting[index]
end

local function sanitizeQty(qty)
    qty = math.floor(tonumber(qty) or 1)
    if qty < 1 or qty > (Config.MaxBatch or 10) then return nil end
    return qty
end

local function scaleRecipe(recipe, qty)
    local ingredients = {}
    for _, ing in ipairs(recipe.ingredients) do
        ingredients[#ingredients + 1] = { item = ing.item, amount = ing.amount * qty }
    end
    return {
        receive = recipe.receive,
        giveamount = recipe.giveamount * qty,
        xpreward = (tonumber(recipe.xpreward) or 0) * qty,
        crafttime = (recipe.crafttime or 10000) * qty,
        ingredients = ingredients,
    }
end

local function getMissing(src, ingredients)
    local missing = {}
    for _, ing in ipairs(ingredients) do
        local have = Inventory:GetItemCount(src, ing.item) or 0
        if have < ing.amount then
            missing[#missing + 1] = { item = ing.item, label = itemLabel(ing.item), have = have, need = ing.amount }
        end
    end
    return missing
end

-- tools that must be held but are never removed (not scaled by batch qty)
local function getMissingTools(src, recipe)
    local missing = {}
    for _, req in ipairs(recipe.requireditems or {}) do
        local need = req.amount or 1
        local have = Inventory:GetItemCount(src, req.item) or 0
        if have < need then
            missing[#missing + 1] = { item = req.item, label = itemLabel(req.item), have = have, need = need }
        end
    end
    return missing
end

local function toolLabels(missing)
    local t = {}
    for _, m in ipairs(missing) do t[#t + 1] = m.label end
    return table.concat(t, ', ')
end

-- the only place items / XP are granted
local function craftRecipe(src, Player, scaled)
    if #getMissing(src, scaled.ingredients) > 0 then return false, 'missing' end
    if not Inventory:CanAddItem(src, scaled.receive, scaled.giveamount) then return false, 'inventory_full' end

    local removed = {}
    local function refund()
        for _, r in ipairs(removed) do Inventory:AddItem(src, r.item, r.amount, nil, nil, 'rsg-crafting-refund') end
    end

    for _, ing in ipairs(scaled.ingredients) do
        if not Inventory:RemoveItem(src, ing.item, ing.amount, nil, 'rsg-crafting') then
            refund()
            return false, 'error'
        end
        removed[#removed + 1] = ing
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[ing.item], 'remove', ing.amount)
    end

    if not Inventory:AddItem(src, scaled.receive, scaled.giveamount, nil, nil, 'rsg-crafting') then
        refund()
        return false, 'error'
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[scaled.receive], 'add', scaled.giveamount)

    if scaled.xpreward > 0 then
        Player.Functions.AddRep(Config.XPType, scaled.xpreward)
        notify(src, locale('xp_gained', scaled.xpreward), 'inform')
    end

    local charinfo = Player.PlayerData.charinfo or {}
    local used = {}
    for _, ing in ipairs(scaled.ingredients) do used[#used + 1] = locale('amount_item', ing.amount, itemLabel(ing.item)) end
    CraftLog('craft', locale('log_title'),
        locale('log_message', ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''), Player.PlayerData.citizenid,
            scaled.giveamount, itemLabel(scaled.receive)), src, {
            { name = locale('wh_crafted'), value = ('%s (`%s`)'):format(locale('amount_item', scaled.giveamount, itemLabel(scaled.receive)), scaled.receive) },
            { name = locale('wh_xp_earned'), value = tostring(scaled.xpreward) },
            { name = locale('wh_total_xp'), value = tostring(getXP(Player)) },
            { name = locale('wh_ingredients_used'), value = table.concat(used, '\n'), inline = false },
        })

    return true
end

---------------------------------------------
-- validate config on start
---------------------------------------------
CreateThread(function()
    if not RSGCore.Shared.Items[Config.BookItem] then
        print(('^1[rsg-crafting] Book item "%s" is missing from rsg-core/shared/items.lua^7'):format(Config.BookItem))
    end
    for i, recipe in ipairs(Config.Crafting) do
        local ok, err = isValidRecipe(recipe)
        if ok then
            validRecipes[i] = true
        else
            print(('^1[rsg-crafting] Config.Crafting[%d] is invalid: %s^7'):format(i, err))
        end
    end
end)

---------------------------------------------
-- usable crafting book
---------------------------------------------
RSGCore.Functions.CreateUseableItem(Config.BookItem, function(source)
    TriggerClientEvent('rsg-crafting:client:openBook', source)
end)

---------------------------------------------
-- recipe list (server decides what the player sees)
---------------------------------------------
lib.callback.register('rsg-crafting:server:getRecipes', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not hasBook(src) then return nil end

    local xp = getXP(Player)
    local list, nextUnlock = {}, nil
    local counts = {}
    local function count(item)
        local c = counts[item]
        if not c then
            c = Inventory:GetItemCount(src, item) or 0
            counts[item] = c
        end
        return c
    end

    for index, recipe in ipairs(Config.Crafting) do
        if validRecipes[index] and hasRequiredJob(Player, recipe.requiredjob) then
            local reqxp = recipe.requiredxp or 0
            local locked = xp < reqxp
            if locked and (not nextUnlock or reqxp < nextUnlock) then nextUnlock = reqxp end

            if not locked or Config.ShowLocked then
                local ingredients, maxCraftable = {}, Config.MaxBatch or 10
                for _, ing in ipairs(recipe.ingredients) do
                    local have = count(ing.item)
                    local data = RSGCore.Shared.Items[ing.item]
                    ingredients[#ingredients + 1] = {
                        item = ing.item, label = itemLabel(ing.item), image = data and data.image,
                        amount = ing.amount, have = have,
                    }
                    maxCraftable = math.min(maxCraftable, math.floor(have / ing.amount))
                end
                local tools = {}
                for _, req in ipairs(recipe.requireditems or {}) do
                    local need = req.amount or 1
                    local have = count(req.item)
                    local data = RSGCore.Shared.Items[req.item]
                    tools[#tools + 1] = {
                        item = req.item, label = itemLabel(req.item), image = data and data.image,
                        amount = need, have = have,
                    }
                    if have < need then maxCraftable = 0 end
                end
                local item = RSGCore.Shared.Items[recipe.receive]
                list[#list + 1] = {
                    id = index,
                    category = recipe.category or locale('category_other'),
                    label = item.label,
                    description = item.description,
                    image = item.image,
                    giveamount = recipe.giveamount,
                    crafttime = recipe.crafttime or 10000,
                    requiredxp = reqxp,
                    xpreward = recipe.xpreward or 0,
                    ingredients = ingredients,
                    tools = tools,
                    locked = locked,
                    maxCraftable = maxCraftable,
                }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.requiredxp ~= b.requiredxp then return a.requiredxp < b.requiredxp end
        return a.label < b.label
    end)

    return { xp = xp, nextUnlock = nextUnlock, recipes = list }
end)

---------------------------------------------
-- start crafting: validate and open a timed session
---------------------------------------------
lib.callback.register('rsg-crafting:server:startCrafting', function(src, index, qty)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return { ok = false, reason = 'error' } end

    local existing = activeSessions[src]
    if existing then
        if GetGameTimer() - existing.startedAt < existing.crafttime + SESSION_TIMEOUT then
            return { ok = false, reason = 'busy' }
        end
        activeSessions[src] = nil
    end

    if not hasBook(src) then return { ok = false, reason = 'error' } end

    local recipe = getRecipe(index)
    if not recipe then return { ok = false, reason = 'error' } end
    qty = sanitizeQty(qty)
    if not qty then return { ok = false, reason = 'error' } end

    if not hasRequiredJob(Player, recipe.requiredjob) then
        return { ok = false, reason = 'job', requiredJob = recipe.requiredjob }
    end

    local xp = getXP(Player)
    if xp < (recipe.requiredxp or 0) then
        return { ok = false, reason = 'xp', requiredXP = recipe.requiredxp, currentXP = xp }
    end

    local missingTools = getMissingTools(src, recipe)
    if #missingTools > 0 then return { ok = false, reason = 'tools', tools = toolLabels(missingTools) } end

    local scaled = scaleRecipe(recipe, qty)
    if #getMissing(src, scaled.ingredients) > 0 then return { ok = false, reason = 'missing' } end
    if not Inventory:CanAddItem(src, scaled.receive, scaled.giveamount) then
        return { ok = false, reason = 'inventory_full', label = itemLabel(recipe.receive) }
    end

    activeSessions[src] = { index = index, qty = qty, crafttime = scaled.crafttime, startedAt = GetGameTimer() }
    return { ok = true, crafttime = scaled.crafttime, label = itemLabel(recipe.receive), qty = qty }
end)

---------------------------------------------
-- finish crafting: only the server decides the reward
---------------------------------------------
lib.callback.register('rsg-crafting:server:finishCrafting', function(src, index)
    local session = activeSessions[src]
    activeSessions[src] = nil
    if not session or session.index ~= index then
        CraftLog('suspicious', locale('log_suspicious_title'), locale('log_invalid_session'), src, {
            { name = locale('wh_sent_recipe'), value = tostring(index) },
            { name = locale('wh_session_recipe'), value = session and tostring(session.index) or locale('wh_none') },
        })
        return { ok = false, reason = 'error' }
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    local recipe = getRecipe(session.index)
    if not Player or not recipe or not hasBook(src) then return { ok = false, reason = 'error' } end

    local elapsed = GetGameTimer() - session.startedAt
    if elapsed + LATENCY_GRACE < session.crafttime then
        print(('^1[rsg-crafting] Player %s finished crafting too fast (%dms of %dms)^7'):format(src, elapsed, session.crafttime))
        CraftLog('suspicious', locale('log_suspicious_title'), locale('log_too_fast'), src, {
            { name = locale('wh_recipe'), value = itemLabel(recipe.receive) },
            { name = locale('wh_elapsed'), value = locale('wh_ms', elapsed) },
            { name = locale('wh_required'), value = locale('wh_ms', session.crafttime) },
        })
        return { ok = false, reason = 'error' }
    end

    if not hasRequiredJob(Player, recipe.requiredjob) then
        return { ok = false, reason = 'job', requiredJob = recipe.requiredjob }
    end

    local xp = getXP(Player)
    if xp < (recipe.requiredxp or 0) then
        return { ok = false, reason = 'xp', requiredXP = recipe.requiredxp, currentXP = xp }
    end

    local missingTools = getMissingTools(src, recipe)
    if #missingTools > 0 then
        CraftLog('failed', locale('log_failed_title'), locale('log_failed_desc', session.qty, itemLabel(recipe.receive)), src, {
            { name = locale('wh_reason'), value = 'tools: ' .. toolLabels(missingTools) },
        })
        return { ok = false, reason = 'tools', tools = toolLabels(missingTools) }
    end

    local scaled = scaleRecipe(recipe, session.qty)
    local ok, reason = craftRecipe(src, Player, scaled)
    if not ok then
        CraftLog('failed', locale('log_failed_title'), locale('log_failed_desc', session.qty, itemLabel(recipe.receive)), src, {
            { name = locale('wh_reason'), value = tostring(reason) },
        })
        return { ok = false, reason = reason, label = itemLabel(recipe.receive) }
    end

    return { ok = true, amount = scaled.giveamount, label = itemLabel(recipe.receive) }
end)

RegisterNetEvent('rsg-crafting:server:cancelCrafting', function()
    local src = source
    local session = activeSessions[src]
    activeSessions[src] = nil
    if session then
        local recipe = Config.Crafting[session.index]
        CraftLog('cancelled', locale('log_cancelled_title'),
            locale('log_cancelled_desc', session.qty, recipe and itemLabel(recipe.receive) or locale('wh_unknown')), src)
    end
end)

AddEventHandler('playerDropped', function()
    activeSessions[source] = nil
end)

---------------------------------------------
-- exports
---------------------------------------------
exports('GetPlayerCraftingXP', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and getXP(Player) or 0
end)

exports('GivePlayerCraftingXP', function(src, amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not Player or amount <= 0 then return false end
    Player.Functions.AddRep(Config.XPType, amount)
    notify(src, locale('xp_gained', amount), 'inform')
    CraftLog('xp', locale('log_xp_title'), locale('log_xp_desc', amount, GetInvokingResource() or locale('wh_unknown')), src, {
        { name = locale('wh_total_xp'), value = tostring(getXP(Player)) },
    })
    return true
end)

exports('GetCraftingRecipes', function() return lib.table.deepclone(Config.Crafting) end)
