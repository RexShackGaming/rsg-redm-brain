-- Citations (master plan: Citations; workflow "Citation and fine").
-- "A citation is an issued legal notice. It may reference an immediate warning or
-- produce a Contracts obligation for a payable fine." Justice never moves money.
local J, Repo, M, A = Justice, Justice.Repo, Justice.Mutation, Justice.Access
local maximumRevision = 9007199254740989

function J.CitationConfigValid()
    local c = JusticeConfig.Citations
    return type(c) == 'table' and type(c.Currency) == 'string' and c.Currency:match('^[a-z][a-z0-9_]*$') ~= nil and #c.Currency <= 32
        and type(c.TypeKey) == 'string' and c.TypeKey:match('^[a-z][a-z0-9_]*$') ~= nil and #c.TypeKey <= 48
        and J.Integer(c.MaximumAmount, 1, 1000000000000) and J.Integer(c.MaximumDueSeconds, 60, 31536000)
end
local function Snapshot(row) return M.Snapshot('citation', row) end
J.CitationSnapshot = Snapshot

J.Export('IssueCitation', function(p, owner)
    if not J.CitationConfigValid() then return J.Err('invalid_config', 'Citation configuration unavailable.') end
    local c = JusticeConfig.Citations
    if not M.Fields(p, { 'caseId', 'expectedCaseRevision', 'subjectCharacterId', 'statuteId', 'basisSummary', 'amount', 'dueInSeconds' }, true)
        or not J.Uuid(p.caseId) or not J.Uuid(p.subjectCharacterId) or not J.Uuid(p.statuteId)
        or not J.Integer(p.expectedCaseRevision, 1, maximumRevision) or not J.Text(p.basisSummary, 2000)
        or (p.amount == nil) ~= (p.dueInSeconds == nil)
        or (p.amount ~= nil and (not J.Integer(p.amount, 1, c.MaximumAmount) or not J.Integer(p.dueInSeconds, 60, c.MaximumDueSeconds))) then
        return J.Err('invalid_input', 'Case revision, subject, statute and basis required; a fine adds amount and dueInSeconds.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.citation.issue', p.caseId:lower(), { payable = p.amount ~= nil }, true)
    if not access.ok then return access end
    local subject = p.subjectCharacterId:lower()
    local identity = A.Character(subject)
    return M.Run('citation.issued', p, owner, access.value.actor, function(tx, context)
        if not identity.ok then return identity end
        local case = A.LockCase(tx, p.caseId:lower(), owner, access.value.actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if not A.Editable(case) then return J.Err('case_closed', 'Citations need an open, filed or pending-hearing case.') end
        if case.revision ~= p.expectedCaseRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        local statute = Repo.Get(tx.one, 'statute', p.statuteId:lower(), owner, true)
        if not statute or statute.jurisdiction_id ~= case.jurisdiction_id or not J.StatuteInForce(statute, context.now) then
            return J.Err('statute_mismatch', 'A statute in force in the case jurisdiction is required.')
        end
        local row = { citation_id = J.NewUuid(), jurisdiction_id = case.jurisdiction_id, case_id = case.case_id,
            subject_character_id = subject, statute_id = statute.statute_id,
            -- A payable citation is 'pending' until Contracts confirms the obligation.
            status = p.amount and 'pending' or 'issued', issued_by_character_id = access.value.actor.characterId,
            issued_at = context.now, amount = p.amount, currency = p.amount and c.Currency or nil,
            type_key = p.amount and c.TypeKey or nil, due_in_seconds = p.dueInSeconds, basis_summary = p.basisSummary, revision = 1 }
        Repo.Insert(tx, 'citation', row)
        if p.amount then Repo.Wake(tx, 'citation', row.citation_id, 0) end
        return J.Ok(Snapshot(row))
    end)
end)

J.Export('GetCitation', function(p, owner)
    if not M.Fields(p, { 'citationId' }, false) or not J.Uuid(p.citationId) then return J.Err('invalid_input', 'Citation UUID required.') end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local row = Repo.Get(DB.one, 'citation', p.citationId:lower(), owner)
    local access = A.CasePrincipal(p, owner, 'justice.citation.view', row and row.case_id, nil, false)
    if not access.ok then return access end
    return J.Ok(Snapshot(row))
end)
J.Export('ListCitations', function(p, owner)
    local page = M.Fields(p, { 'caseId', 'subjectCharacterId', 'jurisdictionId', 'status', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or (p.caseId ~= nil and not J.Uuid(p.caseId)) or (p.subjectCharacterId ~= nil and not J.Uuid(p.subjectCharacterId))
        or (p.jurisdictionId ~= nil and not J.Uuid(p.jurisdictionId)) or (p.status ~= nil and not J.Token(p.status, 16))
        or (p.caseId == nil and (p.subjectCharacterId == nil or p.jurisdictionId == nil)) then
        return J.Err('invalid_input', 'caseId, or subjectCharacterId with jurisdictionId, and a bounded page required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local actor
    if p.caseId then
        local access = A.CasePrincipal(p, owner, 'justice.citation.view', p.caseId:lower(), nil, false)
        if not access.ok then return access end
        actor = access.value.actor
        page.filters = { case_id = access.value.case.case_id }
    else
        local principal = J.Principal(owner, 'justice.citation.view', p, p.jurisdictionId, false, { subjectSearch = true })
        if not principal.ok then return principal end
        actor = principal.value
        page.filters = { jurisdiction_id = p.jurisdictionId:lower() }
    end
    if p.subjectCharacterId then
        page.filters.subject_character_id = p.subjectCharacterId:lower()
        A.AuditSearch(owner, actor, 'justice.citation.view', p.subjectCharacterId:lower())
    end
    page.filters.status = p.status
    page.actor = actor
    local items, more = Repo.Page(DB.query, 'citation', owner, page)
    if not J.Current(actor) then return J.Err('session_expired', 'Actor changed.') end
    return A.Page('citation', items, more)
end)
