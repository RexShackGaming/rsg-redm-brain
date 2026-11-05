# Medical client lifecycle adapter

## Shared-pool native Weapons acceptance

The existing adapter also passed scoped shared-pool Weapons testing on
2026-10-11: persisted death sealed the native ammo runtime, and acknowledged
doctor recovery restored it in a fresh epoch without reopening Inventory panels.
In the one-carried-Regular-round case, recovery retained that round at ledger16;
unloading afterward returned it to loose Inventory at ledger17. A separate
zero-carried case remained ledger21 across dead revision5/alive revision6.
Final Inventory verification confirmed the expected saved equipment, loose ammo
and receipts. No per-weapon ammo quantities or Medical-owned ammo writes were
introduced. These are narrow live gates, not exhaustive final-shot/in-flight
lifecycle races, abnormal resource-stop or multiplayer acceptance.

Local regression: `lua tests/client_lifecycle_spec.lua` from the Medical resource
root verifies identity/revision rejection, notification deduplication and copy
isolation. Medical's existing server condition/recovery authority is unchanged.

## Adapter contract and earlier acceptance

Medical adapts its existing medical.condition.get.v1 and recovery.ack.v1
snapshots into a client cache. Alive recovery is published after successful
server acknowledgment, not after native resurrection alone. Snapshots carry
character/session identity and condition revision; stale publications are
rejected and repeated identical states do not emit duplicate notifications.

Consumers read Medical's GetLifeState Result envelope and observe
feather-medical:client:condition-changed.v1. Weapons suspends native sampling
while dead and reconciles saved ownership after recovery. Lua syntax and the
Medical lifecycle harness pass. The refactored single-M1899 no-fire death and
doctor recovery path passed live testing on 2026-10-07: dead revision 7 to
alive revision 8, restore attempt 1, Express 8 conserved in saved/native state.
Post-recovery firing and staff revive also passed: one shot reduced Express
8 to 7; staff recovery restored on attempt 1 at alive revision 10, preserving
saved/native Express 7. Weapons restart while dead and subsequent doctor
recovery also passed: restoration deferred at dead revision 11, then restored
saved/native Express 7 on attempt 1 at alive revision 12. Dead reconnect and
subsequent doctor recovery also passed: new session, same dead episode/revision
13, then alive revision 14 with Express 7 restored on attempt 1.
Medical restart while dead and subsequent doctor recovery also passed: same
dead episode/revision 15 and deadline, then alive revision 16 with Express 7
restored on attempt 1. One immediate-shot/death/recovery attempt also passed:
Express 7 to 6, dead revision 17, then alive revision 18 with saved/native
6 restored on attempt 1. Exhaustive timing-race coverage and multi-weapon
conservation remain pending.

The existing medical.condition.changed.v1 durable Core broker event remains
unchanged and server-side. Character retains only its existing context and
native condition/recovery application APIs; Inventory and Core need no changes.
