-- Cross-domain workflows with Contracts (master plan: Cross-domain workflows).
-- Separate resources cannot share a transaction: durable state, idempotent
-- requests, retry and reconciliation. Contracts records obligations, Economy
-- settles them; Justice stores the obligation UUID and mirrors confirmed state.
local J, Repo, M = Justice, Justice.Repo, Justice.Mutation
local obligationStates = { draft = true, issued = true, accepted = true, due = true, defaulted = true, disputed = true, settled = true, cancelled = true }

local function Terms(kind, row)
    if kind == 'citation' then
        return { amount = row.amount, dueInSeconds = row.due_in_seconds, debtor = row.subject_character_id, creditor = { type = 'system' },
            referenceType = 'justice_citation', label = 'Justice citation', memo = 'Justice citation' }
    end
    local t = row.terms_json
    return { amount = t.amount, dueInSeconds = t.dueInSeconds, debtor = row.defendant_character_id,
        creditor = row.sentence_type == 'restitution' and { type = 'character', id = t.creditorCharacterId } or { type = 'system' },
        referenceType = 'justice_sentence', label = row.sentence_type == 'fine' and 'Justice sentence fine' or 'Justice sentence restitution',
        memo = row.sentence_type == 'fine' and 'Court fine' or 'Court-ordered restitution' }
end
local function Verify(result, kind, row, knownId)
    local o = result.ok and result.value
    local terms = Terms(kind, row)
    return type(o) == 'table' and J.Uuid(o.obligationId) and o.issuerResource == 'feather-justice' and o.obligationType == row.type_key
        and type(o.debtor) == 'table' and o.debtor.type == 'character' and o.debtor.id == terms.debtor
        and type(o.creditor) == 'table' and o.creditor.type == terms.creditor.type and o.creditor.id == terms.creditor.id
        and o.amount == terms.amount and o.currency == row.currency and o.dueInSeconds == terms.dueInSeconds
        and o.referenceType == terms.referenceType and o.referenceId == row[Repo.Specs[kind].id]
        and o.requiresAcceptance == false and o.debtorMaySettle == true and o.issuerMaySettle == false
        and o.debtorMayDispute == false and obligationStates[o.status] == true
        and (knownId == nil or o.obligationId == knownId)
end
local function RegisterType(kind, row)
    local terms = Terms(kind, row)
    -- Frozen, versioned type. Config changes never rewrite issued terms.
    return J.Call('feather-contracts', 'RegisterObligationType', {
        typeKey = row.type_key, label = terms.label, issuerTypes = { 'system' }, creditorTypes = { terms.creditor.type },
        debtorTypes = { 'character' }, requiresAcceptance = false, debtorMaySettle = true, issuerMaySettle = false,
        debtorMayDispute = false, currencies = { row.currency }, minimumAmount = 1, maximumAmount = 1000000000000,
        maximumDueSeconds = 31536000 })
end
local function Issue(kind, row)
    local registered = RegisterType(kind, row); if not registered.ok then return registered end
    local terms, id = Terms(kind, row), row[Repo.Specs[kind].id]
    local draft = J.Call('feather-contracts', 'CreateDraft', { requestId = 'justice:' .. kind .. ':draft:' .. id,
        obligationType = row.type_key, issuer = { type = 'system' }, creditor = terms.creditor,
        debtor = { type = 'character', id = terms.debtor }, amount = terms.amount, currency = row.currency,
        dueInSeconds = terms.dueInSeconds, referenceType = terms.referenceType, referenceId = id, memo = terms.memo,
        reasonCode = 'justice.' .. kind .. '.issue' })
    if not draft.ok then return draft end
    if not Verify(draft, kind, row) then return J.Err('obligation_mismatch', 'Contracts terms differ.') end
    local issued = J.Call('feather-contracts', 'IssueObligation', { requestId = 'justice:' .. kind .. ':issue:' .. id,
        obligationId = draft.value.obligationId, reasonCode = 'justice.' .. kind .. '.issue' })
    if not issued.ok then return issued end
    if not Verify(issued, kind, row) or issued.value.status == 'draft' then return J.Err('obligation_mismatch', 'Issuance not confirmed.') end
    return J.Ok(issued.value)
end
local function Observe(kind, row)
    local observed = J.Call('feather-contracts', 'GetObligation', { obligationId = row.contracts_obligation_id })
    if not observed.ok then return observed end
    if not Verify(observed, kind, row, row.contracts_obligation_id) then return J.Err('obligation_mismatch', 'Contracts terms differ.') end
    return J.Ok(observed.value.status)
end

-- One system transition per observed (status, revision); retries replay the receipt.
local function Advance(kind, id, owner, seen, fact, apply, generation)
    local request = { requestId = 'justice:workflow:' .. id .. ':' .. seen.status .. ':' .. seen.revision,
        reasonCode = 'justice.workflow.reconcile', workflowRecordId = id }
    return M.Run(fact, request, 'feather-justice', { generation = generation, system = true }, function(tx, context)
        Repo.Get(tx.one, 'case', seen.case_id, owner, true)
        local row = Repo.Get(tx.one, kind, id, owner, true)
        if not row or row.status ~= seen.status or row.revision ~= seen.revision then return J.Err('revision_conflict', 'Workflow advanced.') end
        local changes, keep, nulls = apply(tx, row, context)
        changes.revision = row.revision + 1
        Repo.Update(tx, kind, id, changes, nulls)
        for key, value in pairs(changes) do row[key] = value end
        if keep then Repo.Wake(tx, kind, id, JusticeConfig.Sentences.SettlementCheckSeconds * 1000)
        else Repo.DeleteWorkflow(tx, id) end
        return J.Ok(kind == 'citation' and J.CitationSnapshot(row) or J.SentenceSnapshot(row))
    end)
