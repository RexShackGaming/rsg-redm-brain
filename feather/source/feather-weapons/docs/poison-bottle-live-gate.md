# Toxic Moonshine (Poison Bottle) live gate

Accepted based on reported manual checks: WEAPON_THROWN_POISONBOTTLE / AMMO_POISONBOTTLE. Native probe confirms maximum/current eight; wheel screenshot confirms Toxic Moonshine. Display labels match the wheel; internal poisonbottle identifiers stay stable. Tenth persistent position: throwable_denary / weapon_throwable_denary. No custom projectile recovery or unlock changes.

Reported native effect: cloud produced and nearby NPCs fled; damage/lethality was not established. Attached metadata/runtime agree at eight saved/native; these final snapshots do not independently show the seven-after-throw or zero-after-unload transitions. User reports the manual checklist passed. Smoke tests: lease 5/5, dual-slot 17/17, release 9/9 at 39/43/38 and twelve active slots.

Recipe and Weapons install seeds include carrier and ammunition. Existing installs use sql/add_poison_bottle.sql. Catalog expected: 39 weapons / 43 ammunition / 38 attachments.

1. Stop Weapons then Inventory, apply SQL and deploy all updated Weapons files; start Inventory then Weapons.
2. Server: grantweapon throwable_poisonbottle 1. Chat: /AddItems ammo_poisonbottle 10.
3. Equip beside all nine current carriers; confirm ten entries and capture the native wheel label.
4. Load eight, leaving two in Inventory. Run weaponthrowablecapacity throwable_denary; report maximum/current and stop if different from eight.
5. Throw one in an isolated test area. Expect seven saved/native, unrelated pools unchanged. Report native effect separately from ammunition accounting.
6. Verify Tab tap holster and hover/release switching without consumption.
7. Restart Weapons twice without re-equipping, then reconnect. Same serial/slot and seven saved/native must persist.
8. Unload seven: Inventory nine. No second unload is available and no extra items return.
9. Server: WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1, WeaponDualSlotContractSmokeTest 1, WeaponReleaseContractSmokeTest 1. Client: weaponruntime. Expect 5/5, 17/17, 9/9.

Optional failure simulation: reload eight; weaponthrowablepoolfailure throwable_denary; approved ownership must remain unloadable exactly once.

Identifier mapping is present in https://github.com/Rexshack-RedM/rsg-weapons/blob/main/config.lua . This does not establish capacity or native effect on the target build.

Improved ammunition and cosmetics remain deferred. Review utility catalog scope after this gate.
