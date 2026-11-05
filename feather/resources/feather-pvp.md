# feather-pvp

Version 0.1.0. Client PVP state enforcement for Feather Framework

Owns client-side friendly-fire and player relationship enforcement. Use the client exports `GetState`, `SetEnabled`, and `Toggle`. Test in F8 with `PvpContractSmokeTest`.

Source: https://github.com/FeatherFramework/feather-pvp

## Exports (call as exports['feather-pvp']:Name)

**client:** `GetState()`, `SetEnabled(enabled)`, `Toggle()`

## Commands (RegisterCommand)

**client:** `/PvpContractSmokeTest`

## Public (table) functions

**client/main.lua:** `PVPAPI:updatePVPRelationship()`, `PVPAPI:togglePVP()`, `PVPAPI:setPause(active)`
