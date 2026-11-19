# rsg-targetpractise – Technical Docs

Developer notes for how the resource works internally. For installation and usage, see `README.md`.

## File layout

| File | Side | Purpose |
| --- | --- | --- |
| `shared/config.lua` | shared | All settings |
| `shared/geometry.lua` | shared | Quaternion maths, target pose, face-local conversion, ring scoring, hash normalisation |
| `shared/locale.lua` | shared | Builds the `ui_*` locale table sent to the NUI (key list read from `locales/en.json`) |
| `client/diagnostics.lua` | client | `/targetdiag` report, error capture, shared `TargetPractiseNotify` helper (loads first) |
| `client/projectiles.lua` | client | Shot release detection, knife capture, flight segments, projectile-skipping surface probe |
| `client/client.lua` | client | Target streaming, rsg-target options, placement preview, shot/impact detector, debug drawing |
| `client/leaderboard.lua` | client | Leaderboard NUI open/close and focus |
| `server/server.lua` | server | Placement/pickup transactions, persistence, shot and hit validation, scoring, sync |
| `server/leaderboard.lua` | server | Builds leaderboard rows and range records (never exposes citizen IDs) |
| `html/*` | NUI | Placement panel, bullseye banner, leaderboard |

## Placement flow

1. Player uses the `target` item (or admin runs `/admintarget`). The server checks the item/permission and creates a `pending[src]` request with an expiry.
2. Server sends `rsg-targetpractise:client:place`. The client shows a ghost preview (no collision) and the placement panel.
3. On Enter the client sends `server:place(position, heading)`. The server re-checks the pending request, owner, routing bucket, distance from the player, spacing and limits.
4. Inside a single-flight `transaction`, the target is saved as `placing`, the item is removed, then the target is saved as `active` and broadcast.

## Pickup flow

`server:remove(id)` checks distance, bucket and ownership (or admin). The target is saved as `removing` before the item is credited, so a crash can never duplicate the item. It is then deleted and saved.

## Storage safety

`data/targets.json` is written with a read-back check. If any save fails, or the file is invalid or has an unfinished `placing`/`removing` record at startup, **all item mutations are disabled** (`storageHealthy = false`) until an admin fixes the file and restarts. Nothing is ever refunded automatically.

## Scoring flow

1. The client detector notices a shot (ammo drop / `IsPedShooting` / own moving knife) and sends `server:shot(sequence, weaponHash)`. The server checks the weapon is configured, the player owns the weapon item (`Config.RequireWeaponItem`) and the cooldown, then records the shot with the **server-side** player position.
2. On impact the client probes the surface, confirms it hit a streamed target **face** entity and sends `server:hit(sequence, targetId, impact)`.
3. The server consumes the shot (once only), checks the time window, citizen ID, routing bucket, range from the recorded shooter position and the ring/depth geometry, then calculates the points itself.
4. Totals, records and hit marks are updated in memory and `scoreRevision` is bumped so open leaderboards refresh.

The impact point itself comes from the client. Points are only used for the session leaderboard by default; if you reward money or items via the hook below, add your own cap.

## Events

### Client → server
| Event | Args | Notes |
| --- | --- | --- |
| `rsg-targetpractise:server:place` | `position, heading` | Requires a pending request |
| `rsg-targetpractise:server:cancel` | – | Clears the pending request |
| `rsg-targetpractise:server:remove` | `id` | Owner/admin, within `RemoveDistance` |
| `rsg-targetpractise:server:sync` | – | Throttled 2 s |
| `rsg-targetpractise:server:shot` | `sequence, weaponHash` | Throttled by `shotCooldownMs` |
| `rsg-targetpractise:server:hit` | `sequence, id, impact` | Must match the latest shot |
| `rsg-targetpractise:server:leaderboard` | `open (bool)` | Opens/closes live updates |
| `rsg-targetpractise:server:diagnostic` | – | Admin-free, read-only |

### Server → client
`client:sync`, `client:place`, `client:scored`, `client:scoreRejected` (debug only), `client:leaderboard`, `client:debug`, `client:diagnosticServer`.

### Server-only hook
```lua
AddEventHandler('rsg-targetpractise:server:acceptedHit', function(data)
    -- source, citizenid, name, targetId, weapon, weaponKind, points, radius,
    -- bullseye, distance, distanceBonus, timestamp, impact, scoringMode
end)
```

## Sync

