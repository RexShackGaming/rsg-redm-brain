# Saved attachment reconstruction: scoped alpha gate

Implemented and automatically tested, live pending. Builds on the accepted fixed
Carbine child add/equip/draw/holster/stock-restore test; do not repeat that test.
Not attachment payment, production rollout, all weapons, or funded/death testing.

## Scope and deployment

Jane `6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb`, disposable Carbine135,
serial `FW-ALPHA-MIXED-JANE-V1-repeater_carbine`, one `carbine_wide_sight`.
Original112 must remain untouched. Preserve all config files and audit files.

Weapons existing files:
- shared/character_ammunition_materialization.lua
- client/character_maintenance_native.lua
- client/character_ammunition_creation_native.lua
- client/character_ammunition_loadout.lua
- client/character_ammunition_session.lua

Inventory existing file: server/services/native_repair_fixture.lua.
No manifest/new runtime script; no refresh required.

## Setup (current player ID1; replace if it changed)

Before deployment, normal Weapons active with no probe child:
1. `WeaponNativeEquipmentChange 1 unequip weapon_shoulder`, await PASS.
2. `WeaponNativePrepareStop 1`, await PASS, then `stop feather-weapons`.
3. Copy listed files; `restart feather-inventory`, await readiness. Proof stays stopped.
4. `setr feather_native_child_component_probe 0` (accepted manual probe disabled).
5. `setr feather_native_guid_ownership 1` and `setr feather_native_saved_attachments 1`.
6. `set feather_jane_saved_attachment_fixture 1`.
7. `InvJaneSavedAttachmentFixture 1 6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb install`.
8. Require PASS revision1, then `set feather_jane_saved_attachment_fixture 0`.

Fixture changes ONLY saved attachment array of unequipped pristine135 via CAS.
No grants/payment/material/ammo/equipment writes. Idempotent install at rev1;
only one cycle per database (install rev0→1; remove rev1→2). Unknown state refuses.
Old wear audit baseline for135 is intentionally no longer applicable.

## Live rebuild test

1. `ensure feather-weapons`, await primary startup.
2. `WeaponNativeEquipmentChange 1 equip weapon_shoulder 135`, require PASS.
3. F8 `weaponNativeStatus`, `weaponNativeEntityStatus`, `weaponNativeMaintenanceStatus`.
4. Require112rev1 and135rev1, pristine wear, wideSightPresenttrue,
   nativeAttachmentChild stock=false/wide=true, exact verified wide GUID.
5. `WeaponNativePrepareStop 1`, require PASS; stop then ensure Weapons.
6. Repeat three read-only statuses. Same saved item/revision/attachment, fresh
   runtime epoch and native child GUID, correct wide flag/model, no fixture replay.

Do not manually add/remove the saved child with the old component probe. Automatic
creation restores it; ordinary owned cleanup restores stock and removes newchild.
Any refusal: retain state; no forced restart, new grant, hash adoption, or SQL repair.

## Restore baseline after acceptance

1. Unequip135 shoulder, await PASS; prepare-stop, await PASS; stop Weapons.
2. Enable fixture convar, run same fixture command with `remove`, require PASS
   revision2, disable fixture convar. No stock SQL attachment remains.
3. Disable saved attachment convar and GUID ownership only after135 is unequipped
   and Weapons stopped. Ensure Weapons restores primary112 only.
4. Disposable135 remains unequipped until alpha database flush. No fixture deletion.

## Automated coverage

