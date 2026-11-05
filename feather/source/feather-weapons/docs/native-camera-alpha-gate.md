# Native-only Standard Camera equipment gate

Implemented 2026-10-20; automated tests and scoped live equipment gates pass.
Live accepted: issuance175rev0/replay (native-camera-alpha-v1, serial
FW-CAME-6AD81668-3E276A-0001, provenance27), four-utility coexistence beside172/173/174,
isolated fourth removal, normal menu re-equip, prepared drain/guard teardown/restart,
death seal/doctor and normal new-session restoration. All four drawable; John
ledger16/Tomahawk1 and155rev4/158rev5 wear preserved; Jane ledger35/repeater1 and
112rev2/134rev8 wear unaffected. Final John session6b72c02b-ccf1-11f1-9ad4-e0d55eaa2deb.
No repeat grants/tests requested. Runbook below is retained, not instructions to rerun.
Original camera-live-gate.md equipment/wheel evidence is reused. Weapons owns the
carrier and persistence only. Camera controls/shutter/photo saving remain a
separate optional add-on, not promised by a successful native grant.

## Scope

- Exact utility_camera / weapon_kit_camera / WEAPON_KIT_CAMERA. Advanced Camera
  is excluded. Ammunition-free serial carrier, zero native ammo grant.
- Default0 replicated feather_native_camera requires admitted Binoculars/Davy
  collection and existing utility/DevMode/enrollment/ammo/transport/lifecycle gates.
- Only weapon_utility_quaternary (Utility4), beside existing lasso/Davy/Binoculars.
  No implicit occupied-slot/family replacement; unsupported saved positions refuse.
- Four independently captured exact native GUID owners share sealed lifecycle.
  Fourth factory/creation/cleanup uncertainty retains the parent; no retry,
  adoption, model-wide purge, ammo credits, film grants or photography controls.
- Inventory owns locked full-assignment/metadata/revision CAS and final wear.
  UI options/occupancy include gated Utility4; existing generic UI needs no rebuild.

## First read-only deployment baseline

1. Leave existing flags unchanged. Run WeaponNativePrepareStopAll and wait for
   aggregate PASS/ready, then manually fully quit BOTH clients.
2. Copy Weapons client/, server/, shared/, fxmanifest.lua and Inventory server/.
   Preserve both config.lua files. No UI, schema or SQL changes.
3. Server console:

       setr feather_native_camera 0
       refresh
       restart feather-inventory
       restart feather-weapons

   refresh is required for the newly loaded policy script.
4. Reconnect, report new IDs, both weaponNativeStatus outputs and server
   WeaponNativeUtilityStatus. Expect cameraLoadedtrue/convar0/enabledfalse,
   three current utilities172/173/174 for John, ledger16/Tomahawk1, and Jane
   ledger35/repeater1/no utilities.

No Camera grant/equip until baseline is reviewed. Later prepared Weapons-only
gate1 restart precedes inspecting existing owned Camera; historical original133
is not assumed John ownership. If absent obtain operator approval for one
idempotent issuance/replay, no ammo budget. Equip into Utility4, verify four owners
and wheel/drawability, isolated fourth cleanup, normal menu re-equip and relevant
four-child lifecycle boundaries. Do not request non-existent photography controls.

Durable observed wear: John155rev4 dirt0.6680000424385/degradation0.00778666650876/
soot0.00499999988824, damage/permanent0;158rev5 pristine. Jane112rev2 dirt1/
degradation0.00871666707098/other0;134rev8 pristine. Utility172/173/174rev0.
No production enrollment, crash, transfer or unknown SQL outcome claim.