Targets are sent per routing bucket with only `id`, `position`, `heading` and `canRemove`. The server resyncs on every change (`broadcast`), on `RSGCore:Server:PlayerLoaded` / `OnPlayerUnload`, and every 5 s for players whose bucket changed. Clients spawn local (non-networked) props within `Config.StreamDistance`.

## Leaderboard

While a player has the board open, the server checks every `Config.LeaderboardRefreshMs` and only re-sends when `scoreRevision` has changed (a new hit or a player leaving). Locales are sent once when the board opens.

## Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, OneSync. No ox_lib: locales load via `@rsg-core/shared/locale.lua` (language from the `rsg:locale` convar).

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-targetpractise 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `/onesync`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Item` | `'target'` |  |
| `Config.AdminPermission` | `'admin'` |  |
| `Config.FrameModel` | `'p_targetframe01x'` |  |
| `Config.FaceModel` | `'p_targetarchery02x'` |  |
| `Config.Source` | `table` | Unmodified values from ../props.txt. Geometry derives a LOCAL offset, not a world delta. |
| `Config.Placement` | `table` |  |
| `Config.StreamDistance` | `120.0` |  |
| `Config.RemoveDistance` | `3.0` |  |
| `Config.LeaderboardRefreshMs` | `2000` |  |
| `Config.ModelTimeoutMs` | `10000` |  |
| `Config.PersistTargets` | `true` |  |
| `Config.StorageFile` | `'data/targets.json'` |  |
| `Config.Scoring` | `table` | x/z span the face; y is its depth. Values are in model-local metres. |
| `Config.Weapons` | `table` | Scored weapons. Values are locale keys (locales/*.json) used for the display name. |
| `Config.WEAPON_BOW` | `'weapon_bow'` |  |
| `Config.WEAPON_BOW_IMPROVED` | `'weapon_bow_improved'` |  |
| `Config.WEAPON_THROWN_THROWING_KNIVES` | `'weapon_throwing_knives'` |  |
| `Config.WeaponKinds` | `table` | Used by the leaderboard to separate arrow and knife hits. Unknown weapons fall back to 'other'. |
| `Config.RequireWeaponItem` | `true` | Shots only count if the player has the weapon item in their inventory (blocks spoofed shot events). |
| `Config.Debug` | `false` | Admins can toggle their own debug display with /targetdebug. |
| `Config.DebugImpactMs` | `8000` |  |
| `Config.Projectiles` | `table` |  |
| `Config.Controls` | `table` |  |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-targetpractise:client:sync` | client | `list` | `client/client.lua` |
| `rsg-targetpractise:client:scoreRejected` | client | `reason` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `rsg-targetpractise:client:place` | client | `` | `client/client.lua` |
| `rsg-targetpractise:client:scored` | client | `points, radius, total, impact, mode, bullseye, weaponKind, weaponLabel, distance, bonus` | `client/client.lua` |
| `rsg-targetpractise:client:debug` | client | `enabled` | `client/client.lua` |
| `rsg-targetpractise:client:diagnosticServer` | client | `data` | `client/diagnostics.lua` |
| `rsg-targetpractise:client:openLeaderboard` | client | `` | `client/leaderboard.lua` |
| `rsg-targetpractise:client:leaderboard` | client | `data` | `client/leaderboard.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/leaderboard.lua` |
| `rsg-targetpractise:server:leaderboard` | server | `open` | `server/server.lua` |
| `rsg-targetpractise:server:cancel` | server | `` | `server/server.lua` |
| `rsg-targetpractise:server:place` | server | `position, heading` | `server/server.lua` |
| `rsg-targetpractise:server:remove` | server | `id` | `server/server.lua` |
| `rsg-targetpractise:server:sync` | server | `` | `server/server.lua` |
| `rsg-targetpractise:server:diagnostic` | server | `` | `server/server.lua` |
| `rsg-targetpractise:server:shot` | server | `sequence, weapon` | `server/server.lua` |
| `rsg-targetpractise:server:hit` | server | `sequence, id, impact` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-targetpractise:server:leaderboard', open)
-- from a server script
TriggerClientEvent('rsg-targetpractise:client:sync', source, list)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/targetremove` |  | `client/client.lua` |
| `/targetdiag` |  | `client/diagnostics.lua` |
| `/targetboard` |  | `client/leaderboard.lua` |
| `/admintarget` | locale('command_admin') | `server/server.lua` |
| `/targetdebug` | locale('command_debug') | `server/server.lua` |
| `/targetscore` | locale('command_score') | `server/server.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
