LicenseDefinitions = {}
local Ok, Err = Licenses.Ok, Licenses.Err

local selectDefinition = [[
    SELECT `license_key`,`label`,`owner_resource`,`holder_types`,`default_duration_seconds`,
        `max_duration_seconds`,`renewable`,`status`,`scope_version`,`revision`,
        FLOOR(UNIX_TIMESTAMP(`created_at`))*1000 AS created_at_ms,
        FLOOR(UNIX_TIMESTAMP(`updated_at`))*1000 AS updated_at_ms
    FROM `feather_license_definitions`]]
LicenseDefinitions.Select = selectDefinition

-- Holder types are stored as a sorted comma list ("character,organization").
local function SplitHolderTypes(value)
    local result = {}
    for holderType in tostring(value or ''):gmatch('[^,]+') do
        result[#result + 1] = holderType
    end
    return result
end
LicenseDefinitions.HolderTypes = SplitHolderTypes

function LicenseDefinitions.Snapshot(row)
    if not row then
        return Err('definition_not_found', 'License definition not found.')
    end
    if not Licenses.Key(row.license_key, 48) or (row.status ~= 'active' and row.status ~= 'retired')
        or not Licenses.Integer(tonumber(row.revision), 1, Licenses.MaxRevision + 1) then
        return Err('invalid_persistence', 'Persisted license definition is invalid.')
    end
    return Ok({
        licenseKey = row.license_key,
        label = row.label,
        ownerResource = row.owner_resource,
        holderTypes = SplitHolderTypes(row.holder_types),
        defaultDurationSeconds = row.default_duration_seconds and tonumber(row.default_duration_seconds) or nil,
        maxDurationSeconds = row.max_duration_seconds and tonumber(row.max_duration_seconds) or nil,
        renewable = tonumber(row.renewable) == 1 or row.renewable == true,
        status = row.status,
        scopeVersion = tonumber(row.scope_version),
        revision = tonumber(row.revision),
        createdAt = tonumber(row.created_at_ms),
        updatedAt = tonumber(row.updated_at_ms)
    })
end

function LicenseDefinitions.Owns(ownerResource, resource)
    return ownerResource == resource or Config.Access.privilegedRegistrars[resource] == true
end

-- A non-empty list of configured holder types, without duplicates.
local function NormalizeHolderTypes(value)
    if type(value) ~= 'table' or #value == 0 or #value > 8 then
        return nil
    end
    local seen, result = {}, {}
    for index = 1, #value do
        local holderType = value[index]
        if type(holderType) ~= 'string' or not Config.HolderTypes[holderType] or seen[holderType] then
            return nil
        end
        seen[holderType] = true
        result[#result + 1] = holderType
    end
    for key in pairs(value) do
        if type(key) ~= 'number' then
            return nil
        end
    end
    table.sort(result)
    return table.concat(result, ',')
end

local function Duration(value)
    return Licenses.Integer(value, 1, Config.Limits.maxDurationSeconds)
end

-- RegisterLicenseDefinition ------------------------------------------------------
-- The caller becomes the owner. Consumers re-register on every start with the
-- same stable request ID, which replays the stored result.

local registerFields = Licenses.Allowed({
    'licenseKey',
    'label',
    'holderTypes',
    'defaultDurationSeconds',
    'maxDurationSeconds',
    'renewable',
    'scopeVersion'
})

function LicenseDefinitions.Register(request, resource)
    local begun = Licenses.Begin(request, resource, 'trustedRegistrars', registerFields)
    if not begun.ok then
        return begun
    end
    local holderTypes = NormalizeHolderTypes(request.holderTypes)
    if not Licenses.Key(request.licenseKey, 48) or not Licenses.Label(request.label) or not holderTypes
        or (request.defaultDurationSeconds ~= nil and not Duration(request.defaultDurationSeconds))
        or (request.maxDurationSeconds ~= nil and not Duration(request.maxDurationSeconds))
        or (request.renewable ~= nil and type(request.renewable) ~= 'boolean')
        or (request.scopeVersion ~= nil and not Licenses.Integer(request.scopeVersion, 1, 65535)) then
        return Err('invalid_input',
            'License key, label, holder types, and optional durations, renewable flag and scope version required.')
    end
    if request.defaultDurationSeconds and request.maxDurationSeconds
        and request.defaultDurationSeconds > request.maxDurationSeconds then
        return Err('invalid_duration', 'The default duration exceeds the maximum duration.')
    end
    request = Licenses.Copy(request)
    request.holderTypesNormalized = holderTypes
    request.holderTypes = nil
    local renewable = request.renewable ~= false
    local actor = Licenses.Policy(Config.Authorization.definitionAction, request, resource, {
        licenseKey = request.licenseKey
    })
    if not actor.ok then
        return actor
    end

    return Licenses.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'definition.register',
        fingerprint = Licenses.Fingerprint('definition.register', request, {
            'licenseKey',
            'label',
            'holderTypesNormalized',
            'defaultDurationSeconds',
            'maxDurationSeconds',
            'renewable',
            'scopeVersion',
            'reasonCode'
        }),
        body = function(tx)
            -- The primary key decides duplicates; INSERT IGNORE avoids the gap
            -- locks a locking read of a missing row would take.
            local inserted = tx.exec([[
                INSERT IGNORE INTO `feather_license_definitions`
                    (`license_key`,`label`,`owner_resource`,`holder_types`,`default_duration_seconds`,
                     `max_duration_seconds`,`renewable`,`scope_version`)
                VALUES (?,?,?,?,?,?,?,?)]],
                request.licenseKey, request.label, resource, holderTypes, request.defaultDurationSeconds,
                request.maxDurationSeconds, renewable and 1 or 0, request.scopeVersion or 1)
            if tonumber(inserted) ~= 1 then
                local existing = (tx.query('SELECT `owner_resource` FROM `feather_license_definitions` WHERE `license_key`=?',
                    request.licenseKey) or {})[1]
                return Err('license_key_conflict', 'License key is already registered.', {
                    ownerResource = existing and existing.owner_resource
                })
            end
            local created = LicenseDefinitions.Snapshot((tx.query(selectDefinition .. ' WHERE `license_key`=?',
                request.licenseKey) or {})[1])
            if not created.ok then
                return created
            end
            LicenseEvents.Record(tx, 'definition.registered', {
                aggregateType = 'definition',
                aggregateId = request.licenseKey,
                licenseKey = request.licenseKey,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = 1,
                actor = actor.value,
                details = {
                    label = request.label,
                    ownerResource = resource,
                    status = 'active',
                    defaultDurationSeconds = request.defaultDurationSeconds,
                    maxDurationSeconds = request.maxDurationSeconds,
                    renewable = renewable,
                    scopeVersion = request.scopeVersion or 1
                }
            })
            return created
        end
    })
