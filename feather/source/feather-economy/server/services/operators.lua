-- Operated accounts (extension, off by default).
--
-- Economy knows a closed set of movement shapes. It does not know any consumer's
-- reason codes: an operator resource registers its own codes at start and maps
-- each to one or more shapes. A posting with a registered code is allowed only when
-- the accounts match one of its shapes, and every shape that touches an organization
-- treasury requires that treasury to be bound to the caller (EnsureOperatedTreasury).
--
-- Registrations live in memory: an operator registers on every start, a stopped
-- operator's codes are released, and a code belongs to one resource at a time.

EconomyOperators = {}

local registry = {} -- resource -> { [reasonCode] = { shape, ... } }
local owners = {}   -- reasonCode -> resource

local RESERVED_PREFIXES = { 'shop.', 'economy.' }

local function InGroup(group, resource)
    local members = Config.Access[group]
    return type(resource) == 'string' and type(members) == 'table' and members[resource] == true
end

local function CharacterAccount(account, accountType)
    return account.owner_type == 'character' and account.account_type == accountType
end

-- A wallet the acting character owns. Without an actor, only a movement inside
-- one character's own accounts qualifies.
local function ActorWallet(wallet, from, to, context)
    if not CharacterAccount(wallet, 'wallet') or type(wallet.owner_id) ~= 'string' then return false end
    local actor = type(context) == 'table' and context.actorCharacterId or nil
    if type(actor) == 'string' then return wallet.owner_id:lower() == actor:lower() end
    return from.owner_type == 'character' and to.owner_type == 'character' and from.owner_id == to.owner_id
end

-- An organization treasury bound to `resource`. Posting passes its transaction
-- connection so the read sees the same snapshot as the balances.
local function OperatedBy(account, resource, database)
    if account.account_type ~= 'treasury' or account.owner_type ~= 'organization'
        or type(account.owner_id) ~= 'string' then return false end
    return (database or DB).value(
        'SELECT `operator_resource` FROM `economy_treasury_operators` WHERE `organization_id`=?',
        account.owner_id:lower()) == resource
end
EconomyOperators.OperatedBy = OperatedBy

-- Shapes. `group` is the access list the caller needs to use the shape; `supply`
-- marks the two shapes that create currency (also gated by Config.OperatorSupply
-- and a Core policy decision).
local SHAPES = {
    actor_wallet_to_operated = { operation = 'transfer', group = 'trustedTreasuryOperators',
        allowed = function(from, to, resource, context, database)
            return ActorWallet(from, from, to, context) and OperatedBy(to, resource, database)
        end },
    operated_to_actor_wallet = { operation = 'transfer', group = 'trustedTreasuryOperators',
        allowed = function(from, to, resource, context, database)
            return ActorWallet(to, from, to, context) and OperatedBy(from, resource, database)
        end },
    operated_to_wallet = { operation = 'transfer', group = 'trustedTreasuryOperators',
        allowed = function(from, to, resource, _, database)
            return CharacterAccount(to, 'wallet') and OperatedBy(from, resource, database)
        end },
    operated_to_sink = { operation = 'transfer', group = 'trustedTreasuryOperators',
        allowed = function(from, to, resource, _, database)
            return to.account_type == 'system_sink' and OperatedBy(from, resource, database)
        end },
    bank_to_operated = { operation = 'transfer', group = 'trustedBankTransactors', also = 'trustedTreasuryOperators',
        allowed = function(from, to, resource, _, database)
            return CharacterAccount(from, 'bank') and OperatedBy(to, resource, database)
        end },
    operated_to_bank = { operation = 'transfer', group = 'trustedBankTransactors', also = 'trustedTreasuryOperators',
        allowed = function(from, to, resource, _, database)
            return CharacterAccount(to, 'bank') and OperatedBy(from, resource, database)
        end },
    actor_wallet_to_bank = { operation = 'transfer', group = 'trustedBankTransactors',
        allowed = function(from, to, _, context)
            return CharacterAccount(to, 'bank') and ActorWallet(from, from, to, context)
        end },
    bank_to_actor_wallet = { operation = 'transfer', group = 'trustedBankTransactors',
        allowed = function(from, to, _, context)
            return CharacterAccount(from, 'bank') and ActorWallet(to, from, to, context)
        end },
    bank_to_bank = { operation = 'transfer', group = 'trustedBankTransactors',
        allowed = function(from, to)
            return CharacterAccount(from, 'bank') and CharacterAccount(to, 'bank')
        end },
    bank_to_sink = { operation = 'transfer', group = 'trustedBankTransactors',
        allowed = function(from, to)
            return CharacterAccount(from, 'bank') and to.account_type == 'system_sink'
        end },
    issue_to_bank = { operation = 'issue', group = 'trustedBankTransactors', supply = true,
        allowed = function(from, to)
            return from.account_type == 'system_source' and CharacterAccount(to, 'bank')
        end },
    issue_to_operated = { operation = 'issue', group = 'trustedTreasuryOperators', supply = true,
        allowed = function(from, to, resource, _, database)
            return from.account_type == 'system_source' and OperatedBy(to, resource, database)
        end }
}

