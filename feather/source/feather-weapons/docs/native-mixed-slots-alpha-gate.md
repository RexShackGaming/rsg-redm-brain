# Focused normal-host mixed-slot integration

2026-10-14 LIVE normal-host mixed-slot integration ACCEPTED. Authorized fixture grant COMMIT returned Schofield134rev0/Carbine135rev0, original112rev1 unchanged. Post-grant audit captured. Conditional offhand134/shoulder135 commits restored ACTIVE exact three copies with all five wear fields0/ledger33/all carried0; user confirmed both sidearms and shoulder Carbine visible. Both extra slots conditionally unequipped; final ACTIVE idle one owned primary112 under fresh epoch5. SELECT-only verify-wear PASS revision1/changed=false/ammoUnchanged=true/equipmentUnchanged=true/materialConsumed0. Intermediate two-copy removal readback not supplied, so do not claim separately observed step. No firing/funded mixed-pool/UI slot menu coverage claimed. Fixtures134/135 remain unequipped until alpha flush, no deletion. Temporary mixed-grant helper/dedicated test removed locally after acceptance; cleanup deployment pending Inventory ONLY server/services/native_repair_fixture.lua, existing file/no refresh. Keep convar0. Reuse native-proof family/pair evidence; no repeat live economic gate.

Prepared 2026-10-14; live acceptance pending. User authorized two disposable
firearms: pristine Schofield and Carbine, no ammunition grant or firing. Existing
primary112 remains unchanged; worn128 is not used for unsupported permanent-wear
same-model GUID pair restoration. Reuse native-proof family/pair/firing evidence.

## Deployment and grant

Inventory only: server/services/native_repair_fixture.lua (existing loaded file).
No manifest/config/schema/UI changes or refresh. Prepare-stop current Weapons
owner (last source3), wait PASS, stop Weapons. Copy Inventory file; ensure
feather-inventory then feather-shops (Inventory restart stops its dependents).
Keep existing native/ammo/lifecycle/periodic flags; no config replacement.
Native-proof must also be stopped. Server console:

```text
set feather_jane_mixed_fixture 1
InvJaneMixedFixture <current-id> 6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb
set feather_jane_mixed_fixture 0
```

PASS supplies actual schofieldId/carbineId; never guess IDs. Replay is historical,
never recreates consumed/moved items. One transaction locks receipt/current owned
original112rev1/inventory, creates two canonical pristine instances, records IDs;
refusal rolls back entire transaction. No equipment/ammo/material writes.
Alpha rebuild invalidates receipt/item IDs/audit; no durable fixture migration.

## Batch after grant confirmation

Preserve prior private wear audit by renaming; capture fresh item112 baseline AFTER
grant while primary112 equipped and all other slots empty. Restart Weapons and
confirm ACTIVE one copy/ledger33/all carried0 (actual baseline prevails).

Use conditional equipment routes: equip returned Schofield into weapon_offhand,
then Carbine into weapon_shoulder. Expect two then three exact native copies and
three canonical item/revision entries in weaponNativeMaintenanceStatus. Confirm
visuals and equipment menu slot labels; no firing, loading, repair or artificial
wear. Unequip weapon_shoulder, then weapon_offhand, retaining primary112. Expect
two then one owned copies, unchanged ledger/carried pools.

After full assignment restoration, SELECT-only InvNativeRepairAudit current-id
Jane 112 verify-wear must show changed=false/materialConsumed0/equipmentUnchanged
and ammoUnchanged, preserving all other item rows and receipts. If native wear
changes naturally, inspect before claiming exact no-change; do not reset metadata.
No resource stop/logout/death/family matrix repeat required. New fixtures remain
unequipped until alpha flush; disable grant convar and remove helper after gate.
