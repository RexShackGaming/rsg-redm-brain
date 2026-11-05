-- Pure shared-ammo contract. Dormant until production migration is enabled.
WeaponCharacterAmmunition = {}
local A = WeaponCharacterAmmunition
local function integer(value)
    return type(value) == 'number' and value == value and value >= 0
        and value % 1 == 0 and value < math.huge
end
function A.Validate(pools, limits)
    if type(pools) ~= 'table' or type(limits) ~= 'table' then return nil, 'invalid_pools' end
    local result = {}
    for id, amount in pairs(pools) do
        if not limits[id] then return nil, 'unknown_ammunition' end
        if not integer(amount) or not integer(limits[id]) or amount > limits[id] then
            return nil, 'invalid_count'
        end
        result[id] = amount
    end
    for id, maximum in pairs(limits) do
        if not integer(maximum) then return nil, 'invalid_limit' end
        result[id] = result[id] or 0
    end
    return result
end
function A.Observe(record, report, limits)
    if type(record) ~= 'table' or type(report) ~= 'table' then return nil, 'invalid_report' end
    if report.characterId ~= record.characterId or report.sessionId ~= record.sessionId
        or report.epoch ~= record.epoch then return nil, 'stale_session' end
    if report.revision ~= record.revision then return nil, 'stale_revision' end
    local previous, failure = A.Validate(record.pools, limits)
    if not previous then return nil, failure end
    local observed
    observed, failure = A.Validate(report.pools, limits)
    if not observed then return nil, failure end
    -- Missing observations must not turn into consumption of an entire pool.
    local changed=false
    for id in pairs(limits) do
        if report.pools[id] == nil then return nil, 'incomplete_observation' end
        if observed[id] > previous[id] then return nil, 'native_pool_increased' end
        changed=changed or observed[id]~=previous[id]
    end
    return { characterId = record.characterId, sessionId = record.sessionId,
        epoch = record.epoch, revision = record.revision + (changed and 1 or 0), pools = observed, changed=changed }
end
-- Server-only calculation used INSIDE the same transaction as inventory edits.
-- Positive amount consumes loose inventory; negative returns carried rounds.
function A.Transfer(record, id, amount, limits)
    if type(amount) ~= 'number' or amount == 0 or not integer(math.abs(amount)) then
        return nil, 'invalid_transfer'
    end
    local pools, failure = A.Validate(record.pools, limits)
    if not pools then return nil, failure end
    if pools[id] == nil then return nil, 'unknown_ammunition' end
    local nextAmount = pools[id] + amount
    if nextAmount < 0 then return nil, 'insufficient_ammunition' end
    if nextAmount > limits[id] then return nil, 'capacity_exceeded' end
    pools[id] = nextAmount
    return { characterId = record.characterId, sessionId = record.sessionId,
        epoch = record.epoch, revision = record.revision + 1, pools = pools },
        { ammunitionId = id, inventoryDelta = -amount }
end
