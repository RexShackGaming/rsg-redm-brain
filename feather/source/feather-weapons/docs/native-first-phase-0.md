# Native-first Phase 0 inventory

Status: captured before the production runtime rewrite.

## Reusable server surface

- Core Contract 1 session validation and UUID character identity
- Inventory Contract 2 transactions, equipment persistence, movement guards,
  exact item instances, metadata revisions, and usable-item integration
- Definition validation for weapons, ammunition, condition, and attachments
- Unique issuance, serial generation, repair, attachment, reconciliation, and
  Admin-facing contracts
- Structured result envelopes, correlation IDs, capability gates, and smoke
  test patterns

## Production client surface to replace

| Existing behavior | Current location | Native-first disposition |
| --- | --- | --- |
| Disable and read reload control `0xE30CD707` | `client/main.lua` reload loop | Delete |
| Carry/pickup proximity suppression | `client/main.lua` carry helpers | Delete |
| Reload RPC initiated from physical `R` input | `BeginReload` | Delete |
| Manual `TASK_RELOAD_WEAPON` call | `BeginReload` | Delete |
| Inventory-to-loaded-round transaction | `server/services/ammo.lua` | Replace with escrow transaction |
| Loaded-only client checkpoint | firing observer and `ammo:sync` | Replace with lease-bound loaded/total observation |
| Repeated ammo target adjustment | `SetNativeAmmo` | Replace with idempotent reconciliation |
| Weapon removal and global native ammo reset | cleanup helpers | Retest and narrow by verified native behavior |
| Attachment application | attachment helpers | Retain behind approved lease |

## Current client state to retire

- `reloadInFlight`, `reloadQueued`, and `reloadInputArmed`
- carry/drop interaction inference
- `desiredAmmo` as a loaded-only authority mirror
- reload and unload operations queued behind shot synchronization
- attachment timing retries as an implicit correctness condition

## Native calls requiring Phase 1 evidence

| Native | Purpose under test |
| --- | --- |
| `GiveWeaponToPed` / `RemoveWeaponFromPed` | Idempotent representation boundaries |
| `SetPedAmmoByType` / `GetPedAmmoByType` | Native ammo-type total and reserve behavior |
| `SetAmmoInClip` / `GetAmmoInClip` | Loaded-round behavior |
| `GetAmmoInPedWeapon` | Per-weapon total behavior |
| `GetCurrentPedWeapon` | Selection transitions for the primary hand attach point |
| `IsPedReloading` / `IsPedShooting` | Observation only, never input authority |

## Isolated Phase 1 probe

The probe is loaded from `client/native_probe.lua` but runs only when both
`Config.DevMode` and `Config.NativeProbe.enabled` are `true`. It refuses to
prepare or clear native state while an Inventory-authorized weapon is equipped.
It does not call the server, mutate Inventory, intercept controls, or start a
reload task.

Available F8 commands:

```text
WeaponNativeProbePrepare [loaded] [total] [logicalItem]
WeaponNativeProbeStatus [label]
WeaponNativeProbeWatch
WeaponNativeProbeHolsterPrepare [attachPoint] [weaponName]
WeaponNativeProbeHolsterStatus
WeaponNativeProbeMark <name>
WeaponNativeProbeCompare <first> <second>
WeaponNativeProbeClear
```

The holster probe grants the configured primary test weapon at its normal
attachment point and grants `WEAPON_PISTOL_M1899` at the requested point
(default `3`). It then holsters both and reports every occupied native attachment
point from `0` through `15`. Use `WeaponNativeProbeClear` between candidates.

`loaded` is the requested clip count and `total` is the requested native total.
Use `logicalItem` (for example, `cattleman-a` and `cattleman-b`) to label repeated
remove/grant sequences when testing two persistent instances that share the same
native weapon and ammunition type. The watch command logs only observed state
transitions.

### First runtime finding

On the tested RedM runtime, boolean native results are exposed as numeric `1`
and `0`. Setting the ammo-type total before `SetAmmoInClip` caused the requested
clip to be added to the total (`2` loaded plus requested total `12` observed as
`14`). The probe therefore sets the clip first and the total second. Production
ammo code remains unchanged until the corrected sequence is tested.

