LicenseRecords = {}
local Ok, Err = Licenses.Ok, Licenses.Err

-- A license with its definition label and the database clock, so validity is
-- always computed against one time source.
local selectLicense = [[
    SELECT l.`license_id`,l.`license_key`,l.`holder_type`,l.`holder_id`,l.`status`,l.`issuer_type`,
        l.`issuer_id`,l.`issuer_resource`,l.`scope_version`,l.`scope_json`,l.`expires_at_ms`,l.`revision`,
        FLOOR(UNIX_TIMESTAMP(l.`issued_at`))*1000 AS issued_at_ms,
        FLOOR(UNIX_TIMESTAMP(l.`renewed_at`))*1000 AS renewed_at_ms,
        FLOOR(UNIX_TIMESTAMP(l.`suspended_at`))*1000 AS suspended_at_ms,
        FLOOR(UNIX_TIMESTAMP(l.`revoked_at`))*1000 AS revoked_at_ms,
        d.`label`,d.`status` AS definition_status,
        UNIX_TIMESTAMP()*1000 AS now_ms
    FROM `feather_licenses` l
    JOIN `feather_license_definitions` d ON d.`license_key`=l.`license_key`]]

local function Slot(licenseKey, holderType, holderId)
    return table.concat({ licenseKey, holderType, holderId }, '|')
end

-- Snapshots ----------------------------------------------------------------------

function LicenseRecords.Snapshot(row, includeScope)
    if not row then
        return Err('license_not_found', 'License not found.')
    end
    if not Licenses.Uuid(row.license_id) or not Licenses.Key(row.license_key, 48)
        or not Licenses.Statuses[row.status] or not Licenses.IssuerTypes[row.issuer_type]
        or not Licenses.Integer(tonumber(row.revision), 1, Licenses.MaxRevision + 1) then
        return Err('invalid_persistence', 'Persisted license is invalid.')
    end
    local expiresAt = row.expires_at_ms and tonumber(row.expires_at_ms) or nil
    local expired = expiresAt ~= nil and expiresAt <= tonumber(row.now_ms)
    local snapshot = {
        licenseId = row.license_id,
        licenseKey = row.license_key,
        label = row.label,
        definitionStatus = row.definition_status,
        holderType = row.holder_type,
        holderId = row.holder_id,
        status = row.status,
        expired = expired,
        valid = row.status == 'active' and not expired,
        issuer = { type = row.issuer_type, id = row.issuer_id },
        issuerResource = row.issuer_resource,
        scopeVersion = tonumber(row.scope_version),
        issuedAt = tonumber(row.issued_at_ms),
        expiresAt = expiresAt,
        renewedAt = row.renewed_at_ms and tonumber(row.renewed_at_ms) or nil,
        suspendedAt = row.suspended_at_ms and tonumber(row.suspended_at_ms) or nil,
        revokedAt = row.revoked_at_ms and tonumber(row.revoked_at_ms) or nil,
        revision = tonumber(row.revision)
    }
    if includeScope then
        local scope = {}
        if row.scope_json then
            local decoded, value = pcall(json.decode, row.scope_json)
            if not decoded or type(value) ~= 'table' then
                return Err('invalid_persistence', 'Persisted license scope is invalid.')
            end
            scope = value
        end
        snapshot.scope = scope
    end
    return Ok(snapshot)
end

function LicenseRecords.Read(tx, licenseId)
    local row = (tx.query(selectLicense .. ' WHERE l.`license_id`=?', licenseId) or {})[1]
    return LicenseRecords.Snapshot(row, true)
end

-- Locks the license row only; its definition is read without a lock. Lock order
-- across all license mutations is: receipt -> license.
local function Lock(tx, licenseId)
    return (tx.query([[
        SELECT `license_id`,`license_key`,`holder_type`,`holder_id`,`status`,`expires_at_ms`,`revision`,
            UNIX_TIMESTAMP()*1000 AS now_ms
        FROM `feather_licenses` WHERE `license_id`=? FOR UPDATE]], licenseId) or {})[1]
