# Scoped attachment commit/disconnect recovery gate

Follow-up normal reconnect accepted without resource restart: Character playable
then Weapons startup, sessionc8733dfa/epoch23773645:2 ACTIVEidle1copy112rev1/
pristine,ledger33/allammo0/no pending/closing. No elapsed selection timing, so
not a specifically timed >30s live proof. Earlier injected attachment recovery
still accurately labelled fresh-resource, not retroactively automatic.

Final live baseline22552387:1: ACTIVEidle1copy112rev1/pristine,ledger33/allammo0,
no pending/closing/deathClosing.135lastconfirmedrev13 empty/unequipped/material1.
Interrupted payment + fresh-resource recovery + return + baseline accepted in
observed scope. Intermediate stop/flag acknowledgements not supplied. Automatic
reconnect without restart remains unconfirmed; no repeated payment gate needed.

Live ordinary removal PASS after recovery: SQL:4413/23queries,135rev13/empty,
material1, primary112rev1+shoulder135rev13 at epoch21775483:2. Finish shoulder
unequip/orderly-stop/temporary flags0/primary baseline; no new payment test.

Live recovery snapshot accepted after resource restart: source3, session41b36599,
epoch21105511:1 ACTIVEidle2copies/ledger33/allammo0;135rev12/savedwide/material0,
shoulder12, dirt~0.2 unchanged;112rev1 primary/pristine. No repeat install reported.
Not automatic reconnect acceptance or independent exact-child visual confirmation.
Next ordinary remove135 once, confirm rev13/empty/material1, then baseline cleanup.

Live checkpoint: confirmed SQL COMMIT :3965/16queries and intentional old-session
retirement observed. Reconnect source3 native owner never started; no durable
recovery snapshot supplied, do not repeat install. Character late readiness is
consistent with inspected startup30s expiry; fixed client wait,121Lua/7Node pass.
Additional deployment ONLY client/character_ammunition_startup.lua (existing file,
no refresh). Keep probe0; restart Weapons in observed no-owner state and read
135/current scope. Label result fresh-resource recovery, not automatic reconnect.

2026-10-15: implemented and automatically tested, live pending. Reuses accepted
Carbine sight reconstruction/payment mechanism; not a catalog retest.

## Deployment and preflight

Weapons ONLY: `server/services/native_equipment_transition.lua`. Includes the
late-reply request-isolation fix. Existing file, no refresh or Inventory/UI delta.
PrepareStop current player, wait PASS, stop Weapons, copy file. Preserve config.
Before ensure Weapons set these existing replicated flags to1:
feather_native_guid_ownership, feather_native_saved_attachments,
feather_native_attachment_transactions. Keep catalog/representative probes off.
Set server-only feather_native_attachment_disconnect_probe0 initially.

After ensure, run `WeaponNativeAttachmentStatus <current-id> 135`.
Expected last known baseline: revision11, attachments empty, material1; Carbine
unequipped, original112 primary. Actual snapshot controls next step. No new grant.

## One authorized fault-injected install (only after preflight reviewed)

Equip135 in weapon_shoulder, confirm current ACTIVE owner. Use configured
gunsmith station and normal authorization. Then server console:

```text
set feather_native_attachment_disconnect_probe 1
WeaponNativeArmAttachmentDisconnect CURRENT_ID 135 install carbine_wide_sight
WeaponNativeAttachmentChange CURRENT_ID install 135 carbine_wide_sight
```

Arm is one-use/current epoch/exact item/action/attachment, expires60s. Matching
attempt consumes arm before storage. Only confirmed commit, still-current scoped
session and enabled gates cause DropPlayer. Disabled/unknown/refused storage does
not intentionally disconnect. Wait for Core retirement bounded5s; if unconfirmed
fail closed/no retry. Expected log COMMIT then OBSERVED retired, NOT normal UI PASS.
Do not retry install if disconnected or result uncertain.

Turn probe0, reconnect, obtain CURRENT server ID (may change). Read-only status
and native maintenance/entity status should show one saved sight, material0,
one attachment revision increase (plus a wear revision only if final wear changed),
unchanged original112 and ammo ledger33/all0. Check exact owned child/stock and
readable maintenance; these outputs are required, not assumed by injection logs.
Recovery uses durable metadata, never replays install/payment. Then ordinary
remove/return once, confirm material1/empty attachments, unequip shoulder and
orderly stop before disabling saved/GUID flags and restoring primary baseline.

## Automated evidence and limits

All120 Lua specs and7 Node tests pass. Concrete binding coroutine reproduces
old-session reply/source reuse and verifies new dryrun independence; one-shot
wiring tests default-off/player-arm refusal/expiry, confirmed write before drop,
Core retirement before completion, duplicate acknowledgement no repeat write/drop.
Storage/native/DropPlayer are mocked. No live SQL/native interruption acceptance
until the explicit gate outputs arrive. No new weapon/material grants required.
