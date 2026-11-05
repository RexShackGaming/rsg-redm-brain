# Native attachment payment/return alpha gate

2026-10-15 post-UI baseline runtime confirmed: epoch18118304:1 in existing
sessionb2e3ab83-c83f-11f1-9ae2-e0d55eaa2deb ACTIVE/idle/nonquiescing/notreceiving,
ownedCopies1/sessioncopies1, no ammo pending/closing/deathClosing, ledger33/all27
carried pools0. This closes the runtime restoration gate. Latest canonical item
evidence remains112rev1 and unequipped135rev6/empty attachments/material1 from
the accepted sequence; this status does not itself identify the one native item.
Three temporary attachment flags were instructed0; no independent convar readback
was supplied. No further deployment or repeat attachment test required.

## 2026-10-15 LIVE Equipment menu roundtrip accepted

User followed the Equipment-menu install/remove gate. Read-only preflight135rev4,
attachments empty/material1, primary112rev1 only. After installation, status showed
135rev5 with carbine_wide_sight/sight, material0, shoulder assignment retained and
primary112rev1 unchanged; fresh epoch17840056:3. Removal SQL COMMIT
716198e0-f042-4a23-a32f-2e1ff5e94fa4:3643 (23 queries) followed by
WeaponNativeAttachmentChange PASS canonical payment/metadata CAS/fresh same-session
restore/no ammo economic writes. Read-only status135rev6/attachments empty/material1,
same shoulder assignment and primary112rev1; fresh epoch17941308:4 in session
b2e3ab83-c83f-11f1-9ae2-e0d55eaa2deb. This accepts the scoped pristine player-menu
economic roundtrip, not additional visual/native/ammo readbacks or race/failure
coverage. Primary-only restoration/temporary three-flag shutdown pending. No new
deployment or repeat proof requested; returned sight retained until alpha flush.

## 2026-10-15 Equipment menu integration — live pending

Existing Equipment options now include server-derived `kind=attachment` install
or remove actions for an assigned supported Carbine. Preview requires the same
feature/station/authorization/catalog gates and material presence for install;
it performs no release/payment. Change revalidates through the sealed coordinator.
Inventory routes the button through NativeAttachmentChange/ChangeNativeAttachment,
with its shared equipment busy gate and existing panel lifetime/epoch invalidation.
All 112 Weapons Lua specs/7 Node tests, Inventory Lua runner (including NUI bridge),
2 UI lifetime tests, UI ESLint and Vite production build passed. Native UI click
acceptance remains pending; prior console/payment and draw proofs remain accepted.

Deployment delta since the accepted console gate:
- Weapons: client/native_equipment_actions.lua;
  server/services/native_equipment_transition.lua;
  shared/character_ammunition_materialization.lua;
  client/character_ammunition_creation_native.lua.
- Inventory: client/services/nuicallbacks.lua and complete rebuilt ui/ folder.
No config replacement or new runtime script/manifest entry. Preserve live configs.
PrepareStop current player, wait PASS, stop Weapons before copying/restarting.
Restart Inventory (and its stopped Admin/Shops dependents); enable the same three
saved/GUID/transaction gates, ensure Weapons. Do not restart Core/Character/Medical.

One UI gate only: verify read-only AttachmentStatus current-player 135 still shows
revision4/empty attachments/material1. Equip135 shoulder through Equipment, reopen
at configured gunsmith. Click Install — Wide sight once; expect material0/revision5,
saved sight and fresh active copies2/unchanged ammo33. Reopen, click Remove once;
expect material1/revision6/attachments empty and unchanged ammo. Use read-only status
after each click. No manual native probes/grants/fixture metadata writes. Refusal,
timeout or uncertain result: report output, never repeat payment automatically.
Unequip shoulder after success, PrepareStop/stop, disable three gates, ensure Weapons
to restore original112-only baseline. Current player ID must be checked, not assumed.

Implemented/automatically tested; pristine scoped install/payment/remove/return
live gate ACCEPTED (dated evidence below). Broader UI/failure scenarios remain
pending. Existing saved reconstruction and draw/holster proof stay accepted.
No legacy attachment RPC reenabled.

2026-10-15 player-intent bridge: Inventory-only client export
`ChangeNativeAttachment(itemId, installOrRemove, scope)` now uses the existing
bounded native-equipment channel with `attachment-change` kind. Server derives
the actor from event source and resolves assignment, catalog, station, material,
revision and sealed release through the same coordinator as accepted console
transactions. Scope/busy/rate guards and fresh-restore completion remain shared;
no client metadata/payment authority or legacy RPC fallback. Client and concrete
server transition harnesses pass. Inventory menu/options/NUI hookup is still
pending, so this bridge alone is not a player-visible feature or live test gate.
No server deployment/flag change requested yet. Next deployment delta includes
Weapons client/native_equipment_actions.lua and server/services/native_equipment_transition.lua,
plus the previously staged identity-generalization files. No new runtime scripts.