The corrected sequence was then verified with a Cattleman request of `2` loaded
and `12` total. The selected weapon matched the expected hash, `GetAmmoInClip`
reported `2`, and both `GetAmmoInPedWeapon` and `GetPedAmmoByType` reported
`12`. This establishes a deterministic initial loaded/total snapshot for the
partial-reload tests.

The standing third-person partial reload also passed. RedM advanced the loaded
count one chamber at a time from `2` through `6`, while weapon and ammo-type
totals remained exactly `12`. No Feather reload command or task was involved.
`IsPedReloading` remained false throughout the observed revolver reload, so the
native loaded/total transitions are the useful evidence; the reload flag cannot
be required for correctness.

Two standing third-person shots were observed next. The first changed loaded
and total from `6/12` to `5/11`; the second changed them to `4/10`. Both
`GetAmmoInPedWeapon` and `GetPedAmmoByType` agreed after each shot. This supports
using native count transitions as bounded consumption observations without a
keypress or per-shot server authority claim.

The full reload/fire/carry sequence was repeated from a clean probe state.
Native reload and two shots reproduced the same counts. On body pickup, RedM
selected the unarmed hash and changed carrying to true without changing the
`4/10` ammunition state. Dropping the body changed carrying back to false and
then redistributed the weapon to `6` loaded while total remained `10`; the
weapon was still not selected. Reload, pickup, and drop presentation all worked
normally. The future observer must therefore allow native loaded/reserve
redistribution even while a weapon is holstered, but must still reject any
increase in the approved total.

Locomotion and camera-context tests also passed without Feather owning the
reload input. While walking, the revolver reloaded from `2/12` through `6/12`
one chamber at a time and the following shot produced `5/11`. The walking and
reload states were both visible in the probe, and the animation behaved
normally.

The cover scenario reproduced the same `2/12` to `6/12` reload and `5/11`
shot result. The probe observed entry into cover, although the player left the
cover state during the reload and firing transitions. Presentation remained
normal, so this verifies the native interaction path but does not yet prove a
reload performed continuously while attached to cover.

The mounted scenario passed with stronger state evidence. After mounting and
drawing the weapon, every reload transition from `2/12` through `6/12` retained
`mounted=true`; the subsequent shot retained the mounted state and produced
`5/11`. Both animations behaved normally.

The first-person scenario followed the sequence fire, reload, fire. Counts
changed from `2/12` to `1/11`, reloaded chamber-by-chamber to `6/11`, then
changed to `5/10` on the second shot. Aiming, firing, and reload presentation
were visually confirmed as normal. `IsFirstPersonAimCamActive` remained false
in the sampled output, so that native is not accepted as proof of perspective;
the ammunition transitions and visual confirmation are the evidence for this
case.

The death/admin-revive lifecycle preserved the same ped, selected weapon, and
exact `2/12` ammunition snapshot. The death transition changed only the
observed dead state; the revived comparison reported no ped change and zero
loaded, weapon-total, or ammo-type-total difference. Drawing, firing, and
native reloading after revive all behaved normally. Subsequent shots continued
to reduce both totals by one and reload continued to redistribute only the
remaining total. This proves that the tested admin-revive path does not itself
require a second weapon state machine or a timed ammunition repair.

Character logout and reselect established a hard ped-replacement boundary. The
prepared snapshot was `2/12`; after reselect the ped handle had changed and the
current Weapons lifecycle had reduced loaded, weapon-total, and ammo-type-total
to zero. The weapon hash was selected but could not fire because it had no
ammunition. This probe weapon intentionally had no persisted Inventory lease,
so losing its state is expected. Production reconciliation must treat Character
activation as a fresh native grant: clear stale state idempotently, wait for the
new active ped and approved Inventory snapshot, then restore the authorized
weapon and ammunition exactly once. It must not rely on native ped state
surviving character selection.

Two consecutive `feather-weapons` restarts also passed the isolated cleanup
boundary. Before the first restart the probe held `2/12`. After both restarts,
the selected hash was unarmed, the clip query was unavailable, and loaded,
weapon-total, and ammo-type-total were all zero. Both restarts completed without
usable-item registration conflicts or client/server errors. Cleanup is therefore
idempotent for the probe state; the production path may rebuild only from a
fresh, approved Inventory lease after restart.

