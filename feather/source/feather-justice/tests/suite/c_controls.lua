-- Mutation controls, authorization, privacy and query rules through the export
-- boundary (caller resource, actor source, Core policy) on the real schema.
return function(t)
    local J = Justice
    local function count(sql, ...) return tonumber(t.sql.value(sql, ...)) end
    -- Definitions are set up by the trusted consumer without a player.
    local juris = t.call('RegisterJurisdiction', { reasonCode = 'setup', jurisdictionKey = 'bcc-law:controls', label = 'Controls',
        jurisdictionType = 'county' }, { service = true })
    t.check('definition registered in service mode', juris.ok, t.code(juris))
    local jid = juris.value.jurisdictionId
    local child = t.call('RegisterJurisdiction', { reasonCode = 'setup', jurisdictionKey = 'bcc-law:controls_town', label = 'Town',
        jurisdictionType = 'town', parentJurisdictionId = jid }, { service = true })
    t.check('child jurisdiction in a bounded hierarchy', child.ok and child.value.parentJurisdictionId == jid, t.code(child))
    t.check('jurisdiction key must be namespaced by the caller', t.call('RegisterJurisdiction', { reasonCode = 'setup',
        jurisdictionKey = 'other:controls', label = 'X', jurisdictionType = 'county' }, { service = true }).code == 'invalid_input')
    t.check('unknown jurisdiction type refused', t.call('RegisterJurisdiction', { reasonCode = 'setup',
        jurisdictionKey = 'bcc-law:x', label = 'X', jurisdictionType = 'galaxy' }, { service = true }).code == 'invalid_input')
    t.check('statute key must live under its jurisdiction', t.call('RegisterStatute', { reasonCode = 'setup', jurisdictionId = jid,
        statuteKey = 'bcc-law:elsewhere.theft', title = 'T', category = 'theft', severityClass = 'felony' }, { service = true }).code == 'invalid_input')
    local statute = t.call('RegisterStatute', { reasonCode = 'setup', jurisdictionId = jid, statuteKey = 'bcc-law:controls.theft',
        title = 'Theft', category = 'theft', severityClass = 'felony', recommendedCustodySeconds = { min = 60, max = 600 } }, { service = true })
    t.check('statute registered', statute.ok and statute.value.metadata.recommendedCustodySeconds.max == 600, t.code(statute))
    local future = t.call('RegisterStatute', { reasonCode = 'setup', jurisdictionId = jid, statuteKey = 'bcc-law:controls.future',
        title = 'Future', category = 'order', severityClass = 'infraction', effectiveFrom = J.Repo.Now(DB.value) + 86400000 }, { service = true })
    t.check('future statute registered', future.ok, t.code(future))
    t.check('statute found by key', t.call('GetStatute', { statuteKey = 'bcc-law:controls.theft' }, { service = true }).ok)

    -- Trust, readiness, policy, sessions.
    local open = { reasonCode = 'test', jurisdictionId = jid, caseType = 'criminal', title = 'Controls', summary = 'Private narrative.' }
    t.check('untrusted caller refused', t.call('OpenCase', J.Copy(open), { caller = 'some-script' }).code == 'authorization_denied')
    t.check('player-only action refused in service mode', t.call('OpenCase', J.Copy(open), { service = true }).code == 'actor_required')
    t.policy.denied['justice.case.open'] = true
    t.check('policy denial', t.call('OpenCase', J.Copy(open)).code == 'authorization_denied')
    t.policy.denied['justice.case.open'] = nil
    t.policy.outage = true
    t.check('policy outage fails closed', t.call('OpenCase', J.Copy(open)).code == 'policy_unavailable')
    t.policy.outage = false
    t.policy.current = false
    t.check('stale session refused', t.call('OpenCase', J.Copy(open)).code == 'session_expired')
    t.policy.current = true
    J.State('degraded', 'test')
    t.check('degraded Justice refuses', t.call('OpenCase', J.Copy(open)).code == 'not_ready')
    J.State('ready', 'test')
    t.check('unknown request fields refused', t.call('OpenCase', { reasonCode = 'test', jurisdictionId = jid, caseType = 'criminal',
        title = 'X', summary = 'Y', openedByCharacterId = t.other }).code == 'invalid_input')

    -- Idempotency, rollback, unknown commit.
    local request = J.Copy(open); request.requestId = 'controls-open'; request.correlationId = 'corr-123'
    local case = t.call('OpenCase', J.Copy(request))
    t.check('case opened', case.ok and case.value.status == 'open', t.code(case))
    local cid = case.value.caseId
    t.check('exact retry replays', t.call('OpenCase', J.Copy(request)).value.replayed == true)
    t.check('retry with a new correlation ID still replays', (function() local r = J.Copy(request); r.correlationId = 'corr-456'; return t.call('OpenCase', r).value.replayed end)())
    local changed = J.Copy(request); changed.summary = 'Different'
    t.check('changed payload conflicts', t.call('OpenCase', changed).code == 'idempotency_conflict')
    t.check('another actor cannot reuse the request ID', t.call('OpenCase', J.Copy(request), { source = 6 }).code == 'idempotency_conflict')
    t.check('correlation ID stored with the audit fact', count('SELECT COUNT(*) FROM justice_audit_events WHERE record_id=? AND correlation_id=?', cid, 'corr-123') == 1)
    local cases = count('SELECT COUNT(*) FROM justice_cases')
    t.fault.match = 'INSERT INTO justice_outbox'
    local failed = t.call('OpenCase', { reasonCode = 'test', requestId = 'controls-fault', jurisdictionId = jid, caseType = 'criminal', title = 'F', summary = 'F' })
    t.check('outbox failure refuses the write', failed.code == 'transaction_failed', t.code(failed))
    t.check('outbox failure rolled back case, receipt and audit', count('SELECT COUNT(*) FROM justice_cases') == cases
        and count("SELECT COUNT(*) FROM justice_receipts WHERE request_id='controls-fault'") == 0)
    t.fault.commitLost = true
    local lost = t.call('OpenCase', { reasonCode = 'test', requestId = 'controls-lost', jurisdictionId = jid, caseType = 'criminal', title = 'L', summary = 'L' })
    t.check('lost commit acknowledgement reported as unknown', lost.code == 'transaction_failed', t.code(lost))
    local recovered = t.call('OpenCase', { reasonCode = 'test', requestId = 'controls-lost', jurisdictionId = jid, caseType = 'criminal', title = 'L', summary = 'L' })
    t.check('retry with the same ID recovers exactly one case', recovered.ok and recovered.value.replayed and count('SELECT COUNT(*) FROM justice_cases') == cases + 1)

    -- Identities and parties.
    t.check('numeric character id refused', t.call('ProposeCharge', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1,
        defendantCharacterId = 44, statuteId = statute.value.statuteId, count = 1 }).code == 'invalid_input')
    t.check('unknown character refused', t.call('ProposeCharge', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1,
        defendantCharacterId = t.uuid(999), statuteId = statute.value.statuteId, count = 1 }).code == 'subject_not_found')
    t.check('retired character refused', t.call('ProposeCharge', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1,
        defendantCharacterId = t.retired, statuteId = statute.value.statuteId, count = 1 }).code == 'subject_inactive')
    t.check('statute not yet in force refused', t.call('ProposeCharge', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1,
        defendantCharacterId = t.subject, statuteId = future.value.statuteId, count = 1 }).code == 'statute_mismatch')
    local org = t.call('AddCaseParty', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1, partyType = 'organization',
        partyIdReference = t.organization, partyRole = 'victim' })
    t.check('organization party added', org.ok and org.value.partyType == 'organization', t.code(org))
    t.check('dissolved organization refused', t.call('AddCaseParty', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1,
        partyType = 'organization', partyIdReference = t.dissolvedOrganization, partyRole = 'witness' }).code == 'organization_inactive')
    t.check('duplicate active role refused', t.call('AddCaseParty', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1,
        partyType = 'organization', partyIdReference = t.organization, partyRole = 'victim' }).code == 'party_exists')

    -- Case privacy: role labels make an authorized actor eligible; nothing else.
    t.check('non-member cannot read', t.call('GetCase', { caseId = cid }, { source = 6 }).code == 'not_found')
    local listed = t.call('ListCases', { jurisdictionId = jid }, { source = 6 })
    t.check('non-member list is empty', listed.ok and #listed.value.items == 0, t.code(listed))
    t.call('AddCaseParty', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 1, partyType = 'character',
        partyIdReference = t.other, partyRole = 'reporting_officer' })
    t.check('reporting officer can read', t.call('GetCase', { caseId = cid }, { source = 6 }).ok)
    t.check('reporting officer cannot write', t.call('UpdateCaseSummary', { reasonCode = 'test', caseId = cid, expectedRevision = 1,
        summary = 'x' }, { source = 6 }).code == 'not_found')
    t.policy.wide[t.other] = true
    t.check('justice.case.manage_all widens access', t.call('UpdateCaseSummary', { reasonCode = 'test', caseId = cid, expectedRevision = 1,
        summary = 'Edited by manager.' }, { source = 6 }).ok)
    t.policy.wide[t.other] = nil

    -- Pagination and audited character search.
    for index = 1, 3 do t.call('OpenCase', { reasonCode = 'test', jurisdictionId = jid, caseType = 'civil', title = 'Page ' .. index, summary = 'P' }) end
    local first = t.call('ListCases', { jurisdictionId = jid, caseType = 'civil', limit = 2 })
    local second = first.ok and t.call('ListCases', { jurisdictionId = jid, caseType = 'civil', limit = 2, cursor = first.value.nextCursor })
    t.check('bounded keyset pagination', first.ok and #first.value.items == 2 and first.value.nextCursor and second.ok
        and #second.value.items == 1 and second.value.nextCursor == nil)
    t.check('page size is bounded', t.call('ListCases', { jurisdictionId = jid, limit = 500 }).code == 'invalid_input')
    local draft = t.call('CreateWarrantDraft', { reasonCode = 'test', caseId = cid, expectedCaseRevision = 2, subjectCharacterId = t.subject,
        warrantType = 'arrest', basisSummary = 'Grounds.', validForSeconds = 600 })
    t.call('IssueWarrant', { reasonCode = 'test', warrantId = draft.value.warrantId, expectedRevision = 1 })
    local audited = count('SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=?', t.subject)
    local warrants = t.call('ListActiveWarrants', { jurisdictionId = jid, subjectCharacterId = t.subject })
    t.check('active warrant found by subject', warrants.ok and #warrants.value.items == 1, t.code(warrants))
    t.check('search by character UUID audited with the actor', count('SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=? AND actor_character_id=?',
        t.subject, t.actor) == audited + 1)
    t.check('search refused without policy', (function()
        t.policy.denied['justice.warrant.view'] = true
        local r = t.call('ListActiveWarrants', { jurisdictionId = jid, subjectCharacterId = t.subject })
        t.policy.denied['justice.warrant.view'] = nil
        return r.code == 'authorization_denied'
    end)())
    local service = t.call('GetCustodyStatus', { subjectCharacterId = t.subject }, { service = true })
    t.check('custody status in service mode (no player)', service.ok and service.value.custody == nil, t.code(service))
    t.check('service mode cannot list sentences of a whole jurisdiction', t.call('ListActiveSentences', { jurisdictionId = jid }, { service = true }).code == 'invalid_input')

    -- Events: safe identifiers and state, never narrative; ordered per record.
    local payloads = t.sql.query('SELECT fact, payload_json FROM justice_outbox WHERE record_id=? ORDER BY revision', cid)
    local safe = #payloads > 0
    for _, row in ipairs(payloads) do
        local payload = json.decode(row.payload_json)
        safe = safe and payload.recordId == cid and payload.kind == 'case' and payload.status ~= nil and payload.jurisdictionId == jid
            and not row.payload_json:find('Private narrative', 1, true) and not row.payload_json:find('summary', 1, true)
    end
    t.check('event payloads carry identifiers and state only', safe)
    t.check('warrant event carries the subject identifier', (function()
        local row = t.sql.one("SELECT payload_json FROM justice_outbox WHERE fact='justice.warrant.issued.v1' AND record_id=?", draft.value.warrantId)
        return row and json.decode(row.payload_json).subjectCharacterId == t.subject and not row.payload_json:find('Grounds', 1, true)
    end)())

    -- Redacted audit history: administrators only.
    t.policy.denied['justice.audit.view'] = true
    t.check('history needs justice.audit.view', t.call('GetRecordHistory', { recordId = cid }).code == 'authorization_denied')
    t.policy.denied['justice.audit.view'] = nil
    local history = t.call('GetRecordHistory', { recordId = cid })
    t.check('history lists facts with correlation IDs', history.ok and history.value.items[1].fact == 'justice.case.opened.v1'
        and history.value.items[1].correlationId == 'corr-123', t.code(history))

    -- Metrics through the export boundary.
    local metrics = J.Metrics()
    t.check('per-export metrics recorded', metrics.operations.OpenCase and metrics.operations.OpenCase.codes.idempotency_conflict >= 1)
    t.check('dependency timings recorded', metrics.providers['feather-core.Authorize'] and metrics.providers['feather-core.Authorize'].calls > 0)
    t.check('metrics readable by feather-admin', t.call('GetMetrics', nil, { caller = 'feather-admin' }).ok)
    t.check('metrics refused to other resources', t.call('GetMetrics', nil, { caller = 'some-script' }).code == 'authorization_denied')
    local probes = count('SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=?', t.subject)
    t.check('policy smoke logic passes', J.PolicySmoke().failed == 0)
    t.check('policy smoke writes no access history for real characters',
        count('SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=?', t.subject) == probes)
    -- Repeated automated reads are recorded once per window; officer searches every time.
    local serviceBefore = count("SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=? AND actor_character_id IS NULL", t.other)
    t.call('GetCustodyStatus', { subjectCharacterId = t.other }, { service = true })
    t.call('GetCustodyStatus', { subjectCharacterId = t.other }, { service = true })
    t.check('repeated service-mode reads audited once per window',
        count("SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=? AND actor_character_id IS NULL", t.other) == serviceBefore + 1)
    t.advance(3600 * 1000)
    t.call('GetCustodyStatus', { subjectCharacterId = t.other }, { service = true })
    t.check('the next window records again',
        count("SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=? AND actor_character_id IS NULL", t.other) == serviceBefore + 2)
    local officerBefore = count('SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=? AND actor_character_id=?', t.other, t.actor)
    t.call('GetCustodyStatus', { subjectCharacterId = t.other })
    t.call('GetCustodyStatus', { subjectCharacterId = t.other })
    t.check('every officer search is recorded',
        count('SELECT COUNT(*) FROM justice_access_audit WHERE subject_character_id=? AND actor_character_id=?', t.other, t.actor) == officerBefore + 2)
end
