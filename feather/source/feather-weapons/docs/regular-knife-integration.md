# Regular throwing knives: current quantity integration, 2026-11-21

Implemented and locally tested; the first Jane paid load/throw/own native-recovery
gate is live accepted. Capacity/UI/reselection, batched own recovery, loaded
death/revive, prepared resource restoration and full-capacity native pickup /
headroom also passed. Shared recovery/persistence/draw subsequently passed as
recorded below; live competing collectors remain untested.
This follows the
released Weapons0.25.0 / Inventory0.17.0 / Shops0.5.0 regular-arrow baseline.
Earlier regular/poison knife compatibility, eight-unit ceilings and legacy
lifecycle results remain historical acceptance; they are not repeated as a new
type matrix. This document records the Regular slice; the subsequent Poison
integration is covered by special-ammunition-integration.md. Improved stays excluded.

Enable `setr feather_throwing_knife_quantities 1` together with the existing
`setr feather_throwable_quantities 1` and native runtime/transport/lifecycle gates.
The new knife option defaults off and requires the existing quantity host. It
adds only `ammo_throwing_knives_regular` / `AMMO_THROWING_KNIVES`, capped at8.
No serialized throwing-knife carrier is issued or sold. Existing regular knife
ammo remains $1 per unit; purchase maximum10 and loaded capacity8 are separate.
Poison offers are hidden while this admission is enabled. No physical holder,
old-item conversion, refund, inventory wipe or new SQL schema is included.

One aggregate lifecycle owner manages separate Tomahawk and throwing-knife
carriers. Each owns a distinct native GUID and independently restores its pickup
policy. Carrier construction uses the historically accepted zero-ammo grant and
verifies that all native pools remain unchanged; only the parent's acknowledged
ledger restore writes quantities. Knife recovery may rebind/materialize the
missing zero-ammo carrier but never adds ammunition. Any unresolved child keeps
the aggregate retained and blocks release. Full8 suppresses knife model pickup;
space re-enables it. The model is read using _GET_WEAPONTYPE_MODEL, not guessed.
Config.RegularKnifePickupPriorAllowed is the explicit prior policy (defaulttrue
when enabling this feature); teardown restores it. No native getter is assumed.

Confirmed funded debits atomically create allowances in namespace
`regular-knife-quantity-allowance-v1`. Claims consume only that namespace once,
within180seconds and50metres in the same bucket, at most8 carried units. Arrow
and Tomahawk receipts cannot fund knives. The approved bounded-nearby-allowance
tradeoff still applies; native pickup events do not prove exact object identity.
Different ammunition types increasing together in one sample remain fail-closed.
Definite partial rejection preserves later provisional pickups and real shot
reductions; SQL uncertainty is not automatically retried. Legacy equipped
throwing-knife rows must be stored before opting in; no migration is inferred.

Diagnostics: F8 `weaponKnifeQuantityStatus` reports this type's phase, funded and
observed quantity, GUID capture, pickupAllowed and revision. Existing
`weaponQuantityStatus` stays Tomahawk-specific. `[WeaponNativeKnifePickup] PASS`
identifies an acknowledged knife claim. Native factory refusals now preserve
their specific diagnostic reason without changing native/economic behavior.

Research: archived client/main.lua NativeGrantAmount defaults throwing knives to
zero; the September legacy acceptance establishes regular native compatibility.
Local rdr3 native reference confirms _GET_WEAPONTYPE_MODEL hash0xF70825EB340E7D15.
Build1491.50 MP short_update treats throwing-knife ammunition as its own type.
The current combined-owner/ledger port and model permission behavior need the
new focused live gate; historical tests do not imply those results.

Local checks:312 Weapons Lua suites/syntax,7 JavaScript checks, full Inventory
Lua (parameterized real arrow/knife observation and claim primitives), and44
Shops checkout scenarios pass. Tests cover strict default-off/profile limits,
full shipped manifest with knives on/off, independent carrier GUIDs/permissions,
zero native ammo writes, throw/rebind/capacity/sealed aggregate cleanup, immutable
claim types, partial credit, distinct namespaces and transaction rollback.
Windows PowerShell5.1 package fixtures pass17 exact copies, baseline/hash/stopped
guards, backups/idempotence and BOM/CRLF/operator config/evidence preservation.

Package: C:/coding/deployments/regular-knives-2026-11-21. It contains14 existing
Weapons runtime files and3 existing Inventory runtime files. No new runtime
script/manifest, configuration replacement, Shops runtime, images or DB migration
is needed; no refresh or full server restart is required. Keep the new replicated
flag before startup while using the saved knife pool; disabling is not migration.
User controls commits/pushes/PRs and any later version bump/release.