The first logical A/B isolation run exposed a cleanup failure rather than an
isolation pass. After a prior total of `10`, prepare requests for totals `7` and
`9` both remained at `10`. `SetPedAmmoByType(..., 0)` did not lower the existing
pool. The probe next used the verified `_REMOVE_ALL_PED_AMMO` boundary before
granting the next logical item and explicitly reports setup `PASS` or `FAIL`.
That reset is deliberately broad and remains development-only; production must
not adopt it until the supported isolation policy is decided.

With that broad reset, the logical A/B/A sequence passed: `1/7`, `5/9`, and
`1/7` were each prepared exactly, and the first and restored A snapshots had
zero difference. This proves deterministic restoration is possible, but not yet
that unrelated ammunition can be preserved. The probe now tests
`_REMOVE_AMMO_FROM_PED_BY_TYPE` with an amount of `-1` at the same boundary. A
second A/B/A pass will establish whether revolver ammunition can be isolated
without clearing every native ammunition type.

That first type-scoped attempt failed on the downward B-to-A transition. A
request for restored A at `1/7` observed `1/9`, leaking two rounds from B. The
attempt had removed the weapon before removing ammo by type and used `-1` as
the amount. The next probe removes the currently observed ammo-type quantity
with the weapon still present, then removes the weapon. This ordering must pass
before type-scoped cleanup is accepted.

The reordered type-scoped cleanup passed. For A at `1/7`, B at `5/9`, and
restored A at `1/7`, the observed ammo-type quantity reached zero before each
weapon removal, every preparation reported `PASS`, and restored A differed by
zero loaded and total rounds. This is the first cleanup sequence suitable for
the production isolation design: remove the observed approved ammo-type amount
while the old weapon exists, remove that weapon, then grant the next approved
snapshot once.

## Phase 1 acceptance evidence

For every scenario in `MASTER_PLAN.md`, record the prepared values, transition
output, final status, game build, perspective, locomotion/task state, and frame
rate range. Do not modify production equip or ammunition behavior until:

1. RedM reloads normally without a Feather input handler.
2. Contextual `R` interactions remain independent.
3. Repeated prepare/clear and two logical Cattleman test sequences demonstrate
   deterministic ammo isolation without accumulation.

All three isolated acceptance conditions passed on the tested runtime. Phase 1
therefore has a **go** decision for the native-first Cattleman production slice.
Full reconnect persistence remains a production lease/reconciliation test, not
an isolated native-state expectation.

## Phase 2 implementation boundary

The first production increment adds a monotonically increasing generation to
each restored or newly equipped runtime. Client consumption checkpoints now
carry the session-bound item instance and generation; the server rejects a
stale generation, foreign item, or foreign session before changing metadata.
Client callbacks also verify that the same generation is still active before
applying a response.

The firing-specific polling loop has been replaced by a small periodic native
total observer. It checkpoints decreases after a short debounce and reports an
observed increase as a lease anomaly. The legacy reload input remains in this
increment because Inventory still owns reserve cartridges until the Phase 3
escrow transaction exists. Removing the handler before escrow would knowingly
make production reload unavailable rather than proving the native-first model.

The production lease smoke test passed all five checks for an equipped
Cattleman at generation `1`: the active lease and exact current lease were
accepted, while a stale generation, foreign item, and foreign session were all
rejected. Starting from `6` rounds and condition `100`, two shots produced two
bounded checkpoints (`5/99`, then `4/98`). The final state retained the same
item instance and generation at `4` rounds and condition `98`. This completes
the lease-binding and native-consumption-observer portion of Phase 2.

## Phase 3 escrow increment

Weapon metadata now separates `ammo.loaded` from `ammo.reserve`; older metadata
without `reserve` normalizes to zero. The configured escrow ceiling is `30`
cartridges for the Cattleman slice. Using a compatible ammunition stack performs
one Inventory transaction that removes only the available amount needed to
reach that ceiling and commits it to the equipped weapon's reserve. The client
then applies the approved loaded/total snapshot in the native order proven by
Phase 1.

