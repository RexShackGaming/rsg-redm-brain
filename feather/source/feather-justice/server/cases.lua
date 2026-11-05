-- Cases, parties, sealing and expungement (master plan: Cases, Case parties,
-- Sealing and expungement; Case and Evidence/record-access operations).
local J, Repo, M, A = Justice, Justice.Repo, Justice.Mutation, Justice.Access
local maximumRevision = 9007199254740989
-- adjudicated is entered only through a verdict ruling; sealed only through SealCase.
local transitions = { draft = { open = true, dismissed = true }, open = { filed = true, dismissed = true },
    filed = { pending_hearing = true, closed = true, dismissed = true },
    pending_hearing = { filed = true, dismissed = true }, adjudicated = { closed = true } }
local preparing = { draft = true, open = true, filed = true, pending_hearing = true }
local partyTypes = { character = true, organization = true }
local roles = { suspect = true, defendant = true, victim = true, witness = true, reporting_officer = true,
    investigating_officer = true, prosecutor = true, defense_counsel = true, judge = true }
local organizationRoles = { suspect = true, defendant = true, victim = true, witness = true }
J.CaseTransitions = transitions

local function CaseTypeAllowed(value)
    for _, allowed in ipairs(JusticeConfig.CaseTypes) do if allowed == value then return true end end
    return false
end
local function CaseSnapshot(row) return M.Snapshot('case', row) end
J.CaseSnapshot = CaseSnapshot

