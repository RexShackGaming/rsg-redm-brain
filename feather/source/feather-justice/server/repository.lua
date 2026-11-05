-- Justice repository: the only code that reads or writes Justice tables
-- (master plan: Repository ownership). Column and table names come from the
-- fixed specs below, never from callers; values are always bound parameters.
local J = Justice
local Repo = {}
J.Repo = Repo

local int = 'int'
local specs = {
    jurisdiction = { table = 'justice_jurisdictions', id = 'jurisdiction_id', owner = 'owner_resource', columns = {
        jurisdiction_id = 1, jurisdiction_key = 1, label = 1, jurisdiction_type = 1, status = 1, parent_jurisdiction_id = 1,
        owner_resource = 1, revision = int, created_at = int, retired_at = int } },
    statute = { table = 'justice_statutes', id = 'statute_id', owner = 'owner_resource', columns = {
        statute_id = 1, jurisdiction_id = 1, statute_key = 1, title = 1, description = 1, category = 1, severity_class = 1,
        status = 1, definition_version = int, effective_from = int, effective_until = int, metadata_json = 'json',
        owner_resource = 1, revision = int, created_at = int } },
    case = { table = 'justice_cases', id = 'case_id', owner = 'opened_by_resource', columns = {
        case_id = 1, jurisdiction_id = 1, case_type = 1, status = 1, title = 1, summary = 1, opened_by_character_id = 1,
        opened_by_resource = 1, opened_at = int, closed_at = int, sealed_at = int, sealed_from_status = 1,
        expunged_at = int, revision = int } },
    party = { table = 'justice_case_parties', id = 'party_id', child = true, columns = {
        party_id = 1, case_id = 1, party_type = 1, party_id_reference = 1, party_role = 1, status = 1, added_at = int,
        removed_at = int, added_by_character_id = 1, removed_by_character_id = 1, revision = int } },
    charge = { table = 'justice_charges', id = 'charge_id', child = true, columns = {
        charge_id = 1, case_id = 1, defendant_character_id = 1, statute_id = 1, statute_snapshot_json = 'json', count = int,
        status = 1, proposed_by_character_id = 1, proposed_at = int, filed_by_character_id = 1, filed_at = int,
        disposition = 1, disposed_by_character_id = 1, disposed_at = int, amends_charge_id = 1, amended_by_charge_id = 1,
        ruling_id = 1, revision = int } },
    warrant = { table = 'justice_warrants', id = 'warrant_id', child = true, columns = {
        warrant_id = 1, jurisdiction_id = 1, case_id = 1, subject_character_id = 1, warrant_type = 1, status = 1,
        basis_summary = 1, valid_for_seconds = int, created_by_character_id = 1, created_at = int,
        issued_by_character_id = 1, issued_at = int, expires_at = int, served_at = int, recalled_at = int,
        quashed_at = int, closed_by_character_id = 1, revision = int } },
    citation = { table = 'justice_citations', id = 'citation_id', child = true, columns = {
        citation_id = 1, jurisdiction_id = 1, case_id = 1, subject_character_id = 1, statute_id = 1, status = 1,
        issued_by_character_id = 1, issued_at = int, due_at = int, contracts_obligation_id = 1, amount = int,
        currency = 1, type_key = 1, due_in_seconds = int, basis_summary = 1, revision = int } },
    custody = { table = 'justice_custody_records', id = 'custody_id', child = true, columns = {
        custody_id = 1, jurisdiction_id = 1, case_id = 1, subject_character_id = 1, authority_type = 1, authority_id = 1,
        authority_revision = int, status = 1, arresting_character_id = 1, started_at = int, booked_at = int,
        booked_by_character_id = 1, facility_key = 1, released_at = int, released_by_character_id = 1,
        release_reason = 1, revision = int } },
    ruling = { table = 'justice_rulings', id = 'ruling_id', child = true, columns = {
        ruling_id = 1, case_id = 1, ruling_type = 1, outcome = 1, issued_by_character_id = 1, issued_at = int,
        summary = 1, subject_character_id = 1, findings_json = 'json', revision = int } },
    sentence = { table = 'justice_sentences', id = 'sentence_id', child = true, columns = {
        sentence_id = 1, case_id = 1, defendant_character_id = 1, sentence_type = 1, status = 1, terms_json = 'json',
        starts_at = int, ends_at = int, contracts_obligation_id = 1, ruling_id = 1, jurisdiction_id = 1,
        created_by_character_id = 1, created_at = int, activated_by_character_id = 1, activated_at = int,
        remaining_ms = int, completed_by_character_id = 1, completed_at = int, outcome = 1, effect_reference = 1,
        financial_outcome = 1, currency = 1, type_key = 1, revision = int } },
    evidence = { table = 'justice_evidence_links', id = 'evidence_link_id', child = true, columns = {
        evidence_link_id = 1, case_id = 1, evidence_type = 1, evidence_id = 1, relationship = 1,
        linked_by_character_id = 1, linked_at = int, removed_at = int, removed_by_character_id = 1, status = 1,
        disposition = 1, subject_character_id = 1, description = 1, item_name = 1, revision = int } }
}
Repo.Specs = specs

