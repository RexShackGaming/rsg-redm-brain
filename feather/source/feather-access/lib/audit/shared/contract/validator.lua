FeatherAuditValidator = {}

local limits = FeatherAuditConstants.limits
local MAX_SAFE_INTEGER = 9007199254740991
local idPattern = '^[A-Za-z0-9][A-Za-z0-9%._:%-]*$'
local snakePattern = '^[a-z][a-z0-9_]*$'

local prohibitedKeys = {
    password = true, passwd = true, secret = true, token = true,
    authorization = true, cookie = true, webhook = true, webhook_url = true,
    api_key = true, private_key = true, connection_string = true
}

local envelopeFields = {
    contractVersion = true, eventId = true, eventType = true, eventVersion = true,
    occurredAt = true, sourceResource = true, sourceInstance = true,
    invokingResource = true, correlationId = true, causationId = true,
    actor = true, targets = true, references = true, result = true,
    reasonCode = true, summary = true, context = true,
    sensitivityClass = true, retentionClass = true
}

local actorFields = {
    type = true, id = true, accountId = true, characterId = true,
    resource = true, displayName = true
}

local targetFields = {
    type = true, id = true, role = true, resource = true, displayName = true
}

local referenceFields = { resource = true, type = true, id = true }

local function failure(code, path, detail)
    return { ok = false, code = code, path = path, detail = detail }
end

local function validString(value, maximum, pattern, allowEmpty)
    if type(value) ~= 'string' or #value > maximum then return false end
    if not allowEmpty and #value == 0 then return false end
    if value:find('%z') or value:find('[\1-\8\11\12\14-\31]') then return false end
    if utf8 and not utf8.len(value) then return false end
    return not pattern or value:match(pattern) ~= nil
end

local function isSafeInteger(value)
    return type(value) == 'number' and value == value and value ~= math.huge
        and value ~= -math.huge and value % 1 == 0 and math.abs(value) <= MAX_SAFE_INTEGER
end

local function validNamespacedName(value, requireNamespace)
    if not validString(value, limits.keyBytes, '^[a-z][a-z0-9_%.]*$') then return false end
    if value:sub(-1) == '.' or value:find('%.%.', 1, false) then return false end
    if requireNamespace and not value:find('.', 1, true) then return false end
    for segment in value:gmatch('[^%.]+') do
        if not segment:match(snakePattern) then return false end
    end
    return true
end

local function leap(year)
    return year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0)
end

local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function timestampToEpoch(value)
    if type(value) ~= 'string' then return nil end
    local y, m, d, h, min, s, fraction = value:match(
        '^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)(%.?%d*)Z$')
    y, m, d, h, min, s = tonumber(y), tonumber(m), tonumber(d), tonumber(h), tonumber(min), tonumber(s)
    if not y or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or min > 59 or s > 59 then return nil end
    local maximum = monthDays[m] + ((m == 2 and leap(y)) and 1 or 0)
    if d < 1 or d > maximum then return nil end
    if fraction ~= '' and (not fraction:match('^%.%d%d?%d?$')) then return nil end
    local days = 0
    for year = 1970, y - 1 do days = days + (leap(year) and 366 or 365) end
    for month = 1, m - 1 do days = days + monthDays[month] + ((month == 2 and leap(y)) and 1 or 0) end
    days = days + d - 1
    return days * 86400 + h * 3600 + min * 60 + s
end

local function validateObjectFields(value, allowed, path)
    for key in pairs(value) do
        if type(key) ~= 'string' or not allowed[key] then
            return failure(FeatherAuditResults.fieldInvalid, path .. '.' .. tostring(key))
        end
    end
    return nil
end

