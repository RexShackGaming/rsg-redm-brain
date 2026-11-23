# Validated specialty ammunition — 2026-11-21

Implemented, locally tested and live accepted for the focused scope recorded
below, including loaded death/revive and orderly restart. Prepared for Weapons
0.26.0 with Inventory0.18.0; not yet published. This includes the uncommitted
regular-knife work. No commit, push, item rename, schema migration or grant made.

## Admission and ownership

Existing `feather_regular_arrows` plus `feather_special_arrows=1` admits Small
Game (40), Poison (8), Fire (8) and Dynamite (8) alongside Regular arrows (40).
Existing `feather_throwable_quantities` and `feather_throwing_knife_quantities`
plus `feather_poison_knives=1` admits Poison knives (8) alongside Regular (8).
New flags default off. Once balances exist, keep the flags enabled; disabling
is not a migration. Existing item keys, images, prices and pack sizes remain.
Improved arrows/knives remain excluded. No blanket native compatibility query
can expand this explicit list or define server limits.

All pools are independently funded, sampled, loaded/unloaded and sealed. The
two knife types share one model/GUID carrier, including Poison-only ownership;
they do not create two competing native weapon entries. Regular headroom controls
knife pickup permission because the observed recovered knife is Regular.
Arrow status now includes per-type funded/native quantities. Knife status adds
a `poison` funded/native child while preserving the existing Regular fields.
Type selection uses the native wheel. This does not add persistent wheel-choice
metadata or a new selection setter; all owned pools restore independently.

## Confirmed recovery only

The user approved recovery only for confirmed return types. Historical live
Poison-knife collection increased `AMMO_THROWING_KNIVES`, not Poison. Therefore
its paid debit creates one Regular-knife allowance per unit. Source-tagged,
distinct receipt IDs prevent collisions when Regular and Poison decrease in the
same revision. Existing Regular namespace/radius/bucket/expiry/locking is reused.
Any claimant consumes the allowance once; no serial/condition follows the throw.
An unfunded Poison native increase is declined and compensated, not saved.

Specialty-arrow loading/firing was historically validated, but return-type
evidence has not been established here. None creates recovery allowances.
Unconfirmed native increases use the normal zero-credit compensation path.
Regular arrows retain their existing bounded recovery. As before, a generic
nearby allowance is not exact projectile identity. Simultaneous increases in
multiple native types remain a fail-closed limitation.

## Sources and validation

Reused historical notes in `throwing-knife-multi-ammo.md` and the September30
arrow compatibility evidence recorded in the framework master plan. Archived
`tests/archive/client/main.lua` and `firearm_pools.lua` use native
`0xCC9C4393523833E2`; decompiled build1491.50 `fme_escaped_convicts.ysc.c`
line29661 selects Fire arrows for a Bow. These confirm a native selection path,
not pickup ownership; this implementation adds no speculative setter.

Local checks: 315 Weapons Lua suites, seven JS checks, full Inventory Lua runner
including real debit/claim primitives, 44 Shops composition scenarios, and PS5
installer fixtures. New checks cover explicit native/cap integrity, optional
admission, typed transfers/restoration, Poison-only carrier, shared GUID cleanup,
once-only Poison-to-Regular conversion, same-revision sources, atomic rollback,
and zero-credit specialty-arrow pickup reports. Native/SQL ports are modeled;
these do not replace the focused live integration gate.

Deployment package: `C:\coding\deployments\special-ammunition-2026-11-21`.
Nineteen existing runtime files (16 Weapons, three Inventory), with reviewed
released and prior regular-knife baselines, source hashes, backups and operator
config preservation. No manifest/new runtime scripts, refresh, SQL or full-server
restart required. Full commands and Jane-only test steps are posted in chat.

2026-11-21 Jane Poison-knife current-ledger integration LIVE PASS. Baseline Regular knives6/Poison0, arrows40 and Tomahawks3 at revision99. Paid purchase/load: Regular6/Poison1 revision100; Poison throw: Regular6/Poison0 revision101; native pickup acknowledgement102 with no loose/native ammo grant: Regular7/Poison0, saved/native agreement, active GUID captured. Arrows40 and Tomahawks3 remained unchanged at shared revision102. Accepts one own paid Poison-to-Regular bounded recovery and shared carrier continuity. Does not establish specialty-arrow firing/recovery, loaded-specialty lifecycle, Poison capacity, or cross-player Poison conversion. Next Jane-only gate: specialty-arrow typed loading, exact unloading and reselection; native compatibility matrix need not be repeated. No new deployment/configuration/commands required merely to record this result.

2026-11-21 Jane specialty-arrow typed load/draw LIVE PASS. Active ledger revision106: Regular40, Small Game1, Poison1, Fire1 and Dynamite1, each funded/native matched. User confirms all arrows can be drawn. This accepts simultaneous typed pool loading and native wheel/draw availability in the current ledger integration. Exact Poison unload/reload and Return to Selection/reselection were requested but not explicitly confirmed in this reply; do not infer their completion or persistence from revision106. Specialty firing, return types/recovery and loaded-specialty lifecycle remain separate pending gates. No deployment or restart needed for this result.

