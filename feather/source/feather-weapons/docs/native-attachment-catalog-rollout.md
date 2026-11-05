# Controlled catalog attachment rollout

Complete-set policy hardening: shared ValidateSet now checks bounded canonical
arrays, all catalog compatibility, distinct slots/IDs, conflicts in either
installed definition and prerequisites across the resulting full set. Planner
checks proposed after-set (including dependency-breaking removal); saved projection
checks installed set independently. Tests exercise missing prerequisites,
prerequisite installation/removal order, reverse conflicts and projection refusal.
Shipped dependency arrays remain empty, so no accepted catalog behavior changed.
Menu enumerates sorted attachment IDs for stable options.119Lua/7Node pass.
No new live test/flags required, no accepted gate reopened. Next accumulated
deployment Weapons4existing files: shared/definitions/attachments.lua,
shared/character_attachments.lua,shared/character_ammunition_materialization.lua,
server/services/native_equipment_transition.lua. No Inventory/UI/config/manifest
delta. Keep catalog rollout flag0 until deliberate enrollment; no restart needed now.

Rollout hardening: identical-model customized sidearm pairs now explicitly refuse
in shared materialization Validate before native factory. Previously the pair
factory refused nonempty customization later, but a server attachment intent could
pass proposed-loadout validation and reach release/payment first. Equipment preview
suppresses attachment actions only for the selected member of such a pair, not
unrelated longguns. Concrete server intent test verifies zero release; client
preflight refuses same-model customization while ordinary same-model pair stays
valid. All119 Lua/7Node tests pass. No live payment/rebuild failure was reported for
this case; prevention is based on actual preflight/factory contract mismatch.
Additional staged existing Weapons server/services/native_equipment_transition.lua
joins2shared rollout files. No new runtime files/config/Inventory changes or live
repeat requested. Same-model attachment reconstruction remains unsupported, not
silently healed/dropped; completing it is separate native GUID-pair work.

Implemented/off by default. Existing scoped Dev/native alpha CID and saved/GUID/
transaction gates remain. New replicated feather_native_catalog_attachments=1
admits36 observed combinations across23 models using shared canonical planning,
projection, native GUID factory/dynamic stock, exact sealed payment policy and
cleanup. Compatibility comes from accepted38-pair scan; implementation evidence
reuses accepted Carbine+Schofield representative gates, not36 new live cycles.
Do not call all36 individually engine-tested. Mapping result separately reports
catalogRollout vs reconstructionProved; old representative gate remains compatible.

Excluded: LeMat2 variants (existing dual-ammo item policy).
Sawedoff mismatch fixed using existing catalog/server sidearm policy: exact
shotgun_sawedoff/WEAPON_SHOTGUN_SAWEDOFF shotgun-family client exception allows
primary/offhand, not other shotguns. Wrong shoulder/back/offhandwithoutprimary
and LeMat still refuse. Shotgun ammo unchanged; no new live acceptance claimed.
No utility/bow/throwable enrollment or identical-model customized pairs enabled.

Trusted expected component/item/semantic-slot fields are snapshotted alongside
observed native slots. Weapon native names checked explicitly including Lancaster
Winchester and sniper-rifle exceptions, not a universal guessed rename. Unknown
or mutated component/model/item/slot rejects even with rollout flag. CaptureModel
only expands when gate+scope config valid; no LeMat adoption. Commit guard
rechecks Resolve, so gate loss blocks writes. Do not disable while unsupported
saved components are still installed; remove them through normal transactions
first or preserve gate for reconstruction. Never manually erase saved metadata.

All118 Lua/7Node pass. Actual Scoped/native-buffer factory harness now loops36
rollout combinations (all mocked engine native calls), exact stock preservation,
child flags, cleanup and disabled saved-attachment gate; original reservation and
economic rollback coverage reused. Full catalog planning tests remain separate.
No additional live matrix required by this checkpoint; broader funded/race/crash
coverage is still not accepted. Last live baseline primary-only epoch13861750:1,
ledger33/allammo0 retained, Schofield134rev4 empty/materials returned1each.

Next deployment delta Weapons ONLY shared/definitions/attachments.lua and
shared/character_ammunition_materialization.lua, existing files/no manifest/config
replacement. No Inventory/UI/native-factory runtime delta.
No immediate restart or flag change requested; keep catalog flag0 until deliberately
running controlled rollout. Preserve existing representative flag0 and other test
gates0 at current baseline. Next buildout addresses remaining explicit gaps
rather than reopening completed attachment gates.
