-- Contracts workflows: citation and sentence obligations, failure injection,
-- settlement/default mirroring, cancellation races and event wake-ups.
return function(t)
    local J = Justice
    local function due() t.sql.exec('UPDATE justice_workflows SET next_attempt_at=0') end
    local function workflow(id) return t.sql.one('SELECT attempts, last_code FROM justice_workflows WHERE record_id=?', id) end
    local juris = t.call('RegisterJurisdiction', { reasonCode = 'setup', jurisdictionKey = 'bcc-law:money', label = 'Money',
        jurisdictionType = 'county' }, { service = true }).value
    local statute = t.call('RegisterStatute', { reasonCode = 'setup', jurisdictionId = juris.jurisdictionId, statuteKey = 'bcc-law:money.fraud',
        title = 'Fraud', category = 'fraud', severityClass = 'felony' }, { service = true }).value
    local case = t.call('OpenCase', { reasonCode = 'test', jurisdictionId = juris.jurisdictionId, caseType = 'criminal', title = 'Money', summary = 'M' }).value

    -- Citation: refused issuance retries; default mirrored; settlement only from Contracts.
    t.contracts.refuseIssue = true
    local citation = t.call('IssueCitation', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1, subjectCharacterId = t.subject,
        statuteId = statute.statuteId, basisSummary = 'Fine.', amount = 25, dueInSeconds = 3600 })
    t.check('payable citation pending', citation.ok and citation.value.status == 'pending', t.code(citation))
    J.ProcessWorkflows()
    t.check('Contracts refusal recorded and retried later', workflow(citation.value.citationId).last_code == 'authorization_denied')
    t.check('citation stays pending while Contracts refuses', t.call('GetCitation', { citationId = citation.value.citationId }).value.status == 'pending')
    t.contracts.refuseIssue = false
    due(); J.ProcessWorkflows()
    local issued = t.call('GetCitation', { citationId = citation.value.citationId }).value
    t.check('obligation issued with due time', issued.status == 'issued' and J.Uuid(issued.contractsObligationId)
        and issued.dueAt ~= nil and issued.dueAt >= issued.issuedAt + 3600000, issued.status)
    local obligation = t.obligations[issued.contractsObligationId]
    t.check('obligation terms frozen from the citation', obligation.amount == 25 and obligation.debtor.id == t.subject
        and obligation.referenceType == 'justice_citation' and obligation.issuerMaySettle == false)
    obligation.status = 'defaulted'; due(); J.ProcessWorkflows()
    t.check('default mirrored, still payable', t.call('GetCitation', { citationId = citation.value.citationId }).value.status == 'defaulted')
    obligation.status = 'settled'
    t.subscribers['contracts.obligation.settled.v1']({ issuerResource = 'feather-justice', obligationId = obligation.obligationId })
    t.check('settlement event brings the check forward', t.sql.value('SELECT next_attempt_at FROM justice_workflows WHERE record_id=?', citation.value.citationId) == 0)
    J.ProcessWorkflows()
    t.check('settled only after Contracts confirms', t.call('GetCitation', { citationId = citation.value.citationId }).value.status == 'settled'
        and workflow(citation.value.citationId) == nil)

    -- Sentences need a conviction by the case judge.
    t.call('AddCaseParty', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1, partyType = 'character', partyIdReference = t.actor, partyRole = 'judge' })
    local charge = t.call('ProposeCharge', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 1, defendantCharacterId = t.subject,
        statuteId = statute.statuteId, count = 1 }).value
    t.call('FileCharge', { reasonCode = 'test', chargeId = charge.chargeId, expectedRevision = 1 })
    t.call('TransitionCase', { reasonCode = 'test', caseId = case.caseId, expectedRevision = 1, status = 'filed' })
    local verdict = t.call('RecordRuling', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 2, rulingType = 'verdict',
        subjectCharacterId = t.subject, summary = 'Guilty.', findings = { { chargeId = charge.chargeId, finding = 'convicted' } } }).value
    local function sentence(kind, terms)
        local created = t.call('CreateSentence', { reasonCode = 'test', caseId = case.caseId, expectedCaseRevision = 3, rulingId = verdict.rulingId,
            sentenceType = kind, terms = terms })
        return t.call('ActivateSentence', { reasonCode = 'test', sentenceId = created.value.sentenceId, expectedRevision = 1 }).value
    end
    local fine = sentence('fine', { amount = 40, dueInSeconds = 3600 })
    t.check('fine activating', fine.status == 'activating')
    t.check('cannot complete while Contracts is pending', t.call('CompleteSentence', { reasonCode = 'test', sentenceId = fine.sentenceId,
        expectedRevision = fine.revision, outcome = 'vacated' }).code == 'workflow_pending')
    J.ProcessWorkflows()
    local active = t.call('GetSentence', { sentenceId = fine.sentenceId }).value
    t.check('fine obligation issued', active.status == 'active' and J.Uuid(active.contractsObligationId))
    t.check('fine cannot be marked served by hand', t.call('CompleteSentence', { reasonCode = 'test', sentenceId = fine.sentenceId,
        expectedRevision = active.revision, outcome = 'served' }).code == 'settlement_required')
    t.obligations[active.contractsObligationId].status = 'defaulted'; due(); J.ProcessWorkflows()
    t.check('sentence default mirrored', t.call('GetSentence', { sentenceId = fine.sentenceId }).value.financialOutcome == 'defaulted')
    t.obligations[active.contractsObligationId].status = 'settled'; due(); J.ProcessWorkflows()
    local paid = t.call('GetSentence', { sentenceId = fine.sentenceId }).value
    t.check('settlement completes the fine', paid.status == 'completed' and paid.outcome == 'served' and paid.financialOutcome == 'settled')

    -- Restitution: the victim is the creditor; paid before the vacate reaches Contracts.
    local restitution = sentence('restitution', { amount = 15, dueInSeconds = 3600, creditorCharacterId = t.other })
    J.ProcessWorkflows()
    local owed = t.call('GetSentence', { sentenceId = restitution.sentenceId }).value
    t.check('restitution owed to the victim', t.obligations[owed.contractsObligationId].creditor.id == t.other)
    t.obligations[owed.contractsObligationId].status = 'settled'
    local vacate = t.call('CompleteSentence', { reasonCode = 'test', sentenceId = owed.sentenceId, expectedRevision = owed.revision, outcome = 'vacated' })
    t.check('vacate waits for Contracts', vacate.ok and vacate.value.status == 'completing', t.code(vacate))
    J.ProcessWorkflows()
    local raced = t.call('GetSentence', { sentenceId = owed.sentenceId }).value
    t.check('payment that won the race completes as served, never refunded', raced.status == 'completed' and raced.outcome == 'served'
        and raced.financialOutcome == 'settled')

    -- Tampered obligation terms are refused, not mirrored.
    local tampered = sentence('fine', { amount = 70, dueInSeconds = 3600 })
    J.ProcessWorkflows()
    local issuedFine = t.call('GetSentence', { sentenceId = tampered.sentenceId }).value
    t.obligations[issuedFine.contractsObligationId].amount = 1
    t.obligations[issuedFine.contractsObligationId].status = 'settled'
    due(); J.ProcessWorkflows()
    t.check('obligation mismatch detected and not mirrored', workflow(tampered.sentenceId).last_code == 'obligation_mismatch'
        and t.call('GetSentence', { sentenceId = tampered.sentenceId }).value.status == 'active')
    -- Sealing waits for every financial record to finish.
    t.call('TransitionCase', { reasonCode = 'test', caseId = case.caseId, expectedRevision = 3, status = 'closed' })
    t.check('unfinished sentence blocks sealing', t.call('SealCase', { reasonCode = 'test', caseId = case.caseId, expectedRevision = 4 }).code == 'seal_blocked')
end