The production reload compatibility block is disabled, so Feather no longer
registers, disables, reads, or reacts to `R`. RedM owns reload and every
contextual use of that key. The existing unload action returns both loaded and
reserve cartridges transactionally. Consumption checkpoints now report native
total and clip counts; the server accepts only a decrease within the active
lease and persists the remainder as loaded plus reserve.

The first live escrow test migrated item `36` at generation `2` from `4/0`
(loaded/reserve) to `4/26`, with native total `30`. Native reload followed by
two shots persisted total `28`, loaded `4`, reserve `24`, and condition `96`
from its prior value of `98`. Body pickup and drop both worked normally. RedM's
weapon HUD displayed `28`; this is the native total-ammunition display, while
the authoritative cylinder count remained `4` in the contract snapshot.

Two consecutive character logout/reselect cycles then restored the persisted
snapshot exactly: item `36`, total `28`, loaded `4`, reserve `24`, and condition
`94`. Each new Core character session correctly began a new runtime at
generation `1`; generations are session-scoped and are not persisted counters.
Repeated clear events reduced native total to zero idempotently before the new
ped was granted the approved `28` total once.

An empty-cylinder probe established another native invariant. RedM initially
reported the requested `0/30`, but autonomously changed it to `6/30` on the
next update; reasserting a zero clip after granting the pool did not hold and
`R` had nothing left to reload. Escrow therefore persists this deterministic
native behavior: using ammunition when total is zero immediately assigns up to
one cylinder from the transferred cartridges. Native `R` remains responsible
for later partial reloads. Feather does not fight the engine with a delayed
clip reset.

Native reload distribution checkpointing then passed. From total `27`, one
shot persisted `26/4` and condition `90`; RedM inserted two cartridges and the
observer persisted `26/5` then `26/6`, each with `consumed=0` and no additional
condition wear. Final server and native state matched at total `26`, loaded `6`,
reserve `20`. Reload persistence no longer depends on a later shot.

The final Phase 3 regression passed after removing all legacy reload-input and
carry-proximity code. Lease validation remained `5/5`. One shot persisted
total `25`, loaded `5`, and condition `89`; native reload persisted loaded `6`
with `consumed=0` and unchanged condition. A resource restart cleared native
state and restored item `36` exactly once at total `25`, loaded `6`, reserve
`19`, condition `89`. Server and native snapshots matched after restoration.
Phase 3 is complete for the Cattleman slice.

## Phase 4 lifecycle checkpoint implementation

Character logout previously completed Core session teardown before the client
`Feather:Character:Logout` event reached Weapons. At that point the server had
already invalidated the lease, so that event could only clear native state; it
could not safely persist a final snapshot.

Character now exposes an owner-scoped logout-checkpoint registry. Registrations
contain only an owner and named export—Lua callbacks are never retained across
the resource boundary. Character dynamically resolves each export before
`character.logout.v1` and does not begin session teardown until every registered
checkpoint has returned successfully. Weapons' named export samples native
total and clip state, submits any pending decrease or reload distribution, and
waits for the server acknowledgement internally. This is an event boundary,
not a delay or grace-period workaround. The existing logout event remains
cleanup-only.

Weapons also submits an immediate checkpoint on the transition into native ped
death. Routine firing and reload observations remain debounced; death bypasses
that debounce so the accepted snapshot is current before revive or later
lifecycle work. Hard disconnects can only retain the last already accepted
bounded checkpoint because a disconnected client cannot provide a trustworthy
late report.

The named registration and final logout checkpoint passed live validation. After
a shot persisted total `18`, loaded `4`, and condition `82`, `/logout` reported
`logout checkpoint PASS total=18 loaded=4` before native cleanup and Core session
teardown. This proves the final boundary is acknowledged rather than inferred
from the ordinary debounced observer.

Native reload followed by immediate logout also passed. RedM moved the snapshot
from `18/4/14` to `18/6/12` without condition wear; the final logout checkpoint
reported `18/6`, and reselect restored total `18`, loaded `6`, reserve `12`, and
condition `82`. The next shot persisted `17/5/12` and condition `81`, confirming
consumption and wear remained synchronized after restoration.

