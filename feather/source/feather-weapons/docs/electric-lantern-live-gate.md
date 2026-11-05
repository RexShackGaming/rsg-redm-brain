# Electric Lantern retired

Electric Lantern (utility_lantern_electric / WEAPON_MELEE_LANTERN_ELECTRIC)
failed native materialization: server item 135 matched runtime but client nativeOwned=false.
Tester reported no wheel entry even with Davy Lantern unequipped; attached snapshots
still showed Davy equipped, so the isolation result is tester-reported separately.

Retired from active catalog and fresh-install Weapons/Recipe seeds on 2026-10-03.
Historical add_electric_lantern.sql is now a no-op. Apply retire_electric_lantern.sql
on existing databases to disable its usable definition. Owned item IDs, serials,
metadata and quantities are not deleted or converted. Existing restore reconciliation
rejects and clears the old equipment assignment only. The stable utility_senary key
is retained for saved-loadout compatibility and future utility equipment.

Davy Lantern remains supported. Expected catalog: 45 weapons / 43 ammunition / 38 attachments.

Post-deploy checks: original Electric Lantern remains owned but unusable; Davy still
works; no electric carrier is restored into native loadout. Run WeaponMetadataInspect,
WeaponReleaseContractSmokeTest and client weaponruntime with current player ID.
Retirement live check pending; static retirement contracts pass.
Retirement confirmed by tester on 2026-10-03. Source=3 results show utility_senary
empty, 21 valid equipped slots and release 9/9 at 45/43/38. Tester separately
confirmed retired item remains owned but unusable. No deletion/conversion occurred.
