-- =========================================================================================
-- Server-side usable item registration & consumption
-- =========================================================================================
local RSGCore = exports['rsg-core']:GetCoreObject()
local config = Config

-- Safety net: if the client never reports back (crash, desync) the lock is released after this
local CONSUME_TIMEOUT = 30000

---Active consumption per player. Acts as a one-time token: the return item / refund can only
---be claimed once, and only for the item the server actually removed.
---@type table<number, { item: string, category: string, started: number, expires: number, factor: number, spoiled: boolean, quality: number?, bar: boolean?, price: number? }>
local pending = {}
local lastAction = {} -- [src] = GetGameTimer(), shared cooldown for bar / share / hangover events

---[itemName] = category, built once from the config
local itemCategory = {}
for category, items in pairs(config.Consumables) do
    for name in pairs(items) do itemCategory[name] = category end
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function notify(src, key, nType, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('title_consume'),
        description = locale(key, ...),
        type = nType or 'error',
        duration = 3000,
    })
end

local function onCooldown(src, ms)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < ms then return true end
    lastAction[src] = now
    return false
end

local function itemLabel(name)
    local shared = RSGCore.Shared.Items[name]
    return shared and shared.label or name
end

-- rsg-inventory AddItem/RemoveItem show the ItemBox themselves
local function addItem(src, itemName, reason)
    if not RSGCore.Shared.Items[itemName] then return end
    if not exports['rsg-inventory']:CanAddItem(src, itemName, 1) then
        return notify(src, 'inventory_full')
    end
    exports['rsg-inventory']:AddItem(src, itemName, 1, nil, nil, reason)
end

-- =========================================================================================
-- Alcohol tolerance (stored in player metadata, decays over real time)
-- =========================================================================================

local function getTolerance(Player)
    local tol = config.Tolerance
    if not tol or not tol.Enabled then return 0.0 end
    local md = Player.PlayerData.metadata or {}
    local value = tonumber(md.alcoholtolerance) or 0.0
    local since = tonumber(md.alcoholtolerancetime) or os.time()
    value = value - (os.time() - since) / 86400 * tol.DecayPerDay
    return clamp(value, 0.0, tol.Max)
end

---Multiplier applied to the drunk / pass-out thresholds on the client (1.0 = no tolerance)
local function toleranceMultiplier(Player)
    local tol = config.Tolerance
    if not tol or not tol.Enabled then return 1.0 end
    return 1.0 + (getTolerance(Player) / tol.Max) * tol.MaxThresholdBonus
end

local function addTolerance(Player, alcohol)
    local tol = config.Tolerance
    if not tol or not tol.Enabled or alcohol <= 0 then return end
    local value = clamp(getTolerance(Player) + alcohol * tol.GainPerAlcohol, 0.0, tol.Max)
    Player.Functions.SetMetaData('alcoholtolerance', value)
    Player.Functions.SetMetaData('alcoholtolerancetime', os.time())
    TriggerClientEvent('rsg-consume:client:tolerance', Player.PlayerData.source, toleranceMultiplier(Player))
end

RSGCore.Functions.CreateCallback('rsg-consume:server:getTolerance', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    cb(Player and toleranceMultiplier(Player) or 1.0)
end)

exports('GetTolerance', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and getTolerance(Player) or 0.0
end)

-- =========================================================================================
-- Effects (hunger / thirst / stress are applied here; rsg-hud is authoritative)
-- =========================================================================================

---Amount for one stat: positive gains are scaled by progress, quality and spoilage,
---negative values (spirits drying the throat, stress gain) only by progress.
local function scaledAmount(value, progress, active)
    value = tonumber(value) or 0
    if value > 0 then
        local f = progress * (active.factor or 1.0)
        if active.spoiled then f = f * config.Spoilage.EffectFactor end
        return value * f
    end
    return value * progress
end

local function changeNeed(src, hud, state, key, amount)
    if amount == 0 then return end
    local current = tonumber(state[key]) or 100
    local value = clamp(current + amount, 0, 100)
    if hud then
        exports['rsg-hud']:SetNeed(src, key, value)
    else
        TriggerClientEvent(key == 'hunger' and 'hud:client:UpdateHunger' or 'hud:client:UpdateThirst', src, value)
    end
end

local function changeStress(src, hud, amount)
    amount = math.floor(amount + 0.5)
    if not hud or amount == 0 then return end -- stress needs rsg-hud
    if amount > 0 then
        exports['rsg-hud']:RelieveStress(src, amount)
    else
        exports['rsg-hud']:GainStress(src, -amount)
    end
end

