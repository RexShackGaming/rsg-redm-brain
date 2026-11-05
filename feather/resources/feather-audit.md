# feather-audit

Version 0.1.1. Cross-domain audit, investigation, and operator alerting for Feather Framework

0.1.1 validates Access grant-preservation events and their transfer proof context. Feather Audit provides server-only ingestion of reviewed domain events into an append-only investigation projection. Domains retain their authoritative records.

Source: https://github.com/FeatherFramework/feather-audit

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-audit']:Name)

**server:** `GetCapabilities()`, `GetCorrelation(request, actorSource)`, `GetEvent(request, actorSource)`, `GetHealth()`, `GetVisibilitySmokeFixture()`, `Ingest(event)`, `IsDevelopmentReadPaused(actorSource, sessionId)`, `Search(request, actorSource)`

## Commands (RegisterCommand)

**server:** `/AuditArmReadPause`, `/AuditContractSmokeTest`, `/AuditDependencySmokeTest`, `/AuditFailureBoundarySmokeTest`, `/AuditHealthSmokeTest`, `/AuditIngestionSmokeTest`, `/AuditMigrationSmokeTest`, `/AuditPaginationSmokeTest`, `/AuditProjectionSmokeTest`, `/AuditSearchFoundationSmokeTest`, `/AuditVisibilitySmokeTest`

## Public (table) functions

**producer/event_builder.lua:** `FeatherAuditProducerEvent.Build(values, options)`

**producer/event_id.lua:** `FeatherAuditProducerId.Generate()`

**producer/outbox.lua:** `FeatherAuditProducerOutbox.Create(options)`, `instance.Enqueue(transaction, event, validation)`, `instance.PublishOnce(owner)`

**server/core/config.lua:** `FeatherAuditConfig.Validate()`

**server/core/runtime.lua:** `FeatherAudit.SetState(status, ready, reason)`, `FeatherAudit.SetDatabaseState(ready, migrations, reason)`, `FeatherAudit.IncrementMetric(name)`, `FeatherAudit.GetHealth()`, `FeatherAudit.GetCapabilities()`

**server/database/migrations.lua:** `FeatherAuditMigrations.Run()`

**server/ingestion/rate_limit.lua:** `FeatherAuditRateLimit.Allow(sourceResource, maximum, now)`

**server/ingestion/service.lua:** `FeatherAuditIngestion.Ingest(event, verifiedSource)`

**server/repositories/events.lua:** `FeatherAuditEventRepository.Accept(event, canonical, contextJson)`, `FeatherAuditEventRepository.FindByProducerIdentity(sourceResource, sourceInstance, eventId)`

**server/repositories/quarantine.lua:** `FeatherAuditQuarantineRepository.Record(sourceResource, event, rejection)`, `FeatherAuditQuarantineRepository.CountOpen()`

**server/repositories/search.lua:** `FeatherAuditSearchRepository.Read(request, identity)`

**server/services/authorization.lua:** `FeatherAuditAuthorization.Search(request, actorSource, caller, operation)`

**server/services/projection.lua:** `FeatherAuditProjection.Context(eventType, version, encoded, sensitive)`

**server/services/read_pause.lua:** `FeatherAuditReadPause.Await(actorSource, sessionId)`

**server/services/search.lua:** `FeatherAuditSearch.Validate(request)`, `FeatherAuditSearch.Read(request, identity, operation)`

**shared/contract/canonical.lua:** `FeatherAuditCanonical.Encode(value, hint)`, `FeatherAuditCanonical.EncodeEvent(event, eventSchema)`

**shared/contract/registry.lua:** `FeatherAuditSchemaRegistry.Register(schema)`, `FeatherAuditSchemaRegistry.Get(eventType, eventVersion)`, `FeatherAuditSchemaRegistry.HasEventType(eventType)`, `FeatherAuditSchemaRegistry.ResetForTests()`

**shared/contract/validator.lua:** `FeatherAuditValidator.Validate(event, options)`

**tests/integration/outbox_harness_spec.lua:** `repository.insert(_, row)`, `repository.lease(_, owner, expiresAt, currentTime)`, `repository.markDelivered(row, auditEventId)`, `repository.markRetry(row, nextAttemptAt, code, attempt)`, `repository.markQuarantined(row, code)`, `transport.ingest(event)`

**tests/support/assertions.lua:** `Assert.equal(expected, actual, message)`, `Assert.truthy(value, message)`, `Assert.falsy(value, message)`

**tests/support/fixtures.lua:** `Fixtures.validTransfer(overrides)`
