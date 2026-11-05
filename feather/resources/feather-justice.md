# feather-justice

Version 0.3.0. Authoritative legal records: cases, charges, warrants, citations, custody, rulings, sentences and evidence

The authoritative registry of legal records for the Feather Framework: jurisdictions and their statutes (the penal code), cases and their parties, charges, warrants, citations, arrest and custody authority, rulings, sentences,

Source: https://github.com/FeatherFramework/feather-justice

**Dependencies:** `feather-mysql`, `feather-core`, `feather-character`

## Exports (call as exports['feather-justice']:Name)

**server:** `AwaitReady(timeoutMs)`, `GetCapabilities()`, `GetHealth()`

## Public (table) functions

**server/access.lua:** `A.Gate(owner)`, `J.CaseAllowed(query, case, actor, write)`, `A.CasePrincipal(request, owner, action, caseId, attributes, write)`, `A.LockCase(tx, caseId, owner, actor, write)`, `A.Editable(case)`, `A.Closed(case)`, `A.Character(characterId)`, `A.Organization(organizationId)`, `A.AuditSearch(owner, actor, action, subjectId)`, `A.Page(kind, items, more, extra)`, `A.PageArgs(request)`

**server/cases.lua:** `J.RedactCase(tx, case, marker, context)`

**server/citations.lua:** `J.CitationConfigValid()`

**server/custody.lua:** `J.WarrantlessEnabled()`, `J.ReleaseForSentence(tx, sentence, owner, context, reason)`

**server/definitions.lua:** `J.StatuteInForce(statute, now)`

**server/evidence.lua:** `J.EvidenceGuardActive()`, `J.ReloadEvidenceIndex()`, `J.InstallEvidenceGuard()`, `J.RemoveEvidenceGuard()`, `J.EvidenceGuardLost()`, `J.ReconcileEvidence(limit)`

**server/foundation.lua:** `Justice.Sha256(message)`, `Justice.NewUuid()`, `Justice.Ok(value)`, `Justice.Err(code, message)`, `Justice.Copy(value)`, `Justice.Uuid(value)`, `Justice.Text(value, maximum)`, `Justice.Token(value, maximum)`, `Justice.Integer(value, minimum, maximum)`, `Justice.Fields(request, fields)`, `Justice.State(state, phase)`, `Justice.Generation()`, `Justice.Ready()`, `Justice.Health()`, `Justice.Capabilities()`, `Justice.Metrics()`, `Justice.ResetMetrics()`, `Justice.Call(resource, operation, ...)`, `Justice.WithActor(actor, callback)`, `Justice.Trusted(resource)`, `Justice.Principal(resource, action, request, jurisdictionId, definitions, attributes)`, `Justice.Current(actor)`, `Justice.Export(name, handler)`

**server/judicial.lua:** `J.CloseSentence(tx, row, outcome, context, owner)`, `J.SweepSentences()`

**server/legal.lua:** `J.SweepWarrants()`

**server/mutation.lua:** `M.Fields(request, extras, mutation)`, `M.Snapshot(kind, row, extra)`, `M.Fact(tx, snapshot, fact, context)`, `M.Run(operation, request, owner, actor, body)`

**server/operations.lua:** `J.RunRetention(dryRun)`, `r.check(label, condition, detail)`, `r.done()`, `J.MigrationSmoke()`, `J.PolicySmoke(player)`, `J.RunScenarios(prefix, actorArg, subjectArg, options, scenarios)`

**server/repository.lua:** `Repo.Now(query)`, `Repo.Get(query, kind, id, owner, lock)`, `Repo.GetByKey(query, kind, column, key, owner)`, `Repo.KeyExists(query, kind, column, key)`, `Repo.Insert(tx, kind, values)`, `Repo.Update(tx, kind, id, values, nulls)`, `Repo.IsJudge(query, caseId, characterId)`, `Repo.MemberRole(query, caseId, characterId, write)`, `Repo.Page(query, kind, owner, options)`, `Repo.ActiveCustody(query, subjectId, lock)`, `Repo.ActiveCustodial(query, subjectId, lock)`, `Repo.ActivePartySlot(query, caseId, partyType, reference, role)`, `Repo.ActiveEvidence(query, caseId, evidenceType, evidenceId)`, `Repo.OpenCharges(tx, caseId)`, `Repo.CaseChildren(query, kind, caseId, lock, limit)`, `Repo.DueWarrants(now, limit)`, `Repo.DueSentences(now, limit)`, `Repo.Wake(tx, kind, id, delayMs)`, `Repo.DueWorkflows(limit)`, `Repo.DeferWorkflow(id, delayMs, code)`, `Repo.WorkflowCode(id, code)`, `Repo.DeleteWorkflow(tx, id)`, `Repo.WakeNow(id)`, `Repo.WakeObligation(obligationId)`, `Repo.Workflows(limit)`, `Repo.ClaimReceipt(tx, owner, requestId, fingerprint, actorId)`, `Repo.StoreReceipt(tx, owner, requestId, kind, id, result)`, `Repo.RedactReceipts(tx, recordId)`, `Repo.ReceiptRecord(query, owner, requestId)`, `Repo.AuditFact(tx, fact)`, `Repo.PendingOutbox(limit)`, `Repo.MarkDelivered(eventId)`, `Repo.History(recordId, limit)`, `Repo.Locate(id, owner)`, `Repo.AccessAudit(entry)`, `Repo.AccessHistory(subjectId, limit)`, `Repo.ActiveInventoryEvidence()`, `Repo.ActiveInventoryLinks(limit)`, `Repo.PurgeDeliveredOutbox(cutoffMs, dryRun)`, `Repo.RedactionCandidates(cutoffMs, limit)`, `Repo.Backlog()`, `Repo.UndeliveredForOwner(owner)`, `Repo.DeleteOwnerNamespace(owner)`, `Repo.AccessAuditCleanup(subjectIds)`

**server/scenarios.lua:** `S.Context(prefix, actorId, subjectId, options)`, `t.check(label, condition, detail)`, `t.skip(label, why)`, `t.rid()`, `t.as(actor, name, request)`, `t.call(name, request)`, `t.code(result)`, `t.done()`, `S.Fixture(t)`, `S.Case(t)`, `S.Warrant(t)`, `S.Citation(t)`, `S.Custody(t)`, `S.Evidence(t)`, `S.Judicial(t)`, `S.Deadlines(t)`, `S.Privacy(t)`, `S.Cleanup(subjectIds)`

**server/schema.lua:** `Justice.Migrate()`, `Justice.ExpectedMigrations()`, `Justice.MigrationLedger()`, `Justice.SchemaTables()`

**server/workflows.lua:** `J.ProcessWorkflows()`, `J.SubscribeContracts()`, `J.ResetContractSubscriptions()`

**tests/harness.lua:** `json.encode(v)`, `json.decode(s)`, `api.query(sql, ...)`, `api.one(sql, ...)`, `api.value(sql, ...)`, `api.exec(sql, ...)`, `DB.transaction(callback)`, `t.check(label, condition, detail)`, `t.rid()`, `t.call(name, request, options)`, `t.code(result)`, `t.advance(ms)`, `t.declarations()`, `t.ago(table_, column, idColumn, id, ms)`
