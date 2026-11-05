ContractsTypes = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local V = ContractsValidation
local logger = ContractsLogging.Create('types')

-- persisted[typeKey] = { owner, definition, revision }: every type ever registered.
-- active[typeKey] = true while the owner is running and has registered this session.
local persisted, active = {}, {}

local partyTypes = { character = true, organization = true, system = true }
-- An organization debtor pays from its treasury, through the resource operating it.
local debtorPartyTypes = { character = true, organization = true }
local definitionFields = {
    typeKey = true, label = true, requiresAcceptance = true, debtorMaySettle = true,
    issuerMaySettle = true, debtorMayDispute = true, issuerTypes = true,
    creditorTypes = true, debtorTypes = true, currencies = true, minimumAmount = true, maximumAmount = true,
    maximumDueSeconds = true, defaultAfterSeconds = true
}

local function Flag(value, default)
    if value == nil then return default end
    return value
end

local function PartyList(value, allowed, label)
    if type(value) ~= 'table' or #value == 0 or #value > 3 then
        return Err('invalid_input', ('%s must list at least one party type.'):format(label))
    end
    local seen, list = {}, {}
    for index = 1, #value do
        local entry = value[index]
        if not allowed[entry] or seen[entry] then
            return Err('invalid_input', ('%s contains an invalid party type.'):format(label))
        end
        seen[entry] = true
        list[#list + 1] = entry
    end
    table.sort(list)
    return Ok(list)
end

-- Normalizes a registration request into a canonical, JSON-stable definition.
function ContractsTypes.Normalize(definition)
    local fields = V.Fields(definition, definitionFields, 'obligation type')
    if not fields.ok then return fields end
    if not V.Key(definition.typeKey, 48) or not V.Text(definition.label, 64) then
        return Err('invalid_input', 'Obligation type key and label are required.')
    end
    for _, field in ipairs({ 'requiresAcceptance', 'debtorMaySettle', 'issuerMaySettle', 'debtorMayDispute' }) do
        if definition[field] ~= nil and type(definition[field]) ~= 'boolean' then
            return Err('invalid_input', ('%s must be a boolean.'):format(field))
        end
    end
    local issuerTypes = PartyList(definition.issuerTypes, partyTypes, 'issuerTypes')
    if not issuerTypes.ok then return issuerTypes end
    local debtorTypes = PartyList(definition.debtorTypes or { 'character' }, debtorPartyTypes, 'debtorTypes')
    if not debtorTypes.ok then return debtorTypes end
    for _, debtorType in ipairs(debtorTypes.value) do
        if Config.Settlement.debtorTypes[debtorType] ~= true then
            return Err('debtor_type_unsupported',
                'A listed debtor type cannot be settled by this installation.', { debtorType = debtorType })
        end
    end
    local creditorTypes = PartyList(definition.creditorTypes, partyTypes, 'creditorTypes')
    if not creditorTypes.ok then return creditorTypes end
    for _, creditorType in ipairs(creditorTypes.value) do
        if Config.Settlement.creditorTypes[creditorType] ~= true then
            return Err('creditor_type_unsupported',
                'A listed creditor type cannot be settled by this installation.', { creditorType = creditorType })
        end
    end
    local currencies
    if definition.currencies ~= nil then
        if type(definition.currencies) ~= 'table' or #definition.currencies == 0 or #definition.currencies > 16 then
            return Err('invalid_input', 'currencies must be a non-empty list when provided.')
        end
        local seen = {}
        currencies = {}
        for index = 1, #definition.currencies do
            local code = definition.currencies[index]
            if not V.Key(code, 32) or seen[code] then
                return Err('invalid_input', 'currencies contains an invalid currency code.')
            end
            seen[code] = true
            currencies[#currencies + 1] = code
        end
        table.sort(currencies)
    end
    local maximumAllowed = Config.Limits.maximumAmount
    local minimumAmount = definition.minimumAmount == nil and 1 or definition.minimumAmount
    local maximumAmount = definition.maximumAmount == nil and maximumAllowed or definition.maximumAmount
    if not V.Integer(minimumAmount, 1, maximumAllowed) or not V.Integer(maximumAmount, minimumAmount, maximumAllowed) then
        return Err('invalid_input', 'Amount bounds must be integers in minor units within the configured limit.')
    end
    local maximumDue = definition.maximumDueSeconds == nil and Config.Limits.maximumDueSeconds
        or definition.maximumDueSeconds
    if not V.Integer(maximumDue, 60, Config.Limits.maximumDueSeconds) then
        return Err('invalid_input', 'maximumDueSeconds is outside the configured limit.')
    end
    local defaultAfter = definition.defaultAfterSeconds
    if defaultAfter ~= nil and not V.Integer(defaultAfter, 0, Config.Limits.maximumDueSeconds) then
        return Err('invalid_input', 'defaultAfterSeconds must be a non-negative integer when provided.')
    end
    local normalized = {
        typeKey = definition.typeKey,
        label = definition.label,
        requiresAcceptance = Flag(definition.requiresAcceptance, false),
        debtorMaySettle = Flag(definition.debtorMaySettle, true),
        issuerMaySettle = Flag(definition.issuerMaySettle, false),
        debtorMayDispute = Flag(definition.debtorMayDispute, false),
        issuerTypes = issuerTypes.value,
        debtorTypes = debtorTypes.value,
        creditorTypes = creditorTypes.value,
        currencies = currencies,
        minimumAmount = minimumAmount,
        maximumAmount = maximumAmount,
        maximumDueSeconds = maximumDue,
        defaultAfterSeconds = defaultAfter
    }
    if not normalized.debtorMaySettle and not normalized.issuerMaySettle then
        return Err('invalid_input', 'At least one of debtorMaySettle or issuerMaySettle must be true.')
    end
    return Ok(normalized)
end

-- Derived from the immutable flags snapshotted on each obligation, so changing
-- a type definition never changes the lifecycle of already-created obligations.
function ContractsTypes.Transitions(requiresAcceptance, debtorMayDispute)
    return {
        issue = { 'draft' },
        accept = requiresAcceptance and { 'issued' } or {},
        markDue = requiresAcceptance and { 'accepted' } or { 'issued' },
        settle = requiresAcceptance and { 'accepted', 'due', 'defaulted' } or { 'issued', 'due', 'defaulted' },
        dispute = debtorMayDispute and { 'issued', 'accepted', 'due' } or {},
        resolveDispute = { 'disputed' },
        cancel = { 'draft', 'issued', 'accepted', 'due', 'disputed' },
        default = { 'due' }
    }
end

function ContractsTypes.Allows(transitions, operation, status)
    for _, allowed in ipairs(transitions[operation] or {}) do
        if allowed == status then return true end
    end
    return false
end

local function Encode(definition)
    -- Encode with sorted keys so an unchanged re-registration is detected reliably.
    local keys = {}
    for key in pairs(definition) do keys[#keys + 1] = key end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = json.encode(key) .. ':' .. json.encode(definition[key])
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

function ContractsTypes.Load()
    local rows = DB.query([[SELECT `type_key`,`owner_resource`,`definition_json`,`revision`
        FROM `contract_obligation_types`]]) or {}
    persisted = {}
    for _, row in ipairs(rows) do
        local decoded, definition = pcall(json.decode, row.definition_json)
        if not decoded or type(definition) ~= 'table' then
            return Err('invalid_persistence', 'A persisted obligation type is invalid.', { typeKey = row.type_key })
        end
        persisted[row.type_key] = {
            owner = row.owner_resource, definition = definition, revision = tonumber(row.revision)
        }
    end
    return Ok({ types = #rows })
end

function ContractsTypes.Register(definition, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    if type(resource) ~= 'string' or Config.Access.trustedIssuers[resource] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted obligation issuer.')
    end
    local normalized = ContractsTypes.Normalize(definition)
    if not normalized.ok then return normalized end
    local typeKey = normalized.value.typeKey
    local existing = persisted[typeKey]
    if existing and existing.owner ~= resource then
        return Err('type_owner_conflict', 'That obligation type belongs to another resource.', {
            typeKey = typeKey
        })
    end
    if not existing then
        local count = 0
        for _ in pairs(persisted) do count = count + 1 end
        if count >= Config.Limits.maximumTypes then
            return Err('limit_exceeded', 'The obligation type limit has been reached.')
        end
    end
    local encoded = Encode(normalized.value)
    local result = V.Transaction('type.register', function(tx)
        tx.exec([[INSERT IGNORE INTO `contract_obligation_types` (`type_key`,`owner_resource`,`definition_json`)
            VALUES (?,?,?)]], typeKey, resource, encoded)
        local row = tx.one([[SELECT `owner_resource`,`definition_json`,`revision`
            FROM `contract_obligation_types` WHERE `type_key`=? FOR UPDATE]], typeKey)
        if not row then return Err('internal_error', 'Obligation type could not be reserved.') end
        if row.owner_resource ~= resource then
            return Err('type_owner_conflict', 'That obligation type belongs to another resource.', {
                typeKey = typeKey
            })
        end
        local revision = tonumber(row.revision)
        if row.definition_json ~= encoded then
            tx.exec([[UPDATE `contract_obligation_types` SET `definition_json`=?,`revision`=`revision`+1
                WHERE `type_key`=?]], encoded, typeKey)
            revision = revision + 1
        end
        return Ok({ revision = revision })
    end)
    if not result.ok then return result end
    persisted[typeKey] = { owner = resource, definition = normalized.value, revision = result.value.revision }
    active[typeKey] = true
    logger.Info('type.registered', { typeKey = typeKey, owner = resource, revision = result.value.revision })
    return ContractsTypes.Get({ typeKey = typeKey })
end

local function Snapshot(typeKey)
    local entry = persisted[typeKey]
    if not entry then return nil end
    local value = ContractsFoundation.Copy(entry.definition)
    value.owner = entry.owner
    value.revision = entry.revision
    value.active = active[typeKey] == true
    value.transitions = ContractsTypes.Transitions(value.requiresAcceptance, value.debtorMayDispute)
    return value
end

function ContractsTypes.Get(request)
    local fields = V.Fields(request, { typeKey = true }, 'obligation type lookup')
    if not fields.ok then return fields end
    if not V.Key(request.typeKey, 48) then return Err('invalid_input', 'Obligation type key required.') end
    local value = Snapshot(request.typeKey)
    if not value then return Err('type_not_found', 'Obligation type was not found.') end
    return Ok(value)
end

-- Returns the active definition when `resource` owns it, for issuer operations.
function ContractsTypes.RequireOwnedActive(typeKey, resource)
    local entry = persisted[typeKey]
    if not entry then return Err('type_not_found', 'Obligation type was not found.') end
    if entry.owner ~= resource then
        return Err('authorization_denied', 'Only the owning resource may manage this obligation type.')
    end
    if Config.Access.trustedIssuers[resource] ~= true then
        return Err('authorization_denied', 'Calling resource is no longer a trusted obligation issuer.')
    end
    if not active[typeKey] then
        return Err('type_inactive', 'The owning resource has not registered this obligation type since starting.')
    end
    return Ok(entry.definition)
end

function ContractsTypes.Owner(typeKey)
    local entry = persisted[typeKey]
    return entry and entry.owner or nil
end

function ContractsTypes.Count()
    local total, running = 0, 0
    for typeKey in pairs(persisted) do
        total = total + 1
        if active[typeKey] then running = running + 1 end
    end
    return total, running
end

AddEventHandler('onResourceStop', function(resource)
    for typeKey, entry in pairs(persisted) do
        if entry.owner == resource and active[typeKey] then
            active[typeKey] = nil
            logger.Info('type.deactivated', { typeKey = typeKey, owner = resource })
        end
    end
end)
