ContractsObligations = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local V = ContractsValidation
local Repo = ContractsObligationRepository

local function Identity(value)
    return value
end

-- Builds audit context for a trusted server caller. Actor identity is derived
-- from Core's session for actorSource; callers can never assert actor UUIDs.
function ContractsObligations.ServerContext(resource, context)
    if context ~= nil and type(context) ~= 'table' then
        return Err('invalid_input', 'Context must be a table when provided.')
    end
    context = context or {}
    for field in pairs(context) do
        if field ~= 'actorSource' and field ~= 'correlationId' then
            return Err('invalid_input', 'Unexpected context field.', { field = tostring(field) })
        end
    end
    if context.correlationId ~= nil and not V.Text(context.correlationId, 128) then
        return Err('invalid_input', 'correlationId must be text of at most 128 characters.')
    end
    local output = { resource = resource, correlationId = context.correlationId }
    if context.actorSource ~= nil then
        local src = tonumber(context.actorSource)
        if not V.Integer(src, 1, 65535) then return Err('invalid_input', 'actorSource must be a player source.') end
        local session = exports['feather-core']:GetSessionContext(src)
        if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table' then
            return Err('character_required', 'The actor has no current character session.')
        end
        output.actorSource = src
        output.actorAccountId = session.value.accountId
        output.actorCharacterId = ContractsValidation.Lower(session.value.characterId)
    end
    return Ok(output)
end

function ContractsObligations.Authorize(action, resource, correlationId, subject)
    if Config.Authorization.enabled ~= true then return Ok(true) end
    subject = subject or {}
    subject.resource = resource
    local called, decision = pcall(function()
        return exports['feather-core']:Authorize(action, { correlationId = correlationId, subject = subject })
    end)
    if not called or type(decision) ~= 'table' or decision.ok ~= true or type(decision.value) ~= 'table'
        or decision.value.allowed ~= true then
        return Err('authorization_denied', 'Contracts policy denied the operation.', {
            action = action,
            code = called and type(decision) == 'table' and (decision.code
                or (type(decision.value) == 'table' and decision.value.code)) or 'policy_unavailable'
        })
    end
    return Ok(true)
end

function ContractsObligations.EventPayload(snapshot, previousStatus, context, extra)
    local payload = {
        obligationId = snapshot.obligationId,
        obligationType = snapshot.obligationType,
        issuerResource = snapshot.issuerResource,
        status = snapshot.status,
        previousStatus = previousStatus,
        revision = snapshot.revision,
        debtor = snapshot.debtor,
        creditor = snapshot.creditor,
        amount = snapshot.amount,
        currency = snapshot.currency,
        dueAt = snapshot.dueAt,
        sourceResource = context.resource,
        reasonCode = context.reasonCode,
        correlationId = context.correlationId
    }
    for key, value in pairs(extra or {}) do payload[key] = value end
    return payload
end

local function Party(value, allowedTypes, label, idRequired)
    if type(value) ~= 'table' then return Err('invalid_input', ('%s party required.'):format(label)) end
    for field in pairs(value) do
        if field ~= 'type' and field ~= 'id' then
            return Err('invalid_input', ('Unexpected %s party field.'):format(label))
        end
    end
    local allowed = false
    for _, entry in ipairs(allowedTypes) do if entry == value.type then allowed = true end end
    if not allowed then
        return Err('party_type_not_allowed', ('%s party type is not allowed for this obligation type.'):format(label))
    end
    if value.type == 'system' then
        if value.id ~= nil then return Err('invalid_input', ('A system %s has no id.'):format(label)) end
        return Ok({ type = 'system' })
    end
    if not V.Uuid(value.id) then return Err('invalid_input', ('%s party UUID required.'):format(label)) end
    return Ok({ type = value.type, id = value.id:lower() })
end

local function RequestId(value)
    return V.RequestId(value, Config.Limits.maximumRequestIdLength)
end

