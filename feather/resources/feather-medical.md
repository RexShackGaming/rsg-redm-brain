# feather-medical

Version 0.1.2. A RedM medical system for Feather Framework

Weapons integration: server `ReadNativeWeaponCondition(source, context)` is a read-only, Weapons-only current-session condition snapshot for the scoped native death-wear seal. It performs no initialization, recovery or lifecycle mutation.

Source: https://github.com/FeatherFramework/feather-medical

**Dependencies:** `feather-mysql`, `feather-core`, `feather-toolkit`

Has NUI (`ui_page`).

## Exports (call as exports['feather-medical']:Name)

**server:** `GetHealth()`, `PrepareCharacter(characterId, source, sessionId)`, `ReadNativeWeaponCondition(source,context)`, `RequestStaffRecovery(actor, target)`

**client:** `GetHealth()`, `GetLifeState()`

## Commands (RegisterCommand)

**server:** `/MedicalHealth`, `/MedicalOutboxSmokeTest`, `/MedicalPersistenceSmokeTest`, `/MedicalRecoverySmokeTest`, `/MedicalRevive`, `/MedicalStorageSmokeTest`

**client:** `/MedicalRespawn`, `/MedicalStatus`

## Public (table) functions

**client/lifecycle.lua:** `MedicalClientLifecycle.Publish(snapshot, expected)`

**server/gameplay.lua:** `G.Snapshot(record, context)`, `G.Prepare(characterId, source, sessionId)`, `G.Observe(source, context, expectedRevision)`, `G.Pending(source, context)`, `G.RequestDoctor(source, context)`, `G.Acknowledge(source, context, operationId, deliveryToken)`, `G.RequestStaff(actor, target)`

**server/hospitals.lua:** `H.Validate(points)`, `H.HasEnabled(points)`, `H.Nearest(points, position)`

**server/lifecycle.lua:** `M.ValidateConfig(config)`, `M.New(characterId, now)`, `M.ObserveLethal(record, config, now, episodeId)`, `M.Advance(record, now)`, `M.CanRequestDoctor(record, now)`, `M.CompleteRecovery(record, episodeId, now)`

**server/migrate.lua:** `MedicalMigration.Run()`

**server/outbox.lua:** `O.Validate(payload)`, `O.Tick(repository, publish, decode, now)`

**server/repository.lua:** `R.Get(characterId)`, `R.HasHistory(characterId)`, `R.PendingRecovery(characterId)`, `R.BeginRecovery(characterId, requestedBy, now, operationId, isCurrent, kind, destination)`, `R.Initialize(characterId, now)`, `R.ResetOnActivation(characterId, now, eventId, isCurrent)`, `R.CompleteStaffRecovery(characterId, operationId, now, eventId, isCurrent)`, `R.ObserveLethal(characterId, config, now, episodeId, eventId, isCurrent, expectedRevision)`, `R.Advance(characterId, now, eventId)`, `R.Due(now)`, `R.PendingEvents()`, `R.MarkPublished(eventId, now)`

**server/worker.lua:** `MedicalWorker.Tick(now, repository, newId)`

**tests/recovery_spec.lua:** `tx.one(sql, id)`, `tx.insert(sql, id, episode, character, kind, actor, now)`, `tx.exec(sql, ...)`, `DB.transaction(callback)`

**tests/storage_spec.lua:** `tx.one()`, `tx.insert(sql)`, `tx.exec(sql, state, episode, opened, bleed, doctor, revision, updated)`, `DB.transaction(callback)`
