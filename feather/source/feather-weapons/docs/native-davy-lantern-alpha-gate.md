# Native-only Davy Lantern scoped gate

Implemented 2026-10-20; automated checks and scoped live ownership gates pass.
Live accepted: issuance173rev0/replay (native-davy-lantern-alpha-v1, serial
FW-LANT-6AD7F4F4-88DFF5-0001, provenance25), coexistence beside reinforced172,
isolated Davy removal, normal menu re-equip, two-owner prepared shutdown/guard
teardown/restart, death seal/doctor and normal new-session restoration. Both
utilities drawable; John ledger16/Tomahawk1 and155rev4/158rev5 wear preserved;
Jane ledger35/repeater1 and112rev2/134rev8 wear unaffected. Final John session
60e5fc61-ccde-11f1-9ad4-e0d55eaa2deb. No repeated grants/tests requested.
Deployment/test sequence below is retained as the runbook, not a request to rerun.
Original Davy lighting/wheel/switching evidence is in lantern-live-gate.md.
Do not repeat it as missing implementation. Standard Lantern remains retired.

## Scope and invariants

- Existing identity: utility_davy_lantern / weapon_melee_davy_lantern /
  WEAPON_MELEE_DAVY_LANTERN. Serial-bearing, ammunition-free, zero native ammo grant.
- Independent replicated feather_native_davy_lantern defaults0; existing utility,
  DevMode, exact character enrollment, transport/ammo/lifecycle gates still apply.
- Two existing utility slots only. At most one lasso and one Davy Lantern.
  Neither an occupied slot nor an equipped family is replaced implicitly.
- Davy gate-on utility bundles/status use an items collection, including a single
  lasso. Each child retains its own identity, item revision and captured native GUID.
- One uncertain child factory/creation/removal blocks parent release. No adoption,
  model-wide purge, retry, reconciliation, item conversion or ammo credit.
- Full assignment/metadata/revision checks, final wear and conditional equipment
  mutation remain under the existing released-owner reservation/transaction flow.

## Deployment and first read-only checkpoint

1. Leave feather_native_davy_lantern0 and all existing flags unchanged.
2. Run WeaponNativePrepareStopAll and wait for aggregate PASS/ready.
3. Fully quit BOTH clients manually. Drain does not disconnect them.
4. Copy Weapons client/, server/, shared/ and fxmanifest.lua; preserve config.lua.
   Copy Inventory server/; preserve config.lua. No Inventory UI or schema change.
5. Server console refresh (new scripts/manifest), then restart feather-inventory
   and restart feather-weapons. Reconnect both characters.
6. Report new player IDs, both weaponNativeStatus and WeaponNativeUtilityStatus.
   Expect Davy loaded but disabled, previous lasso/companions and durable balances.

Do not enable Davy against active owners. After that baseline, use a prepared
Weapons drain, setr feather_native_davy_lantern1 and restart Weapons; clients may
remain connected for that Weapons-only change after aggregate PASS. Obtain new
statuses before any candidate issuance/equip.

## Subsequent operator-led tests (not automatic grant instructions)

Check whether an existing Davy carrier is already owned. Never reuse the historical
original tester item127 as a current item assumption. If absent, obtain operator
approval for one idempotent issuance, replay the same request key, then disable
issuance. No ammo/material budget or funding is needed.

Equip the owned Davy into the open utility slot beside the currently equipped
reinforced172. Confirm both identities/GUIDs and unchanged ledger/ammo/sibling
revisions. Test exact Davy unequip with the lasso and companions retained, then
normal menu re-equip. Verify relevant restart/death/normal-session ownership
boundaries without replaying the entire original rope/lighting gameplay matrix.

Current pre-deployment baselines:
Jane ledger35/repeater1; items112rev2 dirt1/degradation0.00871666707098 and134rev8 pristine.
John ledger16/Tomahawk1; utility172rev0; melee160..164rev0; carrier165rev0;
155rev4 dirt0.6680000424385/degradation0.00778666650876/soot0.00499999988824;
158rev5 pristine. Current IDs are ephemeral; ask after reconnect.

This gate does not accept arbitrary utilities, production enrollment, true crashes,
cross-player ownership transfer, or unknown SQL outcomes.
