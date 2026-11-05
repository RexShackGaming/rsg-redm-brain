# Weapons 0.17.0 — alpha checkpoint PR

Prepared 2026-10-16. No commit/push/PR created. User already submitted Admin;
leave that PR alone. Merge/deploy Inventory0.6.0 first, then this checkpoint.
Alpha test-server scope, not a full native production release.

## Title

```text
feat(weapons): checkpoint native maintenance attachments and lifecycle recovery
```

## Summary

```text
- Persist native wear through checkpoints, equipment changes, orderly shutdown, logout and death recovery.
- Add canonical repair and attachment intents with material conservation and fresh-session reconstruction.
- Track native child identity and supported attachment mappings without adopting unrelated replacement entities.
- Improve interrupted-operation recovery, storage guards, provenance and scoped administrator evidence integration.
- Document accepted alpha gates and limitations; retain opt-in controls and bump Weapons to 0.17.0.
```

## Scope and limits

Current durable Inventory snapshots remain authoritative. Native reconstruction,
wear sealing and current-session reservations are separate from economic writes.
Unknown post-dispatch results retain blocked/retired context instead of replaying
economic intent. Retirement does not fabricate final observations or claim native
cleanup confirmation on disconnect. Native provenance observers do not provide an
atomic cross-resource outbox or exactly-once delivery.

Representative Carbine and Schofield attachment tests and earlier catalog proof
are reused; catalog enrollment is not a claim of a new live cycle for every pair.
Customized identical native pairs/unsupported mappings, cross-owner custody and
native destruction remain restricted or refused. Shops/licenses/jobs/crafting,
broader multiplayer failure testing and production probe removal remain follow-up.

Existing native host/ammo gates remain false and exact alpha character remains
nil in defaults. New config defaults to merge only if needed:

```lua
NativeAlphaRepairEnabled = false,
NativeAlphaMaintenanceEnabled = false,
NativeAlphaPeriodicWearEnabled = false,
NativeAlphaPeriodicWearIntervalMs = 60000,
NativeAlphaLifecycleWearEnabled = false,
```

Native attachment/evidence/probe convars keep explicit opt-in/default0 behavior.
Existing DevMode=true is preserved for alpha, not a production-safe-default claim.
Do not replace customized config.lua or activate experimental flags for merging.

## Checks on 2026-10-16

-126 Lua specs PASS; all client/server/shared Lua plus config/manifest syntax PASS.
- Seven Node contract/static tests PASS; git diff --check PASS.
- Companion Inventory full Lua runner, two UI tests, lint/build and package
  verification PASS. Its local Node/pnpm versions differ from declared engines;
  see Inventory PR preparation note.
- Prior live evidence includes equipment/stop/logout/death wear, periodic change
  and no-op checkpoints, repair payment, representative attachment install/return
  and retained wear, interrupted-transfer/attachment recovery, storage veto,
  provenance deposit/pickup and own-current Admin evidence hold/release.
- No fresh live/native test performed for PR preparation. Mock/static checks do
  not establish production latency, full native catalog behavior or multiplayer
  contention. Prior queued Admin audit is not independent durable delivery proof.

## Exact changed runtime deployment files

Repository `C:/coding/feather-scripts/feather-weapons`:

```text
fxmanifest.lua
client/character_ammunition_checkpoint.lua
client/character_ammunition_client_runtime.lua
client/character_ammunition_controller.lua
client/character_ammunition_creation_native.lua
client/character_ammunition_host.lua
client/character_ammunition_loadout.lua
client/character_ammunition_native_owner.lua
client/character_ammunition_routes.lua
client/character_ammunition_session.lua
client/character_ammunition_startup.lua
client/native_equipment_actions.lua
client/character_maintenance_native.lua
client/native_maintenance_checkpoint.lua
server/adapters/character_ammunition_inventory.lua
server/main.lua
server/services/api.lua
server/services/attachments.lua
server/services/character_ammunition_dispatch.lua
server/services/character_ammunition_runtime.lua
server/services/evidence.lua
server/services/native_equipment_transition.lua
server/services/ownership.lua
server/services/provenance.lua
shared/character_ammunition_dispatch.lua
shared/character_ammunition_materialization.lua
shared/character_ammunition_runtime.lua
shared/character_ammunition_transport.lua
shared/definitions/attachments.lua
shared/character_attachments.lua
shared/character_lifecycle_wear.lua
shared/character_maintenance.lua
```

Merge the five config defaults above separately. Docs/tests do not go to server
runtime. No native proof resource or audit snapshots belong in this PR/deployment.
No new database migration files in this checkpoint diff.

Prepare-stop active scoped owner with current player source and wait for PASS;
stop Weapons before updating/restarting Inventory. Deploy companion files, run
server-console refresh (new scripts/manifest), restart Inventory and restore
dependent Admin/Shops, then ensure Weapons. Preserve server flags/config.
Read-only postdeploy native status/maintenance checks should match the saved
loadout; do not create new fixtures or repeat accepted payment matrices by default.

## PR relationships

Requires Inventory0.6.0 native transaction/guard work. Submitted Admin PR consumes
the evidence status/change exports; that scope remains own-current actor only.
Link companion PRs once their URLs exist. Alpha acceptance does not wait for
unimplemented production roadmap features, but known limits must remain visible.
