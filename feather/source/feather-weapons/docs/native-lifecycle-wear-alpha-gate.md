# Final-release wear: equipment and orderly stop

Final recovery confirmed after helper cleanup deployment: native host ACTIVE, one owned copy, original Cattleman112 revision1 restored with all five wear fields zero; character ammo ledger revision25 and all carried pools zero. This closes the orderly-stop final-wear live gate and supersedes the earlier pending original112 restoration note. No additional live proof repetition required.

2026-10-12 live orderly-stop final-wear gate accepted: fixture128 revision2 native dirt≈0.3 was sampled by WeaponNativePrepareStop without an explicit maintenance checkpoint. Cleanup closed with zero owned copies; Inventory audit confirmed revision3, changed=true, equipment/ammo unchanged and materialConsumed=0. Restart readback restored revision3 dirt≈0.3 with other wear unchanged. Temporary dirt helper and its dedicated test removed after acceptance. Original112 restoration commands were supplied but their results have not yet been reported. Changed-wear equipment mutation, logout/death/periodic/crash persistence are not established by this gate.

Implemented and automatically tested; live acceptance pending. This stage covers
normal equipment mutations and `WeaponNativePrepareStop`, not logout, death,
crashes or periodic autosave. Default `NativeAlphaLifecycleWearEnabled=false`.

Client samples the complete exact-owned wear/revision list inside the serialized
release reservation BEFORE final seal/copy removal. Server binds that sample to
the reserved old epoch and immutable equipment metadata snapshot. Canonical
monotonic changes are finalized only after authoritative release. Inventory
locks/checks the full equipment snapshot, saves all changed wear in one transaction,
rebases expected revisions locally, then applies the requested equipment change.
Equipment failure rolls back preceding wear writes. Orderly stop retains assignments
and commits only wear before parking. No ammo/material economic writes.

Missing/duplicate/foreign/stale samples, changed authority and broken-weapon policy
gaps fail closed. Nonzero permanent wear on identical-model GUID pairs remains
unsupported. Dry runs, repair and explicit wear-checkpoint intents do not implicitly
enter this final-wear feature. An unchanged final report performs no metadata writes.

## Prepared runtime delta

**feather-weapons**:

- `config.lua` — merge `NativeAlphaLifecycleWearEnabled=true` for the batch; preserve
  existing scoped flags, keep repair disabled. Do not replace server overrides.
- `fxmanifest.lua`
- `shared/character_lifecycle_wear.lua` (new)
- `client/character_ammunition_native_owner.lua`
- `client/character_ammunition_client_runtime.lua`
- `client/character_ammunition_routes.lua`
- `client/character_maintenance_native.lua` — temporary fixed dirt0.3 input
- `client/character_ammunition_creation_native.lua` — temporary helper binding
- `client/character_ammunition_startup.lua` — temporary helper command
- `server/services/native_equipment_transition.lua`

**feather-inventory**:

- `server/services/native_lifecycle_wear.lua` (new)
- `server/services/native_equipment_commit.lua`

No UI, tests or framework docs need deployment. New shared script/manifest and
Inventory service-glob file require server-console `refresh` before restart.
Bounded input is now approved: exactly native dirt0.3 on existing fixture128rev2.
Helper is implemented and automatically tested, replicated convar default-off.
It verifies fixed test serial, exact owned entity, current Jane/zero carried belt,
and unchanged other wear. No live helper or boundary commit occurred yet.

## New live gate, not a repeated proof matrix

Fixture128 remains owned/unequipped at revision2, dirt0.2; original112 is primary.
Existing wear baseline recorded revision1 and accepted its transition to2.
Retain that completed baseline (rename/keep it, do not silently overwrite it)
before capturing a fresh one-operation baseline for the next gate. Alpha DB rebuilds
invalidate old baselines; there is no production fixture migration requirement.

A meaningful automatic-wear test requires a new native-only dirt increase on
fixture128, proposed0.3 at revision2 with its fixed test serial. User authorization
for that new value was granted; previous temporary helper was approved only for0.2
and was removed. No new ammo/oil/firearm grant or original112 metadata mutation
is needed. Do not issue another explicit maintenance checkpoint: the NEW equipment
or orderly-stop boundary must save the final sample itself.

Preferred first gate: equip existing128, capture fresh wear baseline, apply the
approved native-only dirt input, `WeaponNativePrepareStop`, verify wear with
assignment unchanged, then stop/start Weapons and confirm revision3/dirt≈0.3.
Equipment mutation atomicity is automatically tested; live equipment-final-wear
gate can be batched subsequently, with no full family/proof repetition. Logout/
death automatic wear persistence remains implementation-pending and is not covered
by this gate.

## Initial deployment/stage

Merge only the new lifecycle flag into server config; keep existing scoped flags
and repair disabled. Copy the exact runtime list above from each repo. No tests,
UI or framework docs need moving. Preserve audit files. Server:

```text
refresh
ensure feather-inventory
ensure feather-shops
ensure feather-weapons
WeaponNativeEquipmentChange 2 unequip weapon
```

Wait for PASS, then `WeaponNativeEquipmentChange 2 equip weapon 128`. Use the
current server ID if not2. Client `weaponNativeMaintenanceStatus` should show
128revision2/dirt≈0.2. Return this output before enabling the helper. We will retain
the completed old wear audit by renaming it, then capture a new revision2 baseline.
Do not run explicit maintenance checkpoint or repair in this final-wear gate.

Authorized helper (later, after fresh baseline PASS): server
`setr feather_native_fixture_dirt 1`, client `weaponNativeFixtureDirt`, wait for
PASS dirt≈0.3 then server `setr feather_native_fixture_dirt 0`. It has no SQL/ammo
writes and refuses fixture revisions other than2. Remove helper after the gate.
