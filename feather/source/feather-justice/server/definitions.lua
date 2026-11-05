-- Jurisdictions and statutes (master plan: Domain design; Definition operations).
local J, Repo, M, A = Justice, Justice.Repo, Justice.Mutation, Justice.Access
local maximumRevision = 9007199254740989
local maximumTime = 9007199254740990
local severities = { infraction = true, misdemeanor = true, felony = true }
local statuses = { active = true, retired = true }

local function TypeAllowed(value)
    for _, allowed in ipairs(JusticeConfig.JurisdictionTypes) do if allowed == value then return true end end
    return false
end
local function Range(value, maximum)
    return value == nil or (type(value) == 'table' and J.Fields(value, { min = true, max = true })
        and J.Integer(value.min, 0, maximum) and J.Integer(value.max, value.min or 0, maximum))
end
local function Metadata(request, current)
    local metadata = J.Copy(current or {})
    if request.recommendedFine ~= nil then metadata.recommendedFine = request.recommendedFine end
    if request.recommendedCustodySeconds ~= nil then metadata.recommendedCustodySeconds = request.recommendedCustodySeconds end
    return next(metadata) and metadata or nil
end
-- A statute applies only while active and inside its effective window.
function J.StatuteInForce(statute, now)
    return statute and statute.status == 'active' and (statute.effective_from == nil or statute.effective_from <= now)
        and (statute.effective_until == nil or statute.effective_until > now)
end

