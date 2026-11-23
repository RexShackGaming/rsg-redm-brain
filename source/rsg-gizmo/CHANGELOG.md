# Changelog

All notable changes to rsg-gizmo. Newest first.

## 3.1.0

### Added
- Roll control (hold C, arrows/wheel) when `rotation = 'all'`
- Grid and angle snapping (X): `Config.Snap`, option `snap`
- Undo / redo (Z / V) with per-session history: `Config.History`, `Config.HistoryDelay`
- `PlaceMany(items, options)` export and `rsg-gizmo:client:placeMany` event: place a heading-only group of props together
- `GroupTransform` (client + server) and `IsGroupPlacementValid` (server) so the server rebuilds group positions itself
- Option `maxSlope` (surface steepness check) and `showRange` (ground ring for `maxDistance`)
- Placement memory: starts from the last rotation/mode/snap per calling resource and model (`Config.Remember`, option `remember`)
- `Config.Limits`: cap on any `maxDistance` and world height range checked on the server
- `/gizmotestgroup` admin command; 7 new locale keys in all 11 languages

### Changed
- The camera ray now looks through the player and their mount, so props no longer land on your horse
- Test command places with `maxSlope = 35.0`

## 3.0.2

### Fixed
- `Edit()` now restores the entity's frozen state (it was left frozen after every edit)
- `Edit()` with `rotation = 'z'` no longer flattens an entity's existing pitch/roll
- Pitch/roll no longer grow without limit when tilting with `rotation = 'all'`
- Model request is released when loading times out
- `IsPlacementValid` ignores a non-number `maxDistance` instead of erroring

### Changed
- Confirm/cancel ignored for `Config.InputGrace` ms after a session opens (the key that opened it could place/cancel instantly)
- "Invalid placement" error notification throttled to once per 1.5s
- HUD key captions come from `Config.KeyLabels`

### Performance / cleanup
- Blocked-control list built once instead of two loops every frame
- Removed duplicate rounding work in the HUD update

## 3.0.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
