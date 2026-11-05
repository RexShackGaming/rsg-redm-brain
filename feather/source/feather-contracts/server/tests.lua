local resourceName = GetCurrentResourceName()

local function Runner(label)
    local passed, total = 0, 0
    local runner = {}
    function runner.Check(name, condition)
        total = total + 1
        if condition then passed = passed + 1 end
        print(('[%s] %-34s %s'):format(label, name, condition and 'PASS' or 'FAIL'))
    end
    function runner.Done(note)
        print(('[%s] done %d/%d passed%s'):format(label, passed, total, note and (' ' .. note) or ''))
    end
    return runner
end

local function Same(left, right)
    if #left ~= #right then return false end
    for index = 1, #left do if left[index] ~= right[index] then return false end end
    return true
end

RegisterCommand('ContractsFoundationSmokeTest', function(source)
    if source ~= 0 then return end
    local t = Runner('ContractsFoundationSmokeTest')
    local capabilities = ContractsFoundation.GetCapabilities()
    local health = ContractsFoundation.GetHealth()
    t.Check('capabilities', capabilities.ok and capabilities.value.contract == 1
        and capabilities.value.features.settlement == 1 and capabilities.value.features.amendments == 0)
    t.Check('health ready', health.state == 'ready' and health.checks.migrations ~= nil
        and health.checks['feather-economy'] ~= nil and health.checks.events ~= nil)
    t.Check('migration ledger', tonumber(DB.value(
        "SELECT COUNT(*) FROM `contract_schema_migrations` WHERE `id` IN ('001_contracts_foundation',"
            .. "'002_settlement_economy_check','003_organization_debtors')")) == 3)

    local accepted = ContractsTypes.Transitions(true, true)
    local direct = ContractsTypes.Transitions(false, false)
    t.Check('acceptance transitions', Same(accepted.accept, { 'issued' })
        and Same(accepted.settle, { 'accepted', 'due', 'defaulted' })
        and Same(accepted.markDue, { 'accepted' }))
    t.Check('direct transitions', #direct.accept == 0 and #direct.dispute == 0
        and Same(direct.settle, { 'issued', 'due', 'defaulted' }))
    t.Check('settled is terminal', not ContractsTypes.Allows(accepted, 'cancel', 'settled')
        and not ContractsTypes.Allows(accepted, 'settle', 'settled')
        and not ContractsTypes.Allows(accepted, 'settle', 'disputed'))

    local base = { typeKey = 'smoke_type', label = 'Smoke', issuerTypes = { 'system' },
        creditorTypes = { 'system' } }
    t.Check('valid definition normalizes', ContractsTypes.Normalize(base).ok)
    local badKey = ContractsTypes.Normalize({ typeKey = 'Bad-Key', label = 'x', issuerTypes = { 'system' },
        creditorTypes = { 'system' } })
    t.Check('invalid key rejected', not badKey.ok and badKey.code == 'invalid_input')
    local extra = ContractsTypes.Normalize({ typeKey = 'smoke_type', label = 'x', issuerTypes = { 'system' },
        creditorTypes = { 'system' }, balance = 10 })
    t.Check('unknown field rejected', not extra.ok and extra.code == 'invalid_input')
    local unsettleable = ContractsTypes.Normalize({ typeKey = 'smoke_type', label = 'x', issuerTypes = { 'system' },
        creditorTypes = { 'system' }, debtorMaySettle = false, issuerMaySettle = false })
    t.Check('unsettleable type rejected', not unsettleable.ok)
    local organization = ContractsTypes.Normalize({ typeKey = 'smoke_type', label = 'x',
        issuerTypes = { 'organization' }, creditorTypes = { 'organization' }, debtorTypes = { 'organization' } })
    if Config.Settlement.creditorTypes.organization ~= true then
        t.Check('organization creditor gated', not organization.ok
            and organization.code == 'creditor_type_unsupported')
    else
        t.Check('organization parties allowed', organization.ok)
    end
    local untrusted = ContractsTypes.Register(base, 'untrusted-smoke-resource')
    t.Check('untrusted issuer rejected', not untrusted.ok and untrusted.code == 'authorization_denied')
    local draft = ContractsObligations.CreateDraft({}, nil, 'untrusted-smoke-resource')
    t.Check('invalid draft rejected', not draft.ok and draft.code == 'invalid_input')
    local read = ContractsObligations.GetObligation({ obligationId = '00000000-0000-0000-0000-000000000099' },
        'untrusted-smoke-resource')
    t.Check('missing obligation hidden', not read.ok and read.code == 'obligation_not_found')
    local list = ContractsObligations.ListPartyObligations({ party = { type = 'character',
        id = '00000000-0000-0000-0000-000000000099' } }, 'untrusted-smoke-resource')
    t.Check('unscoped list rejected', not list.ok and list.code == 'authorization_denied')
    local reconcile = ContractsSettlement.Reconcile('untrusted-smoke-resource')
    t.Check('untrusted reconcile rejected', not reconcile.ok and reconcile.code == 'authorization_denied')

    if Config.ClientRoutes.enabled then
        local routes = exports['feather-core']:GetRPCRoutes()
        local owned = {}
        for _, route in ipairs(type(routes) == 'table' and routes.ok and routes.value or {}) do
            if route.owner == resourceName and route.requireCharacter == true then owned[route.route] = true end
        end
        local all = true
        for _, name in ipairs(ContractsRoutes.Names()) do all = all and owned[name] == true end
        t.Check('client routes registered', all)
    end
    t.Done('(read-only)')
end, true)

