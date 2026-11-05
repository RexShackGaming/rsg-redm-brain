ContractsObligationRepository = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local V = ContractsValidation

local function Millis(column)
    return ('UNIX_TIMESTAMP(`%s`)*1000 AS `%s_ms`'):format(column, column)
end

local selectColumns = table.concat({
    '`obligation_id`', '`obligation_type`', '`issuer_resource`', '`issuer_type`', '`issuer_id`',
    '`debtor_type`', '`debtor_id`', '`creditor_type`', '`creditor_id`', '`creditor_account_id`',
    '`amount`', '`currency`', '`status`', '`requires_acceptance`', '`debtor_may_settle`',
    '`issuer_may_settle`', '`debtor_may_dispute`', '`due_in_seconds`', '`default_after_seconds`',
    '`reference_type`', '`reference_id`', '`memo`', '`settlement_state`',
    '`settlement_transaction_id`', '`dispute_return_status`', '`revision`',
    Millis('due_at'), Millis('created_at'), Millis('issued_at'), Millis('accepted_at'),
    Millis('settled_at'), Millis('cancelled_at'), Millis('disputed_at'), Millis('defaulted_at')
}, ',')

ContractsObligationRepository.SelectSql = 'SELECT ' .. selectColumns .. ' FROM `contract_obligations`'

local function Bool(value)
    return value == true or tonumber(value) == 1
end

local function Time(value)
    local number = tonumber(value)
    return number and math.floor(number) or nil
end

function ContractsObligationRepository.Snapshot(row)
    if type(row) ~= 'table' then return Err('obligation_not_found', 'Obligation was not found.') end
    if not V.Uuid(row.obligation_id) or not V.Key(row.obligation_type, 48)
        or tonumber(row.amount) == nil or tonumber(row.revision) == nil then
        return Err('invalid_persistence', 'Persisted obligation is invalid.')
    end
    local requiresAcceptance = Bool(row.requires_acceptance)
    local debtorMayDispute = Bool(row.debtor_may_dispute)
    return Ok({
        obligationId = row.obligation_id,
        obligationType = row.obligation_type,
        issuerResource = row.issuer_resource,
        issuer = { type = row.issuer_type, id = row.issuer_id },
        debtor = { type = row.debtor_type, id = row.debtor_id },
        creditor = { type = row.creditor_type, id = row.creditor_id },
        creditorAccountId = row.creditor_account_id,
        amount = math.floor(tonumber(row.amount)),
        currency = row.currency,
        status = row.status,
        requiresAcceptance = requiresAcceptance,
        debtorMaySettle = Bool(row.debtor_may_settle),
        issuerMaySettle = Bool(row.issuer_may_settle),
        debtorMayDispute = debtorMayDispute,
        dueInSeconds = tonumber(row.due_in_seconds),
        defaultAfterSeconds = tonumber(row.default_after_seconds),
        dueAt = Time(row.due_at_ms),
        referenceType = row.reference_type,
        referenceId = row.reference_id,
        memo = row.memo,
        settlementState = row.settlement_state,
        settlementTransactionId = row.settlement_transaction_id,
        disputeReturnStatus = row.dispute_return_status,
        revision = math.floor(tonumber(row.revision)),
        createdAt = Time(row.created_at_ms),
        issuedAt = Time(row.issued_at_ms),
        acceptedAt = Time(row.accepted_at_ms),
        settledAt = Time(row.settled_at_ms),
        cancelledAt = Time(row.cancelled_at_ms),
        disputedAt = Time(row.disputed_at_ms),
        defaultedAt = Time(row.defaulted_at_ms),
        transitions = ContractsTypes.Transitions(requiresAcceptance, debtorMayDispute)
    })
end

-- The client view drops routing details that only server consumers need.
function ContractsObligationRepository.ClientView(snapshot)
    local view = ContractsFoundation.Copy(snapshot)
    view.creditorAccountId = nil
    view.issuerResource = nil
    view.transitions = nil
    view.disputeReturnStatus = nil
    return view
end

function ContractsObligationRepository.Get(obligationId)
    return ContractsObligationRepository.Snapshot(DB.one(
        ContractsObligationRepository.SelectSql .. ' WHERE `obligation_id`=?', obligationId))
end

function ContractsObligationRepository.Lock(tx, obligationId)
    return tx.one(ContractsObligationRepository.SelectSql .. ' WHERE `obligation_id`=? FOR UPDATE', obligationId)
end

function ContractsObligationRepository.RecordAction(tx, obligationId, actionType, fromStatus, toStatus,
    revision, context, economyTransactionId)
    local actionId = V.NewUuid(tx)
    tx.exec([[INSERT INTO `contract_actions`
        (`action_id`,`obligation_id`,`action_type`,`from_status`,`to_status`,`revision`,`source_resource`,
         `actor_account_id`,`actor_character_id`,`reason_code`,`correlation_id`,`request_id`,`economy_transaction_id`)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)]],
        actionId, obligationId, actionType, fromStatus, toStatus, revision, context.resource,
        context.actorAccountId, context.actorCharacterId, context.reasonCode or actionType,
        context.correlationId, context.requestId, economyTransactionId)
    return actionId
end

-- Bounded, cursor-paginated party listing. The cursor is the last obligation UUID seen.
function ContractsObligationRepository.ListParty(options)
    local column = options.role == 'creditor' and 'creditor' or 'debtor'
    local sql = ContractsObligationRepository.SelectSql
        .. (' WHERE `%s_type`=? AND `%s_id`=?'):format(column, column)
    local params = { options.partyType, options.partyId }
    if options.statuses and #options.statuses > 0 then
        local marks = {}
        for _, status in ipairs(options.statuses) do
            marks[#marks + 1] = '?'
            params[#params + 1] = status
        end
        sql = sql .. ' AND `status` IN (' .. table.concat(marks, ',') .. ')'
    end
    if options.excludeDrafts then sql = sql .. " AND `status`<>'draft'" end
    if options.obligationType then
        sql = sql .. ' AND `obligation_type`=?'
        params[#params + 1] = options.obligationType
    end
    if options.cursor then
        local cursor = DB.one([[SELECT DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `contract_obligations` WHERE `obligation_id`=?]], options.cursor)
        if not cursor then return Err('invalid_cursor', 'List cursor was not found.') end
        sql = sql .. ' AND (`created_at`<? OR (`created_at`=? AND `obligation_id`<?))'
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = options.cursor
    end
    sql = sql .. ' ORDER BY `created_at` DESC,`obligation_id` DESC LIMIT ?'
    params[#params + 1] = options.limit + 1
    local rows = DB.query(sql, table.unpack(params)) or {}
    local items = {}
    for index = 1, math.min(#rows, options.limit) do
        local snapshot = ContractsObligationRepository.Snapshot(rows[index])
        if not snapshot.ok then return snapshot end
        items[#items + 1] = snapshot.value
    end
    local nextCursor
    if #rows > options.limit then nextCursor = items[#items].obligationId end
    return Ok({ items = items, nextCursor = nextCursor })
end
