local RSGCore = exports['rsg-core']:GetCoreObject()
local StateOf = Player -- keep the statebag accessor before local 'Player' variables shadow it

local PACK = 'cigarettes'

local busy = {}    -- [src] = true while a use is going through the flow
local pending = {} -- [src] = { item, slot, expires } smokers waiting for someone to light them
local offerAt = {} -- [src] = os.time() of the last light offer (anti-spam)
local warnedSubstance = false

-- client reason codes -> locale keys
local REASONS = {
    busy     = 'cannot_busy',
    mounted  = 'cannot_mounted',
    swimming = 'cannot_swimming',
    vehicle  = 'cannot_vehicle',
    now      = 'cannot_now',
}

local STRESS = {
    cigarette      = 'CigaretteRelieveStress',
    cigar          = 'CigarRelieveStress',
    pipe           = 'PipeRelieveStress',
    chewingtobacco = 'ChewingRelieveStress',
}

---------------------------------
-- helpers
---------------------------------
local function notify(src, description, notifyType)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title       = locale('notify_title'),
        description = description,
        type        = notifyType or 'inform',
        duration    = 3000,
    })
end

local function itemLabel(name)
    local item = RSGCore.Shared.Items[name]
    return item and item.label or name
end

local function drugsRunning()
    return GetResourceState('rsg-drugs') == 'started'
end

local function inRehab(src)
    return Config.Nicotine.Enabled and Config.Nicotine.BlockInRehab and drugsRunning()
        and exports['rsg-drugs']:IsInRehab(src) == true
end

-- stress is relieved on the server through rsg-hud (it owns the needs and limits client-side changes)
local function relieveStress(src, kind)
    local amount = tonumber(Config[STRESS[kind]]) or 0
    if amount > 0 and GetResourceState('rsg-hud') == 'started' then
        exports['rsg-hud']:RelieveStress(src, amount)
    end
end

local function addNicotine(src, kind)
    local cfg = Config.Nicotine
    local amount = cfg.Enabled and cfg.Amount[kind]
    if not amount or amount <= 0 or not drugsRunning() then return end
    if not exports['rsg-drugs']:AddUse(src, cfg.Substance, amount) and not warnedSubstance then
        warnedSubstance = true
        print(('^3[rsg-smoking]^7 rsg-drugs refused the use: add a "%s" substance to its config (installation/rsg-drugs_tobacco.lua)'):format(cfg.Substance))
    end
end

---------------------------------
-- multi-use items (cigarette pack, match box)
-- `def` needs `uses` (maximum) and optionally `key` (info field holding the uses left)
---------------------------------
local function usesKey(def)
    return def.key or 'uses'
end

local function usesLeft(info, def)
    info = type(info) == 'table' and info or {}
    local uses = tonumber(info[usesKey(def)]) or tonumber(info.uses) -- 'uses' is what the first pack version stored
    if not uses then return def.uses end -- no info = a full pack
    return math.max(0, math.min(math.floor(uses), def.uses))
end

-- takes one use out of the item in `slot`; the item goes when its last use does.
-- returns the uses left, or nil when the inventory call failed
local function spendUse(owner, itemName, slot, invItem, def, reason)
    local inv = exports['rsg-inventory']
    local left = usesLeft(invItem.info, def) - 1
    if left <= 0 then
        if not inv:RemoveItem(owner, itemName, 1, slot, reason) then return nil end
        return 0
    end
    local info = {}
    for k, v in pairs(invItem.info or {}) do info[k] = v end
    info.uses = nil
    info[usesKey(def)] = left
    if (tonumber(invItem.amount) or 1) > 1 then
        -- a stack from before the item became a unique pack: split one off so only it loses a use
        if not inv:RemoveItem(owner, itemName, 1, slot, reason) then return nil end
        if not inv:AddItem(owner, itemName, 1, info, nil, reason) then
            inv:AddItem(owner, itemName, 1, nil, nil, reason) -- give the unit back untouched
            return nil
        end
        return left
    end
    if not inv:SetItemInfo(owner, slot, info) then return nil end
    return left