-- Applies one guarded state change in a single transaction: receipt, row lock,
-- transition check, conditional update, audit action, outbox event.
function ContractsObligations.Mutate(spec)
    local view = spec.view or Identity
    return V.Transaction(spec.label, function(tx)
        local reserved = ContractsReceipts.Reserve(tx, spec.receiptResource, spec.operation,
            spec.requestId, spec.fingerprint)
        if not reserved.ok then return reserved end
        if reserved.value.replay then return Ok(reserved.value.replay) end

        local current = Repo.Snapshot(Repo.Lock(tx, spec.obligationId))
        if not current.ok then return current end
        current = current.value
        if spec.check then
            local permitted = spec.check(current)
            if not permitted.ok then return permitted end
        end
        if spec.expectedRevision ~= nil and spec.expectedRevision ~= current.revision then
            return Err('revision_conflict', 'The obligation changed since it was read.', {
                revision = current.revision
            })
        end
        if not ContractsTypes.Allows(current.transitions, spec.transition, current.status) then
            return Err('invalid_state', 'The obligation cannot make that transition from its current status.', {
                status = current.status, transition = spec.transition
            })
        end
        if spec.blockPendingSettlement ~= false and current.settlementState == 'pending' then
            return Err('settlement_pending', 'A settlement for this obligation is still in progress.')
        end

        local change = spec.apply(current)
        local sql = 'UPDATE `contract_obligations` SET `status`=?,`revision`=`revision`+1'
        local params = { n = 1, change.status }
        for _, assignment in ipairs(change.assignments or {}) do
            sql = sql .. ',' .. assignment[1]
            for index = 2, #assignment do
                params.n = params.n + 1
                params[params.n] = assignment[index]
            end
        end
        sql = sql .. ' WHERE `obligation_id`=? AND `revision`=?'
        params[params.n + 1] = current.obligationId
        params[params.n + 2] = current.revision
        params.n = params.n + 2
        tx.exec(sql, table.unpack(params, 1, params.n))

        local updated = Repo.Snapshot(Repo.Lock(tx, current.obligationId))
        if not updated.ok then return updated end
        updated = updated.value
        if updated.revision ~= current.revision + 1 or updated.status ~= change.status then
            return Err('transaction_conflict', 'The obligation could not be updated.')
        end
        Repo.RecordAction(tx, updated.obligationId, change.actionType, current.status, updated.status,
            updated.revision, spec.context)
        if change.eventKey then
            ContractsOutbox.Record(tx, change.eventKey, updated.obligationId,
                ContractsObligations.EventPayload(updated, current.status, spec.context, change.eventExtra))
        end
        local value = view(updated)
        value.replayed = false
        ContractsReceipts.Complete(tx, spec.receiptResource, spec.operation, spec.requestId, value)
        return Ok(value)
    end)
end

local draftFields = {
    requestId = true, obligationType = true, issuer = true, debtor = true, creditor = true,
    amount = true, currency = true, dueInSeconds = true, referenceType = true, referenceId = true,
    memo = true, reasonCode = true
}

