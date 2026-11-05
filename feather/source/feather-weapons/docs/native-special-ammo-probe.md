# Single-weapon special ammunition baseline

Development-server experiment; no production support is implied by its output.
Keep `Config.NativeProbe.enabled = false` for ordinary operation.

## Improved Throwing Knife setter-order experiment

All compatibility matrix controls and candidates returned true on the target
build: Regular/Poison/Improved knives, Regular/Poison/Improved arrows, and
Regular/Improved/Homing Tomahawks. This rules against a simple compatibility
failure but does not prove unlock requirements or live pool availability.
No specific Improved unlock ID has been established; unlock state is untouched.

Production gives a weapon, requests a selected ammo type, writes a clip, and
sets its pool. The isolated knife command omits clip writes entirely. It gives
a zero-ammo base knife, enables/selects the target, sets one round by type,
activates the weapon, and reads immediately and after one second. Regular is
the control. This experiment changes temporary native state; it is not read-only.
It never issues/persists Inventory items, enables unlocks, or reopens production
Improved loading. Its cleanup tracks the test pool and extra weapon model.

1. Unequip ALL Inventory weapon slots (including all melee and throwable slots).
   Do not unload their ammunition: ownership stays in their Inventory carriers.
2. Enable Config.DevMode and Config.NativeProbe.enabled locally, then restart
   feather-weapons only. Leave other probe defaults unchanged. No grants or SQL.
3. F8: WeaponNativeProbeImproved regular. Inspect wheel without firing. Run
   WeaponNativeProbeStatus, then WeaponNativeProbeClear.
4. F8: WeaponNativeProbeImproved improved. Inspect wheel without firing. Run
   WeaponNativeProbeStatus, then WeaponNativeProbeClear.
5. Send all knife/cleanup output. Disable NativeProbe.enabled, restart Weapons,
   and re-equip Inventory weapons only after clearing the probe.

The command refuses occupied/unavailable server or local equipment state and
nonempty preexisting knife pools. Do not perform Inventory actions during it.
A true compatibility query alone is not a successful grant. If Regular fails,
the control baseline is inconclusive. If only Improved fails without clip writes,
the old clip setter is not sufficient to explain the failure. A later test may
need a different native acquisition path; no production change is justified yet.

1. Unequip every Inventory weapon slot, including shoulder and back. A failed
   native restore does not release the server equipment state.
2. Enable `Config.DevMode` and `Config.NativeProbe.enabled` on the development
   server. Keep the probe's Cattleman and regular ammunition defaults. Restart
   the resource after deploying the updated probe.
3. Run `WeaponNativeProbeSpecial` in F8. It refuses if server state is unavailable
   or any server/local weapon slot is occupied.
4. Send all `[WeaponNativeProbe] special` lines before doing anything else.
   Do not fire or use Inventory weapon actions while the probe is active.
5. Run `WeaponNativeProbeClear` before returning to Inventory weapons. Disable
   the probe after the investigation.

The fixed sequence creates one Cattleman, seeds 12 high-velocity rounds, enables
and requests that type, and activates the weapon without writing a clip.
Draw/reload normally, then run `WeaponNativeProbeStatus` to capture both pools
and the clip after native reload. Do not fire until that baseline is reviewed.
Each immediate snapshot reports the selected type, regular and high-velocity
pools, and clip validity/count. Counts are observations, not acceptance criteria:
this experiment intentionally does not apply production pool compensation.
It does not issue Inventory items or persist test ammunition. Cleanup removes
the test pools and weapon, including on resource stop while no local production
weapon is active. Live behavior and delayed native transitions remain unverified.

The earlier clip-write experiment added three regular rounds despite the wheel
showing 12. One shot reduced the wheel to 11 while the regular/hash totals stayed
at three. Therefore the hash ammo-type readback is not sufficient to conclude
that special selection failed. Production integration remains paused pending
the no-clip-write baseline and direct special-pool conservation checks.

## Improved knife acquisition comparison (historical, deferred)

Improved investigation is deferred by user request. The Improved-only commands
described below have been removed, including weaponammocompatibility and
weaponammovalidity. Do not run these historical instructions. Existing unrelated
native probes remain disabled by default; production loading stays excluded.

The isolated no-clip setter control showed Regular 1/8 in the wheel and the
Regular object ammo hash. Improved remained zero immediately and after 1000 ms,
with no object ammo and an empty wheel. This does not establish an unlock gate.

`WeaponNativeProbeImproved [regular|improved] [set|add]` now accepts an `add`
method. The default remains `set`. The new method uses RDR3
`_ADD_AMMO_TO_PED_BY_TYPE` (0x106A811C6D3035F3), amount one and ADD_REASON_DEBUG
(0x5C05C64D), instead of the setter. Signature source:
https://raw.githubusercontent.com/alloc8or/rdr3-nativedb-data/master/natives.json

This temporarily changes native ammo only; no Inventory items, metadata, clip
writes or unlock-state changes. All Inventory weapons must be unequipped and
DevMode/NativeProbe enabled. Restart feather-weapons after updating the script.

1. Run `WeaponNativeProbeImproved regular add`.
2. Wait at least one second, inspect the wheel without throwing, then run
   `WeaponNativeProbeStatus`. Record the wheel and output before clearing.
3. Run `WeaponNativeProbeClear`.
4. Run `WeaponNativeProbeImproved improved add` and repeat the inspection/status.
5. Run `WeaponNativeProbeClear`, disable NativeProbe and restart before equipping
   Inventory weapons again.

Server grants: None. Player `/AddItems`: None. SQL changes: None.
Improved remains excluded from production loading pending live evidence.

The add-by-type comparison also passed Regular (pool one and Regular visible)
and failed Improved (all pools zero immediately, after 1000 ms and at status;
no Improved wheel entry). Both probes were cleared. Neither setter nor adder
accepted this Improved identifier; an unlock gate remains unproven.

Next read-only check: with DevMode enabled, run `weaponammovalidity` after
restarting feather-weapons. NativeProbe can remain disabled, and no unequipping
or wheel interaction is required. It queries RDR3 `_IS_AMMO_VALID`
(0x1F7977C9101F807F) for supported controls, Improved candidates, Homing Tomahawk
and a deliberately invalid identifier. This tests runtime recognition, not
unlock eligibility. Grants and SQL: None.
