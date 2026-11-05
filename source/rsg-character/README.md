# rsg-character

Character selection, character creation, clothing stores, wardrobe and spawn selection for **RSG-Core** (RedM).

> Server owners and developers: see **[DOCS.md](DOCS.md)** for the full flow, database layout, security model, exports and how to extend the script.

---

## Features

### Character Select
- In-world select screen: your characters' peds line up at a configurable location, with the camera framing every slot automatically.
- Multiple character slots per player license (default **4**, configurable).
- Create, play and delete characters. Deleting a character also removes its skin and saved outfits.

### Character Creator
- Male / female selection.
- Body: body type (slim, sporty, medium, fat, strong), waist, chest and skin tone.
- Face: eyes, eyelids, eyebrows, nose, mouth, lips, teeth, cheekbones, jaw, ears and chin.
- Hair and beard styles and colours.
- Overlays: scars, freckles, moles, spots, ageing, eye shadow, blush, lipstick and eyeliner, each with colour and opacity.
- Identity form: first name, last name, nationality dropdown and a Day / Month / Year birth date picker (range set in config).
- Names, nationality and birth date are all checked on the server; a profanity filter blocks bad names.
- Starter items given once to each new character.

### Clothing Stores & Wardrobe
- Stores in Valentine, Rhodes, Saint Denis, Blackwater, Strawberry, Armadillo and Tumbleweed, with map blips.
- Clothing split into categories (Head, Shirts & Vests, Belts & Holsters, Coats & Outerwear, Legs, Feet, Hands, Belts & Satchels, Misc Gear).
- Every category has its own cash price; you only pay for items you changed.
- Fitting room runs in a private routing bucket so other players don't see you changing.
- Every purchase is saved as a named outfit (up to **30** per character).
- Wear or delete outfits at a cloakroom or any wardrobe / dresser / armoire prop (via rsg-target).
- New characters get a protected **Default** outfit that can't be deleted.
- Clothing layers are applied in a fixed order to stop clipping (see [Clothing Order](#clothing-order)).

### Spawn Select
- Card-based spawn screen with an image per location (Valentine, Rhodes, Saint Denis, Blackwater by default).
- New characters pick a spawn; returning characters spawn back where they logged out.

### Other
- `/logout` saves the character and returns to character select (cooldown, blocked while dead).
- `/loadskin` reloads your appearance if something looks wrong.
- Discord webhook logging: character created, deleted, selected, logout, appearance saved and outfit purchased (rate-limit aware).
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro.
- No ox_lib dependency — uses rsg-core notify, callbacks, locales and `require`.
- Exports, events and callbacks for other resources.

---

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [oxmysql](https://github.com/Rexshack-RedM/oxmysql)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) (starter items)
- Optional: [rsg-target](https://github.com/Rexshack-RedM/rsg-target) (wardrobe props)
- Optional: [rsg-weather](https://github.com/Rexshack-RedM/rsg-weather) (paused during character select; weather, time and rain are handed back to it when the scene ends)

---

## Installation

1. Download the resource and place the `rsg-character` folder in your resources (e.g. `resources/[rsg]/rsg-character`). Keep the folder name `rsg-character` — NUI image paths use it.
2. Make sure your database has the `playerskins` and `playeroutfit` tables. Most RSG-Core installs already include them. If yours doesn't, run:

```sql
CREATE TABLE IF NOT EXISTS `playerskins` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(255) NOT NULL,
  `skin` LONGTEXT NOT NULL,
  `clothes` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `playeroutfit` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(255) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `clothes` LONGTEXT NOT NULL,
  `is_default` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

   On start the script adds the `is_default` column if it's missing and gives every existing character a **Default** outfit copied from what they're wearing.

3. Add it to `server.cfg` **after** its dependencies:

```cfg
ensure oxmysql
ensure rsg-core
ensure rsg-inventory
ensure rsg-target
ensure rsg-character
```

4. Remove or disable any other multicharacter, appearance or clothing resource (`rsg-multicharacter`, `rsg-appearance`, `rsg-clothing` etc.) so they don't conflict.
5. Set your language (optional, defaults to `en`):

```cfg
setr rsg:locale en
```

6. Edit `shared/config.lua` (paste your Discord webhook URLs, check spawn points and prices), then restart the server.

---

## Configuration

Everything is in `shared/config.lua`.

| Option | Description |
|---|---|
| `RSG.Debug` | Prints extra debug info to the client console. |
| `RSG.MaxCharacterSlots` | Character slots per player license (default `4`). |
| `RSG.Birthdate` | `Min`, `Max` and `Default` birth dates (`YYYY-MM-DD`), checked on client and server. |
| `RSG.Logout` | `/logout` settings: `Enabled`, `Command`, `Cooldown` (seconds), `BlockWhenDead`. |
| `RSG.ProfanityWords` | Words blocked as names: `['word'] = true` (lowercase). |
| `RSG.Nationalities` | Locale keys for the nationality dropdown. Names live under `nationalities` in `locales/*.json`. |
| `RSG.StarterItems` | Items given once to a new character: `{ item = 'bread', amount = 2 }`. Unknown items are skipped. |
| `RSG.CharSelectLocation` | `coords` (vector4) where peds line up, `spacing` between them, and `camera` (`back`, `height`, `fov`). |
| `RSG.Webhooks` | One entry per log event: `enabled`, `url`, `name`, `avatar`, `color`. |
| `RSG.SpawnLocations` | Spawn cards: `label`, `coords` (vector4) and `image` (path under `html/`). |
| `RSG.SpawnChecks` | Safety net: anyone who loads within `Radius` of a `badSpawn` point is moved to `moveTo`. |
| `RSG.Prompt` | Control hashes used in the creator (gender, confirm, camera, rotate, zoom). |
| `RSG.OpenKey` / `RSG.Keybind` | Key that opens the clothing store / cloakroom. |
| `RSG.BlipSprite`, `RSG.BlipSpriteCloakRoom`, `RSG.BlipScale` | Map blip settings. |
| `RSG.SetDoorState` | Store door hashes and state (`0` = open, `1` = locked). |
| `RSG.Zones1` | Clothing stores: `blipcoords`, `fittingcoords`, `quitcoords`, `promtcoords`, `showblip`. |
| `RSG.Cloakroom` | Cloakroom (wardrobe) locations, vector3. |
| `RSG.WardrobeTarget` | rsg-target wardrobe props: `enabled`, `distance`, `icon`, `label`, `models`. |
| `RSG.MenuElements` | Which clothing categories appear in each store menu section. |
| `RSG.Price` | Cash price per clothing category. |

### Adding a spawn location
```lua
{ label = 'Strawberry', coords = vector4(-1790.0, -390.0, 160.3, 0.0), image = 'img/spawn/strawberry.jpg' },
```
Put the image in `html/img/spawn/`. To translate the label, add a key under `spawn_locations` in every locale file and use `locale('spawn_locations.strawberry')`. A missing image just leaves the card blank.

### Adding a clothing store
Add an entry to `RSG.Zones1` (stand in the spot and grab coords in-game):
```lua
{
    location = 'annesburg',
    blipcoords    = vector3(x, y, z),       -- map blip
    fittingcoords = vector4(x, y, z, h),    -- where the player stands while changing
    quitcoords    = vector4(x, y, z, h),    -- where they are placed when leaving
    promtcoords   = vector3(x, y, z),       -- where the open prompt shows
    showblip = true
},
```

### Webhooks
Replace the placeholder `https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX` URLs with your own. An enabled category without a real URL prints a single console warning instead of erroring. Set `enabled = false` to turn a category off.

---

## Usage

### Players
1. **Join the server.** The character select screen opens with your characters lined up.
2. **Choose a slot.** Click a character to play, or an empty slot to create one.
3. **Create.** Pick male or female, shape body and face, choose hair and makeup, then enter your name, nationality and birth date. Use the on-screen prompts to move the camera, rotate and zoom.
   - Names must be 2–20 letters, start with a capital and contain no spaces (e.g. `Arthur`).
4. **Spawn.** New characters choose a town from the spawn cards. Existing characters return to where they logged out.
5. **Shop for clothes.** Head to a clothing store blip, stand at the prompt and press the open key. Browse categories, try items on, then pay in cash and name the outfit.
6. **Change outfits.** At a cloakroom or any wardrobe/dresser prop (target it), wear or delete saved outfits.

### Commands
| Command | Description |
|---|---|
| `/logout` | Saves your character and returns you to character select. Has a cooldown and is blocked while dead or downed. |
| `/loadskin` | Reloads your saved skin and clothing. Blocked while dead, cuffed, hogtied, lassoed, dragged, ragdolled, falling or jailed. |

---

## Clothing Order

RedM draws clothing in layers, so the order items go on matters (coat before shirt = clipping). rsg-character always applies clothing in a fixed order:

1. **Base body** — bare upper/lower body for your skin tone and body type, wherever no clothing covers it.
2. **Clothing in layer order** — inner → middle → outer → equipment & accessories.
3. **Unknown categories last**, alphabetically.

| Layer | Categories |
|---|---|
| 1. Inner | `pants`, `skirts`, `boots`, `shirts_full` |
| 2. Middle | `vests`, `suspenders`, `chaps`, `spats`, `boot_accessories`, `leg_attachments` |
| 3. Outer | `coats`, `coats_closed`, `ponchos`, `cloaks`, `aprons`, `armor`, `neckwear`, `neckties`, `gloves`, `gauntlets` |
| 4. Equipment & accessories | `gunbelts`, holsters, `loadouts`, ammo, `satchels`, `belts`, `belt_buckles`, talismans, `badges`, `accessories`, jewellery, `masks`, `eyewear`, `hats` |

Change it with the `CLOTHING_ORDER` table at the top of `client/clothes.lua` (later = drawn on top). See [DOCS.md](DOCS.md#clothing-order) for details.

---

## For developers

Quick reference — full details in [DOCS.md](DOCS.md).

```lua
-- get the logged-in character's appearance (server callback)
local data = RSGCore.Functions.AwaitCallback('rsg-character:server:getAppearance')
-- data = { skin = {...}, clothes = {...} } or nil

-- reload the local player's saved skin + clothes (client)
exports['rsg-character']:ApplySkin()

-- apply a skin/clothes table to any ped (client)
exports['rsg-character']:ApplySkinMultiChar(skinData, ped, clothesData)

-- is the player in the clothing store? (client)
local busy = exports['rsg-character']:IsCothingActive()
```

---

## Changelog

### 3.1.1
- Current release. See DOCS.md for the full feature/flow reference.

### 3.0.10
- Notifications use rsg-core notify and callbacks use rsg-core callbacks.
- Locales load through rsg-core's shared loader; ox_lib is no longer a dependency (data files load with rsg-core's `require`).
- Wardrobe props use rsg-target instead of ox_target.
- Removed the unused `rsg-character:server:LoadSkin` net event (could open a free creator session).
- Wearing a saved outfit re-validates its clothes on the server.
- The store checks your cash before you leave the fitting room, so you keep your selection if you can't afford it.
- The client no longer sends its gender when buying clothes (the server uses the character record).

---

## Credits
- RexShack / RSG Framework

## Support
If you enjoy this script, you can support development here: https://buymeacoffee.com/rexshack

## License
See [LICENSE](LICENSE).
