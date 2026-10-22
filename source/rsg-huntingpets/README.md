# rsg-huntingpets

A combined RedM / RSG-Core resource that adds hunting dogs **and** hunting birds to your server in one package, with a single leather-and-gold themed NUI shop for buying, selling and managing both. Built on `ox_lib` and `ox_target`.

## Features

### Hunting Dogs
- 11 purchasable dog breeds (Husky, Mutt, Labrador Retriever, Rufus, Coon Hound, Hound Dog, Border Collie, Poodle, Foxhound, Australian Shepherd, Street Dog).
- Follow, Stay, Attack and Track commands via `ox_target`.
- **Hunt Mode** — toggle on and your dog will automatically retrieve animals you kill nearby.
- **Defensive Mode** — your dog will engage anyone you're in combat with.
- Growth/XP system: feed your dog to level it up through juvenile → half-grown → fully-grown stages, unlocking Stay/Hunt Mode as it matures.
- A leather & gold themed animations menu (Roll Ground, Begging, Resting, Sleeping, Digging, Barking Up, Barking Vicious, Bark Growl, Guard Growl, Howling Sitting, Sniffing Ground, Pooping).
- Feeding system built around a configurable food item (`raw_meat` by default).

### Hunting Birds
- 16 bird categories covering 40+ individual variants — Hawks, Owls, Eagles, Turkey Vultures, Condors, Crows, Ravens, Seagulls, Parrots, Parakeets, Red-Footed Boobies, Cormorants, Cranes, Herons, Pelicans, Roseate Spoonbills.
- Three bird roles: **Hunting** birds (send them off in area-specific hunting zones for prey), **Scavenging** birds (bring back random items) and **Fishing** birds.
- Birds perch on your shoulder between uses and can be sent off to follow, hunt or fly back to you.
- Parrots/Parakeets can "talk" once they've earned enough XP.
- A free-floating camera view while your bird is following you, for spotting prey.
- Player-to-player bird trading: list one of your birds for sale at a price and location, other players can walk up and buy it directly from you.

### Shop
- Single NUI shop (leather & gold RDR2-style UI) with a **Shop** tab (buy dogs/birds by category) and a **My Pets** tab (manage what you already own — call, sell, feed, follow settings, animations).
- Two shop locations out of the box (Valentine and Blackwater), each with an NPC, a blip, and configurable opening hours.
- All purchase prices are validated server-side against the config — the NUI is display-only and can't be used to buy pets for arbitrary prices.

