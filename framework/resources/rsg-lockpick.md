# rsg-lockpick

Version 3.1.0. Lockpicking minigame for RSG Core

**Lockpicking minigame for RedM (RSG Core).** > A lightweight NUI lockpicking game (pick + cylinder) you can start from any script, with an optional **server-issued attempt** mode that adds lock presets, skill-based difficulty, lockpick wear and breakage, and lawman alerts. Version 3.1.0 · full developer reference in [DOCS.md](DOCS.md). - **rsg-core** (framework, also provides the locale loader)

Source: https://github.com/Rexshack-RedM/rsg-lockpick

**Dependencies:** `rsg-core`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-lockpick']:Name)

**server:** `CancelAttempt(src)`, `HasActiveAttempt(src)`, `StartAttempt(src, data, cb)`

**client:** `CancelLockpick()`, `IsLockpicking()`, `Lockpick(options)`

## Net events registered

**server:** `rsg-lockpick:server:ticketResult`

**client:** `rsg-lockpick:client:ticketCancel`, `rsg-lockpick:client:ticketStart`

## Event handlers

**server:** `rsg-skills:server:ready`

**client:** `rsg-lockpick:client:openLockpick`

## Public (table) functions

**shared/config.lua:** `Config.Clamp(opts)`, `Config.Build(presetName, overrides)`
