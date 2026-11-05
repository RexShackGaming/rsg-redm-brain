# Native-only Standard Binoculars scoped gate

Implemented 2026-10-20; automated tests and scoped live ownership gates pass.
Live accepted: issuance174rev0/replay (native-binoculars-alpha-v1, serial
FW-BINO-6AD7FEAB-984014-0001, provenance26), three-utility coexistence beside172/173,
isolated third-slot removal, normal menu re-equip, prepared shutdown/guard teardown/
restart, death seal/doctor and normal new-session restoration. All three utilities
drawable; John ledger16/Tomahawk1 and155rev4/158rev5 wear preserved; Jane
ledger35/repeater1 and112rev2/134rev8 wear unaffected. Final John session
5bf6494d-cce3-11f1-9ad4-e0d55eaa2deb. No repeat grants/tests requested.
Deployment/test sequence below is retained as runbook, not instructions to rerun.
Original viewing/zoom/exit/combined-wheel evidence in binoculars-live-gate.md is
reused. Do not repeat that entire gameplay matrix as missing implementation.

## Admission and ownership

- Exact utility_binoculars / weapon_kit_binoculars / WEAPON_KIT_BINOCULARS.
  Improved Binoculars remains unsupported by this gate.
- Independent replicated feather_native_binoculars defaults0 and requires current
  Davy collection admission plus the existing utility/DevMode/enrollment/ammo/
  transport/lifecycle gates.
- Only weapon_utility_tertiary (Utility 3) admits Standard Binoculars. Lasso/Davy
  remain in the first two positions. At most one of each admitted family.
- Three private exact-GUID owners share the existing sealed parent lifecycle;
  uncertain third factory/creation/cleanup blocks release. No model-wide purge,
  adoption, uncertain retry, custom viewing controls or ammo writes.
- Inventory retains full snapshot/ownership/revision/metadata/current-mode CAS.
  Gate-disabled saved third assignments refuse rather than silently disappear.
- Utility 3 is included in server menu options and read-only occupancy when
  enabled. Existing generic Inventory UI needs no rebuild.

## First test: deployed gate-off baseline only

1. Leave current flags unchanged. Run WeaponNativePrepareStopAll; wait aggregate
   PASS/ready. Then manually fully quit BOTH clients.
2. Copy Weapons client/, server/, shared/ and fxmanifest.lua; preserve config.lua.
   Copy Inventory server/; preserve config.lua. No UI, SQL or schema deployment.
3. Server console:

       setr feather_native_binoculars 0
       refresh
       restart feather-inventory
       restart feather-weapons

   refresh is required for the newly manifest-loaded policy.
4. Reconnect and report new IDs, both weaponNativeStatus outputs and server
   WeaponNativeUtilityStatus. Expect binocularsLoaded true, convar0/enabled false,
   existing reinforced172 + Davy173 intact, ledger16/Tomahawk1 for John,
   Jane ledger35/repeater1 and no utilities.

Do not opt in or issue until this baseline is reviewed.

## Later operator-led steps

Use prepared Weapons-only drain then replicated feather_native_binoculars1 and
restart Weapons, preserving all existing flags. Confirm current owners/status.
Inspect John for an already-owned Standard Binoculars carrier. Historical original
item128 is not assumed current ownership. If absent, obtain operator approval for
one idempotent issuance/replay; no ammo/material budget is required.

Equip into Utility3 beside reinforced172 and Davy173. Check third GUID ownership,
wheel selection/drawability and unchanged sibling IDs/ammo/wear. Then isolated
third-slot cleanup, normal menu re-equip and the new three-child lifecycle
boundaries. Reuse original viewing/zoom evidence; do not regrant accepted fixtures.

Current durable observed baselines:
John155rev4 soot0.00499999988824/dirt0.6680000424385/degradation0.00778666650876,
damage/permanent0;158rev5 pristine. Jane112rev2 dirt1/degradation0.00871666707098/
other0;134rev8 pristine. John melee160..164rev0, carrier165rev0, utilities172/173rev0.

Scope does not include production enrollment, other utilities, true crash or
unknown SQL/native outcome recovery.
