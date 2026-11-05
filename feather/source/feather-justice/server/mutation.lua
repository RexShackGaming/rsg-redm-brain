-- Mutation controls (master plan: Shared Contract 1 conventions): server-derived
-- actor, named policy action, validation, idempotency, transaction and locks,
-- optimistic revision, correlation ID and audit context, committed event.
local J, Repo = Justice, Justice.Repo
local M = {}
J.Mutation = M

local common = { requestId = true, reasonCode = true, actorSource = true, correlationId = true }
-- Validates request fields; mutations also need requestId/reasonCode (and an optional correlationId).
function M.Fields(request, extras, mutation)
    local fields = mutation and J.Copy(common) or { actorSource = true }
    for _, field in ipairs(extras) do fields[field] = true end
    if not J.Fields(request, fields) then return false end
    if not mutation then return true end
    return J.Token(request.requestId, 128) and J.Token(request.reasonCode, 64)
        and (request.correlationId == nil or J.Token(request.correlationId, 128))
end

-- Public snapshot: plan column names in camelCase, *_json columns decoded under
-- their plain name, plus `kind` and `recordId`. Never a repository row.
local function Camel(name) return (name:gsub('_(%l)', string.upper)) end
function M.Snapshot(kind, row, extra)
    if not row then return nil end
    local spec = Repo.Specs[kind]
    local out = { kind = kind, recordId = row[spec.id] }
    for column, value in pairs(row) do
        if spec.columns[column] == 'json' then out[Camel(column:gsub('_json$', ''))] = J.Copy(value)
        elseif spec.columns[column] then out[Camel(column)] = value end
    end
    for key, value in pairs(extra or {}) do out[key] = value end
    return out
end
-- Safe event payload: identifiers and state only, never narrative text.
local function Payload(eventId, snapshot)
    local subject = snapshot.subjectCharacterId or snapshot.defendantCharacterId
        or (snapshot.partyType == 'character' and snapshot.partyIdReference or nil)
    return { eventId = eventId, kind = snapshot.kind, recordId = snapshot.recordId, revision = snapshot.revision,
        status = snapshot.status, caseId = snapshot.caseId, jurisdictionId = snapshot.jurisdictionId,
        subjectCharacterId = subject }
end

