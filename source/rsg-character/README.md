# rsg-character

Character selection, creation, clothing store and spawn system for **RSG-Core** (RedM).

---

## Features

### Character Select
- In-world character select screen: your characters' peds line up at a location you can configure.
- Multiple character slots per player license (default **4**, configurable).
- Create, select and delete characters, with the camera framing every slot automatically.

### Character Creator
- Male / female selection.
- Body options: body type (slim, sporty, medium, fat, strong), waist, chest, skin tone.
- Detailed face options: eyes, eyelids, eyebrows, nose, mouth, lips, teeth, cheekbones, jaw, ears and chin.
- Hair and beard styles and colours.
- Overlays: scars, freckles, moles, spots, ageing, eye shadow, blush, lipstick and eyeliner, each with colour and opacity.
- Identity form: first name, last name, a nationality dropdown and a Day / Month / Year birth date picker (range set in config, checked on the server).
- A profanity filter for character names.
- Starter items given to each new character.

### Clothing Store & Wardrobe
- Clothing stores in Valentine, Rhodes, Saint Denis, Blackwater, Strawberry, Armadillo and Tumbleweed, with map blips.
- Clothing is split into categories (Head, Shirts & Vests, Belts & Holsters, Coats, Legs, Feet, Hands, Accessories, Misc Gear).
- Each category has its own price, paid in cash.
- Every purchase is saved as a named outfit (up to 30). Wear or delete them at a cloakroom or any wardrobe/dresser prop (rsg-target).
- New characters get a protected **Default** outfit that can't be deleted.
- The server checks every clothing purchase and outfit change.
- Configurable store door states (open or locked).

### Spawn Select
- A card-based spawn screen with an image for each location.
- Default locations: Valentine, Rhodes, Saint Denis and Blackwater.

### Other
- Discord webhook logging for character created, deleted and selected, appearance saved and outfit purchased.
- A `/loadskin` command to reload your appearance.
- A `/logout` command that saves and returns you to character select (with cooldown, blocked while dead).
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro.
- Exports for other resources (see below).

