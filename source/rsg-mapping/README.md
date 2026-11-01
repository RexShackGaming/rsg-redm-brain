# rsg-mapping

An in-game IMAP finder and mapping tool for the **RSG Framework** (RedM). Admins can browse the IMAPs (map data files) around them, turn them on or off, give them friendly names and save their state. Saved changes sync to every player.

The resource also ships with a curated set of default IMAP removals/additions and interior entity sets (stores, banks, saloons, speakeasies and more) that load for every player.

---

## Features

- **Nearby IMAP browser:** lists every IMAP within a chosen radius, sorted by distance.
- **Search:** by IMAP name, friendly label, or hash (`0x1130D783`, `1130D783` or decimal). If a hash is outside the radius, it is still found anywhere on the map.
- **Filters:** All / Active / Inactive, plus an active-count bar.
- **Enable / disable IMAPs** live (`RequestImap` / `RemoveImap`).
- **Persistent state:** toggles are saved to the database and applied for all players, including those who join later.
- **Friendly names:** label any IMAP (e.g. "Valentine barrels"). Labels show in the list and in 3D labels.
- **World highlight:** the selected IMAP gets a pulsing ring, a tall beam, and a line from your character to it.
- **View camera:** a cinematic camera orbits the selected IMAP so you can see what it changes.
- **Waypoint:** sets a GPS route to the IMAP.
- **Copy helpers:** name, hash, ready-to-paste Lua (`RequestImap(0x...) -- name`) or `vector3` coords.
- **3D world labels:** `/imapdraw` shows IMAP names and hashes floating in the world (green = active).
- **Draggable windows:** the panel and details window remember their position (double-click the header to reset).
- **Default map tweaks:** `client/defaultimap.lua` and `client/interiors.lua` load stores, banks, speakeasies, etc. for all players.
- **Fully localised:** all text lives in `locales/en.json`.
- **Admin only:** permission is checked on the server for every write.

---

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)
- [oxmysql](https://github.com/Rexshack-RedM/oxmysql)

---

## Installation

1. Put the `rsg-mapping` folder in your resources directory (e.g. `resources/[rsg]/rsg-mapping`).
2. **Database:** the table is created automatically on first start. To create it by hand, run `installation/rsg-imap.sql`.
3. Make sure it starts **after** its dependencies in your `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure rsg-core
   ensure rsg-mapping
   ```
4. Restart the server (or run `refresh` then `ensure rsg-mapping`).

---

## Configuration

All settings are in `shared/config.lua`:

| Option | Default | Description |
|---|---|---|
| `Config.Command` | `'imaps'` | Command that opens the IMAP finder. |
| `Config.DrawCommand` | `'imapdraw'` | Command that toggles 3D labels in the world. |
| `Config.DefaultRadius` | `50.0` | Search radius (metres) when none is given. |
| `Config.MaxRadius` | `500.0` | Largest radius allowed. |
| `Config.MaxResults` | `200` | Max rows shown in the list at once. |
| `Config.OnlyAdmins` | `true` | Restrict the tool to admins. |
| `Config.AdminPerm` | `'admin'` | rsg-core permission required (players with the `command` ace are also allowed). |
| `Config.DrawDistance` | `60.0` | 3D labels further than this are hidden. |
| `Config.DrawRefresh` | `1000` | How often (ms) the 3D labels rescan nearby IMAPs. |
| `Config.HighlightSize` | `3.0` | Diameter of the ring around the selected IMAP. |
| `Config.HighlightBeam` | `40.0` | Height of the beam above the selected IMAP. |
| `Config.PersistToggles` | `true` | Save enable/disable to the database and sync to all players. If `false`, toggles are local and temporary. |
| `Config.ViewDistance` | `25.0` | View camera distance from the IMAP. |
| `Config.ViewHeight` | `15.0` | View camera height above the IMAP. |
| `Config.ViewOrbitSpeed` | `0.25` | Orbit speed in radians/second (`0` = static). |

### Default map changes

- `client/defaultimap.lua`: a list of `RemoveImap(...)` / `RequestImap(...)` lines applied to every player on join. Add or remove lines to change the default map.
- `client/interiors.lua`: interior entity sets (store shelves, bank interiors, speakeasy themes, etc.). Interiors whose ID is invalid print a warning in the client console.

Saved states from the in-game tool are applied **after** these, so they always win.

### Translations

Included languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Choose one with the ox_lib locale convar in `server.cfg`:

```cfg
setr ox:locale de
```

To add another language, copy `locales/en.json` to e.g. `locales/it.json` and translate the values, keeping every `%s` placeholder.

---

## Usage

### Commands

| Command | Description |
|---|---|
| `/imaps [radius]` | Open the IMAP finder. Radius is optional (default 50m). |
| `/imapdraw [radius]` | Toggle 3D labels in the world. Running it with a new radius while on changes the radius. |

### The finder window

1. Run `/imaps` (or `/imaps 150` for a bigger area).
2. Use the **search box** to filter by name, label or hash. Pasting a hash finds it anywhere on the map.
3. Change the **Radius** box and press Enter (or the ↻ button) to rescan.
4. Use **All / Active / Inactive** to filter. The 💾 icon marks IMAPs with a saved state.
5. Click an IMAP to open its **details window**:
   - **Enable / Disable IMAP:** toggles it live (and saves it if `PersistToggles` is on).
   - **Friendly name:** type a name and press **Save** (or Enter). Saving an empty box clears it.
   - **Set Waypoint:** routes you to it on the map.
   - **View:** orbits the camera around it. Press again to exit.
   - **Copy Name / Hash / Lua / Coords:** copies to your clipboard.
   - **Forget Saved State:** removes the saved state. The IMAP returns to its game default after the next restart.
   - **Back** (or Esc) returns to the list.
6. Press **Esc** or ✕ to close.

### Making a change permanent in code

If you'd rather hard-code a change than keep it in the database, use **Copy Lua** and paste the line into `client/defaultimap.lua`. Change `RequestImap` to `RemoveImap` if you want it removed.

---

## Export

```lua
-- client side: returns IMAPs near the player, sorted by distance
local list = exports['rsg-mapping']:GetNearbyImaps(50.0)
-- each entry: { hash, name, x, y, z, dist, active, label, saved }
```

---

## Credits

- IMAP data generated from [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries).
- Original script by RexShack.
