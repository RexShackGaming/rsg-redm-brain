# Component construction settlement prerequisite

2026-10-14 construction-time live gate FAILED on first draw. Holstered135 had componentPresenttrue/tracked2096386/wear0; drawing destroyed2096386 and exposed2100482, maintenance_owned_object_unavailable. Thus20frame settlement does not establish stable component-bearing copy ownership. Original112 remained tracked2096130. No production attachment economics enabled/accepted. User exited/reconnected with creationflag0; fresh sessioncdc02018-c82a-11f1-9ae2-e0d55eaa2deb restored112rev1/135rev0/wear0/ledger33/all0/two active copies. Temporary construction helper+dedicated test removed locally; entity diagnostics retained, full Weapons Lua suite and diff check pass. Cleanup deployment pending Weapons ONLY client/character_ammunition_creation_native.lua/no refresh. Both componentflags0. Next research requires independent native inventory GUID→current weapon object association across draw, not model-only/entity adoption. Existing GUID pair insertion/removal evidence does NOT establish that mapping, and no confirmed mapping/API is implemented yet. Do not reopen failed component test with longer wait.

2026-10-14 prepared/automatically tested; live acceptance pending. Earlier in-place
Carbine probe destroyed tracked entity on a later frame and is removed. Ordinary
draw-only preserves entity; do not blame normal draw or adopt live replacements.

Temporary replicated default-off feather_native_component_creation=1 affects only
135rev0/fixed mixed-fixture serial/Carbine under configured current Jane/Dev native
alpha. During zero-ammo single construction only (not attached existing copies),
load fixed Wide Sight model bounded100frames, verify original creation point/entity,
apply component to that entity, wait20 current-identity frames, settle current
created copy again, require component presence on final entity, then apply/readback
saved maintenance. Only then return record for lease tracking. No SQL/ammo/material
or saved attachment metadata change. Generic attached loadouts remain rejected;
same-model GUID pair customization and economic/player attachment path unsupported.

Automated native-mock regression covers delayed object replacement, final handle
maintenance/readback, final cleanup and missing-component/wrong-fixture compensation.
Full Weapons Lua suite passes. Finite frame wait is not proof against arbitrarily
late engine replacement; live draw/holster diagnostic is required. Creation failure
does not authorize blanket cleanup or adoption if context/entity is no longer owned.

Deploy Weapons ONLY client/character_ammunition_creation_native.lua, existing file,
no manifest/config replacement/refresh. Current saved112+135, ledger33/carried0.
Keep old probe convar0. Prepare-stop current-id/PASS; stop/copy; setr new creation
convar1 BEFORE ensure. Expect ComponentCreation PASS plus ACTIVE two tracked copies,
112rev1/135rev0 wear0. Read EntityStatus holstered, draw135/no firing, read again:
Carbine final trackedExists true, same tracked entity moves10→0, componentPresent
true, maintenance remains readable, original112 unaffected. Compare visuals but
do not claim appearance from native presence alone.

Then setr creationconvar0 (does not alter existing component) and conditional
unequip shoulder135: read final wear/release/remove exact tracked copy/reconstruct
primary112. This tests safe copy cleanup, not returning a paid attachment item.
No in-place component removal attempt. Keep fixtures unequipped until alpha flush.
Inventory135 verify-wear before unequip can reuse unchanged saved assignment audit;
expect changedfalse/revision0/material0/unchanged equipment+ammo. Do not claim full
attachment economics/restart metadata persistence from this native-only gate.
