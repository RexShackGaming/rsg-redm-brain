# Weapons 0.26.0

Release preparation; not yet published. Pair with Inventory0.18.0. Shops0.5.0
remains compatible and unchanged. User handles commits, pushes, cross-linked
Weapons/Inventory PRs, merges, tags and publication after review and green CI.
Publish Inventory first, then Weapons; deploy the paired runtime changes together.

- Add Regular throwing knives as a funded character quantity with capacity8,
  bounded own/shared recovery and exact loading/unloading.
- Add Poison knives as an independent eight-unit pool sharing the knife carrier.
  A paid Poison throw funds a once-only Regular recovery, matching native behavior.
- Add Small Game arrows (40), Poison/Fire/Dynamite arrows (8 each). Preserve
  separate pool quantities through transfers, consumption and lifecycle changes.
- Restore and clean up both knife pools through one owned native GUID; expose
  typed status diagnostics and admit existing priced offers without renaming items.
- Retain all existing Bow/Regular-arrow and Tomahawk behavior, schema and receipts.

Enable before Inventory/Weapons/Shops startup, preferably in the existing
`throwable-quantities.cfg` executed by server.cfg:

```cfg
setr feather_throwable_quantities 1
setr feather_regular_arrows 1
setr feather_throwing_knife_quantities 1
setr feather_special_arrows 1
setr feather_poison_knives 1
```

New opt-ins default off. Keep them enabled while their saved pools exist;
disabling an option is not a migration. Existing item names, operator prices and
configuration remain unchanged. No schema migration, grant, refund or historical
serialized-item conversion is included.

Local verification:315 Weapons Lua suites/syntax, seven JS checks, full paired
Inventory Lua tests, 44 Shops composition scenarios and guarded PS5 installer
fixtures. Live results cover Regular-knife load/unload/capacity/batched/shared
recovery and lifecycle; Poison-knife own conversion; specialty typed loading,
exact Poison-arrow unload/reload, all four isolated shot reductions, reselection,
loaded death/admin-revive and orderly restart. Shops smoke9/9 passed.
Latest Jane ledger117: Regular arrows40, each specialty1, Regular knives7,
Poison knives1, Tomahawks3 and revolver100. Bow/Poison knife draw confirmed.

Specialty-arrow recovery remains uncredited until native return types are
confirmed. Improved arrows/knives remain excluded. Multiple simultaneous native
type increases fail closed. Native pickup events do not prove exact ownership;
bounded generic allowances remain subject to the accepted nearby-claim tradeoff.
Live contention, specialty capacity boundaries and cross-player Poison conversion
are not claimed. The isolated earlier client crash remains unattributed.

Implementation commits are pushed and verified on GitHub: Weapons
4c95245506bfbe4d4580f537b88eb391c7ed27f5 and Inventory
f589667aa92fb3d545444ed9897f18a678f0dbba. Local workflow follow-ups pin these
exact paired implementations; user commit/push and fresh green CI remain required
before merging/publishing. Do not represent old-pin CI as paired validation.