local function MayUseShape(shape, resource)
    return InGroup(shape.group, resource) and (shape.also == nil or InGroup(shape.also, resource))
end

-- The server owner's exact list of reason codes a resource may create currency with.
local function SupplyListed(resource, reasonCode)
    local listed = Config.OperatorSupply and Config.OperatorSupply[resource or '']
    return type(listed) == 'table' and listed[reasonCode or ''] == true
end

-- True when `resource` registered `reasonCode` with a supply shape and the server
-- lists it in Config.OperatorSupply. Lets such a caller post supply without being
-- in trustedSuppliers; the Core policy check still applies.
function EconomyOperators.SupplyAllowed(resource, reasonCode)
    if not SupplyListed(resource, reasonCode) then return false end
    for _, name in ipairs((registry[resource or ''] or {})[reasonCode or ''] or {}) do
        if SHAPES[name].supply then return true end
    end
    return false
end

-- True when a registered reason of `resource` allows this movement.
function EconomyOperators.Allowed(operation, from, to, request, resource, context, database)
    local shapes = (registry[resource or ''] or {})[request.reasonCode or '']
    if not shapes then return false end
    for _, name in ipairs(shapes) do
        local shape = SHAPES[name]
        if shape.operation == operation and MayUseShape(shape, resource)
            and (not shape.supply or SupplyListed(resource, request.reasonCode))
            and shape.allowed(from, to, resource, context, database) then
            return true
        end
    end
    return false
end

local function ValidReason(code)
    if type(code) ~= 'string' or #code > Config.Limits.maximumReasonLength
        or not code:match('^[a-z][a-z0-9_]*%.[a-z0-9_.]+$') then
        return false
    end
    for _, prefix in ipairs(RESERVED_PREFIXES) do
        if code:sub(1, #prefix) == prefix then return false end
    end
    -- The settlement reason belongs to the trusted settlers (journal.lua).
    if type(Config.Settlement) == 'table' and code == Config.Settlement.reasonCode then return false end
    return true
end

-- Replaces the caller's registered reasons. request.reasons maps each code to a
-- shape name or a list of shape names. A supply shape may be registered by any
-- operator, but creates currency only while Config.OperatorSupply lists the code.
function EconomyOperators.Register(resource, request)
    if not InGroup('trustedTreasuryOperators', resource) and not InGroup('trustedBankTransactors', resource) then
        return EconomyResults.Err('authorization_denied', 'Calling resource is not an account operator.')
    end
    if type(request) ~= 'table' or type(request.reasons) ~= 'table' then
        return EconomyResults.Err('invalid_input', 'reasons is required.')
    end
    for key in pairs(request) do
        if key ~= 'reasons' then
            return EconomyResults.Err('invalid_input', 'Unexpected registration field.')
        end
    end
    local accepted, count = {}, 0
    for code, value in pairs(request.reasons) do
        if not ValidReason(code) then
            return EconomyResults.Err('invalid_input', 'Invalid or reserved reason code.', { reasonCode = tostring(code) })
        end
        if owners[code] and owners[code] ~= resource then
            return EconomyResults.Err('reason_conflict', 'Another resource registered that reason code.',
                { reasonCode = code, operator = owners[code] })
        end
        local names = type(value) == 'string' and { value } or value
        if type(names) ~= 'table' or #names == 0 then
            return EconomyResults.Err('invalid_input', 'Each reason needs at least one shape.', { reasonCode = code })
        end
        local list = {}
        for _, name in ipairs(names) do
            local shape = SHAPES[name]
            if not shape then
                return EconomyResults.Err('invalid_input', 'Unknown shape.', { reasonCode = code, shape = tostring(name) })
            end
            if not MayUseShape(shape, resource) then
                return EconomyResults.Err('authorization_denied', 'Calling resource may not use that shape.',
                    { reasonCode = code, shape = name })
            end
            list[#list + 1] = name
        end
        accepted[code] = list
        count = count + 1
    end
    EconomyOperators.Unregister(resource)
    registry[resource] = accepted
    for code in pairs(accepted) do owners[code] = resource end
    return EconomyResults.Ok({ registered = count })
end

function EconomyOperators.Unregister(resource)
    for code in pairs(registry[resource or ''] or {}) do
        if owners[code] == resource then owners[code] = nil end
    end
    registry[resource or ''] = nil
end

function EconomyOperators.Registered(resource)
    return registry[resource or '']
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then EconomyOperators.Unregister(resource) end
end)
