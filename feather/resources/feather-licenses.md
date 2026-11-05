# feather-licenses

Version 0.1.0. Authoritative registry of issued licenses, certifications and permits for the Feather Framework

The authoritative registry of issued licenses, certifications and permits for the Feather Framework: hunting, mining or weapon licenses, professional certifications, business permits. Licenses owns each license kind (definition),

Source: https://github.com/FeatherFramework/feather-licenses

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-licenses']:Name)

**server:** `AwaitReady(timeoutMs)`, `GetCapabilities()`, `GetHealth()`

## Commands (RegisterCommand)

**server:** `/LicensesReleaseContractSmokeTest`

## Public (table) functions

**server/definitions.lua:** `LicenseDefinitions.Snapshot(row)`, `LicenseDefinitions.Owns(ownerResource, resource)`, `LicenseDefinitions.Register(request, resource)`, `LicenseDefinitions.Update(request, resource)`, `LicenseDefinitions.Get(request, resource)`, `LicenseDefinitions.List(request, resource)`

**server/events.lua:** `LicenseEvents.RecordMany(tx, entries)`, `LicenseEvents.Record(tx, eventType, spec, eventId)`, `LicenseEvents.Start()`, `LicenseEvents.Stop()`, `LicenseEvents.State()`, `LicenseEvents.History(request, resource)`

**server/expiry.lua:** `LicenseExpiry.Sweep()`, `LicenseExpiry.Start()`, `LicenseExpiry.Stop()`

**server/foundation.lua:** `Licenses.RegisterDevCommand(name, handler, restricted)`, `Licenses.Copy(value)`, `Licenses.Ok(value)`, `Licenses.Err(code, message, details)`, `Licenses.Integer(value, minimum, maximum)`, `Licenses.Uuid(value)`, `Licenses.Key(value, maximum)`, `Licenses.Label(value)`, `Licenses.Token(value, maximum)`, `Licenses.Reason(value)`, `Licenses.Fields(request, allowed)`, `Licenses.Allowed(extra)`, `Licenses.ValidateCommon(request)`, `Licenses.Begin(request, resource, group, allowedFields)`, `Licenses.ValidateScope(scope)`, `Licenses.Canonical(value)`, `Licenses.Fingerprint(operation, request, fields)`, `Licenses.SetState(state, phase, failure)`, `Licenses.Fail(result)`, `Licenses.IsReady()`, `Licenses.GetHealth()`, `Licenses.GetCapabilities()`, `Licenses.AwaitReady(timeoutMs)`, `Licenses.CheckAccess(group, resource)`, `Licenses.CheckRead(resource)`, `Licenses.Authorize(action, resource, requestId, subject)`, `Licenses.Actor(request)`, `Licenses.Policy(action, request, resource, subject)`, `Licenses.ResolveOrganization(organizationId)`, `Licenses.ValidateHolder(holderTypes, holderType, holderId)`, `Licenses.Mutate(spec)`, `Licenses.NewIds(tx, count, withNow)`, `Licenses.FindOperation(request, resource)`, `Licenses.ValidateConfig()`, `Licenses.Export(name, operation)`

**server/licenses.lua:** `LicenseRecords.Snapshot(row, includeScope)`, `LicenseRecords.Read(tx, licenseId)`, `LicenseRecords.Issue(request, resource)`, `LicenseRecords.Renew(request, resource)`, `LicenseRecords.Suspend(request, resource)`, `LicenseRecords.Reinstate(request, resource)`, `LicenseRecords.Revoke(request, resource)`, `LicenseRecords.Get(request, resource)`, `LicenseRecords.Check(request, resource)`, `LicenseRecords.QueryByHolder(holderType, holderId, options)`, `LicenseRecords.ListByHolder(request, resource)`

**server/migrations.lua:** `LicenseMigrations.Run()`

**server/rpc.lua:** `LicenseRoutes.Register()`