end

---------------------------------
-- lighters
---------------------------------
-- first lighter the player carries, in Config.LighterItems order
local function findLighter(src)
    local inv = exports['rsg-inventory']
    for _, name in ipairs(Config.LighterItems) do
        local item = inv:GetItemByName(src, name)
        if item and item.slot then
            return { name = name, slot = item.slot, item = item, def = Config.Lighters[name] or {} }
        end
    end
    return nil
end

-- spends one light and rolls for a failed light. false = the smoke must not start
local function useLighter(owner, lighter, smoker)
    local def = lighter.def
    if def.uses then
        local left = spendUse(owner, lighter.name, lighter.slot, lighter.item, def, 'rsg-smoking:light')
        if not left then return false end
        if left <= (def.warnAt or 0) then
            notify(owner, left == 0 and locale('box_empty') or locale('box_left', left), 'inform')
        end
    end
    local fail = tonumber(def.failChance) or 0
    if fail > 0 and math.random(100) <= fail then
        notify(smoker, locale('match_failed'), 'warning')
        return false
    end
    return true
end

---------------------------------
-- asking for a light
---------------------------------
local function clearPending(src)
    if pending[src] then
        pending[src] = nil
        StateOf(src).state:set('smokingNeedsLight', nil, true)
    end
end

local function askForLight(src, itemName, slot)
    local cfg = Config.ShareLight
    if not cfg.Enabled then
        return notify(src, locale('missing_item', itemLabel(Config.LighterItems[1])), 'error')
    end
    local request = { item = itemName, slot = slot, expires = os.time() + cfg.Timeout }
    pending[src] = request
    StateOf(src).state:set('smokingNeedsLight', true, true)
    notify(src, locale('need_light'), 'inform')
    SetTimeout(cfg.Timeout * 1000, function()
        if pending[src] == request then clearPending(src) end
    end)
end