Actual Scoped adapter + materialization preflight + loadout + native child mocks
exercise saved creation, direct per-child equipped flags, child-first cleanup,
fresh epoch reconstruction with fresh GUIDs, and flag-disabled veto. Separate
tests retain failed compensation handles in frozen session/native-owner tracking.
Inventory fixture tests cover fixed serial/pristine/unequipped/revision scope,
CAS and idempotence without economic/equipment queries. Native engine gate pending.
2026-10-14 LIVE saved fixture setup REFUSED before transaction twice despite confirmed Weaponsstopped/playerID1 and Inventoryrestart. Exact remaining gate not identified; no fixture metadata written/no rebuild acceptance. Added read-only `InvJaneSavedAttachmentFixture 1 <Jane> inspect` to existing Inventory native_repair_fixture.lua, reports DevMode/native-runtime flag, readiness, optin, Weapons/proofstates, sessionlookup/character/Corecurrent checks; install refusal includes same details. Inspector bypasses fixture mutation/transaction and works with optin0; no gates loosened. FullInventory runner incldiagnosticmocktests PASS. Deploy only Inventory server/services/native_repair_fixture.lua, restartInventory (restoredependent shops/admin as needed), keepWeaponsstopped and fixtureflag0; runinspect rather than repeatinstall/configchanges. Await evidence; do not guessproofstate or changeCharacterAmmunitionEnabled.

2026-10-14 saved fixture refusal ROOT CAUSE confirmed by liveINSPECT: allresource/readiness/session/Core/Dev checks pass; inventoryNativeRuntimeDisabledfalse means nativeCharacterAmmunitionEnabledtrue. Fixtureoptinfalse expected afteruserdisabledflag forreadinspection. Bug copied obsolete inverse nativefeaturegate fromoldrepairfixture. FIXED new savedfixture ONLY to require Config.CharacterAmmunitionEnabled==true, diagnostics renamedinventoryCharacterAmmoEnabled; regression exercisesenabledallowed/disableddenied. Existing repairfixtureuntouched. FullInventory runner PASS; no runtimeconfigchange. Deploy ONLY Inventory server/services/native_repair_fixture.lua, restartInventory/restoredeps, set fixtureoptin1, runinstallonce andset0; expect135rev1. Weapons/proofremainstopped. Saved attachment rebuild still livepending.

2026-10-14 LIVE saved attachment fixture INSTALL PASS: item135 revision1, modeinstall/unchangedfalse/fixtureMetadataWritetrue, noEquipmentWrites/noAmmoOrMaterialWritestrue. User disabledfixtureconvarafterPASS. This is explicit disposable canonical metadata staging only, not productionattachmentpayment or reconstructionacceptance. Next ensureWeapons then conditional equipshoulder135 and inspect native/entity/maintenance: expected112rev1+135rev1/pristine/savedwide childon/stockoff. Saved/guidconvarsremain1; manualchildprobe0. No new deployment/configflagsrequired fornextstep. Do not rerunfixtureinstall or usemanualchildprobe toapplysavedmetadata.

2026-10-14 LIVE saved metadata reconstruction initial creation PASS. Runtime12860205:2 ACTIVEidle/copies2, ledger33/all27pools0. Original112rev1 entity879108/wearall0; Carbine135rev1 entity867588/capturedweaponGUID80000000000000009db30382c239540a/wearall0, wideSightPresenttrue. Automatic nativeAttachmentChild ownedtrue/uncertainfalse/count2: exactwideGUID80000000000000009db30382c2395494 f10=1/readConfirmed; stockGUID80000000000000009db30382c239540f f10=0. No manual component install. Confirms canonical fixture metadata→normal native creation for fixed135. Ordinary orderly stop/fresh resource-start reconstruction still pending; preserveflags/metadata, no newfile/fixtureoperation. Nextpreparestop1PASS→stop/ensureWeapons→readstatuses; requirefreshnativechildGUID/differentepoch andsame135rev1/ledger33/pristinewide. Do not repeatdraw/holster acceptedgate or manualprobe.