RegisterCommand('ContractsAuditSmokeTest', function(source)
    if source ~= 0 then return end
    local t = Runner('ContractsAuditSmokeTest')
    local outbox = ContractsOutbox.GetState()
    t.Check('outbox running', outbox.ok and outbox.value.running == true)
    t.Check('scheduler running', ContractsScheduler.IsRunning())
    t.Check('outbox states valid', tonumber(DB.value(
        "SELECT COUNT(*) FROM `contract_outbox` WHERE `status` NOT IN ('pending','published')")) == 0)
    local audit = ContractsSettlement.Audit()
    for _, key in ipairs({ 'settledWithoutCommittedSettlement', 'committedSettlementNotSettled',
        'pendingFlagWithoutSettlement', 'pendingSettlementWithoutFlag', 'multipleCommitted', 'amountMismatch' }) do
        t.Check(key, audit[key] == 0)
    end
    t.Check('issued have frozen creditor', tonumber(DB.value([[SELECT COUNT(*) FROM `contract_obligations`
        WHERE `status`<>'draft' AND `issued_at` IS NOT NULL AND `creditor_account_id` IS NULL]])) == 0)
    t.Check('terminal timestamps present', tonumber(DB.value([[SELECT COUNT(*) FROM `contract_obligations`
        WHERE (`status`='settled' AND `settled_at` IS NULL) OR (`status`='cancelled' AND `cancelled_at` IS NULL)
           OR (`status`='defaulted' AND `defaulted_at` IS NULL)]])) == 0)
    t.Check('every obligation audited', tonumber(DB.value([[SELECT COUNT(*) FROM `contract_obligations` o
        WHERE NOT EXISTS (SELECT 1 FROM `contract_actions` a WHERE a.`obligation_id`=o.`obligation_id`)]])) == 0)
    t.Done(('pending=%s published=%s pendingSettlements=%s stuck=%s (read-only)'):format(
        tostring(outbox.ok and outbox.value.pending), tostring(outbox.ok and outbox.value.published),
        tostring(audit.pendingSettlements), tostring(audit.stuckSettlements)))
end, true)