Current support: owned Carbine copies with canonical identity/metadata and
carbine_wide_sight only, within the configured alpha character scope. The accepted
live payment gate used disposable135; arbitrary IDs/serials are additionally covered
by automated creation/rebuild/transition tests. Other attachments remain refused.
`WeaponNativeAttachmentStatus <player> <owned-carbine-item-id>` is read-only;
`WeaponNativeAttachmentChange <player> install|remove <equipped-item-id>` writes.

## Protocol

Server verifies owned equipped item, canonical metadata/catalog compatibility,
gunsmith station and existing authorization policy. Install checks at least one
material unit before releasing natives. Full final-wear snapshot is reserved.
Only acknowledged sealed cleanup/release permits the exact one-use ticket to write.
Station/authorization rechecked before Inventory transaction. Inventory revalidates
Core/session/ticket at write boundaries; locks full equipment/item metadata/revision.
Same transaction commits monotonic final wear, consumes/returns exactly one sight,
and metadata CAS; capacity/payment/CAS/current/postequipment failures roll back all.
Changed target wear requires wear CAS plus attachment CAS (two target revisions,
one transaction); unchanged target wear requires just attachment CAS. Rebuild checks
all resulting revisions/metadata before fresh same-session activation. Unknown
commit acknowledgement freezes without retry, refund, or speculative native rebuild.

## Deployment (not a config replacement)

Weapons: fxmanifest.lua; shared/character_attachments.lua (NEW);
server/services/attachments.lua; server/services/native_equipment_transition.lua.
Inventory: server/services/native_attachment_commit.lua (NEW, existing wildcard);
server/services/native_equipment_commit.lua.
Run `refresh` before restarting resources: manifest/shared script and Inventory
wildcard runtime script are new. Preserve configs/audit files. PrepareStop PASS,
stop Weapons first; restart Inventory and dependent shops/admin, then ensure Weapons.
Gates: setr feather_native_saved_attachments 1; setr feather_native_guid_ownership 1;
setr feather_native_attachment_transactions 1. Existing lifecycle-wear must stay on.
Keep fixture convars/manual component probes OFF. Leave135 unequipped for first
read-only Status (explicit item ID135 for the historical fixture), expected saved
revision2/attachments empty/material quantity for that original setup.

## Live test outline (wait for first read-only status before payment)

Need one ordinary carbine_wide_sight unit in Jane's inventory; no fixture metadata
install command (old one-cycle fixture is complete). Do not grant extra weapons.
Use normal authorized development item supply if needed; no agent-side grants.
Stand within configured Valentine gunsmith bench tolerance; don't disable station
or authorization policy to pass. Equip135 shoulder, capture read-only Status and
native ammo status baseline. Install command: expect material -1, attachment saved,
fresh native wide equipped, unchanged assignment/ammo/original112. Remove: expect
material +1, attachment empty, fresh stock sight, same assignment/ammo/original112.
No repeat of accepted manual draw/holster/restart proof is required for this gate.

Only after successful remove, unequip135, prepare-stop PASS, disable transaction,
saved and GUID test gates while Weapons stopped, restore primary112. Retain returned
test sight until alpha flush; do not silently destroy inventory units. Unknown commit
or any refusal: inspect evidence, never auto-repeat payment or manually edit SQL.

## Automated evidence

Canonical intent + actual coordinator binding: feature/station/quantity veto before
release, final-wear reservation, no payment before release ack, duplicate release
doesn't pay twice, install/remove fresh rebuild, uncertain ack freezes/no retry.
Inventory unit body: consume/return1, before/after-only attachment delta, capacity,
CAS/authority/postequipment rollback. Export: exact original reservation throughout
same-transaction wear/rebased attachment, post-current rollback, exception propagation.
Read-only material/status tests. Mocks are not live SQL/native payment acceptance.
2026-10-14 LIVE native attachment transaction first READ-ONLY PREFLIGHT PASS: fresh epoch14859118:1, expectedprimary112rev1 only, disposable135rev2/attachmentsempty, materialQuantity0, noSQL/nativewrites. New service/shared/exportdeployment recognized. No attachment payment requested and no material grant performed. Next user normal ACE-restricted Dev AddItems carbine_wide_sight1 fromF8 (self, never serverconsole source0), readstatus toconfirmexactone; no repeatedgrants ifpermissionrefused/quantitynot1. Then equip135shoulder and configuredgunsmithstation install/payment test. Preserveflags current3enabled/fixturesoff. No furtherfiles/configreplacementrequired. Gate remainsLIVEpaymentpending; readonlystatusnottransactionacceptance.

