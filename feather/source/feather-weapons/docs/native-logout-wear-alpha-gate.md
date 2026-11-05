# Voluntary logout final-wear gate

Changed-wear voluntary logout live gate ACCEPTED: native-only dirt0.4 on fixture128rev3 was saved by ordinary logout (no explicit checkpoint/prepare-stop), fresh session5bab7fbe-c6bd-11f1-9ae2-e0d55eaa2deb restored one exact copy128rev4 dirt≈0.4 with other wear unchanged. Inventory verify-wear PASS revision4/changed=true/equipmentUnchanged=true/ammoUnchanged=true/materialConsumed0; ledger25 all carried pools zero. Temporary helper removed after acceptance. Original112 restoration and cleanup deployment pending; death/periodic/crash persistence remain pending. No further repeat of this accepted logout gate is needed.

Changed-wear logout test prepared with user authorization to proceed without repeated approval: temporary default-off native-only fixed dirt0.3→0.4 helper targets exact Jane fixture128revision3/test serial/owned entity and zero carried pools. Independent readback requires unchanged other wear; no SQL/ammo/grant/material writes. Full Weapons Lua suite and diff checks pass; live changed-wear logout remains pending. Preserve completed revision2→3 audit by renaming before fresh revision3 capture. After helper PASS disable its convar and invoke ordinary logout, NOT maintenance checkpoint or prepare-stop (those would save before the boundary under test). Re-enter Jane, expect fixture128revision4/dirt≈0.4 and verify-wear conservation with current server ID. Remove helper and restore112 after acceptance.

Live voluntary logout/re-entry no-change gate accepted: inventory/equipment panels closed, character selector appeared, Jane re-entered with fresh session9db9c2e1-c6b8-11f1-9ae2-e0d55eaa2deb/epoch. Native host ACTIVE, exactly one owned copy, original112revision1 all five wear fields zero; ammo ledger25 and all carried pools zero. This confirms logout handshake/session retirement/re-entry integration, not a new changed-wear logout commit. Changed-wear logout and death/periodic/crash persistence remain pending.

Implemented and automatically tested; live acceptance pending. Under the existing
NativeAlphaLifecycleWearEnabled flag, Character's logout/save_quit checkpoint now
requests the server-owned shutdown transition. It waits outside the runtime busy
reservation so the release event can sample exact-owned wear before seal/removal.
The server acknowledges only after authoritative release and the Inventory wear
transaction. Client also requires its owner closed and the same current session
before allowing Character to call its logout RPC. No automatic old-session rebuild.
Caller, scope, pending request, one-use result, rate and timeout guards fail closed.
Flag off retains the existing ammunition checkpoint. No Character/Medical edits.

Death, periodic persistence, abrupt disconnect/crash and changed-wear equipment
live acceptance remain separate gaps. The completed orderly-stop changed-wear
transaction is reused, not retested with another temporary dirt helper.

## Deploy and first focused test

Only feather-weapons runtime files:

- client/character_ammunition_checkpoint.lua
- client/character_ammunition_routes.lua
- server/services/native_equipment_transition.lua

No manifest/new runtime file, UI, Inventory or Character/Medical deploy. No refresh
required. Preserve existing scoped flags including NativeAlphaLifecycleWearEnabled=true;
keep repair and all disposable helpers disabled. Prepare-stop current player, wait
for PASS, stop Weapons, replace files and ensure Weapons. Do not replace config.

First live integration gate uses restored original112rev1 with zero carried pools:
open inventory/equipment panel, invoke ordinary client logout, verify panels close
and selector appears, select Jane again. Read weaponNativeStatus and
weaponNativeMaintenanceStatus: fresh session/epoch, ACTIVE, exactly one copy,
original112rev1 with unchanged wear and ledger25 zero pools. Request no equipment,
ammo, oil or fixture grant. Report errors rather than bypassing a refused checkpoint.
Changed-wear logout end-to-end acceptance remains pending after this no-op gate.
