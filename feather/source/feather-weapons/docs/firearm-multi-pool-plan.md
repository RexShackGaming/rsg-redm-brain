# Firearm multi-pool implementation

Status: atomic server batch, shared restore helpers, client observer and main lifecycle routing implemented; focused Lua verification passed; first Cattleman live gate available through disabled-by-default Config.AmmunitionPools. Broad catalog opt-in remains pending.
Existing single-type firearm behavior and multi-type knives remain active.

Requested outcome: load each supported type without unloading other owned types,
select funded types through the wheel, persist consumption and selected clip,
and retain all types across restart/logout. No native pool may mint ownership.

Server groundwork generalizes opt-in validation and permits actual clip counts
in pool checkpoints rather than automatically refilling a cylinder from reserve.
Per-type loaded counts now have metadata projection/save validation, and pair
checkpoints save their selected pool. A separate, not-yet-integrated shared-pool
allocator rejects ambiguous/double attribution and never credits native pickups.
Focused ownership, observer, atomic server batch (9 checks), unfunded-pool and restart-ordering suites pass. The broader legacy suite still fails at an equipment-request fixture, so full-suite acceptance is not claimed.
The batch RPC validates all equipped leases, rejects increases/omitted pools,
and commits all item metadata in one Inventory transaction before updating runtime.
Regression cases cover a shared two-revolver loadout, partial cylinder, stale
second lease, attempted increase and rollback. Restore helpers aggregate all
funded item pools once; they are not yet called from the client restore lifecycle.
The client observer reads selected types per weapon, allocates shared decreases
once and exposes Capture/Accept so failed transactions cannot advance its baseline.
Native clips and total restoration are separate; unfamiliar or ambiguous native
transitions fail closed. Observer tests cover a shot, retry, accepted baseline,
wheel selection and unattributed decrease. Focused Lua suites now execute successfully using a local Lua 5.4 test runtime.
Main reconciliation now restores opted-in firearm pools; single/pair and long-gun
checkpoints route to the atomic observer. Legacy observers do not run alongside
multi-type firearms. Logout waits for the pool request, and restore epochs reject
stale callbacks. The observer remains inactive for current production definitions.

Required before enabling:

- Allocate shared native type totals across equipped item pools exactly once;
  do not copy the full native pool into each revolver/rifle.
- Preserve per-instance loaded state during switching and checkpoints.
- Restore all funded native pools and enable only funded variants per weapon.
- Route sidearm pair and long-gun checkpoints through the generalized contract.
- Keep existing knife pickup rejection and unfunded native pool cleanup.
- Test single firearm, distinct dual sidearms, shared long guns, unload-all,
  partial unload, empty types, rejected stale leases and restart/reconnect.

No new item seeds or SQL migrations are needed; legacy owned selected ammunition
must seed the initial pool without granting any additional variants.

See [first live gate](firearm-pools-live-gate.md). No production multi-type behavior is enabled by default.