local function validateArray(value, maximum, path)
    if type(value) ~= 'table' then return failure(FeatherAuditResults.fieldInvalid, path) end
    local count, highest = 0, 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            return failure(FeatherAuditResults.fieldInvalid, path, 'mixed_array')
        end
        count = count + 1
        if key > highest then highest = key end
    end
    if count ~= highest then return failure(FeatherAuditResults.fieldInvalid, path, 'sparse_array') end
    if count > maximum then return failure(FeatherAuditResults.fieldInvalid, path, 'items') end
    return nil, count
end

local function validateIdentity(value, path, allowed)
    if type(value) ~= 'table' then return failure(FeatherAuditResults.fieldInvalid, path) end
    local objectError = validateObjectFields(value, allowed, path)
    if objectError then return objectError end
    if not validNamespacedName(value.type, false) then
        return failure(FeatherAuditResults.fieldInvalid, path .. '.type')
    end
    if not validString(value.id, limits.identifierBytes, idPattern) then
        return failure(FeatherAuditResults.fieldInvalid, path .. '.id')
    end
    if value.displayName ~= nil and not validString(value.displayName, limits.displayNameBytes, nil, true) then
        return failure(FeatherAuditResults.fieldInvalid, path .. '.displayName')
    end
    for _, key in ipairs({ 'accountId', 'characterId' }) do
        if value[key] ~= nil and not validString(value[key], limits.identifierBytes, idPattern) then
            return failure(FeatherAuditResults.fieldInvalid, path .. '.' .. key)
        end
    end
    if value.resource ~= nil and not validString(value.resource, limits.keyBytes, '^[a-z0-9][a-z0-9_%-]*$') then
        return failure(FeatherAuditResults.fieldInvalid, path .. '.resource')
    end
    return nil
end

local function validateContextValue(value, spec, path, depth, counter)
    if depth > limits.contextDepth then return failure(FeatherAuditResults.fieldInvalid, path, 'depth') end
    local kind = spec.type
    if kind == 'string' then
        if not validString(value, spec.maxBytes or limits.identifierBytes, spec.pattern, spec.allowEmpty) then
            return failure(FeatherAuditResults.fieldInvalid, path)
        end
        if spec.enum and not spec.enum[value] then return failure(FeatherAuditResults.fieldInvalid, path) end
        return nil
    end
    if kind == 'integer' then
        if not isSafeInteger(value) or (spec.minimum and value < spec.minimum)
            or (spec.maximum and value > spec.maximum) then
            return failure(FeatherAuditResults.fieldInvalid, path)
        end
        return nil
    end
    if kind == 'boolean' then
        if type(value) ~= 'boolean' then return failure(FeatherAuditResults.fieldInvalid, path) end
        return nil
    end
    if kind == 'array' then
        local arrayError, count = validateArray(value, spec.maxItems or limits.contextArrayItems, path)
        if arrayError then return arrayError end
        for index = 1, count do
            local err = validateContextValue(value[index], spec.items, ('%s[%d]'):format(path, index), depth + 1, counter)
            if err then return err end
        end
        return nil
    end
    if kind == 'object' then
        if type(value) ~= 'table' then return failure(FeatherAuditResults.fieldInvalid, path) end
        for key, child in pairs(value) do
            if type(key) ~= 'string' or not validString(key, limits.keyBytes, snakePattern) then
                return failure(FeatherAuditResults.fieldInvalid, path .. '.' .. tostring(key))
            end
            counter.count = counter.count + 1
            if counter.count > limits.contextKeys then return failure(FeatherAuditResults.fieldInvalid, path, 'keys') end
            if prohibitedKeys[tostring(key):lower()] then return failure(FeatherAuditResults.prohibitedContent, path .. '.' .. tostring(key)) end
            local childSpec = spec.fields and spec.fields[key]
            if not childSpec then return failure(FeatherAuditResults.contextUnknownField, path .. '.' .. tostring(key)) end
            local err = validateContextValue(child, childSpec, path .. '.' .. key, depth + 1, counter)
            if err then return err end
        end
        for key, childSpec in pairs(spec.fields or {}) do
            if childSpec.required and value[key] == nil then return failure(FeatherAuditResults.fieldInvalid, path .. '.' .. key) end
        end
        return nil
    end
    return failure(FeatherAuditResults.fieldInvalid, path, 'schema_type')
