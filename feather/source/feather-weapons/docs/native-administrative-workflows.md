# Native administrative workflows

LIVE Admin UI roundtrip accepted:135rev19/clear/same serial+wear/no reservation,
ledger hold10/release11 persisted; Admin audit queued both, SQLrelease:6857 COMMIT.
No durable Admin audit receipt inferred. Own-current Jane administrator scope,
no cross-owner/destruction/repeated storage. Set evidence optin0 to finish; no
new files. Earlier UI refusal cause not retrospectively established by success.

Admin UI now implemented, live pending: own Inventory instance→Weapon evidence
read-only preview→exact ticket/revision/session confirmation→existing authorized
transaction. Cross-owner/destruction still excluded. Runbook Admin
docs/evidence-inventory-ui.md lists6existing file/merge targets; no refresh or
Inventory restart. First optin0 inspect135 page, no action yet.126WeaponsLua and
Admin specs/syntax+7Node pass, no live menu rendering claim.

LIVE gate accepted: user confirms held135 storage movement refused. Release
SQL:5928/8queries COMMIT→rev17/event9/provenancePersistedtrue. Independent status
evidencefalse/reservationnone/unequipped/unbound/disabledfalse/serial+wear retained.
History reads release9/hold8 plus pickup7/deposit6. Final supplied optintrue;
set feather_native_evidence_transactions0 to finish. No further files/repeated
hold/move/release required. Scope is current administrator's own unequipped item,
not Admin UI/cross-owner police custody/destruction or live failure/outbox proof.

LIVE HOLD accepted: Jane administrator5/currenta45c3a4d bothpermissions true,
135rev15→16, SQL:5897/8queries, evidence_hold event8/provenancePersistedtrue.
Independent status evidencetrue/reservationnone/unequipped/unbound/same serial,
dirt~0.2 otherwear0. Next storage attempt must refuse; release/readback/ledger
and optin0 pending. No new files or destructive test.

Current policy supersedes owner-only staging: user approved administrator minimum
for hold/release, owner inherits, moderator denied. Admin catalog90/grants190,
receipt version005; no person promoted/destruction grant. Jane rejoined serverID5.
Deploy Admin authority_catalog/policy_provider and merge2administrator permission
entries, retain prior90-action authority_contract. RestartAdmin only/no refresh,
evidence0, WeaponNativeEvidenceStatus5 135. Live permission proof pending.

Post-Admin status still denies both permissions; optin0 and135rev15 unchanged.
Admin startup90/188/role parity not supplied. First inspect existing read-only
AdminAuthorityRoleParitySmokeTest and AdminReleaseContractSmokeTest plus catalog
restart line. Do not assign owner merely to pass. Optional staged Weapons
evidence.lua diagnostic adds bounded permissionDetails action/code/provider/reason;
126Lua pass. No immediate file deployment requested until existing diagnostics
reviewed; root cause is not established by booleans alone.

Live preflight source4/135rev15: correct serial/evidencefalse/disabledfalse,
unequipped/unbound/reservationnone/dirt~0.2, optinfalse, permissions holdfalse/
releasefalse. No mutation. Local Admin has no weapons.evidence.hold/release
permissions/catalog mappings; provider unknown_action denies unmapped actions.
Exact live denial code not returned by this status. Keep optin0. Policy mapping
and role choice require user approval; do not grant or bypass permissions merely
to execute gate. No files to move until approved integration prepared.

## Current deployment gate — 2026-10-15

Read-only permission/reservation preflight and console-only normal-authority
Hold/Release commands are implemented; defaultoff and live pending.

Move Weapons existing files:

- server/services/evidence.lua
- server/services/ownership.lua
- server/services/api.lua

Move Inventory new file:

- server/services/native_evidence_commit.lua

PrepareStop CURRENT_ID→wait PASS→stop Weapons, then copy files. Run server-console
refresh (new Inventory service-glob script), restart Inventory, restore Admin/Shops
if stopped, set feather_native_evidence_transactions0 and ensure Weapons. Preserve
all configs and existing flags. No UI/manifest edit or new fixture/grant/deletion.

First read-only server-console command:

```text
WeaponNativeEvidenceStatus CURRENT_ID 135
```

