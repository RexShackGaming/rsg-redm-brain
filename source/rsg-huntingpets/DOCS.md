# rsg-huntingpets — Developer Docs

## Dependencies
- `rsg-core` (locales, notifications, core object)
- `rsg-target` (pet shop NPC and dog interaction targets)
- `oxmysql`

`ox_lib` is **not** used (migrated to rsg-core in 3.1.x).

## Locales
`fxmanifest.lua` loads `@rsg-core/shared/locale.lua` in `shared_scripts`; strings live in `locales/*.json`
(en, de, el, es, fr, ja, nl, pl, pt-br, ro) and are read with `locale('key', ...)`.
Language: `setr rsg:locale "<code>"` in server.cfg (falls back to `ox:locale`, then `en`).
The NUI receives a resolved string bundle from `client/client_shop.lua` (`GetUiLocale()`).

## Notifications
- Client: `Notify(title, message, template, duration)` in `client/client_shop.lua` wraps
  `RSGCore.Functions.Notify`. Templates `ERROR`, `SUCCESS`, `TIP` (inform), `WARNING`.
- Server: `TriggerClientEvent('RSGCore:Client:Notify', src, { title, description, duration, type })`.

## Files
| Path | Purpose |
|---|---|
| `client/client_shop.lua` | Shop NUI, notify helper, locale bundle |
| `client/npcs.lua` | Shop NPCs + rsg-target |
| `client/client_dogs.lua` / `client_birds.lua` | Pet behaviour, prompts, hunt modes |
| `server/server_dogs.lua` / `server_birds.lua` | Buying/selling/feeding, validation |
| `server/database.lua` | Auto-creates tables (manual SQL in `installation/rsg_huntingpets.sql`) |
| `shared/config_*.lua` | Config |

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-huntingpets 3.1.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`

### Database

Tables: `is`, `player_dogs`, `player_birds`, `player_selected_pets`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg_huntingpets.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.SellingBirdJob` | `{"birdtrainer", "wapiti"}` | for no job: Config.SellingBirdJob = false |
| `Config.Prompts` | `table` |  |
| `Config.ConfirmDeleteValue` | `"delete"` | players must type this word in order to delete a bird from owned birds |
| `Config.Texts` | `table` |  |
| `Config.MaxBirdXP` | `1000` |  |
| `Config.Hunting` | `table` |  |
| `Config.BirdGoForHuntTimer` | `20--seconds - when the bird is flying away to hunt, after the timer ru` |  |
| `Config.HuntingTimer` | `20--seconds - after the deletion, this timer starts and once its compl` |  |
| `Config.ParrotTalkingXPReq` | `1` | required XP for parrot's talking ability |
| `Config.ScavengerItems` | `table` |  |
| `Config.FishItems` | `table` |  |
| `Config.BirdShops` | `table` |  |
| `Config.BirdOfPreys` | `{--for hunting` |  |
| `Config.Scavengers` | `{--for scavenging` |  |
| `Config.FishingBirds` | `{--for fishing` |  |
| `Config.Birds` | `table` |  |
| `Config.BirdAttach` | `{--Options for attaching bird to player's ped` |  |
| `Config.Textures` | `table` |  |
| `Config.Areas` | `table` | ===========================================================-- |
| `Config.Districts` | `table` | ===========================================================-- |
| `Config.Districts2` | `table` | ===========================================================-- |
| `Config.AudioBank` | `table` | MORE AUDIO BANKS: https://www.rdr2mods.com/wiki/speech/ |
| `Config.DogKeyBind` | `'E'` |  |
| `Config.DogTrackingJob` | `"leo"` |  |
| `Config.CallDogKey` | `true` |  |
| `Config.DogTriggerKeys` | `table` |  |
| `Config.AttackCommand` | `true` | Attack command: send your dog to attack a locked-on target |
| `Config.AttackOnlyPlayers` | `true` |  |
| `Config.AttackOnlyAnimals` | `true` |  |
| `Config.AttackOnlyNPC` | `true` |  |
| `Config.TrackCommand` | `true` | Track command: send your dog to follow a locked-on target |
| `Config.TrackOnlyPlayers` | `true` |  |
| `Config.TrackOnlyAnimals` | `true` |  |
| `Config.TrackOnlyNPC` | `true` |  |
| `Config.DefensiveMode` | `true` | Pets hostile to anything you are in combat with |
| `Config.NoFear` | `true` | Prevents horses from fearing your pet |
| `Config.DogSearchRadius` | `50.0` | How far the dog searches for hunted animals |
| `Config.DogFeedInterval` | `1800` | 1800 = 30 min, seconds between feeds |
| `Config.RaiseAnimal` | `true` | Feed to gain XP and grow |
| `Config.DogFullGrownXp` | `1000` | XP to be fully grown |
| `Config.DogXpPerFeed` | `20` | XP gained per feed |
| `Config.NotifyWhenHungry` | `true` |  |
| `Config.DogPetSearchDatabase` | `true` |  |
| `Config.DogAllowedSearchTables` | `{'player_outlawbench', 'player_cocainedry', 'player_cannabisdry', 'can` |  |
| `Config.DogPetAttributes` | `table` |  |
| `Config.Dogs` | `table` |  |
| `Config.DogRetrievableAnimals` | `table` |  |
| `Config.DogKeys` | `table` |  |
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import installation/rsg_huntingpets.sql for a  |
| `Config.Debug` | `false` |  |
| `Config.FadeIn` | `true` |  |
| `Config.DistanceSpawn` | `20.0` |  |
| `Config.AnimalFood` | `'raw_meat'` | Food item for both dogs and birds |
| `Config.AlwaysOpen` | `true` | if false, configure open/close times |
| `Config.OpenTime` | `8` | store opens |
| `Config.CloseTime` | `20` | store closes |
| `Config.Blip` | `table` |  |
| `Config.Shops` | `table` |  |
| `Config.Checkpoints` | `table` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-huntingpets:server:getShopData` | server | `source, cb` | `server/server_dogs.lua` |
| `rsg-huntingpets:server:selectDog` | server | `source, cb, dogId` | `server/server_dogs.lua` |
| `rsg-huntingpets:server:selectBird` | server | `source, cb, birdId` | `server/server_dogs.lua` |
| `rsg-huntingpets:server:getPetData` | server | `source, cb, petName` | `server/server_dogs.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-huntingpets:server:getShopData', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-huntingpets:start_sell` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:client:spawnBird` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:starthunt` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:sell:gotpoints_c` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:sell:updatepoints` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:sell:updatepoints1` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:sell:finishsell` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:checktalk` | client | `` | `client/client_birds.lua` |
| `rsg-huntingpets:client:dogAnimations` | client | `` | `client/client_dogs.lua` |
| `rsg-huntingpets:client:spawnDog` | client | `` | `client/client_dogs.lua` |
| `rsg-huntingpets:client:putawayDog` | client | `` | `client/client_dogs.lua` |
| `rsg-huntingpets:client:sellDogConfirm` | client | `` | `client/client_dogs.lua` |
| `rsg-huntingpets:client:dogFed` | client | `` | `client/client_dogs.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client_shop.lua` |
| `rsg-huntingpets:client:openShop` | client | `` | `client/client_shop.lua` |
| `rsg-huntingpets:client:birdSold` | client | `` | `client/client_shop.lua` |
| `rsg-huntingpets:server:buyBird` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:server:sellBird` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:server:callBird` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:server:loadBird` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:checkhunt` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:addxp` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:addscavengeditem` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:check_sell` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:sell:create` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:sell:stop` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:sell:getpoints` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:sell:buyoffer` | server | `` | `server/server_birds.lua` |
| `rsg-huntingpets:server:buyDog` | server | `` | `server/server_dogs.lua` |
| `rsg-huntingpets:server:sellDog` | server | `` | `server/server_dogs.lua` |
| `rsg-huntingpets:server:callDog` | server | `` | `server/server_dogs.lua` |
| `rsg-huntingpets:server:feedDog` | server | `` | `server/server_dogs.lua` |
| `rsg-huntingpets:server:loadDog` | server | `` | `server/server_dogs.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-huntingpets:server:buyBird')
-- from a server script
TriggerClientEvent('rsg-huntingpets:start_sell', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/callbird` |  | `client/client_birds.lua` |
| `/fleebird` |  | `client/client_birds.lua` |
| `/calldog` |  | `client/client_dogs.lua` |
| `/fleedog` |  | `client/client_dogs.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