function ContractsObligations.CreateDraft(request, context, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local fields = V.Fields(request, draftFields, 'draft')
    if not fields.ok then return fields end
    local built = ContractsObligations.ServerContext(resource, context)
    if not built.ok then return built end
    context = built.value
    if not RequestId(request.requestId) or not V.Key(request.obligationType, 48) then
        return Err('invalid_input', 'Stable requestId and obligationType are required.')
    end
    local definition = ContractsTypes.RequireOwnedActive(request.obligationType, resource)
    if not definition.ok then return definition end
    definition = definition.value

    local issuer = Party(request.issuer, definition.issuerTypes, 'issuer')
    if not issuer.ok then return issuer end
    -- Types registered before debtorTypes existed accept character debtors only.
    local debtor = Party(request.debtor, definition.debtorTypes or { 'character' }, 'debtor')
    if not debtor.ok then return debtor end
    if Config.Settlement.debtorTypes[debtor.value.type] ~= true then
        return Err('debtor_type_unsupported', 'This installation cannot settle obligations from that debtor type.')
    end
    local creditor = Party(request.creditor, definition.creditorTypes, 'creditor')
    if not creditor.ok then return creditor end
    if Config.Settlement.creditorTypes[creditor.value.type] ~= true then
        return Err('creditor_type_unsupported', 'This installation cannot settle obligations to that creditor type.')
    end
    if creditor.value.type == debtor.value.type and creditor.value.id == debtor.value.id then
        return Err('invalid_input', 'Debtor and creditor must be different parties.')
    end
    if not V.Integer(request.amount, definition.minimumAmount, definition.maximumAmount) then
        return Err('invalid_amount', 'Amount must be an integer in minor units within the type bounds.', {
            minimum = definition.minimumAmount, maximum = definition.maximumAmount
        })
    end
    if not V.Key(request.currency, 32) then return Err('invalid_input', 'Currency code required.') end
    if definition.currencies then
        local allowed = false
        for _, code in ipairs(definition.currencies) do if code == request.currency then allowed = true end end
        if not allowed then return Err('currency_not_allowed', 'Currency is not allowed for this obligation type.') end
    end
    local currency = ContractsEconomy.RequireCurrency(request.currency)
    if not currency.ok then return currency end
    if not V.Integer(request.dueInSeconds, 0, definition.maximumDueSeconds) then
        return Err('invalid_input', 'dueInSeconds must be an integer within the type limit.', {
            maximum = definition.maximumDueSeconds
        })
    end
    if (request.referenceType ~= nil or request.referenceId ~= nil)
        and (not V.Code(request.referenceType, 48)
            or not V.RequestId(request.referenceId, Config.Limits.maximumReferenceLength)) then
        return Err('invalid_input', 'referenceType and referenceId must be provided together as stable codes.')
    end
    if request.memo ~= nil and not V.Text(request.memo, Config.Limits.maximumMemoLength) then
        return Err('invalid_input', 'memo must be single-line text within the configured length.')
    end
    if request.reasonCode ~= nil and not V.Code(request.reasonCode, 64) then
        return Err('invalid_input', 'reasonCode must be a stable code.')
    end
    context.reasonCode = request.reasonCode or 'contracts.draft.created'
    context.requestId = request.requestId

    local fingerprint = V.Fingerprint({ request.obligationType, issuer.value.type, issuer.value.id,
        debtor.value.type, debtor.value.id, creditor.value.type, creditor.value.id, request.amount,
        request.currency, request.dueInSeconds, request.referenceType, request.referenceId,
        request.memo, request.reasonCode })

    return V.Transaction('obligation.create_draft', function(tx)
        local reserved = ContractsReceipts.Reserve(tx, resource, 'create_draft', request.requestId, fingerprint)
        if not reserved.ok then return reserved end
        if reserved.value.replay then return Ok(reserved.value.replay) end
        local obligationId = V.NewUuid(tx)
        tx.exec([[INSERT INTO `contract_obligations`
            (`obligation_id`,`obligation_type`,`issuer_resource`,`issuer_type`,`issuer_id`,`debtor_type`,`debtor_id`,
             `creditor_type`,`creditor_id`,`amount`,`currency`,`status`,`requires_acceptance`,`debtor_may_settle`,
             `issuer_may_settle`,`debtor_may_dispute`,`due_in_seconds`,`default_after_seconds`,
             `reference_type`,`reference_id`,`memo`)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,'draft',?,?,?,?,?,?,?,?,?)]],
            obligationId, request.obligationType, resource, issuer.value.type, issuer.value.id,
            debtor.value.type, debtor.value.id, creditor.value.type, creditor.value.id,
            request.amount, request.currency,
            definition.requiresAcceptance and 1 or 0, definition.debtorMaySettle and 1 or 0,
            definition.issuerMaySettle and 1 or 0, definition.debtorMayDispute and 1 or 0,
            request.dueInSeconds, definition.defaultAfterSeconds,
            request.referenceType, request.referenceId, request.memo)
        local created = Repo.Snapshot(Repo.Lock(tx, obligationId))
        if not created.ok then return created end
        Repo.RecordAction(tx, obligationId, 'created', nil, 'draft', created.value.revision, context)
        created.value.replayed = false
        ContractsReceipts.Complete(tx, resource, 'create_draft', request.requestId, created.value)
        return created
    end)
end

local function OwnedObligation(obligationId, resource)
    if not V.Uuid(obligationId) then return Err('invalid_input', 'Obligation UUID required.') end
    local current = Repo.Get(obligationId:lower())
    if not current.ok then return current end
    if current.value.issuerResource ~= resource or ContractsTypes.Owner(current.value.obligationType) ~= resource then
        return Err('authorization_denied', 'Only the issuing resource may manage this obligation.')
    end
    return current
end

local function IssuerFields(request, label)
    return V.Fields(request, { requestId = true, obligationId = true, reasonCode = true,
        expectedRevision = true }, label)
