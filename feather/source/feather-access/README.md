# Feather Access

Doors target configuration: `doors.group` is owned by `feather-doors` with exact
`door.lock`/`door.unlock` vocabulary. Doors is a trusted target-context reader only;
this adds no grant reader/manager or Core grant-service policy. Its current target
provider denies grant management. Doors owns lifecycle/epoch facts; Access remains
the only grants authority. See framework docs `feather-doors/ACCESS_TARGET_ACCEPTANCE.md`.

## 0.1.0 alpha scope

Character/organization grantees, exact organization role selectors, real Inventory
delegation, character-owned Assets/Property grants and explicit post-transfer
adoption are in scope. DevMode=true is intentional. Organization-owned grant
management and Inventory transfer preservation are deferred and fail closed/
default to invalidation. Actual world gameplay and unverified multiplayer/crash/
restore scenarios are not release acceptance claims.

`AccessAlphaReleaseSmokeTest` is a console-only read-only gate for this scope:
readiness, four verified migrations, all three real providers, exact service
policy, healthy mutation fence and empty/available Audit queue. Expect16/16.
`AccessReleaseContractSmokeTest` remains the separate production-posture check
requiring development disabled; do not toggle DevMode merely to run it in alpha.

## Explicit transfer adoption

Assets/Property may prepare immutable manifests of up to25 exact grant IDs and
expected revisions using `PreparePreservation`. The target domain then commits
its normal ownership transfer, recording `preservationManifestId` and advancing
its epoch. Delegation denies during this handoff. The authenticated new character
owner calls `AdoptPreservation` through that domain, selecting a nonempty subset
of captured grants; receipt proof must match target, manifest and consecutive
epochs. Grant IDs, recipients, roles/capability and original expiry remain unchanged;
revisions advance. Revoked, expired, altered or late grants cannot be adopted.

`PreparePreservation` takes requestId, reasonCode, actorSource, targetType,
targetId, expectedEpoch and grants (`{grantId,expectedRevision}` entries).
`AdoptPreservation` takes requestId, reasonCode, actorSource, manifestId,
transferResource, transferRequestId and selected grants. Exact retries replay;
each manifest adopts once. `FindOperation` recovers the owning broker's receipts.
Assets/Property expose their corresponding `FindDelegationOperation` wrapper.
`ResolvePreservationManifest` is restricted to the configured owning target domain
and proves a committed snapshot exists before its transfer transaction starts.

This is post-transfer adoption, not an atomic cross-resource ownership-and-grant
commit. Further owner-set changes invalidate stale handoffs. Inventory does not
currently expose transfer adoption. System/organization-owner adoption is denied.
Migration004 adds manifests; Audit requires `access.grant.preserved` schema support.

## Inventory integration

inventory.storage uses Inventory's existing UUID and exact inventory.read/insert/
remove capabilities. Config grants feather-inventory provider, manager and reader
trust; Admin must load its exact access.grant.manage/read service policy. Inventory
continues to validate actual target ownership/admin authority. No auditor-wide
grant or manage capability is given to recipients.

WithInventoryFence(callback) and ValidateInventoryFence(token) are reserved for
actual feather-inventory. They order normal grant/revoke writes with Inventory's
prepared SQL mutations; never call provider/CheckCapability SQL from the SQL body.
CheckCapability now returns validForMs with an allowed grant, a conservative input
for transaction expiry budgets, not a standalone authorization token. Unexpected
consumer stop while held latches the fence closed until Access restart; GetHealth
and AccessStatus expose that state. This is not full-server crash atomicity.

Inventory migration selects native authority per container and preserves legacy
rows. No automatic conversion or fallback to the old persistent writer. The new
fence.lua manifest entry requires refresh before restart. Versions unchanged.

## Jobs-backed organization grants

Config.Employment.Scopes maps exact organization UUIDs to jobIds and dutyState
('any' or 'on_duty'). Jobs/Organizations must trust feather-access as a reader.
Each selected role is grade.<stable grade UUID>; numeric rank confers no implicit
permission. Active organization/job/grade and current matching employment are
required. Suspended duty never qualifies. Scopes default empty; configure before
restart. Bounds: 128 scopes, 8 jobs/scope and 32 active grades/scope. Do not also
configure a custom membership provider for the same organization.

Jobs/Organizations outages fail employment resolution closed. They remain runtime
providers, not hard startup dependencies. Checks read current facts; they do not
lock another domain's mutation transaction. EmploymentFixtureScope is restricted
to the exact development fixture caller, not a production registration API.

Server-only durable capability delegation in Feather.

Requires `feather-core` Contract 1 and `feather-mysql`. Start both first, then
`ensure feather-access`. After manifest changes, run `refresh` before restarting
the resource. Restart Access after a required dependency stops or restarts.

`config.lua` contains the required contract versions and the per-dependency
readiness timeout in milliseconds (0–60000, default 30000).

Startup verifies checksummed resource-owned migrations. An unknown migration or
checksum mismatch fails startup; restore the matching resource/schema version
rather than deleting the migration ledger. DDL is restart-safe but is not wrapped
in a transaction because MariaDB DDL commits implicitly.

