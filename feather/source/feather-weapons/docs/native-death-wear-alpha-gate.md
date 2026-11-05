# Death-boundary final wear

Death-wear gate final cleanup/recovery confirmed: after temporary helper removal deployment and original restoration, ACTIVE one owned Cattleman112revision1; all five native wear fields zero, ammo ledger25/all pools0, same session5bab7fbe-c6bd-11f1-9ae2-e0d55eaa2deb and fresh startup epoch. This supersedes the pending original112 restoration/cleanup deployment note. Changed-wear death persistence and doctor recovery gate is closed; no repeat testing or additional deployment required for this accepted gate.

LIVE changed-wear death/doctor gate ACCEPTED: fixture128rev4 native dirt0.5 saved during authoritative dead9 before recovery. Inventory COMMIT (12queries) and death-final-wear changes=1 log; SELECT-only verify-wear PASS revision5/changed=true/equipmentUnchanged=true/ammoUnchanged=true/materialConsumed0. Weapons correctly sealed with tracked copy retained. Medical doctor alive10 restored same session5bab7fbe-c6bd-11f1-9ae2-e0d55eaa2deb/ped4347654 under fresh epoch4: ACTIVE one copy128rev5 dirt0.5, permanent/degradation/damage≈0.1, soot0; ledger25 all carried pools0. This accepts dead-ped readback, atomic reserved wear seal and doctor reconstruction; no repeat gate needed. Temporary dirt helper removed locally after acceptance; original112 restoration, dev flag shutdown and four-client-file cleanup deployment still pending. Periodic/crash/broken/GUID-pair permanent-wear work remains separate.

Implemented and automatically tested; live acceptance pending. Existing scoped
NativeAlphaLifecycleWearEnabled gate is reused. Do not change native enrollment,
repair or ammunition flags between this test and the accepted lifecycle tests.

Client reads every exact tracked copy while the same native ped and Medical
revision are dead, using a read-only adapter with no setters/recovery authority.
Death controller attaches complete bounded wear only to its final seal request.
Server independently reads Medical's current stored condition, validates exact
old lease/revision against an Inventory-owned snapshot, and constructs canonical
monotonic changes. The ammo runtime reserves the exact wear plan even when the
belt is unchanged; sealing cannot acknowledge before that Inventory transaction.

Inventory performs final ammo observation and all wear CAS writes in one owned
transaction. Wear failure, assignment/revision change or authority loss rolls
back preceding ammo reduction. Zero carried belt leaves ledger revision unchanged.
No equipment mutation, material payment or grant. Native hold remains until normal
doctor recovery removes old copies; fresh same-session loadout restores new item
revisions. A synchronous metadata guard exception accepts only the active server
death ticket, exact item/revision and approved wear document (wear-only decimal
noise tolerance1e-12); move/destroy/unrelated metadata remain blocked.

Medical adds trusted Weapons-only ReadNativeWeaponCondition(source,context),
read-only and current-session checked before/after storage. It never initializes
or changes Medical condition. Death, not arbitrary client hints, selects this path.
Late/duplicate/stale/foreign/missing reports fail closed. Crashes, periodic saving,
GUID-pair permanent-wear restoration and broken-weapon policy remain separate gaps.

## Runtime files to deploy

feather-weapons:

```text
shared/character_lifecycle_wear.lua
shared/character_ammunition_runtime.lua
shared/character_ammunition_transport.lua
client/character_maintenance_native.lua
client/character_ammunition_creation_native.lua
client/character_ammunition_native_owner.lua
client/character_ammunition_host.lua
client/character_ammunition_controller.lua
client/character_ammunition_startup.lua
server/services/character_ammunition_runtime.lua
server/adapters/character_ammunition_inventory.lua
```

feather-inventory:

```text
server/services/character_ammunition.lua
server/services/transactions.lua
```

feather-medical:

```text
server/gameplay.lua
```

No Admin/Character/UI/manifest/config deployment; no new runtime scripts or
refresh needed. Preserve server scoped config and private audit files. All Weapons
Lua suites/7 Node checks, full Inventory runner and Medical Lua/web tests pass.

## One changed-wear gate

User authorizes continued fixture-only input without repeated approval. Temporary
default-off helper targets exact Jane/fixture128rev4/fixed serial/owned entity and
zero carried pools; independent readback changes only native dirt0.4→0.5. No SQL,
ammo, new items/oil/grants, or original112 metadata change. Remove after acceptance.

1. While original112 active, WeaponNativePrepareStop current-id, wait PASS; stop
   Weapons, replace exact runtime files above. Ensure Medical, Inventory, Shops,
   Weapons in that order (Inventory restart stops Admin/Shops dependencies).
2. Conditional unequip then equip128; wait each PASS. Native maintenance readback
   must show fixture128rev4 dirt≈0.4 before proceeding.
3. Retain completed wear audit by renaming .native-wear-audit-<Jane>.json to
   .native-wear-audit-<Jane>.completed-rev4.json. Capture fresh revision4 baseline
   via InvNativeRepairAudit current-id Jane 128 capture-wear; wait PASS.
4. setr feather_native_fixture_dirt 1; client weaponNativeFixtureDirt; expect128rev4
   dirt≈0.5 native-only PASS; then setr feather_native_fixture_dirt 0.
5. No prepare-stop/logout/equipment mutation/checkpoint after the dirt input.
   Temporarily setr feather_admin_dev_selfkill 1; use existing AdminDevKillSelf.
   Confirm authoritative dead and Weapons sealed. Expect server death-final-wear
   persisted changes=1 log. Verify-wear while dead: changed=true, revision5,
   materialConsumed0, equipment/ammo unchanged. This proves persistence before
   doctor recovery, rather than an unrelated later checkpoint.
6. After existing doctor timer, MedicalRespawn. Native maintenance should restore
   fixture128rev5 dirt≈0.5, one owned copy and same Character session/fresh epoch.
   Repeat SELECT-only verify-wear; no additional wear revision/material/ammo change.
7. Restore original112 via conditional equipment commands; disable self-kill/helper.
   Prepare-stop before deploying helper removal; do not repeat the accepted gate.

Alpha server rebuild flushes invalidate these IDs/audits. Never reuse retained
baselines against a rebuilt DB, overwrite a completed baseline or issue replacement
fixtures/materials without an actual need.
