-- Arrest and custody authority (master plan: Arrest and custody authority;
-- Citation and custody operations; workflow "Arrest and custody").
-- Justice records legal custody facts; Law performs restraint, transport, booking.
local J, Repo, M, A = Justice, Justice.Repo, Justice.Mutation, Justice.Access
local maximumRevision = 9007199254740989
local authorities = { warrant = true, judicial_order = true, exception = true }

function J.WarrantlessEnabled()
    return type(JusticeConfig.Custody) == 'table' and type(JusticeConfig.Custody.Exceptions) == 'table'
        and next(JusticeConfig.Custody.Exceptions) ~= nil
end
local function Snapshot(row) return M.Snapshot('custody', row) end
J.CustodySnapshot = Snapshot

J.Export('RecordArrest', function(p, owner)
    if not M.Fields(p, { 'caseId', 'authorityType', 'authorityId', 'expectedAuthorityRevision', 'subjectCharacterId' }, true)
        or not J.Uuid(p.caseId) or not authorities[p.authorityType or '']
        or (p.authorityType ~= 'exception' and (not J.Uuid(p.authorityId) or not J.Integer(p.expectedAuthorityRevision, 1, maximumRevision)
            or p.subjectCharacterId ~= nil))
        or (p.authorityType == 'exception' and (not J.Token(p.authorityId, 64) or not J.Uuid(p.subjectCharacterId)
            or p.expectedAuthorityRevision ~= nil)) then
        return J.Err('invalid_input', 'Case UUID and one complete authority (warrant, judicial_order or exception) required.')
    end
    if p.authorityType == 'exception' and not (J.WarrantlessEnabled() and JusticeConfig.Custody.Exceptions[p.authorityId] == true) then
        return J.Err('exception_not_allowed', 'This warrantless custody exception is not configured.')
    end
    local access = A.CasePrincipal(p, owner, 'justice.custody.record', p.caseId:lower(),
        { authorityType = p.authorityType, exceptionKey = p.authorityType == 'exception' and p.authorityId or nil }, true)
    if not access.ok then return access end
    local actor = access.value.actor
    -- Executing an arrest warrant is also its service: independently authorized.
    if p.authorityType == 'warrant' then
        local serve = J.Principal(owner, 'justice.warrant.serve', p, access.value.case.jurisdiction_id, false, { warrantType = 'arrest' })
        if not serve.ok then return serve end
    end
    local subjectId
    if p.authorityType == 'warrant' then
        local warrant = Repo.Get(DB.one, 'warrant', p.authorityId:lower(), owner)
        subjectId = warrant and warrant.subject_character_id
    elseif p.authorityType == 'judicial_order' then
        local sentence = Repo.Get(DB.one, 'sentence', p.authorityId:lower(), owner)
        subjectId = sentence and sentence.defendant_character_id
    else subjectId = p.subjectCharacterId:lower() end
    local identity = subjectId and A.Character(subjectId) or J.Err('not_found', 'Authority unavailable.')
    return M.Run('custody.started', p, owner, actor, function(tx, context)
        if not identity.ok then return identity end
        local case = A.LockCase(tx, p.caseId:lower(), owner, actor, true)
        if not case then return J.Err('not_found', 'Case unavailable.') end
        local row = { custody_id = J.NewUuid(), jurisdiction_id = case.jurisdiction_id, case_id = case.case_id,
            subject_character_id = subjectId, authority_type = p.authorityType, status = 'arrested',
            arresting_character_id = actor.characterId, started_at = context.now, revision = 1 }
        local served
        if p.authorityType == 'warrant' then
            local warrant = Repo.Get(tx.one, 'warrant', p.authorityId:lower(), owner, true)
            if not warrant or warrant.case_id ~= case.case_id then return J.Err('not_found', 'Warrant unavailable.') end
            if warrant.revision ~= p.expectedAuthorityRevision then return J.Err('revision_conflict', 'Warrant changed.') end
            if warrant.status ~= 'active' or warrant.warrant_type ~= 'arrest' then return J.Err('invalid_transition', 'Active arrest warrant required.') end
            if warrant.expires_at <= context.now then return J.Err('warrant_expired', 'Warrant expired.') end
            row.authority_id, row.authority_revision = warrant.warrant_id, warrant.revision
            served = warrant
        elseif p.authorityType == 'judicial_order' then
            local sentence = Repo.Get(tx.one, 'sentence', p.authorityId:lower(), owner, true)
            if not sentence or sentence.case_id ~= case.case_id then return J.Err('not_found', 'Sentence unavailable.') end
            if sentence.revision ~= p.expectedAuthorityRevision then return J.Err('revision_conflict', 'Sentence changed.') end
            if sentence.sentence_type ~= 'custodial' or sentence.status ~= 'active' then
                return J.Err('invalid_transition', 'Active custodial sentence required.')
            end
            if sentence.ends_at <= context.now then return J.Err('sentence_elapsed', 'The custodial term has elapsed.') end
            row.authority_id, row.authority_revision = sentence.sentence_id, sentence.revision
        else
            if not A.Editable(case) then return J.Err('case_closed', 'Warrantless custody needs an open case.') end
            row.authority_id = p.authorityId
        end
        if Repo.ActiveCustody(tx.one, subjectId, true) then
            return J.Err('custody_conflict', 'The subject already has an unreleased custody record.')
        end
        Repo.Insert(tx, 'custody', row)
        if served then
            local changes = { status = 'served', served_at = context.now, closed_by_character_id = actor.characterId,
                revision = served.revision + 1 }
            Repo.Update(tx, 'warrant', served.warrant_id, changes)
            for key, value in pairs(changes) do served[key] = value end
            M.Fact(tx, J.WarrantSnapshot(served, context.now), 'warrant.served', context)
        end
        return J.Ok(Snapshot(row))
    end)
end)

