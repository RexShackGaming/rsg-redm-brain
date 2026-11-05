---
title: Feather World
---

# Feather World

Feather World owns population density, map helpers, interior compatibility fixes, ambient-wagon cleanup, and random-loot prompt suppression.

## Settings

`Config.DisableRandomLootPrompts`, `EnableInteriorFixes`, and `EnableWagonFix` toggle compatibility behavior. `DensityMultipliers` independently control ambient/scenario pedestrians, animals, and vehicles. Keep `DevMode` off in production.

## Public API

**Server**

```lua
exports['feather-world']:GetCapabilities()
exports['feather-world']:GetDensityMultipliers()
```

**Client**

```lua
exports['feather-world']:SetFogOfWar(enabled)
exports['feather-world']:DisplayWorldRadar(enabled)
exports['feather-world']:StartGpsRoute(colorName, waypoints)
exports['feather-world']:StopGpsRoute()
```

The DataView and game-event runtime files are internal compatibility implementations, not supported cross-resource APIs.