`Config.DevMode` defaults to false. Enabling it trusts only the explicitly named
development provider fixture. Do not enable it in production. The fixture resources
are siblings of Access and are not loaded by Access's manifest.

`Config.Providers` configures exact provider owners and trusted context readers:

```lua
Targets = {
    ['my_storage'] = {
        resource = 'my-storage',
        capabilities = { 'storage.read', 'storage.insert', 'storage.remove' },
    },
},
Memberships = { ['organization-uuid'] = 'my-society' },
TrustedReaders = { ['feather-access'] = true, ['my-storage'] = true },
```

Replace `organization-uuid` with an actual lowercase UUID. No production providers
are enabled by default. `TimeoutMs` is 10–10000 (default 2000); `MaxInFlight` is
1–128 (default 32). A timed-out callback retains its slot until completion or owner
stop, so hung providers cannot create unlimited background work.

## Server API

- `GetCapabilities()` returns the resource version, contract, state and feature versions.
- `GetHealth()` returns a defensive lifecycle snapshot, including failure details.
- `AwaitReady(timeoutMs?)` waits for foundation readiness with a bounded timeout.
- `RegisterTargetProvider({ targetType, contract = 1, resolve })` registers the
  configured target owner. `resolve({ targetType, targetId })` returns a successful
  envelope containing `{ targetType, targetId, epoch, status, capabilities }`.
  Epoch is an integer from 1 to 9007199254740991. Status is `active`, `suspended`,
  `retired`, or `unavailable`; capabilities are a nonempty exact subset of the
  configured vocabulary.
  To manage grants, supply `authorize(request)` as well. It receives `target`,
  `actor`, `action` (`grant`, `revoke`, `list`) and optional `capability`, and must
  return `{ ok = true, value = { allowed = true } }` only for a target-authorized
  owner/manager or explicitly permitted system service. A recipient's grant alone
  must never establish management authority.
- `UnregisterTargetProvider({ targetType })` removes the caller's registration.
- `RegisterMembershipProvider({ organizationId, contract = 1, resolve })`
  registers the configured membership owner for one organization UUID.
  `resolve({ organizationId, characterId })` returns a successful envelope with
  `{ organizationId, characterId, status, roleIds }`. Status is `active` or
  `inactive`; inactive membership must have no roles.
  Organization grants also require a `catalog({ organizationId })` callback
  returning `{ ok = true, value = { organizationId, status, roleIds } }` with
  current active/inactive organization state and stable existing roles.
- `UnregisterMembershipProvider({ organizationId })` removes the caller's registration.
- `ResolveTargetContext({ targetType, targetId })` and
  `ResolveMembershipContext({ organizationId, characterId })` return validated
  defensive facts to explicitly trusted readers. These calls grant no permission.

Capability/role arrays are dense and duplicate-free, with at most 32 entries.
Names use lowercase stable keys up to 64 characters (`a-z`, digits, `_`, `.`, `-`,
starting with a letter). Role IDs additionally accept lowercase UUIDs. Empty role
arrays confer no implicit eligibility. Providers echo normalized lowercase UUIDs.
Responses include `{ provider = { key, resource, contract, generation } }`.
Generation identifies a runtime registration; it is not a durable delegation epoch.

## Durable grant API

Configure `Config.Grants.Managers`, `Readers` and `Auditors` as exact resource-name
boolean maps. They default empty. Managers may request target-authorized writes
and target lists; Readers may check and recover their own operation receipts;
Auditors may list grants by grantee. Grant services additionally require Core
policy actions `access.grant.manage` / `access.grant.read` for the actual caller.
With Admin's policy provider, add the corresponding service principal under
`Config.servicePolicy['feather-access']`. Access cannot infer player management
authority from that service permission; the target callback must still validate it.

- `GrantCapability({ requestId, reasonCode, targetType, targetId, expectedEpoch,
  granteeType, granteeId, capability, validFrom, validUntil, provenanceType,
  provenanceId, roleIds?, actorSource? })` creates one immutable exact grant.
  Validity uses UTC Unix milliseconds and lasts at most `MaxValidityMs` (default
  366 days). Explicit finite end time is required. Character UUIDs resolve through
  Core's persisted Character profile provider. Organization grants require at
  least one current catalog role. Any selected matching role may qualify.
- `RevokeGrant({ grantId, expectedRevision, requestId, reasonCode, actorSource? })`
  revokes one grant. It does not require its grantee still to be eligible. Current
  target-provider authority is required even for suspended/retired targets.
- `CheckCapability({ targetType, targetId, capability, actorSource? , characterId? })`
  requires exactly one active actor source or explicit offline character UUID
  from a trusted server reader. Inspect `result.ok` and `result.value.allowed == true`.
  Error envelopes and `allowed=false` both deny. Owning a target is a separate
  provider/domain path; this API only checks durable delegation.
- `ListTargetGrants({ targetType, targetId, limit?, cursor?, actorSource? })` and
  `ListGranteeGrants({ granteeType, granteeId, limit?, cursor?, actorSource? })`
  return historical `{ items, nextCursor? }`, with limit 1–50 (default 25) and
  grant-UUID keyset cursors. Lists are not authorization decisions.
