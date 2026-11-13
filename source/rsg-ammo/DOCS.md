# rsg-ammo – Docs (v3.0.2)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports and events
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `oxmysql` |
| `shared/config.lua` | Ammo box items, arrow items, carry limits |
| `client/client.lua` | Applies saved ammo, progress bar, saves changes, `GetAmmoTypes` export |
| `server/server.lua` | Useable items, auto database, load/save, validation |
| `server/versionchecker.lua` | GitHub version check |
| `installation/rsg-ammo.sql` | Manual database install (backup) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Every ammo box and arrow in `Config.BoxAmmo` / `Config.ArrowAmmo` is registered as a useable item.
- Using a box starts a cancellable progress bar (`Config.OpenAmmoBoxTime`). The box is only removed when it finishes. Arrows apply instantly.
- If the player is already at the type's `maxAmmo`, the item is not used and "Max Ammo Reached" is shown.
- The server decides the item, ammo type and amount (`refill`). Saved values are validated and clamped to `maxAmmo`.
- Ammo for every type, including throwables (dynamite, molotov, throwing knives, tomahawks, bolas, hatchets), is stored per character and restored on login.
- Changed counts are saved every `Config.SaveAmmoInterval` ms and on logout or character switch.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `SaveAmmoInterval` | `10000` | ms between saves of changed ammo |
| `OpenAmmoBoxTime` | `2000` | Progress bar time for boxes |
| `BoxAmmo` | table | item name → ammo type (revolver, pistol, repeater, rifle, shotgun, elephant, varmint incl. express, explosive, high velocity, split point) |
| `ArrowAmmo` | table | arrow item → ammo type (regular, small game, fire, poison, dynamite) |
| `AmmoTypes` | table | ammo type → `{ maxAmmo, refill }` |

Example, a new ammo box:
```lua
Config.BoxAmmo['ammo_box_rifle_custom'] = 'AMMO_RIFLE'
```
The item must exist in `rsg-core/shared/items.lua` with `useable = true`.

## 4. Exports and events
| Name | Side | Notes |
|---|---|---|
| `GetAmmoTypes()` | client export | Returns `Config.AmmoTypes`; used by rsg-weapons for throwables |
| `rsg-ammo:client:AddAmmo` | client net event | `(ammoType, amount)` |
| `rsg-ammo:client:openAmmoBox` | client net event | `(ammoBoxItem)` starts the progress bar |
| `rsg-ammo:server:openAmmoBox` | server net event | Finish opening a box |
| `rsg-ammo:server:cancelOpen` | server net event | Cancel; box is kept |
| `rsg-ammo:server:initializeDb` | callback | Returns the character's saved ammo |
| `rsg-ammo:server:updateDb` | server net event | Saves changed counts |

## 5. Database
Table `player_ammo`: one row per `citizenid` with one `INT` column per ammo type (e.g. `ammo_revolver`, `ammo_rifle_express`, `ammo_arrow_fire`), default `0`. The table and any new ammo columns are created automatically on start. If the database user lacks `CREATE`/`ALTER`, import `installation/rsg-ammo.sql`.

## 6. Security
The server picks item, type and amount; the client never sends an amount to add. Saved values are clamped to each type's `maxAmmo`.

## 7. How-tos
- Give ammo: `/giveitem [id] ammo_box_revolver 1`, or sell the items in a shop.
- Change carry limits or refill amounts in `Config.AmmoTypes`.
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Item does nothing | Item must exist in `items.lua` with `useable = true` and be listed in `Config.BoxAmmo`/`ArrowAmmo` |
| `[rsg-ammo]` database error | Import `installation/rsg-ammo.sql` |
| "Max Ammo Reached" | Player is at the limit for that type |
| Ammo lost after restart | Start `oxmysql`, `rsg-core`, `rsg-inventory` before rsg-ammo |

Support the Project : https://rexshack.tebex.store/
