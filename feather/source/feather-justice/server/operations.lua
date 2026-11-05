-- Operations and observability (master plan: Operations and observability,
-- Retention classes, Testing standard). Console commands only run from source 0.
local J, Repo, M, A, S = Justice, Justice.Repo, Justice.Mutation, Justice.Access, Justice.Scenarios

-- Retention is operator policy; legal records are kept unless configured otherwise.
function J.RunRetention(dryRun)
    local c = JusticeConfig.Retention or {}
    local report = { outbox = 0, redacted = 0, dryRun = dryRun == true }
    local now = Repo.Now(DB.value)
    if J.Integer(c.DeliveredOutboxDays, 1, 3650) then
        report.outbox = Repo.PurgeDeliveredOutbox(now - c.DeliveredOutboxDays * 86400000, dryRun) or 0
    end
    if J.Integer(c.RedactClosedCaseNarrativesDays, 1, 36500) then
        for _, candidate in ipairs(Repo.RedactionCandidates(now - c.RedactClosedCaseNarrativesDays * 86400000, 10)) do
            if dryRun then report.redacted = report.redacted + 1 else
                local owner = candidate.opened_by_resource
                local result = M.Run('case.updated', { requestId = 'justice:retention:' .. candidate.case_id .. ':' .. candidate.revision,
                    reasonCode = 'justice.retention.redact', retentionCaseId = candidate.case_id }, 'feather-justice',
                    { generation = J.Generation(), system = true }, function(tx, context)
                        local case = Repo.Get(tx.one, 'case', candidate.case_id, owner, true)
                        if not case or case.revision ~= tonumber(candidate.revision) then return J.Err('revision_conflict', 'Case changed.') end
                        local changes = J.RedactCase(tx, case, '[redacted]', context)
                        changes.revision = case.revision + 1
                        Repo.Update(tx, 'case', case.case_id, changes)
                        for key, value in pairs(changes) do case[key] = value end
                        return J.Ok(J.CaseSnapshot(case))
                    end)
                if result.ok then report.redacted = report.redacted + 1 end
            end
        end
    end
    return report
end

-- Redacted audit query for authorized administrators: facts, never narrative.
J.Export('GetRecordHistory', function(p, owner)
    if not M.Fields(p, { 'recordId', 'limit' }, false) or not J.Uuid(p.recordId) or (p.limit ~= nil and not J.Integer(p.limit, 1, 100)) then
        return J.Err('invalid_input', 'Record UUID and a limit up to 100 required.')
    end
    local gate = A.Gate(owner); if not gate.ok then return gate end
    local kind, located = Repo.Locate(p.recordId:lower(), owner)
    local actor = J.Principal(owner, 'justice.audit.view', p, located and located.jurisdiction_id or nil)
    if not actor.ok then return actor end
    if not kind then return J.Err('not_found', 'Record unavailable.') end
    if located.case_id then
        local case = Repo.Get(DB.one, 'case', located.case_id, owner)
        if case and case.status == 'sealed' and not actor.value.viewSealed then return J.Err('not_found', 'Record unavailable.') end
    end
    local items = {}
    for _, f in ipairs(Repo.History(located.id, p.limit or 50)) do
        items[#items + 1] = { eventId = f.event_id, fact = f.fact, revision = tonumber(f.revision), reasonCode = f.reason_code,
            correlationId = f.correlation_id, actorCharacterId = f.actor_character_id, sourceResource = f.source_resource,
            createdAt = tonumber(f.created_at) }
    end
    if not J.Current(actor.value) then return J.Err('session_expired', 'Actor changed.') end
    return J.Ok({ recordId = located.id, kind = kind, items = items })
end)

J.Export('GetMetrics', function(request, owner)
    if request ~= nil and (type(request) ~= 'table' or next(request) ~= nil) then return J.Err('invalid_input', 'No fields are accepted.') end
    if not J.Trusted(owner) and not (JusticeConfig.MetricsReaders or {})[owner or ''] then
        return J.Err('authorization_denied', 'Caller may not read Justice metrics.')
    end
    local m, caps = J.Metrics(), J.Capabilities().value
    return J.Ok({ release = caps.release, state = caps.state, uptimeMs = GetGameTimer() - m.since, operations = m.operations,
        providers = m.providers, backlog = J.Ready() and Repo.Backlog() or nil, evidenceGuard = J.EvidenceGuardActive() })
end)