RegisterCommand('ContractsReleaseSmokeTest', function(source)
    if source ~= 0 then return end
    local t = Runner('ContractsReleaseSmokeTest')
    local registered = {}
    local callable = type(GetRegisteredCommands) == 'function'
    if callable then
        for _, command in ipairs(GetRegisteredCommands() or {}) do
            if type(command) == 'table' and type(command.name) == 'string' then registered[command.name] = true end
        end
    end
    t.Check('service ready', ContractsFoundation.IsReady())
    t.Check('development disabled', Config.DevMode == false)
    t.Check('policy enabled', Config.Authorization.enabled == true)
    t.Check('self not trusted issuer', Config.Access.trustedIssuers[resourceName] ~= true)
    t.Check('development commands absent', callable and registered.ContractsLiveTest ~= true
        and registered.ContractsOrganizationTest ~= true)
    t.Check('reconcile command available', registered.ContractsReconcile == true)
    t.Done('(read-only)')
end, true)

if not Config.DevMode then return end

-- Development acceptance. When the debtor has at least 0.02 of the chosen
-- currency it moves 0.01 to the creditor and 0.01 to the system sink (the
-- Economy timeout recovery check), and it leaves one defaulted 0.01 obligation
-- as evidence of due/default processing.
RegisterCommand('ContractsLiveTest', function(source, args)
    if source ~= 0 then return end
    -- Each party is a connected player's server id or a character UUID; nobody
    -- needs to be online. Debtor actions run with a context built from that
    -- character (what Core's session supplies for a connected player).
    local function Character(value)
        local src = tonumber(value)
        if src then
            local session = exports['feather-core']:GetSessionContext(src)
            return type(session) == 'table' and session.ok and session.value.characterId:lower() or nil
        end
        return ContractsValidation.Uuid(value) and value:lower() or nil
    end
    local debtorId, creditorId = Character(args and args[1]), Character(args and args[2])
    local runId, currency = args and args[3], (args and args[4]) or 'dollars'
    if not debtorId or not creditorId or debtorId == creditorId
        or type(runId) ~= 'string' or not runId:match('^[A-Za-z0-9][A-Za-z0-9_-]*$') or #runId > 40 then
        print('[ContractsLiveTest] usage: ContractsLiveTest <debtor id|character UUID> '
            .. '<creditor id|character UUID> <fresh runId> [currency]')
        return
    end
    local t = Runner('ContractsLiveTest')
    local function Actor(characterId) return { resource = resourceName, actorCharacterId = characterId } end
    local function key(suffix) return ('live-%s-%s'):format(runId, suffix) end
    local typed = ContractsTypes.Register({ typeKey = 'contracts_smoke_invoice', label = 'Smoke invoice',
        requiresAcceptance = true, debtorMayDispute = true, issuerTypes = { 'character' },
        creditorTypes = { 'character', 'system' } }, resourceName)
    t.Check('type registered', typed.ok)
    local overdueType = ContractsTypes.Register({ typeKey = 'contracts_smoke_fine', label = 'Smoke fine',
        defaultAfterSeconds = 0, issuerTypes = { 'system' }, creditorTypes = { 'system' } }, resourceName)
    t.Check('second type registered', overdueType.ok)
    if not typed.ok or not overdueType.ok then return t.Done() end

    local draftRequest = { requestId = key('draft'), obligationType = 'contracts_smoke_invoice',
        issuer = { type = 'character', id = creditorId }, debtor = { type = 'character', id = debtorId },
        creditor = { type = 'character', id = creditorId }, amount = 1, currency = currency,
        dueInSeconds = 3600, referenceType = 'smoke', referenceId = runId }
    local draft = ContractsObligations.CreateDraft(draftRequest, nil, resourceName)
    local replay = ContractsObligations.CreateDraft(draftRequest, nil, resourceName)
    t.Check('draft created', draft.ok and draft.value.status == 'draft')
    t.Check('draft replayed', replay.ok and replay.value.replayed == true
        and draft.ok and replay.value.obligationId == draft.value.obligationId)
    local changed = {}
    for field, value in pairs(draftRequest) do changed[field] = value end
    changed.amount = 2
    local conflict = ContractsObligations.CreateDraft(changed, nil, resourceName)
    t.Check('payload reuse rejected', not conflict.ok and conflict.code == 'idempotency_conflict')
    if not draft.ok then return t.Done() end
    local id = draft.value.obligationId

    local issued = ContractsObligations.IssueObligation({ requestId = key('issue'), obligationId = id }, nil, resourceName)
    t.Check('issued', issued.ok and issued.value.status == 'issued' and issued.value.creditorAccountId ~= nil)
    if not issued.ok then
        print(('[ContractsLiveTest] issue failed code=%s; with policy enabled, grant feather-contracts '
            .. 'its own service actions in feather-admin servicePolicy for this test'):format(tostring(issued.code)))
        return t.Done()
    end
    local early = ContractsSettlement.SettleObligation({ requestId = key('early'), obligationId = id },
        Actor(debtorId), resourceName, false)
    t.Check('settle before accept rejected', not early.ok and early.code == 'invalid_state')
    local wrongActor = ContractsObligations.AcceptObligation({ requestId = key('accept-wrong'), obligationId = id },
        Actor(creditorId), resourceName, false)
    t.Check('non-debtor accept rejected', not wrongActor.ok and wrongActor.code == 'authorization_denied')
    local accepted = ContractsObligations.AcceptObligation({ requestId = key('accept'), obligationId = id },
        Actor(debtorId), resourceName, false)
    t.Check('debtor accepted', accepted.ok and accepted.value.status == 'accepted')

    local settleRequest = { requestId = key('settle'), obligationId = id }
    local settled = ContractsSettlement.SettleObligation(settleRequest, Actor(debtorId), resourceName, false)
    if settled.ok then
        local again = ContractsSettlement.SettleObligation(settleRequest, Actor(debtorId), resourceName, false)
        local second = ContractsSettlement.SettleObligation({ requestId = key('settle-2'), obligationId = id },
            Actor(debtorId), resourceName, false)
        t.Check('settled with transaction', settled.value.status == 'settled'
            and settled.value.settlementTransactionId ~= nil)
        t.Check('settlement replayed', again.ok and again.value.replayed == true
            and again.value.settlementTransactionId == settled.value.settlementTransactionId)
        t.Check('no double payment', not second.ok and second.code == 'invalid_state')
        t.Check('one committed settlement', tonumber(DB.value([[SELECT COUNT(*) FROM `contract_settlements`
            WHERE `obligation_id`=? AND `status`='committed']], id)) == 1)

        -- Economy timeout after the money moved: the reply is dropped, the
        -- settlement stays pending, and a replay with the same key finishes it
        -- without a second transfer.
        local lostDraft = ContractsObligations.CreateDraft({ requestId = key('t-draft'),
            obligationType = 'contracts_smoke_invoice', issuer = { type = 'character', id = creditorId },
            debtor = { type = 'character', id = debtorId }, creditor = { type = 'system' }, amount = 1,
            currency = currency, dueInSeconds = 3600 }, nil, resourceName)
        local lostId = lostDraft.ok and lostDraft.value.obligationId
        local lostReady = lostId and ContractsObligations.IssueObligation({ requestId = key('t-issue'),
            obligationId = lostId }, nil, resourceName) or lostDraft
        lostReady = lostReady.ok and ContractsObligations.AcceptObligation({ requestId = key('t-accept'),
            obligationId = lostId }, Actor(debtorId), resourceName, false) or lostReady
        if lostReady.ok then
            -- The debtor's balance, read through Economy's exports (never its tables).
            local function Balance()
                local wallet = ContractsEconomy.ResolveDebtorAccount({ type = 'character', id = debtorId }, currency)
                return wallet.ok and tonumber(wallet.value.balance) or nil
            end
            local before = Balance()
            ContractsEconomy.simulatedLostReplies = 1
            local lost = ContractsSettlement.SettleObligation({ requestId = key('t-settle'), obligationId = lostId },
                Actor(debtorId), resourceName, false)
            ContractsEconomy.simulatedLostReplies = 0
            local pendingRow = DB.one([[SELECT `settlement_id` FROM `contract_settlements`
                WHERE `obligation_id`=? AND `status`='pending']], lostId)
            t.Check('timeout leaves settlement pending', not lost.ok and lost.code == 'settlement_pending'
                and pendingRow ~= nil)
            t.Check('money moved during timeout', before ~= nil and Balance() == before - 1)
            ContractsSettlement.ProcessPending(Config.Scheduler.batchSize, true)
            local recovered = ContractsObligationRepository.Get(lostId)
            t.Check('replay settles after timeout', recovered.ok and recovered.value.status == 'settled'
                and recovered.value.settlementState == 'none')
            t.Check('no second transfer after timeout', before ~= nil and Balance() == before - 1)
        else
            t.Check('timeout obligation ready', false)
        end
        if ContractsEconomy.CanReadTransactions() then
            ContractsSettlement.VerifyWithEconomy(Config.Settlement.verifyBatchSize)
            t.Check('settlements match economy journal', tonumber(DB.value([[SELECT COUNT(*)
                FROM `contract_settlements` WHERE `obligation_id` IN (?,?) AND `status`='committed'
                AND `economy_check`='verified']], id, lostId or id)) == (lostId and 2 or 1))
        else
            print('[ContractsLiveTest] feather-economy has no GetTransaction; journal check skipped')
        end
    else
        t.Check('insufficient funds reported', settled.code == 'insufficient_funds')
        local after = ContractsObligationRepository.Get(id)
        t.Check('obligation still payable', after.ok and after.value.status == 'accepted'
            and after.value.settlementState == 'none')
        local cancelled = ContractsObligations.CancelObligation({ requestId = key('cancel'), obligationId = id,
            reasonCode = 'smoke.cleanup' }, nil, resourceName)
        t.Check('unpaid obligation cancelled', cancelled.ok and cancelled.value.status == 'cancelled')
    end

    local disputeDraft = ContractsObligations.CreateDraft({ requestId = key('d-draft'),
        obligationType = 'contracts_smoke_invoice', issuer = { type = 'character', id = creditorId },
        debtor = { type = 'character', id = debtorId }, creditor = { type = 'system' }, amount = 1,
        currency = currency, dueInSeconds = 3600 }, nil, resourceName)
    local disputeId = disputeDraft.ok and disputeDraft.value.obligationId
    local disputeIssued = disputeId and ContractsObligations.IssueObligation({ requestId = key('d-issue'),
        obligationId = disputeId }, nil, resourceName) or disputeDraft
    local disputed = disputeIssued.ok and ContractsObligations.DisputeObligation({ requestId = key('d-dispute'),
        obligationId = disputeId, reasonCode = 'smoke.amount' }, Actor(debtorId), resourceName, false) or disputeIssued
    t.Check('debtor disputed', disputed.ok and disputed.value.status == 'disputed')
    local upheld = disputed.ok and ContractsObligations.ResolveDispute({ requestId = key('d-resolve'),
        obligationId = disputeId, outcome = 'upheld', reasonCode = 'smoke.upheld' }, nil, resourceName) or disputed
    t.Check('dispute upheld restores status', upheld.ok and upheld.value.status == 'issued')
    local stale = upheld.ok and ContractsObligations.CancelObligation({ requestId = key('d-stale'),
        obligationId = disputeId, reasonCode = 'smoke.cleanup', expectedRevision = 1 }, nil, resourceName) or upheld
    t.Check('stale revision rejected', not stale.ok and stale.code == 'revision_conflict')
    local cleaned = upheld.ok and ContractsObligations.CancelObligation({ requestId = key('d-cancel'),
        obligationId = disputeId, reasonCode = 'smoke.cleanup' }, nil, resourceName) or upheld
    t.Check('disputed obligation cancelled', cleaned.ok and cleaned.value.status == 'cancelled')

    local fineDraft = ContractsObligations.CreateDraft({ requestId = key('f-draft'),
        obligationType = 'contracts_smoke_fine', issuer = { type = 'system' },
        debtor = { type = 'character', id = debtorId }, creditor = { type = 'system' }, amount = 1,
        currency = currency, dueInSeconds = 0 }, nil, resourceName)
    local fineId = fineDraft.ok and fineDraft.value.obligationId
    local fineIssued = fineId and ContractsObligations.IssueObligation({ requestId = key('f-issue'),
        obligationId = fineId }, nil, resourceName) or fineDraft
    if fineIssued.ok then
        Wait(1500)
        ContractsScheduler.RunOnce()
        local overdue = ContractsObligationRepository.Get(fineId)
        t.Check('scheduler marked due then defaulted', overdue.ok and overdue.value.status == 'defaulted')
        local actions = DB.query([[SELECT `action_type` FROM `contract_actions` WHERE `obligation_id`=?
            ORDER BY `created_at`,`action_id`]], fineId) or {}
        local seen = {}
        for _, row in ipairs(actions) do seen[row.action_type] = true end
        t.Check('due and default audited', seen.due == true and seen.defaulted == true)
    else
        t.Check('fine issued', false)
    end
    local audit = ContractsSettlement.Audit()
    t.Check('settlement integrity', audit.settledWithoutCommittedSettlement == 0
        and audit.committedSettlementNotSettled == 0 and audit.multipleCommitted == 0)
    t.Done(('run=%s'):format(runId))
end, true)

-- Development acceptance for organization parties. Nobody needs to be online.
-- Uses an organization whose treasury is bound to an operator resource (for
-- example a business run by a society resource). Moves 0.01 from the character
-- into the treasury (organization creditor), then 0.01 from the treasury to the
-- system sink (organization debtor), so the treasury ends where it started. The
-- operator's own actions are run in its name through the service layer.
--   ContractsOrganizationTest <character id|UUID> <organizationUuid> <fresh runId> [currency]
RegisterCommand('ContractsOrganizationTest', function(source, args)
    if source ~= 0 then return end
    local function Character(value)
        local src = tonumber(value)
        if src then
            local session = exports['feather-core']:GetSessionContext(src)
            return type(session) == 'table' and session.ok and session.value.characterId:lower() or nil
        end
        return ContractsValidation.Uuid(value) and value:lower() or nil
    end
    local characterId = Character(args and args[1])
    local organizationId = ContractsValidation.Uuid(args and args[2]) and args[2]:lower() or nil
    local runId, currency = args and args[3], (args and args[4]) or 'dollars'
    if not characterId or not organizationId or type(runId) ~= 'string'
        or not runId:match('^[A-Za-z0-9][A-Za-z0-9_-]*$') or #runId > 40 then
        print('[ContractsOrganizationTest] usage: ContractsOrganizationTest <character id|UUID> '
            .. '<organizationUuid> <fresh runId> [currency]')
        return
    end
    local operator = ContractsEconomy.TreasuryOperator(organizationId, currency)
    if not operator then
        return print('[ContractsOrganizationTest] the organization has no treasury bound to an operator resource')
    end
    local t = Runner('ContractsOrganizationTest')
    local function key(suffix) return ('org-%s-%s'):format(runId, suffix) end
    local function Treasury()
        local accounts = exports['feather-economy']:FindAccountsByOwner({ ownerType = 'organization', ownerId = organizationId })
        for _, account in ipairs(accounts.ok and accounts.value or {}) do
            if account.accountType == 'treasury' and account.currency == currency then return account end
        end
    end
    local function Actor(id) return { resource = resourceName, actorCharacterId = id } end
    local function As(resource) return { resource = resource } end
    print(('[ContractsOrganizationTest] organization %s, treasury operator %s'):format(organizationId, operator))

    local typed = ContractsTypes.Register({ typeKey = 'contracts_smoke_org', label = 'Smoke organization bill',
        requiresAcceptance = true, issuerMaySettle = true, issuerTypes = { 'system' },
        creditorTypes = { 'character', 'organization', 'system' }, debtorTypes = { 'character', 'organization' } },
        resourceName)
    t.Check('organization type registered', typed.ok)
    if not typed.ok then return t.Done() end
    local treasury = Treasury()
    local start = treasury and treasury.balance or 0

    -- The organization is owed: a character pays into its treasury.
    local owed = ContractsObligations.CreateDraft({ requestId = key('c-draft'), obligationType = 'contracts_smoke_org',
        issuer = { type = 'system' }, debtor = { type = 'character', id = characterId },
        creditor = { type = 'organization', id = organizationId }, amount = 1, currency = currency,
        dueInSeconds = 3600 }, nil, resourceName)
    local owedId = owed.ok and owed.value.obligationId
    local owedIssued = owedId and ContractsObligations.IssueObligation({ requestId = key('c-issue'),
        obligationId = owedId }, nil, resourceName) or owed
    t.Check('creditor treasury frozen at issue', owedIssued.ok and treasury ~= nil
        and owedIssued.value.creditorAccountId == treasury.accountId)
    if not owedIssued.ok then
        print(('[ContractsOrganizationTest] issue failed code=%s'):format(tostring(owedIssued.code)))
        return t.Done()
    end
    local owedAccepted = ContractsObligations.AcceptObligation({ requestId = key('c-accept'), obligationId = owedId },
        Actor(characterId), resourceName, false)
    local paidIn = owedAccepted.ok and ContractsSettlement.SettleObligation({ requestId = key('c-settle'),
        obligationId = owedId }, Actor(characterId), resourceName, false) or owedAccepted
    local afterIn = Treasury()
    t.Check('character paid the organization', paidIn.ok and paidIn.value.status == 'settled'
        and afterIn ~= nil and afterIn.balance == start + 1)

    -- The organization owes: only its treasury operator may act for it.
    local owes = ContractsObligations.CreateDraft({ requestId = key('d-draft'), obligationType = 'contracts_smoke_org',
        issuer = { type = 'system' }, debtor = { type = 'organization', id = organizationId },
        creditor = { type = 'system' }, amount = 1, currency = currency, dueInSeconds = 3600 }, nil, resourceName)
    local owesId = owes.ok and owes.value.obligationId
    local owesIssued = owesId and ContractsObligations.IssueObligation({ requestId = key('d-issue'),
        obligationId = owesId }, nil, resourceName) or owes
    t.Check('organization debt issued', owesIssued.ok and owesIssued.value.status == 'issued')
    local wrongAccept = owesIssued.ok and ContractsObligations.AcceptObligation({ requestId = key('d-accept-wrong'),
        obligationId = owesId }, As(resourceName), resourceName, false) or owesIssued
    t.Check('non-operator cannot accept for it', not wrongAccept.ok and wrongAccept.code == 'authorization_denied')
    local accepted = owesIssued.ok and ContractsObligations.AcceptObligation({ requestId = key('d-accept'),
        obligationId = owesId }, As(operator), operator, false) or owesIssued
    t.Check('operator accepted for it', accepted.ok and accepted.value.status == 'accepted')
    local issuerPays = accepted.ok and ContractsSettlement.SettleObligation({ requestId = key('d-settle-issuer'),
        obligationId = owesId }, As(resourceName), resourceName, false) or accepted
    t.Check('issuer cannot spend its treasury', not issuerPays.ok and issuerPays.code == 'settlement_not_allowed')
    local paidOut = accepted.ok and ContractsSettlement.SettleObligation({ requestId = key('d-settle'),
        obligationId = owesId }, As(operator), operator, false) or accepted
    local afterOut = Treasury()
    t.Check('operator paid from the treasury', paidOut.ok and paidOut.value.status == 'settled'
        and afterOut ~= nil and afterOut.balance == start)

    if ContractsEconomy.CanReadTransactions() then
        ContractsSettlement.VerifyWithEconomy(Config.Settlement.verifyBatchSize)
        t.Check('both settlements match economy journal', tonumber(DB.value([[SELECT COUNT(*)
            FROM `contract_settlements` WHERE `obligation_id` IN (?,?) AND `status`='committed'
            AND `economy_check`='verified']], owedId, owesId or owedId)) == 2)
    end
    t.Done(('run=%s treasury %s -> %s'):format(runId, tostring(start), tostring(afterOut and afterOut.balance)))
end, true)