- `FindOperation({ requestId })` returns `{ found, operation?, result? }` for the
  calling service's own request namespace. Results are original snapshots; a
  creation receipt can still say active after the underlying grant was revoked.

`actorSource` derives account/character/session identity through Core. Omitting it
requests an explicit server-service operation, which the target must authorize.
No client mutation events are registered. Reusing the same caller/request ID with
changed terms, actor identity or operation returns `idempotency_conflict`.
Successful replay returns the original grant snapshot with `replayed=true` and
never revives a revoked/expired grant. Separate overlapping grants are independent;
revoking one does not revoke the others. Revoke by grant UUID.

Checks use fresh target, organization and membership facts and DB-time validity;
expiry needs no cleanup worker. They deny old ownership epochs and unavailable
providers. More than 256 active candidate grants returns `limit_exceeded`; reconcile
overlap instead of relying on an unbounded check. Online actor identity is checked
after yielding; session lifecycle events also fence writes before commit.
`CheckTimeoutMs` bounds accumulated context work (100–30000 ms, default 5000).
Late positive results are denied; an already-running SQL/provider call still uses
its own deadline and cannot be cancelled by this budget. An independent character
grant does not depend on unrelated organization providers being online.

Caller identity comes from the invoking resource. Registration scopes cannot be
claimed by supplying a resource field. Registrations are ephemeral and are removed
when the provider stops. Providers must re-register after their own or Access's
restart. Duplicate registration requires an explicit owner-only unregister first.

All results use `{ ok = true, value = ... }` or
`{ ok = false, code = 'stable_code', message = '...', details = ... }`.
Health and capability reads are diagnostic; they do not authorize access.

`AccessStatus` and `AccessReleaseContractSmokeTest` are read-only server-console
commands. The release smoke expects development mode off and the trusted fixture
stopped. Run it after reverting test configuration before packaging.
AccessStatus also reports the active grant trust counts and test-principal flags.
Authorization errors identify `details.stage` (`access_trust` or `core_policy`),
the required trust group/action and available policy decision metadata. Staff
ownership is separate from service-principal authorization.

Access owns its schema-migration ledger, receipts, grants, audit events and pending
outbox. State, receipt, local fact and immutable Audit envelope commit together.
When the configured publisher is enabled, `eventPublication=1` means Audit delivery
support; it does not mean that Audit is currently ready or every row has delivered.
Preserve all these tables together for backup/restore. No production domain adapter or Inventory ACL cutover
is enabled. No transfer-preservation workflow, client UI or reservation for later
gameplay mutations is implemented. Checks overlapping revocation/transfer may order
either way; consumers must enforce their own mutation-boundary safeguards.

## Audit delivery

Audit is optional at runtime: grants still commit when it is stopped. Access uses
a vendored Audit Contract 1 producer kit under `lib/audit`, so event construction
and enqueueing require no Audit exports. Its publisher sends committed envelopes
to `feather-audit:Ingest`. Audit must load the Access grant schemas and explicitly
register `feather-access` for the `access.grant.` prefix/version 1.

`Config.Audit.SourceInstance` must match Audit's producer registration (default
`default`). Keep it stable: it is persisted deduplication identity. Existing queued
envelopes retain their original instance and timestamp across config changes.
Migration 003 upgrades the existing outbox; historical pending facts gain an
envelope under a row lock before first delivery, preserving event UUID/time.

`Config.Audit.Enabled=true` starts the publisher; false pauses delivery while new
mutations still enqueue. Other defaults are poll 1000 ms, batch 10, lease 30 s,
retry ceiling 2–60 s and transport timeout 3000 ms. The per-call timeout is bounded
to 100–10000 ms, batch to 1–100, and lease to 30–600 s. Retries use jitter/backoff;
an expired lease is reclaimable after restart. A hung transport retains its single
slot until return or Audit stop; late acknowledgements cannot overwrite newer work.

Accepted/duplicate responses with a valid Audit UUID mark a row delivered.
Retryable failures retain the original envelope. Quarantine stops automatic retry
and prints the event UUID and safe code. Console-only operator commands:

- `AccessAuditStatus`: publisher availability and pending/leased/delivered/quarantined counts.
- `AccessAuditInspect <event-UUID>`: one row's state, attempts, result and acknowledgement ID.
- `AccessAuditRetry <event-UUID>`: requeue a quarantined event after its external
  configuration/schema issue is fixed, preserving its validated envelope. It
  refuses corrupted payloads and never repairs them by changing event identity.

`GetHealth().value.audit` contains lightweight publisher state. Audit outage does
not change domain readiness; observe the outbox separately. Test controls require
DevMode and the exact sibling fixture caller; stopping that fixture clears any
test pause. Local DevMode is enabled for the owner's development servers. Disable
fixture trust when preparing a production configuration; ordinary development does
not require repeating that packaging check after each increment.

Design and implementation documentation lives in
[feather-framework-docs](../feather-framework-docs/feather-access/ACCESS_IMPLEMENTATION_PLAN.md).