local function PrintBucket(label, bucket)
    local names = {}
    for name in pairs(bucket) do names[#names + 1] = name end
    table.sort(names, function(a, b) return bucket[a].calls > bucket[b].calls end)
    for _, name in ipairs(names) do
        local e, codes = bucket[name], {}
        for code, count in pairs(e.codes) do codes[#codes + 1] = code .. '=' .. count end
        table.sort(codes)
        print(('[JusticeMetrics] %s %s calls=%d ok=%d replayed=%d avgMs=%d maxMs=%d %s'):format(label, name, e.calls, e.ok, e.replayed,
            e.calls > 0 and math.floor(e.totalMs / e.calls) or 0, e.maxMs, table.concat(codes, ' ')))
    end
end
local function Console(name, handler) RegisterCommand(name, function(source, args) if source == 0 then handler(args) end end, true) end

Console('JusticeContractSmokeTest', function()
    local caps = J.Capabilities().value
    local f = caps.features
    print(('[JusticeContractSmokeTest] read-only release=%s contract=%s v%d ready=%s cases=%d warrants=%d custody=%d rulings=%d sentences=%d evidenceLinks=%d sealing=%d evidenceGuard=%d'):format(
        caps.release, caps.contract, caps.version, tostring(J.Ready()), f.cases, f.warrants, f.custody, f.rulings, f.sentences,
        f.evidenceLinks, f.sealing, f.evidenceGuard))
end)
Console('JusticeMetrics', function(args)
    if args[1] == 'reset' then J.ResetMetrics(); print('[JusticeMetrics] reset'); return end
    local m = J.Metrics()
    print(('[JusticeMetrics] uptimeMs=%d (counters since start or last reset)'):format(GetGameTimer() - m.since))
    PrintBucket('operation', m.operations)
    PrintBucket('provider', m.providers)
    if J.Ready() then
        local b = Repo.Backlog()
        print(('[JusticeMetrics] backlog outboxPending=%d oldestSeconds=%d workflows=%d errors=%d activeCustody=%d activeCustodial=%d sealed=%d'):format(
            b.outboxPending, b.outboxOldestSeconds, b.workflows, b.workflowErrors, b.activeCustody, b.activeCustodial, b.sealedCases))
    end
end)
Console('JusticeStatus', function()
    local caps = J.Capabilities().value
    print(('[JusticeStatus] release=%s state=%s evidenceGuard=%s'):format(caps.release, caps.state, tostring(J.EvidenceGuardActive())))
    if not J.Ready() then return end
    for _, row in ipairs(Repo.Workflows(15)) do
        print(('[JusticeStatus] workflow %s %s attempts=%s code=%s'):format(row.record_kind, row.record_id, tostring(row.attempts), tostring(row.last_code or 'queued')))
    end
end)
-- Brings a workflow forward; never edits legal state directly.
Console('JusticeWorkflowRetry', function(args)
    if not J.Uuid(args[1]) then print('[JusticeWorkflowRetry] usage: JusticeWorkflowRetry <recordUuid>'); return end
    Repo.WakeNow(args[1]:lower())
    print('[JusticeWorkflowRetry] queued ' .. args[1])
end)
Console('JusticeEvidenceReconcile', function()
    local result = J.ReconcileEvidence(100)
    if not result.ok then print('[JusticeEvidenceReconcile] ' .. result.code); return end
    print(('[JusticeEvidenceReconcile] checked=%d missing=%d unavailable=%d'):format(result.value.checked, result.value.missing, result.value.unavailable))
end)
Console('JusticeRetentionRun', function(args)
    if not J.Ready() then print('[JusticeRetentionRun] not ready'); return end
    local report = J.RunRetention(args[1] ~= 'apply')
    print(('[JusticeRetentionRun] dryRun=%s outbox=%d redactedCases=%d (pass "apply" to execute)'):format(tostring(report.dryRun), report.outbox, report.redacted))
end)
-- Who searched for a character (master plan: search by character UUID is audited).
Console('JusticeAccessAudit', function(args)
    if not J.Uuid(args[1]) then print('[JusticeAccessAudit] usage: JusticeAccessAudit <characterUuid>'); return end
    for _, row in ipairs(Repo.AccessHistory(args[1]:lower(), 25)) do
        print(('[JusticeAccessAudit] at=%s by=%s via=%s action=%s'):format(tostring(row.created_at), tostring(row.actor_character_id or 'service'),
            row.source_resource, row.action))
    end
end)

-- Read-only, production-safe ----------------------------------------------------
local function Reporter(prefix)
    local r = { passed = 0, failed = 0 }
    function r.check(label, condition, detail)
        if condition then r.passed = r.passed + 1 else r.failed = r.failed + 1 end
        print(('[%s] %s %s%s'):format(prefix, condition and 'PASS' or 'FAIL', label, (not condition and detail ~= nil) and (' (' .. tostring(detail) .. ')') or ''))
        return condition
    end
    function r.done() print(('[%s] RESULT %d passed, %d failed'):format(prefix, r.passed, r.failed)) end
    return r
end
function J.MigrationSmoke()
    local r = Reporter('JusticeMigrationSmokeTest')
    print('[JusticeMigrationSmokeTest] read-only, production-safe')
    local ledger = J.MigrationLedger()
    if not r.check('ledger readable', ledger ~= nil) then return r end
    for _, migration in ipairs(J.ExpectedMigrations()) do
        r.check(migration.id .. ' applied with matching checksum', ledger[migration.id] == migration.checksum,
            ledger[migration.id] and 'checksum drift' or 'not applied')
        ledger[migration.id] = nil
    end
    for id in pairs(ledger) do r.check('no unknown ledger entry ' .. id, false, 'not in this release') end
    local present = J.SchemaTables()
    for _, name in ipairs(J.Tables) do r.check('table ' .. name .. ' exists', present[name] == true) end
    r.check('Justice ready', J.Ready(), J.Health().value.state)
    return r
end
Console('JusticeMigrationSmokeTest', function() J.MigrationSmoke().done() end)

-- Real Core policy (no constructed actor). Offline: a character UUID; with an online
-- player's server id it also checks the session path and lists that player's decisions.
function J.PolicySmoke(player)
    local r = Reporter('JusticePolicySmokeTest')
    print('[JusticePolicySmokeTest] read-only, production-safe; real Core policy')
    if not r.check('Justice ready', J.Ready()) then return r end
    -- The service grants are checked for the first trusted resource (sorted by name).
    local trusted = {}
    for resource, allowed in pairs(JusticeConfig.TrustedResources) do if allowed == true then trusted[#trusted + 1] = resource end end
    table.sort(trusted)
    local consumer = trusted[1]
    if not r.check('a trusted consumer is configured', consumer ~= nil) then return r end
    print(('[JusticePolicySmokeTest] service grants checked for %s'):format(consumer))
    local function Decide(action, src)
        local result = J.Call('feather-core', 'Authorize', action, { source = src or 0, subject = { resource = consumer } })
        return result.ok and type(result.value) == 'table' and result.value.allowed == true
    end
    -- Probe with a UUID that belongs to no character, so no real access history is written.
    local probe = J.NewUuid()
    local status = J.Handlers.GetCustodyStatus({ subjectCharacterId = probe }, consumer)
    r.check('service mode: custody status readable without a player', status.ok,
        status.code == 'authorization_denied' and ('grant justice.custody.view in feather-admin service_policy (%s)'):format(consumer) or status.code)
    r.check('service mode refused for player-only actions', J.Handlers.GetCase({ caseId = J.NewUuid() }, consumer).code == 'actor_required')
    r.check('untrusted resource refused', J.Handlers.GetCustodyStatus({ subjectCharacterId = probe }, 'justice-untrusted-smoke').code == 'authorization_denied')
    r.check('service grant: justice.definition.manage', Decide('justice.definition.manage'))
    r.check('service grant: justice.sentence.complete', Decide('justice.sentence.complete'))
    r.check('no blanket service grant (justice.case.open denied without a player)', not Decide('justice.case.open'))
    r.check('no blanket service grant (justice.ruling.record denied without a player)', not Decide('justice.ruling.record'))
    r.check('unknown action denied', not Decide('justice.smoke.unknown_action'))
    if player then
        local session = J.Call('feather-core', 'GetSessionContext', player)
        if r.check('player ' .. player .. ' has an active character session', session.ok and type(session.value) == 'table' and J.Uuid(session.value.characterId)) then
            local probe = J.Handlers.GetCase({ actorSource = player, caseId = J.NewUuid() }, consumer)
            r.check('player path resolves the session and hides unknown cases', probe.code == 'not_found' or probe.code == 'authorization_denied', probe.code)
            for _, action in ipairs({ 'justice.case.open', 'justice.case.view', 'justice.warrant.issue', 'justice.custody.record',
                'justice.ruling.record', 'justice.sentence.impose', 'justice.evidence.link', 'justice.record.seal',
                'justice.case.view_sealed', 'justice.record.expunge', 'justice.audit.view' }) do
                print(('[JusticePolicySmokeTest] INFO player %d %s %s'):format(player, action, Decide(action, player) and 'allowed' or 'denied'))
            end
        end
    end
    return r
end
-- Usage: JusticePolicySmokeTest [onlinePlayerId]. An old-style character UUID first
-- argument is accepted and ignored (the probe no longer needs a real character).
Console('JusticePolicySmokeTest', function(args)
    local player = J.Uuid(args[1]) and tonumber(args[2]) or tonumber(args[1])
    J.PolicySmoke(player).done()
end)

-- Development (own namespace, offline UUIDs, self-cleaning) ----------------------
local busy = false
local function Options(args, from)
    local options = {}
    for index = from, #args do
        local value = args[index]
        if value == 'contracts' then options.contracts = true
        elseif value:match('^item=%d+$') then options.item = value:sub(6)
        elseif value:match('^org=') and J.Uuid(value:sub(5)) then options.organizationId = value:sub(5):lower() end
    end
    return options
end
-- Runs scenarios under a constructed actor; `<actor|source>` accepts a UUID or an online server id.
function J.RunScenarios(prefix, actorArg, subjectArg, options, scenarios)
    local function Resolve(value)
        if J.Uuid(value) then return value:lower() end
        local session = tonumber(value) and J.Call('feather-core', 'GetSessionContext', tonumber(value))
        return session and session.ok and type(session.value) == 'table' and session.value.characterId or nil
    end
    local actorId, subjectId = Resolve(actorArg), Resolve(subjectArg)
    if not actorId or not subjectId or actorId == subjectId then
        print(('[%s] usage: %s <actorUuid|source> <subjectUuid|source> [contracts] [item=<id>] [org=<uuid>]'):format(prefix, prefix))
        return nil
    end
    if busy then print('[' .. prefix .. '] another smoke test is running'); return nil end
    if not J.Ready() then print('[' .. prefix .. '] Justice is not ready'); return nil end
    for _, id in ipairs({ actorId, subjectId }) do
        local identity = A.Character(id)
        if not identity.ok then print(('[%s] character %s unavailable: %s'):format(prefix, id, identity.code)); return nil end
    end
    busy = true
    print(('[%s] development mutation under %s (real database, constructed actor; Core policy not exercised)'):format(prefix, S.Owner))
    local t = S.Context(prefix, actorId, subjectId, options)
    local ok, failure = pcall(function() for _, scenario in ipairs(scenarios) do scenario(t) end end)
    if not ok and failure ~= 'fixture' then t.check('scenario completed', false, tostring(failure):match('^[^\n]*')) end
    busy = false
    if options.keep and ok then return t end
    print(('[%s] cleanup records=%d'):format(prefix, S.Cleanup({ subjectId })))
    t.done()
    return t
end
for name, scenarios in pairs({
    JusticeCaseSmokeTest = { S.Case }, JusticeWarrantSmokeTest = { S.Warrant }, JusticeCitationSmokeTest = { S.Citation },
    JusticeCustodySmokeTest = { S.Warrant, S.Custody }, JusticeEvidenceSmokeTest = { S.Evidence } }) do
    Console(name, function(args) J.RunScenarios(name, args[1], args[2], Options(args, 3), scenarios) end)
end
J.AcceptanceScenarios = { S.Case, S.Warrant, S.Citation, S.Custody, S.Evidence, S.Judicial, S.Deadlines, S.Privacy }
Console('JusticeAcceptanceTest', function(args)
    J.RunScenarios('JusticeAcceptanceTest', args[1], args[2], Options(args, 3), J.AcceptanceScenarios)
end)
Console('JusticeAcceptanceCleanup', function()
    print(('[JusticeAcceptanceCleanup] removed %d records under %s'):format(S.Cleanup({}), S.Owner))
end)

-- Restart checklist: prepare -> restart feather-justice -> verify.
local restartKey = 'justice:restartChecklist'
Console('JusticeRestartChecklist', function(args)
    if args[1] == 'prepare' then
        if GetResourceKvpString(restartKey) then print('[JusticeRestartChecklist] already prepared; run verify or abort'); return end
        local prepared
        local function Prepare(t)
            local fx = S.Fixture(t)
            local draft = t.call('CreateWarrantDraft', { reasonCode = 'restart', caseId = fx.case.caseId, expectedCaseRevision = 1,
                subjectCharacterId = t.subjectId, warrantType = 'arrest', basisSummary = 'Restart checklist.', validForSeconds = 3600 })
            local warrant = t.call('IssueWarrant', { reasonCode = 'restart', warrantId = draft.value.warrantId, expectedRevision = 1 }).value
            local charge = t.call('ProposeCharge', { reasonCode = 'restart', caseId = fx.case.caseId, expectedCaseRevision = 1,
                defendantCharacterId = t.subjectId, statuteId = fx.statute.statuteId, count = 1 }).value
            t.call('FileCharge', { reasonCode = 'restart', chargeId = charge.chargeId, expectedRevision = 1 })
            t.call('TransitionCase', { reasonCode = 'restart', caseId = fx.case.caseId, expectedRevision = 1, status = 'filed' })
            local verdict = t.call('RecordRuling', { reasonCode = 'restart', caseId = fx.case.caseId, expectedCaseRevision = 2,
                rulingType = 'verdict', subjectCharacterId = t.subjectId, summary = 'Restart.', findings = { { chargeId = charge.chargeId, finding = 'convicted' } } }).value
            local sentence = t.call('CreateSentence', { reasonCode = 'restart', caseId = fx.case.caseId, expectedCaseRevision = 3,
                rulingId = verdict.rulingId, sentenceType = 'custodial', terms = { termSeconds = 120 } }).value
            local active = t.call('ActivateSentence', { reasonCode = 'restart', sentenceId = sentence.sentenceId, expectedRevision = 1 }).value
            prepared = { actorId = t.actorId, subjectId = t.subjectId, caseId = fx.case.caseId, warrantId = warrant.warrantId,
                sentenceId = sentence.sentenceId, endsAt = active.endsAt }
        end
        local t = J.RunScenarios('JusticeRestartChecklist', args[2], args[3], { keep = true }, { Prepare })
        if not t then return end
        if not prepared or t.failed > 0 then
            print('[JusticeRestartChecklist] prepare failed; cleaning up'); S.Cleanup({ t.subjectId }); return
        end
        SetResourceKvp(restartKey, json.encode(prepared))
        print('[JusticeRestartChecklist] prepared: case, active arrest warrant, 120 s custodial sentence.')
        print('[JusticeRestartChecklist] now run: restart feather-justice   then: start the resources that depend on it   then: JusticeRestartChecklist verify')
    elseif args[1] == 'verify' then
        local stored = GetResourceKvpString(restartKey)
        if not stored then print('[JusticeRestartChecklist] nothing prepared; run prepare first'); return end
        local state = json.decode(stored)
        local t = S.Context('JusticeRestartChecklist', state.actorId, state.subjectId, {})
        busy = true
        local ok, failure = pcall(function()
            if not t.check('Justice ready after restart', J.Ready(), J.Health().value.state) then return end
            local case = t.call('GetCase', { caseId = state.caseId })
            t.check('case persisted across restart', case.ok and case.value.status == 'adjudicated', case.ok and case.value.status or t.code(case))
            local warrants = t.call('ListActiveWarrants', { caseId = state.caseId })
            t.check('active warrant rebuilt from persistence', warrants.ok and #warrants.value.items == 1)
            local deadline = GetGameTimer() + 15000
            while Repo.UndeliveredForOwner(S.Owner) > 0 and GetGameTimer() < deadline do Wait(1000) end
            t.check('outbox drained by the restarted publisher', Repo.UndeliveredForOwner(S.Owner) == 0)
            if GetResourceState('feather-inventory') == 'started' and JusticeConfig.Evidence.InventoryGuard then
                t.check('evidence guard re-registered with Inventory', J.EvidenceGuardActive())
            end
            local waitMs = math.max(0, state.endsAt - Repo.Now(DB.value)) + (JusticeConfig.WarrantExpirySweepSeconds * 2 + 10) * 1000
            print(('[JusticeRestartChecklist] waiting up to %d s for the background sweep...'):format(math.ceil(waitMs / 1000)))
            local stop, sentence = GetGameTimer() + waitMs, nil
            repeat
                sentence = t.call('GetSentence', { sentenceId = state.sentenceId })
                if sentence.ok and sentence.value.status == 'completed' then break end
                Wait(5000)
            until GetGameTimer() > stop
            t.check('sentence completed by the restarted worker at its deadline', sentence.ok and sentence.value.status == 'completed'
                and sentence.value.outcome == 'served', sentence.ok and sentence.value.status or t.code(sentence))
        end)
        busy = false
        if not ok then t.check('checklist completed', false, tostring(failure)) end
        print(('[JusticeRestartChecklist] cleanup records=%d'):format(S.Cleanup({ state.subjectId })))
        DeleteResourceKvp(restartKey)
        t.done()
    elseif args[1] == 'abort' then
        print(('[JusticeRestartChecklist] aborted; cleanup records=%d'):format(S.Cleanup({})))
        DeleteResourceKvp(restartKey)
    else
        print('[JusticeRestartChecklist] usage: JusticeRestartChecklist prepare <actorUuid|source> <subjectUuid|source> | verify | abort')
    end
end)
