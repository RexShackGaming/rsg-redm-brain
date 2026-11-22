-- The stash id stays 'rsg_gang_stash_<uuid>' so existing stashes keep their contents.
local function stashIdFor(gang)
    return 'rsg_gang_stash_' .. gang.stashId
end

local function findTier(tierId)
    for _, tier in ipairs((Config.GangStash and Config.GangStash.tiers) or {}) do
        if tier.id == tierId then return tier end
    end
    return nil
end

local function currentTier(gang)
    return findTier(gang.stashTier or 'small') or (Config.GangStash.tiers and Config.GangStash.tiers[1])
end

RegisterNetEvent('rsg-gangs:server:openGangStash', function()
    local src = source
    if not Config.GangStash or not Config.GangStash.enabled then return end
    if RSGGangs.OnCooldown(src, 'stash', 1000) then return end

    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    if not citizenid then return end
    local gang = RSGGangs.FindGangByMember(citizenid)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end

    local minWeight = Config.GangStash.minWeight or 0
    if RSGGangs.RankWeight(gang, citizenid) < minWeight then
        RSGGangs.Notify(src, locale('error_stash_rank'), 'error')
        return
    end

    local boxId = Config.GangStash.equipmentId
    if not RSGGangs.HasDeployedEquipmentItem(gang, boxId) then
        RSGGangs.Notify(src, locale('error_craft_no_station', Config.GangStash.label), 'error')
        return
    end

    -- Must be next to the gang's own deployed strongbox.
    if not RSGGangs.PlayerNearEquipment(src, gang, boxId, Config.StationInteractDistance + 2.0) then
        RSGGangs.Notify(src, locale('error_too_far'), 'error')
        return
    end

    local tier = currentTier(gang)
    local ok, err = pcall(function()
        exports['rsg-inventory']:OpenInventory(src, stashIdFor(gang), {
            label = Config.GangStash.label .. (tier and (' (' .. tier.label .. ')') or ''),
            maxweight = tier and tier.maxWeight or 500000,
            slots = tier and tier.slots or 50,
        })
    end)

    if not ok then
        print(('^1[rsg-gangs] failed to open the stash for %s: %s^7'):format(gang.name, tostring(err)))
        RSGGangs.Notify(src, locale('notify_stash_open_error'), 'error')
    end
end)

RegisterNetEvent('rsg-gangs:server:upgradeGangStash', function()
    local src = source
    if not Config.GangStash or not Config.GangStash.enabled then return end
    if RSGGangs.OnCooldown(src, 'stashUpgrade', 1500) then return end

    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    if not citizenid then return end
    local gang = RSGGangs.FindGangByMember(citizenid)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end

    -- Upgrading spends gang money, so it has its own permission (not 'withdraw').
    if not RSGGangs.HasPermission(gang, citizenid, 'upgrade') then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return
    end

    local currentIndex = RSGGangs.StashTierIndex(gang.stashTier or 'small') or 1
    local nextTier = Config.GangStash.tiers[currentIndex + 1]
    if not nextTier then
        RSGGangs.Notify(src, locale('error_stash_max_tier'), 'error')
        return
    end

    local cost = nextTier.upgradeCost or 0
    if gang.bank < cost then
        RSGGangs.Notify(src, locale('error_insufficient_gang_funds'), 'error')
        return
    end

    -- The money comes out of the rsg-society account first; if the tier cannot be saved it is paid back.
    if not RSGGangs.AdjustBank(gang, -cost) then
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end
    if not RSGGangs.DbOk('UPDATE rsg_gangs SET stash_tier = ? WHERE name = ?', { nextTier.id, gang.name }) then
        RSGGangs.AdjustBank(gang, cost)
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end
    gang.stashTier = nextTier.id

    RSGGangs.Log('Gang stash upgraded', ('%s upgraded to %s by %s'):format(gang.name, nextTier.id, citizenid))
    RSGGangs.AddLog(gang, citizenid, 'stash_upgrade', nextTier.label, cost)
    RSGGangs.Notify(src, locale('success_stash_upgraded', nextTier.label), 'success')
    RSGGangs.BroadcastGangUpdate(gang)
end)
