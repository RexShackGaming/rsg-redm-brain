# Feather Property

Current version: **0.3.0** adds canonical Property link context for trusted readers and Doors binding integration.

`GetPropertyLinkContext({linkType, externalId})` is a trusted-reader server API
returning `{ok=true,value={linkId,propertyId,epoch,status}}` from one canonical
SQL read. Epoch is Property's delegation epoch; expired owner state returns
unavailable until cleanup. Link UUID identifies link incarnation, including
unlink/relink to the same property. Missing links return link_not_found. Doors
receives read-only trust; no Property manager permission. In DevMode, only the
isolated feather-doors-property-tests caller gets fixture reader/manager trust.
Its service principal is narrowly configured in Admin, never a player role.

0.2.1 adds optional Access entry delegation, owner epochs and explicit post-transfer grant adoption.

## Access-backed entry delegation (alpha)

For explicit post-transfer adoption, call `PrepareDelegationPreservation` with
propertyId, actorSource, requestId, reasonCode and up to25 grantId/expectedRevision
entries. Include manifestId as `preservationManifestId` in `TransferOwnership`.
Existing grants invalidate immediately. The authenticated new character owner
may then `AdoptDelegationPreservation` with actorSource, requestId, reasonCode,
manifestId, transferResource, transferRequestId and selected grants. Only the
actual committed transfer/new owner/consecutive epochs match; adding a co-owner
later is not transfer acceptance. Original grant IDs and expiry stay, revisions
advance. `FindDelegationOperation({requestId=...})` recovers Access broker receipts
for trusted readers. No uninterrupted preservation or door operation is promised.

`Config.Delegation.enabled=true` registers `property.property` with exact capability
`property.enter` in optional feather-access. `PropertyAccessStatus` reports provider
registration; missing Access denies delegation without preventing Property startup.
Provider re-registers after Access restart. Install matching Access/Admin policy.

Trusted managers call `GrantEntryCapability` with propertyId, actorSource,
requestId, reasonCode, granteeType/granteeId, validFrom/validUntil and optional
organization roleIds. Any current character owner may issue/revoke; a tenant,
system actor or organization owner alone cannot delegate. Organization-owned
management needs a separate authority contract. RevokeEntryGrant accepts
actorSource, grantId, expectedRevision, requestId and reasonCode. Revocation by
current owners remains possible while suspended. Recipients gain no onward rights.

Trusted readers call `CheckDelegatedEntry({propertyId=uuid, actorSource=source})`;
check both ok and value.allowed. It evaluates grants only, separate from owner/
tenant entitlement. It does not open doors or reserve a gameplay mutation.

`delegationEpoch` advances on owner grant/end/transfer, owner expiry cleanup and
retirement, invalidating all older grants by default. Tenant/label/metadata/status
changes do not otherwise advance it. Suspended/retired properties deny entry.
Expired owner interests deny delegation before the sweep commits their epoch
change; returning owners cannot revive old grants. Preservation is not implemented.
New migration005 adds the column without rewriting existing migrations.

The authoritative registry of persistent real property for the Feather
Framework: houses, hotel rooms, business premises, and the legal interests in
them (owners and tenants). Property owns each property's identity, stable key,
type, status, interests and their validity periods, and versioned metadata, and
keeps an audit trail of every change.

Property does not own gameplay. Interiors, doors, furniture, prices, purchase
menus, mortgages, taxes and hotel check-in stay in the gameplay resources, which
ask Property who owns or rents what and record those changes through it. Money
moves only in feather-economy; storage lives in feather-inventory.

## Status

Version 1.0.0: Feather Contract 1 is frozen. The full public contract (exports,
fields, errors, events, configuration, and what may and may not change) is in
[CONTRACT.md](CONTRACT.md); within Contract 1 the API only grows, nothing
documented changes or goes away.

The release, lifecycle and links acceptance tests pass. A housing integration
(purchases, rentals, sales between players and back to an agent, hotel rooms,
suspension for unpaid tax) is built on it.

## Requirements

```text
feather-mysql
feather-core
```

At runtime, character holders resolve through the `character-profile` provider
(feather-character), and organization holders through feather-organizations
when that holder type is used. Service policy is decided by Core's default
policy provider (feather-admin).

## Installation

1. Place the resource in `resources/[feather]/feather-property`.
2. Start it after Core, Character and Organizations, and before feather-admin
   and the resources that use it:

   ```cfg
   ensure feather-mysql
   ensure feather-core
   ensure feather-character
   ensure feather-organizations
   ensure feather-property
   ensure feather-admin
   ```

