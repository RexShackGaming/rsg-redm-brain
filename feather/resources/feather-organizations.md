# feather-organizations

Version 0.2.2. Durable organization identity for the Feather Framework

Alpha release 0.2.1 (2026-10-20): native Jobs and Access reader integration, development fixtures and real employment/grant lifecycle acceptance. Config.DevMode stays true at owner direction for early alpha/pre-alpha releases. No schema change.

Source: https://github.com/FeatherFramework/feather-organizations

**Dependencies:** `feather-mysql`, `feather-core`

## Exports (call as exports['feather-organizations']:Name)

**server:** `AwaitReady(timeoutMs)`, `ChangeOrganizationStatus(request)`, `CreateOrganization(request)`, `FindOrganizationByKey(request)`, `GetCapabilities()`, `GetHealth()`, `GetOrganization(request)`, `GetOrganizationType(key)`, `GrantOrganizationInterest(request)`, `InspectOrganizationHistory(request)`, `ListOrganizationChildren(request)`, `ListOrganizationInterestTypes()`, `ListOrganizationInterests(request)`, `ListOrganizationTypes()`, `ListOrganizations(request)`, `RemoveParentOrganization(request)`, `RevokeOrganizationInterest(request)`, `SetParentOrganization(request)`, `UpdateOrganizationIdentity(request)`

## Commands (RegisterCommand)

**server:** `/OrganizationsReleaseContractSmokeTest`

## Public (table) functions

**server/directory.lua:** `OrganizationDirectory.ValidateList(request)`, `OrganizationDirectory.List(request,resource)`, `OrganizationDirectory.ValidateUpdate(request)`, `OrganizationDirectory.Update(request,resource)`

**server/events.lua:** `OrganizationEvents.Record(tx,organizationId,eventType,resource,requestId,reason,revision,details)`, `OrganizationEvents.Start()`, `OrganizationEvents.Stop()`, `OrganizationEvents.State()`, `OrganizationEvents.ValidateHistory(request)`, `OrganizationEvents.History(request,resource)`

**server/foundation.lua:** `Organizations.RegisterDevCommand(name,handler,restricted)`, `Organizations.Copy(value)`, `Organizations.Ok(value)`, `Organizations.Err(code, message, details)`, `Organizations.Integer(value, minimum, maximum)`, `Organizations.Uuid(value)`, `Organizations.SetState(state, phase, failure)`, `Organizations.Fail(result)`, `Organizations.GetHealth()`, `Organizations.GetCapabilities()`, `Organizations.AwaitReady(timeoutMs)`, `Organizations.CheckRead(resource)`, `Organizations.ValidateConfig()`

**server/hierarchy.lua:** `OrganizationHierarchy.CheckStartup()`, `OrganizationHierarchy.ValidateGraph(parents)`, `OrganizationHierarchy.Validate(request,operation)`, `OrganizationHierarchy.Change(request,resource,operation)`, `OrganizationHierarchy.Children(request,resource)`

**server/interests.lua:** `OrganizationInterests.CharacterProvider()`, `OrganizationInterests.CharacterSnapshot(result,holderId)`, `OrganizationInterests.ResolveHolder(request,resource)`, `OrganizationInterests.Types(resource)`, `OrganizationInterests.ValidateGrant(request)`, `OrganizationInterests.EvaluatePolicy(evaluate,action,context)`, `OrganizationInterests.Change(request,resource,operation)`, `OrganizationInterests.ValidateList(request)`, `OrganizationInterests.List(request,resource)`

**server/lifecycle.lua:** `OrganizationLifecycle.CanTransition(from, to)`, `OrganizationLifecycle.Validate(request)`, `OrganizationLifecycle.Change(request, resource)`

**server/migrations.lua:** `OrganizationMigrations.Run()`

**server/organizations.lua:** `OrganizationIdentity.Validate(request)`, `OrganizationIdentity.Get(request, resource)`, `OrganizationIdentity.Find(request, resource)`, `OrganizationIdentity.Create(request, resource)`

**server/types.lua:** `OrganizationTypes.Load()`, `OrganizationTypes.Get(key, resource)`, `OrganizationTypes.List(resource)`
