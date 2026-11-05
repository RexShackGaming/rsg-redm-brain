-- Evidence guard and reconciliation, retention, and judicial edge cases.
return function(t)
    local J = Justice
    local juris = t.call('RegisterJurisdiction', { reasonCode = 'setup', jurisdictionKey = 'bcc-law:court', label = 'Court',
        jurisdictionType = 'court_district' }, { service = true }).value
    local statute = t.call('RegisterStatute', { reasonCode = 'setup', jurisdictionId = juris.jurisdictionId, statuteKey = 'bcc-law:court.assault',
        title = 'Assault', category = 'violence', severityClass = 'felony' }, { service = true }).value
    local function open(title)
        local case = t.call('OpenCase', { reasonCode = 'test', jurisdictionId = juris.jurisdictionId, caseType = 'criminal', title = title, summary = 'Narrative ' .. title }).value
        return case
    end

    -- Evidence ------------------------------------------------------------------
    J.InstallEvidenceGuard()
    local guard = t.guards['feather-justice:evidence']
    local case = open('Evidence')
    local link = t.call('LinkEvidence', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1, evidenceType = 'inventory_item',
        evidenceId = '501', relationship = 'collected', subjectCharacterId = t.subject })
    t.check('inventory evidence verified', link.ok and link.value.itemName == 'evidence_knife', t.code(link))
    t.check('guard vetoes destroying linked evidence', guard({ id = 501 }) == false and guard({ id = 503 }) == true)
    t.check('unknown item refused', t.call('LinkEvidence', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1,
        evidenceType = 'inventory_item', evidenceId = '999', relationship = 'collected' }).code == 'evidence_not_found')
    t.check('malformed instance id refused', t.call('LinkEvidence', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1,
        evidenceType = 'inventory_item', evidenceId = '01x', relationship = 'collected' }).code == 'invalid_input')
    local destroyed = t.call('RemoveEvidenceLink', { reasonCode = 'test', evidenceLinkId = link.value.evidenceLinkId, expectedRevision = 1, disposition = 'destroyed' })
    t.check('disposition recorded and guard released', destroyed.ok and destroyed.value.disposition == 'destroyed' and guard({ id = 501 }) == true)
    local letter = t.call('LinkEvidence', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1, evidenceType = 'inventory_item',
        evidenceId = '502', relationship = 'exhibit' })
    t.items[502] = nil
    local reconciled = J.ReconcileEvidence(10)
    t.check('item deleted outside Justice marked missing', reconciled.ok and reconciled.value.missing == 1
        and t.sql.value('SELECT status FROM justice_evidence_links WHERE evidence_link_id=?', letter.value.evidenceLinkId) == 'missing')
    t.stopped['feather-inventory'] = true
    t.check('Inventory outage fails closed for item evidence', t.call('LinkEvidence', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1,
        evidenceType = 'inventory_item', evidenceId = '501', relationship = 'collected' }).code == 'inventory_unavailable')
    t.check('external evidence unaffected by an Inventory outage', t.call('LinkEvidence', { reasonCode = 'test', caseId = case.caseId,
        expectedCaseRevision = 1, evidenceType = 'external', evidenceId = t.uuid(800), relationship = 'submitted' }).ok)
    t.stopped['feather-inventory'] = nil
    J.RemoveEvidenceGuard()
    t.check('guard unregistered when Justice stops', t.guards['feather-justice:evidence'] == nil)

    -- Rulings ---------------------------------------------------------------------
    local trial = open('Trial')
    local function charge(subject)
        local proposed = t.call('ProposeCharge', { reasonCode = 'test', caseId = trial.caseId, expectedCaseRevision = 1, defendantCharacterId = subject,
            statuteId = statute.statuteId, count = 1 }).value
        return t.call('FileCharge', { reasonCode = 'test', chargeId = proposed.chargeId, expectedRevision = 1 }).value
    end
    local first, second = charge(t.subject), charge(t.other)
    t.call('TransitionCase', { reasonCode = 'test', caseId = trial.caseId, expectedRevision = 1, status = 'filed' })
    local verdict = { reasonCode = 'test', caseId = trial.caseId, expectedCaseRevision = 2, rulingType = 'verdict', subjectCharacterId = t.subject,
        summary = 'Reasons.', findings = { { chargeId = first.chargeId, finding = 'convicted' } } }
    t.check('ruling needs the case judge', t.call('RecordRuling', J.Copy(verdict)).code == 'judge_required')
    t.call('AddCaseParty', { reasonCode = 'test', caseId = trial.caseId, expectedCaseRevision = 2, partyType = 'character', partyIdReference = t.actor, partyRole = 'judge' })
    local wrong = J.Copy(verdict); wrong.findings = { { chargeId = second.chargeId, finding = 'convicted' } }
    local wrongResult = t.call('RecordRuling', wrong)
    t.check("findings limited to the subject's filed charges", wrongResult.code == 'charge_not_filed', t.code(wrongResult))
    local extra = t.call('ProposeCharge', { reasonCode = 'test', caseId = trial.caseId, expectedCaseRevision = 2, defendantCharacterId = t.subject,
        statuteId = statute.statuteId, count = 2 }).value
    t.call('FileCharge', { reasonCode = 'test', chargeId = extra.chargeId, expectedRevision = 1 })
    local partial = t.call('RecordRuling', J.Copy(verdict))
    t.check('every filed charge of the subject needs a finding', partial.code == 'findings_incomplete', t.code(partial))
    verdict.findings[2] = { chargeId = extra.chargeId, finding = 'acquitted' }
    verdict.requestId = 'verdict-1'
    local recorded = t.call('RecordRuling', J.Copy(verdict))
    t.check('verdict recorded', recorded.ok and recorded.value.outcome == 'convicted', t.code(recorded))
    t.check('verdict replay with table findings', t.call('RecordRuling', J.Copy(verdict)).value.replayed == true)
    t.check('case not adjudicated while another defendant is open', t.call('GetCase', { caseId = trial.caseId }).value.status == 'filed')
    local dismissal = t.call('RecordRuling', { reasonCode = 'test', caseId = trial.caseId, expectedCaseRevision = 2, rulingType = 'dismissal',
        subjectCharacterId = t.other, summary = 'Dismissed.' })
    t.check('dismissal for the other defendant', dismissal.ok and dismissal.value.outcome == 'dismissed', t.code(dismissal))
    local after = t.call('GetCase', { caseId = trial.caseId }).value
    t.check('last ruling with nothing open left decides the case status', after.status == 'dismissed', after.status)

    -- Sentences --------------------------------------------------------------------
    local court = open('Sentencing')
    t.call('AddCaseParty', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 1, partyType = 'character', partyIdReference = t.actor, partyRole = 'judge' })
    local filed = (function()
        local proposed = t.call('ProposeCharge', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 1, defendantCharacterId = t.subject,
            statuteId = statute.statuteId, count = 1 }).value
        return t.call('FileCharge', { reasonCode = 'test', chargeId = proposed.chargeId, expectedRevision = 1 }).value
    end)()
    local warrantDraft = t.call('CreateWarrantDraft', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 1, subjectCharacterId = t.subject,
        warrantType = 'arrest', basisSummary = 'Grounds.', validForSeconds = 600 }).value
    local warrant = t.call('IssueWarrant', { reasonCode = 'test', warrantId = warrantDraft.warrantId, expectedRevision = 1 }).value
    local arrest = t.call('RecordArrest', { reasonCode = 'test', caseId = court.caseId, authorityType = 'warrant', authorityId = warrant.warrantId,
        expectedAuthorityRevision = warrant.revision })
    t.check('arrest serves the warrant', arrest.ok and t.call('GetWarrant', { warrantId = warrant.warrantId }).value.status == 'served', t.code(arrest))
    t.policy.denied['justice.warrant.serve'] = true
    t.check('arrest needs warrant-serve authority too', t.call('RecordArrest', { reasonCode = 'test', caseId = court.caseId, authorityType = 'warrant',
        authorityId = warrant.warrantId, expectedAuthorityRevision = warrant.revision }).code == 'authorization_denied')
    t.policy.denied['justice.warrant.serve'] = nil
    t.call('TransitionCase', { reasonCode = 'test', caseId = court.caseId, expectedRevision = 1, status = 'filed' })
    local ruling = t.call('RecordRuling', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 2, rulingType = 'verdict', subjectCharacterId = t.subject,
        summary = 'Guilty.', findings = { { chargeId = filed.chargeId, finding = 'convicted' } } }).value
    local order = t.call('RecordRuling', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 3, rulingType = 'order', outcome = 'bail_set', summary = 'Bail.' })
    t.check('order ruling recorded without effects', order.ok and order.value.outcome == 'bail_set', t.code(order))
    t.check('sentence requires a convicting verdict', t.call('CreateSentence', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 3,
        rulingId = order.value.rulingId, sentenceType = 'fine', terms = { amount = 5, dueInSeconds = 600 } }).code == 'conviction_required')
    t.check('sentence terms are typed', t.call('CreateSentence', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 3,
        rulingId = ruling.rulingId, sentenceType = 'custodial', terms = { termSeconds = 120, cell = 4 } }).code == 'invalid_input')
    local created = t.call('CreateSentence', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 3, rulingId = ruling.rulingId,
        sentenceType = 'custodial', terms = { termSeconds = 120 } }).value
    local active = t.call('ActivateSentence', { reasonCode = 'test', sentenceId = created.sentenceId, expectedRevision = 1 }).value
    t.check('custodial sentence active', active.status == 'active' and active.endsAt == active.startsAt + 120000)
    t.check('service mode may not commute', t.call('CompleteSentence', { reasonCode = 'test', sentenceId = created.sentenceId, expectedRevision = 2,
        outcome = 'commuted' }, { service = true }).code == 'authorization_denied')
    t.check('service mode may not serve a custodial term', t.call('CompleteSentence', { reasonCode = 'test', sentenceId = created.sentenceId, expectedRevision = 2,
        outcome = 'served' }, { service = true }).code == 'authorization_denied')
    t.check('custody of the same case still unreleased', t.call('GetCustodyStatus', { subjectCharacterId = t.subject }).value.custody.status == 'arrested')
    t.ago('justice_sentences', 'ends_at', 'sentence_id', created.sentenceId, 1000)
    t.check('sweep completes the term', J.SweepSentences() == 1)
    local done = t.call('GetSentence', { sentenceId = created.sentenceId }).value
    t.check('term served at its deadline', done.status == 'completed' and done.outcome == 'served' and done.completedByCharacterId == nil)
    local status = t.call('GetCustodyStatus', { subjectCharacterId = t.subject }).value
    t.check('same-case custody released in the same transaction', status.custody == nil and status.custodialSentence == nil)
    t.check('second sweep finds nothing', J.SweepSentences() == 0)

    -- Warrant expiry is persisted once.
    local short = t.call('CreateWarrantDraft', { reasonCode = 'test', caseId = court.caseId, expectedCaseRevision = 3, subjectCharacterId = t.other,
        warrantType = 'summons', basisSummary = 'Appear.', validForSeconds = 60 })
    t.check('no drafting on an adjudicated case', short.code == 'case_closed')

    -- Retention: delivered outbox ages out; closed narratives redacted only when configured.
    t.sql.exec('UPDATE justice_outbox SET delivered=1, created_at=1')
    local dry = J.RunRetention(true)
    t.check('retention dry run counts aged outbox rows', dry.outbox > 0 and dry.redacted == 0)
    J.RunRetention(false)
    t.check('retention purged delivered outbox rows', tonumber(t.sql.value('SELECT COUNT(*) FROM justice_outbox WHERE created_at=1')) == 0)
    JusticeConfig.Retention.RedactClosedCaseNarrativesDays = 1
    t.sql.exec('UPDATE justice_audit_events SET created_at=1 WHERE record_id=?', trial.caseId)
    local redacted = J.RunRetention(false)
    JusticeConfig.Retention.RedactClosedCaseNarrativesDays = nil
    local trialCase = t.call('GetCase', { caseId = trial.caseId }).value
    t.check('old dismissed case narrative redacted', redacted.redacted >= 1 and trialCase.summary == '[redacted]' and trialCase.title == 'Trial')
end
