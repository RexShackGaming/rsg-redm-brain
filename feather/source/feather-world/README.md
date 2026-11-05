# Feather World

Feather World owns shared RedM world behavior for Feather Framework:

- population density;
- curated interiors and IMAP states;
- ambient stuck-wagon cleanup;
- player input and HUD safeguards;
- random-loot prompt suppression;
- minimap, radar, and GPS helpers.

Start it after `feather-core`. Core does not depend on this resource and remains operational when World is stopped.

## Configuration

All server-owner settings are documented inline in `config.lua`.

Configuration changes require restarting `feather-world`. Manifest or version changes also require `refresh` first.

### General and player runtime

| Setting | Default | Purpose |
| --- | ---: | --- |
| `DevMode` | `false` | Enables diagnostic logging and development-only commands. |
| `PlayerRuntime.clearChallengeFeed` | `true` | Clears unused Rockstar challenge notifications. |
| `PlayerRuntime.disableWeaponSoftlockControls` | `true` | Disables controls associated with known weapon/input softlocks. |
| `PlayerRuntime.disableFrameworkHudControls` | `true` | Prevents Rockstar HUD shortcuts from conflicting with Feather interfaces. |
| `PlayerRuntime.suppressRandomLootPrompts` | `true` | Hides ambient corpse and saddlebag loot prompts. |

### Map

| Setting | Default | Purpose |
| --- | ---: | --- |
| `Map.gpsRouteColor` | `6` | RedM route color used by `StartGpsRoute`. |

### Interiors and IMAPs

| Setting | Default | Purpose |
| --- | ---: | --- |
| `InteriorFix.enabled` | `true` | Applies the curated production interior and IMAP catalog. |
| `InteriorFix.startupDelayMs` | `1` | Delay before interior entity-set activation. IMAP states apply immediately. |
| `InteriorFix.expected*` | catalog-specific | Integrity counts used by contract tests. Do not edit unless the catalog changes. |

The catalog contains 35 interiors, 494 entity sets, 400 deterministic IMAP states, and 217 verified English descriptions. Selection data was reviewed against the current [`redm-ipls`](https://github.com/outsider31000/redm-ipls) resource used by the VORP recipe. Coordinates, type hashes, internal names, and RPF names were cross-checked against [`rdr3_discoveries`](https://github.com/femga/rdr3_discoveries/tree/master/interiors).

Files are separated by responsibility:

- `client/interiors/definitions.lua`: readable interior definitions, metadata, and selected entity sets;
- `client/interiors/imaps.lua`: one final production state per IMAP hash;
- `client/services/interiorsfix.lua`: activation lifecycle and diagnostics.

Alternative entity sets are not activated automatically because many represent mutually exclusive states such as intact/broken, clean/ransacked, or open/closed.

### Wagon cleanup

| Setting | Default | Purpose |
| --- | ---: | --- |
| `WagonFix.enabled` | `true` | Enables stuck ambient-wagon detection. |
| `WagonFix.checkIntervalMs` | `1000` | Delay between vehicle scans. |
| `WagonFix.orphanCheckIntervalMs` | `5000` | Delay between detached-component scans. |
| `WagonFix.removeOrphanedComponents` | `true` | Removes allowlisted components no longer associated with a vehicle. |
| `WagonFix.componentDistance` | `3.0` | Association radius for known wagon components. |
| `WagonFix.occupantDistance` | `5.0` | Search radius for attached NPC occupants. |
| `WagonFix.networkControl.maxAttempts` | `50` | Maximum bounded network-control attempts before skipping an entity. |
| `WagonFix.networkControl.waitMs` | `10` | Delay between control attempts. |
| `WagonFix.components` | four models | Allowlist of detachable wagon component models. |

Cleanup targets only stopped ambient wagons whose harness horse continues walking. Player-controlled, player-occupied, and mission-owned entities are protected. Arbitrary nearby world objects are not removed.

### Population density

Every `DensityMultipliers` value is enforced each rendered frame. Use `0.0` to suppress a category and `1.0` for the game default. The available categories are ambient and scenario peds, vehicles, parked vehicles, random vehicles, ambient animals, ambient humans, scenario animals, and scenario humans.

## Client exports

- `SetFogOfWar(hidden)`
- `DisplayWorldRadar(visible)`
- `StartGpsRoute(startCoords, finishCoords)`
- `StopGpsRoute()`

Each export returns a result table. Successful calls return `{ ok = true }`. Invalid GPS coordinates return `{ ok = false, error = { code, message } }`.

## Server exports

- `GetCapabilities()`
- `GetDensityMultipliers()`

Both return result envelopes. The density export returns a defensive snapshot rather than the mutable configuration table.

## Development commands

When `Config.DevMode` is enabled, client F8 command `WorldInteriorInspect <interiorId>` prints the selected interior's English name, coordinates, type metadata, entity-set count, and current validity.

## Tests

After startup:

- Server console: `WorldContractSmokeTest`
- Client F8: `WorldClientSmokeTest`

The server test validates capabilities and every configuration section. The client test validates the density loop, catalog counts, player safeguards, wagon cleanup, and map configuration.

Stopping the resource stops its frame loops and cleanup threads without affecting Feather Core readiness.