Review actual serial/revision/evidence flag/unequipped+unbound/reservationnone and
hold+release permissions. New optin enabled=false expected. Preflight calls Core
permission checks (may produce normal audit activity), never item/ammo/material
writes or reservations. Existing Carbine135 owns storage roundtrip revisions;
actual status is authoritative. Do not change permissions or enable mutations
blindly if either permissionfalse. Tests use mocked authority, not live policy.

Only after successful reviewed preflight, focused gate (not yet executed): set
feather_native_evidence_transactions1; WeaponNativeEvidenceChange CURRENT_ID hold
135 EXACT_SERIAL. Read status verifies one revision increase/evidencetrue, same
wear/identity, no materials/ammo. Attempt existing storage move must refuse.
Then WeaponNativeEvidenceChange CURRENT_ID release135 EXACT_SERIAL, confirm another
revision/evidencefalse and ledger hold/release facts, return optin0. No equip or
destruction test. Console command requires normal current actor Core permission;
no bypass for console or legacy authorization.enabledfalse. Target currently
limited to the configured actor's own unequipped native firearm, not police
cross-owner custody. Unknown result/reservationunresolved: inspect, do not retry
or restart merely to clear the safety hold. Confirmed mutation with
provenancePersistedfalse is not a retryable mutation failure.

126 Weapons Lua specs/7Node/fullInventory suite pass. Status-with-optinoff and
unresolved readback, player console refusal and existing authority/rollback tests
are automated only. New status/command live acceptance pending.

2026-10-15 native binding/export connected, defaultoff/live pending. Optin
feather_native_evidence_transactions1 plus full scoped native flags permits
trusted Hold/Release on current configured actor's own exact item/serial/session.
Per-item private reservation binds ticket/context/full spec; Inventory-only
validator rechecks Core affirmative hold/release action permission, current actor,
exact reservation and no native lease at each transaction boundary. Native Core
authorization is mandatory regardless legacy authorization.enabled. Existing
SetMetadata guards/locked equipment/CAS body remain authoritative. Not cross-owner
police custody support; no equipped release/rebuild required because target must
be unequipped/non-native-bound.

After dispatch, unknown/refused acknowledgements remain unresolved/blocked rather
than automatically retrying. Confirmed item mutation remains success if subsequent
provenance insert fails, with provenancePersistedfalse; caller must not repeat
mutation to obtain a ledger event. No new atomic outbox guarantee. Destruction
stays disabled.126WeaponsLua/7Node/fullInventory pass with mocks; no live evidence
change or SQL/authorization acceptance yet. Next read-only permission/reservation
diagnostics, then focused test gate. Deployment still held: Weapons evidence.lua,
ownership.lua,api.lua and Inventory native_evidence_commit.lua (new service requires
refresh). No config/UI edits or live deletion.

2026-10-15 internal evidence body implemented in Inventory
server/services/native_evidence_commit.lua, no export/route. Exact reservation,
locked owner/equipment/item, serial/revision/full snapshot, flags.evidence-only,
guard/CAS/current and postequipment rechecks. Full Inventory suite passes with
mock rollback/hold/release/authority tests. Actor authorization/reservation/export
binding still pending; do not enable live mutation. New service-glob script needs
refresh on eventual deployment; no immediate server copy requested.

2026-10-15 safety boundary implemented, native mutations remain unsupported.
Trusted evidence hold/release and destruction validate caller/request first, then
return explicit OPERATION_CONFLICT/native_*_not_implemented when either native
cutover flag is active. No legacy provider access, authorization export, mutation,
deletion or provenance write; no automatic retry. Existing administrative movement
guards remain active. Legacy dispatch remains when both cutover flags are false.

125Lua specs/7Node tests pass. New regression covers partial/native flags, untrusted
caller, invalid IDs, context preservation, no external side effects, legacy path
dispatch and truthful native capabilities. No live mutation/deletion acceptance.

Staged Weapons files (no immediate server deployment required):

- server/services/evidence.lua
- server/services/ownership.lua
- server/services/api.lua

Existing files/no refresh/config/Inventory/UI change. Next: native unequipped
evidence hold/release with current actor authorization, exact owner/item/serial,
locked revision CAS and native hold/equipped guards. Terminal destruction is a
separate transaction/authorization boundary. Never delete a live item as an
implicit test; any destructive live gate needs explicit target authorization.
