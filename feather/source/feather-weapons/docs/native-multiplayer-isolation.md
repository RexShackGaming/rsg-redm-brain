# Native multiplayer isolation — automated checkpoint

2026-10-16, after merged local checkpoint PR38 (`8c24155`).

The real equipment transition coordinator and periodic scheduler are exercised
with two independent sources/characters and deliberately interleaved callbacks.
Provider/native boundaries are mocked; this is not live two-player/SQL acceptance
and does not broaden the single-configured-character native runtime enrollment.

Covered:

- One player's pending provider call does not stop another player's transition.
- Cross-player tickets, identities and forged actor-source commits are refused.
- Duplicate/overlapping same-player release cannot dispatch a second write.
- Cancelling one player leaves the other player's restored state untouched.
- Late confirmed, refused and uncertain provider results preserve their actual
  outcome without rebuilding a cancelled owner.
- Retired source/session reuse rejects old release/cancellation even when ticket
  text is reused by the mocked generator.
- Periodic busy checks, deadlines, cursors and persistence counters stay per player;
  foreign completion/cleanup cannot change another player's scheduler state.

127 Lua specs and seven Node tests PASS; diff checks PASS. No runtime change,
server deployment, config/flag changes, version bump or new fixture is needed.
The test file is `tests/native_multiplayer_transition_isolation_spec.lua`.

Remaining: live multiplayer enrollment/transaction contention and actual SQL/native
fault injection remain separate. Broken-condition final wear still deliberately
refuses release until an explicit gameplay policy is chosen; this test does not
silently decide whether to auto-unequip a broken firearm.