end

-- UpdateLicenseDefinition --------------------------------------------------------
-- Changes apply to new issues and renewals; existing licenses keep their expiry.
-- A duration of false removes the limit.

local updateFields = Licenses.Allowed({
    'licenseKey',
    'expectedRevision',
    'label',
    'holderTypes',
    'defaultDurationSeconds',
    'maxDurationSeconds',
    'renewable',
    'status',
    'scopeVersion'
})

function LicenseDefinitions.Update(request, resource)
    local begun = Licenses.Begin(request, resource, 'trustedRegistrars', updateFields)
    if not begun.ok then
        return begun
    end
    local holderTypes = request.holderTypes ~= nil and NormalizeHolderTypes(request.holderTypes) or nil
    local changes = 0
    for _, field in ipairs({ 'label', 'holderTypes', 'defaultDurationSeconds', 'maxDurationSeconds', 'renewable',
        'status', 'scopeVersion' }) do
        if request[field] ~= nil then
            changes = changes + 1
        end
    end
    if not Licenses.Key(request.licenseKey, 48)
        or not Licenses.Integer(request.expectedRevision, 1, Licenses.MaxRevision)
        or (request.label ~= nil and not Licenses.Label(request.label))
        or (request.holderTypes ~= nil and not holderTypes)
        or (request.defaultDurationSeconds ~= nil and request.defaultDurationSeconds ~= false
            and not Duration(request.defaultDurationSeconds))
        or (request.maxDurationSeconds ~= nil and request.maxDurationSeconds ~= false
            and not Duration(request.maxDurationSeconds))
        or (request.renewable ~= nil and type(request.renewable) ~= 'boolean')
        or (request.status ~= nil and request.status ~= 'active' and request.status ~= 'retired')
        or (request.scopeVersion ~= nil and not Licenses.Integer(request.scopeVersion, 1, 65535))
        or changes == 0 then
        return Err('invalid_input', 'License key, expected revision, and at least one valid change required.')
    end
    request = Licenses.Copy(request)
    request.holderTypesNormalized = holderTypes
    request.holderTypes = nil
    local actor = Licenses.Policy(Config.Authorization.definitionAction, request, resource, {
        licenseKey = request.licenseKey
    })
    if not actor.ok then
        return actor
    end

    return Licenses.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'definition.update',
        fingerprint = Licenses.Fingerprint('definition.update', request, {
            'licenseKey',
            'expectedRevision',
            'label',
            'holderTypesNormalized',
            'defaultDurationSeconds',
            'maxDurationSeconds',
            'renewable',
            'status',
            'scopeVersion',
            'reasonCode'
        }),
        body = function(tx)
            local row = (tx.query(selectDefinition .. ' WHERE `license_key`=? FOR UPDATE', request.licenseKey) or {})[1]
            if not row then
                return Err('definition_not_found', 'License definition not found.')
            end
            if not LicenseDefinitions.Owns(row.owner_resource, resource) then
                return Err('authorization_denied', 'Caller does not own this license definition.')
            end
            local current = LicenseDefinitions.Snapshot(row)
            if not current.ok then
                return current
            end
            current = current.value
            if current.revision ~= request.expectedRevision then
                return Err('revision_conflict', 'License definition revision changed.', { revision = current.revision })
            end

            local function Pick(field, fallback)
                if request[field] == nil then
                    return fallback
                elseif request[field] == false and (field == 'defaultDurationSeconds' or field == 'maxDurationSeconds') then
                    return nil
                end
                return request[field]
            end
            local nextValues = {
                label = Pick('label', current.label),
                holderTypes = holderTypes or table.concat(current.holderTypes, ','),
                defaultDurationSeconds = Pick('defaultDurationSeconds', current.defaultDurationSeconds),
                maxDurationSeconds = Pick('maxDurationSeconds', current.maxDurationSeconds),
                renewable = Pick('renewable', current.renewable),
                status = Pick('status', current.status),
                scopeVersion = Pick('scopeVersion', current.scopeVersion)
            }
            if nextValues.defaultDurationSeconds and nextValues.maxDurationSeconds
                and nextValues.defaultDurationSeconds > nextValues.maxDurationSeconds then
                return Err('invalid_duration', 'The default duration exceeds the maximum duration.')
            end
            if nextValues.label == current.label and nextValues.holderTypes == table.concat(current.holderTypes, ',')
                and nextValues.defaultDurationSeconds == current.defaultDurationSeconds
                and nextValues.maxDurationSeconds == current.maxDurationSeconds
                and nextValues.renewable == current.renewable and nextValues.status == current.status
                and nextValues.scopeVersion == current.scopeVersion then
                return Err('no_change', 'License definition already matches the request.')
            end

            tx.exec([[
                UPDATE `feather_license_definitions`
                SET `label`=?,`holder_types`=?,`default_duration_seconds`=?,`max_duration_seconds`=?,
                    `renewable`=?,`status`=?,`scope_version`=?,`revision`=`revision`+1
                WHERE `license_key`=? AND `revision`=?]],
                nextValues.label, nextValues.holderTypes, nextValues.defaultDurationSeconds,
                nextValues.maxDurationSeconds, nextValues.renewable and 1 or 0, nextValues.status,
                nextValues.scopeVersion, request.licenseKey, current.revision)
            local updated = LicenseDefinitions.Snapshot((tx.query(selectDefinition .. ' WHERE `license_key`=?',
                request.licenseKey) or {})[1])
            if not updated.ok then
                return updated
            end
            LicenseEvents.Record(tx, 'definition.updated', {
                aggregateType = 'definition',
                aggregateId = request.licenseKey,
                licenseKey = request.licenseKey,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = current.revision + 1,
                actor = actor.value,
                details = {
                    label = nextValues.label,
                    status = nextValues.status,
                    previousStatus = current.status,
                    defaultDurationSeconds = nextValues.defaultDurationSeconds,
                    maxDurationSeconds = nextValues.maxDurationSeconds,
                    renewable = nextValues.renewable,
                    scopeVersion = nextValues.scopeVersion
                }
            })
            return updated
        end
    })
