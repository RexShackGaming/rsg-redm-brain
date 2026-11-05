# feather-property

Version 0.3.0. Authoritative registry of real property (houses, hotel rooms, premises) and its owners and tenants for the Feather Framework

Current version: **0.3.0** adds canonical Property link context for trusted readers and Doors binding integration. `GetPropertyLinkContext({linkType, externalId})` is a trusted-reader server API returning `{ok=true,value={linkId,propertyId,epoch,status}}` from one canonical

Source: https://github.com/FeatherFramework/feather-property

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-property']:Name)

**server:** `AwaitReady(timeoutMs)`, `GetCapabilities()`, `GetHealth()`

## Commands (RegisterCommand)

**server:** `/PropertyAccessStatus`, `/PropertyReleaseContractSmokeTest`

## Public (table) functions

**server/delegation.lua:** `D.Resolve(request)`, `D.Authorize(request)`, `D.Register()`, `D.Grant(request, resource)`, `D.Revoke(request, resource)`, `D.Check(request, resource)`, `D.ResolveManifest(manifestId,targetId)`, `D.Prepare(request,resource)`, `D.Adopt(request,resource)`, `D.Transfer(request)`, `D.FindDelegationOperation(request,resource)`

**server/events.lua:** `PropertyEvents.RecordMany(tx, entries)`, `PropertyEvents.Record(tx, eventType, spec, eventId)`, `PropertyEvents.Start()`, `PropertyEvents.Stop()`, `PropertyEvents.State()`, `PropertyEvents.History(request, resource)`

**server/foundation.lua:** `Property.RegisterDevCommand(name, handler, restricted)`, `Property.Copy(value)`, `Property.Ok(value)`, `Property.Err(code, message, details)`, `Property.Integer(value, minimum, maximum)`, `Property.Uuid(value)`, `Property.Key(value, maximum)`, `Property.PropertyKey(value)`, `Property.Label(value)`, `Property.Token(value, maximum)`, `Property.Reason(value)`, `Property.Fields(request, allowed)`, `Property.Allowed(extra)`, `Property.ValidateCommon(request)`, `Property.Begin(request, resource, allowedFields)`, `Property.ValidateMetadata(metadata)`, `Property.Canonical(value)`, `Property.Fingerprint(operation, request, fields)`, `Property.SetState(state, phase, failure)`, `Property.Fail(result)`, `Property.IsReady()`, `Property.GetHealth()`, `Property.GetCapabilities()`, `Property.AwaitReady(timeoutMs)`, `Property.CheckAccess(group, resource)`, `Property.CheckRead(resource)`, `Property.CanMutate(managerResource, resource)`, `Property.Authorize(action, resource, requestId, subject)`, `Property.Actor(request)`, `Property.Policy(action, request, resource, subject)`, `Property.ValidateHolder(propertyType, holderType, holderId)`, `Property.Mutate(spec)`, `Property.NewIds(tx, count, withNow)`, `Property.FindOperation(request, resource)`, `Property.ValidateConfig()`, `Property.Export(name, operation)`

**server/interests.lua:** `PropertyInterests.Grant(request, resource)`, `PropertyInterests.End(request, resource)`, `PropertyInterests.Transfer(request, resource)`, `PropertyInterests.Check(request, resource)`, `PropertyInterests.SweepExpired()`

**server/links.lua:** `PropertyLinks.Add(request, resource)`, `PropertyLinks.Remove(request, resource)`, `PropertyLinks.FindByLink(request, resource)`, `PropertyLinks.Context(request,resource)`

**server/migrations.lua:** `PropertyMigrations.Run()`

**server/records.lua:** `PropertyRecords.Snapshot(row, interestRows, includeMetadata, linkRows)`, `PropertyRecords.Read(tx, propertyId)`, `PropertyRecords.Lock(tx, propertyId)`, `PropertyRecords.CheckMutable(row, resource, expectedRevision)`, `PropertyRecords.LockInterests(tx, propertyId)`, `PropertyRecords.Register(request, resource)`, `PropertyRecords.ChangeStatus(request, resource)`, `PropertyRecords.UpdateMetadata(request, resource)`, `PropertyRecords.Get(request, resource)`, `PropertyRecords.FindByKey(request, resource)`, `PropertyRecords.QueryByHolder(holderType, holderId, options)`, `PropertyRecords.ListByHolder(request, resource)`

**server/rpc.lua:** `PropertyRoutes.Register()`