end

local function ReadDefinition(db, licenseKey, lock)
    local row = (db.query(LicenseDefinitions.Select .. ' WHERE `license_key`=?' .. (lock and ' LOCK IN SHARE MODE' or ''),
        licenseKey) or {})[1]
    return LicenseDefinitions.Snapshot(row)
end

local function CanIssue(definition, resource)
    return definition.ownerResource == resource or Config.Access.privilegedIssuers[resource] == true
end

local function DurationOrNil(value)
    return Licenses.Integer(value, 1, Config.Limits.maxDurationSeconds)
end

-- IssueLicense -------------------------------------------------------------------
-- The definition owner (or a privileged issuer) issues; prerequisites and fees
-- are the caller's business. A character issuer is always the acting player.

local issueFields = Licenses.Allowed({
    'licenseKey',
    'holderType',
    'holderId',
    'issuerType',
    'issuerId',
    'durationSeconds',
    'scopeVersion',
    'scope'
})

function LicenseRecords.Issue(request, resource)
    local begun = Licenses.Begin(request, resource, 'trustedIssuers', issueFields)
    if not begun.ok then
        return begun
    end
    local issuerType = request.issuerType or 'system'
    if not Licenses.Key(request.licenseKey, 48) or not Config.HolderTypes[request.holderType or '']
        or not Licenses.Uuid(request.holderId) or not Licenses.IssuerTypes[issuerType]
        or (request.durationSeconds ~= nil and request.durationSeconds ~= false
            and not DurationOrNil(request.durationSeconds))
        or (request.scopeVersion ~= nil and not Licenses.Integer(request.scopeVersion, 1, 65535)) then
        return Err('invalid_input',
            'License key, holder, and optional issuer, duration (seconds or false), scope version and scope required.')
    end
    if (issuerType == 'organization') ~= (request.issuerId ~= nil)
        or (request.issuerId ~= nil and not Licenses.Uuid(request.issuerId)) then
        return Err('invalid_input', 'An organization issuer needs issuerId; other issuers take none.')
    end
    if issuerType == 'character' and request.actorSource == nil then
        return Err('invalid_input', 'A character issuer is the acting player: actorSource is required.')
    end
    local encodedScope
    if request.scope ~= nil then
        local scope = Licenses.ValidateScope(request.scope)
        if not scope.ok then
            return scope
        end
        encodedScope = scope.value
    end
    request = Licenses.Copy(request)
    request.holderId = request.holderId:lower()
    request.issuerId = request.issuerId and request.issuerId:lower() or nil
    request.issuerTypeResolved = issuerType
    request.scopeCanonical = request.scope ~= nil and Licenses.Canonical(request.scope) or nil
    request.scope = nil
    local actor = Licenses.Policy(Config.Authorization.issueAction, request, resource, {
        licenseKey = request.licenseKey,
        holderType = request.holderType,
        holderId = request.holderId
    })
    if not actor.ok then
        return actor
    end
    local issuerId = issuerType == 'character' and actor.value.characterId or request.issuerId

    return Licenses.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'license.issue',
        fingerprint = Licenses.Fingerprint('license.issue', request, {
            'licenseKey',
            'holderType',
            'holderId',
            'issuerTypeResolved',
            'issuerId',
            'durationSeconds',
            'scopeVersion',
            'scopeCanonical',
            'reasonCode'
        }),
        precheck = function()
            local definition = ReadDefinition(DB, request.licenseKey)
            if not definition.ok then
                return definition
            end
            if not CanIssue(definition.value, resource) then
                return Err('authorization_denied', 'Caller does not own this license definition.')
            end
            local holder = Licenses.ValidateHolder(definition.value.holderTypes, request.holderType, request.holderId)
            if not holder.ok then
                return holder
            end
            if issuerType == 'organization' then
                local issuer = Licenses.ResolveOrganization(issuerId)
                if not issuer.ok then
                    return Err('issuer_not_found', 'Issuing organization is not available.', { code = issuer.code })
                end
            end
            return Ok({})
        end,
        body = function(tx)
            -- A shared lock keeps the definition from being retired mid-issue.
            local definition = ReadDefinition(tx, request.licenseKey, true)
            if not definition.ok then
                return definition
            end
            definition = definition.value
            if not CanIssue(definition, resource) then
                return Err('authorization_denied', 'Caller does not own this license definition.')
            end
            if definition.status ~= 'active' then
                return Err('definition_inactive', 'License definition is retired.')
            end
            local duration = request.durationSeconds
            if duration == nil then
                duration = definition.defaultDurationSeconds
            elseif duration == false then
                duration = nil
            end
            if definition.maxDurationSeconds and (duration == nil or duration > definition.maxDurationSeconds) then
                return Err('invalid_duration', 'The duration exceeds what this license allows.', {
                    maxDurationSeconds = definition.maxDurationSeconds
                })
            end

            local ids, nowSeconds = Licenses.NewIds(tx, 2, true)
            local licenseId = ids[1]
            local expiresAt = duration and (nowSeconds + duration) * 1000 or nil
            local scopeVersion = request.scopeVersion or definition.scopeVersion
            -- The current-slot unique key decides duplicates without gap locks.
            local inserted = tx.exec([[
                INSERT IGNORE INTO `feather_licenses`
                    (`license_id`,`license_key`,`holder_type`,`holder_id`,`status`,`current_slot`,`issuer_type`,
                     `issuer_id`,`issuer_resource`,`scope_version`,`scope_json`,`issued_at`,`expires_at_ms`)
                VALUES (?,?,?,?,'active',?,?,?,?,?,?,FROM_UNIXTIME(?),?)]],
                licenseId, request.licenseKey, request.holderType, request.holderId,
                Slot(request.licenseKey, request.holderType, request.holderId), issuerType, issuerId, resource,
                scopeVersion, encodedScope, nowSeconds, expiresAt)
            if tonumber(inserted) ~= 1 then
                local existing = (tx.query('SELECT `license_id` FROM `feather_licenses` WHERE `current_slot`=?',
                    Slot(request.licenseKey, request.holderType, request.holderId)) or {})[1]
                if not existing then
                    return Err('internal_error', 'License could not be created.')
                end
                return Err('license_exists', 'The holder already has this license; renew or revoke it.', {
                    licenseId = existing.license_id
                })
            end
            LicenseEvents.Record(tx, 'license.issued', {
                aggregateType = 'license',
                aggregateId = licenseId,
                licenseId = licenseId,
                licenseKey = request.licenseKey,
                holderType = request.holderType,
                holderId = request.holderId,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = 1,
                actor = actor.value,
                details = {
                    status = 'active',
                    issuerType = issuerType,
                    issuerId = issuerId,
                    issuerResource = resource,
                    expiresAt = expiresAt,
                    scopeVersion = scopeVersion
                }
            }, ids[2])
            return LicenseRecords.Read(tx, licenseId)
        end
    })