2026-10-14 LIVE canonical attachment INSTALL PAYMENT gate PASS fixed135. ConditionalshoulderequipPASS; AttachmentChangeinstallSTARTED→InventorySQL COMMIT transaction716198e0-f042-4a23-a32f-2e1ff5e94fa4:3032/16queries→PASS metadataCAS/freshsamesessionrestore. Independentreadstatus material1→0;135rev2→3 savedcarbine_wide_sight/sight; assignmentprimary112rev1+shoulder135rev3 unchanged. Freshruntime15092075:3 ACTIVEidle/copies2/ledger33/all27ammo0.135entity3347972/capturedparentGUID80000000000000009db30382c25c0281; nativewideGUIDc25c030d equippedf10=1, stockc25c0286f10=0, visualwideSighttrue; allwear0. Original112rev1/entity3349764/wear0 intact. No manualprobe/fixturemetadataoperation. Next normal attachment REMOVE/returntransaction must restorematerial0→1,135rev3→4/pristinemetadataattachments empty/stocknative, sameequipment/ammo; keepconfiguredgunsmithstation/flags. Install accepted in pristine scopedcase only; changedwear/paymentrollback/funded/death/multiplayer remainautomated/unverified aspreviousnotes. No newserverfiles/flagsrequired, no repeatdraw/restartproof.

2026-10-14 LIVE canonical attachment REMOVE/RETURN PASS fixed135. InventorySQLCOMMIT716198e0-f042-4a23-a32f-2e1ff5e94fa4:3070/23queries→AttachmentChangePASS freshsamesessionrestore; readonlymaterial0→1,135rev3→4/attachmentsempty. Sameassignmentsprimary112rev1+shoulder135rev4, runtime15238210:4 ACTIVEidle/copies2/ledger33/all27ammo0.135entity3419396 capturedGUIDcurrent/readable/visualwideSightfalse, allwear0;112entity3426052/rev1/wear0 intact. No savedchildprobe needed for emptyattachmentstate. Combined pristine scoped installconsume1/remove return1/canonicalCAS/nativefreshrebuild gate ACCEPTED. This doesnot prove changedwearatomic enginegate/capacityorunknownfailure live/multiplayer/generalattachments. Next restoreprimaryonly viaunequipshoulderPASS→preparestopPASS→stopWeapons; disabletransaction/saved/GUIDflags while135unequipped;ensure primarybaseline. Retainone returnedtestmaterial untilalphaflush, nofixture/deletion/grants. Ifstopprints nativeInventoryguardteardownPASS recordnewliveevidence, not assumed. No newfilesdeploymentneeded.

2026-10-14 LIVE attachment payment gate BASELINE RESTORED. Epoch15600539:1 ACTIVEidle/nonquiescing/notreceiving/copies1, originalCattleman112revision1/all5wear0; ledger33/all27ammo0/no pending/closing/deathclosing. Userwasinstructedtransaction/saved/GUIDflags0beforeensure; no convarreadback supplied.135lastdurableconfirmedrev4/attachmentsempty/unequipped, one returnedtestSight retained. Scoped pristine native attachment canonical install/payment/remove/return/rebuild/basecleanup gate COMPLETE; no retest needed. Stoplognotincluded, so nativeInventoryguardteardown code remainsautomatedtested/notspecificlivePASSclaimed. Remaining: generalweapon/attachment support, normalplayerUI, changedwear+paymentliveatomicity/funded/death/concurrency/failuregates aspriorplan; accepted mechanism is notproduction-wide rollout. No currentserverfiles/flags/tests needed.

2026-10-14 fixture identity restrictions REMOVED from normal saved attachment/transaction paths, automatedPASS/live broaderidentitypending. Support now any owned canonical Carbine copy/positiveinstanceId/nonemptyserial/nonnegativeintegerrevision within configuredalphaCID and existing3optin/lifecyclegates; only provenCarbineWideSight model/nativeSlot mapping remainsallowed. Saved-mode GUID capture applies by trustedCarbinemodel, not135; unrelated weaponwithid135 unaffected. Client savedpreflight/factory and server assignedownedpreflight no longerrequire135/fixedserial; foreign ownership/fullrevision/serial/GUID/current/catalog checks remain. Manual rawnative probes intentionallyretainoldfixedfixture restriction and aredisabled in savedmode. ReadonlyAttachmentStatus nowrequires explicit <player> <owned-carbine-item-id>, not135implicit; validatesownedCarbine. ExistingInventorytransactionbodyalreadyinstance-independent, noInventoryruntimechange. ActualScoped/nativebuffer reconstruction + concretepaidtransition mocks changedtoID901/ordinaryserial; newidentityspecprovesCattleman135 unaffected/Carbine901captured/malformedIDserialrevision rejectedBEFOREgrant.112Lua+7Node PASS. Acceptedengine135proof not repeated; no newnativecomponent/modelbehaviorenabled. Files for NEXTdeployment only: Weapons shared/character_ammunition_materialization.lua, client/character_ammunition_creation_native.lua, server/services/native_equipment_transition.lua. No immediateflag/restart/servertestrequested; preservebaseline. Next normalplayerUI/intentintegration, otherweaponcomponents stillunproved/refused.

