-- Charges and warrants (master plan: Charges, Warrants; Charge and Warrant operations).
local J, Repo, M, A = Justice, Justice.Repo, Justice.Mutation, Justice.Access
local maximumRevision = 9007199254740989
local warrantTypes = { arrest = true, search = true, seizure = true, summons = true }
J.WarrantTypes = warrantTypes

local function StatuteSnapshot(statute)
    return { statuteId = statute.statute_id, statuteKey = statute.statute_key, title = statute.title,
        description = statute.description, category = statute.category, severityClass = statute.severity_class,
        definitionVersion = statute.definition_version, revision = statute.revision, metadata = statute.metadata_json }
end
local function ChildSnapshot(kind, row, case) return M.Snapshot(kind, row, { jurisdictionId = case.jurisdiction_id }) end
-- Reads derive expiry exactly at the deadline; the sweep persists it as a fact.
local function WarrantSnapshot(row, now)
    local snapshot = M.Snapshot('warrant', row)
    snapshot.storedStatus = row.status
    if row.status == 'active' and row.expires_at and row.expires_at <= now then snapshot.status = 'expired' end
    return snapshot
end
J.WarrantSnapshot = WarrantSnapshot

-- Charges ---------------------------------------------------------------------
J.Export('ProposeCharge', function(p, owner)
    if not M.Fields(p, { 'caseId', 'expectedCaseRevision', 'defendantCharacterId', 'statuteId', 'count' }, true)
        or not J.Uuid(p.caseId) or not J.Uuid(p.defendantCharacterId) or not J.Uuid(p.statuteId)
        or not J.Integer(p.expectedCaseRevision, 1, maximumRevision) or not J.Integer(p.count, 1, 100) then
        return J.Err('invalid_input', 'Case, defendant and statute UUIDs, case revision and a count of 1-100 required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.charge.propose', p.caseId:lower(), nil, true)
    if not access.ok then return access end
    local defendant = p.defendantCharacterId:lower()
    local identity = A.Character(defendant)
    return M.Run('charge.proposed', p, owner, access.value.actor, function(tx, context)
        if not identity.ok then return identity end
        local case = A.LockCase(tx, p.caseId:lower(), owner, access.value.actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if not A.Editable(case) then return J.Err('case_closed', 'Charges need an open, filed or pending-hearing case.') end
        if case.revision ~= p.expectedCaseRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        local statute = Repo.Get(tx.one, 'statute', p.statuteId:lower(), owner, true)
        if not statute or statute.jurisdiction_id ~= case.jurisdiction_id or not J.StatuteInForce(statute, context.now) then
            return J.Err('statute_mismatch', 'A statute in force in the case jurisdiction is required.')
        end
        local row = { charge_id = J.NewUuid(), case_id = case.case_id, defendant_character_id = defendant,
            statute_id = statute.statute_id, statute_snapshot_json = StatuteSnapshot(statute), count = p.count,
            status = 'proposed', proposed_by_character_id = access.value.actor.characterId, proposed_at = context.now, revision = 1 }
        Repo.Insert(tx, 'charge', row)
        return J.Ok(ChildSnapshot('charge', row, case))
    end)
end)

-- Shared lock order for record changes: receipt -> parent case -> record.
local function ChangeRecord(kind, idField, p, owner, action, fact, attributes, apply, extraFields)
    local fields = { idField, 'expectedRevision' }
    for _, field in ipairs(extraFields or {}) do fields[#fields + 1] = field end
    if not M.Fields(p, fields, true) or not J.Uuid(p[idField]) or not J.Integer(p.expectedRevision, 1, maximumRevision) then
        return J.Err('invalid_input', 'Record UUID, expected revision and valid fields required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local existing = Repo.Get(DB.one, kind, p[idField]:lower(), owner)
    local access = A.CasePrincipal(p, owner, action, existing and existing.case_id, attributes and existing and attributes(existing), true)
    if not access.ok then return access end
    return M.Run(fact, p, owner, access.value.actor, function(tx, context)
        local case = A.LockCase(tx, existing.case_id, owner, access.value.actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        local row = Repo.Get(tx.one, kind, existing[Repo.Specs[kind].id], owner, true)
        if row.revision ~= p.expectedRevision then return J.Err('revision_conflict', 'Record revision changed.') end
        context.case = case
        local changes, extra = apply(tx, row, case, context)
        if type(changes) == 'table' and changes.ok == false then return changes end
        changes.revision = row.revision + 1
        Repo.Update(tx, kind, row[Repo.Specs[kind].id], changes)
        for key, value in pairs(changes) do row[key] = value end
        if extra then return extra(row) end
        return J.Ok(kind == 'warrant' and WarrantSnapshot(row, context.now) or ChildSnapshot(kind, row, case))
    end)
end
J.ChangeRecord = ChangeRecord

J.Export('FileCharge', function(p, owner)
    return ChangeRecord('charge', 'chargeId', p, owner, 'justice.charge.file', 'charge.filed', nil, function(_, row, case, context)
        if row.status ~= 'proposed' then return J.Err('invalid_transition', 'Only a proposed charge can be filed.') end
        if not A.Editable(case) then return J.Err('case_closed', 'Filing needs an open, filed or pending-hearing case.') end
        return { status = 'filed', filed_by_character_id = context.actor.characterId, filed_at = context.now }
    end)
end)
J.Export('DisposeCharge', function(p, owner)
    if type(p) ~= 'table' or (p.disposition ~= 'withdrawn' and p.disposition ~= 'dismissed') then
        return J.Err('invalid_input', 'Disposition withdrawn or dismissed required; convictions come from rulings.')
    end
    return ChangeRecord('charge', 'chargeId', p, owner, 'justice.charge.dispose', 'charge.disposed', nil, function(_, row, _, context)
        local allowed = (row.status == 'proposed' and p.disposition == 'withdrawn')
            or (row.status == 'filed' and (p.disposition == 'withdrawn' or p.disposition == 'dismissed'))
        if not allowed then return J.Err('invalid_transition', 'Charge disposition is not allowed.') end
        return { status = p.disposition, disposition = p.disposition, disposed_by_character_id = context.actor.characterId,
            disposed_at = context.now }
    end, { 'disposition' })
end)
J.Export('AmendCharge', function(p, owner)
    if type(p) ~= 'table' or (p.statuteId ~= nil and not J.Uuid(p.statuteId)) or (p.count ~= nil and not J.Integer(p.count, 1, 100))
        or (p.statuteId == nil and p.count == nil) then
        return J.Err('invalid_input', 'A new statute or count is required.')
    end
    local created
    return ChangeRecord('charge', 'chargeId', p, owner, 'justice.charge.amend', 'charge.amended', nil, function(tx, row, case, context)
        if row.status ~= 'proposed' and row.status ~= 'filed' then return J.Err('invalid_transition', 'Only proposed or filed charges can be amended.') end
        if not A.Editable(case) then return J.Err('case_closed', 'Amendment needs an open, filed or pending-hearing case.') end
        local snapshot = row.statute_snapshot_json
        local statuteId = row.statute_id
        if p.statuteId then
            local statute = Repo.Get(tx.one, 'statute', p.statuteId:lower(), owner, true)
            if not statute or statute.jurisdiction_id ~= case.jurisdiction_id or not J.StatuteInForce(statute, context.now) then
                return J.Err('statute_mismatch', 'A statute in force in the case jurisdiction is required.')
            end
            snapshot, statuteId = StatuteSnapshot(statute), statute.statute_id
        end
        local count = p.count or row.count
        if statuteId == row.statute_id and snapshot.revision == row.statute_snapshot_json.revision and count == row.count then
            return J.Err('no_change', 'The amendment changes nothing.')
        end
        created = { charge_id = J.NewUuid(), case_id = case.case_id, defendant_character_id = row.defendant_character_id,
            statute_id = statuteId, statute_snapshot_json = snapshot, count = count, status = row.status,
            proposed_by_character_id = context.actor.characterId, proposed_at = context.now,
            amends_charge_id = row.charge_id, revision = 1 }
        if row.status == 'filed' then created.filed_by_character_id, created.filed_at = context.actor.characterId, context.now end
        Repo.Insert(tx, 'charge', created)
        return { status = 'amended', disposition = 'amended', amended_by_charge_id = created.charge_id,
            disposed_by_character_id = context.actor.characterId, disposed_at = context.now },
            function(old)
                -- The new charge is the operation's record; the superseded one gets its own fact.
                M.Fact(tx, ChildSnapshot('charge', old, case), 'charge.disposed', context)
                return J.Ok(ChildSnapshot('charge', created, case))
            end
    end, { 'statuteId', 'count' })
end)
J.Export('ListCharges', function(p, owner)
    local page = M.Fields(p, { 'caseId', 'defendantCharacterId', 'jurisdictionId', 'status', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or (p.caseId ~= nil and not J.Uuid(p.caseId)) or (p.defendantCharacterId ~= nil and not J.Uuid(p.defendantCharacterId))
        or (p.jurisdictionId ~= nil and not J.Uuid(p.jurisdictionId)) or (p.status ~= nil and not J.Token(p.status, 16))
        or (p.caseId == nil and (p.defendantCharacterId == nil or p.jurisdictionId == nil)) then
        return J.Err('invalid_input', 'caseId, or defendantCharacterId with jurisdictionId, and a bounded page required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local actor, jurisdictionId
    if p.caseId then
        local access = A.CasePrincipal(p, owner, 'justice.charge.view', p.caseId:lower(), nil, false)
        if not access.ok then return access end
        actor, jurisdictionId = access.value.actor, access.value.case.jurisdiction_id
        page.filters = { case_id = access.value.case.case_id }
    else
        local principal = J.Principal(owner, 'justice.charge.view', p, p.jurisdictionId, false, { subjectSearch = true })
        if not principal.ok then return principal end
        actor, jurisdictionId = principal.value, p.jurisdictionId:lower()
        page.filters = { ['case.jurisdiction_id'] = jurisdictionId }
    end
    if p.defendantCharacterId then
        page.filters.defendant_character_id = p.defendantCharacterId:lower()
        A.AuditSearch(owner, actor, 'justice.charge.view', p.defendantCharacterId:lower())
    end
    page.filters.status = p.status
    page.actor = actor
    local items, more = Repo.Page(DB.query, 'charge', owner, page)
    if not J.Current(actor) then return J.Err('session_expired', 'Actor changed.') end
    return A.Page('charge', items, more, function() return { jurisdictionId = jurisdictionId } end)
end)

-- Warrants --------------------------------------------------------------------
J.Export('CreateWarrantDraft', function(p, owner)
    if not M.Fields(p, { 'caseId', 'expectedCaseRevision', 'subjectCharacterId', 'warrantType', 'basisSummary', 'validForSeconds' }, true)
        or not J.Uuid(p.caseId) or not J.Uuid(p.subjectCharacterId) or not warrantTypes[p.warrantType or '']
        or not J.Integer(p.expectedCaseRevision, 1, maximumRevision) or not J.Text(p.basisSummary, 2000)
        or not J.Integer(p.validForSeconds, 60, 2592000) then
        return J.Err('invalid_input', 'Case revision, subject, warrant type, basis and 60-2592000 seconds required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.warrant.draft', p.caseId:lower(), { warrantType = p.warrantType }, true)
    if not access.ok then return access end
    local subject = p.subjectCharacterId:lower()
    local identity = A.Character(subject)
    return M.Run('warrant.drafted', p, owner, access.value.actor, function(tx, context)
        if not identity.ok then return identity end
        local case = A.LockCase(tx, p.caseId:lower(), owner, access.value.actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if not A.Editable(case) then return J.Err('case_closed', 'Drafting needs an open, filed or pending-hearing case.') end
        if case.revision ~= p.expectedCaseRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        local row = { warrant_id = J.NewUuid(), jurisdiction_id = case.jurisdiction_id, case_id = case.case_id,
            subject_character_id = subject, warrant_type = p.warrantType, status = 'draft', basis_summary = p.basisSummary,
            valid_for_seconds = p.validForSeconds, created_by_character_id = access.value.actor.characterId,
            created_at = context.now, revision = 1 }
        Repo.Insert(tx, 'warrant', row)
        return J.Ok(WarrantSnapshot(row, context.now))
    end)
end)
local function WarrantAttributes(row) return { warrantType = row.warrant_type } end
local function WarrantChange(p, owner, action, fact, column)
    -- Identity is read before any Justice lock is taken.
    local subject = J.Ok(true)
    if fact == 'warrant.issued' and type(p) == 'table' and J.Uuid(p.warrantId) and J.Ready() then
        local existing = Repo.Get(DB.one, 'warrant', p.warrantId:lower(), owner)
        if existing then subject = A.Character(existing.subject_character_id) end
    end
    return ChangeRecord('warrant', 'warrantId', p, owner, action, fact, WarrantAttributes, function(_, row, case, context)
        if fact == 'warrant.issued' then
            if row.status ~= 'draft' then return J.Err('invalid_transition', 'Only a draft warrant can be issued.') end
            if not A.Editable(case) then return J.Err('case_closed', 'Issuance needs an open, filed or pending-hearing case.') end
            if not subject.ok then return subject end
            return { status = 'active', issued_by_character_id = context.actor.characterId, issued_at = context.now,
                expires_at = context.now + row.valid_for_seconds * 1000 }
        end
        if row.status ~= 'active' then return J.Err('invalid_transition', 'An active warrant is required.') end
        if row.expires_at <= context.now then return J.Err('warrant_expired', 'The warrant has expired.') end
        local changes = { status = ({ ['warrant.served'] = 'served', ['warrant.recalled'] = 'recalled', ['warrant.quashed'] = 'quashed' })[fact],
            closed_by_character_id = context.actor.characterId }
        changes[column] = context.now
        return changes
    end)
end
J.Export('IssueWarrant', function(p, owner) return WarrantChange(p, owner, 'justice.warrant.issue', 'warrant.issued') end)
J.Export('ServeWarrant', function(p, owner) return WarrantChange(p, owner, 'justice.warrant.serve', 'warrant.served', 'served_at') end)
J.Export('RecallWarrant', function(p, owner) return WarrantChange(p, owner, 'justice.warrant.recall', 'warrant.recalled', 'recalled_at') end)
J.Export('QuashWarrant', function(p, owner) return WarrantChange(p, owner, 'justice.warrant.quash', 'warrant.quashed', 'quashed_at') end)

J.Export('GetWarrant', function(p, owner)
    if not M.Fields(p, { 'warrantId' }, false) or not J.Uuid(p.warrantId) then return J.Err('invalid_input', 'Warrant UUID required.') end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local row = Repo.Get(DB.one, 'warrant', p.warrantId:lower(), owner)
    local access = A.CasePrincipal(p, owner, 'justice.warrant.view', row and row.case_id, row and WarrantAttributes(row), false)
    if not access.ok then return access end
    local now = Repo.Now(DB.value)
    if not J.Current(access.value.actor) then return J.Err('session_expired', 'Actor changed.') end
    return J.Ok(WarrantSnapshot(row, now))
end)
J.Export('ListActiveWarrants', function(p, owner)
    local page = M.Fields(p, { 'jurisdictionId', 'caseId', 'subjectCharacterId', 'warrantType', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or (p.jurisdictionId ~= nil and not J.Uuid(p.jurisdictionId)) or (p.caseId ~= nil and not J.Uuid(p.caseId))
        or (p.subjectCharacterId ~= nil and not J.Uuid(p.subjectCharacterId)) or (p.warrantType ~= nil and not warrantTypes[p.warrantType])
        or (p.jurisdictionId == nil and p.caseId == nil) then
        return J.Err('invalid_input', 'jurisdictionId or caseId, optional subject/type filters and a bounded page required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local actor
    page.filters = {}
    if p.caseId then
        local access = A.CasePrincipal(p, owner, 'justice.warrant.view', p.caseId:lower(), nil, false)
        if not access.ok then return access end
        if p.jurisdictionId and p.jurisdictionId:lower() ~= access.value.case.jurisdiction_id then
            return J.Err('jurisdiction_mismatch', 'Case belongs to a different jurisdiction.')
        end
        actor = access.value.actor
        page.filters.case_id = access.value.case.case_id
    else
        local principal = J.Principal(owner, 'justice.warrant.view', p, p.jurisdictionId, false,
            p.subjectCharacterId and { subjectSearch = true } or nil)
        if not principal.ok then return principal end
        actor = principal.value
        page.filters.jurisdiction_id = p.jurisdictionId:lower()
    end
    if p.subjectCharacterId then
        page.filters.subject_character_id = p.subjectCharacterId:lower()
        A.AuditSearch(owner, actor, 'justice.warrant.view', p.subjectCharacterId:lower())
    end
    page.filters.warrant_type = p.warrantType
    page.statuses = { 'active' }
    local now = Repo.Now(DB.value)
    page.unexpiredAt = now
    page.actor = actor
    local items, more = Repo.Page(DB.query, 'warrant', owner, page)
    if not J.Current(actor) then return J.Err('session_expired', 'Actor changed.') end
    local list = {}
    for index, row in ipairs(items) do list[index] = WarrantSnapshot(row, now) end
    return J.Ok({ items = list, nextCursor = more and items[#items].warrant_id or nil })
end)

-- Persist expiry as a legal fact once (reads already derive it at the deadline).
function J.SweepWarrants()
    if not J.Ready() then return 0 end
    local generation, count = J.Generation(), 0
    for _, due in ipairs(Repo.DueWarrants(Repo.Now(DB.value), JusticeConfig.OutboxBatchSize)) do
        if not J.Ready() or generation ~= J.Generation() then break end
        local request = { requestId = 'justice:warrant:expire:' .. due.warrant_id, reasonCode = 'justice.warrant.expired', warrantId = due.warrant_id }
        local result = M.Run('warrant.expired', request, 'feather-justice', { generation = generation, system = true }, function(tx, context)
            local found = Repo.Get(tx.one, 'warrant', due.warrant_id, due.opened_by_resource)
            if not found then return J.Err('not_found', 'Warrant unavailable.') end
            Repo.Get(tx.one, 'case', found.case_id, due.opened_by_resource, true)
            local row = Repo.Get(tx.one, 'warrant', due.warrant_id, due.opened_by_resource, true)
            if row.status ~= 'active' or row.expires_at > context.now then return J.Err('invalid_transition', 'Warrant not due.') end
            local changes = { status = 'expired', revision = row.revision + 1 }
            Repo.Update(tx, 'warrant', row.warrant_id, changes)
            for key, value in pairs(changes) do row[key] = value end
            return J.Ok(WarrantSnapshot(row, context.now))
        end)
        if result.ok then count = count + 1 end
    end
    return count
end
