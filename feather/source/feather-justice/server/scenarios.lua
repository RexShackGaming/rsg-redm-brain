-- Development smoke scenarios (master plan: Testing standard, Proposed smoke tests).
-- They write real records under the `justice-acceptance` owner namespace with a
-- constructed actor (character UUIDs, nobody online) and are always cleaned up.
-- Core policy and sessions are not exercised here; JusticePolicySmokeTest does that.
local J, Repo = Justice, Justice.Repo
local S = {}
J.Scenarios = S
S.Owner = 'justice-acceptance'

function S.Context(prefix, actorId, subjectId, options)
    local t = { passed = 0, failed = 0, skipped = 0, actorId = actorId, subjectId = subjectId, options = options or {}, serial = 0 }
    t.stamp = tostring(Repo.Now(DB.value))
    t.officer = { resource = S.Owner, characterId = actorId }
    t.auditor = { resource = S.Owner, characterId = actorId, viewSealed = true }
    t.service = { resource = S.Owner, system = true }
    function t.check(label, condition, detail)
        if condition then t.passed = t.passed + 1 else t.failed = t.failed + 1 end
        print(('[%s] %s %s%s'):format(prefix, condition and 'PASS' or 'FAIL', label,
            (not condition and detail ~= nil) and (' (' .. tostring(detail) .. ')') or ''))
        return condition
    end
    function t.skip(label, why) t.skipped = t.skipped + 1; print(('[%s] SKIP %s (%s)'):format(prefix, label, why)) end
    function t.rid() t.serial = t.serial + 1; return 'smoke-' .. t.stamp .. '-' .. t.serial end
    function t.as(actor, name, request)
        if request.reasonCode and not request.requestId then request.requestId = t.rid() end
        return J.WithActor(actor, function() return J.Handlers[name](request, S.Owner) end)
    end
    function t.call(name, request) return t.as(t.officer, name, request) end
    function t.code(result) return result.ok and 'ok' or result.code end
    function t.done() print(('[%s] RESULT %d passed, %d failed, %d skipped'):format(prefix, t.passed, t.failed, t.skipped)) end
    return t
end

-- Jurisdiction, statute and an open criminal case with the subject as defendant
-- and the actor as judge (rulings and sentences need the case judge).
function S.Fixture(t)
    if t.fixture then return t.fixture end
    local juris = t.call('RegisterJurisdiction', { reasonCode = 'smoke', jurisdictionKey = S.Owner .. ':j' .. t.stamp,
        label = 'Smoke county', jurisdictionType = 'county' })
    if not t.check('fixture jurisdiction registered', juris.ok, t.code(juris)) then error('fixture', 0) end
    local statute = t.call('RegisterStatute', { reasonCode = 'smoke', jurisdictionId = juris.value.jurisdictionId,
        statuteKey = juris.value.jurisdictionKey .. '.theft.petty', title = 'Petty theft', category = 'theft',
        severityClass = 'misdemeanor', recommendedFine = { min = 5, max = 50 } })
    if not t.check('fixture statute registered', statute.ok, t.code(statute)) then error('fixture', 0) end
    local case = t.call('OpenCase', { reasonCode = 'smoke', jurisdictionId = juris.value.jurisdictionId, caseType = 'criminal',
        title = 'Smoke case', summary = 'Smoke narrative.' })
    if not t.check('fixture case opened', case.ok, t.code(case)) then error('fixture', 0) end
    local judge = t.call('AddCaseParty', { reasonCode = 'smoke', caseId = case.value.caseId, expectedCaseRevision = 1,
        partyType = 'character', partyIdReference = t.actorId, partyRole = 'judge' })
    local defendant = t.call('AddCaseParty', { reasonCode = 'smoke', caseId = case.value.caseId, expectedCaseRevision = 1,
        partyType = 'character', partyIdReference = t.subjectId, partyRole = 'defendant' })
    t.check('fixture parties added (offline characters)', judge.ok and defendant.ok, t.code(judge) .. '/' .. t.code(defendant))
    t.fixture = { jurisdiction = juris.value, statute = statute.value, case = case.value }
    return t.fixture
