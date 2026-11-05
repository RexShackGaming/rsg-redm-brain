# feather-authority

Version 0.4.0. Durable capability and assignment authority for the Feather Framework

Feather Authority owns durable capability definitions, roles, grants, assignments, scopes, expiry, suspension, revocation, and explainable decisions. Core remains the authenticated policy-evaluation boundary, while every domain

Source: https://github.com/FeatherFramework/feather-authority

**Dependencies:** `feather-mysql`, `feather-core`, `feather-character`, `feather-organizations`

## Exports (call as exports['feather-authority']:Name)

**server:** `AwaitReady(timeoutMs)`, `ChangeAssignmentStatus(request)`, `CreateRole(request)`, `Evaluate(request)`, `FindRoleByKey(request)`, `GetAssignment(request)`, `GetCapabilities()`, `GetCapability(key)`, `GetHealth()`, `GetRole(request)`, `GrantRoleCapability(request)`, `IssueAssignment(request)`, `ListCapabilities()`, `ListEffectiveCapabilities(request)`, `ListRoleGrants(request)`, `ListSubjectAssignments(request)`, `RegisterCapabilities(request)`, `ReplaceOwnedStaffAssignment(request)`

## Commands (RegisterCommand)

**server:** `/AuthorityReleaseContractSmokeTest`

## Public (table) functions

**server/assignments.lua:** `AuthorityAssignments.ValidateIssue(request)`, `AuthorityAssignments.ValidateLifecycle(request)`, `AuthorityAssignments.ValidateReplacement(request)`, `AuthorityAssignments.Get(request, resource)`, `AuthorityAssignments.ListSubject(request, resource)`, `AuthorityAssignments.Issue(request, resource)`, `AuthorityAssignments.ChangeStatus(request, resource)`, `AuthorityAssignments.ReplaceOwned(request, resource)`

**server/capabilities.lua:** `AuthorityCapabilities.ValidateRegistration(request)`, `AuthorityCapabilities.Register(request, resource)`, `AuthorityCapabilities.Load()`, `AuthorityCapabilities.Get(key, resource)`, `AuthorityCapabilities.List(resource)`

**server/evaluation.lua:** `AuthorityEvaluation.Validate(request)`, `AuthorityEvaluation.Evaluate(request, resource)`, `AuthorityEvaluation.ListEffective(request, resource)`

**server/foundation.lua:** `Authority.RegisterDevCommand(name, handler, restricted)`, `Authority.Copy(value)`, `Authority.Ok(value)`, `Authority.Err(code, message, details)`, `Authority.Integer(value, minimum, maximum)`, `Authority.Uuid(value)`, `Authority.SetState(state, phase, failure)`, `Authority.Fail(result)`, `Authority.GetHealth()`, `Authority.GetCapabilities()`, `Authority.AwaitReady(timeoutMs)`, `Authority.CheckRead(resource)`, `Authority.ValidateConfig()`

**server/grants.lua:** `AuthorityGrants.ValidateIssue(request)`, `AuthorityGrants.Issue(request, resource)`, `AuthorityGrants.List(request, resource)`

**server/migrations.lua:** `AuthorityMigrations.Run()`

**server/policy_provider.lua:** `AuthorityPolicy.Evaluate(action, context)`, `AuthorityPolicy.Install()`, `AuthorityPolicy.IsInstalled()`

**server/roles.lua:** `AuthorityRoles.ValidateCreate(request)`, `AuthorityRoles.Get(request, resource)`, `AuthorityRoles.Find(request, resource)`, `AuthorityRoles.Create(request, resource)`
