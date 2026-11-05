-- Rulings and sentences (master plan: Rulings and sentences; Ruling and sentence
-- operations; workflows "Sentence and fine/restitution", "Sentence and jail",
-- "License suspension", "Forfeiture"). Other domains execute effects.
local J, Repo, M, A = Justice, Justice.Repo, Justice.Mutation, Justice.Access
local maximumRevision = 9007199254740989
local rulingTypes = { verdict = true, dismissal = true, order = true }
local findingsAllowed = { convicted = true, acquitted = true }
local timed = { custodial = true, probation = true }
local financial = { fine = true, restitution = true }
local effects = { license_suspension = true, forfeiture = true }
local targetTypes = { property = true, asset = true, item = true }
local outcomes = { served = true, vacated = true, commuted = true }

-- Rulings and judicial sentence changes need the case judge (configurable; team decision).
local function Judge(query, caseId, actor)
    if actor.system or actor.manageAll or not JusticeConfig.Rulings.RequireJudgeParticipant then return true end
    return Repo.IsJudge(query, caseId, actor.characterId)
end

-- Rulings ---------------------------------------------------------------------
J.Export('RecordRuling', function(p, owner)
    local maximum = JusticeConfig.Rulings.MaximumFindings
    if not M.Fields(p, { 'caseId', 'expectedCaseRevision', 'rulingType', 'summary', 'subjectCharacterId', 'findings', 'outcome' }, true)
        or not J.Uuid(p.caseId) or not J.Integer(p.expectedCaseRevision, 1, maximumRevision) or not rulingTypes[p.rulingType or '']
        or not J.Text(p.summary, 4000) or (p.subjectCharacterId ~= nil and not J.Uuid(p.subjectCharacterId))
        or (p.rulingType == 'verdict' and (p.subjectCharacterId == nil or type(p.findings) ~= 'table' or #p.findings < 1 or #p.findings > maximum))
        or (p.rulingType ~= 'verdict' and p.findings ~= nil)
        or (p.rulingType == 'order' and not J.Token(p.outcome, 64)) or (p.rulingType ~= 'order' and p.outcome ~= nil) then
        return J.Err('invalid_input', 'Case revision, ruling type, summary; verdicts need a subject and findings, orders an outcome.')
    end
    local seen, ordered = {}, {}
    for index, item in ipairs(p.findings or {}) do
        if type(item) ~= 'table' or not J.Fields(item, { chargeId = true, finding = true }) or not J.Uuid(item.chargeId)
            or not findingsAllowed[item.finding] or seen[item.chargeId:lower()] then
            return J.Err('invalid_input', 'Each finding needs a distinct charge UUID and convicted or acquitted.')
        end
        seen[item.chargeId:lower()] = item.finding
        ordered[index] = { chargeId = item.chargeId:lower(), finding = item.finding }
    end
    local access = A.CasePrincipal(p, owner, 'justice.ruling.record', p.caseId:lower(), { rulingType = p.rulingType }, true)
    if not access.ok then return access end
    local actor = access.value.actor
    return M.Run('ruling.recorded', p, owner, actor, function(tx, context)
        local case = A.LockCase(tx, p.caseId:lower(), owner, actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if case.revision ~= p.expectedCaseRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        if not Judge(tx.one, case.case_id, actor) then return J.Err('judge_required', 'Only the case judge may record a ruling.') end
        if p.rulingType ~= 'order' and case.status ~= 'filed' and case.status ~= 'pending_hearing' then
            return J.Err('invalid_transition', 'Verdicts and dismissals need a filed or pending-hearing case.')
        end
        if p.rulingType == 'order' and (A.Closed(case) or case.status == 'draft') then
            return J.Err('case_closed', 'Orders need an open case.')
        end
        local subject = p.subjectCharacterId and p.subjectCharacterId:lower() or nil
        local open = Repo.OpenCharges(tx, case.case_id)
        local affected, remaining, outcome = {}, 0, p.outcome
        if p.rulingType == 'verdict' then
            -- Deterministic order: findings must name the subject's filed charges, then cover all of them.
            local mine = {}
            for _, charge in ipairs(open) do
                if charge.defendant_character_id == subject and charge.status == 'filed' then mine[charge.charge_id] = charge end
            end
            for _, item in ipairs(ordered) do
                if not mine[item.chargeId] then return J.Err('charge_not_filed', 'Findings may only cover the subject\'s filed charges.') end
            end
            for _, charge in ipairs(open) do
                if mine[charge.charge_id] then
                    if not seen[charge.charge_id] then return J.Err('findings_incomplete', 'Every filed charge of the subject needs a finding.') end
                    charge.status = seen[charge.charge_id]; affected[#affected + 1] = charge
                else remaining = remaining + 1 end
            end
            outcome = 'acquitted'
            for _, item in ipairs(ordered) do if item.finding == 'convicted' then outcome = 'convicted' end end
        elseif p.rulingType == 'dismissal' then
            outcome = 'dismissed'
            for _, charge in ipairs(open) do
                if subject == nil or charge.defendant_character_id == subject then
                    charge.status = charge.status == 'filed' and 'dismissed' or 'withdrawn'; affected[#affected + 1] = charge
                else remaining = remaining + 1 end
            end
        end
        local row = { ruling_id = J.NewUuid(), case_id = case.case_id, ruling_type = p.rulingType, outcome = outcome,
            issued_by_character_id = actor.characterId, issued_at = context.now, summary = p.summary,
            subject_character_id = subject, findings_json = p.rulingType == 'verdict' and ordered or nil, revision = 1 }
        Repo.Insert(tx, 'ruling', row)
        for _, charge in ipairs(affected) do
            local changes = { status = charge.status, disposition = charge.status, disposed_by_character_id = actor.characterId,
                disposed_at = context.now, revision = charge.revision + 1 }
            if findingsAllowed[charge.status] then changes.ruling_id = row.ruling_id end
            Repo.Update(tx, 'charge', charge.charge_id, changes)
            for key, value in pairs(changes) do charge[key] = value end
            M.Fact(tx, M.Snapshot('charge', charge, { jurisdictionId = case.jurisdiction_id }), 'charge.disposed', context)
        end
        if p.rulingType ~= 'order' and remaining == 0 then
            local changes = { status = p.rulingType == 'verdict' and 'adjudicated' or 'dismissed', revision = case.revision + 1 }
            if changes.status == 'dismissed' then changes.closed_at = context.now end
            Repo.Update(tx, 'case', case.case_id, changes)
            for key, value in pairs(changes) do case[key] = value end
            M.Fact(tx, J.CaseSnapshot(case), 'case.transitioned', context)
        end
        return J.Ok(M.Snapshot('ruling', row, { jurisdictionId = case.jurisdiction_id }))
    end)
end)

-- Sentences -------------------------------------------------------------------
local function TermsValid(kind, t)
    local c = JusticeConfig.Sentences
    if type(t) ~= 'table' then return false end
    if kind == 'custodial' then
        return J.Fields(t, { termSeconds = true, facilityKey = true }) and J.Integer(t.termSeconds, 60, c.MaximumTermSeconds)
            and (t.facilityKey == nil or J.Token(t.facilityKey, 64))
    elseif kind == 'probation' then
        return J.Fields(t, { termSeconds = true, conditionsSummary = true }) and J.Integer(t.termSeconds, 60, c.MaximumTermSeconds)
            and J.Text(t.conditionsSummary, 2000)
    elseif kind == 'community_service' then
        return J.Fields(t, { units = true, taskKey = true }) and J.Integer(t.units, 1, c.MaximumServiceUnits) and J.Token(t.taskKey, 64)
    elseif kind == 'fine' then
        return J.Fields(t, { amount = true, dueInSeconds = true }) and J.Integer(t.amount, 1, c.MaximumAmount)
            and J.Integer(t.dueInSeconds, 60, c.MaximumDueSeconds)
    elseif kind == 'restitution' then
        return J.Fields(t, { amount = true, dueInSeconds = true, creditorCharacterId = true }) and J.Integer(t.amount, 1, c.MaximumAmount)
            and J.Integer(t.dueInSeconds, 60, c.MaximumDueSeconds) and J.Uuid(t.creditorCharacterId)
    elseif kind == 'license_suspension' then
        return J.Fields(t, { licenseKey = true, termSeconds = true }) and J.Token(t.licenseKey, 64)
            and (t.termSeconds == nil or J.Integer(t.termSeconds, 60, c.MaximumTermSeconds))
    elseif kind == 'forfeiture' then
        return J.Fields(t, { targetType = true, targetReference = true }) and targetTypes[t.targetType] == true and J.Token(t.targetReference, 64)
    end
    return false
end
local function Snapshot(row, service)
    local snapshot = M.Snapshot('sentence', row)
    -- Service-mode readers (no player) never receive narrative terms.
    if service and type(snapshot.terms) == 'table' then snapshot.terms.conditionsSummary = nil end
    return snapshot
end
J.SentenceSnapshot = Snapshot

J.Export('CreateSentence', function(p, owner)
    if not M.Fields(p, { 'caseId', 'expectedCaseRevision', 'rulingId', 'sentenceType', 'terms' }, true)
        or not J.Uuid(p.caseId) or not J.Uuid(p.rulingId) or not J.Integer(p.expectedCaseRevision, 1, maximumRevision)
        or not TermsValid(p.sentenceType, p.terms) then
        return J.Err('invalid_input', 'Case revision, ruling UUID, sentence type and typed terms required.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.sentence.impose', p.caseId:lower(), { sentenceType = p.sentenceType }, true)
    if not access.ok then return access end
    local actor = access.value.actor
    local creditor = p.sentenceType == 'restitution' and A.Character(p.terms.creditorCharacterId:lower()) or J.Ok(true)
    return M.Run('sentence.created', p, owner, actor, function(tx, context)
        if not creditor.ok then return creditor end
        local case = A.LockCase(tx, p.caseId:lower(), owner, actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        if case.revision ~= p.expectedCaseRevision then return J.Err('revision_conflict', 'Case revision changed.') end
        if not Judge(tx.one, case.case_id, actor) then return J.Err('judge_required', 'Only the case judge may impose a sentence.') end
        if A.Closed(case) or case.status == 'draft' then return J.Err('case_closed', 'Sentencing needs an open case.') end
        local ruling = Repo.Get(tx.one, 'ruling', p.rulingId:lower(), owner, true)
        if not ruling or ruling.case_id ~= case.case_id or ruling.ruling_type ~= 'verdict' or ruling.outcome ~= 'convicted' then
            return J.Err('conviction_required', 'A convicting verdict in this case is required.')
        end
        local terms = J.Copy(p.terms)
        if terms.creditorCharacterId then terms.creditorCharacterId = terms.creditorCharacterId:lower() end
        local c = JusticeConfig.Sentences
        local row = { sentence_id = J.NewUuid(), case_id = case.case_id, defendant_character_id = ruling.subject_character_id,
            sentence_type = p.sentenceType, status = 'pending', terms_json = terms, ruling_id = ruling.ruling_id,
            jurisdiction_id = case.jurisdiction_id, created_by_character_id = actor.characterId, created_at = context.now, revision = 1 }
        if financial[p.sentenceType] then
            row.currency = c.Currency
            row.type_key = p.sentenceType == 'fine' and c.FineTypeKey or c.RestitutionTypeKey
        end
        Repo.Insert(tx, 'sentence', row)
        return J.Ok(Snapshot(row))
    end)
end)

-- Closes a sentence in the caller's transaction; custodial completion releases the hold.
function J.CloseSentence(tx, row, outcome, context, owner)
    local changes = { status = 'completed', outcome = outcome, completed_at = context.now,
        completed_by_character_id = context.actor.characterId }
    local nulls = { 'remaining_ms' }
    if row.sentence_type == 'custodial' then
        J.ReleaseForSentence(tx, row, owner, context, outcome == 'served' and 'justice.sentence.term_served' or 'justice.sentence.' .. outcome)
    end
    return changes, nulls
end

local function SentenceChange(p, owner, action, fact, apply, extraFields)
    local fields = { 'sentenceId', 'expectedRevision' }
    for _, field in ipairs(extraFields or {}) do fields[#fields + 1] = field end
    if not M.Fields(p, fields, true) or not J.Uuid(p.sentenceId) or not J.Integer(p.expectedRevision, 1, maximumRevision) then
        return J.Err('invalid_input', 'Sentence UUID, expected revision and valid fields required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local existing = Repo.Get(DB.one, 'sentence', p.sentenceId:lower(), owner)
    local attributes = existing and { sentenceType = existing.sentence_type, outcome = p.outcome } or nil
    local actor = J.Principal(owner, action, p, existing and existing.jurisdiction_id or nil, false, attributes)
    if not actor.ok then return actor end
    actor = actor.value
    if not existing then return J.Err('not_found', 'Sentence unavailable.') end
    return M.Run(fact, p, owner, actor, function(tx, context)
        local case = A.LockCase(tx, existing.case_id, owner, actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        local row = Repo.Get(tx.one, 'sentence', existing.sentence_id, owner, true)
        if row.revision ~= p.expectedRevision then return J.Err('revision_conflict', 'Sentence revision changed.') end
        local changes, nulls = apply(tx, row, case, context)
        if changes.ok == false then return changes end
        changes.revision = row.revision + 1
        Repo.Update(tx, 'sentence', row.sentence_id, changes, nulls)
        for key, value in pairs(changes) do row[key] = value end
        for _, column in ipairs(nulls or {}) do row[column] = nil end
        return J.Ok(Snapshot(row, actor.system))
    end)
end

J.Export('ActivateSentence', function(p, owner)
    return SentenceChange(p, owner, 'justice.sentence.activate', 'sentence.activated', function(tx, row, _, context)
        local actor = context.actor
        if row.status == 'suspended' then
            -- Resume: the frozen remaining time restarts from now.
            if timed[row.sentence_type] then return { status = 'active', ends_at = context.now + row.remaining_ms }, { 'remaining_ms' } end
            return { status = 'active' }
        end
        if row.status ~= 'pending' then return J.Err('invalid_transition', 'Only a pending or suspended sentence can be activated.') end
        if financial[row.sentence_type] then
            Repo.Wake(tx, 'sentence', row.sentence_id, 0)
            return { status = 'activating', activated_by_character_id = actor.characterId }
        end
        if row.sentence_type == 'custodial' then
            local held = Repo.ActiveCustodial(tx.one, row.defendant_character_id, true)
            if held and held.sentence_id ~= row.sentence_id then
                return J.Err('sentence_conflict', 'The subject already has an active or suspended custodial sentence.')
            end
        end
        local changes = { status = 'active', activated_by_character_id = actor.characterId, activated_at = context.now }
        if timed[row.sentence_type] then
            changes.starts_at, changes.ends_at = context.now, context.now + row.terms_json.termSeconds * 1000
        end
        return changes
    end)
end)
J.Export('SuspendSentence', function(p, owner)
    return SentenceChange(p, owner, 'justice.sentence.suspend', 'sentence.suspended', function(tx, row, case, context)
        if not Judge(tx.one, case.case_id, context.actor) then return J.Err('judge_required', 'Only the case judge may suspend a sentence.') end
        if row.status ~= 'active' or financial[row.sentence_type] or effects[row.sentence_type] then
            return J.Err('invalid_transition', 'Only active custodial, probation or community-service sentences can be suspended.')
        end
        if timed[row.sentence_type] then
            if row.ends_at <= context.now then return J.Err('sentence_elapsed', 'The term has already elapsed.') end
            return { status = 'suspended', remaining_ms = row.ends_at - context.now }
        end
        return { status = 'suspended' }
    end)
end)
J.Export('CompleteSentence', function(p, owner)
    if type(p) ~= 'table' or not outcomes[p.outcome or ''] or (p.effectReference ~= nil and not J.Token(p.effectReference, 128)) then
        return J.Err('invalid_input', 'Outcome served, vacated or commuted (and an optional effect reference) required.')
    end
    return SentenceChange(p, owner, 'justice.sentence.complete', 'sentence.completed', function(tx, row, case, context)
        local actor = context.actor
        if row.status == 'completed' then return J.Err('invalid_transition', 'The sentence is already complete.') end
        if row.status == 'activating' or row.status == 'completing' then
            return J.Err('workflow_pending', 'A Contracts step is still pending; retry later.')
        end
        -- Service mode may only report finished community service.
        if actor.system and (row.sentence_type ~= 'community_service' or p.outcome ~= 'served') then
            return J.Err('authorization_denied', 'Service mode may only complete community service.')
        end
        if p.outcome ~= 'served' then
            if not Judge(tx.one, case.case_id, actor) then return J.Err('judge_required', 'Only the case judge may vacate or commute.') end
            if financial[row.sentence_type] and row.status ~= 'pending' then
                -- The obligation is cancelled through Contracts first; a debt already paid completes as served.
                Repo.Wake(tx, 'sentence', row.sentence_id, 0)
                return { status = 'completing', outcome = p.outcome }
            end
            return J.CloseSentence(tx, row, p.outcome, context, owner)
        end
        if row.status ~= 'active' then return J.Err('invalid_transition', 'Only an active sentence can be served.') end
        if financial[row.sentence_type] then return J.Err('settlement_required', 'Financial sentences complete when Contracts confirms payment.') end
        if effects[row.sentence_type] then
            if not p.effectReference then return J.Err('effect_reference_required', 'Record the executing domain operation reference.') end
            local changes, nulls = J.CloseSentence(tx, row, 'served', context, owner)
            changes.effect_reference = p.effectReference
            return changes, nulls
        end
        if timed[row.sentence_type] and row.ends_at > context.now then
            return J.Err('term_not_served', 'The term has not elapsed; a judge may commute it.')
        end
        return J.CloseSentence(tx, row, 'served', context, owner)
    end, { 'outcome', 'effectReference' })
end)

J.Export('GetSentence', function(p, owner)
    if not M.Fields(p, { 'sentenceId' }, false) or not J.Uuid(p.sentenceId) then return J.Err('invalid_input', 'Sentence UUID required.') end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local row = Repo.Get(DB.one, 'sentence', p.sentenceId:lower(), owner)
    local access = A.CasePrincipal(p, owner, 'justice.sentence.view', row and row.case_id, nil, false)
    if not access.ok then return access end
    return J.Ok(Snapshot(row))
end)
J.Export('ListActiveSentences', function(p, owner)
    local page = M.Fields(p, { 'jurisdictionId', 'caseId', 'defendantCharacterId', 'sentenceType', 'limit', 'cursor' }, false) and A.PageArgs(p)
    if not page or (p.jurisdictionId ~= nil and not J.Uuid(p.jurisdictionId)) or (p.caseId ~= nil and not J.Uuid(p.caseId))
        or (p.defendantCharacterId ~= nil and not J.Uuid(p.defendantCharacterId)) or (p.sentenceType ~= nil and not J.Token(p.sentenceType, 24))
        or (p.jurisdictionId == nil and p.caseId == nil and p.defendantCharacterId == nil) then
        return J.Err('invalid_input', 'jurisdictionId, caseId or defendantCharacterId and a bounded page required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local actor
    page.filters = {}
    if p.caseId then
        local access = A.CasePrincipal(p, owner, 'justice.sentence.view', p.caseId:lower(), nil, false)
        if not access.ok then return access end
        actor = access.value.actor
        page.filters.case_id = access.value.case.case_id
    else
        local principal = J.Principal(owner, 'justice.sentence.view', p, p.jurisdictionId, false,
            p.defendantCharacterId and { subjectSearch = true } or nil)
        if not principal.ok then return principal end
        actor = principal.value
        if actor.system and not p.defendantCharacterId then return J.Err('invalid_input', 'Service mode reads one defendant at a time.') end
        page.filters.jurisdiction_id = p.jurisdictionId and p.jurisdictionId:lower() or nil
    end
    if p.defendantCharacterId then
        page.filters.defendant_character_id = p.defendantCharacterId:lower()
        A.AuditSearch(owner, actor, 'justice.sentence.view', p.defendantCharacterId:lower())
    end
    page.filters.sentence_type = p.sentenceType
    page.statuses = { 'activating', 'active', 'suspended', 'completing' }
    page.actor = actor
    local items, more = Repo.Page(DB.query, 'sentence', owner, page)
    if not J.Current(actor) then return J.Err('session_expired', 'Actor changed.') end
    local list = {}
    for index, row in ipairs(items) do list[index] = Snapshot(row, actor.system) end
    return J.Ok({ items = list, nextCursor = more and items[#items].sentence_id or nil })
end)

-- Completes custodial/probation terms at their UTC deadline (offline time counts).
function J.SweepSentences()
    if not J.Ready() then return 0 end
    local generation, count = J.Generation(), 0
    for _, due in ipairs(Repo.DueSentences(Repo.Now(DB.value), JusticeConfig.OutboxBatchSize)) do
        if not J.Ready() or generation ~= J.Generation() then break end
        local owner = due.opened_by_resource
        local request = { requestId = 'justice:sentence:term:' .. due.sentence_id, reasonCode = 'justice.sentence.term_served', sentenceId = due.sentence_id }
        local result = M.Run('sentence.completed', request, 'feather-justice', { generation = generation, system = true }, function(tx, context)
            local found = Repo.Get(tx.one, 'sentence', due.sentence_id, owner)
            if not found then return J.Err('not_found', 'Sentence unavailable.') end
            Repo.Get(tx.one, 'case', found.case_id, owner, true)
            local row = Repo.Get(tx.one, 'sentence', due.sentence_id, owner, true)
            if row.status ~= 'active' or not timed[row.sentence_type] or row.ends_at > context.now then
                return J.Err('invalid_transition', 'Sentence not due.')
            end
            local changes, nulls = J.CloseSentence(tx, row, 'served', context, owner)
            changes.revision = row.revision + 1
            Repo.Update(tx, 'sentence', row.sentence_id, changes, nulls)
            for key, value in pairs(changes) do row[key] = value end
            return J.Ok(Snapshot(row))
        end)
        if result.ok then count = count + 1 end
    end
    return count
end