end

-- Changes to an existing license ------------------------------------------------
-- Shared shape for renew, suspend, reinstate and revoke: the caller owns the
-- definition (or is privileged), the revision matches, and the stored status
-- allows the transition.

local function Change(request, resource, spec)
    local allowedFields = Licenses.Allowed(spec.fields)
    local begun = Licenses.Begin(request, resource, 'trustedIssuers', allowedFields)
    if not begun.ok then
        return begun
    end
    if not Licenses.Uuid(request.licenseId) or not Licenses.Integer(request.expectedRevision, 1, Licenses.MaxRevision) then
        return Err('invalid_input', 'License UUID and expected revision required.')
    end
    if spec.validate then
        local valid = spec.validate(request)
        if not valid.ok then
            return valid
        end
    end
    request = Licenses.Copy(request)
    request.licenseId = request.licenseId:lower()
    local actor = Licenses.Policy(spec.action, request, resource, { licenseId = request.licenseId })
    if not actor.ok then
        return actor
    end
    local fingerprintFields = { 'licenseId', 'expectedRevision', 'reasonCode' }
    for _, field in ipairs(spec.fields) do
        if field ~= 'licenseId' and field ~= 'expectedRevision' then
            fingerprintFields[#fingerprintFields + 1] = field
        end
    end

    return Licenses.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = spec.operation,
        fingerprint = Licenses.Fingerprint(spec.operation, request, fingerprintFields),
        body = function(tx)
            local row = Lock(tx, request.licenseId)
            if not row then
                return Err('license_not_found', 'License not found.')
            end
            local definition = ReadDefinition(tx, row.license_key)
            if not definition.ok then
                return definition
            end
            definition = definition.value
            if not CanIssue(definition, resource) then
                return Err('authorization_denied', 'Caller does not own this license definition.')
            end
            if row.status == 'revoked' then
                return Err('license_revoked', 'License has been revoked.')
            end
            local revision = tonumber(row.revision)
            if revision ~= request.expectedRevision then
                return Err('revision_conflict', 'License revision changed.', { revision = revision })
            end
            local applied = spec.apply(tx, row, definition, request)
            if not applied.ok then
                return applied
            end
            LicenseEvents.Record(tx, spec.eventType, {
                aggregateType = 'license',
                aggregateId = request.licenseId,
                licenseId = request.licenseId,
                licenseKey = row.license_key,
                holderType = row.holder_type,
                holderId = row.holder_id,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = applied.value
            })
            return LicenseRecords.Read(tx, request.licenseId)
        end
    })
