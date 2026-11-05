# Feather Property: implementation plan

**Status:** P0 (use-case inventory) done 2026-10-11; P1–P2 done 2026-10-11 (release check 10/10, lifecycle test 33/33); P3 (bcc-housing) in progress: Property integration code complete; offline flow test 15/15 on 2026-10-13 (rent, unrent, buy, sale to player and agent, hotel room), tax suspension and reactivation 10/10.
**Master plan:** [Feather Property Master Plan](https://github.com/FeatherFramework/feather-framework-docs/blob/main/feather-property/Feather_Property_Master_Plan.md) (architecture proposal, "accept for detailed discovery").
**First consumer:** bcc-housing (named by the master plan: "Use BCC Housing as the first consumer").
**Pattern:** same Contract 1 service kernel as `feather-assets` and `feather-jobs`.

## 1. Scope from the master plan

Property owns persistent real-property identity, lifecycle, ownership, tenancy and
occupancy interests: property records, stable keys, type, status, legal interests,
tenancy periods and bounded metadata.

It does **not** own interiors, door rendering, furniture placement, purchase UI,
mortgage products, taxes or hotel check-in presentation.

Initial contract: `RegisterProperty`, `GetProperty`, `FindPropertyByKey`,
`ListPropertiesByHolder`, `GrantInterest`, `TransferOwnership`, `EndInterest`,
`ChangePropertyStatus`, `CheckInterest`. Initial interest types: `owner`, `tenant`.

## 2. P0: use-case inventory

| Use case | Consumer | Property facts needed | v1 |
|---|---|---|---|
| Configured houses for sale or rent | bcc-housing (`configs/houses.lua`, `uniqueName`) | property per house key; owner or tenant interest; status | yes |
| Admin-created houses for a player | bcc-housing (`/HousingManager` create-house menu) | property registered at creation; owner interest | yes |
| Co-owners (up to `playerMax`) | bcc-housing | several `owner` interests on one property | yes |
| Rentals (deposit, monthly rent) | bcc-housing (`ownershipStatus = 'rented'`) | `tenant` interest with `valid_from`; ended on unrent or eviction | yes |
| Hotel rooms | bcc-housing (`configs/hotels.lua`) | property per hotel room type; `tenant` interest per character | yes |
| Business premises | bcc-society (blip/storage location today) | `owner` interest held by an organization | later (P4) |
| Ranches, camps | future gameplay | same registry, different `property_type` | later |
| Government seizure | future civic/justice | status change under explicit policy | later |

Holder types for v1: `character` (UUID through the character-profile provider) and
`organization` (validated through feather-organizations), as in feather-assets.

## 3. bcc-housing: where each fact goes

bcc-housing today is a VORP script that keeps ownership, money and access in its own
tables (`bcchousing`, `bcchousinghotels`, `bcchousing_transactions`,
`bcchousing_ownedfurniture`). For the Feather port each fact moves to its
authoritative domain:

| Today (bcc-housing) | Moves to | How |
|---|---|---|
| `bcchousing.charidentifier` (owner), `ownershipStatus` | **feather-property** | `owner` or `tenant` interest on the house's property |
| `allowed_ids` roommates (`playerMax`) | bcc-housing (until **feather-access**) | corrected 2026-10-11: roommates get door and house access but cannot sell or manage, so they are delegated access, not ownership; houses have one holder (owner or tenant) |
| `uniqueName`, `houseid` | **feather-property** | `property_key` = `bcc-housing:<uniqueName>` (or `bcc-housing:custom:<id>`) and `property_id` UUID; bcc-housing keeps a link row |
| Coordinates, radius, PolyZone, interior teleport, blips, menus | bcc-housing | gameplay presentation, not property facts |
| `ledger` (prepaid tax/rent float in the house row) | removed; **feather-economy** | taxes and rent are charged from the holder's wallet when due (`Transfer` wallet → system sink, reasons `housing.tax`, `housing.rent`); no money stays in bcc-housing |
| `tax_amount`, due dates, `taxes_collected` (`overdue`, `released`) | bcc-housing | the tax rule is gameplay (the master plan excludes taxes from Property); overdue becomes a property status change |
| Purchase price paid | **feather-economy** | `Transfer` buyer wallet → system sink (`housing.purchase`) |
| Sale to the NPC agent, sale money queue (`bcchousing_transactions`) | **feather-economy** | payout issued at sale time to the seller's wallet (`Issue`, `housing.sale`, policy grant); the queue table is dropped |
| Sale to another player | **feather-economy** + **feather-property** | `Transfer` buyer → seller wallet, then `TransferOwnership` |
| Rol tokens (`currencyType = 2`) | dropped | Economy has dollars and gold only; tokens are deferred by the Economy master plan |
| House storage (`invlimit`, upgrade stages) | **feather-inventory** | one container per property (as bcc-society), upgrades paid through Economy |
| Hotel room storage | **feather-inventory** | one container per tenancy |
| Property deed item | **feather-inventory** item | display copy with `property_id` in metadata; ownership truth is Property |
| Doors (`doors`, direct `doorlocks` table writes) | **bcc-doorlocks** server API | `getDoorLocksAPI()`: `AddDoor`, `UpdateAllowedIds` with owner/tenant/guest character UUIDs; no direct table access |
| Furniture catalog and placed furniture | bcc-housing | gameplay presentation; purchases and sell-back through Economy |
| Owned furniture list (`bcchousing_ownedfurniture`) | bcc-housing for v1; review for **feather-inventory** | furniture bought but not placed is item-like; decide with the Inventory owners |
| Instances (`SetInstance` from the client) | **feather-routing** | server-chosen routing bucket per property; the client no longer picks a bucket |
| Admin (`character.group`, `ALlowedJobs`) | **feather-authority** + **feather-jobs** | capability `staff.housing.manage` and Feather Admin staff capability; agent jobs through `CheckAssignment` |
| VORP character IDs, `bcc-utils`, `feather-menu` v1, `vorp_inventory` | Feather Core sessions, Core RPC, Toolkit, feather-menu-v2, feather-inventory | same adapters as the other ports |

## 4. Smallest useful v1 (P1–P2)

```text
feather_properties
  property_id (UUID), property_key (unique), property_type, label, status,
  owner_resource, definition_version, metadata_json, revision, timestamps

feather_property_interests
  interest_id (UUID), property_id, holder_type, holder_id, interest_type,
  status, valid_from, valid_until, provenance_type, provenance_id, revision

feather_property_links
  link_id, property_id, link_type, external_id, revision
```

Plus receipts (idempotency), events and outbox, migrations ledger: the same kernel
tables as feather-assets.

- Property types: `house`, `hotel_room`, `business`, `ranch`, `camp` (registry; only
  `house` and `hotel_room` used in v1).
- Status: `active`, `suspended`, `retired` (occupancy is derived from interests, not stored).
- Interest types: `owner`, `tenant`. Status: `active`, `ended`.
- Invariants: an `owner` and a `tenant` interest cannot both be active for different
  parties on a single-occupancy property; `TransferOwnership` ends the old owner
  interests and grants the new one in one transaction with an expected revision;
  `valid_until` in the past means the interest is not effective.
- Exports: the nine from the master plan, each with `requestId` idempotency,
  `reasonCode`, optional `actorSource`, Contract 1 results.
- Events: `property.registered.v1`, `property.status_changed.v1`,
  `property.interest_granted.v1`, `property.interest_ended.v1`,
  `property.ownership_transferred.v1`.
- Access: `trustedReaders`, `trustedManagers` (+ `privilegedManagers`),
  `trustedAuditors` (+ `privilegedAuditors`), as in feather-assets, plus Core service
  policy actions `property.property.manage`, `property.interest.manage`.
- Also implemented: `UpdatePropertyMetadata` (label, metadata), `FindOperation`,
  `InspectPropertyHistory`, the client route `property.held.list.v1`, and an expiry
  sweep that ends tenancies past `valid_until`.
- Release check: `PropertyReleaseContractSmokeTest`; lifecycle test in DevMode.

## 5. Delivery

| Phase | Deliverable | Gate |
|---|---|---|
| P0 | This inventory | done |
| P1 | Registry: register, get, find by key, status | done: release check 10/10 |
| P2 | Interests: grant, end, transfer, check, list by holder | done: lifecycle 33/33 (transfer race, caps, expiry, retire) |
| P3 | bcc-housing Feather port on Property, Economy, Inventory, doorlocks API, routing | live: buy, rent, co-own, sell to player and NPC, taxes, storage, deeds, hotel |
| P4 | Door and storage adapters proven; business premises from bcc-society | domain side done 2026-10-17: property links (`AddPropertyLink`, `RemovePropertyLink`, `FindPropertyByLink`, migration 004), `PropertyLinkSmokeTest` 17/17 with two offline characters (the owner opens the linked storage, then the new owner after a transfer); lifecycle 33/33 again. The housing and doorlocks adapters still have to use the links |
| P5 | Access decision with feather-assets | only if grants are materially identical |

## 6. Decisions (2026-10-11)

1. **Furniture:** owned and placed furniture stay in bcc-housing for v1. Purchases and
   sell-back go through Economy.
2. **Taxes and rent:** charged from the holder's wallet when due (`Transfer` wallet →
   system sink, `housing.tax` / `housing.rent`; allowed by Economy v1 without the
   operated-accounts extension). The house **ledger is removed**: no money is held by
   bcc-housing. Players may still pay ahead; bcc-housing then stores only a
   **"paid until" date**, never a balance. An unpaid house becomes `suspended` in
   Property (still owned, cannot be sold, doors and storage may be locked) until the
   arrears are paid; optional reclaim after a configurable number of overdue months.
   Move to feather-contracts obligations once Contracts is accepted.
3. **Sale to the NPC agent:** kept. It is a policy-gated supply operation, as the Economy
   master plan allows: bcc-housing in `trustedSuppliers` plus a service grant
   `economy.currency.issue`; the amount comes only from the server config, one
   idempotency key per sale, paid straight into the seller's wallet (works offline).
   Removing the grant leaves player-to-player sales only.
4. **Hotels:** one property per hotel (`bcc-housing:hotel:<hotelId>`, type
   `hotel_room`); each character who pays holds an open-ended `tenant` interest, as the
   script works today (one private, instanced room per character per hotel). Storage is
   one feather-inventory container per character and hotel. A timed stay later only
   needs `validUntil` on the tenancy.
