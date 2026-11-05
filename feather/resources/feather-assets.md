# feather-assets

Version 0.2.1. Authoritative registry of persistent world assets (horses, wagons, boats) and their ownership for the Feather Framework

For transfer adoption, a trusted manager calls `PrepareDelegationPreservation` with assetId, actorSource, requestId, reasonCode and grants (`grantId` plus expectedRevision). Include its manifestId as `preservationManifestId` in normal

Source: https://github.com/FeatherFramework/feather-assets

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-assets']:Name)

**server:** `AwaitReady(timeoutMs)`, `GetCapabilities()`, `GetHealth()`

## Commands (RegisterCommand)

**server:** `/AssetsAccessStatus`, `/AssetsReleaseContractSmokeTest`

## Public (table) functions

**server/delegation.lua:** `D.Resolve(request)`, `D.Authorize(request)`, `D.Register()`, `D.Grant(request, resource)`, `D.Revoke(request, resource)`, `D.Check(request, resource)`, `D.ResolveManifest(manifestId,targetId)`, `D.Prepare(request,resource)`, `D.Adopt(request,resource)`, `D.Transfer(request)`, `D.FindDelegationOperation(request,resource)`

**server/events.lua:** `AssetEvents.RecordMany(tx, entries)`, `AssetEvents.Record(tx, eventType, spec, eventId)`, `AssetEvents.Start()`, `AssetEvents.Stop()`, `AssetEvents.State()`, `AssetEvents.History(request, resource)`

**server/foundation.lua:** `Assets.RegisterDevCommand(name, handler, restricted)`, `Assets.Copy(value)`, `Assets.Ok(value)`, `Assets.Err(code, message, details)`, `Assets.Integer(value, minimum, maximum)`, `Assets.Uuid(value)`, `Assets.Key(value, maximum)`, `Assets.ModelKey(value)`, `Assets.Token(value, maximum)`, `Assets.Reason(value)`, `Assets.Fields(request, allowed)`, `Assets.Allowed(extra)`, `Assets.ValidateCommon(request)`, `Assets.Begin(request, resource, allowedFields)`, `Assets.ValidateMetadata(metadata)`, `Assets.Canonical(value)`, `Assets.Fingerprint(operation, request, fields)`, `Assets.SetState(state, phase, failure)`, `Assets.Fail(result)`, `Assets.IsReady()`, `Assets.GetHealth()`, `Assets.GetCapabilities()`, `Assets.AwaitReady(timeoutMs)`, `Assets.CheckAccess(group, resource)`, `Assets.CheckRead(resource)`, `Assets.CanMutate(managerResource, resource)`, `Assets.Authorize(action, resource, requestId, subject)`, `Assets.Actor(request)`, `Assets.Policy(action, request, resource, subject)`, `Assets.ValidateHolder(assetType, holderType, holderId)`, `Assets.Mutate(spec)`, `Assets.NewIds(tx, count, withNow)`, `Assets.FindOperation(request, resource)`, `Assets.ValidateConfig()`, `Assets.Export(name, operation)`

**server/interests.lua:** `AssetInterests.Transfer(request, resource)`, `AssetInterests.Check(request, resource)`

**server/migrations.lua:** `AssetMigrations.Run()`

**server/records.lua:** `AssetRecords.Snapshot(row, includeMetadata)`, `AssetRecords.Read(tx, assetId)`, `AssetRecords.Lock(tx, assetId)`, `AssetRecords.CheckMutable(row, resource, expectedRevision)`, `AssetRecords.LockOwner(tx, assetId)`, `AssetRecords.Register(request, resource)`, `AssetRecords.ChangeStatus(request, resource)`, `AssetRecords.UpdateMetadata(request, resource)`, `AssetRecords.Retire(request, resource)`, `AssetRecords.Get(request, resource)`, `AssetRecords.QueryByHolder(holderType, holderId, options)`, `AssetRecords.ListByHolder(request, resource)`

**server/rpc.lua:** `AssetRoutes.Register()`