J.Export('RegisterJurisdiction', function(p, owner)
    if not M.Fields(p, { 'jurisdictionKey', 'label', 'jurisdictionType', 'parentJurisdictionId' }, true)
        or not J.Token(p.jurisdictionKey, 128) or p.jurisdictionKey:sub(1, #(owner or '') + 1) ~= (owner or '') .. ':'
        or not J.Text(p.label, 100) or not TypeAllowed(p.jurisdictionType)
        or (p.parentJurisdictionId ~= nil and not J.Uuid(p.parentJurisdictionId)) then
        return J.Err('invalid_input', 'Namespaced key (owner:name), label, configured type and optional parent UUID required.')
    end
    local actor = J.Principal(owner, 'justice.definition.manage', p, p.parentJurisdictionId, true)
    if not actor.ok then return actor end
    return M.Run('jurisdiction.registered', p, owner, actor.value, function(tx, context)
        if Repo.KeyExists(tx.one, 'jurisdiction', 'jurisdiction_key', p.jurisdictionKey) then
            return J.Err('key_conflict', 'Jurisdiction key already exists; reuse its original request ID.')
        end
        if p.parentJurisdictionId then
            local depth, cursor = 1, Repo.Get(tx.one, 'jurisdiction', p.parentJurisdictionId:lower(), owner, true)
            if not cursor or cursor.status ~= 'active' then return J.Err('jurisdiction_unavailable', 'Active owned parent jurisdiction required.') end
            while cursor.parent_jurisdiction_id do
                depth = depth + 1
                if depth >= JusticeConfig.MaximumJurisdictionDepth then return J.Err('hierarchy_too_deep', 'Jurisdiction hierarchy is bounded.') end
                cursor = Repo.Get(tx.one, 'jurisdiction', cursor.parent_jurisdiction_id, owner)
                if not cursor then break end
            end
        end
        local row = { jurisdiction_id = J.NewUuid(), jurisdiction_key = p.jurisdictionKey, label = p.label,
            jurisdiction_type = p.jurisdictionType, status = 'active',
            parent_jurisdiction_id = p.parentJurisdictionId and p.parentJurisdictionId:lower() or nil,
            owner_resource = owner, revision = 1, created_at = context.now }
        Repo.Insert(tx, 'jurisdiction', row)
        return J.Ok(M.Snapshot('jurisdiction', row))
    end)
end)

J.Export('UpdateJurisdiction', function(p, owner)
    if not M.Fields(p, { 'jurisdictionId', 'expectedRevision', 'label', 'status' }, true) or not J.Uuid(p.jurisdictionId)
        or not J.Integer(p.expectedRevision, 1, maximumRevision) or (p.label ~= nil and not J.Text(p.label, 100))
        or (p.status ~= nil and not statuses[p.status]) or (p.label == nil and p.status == nil) then
        return J.Err('invalid_input', 'Jurisdiction UUID, revision and a new label or status required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local actor = J.Principal(owner, 'justice.definition.manage', p, p.jurisdictionId, true)
    if not actor.ok then return actor end
    return M.Run('jurisdiction.updated', p, owner, actor.value, function(tx, context)
        local row = Repo.Get(tx.one, 'jurisdiction', p.jurisdictionId:lower(), owner, true)
        if not row then return J.Err('not_found', 'Jurisdiction not found.') end
        if row.revision ~= p.expectedRevision then return J.Err('revision_conflict', 'Jurisdiction revision changed.') end
        local changes, nulls = {}, {}
        if p.label and p.label ~= row.label then changes.label = p.label end
        if p.status and p.status ~= row.status then
            changes.status = p.status
            if p.status == 'retired' then changes.retired_at = context.now else nulls[1] = 'retired_at' end
        end
        if next(changes) == nil then return J.Err('no_change', 'The jurisdiction already has these values.') end
        changes.revision = row.revision + 1
        Repo.Update(tx, 'jurisdiction', row.jurisdiction_id, changes, nulls)
        for key, value in pairs(changes) do row[key] = value end
        if nulls[1] then row.retired_at = nil end
        return J.Ok(M.Snapshot('jurisdiction', row))
    end)
end)

local function StatuteFields(p, revise)
    return (p.title == nil and revise or J.Text(p.title, 180))
        and (p.description == nil or J.Text(p.description, 4000))
        and (p.category == nil and revise or J.Token(p.category, 32))
        and (p.severityClass == nil and revise or severities[p.severityClass] == true)
        and (p.effectiveFrom == nil or J.Integer(p.effectiveFrom, 0, maximumTime))
        and (p.effectiveUntil == nil or J.Integer(p.effectiveUntil, 1, maximumTime))
        and Range(p.recommendedFine, 1000000000) and Range(p.recommendedCustodySeconds, 31536000)
        and (p.status == nil or statuses[p.status] == true)
end

J.Export('RegisterStatute', function(p, owner)
    if not M.Fields(p, { 'jurisdictionId', 'statuteKey', 'title', 'description', 'category', 'severityClass',
            'effectiveFrom', 'effectiveUntil', 'recommendedFine', 'recommendedCustodySeconds' }, true)
        or not J.Uuid(p.jurisdictionId) or not J.Token(p.statuteKey, 160) or not StatuteFields(p, false)
        or (p.effectiveFrom and p.effectiveUntil and p.effectiveUntil <= p.effectiveFrom) then
        return J.Err('invalid_input', 'Jurisdiction, namespaced key, title, category, severity class and valid optional terms required.')
    end
    local actor = J.Principal(owner, 'justice.definition.manage', p, p.jurisdictionId, true)
    if not actor.ok then return actor end
    return M.Run('statute.registered', p, owner, actor.value, function(tx, context)
        local jurisdiction = Repo.Get(tx.one, 'jurisdiction', p.jurisdictionId:lower(), owner, true)
        if not jurisdiction or jurisdiction.status ~= 'active' then
            return J.Err('jurisdiction_unavailable', 'Active owned jurisdiction required.')
        end
        -- Keys are namespaced under their jurisdiction, e.g. bcc-law:new_hanover.theft.grand.
        if p.statuteKey:sub(1, #jurisdiction.jurisdiction_key + 1) ~= jurisdiction.jurisdiction_key .. '.' then
            return J.Err('invalid_input', 'Statute keys start with their jurisdiction key and a dot.')
        end
        if Repo.KeyExists(tx.one, 'statute', 'statute_key', p.statuteKey) then
            return J.Err('key_conflict', 'Statute key already exists; reuse its original request ID.')
        end
        local row = { statute_id = J.NewUuid(), jurisdiction_id = jurisdiction.jurisdiction_id, statute_key = p.statuteKey,
            title = p.title, description = p.description, category = p.category, severity_class = p.severityClass,
            status = 'active', definition_version = 1, effective_from = p.effectiveFrom, effective_until = p.effectiveUntil,
            metadata_json = Metadata(p), owner_resource = owner, revision = 1, created_at = context.now }
        Repo.Insert(tx, 'statute', row)
        return J.Ok(M.Snapshot('statute', row))
    end)
end)

J.Export('ReviseStatute', function(p, owner)
    if not M.Fields(p, { 'statuteId', 'expectedRevision', 'title', 'description', 'category', 'severityClass',
            'effectiveFrom', 'effectiveUntil', 'recommendedFine', 'recommendedCustodySeconds', 'status' }, true)
        or not J.Uuid(p.statuteId) or not J.Integer(p.expectedRevision, 1, maximumRevision) or not StatuteFields(p, true) then
        return J.Err('invalid_input', 'Statute UUID, revision and valid changes required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local existing = Repo.Get(DB.one, 'statute', p.statuteId:lower(), owner)
    local actor = J.Principal(owner, 'justice.definition.manage', p, existing and existing.jurisdiction_id or nil, true)
    if not actor.ok then return actor end
    return M.Run('statute.revised', p, owner, actor.value, function(tx)
        local row = Repo.Get(tx.one, 'statute', p.statuteId:lower(), owner, true)
        if not row then return J.Err('not_found', 'Statute not found.') end
        if row.revision ~= p.expectedRevision then return J.Err('revision_conflict', 'Statute revision changed.') end
        local changes, content = {}, false
        local map = { title = 'title', description = 'description', category = 'category', severityClass = 'severity_class',
            effectiveFrom = 'effective_from', effectiveUntil = 'effective_until' }
        for field, column in pairs(map) do
            if p[field] ~= nil and p[field] ~= row[column] then changes[column] = p[field]; content = true end
        end
        if p.recommendedFine ~= nil or p.recommendedCustodySeconds ~= nil then
            local metadata = Metadata(p, row.metadata_json)
            if json.encode(metadata) ~= json.encode(row.metadata_json) then changes.metadata_json = metadata; content = true end
        end
        local from, untilAt = changes.effective_from or row.effective_from, changes.effective_until or row.effective_until
        if from and untilAt and untilAt <= from then return J.Err('invalid_input', 'effectiveUntil must follow effectiveFrom.') end
        if p.status and p.status ~= row.status then
            if p.status == 'active' then
                local jurisdiction = Repo.Get(tx.one, 'jurisdiction', row.jurisdiction_id, owner, true)
                if not jurisdiction or jurisdiction.status ~= 'active' then
                    return J.Err('jurisdiction_unavailable', 'An active jurisdiction is required for an active statute.')
                end
            end
            changes.status = p.status
        end
        if next(changes) == nil then return J.Err('no_change', 'The statute already has these values.') end
        if content then changes.definition_version = row.definition_version + 1 end
        changes.revision = row.revision + 1
        Repo.Update(tx, 'statute', row.statute_id, changes)
        for key, value in pairs(changes) do row[key] = value end
        return J.Ok(M.Snapshot('statute', row))
    end)
end)

local function Read(kind, keyColumn, idField, keyField, p, owner)
    if not M.Fields(p, { idField, keyField }, false) or (p[idField] == nil) == (p[keyField] == nil)
        or (p[idField] ~= nil and not J.Uuid(p[idField])) or (p[keyField] ~= nil and not J.Token(p[keyField], 160)) then
        return J.Err('invalid_input', 'Exactly one of ' .. idField .. ' or ' .. keyField .. ' required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local row = p[idField] and Repo.Get(DB.one, kind, p[idField]:lower(), owner) or Repo.GetByKey(DB.one, kind, keyColumn, p[keyField], owner)
    local actor = J.Principal(owner, 'justice.definition.view', p, row and (row.jurisdiction_id) or nil, true)
    if not actor.ok then return actor end
    if not row then return J.Err('not_found', 'Definition not found.') end
    return J.Ok(M.Snapshot(kind, row))
end
J.Export('GetJurisdiction', function(p, owner) return Read('jurisdiction', 'jurisdiction_key', 'jurisdictionId', 'jurisdictionKey', p, owner) end)
J.Export('GetStatute', function(p, owner) return Read('statute', 'statute_key', 'statuteId', 'statuteKey', p, owner) end)

J.Export('ListJurisdictions', function(p, owner)
    local page = M.Fields(p, { 'parentJurisdictionId', 'status', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or (p.parentJurisdictionId ~= nil and not J.Uuid(p.parentJurisdictionId)) or (p.status ~= nil and not statuses[p.status]) then
        return J.Err('invalid_input', 'Optional parent UUID, status and bounded page required.')
    end
    local actor = J.Principal(owner, 'justice.definition.view', p, nil, true)
    if not actor.ok then return actor end
    page.filters = { parent_jurisdiction_id = p.parentJurisdictionId and p.parentJurisdictionId:lower() or nil, status = p.status }
    local items, more = Repo.Page(DB.query, 'jurisdiction', owner, page)
    return A.Page('jurisdiction', items, more)
end)
J.Export('ListStatutes', function(p, owner)
    local page = M.Fields(p, { 'jurisdictionId', 'status', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or not J.Uuid(p.jurisdictionId) or (p.status ~= nil and not statuses[p.status]) then
        return J.Err('invalid_input', 'Jurisdiction UUID, optional status and bounded page required.')
    end
    local actor = J.Principal(owner, 'justice.definition.view', p, p.jurisdictionId, true)
    if not actor.ok then return actor end
    page.filters = { jurisdiction_id = p.jurisdictionId:lower(), status = p.status }
    local items, more = Repo.Page(DB.query, 'statute', owner, page)
    return A.Page('statute', items, more)
end)
