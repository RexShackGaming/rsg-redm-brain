# Feather Assets

## Access-backed retrieval delegation (alpha)

For transfer adoption, a trusted manager calls `PrepareDelegationPreservation`
with assetId, actorSource, requestId, reasonCode and grants (`grantId` plus
expectedRevision). Include its manifestId as `preservationManifestId` in normal
`TransferOwnership`. Ownership/epoch still changes immediately and delegation denies.
The current new character owner then calls `AdoptDelegationPreservation` with
actorSource, requestId, reasonCode, manifestId, transferResource, transferRequestId
and selected grants. The actual committed transfer receipt must match. Original
IDs/expiry stay; revoke uses the adopted grant's incremented revision.
`FindDelegationOperation({requestId=...})` lets trusted readers recover Access
broker receipts after an unknown outcome. Do not change an operation's payload
to retry. Transfer replay accepts a previously consumed manifest as historical
proof; new transfers still require its original source epoch under lock.

`Config.Delegation.enabled=true` registers target `assets.asset` with the optional
`feather-access` resource. The only capability is `asset.retrieve`. No startup
dependency on Access is added; delegated checks fail closed while it is unavailable.
`AssetsAccessStatus` reports registration. A provider re-registers after Access
restarts. Install matching Access trust/config and Admin service permissions.

Trusted Assets managers may call `GrantRetrievalCapability` with assetId,
actorSource, requestId, reasonCode, granteeType/granteeId, validFrom/validUntil
and optional organization roleIds. The online actor must be the current character
owner. Assets derives target epoch, capability and provenance. System callers and
organization ownership cannot issue grants in this increment. Use
`RevokeRetrievalGrant` with actorSource, grantId, expectedRevision, requestId and
reasonCode; current target ownership is revalidated by Access. Revocation remains
available to the owner while held/missing. Recipients gain no onward delegation.

Trusted readers call `CheckDelegatedRetrieval({assetId=uuid, actorSource=source})`.
Inspect both `ok` and `value.allowed`. This checks delegation only: owning the asset
does not itself create a delegated grant. Owner retrieval remains a separate domain
ownership check. Held, missing and retired targets deny delegated retrieval; active
status resumes an otherwise-valid grant. Transfer/retirement advance target epoch
and invalidate old grants; preservation is not implemented. No asset spawns or
Inventory items are created by these APIs. Gameplay must check immediately at its
retrieval boundary; a positive result is not a reusable commit token or reservation.

The authoritative registry of persistent, individually identifiable world
assets for the Feather Framework: horses, wagons, boats, or any other type you
configure. Assets owns each asset's identity, type, model, owner, status,
provenance, lifecycle and versioned metadata, and keeps an audit trail of every
change.

Assets does not own gameplay. Spawning, AI, stable or garage menus, feed, fuel,
condition, handling, XP, customization presentation and theft stay in the
gameplay resources. Those resources ask Assets who owns what and record
ownership changes through it.

## Status

Version 0.2.1. [Contract 1](CONTRACT.md) is proposed for freezing: the master
plan phases A0 to A5 are complete (see [ASSETS_PLAN.md](ASSETS_PLAN.md)).
`horse`, `wagon` and `boat` are enabled and share one service with no
type-specific code. bcc-stables is the first consumer.

`CONTRACT.md` is the reference to code against; this README explains the model
and setup.

## Requirements

```text
feather-mysql
feather-core
```

At runtime, character holders resolve through the `character-profile` provider
(feather-character), and organization holders through feather-organizations,
which must list `feather-assets` in its `trustedReaders`. Service policy is
decided by Core's default policy provider (feather-admin).

## Installation

1. Place the resource in `resources/[feather]/feather-assets`.
2. Start it after Core, Character, Organizations and Authority (and Jobs when
   installed), and before feather-admin and the resources that use it:

   ```text
   ensure feather-mysql
   ensure feather-core
   ensure feather-character
   ensure feather-organizations
   ensure feather-authority
   ensure feather-assets
   ensure feather-admin
   ```