---

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [oxmysql](https://github.com/Rexshack-RedM/oxmysql)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) (starter items)
- Optional: [rsg-target](https://github.com/Rexshack-RedM/rsg-target) (wardrobe props), [rsg-weather](https://github.com/Rexshack-RedM/rsg-weather) (paused during character select)

---

## Installation

1. Download the resource and put the `rsg-character` folder in your server's `resources` folder (for example `resources/[rsg]/rsg-character`).
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

The `is_default` column is added automatically on start if it's missing, and existing characters get a Default outfit copied from what they're wearing.

3. Ensure the resource in `server.cfg` **after** its dependencies:

```cfg
ensure oxmysql
ensure rsg-core
ensure rsg-character
```

4. Remove or disable any other multicharacter, appearance or clothing resource (such as `rsg-multicharacter` or `rsg-appearance`) so they don't conflict.
5. Edit `shared/config.lua` (see below), then restart the server.

---

## Configuration

All settings are in `shared/config.lua`.

| Option | Description |
|---|---|
| `RSG.MaxCharacterSlots` | Number of character slots per player license (default `4`). |
| `RSG.Birthdate` | `Min`, `Max` and `Default` birth dates (`YYYY-MM-DD`) for the creator. |
| `RSG.Logout` | `/logout` settings: `Enabled`, `Command`, `Cooldown` (seconds), `BlockWhenDead`. |
| `RSG.ProfanityWords` | Words blocked in character names (`['word'] = true`). |
| `RSG.Nationalities` | Locale keys shown in the nationality dropdown. Their display names are under `nationalities` in `locales/*.json`. |
| `RSG.StarterItems` | Items given once to a new character: `{ item = 'bread', amount = 2 }`. |
| `RSG.CharSelectLocation` | `coords` (vector4) where the peds line up, `spacing` between peds, and `camera` settings (`back`, `height`, `fov`). |
| `RSG.Webhooks` | One entry per log event. Set `enabled`, paste your Discord webhook `url`, and optionally set `name`, `avatar` and `color`. |
| `RSG.SpawnLocations` | Spawn cards: `label`, `coords` (vector4) and `image` (a path under `html/`, such as `img/spawn/valentine.jpg`). |
| `RSG.Prompt` | Control hashes used in the creator (gender select, confirm, camera, rotate, zoom). |
| `RSG.OpenKey` / `RSG.Keybind` | Key that opens the clothing store / wardrobe. |
| `RSG.BlipSprite`, `RSG.BlipSpriteCloakRoom`, `RSG.BlipScale` | Map blip settings. |
| `RSG.SetDoorState` | Store door hashes and state (`0` = open, `1` = locked). |
| `RSG.Zones1` | Clothing store locations: `blipcoords`, `fittingcoords`, `quitcoords`, `promtcoords` and `showblip`. |
| `RSG.Cloakroom` | Wardrobe locations (vector3). |
| `RSG.WardrobeTarget` | rsg-target wardrobe props: `enabled`, `distance`, `icon`, `label`, `models`. When enabled, saved outfits can be worn at any of these props. |
| `RSG.MenuElements` | Which clothing categories appear under each store menu section. |
| `RSG.Price` | Cash price for each clothing category. |

### Adding a spawn location
```lua
{ label = 'Strawberry', coords = vector4(-1790.0, -390.0, 160.3, 0.0), image = 'img/spawn/strawberry.jpg' },
```
Put the image in `html/img/spawn/`. Existing entries use a locale key (`locale('spawn_locations.valentine')`) as the label. You can do the same for new ones by adding a key under `spawn_locations` in the locale files. A missing image just leaves the card blank.

### Webhooks
Replace the placeholder `https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX` URLs with your own. A category that is enabled but has no valid URL prints a warning to the server console instead of throwing an error.

### Locales
Text is loaded by rsg-core's shared locale loader (`@rsg-core/shared/locale.lua`) from `locales/<lang>.json`. Choose the language in `server.cfg` (`ox:locale` still works as a fallback), for example:
```cfg
setr rsg:locale en
```

---

## Clothing Order

RedM draws clothing in layers, so the order items go on matters. If a coat goes on before a shirt, or a hat before the hair, you can get clipping, missing body parts or floating accessories. rsg-character always applies clothing in a fixed layer order, both when an outfit loads and when you change an item in the clothing store.

### How it works
1. **Base body first.** For each body part (upper and lower) that no clothing covers, the bare skin for your skin tone and body type goes on before any clothes.
2. **Clothing in layer order.** Every category then goes on in the order below, so outer items always sit on top of inner ones.
3. **Unknown categories last.** Any category not in the list goes on after everything else, sorted alphabetically.

| Layer | Categories (in order) |
|---|---|
| 1. Inner | `pants`, `skirts`, `boots`, `shirts_full` |
| 2. Middle | `vests`, `suspenders`, `chaps`, `spats`, `boot_accessories`, `leg_attachments` |
| 3. Outer | `coats`, `coats_closed`, `ponchos`, `cloaks`, `aprons`, `armor`, `neckwear`, `neckties`, `gloves`, `gauntlets` |
| 4. Equipment & accessories | `gunbelts`, `holsters_right`, `holsters_left`, `holsters_crossdraw`, `holsters_knife`, `loadouts`, `ammo_pistols`, `ammo_rifles`, `satchels`, `belts`, `belt_buckles`, `talisman_belt`, `talisman_holster`, `talisman_satchel`, `talisman_wrist`, `badges`, `accessories`, `jewelry_bracelets`, `jewelry_rings_left`, `jewelry_rings_right`, `masks`, `eyewear`, `hats` |

### Changing the order
The order is set by the `CLOTHING_ORDER` table at the top of `client/clothes.lua`. Move a category up or down to change when it goes on (later means drawn on top), or add a new category to give it a fixed place. The `OrderedClothes(tbl)` helper walks any clothes table in this order, so other client code can use it too:

```lua
for category, data in OrderedClothes(ClothesCache) do
    -- applied in layer order
end
```

---

## Usage

### Players
1. **Join the server.** The character select screen opens with your existing characters.
2. **Choose a slot.** Click an existing character to play, or an empty slot to create a new one.
3. **Create a character.** Pick male or female, shape the body and face, choose hair and makeup, then enter your name, nationality and birth date. Use the on-screen prompts to move the camera up and down, rotate and zoom.
4. **Spawn.** Choose a spawn location from the cards.
5. **Clothing stores.** Go to a store (clothing blip on the map), stand at the prompt and press the open key. Browse categories, try items on, and pay in cash to save the outfit.
6. **Wardrobe.** At a cloakroom, wear or delete your saved outfits.

### Commands
| Command | Description |
|---|---|
| `/logout` | Saves your character and returns you to character select. |
| `/loadskin` | Reloads your saved skin and clothing. It doesn't work while you're dead, cuffed, hogtied, lassoed, being dragged, ragdolled, falling or jailed. |

### Exports (client)
```lua
exports['rsg-character']:ApplySkin(...)
exports['rsg-character']:ApplySkinMultiChar(...)
exports['rsg-character']:SetFaceOverlays(target, data)
exports['rsg-character']:SetHair(target, data)
exports['rsg-character']:SetBeard(target, data)
exports['rsg-character']:GetComponentId(name)
exports['rsg-character']:GetBodyComponents()
exports['rsg-character']:GetBodyCurrentComponentHash(name)
exports['rsg-character']:GetComponentsMax(name)
exports['rsg-character']:GetMaxTexturesForModel(category, model, isClothing)
exports['rsg-character']:GetClothesCache(name)
exports['rsg-character']:GetClothesComponentId(name)
exports['rsg-character']:GetClothesCurrentComponentHash(name)
exports['rsg-character']:IsCothingActive()
```

### Events
| Event | Side | Description |
|---|---|---|
| `rsg-character:client:OpenCharSelect` | client | Opens the character select screen. |
| `rsg-character:client:OpenCreator` | client | Opens the character creator. Only saves when the server opened it (use the server flow, not a client trigger). |
| `rsg-character:client:OpenSpawnSelect` | client | Opens the spawn select screen. |
| `rsg-character:client:ApplySkin` | client | Applies a skin and clothes to the player. |
| `rsg-character:client:outfits` | client | Opens the outfit wardrobe. |

### Callbacks (rsg-core)
| Callback | Returns |
|---|---|
| `rsg-character:server:getAppearance` | `{ skin, clothes }` for the logged-in character, or `nil` |
| `rsg-multicharacter:server:getAppearance` | Same, kept for older resources (`{ skin = {}, clothes = {} }` when none) |
| `rsg-character:server:getOutfits` | The character's saved outfits |

```lua
local data = RSGCore.Functions.AwaitCallback('rsg-character:server:getAppearance')
```

## Changelog
### 3.0.10
- Notifications now use rsg-core notify and callbacks use rsg-core callbacks 
- Locales load through rsg-core's shared loader; ox_lib is no longer a dependency (data files load with rsg-core's `require`).
- Wardrobe props use rsg-target instead of ox_target.
- Removed the unused `rsg-character:server:LoadSkin` net event: a logged-in player without a saved skin could call it to open a free creator session.
- Wearing a saved outfit re-validates its clothes on the server before applying it.
- The clothing store checks your cash before you leave the fitting room, so you keep your selection if you can't afford it.
- The client no longer sends its gender when buying clothes (the server already uses the character record).

---

## Credits
- RexShack / RSG Framework

Support: https://buymeacoffee.com/rexshack