2026-10-14 LIVE saved attachment FRESH RESOURCE RECONSTRUCTION PASS: runtimeepoch12860205:2→13001400:1, ACTIVEidle/copies2, ledger33/all27pools0, same character/session.135 remainsrevision1/pristine, newparentGUID80000000000000009db30382c23ba34b/newwideGUID80000000000000009db30382c23ba4c9 (priorwidec2395494), stockGUIDc23ba350 preserved/off, wideon/readConfirmed/verifiedGUIDmatching/wideSightPresenttrue.112revision1/pristine independently rebuilt. No manualprobe/fixture reapply. Submitted paste lacks precedingPrepareStopPASS, so fresh reconstruction accepted but no invented priorstopcleanupack. Next ordinary shoulderunequipPASS→preparestopPASS then stopped explicitfixture remove (rev1→2), disable saved/guid flags onlyafter135unequipped, ensureprimarybaseline. No repeat accepteddraw/holster orfreshrebuild gate. No newfiles/configdeploymentrequired. This remains scoped native metadata reconstruction, not payment/generalization/death/funded/multiplayer acceptance.

2026-10-14 LIVE savedattachment SHOULDER UNEQUIP PASS (automatic childcleanup/freshsame-session restore) and PrepareStopPASS finalseal/ownedcleanup/serverrelease. Afterstop fixture SQL removal REFUSED stale feather-weapons guard callback errored; failclosed, no acknowledged removal (expect135stillrev1). Rootcause native guard provider Install registered3crossresource callbacks but hadnoUninstall/onResourceStop; Inventory registry retained deadCFXrefs. FIXED nativeprovider teardown only when service CanReleaseInventoryGuards sees loadouts/opening/deathwrites all empty. All3unregister callbacks preflight/callableCFX/nilvoidresults supported; held/unknown provider refuses, no bypass on guarderror, own-resource stoponly. Tests activeleaseveto/independentretirement/empty, held/missing/duplicate teardown and resourceevent.109Lua+7Node PASS. Existing stale registry recovery restartInventory WHILE Weaponsremainsstopped, restoredependentShops/Admin, retryexplicitfixture remove thenflag0. Copy Weapons ONLY server/adapters/character_ammunition_inventory.lua and server/services/character_ammunition_runtime.lua while stopped topreventnextgracefulstop recurrence. No Inventory/configfileschange; no refresh. Previous live reconstruction accepted; baselinecleanup fixture rev2 stillpending. Guardfix live teardown evidence pending; not abrupt/unknownstop or legacyguard lifecycle acceptance.

2026-10-14 LIVE saved attachment fixture REMOVE PASS after stopped Inventoryrestart cleared stale callback registry: item135revision2/mode remove/unchangedfalse/fixtureMetadataWritetrue/noEquipmentWrites/noAmmoOrMaterialWritestrue. Userfixtureoptin0. Combined accepted initial saved reconstruction, fresh-resource freshGUID rebuild, conditionalshoulderunequip and orderlyseal/release, plus explicitcanonicalfixture cleanup.135nowunequipped/attachments empty; original112protected. Next disable feather_native_saved_attachments and feather_native_guid_ownership (Weaponsstillstopped), ensureWeapons, primary-only status expectedcopies1/ledger33/all0/112rev1wear0. No files or config replacement required. New guardteardowncode locally tested/deployment instructed; no live teardownPASS supplied yet, do not mark engineaccepted. Full attachment payment/generalization/death/funded gates remain outsideaccepted scope.

2026-10-14 LIVE PRIMARY BASELINE RESTORED after saved fixturecleanup and userinstructedtemporarysaved/GUIDflags0. Epoch13691213:1 ACTIVEidle/nonquiescing/notreceiving/copies1; originalCattleman112revision1/all5wear0; ledger33/all27ammo0/no pending/closing/deathclosing. Disposable135revision2 remainsunequipped afterexplicitwideattachmentfixture removal; no repeatfixturecycle. Scoped savedattachment initialcreation/freshresource reconstruction/nativechild cleanup/canonicalfixture cleanup/base restore gate COMPLETE in tested scope. Not general attachment/paymentproduction rollout; inventoryguardteardown fix stillneeds futurelive own-stopPASS evidence (109Lua+7Node automated). Next implementation can broaden policy-controlled native reconstruction or canonical payment/release-before-CAS, retaining acceptednativeproof results rather than retestingthem. No currentdeployment/flag/testingrequests.

