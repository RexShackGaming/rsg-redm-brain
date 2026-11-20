local RSGCore = exports['rsg-core']:GetCoreObject()

local CRAFT_DISTANCE = 6.0

local function findStation(stationId)
    for _, station in ipairs((Config.Crafting and Config.Crafting.stations) or {}) do
        if station.id == stationId then return station end
    end
    return nil
end

local function findRecipe(station, recipeId)
    for _, recipe in ipairs(station.recipes or {}) do
        if recipe.id == recipeId then return recipe end
    end
    return nil
end

local function missingIngredient(src, ingredients)
    for _, ing in ipairs(ingredients) do
        if not exports['rsg-inventory']:HasItem(src, ing.item, ing.amount) then return ing end
    end
    return nil
end

RegisterNetEvent('rsg-gangs:server:craftItem', function(stationId, recipeId)
    local src = source
    if not Config.Crafting or not Config.Crafting.enabled then return end
    if type(stationId) ~= 'string' or type(recipeId) ~= 'string' then return end
    if RSGGangs.OnCooldown(src, 'craft', 1500) then return end

    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    if not citizenid then return end
    local gang = RSGGangs.FindGangByMember(citizenid)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end

    if not RSGGangs.HasPermission(gang.members[citizenid].rank, 'equipment') then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return
    end

    local station = findStation(stationId)
    if not station then return end

    if not RSGGangs.HasDeployedEquipmentItem(gang, station.equipmentId) then
        RSGGangs.Notify(src, locale('error_craft_no_station', station.label), 'error')
        return
    end

    -- Must be standing at the gang's own deployed station.
    if not RSGGangs.PlayerNearEquipment(src, gang, station.equipmentId, Config.StationInteractDistance + 2.0) then
        RSGGangs.Notify(src, locale('error_too_far'), 'error')
        return
    end

    local recipe = findRecipe(station, recipeId)
    if not recipe then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local missing = missingIngredient(src, recipe.ingredients)
    if missing then
        RSGGangs.Notify(src, locale('error_craft_missing_ingredients', missing.item), 'error')
        return
    end

    local outputAmount = recipe.output.amount or 1
    if not exports['rsg-inventory']:CanAddItem(src, recipe.output.item, outputAmount) then
        RSGGangs.Notify(src, locale('error_inventory_full'), 'error')
        return
    end

    -- Take the ingredients one by one; if anything fails, hand back what was already taken.
    local taken = {}
    for _, ing in ipairs(recipe.ingredients) do
        if exports['rsg-inventory']:RemoveItem(src, ing.item, ing.amount, false, 'gang-crafting') then
            taken[#taken + 1] = ing
        else
            for _, back in ipairs(taken) do
                exports['rsg-inventory']:AddItem(src, back.item, back.amount, false, false, 'gang-crafting-refund')
            end
            RSGGangs.Notify(src, locale('error_craft_missing_ingredients', ing.item), 'error')
            return
        end
    end

    if not exports['rsg-inventory']:AddItem(src, recipe.output.item, outputAmount, false, false, 'gang-crafting') then
        for _, back in ipairs(taken) do
            exports['rsg-inventory']:AddItem(src, back.item, back.amount, false, false, 'gang-crafting-refund')
        end
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end

    RSGGangs.Notify(src, locale('success_crafted', recipe.label), 'success')
end)

---------------------------------------------------------------------
-- Well pump: the gang's own deployed pump (the bucket swap and drinking are done by rsg-wellpump)
---------------------------------------------------------------------
-- Returns true when `src` is a gang member standing at their gang's deployed well pump.
local function canUsePump(src)
    local cfg = Config.WellPump
    if not cfg or not cfg.enabled then return false end

    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    if not citizenid then return false end
    local gang = RSGGangs.FindGangByMember(citizenid)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return false end

    if cfg.requirePermission and not RSGGangs.HasPermission(gang.members[citizenid].rank, 'equipment') then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return false
    end

    if not RSGGangs.HasDeployedEquipmentItem(gang, cfg.equipmentId) then
        RSGGangs.Notify(src, locale('error_craft_no_station', locale('ui_well_pump')), 'error')
        return false
    end

    if not RSGGangs.PlayerNearEquipment(src, gang, cfg.equipmentId, Config.StationInteractDistance + 2.0) then
        RSGGangs.Notify(src, locale('error_too_far'), 'error')
        return false
    end
    return true
end

RegisterNetEvent('rsg-gangs:server:fillBucket', function()
    local src = source
    -- the client plays a timed progress bar first, so refuse fills that come in faster than that
    local fillTime = exports['rsg-wellpump']:GetFillTime() or 6000
    if RSGGangs.OnCooldown(src, 'fillbucket', math.floor(fillTime * 0.8)) then return end
    if not canUsePump(src) then return end

    local ok, msg = exports['rsg-wellpump']:FillBucket(src)
    RSGGangs.Notify(src, msg, ok and 'success' or 'error')
end)

RegisterNetEvent('rsg-gangs:server:drinkWater', function()
    local src = source
    local cfg = Config.WellPump
    if not cfg or not cfg.drink then return end
    -- rsg-wellpump enforces its own drink cooldown; this only stops event spam
    if RSGGangs.OnCooldown(src, 'drinkwater', 1500) then return end
    if not canUsePump(src) then return end

    local ok, msg = exports['rsg-wellpump']:Drink(src)
    RSGGangs.Notify(src, msg, ok and 'success' or 'error')
end)