J.Export('OpenCase', function(p, owner)
    if not M.Fields(p, { 'jurisdictionId', 'caseType', 'title', 'summary', 'status' }, true) or not J.Uuid(p.jurisdictionId)
        or not CaseTypeAllowed(p.caseType) or not J.Text(p.title, 180) or not J.Text(p.summary, 4000)
        or (p.status ~= nil and p.status ~= 'draft' and p.status ~= 'open') then
        return J.Err('invalid_input', 'Jurisdiction UUID, configured case type, title, summary and optional draft/open status required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local actor = J.Principal(owner, 'justice.case.open', p, p.jurisdictionId, false, { caseType = p.caseType })
    if not actor.ok then return actor end
    return M.Run('case.opened', p, owner, actor.value, function(tx, context)
        local jurisdiction = Repo.Get(tx.one, 'jurisdiction', p.jurisdictionId:lower(), owner, true)
        if not jurisdiction or jurisdiction.status ~= 'active' then
            return J.Err('jurisdiction_unavailable', 'Active owned jurisdiction required.')
        end
        local row = { case_id = J.NewUuid(), jurisdiction_id = jurisdiction.jurisdiction_id, case_type = p.caseType,
            status = p.status or 'open', title = p.title, summary = p.summary,
            opened_by_character_id = actor.value.characterId, opened_by_resource = owner, opened_at = context.now, revision = 1 }
        Repo.Insert(tx, 'case', row)
        return J.Ok(CaseSnapshot(row))
    end)
end)

local function EditCase(p, owner, transition)
    local fields = transition and { 'caseId', 'expectedRevision', 'status' } or { 'caseId', 'expectedRevision', 'summary', 'title' }
    if not M.Fields(p, fields, true) or not J.Uuid(p.caseId) or not J.Integer(p.expectedRevision, 1, maximumRevision)
        or (transition and type(p.status) ~= 'string')
        or (not transition and (not J.Text(p.summary, 4000) or (p.title ~= nil and not J.Text(p.title, 180)))) then
        return J.Err('invalid_input', 'Case UUID, revision and a valid edit required.')
    end
    local access = A.CasePrincipal(p, owner, transition and 'justice.case.transition' or 'justice.case.update',
        p.caseId:lower(), transition and { status = p.status } or nil, true)
    if not access.ok then return access end
    return M.Run(transition and 'case.transitioned' or 'case.updated', p, owner, access.value.actor, function(tx, context)
        local case = A.LockCase(tx, p.caseId:lower(), owner, access.value.actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if case.revision ~= p.expectedRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        local changes = { revision = case.revision + 1 }
        if transition then
            if not (transitions[case.status] and transitions[case.status][p.status]) then
                return J.Err('invalid_transition', 'Case transition is not allowed.')
            end
            changes.status = p.status
            if p.status == 'closed' or p.status == 'dismissed' then changes.closed_at = context.now end
        else
            if not preparing[case.status] then return J.Err('case_closed', 'Only draft, open, filed or pending cases can be edited.') end
            changes.summary = p.summary
            if p.title then changes.title = p.title end
        end
        Repo.Update(tx, 'case', case.case_id, changes)
        for key, value in pairs(changes) do case[key] = value end
        return J.Ok(CaseSnapshot(case))
    end)
end
J.Export('UpdateCaseSummary', function(p, owner) return EditCase(p, owner, false) end)
J.Export('TransitionCase', function(p, owner) return EditCase(p, owner, true) end)

local relatedKinds = { 'warrant', 'custody', 'ruling', 'sentence' }
J.Export('GetCase', function(p, owner)
    if not M.Fields(p, { 'caseId', 'includeRelated' }, false) or not J.Uuid(p.caseId)
        or (p.includeRelated ~= nil and type(p.includeRelated) ~= 'boolean') then
        return J.Err('invalid_input', 'Case UUID required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.case.view', p.caseId:lower(), nil, false)
    if not access.ok then return access end
    local snapshot = CaseSnapshot(access.value.case)
    if p.includeRelated then
        -- Bounded case file index: up to 25 records per kind, oldest first, with a truncation flag.
        snapshot.related = {}
        for _, kind in ipairs(relatedKinds) do
            local rows = Repo.CaseChildren(DB.query, kind, access.value.case.case_id, false, 26)
            local list = {}
            for index = 1, math.min(#rows, 25) do list[index] = M.Snapshot(kind, rows[index], { jurisdictionId = access.value.case.jurisdiction_id }) end
            snapshot.related[kind] = { items = list, truncated = #rows > 25 }
        end
    end
    if not J.Current(access.value.actor) then return J.Err('session_expired', 'Actor changed.') end
    return J.Ok(snapshot)
end)

J.Export('ListCases', function(p, owner)
    local page = M.Fields(p, { 'jurisdictionId', 'status', 'caseType', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or not J.Uuid(p.jurisdictionId) or (p.status ~= nil and not J.Token(p.status, 24))
        or (p.caseType ~= nil and not J.Token(p.caseType, 32)) then
        return J.Err('invalid_input', 'Jurisdiction UUID, optional filters and bounded page required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local actor = J.Principal(owner, 'justice.case.view', p, p.jurisdictionId)
    if not actor.ok then return actor end
    page.filters = { jurisdiction_id = p.jurisdictionId:lower(), status = p.status, case_type = p.caseType }
    page.actor = actor.value
    local items, more = Repo.Page(DB.query, 'case', owner, page)
    if not J.Current(actor.value) then return J.Err('session_expired', 'Actor changed.') end
    return A.Page('case', items, more)
end)

-- Parties ---------------------------------------------------------------------
J.Export('AddCaseParty', function(p, owner)
    if not M.Fields(p, { 'caseId', 'expectedCaseRevision', 'partyType', 'partyIdReference', 'partyRole' }, true)
        or not J.Uuid(p.caseId) or not J.Integer(p.expectedCaseRevision, 1, maximumRevision)
        or not partyTypes[p.partyType or ''] or not J.Uuid(p.partyIdReference) or not roles[p.partyRole or '']
        or (p.partyType == 'organization' and not organizationRoles[p.partyRole]) then
        return J.Err('invalid_input', 'Case revision, party type, party UUID and a role allowed for that type required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.party.manage', p.caseId:lower(), { partyType = p.partyType, partyRole = p.partyRole }, true)
    if not access.ok then return access end
    local reference = p.partyIdReference:lower()
    local identity = p.partyType == 'character' and A.Character(reference) or A.Organization(reference)
    return M.Run('party.added', p, owner, access.value.actor, function(tx, context)
        if not identity.ok then return identity end
        local case = A.LockCase(tx, p.caseId:lower(), owner, access.value.actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if not preparing[case.status] then return J.Err('case_closed', 'Parties need a draft, open, filed or pending case.') end
        if case.revision ~= p.expectedCaseRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        if Repo.ActivePartySlot(tx.one, case.case_id, p.partyType, reference, p.partyRole) then
            return J.Err('party_exists', 'This party already has this role in the case.')
        end
        local row = { party_id = J.NewUuid(), case_id = case.case_id, party_type = p.partyType, party_id_reference = reference,
            party_role = p.partyRole, status = 'active', added_at = context.now,
            added_by_character_id = access.value.actor.characterId, revision = 1 }
        Repo.Insert(tx, 'party', row)
        return J.Ok(M.Snapshot('party', row, { jurisdictionId = case.jurisdiction_id }))
    end)
end)
J.Export('RemoveCaseParty', function(p, owner)
    if not M.Fields(p, { 'partyId', 'expectedRevision' }, true) or not J.Uuid(p.partyId)
        or not J.Integer(p.expectedRevision, 1, maximumRevision) then
        return J.Err('invalid_input', 'Party UUID and revision required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local existing = Repo.Get(DB.one, 'party', p.partyId:lower(), owner)
    local access = A.CasePrincipal(p, owner, 'justice.party.manage', existing and existing.case_id, nil, true)
    if not access.ok then return access end
    return M.Run('party.removed', p, owner, access.value.actor, function(tx, context)
        local case = A.LockCase(tx, existing.case_id, owner, access.value.actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if not preparing[case.status] then return J.Err('case_closed', 'Case is closed.') end
        local row = Repo.Get(tx.one, 'party', existing.party_id, owner, true)
        if row.revision ~= p.expectedRevision then return J.Err('revision_conflict', 'Party revision changed.') end
        if row.status ~= 'active' then return J.Err('invalid_transition', 'Party is already removed.') end
        local changes = { status = 'removed', removed_at = context.now, removed_by_character_id = access.value.actor.characterId,
            revision = row.revision + 1 }
        Repo.Update(tx, 'party', row.party_id, changes)
        for key, value in pairs(changes) do row[key] = value end
        return J.Ok(M.Snapshot('party', row, { jurisdictionId = case.jurisdiction_id }))
    end)
end)
J.Export('ListCaseParties', function(p, owner)
    local page = M.Fields(p, { 'caseId', 'includeRemoved', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or not J.Uuid(p.caseId) or (p.includeRemoved ~= nil and type(p.includeRemoved) ~= 'boolean') then
        return J.Err('invalid_input', 'Case UUID and bounded page required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.party.view', p.caseId:lower(), nil, false)
    if not access.ok then return access end
    page.filters = { case_id = access.value.case.case_id }
    page.statuses = not p.includeRemoved and { 'active' } or nil
    local items, more = Repo.Page(DB.query, 'party', owner, page)
    if not J.Current(access.value.actor) then return J.Err('session_expired', 'Actor changed.') end
    return A.Page('party', items, more, function() return { jurisdictionId = access.value.case.jurisdiction_id } end)
end)

-- Sealing and expungement ------------------------------------------------------
-- Anything still producing legal or financial effects keeps a case unsealable.
local function Blocker(tx, caseId, now)
    for _, row in ipairs(Repo.CaseChildren(tx.query, 'warrant', caseId, true)) do
        if row.status == 'active' and row.expires_at and row.expires_at > now then return 'warrant' end
    end
    for _, row in ipairs(Repo.CaseChildren(tx.query, 'custody', caseId, true)) do
        if row.status ~= 'released' then return 'custody' end
    end
    for _, row in ipairs(Repo.CaseChildren(tx.query, 'sentence', caseId, true)) do
        if row.status ~= 'completed' then return 'sentence' end
    end
    for _, row in ipairs(Repo.CaseChildren(tx.query, 'citation', caseId, true)) do
        if row.amount and row.status ~= 'settled' then return 'citation' end
    end
    return nil
end
-- Replaces narratives of a case and its records, including stored receipts (they
-- hold full snapshots). Structure, identities, snapshots and audit facts remain.
function J.RedactCase(tx, case, marker, context)
    local touched = { case.case_id }
    local function redact(kind, column, nested)
        for _, row in ipairs(Repo.CaseChildren(tx.query, kind, case.case_id, true)) do
            local changes, nulls = {}, nil
            if nested then
                local terms = row[column]
                if type(terms) == 'table' and terms[nested] and terms[nested] ~= marker then
                    terms[nested] = marker
                    changes[column] = terms
                end
            elseif kind == 'evidence' then
                -- Evidence descriptions are removed rather than replaced.
                if row[column] then nulls = { column } end
            elseif row[column] and row[column] ~= marker then
                changes[column] = marker
            end
            if next(changes) or nulls then
                changes.revision = row.revision + 1
                Repo.Update(tx, kind, row[Repo.Specs[kind].id], changes, nulls)
                touched[#touched + 1] = row[Repo.Specs[kind].id]
            end
        end
    end
    redact('warrant', 'basis_summary')
    redact('citation', 'basis_summary')
    redact('ruling', 'summary')
    redact('sentence', 'terms_json', 'conditionsSummary')
    redact('evidence', 'description')
    for _, id in ipairs(touched) do Repo.RedactReceipts(tx, id) end
    local changes = { summary = marker }
    if marker == '[expunged]' then changes.title = marker end
    return changes
end
local function Visibility(p, owner, mode)
    if not M.Fields(p, { 'caseId', 'expectedRevision' }, true) or not J.Uuid(p.caseId)
        or not J.Integer(p.expectedRevision, 1, maximumRevision) then
        return J.Err('invalid_input', 'Case UUID and revision required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local existing = Repo.Get(DB.one, 'case', p.caseId:lower(), owner)
    local actor = J.Principal(owner, mode == 'expunge' and 'justice.record.expunge' or 'justice.record.seal', p,
        existing and existing.jurisdiction_id or nil)
    if not actor.ok then return actor end
    actor = actor.value
    if mode ~= 'seal' and not actor.viewSealed then return J.Err('not_found', 'Case unavailable.') end
    -- Only these three operations may write to a sealed case (and replay their receipts).
    actor.visibilityWrite = true
    local fact = ({ seal = 'record.sealed', unseal = 'record.unsealed', expunge = 'record.expunged' })[mode]
    return M.Run(fact, p, owner, actor, function(tx, context)
        local case = A.LockCase(tx, p.caseId:lower(), owner, actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if case.revision ~= p.expectedRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        local changes, nulls = { revision = case.revision + 1 }, {}
        if mode == 'seal' then
            if case.status ~= 'closed' and case.status ~= 'dismissed' then
                return J.Err('case_open', 'Only closed or dismissed cases can be sealed.')
            end
            local blocker = Blocker(tx, case.case_id, context.now)
            if blocker then return J.Err('seal_blocked', 'An active ' .. blocker .. ' still depends on this case.') end
            changes.status, changes.sealed_at, changes.sealed_from_status = 'sealed', context.now, case.status
        elseif mode == 'unseal' then
            if case.status ~= 'sealed' or case.expunged_at then
                return J.Err('invalid_transition', 'Only a sealed, not expunged, case can be unsealed.')
            end
            changes.status = case.sealed_from_status
            nulls = { 'sealed_at', 'sealed_from_status' }
        else
            if case.status ~= 'sealed' or case.expunged_at then return J.Err('invalid_transition', 'Seal the case before expunging it.') end
            for key, value in pairs(J.RedactCase(tx, case, '[expunged]', context)) do changes[key] = value end
            changes.expunged_at = context.now
        end
        Repo.Update(tx, 'case', case.case_id, changes, nulls)
        for key, value in pairs(changes) do case[key] = value end
        for _, column in ipairs(nulls) do case[column] = nil end
        return J.Ok(CaseSnapshot(case))
    end)
end
J.Export('SealCase', function(p, owner) return Visibility(p, owner, 'seal') end)
J.Export('UnsealCase', function(p, owner) return Visibility(p, owner, 'unseal') end)
J.Export('ExpungeRecord', function(p, owner) return Visibility(p, owner, 'expunge') end)
