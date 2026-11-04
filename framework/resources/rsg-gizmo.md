# rsg-gizmo

Version 3.0.1. Standard prop placement gizmo for the RSG Framework

The standard prop placement gizmo for the RSG Framework. Any script that needs a player or admin to put a prop in the world calls rsg-gizmo, gets back coords + rotation, and does its own saving. **Version:** 3.0.0 · **Dependencies:** rsg-core · **Full API:** [DOCS.md](DOCS.md) - One blocking export: `exports['rsg-gizmo']:Place(model, options)` → `{ coords, rotation, heading }` or `nil`

Source: https://github.com/Rexshack-RedM/rsg-gizmo

**Dependencies:** `rsg-core`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-gizmo']:Name)

**server:** `IsPlacementValid(src, coords, maxDistance)`, `SanitiseRotation(rot)`

**client:** `Cancel()`, `Edit(entity, opts)`, `IsActive()`, `Place(model, opts)`

## Net events registered

**client:** `rsg-gizmo:client:test`

## Event handlers

**client:** `rsg-gizmo:client:place`
