# Feather Licenses

The authoritative registry of issued licenses, certifications and permits for
the Feather Framework: hunting, mining or weapon licenses, professional
certifications, business permits. Licenses owns each license kind (definition),
every issued license with its holder, issuer, status, scope and expiry, and an
audit trail of every change.

Licenses does not own gameplay. Examinations, fees, issuing desks, document
items, enforcement and penalties stay in the gameplay resources. Fees are paid
through feather-economy by the consumer before it issues or renews.

## Status

Version 0.1.0. Master plan phases L0 to L2 (inventory, definitions and issuance,
status lifecycle) are implemented; see [LICENSES_PLAN.md](LICENSES_PLAN.md).
[CONTRACT.md](CONTRACT.md) is the reference to code against (a draft until the
first consumer, the bcc-documents Feather port, runs on it).

Server acceptance on 2026-10-18, nobody connected (character UUIDs):
`LicensesReleaseContractSmokeTest` 10/10; `LicensesLifecycleSmokeTest` 35/35
with an organization (expiry without the sweep, expired event, renewal,
suspension, revocation, concurrent issue, organization holder and issuer).

## Requirements

```text
feather-mysql
feather-core
```

At runtime, character holders resolve through the `character-profile` provider
(feather-character), and organization holders and issuers through
feather-organizations, which must list `feather-licenses` in its
`trustedReaders`. Service policy is decided by Core's default policy provider
(feather-admin).

## Installation

1. Place the resource in `resources/[feather]/feather-licenses`.
2. Start it after Core, Character and Organizations, and before feather-admin
   and the resources that use it:

   ```cfg
   ensure feather-mysql
   ensure feather-core
   ensure feather-character
   ensure feather-organizations
   ensure feather-licenses
   ensure feather-admin
   ```