end

local function ProcessCitation(row, owner, generation)
    if row.status == 'pending' then
        local issued = Issue('citation', row); if not issued.ok then return issued end
        return Advance('citation', row.citation_id, owner, row, 'citation.obligation_issued', function(_, current, context)
            return { status = 'issued', contracts_obligation_id = issued.value.obligationId,
                due_at = context.now + current.due_in_seconds * 1000 }, true
        end, generation)
    end
    if row.status ~= 'issued' and row.status ~= 'defaulted' then return 'done' end
    local status = Observe('citation', row); if not status.ok then return status end
    if status.value == 'settled' then
        return Advance('citation', row.citation_id, owner, row, 'citation.settled', function() return { status = 'settled' }, false end, generation)
    elseif status.value == 'defaulted' and row.status == 'issued' then
        return Advance('citation', row.citation_id, owner, row, 'citation.defaulted', function() return { status = 'defaulted' }, true end, generation)
    end
    return J.Err('settlement_pending', 'Obligation not settled yet.')
end
local function Finish(row, owner, generation, outcome, financialOutcome)
    return Advance('sentence', row.sentence_id, owner, row, 'sentence.completed', function(tx, current, context)
        local changes, nulls = J.CloseSentence(tx, current, outcome, context, owner)
        changes.financial_outcome = financialOutcome
        return changes, false, nulls
    end, generation)
end
local function ProcessSentence(row, owner, generation)
    if row.status == 'activating' then
        local issued = Issue('sentence', row); if not issued.ok then return issued end
        return Advance('sentence', row.sentence_id, owner, row, 'sentence.obligation_issued', function(_, _, context)
            return { status = 'active', contracts_obligation_id = issued.value.obligationId, activated_at = context.now,
                starts_at = context.now }, true
        end, generation)
    end
    if row.status == 'completing' then
        local cancelled = J.Call('feather-contracts', 'CancelObligation', { requestId = 'justice:sentence:cancel:' .. row.sentence_id,
            obligationId = row.contracts_obligation_id, reasonCode = 'justice.sentence.' .. tostring(row.outcome) })
        local status = Observe('sentence', row)
        if status.ok and status.value == 'cancelled' then return Finish(row, owner, generation, row.outcome, 'cancelled') end
        -- Paid before the cancellation reached Contracts: satisfied, never refunded here.
        if status.ok and status.value == 'settled' then return Finish(row, owner, generation, 'served', 'settled') end
        return cancelled.ok and J.Err('settlement_pending', 'Cancellation not confirmed.') or cancelled
    end
    if row.status ~= 'active' then return 'done' end
    local status = Observe('sentence', row); if not status.ok then return status end
    if status.value == 'settled' then return Finish(row, owner, generation, 'served', 'settled') end
    if status.value == 'cancelled' then return Finish(row, owner, generation, 'vacated', 'cancelled') end
    if status.value == 'defaulted' and row.financial_outcome == nil then
        return Advance('sentence', row.sentence_id, owner, row, 'sentence.defaulted', function() return { financial_outcome = 'defaulted' }, true end, generation)
    end
    return J.Err('settlement_pending', 'Obligation not settled yet.')
end

local working = false
function J.ProcessWorkflows()
    if working or not J.Ready() then return end
    working = true
    local generation = J.Generation()
    local c = JusticeConfig.Sentences
    local ok, failure = pcall(function()
        for _, due in ipairs(Repo.DueWorkflows(c.BatchSize)) do
            if not J.Ready() or generation ~= J.Generation() then return end
            local owner = due.owner_resource
            local row = owner and Repo.Get(DB.one, due.record_kind, due.record_id, owner)
            -- Defer before external calls so a hung record does not starve its peers.
            local waiting = row and (row.status == 'pending' or row.status == 'activating' or row.status == 'completing')
            Repo.DeferWorkflow(due.record_id, (waiting and c.RetrySeconds or c.SettlementCheckSeconds) * 1000, 'pending')
            local called, result = pcall(function()
                if not row then return 'done' end
                if due.record_kind == 'citation' then return ProcessCitation(row, owner, generation) end
                return ProcessSentence(row, owner, generation)
            end)
            if called and result == 'done' then
                DB.transaction(function(tx) Repo.DeleteWorkflow(tx, due.record_id); return true end)
            elseif not called or type(result) ~= 'table' or not result.ok then
                local code = called and type(result) == 'table' and J.Token(result.code, 64) and result.code or 'operation_failed'
                Repo.WorkflowCode(due.record_id, code)
            end
        end
    end)
    working = false
    if not ok then print('[feather-justice] event=workflow.retry error=' .. tostring(type(failure) == 'table' and failure.code or 'lua')) end
end

-- Contracts events only bring a check forward; the obligation read stays authoritative.
local subscriptions = {}
function J.SubscribeContracts()
    for _, name in ipairs({ 'contracts.obligation.settled.v1', 'contracts.obligation.defaulted.v1', 'contracts.obligation.cancelled.v1' }) do
        if not subscriptions[name] then
            local result = J.Call('feather-core', 'SubscribeEvent', name, function(payload)
                if type(payload) ~= 'table' or payload.issuerResource ~= 'feather-justice' or not J.Uuid(payload.obligationId) then return end
                pcall(Repo.WakeObligation, payload.obligationId)
            end)
            if result.ok then subscriptions[name] = true end
        end
    end
end
function J.ResetContractSubscriptions() subscriptions = {} end
