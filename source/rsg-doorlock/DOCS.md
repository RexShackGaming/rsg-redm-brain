# rsg-doorlock – Docs (v3.2.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Admin editor
5. Events and callbacks
6. Commands
7. Database
8. Discord webhooks
9. Security
10. Server owner how-tos
11. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; locales via `@rsg-core/shared/locale.lua`; depends on `rsg-core`, `oxmysql` |
| `shared/config.lua` | Distances, cooldown, admin settings, `Config.JailDoors` |
| `shared/doorhashes.lua` | Built-in list of ~1,750 RedM door hashes (editor picker) |
| `shared/doorhashes_custom.lua` | Your own MLO / custom door hashes |
| `client/main.lua` | Door state, hold prompt, key animation, sync |
| `client/editor.lua` | Admin editor: aim-and-pick doors, NUI bridge |
| `server/main.lua` | Auto database, lock state, toggle validation, admin callbacks |
| `server/seed_doors.lua` | Doors imported once into an empty table |
| `server/sv_config.lua` | Webhook URLs (server only) |
| `server/webhooks.lua` | Discord logging |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI editor (`index.html`, `style.css`, `app.js`) |
| `installation/rsg_doorlocks.sql` | Manual database install |
| `locales/*.json` | en, cs, de, el, es, fr, it, ja, nl, pl, pt-br, ro |

## 2. How it works
- Every lock is a row in `rsg_doorlocks` with one or more door hashes, text coordinates, allowed jobs, interaction distance and locked state.
- The server owns the lock state. Clients only send a request (`rsg-doorlock:server:requestToggle`) and the server checks the player, the door, distance, job (and duty), cooldown and admin bypass before changing anything.
- The door list goes to each client once. Lock state changes are broadcast to everyone, and players who join late receive the full state.
- A light 500 ms loop looks for nearby doors. A per-frame loop only runs while the player stands at a door, to show the hold prompt.
- Locked doors are frozen shut; the player holds ENTER for `Config.HoldDuration` ms and a key animation plays.
- On first start with an empty table, `server/seed_doors.lua` is imported once (`Config.ImportConfigDoors`).
- `Config.JailDoors` lists the Sisika prison front gate hashes, which are locked by default.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `DefaultDistance` | `1.25` | Interaction range when a lock has no distance |
| `DistanceTolerance` | `2.0` | Extra server-side leeway for the distance check |
| `SyncDistance` | `30.0` | Doors within this range are kept in their synced state |
| `Cooldown` | `1500` | ms between door uses per player (server enforced) |
| `HoldDuration` | `750` | ms the player holds ENTER |
| `RequireOnDuty` | `false` | Job doors need the player on duty |
| `AdminPermission` | `'admin'` | RSG permission needed for the editor |
| `AdminCommand` | `'doorlock'` | Editor command name |
| `AdminBypass` | `true` | Admins can open every lock |
| `MaxDoorsPerLock` | `8` | Doors per lock (2 for double doors) |
| `PickRange` | `2.0` | Aim tolerance when selecting a door in the editor |
| `AllowCustomDoors` | `true` | Allow MLO / custom doors not in the built-in list |
| `ImportConfigDoors` | `true` | Import `seed_doors.lua` once into an empty table |
| `Debug` | `false` | Print MLO door lookups to F8 |

`server/sv_config.lua` holds the webhook URLs. Never add it to `shared_scripts`.

## 4. Admin editor
Open it with `/doorlock` (needs `Config.AdminPermission`).
- Search the lock list by name, job or hash, sorted by nearest.
- Create, edit and delete locks without restarting the resource.
- **Door picking:** aim at a door and press ENTER. The HUD shows the model, hash, selection count and keys, and warns if the door already belongs to another lock. A door can belong to only one lock.
- Set job tags, interaction range and the default locked/unlocked state.
- Teleport to any lock.
- MLO doors: add the hashes to `shared/doorhashes_custom.lua`, or pick the door prop directly (`Config.AllowCustomDoors`).

## 5. Events and callbacks
| Name | Side | Notes |
|---|---|---|
| `rsg-doorlock:server:getDoors` | callback | Returns the door list |
| `rsg-doorlock:server:requestToggle` | server net event | `(doorID)`; validated and rate-limited |
| `rsg-doorlock:server:admin:check` | callback | Editor permission check |
| `rsg-doorlock:server:admin:save` | callback | Create/update a lock (validated) |
| `rsg-doorlock:server:admin:delete` | callback | Delete a lock |
| `rsg-doorlock:server:admin:teleported` | server net event | Logs an admin teleport |
| `rsg-doorlock:client:setState` | client net event | `(doorID, locked)` |
| `rsg-doorlock:client:syncAll` | client net event | Full state on join |
| `rsg-doorlock:client:syncDoor` | client net event | One door changed |
| `rsg-doorlock:client:playKeyAnim` | client net event | Key animation |
| `rsg-doorlock:client:openEditor` | client net event | Open the editor |
| `rsg-doorlock:client:editorRefresh` | client net event | Refresh the list |

## 6. Commands
| Command | Who | What |
|---|---|---|
| `/doorlock` | `Config.AdminPermission` | Open the door editor (name changes with `Config.AdminCommand`) |

## 7. Database
```sql
CREATE TABLE IF NOT EXISTS `rsg_doorlocks` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `doors` LONGTEXT NOT NULL,
    `text_coords` LONGTEXT NOT NULL,
    `jobs` LONGTEXT NOT NULL,
    `distance` FLOAT NOT NULL DEFAULT 1.25,
    `locked` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
The table is created on start. If your database user lacks `CREATE` permission, import `installation/rsg_doorlocks.sql` manually. Lock states survive restarts.

## 8. Discord webhooks
Set URLs in `server/sv_config.lua` (`SvConfig.Webhooks`). Separate channels, or one default channel, for: door use, denied access, admin actions, security and system. Embeds include character name, citizen ID, job and grade, server ID and Discord mention. Edit logs show a before → after list. Messages are batched and Discord 429 replies are handled. Security alerts (non-admin editor requests, fake doors, using doors from far away) can ping a role.

## 9. Security
- Server checks player, door, distance, job, duty, permission and all input data.
- Per-player server cooldown. Clients never decide lock state.
- Door hashes and coordinates are validated (integers, finite values, map bounds).
- Admin callbacks are permission-checked and logged.
- A duplicate door is rejected with the name of the lock that owns it.

## 10. How-tos
- **Add a lock to an MLO house:** `/doorlock` → create → aim at the door → ENTER → set jobs/distance → save. If the door isn't in the hash list, add it to `shared/doorhashes_custom.lua`.
- **Double door:** select both doors in one lock (up to `MaxDoorsPerLock`).
- **Change the language:** `setr rsg:locale "de"` in server.cfg.

## 11. Troubleshooting
| Problem | Fix |
|---|---|
| Can't pick a door | Check `AllowCustomDoors`; add the hash to `doorhashes_custom.lua`; turn on `Debug` |
| "Door already belongs to another lock" | Remove it from the other lock first |
| No Discord logs | Check URLs in `server/sv_config.lua` |
| Table not created | Import `installation/rsg_doorlocks.sql` |
| Editor won't open | You need `Config.AdminPermission` |

Support the Project : https://rexshack.tebex.store/