3. Trust each resource that uses Assets (see
   [Configuration and access](#configuration-and-access)) and restart
   feather-admin and feather-organizations so they load their entries.

A fresh install applies five checksummed migrations and logs
`event=startup.ready migrationsApplied=5 routes=1`. Later starts apply none (an
upgrade from 0.1.0 applies one: `005_asset_delegation_epoch`).

## Verification

Read-only, safe on a live server:

```text
AssetsReleaseContractSmokeTest
```

Expect 10/10 with `Config.DevMode = false`. It includes an integrity check:
every asset that is not retired has exactly one owner, and a retired one none.

The lifecycle test changes data, so it runs only with `Config.DevMode = true` on
a development server. Nobody needs to be online: pass two different characters
as character UUIDs (or server IDs of connected players).

```text
AssetsLifecycleSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid> [assetType]
```

Expect 23/23 for each type (`horse` by default, then `wagon` and `boat`). It
registers a test asset for the first character, races two concurrent transfers
to the second (exactly one must win), revises metadata, transfers the asset
back (a new delegation epoch, not the old one), holds it and retires it. The test runs as feather-assets, so it needs the
two Assets policy actions granted to `feather-assets` while it runs. Set DevMode
back to `false`, remove that grant and restart afterwards.

If a mutation returns `authorization_denied` with `policyCode=service_forbidden`,
the calling resource has no policy grant; add it and restart feather-admin.

## Rules

| Decision | Choice |
|---|---|
| One service for every asset type | Types are configuration (`Config.AssetTypes`); the service has no type-specific code. |
| Customization | Generic versioned metadata: one bounded JSON object per asset plus a `metadataVersion` the managing resource owns. |
| Stolen possession | A gameplay fact. Theft does not change ownership; the managing resource may mark an asset `missing`. |
| Liens and insurance | Not supported. Only the `owner` interest exists. Delegated use (keys, shared mounts) is planned for `feather-access`. |

- **One owner.** A unique active slot per asset and interest type makes double
  ownership impossible at the database level.
- **No duplicate registration.** Provenance (`provenanceType` +
  `provenanceId`) is unique per managing resource. Registering the same purchase, capture or
  imported row twice returns `asset_exists` with the existing `assetId`.
- **Concurrent sales.** Transfers lock the asset row and require
  `expectedRevision`. Of two concurrent sales, one commits and the other gets
  `revision_conflict`.
- **Statuses.** `active`, `held` (impounded, collateral) and `missing` are set
  with `ChangeAssetStatus`. `retired` is terminal and only set by
  `RetireAsset`, which also ends the owner interest. Only an `active` asset can
  change owner.
- **Managing resource.** The resource that registers an asset manages it and is
  the only caller, besides privileged managers, that may change it.
- **Independent of entities.** Records never reference a runtime entity or a
  server source ID, so they survive entity deletion and restarts.
- **Offline owners.** Character UUIDs resolve through the Character provider
  whether or not the character is online.
- **Delegation epoch.** `delegationEpoch` rises by 1 with every owner change
  and on retirement, never on status or metadata changes, and is never reused.
  feather-access will bind shared use (keys, shared mounts) to it, so a sale
  ends every grant at once.

## Server exports

All exports return `{ ok = true, value = ... }` or
`{ ok = false, code, message, details }`. The caller is the Cfx invoking
resource and must be listed in the matching `Config.Access` group. A client can
never supply a resource, account or character identity.

`GetCapabilities()`, `GetHealth()` and `AwaitReady(timeoutMs)` (default 30000,
integer 0 to 60000) report the lifecycle.

Every mutation takes a stable `requestId` (at most 128 characters) and a
namespaced `reasonCode` such as `stables.purchase`. Optional fields:

- `actorSource`: the player who triggered the change. Assets derives that
  player's account and character from Core.
- `correlationId`.
- `referenceType` + `referenceId`: the caller's record behind the change (for
  example an order UUID). It is stored on the audit event and published with
  it, so one workflow can be traced across Assets and Economy.

Retrying a request ID with the same payload replays the stored result with
`replayed = true`. Reusing it with a different payload returns
`idempotency_conflict`.

### Mutations

| Export | Fields | Policy action |
|---|---|---|
| `RegisterAsset` | `assetType`, `modelKey`, `holderType`, `holderId`, `provenanceType`, `provenanceId`, optional `metadataVersion`, `metadata` | `assets.asset.manage` |
| `TransferOwnership` | `assetId`, `expectedRevision`, `toHolderType`, `toHolderId`, optional `fromHolderType` + `fromHolderId` | `assets.ownership.transfer` |
| `ChangeAssetStatus` | `assetId`, `expectedRevision`, `status` (`active`, `held`, `missing`) | `assets.asset.manage` |
| `UpdateAssetMetadata` | `assetId`, `expectedRevision`, `metadataVersion`, `metadata` (object, or `false` to clear) | `assets.asset.manage` |
| `RetireAsset` | `assetId`, `expectedRevision` | `assets.asset.manage` |

The caller of `RegisterAsset` becomes the managing resource. Every mutation
returns the full asset snapshot with its new `revision`.

### Reads

| Export | Fields | Returns |
|---|---|---|
| `GetAsset` | `assetId` | Asset snapshot with `owner` and `metadata` |
| `ListAssetsByHolder` | `holderType`, `holderId`, optional `assetType`, `status`, `includeMetadata`, `limit`, `cursor` | `{ items, nextCursor }`, newest first |
| `CheckInterest` | `assetId`, `holderType`, `holderId`, optional `interestType` (`owner`) | `{ matched, interestType, interestId?, assetType, assetStatus, delegationEpoch }` |
| `FindOperation` | `requestId` | The caller's stored result, for recovery after a timeout |
| `InspectAssetHistory` | `assetId`, optional `limit`, `cursor` | Audit trail; managers read their own assets, privileged auditors read all |

`CheckInterest` returns facts only. The calling resource decides whether they
permit an action: a `held` horse is still owned, but a stable may refuse to
release it.

### Asset snapshot

```lua
{
    assetId = 'uuid',
    assetType = 'horse',
    modelKey = 'A_C_Horse_Arabian_White',
    status = 'active',
    managerResource = 'my-stables',
    provenanceType = 'stable_purchase',
    provenanceId = 'purchase-uuid',
    metadataVersion = 1,
    metadata = { name = 'Silver', gender = 'female', components = { ... } },
    revision = 3,
    delegationEpoch = 2,
    createdAt = 1759500000000,
    updatedAt = 1759500100000,
    retiredAt = nil,
    owner = {
        interestId = 'uuid',
        holderType = 'character',
        holderId = 'character-uuid',
        revision = 1,
        validFrom = 1759500100000
    }
}
```

### Metadata limits

Metadata is an object with identifier keys whose values are strings, finite
numbers, booleans, arrays or objects. `Config.Limits` bounds it to 8192 encoded
bytes, depth 4, 256 nodes and 1024-character strings. Anything larger returns
`invalid_metadata`. Metadata is never copied into events; only
`metadataVersion` travels with them.

### Failure codes

| Code | Meaning |
|---|---|
| `authorization_denied` | Caller not trusted, not the manager, or policy denied |
| `policy_unavailable` | Policy provider missing or indeterminate (Assets fails closed) |
| `revision_conflict` | Stale `expectedRevision`; `details.revision` holds the current value |
| `idempotency_conflict` | Request ID reused with a different payload |
| `asset_exists` | Provenance already registered by this manager; `details.assetId` |
| `asset_not_found`, `asset_retired`, `asset_unavailable` | Missing, terminal, or not `active` for a transfer |
| `holder_mismatch` | `fromHolder*` is not the current owner |
| `holder_not_found`, `holder_inactive`, `holder_type_not_allowed`, `holder_provider_unavailable` | Holder validation |
| `invalid_metadata`, `invalid_input`, `no_change` | Request validation |
| `transaction_failed` | Retry with the same request ID, or call `FindOperation` first |

## Example

```lua
local Assets = exports['feather-assets']

-- Purchase: the stable has taken payment and stored a pending purchase record.
local registered = Assets:RegisterAsset({
    requestId = ('purchase:%s'):format(purchaseId),
    assetType = 'horse',
    modelKey = 'A_C_Horse_Arabian_White',
    holderType = 'character',
    holderId = characterId,
    provenanceType = 'stable_purchase',
    provenanceId = purchaseId,
    metadataVersion = 1,
    metadata = { name = 'Silver', gender = 'female' },
    reasonCode = 'stables.purchase',
    actorSource = source
})

-- Sale between players: assert the seller so a stale view is rejected.
local asset = registered.value
Assets:TransferOwnership({
    requestId = ('sale:%s'):format(saleId),
    assetId = asset.assetId,
    expectedRevision = asset.revision,
    fromHolderType = 'character',
    fromHolderId = sellerCharacterId,
    toHolderType = 'character',
    toHolderId = buyerCharacterId,
    reasonCode = 'stables.sale',
    actorSource = source
})

-- Before spawning: facts only, the stable decides.
local check = Assets:CheckInterest({
    assetId = assetId,
    holderType = 'character',
    holderId = characterId
})
```

## Client route

`assets.owned.list.v1` takes an empty payload or `{ assetType = 'horse' }` and
returns the calling player's own assets (`assetId`, `assetType`,
`modelKey`, `status`), at most `Config.Limits.maxClientAssets`. It leaves out
the manager, provenance and metadata, requires an active character, and is rate
limited. Clients cannot change anything.

