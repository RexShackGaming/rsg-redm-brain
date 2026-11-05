# feather-jobs

Version 0.2.1. Authoritative job definitions, grades, character assignments, and duty state for the Feather Framework

Alpha release 0.2.1 (2026-10-20): Config.DevMode stays true for this early-alpha release at owner direction. Native organization fixtures are supplied by the sibling feather-jobs-tests resource. Run NativeDomainFixtureTest <stableRun> [characterUUID|serverID]

Source: https://github.com/FeatherFramework/feather-jobs

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-jobs']:Name)

**server:** `AwaitReady(timeoutMs)`, `GetCapabilities()`, `GetHealth()`

## Commands (RegisterCommand)

**server:** `/JobsNativeIntegrationSmokeTest`, `/JobsReleaseContractSmokeTest`

## Public (table) functions

**server/assignments.lua:** `JobAssignments.Snapshot(row)`, `JobAssignments.Read(tx, assignmentId)`, `JobAssignments.CanMutate(ownerResource, resource)`, `JobAssignments.LockCharacter(tx, characterId)`, `JobAssignments.Begin(request, resource, allowedFields)`, `JobAssignments.Policy(request, resource, subject)`, `JobAssignments.Create(request, resource)`, `JobAssignments.ChangeGrade(request, resource)`, `JobAssignments.End(request, resource)`, `JobAssignments.Get(request, resource)`, `JobAssignments.ListOpen(characterId)`, `JobAssignments.List(request, resource)`

**server/definitions.lua:** `JobDefinitions.Snapshot(row)`, `JobDefinitions.GradeSnapshot(row)`, `JobDefinitions.Register(request, resource)`, `JobDefinitions.Update(request, resource)`, `JobDefinitions.DefineGrade(request, resource)`, `JobDefinitions.Load(jobId, jobKey)`, `JobDefinitions.Get(request, resource)`, `JobDefinitions.List(request, resource)`

**server/effective.lua:** `JobEffective.SetDuty(request, resource)`, `JobEffective.SetActive(request, resource)`, `JobEffective.Build(characterId)`, `JobEffective.GetSnapshot(request, resource)`, `JobEffective.Check(request, resource)`

**server/events.lua:** `JobEvents.RecordMany(tx, entries)`, `JobEvents.Record(tx, eventType, spec, eventId)`, `JobEvents.Start()`, `JobEvents.Stop()`, `JobEvents.State()`, `JobEvents.History(request, resource)`

**server/foundation.lua:** `Jobs.RegisterDevCommand(name, handler, restricted)`, `Jobs.Copy(value)`, `Jobs.Ok(value)`, `Jobs.Err(code, message, details)`, `Jobs.Integer(value, minimum, maximum)`, `Jobs.Uuid(value)`, `Jobs.Key(value, maximum)`, `Jobs.Text(value, maximum)`, `Jobs.Token(value, maximum)`, `Jobs.Reason(value)`, `Jobs.Fields(request, allowed)`, `Jobs.ValidateCommon(request)`, `Jobs.Allowed(extra)`, `Jobs.Fingerprint(operation, request, fields)`, `Jobs.SetState(state, phase, failure)`, `Jobs.Fail(result)`, `Jobs.IsReady()`, `Jobs.GetHealth()`, `Jobs.GetCapabilities()`, `Jobs.AwaitReady(timeoutMs)`, `Jobs.CheckAccess(group, resource)`, `Jobs.CheckRead(resource)`, `Jobs.Authorize(action, resource, requestId, subject)`, `Jobs.Actor(request)`, `Jobs.ResolveCharacter(characterId)`, `Jobs.ValidateEmployer(employerType, employerId)`, `Jobs.Mutate(spec)`, `Jobs.NewIds(tx, count, withNow)`, `Jobs.FindOperation(request, resource)`, `Jobs.ValidateConfig()`, `Jobs.Export(name, operation)`

**server/migrations.lua:** `JobMigrations.Run()`

**server/rpc.lua:** `JobRoutes.Register()`
