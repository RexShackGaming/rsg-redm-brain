-- Shared native pools are observations, not per-item ownership. Allocate each
-- decrease once, only to explicitly identified firing instances. Ambiguous
-- decreases fail closed rather than charging another weapon's reserve.
WeaponAmmunitionPools = {}

function WeaponAmmunitionPools.Allocate(previous, observed, owners, shots)
    local result, totals = {}, {}
    for slot, pools in pairs(owners or {}) do
        result[slot] = {}
        for id, amount in pairs(pools) do
            if type(amount) ~= 'number' or amount < 0 or amount % 1 ~= 0 then
                return nil, 'invalid_ownership'
            end
            result[slot][id] = amount
            totals[id] = (totals[id] or 0) + amount
        end
    end
    for id, before in pairs(previous or {}) do
        local after = observed and observed[id]
        if type(before) ~= 'number' or type(after) ~= 'number'
            or before < 0 or after < 0 or before % 1 ~= 0 or after % 1 ~= 0 then
            return nil, 'invalid_observation'
        end
        -- Native pickups and reload artifacts cannot grant owned ammunition.
        local decrease = math.max(0, before - after)
        local attributed = 0
        for slot, report in pairs(shots or {}) do
            local consumed = report[id] or 0
            if type(consumed) ~= 'number' or consumed < 0 or consumed % 1 ~= 0
                or not result[slot] or consumed > (result[slot][id] or 0) then
                return nil, 'invalid_attribution'
            end
            attributed = attributed + consumed
            -- A global pool includes several weapon families. Zero consumption
            -- must not inject foreign ammunition keys into another item report.
            if result[slot][id] ~= nil then
                result[slot][id] = result[slot][id] - consumed
            end
        end
        if attributed ~= decrease then return nil, 'ambiguous_consumption' end
    end
    for _, report in pairs(shots or {}) do
        for id, amount in pairs(report) do
            if previous[id] == nil and amount ~= 0 then return nil, 'unknown_pool' end
        end
    end
    return result
end
