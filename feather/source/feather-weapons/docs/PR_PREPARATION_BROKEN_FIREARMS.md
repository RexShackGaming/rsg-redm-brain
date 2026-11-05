# Broken-firearm alpha follow-up to PR #38

Reviewed 2026-10-16 against local checkpoint 8c24155. No commit, push or PR created.
Scope is opt-in alpha/test servers, not general native production readiness.
Version remains 0.17.0; no version bump made during this review.

## Proposed title

```text
feat(weapons): persist broken firearms and promote healthy offhands
```

## Summary

```text
- Persist broken wear and remove unusable equipment during periodic and lifecycle checkpoints.
- Promote a healthy compatible offhand atomically when the primary breaks.
- Authorize only reserved death-time assignment changes and require matching Inventory contracts.
- Marshal native wear setters as floats, including integer-valued zero and one.
- Add rollback, compatibility and multiplayer-isolation regressions; record scoped live acceptance.
```

## Verification

- 128 Lua specs plus runtime syntax and 7 Node tests pass; git diff --check passes.
- Live shoulder break, equip refusal, normal repair and healthy re-equip accepted.
- Live synthetic death report committed broken shoulder wear, detached it, excluded
  it after doctor recovery, and allowed normal repair/re-equip. This is not native
  dead-setter or native damage-generation proof.
- Live periodic mixed-sidearm break promoted pristine Cattleman112 from offhand
  to primary at unchanged revision1; broken Schofield134 persisted at revision5.
  Normal repair/re-equip restored Schofield revision6 with zero wear.
- Temporary native/synthetic break commands and helpers are removed. No audit
  baselines or fixture inventory items were deleted.

## Limitations

Funded-ammo death, death-time promotion, same-model promotion and full independent
serial/attachment/material conservation are not live accepted by these gates.
Mocked DB/native tests do not replace those gates. Broader rollout, custody,
destruction and multiplayer native contention remain outside this PR.

## Deployment

Deploy companion Inventory changes first while Weapons is stopped. Prepare-stop
the current player and wait PASS before stopping Weapons; restart Inventory and
affected dependents, then start Weapons. Existing scripts only: no refresh,
config replacement, migration or UI build is required by this delta.

Weapons runtime files changed since #38:

```text
client/character_maintenance_native.lua
server/adapters/character_ammunition_inventory.lua
server/services/character_ammunition_runtime.lua
server/services/native_equipment_transition.lua
shared/character_lifecycle_wear.lua
```

If the server previously received temporary test hooks, also copy the cleaned
client/character_ammunition_creation_native.lua,
client/character_ammunition_native_owner.lua and client/character_ammunition_startup.lua.
These cleanup files match the checkpoint, so they do not appear in the PR delta.
Keep temporary fixture convars zero. Preserve all private audit baseline files.
