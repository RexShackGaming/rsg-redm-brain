---
title: Feather Character
---

# Feather Character

Feather Character owns Character creation, selection, UUID identity, profiles, appearance, activation, logout, death/respawn, and position synchronization.

## Installation and settings

This version of Character still requires [Legacy: Menu v1](/api/resources/Menuv1) (`feather-menu`). [Menu v2](/api/resources/Menuv2) is the official system for new Feather development, but Character's existing menu calls must be migrated before its Legacy dependency can be removed.

```cfg
ensure oxmysql
ensure feather-core
ensure feather-menu
ensure feather-character
```

Important `config.lua` settings include the Contract version, logging, appearance document limit, position sync interval, death/doctor behavior, spawn points, maximum Characters, profile input limits, deletion recovery, creation cameras, and arrival locations. Keep `Config.DevMode = false` in production.

## Server contract

```lua
exports['feather-character']:GetCapabilities()
exports['feather-character']:GetHealth()
exports['feather-character']:AwaitReady(timeoutMs?)
```

Character installs its versioned providers into Core. Other resources should consume the provider contract or Core session context rather than query Character tables.

## Client utilities

**Signatures**

```lua
exports['feather-character']:TeleportToCoords(coords, options?)
exports['feather-character']:RegisterLogoutCheckpoint(spec)
```

**Example**

```lua
local moved = exports['feather-character']:TeleportToCoords(
  { x = -273.91, y = 794.71, z = 118.66, heading = 158.85 },
  { fade = true, ground = true }
)
```

Teleportation and logout checkpoints are client-only. Character identity and profile mutations remain server-authoritative.

## Events

Consumers should prefer the current Contract 1/Core session facts over legacy `Feather:Character:*` compatibility events. Always use the UUID Character ID as durable identity; a player source is only a temporary connection address.