First live gate uses Jane only: record existing arrow/Tomahawk balances, confirm
active knife0, buy two loose regular knife ammo units for$2 (no carrier item), load2,
throw once into clear nearby ground, await saved/native1, native collect within
180seconds/50metres ->2 and knife PASS. Verify arrow/Tomahawk balances unchanged.
Capacity8, batched/shared knife recovery and lifecycle follow-ups are separate
pending gates. No grants or repeat of the legacy poison/improved matrix.

2026-11-21 Jane regular throwing-knife FIRST CURRENT-RUNTIME LIVE PASS. Initial knife ACTIVE saved/native0rev81, GUIDfalse/pickupAllowedtrue; Tomahawk saved/native3 GUIDtrue/pickupAllowedfalse and arrows saved/native40 at81. Paid load2 -> knife ACTIVE saved/native2rev82/GUIDtrue; single throw ->1rev83; native pickup WeaponNativeKnifePickup PASS ledger acknowledged/read-only GUID rebind84, no loose/native ammo grant ->ACTIVE saved/native2rev84/GUIDtrue/pickupAllowedtrue. Tomahawks3 and arrows40 independently remain unchanged at shared84. This accepts first paid regular-knife load/throw/own native recovery and coexistence with existing Tomahawk/arrow pools, not capacity8/batched/shared knife pickup or knife-specific lifecycle follow-ups. No new deployment, repair or repeat needed for this result. Current Jane knife2/Tomahawk3/arrow40 rev84. User handles commits/pushes/PRs; no feature version bump/release performed.

2026-11-21 Jane regular throwing-knife CAPACITY/UI/RESELECTION LIVE PASS. User confirms all posted checks passed: paid loose stock sufficient to leave an extra unit, load6 from carried2 ->8, Load disabled with capacity reason while loose stock remains/no loose loss, unload1 ->7 with exact loose return/Load enabled/pickupAllowedtrue, reload1 ->8/Load disabled/pickupAllowedfalse, Return to Selection/reselect and throwing-knife draw. Supplied final F8 independently confirms ACTIVE saved/native knives8 GUIDtrue/pickupAllowedfalse, Tomahawks3 GUIDtrue/pickupAllowedfalse, arrows40, all at shared ledger87. Intermediate7/native sample and loose counts were not separately pasted; detailed UI observations accepted through user's all-checks confirmation. This accepts eight-unit knife ceiling, one-unit transfer conservation, permission threshold and full-capacity reselection persistence/coexistence. Batched/shared knife recovery, full-capacity native pickup behavior, death/revive and prepared restart are separate pending gates. No new deployment/config/restart needed to record result. Latest Jane knives8/Tomahawks3/arrows40 rev87. User handles commits/pushes/PRs and later feature release.

2026-11-21 Jane regular throwing-knife MULTIPLE-OUTSTANDING/BATCHED RECOVERY LIVE PASS. User confirms all posted checks passed. Prior accepted baseline8rev87; three paid throws settled ACTIVE saved/native5rev90, GUIDtrue/pickupAllowedtrue. Native knife pickup acknowledgements91 and92 (read-only GUID rebind, no loose/native ammo grant) restored ACTIVE saved/native8rev92, GUIDtrue/pickupAllowedfalse. Three units recovered in two acknowledgements establishes at least one multi-unit credit; exact batch sizes/order not supplied. Tomahawks3 GUIDtrue/pickupAllowedfalse and arrows40 independently unchanged at shared92. This accepts three outstanding knife allowances and batched own recovery/coexistence, not cross-player or live competing-collector contention. Knife full-capacity native pickup and loaded death/revive/prepared-restart remain pending. No new deployment/config/restart required to record result. Latest Jane knives8/Tomahawks3/arrows40 rev92. User handles commits/pushes/PRs and later release.

2026-11-21 Jane regular throwing-knife LOADED DEATH/REVIVE + PREPARED RESOURCE-RESTART LIVE PASS. User confirms all posted manual checks passed: baseline knives8/Tomahawks3/arrows40; Admin Kill and sealed (not frozen) runtime, Admin Revive restores active/draw, aggregate PrepareStopAll PASS/ShutdownStatusready, ordered Shops/Weapons stop+ensure, Shops smoke and post-start draw. Intermediate death/seal/prepare-stop/smoke outputs were not separately pasted; accepted through user's manual-check confirmation. Supplied final F8 independently confirms ACTIVE idle/nonreceiving/nonquiescing runtime with2firearm/bow copies and five GUID-owned melee entries, no pending/closing/deathClosing; session8418d5f3-e609-11f1-98c3-e0d55eaa2deb / epochending1795307292:7415341:1. Aggregate throwable owner and its knife child both ACTIVE with separate GUIDs and pickupAllowedfalse, saved/native knife8/Tomahawk3, arrow40, revolver100; ledger92 unchanged. This accepts loaded knife/Tomahawk aggregate cleanup/restoration through the confirmed lifecycle sequence, not abrupt crash or in-flight SQL interruption. Knife cross-player recovery and full-capacity native-world pickup remain distinct pending gates. No deployment/repair/repeat needed for this result. Latest Jane8knives/3Tomahawks/40arrows/100revolver rev92. User handles commits/pushes/PRs and later release.

