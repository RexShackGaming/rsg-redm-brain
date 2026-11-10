# GUID creation validation

This opt-in engine acceptance suite validates the same unified GUID factory used by production creation. It uses one active player and a temporary native-only matrix. No inventory weapon grants, equipment edits, loose ammunition transactions, native ammo/clip/type writes or database repairs are performed by the suite. Original loadout/ammo/item state is compared before and after normal seal/release/restore.

Keep the player idle. Current native wear must already match saved metadata; use ordinary equipment changes to seal wear before running. No development mode is required. Stop on any review_required report; do not repeat run to bypass retained ownership.

Server console after deployment:

```text
set feather_native_guid_suite 1
WeaponGuidAcceptance run
WeaponGuidAcceptance status
```

`run <current-server-id>` chooses one player explicitly when several are active.
The matrix is 1800 cases/24firearms: all valid ordered pairs and carry positions, required Primary anchors for Offhand, clean/customized wear+attachment profiles, and representative four-slot cases. It is not exhaustive four-way permutations and does not certify all draw animations.

The runner stops at the first failure, preserving the named case and observations. It has a15-second case deadline and30-minute native run deadline plus up to3minutes for acknowledged report delivery; confirmed native cleanup is required before original loadout restoration. A cleanup-confirmed failure may still restore original loadout and remain review_required. Unconfirmed cleanup holds the restore and input.

```text
WeaponGuidAcceptance cancel
```

Requests cancellation without retrying creation. Review the report before any next action. `archive` retains the report in a timestamped file and resets only diagnostic evidence, never gameplay/runtime state. It does not authorize replay over a frozen owner.

After complete/restored, confirm normal equipped weapons draw and record:

```text
WeaponGuidAcceptance visual pass
```

Detailed report: `native-guid-acceptance-report.json` in the Weapons resource. The opt-in automatically returns to0 after completion and resets on resource start. Never stop/restart during the run to skip a held failure. The first RedM run reached1800/1800 but its old unbounded final report failed delivery. Detailed old client observations were not retained; the original run is not marked complete. Bounded transport and read-only recovery subsequently passed separately; see the live record below.


Report transport v2 uses JSON string packets of at most6000bytes, acknowledgements and idempotent report-only retries. Native cases are never replayed by a report retry. The client caches result/packet data until acknowledgement or resource shutdown. `WeaponGuidAcceptance resend` requests data retransmission only when a matching live/completed receipt exists.

After the original transport failure, quit/reconnect with the patch so the normal host restores the saved loadout to a fresh session. With the player idle, server console:

```text
set feather_native_guid_suite 1
WeaponGuidAcceptance recover
WeaponGuidAcceptance status
```

Requires exact unchanged saved state and a matching restored client view. It records recovered_transport_failure and preserves the old failure rather than rewriting it as a completed native run. It cannot create a fresh loadout or clear a frozen runtime.

Only after recovery is confirmed:

```text
set feather_native_guid_suite 1
WeaponGuidAcceptance transport
WeaponGuidAcceptance status
```

This validates1800synthetic report rows without native creation, inventory edits or equipment release. Expect kindreport_transport_only / phasetransport_complete. It is not a repeated weapon matrix or a new native acceptance claim. No visual confirmation is required for synthetic data.


2026-11-09 LIVE: read-only recovery confirmed unchanged saved state and active original loadout. The standalone transport check then received all1800synthetic rows, completed with zero report-delivery retries and zero mutation retries. Historical native-run detail loss remains recorded separately; transport_complete does not certify a new native creation run.


### Production consolidation — 2026-11-09

All firearms now use one inventory GUID insertion, record update/readback, explicit point activation, captured identity, maintenance and exact-GUID cleanup implementation. Same-model hand pairs require one inventory-slot separation before the common activation sequence. Neither model name nor permanent wear selects another creation mechanism. Primary readiness is checked before Offhand activation. Model grants/removal and legacy inventory equip/selection are removed from this firearm factory. Unknown insertion/move outcomes remain held; there is no fallback or native retry. Explicitly disabled GUID ownership refuses firearm creation.

Materialization uses `native_inventory_guid` for every firearm. The acceptance runner invokes the ordinary scoped factory directly with a temporary context guard; no candidate policy parameter exists. Its report identifies `native_inventory_guid_v1`. Existing report-only transport and prior failure archives are preserved. No clip/type/ammo-total setters or SQL changes were introduced.

Offline: 239 isolated Lua specs/runtime syntax and 7 JavaScript checks pass; Inventory Lua plus 41 Python regressions pass. Includes mixed four-slot GUID identity, clean/worn matching pairs, bounded readiness/identity loss, unknown move ownership retention, exact cleanup with a foreign same-model copy, obsolete strategy rejection and all supported attachment reconstructions. RedM end-to-end production matrix remains pending; the historical 1800-case progress and separate successful transport check are not relabeled as that result.

Deployment batch: `C:/coding/deployments/guid-production-2026-11-09`, six Weapons runtime files only. No manifest/config/Inventory/database change; no refresh required for this patch. Keep the normal owner settled, seal/release before stopping, install with Weapons stopped, start Weapons and reconnect once, then run the automated matrix with the player idle. Require complete/restored/cleanupComplete and a final original-loadout draw check before recording visual pass. No repeated manual weapon-position matrix.


### 2026-11-09 unified production GUID engine acceptance LIVE PASSED

User supplied actual native_creation run completion: passed1800/total1800/receivedCases1800, phasecomplete, cleanupCompletetrue, restoredtrue, reportDeliveryRetries0, automaticRetries0 and automaticMutationRetries0. The normal equipment dry-run also reports final seal/owned cleanup/server release/fresh same-session restore PASS with no equipment/ammo economic writes. User recorded visualpass and status retained complete/1800/restored/cleanuptrue. This closes the final end-to-end production creation matrix, bounded report delivery, original-loadout restore/comparison and short visual gate. It is a new native_creation result, separate from the historical transport failure and synthetic transport-only proof; those records remain preserved. The detailed report remains native-guid-acceptance-report.json in the server Weapons resource; this documentation records supplied console evidence, not a locally retrieved report.

Post-run F8 confirms Jane ACTIVE with2ownedcopies, idle/nonquiescing/nonreceiving runtime, active ammo with pending/closing/deathClosingfalse. Character6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb, session45318af3-dcb5-11f1-9f05-e0d55eaa2deb, epochending1794280675:2912132:1. Ledger57 unchanged: revolverregular1, repeaterregular1, shotgunregular0, allotherpools0. Normal runtime cleanupCompletefalse is expected while the restored loadout owns2copies; the test report cleanupCompletetrue describes temporary suite copies. No further deployment, restart, SQL or repeated matrix is needed for this accepted gate.

Scope remains24firearms/1800pairwise and representative four-slot clean/customized cases, plus a final original-loadout draw check; this does not claim exhaustive four-way permutations or visual animation inspection of every temporary case. Commit/version/PR preparation remains separate and has not been performed by recording this result.