end

local function prohibitedString(value)
    local lower = value:lower()
    return lower:find('discord%.com/api/webhooks/', 1, false)
        or lower:find('discordapp%.com/api/webhooks/', 1, false)
        or lower:find('-----begin private key-----', 1, true)
        or lower:find('bearer ', 1, true) == 1
end

local function scanProhibited(value, path, seen)
    if type(value) == 'string' then
        if prohibitedString(value) then return failure(FeatherAuditResults.prohibitedContent, path) end
        return nil
    end
    if type(value) ~= 'table' or seen[value] then return nil end
    seen[value] = true
    for key, child in pairs(value) do
        if type(key) == 'string' and prohibitedKeys[key:lower()] then
            return failure(FeatherAuditResults.prohibitedContent, path .. '.' .. key)
        end
        local err = scanProhibited(child, path .. '.' .. tostring(key), seen)
        if err then return err end
    end
    return nil
end

function FeatherAuditValidator.Validate(event, options)
    options = options or {}
    if type(event) ~= 'table' then return failure(FeatherAuditResults.fieldInvalid, '$') end
    local envelopeError = validateObjectFields(event, envelopeFields, '$')
    if envelopeError then return envelopeError end
    if event.contractVersion ~= FeatherAuditConstants.contractVersion then
        return failure(FeatherAuditResults.contractUnsupported, '$.contractVersion')
    end
    if not validString(event.eventId, limits.identifierBytes, idPattern) then
        return failure(FeatherAuditResults.fieldInvalid, '$.eventId')
    end
    if not validNamespacedName(event.eventType, true) then
        return failure(FeatherAuditResults.fieldInvalid, '$.eventType')
    end
    if not isSafeInteger(event.eventVersion) or event.eventVersion < 1 then
        return failure(FeatherAuditResults.fieldInvalid, '$.eventVersion')
    end
    local occurredEpoch = timestampToEpoch(event.occurredAt)
    if not occurredEpoch then return failure(FeatherAuditResults.fieldInvalid, '$.occurredAt') end
    local now = options.nowEpoch or os.time()
    if occurredEpoch > now + limits.futureHardLimitSeconds then
        return failure(FeatherAuditResults.occurredAtFuture, '$.occurredAt')
    end
    if not validString(event.sourceResource, limits.keyBytes, '^[a-z0-9][a-z0-9_%-]*$') then
        return failure(FeatherAuditResults.fieldInvalid, '$.sourceResource')
    end
    if options.sourceResource and options.sourceResource ~= event.sourceResource then
        return failure(FeatherAuditResults.sourceMismatch, '$.sourceResource')
    end
    if not validString(event.sourceInstance, limits.identifierBytes, idPattern) then
        return failure(FeatherAuditResults.fieldInvalid, '$.sourceInstance')
    end
    if options.sourceInstance and options.sourceInstance ~= event.sourceInstance then
        return failure(FeatherAuditResults.instanceMismatch, '$.sourceInstance')
    end
    for _, field in ipairs({ 'invokingResource', 'correlationId', 'causationId' }) do
        if event[field] ~= nil and not validString(event[field], limits.identifierBytes, idPattern) then
            return failure(FeatherAuditResults.fieldInvalid, '$.' .. field)
        end
    end
    local actorError = validateIdentity(event.actor, '$.actor', actorFields)
    if actorError then return actorError end
    if not FeatherAuditConstants.eventResults[event.result] then return failure(FeatherAuditResults.fieldInvalid, '$.result') end
    if not validString(event.reasonCode, limits.keyBytes, snakePattern) then return failure(FeatherAuditResults.fieldInvalid, '$.reasonCode') end
    if not validString(event.summary, limits.summaryBytes, nil, true) then return failure(FeatherAuditResults.fieldInvalid, '$.summary') end
    if not FeatherAuditConstants.sensitivityClasses[event.sensitivityClass] then return failure(FeatherAuditResults.fieldInvalid, '$.sensitivityClass') end
    if not FeatherAuditConstants.retentionClasses[event.retentionClass] then return failure(FeatherAuditResults.fieldInvalid, '$.retentionClass') end

    local schema = FeatherAuditSchemaRegistry.Get(event.eventType, event.eventVersion)
    if not schema then
        local code = FeatherAuditSchemaRegistry.HasEventType(event.eventType)
            and FeatherAuditResults.eventVersionUnsupported or FeatherAuditResults.eventSchemaUnknown
        return failure(code, '$.eventType')
    end
    if schema.actorTypes and not schema.actorTypes[event.actor.type] then return failure(FeatherAuditResults.fieldInvalid, '$.actor.type') end
    if schema.minimumSensitivity and schema.minimumSensitivity ~= event.sensitivityClass then
        local order = { public = 1, internal = 2, restricted = 3, sealed = 4 }
        if order[event.sensitivityClass] < order[schema.minimumSensitivity] then return failure(FeatherAuditResults.fieldInvalid, '$.sensitivityClass') end
    end
    if schema.retentionClass and schema.retentionClass ~= event.retentionClass then return failure(FeatherAuditResults.fieldInvalid, '$.retentionClass') end

    local targetsError, targetCount = validateArray(event.targets, limits.targets, '$.targets')
    if targetsError then return targetsError end
    if targetCount < (schema.minimumTargets or 0) then return failure(FeatherAuditResults.fieldInvalid, '$.targets') end
    for index = 1, targetCount do
        local target = event.targets[index]
        local err = validateIdentity(target, ('$.targets[%d]'):format(index), targetFields)
        if err then return err end
        if not validString(target.role, limits.keyBytes, snakePattern) then return failure(FeatherAuditResults.fieldInvalid, ('$.targets[%d].role'):format(index)) end
    end
    local referencesError, referenceCount = validateArray(event.references, limits.references, '$.references')
    if referencesError then return referencesError end
    for index = 1, referenceCount do
        local reference = event.references[index]
        local path = ('$.references[%d]'):format(index)
        if type(reference) ~= 'table' then return failure(FeatherAuditResults.fieldInvalid, path) end
        local fieldsError = validateObjectFields(reference, referenceFields, path)
        if fieldsError then return fieldsError end
        if not validString(reference.resource, limits.keyBytes, '^[a-z0-9][a-z0-9_%-]*$')
            or not validNamespacedName(reference.type, false)
            or not validString(reference.id, limits.identifierBytes, idPattern) then
            return failure(FeatherAuditResults.fieldInvalid, path)
        end
    end
    local contextError = validateContextValue(event.context, schema.context or { type = 'object', fields = {} }, '$.context', 0, { count = 0 })
    if contextError then return contextError end
    local secretError = scanProhibited(event, '$', {})
    if secretError then return secretError end
    local canonical, canonicalError = FeatherAuditCanonical.EncodeEvent(event, schema)
    if not canonical then return failure(FeatherAuditResults.fieldInvalid, '$', canonicalError) end
    if #canonical > limits.eventBytes then return failure(FeatherAuditResults.payloadTooLarge, '$') end
    local canonicalContext = FeatherAuditCanonical.Encode(event.context, schema.context)
    if not canonicalContext or #canonicalContext > limits.contextBytes then return failure(FeatherAuditResults.payloadTooLarge, '$.context') end
    return {
        ok = true,
        event = event,
        schema = schema,
        canonical = canonical,
        warnings = occurredEpoch > now + limits.futureWarningSeconds and { 'producer_clock_ahead' } or {}
    }
end