### Multi-language support
- All in-game notifications, prompts, menu text and the shop UI itself are fully localized via `ox_lib`'s locale system.
- Shipped languages: **English (en), German (de), Greek (el), Spanish (es), French (fr), Japanese (ja), Dutch (nl), Polish (pl), Brazilian Portuguese (pt-br), Romanian (ro)**.
- The server picks one language for everyone via a convar — see [Localization](#localization) below.

### Automatic database setup
- The three tables this resource needs (`player_dogs`, `player_birds`, `player_selected_pets`) are created automatically the first time the resource starts. No manual SQL import required — see [Installation](#installation).

## Dependencies

| Resource | Purpose |
|---|---|
| [`rsg-core`](https://github.com/Rexshack-RedM) | Framework (player/money/inventory functions) |
| [`ox_lib`](https://github.com/overextended/ox_lib) | Notifications, locales |
| [`ox_target`](https://github.com/overextended/ox_target) | Interaction prompts (shop NPC, pets, sell points) |
| `oxmysql` | Database access (auto-creates its own tables — see below) |

Make sure all four are started **before** `rsg-huntingpets` in your `server.cfg`.

## Installation

1. Download/clone this resource into your server's `resources` folder as `rsg-huntingpets`.
2. Add the dependencies above to your `server.cfg` if they aren't already there, followed by:
   ```
   ensure rsg-huntingpets
   ```
3. Copy the carcass/scavenger item images from `installation/images/` into your inventory resource's `html/images/` folder (e.g. `rsg-inventory/html/images/`).
4. Open `installation/rsg-core_items.lua` and add any items listed there that don't already exist in your `rsg-core` shared items file (bird/animal carcasses used as scavenged loot, plus the food item if needed).
5. Review and adjust the config files under `shared/` to taste (see [Configuration](#configuration) below).
6. Start/restart your server.

That's it — `server/database.lua` creates `player_dogs`, `player_birds` and `player_selected_pets` automatically the first time the resource starts (`CREATE TABLE IF NOT EXISTS`, so it's safe to run on every restart and never touches existing data). `installation/rsg_huntingpets.sql` is kept only as a schema reference or for manual setups where your database user isn't allowed to create tables — it is **not** required for a normal install.

## Configuration

All config files live under `shared/` and are loaded before the client/server scripts.

### `shared/config_shared.lua` — general settings
| Option | Description |
|---|---|
| `Config.Debug` | Reserved debug flag. |
| `Config.FadeIn` | Fade shop/decoration NPCs in and out as you approach/leave. |
| `Config.DistanceSpawn` | Distance (units) at which shop NPCs spawn. |
| `Config.AnimalFood` | Item name used to feed dogs (shared with birds' scavenging item pool). |
| `Config.AlwaysOpen` | If `false`, the shop only opens between `OpenTime`/`CloseTime`. |
| `Config.OpenTime` / `Config.CloseTime` | 24-hour opening hours (only used when `AlwaysOpen` is `false`). |
| `Config.Blip` | Map blip name/sprite/scale for shop locations. |
| `Config.Shops` | List of shop locations — coordinates, NPC model/scenario, dog spawn point, whether to show a blip. Add more entries here to add more shops. |
| `Config.Checkpoints` | RGB colour used for the player-to-player bird sell checkpoint markers. |

### `shared/config_dogs.lua` — dog settings
| Option | Description |
|---|---|
| `Config.DogTrackingJob` | Job name allowed to use the tracking/search features (default `"leo"`). |
| `Config.CallDogKey` / `Config.DogTriggerKeys.CallDog` | Enable and set the hotkey that calls your selected dog (default `U`). |
| `Config.AttackCommand` / `AttackOnly*` | Enable the dog-attack prompt and restrict its targets (players/animals/NPCs). |
| `Config.TrackCommand` / `TrackOnly*` | Same, for the dog-track prompt. |
| `Config.DefensiveMode` | Dog automatically fights anyone attacking you. |
| `Config.NoFear` | Stops horses from spooking at your dog. |
| `Config.DogSearchRadius` | Radius the dog scans for a killed animal to retrieve in Hunt Mode. |
| `Config.DogFeedInterval` | Seconds between required feedings (default 1800 = 30 min). |
| `Config.RaiseAnimal` | If `true`, dogs start small and grow with XP; if `false`, they spawn fully grown. |
| `Config.DogFullGrownXp` / `Config.DogXpPerFeed` | XP needed to fully grow, and XP gained per feeding. |
| `Config.NotifyWhenHungry` | Send a notification when the dog becomes hungry. |
| `Config.DogPetAttributes` | Follow distance, invincibility, spawn cooldown, death cooldown. |
| `Config.Dogs` | The list of purchasable breeds — display text, description, shop image, model, price. Add/remove/edit entries to change what's for sale. |
| `Config.DogRetrievableAnimals` | Model-hash → name map of animals Hunt Mode will retrieve. |
| `Config.DogKeys` | Internal control-hash lookup table for the configurable hotkey — don't need to touch this unless adding a new key choice. |

> `Config.DogPetSearchDatabase` and `Config.DogAllowedSearchTables` are present in the config as a reserved hook for a future contraband-search feature — they aren't wired up to any behaviour yet, so changing them currently has no effect.

### `shared/config_birds.lua` — bird settings
| Option | Description |
|---|---|
| `Config.SellingBirdJob` | Job(s) allowed to list a bird for player-to-player sale, or `false` to allow everyone. |
| `Config.Prompts` | Control-hash + label pairs for every bird interaction prompt (Send Home, Follow, Hunt, Fly Back, Camera, Sell, Buy, Stop Sell, Talk). |
| `Config.ConfirmDeleteValue` | Word a player must type to confirm deleting an owned bird (menu-side; not currently wired into the NUI delete flow). |
| `Config.Texts` | All shop/bird notification text — localized via `locale()`, see [Localization](#localization). |
| `Config.MaxBirdXP` | XP cap for birds. |
| `Config.Hunting.jobrequired` / `Config.Hunting.jobs` | Restrict sending birds hunting/scavenging/fishing to specific jobs. |
| `Config.Hunting.extra_XP` | Bonus XP per hunt for players with one of `Config.Hunting.jobs`. |
| `Config.BirdGoForHuntTimer` / `Config.HuntingTimer` | Seconds the bird is "away" before, then after, the hunt roll. |
| `Config.ParrotTalkingXPReq` | XP required before a parrot/parakeet can use its talk ability. |
| `Config.ScavengerItems` | Pool of scavenged items (name, amount, XP, XP requirement) scavenger birds can bring back. |
| `Config.FishItems` | Same, for fishing birds. |
| `Config.BirdShops` | Bird-specific shop stand positions. |
| `Config.BirdOfPreys` / `Config.Scavengers` / `Config.FishingBirds` | Model lists that decide which role (hunter/scavenger/fisher) a given bird species has. |
| `Config.Birds` | The full shop catalogue — 16 categories of variants (name, model, preset/skin, price, XP, image, role). This is the big one if you want to add/remove/reprice birds. |
| `Config.BirdAttach` | Per-model shoulder attachment offsets (male/female). |
| `Config.Areas` / `Config.Districts` / `Config.Districts2` | Zone hashes used to decide what prey is available in a given part of the map when hunting. |
| `Config.AudioBank` | Talking-bird speech line pools. |

## How to use

### As a player
1. Walk up to a Hunting Pets shop (Valentine or Blackwater by default) and interact with the NPC to open the shop.
2. **Shop tab** — pick Dogs or a bird category, choose a pet, name it and confirm the purchase (price is always what the server has configured, regardless of what the NUI shows).
3. **My Pets tab** — see everything you own. From here you can:
   - **Call** a pet to spawn it (only one dog *or* bird can be active at a time — send the current one home first).
   - **Sell** a pet back for half its purchase price.
   - **Select** a pet as your default so `/calldog` or `/callbird` spawns it without opening the shop.
4. Once a dog is out: use the `ox_target` options on it for Follow/Stay/Attack/Track/Hunt Mode/Feed, or open its Animations menu.
5. Once a bird is out: use the on-screen prompts to send it home, have it follow, send it hunting (Hunt/Scavenge/Fish depending on species), or open the camera view while it's flying.
6. To sell a bird to another player instead of the shop: use the Sell prompt while your bird is with you, set a price, and other players nearby can then buy it directly off you.

### Commands
| Command | Effect |
|---|---|
| `/calldog` | Spawn your currently selected dog. |
| `/fleedog` | Send your active dog home. |
| `/callbird` | Spawn your currently selected bird. |
| `/fleebird` | Send your active bird home. |

### Hotkeys
| Key | Effect |
|---|---|
| `U` (configurable via `Config.DogTriggerKeys.CallDog`) | Call your selected dog, same as `/calldog`. |

## Localization

The server-wide language is chosen with a convar in `server.cfg` (defaults to English if unset):

```
setr ox:locale "de"
```

Use one of: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Every player sees the same language — this resource follows `ox_lib`'s standard single-locale-per-server model, it doesn't do per-player language switching.

To add or edit translations, edit the matching file under `locales/<code>.json` (flat `"key": "value"` pairs) — no code changes needed. If you add a brand-new piece of UI text, add its key to every locale file so it doesn't fall back to the raw key name.

> The translations shipped with this resource were AI-generated. They cover every notification, menu, prompt and shop UI string, but haven't been reviewed by native speakers — treat them as a solid starting point and adjust as needed for your community, particularly for German, Greek, Japanese and Romanian.

## Notes & limitations

- Only one pet — a dog *or* a bird — can be active at a time per player.
- The food item used to feed pets is not sold by this resource; make sure players can obtain `Config.AnimalFood` (default `raw_meat`) some other way.
- Dogs need regular feeding to keep growing and to avoid becoming hungry; birds gain XP from successful hunts/scavenges/fishing trips instead.
- The in-game "Transfer" and "Commands" pet actions in the My Pets detail panel are UI placeholders and are not implemented yet.
