# Torch retired

Torch (utility_torch / WEAPON_MELEE_TORCH) retired on 2026-10-03.
Tester observed wheel access and use, but Tab and hover/release switching dropped
it on the ground with no pickup. Davy Lantern was hidden while Torch was equipped.
Item 136 remained owned and server-equipped with runtimeMatch=true, while client
nativeOwned=false after dropping. This fails reusable utility lifecycle/coexistence.

Removed from active catalog and fresh-install Weapons/Recipe seeds. add_torch.sql
is now a no-op; apply retire_torch.sql to disable the existing usable definition.
No owned instances, serials, metadata or quantities are deleted or converted.
Existing restore reconciliation clears only the retired equipment assignment.
Stable utility_senary key is retained. Davy Lantern remains supported.
Expected catalog: 45 weapons / 43 ammunition / 38 attachments.

Post-deploy: confirm Torch remains owned/unusable, its equipment assignment is empty,
Davy returns to the wheel and other carriers remain accessible. Run
WeaponMetadataInspect 3, WeaponReleaseContractSmokeTest 3 and client weaponruntime
using current server ID. Retirement live checks passed, reported by tester on 2026-10-03.
Attached source=3 results confirm utility_senary empty, Davy item 127 retaining
serial/runtimeMatch=true, 21 active slots and release 9/9 at 45/43/38.
Owned/unusable Torch retention and Davy wheel functionality are tester-reported;
the attachment is an equipped metadata snapshot rather than an Inventory dump.
