# Batched native attachment slot discovery

General Inventory mutation validation connected locally: Weapons reserves a
server-derived attachmentPolicy (definition/slot/material name/weapon definition
and item name) inside the original sealed spec. Inventory's current callback
continues verifying that exact original reservation, including during wear rebase.
Transaction body validates bounded dense unique canonical attachment arrays,
exact selected-slot add/remove, unrelated slot preservation, exact nonattachment
metadata, correct material quantity1/direction/DB identity and owned weapon item.
Legacy no-policy specs retain narrow Carbine-only fallback; this is not a generic
unvalidated caller override. Slot-specific metadata still CASes in same transaction
as wear/payment. No native-admission changes or new player feature flag.
Inventory full Lua runner and117 Weapons Lua specs pass. Generic representative
Schofield barrel+sight cases cover install/remove, unrelated edits/removal, wrong
material/weapon policy, duplicate slots, CAS rollback/capacity refusal. New staged
Inventory file server/services/native_attachment_commit.lua joins prior selection
files; Weapons existing server/services/native_equipment_transition.lua updated.
No immediate deployment/live repeat requested; remaining native enrollment still
separate from pure/general transaction policy.

Selection plumbing generalized locally: Equipment preview enumerates trusted
catalog definitions through production Plan admission, includes attachmentId and
catalog label; clicked ID travels App→Inventory NUI→Weapons Inventory-only export→
bounded server intent→canonical definition/material lookup. UI keys distinguish
components/actions; explanatory text is attachment-neutral. Optional ID omission
retains accepted Carbine console/backward compatibility. IDs bounded before any
recursive copy/yield; prices/hashes/cost/metadata never supplied by UI. Inventory
read-only material reader accepts server-selected itemName via parameterized SQL;
payment transaction body still narrow and exact. No new mapping enabled.
All117 Weapons Lua, Inventory Lua runner,2UI lifetime tests, UI ESLint/Vite build
pass. Existing7 Weapons Node result unchanged. Not broader transaction enrollment
or live UI acceptance for new components. New staged delta: Weapons
client/native_equipment_actions.lua + server/services/native_equipment_transition.lua;
Inventory client/services/nuicallbacks.lua + server/services/native_equipment_commit.lua
and rebuilt ui/. No immediate deployment/config/flags/test request; next generalized
transaction-delta validator must preserve unrelated slots and released authority.

Canonical catalog planning/projection generalized locally. Pure PlanCatalog and
BuildCatalog support up to4 distinct slots, bounded dense canonical arrays,
private metadata/projection, deterministic slot ordering; adding/removing one slot
preserves unrelated attachments. Native instructions in saved metadata, duplicate
slots, incompatible weapon/component and sparse/excess arrays refuse. Production
Plan/Build wrappers independently require registry reconstruction approval and
remain Carbine-only. Catalog plans are not payment/reconstruction permission.
No RPC/export/feature switch exposes catalog-only admission to players.

