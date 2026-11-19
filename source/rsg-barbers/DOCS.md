# rsg-barbers – Docs (v3.0.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Events and callbacks
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-character`, `rsg-target`, `oxmysql` |
| `config.lua` | Prices, target/prompt, makeup ranges, locations |
| `shared/hairs.lua`, `shared/overlays.lua`, `shared/functions.lua` | Hair/overlay data and price/hash helpers |
| `client/npcs.lua` | Barber NPCs, blips, rsg-target or prompt |
| `client/client.lua` | Chair, camera, lighting, NUI, live preview |
| `server/server.lua` | Purchase validation, payment, skin save |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI panel (`index.html`, `style.css`, `script.js`) |
| `locales/*.json` | en, cs, de, el, es, fr, it, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- Barber NPCs spawn and fade in near each shop (`DistanceSpawn`) with map blips.
- Interact with the NPC through rsg-target (or an rsg-core prompt when `UseTarget = false`), sit in the chair with a scripted camera and studio lighting.
- Change hair style/colour, beard style/colour (male) and makeup: stubble (male), eyeshadow, blush, lipstick, eyeliner.
- The menu opens with the current look loaded. Cancel, close or Esc reverts the preview via `exports['rsg-character']:ApplySkin()`.
- Press Pay (or Enter) to buy. You are only charged when something changed.
- The NUI has Hair & Beard and Makeup tabs, arrow steppers (hold to repeat), clickable opacity bars and Shift + mouse wheel.

## 3. Configuration
`config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Debug prints |
| `BarberCost` | `5` | Default cash price; a location can override with `price` |
| `UseTarget` | `true` | rsg-target on the NPC, or a prompt at `coords` |
| `Key` | `'J'` | Prompt key when not using target |
| `MaxDistance` | `3.0` | Server-checked distance from the chair when paying |
| `Cooldown` | `3` | Seconds between purchase attempts |
| `MenuAlign` | `'right'` | Panel side (`right`/`left`) |
| `DistanceSpawn` | `20.0` | NPC spawn/despawn distance |
| `FadeIn`, `BlipSprite`, `BlipScale` | | NPC fade and blip |
| `Makeup` | list | `{ key, label, min, max, default, hop, maleOnly }`; also used by the server to validate values |
| `BarberLocations` | list | `name`, `barberid`, `npcmodel`, `npccoords`, `coords`, `seat`, `camPos`, `camRot`, `lighting`, optional `price` |

## 4. Events and callbacks
| Name | Side | Notes |
|---|---|---|
| `rsg-barbers:client:open` | client event | `(barberid)` opens the barber menu (also reachable via the older `rsg-barber:client:menu`) |
| `rsg-barbers:server:purchase` | callback | `(barberid, payload)`; returns `{ ok, reason, price }` |

## 5. Database
No new tables. The saved look is written to the `playerskins` table (from rsg-character) for the character.

## 6. Security
The server works out hair and beard hashes itself, checks every makeup value against `Config.Makeup` ranges, checks distance to the chair, applies a cooldown, takes cash before saving and refunds it if the save fails.

## 7. How-tos
- Add a shop: copy a `BarberLocations` entry with a unique `barberid` and set the NPC, chair and camera positions.
- Change a price for one shop: add `price = 10` to that location.
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| No NPC | Move within `DistanceSpawn`; check the model and coordinates |
| Can't interact | Start rsg-target, or set `UseTarget = false` |
| Look didn't save | Character needs a `playerskins` row (rsg-character) |
| Preview stuck | Close and reopen; the cancel path calls `ApplySkin` |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-barbers 3.0.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-character`, `rsg-target`, `oxmysql`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` |  |
| `Config.BarberCost` | `5` | default price (cash) for a new style; a location can override with `price` |
| `Config.UseTarget` | `true` | true = rsg-target on the barber NPC, false = rsg-core prompt at `coords` |
| `Config.Key` | `'J'` | prompt key when Config.UseTarget = false |
| `Config.MaxDistance` | `3.0` | max distance (server checked) from the chair when paying |
| `Config.Cooldown` | `3` | seconds between purchase attempts per player |
| `Config.MenuAlign` | `'right'` | NUI panel side: 'right' or 'left' |
| `Config.DistanceSpawn` | `20.0` | spawn/despawn distance for barber NPCs |
| `Config.FadeIn` | `true` |  |
| `Config.BlipSprite` | `-2090472724` |  |
| `Config.BlipScale` | `0.2` |  |
| `Config.Makeup` | `table` |  |
| `Config.BarberLocations` | `table` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-barbers:server:purchase` | server | `source, cb, barberid, payload` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-barbers:server:purchase', function(result)
    -- use result
end, barberid, payload)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-barbers:client:open` | client | `barberid` | `client/client.lua` |

```lua
-- from a server script
TriggerClientEvent('rsg-barbers:client:open', source, barberid)
```

### Locales

Language files in `locales/`: `cs`, `de`, `el`, `en`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