2026-11-21 Jane specialty-arrow exact unload/reload LIVE PASS. At revision107 Poison arrows decreased1->0; Regular40, Small Game1, Fire1, Dynamite1, Regular knives7, Poison knives0 and Tomahawks3 remained saved/native matched. User explicitly confirms exactly one loose Poison arrow returned to Inventory. Reload result revision108 restores Poison1; Regular40 and other specialties1 remain matched and active. User confirms all arrow types can be drawn. Return to Selection/reselection was requested, but the reply does not explicitly state it was performed; retain persistence as pending confirmation rather than infer it from revision108. No deployment/restart needed. Next isolated firing gate can use Small Game while preserving other pools; specialty recovery remains uncredited pending confirmed return types.

2026-11-21 Jane specialty-arrow reselection and Small Game firing LIVE PASS. User explicitly confirms Return to Selection/reselection of Jane, resolving the earlier persistence confirmation gap. Prior reload/draw result revision108 had Regular40 and all four specialties1, funded/native matched. After requested single Small Game shot, active revision109 has Small Game0, Regular40, Poison1, Fire1 and Dynamite1, all funded/native matched. Accepts specialty-pool persistence through reselection and isolated Small Game consumption without changing other arrow pools. No specialty pickup/recovery evidence supplied; no recovery credit enabled. Next Jane-only firing gate: one Poison arrow, leave uncollected. No new deployment/config/restart required.

2026-11-21 Jane isolated Poison-arrow firing LIVE PASS. Following the requested single Poison shot, active revision110 reports Regular40, Small Game0, Poison0, Fire1 and Dynamite1, each funded/native matched. Only Poison decreased from revision109; accepts typed Poison consumption without other arrow-pool changes. Specialty recovery remains unconfirmed and uncredited. Next Jane-only firing checks: Fire then Dynamite, one shot each with separate status samples. No deployment/config/restart required.

2026-11-21 Jane Fire/Dynamite isolated consumption LIVE PASS. Revision111: Fire1->0, Dynamite1, Small Game0, Poison0, Regular40; revision112: Dynamite1->0, all specialties0, Regular40. Every reported funded/native pool matches and runtime remains active. Together with revisions109/110, all four historically supported specialty types pass isolated consumption in the current ledger path. Typed loading/draw, exact Poison unload/reload, reselection persistence and Poison-knife-to-Regular recovery were previously live accepted. No specialty-arrow return-type/recovery evidence is established. Remaining focused lifecycle gate: load one of each specialty arrow plus one Poison knife, then loaded death/revive and orderly restart with those pools populated; no need to repeat compatibility or firing checks. No deployment/config/restart needed merely to record these results.

2026-11-21 Jane populated specialty death/admin-revive LIVE PASS. Attached death trace: Medical dead revision9, Weapons runtime/session/ammo sealed, quiescingtrue, pendingfalse, ledger117; no frozen state. Saved pools: Regular arrows40, each Small Game/Poison/Fire/Dynamite1, Regular knives7/Poison1, Tomahawks3, revolver100. Medical alive revision10 restores fresh epoch ending1795322992:23114645:5 in the same session/ped; runtime active, idle/nonquiescing/nonreceiving, ammo closingfalse/deathClosingfalse/pendingfalse, ledger117 and all balances unchanged. Knife and Tomahawk GUIDs captured; user confirms bow and Poison knife can be drawn. Accepts loaded-specialty death seal and admin-revive restoration without quantity churn/loss/duplication. Orderly resource restart with these populated pools remains pending; no specialty-arrow recovery evidence inferred. No new deployment/config needed.

2026-11-21 Jane populated-specialty orderly resource restart LIVE PASS. Pre-stop runtime closed, cleanupCompletetrue, ownedCopies0; client stop cleanup PASS with no new SQL/release acknowledgement. Restart restores fresh epoch ending1795323253:23375473:1, ACTIVE/nonquiescing/nonreceiving/idle, two owned copies, five GUID-captured melee entries, ammo pendingfalse/closingfalse/deathClosingfalse. Ledger117 unchanged: Regular arrows40, each specialty1, Regular knives7/Poison1, Tomahawks3, revolver100; supplied per-type statuses all funded/native matched. User confirms bow and Poison knife still draw. Shops release smoke9/9 read-only PASS. Accepts loaded-specialty cleanup/restart restoration and catalog readiness; no specialty-arrow recovery evidence or live contention inferred. Current focused implementation gate is complete for typed admission, load/unload/draw, isolated consumption, reselection, death/admin-revive and orderly restart, plus own Poison-knife-to-Regular recovery. Remaining optional follow-ups: current-runtime specialty capacity boundaries, cross-player Poison conversion, and research/verification before enabling any specialty-arrow recovery. No deployment/restart needed to record this result; versions unchanged and user retains commit/push/PR control.