New pure regression covers38 catalog projections and36 install/remove pairs;
LeMat's2 variants retain preexisting unsupported dual-ammo item policy. A
representative Schofield sight+barrel proves slot-preserving removal and private
native descriptor generation without38 live cycles. Full117 Lua and7 Node tests
pass (Node unchanged from this step's earlier run). No broad native engine or
economic acceptance inferred. No new files/manifest/config/Inventory runtime.
Existing shared character_attachments.lua/materialization.lua staged with mapping
and factory updates; no immediate deployment/live gate requested.

Native factory genericization implemented locally: saved reconstruction passes
private validated component descriptor (component hash/slot/optional known stock)
through factory; native child probes indexed per record AND native slot. Removal
checks every retained child; diagnostics report per-slot children while retaining
single-child compatibility output. The old manual Carbine probe keeps its fixed
descriptor and restrictions. No new mapping admission/payment path enabled.

When no stock component name is supplied, factory requires fresh slot count1,
reads its candidate item hash/GUID, independently verifies exact inventory child
hash/GUID/equipped f10 and unchanged parent/count, rejects desired-component-as-
stock, then preserves actual stock identity. Does not derive stock names by string
replacement or trust stale slot query after modifications. Actual Scoped/native-
buffer reconstruction test now runs a dynamic-stock case without a stock name,
including child equip/stock restoration/exact cleanup. Full116Lua/7Node pass.
Production Carbine mapping still uses accepted explicit stock name; dynamic-stock
native path awaits representative runtime enrollment, not38 repeated tests.
No immediate deployment/live action. Current staged change extends existing
client/character_ammunition_creation_native.lua; preserve prior five-file batch.

Shared reconstruction lifecycle extended locally (no new mappings enabled):
up to4 validated distinct semantic/native slots, all validated before first
mutation; private per-component ownership records; reverse creation-order cleanup.
Failure on second install retains both first and partial second; unknown second
factory retains whole reservation; cleanup failure blocks weapon removal. Actual
saved factory now validates component through shared reconstruction-admitted
registry. Representative mocked sidearm/longgun + sight/barrel tests pass along
with full116 Lua/7Node suite. These do not establish native stock-child hashes or
general multi-attachment projection/payment, which remain narrow. Production
projection/registry still only admit accepted Carbine sight, so no new live gate
or repeated old evidence required. Next batch adds existing client files
character_maintenance_native.lua and character_ammunition_creation_native.lua to
the3shared mapping files listed below. No deployment requested yet.

Shared mapping enrollment implemented: all38 observed pairs/signed native slots
are retained in private WeaponNativeAttachmentMappings registry within existing
shared/definitions/attachments.lua. Resolve validates weapon/catalog-slot pairing,
returns private data and distinguishes discovery from reconstruction admission.
Canonical attachment intent and native saved projection now consult the same
registry for accepted Carbine support. No other mapping admitted for mutation yet.
All115 Lua/7Node tests pass, including every observed pair and exactly one proved
reconstruction entry. No new script/manifest/config change. Next batched deployment
delta (not needed now): shared/definitions/attachments.lua,
shared/character_attachments.lua, shared/character_ammunition_materialization.lua.

Evidence reuse strategy: original catalog/visual/attachment acceptance is retained,
not restarted. The38-row native compatibility scan is also complete. New checks
focus on new exact-child stock preservation/reconstruction differences: sidearm vs
longgun and barrel vs sight, plus shared failure/identity guards. The completed
Carbine economic/lifecycle matrix is reused. Do not schedule38 install/remove
roundtrips or treat legacy entity-only success as inventory-GUID cleanup evidence.
The old master describes Long Barrel phase intent; it is not by itself proof of
all native child paths. Additional recovered reports should be recorded at their
actual scope, not silently inferred or used to reopen accepted work.

LIVE catalog scan received: all38 catalog combinations returned exactly one
compatible native slot; no errors/ambiguity, noNativeWrites/noSQLWrites/noAmmoWrites
true. Full source: user attachment860b6f48-9ffa-4e58-bd3f-ab29d53263b5/Pasted text.txt.
Examples: accepted CarbineWideSight468034421/category2731268404 unchanged;
SchofieldWideSight1880805647 and ShortBarrel1985390213/category3098158289;
CattlemanWideSight361381308 and LongBarrel1024262875/category848810968.
Negative slot values elsewhere are signed native hashes, not missing mappings.
This accepts batch compatibility discovery ONLY; no new attachment creation,
stock-child hash, GUID stability, payment or reconstruction accepted. Existing
unproved combinations remain blocked. Next candidate Schofield134 wide sight,
using already-owned disposable item rather than original112. Need read-only exact
stock-child identification before adding its mapping to mutation paths; do not
guess narrow component names or grant items/equip yet. No files/flags needed now.

Implemented and automatically tested; engine catalog output pending.
F8 `weaponNativeComponentSlotStatus catalog` resolves model/component names only
from existing trusted weapon attachment-slot definitions. Sorted batch capped64;
each component's category/slot enumeration retains32-slot limit. Results identify
weapon/attachment/semantic slot, native category, compatible slot list and whether
exactly one compatible slot exists. Unsupported reads are isolated per entry;
ambiguous compatibility never chooses a slot. No-argument Carbine diagnostic is
unchanged. No arbitrary hash/model/slot arguments accepted. DevMode/native-alpha
gates apply; no new flags or item/equipment/session prerequisites.

The native operations are read-only category/count/slot/compatibility queries.
No weapon creation/equip, native child insert/remove, SQL, ammo/material writes,
runtime mapping admission or payment route changes. Compatibility discovery alone
does not prove stock-child identity, GUID stability, reconstruction or cleanup.
Unproved combinations stay refused. Existing Carbine live gates remain accepted.

Full114 Lua specs and7 Node tests pass. New regression covers trusted catalog
names, deterministic order, batch bound, per-entry unavailable/ambiguous results,
actual startup command with read-only native mock, invalid args and dev-off veto.

Deployment batch Weapons ONLY existing files:
- client/character_maintenance_native.lua (catalog discovery)
- client/character_ammunition_startup.lua (command + prior helper removal)
- client/character_ammunition_native_owner.lua (prior helper removal)
- server/services/native_equipment_transition.lua (prior refusal diagnostics)

No manifest/new runtime script/config/Inventory changes. PrepareStop current ID,
wait PASS, stop Weapons, copy four files, ensure Weapons. All temporary attachment
flags stay0; no restart Core/Character/Inventory/Medical. Run F8 catalog command
once and send full output (paste file if large). Keep primary-only baseline.
Next select next model/component from returned unique mappings; no guessed native
slot/stock component and no broad attachment enablement inferred.