local function applyEffects(src, data, progress, active)
    local hud = GetResourceState('rsg-hud') == 'started'
    local state = Player(src).state

    changeNeed(src, hud, state, 'hunger', scaledAmount(data.hunger, progress, active))
    changeNeed(src, hud, state, 'thirst', scaledAmount(data.thirst, progress, active))

    local stress = scaledAmount(data.stress, progress, active)
    if active.spoiled and stress > 0 then stress = 0 end
    changeStress(src, hud, stress)

    -- rotten food: sick, thirsty and stressed
    if active.spoiled then
        local sp = config.Spoilage
        changeNeed(src, hud, state, 'thirst', -sp.ThirstLoss)
        changeStress(src, hud, -sp.StressGain)
        TriggerClientEvent('rsg-consume:client:sick', src, sp.SickDuration)
    end
end

---Timed buffs and warmth are decided here and sent to the client, which only plays them.
local function sendTimedEffects(src, itemName, category, data, progress, active)
    if active.spoiled then return end
    local scale = progress * (active.factor or 1.0)

    if data.buff and config.Buffs and config.Buffs.Enabled then
        local buffs = {}
        for kind, b in pairs(data.buff) do
            if (kind == 'health' or kind == 'stamina') and tonumber(b.amount) and tonumber(b.interval) and tonumber(b.duration) then
                buffs[kind] = { amount = b.amount, interval = math.max(500, b.interval), duration = math.floor(b.duration * scale) }
            end
        end
        if next(buffs) then TriggerClientEvent('rsg-consume:client:buff', src, buffs) end
    end

    local w = config.Warmth
    if w and w.Enabled then
        local def = data.warmth or (w.Categories and w.Categories[category])
        if def and tonumber(def.amount) and tonumber(def.duration) and def.amount ~= 0 then
            TriggerClientEvent('rsg-consume:client:warmth', src, def.amount, math.floor(def.duration * scale))
        end
    end
end

-- =========================================================================================
-- Starting a consumption (item use or bar order)
-- =========================================================================================

---True when the item would only restore a need that is already (nearly) full.
---Items with alcohol, or that restore neither hunger nor thirst, are never blocked.
local function isFull(src, data)
    local f = config.Fullness
    if not f or not f.Enabled then return false end
    if (tonumber(data.alcohol) or 0) > 0 then return false end
    local wantsHunger = (tonumber(data.hunger) or 0) > 0
    local wantsThirst = (tonumber(data.thirst) or 0) > 0
    if not wantsHunger and not wantsThirst then return false end
    local state = Player(src).state
    if wantsHunger and (tonumber(state.hunger) or 100) < f.BlockAt then return false end
    if wantsThirst and (tonumber(state.thirst) or 100) < f.BlockAt then return false end
    return true
end

---Works out quality scaling and spoilage from the item's quality (rsg-inventory decay, 0-100)
local function evaluateQuality(category, quality)
    local factor, spoiled = 1.0, false
    quality = tonumber(quality)
    if not quality then return factor, spoiled end
    quality = clamp(quality, 0, 100)

    local q = config.Quality
    if q and q.Enabled then
        factor = q.MinFactor + (1.0 - q.MinFactor) * (quality / 100)
    end

    local sp = config.Spoilage
    if sp and sp.Enabled and sp.Categories[category] and quality < sp.Below then
        local chance = sp.MaxChance * (sp.Below - quality) / sp.Below
        spoiled = math.random() * 100 < chance
    end
    return factor, spoiled
end

local function begin(src, itemName, category, extra)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local factor, spoiled = evaluateQuality(category, extra.quality)
    local now = GetGameTimer()
    pending[src] = {
        item = itemName, category = category, started = now, expires = now + CONSUME_TIMEOUT,
        factor = factor, spoiled = spoiled, bar = extra.bar, price = extra.price,
    }
    TriggerClientEvent('rsg-consume:client:consume', src, itemName, category, {
        tolerance = toleranceMultiplier(Player),
        cancel = config.Cancel and config.Cancel.Enabled or false,
        spoiled = spoiled,
    })
end

local function isBusy(src)
    local active = pending[src]
    return active and active.expires > GetGameTimer()
end

---Registers every item in a category as usable. The item is removed server-side
---BEFORE the client plays the animation, so the client never decides whether it is consumed.
local function registerConsumables(category, items)
    for itemName, data in pairs(items) do
        if not RSGCore.Shared.Items[itemName] then
            print(('^3[rsg-consume] Item "%s" (%s) is not in rsg-core shared items, skipping^7'):format(itemName, category))
        else
            RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
                local src = source
                if not RSGCore.Functions.GetPlayer(src) then return end
                if isBusy(src) then return notify(src, 'busy') end
                if isFull(src, data) then return notify(src, 'full') end

                local quality = item and item.info and item.info.quality
                if not exports['rsg-inventory']:RemoveItem(src, itemName, 1, item and item.slot, 'rsg-consume') then return end

                begin(src, itemName, category, { quality = quality })
            end)
        end
    end
end

for category, items in pairs(config.Consumables) do
    registerConsumables(category, items)
end

-- =========================================================================================
-- Finishing
-- =========================================================================================