-- Canonical, order-independent encoding; nested tables (findings, terms) are
-- encoded by sorted key so an identical retry always has the same fingerprint.
local function Canonical(value, depth)
    if type(value) ~= 'table' then return type(value) .. ':' .. tostring(value) end
    if depth > 4 then error('request_too_deep') end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do
        local encoded = Canonical(value[key], depth + 1)
        parts[#parts + 1] = #tostring(key) .. ':' .. tostring(key) .. #encoded .. ':' .. encoded
    end
    return 'table{' .. table.concat(parts, ',') .. '}'
end
local function Signature(operation, request, actor)
    local keys, parts = {}, { operation, actor.characterId or 'system' }
    for key in pairs(request) do
        if key ~= 'actorSource' and key ~= 'requestId' and key ~= 'correlationId' then keys[#keys + 1] = key end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local value = Canonical(request[key], 1)
        parts[#parts + 1] = #key .. ':' .. key .. #value .. ':' .. value
    end
    return table.concat(parts, '|')
end

-- Per-transaction caches keyed by the wrapped tx.one: case-access decisions.
J.TxMemo = setmetatable({}, { __mode = 'k' })
local function Wrap(tx)
    local wrapped, now = {}, nil
    for key, value in pairs(tx) do wrapped[key] = value end
    wrapped.one = function(...) return tx.one(...) end
    wrapped.value = function(sql, ...)
        if sql == J.NowSql and now then return now end
        return tx.value(sql, ...)
    end
    J.TxMemo[wrapped.one] = { access = {} }
    return wrapped, function(value) now = value end
end

-- Secondary fact for another record changed in the same transaction.
function M.Fact(tx, snapshot, fact, context)
    local eventId = J.NewUuid()
    Repo.AuditFact(tx, { eventId = eventId, kind = snapshot.kind, recordId = snapshot.recordId,
        fact = 'justice.' .. fact .. '.v1', source = context.owner, actorId = context.actor.characterId,
        reasonCode = context.request.reasonCode, correlationId = context.request.correlationId,
        revision = snapshot.revision, now = context.now, payload = Payload(eventId, snapshot) })
end

-- body(tx, context) returns J.Ok(snapshot) or an error envelope. context carries
-- owner, actor, request and the transaction's database time (context.now).
function M.Run(operation, request, owner, actor, body)
    local result
    local executed, committed = pcall(DB.transaction, function(raw)
        local tx, setNow = Wrap(raw)
        local ok, outcome = pcall(function()
            local fingerprint = J.Sha256(Signature(operation, request, actor))
            local receipt = Repo.ClaimReceipt(tx, owner, request.requestId, fingerprint, actor.characterId)
            if not receipt or receipt.fingerprint ~= fingerprint then
                return J.Err('idempotency_conflict', 'Request ID is bound to another operation or payload.')
            end
            local now = math.tointeger(tonumber(receipt.now_ms)) or tonumber(receipt.now_ms)
            if not now then error('invalid_database_time') end
            setNow(now)
            if not J.Current(actor) then return J.Err('session_expired', 'Actor context changed.') end
            if receipt.result_json then
                local stored = json.decode(receipt.result_json)
                if type(stored) ~= 'table' then error('invalid_receipt') end
                -- Replays still require current access to the parent case.
                local caseId = stored.kind == 'case' and stored.recordId or stored.caseId
                if caseId and not actor.system and not J.CaseAllowed(tx.one, Repo.Get(tx.one, 'case', caseId, owner, true), actor, true) then
                    return J.Err('not_found', 'Record unavailable.')
                end
                stored.replayed = true
                return J.Ok(stored)
            end
            local context = { owner = owner, actor = actor, request = request, now = now }
            local answer = body(tx, context)
            if not answer.ok then return answer end
            if not J.Current(actor) then return J.Err('session_expired', 'Actor context changed.') end
            local snapshot = answer.value
            local eventId = J.NewUuid()
            Repo.AuditFact(tx, { eventId = eventId, kind = snapshot.kind, recordId = snapshot.recordId,
                fact = 'justice.' .. operation .. '.v1', source = owner, actorId = actor.characterId,
                reasonCode = request.reasonCode, correlationId = request.correlationId, revision = snapshot.revision,
                now = now, payload = Payload(eventId, snapshot) })
            snapshot.replayed = false
            Repo.StoreReceipt(tx, owner, request.requestId, snapshot.kind, snapshot.recordId, snapshot)
            if not J.Current(actor) then return J.Err('session_expired', 'Actor context changed.') end
            return answer
        end)
        if not ok then
            -- Codes only: database errors can carry values, code errors stay one short line.
            local detail = type(outcome) == 'table' and ('code=' .. tostring(outcome.code) .. ' sqlState=' .. tostring(outcome.sqlState))
                or ('error=' .. tostring(outcome):match('^[^\n]*'):sub(1, 160))
            print('[feather-justice] event=transaction.error operation=' .. operation .. ' ' .. detail)
        end
        result = ok and outcome or J.Err('transaction_failed', 'Transaction failed; retry the same request ID.')
        return result.ok == true
    end)
    if not executed or (result and result.ok and committed ~= true) then
        return J.Err('transaction_failed', 'Commit was not confirmed; retry the same request ID.')
    end
    if result and result.ok and not J.Current(actor) then
        return J.Err('session_expired', 'Actor changed after commit; reuse the same request ID to recover.')
    end
    return result or J.Err('transaction_failed', 'Transaction did not complete.')
end
M.Canonical = Canonical