## Events

Each change is written to the `feather_asset_events` audit table and the
`feather_asset_outbox` in the same transaction, then published through Core:

```text
assets.asset.registered.v1
assets.ownership.transferred.v1
assets.status.changed.v1
assets.metadata.revised.v1
assets.asset.retired.v1
```

Payloads carry `eventId`, `assetId`, `assetType`, the current holder,
`revision`, the source resource, request, reason, actor and correlation fields,
plus details for the event (previous holder, previous status, metadata
versions, the new `delegationEpoch` on transfer and retirement). They are at
most 4096 bytes. Delivery is at least once; deduplicate by `eventId`.

## Configuration and access

| Setting | Purpose |
|---|---|
| `Config.AssetTypes` | Registrable types and the holder types each accepts. |
| `Config.HolderTypes` | `character` (Character provider), `organization` (feather-organizations); `validator = false` trusts the managing resource. |
| `Config.Limits` | List page size, client route bound, metadata bounds. |
| `Config.Authorization` | Policy actions `assets.asset.manage` and `assets.ownership.transfer`. |
| `Config.Access` | `trustedReaders`, `trustedManagers` (with `privilegedManagers`), `trustedAuditors` (with `privilegedAuditors`). A privileged entry must also be in its trusted group. |

To let a resource (here `my-stables`) manage assets, add it to the reader,
manager and auditor groups in `config.lua`:

```lua
trustedReaders  = { ['my-stables'] = true, ... },
trustedManagers = { ['my-stables'] = true, ... },
trustedAuditors = { ['my-stables'] = true, ... },
```

Trust alone does not allow changes. Grant the policy actions in
feather-admin's `configs/service_policy.lua`, then restart feather-admin:

```lua
Config.servicePolicy['feather-assets'] = {
    ['my-stables'] = {
        ['assets.asset.manage'] = true,
        ['assets.ownership.transfer'] = true
    }
}
```

A resource that only reads needs reader trust and no policy grants.

### Asset types

`horse`, `wagon` and `boat` are enabled in the shipped configuration, each
ownable by characters and organizations. To add a type, add it to
`Config.AssetTypes` with the holder types that may own it. Type keys are stored
on every asset: never rename or remove one once assets of that type exist.

What a stable, wagon or boat resource keeps itself (selection, XP, condition,
fuel, storage) and what goes to Assets is listed in
[ASSETS_PLAN.md](ASSETS_PLAN.md#2-a0-consumer-inventory).

## Importing existing data

Assets ships no importer. A resource moving its own ownership table to Assets
registers each existing row once, with the owner's character UUID and the old
row as provenance (`provenanceType = 'legacy_<table>'`,
`provenanceId = <old id>`). Provenance is unique, so running the import again
returns `asset_exists` for rows already registered.

## Database

Only Assets writes `feather_asset_records`, `feather_asset_interests`,
`feather_asset_receipts`, `feather_asset_events`, `feather_asset_outbox` and
`feather_asset_schema_migrations`. Other resources must use the exports and
never query these tables. Applied migrations are checksummed and must not be
edited; a mismatch fails readiness.

## Backup and rollback

Back up the six `feather_asset_*` tables together, in one consistent dump
(`mysqldump --single-transaction`): receipts, events and outbox must match the
records, or replays and history break. Consumer tables keyed by asset UUID
(stables, wagons) belong in the same backup window.

Migrations only add tables and columns. Rolling back the resource to 0.1.0
after 0.2.0 has run is safe for data (0.1.0 ignores `delegation_epoch`; only
its release test fails "migration ledger", 5 rows for 4 migrations), but 0.1.0
does not advance the epoch, so do not run feather-access against a rolled-back
Assets.

## Not in this release

- Interests other than `owner` (liens, insurance).
- An Access target provider and grant preservation on transfer. The delegation
  epoch is in place; the rest waits for the feather-access Phase 0 contract
  (see [ASSETS_PLAN.md](ASSETS_PLAN.md#5-a5-delegation-and-the-access-integration-request-2026-10-14)).
