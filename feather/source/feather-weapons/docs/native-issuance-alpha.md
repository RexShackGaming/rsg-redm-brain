# Native firearm issuance — controlled alpha

Checkpoint review finding (2026-10-17): legacy/native issuance use separate
receipt stores; same trusted resource/requestId after switching modes can
duplicate delivery. Native-only replay gates below remain accepted, but shared
durable cross-mode key fencing is required before general cutover. Do not
switch modes or reuse keys as a workaround; see authoritative framework
Weapons CHECKPOINT_2026-10-17.md. No live cross-mode grant test is authorized.

Implemented and automatically tested 2026-10-17; live acceptance PENDING.
Live read-only readiness accepted: available=true, pristineOnly=true,
stableRequestIdRequired=true, noGrants=true with opt-in1. No firearm has been
issued at readiness time. Subsequent first delivery accepted: request
native-issue-alpha-v1 to John2 returned158rev0, serialFW-REVO-6AD42303-341ED0-0001,
provenance14/replayedfalse after Inventory transaction :1744 COMMIT18queries.
Pristine native character-owned ammo metadata confirmed. Exact-key replay also
accepted: replayedtrue/same158rev0/same serial/event14/original createdAt.
Independent history accepted: current158/events1/issuance14; expected separate
runtime balances confirmed Jane ledger35/repeater1/two copies and John
ledger2/revolver1/one copy. No fresh deployment-epoch pre-issuance snapshots
supplied; exact epoch invariance not claimed. Opt-in cleared0. New158 native
materialization now accepted: John reports only158rev0/all five wear0 at
epoch8752158:4. Reconnect accepted: John source3/new sessionb133ab17-ca95-11f1-9ad4-
e0d55eaa2deb/epoch8924074:5 restores158rev0/all wear0/one copy/ledger2/revolver1.
Jane observer unchanged exact session/epoch8281267:1/two copies/ledger35/repeater1.
Scoped pristine issuance gate complete; no same-model pair or firing claimed.
Further replay after requested restart sequence returned same158rev0/serial/
event14/replayedtrue. Operator subsequently confirmed Weapons stop/ensure
preceded this replay; restart-durable replay is accepted (orderly resource
restart, not abrupt process crash).
Issuance was enabled1 for this replay; clearing it back to0 remains pending.

## Contract and boundaries

Live ownership-change replay:158 given from John inventory5 to Jane inventory2;
original John request replay returns same158/event14/original inventory5/rev0
with replayedtrue. Historical receipt is not current ownership or maintenance.
Opt-in cleared0. Post-replay history accepted: events14 issuance/15 transfer
only, current158 true/destroyedfalse; John ACTIVE idle0copies/ledger3/all pools0
at epoch10439638:6. No duplicate event/native recreation/ammo observed; full SQL
inventory count audit not supplied. Return cleanup accepted: John ACTIVE idle
one copy/158rev3/prior soot0.005/degradation0.00333333341404/other wear0,
ledger3/all pools0 at epoch10696007:7. Historical-replay gate complete.

Live changed-definition request test: Schofield with retained Cattleman key
native-issue-alpha-v1 refused native_issuance_refused (combined receipt-conflict/
authority-changed message); opt-in cleared0. Refusal observed; exact rejecting
branch/full inventory no-write audit not independently supplied.

The existing IssueWeapon export and IssuanceService authorization retain trusted
resource/purpose and optional Core action checks. Native mode now selects a
narrow receipt-backed Inventory path, never the legacy mutation/usable provider.
Admin roles and permissions are unchanged (weapons.issue remains its existing
owner-tier action). Administrator Jane need not receive that permission to run
the server-console acceptance gate. No Admin files changed.

Native issuance is default-off via server convar feather_native_issuance=0.
It additionally requires the existing explicit native/DevMode/transport flags,
ready Inventory/provider/provenance contract, stopped proof resource, an admitted
firearm definition and one current active enrolled target session. Offline,
unsettled, un-enrolled, ambiguous and shutdown-latched targets refuse. Missing
Inventory contract/export never enables the legacy provider as fallback.

Every native purpose requires a stable requestId. Initial scope: pristine
condition100/quality100 firearm, no attachments/cosmetics/item-ammo quantities,
no equip, carried-ammo, material or automatic enrollment. Metadata has only
ammo ownership=character and its preferred type. Original supplied provenance
type/reference are normalized and bound; requestId becomes the canonical
provenance reference and the supplied reference is retained as sourceReference.
Payload identities exceeding the existing 300-byte receipt bound refuse.

Inventory accepts only feather-weapons plus a private current exact issuance
ticket callback (context/spec/metadata bound). Within one transaction it locks
a resource/request receipt, verifies payload identity, resolves the target
inventory and existing ammunition enrollment, validates the active unique item
definition, creates one instance through normal capacity checks, and completes
the receipt. Current authority is rechecked before commit. Replays return the
historical item/serial/metadata, not a replacement—even after later transfer,
consumption/destruction. Receipt replay does not prove the item still exists.
No cancellation/refund or regrant on unknown outcome is provided.

Provenance recording follows confirmed delivery, not the same SQL transaction.
Missing provenance is recoverable with the SAME requestId; failure explicitly
reports committed delivery/incomplete provenance. Event lookup failure cannot
be treated as absence. Concurrent same-key requests in this Weapons lifetime
refuse while the first is pending. Atomic durable receipt prevents duplicate
delivery across restarts/lost replies. Actual in-flight server crash remains
unproven; do not invent SQL outcomes or change requestId after uncertainty.

## Runtime deployment delta

Weapons existing files:
- server/services/issuance.lua
- server/services/api.lua

Inventory existing files:
- server/services/grants_once.lua
- server/services/api.lua

No manifest/new runtime script, refresh, web rebuild or config replacement.
Keep all prior controlled-enrollment settings and current gameplay balances.
Tests/documentation are not deployment files.

Use aggregate WeaponNativePrepareStopAll and wait for 2/2 PASS/ready before
stopping Weapons. Copy both resources' files, restart Inventory and affected
dependents, then ensure Weapons. Both owners must restore ACTIVE/idle.

Read-only readiness gate, server console:

```text
set feather_native_issuance 1
WeaponNativeIssuanceStatus
```

Expected available=true/pristineOnly=true/stableRequestIdRequired=true/noGrants=true.
Stop here for the initial deployment report; this does not create anything.

## Proposed one-firearm acceptance (not executed/accepted)

When an additional disposable issuance is authorized, choose the current enrolled
target ID and one retained requestId; do not guess a source after reconnect.

```text
WeaponNativeIssue CURRENT_ID revolver_cattleman native-issue-alpha-v1
```

Capture item/serial/provenance event and both ammo statuses; leave item unequipped.
Repeat the EXACT same command/key: expect replayed=true and identical item/serial,
not another item or event. Inspect WeaponProvenanceInspect with the returned ID.
Do not fire/grant ammunition or alter existing155/112/134. Clear the convar after
the focused gate. Unknown/refused results require inspection, not a new key.
Native materialization/reconnect for a newly issued item are later acceptance
steps, distinct from readiness and durable delivery replay.

Automated tests cover real metadata contract, scope/trust/gate/latch refusal,
exact callback ticket, changed payload, lost-reply replay and provenance recovery;
Inventory body tests cover atomic receipt/item, historical replay, capacity,
enrollment/current-authority and completion rollback with unchanged ammo/equipment.
SQL/native boundaries remain mocked. Broader non-firearm, worn/customized issuance,
shop payment/crafting integration and Admin menu work remain separate.
