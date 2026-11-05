# Scoped native wear checkpoint

Live update: one changed-wear commit is durably verified at fixture128revision2
with equipment/ammo/materials unchanged, but immediate reconstruction failed.
Postcommit float equality defect is reproduced and fixed with1e-12 tolerance only
on known wear fields; other metadata remains exact. The generic old failure did
not retain its specific reason. Recovery is a Weapons restart/readback/audit, never
a second checkpoint/payment/grant. The server transition now logs bounded rebuild
reasons for future errors.

Implemented opt-in console checkpoint, not periodic persistence. Default
`NativeAlphaMaintenanceEnabled=false`; repair may stay disabled. Console
`WeaponNativeMaintenanceCheckpoint <server-id> <equipped-item-id>` requests exact
owned client readback under a one-use 10-second ticket. Server checks actual
session/epoch/equipment/item revision, canonical monotonic wear, then reserves
the existing equipment/stop coordinator. Changed wear requires final seal/release,
Inventory metadata CAS and fresh restore; no ammo/material economic writes.
Float changes <=0.0001 are ignored. Unchanged wear returns PASS without release
or SQL writes. Stale/foreign/duplicate replies cannot write.

Limitations: severe wear that would make the rebuilt loadout unequippable is
refused during preflight, not silently saved or healed; broken-weapon policy is
pending. Nonzero permanent wear on identical-model GUID pairs remains unsupported.
Automatic periodic/final lifecycle wear checkpoints and full multiplayer enrollment
are not enabled. Tests use transaction/native mocks; live acceptance is pending.

## Runtime files for this delta

Weapons:

- `config.lua` — preserve server overrides; add `NativeAlphaMaintenanceEnabled=true`
  for this batch only. Keep repair false and existing scoped native flags unchanged.
- `fxmanifest.lua`
- `shared/character_maintenance.lua`
- `client/native_maintenance_checkpoint.lua` (new)
- `server/services/native_equipment_transition.lua`

Inventory:

- `server/services/native_repair_commit.lua`
- `server/services/native_equipment_commit.lua`
- `server/services/native_repair_verify.lua`
- `server/services/native_repair_audit.lua`

No UI, test or documentation files need deployment. Run server-console `refresh`
before restarting because the client script/manifest is new. Preserve both private
audit files and do not carry them into a rebuilt alpha database.

## First live stage

Use already-owned repaired disposable fixture128; never regrant oil or run repair.
Restore all normal dependencies after Inventory restart. Current server ID must
still be checked rather than assumed to remain2.

```text
refresh
ensure feather-inventory
ensure feather-shops
ensure feather-weapons
WeaponNativeEquipmentChange <ID> unequip weapon
```

Wait for PASS, then:

```text
WeaponNativeEquipmentChange <ID> equip weapon 128
```

Wait for PASS; client F8 `weaponNativeMaintenanceStatus` must show fixture128rev1,
permanent/degradation/damage≈0.1 and dirt/soot0. Server:

```text
InvNativeRepairAudit <ID> 6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb 128 capture-wear
```

Stop and return capture/readback output before requesting the first checkpoint.
Wear capture uses `.native-wear-audit-<uuid>.json`, separate from the repair baseline.
Later `verify-wear` accepts exactly one monotonic wear revision or a genuine no-op,
and requires unchanged equipment/ammo/materials/other items. Do not run multiple
mutating checkpoints against the same one-operation baseline.

Original repair's automatic assignment preservation remains an unresolved live
gap. User suspects an extra Weapons restart; this is plausible but not established
by the captured logs. Successful recovery/restart does not replace that gate.

## Temporary authorized dirt helper

Completed/removed: user confirmed changed-wear persistence/restart and original112
restoration. Temporary dirt command and adapter/owner hooks were removed from the
four client files below; deploy those cleaned files to remove it from the server.
Helper-only test was removed; normal maintenance and checkpoint regressions remain.
Keep `feather_native_fixture_dirt=0`. The historical helper steps below are retained
as the test record, not commands to repeat. No server fixture/audit file was deleted.

Natural dirt did not increase. User authorized native dirt0.2 only on Jane's
fixture128revision1/test serial, with zero carried baseline. No SQL/ammo/oil or
original112 mutation. Deploy only these Weapons files for this helper delta:

- `client/character_maintenance_native.lua`
- `client/character_ammunition_creation_native.lua`
- `client/character_ammunition_native_owner.lua`
- `client/character_ammunition_startup.lua`

No Inventory/config/manifest/UI changes. Preserve flags and audit files. Restart
Weapons once, then server `setr feather_native_fixture_dirt 1`; client F8
`weaponNativeFixtureDirt`. Wait for PASS readback dirt≈0.2, then server
`setr feather_native_fixture_dirt 0`. Return output before checkpoint. Do not run
repair/grant or recapture/overwrite the existing wear baseline. Remove this helper
after the focused changed-wear gate.