2026-11-21 Jane regular throwing-knife FULL-CAPACITY NATIVE PICKUP/HEADROOM LIVE PASS. User confirms all requested manual checks passed, including grounded knife retained while full and collection after headroom opens. Initial active saved/native8rev92/GUIDtrue/pickupAllowedfalse; unload1+throw1 supplies active6rev94/pickupAllowedtrue. User-confirmed load2 ->8/suppressed; walking over grounded knife at full leaves it available. Unload1 then native pickup logs WeaponNativeKnifePickup PASS ledger acknowledgement97/read-only GUID rebind/no loose/native ammo grant. Final F8 ACTIVE saved/native8rev97/GUIDtrue/pickupAllowedfalse; Tomahawks3 and arrows40 independently unchanged at shared97. Intermediate full8rev95/unload7rev96 samples and ground observation were not separately pasted; the manual-check confirmation covers them, with revisions consistent with the actions. This accepts cap suppression, re-enable on space and grounded native recovery in this tested build, with no over-cap balance or frozen state. Shared knife pickup and live competing-collector contention remain separate pending gates. No deployment/config/restart/repair needed for this result. Latest Jane knives8/Tomahawks3/arrows40 rev97. User handles commits/pushes/PRs and later release.

2026-11-21 regular throwing-knife CROSS-PLAYER TRANSFER PERSISTED, CLIENT CRASH OPEN. Before test John ACTIVE saved/native0rev11/GUIDfalse; Jane supplied8rev97 then throw settled7rev98/GUIDtrue/pickupAllowedtrue. John collected but his client crashed with a RAGE error before F8 capture; error/crash identifier unavailable. After rejoining, John independently reports ACTIVE saved/native1rev12/GUIDtrue/pickupAllowedtrue and confirms he can draw the recovered knife. Combined saved count conserved8 (Jane7+John1). Accept committed shared transfer, reconnect persistence/restoration and recipient draw; do NOT mark original live pickup/session stability passed or generic crash/in-flight-write durability accepted. Root cause unconfirmed. Review identifies an empty-recipient-specific candidate: Q.AcceptNativePickup -> ensure -> zero-ammo materialize if inventory GUID absent, through GiveWeaponToPed; this is a hypothesis, not a diagnosed crashing native. No runtime mitigation, delay, refund, replay or data repair introduced without evidence. Next useful comparison is another shared pickup while John already has1/current carrier, separating empty-carrier creation from already-funded pickup. If crash repeats, preserve exact dialog/log evidence. No code deployment required for that comparison. Latest known Jane7rev98 / John1rev12. User handles commits/pushes/PRs and later release.

2026-11-21 regular throwing-knife SHARED PICKUP WITH EXISTING RECIPIENT CARRIER LIVE PASS. Comparison after earlier unresolved empty-recipient RAGE crash: Jane ACTIVE saved/native7rev98 -> single paid throw ->6rev99. John starts ACTIVE saved/native1rev12/GUIDtrue, receives WeaponNativeKnifePickup PASS ledger acknowledgement13/read-only GUID rebind/no loose/native ammo grant, ends ACTIVE saved/native2rev13/GUIDtrue/pickupAllowedtrue; no crash reported in this comparison. Combined saved quantity conserved8 (Jane6+John2). Accept normal shared collection for an already-funded recipient in this run. This does not diagnose the earlier crash or establish a reliable empty-recipient collection path; empty GUID creation remains a candidate distinction, and the original crash signature was unavailable. No runtime change, delay, economic replay, refund or repair applied. Latest known Jane6rev99 / John2rev13. Further empty-recipient reproduction/diagnostic decision remains separate; live competing-collector contention untested. User handles commits/pushes/PRs and later release.

2026-11-21 isolated cross-player pickup crash DISPOSITION: user considers the earlier RAGE crash likely unrelated to Weapons/client instability and does not want it treated as a Weapons blocker. Evidence does not establish a cause: crash signature unavailable; first transfer persisted and recipient restored/drew after reconnect; subsequent already-equipped shared pickup passed without a reported crash. Retain incident as one unattributed client crash, not a diagnosed Weapons defect or claimed fix. Shared transfer/conservation, persistence/restoration/draw and subsequent normal collection are accepted within supplied observations. No further crash-specific reproduction or speculative native mitigation required unless the issue recurs or new evidence appears. The earlier empty-recipient materialization candidate remains unproven and is not elevated to an active blocker. No code, balances, deployment or runtime settings changed for this disposition. Latest Jane6rev99 / John2rev13, combined8. User handles commits/pushes/PRs and later release.