---------------------------------
-- the use flow
-- lightFrom: server id of the player whose lighter is used (shared light), nil = the smoker's own
---------------------------------
local function useSmokable(src, itemName, def, usedItem, lightFrom)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local metadata = Player.PlayerData.metadata
    if metadata.isdead or metadata.ishandcuffed then return end
    if inRehab(src) then return notify(src, locale('in_rehab'), 'error') end

    clearPending(src)
    local inv = exports['rsg-inventory']
    local slot = usedItem and tonumber(usedItem.slot)

    -- the used item (checked by slot, so the right pack is used) plus everything it requires
    local invItem = slot and inv:GetItemBySlot(src, slot) or nil
    if not invItem or invItem.name ~= itemName then
        invItem = inv:GetItemByName(src, itemName)
        slot = invItem and invItem.slot or nil
    end
    if not invItem or not slot then
        return notify(src, locale('missing_item', itemLabel(itemName)), 'error')
    end
    for _, name in ipairs(def.requires or {}) do
        if not inv:HasItem(src, name, 1) then
            return notify(src, locale('missing_item', itemLabel(name)), 'error')
        end
    end

    local isPack = def.uses ~= nil
    if isPack and usesLeft(invItem.info, def) <= 0 then
        inv:RemoveItem(src, itemName, 1, slot, 'rsg-smoking:empty')
        return notify(src, locale(def.emptyMsg or 'pack_empty'), 'error')
    end

    -- a lighter is needed: own one, or the one belonging to the player offering a light
    local giver = lightFrom or src
    local lighter = def.lighter and findLighter(giver) or nil
    if def.lighter and not lighter then
        if lightFrom then return end
        return askForLight(src, itemName, slot)
    end

    -- ask the client first so nothing is consumed if the player cannot smoke right now
    local reason = RSGCore.Functions.AwaitClientCallback('rsg-smoking:client:canSmoke', src, 3000, def.kind)
    if reason ~= 'ok' then
        return notify(src, locale(REASONS[reason] or 'cannot_now'), 'error')
    end

    -- the player may have moved things while the client was answering: check again
    local current = inv:GetItemBySlot(src, slot)
    if not current or current.name ~= itemName then return end
    if def.lighter then
        lighter = findLighter(giver)
        if not lighter then return notify(src, locale('missing_item', itemLabel(Config.LighterItems[1])), 'error') end
        if not useLighter(giver, lighter, src) then return end
    end

    if isPack then
        -- take one cigarette out of the pack; the pack goes when it is empty
        local left = spendUse(src, itemName, slot, current, def, 'rsg-smoking:use')
        if not left then return end
        notify(src, left <= 0 and locale(def.emptyMsg or 'pack_empty') or locale(def.leftMsg or 'pack_left', left), 'inform')
    elseif def.legacy then
        -- old pack item: swap it for a 'cigarettes' pack holding what is left
        local remaining = def.legacy - 1
        if not inv:RemoveItem(src, itemName, 1, slot, 'rsg-smoking:convert') then return end
        if remaining > 0 then
            local packDef = Config.Smokables[PACK] or {}
            local added = inv:CanAddItem(src, PACK, 1)
                and inv:AddItem(src, PACK, 1, { [usesKey(packDef)] = remaining }, nil, 'rsg-smoking:convert')
            if not added then
                -- hand the old pack back so nothing is lost, and do not smoke
                print(('^1[rsg-smoking]^7 could not give %s to player %s, restoring %s'):format(PACK, src, itemName))
                inv:AddItem(src, itemName, 1, nil, nil, 'rsg-smoking:convert-restore')
                return notify(src, locale('cannot_now'), 'error')
            end
            notify(src, locale('pack_left', remaining), 'inform')
        end
    else
        local consume = def.consume or itemName
        if not inv:RemoveItem(src, consume, 1, nil, 'rsg-smoking:use') then return end
    end

    relieveStress(src, def.kind)
    addNicotine(src, def.kind)
    TriggerClientEvent('rsg-smoking:client:' .. def.kind, src)

    if lightFrom then
        notify(lightFrom, locale('light_shared'), 'success')
        notify(src, locale('light_received'), 'success')
    end
end

local function runUse(src, itemName, def, usedItem, lightFrom)
    if busy[src] then return end
    busy[src] = true
    local ok, err = pcall(useSmokable, src, itemName, def, usedItem, lightFrom)
    busy[src] = nil
    if not ok then
        print(('^1[rsg-smoking]^7 error using %s: %s'):format(itemName, err))
    end
end

for itemName, def in pairs(Config.Smokables) do
    RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
        runUse(source, itemName, def, item)
    end)
end

---------------------------------
-- offering a light to a player who asked for one (client: rsg-target option on that player)
---------------------------------
RegisterNetEvent('rsg-smoking:server:offerLight', function(targetId)
    local src = source
    if not Config.ShareLight.Enabled then return end

    targetId = math.tointeger(tonumber(targetId))
    if not targetId or targetId == src then return end

    local holder = RSGCore.Functions.GetPlayer(src)
    local smoker = RSGCore.Functions.GetPlayer(targetId)
    if not holder or not smoker then return end

    local now = os.time()
    if offerAt[src] and now - offerAt[src] < Config.ShareLight.OfferCooldown then return end
    offerAt[src] = now

    local metadata = holder.PlayerData.metadata
    if metadata.isdead or metadata.ishandcuffed then return end

    -- the target must really be waiting for a light, and be close enough
    local request = pending[targetId]
    if not request or request.expires < now or busy[targetId] then return end
    local def = Config.Smokables[request.item]
    if not def then return clearPending(targetId) end

    local distance = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId)))
    if distance > Config.ShareLight.Distance then return end

    if not findLighter(src) then
        return notify(src, locale('missing_item', itemLabel(Config.LighterItems[1])), 'error')
    end

    runUse(targetId, request.item, def, { slot = request.slot }, src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    offerAt[src] = nil
    pending[src] = nil
end)
