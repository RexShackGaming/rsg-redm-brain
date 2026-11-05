---
title: Feather PVP
---

# Feather PVP

Feather PVP owns client-side friendly-fire and player relationship enforcement.

## Settings

```lua
Config.DefaultEnabled = true
```

## Client API

```lua
exports['feather-pvp']:GetState() -> { enabled, paused }
exports['feather-pvp']:SetEnabled(enabled) -> boolean
exports['feather-pvp']:Toggle() -> boolean
```

```lua
local enabled = exports['feather-pvp']:SetEnabled(false)
local state = exports['feather-pvp']:GetState()
```

Run `PvpContractSmokeTest` in F8 to verify the contract.