local function Number(value)
    local number = tonumber(value)
    return number and (math.tointeger(number) or number) or nil
end
local function Convert(kind, row)
    if type(row) ~= 'table' then return nil end
    local spec, out = specs[kind], {}
    for column, value in pairs(row) do
        local class = spec.columns[column]
        if class == int then out[column] = Number(value)
        elseif class == 'json' then
            local ok, decoded = pcall(json.decode, value)
            out[column] = ok and decoded or nil
            if not ok or decoded == nil then out['__invalid'] = column end
        elseif class then out[column] = value end
    end
    return out
end
local function Encode(kind, column, value)
    if specs[kind].columns[column] == 'json' and value ~= nil then return json.encode(value) end
    return value
end
local function Columns(kind, alias)
    local list = {}
    for column in pairs(specs[kind].columns) do list[#list + 1] = (alias and alias .. '.' or '') .. column end
    table.sort(list)
    return table.concat(list, ',')
end
local function From(kind)
    local spec = specs[kind]
    if spec.child then
        return ' FROM ' .. spec.table .. ' x JOIN justice_cases k ON k.case_id=x.case_id', 'k.opened_by_resource'
    end
    return ' FROM ' .. spec.table .. ' x', 'x.' .. spec.owner
end

function Repo.Now(query) return Number(query(J.NowSql)) end

-- Owner-scoped read by primary key; a foreign-owned row is indistinguishable from absent.
function Repo.Get(query, kind, id, owner, lock)
    local from, ownerColumn = From(kind)
    local row = query('SELECT ' .. Columns(kind, 'x') .. from .. ' WHERE x.' .. specs[kind].id .. '=? AND ' .. ownerColumn .. '=?'
        .. (lock and ' FOR UPDATE' or ''), id, owner)
    return Convert(kind, row)
end
function Repo.GetByKey(query, kind, column, key, owner)
    assert(column == 'jurisdiction_key' or column == 'statute_key', 'unsupported key column')
    return Convert(kind, query('SELECT ' .. Columns(kind) .. ' FROM ' .. specs[kind].table .. ' WHERE ' .. column .. '=? AND owner_resource=?', key, owner))
end
function Repo.KeyExists(query, kind, column, key)
    assert(column == 'jurisdiction_key' or column == 'statute_key', 'unsupported key column')
    return query('SELECT 1 AS present FROM ' .. specs[kind].table .. ' WHERE ' .. column .. '=?', key) ~= nil
end
function Repo.Insert(tx, kind, values)
    local spec, columns, marks, params = specs[kind], {}, {}, {}
    for column, value in pairs(values) do
        assert(spec.columns[column], 'unknown column ' .. column)
        columns[#columns + 1] = column
    end
    table.sort(columns)
    for index, column in ipairs(columns) do marks[index] = '?'; params[index] = Encode(kind, column, values[column]) end
    tx.exec('INSERT INTO ' .. spec.table .. ' (' .. table.concat(columns, ',') .. ') VALUES (' .. table.concat(marks, ',') .. ')',
        table.unpack(params, 1, #columns))
end
-- Writes every listed column; `nulls` names columns to set to NULL explicitly.
function Repo.Update(tx, kind, id, values, nulls)
    local spec, sets, params = specs[kind], {}, {}
    local columns = {}
    for column in pairs(values) do assert(spec.columns[column], 'unknown column ' .. column); columns[#columns + 1] = column end
    table.sort(columns)
    for _, column in ipairs(columns) do sets[#sets + 1] = column .. '=?'; params[#params + 1] = Encode(kind, column, values[column]) end
    for _, column in ipairs(nulls or {}) do assert(spec.columns[column], 'unknown column ' .. column); sets[#sets + 1] = column .. '=NULL' end
    params[#params + 1] = id
    tx.exec('UPDATE ' .. spec.table .. ' SET ' .. table.concat(sets, ',') .. ' WHERE ' .. spec.id .. '=?', table.unpack(params))
end

-- Case visibility and eligibility as SQL, applied to every list (master plan: Privacy).
local readerRoles = "'reporting_officer','investigating_officer','prosecutor','defense_counsel','judge'"
local writerRoles = "'investigating_officer','prosecutor','judge'"
local function CaseFilter(actor, alias)
    local sql, params = '', {}
    if not actor.viewSealed then sql = sql .. ' AND ' .. alias .. ".status<>'sealed'" end
    if actor.system or actor.viewAll or actor.manageAll then return sql, params end
    sql = sql .. ' AND (' .. alias .. '.opened_by_character_id=? OR EXISTS (SELECT 1 FROM justice_case_parties cp WHERE cp.case_id='
        .. alias .. ".case_id AND cp.party_type='character' AND cp.party_id_reference=? AND cp.status='active' AND cp.party_role IN ("
        .. readerRoles .. ')))'
    params[1], params[2] = actor.characterId, actor.characterId
    return sql, params
end
function Repo.IsJudge(query, caseId, characterId)
    return query("SELECT 1 AS judge FROM justice_case_parties WHERE case_id=? AND party_type='character' AND party_id_reference=? AND party_role='judge' AND status='active'",
        caseId, characterId) ~= nil
end
function Repo.MemberRole(query, caseId, characterId, write)
    local row = query("SELECT party_role FROM justice_case_parties WHERE case_id=? AND party_type='character' AND party_id_reference=? AND status='active' AND party_role IN ("
        .. (write and writerRoles or readerRoles) .. ') LIMIT 1', caseId, characterId)
    return row and row.party_role or nil
end

-- Bounded keyset page ordered by primary key. `filters` are equality filters on
-- whitelisted columns; `statuses` an optional IN list; `actor` applies case privacy.
function Repo.Page(query, kind, owner, options)
    local spec = specs[kind]
    local from, ownerColumn = From(kind)
    local caseAlias = spec.child and 'k' or (kind == 'case' and 'x' or nil)
    local sql = 'SELECT ' .. Columns(kind, 'x') .. from .. ' WHERE ' .. ownerColumn .. '=? AND x.' .. spec.id .. '>?'
    local params = { owner, options.cursor or '' }
    local names = {}
    for column in pairs(options.filters or {}) do names[#names + 1] = column end
    table.sort(names)
    for _, column in ipairs(names) do
        local target = column:match('^case%.(.+)$')
        if target then
            assert(specs.case.columns[target], 'unknown case column ' .. target)
            sql = sql .. ' AND ' .. (caseAlias or 'k') .. '.' .. target .. '=?'
        else
            assert(spec.columns[column], 'unknown column ' .. column)
            sql = sql .. ' AND x.' .. column .. '=?'
        end
        params[#params + 1] = options.filters[column]
    end
    if options.statuses then
        local marks = {}
        for index, status in ipairs(options.statuses) do marks[index] = '?'; params[#params + 1] = status end
        sql = sql .. ' AND x.status IN (' .. table.concat(marks, ',') .. ')'
    end
    if options.unexpiredAt then sql = sql .. ' AND x.expires_at>?'; params[#params + 1] = options.unexpiredAt end
    if options.actor and caseAlias then
        local filter, extra = CaseFilter(options.actor, caseAlias)
        sql = sql .. filter
        for _, value in ipairs(extra) do params[#params + 1] = value end
    end
    sql = sql .. ' ORDER BY x.' .. spec.id .. ' ASC LIMIT ?'
    params[#params + 1] = options.limit + 1
    local rows = query(sql, table.unpack(params))
    local items = {}
    for index = 1, math.min(#rows, options.limit) do items[index] = Convert(kind, rows[index]) end
    return items, #rows > options.limit
end

-- Exclusive slots (backed by unique generated columns; FOR UPDATE also gap-locks).
function Repo.ActiveCustody(query, subjectId, lock)
    return Convert('custody', query('SELECT ' .. Columns('custody') .. ' FROM justice_custody_records WHERE active_subject=?'
        .. (lock and ' FOR UPDATE' or ''), subjectId))
end
function Repo.ActiveCustodial(query, subjectId, lock)
    return Convert('sentence', query('SELECT ' .. Columns('sentence') .. ' FROM justice_sentences WHERE active_custodial=?'
        .. (lock and ' FOR UPDATE' or ''), subjectId))
end
function Repo.ActivePartySlot(query, caseId, partyType, reference, role)
    return query('SELECT party_id FROM justice_case_parties WHERE active_key=? FOR UPDATE',
        caseId .. ':' .. partyType .. ':' .. reference .. ':' .. role) ~= nil
end
function Repo.ActiveEvidence(query, caseId, evidenceType, evidenceId)
    return query('SELECT evidence_link_id FROM justice_evidence_links WHERE active_key=? FOR UPDATE',
        caseId .. ':' .. evidenceType .. ':' .. evidenceId) ~= nil
end

-- Case-scoped child sets used by rulings, sealing and expunge (locked in key order).
function Repo.OpenCharges(tx, caseId)
    local rows = tx.query('SELECT ' .. Columns('charge') .. " FROM justice_charges WHERE case_id=? AND status IN ('proposed','filed') ORDER BY charge_id FOR UPDATE", caseId)
    for index, row in ipairs(rows) do rows[index] = Convert('charge', row) end
    return rows
end
function Repo.CaseChildren(query, kind, caseId, lock, limit)
    local spec = specs[kind]
    assert(spec.child, 'not a case child')
    local rows = query('SELECT ' .. Columns(kind) .. ' FROM ' .. spec.table .. ' WHERE case_id=? ORDER BY ' .. spec.id
        .. (limit and ' LIMIT ' .. math.floor(limit) or '') .. (lock and ' FOR UPDATE' or ''), caseId)
    for index, row in ipairs(rows) do rows[index] = Convert(kind, row) end
    return rows
end

-- Sweeps (system workers).
function Repo.DueWarrants(now, limit)
    local rows = DB.query('SELECT x.warrant_id, k.opened_by_resource FROM justice_warrants x JOIN justice_cases k ON k.case_id=x.case_id'
        .. " WHERE x.status='active' AND x.expires_at<=? ORDER BY x.expires_at, x.warrant_id LIMIT ?", now, limit)
    return rows
end
function Repo.DueSentences(now, limit)
    return DB.query('SELECT x.sentence_id, k.opened_by_resource FROM justice_sentences x JOIN justice_cases k ON k.case_id=x.case_id'
        .. " WHERE x.status='active' AND x.ends_at IS NOT NULL AND x.ends_at<=? ORDER BY x.ends_at, x.sentence_id LIMIT ?", now, limit)
end

-- Workflows (Contracts issue/cancel/settlement watch).
function Repo.Wake(tx, kind, id, delayMs)
    tx.exec([[INSERT INTO justice_workflows (record_id, record_kind, next_attempt_at) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE next_attempt_at=VALUES(next_attempt_at), last_code=NULL]], id, kind, Repo.Now(tx.value) + (delayMs or 0))
end
function Repo.DueWorkflows(limit)
    return DB.query([[SELECT w.record_id, w.record_kind, COALESCE(c.opened_by_resource, s.opened_by_resource) AS owner_resource
        FROM justice_workflows w
        LEFT JOIN justice_citations ci ON w.record_kind='citation' AND ci.citation_id=w.record_id
        LEFT JOIN justice_cases c ON c.case_id=ci.case_id
        LEFT JOIN justice_sentences se ON w.record_kind='sentence' AND se.sentence_id=w.record_id
        LEFT JOIN justice_cases s ON s.case_id=se.case_id
        WHERE w.next_attempt_at<=? ORDER BY w.next_attempt_at, w.record_id LIMIT ?]], Repo.Now(DB.value), limit)
end
function Repo.DeferWorkflow(id, delayMs, code)
    DB.exec('UPDATE justice_workflows SET attempts=attempts+1, next_attempt_at=?, last_code=? WHERE record_id=?',
        Repo.Now(DB.value) + delayMs, code, id)
end
function Repo.WorkflowCode(id, code) DB.exec('UPDATE justice_workflows SET last_code=? WHERE record_id=?', code, id) end
function Repo.DeleteWorkflow(tx, id) tx.exec('DELETE FROM justice_workflows WHERE record_id=?', id) end
function Repo.WakeNow(id) DB.exec('UPDATE justice_workflows SET next_attempt_at=0 WHERE record_id=?', id) end
function Repo.WakeObligation(obligationId)
    DB.exec([[UPDATE justice_workflows w SET w.next_attempt_at=0 WHERE w.record_id IN (
        SELECT citation_id FROM justice_citations WHERE contracts_obligation_id=?
        UNION SELECT sentence_id FROM justice_sentences WHERE contracts_obligation_id=?)]], obligationId, obligationId)
end
function Repo.Workflows(limit)
    return DB.query('SELECT record_id, record_kind, attempts, last_code FROM justice_workflows ORDER BY next_attempt_at, record_id LIMIT ?', limit)
end

-- Receipts, audit facts and outbox (master plan: Mutation controls, Events).
function Repo.ClaimReceipt(tx, owner, requestId, fingerprint, actorId)
    tx.exec([[INSERT INTO justice_receipts (source_resource, request_id, fingerprint, actor_character_id)
        VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE request_id=request_id]], owner, requestId, fingerprint, actorId)
    -- The receipt lock also reads database time once for the whole transaction.
    return tx.one([[SELECT fingerprint, result_json, FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000) AS now_ms
        FROM justice_receipts WHERE source_resource=? AND request_id=? FOR UPDATE]], owner, requestId)
end
function Repo.StoreReceipt(tx, owner, requestId, kind, id, result)
    tx.exec('UPDATE justice_receipts SET record_kind=?, record_id=?, result_json=? WHERE source_resource=? AND request_id=?',
        kind, id, json.encode(result), owner, requestId)
end
function Repo.RedactReceipts(tx, recordId)
    tx.exec('UPDATE justice_receipts SET result_json=? WHERE record_id=?', json.encode({ recordId = recordId, redacted = true }), recordId)
end
function Repo.ReceiptRecord(query, owner, requestId)
    return query('SELECT record_kind, record_id FROM justice_receipts WHERE source_resource=? AND request_id=?', owner, requestId)
end
function Repo.AuditFact(tx, fact)
    tx.exec([[INSERT INTO justice_audit_events (event_id, record_kind, record_id, fact, source_resource, actor_character_id,
        reason_code, correlation_id, revision, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)]], fact.eventId, fact.kind, fact.recordId,
        fact.fact, fact.source, fact.actorId, fact.reasonCode, fact.correlationId, fact.revision, fact.now)
    tx.exec('INSERT INTO justice_outbox (event_id, record_id, fact, revision, payload_json, created_at) VALUES (?,?,?,?,?,?)',
        fact.eventId, fact.recordId, fact.fact, fact.revision, json.encode(fact.payload), fact.now)
end
function Repo.PendingOutbox(limit)
    return DB.query([[SELECT o.event_id, o.fact, o.payload_json FROM justice_outbox o WHERE o.delivered=0 AND NOT EXISTS
        (SELECT 1 FROM justice_outbox p WHERE p.record_id=o.record_id AND p.delivered=0 AND p.revision<o.revision)
        ORDER BY o.created_at, o.event_id LIMIT ?]], limit)
end
function Repo.MarkDelivered(eventId) DB.exec('UPDATE justice_outbox SET delivered=1 WHERE event_id=?', eventId) end
function Repo.History(recordId, limit)
    return DB.query([[SELECT event_id, record_kind, fact, revision, reason_code, correlation_id, actor_character_id,
        source_resource, created_at FROM justice_audit_events WHERE record_id=? ORDER BY revision, created_at LIMIT ?]], recordId, limit)
end
-- Locates any owned record (for audit history) and its case.
function Repo.Locate(id, owner)
    for kind, spec in pairs(specs) do
        local from, ownerColumn = From(kind)
        local row = DB.one('SELECT x.' .. spec.id .. ' AS id' .. ((spec.child or kind == 'case') and ', x.case_id AS case_id' or '')
            .. ((spec.columns.jurisdiction_id) and ', x.jurisdiction_id AS jurisdiction_id' or '')
            .. from .. ' WHERE x.' .. spec.id .. '=? AND ' .. ownerColumn .. '=?', id, owner)
        if row then return kind, row end
    end
end
function Repo.AccessAudit(entry)
    DB.exec([[INSERT INTO justice_access_audit (access_id, source_resource, actor_character_id, action, subject_character_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?)]], J.NewUuid(), entry.source, entry.actorId, entry.action, entry.subjectId, Repo.Now(DB.value))
end
function Repo.AccessHistory(subjectId, limit)
    return DB.query([[SELECT source_resource, actor_character_id, action, created_at FROM justice_access_audit
        WHERE subject_character_id=? ORDER BY created_at DESC LIMIT ?]], subjectId, limit)
end

-- Evidence guard cache and reconciliation.
function Repo.ActiveInventoryEvidence()
    local ids = {}
    for _, row in ipairs(DB.query("SELECT evidence_id FROM justice_evidence_links WHERE evidence_type='inventory_item' AND status='active'")) do
        ids[tostring(row.evidence_id)] = true
    end
    return ids
end
function Repo.ActiveInventoryLinks(limit)
    local rows = DB.query('SELECT ' .. Columns('evidence', 'x') .. ', k.opened_by_resource AS owner_resource FROM justice_evidence_links x'
        .. " JOIN justice_cases k ON k.case_id=x.case_id WHERE x.evidence_type='inventory_item' AND x.status='active' ORDER BY x.evidence_link_id LIMIT ?", limit)
    for index, row in ipairs(rows) do
        local owner = row.owner_resource
        rows[index] = Convert('evidence', row)
        rows[index].owner_resource = owner
    end
    return rows
end

-- Retention (operator policy).
function Repo.PurgeDeliveredOutbox(cutoffMs, dryRun)
    if dryRun then return Number(DB.value('SELECT COUNT(*) FROM justice_outbox WHERE delivered=1 AND created_at<?', cutoffMs)) end
    DB.exec('DELETE FROM justice_outbox WHERE delivered=1 AND created_at<? LIMIT 1000', cutoffMs)
end
function Repo.RedactionCandidates(cutoffMs, limit)
    return DB.query([[SELECT k.case_id, k.opened_by_resource, k.revision FROM justice_cases k
        WHERE k.status IN ('closed','dismissed') AND k.summary NOT IN ('[redacted]','[expunged]')
        AND NOT EXISTS (SELECT 1 FROM justice_audit_events e WHERE e.record_id=k.case_id AND e.created_at>=?)
        ORDER BY k.case_id LIMIT ?]], cutoffMs, limit)
end

-- Operator visibility.
function Repo.Backlog()
    local function count(sql, ...) local ok, value = pcall(DB.value, sql, ...); return ok and Number(value) or -1 end
    local now = Repo.Now(DB.value) or 0
    local oldest = count('SELECT MIN(created_at) FROM justice_outbox WHERE delivered=0')
    return {
        outboxPending = count('SELECT COUNT(*) FROM justice_outbox WHERE delivered=0'),
        outboxOldestSeconds = (oldest and oldest > 0) and math.floor((now - oldest) / 1000) or 0,
        workflows = count('SELECT COUNT(*) FROM justice_workflows'),
        workflowErrors = count("SELECT COUNT(*) FROM justice_workflows WHERE last_code IS NOT NULL AND last_code NOT IN ('pending','settlement_pending')"),
        activeCustody = count('SELECT COUNT(*) FROM justice_custody_records WHERE active_subject IS NOT NULL'),
        activeCustodial = count('SELECT COUNT(*) FROM justice_sentences WHERE active_custodial IS NOT NULL'),
        sealedCases = count("SELECT COUNT(*) FROM justice_cases WHERE status='sealed'")
    }
end
function Repo.UndeliveredForOwner(owner)
    return Number(DB.value([[SELECT COUNT(*) FROM justice_outbox o WHERE o.delivered=0 AND o.record_id IN (
        SELECT case_id FROM justice_cases WHERE opened_by_resource=?)]], owner)) or 0
end

-- Development cleanup of one owner namespace (acceptance/smoke tests only).
function Repo.DeleteOwnerNamespace(owner)
    local cases = DB.query('SELECT case_id FROM justice_cases WHERE opened_by_resource=?', owner)
    local ids = {}
    for _, row in ipairs(cases) do ids[#ids + 1] = row.case_id end
    for _, row in ipairs(DB.query('SELECT jurisdiction_id AS id FROM justice_jurisdictions WHERE owner_resource=? UNION SELECT statute_id FROM justice_statutes WHERE owner_resource=?', owner, owner)) do
        ids[#ids + 1] = row.id
    end
    local childTables = { 'justice_evidence_links', 'justice_sentences', 'justice_rulings', 'justice_custody_records',
        'justice_citations', 'justice_warrants', 'justice_charges', 'justice_case_parties' }
    local childIds = { justice_evidence_links = 'evidence_link_id', justice_sentences = 'sentence_id', justice_rulings = 'ruling_id',
        justice_custody_records = 'custody_id', justice_citations = 'citation_id', justice_warrants = 'warrant_id',
        justice_charges = 'charge_id', justice_case_parties = 'party_id' }
    for _, name in ipairs(childTables) do
        for _, row in ipairs(DB.query('SELECT x.' .. childIds[name] .. ' AS id FROM ' .. name .. ' x JOIN justice_cases k ON k.case_id=x.case_id WHERE k.opened_by_resource=?', owner)) do
            ids[#ids + 1] = row.id
        end
    end
    for _, id in ipairs(ids) do
        DB.exec('DELETE FROM justice_workflows WHERE record_id=?', id)
        DB.exec('DELETE FROM justice_audit_events WHERE record_id=?', id)
        DB.exec('DELETE FROM justice_outbox WHERE record_id=?', id)
        DB.exec('DELETE FROM justice_receipts WHERE record_id=?', id)
    end
    DB.exec('DELETE FROM justice_receipts WHERE source_resource=?', owner)
    for _, name in ipairs(childTables) do
        DB.exec('DELETE x FROM ' .. name .. ' x JOIN justice_cases k ON k.case_id=x.case_id WHERE k.opened_by_resource=?', owner)
    end
    DB.exec('DELETE FROM justice_cases WHERE opened_by_resource=?', owner)
    DB.exec('DELETE FROM justice_statutes WHERE owner_resource=?', owner)
    DB.exec('DELETE FROM justice_jurisdictions WHERE owner_resource=? AND parent_jurisdiction_id IS NOT NULL', owner)
    DB.exec('DELETE FROM justice_jurisdictions WHERE owner_resource=?', owner)
    return #ids
end
function Repo.AccessAuditCleanup(subjectIds)
    for _, id in ipairs(subjectIds) do
        DB.exec("DELETE FROM justice_access_audit WHERE subject_character_id=? AND source_resource='justice-acceptance'", id)
    end
end