end

-- RenewLicense: extends from the later of now and the current expiry, so paid
-- time is never lost and an expired license becomes valid again.
function LicenseRecords.Renew(request, resource)
    return Change(request, resource, {
        operation = 'license.renew',
        action = Config.Authorization.issueAction,
        eventType = 'license.renewed',
        fields = { 'licenseId', 'expectedRevision', 'durationSeconds' },
        validate = function(input)
            if input.durationSeconds ~= nil and not DurationOrNil(input.durationSeconds) then
                return Err('invalid_input', 'Duration must be a positive number of seconds.')
            end
            return Ok(true)
        end,
        apply = function(tx, row, definition, input)
            if row.status == 'suspended' then
                return Err('license_suspended', 'A suspended license cannot be renewed; reinstate it first.')
            end
            if definition.status ~= 'active' then
                return Err('definition_inactive', 'License definition is retired.')
            end
            if not definition.renewable then
                return Err('not_renewable', 'This license cannot be renewed.')
            end
            if row.expires_at_ms == nil then
                return Err('no_change', 'This license never expires.')
            end
            local duration = input.durationSeconds or definition.defaultDurationSeconds
            if not duration then
                return Err('invalid_duration', 'This license has no default duration; pass durationSeconds.')
            end
            local now, current = math.floor(tonumber(row.now_ms)), math.floor(tonumber(row.expires_at_ms))
            local expiresAt = math.floor(math.max(now, current) + duration * 1000)
            if definition.maxDurationSeconds and expiresAt - now > definition.maxDurationSeconds * 1000 then
                return Err('invalid_duration', 'The renewal would exceed what this license allows.', {
                    maxDurationSeconds = definition.maxDurationSeconds
                })
            end
            tx.exec([[
                UPDATE `feather_licenses`
                SET `expires_at_ms`=?,`renewed_at`=CURRENT_TIMESTAMP,`expiry_notified_at`=NULL,`revision`=`revision`+1
                WHERE `license_id`=? AND `revision`=?]], expiresAt, row.license_id, tonumber(row.revision))
            return Ok({ status = row.status, expiresAt = expiresAt, previousExpiresAt = current })
        end
    })
