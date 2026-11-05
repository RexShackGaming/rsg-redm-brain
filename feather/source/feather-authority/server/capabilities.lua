AuthorityCapabilities = {}
local catalog = {}

local function CapabilityKey(value)
    return type(value) == 'string' and #value >= 3 and #value <= 100
        and value:match('^[a-z][a-z0-9_]*%.[a-z][a-z0-9_.]*$') ~= nil
        and value:sub(-1) ~= '.' and not value:find('..', 1, true)
end
local function Text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and not value:find('%c') and value:find('%S') ~= nil
end

function AuthorityCapabilities.ValidateRegistration(request)
    if type(request) ~= 'table' then return Authority.Err('invalid_input', 'Capability registration required.') end
    local fields = { requestId = true, capabilities = true }
    for field in pairs(request) do
        if not fields[field] then return Authority.Err('invalid_input', 'Unexpected registration field.') end
    end
    if type(request.requestId) ~= 'string' or #request.requestId < 1 or #request.requestId > 128
        or not request.requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or type(request.capabilities) ~= 'table' or #request.capabilities < 1
        or #request.capabilities > 100 then
        return Authority.Err('invalid_input', 'Stable request ID and 1-100 capability definitions required.')
    end
    local seen, fingerprint = {}, {}
    for _, definition in ipairs(request.capabilities) do
        if type(definition) ~= 'table' then return Authority.Err('invalid_input', 'Capability definition required.') end
        for field in pairs(definition) do
            if field ~= 'key' and field ~= 'description' and field ~= 'riskClass' then
                return Authority.Err('invalid_input', 'Unexpected capability definition field.')
            end
        end
        if not CapabilityKey(definition.key) or seen[definition.key]
            or not Text(definition.description, 255)
            or (definition.riskClass ~= 'low' and definition.riskClass ~= 'moderate'
                and definition.riskClass ~= 'high' and definition.riskClass ~= 'critical') then
            return Authority.Err('invalid_input', 'Capability definitions must be bounded, valid, and unique.')
        end
        seen[definition.key] = true
        fingerprint[#fingerprint + 1] = definition.key .. '\0' .. definition.description
            .. '\0' .. definition.riskClass
    end
    table.sort(fingerprint)
    return Authority.Ok(table.concat(fingerprint, '\1'))
end

function AuthorityCapabilities.Register(request, resource)
    if Config.Access.trustedCapabilityRegistrars[resource or ''] ~= true then
        return Authority.Err('authorization_denied', 'Calling resource is not a trusted capability registrar.')
    end
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = AuthorityCapabilities.ValidateRegistration(request)
    if not valid.ok then return valid end
    request = Authority.Copy(request)
    table.sort(request.capabilities, function(left, right) return left.key < right.key end)
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_authority_capability_registration_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]],
                resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json` FROM
                `feather_authority_capability_registration_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]],
                resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Authority.Err('internal_error', 'Registration receipt could not be reserved.') end
            if receipt.request_fingerprint ~= valid.value then
                return Authority.Err('idempotency_conflict',
                    'Request ID is bound to a different capability catalog.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' or type(value.capabilities) ~= 'table' then
                    return Authority.Err('invalid_persistence', 'Stored registration receipt is invalid.')
                end
                value.replayed = true
                return Authority.Ok(value)
            end
            local total = tonumber((tx.query('SELECT COUNT(*) AS `count` FROM `feather_authority_capabilities`') or {})[1].count)
            local keys, placeholders = {}, {}
            for _, definition in ipairs(request.capabilities) do
                keys[#keys + 1] = definition.key
                placeholders[#placeholders + 1] = '?'
            end
            local selection = [[SELECT * FROM `feather_authority_capabilities`
                WHERE `capability_key` IN (]] .. table.concat(placeholders, ',')
                .. ') ORDER BY `capability_key` FOR UPDATE'
            local existing = {}
            for _, row in ipairs(tx.query(selection, table.unpack(keys)) or {}) do
                existing[row.capability_key] = row
            end
            local registered, updated, unchanged, identities = 0, 0, 0, {}
            local inserts, insertParams, changes, events = {}, {}, {}, {}
            for _, definition in ipairs(request.capabilities) do
                local row = existing[definition.key]
                if row and row.owner_resource ~= resource then
                    return Authority.Err('capability_owner_conflict',
                        'Capability belongs to another resource.', { capabilityKey = definition.key })
                end
                local changed = row and (row.description ~= definition.description
                    or row.risk_class ~= definition.riskClass)
                if not row then
                    if total + registered >= 128 then
                        return Authority.Err('capability_catalog_limit', 'Capability catalog limit would be exceeded.')
                    end
                    inserts[#inserts + 1] = '(UUID(),?,?,?,?)'
                    insertParams[#insertParams + 1] = definition.key
                    insertParams[#insertParams + 1] = definition.description
                    insertParams[#insertParams + 1] = definition.riskClass
                    insertParams[#insertParams + 1] = resource
                    registered = registered + 1
                elseif changed then
                    changes[#changes + 1] = definition
                    updated = updated + 1
                else unchanged = unchanged + 1 end
                if not row or changed then
                    events[definition.key] = row and 'authority.capability.updated'
                        or 'authority.capability.registered'
                end
            end
            -- Keep large startup catalogs within the transaction deadline by grouping
            -- inserts, identity reads, and events on this same transaction connection.
            if #inserts > 0 then
                tx.exec([[INSERT INTO `feather_authority_capabilities`
                    (`capability_id`,`capability_key`,`description`,`risk_class`,`owner_resource`)
                    VALUES ]] .. table.concat(inserts, ','), table.unpack(insertParams))
                for _, row in ipairs(tx.query(selection, table.unpack(keys)) or {}) do
                    existing[row.capability_key] = row
                end
            end
            for _, definition in ipairs(changes) do
                tx.exec([[UPDATE `feather_authority_capabilities` SET `description`=?,`risk_class`=?,
                    `revision`=`revision`+1 WHERE `capability_id`=?]],
                    definition.description, definition.riskClass, existing[definition.key].capability_id)
            end
            local eventValues, eventParams = {}, {}
            for _, definition in ipairs(request.capabilities) do
                local capabilityId = existing[definition.key].capability_id
                identities[#identities + 1] = { key = definition.key, capabilityId = capabilityId }
                if events[definition.key] then
                    eventValues[#eventValues + 1] = '(UUID(),?,?,?,?)'
                    eventParams[#eventParams + 1] = capabilityId
                    eventParams[#eventParams + 1] = events[definition.key]
                    eventParams[#eventParams + 1] = resource
                    eventParams[#eventParams + 1] = request.requestId
                end
            end
            if #eventValues > 0 then
                tx.exec([[INSERT INTO `feather_authority_capability_events`
                    (`event_id`,`capability_id`,`event_type`,`source_resource`,`request_id`)
                    VALUES ]] .. table.concat(eventValues, ','), table.unpack(eventParams))
            end
            local value = { registered = registered, updated = updated, unchanged = unchanged,
                capabilities = identities, replayed = false }
            tx.exec([[UPDATE `feather_authority_capability_registration_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]],
                json.encode(value), resource, request.requestId)
            if registered + updated > 0 then
                tx.exec('UPDATE `feather_authority_policy_state` SET `policy_version`=`policy_version`+1 WHERE `id`=1')
            end
            return Authority.Ok(value)
        end, debug.traceback)
        if not executed then result = Authority.Err('internal_error', 'Capability registration failed.'); return false end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Authority.Err('transaction_failed', 'Registration did not confirm commit. Retry the same request ID.')
    end
    if result and result.ok then
        local loaded = AuthorityCapabilities.Load()
        if not loaded.ok then return loaded end
    end
    return result or Authority.Err('transaction_failed', 'Registration did not complete. Retry the same request ID.')
end

function AuthorityCapabilities.Load()
    for _, definition in ipairs(Config.Capabilities) do
        local existing = DB.one(
            'SELECT `owner_resource` FROM `feather_authority_capabilities` WHERE `capability_key`=?',
            definition.key)
        if existing and existing.owner_resource ~= GetCurrentResourceName() then
            return Authority.Err('capability_owner_conflict', 'Configured capability belongs to another resource.', {
                capabilityKey = definition.key
            })
        end
        DB.exec([[INSERT INTO `feather_authority_capabilities`
            (`capability_id`,`capability_key`,`description`,`risk_class`,`owner_resource`)
            VALUES (UUID(),?,?,?,?) ON DUPLICATE KEY UPDATE
                `revision`=`revision` + IF(`description`<>VALUES(`description`)
                    OR `risk_class`<>VALUES(`risk_class`),1,0),
                `description`=VALUES(`description`),
                `risk_class`=VALUES(`risk_class`)]],
            definition.key, definition.description, definition.riskClass, GetCurrentResourceName()
        )
    end
    local rows = DB.query([[SELECT `capability_id`,`capability_key`,`description`,
        `risk_class`,`owner_resource`,`status`,`revision`
        FROM `feather_authority_capabilities` ORDER BY `capability_key` LIMIT 129]]) or {}
    if #rows > 128 then
        return Authority.Err('capability_catalog_limit', 'Capability catalog exceeds the foundation limit of 128.')
    end
    local loaded = {}
    for _, row in ipairs(rows) do
        local revision = tonumber(row.revision)
        if not Authority.Uuid(row.capability_id) or not Authority.Integer(revision, 1, 9007199254740991)
            or (row.status ~= 'active' and row.status ~= 'retired') then
            return Authority.Err('invalid_persistence', 'Persisted capability identity, status, or revision is invalid.')
        end
        loaded[row.capability_key] = {
            capabilityId = row.capability_id,
            key = row.capability_key,
            description = row.description,
            riskClass = row.risk_class,
            ownerResource = row.owner_resource,
            status = row.status,
            revision = revision
        }
    end
    catalog = loaded
    return Authority.Ok({ capabilities = #rows })
end

function AuthorityCapabilities.Get(key, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(key) ~= 'string' or #key > 100
        or not key:match('^[a-z][a-z0-9_]*%.[a-z][a-z0-9_.]*$')
        or key:find('..', 1, true) then
        return Authority.Err('invalid_input', 'Valid capability key required.')
    end
    if not catalog[key] then return Authority.Err('capability_not_found', 'Capability was not found.') end
    return Authority.Ok(Authority.Copy(catalog[key]))
end

function AuthorityCapabilities.List(resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local result = {}
    for _, definition in pairs(catalog) do result[#result + 1] = Authority.Copy(definition) end
    table.sort(result, function(left, right) return left.key < right.key end)
    return Authority.Ok(result)
end

exports('GetCapability', function(key)
    return AuthorityCapabilities.Get(key, GetInvokingResource())
end)
exports('ListCapabilities', function()
    return AuthorityCapabilities.List(GetInvokingResource())
end)
exports('RegisterCapabilities', function(request)
    local called, result = xpcall(function()
        return AuthorityCapabilities.Register(request, GetInvokingResource())
    end, debug.traceback)
    if not called then return Authority.Err('internal_error', 'Capability registration operation failed.') end
    return result
end)
