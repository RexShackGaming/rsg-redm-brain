# Lantern status: Davy supported, Standard retired

2026-10-20 native-only port: original Davy lighting/wheel/switching evidence below
is reusable. Strict Davy policy, two-utility snapshot/lease/owner composition and
conditional transitions are implemented under default0 feather_native_davy_lantern.
Existing item/native names and zero ammunition are preserved. Automated tests pass;
scoped new-port live ownership gates passed on 2026-10-20: issued173rev0/replay,
coexistence with reinforced172, exact removal/menu re-equip, prepared restart,
death/doctor and normal new-session restoration with unchanged observer balances
and wear. See native-davy-lantern-alpha-gate.md; no repeat issuance/test requested.
Historical reconciliation/grant instructions below are not native-only port
instructions: do not clear saved assignments or adopt/remove untracked copies.

Standard Lantern (utility_lantern / WEAPON_MELEE_LANTERN) failed wheel testing,
even with Lasso unequipped, despite matching metadata and native ownership.
It is removed from the active catalog and fresh-install seeds. The old add_lantern.sql
is now a no-op to prevent accidental recreation. Existing carriers are not deleted
or converted. Apply retire_standard_lantern.sql to disable their usable definition.
An old saved equipment assignment is rejected and cleared by existing restore reconciliation;
the underlying Inventory item remains owned. No automatic Davy replacement or refund.

## Standard Lantern result / separate Davy candidate

Standard Lantern did not appear on either wheel page, even with Lasso unequipped.
Server item 126 remained valid and matched runtime; native ownership was true.
This is not an accepted functional Lantern. Its item/model remain unchanged.
Separate candidate utility_davy_lantern uses WEAPON_MELEE_DAVY_LANTERN.
Unequip Standard Lantern before testing Davy beside one Lasso in the two utility positions.
Supported item setup: sql/add_davy_lantern.sql; grantweapon utility_davy_lantern 2 (current server ID).
Repeat lighting, switching, no consumption, ammo UI exclusion, two restarts and reconnect checks above.
Catalog counts: 43 weapons / 43 ammunition / 38 attachments. Davy live acceptance passed on 2026-10-02.
Tester reported the manual lighting, switching, no-consumption and lifecycle checks passed.
Screenshot confirms Weapons wheel entry Melee / Light / Lantern alongside Lasso.
Server metadata confirms Davy item 127, serial FW-LANT-6AC088F1-CB77F4-0001,
in utility_secondary with zero ammo and runtimeMatch=true alongside Reinforced Lasso.
Client confirms both nativeOwned=true and existing throwable pools intact.
Lease checks passed 5/5 (Lasso slot); release checks passed 9/9, 14 active slots.
The snapshots do not independently demonstrate every lighting/lifecycle transition.
Standard Lantern remains a failed wheel candidate, not an accepted functional item.

Current active catalog after retirement: 42 weapons / 43 ammunition / 38 attachments.
Retirement manual checks passed, reported by the tester on 2026-10-02.
Attached source=2 metadata confirms Reinforced Lasso item 125 and Davy Lantern
item 127 retain their serials, zero ammunition and runtimeMatch=true.
Release contract passed 9/9 with 42 weapons / 43 ammunition / 38 attachments
and 14 active slots. Retired item retention/unusable state is tester-reported;
the attachment is an equipped-loadout snapshot, not an Inventory or SQL dump.
