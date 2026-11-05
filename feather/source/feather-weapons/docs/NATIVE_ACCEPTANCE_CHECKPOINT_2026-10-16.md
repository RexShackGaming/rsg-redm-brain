# Native alpha acceptance checkpoint — 2026-10-16

This consolidates the post-commit test evidence. It does not expand enrollment or
claim production readiness. Detailed chronology remains in native-broken-firearm-alpha.md;
authoritative remaining work is in feather-framework-docs.

## Accepted additions

- Funded no-shot death: acknowledged regular repeater pool2/revision34 survived
  sealing and doctor recovery without replay/adoption.
- Final-shot death: probe observed native2→1 while baseline remained34; no flush
  requested. Death transaction :3786 committed wear and sealed revision35/pool1;
  doctor alive20 restored ACTIVEidle/revision35/pool1. Carbine135 advanced23→24.
- Synthetic death-primary break: :4050 committed Schofield1346→7/condition0,
  promoted healthy Cattleman112 to primary, and preserved ledger35/repeater1.
  Doctor alive22 restored only112 at point2 with revision2/prior wear unchanged.
  This is real SQL/recovery from synthetic broken wear, not native damage proof.
- Post-promotion repair: :4175 committed normal one-oil repair; independent134rev8/
  alreadyserviced and native offhand re-equip/allwear0.112rev2 wear unchanged.

No independent oil0 readback was supplied by abbreviated alreadyserviced status.
Cattleman112 is not pristine: dirt1/degradation0.00871666707098 were already
recorded before these promotion/recovery gates. Its original wear cause is unproven.

## Diagnostic meaning

Recovery status top-level ledgerRevision/itemRevisions are loadout-opening
snapshots. currentAcknowledged is the current server runtime acknowledgment,
not a new SQL query. Compare the latter with a fresh recovery baseline; do not
interpret opening revision34/current35 as lost ammunition.

## Cleanup and current state

Temporary funded-shot and death-promotion methods, commands, state and fixture-only
tests are removed; owning client files match committed versions. Permanent tests
remain (128 Lua specs and 7 Node tests last passed after cleanup). Inventory has
no new runtime delta. User reports cleanup files updated after relevant gates;
no new deployment is required by this documentation checkpoint. Preserve all
private named audit baselines; no items or audit files were deleted.

Last supplied native state:112rev2 primary with recorded wear;134rev8 healthy
offhand. Latest directly observed ammo baseline35/repeater1 preceded repair and
re-equip; those reported no ammo economic writes, but no new full baseline was
supplied afterward. Current source was3; do not assume it survives reconnect.

## Next work

Prioritize actual two-player isolation/contention evidence before broader
enrollment. Existing coroutine tests are not live multiplayer proof; exact-Jane
scope must not simply be widened to everyone. Prepare explicit authorized
per-character enrollment/isolation before a live second-player mutation test.
Abrupt-stop/crash behavior and unsupported identical-model customization remain
separate work. No repeat death/repair grants or test hooks are requested here.