3. Trust each resource that uses Licenses (see
   [Configuration and access](#configuration-and-access)) and restart
   feather-licenses and feather-admin.

A fresh install applies three checksummed migrations and logs
`event=startup.ready migrationsApplied=3 routes=1`. Later starts apply none.

## Verification

Read-only, safe on a live server:

```text
LicensesReleaseContractSmokeTest
```

Expect 10/10 with `Config.DevMode = false`.

The lifecycle test changes data, so it runs only with `Config.DevMode = true` on
a development server. Nobody needs to be online: pass two different characters
as character UUIDs (or server IDs of connected players).

```text
LicensesLifecycleSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid> [organizationUuid]
```

Expect 33/33, or 35/35 with an active organization UUID. It registers a
uniquely keyed test definition, issues it to both characters, lets a two-second
license expire (validity changes without the sweep, and the sweep then
publishes the expired event), renews, suspends, reinstates, revokes, issues
again and retires the definition. It then races two issues of a second
definition for one holder (exactly one must win) and, with an organization,
issues a business license held and issued by it. The organization checks need
feather-organizations to list `feather-licenses` in its `trustedReaders`. The test runs as
feather-licenses, so while it runs it needs the three Licenses policy actions
granted to `feather-licenses`. Remove that grant, set DevMode back to `false`
and restart afterwards.

## Model

- **Definition:** a license kind with a stable key (`hunting`, `weapons`), a
  label, the holder types it accepts (`character`, `organization`), an optional
  default and maximum duration, whether it can be renewed, and a scope version.
  The resource that registers it owns it.
- **License:** one issuance of a definition to a holder: `licenseId` (UUID),
  holder, issuer (`system`, the acting `character`, or an `organization`),
  status, optional `scope`, `issuedAt` and `expiresAt`.
- **Status:** `active`, `suspended` (keeps its expiry; `ReinstateLicense`
  resumes it) and `revoked` (terminal). `expired` is not a stored status: a
  license is `expired` once `expiresAt` has passed, checked against the
  database clock on every read.
- **One current license.** A holder has at most one active or suspended
  license of each kind. Revoking frees the slot; history stays.
- **Valid** means `status = active` and not expired. `CheckLicense` returns
  `matched = valid`, plus the facts behind it.

## Rules

- **Issuer authority.** Only the resource that owns the definition, or a
  privileged issuer, may issue, renew, suspend, reinstate or revoke its
  licenses, and Core policy must allow it. A `character` issuer is always the
  player in `actorSource`; no request can name another character as issuer.
- **Renewal** extends from the later of now and the current expiry, so paid
  time is never lost and an expired license becomes valid again. Suspended
  licenses cannot be renewed. Definitions can forbid renewal.
- **Durations** come from the request or the definition's default, and never
  exceed the definition's maximum. A license without a duration never expires
  (allowed only when the definition has no maximum).
- **Expiry events.** A sweep publishes `licenses.license.expired.v1` once per
  license and expiry. Validity never waits for it.
- **Offline holders.** Character UUIDs resolve through the Character provider
  whether or not the character is online.
- **Retired definitions** accept no new licenses or renewals. Existing licenses
  keep their state; snapshots report `definitionStatus`.

## Server exports

All exports return `{ ok = true, value = ... }` or
`{ ok = false, code, message, details }`. The caller is the Cfx invoking
resource and must be listed in the matching `Config.Access` group.

Every mutation takes a stable `requestId` (at most 128 characters) and a
namespaced `reasonCode` such as `documents.purchase`. Optional fields:
`actorSource` (the player who triggered it), `correlationId`, and
`referenceType` + `referenceId` (the caller's record behind the change, for
example an order). Retrying a request ID with the same payload replays the
stored result with `replayed = true`; reusing it with a different payload
returns `idempotency_conflict`. Changes to an existing license take its
`expectedRevision`.

### Definitions

Trusted registrars; policy action `licenses.definition.manage`.

| Export | Fields |
|---|---|
| `RegisterLicenseDefinition` | `licenseKey`, `label`, `holderTypes`, optional `defaultDurationSeconds`, `maxDurationSeconds`, `renewable` (default true), `scopeVersion` |
| `UpdateLicenseDefinition` | `licenseKey`, `expectedRevision`, any of `label`, `holderTypes`, `defaultDurationSeconds`, `maxDurationSeconds` (`false` removes the limit), `renewable`, `status` (`active`, `retired`), `scopeVersion` |

### Licenses

Trusted issuers.

| Export | Fields | Policy action |
|---|---|---|
| `IssueLicense` | `licenseKey`, `holderType`, `holderId`, optional `issuerType` (`system` default, `character`, `organization`), `issuerId` (organization only), `durationSeconds` (or `false` for no expiry), `scopeVersion`, `scope` | `licenses.issue` |
| `RenewLicense` | `licenseId`, `expectedRevision`, optional `durationSeconds` | `licenses.issue` |
| `SuspendLicense` | `licenseId`, `expectedRevision` | `licenses.revoke` |
| `ReinstateLicense` | `licenseId`, `expectedRevision` | `licenses.issue` |
| `RevokeLicense` | `licenseId`, `expectedRevision` | `licenses.revoke` |

### Reads

| Export | Fields | Returns |
|---|---|---|
| `GetLicenseDefinition` | `licenseKey` | Definition snapshot |
| `ListLicenseDefinitions` | optional `ownerResource`, `status`, `limit`, `cursor` | `{ items, nextCursor }` by key |
| `GetLicense` | `licenseId` | License snapshot with `scope` |
| `CheckLicense` | `holderType`, `holderId`, `licenseKey` | `{ matched, licenseKey, licenseId?, status?, expired?, expiresAt?, issuer?, scopeVersion?, scope?, revision? }` |
| `ListHolderLicenses` | `holderType`, `holderId`, optional `licenseKey`, `includeRevoked`, `includeScope`, `limit`, `cursor` | `{ items, nextCursor }`, newest first |
| `FindOperation` | `requestId` | The caller's stored result |
| `InspectLicenseHistory` | `aggregateType` (`definition`, `license`), `aggregateId`, optional `limit`, `cursor` | Audit trail (trusted auditors; owners read their own) |

`CheckLicense` returns facts only. The calling resource decides what they
permit.

### License snapshot

```lua
{
    licenseId = 'uuid',
    licenseKey = 'hunting',
    label = 'Hunting Licence',
    definitionStatus = 'active',
    holderType = 'character',
    holderId = 'character-uuid',
    status = 'active',          -- active | suspended | revoked
    expired = false,
    valid = true,               -- active and not expired
    issuer = { type = 'system' },
    issuerResource = 'my-documents',
    scopeVersion = 1,
    scope = { ... },            -- GetLicense, CheckLicense, lists with includeScope
    issuedAt = 1760000000000,   -- Unix ms
    expiresAt = 1760086400000,  -- nil = never expires
    renewedAt = nil,
    suspendedAt = nil,
    revokedAt = nil,
    revision = 1
}
```

## Example

```lua
local Licenses = exports['feather-licenses']

-- On start: register owned definitions (replays on restart).
Licenses:RegisterLicenseDefinition({
    requestId = 'definition:hunting', licenseKey = 'hunting', label = 'Hunting Licence',
    holderTypes = { 'character' }, defaultDurationSeconds = 7 * 86400,
    maxDurationSeconds = 90 * 86400, reasonCode = 'documents.setup'
})

-- Purchase, after the Economy payment committed.
local issued = Licenses:IssueLicense({
    requestId = ('purchase:%s'):format(orderId),
    licenseKey = 'hunting', holderType = 'character', holderId = characterId,
    reasonCode = 'documents.purchase', referenceType = 'documents_order', referenceId = orderId,
    actorSource = source
})

-- A weapon license given by an officer: the officer is the acting player.
Licenses:IssueLicense({
    requestId = ('weapons:%s'):format(requestUuid),
    licenseKey = 'weapons', holderType = 'character', holderId = targetCharacterId,
    issuerType = 'character', actorSource = source, reasonCode = 'documents.officer_issue'
})

-- A legendary hunt: facts only, the hunt resource decides.
local check = Licenses:CheckLicense({
    holderType = 'character', holderId = characterId, licenseKey = 'hunting'
})
if check.ok and check.value.matched then
    -- start the hunt
end
```

## Client route

`licenses.held.list.v1` takes `{ licenseKey? }` and returns the calling
player's own licenses that are not revoked (`licenseId`, `licenseKey`, `label`,
`status`, `valid`, `expired`, `issuedAt`, `expiresAt`), at most
`Config.Limits.maxClientLicenses`. It leaves out issuer and scope, requires an
active character, and is rate limited. Clients cannot change anything.

## Events

Each change is written to `feather_license_events` and `feather_license_outbox`
in the same transaction, then published through Core:

```text
licenses.definition.registered.v1
licenses.definition.updated.v1
licenses.license.issued.v1
licenses.license.renewed.v1
licenses.license.suspended.v1
licenses.license.reinstated.v1
licenses.license.revoked.v1
licenses.license.expired.v1
```

Payloads carry `eventId`, `aggregateType`, `aggregateId`, `licenseKey`,
`licenseId`, the holder, `revision`, the source resource, request, reason,
reference, actor and correlation fields, plus details (status, issuer, expiry).
They never carry scope bodies and are at most 4096 bytes. Delivery is at least
once; deduplicate by `eventId`.

## Configuration and access

| Setting | Purpose |
|---|---|
| `Config.HolderTypes` | `character` (Character provider), `organization` (feather-organizations) |
| `Config.Limits` | List page size, client route bound, longest duration, scope bounds |
| `Config.Expiry` | Sweep interval and batch size for expiry events |
| `Config.Authorization` | Policy actions `licenses.definition.manage`, `licenses.issue`, `licenses.revoke` |
| `Config.Access` | `trustedReaders`, `trustedRegistrars` (with `privilegedRegistrars`), `trustedIssuers` (with `privilegedIssuers`), `trustedAuditors` (with `privilegedAuditors`) |

To let a resource (here `my-documents`) define and issue licenses, add it to
the reader, registrar, issuer and auditor groups in `config.lua`, and grant the
policy actions in feather-admin's `configs/service_policy.lua`:

```lua
Config.servicePolicy['feather-licenses'] = {
    ['my-documents'] = {
        ['licenses.definition.manage'] = true, -- register its license kinds
        ['licenses.issue'] = true,             -- issue, renew, reinstate
        ['licenses.revoke'] = true             -- suspend, revoke
    }
}
```

A resource that only checks licenses (a hunt, a shop) needs `trustedReaders`
and no grants.

## Database

Only Licenses writes `feather_license_definitions`, `feather_licenses`,
`feather_license_receipts`, `feather_license_events`, `feather_license_outbox`
and `feather_license_schema_migrations`. Other resources must use the exports
and never query these tables. Applied migrations are checksummed and must not
be edited; a mismatch fails readiness.

## Not in this release

- The bcc-documents port (L3) and the bcc-legendaries check (L4).
- A character issuer (`issuerType = 'character'`) needs a connected player; it
  is covered by the L3 live test, not by the offline lifecycle test.
- Job and asset adapters (certifications required by jobs, transport permits).
