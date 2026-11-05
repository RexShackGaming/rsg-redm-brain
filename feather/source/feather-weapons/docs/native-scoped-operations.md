# Scoped native Weapons operations

This is the accepted two-character development rollout, not production enrollment.
Do not deploy anything from `tests/archive` as runtime code or a manifest.
Archived pool-increase/committed-spend recovery is a behavior reference only;
the current ledger and durable receipt authority must remain the only economy.

## Configuration versus replicated flags

The repository `config.lua` intentionally defaults NativeAlphaRuntime,
CharacterAmmoTransportEnabled and lifecycle wear off, with no enrolled character.
Preserve the server's reviewed scoped configuration when copying files. Do not
overwrite it with the default template and expect console convars to enable it.
Never replace exact enrollment with wildcard/global authorization.

For the already configured John/Jane cohort, set these before starting Weapons
or before either client enters a character:

```text
setr feather_native_knife 1
setr feather_native_melee 1
setr feather_native_throwable 1
setr feather_native_throwable_pickup 0
```

Persist only deliberately approved values in the server configuration; console
settings alone do not survive a full server restart. Pickup remains a separate
opt-in test gate. Issuance, budget and projectile-probe gates stay off. Enabling
companions after an owner has already opened does not rebuild that loadout.

## Updating or restarting

1. For active owners, run `WeaponNativePrepareStopAll`; require aggregate PASS
   and `WeaponNativeShutdownStatus` phase `ready` before stopping Weapons.
2. A frozen or failed owner is not ready: fully quit its RedM client. Do not
   force-thaw it, blanket-remove weapons or retry an uncertain economic request.
3. New runtime scripts or manifest changes require server-console `refresh`
   before restarting. Existing-file-only updates do not require refresh.
4. Inventory or Character updates require both clients fully disconnected first.
5. After reconnect, obtain new source IDs; never use a remembered ID for a grant,
   funding operation or equipment mutation.

Do not alter companion flags underneath active owners as a cleanup mechanism.
Do not use an unprepared restart to stand in for an approved crash test.

## Resuming after a prepared shutdown

PrepareStopAll admission stays latched until Weapons restarts; quitting clients
does not clear it. If clients return to clean closed/zero-copy Weapons owners
with readiness retries exhausted after the previous prepared shutdown, inspect
WeaponNativeShutdownStatus. With those owners still cleanly closed, restart only
feather-weapons to reopen admission and renew readiness. Do not rerun PrepareStopAll
as a startup command, force-unlatch a live owner, change companion flags mid-owner,
or grant replacement items. This recovery restored the accepted two-player
checkpoint on 2026-10-20. Unexpected active/frozen/uncertain owners require inspection
before any restart; this is not a general bypass for readiness failures.

## Current accepted durable checkpoint

2026-10-20 lasso addition: John now also owns/equips utility_lasso item171rev0,
serial FW-LASS-6AD6F519-0580E8-0001 in weapon_utility. The scoped utility convar is1;
pickup remains0. Lasso issuance/replay, exact cleanup, menu re-equip, restart,
death/doctor/logout and observer invariance passed. Reuse original rope gameplay
acceptance in lasso-live-gate.md; do not run its archived grant commands. Other
utility models and broader production enrollment remain unapproved.

John: character `4560a489-ca6c-11f1-9ad4-e0d55eaa2deb`, ledger16/Tomahawk1,
carrier165rev0, melee160–164rev0, firearms155rev3/158rev5.
Jane: character `6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb`, ledger35/repeater1,
Tomahawk runtime0, firearms112rev2/134rev8. Her raw durable Tomahawk key may be
absent; the canonical reader normalizes absent admitted pools to zero.
These are checkpoints, not values to force into SQL.

The read-only companion audit is Inventory's
`docs/native-tomahawk-durable-audit.sql`. Both accepted pickup receipts remain
claimed: spend:165:13 at14 and spend:165:15 at16. Receipt replay must never refill
a later spent balance. No additional grant is needed to preserve this checkpoint.

Accepted: own-character regular-Tomahawk pickup, funded equipment roundtrip,
prepared restart, logout, death/doctor and settled full-client disconnect, with
observer isolation. Automated unknown-reply/replay/reconnect checks also pass.
Not live-accepted: server/process crash, in-flight SQL ambiguity, cross-player
contention or exact landed-projectile provenance. Do not broaden rollout based
on these scoped results.