end

function LicenseRecords.Suspend(request, resource)
    return Change(request, resource, {
        operation = 'license.suspend',
        action = Config.Authorization.revokeAction,
        eventType = 'license.suspended',
        fields = { 'licenseId', 'expectedRevision' },
        apply = function(tx, row)
            if row.status == 'suspended' then
                return Err('no_change', 'License is already suspended.')
            end
            tx.exec([[
                UPDATE `feather_licenses` SET `status`='suspended',`suspended_at`=CURRENT_TIMESTAMP,`revision`=`revision`+1
                WHERE `license_id`=? AND `revision`=?]], row.license_id, tonumber(row.revision))
            return Ok({ status = 'suspended', previousStatus = row.status })
        end
    })
end

function LicenseRecords.Reinstate(request, resource)
    return Change(request, resource, {
        operation = 'license.reinstate',
        action = Config.Authorization.issueAction,
        eventType = 'license.reinstated',
        fields = { 'licenseId', 'expectedRevision' },
        apply = function(tx, row)
            if row.status == 'active' then
                return Err('no_change', 'License is not suspended.')
            end
            tx.exec([[
                UPDATE `feather_licenses` SET `status`='active',`suspended_at`=NULL,`revision`=`revision`+1
                WHERE `license_id`=? AND `revision`=?]], row.license_id, tonumber(row.revision))
            return Ok({ status = 'active', previousStatus = row.status })
        end
    })
end

-- RevokeLicense: terminal. The record and its history stay; the holder may be
-- issued the license again afterwards.
function LicenseRecords.Revoke(request, resource)
    return Change(request, resource, {
        operation = 'license.revoke',
        action = Config.Authorization.revokeAction,
        eventType = 'license.revoked',
        fields = { 'licenseId', 'expectedRevision' },
        apply = function(tx, row)
            tx.exec([[
                UPDATE `feather_licenses`
                SET `status`='revoked',`current_slot`=NULL,`revoked_at`=CURRENT_TIMESTAMP,`revision`=`revision`+1
                WHERE `license_id`=? AND `revision`=?]], row.license_id, tonumber(row.revision))
            return Ok({ status = 'revoked', previousStatus = row.status })
        end
    })
end

-- Reads ------------------------------------------------------------------------

function LicenseRecords.Get(request, resource)
    local allowed = Licenses.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Licenses.Fields(request, { licenseId = true })
    if not fields.ok then
        return fields
    end
    if not Licenses.Uuid(request.licenseId) then
        return Err('invalid_input', 'License UUID required.')
    end
    return LicenseRecords.Snapshot(DB.one(selectLicense .. ' WHERE l.`license_id`=?', request.licenseId:lower()), true)
end

-- CheckLicense returns facts only: whether the holder's current license of that
-- kind is valid now, and why not. The consumer decides what they permit.
local checkFields = { holderType = true, holderId = true, licenseKey = true }

function LicenseRecords.Check(request, resource)
    local allowed = Licenses.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Licenses.Fields(request, checkFields)
    if not fields.ok then
        return fields
    end
    if not Config.HolderTypes[request.holderType or ''] or not Licenses.Uuid(request.holderId)
        or not Licenses.Key(request.licenseKey, 48) then
        return Err('invalid_input', 'Holder type and UUID, and license key required.')
    end
    local row = DB.one(selectLicense .. ' WHERE l.`current_slot`=?',
        Slot(request.licenseKey, request.holderType, request.holderId:lower()))
    if not row then
        return Ok({ matched = false, licenseKey = request.licenseKey })
    end
    local snapshot = LicenseRecords.Snapshot(row, true)
    if not snapshot.ok then
        return snapshot
    end
    local license = snapshot.value
    return Ok({
        matched = license.valid,
        licenseKey = license.licenseKey,
        licenseId = license.licenseId,
        status = license.status,
        expired = license.expired,
        expiresAt = license.expiresAt,
        issuer = license.issuer,
        scopeVersion = license.scopeVersion,
        scope = license.scope,
        revision = license.revision
    })
