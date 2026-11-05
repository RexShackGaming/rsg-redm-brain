# Native movement provenance integration gate

LIVE accepted 2026-10-15:135 current=true/events0 before movement, then deposit
event6 inventory2/Jane→4 at21:11:19 and pickup event7 inventory4→2/Jane at21:12:26.
Both records persisted/readable with stable serial
FW-ALPHA-MIXED-JANE-V1-repeater_carbine; current=true/destroyed=false/events2.
No grant/equip/payment or repeated storage matrix. Closes native reader/ledger
integration gate; not exactly-once/outbox/failure-delivery acceptance. No new
server files or repeat movement required. Historical pending instructions below
are retained as the gate procedure, superseded by this observed result.

Implemented 2026-10-15; live pending. Reuses existing Inventory movement contract
and provenance tables. No new issuance/grant/equipment/payment route, no backfill
of earlier unobserved moves. Legacy provider/usable items/restoration stay disabled.

## Deployment

Weapons ONLY, existing files:

- server/adapters/character_ammunition_inventory.lua
- server/services/ownership.lua
- server/services/provenance.lua
- server/main.lua

PrepareStop CURRENT_ID, wait PASS, stop Weapons, copy, ensure Weapons. No refresh,
Inventory/UI/config/flag changes. Native startup initializes read-only Inventory
definition/instance/character-inventory reader and existing provenance schema
before native guards; failures prevent normal startup. Existing provenance Start
also checks its issuance-request table; this does not issue any item.

First read-only server console command:

```text
WeaponProvenanceInspect 135 5
```

Expect current=true and existing events (possibly zero). Do not invent historical
records or repeat a move to obtain them. Preserve primary112. Subsequent focused
live gate, only after preflight reviewed: move existing unequipped135 to an existing
storage and back, then inspect135 for deposit/pickup records with same serial,
correct inventories and increasing event IDs. No attachments/material grants or
equipping135 required. Test provenance logging, not the accepted storage matrix.

## Evidence and limitations

124 Weapons Lua specs and7 Node tests pass. New tests cover CFX callable-table
reader contracts, duplicate/missing definitions, no mutation methods, native-only
startup/failure gates, real observer+ledger with mocked storage, movement classes,
native lease diagnostics, independent committed/observed revisions and failed
insert. Full Inventory suite also passes. Not live MariaDB/native acceptance.

Movement event revision is the committed fact; observedRevision/inventory can be
later, and observationMatchesCommittedRevision explicitly distinguishes it. A
deleted/unreadable item cannot be reconstructed from the current event payload:
report failure, do not invent its serial/snapshot. Ledger failure cannot roll back
an already committed Inventory move. Existing critical diagnostics remain, no
automatic replay/retry and no new exactly-once/outbox guarantee. Atomic Inventory
move+provenance and restart-safe observer delivery remain separate hardening work.
