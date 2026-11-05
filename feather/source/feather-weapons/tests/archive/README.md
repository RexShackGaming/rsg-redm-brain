# Historical test fixtures — not runtime

Archived 2026-10-17 after native-only cutover. These are retired source bodies
and temporary test manifests, kept solely for isolated historical regressions.
They are not supported gameplay, migration, fallback or deployment options.
Never copy an archived manifest to fxmanifest.lua and never add archive paths
to the active manifest. Do not deploy tests/archive to the game server.

Tests reading these fixtures preserve past evidence, not native non-firearm
parity or backward compatibility. Native runtime tests load the real manifest
and assert that the old globals/providers are absent. Old code may depend on
obsolete contracts and is executed only in isolated mocks, never alongside the
native host.

Moved from resource root (same relative layout inside this archive):

```text
server/imports.lua
server/adapters/inventory.lua
server/adapters/feather_inventory.lua
server/services/runtime.lua
server/services/equip.lua
server/services/ammo.lua
server/services/maintenance.lua
server/services/repair.lua
server/services/reconciliation.lua
client/imports.lua
client/guid_weapons.lua
client/native_maintenance.lua
client/native_weapon_coordinator.lua
client/firearm_pools.lua
client/main.lua
client/dev_shot_death.lua
client/native_probe.lua
server/jane_ammunition_economic.lua
server/jane_ammunition_zero.lua
server/jane_ammunition_readonly.lua
client/jane_ammunition_economic.lua
client/jane_ammunition_zero.lua
client/jane_ammunition_startup.lua
fxmanifest.jane-economic.lua
fxmanifest.jane-readonly.lua
fxmanifest.jane-startup.lua
fxmanifest.jane-zero.lua
```

No items, database rows, receipts, provenance or external audit files moved or
deleted. Git history and this archive retain the source; runtime originals were
removed. The live server may retain old unreferenced copies until an operator
removes exactly this list after verifying the active native-only manifest.
No server cleanup or database wipe was executed by this archival work.