end

-- Reads ------------------------------------------------------------------------

function LicenseDefinitions.Get(request, resource)
    local allowed = Licenses.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Licenses.Fields(request, { licenseKey = true })
    if not fields.ok then
        return fields
    end
    if not Licenses.Key(request.licenseKey, 48) then
        return Err('invalid_input', 'License key required.')
    end
    return LicenseDefinitions.Snapshot(DB.one(selectDefinition .. ' WHERE `license_key`=?', request.licenseKey))
end

function LicenseDefinitions.List(request, resource)
    local allowed = Licenses.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    request = request or {}
    local fields = Licenses.Fields(request, { ownerResource = true, status = true, limit = true, cursor = true })
    if not fields.ok then
        return fields
    end
    local limit = request.limit == nil and 20 or request.limit
    if not Licenses.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.ownerResource ~= nil
            and (type(request.ownerResource) ~= 'string' or #request.ownerResource > 100))
        or (request.status ~= nil and request.status ~= 'active' and request.status ~= 'retired')
        or (request.cursor ~= nil and not Licenses.Key(request.cursor, 48)) then
        return Err('invalid_input', 'Bounded limit, optional owner and status filters, and license key cursor required.')
    end
    local clauses, params = {}, {}
    if request.ownerResource then
        clauses[#clauses + 1] = '`owner_resource`=?'
        params[#params + 1] = request.ownerResource
    end
    if request.status then
        clauses[#clauses + 1] = '`status`=?'
        params[#params + 1] = request.status
    end
    if request.cursor then
        clauses[#clauses + 1] = '`license_key`>?'
        params[#params + 1] = request.cursor
    end
    local sql = selectDefinition
    if #clauses > 0 then
        sql = sql .. ' WHERE ' .. table.concat(clauses, ' AND ')
    end
    sql = sql .. ' ORDER BY `license_key` LIMIT ?'
    params[#params + 1] = limit + 1

    local rows = DB.query(sql, table.unpack(params)) or {}
    local items = {}
    for index = 1, math.min(#rows, limit) do
        local definition = LicenseDefinitions.Snapshot(rows[index])
        if not definition.ok then
            return definition
        end
        items[#items + 1] = definition.value
    end
    return Ok({ items = items, nextCursor = #rows > limit and items[#items].licenseKey or nil })
end

Licenses.Export('RegisterLicenseDefinition', LicenseDefinitions.Register)
Licenses.Export('UpdateLicenseDefinition', LicenseDefinitions.Update)
Licenses.Export('GetLicenseDefinition', LicenseDefinitions.Get)
Licenses.Export('ListLicenseDefinitions', LicenseDefinitions.List)