end

local function ValidateIssuerRequest(request, label)
    local fields = IssuerFields(request, label)
    if not fields.ok then return fields end
    if not RequestId(request.requestId) or not V.Uuid(request.obligationId) then
        return Err('invalid_input', 'Stable requestId and obligation UUID are required.')
    end
    if request.reasonCode ~= nil and not V.Code(request.reasonCode, 64) then
        return Err('invalid_input', 'reasonCode must be a stable code.')
    end
    if request.expectedRevision ~= nil and not V.Integer(request.expectedRevision, 1, 9007199254740991) then
        return Err('invalid_input', 'expectedRevision must be a positive integer.')
    end
    return Ok(true)
end

function ContractsObligations.IssueObligation(request, context, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local valid = ValidateIssuerRequest(request, 'issue')
    if not valid.ok then return valid end
    local built = ContractsObligations.ServerContext(resource, context)
    if not built.ok then return built end
    context = built.value
    local current = OwnedObligation(request.obligationId, resource)
    if not current.ok then return current end
    current = current.value
    local active = ContractsTypes.RequireOwnedActive(current.obligationType, resource)
    if not active.ok then return active end
    context.reasonCode = request.reasonCode or 'contracts.obligation.issued'
    context.requestId = request.requestId

    local creditorAccountId
    if current.status == 'draft' then
        local allowed = ContractsObligations.Authorize(Config.Authorization.issueAction, resource,
            context.correlationId or request.requestId, {
                obligationType = current.obligationType, obligationId = current.obligationId,
                amount = current.amount, currency = current.currency
            })
        if not allowed.ok then return allowed end
        -- Freeze the creditor destination now; it never changes after issuance.
        local creditorAccount = ContractsEconomy.ResolveCreditorAccount(current.creditor.type,
            current.creditor.id, current.currency)
        if not creditorAccount.ok then
            return Err('creditor_account_unavailable', 'The creditor has no open account in that currency.', {
                code = creditorAccount.code
            })
        end
        local debtorWallet = ContractsEconomy.ResolveDebtorAccount(current.debtor, current.currency)
        if not debtorWallet.ok then
            return Err('debtor_account_unavailable', 'The debtor has no open account in that currency.', {
                code = debtorWallet.code
            })
        end
        if debtorWallet.value.accountId == creditorAccount.value.accountId then
            return Err('invalid_input', 'Debtor and creditor resolve to the same account.')
        end
        creditorAccountId = creditorAccount.value.accountId
    end

    return ContractsObligations.Mutate({
        label = 'obligation.issue',
        receiptResource = resource,
        operation = 'issue',
        requestId = request.requestId,
        fingerprint = V.Fingerprint({ request.obligationId:lower(), request.reasonCode, request.expectedRevision }),
        obligationId = request.obligationId:lower(),
        expectedRevision = request.expectedRevision,
        transition = 'issue',
        context = context,
        check = function(row)
            if not creditorAccountId then
                return Err('invalid_state', 'Only drafts can be issued.', { status = row.status })
            end
            if row.issuerResource ~= resource then
                return Err('authorization_denied', 'Only the issuing resource may issue this obligation.')
            end
            return Ok(true)
        end,
        apply = function(row)
            return {
                status = 'issued',
                actionType = 'issued',
                eventKey = 'issued',
                assignments = {
                    { '`creditor_account_id`=?', creditorAccountId },
                    { '`issued_at`=CURRENT_TIMESTAMP' },
                    { '`due_at`=DATE_ADD(CURRENT_TIMESTAMP, INTERVAL `due_in_seconds` SECOND)' }
                }
            }
        end
    })
end

-- Debtor actions (accept, dispute) require the acting character to be the
-- debtor. Server callers prove that with actorSource; client routes with the session.
-- A character debtor acts as the actor (Core session); an organization debtor
-- acts through the resource its treasury is bound to.
local function RequireDebtor(row, context)
    if row.debtor.type == 'organization' then
        local operator = ContractsEconomy.TreasuryOperator(row.debtor.id, row.currency)
        if operator == nil or operator ~= context.resource then
            return Err('authorization_denied', 'Only the resource operating the debtor treasury may act for it.')
        end
        return Ok(true)
    end
    if row.debtor.type ~= 'character' or context.actorCharacterId == nil
        or context.actorCharacterId ~= row.debtor.id then
        return Err('authorization_denied', 'Only the debtor may perform this action.')
    end
    return Ok(true)
end

local function RequireTypeOwnerOrClient(row, resource, viaClient)
    if viaClient then return Ok(true) end
    if ContractsTypes.Owner(row.obligationType) ~= resource then
        return Err('authorization_denied', 'Only the owning resource may act on this obligation.')
    end
    return Ok(true)
end

-- A character debtor acts through the type owner or a client route. An
-- organization debtor acts through the resource operating its treasury, which
-- RequireDebtor checks; client routes never act for an organization.
local function RequireDebtorCaller(row, resource, viaClient)
    if row.debtor.type == 'organization' then
        if viaClient then return Err('authorization_denied', 'Only the debtor may perform this action.') end
        return Ok(true)
    end
    return RequireTypeOwnerOrClient(row, resource, viaClient)
end

function ContractsObligations.AcceptObligation(request, context, resource, viaClient)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local fields = V.Fields(request, { requestId = true, obligationId = true }, 'accept')
    if not fields.ok then return fields end
    if not RequestId(request.requestId) or not V.Uuid(request.obligationId) then
        return Err('invalid_input', 'Stable requestId and obligation UUID are required.')
    end
    context.reasonCode = 'contracts.obligation.accepted'
    context.requestId = request.requestId
    return ContractsObligations.Mutate({
        label = 'obligation.accept',
        receiptResource = context.receiptResource or resource,
        operation = 'accept',
        requestId = context.receiptRequestId or request.requestId,
        fingerprint = V.Fingerprint({ request.obligationId:lower(), context.actorCharacterId }),
        obligationId = request.obligationId:lower(),
        transition = 'accept',
        context = context,
        view = context.view,
        check = function(row)
            local owner = RequireDebtorCaller(row, resource, viaClient)
            if not owner.ok then return owner end
            return RequireDebtor(row, context)
        end,
        apply = function()
            return {
                status = 'accepted', actionType = 'accepted', eventKey = 'accepted',
                assignments = { { '`accepted_at`=CURRENT_TIMESTAMP' } }
            }
        end
    })
end

function ContractsObligations.DisputeObligation(request, context, resource, viaClient)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local fields = V.Fields(request, { requestId = true, obligationId = true, reasonCode = true }, 'dispute')
    if not fields.ok then return fields end
    if not RequestId(request.requestId) or not V.Uuid(request.obligationId)
        or not V.Code(request.reasonCode, 64) then
        return Err('invalid_input', 'Stable requestId, obligation UUID, and reasonCode are required.')
    end
    context.reasonCode = request.reasonCode
    context.requestId = request.requestId
    return ContractsObligations.Mutate({
        label = 'obligation.dispute',
        receiptResource = context.receiptResource or resource,
        operation = 'dispute',
        requestId = context.receiptRequestId or request.requestId,
        fingerprint = V.Fingerprint({ request.obligationId:lower(), request.reasonCode, context.actorCharacterId }),
        obligationId = request.obligationId:lower(),
        transition = 'dispute',
        context = context,
        view = context.view,
        check = function(row)
            local owner = RequireDebtorCaller(row, resource, viaClient)
            if not owner.ok then return owner end
            return RequireDebtor(row, context)
        end,
        apply = function(row)
            return {
                status = 'disputed', actionType = 'disputed', eventKey = 'disputed',
                assignments = {
                    { '`disputed_at`=CURRENT_TIMESTAMP' },
                    { '`dispute_return_status`=?', row.status }
                }
            }
        end
    })
end

function ContractsObligations.ResolveDispute(request, context, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local fields = V.Fields(request, { requestId = true, obligationId = true, outcome = true,
        reasonCode = true, expectedRevision = true }, 'dispute resolution')
    if not fields.ok then return fields end
    if not RequestId(request.requestId) or not V.Uuid(request.obligationId)
        or (request.outcome ~= 'upheld' and request.outcome ~= 'cancelled')
        or not V.Code(request.reasonCode, 64) then
        return Err('invalid_input', 'Stable requestId, obligation UUID, outcome (upheld|cancelled), and reasonCode are required.')
    end
    if request.expectedRevision ~= nil and not V.Integer(request.expectedRevision, 1, 9007199254740991) then
        return Err('invalid_input', 'expectedRevision must be a positive integer.')
    end
    local built = ContractsObligations.ServerContext(resource, context)
    if not built.ok then return built end
    context = built.value
    local current = OwnedObligation(request.obligationId, resource)
    if not current.ok then return current end
    if request.outcome == 'cancelled' then
        local allowed = ContractsObligations.Authorize(Config.Authorization.cancelAction, resource,
            context.correlationId or request.requestId, {
                obligationType = current.value.obligationType, obligationId = current.value.obligationId
            })
        if not allowed.ok then return allowed end
    end
    context.reasonCode = request.reasonCode
    context.requestId = request.requestId
    return ContractsObligations.Mutate({
        label = 'obligation.resolve_dispute',
        receiptResource = resource,
        operation = 'resolve_dispute',
        requestId = request.requestId,
        fingerprint = V.Fingerprint({ request.obligationId:lower(), request.outcome, request.reasonCode,
            request.expectedRevision }),
        obligationId = request.obligationId:lower(),
        expectedRevision = request.expectedRevision,
        transition = 'resolveDispute',
        context = context,
        apply = function(row)
            if request.outcome == 'cancelled' then
                return {
                    status = 'cancelled', actionType = 'dispute_cancelled', eventKey = 'dispute_resolved',
                    eventExtra = { outcome = 'cancelled' },
                    assignments = { { '`cancelled_at`=CURRENT_TIMESTAMP' }, { '`dispute_return_status`=NULL' } }
                }
            end
            -- Upholding restores the status held before the dispute. A passed
            -- due date is picked up by the scheduler on its next pass.
            local restored = row.disputeReturnStatus
            if restored ~= 'issued' and restored ~= 'accepted' and restored ~= 'due' then
                restored = (row.requiresAcceptance and row.acceptedAt) and 'accepted' or 'issued'
            end
            return {
                status = restored,
                actionType = 'dispute_upheld', eventKey = 'dispute_resolved',
                eventExtra = { outcome = 'upheld' },
                assignments = { { '`dispute_return_status`=NULL' } }
            }
        end
    })
end

function ContractsObligations.CancelObligation(request, context, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local valid = ValidateIssuerRequest(request, 'cancel')
    if not valid.ok then return valid end
    if request.reasonCode == nil then return Err('invalid_input', 'reasonCode is required to cancel.') end
    local built = ContractsObligations.ServerContext(resource, context)
    if not built.ok then return built end
    context = built.value
    local current = OwnedObligation(request.obligationId, resource)
    if not current.ok then return current end
    local allowed = ContractsObligations.Authorize(Config.Authorization.cancelAction, resource,
        context.correlationId or request.requestId, {
            obligationType = current.value.obligationType, obligationId = current.value.obligationId
        })
    if not allowed.ok then return allowed end
    context.reasonCode = request.reasonCode
    context.requestId = request.requestId
    return ContractsObligations.Mutate({
        label = 'obligation.cancel',
        receiptResource = resource,
        operation = 'cancel',
        requestId = request.requestId,
        fingerprint = V.Fingerprint({ request.obligationId:lower(), request.reasonCode, request.expectedRevision }),
        obligationId = request.obligationId:lower(),
        expectedRevision = request.expectedRevision,
        transition = 'cancel',
        context = context,
        apply = function()
            return {
                status = 'cancelled', actionType = 'cancelled', eventKey = 'cancelled',
                assignments = { { '`cancelled_at`=CURRENT_TIMESTAMP' }, { '`dispute_return_status`=NULL' } }
            }
        end
    })
end

function ContractsObligations.MarkDefaulted(request, context, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local valid = ValidateIssuerRequest(request, 'default')
    if not valid.ok then return valid end
    if request.reasonCode == nil then return Err('invalid_input', 'reasonCode is required to mark a default.') end
    local built = ContractsObligations.ServerContext(resource, context)
    if not built.ok then return built end
    context = built.value
    local current = OwnedObligation(request.obligationId, resource)
    if not current.ok then return current end
    local allowed = ContractsObligations.Authorize(Config.Authorization.defaultAction, resource,
        context.correlationId or request.requestId, {
            obligationType = current.value.obligationType, obligationId = current.value.obligationId
        })
    if not allowed.ok then return allowed end
    context.reasonCode = request.reasonCode
    context.requestId = request.requestId
    return ContractsObligations.Mutate({
        label = 'obligation.default',
        receiptResource = resource,
        operation = 'default',
        requestId = request.requestId,
        fingerprint = V.Fingerprint({ request.obligationId:lower(), request.reasonCode, request.expectedRevision }),
        obligationId = request.obligationId:lower(),
        expectedRevision = request.expectedRevision,
        transition = 'default',
        context = context,
        apply = function()
            return {
                status = 'defaulted', actionType = 'defaulted', eventKey = 'defaulted',
                assignments = { { '`defaulted_at`=CURRENT_TIMESTAMP' } }
            }
        end
    })
end

local function CanRead(snapshot, resource)
    return Config.Access.trustedReaders[resource] == true
        or snapshot.issuerResource == resource
        or ContractsTypes.Owner(snapshot.obligationType) == resource
end

function ContractsObligations.GetObligation(request, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local fields = V.Fields(request, { obligationId = true }, 'obligation lookup')
    if not fields.ok then return fields end
    if not V.Uuid(request.obligationId) then return Err('invalid_input', 'Obligation UUID required.') end
    local current = Repo.Get(request.obligationId:lower())
    if not current.ok then return current end
    if not CanRead(current.value, resource) then
        -- Indistinguishable from a missing record, so callers cannot probe UUIDs.
        return Err('obligation_not_found', 'Obligation was not found.')
    end
    return current
end

local statusValues = {
    draft = true, issued = true, accepted = true, due = true, settled = true,
    cancelled = true, disputed = true, defaulted = true
}

function ContractsObligations.ValidateListOptions(request, allowParty)
    local allowed = { role = true, statuses = true, obligationType = true, limit = true, cursor = true }
    if allowParty then allowed.party = true end
    local fields = V.Fields(request or {}, allowed, 'list')
    if not fields.ok then return fields end
    request = request or {}
    local options = { role = request.role or 'debtor', limit = request.limit or 20 }
    if options.role ~= 'debtor' and options.role ~= 'creditor' then
        return Err('invalid_input', 'role must be debtor or creditor.')
    end
    if not V.Integer(options.limit, 1, Config.Limits.maximumPageSize) then
        return Err('invalid_input', 'limit is outside the configured page size.')
    end
    if request.statuses ~= nil then
        if type(request.statuses) ~= 'table' or #request.statuses > 8 then
            return Err('invalid_input', 'statuses must be a list of obligation statuses.')
        end
        options.statuses = {}
        for index = 1, #request.statuses do
            if not statusValues[request.statuses[index]] then
                return Err('invalid_input', 'statuses contains an unknown status.')
            end
            options.statuses[#options.statuses + 1] = request.statuses[index]
        end
    end
    if request.obligationType ~= nil then
        if not V.Key(request.obligationType, 48) then return Err('invalid_input', 'Invalid obligationType.') end
        options.obligationType = request.obligationType
    end
    if request.cursor ~= nil then
        if not V.Uuid(request.cursor) then return Err('invalid_input', 'cursor must be an obligation UUID.') end
        options.cursor = request.cursor:lower()
    end
    if allowParty then
        local party = request.party
        if type(party) ~= 'table' or (party.type ~= 'character' and party.type ~= 'organization')
            or not V.Uuid(party.id) then
            return Err('invalid_input', 'party with type and UUID is required.')
        end
        options.partyType, options.partyId = party.type, party.id:lower()
    end
    return Ok(options)
end

function ContractsObligations.ListPartyObligations(request, resource)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local options = ContractsObligations.ValidateListOptions(request, true)
    if not options.ok then return options end
    options = options.value
    if Config.Access.trustedReaders[resource] ~= true then
        -- Type owners may list only their own obligation types; the resource
        -- operating an organization's treasury may list that organization's.
        local operates = options.partyType == 'organization'
            and ContractsEconomy.OrganizationOperator(options.partyId) == resource
        if not operates and (not options.obligationType or ContractsTypes.Owner(options.obligationType) ~= resource) then
            return Err('authorization_denied',
                'Callers outside trustedReaders must list an obligationType they own, or an organization they operate.')
        end
    end
    return Repo.ListParty(options)
end
