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
