AuthorityAssignments = {}
local Ok, Err = Authority.Ok, Authority.Err

local function Token(value, maximum, lower)
    if type(value) ~= 'string' or #value < 1 or #value > maximum then return false end
    return value:match(lower and '^[a-z][a-z0-9._:%-]*$'
        or '^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end
local function Text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and not value:find('%c') and value:find('%S') ~= nil
end

local function SubjectType(value)
    return value == 'account' or value == 'character'
end

local function IsCallable(value)
    return type(value) == 'function' or (type(value) == 'table'
        and type(rawget(value, '__cfx_functionReference')) == 'string')
end

local function ResolveSubject(subjectType, subjectId)
    if subjectType == 'account' then
        local identity = exports['feather-core']:GetAccountIdentity(subjectId)
        if type(identity) ~= 'table' or not identity.ok or type(identity.value) ~= 'table'
            or identity.value.accountId:lower() ~= subjectId:lower() then
            return Err('subject_not_found', 'Canonical account subject was not found.')
        end
        if identity.value.status ~= 'active' then
            return Err('subject_inactive', 'Account subject is not active.')
        end
        return Ok(identity.value)
    end
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    local implementation = type(provider) == 'table' and provider.ok and provider.value.implementation or nil
    if type(implementation) ~= 'table' or not IsCallable(implementation.GetIdentity) then
        return Err('subject_provider_unavailable', 'Canonical character identity provider is unavailable.')
    end
    local identity = implementation.GetIdentity(subjectId)
    if type(identity) ~= 'table' or not identity.ok or type(identity.value) ~= 'table'
        or identity.value.characterId:lower() ~= subjectId:lower() then
        return Err('subject_not_found', 'Canonical character subject was not found.')
    end
    if identity.value.status ~= 'active' then
        return Err('subject_inactive', 'Character subject is not active.')
    end
    return Ok(identity.value)
end

function AuthorityAssignments.ValidateIssue(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Assignment request required.') end
    local fields = { requestId = true, subjectType = true, subjectId = true, roleId = true,
        expectedRoleRevision = true, scopeType = true, validUntil = true, reason = true,
        reasonCode = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected assignment field.') end
    end
    if not Token(request.requestId, 128, false) or not SubjectType(request.subjectType)
        or not Authority.Uuid(request.subjectId) or not Authority.Uuid(request.roleId)
        or not Authority.Integer(request.expectedRoleRevision, 1, 9007199254740991)
        or request.scopeType ~= 'server' or not Text(request.reason, 255)
        or not Token(request.reasonCode, 64, true)
        or (request.validUntil ~= nil and not Authority.Integer(request.validUntil, 1, 4102444800)) then
        return Err('invalid_input', 'Subject, role revision, server scope, expiry, reason, and stable IDs are required.')
    end
    local fingerprint = {}
    for _, field in ipairs({ 'subjectType', 'subjectId', 'roleId', 'expectedRoleRevision',
        'scopeType', 'validUntil', 'reason', 'reasonCode' }) do
        local value = request[field] == nil and '' or tostring(request[field])
        fingerprint[#fingerprint + 1] = tostring(#value) .. ':' .. value
    end
    return Ok(table.concat(fingerprint))
end

function AuthorityAssignments.ValidateLifecycle(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Assignment lifecycle request required.') end
    local fields = { requestId = true, assignmentId = true, expectedRevision = true,
        status = true, reasonCode = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected assignment lifecycle field.') end
    end
    if not Token(request.requestId, 128, false) or not Authority.Uuid(request.assignmentId)
        or not Authority.Integer(request.expectedRevision, 1, 9007199254740991)
        or (request.status ~= 'active' and request.status ~= 'suspended' and request.status ~= 'revoked')
        or not Token(request.reasonCode, 64, true) then
        return Err('invalid_input', 'Assignment, revision, target status, reason, and stable request ID are required.')
    end
    local fingerprint = {}
    for _, field in ipairs({ 'assignmentId', 'expectedRevision', 'status', 'reasonCode' }) do
        local value = tostring(request[field])
        fingerprint[#fingerprint + 1] = tostring(#value) .. ':' .. value
    end
    return Ok(table.concat(fingerprint))
end

function AuthorityAssignments.ValidateReplacement(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Assignment replacement request required.') end
    local fields = { requestId = true, subjectType = true, subjectId = true, roleId = true,
        expectedRoleRevision = true, scopeType = true, reason = true, reasonCode = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected assignment replacement field.') end
    end
    local assigning = request.roleId ~= nil or request.expectedRoleRevision ~= nil
    if not Token(request.requestId, 80, false) or not SubjectType(request.subjectType)
        or not Authority.Uuid(request.subjectId)
        or (assigning and (not Authority.Uuid(request.roleId)
            or not Authority.Integer(request.expectedRoleRevision, 1, 9007199254740991)))
        or request.scopeType ~= 'server' or not Text(request.reason, 255)
        or not Token(request.reasonCode, 64, true) then
        return Err('invalid_input', 'Subject, owned role revision, scope, reason, and stable request ID are required.')
    end
    local fingerprint = {}
    for _, field in ipairs({ 'subjectType', 'subjectId', 'roleId', 'expectedRoleRevision',
        'scopeType', 'reason', 'reasonCode' }) do
        local value = request[field] == nil and '' or tostring(request[field])
        fingerprint[#fingerprint + 1] = tostring(#value) .. ':' .. value
    end
    return Ok(table.concat(fingerprint))
end

local function Snapshot(row)
    if not row then return Err('assignment_not_found', 'Authority assignment was not found.') end
    local revision = tonumber(row.revision)
    if not Authority.Uuid(row.assignment_id) or not SubjectType(row.subject_type)
        or not Authority.Uuid(row.subject_id) or not Authority.Uuid(row.role_id)
        or row.issuer_type ~= 'service_principal' or type(row.issuer_id) ~= 'string'
        or row.scope_type ~= 'server'
        or (row.status ~= 'active' and row.status ~= 'suspended' and row.status ~= 'revoked')
        or not Authority.Integer(revision, 1, 9007199254740991) then
        return Err('invalid_persistence', 'Persisted Authority assignment is invalid.')
    end
    return Ok({ assignmentId = row.assignment_id, subjectType = row.subject_type,
        subjectId = row.subject_id, roleId = row.role_id, issuerType = row.issuer_type,
        issuerId = row.issuer_id, scopeType = row.scope_type, validFrom = row.valid_from,
        validUntil = row.valid_until, status = row.status, reason = row.reason, revision = revision })
end

function AuthorityAssignments.Get(request, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or not Authority.Uuid(request.assignmentId) then
        return Err('invalid_input', 'Assignment UUID required.')
    end
    for field in pairs(request) do
        if field ~= 'assignmentId' then return Err('invalid_input', 'Unexpected assignment read field.') end
    end
    return Snapshot(DB.one(
        'SELECT * FROM `feather_authority_assignments` WHERE `assignment_id`=?',
        request.assignmentId:lower()))
end

function AuthorityAssignments.ListSubject(request, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' then return Err('invalid_input', 'Subject assignment request required.') end
    local fields = { subjectType = true, subjectId = true, scopeType = true,
        ownerResource = true, status = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected subject assignment field.') end
    end
    if not SubjectType(request.subjectType) or not Authority.Uuid(request.subjectId)
        or request.scopeType ~= 'server' or type(request.ownerResource) ~= 'string'
        or #request.ownerResource < 1 or #request.ownerResource > 100
        or (request.status ~= nil and request.status ~= 'active'
            and request.status ~= 'suspended' and request.status ~= 'revoked') then
        return Err('invalid_input', 'Subject, server scope, owner resource, and valid status are required.')
    end
    if resource ~= GetCurrentResourceName() and request.ownerResource ~= resource then
        return Err('authorization_denied', 'A caller may only list assignments for roles it owns.')
    end
    local parameters = { request.subjectType, request.subjectId:lower(), request.ownerResource }
    local statusSql = ''
    if request.status then
        statusSql = ' AND a.`status`=?'
        parameters[#parameters + 1] = request.status
        if request.status == 'active' then
            statusSql = statusSql
                .. " AND (a.`valid_until` IS NULL OR a.`valid_until`>CURRENT_TIMESTAMP)"
                .. " AND r.`status`='active'"
        end
    end
    local rows = DB.query([[SELECT a.*,r.`role_key`,r.`label`,r.`role_class`,
            r.`owner_resource`,r.`status` AS `role_status`,r.`revision` AS `role_revision`
        FROM `feather_authority_assignments` a
        JOIN `feather_authority_roles` r ON r.`role_id`=a.`role_id`
        WHERE a.`subject_type`=? AND a.`subject_id`=? AND a.`scope_type`='server'
            AND r.`owner_resource`=?]] .. statusSql .. [[
        ORDER BY a.`created_at` DESC,a.`assignment_id` DESC LIMIT 51]], table.unpack(parameters, 1, #parameters)) or {}
    if #rows > 50 then return Err('assignment_result_limit', 'Subject assignment result exceeds 50.') end
    local values = {}
    for _, row in ipairs(rows) do
        local assignment = Snapshot(row)
        if not assignment.ok then return assignment end
        if type(row.role_key) ~= 'string' or type(row.label) ~= 'string'
            or row.role_class ~= 'staff' or row.owner_resource ~= request.ownerResource
            or (row.role_status ~= 'active' and row.role_status ~= 'retired')
            or not Authority.Integer(tonumber(row.role_revision), 1, 9007199254740991) then
            return Err('invalid_persistence', 'Persisted subject assignment role is invalid.')
        end
        assignment.value.roleKey = row.role_key
        assignment.value.roleLabel = row.label
        assignment.value.roleClass = row.role_class
        assignment.value.roleOwnerResource = row.owner_resource
        assignment.value.roleRevision = tonumber(row.role_revision)
        values[#values + 1] = assignment.value
    end
    return Ok(values)
end

function AuthorityAssignments.Issue(request, resource)
    if Config.Access.trustedAssigners[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted assigner.')
    end
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = AuthorityAssignments.ValidateIssue(request)
    if not valid.ok then return valid end
    local identity = ResolveSubject(request.subjectType, request.subjectId)
    if not identity.ok then return identity end
    request = Authority.Copy(request)
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_authority_assignment_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]],
                resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json` FROM
                `feather_authority_assignment_receipts` WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]],
                resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Err('internal_error', 'Assignment receipt could not be reserved.') end
            if receipt.request_fingerprint ~= valid.value then
                return Err('idempotency_conflict', 'Request ID is bound to a different assignment payload.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' or not Authority.Uuid(value.subjectId)
                    or (value.cleared ~= true and not Authority.Uuid(value.assignmentId)) then
                    return Err('invalid_persistence', 'Stored assignment receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local roles = tx.query('SELECT * FROM `feather_authority_roles` WHERE `role_id`=? FOR UPDATE',
                request.roleId:lower()) or {}
            local role = roles[1]
            if not role then return Err('role_not_found', 'Authority role was not found.') end
            if role.status ~= 'active' then return Err('role_inactive', 'Authority role is not active.') end
            if role.role_class ~= 'staff' then return Err('class_mismatch', 'Staff subjects require a staff role.') end
            if tonumber(role.revision) ~= request.expectedRoleRevision then
                return Err('revision_conflict', 'Authority role revision changed.')
            end
            local existing = tx.query([[SELECT `assignment_id` FROM `feather_authority_assignments`
                WHERE `subject_type`=? AND `subject_id`=? AND `role_id`=?
                    AND `scope_type`='server' AND `status` IN ('active','suspended')
                    AND (`valid_until` IS NULL OR `valid_until`>CURRENT_TIMESTAMP) FOR UPDATE]],
                request.subjectType, request.subjectId:lower(), request.roleId:lower()) or {}
            if existing[1] then return Err('assignment_conflict', 'An active assignment already exists.') end
            local ids = tx.query('SELECT UUID() AS `assignment_id`,UUID() AS `event_id`') or {}
            local assignmentId, eventId = ids[1] and ids[1].assignment_id, ids[1] and ids[1].event_id
            if not Authority.Uuid(assignmentId) or not Authority.Uuid(eventId) then
                return Err('internal_error', 'Could not generate assignment identities.')
            end
            tx.exec([[INSERT INTO `feather_authority_assignments`
                (`assignment_id`,`subject_type`,`subject_id`,`role_id`,`issuer_type`,`issuer_id`,
                    `scope_type`,`valid_until`,`reason`) VALUES (?,?,?,?,'service_principal',?,
                    'server',FROM_UNIXTIME(?),?)]],
                assignmentId, request.subjectType, request.subjectId:lower(), request.roleId:lower(), resource,
                    request.validUntil, request.reason)
            local rows = tx.query('SELECT * FROM `feather_authority_assignments` WHERE `assignment_id`=? FOR UPDATE',
                assignmentId) or {}
            local created = Snapshot(rows[1])
            if not created.ok then return created end
            created.value.roleRevision = request.expectedRoleRevision
            created.value.replayed = false
            tx.exec([[INSERT INTO `feather_authority_assignment_events`
                (`event_id`,`assignment_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`)
                VALUES (?,?,'authority.assignment.issued',?,?,?,1)]],
                eventId, assignmentId, resource, request.requestId, request.reasonCode)
            tx.exec([[UPDATE `feather_authority_assignment_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]],
                json.encode(created.value), resource, request.requestId)
            tx.exec('UPDATE `feather_authority_policy_state` SET `policy_version`=`policy_version`+1 WHERE `id`=1')
            return created
        end, debug.traceback)
        if not executed then result = Err('internal_error', 'Assignment transaction failed.'); return false end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Assignment did not confirm commit. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Assignment did not complete. Retry the same request ID.')
end

function AuthorityAssignments.ChangeStatus(request, resource)
    if Config.Access.trustedAssigners[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted assigner.')
    end
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = AuthorityAssignments.ValidateLifecycle(request)
    if not valid.ok then return valid end
    request = Authority.Copy(request)
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_authority_assignment_lifecycle_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]],
                resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json` FROM
                `feather_authority_assignment_lifecycle_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]],
                resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Err('internal_error', 'Lifecycle receipt could not be reserved.') end
            if receipt.request_fingerprint ~= valid.value then
                return Err('idempotency_conflict', 'Request ID is bound to a different lifecycle payload.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' or not Authority.Uuid(value.assignmentId) then
                    return Err('invalid_persistence', 'Stored lifecycle receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local rows = tx.query([[SELECT *,(valid_until IS NOT NULL AND valid_until<=CURRENT_TIMESTAMP) AS expired
                FROM `feather_authority_assignments` WHERE `assignment_id`=? FOR UPDATE]],
                request.assignmentId:lower()) or {}
            local row = rows[1]
            if not row then return Err('assignment_not_found', 'Authority assignment was not found.') end
            if tonumber(row.revision) ~= request.expectedRevision then
                return Err('revision_conflict', 'Authority assignment revision changed.')
            end
            if row.status == 'revoked' then return Err('assignment_terminal', 'Revoked assignment is terminal.') end
            if row.status == request.status then return Err('status_unchanged', 'Assignment already has that status.') end
            local transition = (row.status == 'active' and (request.status == 'suspended' or request.status == 'revoked'))
                or (row.status == 'suspended' and (request.status == 'active' or request.status == 'revoked'))
            if not transition then return Err('invalid_transition', 'Assignment status transition is invalid.') end
            if request.status == 'active' and tonumber(row.expired) == 1 then
                return Err('assignment_expired', 'Expired assignment cannot be resumed.')
            end
            tx.exec([[UPDATE `feather_authority_assignments` SET `status`=?,`revision`=`revision`+1,
                `revoked_at`=IF(?='revoked',CURRENT_TIMESTAMP,NULL) WHERE `assignment_id`=?]],
                request.status, request.status, request.assignmentId:lower())
            local changed = tx.query('SELECT * FROM `feather_authority_assignments` WHERE `assignment_id`=?',
                request.assignmentId:lower()) or {}
            local snapshot = Snapshot(changed[1])
            if not snapshot.ok then return snapshot end
            snapshot.value.replayed = false
            local ids = tx.query('SELECT UUID() AS `event_id`') or {}
            tx.exec([[INSERT INTO `feather_authority_assignment_events`
                (`event_id`,`assignment_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`)
                VALUES (?,?,?,?,?,?,?)]], ids[1].event_id, request.assignmentId:lower(),
                'authority.assignment.' .. request.status, resource, request.requestId,
                request.reasonCode, snapshot.value.revision)
            tx.exec([[UPDATE `feather_authority_assignment_lifecycle_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]],
                json.encode(snapshot.value), resource, request.requestId)
            tx.exec('UPDATE `feather_authority_policy_state` SET `policy_version`=`policy_version`+1 WHERE `id`=1')
            return snapshot
        end, debug.traceback)
        if not executed then result = Err('internal_error', 'Assignment lifecycle transaction failed.'); return false end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Assignment lifecycle did not confirm commit. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Assignment lifecycle did not complete. Retry the same request ID.')
end

function AuthorityAssignments.ReplaceOwned(request, resource)
    if Config.Access.trustedAssigners[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted assigner.')
    end
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = AuthorityAssignments.ValidateReplacement(request)
    if not valid.ok then return valid end
    local identity = ResolveSubject(request.subjectType, request.subjectId)
    if not identity.ok then return identity end
    request = Authority.Copy(request)
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_authority_assignment_replacement_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]],
                resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json` FROM
                `feather_authority_assignment_replacement_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]],
                resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Err('internal_error', 'Replacement receipt could not be reserved.') end
            if receipt.request_fingerprint ~= valid.value then
                return Err('idempotency_conflict', 'Request ID is bound to a different assignment replacement.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table'
                    or (value.cleared ~= true and not Authority.Uuid(value.assignmentId)) then
                    return Err('invalid_persistence', 'Stored assignment replacement receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local role
            if request.roleId ~= nil then
                local roles = tx.query('SELECT * FROM `feather_authority_roles` WHERE `role_id`=? FOR UPDATE',
                    request.roleId:lower()) or {}
                role = roles[1]
                if not role then return Err('role_not_found', 'Authority role was not found.') end
                if role.status ~= 'active' or role.role_class ~= 'staff' then
                    return Err('role_inactive', 'An active staff role is required.')
                end
                if role.owner_resource ~= resource then
                    return Err('authorization_denied', 'A service may only replace assignments for roles it owns.')
                end
                if tonumber(role.revision) ~= request.expectedRoleRevision then
                    return Err('revision_conflict', 'Authority role revision changed.')
                end
            end
            local current = tx.query([[SELECT a.* FROM `feather_authority_assignments` a
                JOIN `feather_authority_roles` r ON r.`role_id`=a.`role_id`
                WHERE a.`subject_type`=? AND a.`subject_id`=? AND a.`scope_type`='server'
                    AND a.`status` IN ('active','suspended') AND r.`owner_resource`=? FOR UPDATE]],
                request.subjectType, request.subjectId:lower(), resource) or {}
            if role and #current == 1 and current[1].role_id:lower() == request.roleId:lower()
                and current[1].status == 'active' then
                local unchanged = Snapshot(current[1])
                if not unchanged.ok then return unchanged end
                unchanged.value.replaced = 0
                unchanged.value.unchanged = true
                unchanged.value.replayed = false
                tx.exec([[UPDATE `feather_authority_assignment_replacement_receipts` SET `result_json`=?
                    WHERE `source_resource`=? AND `request_id`=?]],
                    json.encode(unchanged.value), resource, request.requestId)
                return unchanged
            end
            for index, row in ipairs(current) do
                tx.exec([[UPDATE `feather_authority_assignments` SET `status`='revoked',
                    `revision`=`revision`+1,`revoked_at`=CURRENT_TIMESTAMP WHERE `assignment_id`=?]],
                    row.assignment_id)
                local ids = tx.query('SELECT UUID() AS `event_id`') or {}
                tx.exec([[INSERT INTO `feather_authority_assignment_events`
                    (`event_id`,`assignment_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`)
                    VALUES (?,?, 'authority.assignment.revoked',?,?,?,?)]],
                    ids[1].event_id, row.assignment_id, resource,
                        request.requestId .. ':revoke:' .. tostring(index), request.reasonCode,
                        tonumber(row.revision) + 1)
            end
            if not role then
                local cleared = { subjectId = request.subjectId:lower(), cleared = true,
                    replaced = #current, unchanged = #current == 0, replayed = false }
                tx.exec([[UPDATE `feather_authority_assignment_replacement_receipts` SET `result_json`=?
                    WHERE `source_resource`=? AND `request_id`=?]],
                    json.encode(cleared), resource, request.requestId)
                if #current > 0 then
                    tx.exec('UPDATE `feather_authority_policy_state` SET `policy_version`=`policy_version`+1 WHERE `id`=1')
                end
                return Ok(cleared)
            end
            local ids = tx.query('SELECT UUID() AS `assignment_id`,UUID() AS `event_id`') or {}
            local assignmentId = ids[1] and ids[1].assignment_id
            if not Authority.Uuid(assignmentId) then
                return Err('internal_error', 'Could not generate replacement assignment identity.')
            end
            tx.exec([[INSERT INTO `feather_authority_assignments`
                (`assignment_id`,`subject_type`,`subject_id`,`role_id`,`issuer_type`,`issuer_id`,
                    `scope_type`,`reason`) VALUES (?,?,?,?,'service_principal',?,'server',?)]],
                assignmentId, request.subjectType, request.subjectId:lower(), request.roleId:lower(), resource,
                    request.reason)
            local createdRows = tx.query('SELECT * FROM `feather_authority_assignments` WHERE `assignment_id`=?',
                assignmentId) or {}
            local created = Snapshot(createdRows[1])
            if not created.ok then return created end
            created.value.roleRevision = request.expectedRoleRevision
            created.value.replaced = #current
            created.value.unchanged = false
            created.value.replayed = false
            tx.exec([[INSERT INTO `feather_authority_assignment_events`
                (`event_id`,`assignment_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`)
                VALUES (?,?, 'authority.assignment.issued',?,?,?,1)]],
                ids[1].event_id, assignmentId, resource, request.requestId .. ':issue', request.reasonCode)
            tx.exec([[UPDATE `feather_authority_assignment_replacement_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]],
                json.encode(created.value), resource, request.requestId)
            tx.exec('UPDATE `feather_authority_policy_state` SET `policy_version`=`policy_version`+1 WHERE `id`=1')
            return created
        end, debug.traceback)
        if not executed then result = Err('internal_error', 'Assignment replacement transaction failed.'); return false end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Assignment replacement did not confirm commit. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Assignment replacement did not complete. Retry the same request ID.')
end

exports('IssueAssignment', function(request)
    local called, result = xpcall(function()
        return AuthorityAssignments.Issue(request, GetInvokingResource())
    end, debug.traceback)
    if not called then return Err('internal_error', 'Authority assignment operation failed.') end
    return result
end)
exports('GetAssignment', function(request)
    return AuthorityAssignments.Get(request, GetInvokingResource())
end)
exports('ListSubjectAssignments', function(request)
    return AuthorityAssignments.ListSubject(request, GetInvokingResource())
end)
exports('ChangeAssignmentStatus', function(request)
    local called, result = xpcall(function()
        return AuthorityAssignments.ChangeStatus(request, GetInvokingResource())
    end, debug.traceback)
    if not called then return Err('internal_error', 'Authority assignment lifecycle operation failed.') end
    return result
end)
exports('ReplaceOwnedStaffAssignment', function(request)
    local called, result = xpcall(function()
        return AuthorityAssignments.ReplaceOwned(request, GetInvokingResource())
    end, debug.traceback)
    if not called then return Err('internal_error', 'Assignment replacement operation failed.') end
    return result
end)