end
local function CaseRevision(t, caseId)
    local case = t.as(t.auditor, 'GetCase', { caseId = caseId })
    return case.ok and case.value.revision or 0
end

function S.Case(t)
    local fx = S.Fixture(t)
    local draftRequest = { requestId = t.rid(), reasonCode = 'smoke', jurisdictionId = fx.jurisdiction.jurisdictionId,
        caseType = 'investigation', title = 'Draft case', summary = 'Draft narrative.', status = 'draft' }
    local draft = t.call('OpenCase', draftRequest)
    t.check('case opened as draft', draft.ok and draft.value.status == 'draft', t.code(draft))
    t.check('exact retry replays', t.call('OpenCase', J.Copy(draftRequest)).value.replayed == true)
    local changed = J.Copy(draftRequest); changed.title = 'Other'
    t.check('changed payload under the same request ID refused', t.call('OpenCase', changed).code == 'idempotency_conflict')
    local opened = t.call('TransitionCase', { reasonCode = 'smoke', caseId = draft.value.caseId, expectedRevision = 1, status = 'open' })
    t.check('draft opened', opened.ok and opened.value.status == 'open', t.code(opened))
    t.check('stale revision refused', t.call('UpdateCaseSummary', { reasonCode = 'smoke', caseId = draft.value.caseId,
        expectedRevision = 1, summary = 'x' }).code == 'revision_conflict')
    t.check('adjudicated only through a verdict', t.call('TransitionCase', { reasonCode = 'smoke', caseId = draft.value.caseId,
        expectedRevision = 2, status = 'adjudicated' }).code == 'invalid_transition')
    -- Concurrent edits at the same revision: exactly one wins (optimistic revision + row lock).
    local results, finished = {}, 0
    for index = 1, 2 do
        CreateThread(function()
            results[index] = t.call('UpdateCaseSummary', { reasonCode = 'smoke', caseId = draft.value.caseId,
                expectedRevision = 2, summary = 'Concurrent ' .. index })
            finished = finished + 1
        end)
    end
    local deadline = GetGameTimer() + 10000
    while finished < 2 and GetGameTimer() < deadline do Wait(50) end
    local wins, conflicts = 0, 0
    for _, result in ipairs(results) do
        if result.ok then wins = wins + 1 elseif result.code == 'revision_conflict' then conflicts = conflicts + 1 end
    end
    t.check('concurrent edits: one commit, one revision conflict', wins == 1 and conflicts == 1, wins .. '/' .. conflicts)
    if t.options.organizationId then
        local org = t.call('AddCaseParty', { reasonCode = 'smoke', caseId = draft.value.caseId, expectedCaseRevision = 3,
            partyType = 'organization', partyIdReference = t.options.organizationId, partyRole = 'victim' })
        t.check('organization party verified and added', org.ok and org.value.partyType == 'organization', t.code(org))
    else t.skip('organization party', 'pass org=<organizationUuid>') end
    t.check('organizations cannot hold officer roles', t.call('AddCaseParty', { reasonCode = 'smoke', caseId = draft.value.caseId,
        expectedCaseRevision = 3, partyType = 'organization', partyIdReference = J.NewUuid(), partyRole = 'judge' }).code == 'invalid_input')
    local parties = t.call('ListCaseParties', { caseId = fx.case.caseId })
    t.check('parties listed', parties.ok and #parties.value.items == 2, t.code(parties))
    local file = t.call('GetCase', { caseId = fx.case.caseId, includeRelated = true })
    t.check('case file index returned', file.ok and type(file.value.related) == 'table' and file.value.related.warrant ~= nil, t.code(file))
end

function S.Warrant(t)
    local fx = S.Fixture(t)
    local function warrant(kind, seconds)
        local draft = t.call('CreateWarrantDraft', { reasonCode = 'smoke', caseId = fx.case.caseId, expectedCaseRevision = 1,
            subjectCharacterId = t.subjectId, warrantType = kind, basisSummary = 'Smoke basis.', validForSeconds = seconds or 3600 })
        if not draft.ok then return draft end
        return t.call('IssueWarrant', { reasonCode = 'smoke', warrantId = draft.value.warrantId, expectedRevision = 1 })
    end
    local search = warrant('search')
    t.check('search warrant issued', search.ok and search.value.status == 'active', t.code(search))
    local served = t.call('ServeWarrant', { reasonCode = 'smoke', warrantId = search.value.warrantId, expectedRevision = 2 })
    t.check('search warrant served', served.ok and served.value.status == 'served' and served.value.servedAt ~= nil, t.code(served))
    local summons = warrant('summons')
    t.check('summons recalled', summons.ok and t.call('RecallWarrant', { reasonCode = 'smoke', warrantId = summons.value.warrantId,
        expectedRevision = 2 }).value.status == 'recalled')
    local seizure = warrant('seizure')
    t.check('seizure quashed', seizure.ok and t.call('QuashWarrant', { reasonCode = 'smoke', warrantId = seizure.value.warrantId,
        expectedRevision = 2 }).value.status == 'quashed')
    local arrest = warrant('arrest')
    t.check('arrest warrant issued with UTC expiry', arrest.ok and arrest.value.expiresAt == arrest.value.issuedAt + 3600000, t.code(arrest))
    t.fixture.arrest = arrest.ok and arrest.value or nil
    local before = #Repo.AccessHistory(t.subjectId, 100)
    local active = t.call('ListActiveWarrants', { jurisdictionId = fx.jurisdiction.jurisdictionId, subjectCharacterId = t.subjectId })
    t.check('active warrants listed by subject', active.ok and #active.value.items == 1, t.code(active))
    t.check('search by character UUID audited', #Repo.AccessHistory(t.subjectId, 100) == before + 1)
    t.check('closed warrant cannot be served again', t.call('ServeWarrant', { reasonCode = 'smoke', warrantId = search.value.warrantId,
        expectedRevision = 3 }).code == 'invalid_transition')
end

function S.Citation(t)
    local fx = S.Fixture(t)
    local warning = t.call('IssueCitation', { reasonCode = 'smoke', caseId = fx.case.caseId, expectedCaseRevision = 1,
        subjectCharacterId = t.subjectId, statuteId = fx.statute.statuteId, basisSummary = 'Verbal warning.' })
    t.check('warning citation issued without obligation', warning.ok and warning.value.status == 'issued'
        and warning.value.contractsObligationId == nil, t.code(warning))
    local list = t.call('ListCitations', { subjectCharacterId = t.subjectId, jurisdictionId = fx.jurisdiction.jurisdictionId })
    t.check('citations listed by subject', list.ok and #list.value.items >= 1, t.code(list))
    if t.options.contracts then
        local fine = t.call('IssueCitation', { reasonCode = 'smoke', caseId = fx.case.caseId, expectedCaseRevision = 1,
            subjectCharacterId = t.subjectId, statuteId = fx.statute.statuteId, basisSummary = 'Fine.', amount = 1, dueInSeconds = 3600 })
        t.check('payable citation pending Contracts', fine.ok and fine.value.status == 'pending', t.code(fine))
        J.ProcessWorkflows()
        local issued = t.call('GetCitation', { citationId = fine.value.citationId })
        t.check('Contracts obligation issued for citation', issued.ok and issued.value.status == 'issued'
            and J.Uuid(issued.value.contractsObligationId), issued.ok and issued.value.status or t.code(issued))
        t.fixture.payableCitation = issued.ok and issued.value or nil
    else t.skip('payable citation via Contracts', 'pass contracts; creates a $1 obligation') end
end

function S.Custody(t)
    local fx = S.Fixture(t)
    if not fx.arrest then S.Warrant(t) end
    local arrest = t.fixture.arrest
    if not arrest then return t.skip('custody', 'no arrest warrant') end
    local started = t.call('RecordArrest', { reasonCode = 'smoke', caseId = fx.case.caseId, authorityType = 'warrant',
        authorityId = arrest.warrantId, expectedAuthorityRevision = arrest.revision })
    t.check('arrest recorded on the warrant', started.ok and started.value.status == 'arrested', t.code(started))
    local warrant = t.call('GetWarrant', { warrantId = arrest.warrantId })
    t.check('warrant served atomically with the arrest', warrant.ok and warrant.value.status == 'served')
    t.check('warrantless arrest disabled by default', t.call('RecordArrest', { reasonCode = 'smoke', caseId = fx.case.caseId,
        authorityType = 'exception', authorityId = 'caught_in_the_act', subjectCharacterId = t.subjectId }).code == 'exception_not_allowed')
    local draft = t.call('CreateWarrantDraft', { reasonCode = 'smoke', caseId = fx.case.caseId, expectedCaseRevision = 1,
        subjectCharacterId = t.subjectId, warrantType = 'arrest', basisSummary = 'Second warrant.', validForSeconds = 3600 })
    local second = draft.ok and t.call('IssueWarrant', { reasonCode = 'smoke', warrantId = draft.value.warrantId, expectedRevision = 1 }) or draft
    local conflict = second.ok and t.call('RecordArrest', { reasonCode = 'smoke', caseId = fx.case.caseId, authorityType = 'warrant',
        authorityId = second.value.warrantId, expectedAuthorityRevision = second.value.revision }) or second
    t.check('one unreleased custody record per subject', conflict.code == 'custody_conflict', t.code(conflict))
    if second.ok then t.call('RecallWarrant', { reasonCode = 'smoke', warrantId = second.value.warrantId, expectedRevision = second.value.revision }) end
    local booked = t.call('BookCustody', { reasonCode = 'smoke', custodyId = started.value.custodyId, expectedRevision = 1, facilityKey = 'smoke_jail' })
    t.check('custody booked at a facility', booked.ok and booked.value.status == 'booked' and booked.value.facilityKey == 'smoke_jail', t.code(booked))
    local status = t.as(t.service, 'GetCustodyStatus', { subjectCharacterId = t.subjectId })
    t.check('custody status readable in service mode', status.ok and status.value.custody and status.value.custody.status == 'booked', t.code(status))
    t.fixture.custody = booked.ok and booked.value or nil
end

function S.Evidence(t)
    local fx = S.Fixture(t)
    local reference = J.NewUuid()
    local link = t.call('LinkEvidence', { reasonCode = 'smoke', caseId = fx.case.caseId, expectedCaseRevision = 1,
        evidenceType = 'external', evidenceId = reference, relationship = 'collected', description = 'Smoke exhibit.' })
    t.check('external evidence linked', link.ok, t.code(link))
    t.check('duplicate link refused', t.call('LinkEvidence', { reasonCode = 'smoke', caseId = fx.case.caseId, expectedCaseRevision = 1,
        evidenceType = 'external', evidenceId = reference, relationship = 'collected' }).code == 'evidence_exists')
    local removed = t.call('RemoveEvidenceLink', { reasonCode = 'smoke', evidenceLinkId = link.value.evidenceLinkId,
        expectedRevision = 1, disposition = 'returned' })
    t.check('link removed with an immutable disposition', removed.ok and removed.value.disposition == 'returned', t.code(removed))
    local all = t.call('ListCaseEvidence', { caseId = fx.case.caseId, includeRemoved = true })
    t.check('removed links kept in history', all.ok and #all.value.items >= 1, t.code(all))
    if t.options.item then
        local item = t.call('LinkEvidence', { reasonCode = 'smoke', caseId = fx.case.caseId, expectedCaseRevision = 1,
            evidenceType = 'inventory_item', evidenceId = t.options.item, relationship = 'collected' })
        t.check('inventory instance verified and linked', item.ok and item.value.itemName ~= nil, t.code(item))
        if item.ok then
            local api = exports['feather-inventory']:initiate()
            local called, allowed = pcall(api.Guards.CanDestroyInstance, tonumber(t.options.item), { reason = 'justice_smoke_guard' })
            t.check('guard vetoes destroying linked evidence (nothing destroyed)', J.EvidenceGuardActive() and called and allowed == false,
                J.EvidenceGuardActive() and tostring(allowed) or 'guard inactive')
            t.call('RemoveEvidenceLink', { reasonCode = 'smoke', evidenceLinkId = item.value.evidenceLinkId, expectedRevision = 1 })
        end
    else t.skip('inventory evidence guard', 'pass item=<instanceId> of a throwaway item') end
end

-- Acceptance only: charges, rulings, sentences, judicial custody and privacy.
function S.Judicial(t)
    local fx = S.Fixture(t)
    local case = fx.case
    local charge = t.call('ProposeCharge', { reasonCode = 'smoke', caseId = case.caseId, expectedCaseRevision = 1,
        defendantCharacterId = t.subjectId, statuteId = fx.statute.statuteId, count = 1 })
    t.check('charge proposed with statute snapshot', charge.ok and charge.value.statuteSnapshot.category == 'theft', t.code(charge))
    t.call('FileCharge', { reasonCode = 'smoke', chargeId = charge.value.chargeId, expectedRevision = 1 })
    local amended = t.call('AmendCharge', { reasonCode = 'smoke', chargeId = charge.value.chargeId, expectedRevision = 2, count = 2 })
    t.check('charge amended into a new filed charge', amended.ok and amended.value.status == 'filed' and amended.value.amendsChargeId == charge.value.chargeId, t.code(amended))
    local list = t.call('ListCharges', { caseId = case.caseId })
    local superseded = false
    for _, item in ipairs(list.ok and list.value.items or {}) do if item.chargeId == charge.value.chargeId then superseded = item.status == 'amended' end end
    t.check('original charge marked amended', superseded)
    -- A short arrest warrant expires during the term wait below.
    local short = t.call('CreateWarrantDraft', { reasonCode = 'smoke', caseId = case.caseId, expectedCaseRevision = 1,
        subjectCharacterId = t.subjectId, warrantType = 'arrest', basisSummary = 'Expiring.', validForSeconds = 60 })
    short = short.ok and t.call('IssueWarrant', { reasonCode = 'smoke', warrantId = short.value.warrantId, expectedRevision = 1 }) or short
    local revision = CaseRevision(t, case.caseId)
    t.call('TransitionCase', { reasonCode = 'smoke', caseId = case.caseId, expectedRevision = revision, status = 'filed' })
    local hearing = t.call('TransitionCase', { reasonCode = 'smoke', caseId = case.caseId, expectedRevision = revision + 1, status = 'pending_hearing' })
    t.check('case set for hearing', hearing.ok, t.code(hearing))
    local verdict = t.call('RecordRuling', { reasonCode = 'smoke', caseId = case.caseId, expectedCaseRevision = revision + 2,
        rulingType = 'verdict', subjectCharacterId = t.subjectId, summary = 'Guilty.',
        findings = { { chargeId = amended.value.chargeId, finding = 'convicted' } } })
    t.check('verdict recorded by the case judge', verdict.ok and verdict.value.outcome == 'convicted', t.code(verdict))
    local adjudicated = t.call('GetCase', { caseId = case.caseId })
    t.check('case adjudicated by the verdict', adjudicated.ok and adjudicated.value.status == 'adjudicated')
    revision = adjudicated.value.revision
    local function sentence(kind, terms)
        local created = t.call('CreateSentence', { reasonCode = 'smoke', caseId = case.caseId, expectedCaseRevision = revision,
            rulingId = verdict.value.rulingId, sentenceType = kind, terms = terms })
        if not created.ok then return created, created end
        return t.call('ActivateSentence', { reasonCode = 'smoke', sentenceId = created.value.sentenceId, expectedRevision = 1 }), created
    end
    -- Custody from the earlier booking, if any, is released first so the judicial order can hold.
    if t.fixture.custody then
        t.call('ReleaseCustody', { reasonCode = 'smoke', custodyId = t.fixture.custody.custodyId,
            expectedRevision = t.fixture.custody.revision, releaseReason = 'transferred' })
    end
    local custodial = sentence('custodial', { termSeconds = 60, facilityKey = 'smoke_jail' })
    t.check('custodial sentence active with a UTC deadline', custodial.ok and custodial.value.endsAt == custodial.value.startsAt + 60000, t.code(custodial))
    local second, queued = sentence('custodial', { termSeconds = 120 })
    t.check('second custodial sentence refused', second.code == 'sentence_conflict', t.code(second))
    local order = t.call('RecordArrest', { reasonCode = 'smoke', caseId = case.caseId, authorityType = 'judicial_order',
        authorityId = custodial.value.sentenceId, expectedAuthorityRevision = custodial.value.revision })
    t.check('custody recorded on the judicial order', order.ok and order.value.authorityType == 'judicial_order', t.code(order))
    local status = t.as(t.service, 'GetCustodyStatus', { subjectCharacterId = t.subjectId })
    t.check('placement status: hold and authoritative deadline', status.ok and status.value.custodialSentence
        and status.value.custodialSentence.endsAt == custodial.value.endsAt, t.code(status))
    local suspended = t.call('SuspendSentence', { reasonCode = 'smoke', sentenceId = custodial.value.sentenceId, expectedRevision = 2 })
    t.check('suspension freezes the remaining time', suspended.ok and suspended.value.remainingMs > 0, t.code(suspended))
    local resumed = t.call('ActivateSentence', { reasonCode = 'smoke', sentenceId = custodial.value.sentenceId, expectedRevision = 3 })
    t.check('activation resumes from now', resumed.ok and resumed.value.status == 'active', t.code(resumed))
    local early = t.call('CompleteSentence', { reasonCode = 'smoke', sentenceId = custodial.value.sentenceId, expectedRevision = 4, outcome = 'served' })
    t.check('term cannot be served early', early.code == 'term_not_served', t.code(early))
    local service = sentence('community_service', { units = 2, taskKey = 'smoke_chores' })
    local done = t.as(t.service, 'CompleteSentence', { reasonCode = 'smoke', sentenceId = service.value.sentenceId, expectedRevision = 2, outcome = 'served' })
    t.check('community service completed in service mode', done.ok and done.value.status == 'completed', t.code(done))
    local probation = sentence('probation', { termSeconds = 600, conditionsSummary = 'Smoke conditions.' })
    local commuted = t.call('CompleteSentence', { reasonCode = 'smoke', sentenceId = probation.value.sentenceId, expectedRevision = 2, outcome = 'commuted' })
    t.check('probation commuted by the judge', commuted.ok and commuted.value.outcome == 'commuted', t.code(commuted))
    local license = sentence('license_suspension', { licenseKey = 'hunting' })
    t.check('suspension needs the executing domain reference', t.call('CompleteSentence', { reasonCode = 'smoke',
        sentenceId = license.value.sentenceId, expectedRevision = 2, outcome = 'served' }).code == 'effect_reference_required')
    local effect = t.call('CompleteSentence', { reasonCode = 'smoke', sentenceId = license.value.sentenceId, expectedRevision = 2,
        outcome = 'served', effectReference = 'licenses-op-smoke' })
    t.check('suspension completed with its reference', effect.ok and effect.value.effectReference == 'licenses-op-smoke', t.code(effect))
    local vacatedQueued = t.call('CompleteSentence', { reasonCode = 'smoke', sentenceId = queued.value.sentenceId, expectedRevision = 1, outcome = 'vacated' })
    t.check('pending sentence vacated', vacatedQueued.ok and vacatedQueued.value.outcome == 'vacated', t.code(vacatedQueued))
    if t.options.contracts then
        local fine = sentence('fine', { amount = 1, dueInSeconds = 3600 })
        t.check('fine waits for Contracts', fine.ok and fine.value.status == 'activating', t.code(fine))
        J.ProcessWorkflows()
        local active = t.call('GetSentence', { sentenceId = fine.value.sentenceId })
        t.check('fine obligation issued', active.ok and active.value.status == 'active', active.ok and active.value.status or t.code(active))
        local vacating = t.call('CompleteSentence', { reasonCode = 'smoke', sentenceId = fine.value.sentenceId,
            expectedRevision = active.value.revision, outcome = 'vacated' })
        J.ProcessWorkflows()
        local after = t.call('GetSentence', { sentenceId = fine.value.sentenceId })
        t.check('vacating the fine cancels its obligation', vacating.ok and after.ok and after.value.status == 'completed'
            and after.value.financialOutcome == 'cancelled', after.ok and after.value.status or t.code(vacating))
    else t.skip('fine via Contracts', 'pass contracts') end
    t.waitTerm = custodial.ok and custodial.value or nil
    t.shortWarrant = short.ok and short.value or nil
end
-- Waits for the real clock: the term sweep completes and releases, the warrant expires.
function S.Deadlines(t)
    if not t.waitTerm then return end
    print('[JusticeAcceptanceTest] waiting 65 s for the custodial term and warrant deadline (offline time counts)...')
    if t.options.fastClock then t.options.fastClock(t) else Wait(65000) end
    J.SweepSentences(); J.SweepWarrants()
    local sentence = t.call('GetSentence', { sentenceId = t.waitTerm.sentenceId })
    t.check('term completed at its UTC deadline', sentence.ok and sentence.value.status == 'completed' and sentence.value.outcome == 'served',
        sentence.ok and sentence.value.status or t.code(sentence))
    local status = t.as(t.service, 'GetCustodyStatus', { subjectCharacterId = t.subjectId })
    t.check('completion released the hold in the same transaction', status.ok and status.value.custody == nil and status.value.custodialSentence == nil)
    if t.shortWarrant then
        local warrant = t.call('GetWarrant', { warrantId = t.shortWarrant.warrantId })
        t.check('expired warrant persisted as expired', warrant.ok and warrant.value.storedStatus == 'expired', warrant.ok and warrant.value.storedStatus or t.code(warrant))
    end
end
function S.Privacy(t)
    local fx = S.Fixture(t)
    local case = t.call('GetCase', { caseId = fx.case.caseId })
    if not case.ok then return t.check('privacy case readable', false, t.code(case)) end
    if t.fixture.payableCitation then
        t.skip('sealing', 'an unsettled payable citation correctly blocks sealing')
        return
    end
    local closed = t.call('TransitionCase', { reasonCode = 'smoke', caseId = case.value.caseId, expectedRevision = case.value.revision, status = 'closed' })
    t.check('adjudicated case closed', closed.ok, t.code(closed))
    local sealRequest = { requestId = t.rid(), reasonCode = 'smoke', caseId = case.value.caseId, expectedRevision = closed.value.revision }
    local sealed = t.call('SealCase', sealRequest)
    if not t.check('closed case sealed', sealed.ok and sealed.value.status == 'sealed', t.code(sealed)) then return end
    t.check('seal replays after sealing', t.call('SealCase', J.Copy(sealRequest)).value.replayed == true)
    t.check('sealed case hidden from ordinary actor', t.call('GetCase', { caseId = case.value.caseId }).code == 'not_found')
    t.check('sealed case records hidden too', t.call('ListCharges', { caseId = case.value.caseId }).code == 'not_found')
    t.check('sealed case visible with view_sealed', t.as(t.auditor, 'GetCase', { caseId = case.value.caseId }).ok)
    local unsealed = t.as(t.auditor, 'UnsealCase', { reasonCode = 'smoke', caseId = case.value.caseId, expectedRevision = sealed.value.revision })
    t.check('unseal restores the previous status', unsealed.ok and unsealed.value.status == 'closed', t.code(unsealed))
    local resealed = t.call('SealCase', { reasonCode = 'smoke', caseId = case.value.caseId, expectedRevision = unsealed.value.revision })
    local expunged = t.as(t.auditor, 'ExpungeRecord', { reasonCode = 'smoke', caseId = case.value.caseId, expectedRevision = resealed.value.revision })
    t.check('sealed case expunged', expunged.ok and expunged.value.summary == '[expunged]' and expunged.value.expungedAt ~= nil, t.code(expunged))
    local file = t.as(t.auditor, 'GetCase', { caseId = case.value.caseId, includeRelated = true })
    local ruling = file.ok and file.value.related.ruling.items[1]
    t.check('expunge redacted related narratives', ruling and ruling.summary == '[expunged]')
    t.check('expunge cannot be undone', t.as(t.auditor, 'UnsealCase', { reasonCode = 'smoke', caseId = case.value.caseId,
        expectedRevision = expunged.value.revision }).code == 'invalid_transition')
    local history = t.as(t.auditor, 'GetRecordHistory', { recordId = case.value.caseId })
    t.check('audit history lists the case facts', history.ok and #history.value.items >= 5, t.code(history))
end

function S.Cleanup(subjectIds)
    local removed = Repo.DeleteOwnerNamespace(S.Owner)
    pcall(Repo.AccessAuditCleanup, subjectIds or {})
    pcall(J.ReloadEvidenceIndex)
    return removed
end