3. Trust each resource that uses Property (see
   [Configuration and access](#configuration-and-access)) and restart
   feather-property and feather-admin.

The first start applies three checksummed migrations and logs
`event=startup.ready migrationsApplied=3 routes=1`. Later starts apply none.

## Verification

Read-only, safe on a live server:

```text
PropertyReleaseContractSmokeTest
```

Expect 10/10 with `Config.DevMode = false`.

The lifecycle test changes data, so it runs only with `Config.DevMode = true` on
a development server. Nobody needs to be online: pass two different characters
as character UUIDs (or server IDs of connected players).

```text
PropertyLifecycleSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid>
```

Expect 33/33. The links test takes the same two characters (offline is fine):

```text
PropertyLinkSmokeTest <serverId|characterUuid> <otherServerId|otherCharacterUuid>
```

Expect 17/17. It links a storage container to a test house, checks replay, a
thing linked elsewhere, stale revision and find; gives the house to the first
character (who can then open the storage, the second cannot) and transfers it to
the second (the other way round); then removes the link and checks that retiring
a house frees its links. The lifecycle test registers a uniquely keyed test house, grants co-owners and a
tenancy that expires after three seconds, races two transfers, then suspends and
retires the house. The test runs as feather-property, so while it runs it needs
both Property policy actions granted to `feather-property`
(`Config.servicePolicy['feather-property']['feather-property']`). Remove that
grant, set DevMode back to `false` and restart afterwards.

## Model

- **Property:** `propertyId` (UUID), `propertyKey` (stable, namespaced by the
  registering resource, for example `my-housing:house0`), `propertyType`,
  `label`, `status`, the managing resource, owner and tenant caps, and versioned
  metadata.
- **Property types** (`Config.PropertyTypes`): `house` (up to 4 owners, 1
  tenant), `hotel_room` (tenants only, up to 256), `business` (organizations). A
  property may lower the caps when it is registered.
- **Status:** `active`; `suspended` (keeps its interests, gains none and cannot
  change owner, for example for unpaid tax or a seizure under review);
  `retired` (terminal, ends every interest in the same commit).
- **Interests:** `owner` and `tenant`, held by a `character` or
  `organization`. One holder has at most one active interest of each type per
  property, and owners and tenants stay within the caps. A tenancy may have a
  `validUntil`: it stops counting at that moment, and the expiry sweep ends it
  and records `property.tenancy_expired`.

## Server exports

All exports return `{ ok = true, value = ... }` or
`{ ok = false, code, message, details }`. The caller is the Cfx invoking
resource and must be in the matching `Config.Access` group. A client can never
supply a resource, account or character identity.

Every mutation takes a stable `requestId` (at most 128 characters) and a
namespaced `reasonCode` such as `housing.purchase`. Optional fields:

- `actorSource`: the player who triggered the change. Property derives that
  player's account and character from Core.
- `correlationId`.
- `referenceType` + `referenceId`: the caller's record behind the change.

Retrying a request ID with the same payload replays the stored result with
`replayed = true`; reusing it with a different payload returns
`idempotency_conflict`. Changes to an existing property take its
`expectedRevision`.

### Mutations

Trusted managers only; each property can be changed only by its managing
resource or a privileged manager.

| Export | Fields |
|---|---|
| `RegisterProperty` | `propertyKey`, `propertyType`, `label`, optional `maxOwners`, `maxTenants`, `metadataVersion`, `metadata`. The caller becomes the manager; the property starts with no interests. |
| `ChangePropertyStatus` | `propertyId`, `expectedRevision`, `status` |
| `UpdatePropertyMetadata` | `propertyId`, `expectedRevision`, and `label` and/or `metadataVersion` + `metadata` (`false` clears) |
| `GrantInterest` | `propertyId`, `expectedRevision`, `holderType`, `holderId`, `interestType`, optional `validUntil` (Unix ms) |
| `EndInterest` | `propertyId`, `expectedRevision`, `interestId` |
| `TransferOwnership` | `propertyId`, `expectedRevision`, `toHolderType`, `toHolderId`, optional `fromHolderType` + `fromHolderId` (must be a current owner). Ends every owner interest and grants one; tenancies are kept. |
| `AddPropertyLink` | `propertyId`, `expectedRevision`, `linkType`, `externalId`. Attaches an external thing (see Links). |
| `RemovePropertyLink` | `propertyId`, `expectedRevision`, `linkId` |

### Reads

Trusted readers.

| Export | Returns |
|---|---|
| `GetProperty({ propertyId })`, `FindPropertyByKey({ propertyKey })` | The property with its current `owners` and `tenants` |
| `ListPropertiesByHolder({ holderType, holderId, interestType?, propertyType?, includeMetadata?, limit?, cursor? })` | Properties in which the holder has an effective interest |
| `CheckInterest({ propertyId \| propertyKey, holderType, holderId, interestType? })` | `{ matched, interests, propertyStatus }`. Facts only; the caller decides what they permit. |
| `FindPropertyByLink({ linkType, externalId })` | The property an external thing is linked to |
| `FindOperation({ requestId })` | The caller's stored result, for recovery after a timeout |
| `InspectPropertyHistory({ propertyId, limit?, cursor? })` | Audit trail (trusted auditors; managers read their own properties, privileged auditors any) |

Lifecycle: `GetCapabilities()`, `GetHealth()`, `AwaitReady(timeoutMs)`.

### Failure codes

`authorization_denied`, `policy_unavailable`, `revision_conflict`
(`details.revision`), `idempotency_conflict`, `property_exists`,
`property_not_found`, `property_retired`, `property_unavailable`,
`interest_exists`, `interest_limit`, `interest_not_found`, `link_exists`, `link_in_use`, `link_not_found`,
`link_limit`, `holder_mismatch`,
`holder_not_found`, `no_change`, and `transaction_failed` (retry with the same
request ID, or call `FindOperation` first).

## Links

A link attaches an external thing to a property: a storage container, a door, or
another configured type (`Config.LinkTypes`, default `storage` and `door`). The
resource that owns the thing chooses its `externalId` (an inventory container
ID, a door ID); Property only records which property it belongs to.

- One external thing belongs to at most one property: linking it elsewhere
  returns `link_in_use` with `details.propertyId`; linking it twice to the same
  property returns `link_exists`.
- Adding or removing a link changes the property revision and publishes
  `property.link.added.v1` or `property.link.removed.v1`.
- Snapshots list a property's `links` (`linkId`, `linkType`, `externalId`).
- Retiring a property removes its links in the same commit, so the things are
  free for another property.
- At most `Config.Limits.maxLinksPerProperty` links per property
  (`link_limit`).

A door or storage resource asks `FindPropertyByLink` whose a thing is, then
`CheckInterest` for the player.

## Example

```lua
local Property = exports['feather-property']

-- Register a configured house once (replays on restart).
local house = Property:RegisterProperty({
    requestId = 'register:house0', propertyKey = 'my-housing:house0',
    propertyType = 'house', label = 'Strawberry House', maxOwners = 3,
    reasonCode = 'housing.setup'
})

-- Purchase: after the Economy payment committed.
Property:TransferOwnership({
    requestId = ('purchase:%s'):format(orderId),
    propertyId = house.value.propertyId, expectedRevision = house.value.revision,
    toHolderType = 'character', toHolderId = buyerCharacterId,
    reasonCode = 'housing.purchase', referenceType = 'housing_order', referenceId = orderId,
    actorSource = source
})

-- A door or storage check.
local check = Property:CheckInterest({
    propertyKey = 'my-housing:house0', holderType = 'character', holderId = characterId
})
if check.ok and check.value.matched and check.value.propertyStatus == 'active' then
    -- allowed by the calling resource's own rule
end
```

## Client route

`property.held.list.v1` takes `{ propertyType? }` and returns the calling
player's properties with only their own interests. It requires an active
character and is rate limited. Clients cannot change anything.

## Events

Each change is written to `feather_property_events` and
`feather_property_outbox` in the same transaction, then published through Core:

```text
property.property.registered.v1
property.status.changed.v1
property.metadata.revised.v1
property.interest.granted.v1
property.interest.ended.v1
property.ownership.transferred.v1
property.link.added.v1
property.link.removed.v1
```

Payloads are at most 4096 bytes and never carry metadata.

## Configuration and access

`Config.Access` groups: `trustedReaders`, `trustedManagers` (with
`privilegedManagers`), `trustedAuditors` (with `privilegedAuditors`). A
privileged entry must also be in its trusted group.

To let a resource (here `my-housing`) manage properties, add it to the reader,
manager and auditor groups in `config.lua`:

```lua
trustedReaders  = { ['my-housing'] = true, ... },
trustedManagers = { ['my-housing'] = true, ... },
trustedAuditors = { ['my-housing'] = true, ... },
```

Trust alone does not allow changes. Grant the policy actions in
feather-admin's `configs/service_policy.lua`:

```lua
Config.servicePolicy['feather-property'] = {
    ['my-housing'] = {
        ['property.property.manage'] = true, -- register, status, metadata
        ['property.interest.manage'] = true  -- owners, tenants, transfers
    }
}
```

Restart feather-property and feather-admin after changing them. A resource that
only reads needs reader trust and no policy grants.

## Database

Only Property writes `feather_properties`, `feather_property_interests`,
`feather_property_receipts`, `feather_property_events`,
`feather_property_outbox` and `feather_property_schema_migrations`. Other
resources must use the exports and never query these tables. Applied migrations
are checksummed and must not be edited.

## Not in this release

- Mortgages, liens and seizure.
- Delegated access (guests, keys), planned for `feather-access`.