---Client reports the consumption finished.
---consumed  = true  -> apply the effects and give the configured return item (e.g. emptybottle)
---consumed  = false -> client could not play it (busy / passed out / dead / swimming), refund
---cancelled = true  -> player stopped early. The server measures the progress itself:
---                     below Config.Cancel.RefundBelow the item is refunded, above it the
---                     effects are applied in proportion and the return item is still given.
---A "true" that arrives faster than the animation can possibly run (Config.MinDuration) is
---treated as a skipped animation: nothing is applied and the item is refunded.
RegisterNetEvent('rsg-consume:server:finish', function(consumed, cancelled)
    local src = source
    local active = pending[src]
    if not active then return end -- no token: spam / replay attempt
    pending[src] = nil

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local data = config.Consumables[active.category][active.item]
    local progress = 1.0
    local ok = false

    if consumed == true then
        local elapsed = GetGameTimer() - active.started
        if cancelled == true and config.Cancel and config.Cancel.Enabled then
            local duration = config.Duration and config.Duration[active.category] or 5000
            progress = clamp(elapsed / duration, 0.0, 1.0)
            ok = progress >= config.Cancel.RefundBelow
        else
            local minTime = config.MinDuration and config.MinDuration[active.category] or 0
            ok = elapsed >= minTime
        end
    end

    if not ok then
        -- refund: the item, or the money for a bar order
        if active.bar then
            if active.price and active.price > 0 then Player.Functions.AddMoney('cash', active.price, 'rsg-consume-bar-refund') end
        else
            addItem(src, active.item, 'rsg-consume-refund')
        end
        return
    end

    applyEffects(src, data, progress, active)
    sendTimedEffects(src, active.item, active.category, data, progress, active)
    addTolerance(Player, scaledAmount(data.alcohol, progress, { factor = 1.0 }))
    if data.giveItem and not active.bar then addItem(src, data.giveItem, 'rsg-consume-return') end

    -- other resources (e.g. rsg-drugs addiction) hook this instead of relaying a client event
    TriggerEvent('rsg-consume:server:consumed', src, active.item, active.category, data, {
        progress = progress, spoiled = active.spoiled, bar = active.bar == true,
    })
end)

-- =========================================================================================
-- Hangover after passing out (only ever costs the player something)
-- =========================================================================================

RegisterNetEvent('rsg-consume:server:passedOut', function()
    local src = source
    local h = config.Hangover
    if not h or not h.Enabled or not RSGCore.Functions.GetPlayer(src) then return end
    if onCooldown(src, 60000) then return end
    local hud = GetResourceState('rsg-hud') == 'started'
    changeNeed(src, hud, Player(src).state, 'thirst', -h.ThirstLoss)
    changeStress(src, hud, -h.StressGain)
end)

-- =========================================================================================
-- Bar orders: pay at the bar, drink on the spot (no item is created)
-- =========================================================================================

RegisterNetEvent('rsg-consume:server:bar', function(barIndex, itemName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(barIndex) ~= 'number' or type(itemName) ~= 'string' then return end

    local bar = config.Bars and config.Bars[barIndex]
    local price = bar and bar.items and tonumber(bar.items[itemName])
    local category = itemCategory[itemName]
    if not bar or not price or price < 0 or not category then return end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - bar.coords) > (bar.radius or 3.0) + 2.0 then return end
    if onCooldown(src, 1000) then return end
    if isBusy(src) then return notify(src, 'busy') end
    if isFull(src, config.Consumables[category][itemName]) then return notify(src, 'full') end

    if price > 0 and not Player.Functions.RemoveMoney('cash', price, 'rsg-consume-bar') then
        return notify(src, 'bar_no_money')
    end
    begin(src, itemName, category, { bar = true, price = price })
end)

-- =========================================================================================
-- Share a drink with a nearby player (hands them one item; they drink it themselves)
-- =========================================================================================

RegisterNetEvent('rsg-consume:server:share', function(targetId, itemName)
    local src = source
    local s = config.Share
    if not s or not s.Enabled then return end
    targetId = tonumber(targetId)
    if not targetId or targetId == src or type(itemName) ~= 'string' or not s.Items[itemName] then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Player or not Target then return end
    if onCooldown(src, 3000) then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > s.Distance + 1.0 then
        return notify(src, 'share_far')
    end
    if not exports['rsg-inventory']:CanAddItem(targetId, itemName, 1) then
        return notify(src, 'share_full')
    end
    if not exports['rsg-inventory']:RemoveItem(src, itemName, 1, nil, 'rsg-consume-share') then
        return notify(src, 'share_failed')
    end
    exports['rsg-inventory']:AddItem(targetId, itemName, 1, nil, nil, 'rsg-consume-share')

    notify(src, 'share_given', 'success', itemLabel(itemName))
    notify(targetId, 'share_received', 'inform', itemLabel(itemName))
end)

AddEventHandler('playerDropped', function()
    local src = source
    pending[src] = nil
    lastAction[src] = nil
end)