Death/admin revive also retained the exact accepted snapshot on both sides:
total `17`, loaded `5`, reserve `12`, condition `81`. No duplicate grant,
ammunition change, or extra wear appeared after revive.

Character isolation and restart reconciliation passed. A second character
received no weapon or ammunition, and its logout checkpoint correctly reported
a skipped `nil/nil` snapshot. Returning to the original character repeatedly
restored item `36` exactly once at total `17`, loaded `5`, reserve `12`, and
condition `81`. Restarting `feather-weapons` cleared native state and restored
that same accepted lease without duplication. Phase 4 is complete for the
Cattleman slice.

## Phase 5 attachment wiring

The existing attachment service already enforced equipped ownership,
definition compatibility, slot conflicts, server-side gunsmith proximity,
transactional Inventory consumption/return, metadata revision checks, and
runtime generation continuity. The installation RPC and its client menu path
were missing, so only removal was reachable. Both directions are now wired.

The F6 modification menu lists compatible uninstalled components and installed
components separately. Installation remains authoritative on the server; a
menu entry does not imply the player owns the required Inventory item. A
successful change rebuilds the approved native weapon snapshot with the same
ammo, condition, lease generation, and complete attachment set. `weaponstate`
now reports attachment IDs for live verification.

The complete Long Barrel lifecycle passed live validation: the compatible item
was consumed transactionally, the native component appeared, metadata reported
`cattleman_long_barrel`, logout/reselect and a Weapons restart restored it, and
removal returned the item while metadata returned to an empty attachment set.

Phase 5 contract regression passed: `WeaponRuntimeLeaseSmokeTest` reported
`5/5`, including stale-generation and foreign-session rejection, while
`AdminWeaponsContractSmokeTest` reported `10/10` across identity, capability,
named issuance export, weapon/ammunition catalogs, Inventory mappings, and the
character grant export.

Live Admin issuance and ammunition grants also passed before and after a Weapons
restart. Issued weapons retained unique serial metadata, Admin ammunition entered
Inventory rather than bypassing escrow, and using the stack respected the
configured total ceiling.

Two server-console recovery tools complete the Phase 5 operational surface.
`WeaponMetadataInspect` performs read-only validation of the persisted equipped
instance and compares it with the runtime lease. `WeaponReconcile` explicitly
invalidates the old generation and restores the last accepted Inventory snapshot;
it does not trust or preserve unaccepted native state. A failed restore clears the
client weapon instead of leaving an invalid native lease active.

Both recovery tools passed live validation. Metadata inspection validated item
`163`, its unique serial, total `30`, loaded `6`, reserve `24`, condition `100`,
and `runtimeMatch=true`. Forced reconciliation advanced the lease to generation
`2`, cleared and restored native state exactly once, and produced an identical
server/native snapshot. A subsequent shot and native reload persisted `29/5`
then `29/6` with condition `99`, proving normal observation continued after
recovery. Phase 5 is complete for the Cattleman slice.

The first Phase 6 production-default regression also passed with `DevMode=false`,
the native probe disabled, warning-level logging, the retired reload RPC removed,
and delayed lifecycle retries removed. Native reload, firing, restoration,
logout/reselect, modifications, metadata inspection, and the Admin catalog all
continued to work through event-led reconciliation.

Clean-install catalog hardening passed after aligning the recipe and standalone
SQL. Startup now validates missing/duplicate names, item types, unique/stack
modes, and usable flags. The Long Barrel remained non-usable and installable
only through the gunsmith menu, while ammunition and gun oil remained
usable and metadata inspection continued to pass.

The final release contract smoke test passed `8/8`: exact definition counts,
Inventory readiness, native reload/escrow capabilities, runtime and attachment
routes, retired reload-route absence, disabled native probe, and active metadata
validation all passed. Phase 6 code and contract gates are complete.

A coordinated recipe installation against a fresh database also passed. The
four supported Inventory definitions were created with the expected usable,
type, category, and unique/stack settings, and Weapons passed its startup
contract without relying on upgrade history.