J.Export('BookCustody', function(p, owner)
    if type(p) ~= 'table' or not J.Token(p.facilityKey, 64) then return J.Err('invalid_input', 'Facility key required.') end
    return J.ChangeRecord('custody', 'custodyId', p, owner, 'justice.custody.record', 'custody.booked', nil, function(_, row, _, context)
        if row.status ~= 'arrested' then return J.Err('invalid_transition', 'Only an arrested subject can be booked.') end
        return { status = 'booked', booked_at = context.now, booked_by_character_id = context.actor.characterId, facility_key = p.facilityKey }
    end, { 'facilityKey' })
end)
J.Export('ReleaseCustody', function(p, owner)
    if type(p) ~= 'table' or not J.Token(p.releaseReason, 64) then return J.Err('invalid_input', 'Release reason required.') end
    return J.ChangeRecord('custody', 'custodyId', p, owner, 'justice.custody.release', 'custody.released', nil, function(_, row, _, context)
        if row.status == 'released' then return J.Err('invalid_transition', 'Custody is already released.') end
        return { status = 'released', released_at = context.now, released_by_character_id = context.actor.characterId,
            release_reason = p.releaseReason }
    end, { 'releaseReason' })
end)

-- Releases a subject's unreleased custody tied to a sentence (same case or booked on
-- its judicial order), in the caller's transaction. Used at sentence completion.
function J.ReleaseForSentence(tx, sentence, owner, context, reason)
    local custody = Repo.ActiveCustody(tx.one, sentence.defendant_character_id, true)
    if not custody then return end
    if custody.case_id ~= sentence.case_id and not (custody.authority_type == 'judicial_order' and custody.authority_id == sentence.sentence_id) then
        return
    end
    if not Repo.Get(tx.one, 'custody', custody.custody_id, owner) then return end
    local changes = { status = 'released', released_at = context.now, released_by_character_id = context.actor.characterId,
        release_reason = reason, revision = custody.revision + 1 }
    Repo.Update(tx, 'custody', custody.custody_id, changes)
    for key, value in pairs(changes) do custody[key] = value end
    M.Fact(tx, Snapshot(custody), 'custody.released', context)
end

-- By record, or by character for placement/reconnect (audited; service mode allowed).
J.Export('GetCustodyStatus', function(p, owner)
    if not M.Fields(p, { 'custodyId', 'subjectCharacterId' }, false) or (p.custodyId == nil) == (p.subjectCharacterId == nil)
        or (p.custodyId ~= nil and not J.Uuid(p.custodyId)) or (p.subjectCharacterId ~= nil and not J.Uuid(p.subjectCharacterId)) then
        return J.Err('invalid_input', 'Exactly one of custodyId or subjectCharacterId required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    if p.custodyId then
        local row = Repo.Get(DB.one, 'custody', p.custodyId:lower(), owner)
        local access = A.CasePrincipal(p, owner, 'justice.custody.view', row and row.case_id, nil, false)
        if not access.ok then return access end
        return J.Ok(Snapshot(row))
    end
    local actor = J.Principal(owner, 'justice.custody.view', p, nil, false, { subjectSearch = true })
    if not actor.ok then return actor end
    local subject = p.subjectCharacterId:lower()
    A.AuditSearch(owner, actor.value, 'justice.custody.view', subject)
    local now = Repo.Now(DB.value)
    local status = { subjectCharacterId = subject, serverTime = now }
    local custody = Repo.ActiveCustody(DB.one, subject)
    if custody and Repo.Get(DB.one, 'custody', custody.custody_id, owner) then status.custody = Snapshot(custody) end
    local sentence = Repo.ActiveCustodial(DB.one, subject)
    if sentence and Repo.Get(DB.one, 'sentence', sentence.sentence_id, owner) then
        status.custodialSentence = { sentenceId = sentence.sentence_id, revision = sentence.revision, caseId = sentence.case_id,
            status = sentence.status, startsAt = sentence.starts_at, endsAt = sentence.ends_at,
            facilityKey = type(sentence.terms_json) == 'table' and sentence.terms_json.facilityKey or nil,
            remainingMs = sentence.status == 'suspended' and sentence.remaining_ms or math.max(0, (sentence.ends_at or now) - now) }
    end
    if not J.Current(actor.value) then return J.Err('session_expired', 'Actor changed.') end
    return J.Ok(status)
end)
