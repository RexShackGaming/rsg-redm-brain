# feather-access

Version 0.1.1. Durable capability delegation for the Feather Framework

Doors target configuration: `doors.group` is owned by `feather-doors` with exact `door.lock`/`door.unlock` vocabulary. Doors is a trusted target-context reader only; this adds no grant reader/manager or Core grant-service policy. Its current target

Source: https://github.com/FeatherFramework/feather-access

**Dependencies:** `feather-mysql`, `feather-core`

## Commands (RegisterCommand)

**server:** `/AccessAlphaReleaseSmokeTest`, `/AccessAuditInspect`, `/AccessAuditRetry`, `/AccessAuditStatus`, `/AccessReleaseContractSmokeTest`, `/AccessStatus`

## Public (table) functions

**lib/audit/producer/event_builder.lua:** `FeatherAuditProducerEvent.Build(values, options)`

**lib/audit/producer/event_id.lua:** `FeatherAuditProducerId.Generate()`

**lib/audit/producer/outbox.lua:** `FeatherAuditProducerOutbox.Create(options)`, `instance.Enqueue(transaction, event, validation)`, `instance.PublishOnce(owner)`

**lib/audit/shared/contract/canonical.lua:** `FeatherAuditCanonical.Encode(value, hint)`, `FeatherAuditCanonical.EncodeEvent(event, eventSchema)`

**lib/audit/shared/contract/registry.lua:** `FeatherAuditSchemaRegistry.Register(schema)`, `FeatherAuditSchemaRegistry.Get(eventType, eventVersion)`, `FeatherAuditSchemaRegistry.HasEventType(eventType)`, `FeatherAuditSchemaRegistry.ResetForTests()`

**lib/audit/shared/contract/validator.lua:** `FeatherAuditValidator.Validate(event, options)`

**server/audit.lua:** `A.ValidateConfig()`, `A.Build(fact, occurredEpoch)`, `repository.insert(tx, row)`, `repository.lease(batchSize, leaseOwner, expiresAt, now)`, `repository.markDelivered(row, auditEventId, result)`, `repository.markRetry(row, nextAttemptAt, resultCode, attemptCount)`, `repository.markQuarantined(row, resultCode)`, `A.Enqueue(tx, fact)`, `A.Step(force, eventId)`, `A.Start()`, `A.Stop()`, `A.AuditStopped()`, `A.FixtureStopped()`, `A.State()`, `A.Counts()`, `A.RetryQuarantine(eventId)`, `A.Fixture(request, caller)`

**server/dependencies.lua:** `Access.CheckDependencies()`, `Access.StartDependencies()`

**server/employment.lua:** `E.ValidateConfig()`, `E.Catalog(id, scope)`, `E.Resolve(id, scope, request)`, `E.Start()`, `E.Fixture(request, caller)`, `E.Stopped(resource)`

**server/fence.lua:** `F.Mutate(fn, request, caller)`, `F.Run(callback, caller)`, `F.Valid(token, caller)`, `F.Stopped(resource)`, `F.State()`

**server/foundation.lua:** `Access.LocalReady()`, `Access.Copy(value)`, `Access.Ok(value)`, `Access.Err(code, message, details)`, `Access.Integer(value, minimum, maximum)`, `Access.SetState(state, phase, failure)`, `Access.Fail(result)`, `Access.GetHealth()`, `Access.GetCapabilities()`, `Access.AwaitReady(timeoutMs)`, `Access.ValidateConfig()`, `Access.Uuid(value)`, `Access.Key(value)`, `Access.OnlyFields(value, fields)`, `Access.Ready()`

**server/grant_support.lua:** `G.Fence(actor)`, `G.ValidateConfig()`, `G.Token(value, maximum)`, `G.Begin(request, caller, group)`, `G.Current(actor)`, `G.Character(characterId)`, `G.Context(targetType, targetId)`, `G.Capability(context, capability)`, `G.Fingerprint(operation, request, actor, fields)`, `G.Replay(caller, requestId, operation, fingerprint, query)`, `G.Mutate(caller, requestId, operation, fingerprint, actor, body)`, `G.Clock(tx)`, `G.Snapshot(row)`, `G.Record(tx, eventId, eventType, grant, actor, request)`

**server/grants.lua:** `G.Grant(request, caller)`, `G.Revoke(request, caller)`, `G.Check(request, caller)`, `G.ListTarget(request, caller)`, `G.ListGrantee(request, caller)`, `G.Find(request, caller)`

**server/migrations.lua:** `Access.Migrations.Run()`

**server/preservation.lua:** `P.Resolve(request,caller)`, `P.Prepare(request,caller)`, `P.Adopt(request,caller)`

**server/providers.lua:** `Access.Providers.ValidateConfig()`, `Access.Providers.RegisterTarget(request, caller)`, `Access.Providers.RegisterMembership(request, caller)`, `Access.Providers.UnregisterTarget(request, caller)`, `Access.Providers.UnregisterMembership(request, caller)`, `Access.Providers.TransferProof(context, actor, request, manifest)`, `Access.Providers.Authorize(context, actor, action, capability)`, `Access.Providers.Catalog(organizationId)`, `Access.Providers.ResolveTarget(request, caller)`, `Access.Providers.ResolveMembership(request, caller)`, `Access.Providers.DropOwner(resource)`, `Access.Providers.Counts()`, `Access.Providers.TargetStatus(targetType,resource)`
