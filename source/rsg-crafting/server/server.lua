local RSGCore = exports['rsg-core']:GetCoreObject()
local Inventory = exports['rsg-inventory']
CraftingServer = CraftingServer or {}

local LATENCY_GRACE   = 1500   -- ms tolerance for network delay on finish
local SESSION_TIMEOUT = 30000  -- ms after craft time before an abandoned session is discarded
local MIN_ASSIST_LEFT = 3000   -- ms a craft must still have left to be helped

-- [source] = { index, qty, crafttime, startedAt, helpers = { [helperSrc] = true } }
local activeSessions = {}
local assistCooldown = {} -- [helperSrc] = GetGameTimer() value when it may help again
local learnedCache = {}   -- [src] = { cid, set = { [blueprint] = true } }

---------------------------------------------
-- helpers
---------------------------------------------
local function notify(src, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
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

local function isWhole(n)
    return type(n) == 'number' and n >= 1 and n == math.floor(n) and n < math.huge
end

local function isPercent(n)
    return type(n) == 'number' and n == n and n >= 0 and n <= 100
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function isValidRecipe(recipe)
    if type(recipe) ~= 'table' then return false, 'recipe must be a table' end
    if not RSGCore.Shared.Items[recipe.receive] then return false, 'unknown item: ' .. tostring(recipe.receive) end
    if not isWhole(recipe.giveamount) then return false, 'invalid giveamount' end
    for _, field in ipairs({ 'crafttime', 'requiredxp', 'xpreward' }) do
        local v = recipe[field]
        if v ~= nil and (type(v) ~= 'number' or v ~= v or v < 0 or v == math.huge) then return false, 'invalid ' .. field end
    end
    if recipe.failchance ~= nil and not isPercent(recipe.failchance) then return false, 'failchance must be 0-100' end
    if recipe.station ~= nil and (type(recipe.station) ~= 'string' or not Config.Stations.Types[recipe.station]) then
        return false, 'unknown station: ' .. tostring(recipe.station)
    end
    if recipe.blueprint ~= nil and (type(recipe.blueprint) ~= 'string' or not RSGCore.Shared.Items[recipe.blueprint]) then
        return false, 'unknown blueprint item: ' .. tostring(recipe.blueprint)
    end
    if type(recipe.ingredients) ~= 'table' or #recipe.ingredients == 0 then return false, 'no ingredients' end
    local seen = {}
    for _, ing in ipairs(recipe.ingredients) do
        if type(ing) ~= 'table' or not RSGCore.Shared.Items[ing.item] then return false, 'unknown ingredient: ' .. tostring(ing and ing.item) end
        if seen[ing.item] then return false, 'duplicate ingredient: ' .. ing.item end
        seen[ing.item] = true
        if not isWhole(ing.amount) then return false, 'invalid amount for ' .. ing.item end
    end
    if recipe.requireditems ~= nil then
        if type(recipe.requireditems) ~= 'table' then return false, 'requireditems must be a table' end
        local seenTool = {}
        for _, req in ipairs(recipe.requireditems) do
            if type(req) ~= 'table' or not RSGCore.Shared.Items[req.item] then return false, 'unknown required item: ' .. tostring(req and req.item) end
            if seenTool[req.item] then return false, 'duplicate required item: ' .. req.item end
            if seen[req.item] then return false, 'required item is also an ingredient: ' .. req.item end
            seenTool[req.item] = true
            if req.amount ~= nil and not isWhole(req.amount) then return false, 'invalid amount for required item ' .. req.item end
        end
    end
    return true
end

-- [index] = true for recipes that passed validation (built once on start)
local validRecipes = {}
local blueprintRecipes = {} -- [blueprint item] = recipe

local function getRecipe(index)
    if type(index) ~= 'number' or not validRecipes[index] then return nil end
    return Config.Crafting[index]
end

local function sanitizeQty(qty)
    qty = tonumber(qty) or 1
    if qty ~= qty then return nil end -- NaN would slip past every comparison below
    qty = math.floor(qty)
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

---------------------------------------------
-- rsg-skills (optional): mirror XP into the shared skill and read perks, both on the server
---------------------------------------------
local function skillsActive()
    return Config.Skills.Enabled and GetResourceState('rsg-skills') == 'started'
end

local function skillXP(src, amount, reason)
    if not skillsActive() or not amount or amount <= 0 then return end
    exports['rsg-skills']:AddXP(src, Config.Skills.Skill, math.max(1, math.floor(amount * (Config.Skills.XPScale or 1) + 0.5)), reason)
end

local function skillPerk(src, perk)
    if not skillsActive() then return 0 end
    return tonumber(exports['rsg-skills']:GetPerk(src, Config.Skills.Skill, perk)) or 0
end

-- ms per unit, after the rsg-skills speed_bonus perk
local function craftTimePer(src, recipe)
    local t = recipe.crafttime or 10000
    if Config.Skills.SpeedBonus then
        local bonus = skillPerk(src, 'speed_bonus')
        if bonus > 0 then t = math.max(1000, math.floor(t * (1 - math.min(bonus, 75) / 100))) end
    end
    return t
end

---------------------------------------------
-- failure chance and quality
---------------------------------------------
local function failChance(recipe, xp)
    local cfg = Config.Failure
    local base = tonumber(recipe.failchance) or 0
    if not cfg or not cfg.Enabled or base <= 0 then return 0 end
    local reduce = (cfg.ReducePerXP or 0) > 0 and math.floor(xp / cfg.ReducePerXP) or 0
    return math.max(cfg.MinChance or 0, math.min(100, base - reduce))
end

local function usesQuality(recipe)
    return recipe.quality == true and Config.Quality ~= nil and Config.Quality.Enabled == true
end

local function baseQuality(xp)
    local q = Config.Quality
    local progress = math.min(1, xp / math.max(1, q.XPForMax or 1))
    return math.floor(q.Min + (q.Max - q.Min) * progress + 0.5)
end

local function rollQuality(xp)
    local spread = math.floor(Config.Quality.Variance or 0)
    local value = baseQuality(xp) + (spread > 0 and math.random(-spread, spread) or 0)
    return math.max(1, math.min(100, value))
end

---------------------------------------------
-- blueprints (learned recipes, saved per character)
---------------------------------------------
local function getLearned(Player)
    local src, cid = Player.PlayerData.source, Player.PlayerData.citizenid
    local cache = learnedCache[src]
    if cache and cache.cid == cid then return cache.set end
    local set = {}
    if CraftingServer.ready then
        for _, row in ipairs(MySQL.query.await('SELECT recipe FROM rsg_crafting_recipes WHERE citizenid = ?', { cid }) or {}) do
            set[row.recipe] = true
        end
    end
    learnedCache[src] = { cid = cid, set = set }
    return set
end

local function hasLearned(Player, recipe)
    return not recipe.blueprint or getLearned(Player)[recipe.blueprint] == true
end

-- returns true when the recipe was newly learned
function CraftingServer.LearnRecipe(Player, key)
    if not blueprintRecipes[key] then return false end
    local set = getLearned(Player)
    if set[key] then return false end
    MySQL.insert.await('INSERT IGNORE INTO rsg_crafting_recipes (citizenid, recipe) VALUES (?, ?)', { Player.PlayerData.citizenid, key })
    set[key] = true
    return true
end

function CraftingServer.ForgetRecipe(Player, key)
    if not blueprintRecipes[key] then return false end
    local set = getLearned(Player)
    if not set[key] then return false end
    MySQL.query.await('DELETE FROM rsg_crafting_recipes WHERE citizenid = ? AND recipe = ?', { Player.PlayerData.citizenid, key })
    set[key] = nil
    return true
end

function CraftingServer.IsBlueprint(key) return blueprintRecipes[key] ~= nil end

---------------------------------------------
-- the only place items / XP are granted
---------------------------------------------
-- consumes the ingredients, rolls failures and quality, and hands over the result.
-- returns true, { amount, successes, failures, quality, xp } or false, reason
local function craftRecipe(src, Player, recipe, qty)
    local scaled = scaleRecipe(recipe, qty)
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
    end

    -- every unit is rolled on its own
    local xp = getXP(Player)
    local chance = failChance(recipe, xp)
    local successes = qty
    if chance > 0 then
        successes = 0
        for _ = 1, qty do
            if math.random(100) > chance then successes = successes + 1 end
        end
    end
    local failures = qty - successes

    local amount = successes * recipe.giveamount
    local quality
    if amount > 0 then
        local info
        if usesQuality(recipe) then
            quality = rollQuality(xp)
            info = { quality = quality }
        end
        if not Inventory:AddItem(src, recipe.receive, amount, info, nil, 'rsg-crafting') then
            refund()
            return false, 'error'
        end
    end

    -- failed units give part of their ingredients back
    if failures > 0 then
        local pct = (Config.Failure and Config.Failure.RefundPercent) or 0
        for _, ing in ipairs(recipe.ingredients) do
            local back = math.floor(ing.amount * pct / 100) * failures
            if back > 0 and Inventory:CanAddItem(src, ing.item, back) then
                Inventory:AddItem(src, ing.item, back, nil, nil, 'rsg-crafting-fail-refund')
            end
        end
    end

    local reward = tonumber(recipe.xpreward) or 0
    local earned = successes * reward
    if failures > 0 then
        earned = earned + math.floor(reward * failures * ((Config.Failure and Config.Failure.XPPercent) or 0) / 100 + 0.5)
    end
    if earned > 0 then
        Player.Functions.AddRep(Config.XPType, earned)
        notify(src, locale('xp_gained', earned), 'inform')
        skillXP(src, earned, 'crafting')
    end

    -- rsg-skills: save_chance perk, the ingredients of the successful units come back
    if successes > 0 and Config.Skills.SaveChance and math.random(100) <= skillPerk(src, 'save_chance') then
        for _, ing in ipairs(recipe.ingredients) do
            local back = ing.amount * successes
            if Inventory:CanAddItem(src, ing.item, back) then
                Inventory:AddItem(src, ing.item, back, nil, nil, 'rsg-crafting-skill-save')
            end
        end
    end

    local charinfo = Player.PlayerData.charinfo or {}
    local used = {}
    for _, ing in ipairs(scaled.ingredients) do used[#used + 1] = locale('amount_item', ing.amount, itemLabel(ing.item)) end
    local fields = {
        { name = locale('wh_crafted'), value = ('%s (`%s`)'):format(locale('amount_item', amount, itemLabel(recipe.receive)), recipe.receive) },
        { name = locale('wh_xp_earned'), value = tostring(earned) },
        { name = locale('wh_total_xp'), value = tostring(getXP(Player)) },
        { name = locale('wh_ingredients_used'), value = table.concat(used, '\n'), inline = false },
    }
    if quality then fields[#fields + 1] = { name = locale('wh_quality'), value = tostring(quality) } end
    if failures > 0 then fields[#fields + 1] = { name = locale('wh_failed_units'), value = tostring(failures) } end
    if amount > 0 then
        CraftLog('craft', locale('log_title'),
            locale('log_message', ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''), Player.PlayerData.citizenid,
                amount, itemLabel(recipe.receive)), src, fields)
    end

    return true, { amount = amount, successes = successes, failures = failures, quality = quality, xp = earned }
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
            if recipe.blueprint then
                if blueprintRecipes[recipe.blueprint] then
                    print(('^1[rsg-crafting] Config.Crafting[%d] reuses blueprint "%s"; each blueprint can teach one recipe^7'):format(i, recipe.blueprint))
                    validRecipes[i] = nil
                else
                    blueprintRecipes[recipe.blueprint] = recipe
                end
            end
        else
            print(('^1[rsg-crafting] Config.Crafting[%d] is invalid: %s^7'):format(i, err))
        end
    end
    for i, s in ipairs(Config.Stations.Static) do
        if type(s) ~= 'table' or not Config.Stations.Types[s.type] or type(s.coords) ~= 'vector3' then
            print(('^1[rsg-crafting] Config.Stations.Static[%d] needs a known type and vector3 coords^7'):format(i))
            Config.Stations.Static[i] = { type = '', coords = vector3(0.0, 0.0, -9999.0) } -- neutralised
        end
    end

    -- using a blueprint item teaches its recipe
    for key, recipe in pairs(blueprintRecipes) do
        RSGCore.Functions.CreateUseableItem(key, function(source)
            local Player = RSGCore.Functions.GetPlayer(source)
            if not Player then return end
            local label = itemLabel(recipe.receive)
            if getLearned(Player)[key] then
                return notify(source, locale('recipe_known', label), 'inform')
            end
            if not Inventory:RemoveItem(source, key, 1, nil, 'rsg-crafting-blueprint') then return end
            CraftingServer.LearnRecipe(Player, key)
            notify(source, locale('recipe_learned', label), 'success')
        end)
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
local function buildRecipeList(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not hasBook(src) then return nil end

    local xp = getXP(Player)
    local list, nextUnlock = {}, nil
    local counts, nearStation = {}, {}
    local function count(item)
        local c = counts[item]
        if not c then
            c = Inventory:GetItemCount(src, item) or 0
            counts[item] = c
        end
        return c
    end
    local function atStation(stationType)
        if nearStation[stationType] == nil then nearStation[stationType] = CraftingServer.IsNearStation(src, stationType) end
        return nearStation[stationType]
    end

    for index, recipe in ipairs(Config.Crafting) do
        if validRecipes[index] and hasRequiredJob(Player, recipe.requiredjob) then
            local reqxp = recipe.requiredxp or 0
            local unknown = not hasLearned(Player, recipe)
            local locked = xp < reqxp or unknown
            if xp < reqxp and (not nextUnlock or reqxp < nextUnlock) then nextUnlock = reqxp end

            if (not unknown or Config.Blueprints.ShowUnknown) and (not locked or Config.ShowLocked) then
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
                local category = recipe.category or 'Other'
                local catCfg = Config.Categories[category]
                local chance = failChance(recipe, xp)
                list[#list + 1] = {
                    id = index,
                    key = recipe.receive,
                    category = category,
                    categoryLabel = catCfg and locale(catCfg.label) or (recipe.category or locale('category_other')),
                    categoryImage = catCfg and catCfg.image or nil,
                    label = item.label,
                    description = item.description,
                    image = item.image,
                    giveamount = recipe.giveamount,
                    crafttime = craftTimePer(src, recipe),
                    requiredxp = reqxp,
                    xpreward = recipe.xpreward or 0,
                    ingredients = ingredients,
                    tools = tools,
                    locked = locked,
                    blueprintLocked = unknown,
                    maxCraftable = maxCraftable,
                    failchance = chance > 0 and chance or nil,
                    quality = usesQuality(recipe) and baseQuality(xp) or nil,
                    station = recipe.station and CraftingServer.StationLabel(recipe.station) or nil,
                    stationOk = recipe.station and atStation(recipe.station) or nil,
                }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.requiredxp ~= b.requiredxp then return a.requiredxp < b.requiredxp end
        return a.label < b.label
    end)

    return { xp = xp, nextUnlock = nextUnlock, recipes = list }
end

RSGCore.Functions.CreateCallback('rsg-crafting:server:getRecipes', function(src, cb)
    cb(buildRecipeList(src))
end)

---------------------------------------------
-- shared checks used when a craft starts and when it finishes
---------------------------------------------
-- returns nil when the player may craft, otherwise a result table for the client
local function checkRequirements(src, Player, recipe, extraStationRange)
    if not hasRequiredJob(Player, recipe.requiredjob) then
        return { ok = false, reason = 'job', requiredJob = recipe.requiredjob }
    end
    if not hasLearned(Player, recipe) then return { ok = false, reason = 'blueprint' } end

    local xp = getXP(Player)
    if xp < (recipe.requiredxp or 0) then
        return { ok = false, reason = 'xp', requiredXP = recipe.requiredxp, currentXP = xp }
    end

    if recipe.station and not CraftingServer.IsNearStation(src, recipe.station, extraStationRange) then
        return { ok = false, reason = 'station', station = CraftingServer.StationLabel(recipe.station) }
    end

    local missingTools = getMissingTools(src, recipe)
    if #missingTools > 0 then return { ok = false, reason = 'tools', tools = toolLabels(missingTools) } end
    return nil
end

---------------------------------------------
-- start crafting: validate and open a timed session
---------------------------------------------
local function startCrafting(src, index, qty)
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

    local blocked = checkRequirements(src, Player, recipe)
    if blocked then return blocked end

    local scaled = scaleRecipe(recipe, qty)
    if #getMissing(src, scaled.ingredients) > 0 then return { ok = false, reason = 'missing' } end
    if not Inventory:CanAddItem(src, scaled.receive, scaled.giveamount) then
        return { ok = false, reason = 'inventory_full', label = itemLabel(recipe.receive) }
    end

    local crafttime = craftTimePer(src, recipe) * qty
    activeSessions[src] = { index = index, qty = qty, crafttime = crafttime, startedAt = GetGameTimer(), helpers = {} }
    return { ok = true, crafttime = crafttime, label = itemLabel(recipe.receive), qty = qty }
end

RSGCore.Functions.CreateCallback('rsg-crafting:server:startCrafting', function(src, cb, index, qty)
    cb(startCrafting(src, tonumber(index), qty))
end)

---------------------------------------------
-- helpers earn a share of the XP when they stayed close until the end
---------------------------------------------
local function payHelpers(src, session, recipe)
    local cfg = Config.Assist
    if not cfg or not cfg.Enabled then return end
    local reward = math.floor((tonumber(recipe.xpreward) or 0) * session.qty * (cfg.XPSharePercent or 0) / 100)
    if reward <= 0 then return end
    local crafterPos = playerCoords(src)
    for helperSrc in pairs(session.helpers) do
        local Helper = RSGCore.Functions.GetPlayer(helperSrc)
        local helperPos = playerCoords(helperSrc)
        if Helper and crafterPos and helperPos and #(crafterPos - helperPos) <= (cfg.Distance or 3.0) + 5.0 then
            Helper.Functions.AddRep(Config.XPType, reward)
            notify(helperSrc, locale('assist_reward', reward), 'success')
            skillXP(helperSrc, reward, 'crafting (assist)')
        end
    end
end

---------------------------------------------
-- finish crafting: only the server decides the reward
---------------------------------------------
local function finishCrafting(src, index)
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

    -- the player may have walked a little while crafting, so the station range gets some slack
    local blocked = checkRequirements(src, Player, recipe, 3.0)
    if blocked then
        if blocked.reason == 'tools' then
            CraftLog('failed', locale('log_failed_title'), locale('log_failed_desc', session.qty, itemLabel(recipe.receive)), src, {
                { name = locale('wh_reason'), value = 'tools: ' .. (blocked.tools or '') },
            })
        end
        return blocked
    end

    local ok, result = craftRecipe(src, Player, recipe, session.qty)
    if not ok then
        CraftLog('failed', locale('log_failed_title'), locale('log_failed_desc', session.qty, itemLabel(recipe.receive)), src, {
            { name = locale('wh_reason'), value = tostring(result) },
        })
        return { ok = false, reason = result, label = itemLabel(recipe.receive) }
    end

    if result.successes > 0 then payHelpers(src, session, recipe) end

    if result.amount == 0 then
        CraftLog('failed', locale('log_failed_title'), locale('log_failed_desc', session.qty, itemLabel(recipe.receive)), src, {
            { name = locale('wh_reason'), value = locale('wh_unlucky') },
        })
        return { ok = false, reason = 'crafting_failed', label = itemLabel(recipe.receive) }
    end

    return {
        ok = true, amount = result.amount, label = itemLabel(recipe.receive),
        failures = result.failures, quality = result.quality,
    }
end

RSGCore.Functions.CreateCallback('rsg-crafting:server:finishCrafting', function(src, cb, index)
    cb(finishCrafting(src, tonumber(index)))
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

---------------------------------------------
-- shared crafting: help a player who is crafting
---------------------------------------------
RegisterNetEvent('rsg-crafting:server:assist', function(targetId)
    local src = source
    local cfg = Config.Assist
    if not cfg or not cfg.Enabled then return end
    targetId = math.tointeger(tonumber(targetId))
    if not targetId or targetId == src then return end

    local Helper = RSGCore.Functions.GetPlayer(src)
    local Crafter = RSGCore.Functions.GetPlayer(targetId)
    if not Helper or not Crafter then return end

    local now = GetGameTimer()
    if (assistCooldown[src] or 0) > now then return notify(src, locale('assist_cooldown'), 'error') end
    if activeSessions[src] or (cfg.RequireBook and not hasBook(src)) then return notify(src, locale('assist_unavailable'), 'error') end

    local session = activeSessions[targetId]
    if not session or session.helpers[src] then return notify(src, locale('assist_unavailable'), 'error') end

    local helperCount = 0
    for _ in pairs(session.helpers) do helperCount = helperCount + 1 end
    if helperCount >= (cfg.MaxHelpers or 1) then return notify(src, locale('assist_full'), 'error') end

    local a, b = playerCoords(src), playerCoords(targetId)
    if not a or not b or #(a - b) > (cfg.Distance or 3.0) + 2.0 then return notify(src, locale('assist_too_far'), 'error') end

    local remaining = session.startedAt + session.crafttime - now
    if remaining < MIN_ASSIST_LEFT then return notify(src, locale('assist_unavailable'), 'error') end

    local cut = math.floor(remaining * (cfg.ReductionPercent or 0) / 100)
    session.crafttime = session.crafttime - cut
    session.helpers[src] = true
    assistCooldown[src] = now + (cfg.Cooldown or 0) * 1000

    TriggerClientEvent('rsg-crafting:client:assisted', targetId, session.crafttime)
    TriggerClientEvent('rsg-crafting:client:assistAnim', src, remaining - cut)
    notify(targetId, locale('assist_crafter'), 'success')
    notify(src, locale('assist_helper'), 'inform')
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeSessions[src] = nil
    assistCooldown[src] = nil
    learnedCache[src] = nil
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
    skillXP(src, amount, 'crafting (export)')
    CraftLog('xp', locale('log_xp_title'), locale('log_xp_desc', amount, GetInvokingResource() or locale('wh_unknown')), src, {
        { name = locale('wh_total_xp'), value = tostring(getXP(Player)) },
    })
    return true
end)

-- recipe discovery: key is the recipe's blueprint item name
exports('LearnRecipe', function(src, key)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player ~= nil and CraftingServer.LearnRecipe(Player, key)
end)

exports('ForgetRecipe', function(src, key)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player ~= nil and CraftingServer.ForgetRecipe(Player, key)
end)

exports('HasLearnedRecipe', function(src, key)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player ~= nil and blueprintRecipes[key] ~= nil and getLearned(Player)[key] == true
end)

local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepcopy(v) end
    return out
end

exports('GetCraftingRecipes', function() return deepcopy(Config.Crafting) end)