end

-- Licenses of one holder, newest issued first. Bounded and paged.
function LicenseRecords.QueryByHolder(holderType, holderId, options)
    local sql = selectLicense .. ' WHERE l.`holder_type`=? AND l.`holder_id`=?'
    local params = { holderType, holderId }
    if options.licenseKey then
        sql = sql .. ' AND l.`license_key`=?'
        params[#params + 1] = options.licenseKey
    end
    if not options.includeRevoked then
        sql = sql .. " AND l.`status`<>'revoked'"
    end
    if options.cursor then
        local cursor = DB.one([[
            SELECT DATE_FORMAT(`issued_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_licenses` WHERE `license_id`=? AND `holder_type`=? AND `holder_id`=?]],
            options.cursor, holderType, holderId)
        if not cursor then
            return Err('invalid_cursor', 'License cursor was not found for this holder.')
        end
        sql = sql .. ' AND (l.`issued_at`<? OR (l.`issued_at`=? AND l.`license_id`<?))'
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = options.cursor
    end
    sql = sql .. ' ORDER BY l.`issued_at` DESC,l.`license_id` DESC LIMIT ?'
    params[#params + 1] = options.limit + 1

    local rows = DB.query(sql, table.unpack(params)) or {}
    local items = {}
    for index = 1, math.min(#rows, options.limit) do
        local snapshot = LicenseRecords.Snapshot(rows[index], options.includeScope)
        if not snapshot.ok then
            return snapshot
        end
        items[#items + 1] = snapshot.value
    end
    return Ok({
        items = items,
        nextCursor = #rows > options.limit and items[#items].licenseId or nil
    })
end

local listFields = {
    holderType = true,
    holderId = true,
    licenseKey = true,
    includeRevoked = true,
    includeScope = true,
    limit = true,
    cursor = true
}

function LicenseRecords.ListByHolder(request, resource)
    local allowed = Licenses.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Licenses.Fields(request, listFields)
    if not fields.ok then
        return fields
    end
    local limit = request.limit == nil and 20 or request.limit
    if not Config.HolderTypes[request.holderType or ''] or not Licenses.Uuid(request.holderId)
        or (request.licenseKey ~= nil and not Licenses.Key(request.licenseKey, 48))
        or (request.includeRevoked ~= nil and type(request.includeRevoked) ~= 'boolean')
        or (request.includeScope ~= nil and type(request.includeScope) ~= 'boolean')
        or not Licenses.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.cursor ~= nil and not Licenses.Uuid(request.cursor)) then
        return Err('invalid_input',
            'Holder type and UUID, optional license key and flags, bounded limit, and license UUID cursor required.')
    end
    return LicenseRecords.QueryByHolder(request.holderType, request.holderId:lower(), {
        licenseKey = request.licenseKey,
        includeRevoked = request.includeRevoked == true,
        includeScope = request.includeScope == true,
        limit = limit,
        cursor = request.cursor and request.cursor:lower() or nil
    })
end

Licenses.Export('IssueLicense', LicenseRecords.Issue)
Licenses.Export('RenewLicense', LicenseRecords.Renew)
Licenses.Export('SuspendLicense', LicenseRecords.Suspend)
Licenses.Export('ReinstateLicense', LicenseRecords.Reinstate)
Licenses.Export('RevokeLicense', LicenseRecords.Revoke)
Licenses.Export('GetLicense', LicenseRecords.Get)
Licenses.Export('CheckLicense', LicenseRecords.Check)
Licenses.Export('ListHolderLicenses', LicenseRecords.ListByHolder)
