# rsg-hunting – Docs (v3.3.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `oxmysql`, `rsg-core`, `rsg-target`, `rsg-inventory` |
| `config.lua` | Animals, trappers, butchers, XP, bounties, leaderboard |
| `client/client.lua` | Skinning hook |
| `client/vendor.lua` | Trapper NPCs and NUI sell screen |
| `client/butcher.lua`, `client/npcs.lua` | Butcher NPCs, prompts/targets |
| `client/leaderboard.lua`, `client/main.js` | Leaderboard UI |
| `server/server.lua` | Skin rewards |
| `server/vendor.lua` | Trapper selling, stock |
| `server/butcher.lua` | Carcass selling |
| `server/xp.lua` | Hunting XP, levels, weekly leaderboard |
| `server/bounty.lua` | Daily bounties |
| `server/sv_config.lua`, `server/webhooks.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI (sell screen, leaderboard) |
| `install.sql` | Manual database install |
| `installation/shared_items.lua` | Items to add to your items file |
| `stream/annesburg.ymap` | Map streaming file |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- **Skinning:** hooks the game's native skinning event (no minigame). Up to 5 reward items per animal, 90+ animals in `Config.Animals`. The client only sends the carcass network id; the server checks it exists, is dead, is close, is skinnable and was not skinned before. `Config.DeleteCarcass` removes the carcass afterwards.
- **Trappers:** 5 NPCs with blips and an NUI sell screen (search, owned-only filter, quantity, basket). Stock-based pricing per trapper: 1.25x below 50% of `maxStock`, 1.5x below 25%. Stock decays over time (`StockDecayMinutes`, `StockDecayPercent`) so prices recover. Stock is saved to `vendor_stock.json`.
- **Butchers:** 12 NPCs (rsg-target or prompt). Sell the carried carcass, or one on your horse (`SellFromHorse`), for cash and meat scaled by pelt quality (poor, good, perfect).
- **Daily bounties:** `Config.Bounty` picks animals per UTC day that pay extra at the butcher and give extra XP.
- **Hunting XP:** XP for skinning and butcher sales, levels with perks (`trapperBonus`, `butcherBonus`, `extraSkinChance`), clean-kill multiplier for perfect pelts.
- **Weekly leaderboard:** weeks start Monday 00:00 UTC; top ranks collect cash at any trapper.

## 3. Configuration
`config.lua` (main options):
| Option | Meaning |
|---|---|
| `DeleteCarcass` | Remove the carcass after skinning |
| `Image` | Item image folder |
| `AllowPushToTalkWhileOpen`, `PushToTalkControls` | Keep push-to-talk working while NUI is open |
| `BlipSprite`, `BlipScale` | Trapper blips |
| `StockDecayMinutes` / `StockDecayPercent` | Trapper stock recovery (30 min / 10%) |
| `Bounty` | `Enabled`, `Count`, `ButcherBonus`, `XPMultiplier`, `MinReward`, `Animals` |
| `Vendors` | Trappers: `pedModel`, `coords`, blip, `items` (`name`, `sellPrice`, `maxStock`, `canSell`, `stockBasedPrice`) |
| `SellFromHorse` | Butcher buys carcasses on your horse |
| `KeyBind` / `EnableTarget` | `'J'` prompt, or rsg-target on butcher NPCs |
| `HuntingXP` | `Enabled`, `RepName`, `DefaultXP`, `Notify`, `ButcherXP`, `ButcherQualityMultiplier`, `Levels`, `CleanKillMultiplier`, `Weekly`, `Leaderboard`, per-animal `Animals` |

Perks are not cumulative: each level lists its full perk set. Webhook URLs are in `server/sv_config.lua`.

## 4. Exports, events and commands
| Name | Side | Notes |
|---|---|---|
| `GetDailyBounties()` | server export | Today's bounty animals |
| `AwardHuntingXP(...)` | server export | Give hunting XP |
| `GetHuntingXP(...)` / `GetHuntingLevel(src)` | server exports | Read XP and level |
| `SendWebhook(...)` | server export | Send a hunting webhook |
| `rsg-hunting:server:giverewards` | server event | `(netId, quality)` skin rewards |
| `rsg-hunting:server:getSellData` | callback | `(vendorIndex)` |
| `rsg-hunting:server:sellBasket` | callback | `(vendorIndex, basket)` |
| `rsg-hunting:server:sellCarcass` | callback | `(netId, quality)` |
| `rsg-hunting:server:getBounties` | callback | Daily bounties |
| `rsg-hunting:server:getLeaderboard` | callback | `(mode)` |
| `rsg-hunting:server:claimWeekly` | callback | Collect last week's reward |
| `rsg-hunting:client:butcher:mainmenu` | client event | Open the butcher menu |

| Command | Who | What |
|---|---|---|
| `/huntingboard` | everyone | Open the leaderboard (name from `Leaderboard.Command`, `''` disables) |
| `/resetvendorstock` | server console only | Reset trapper stock |
| `/huntingwebhooktest` | admin | Send a test webhook |

## 5. Database
`install.sql` (created automatically on start):
- `hunting_weekly`: `citizenid`, `week`, `name`, `xp` (primary key `citizenid`, `week`).
- `hunting_weekly_rewards`: `id`, `citizenid`, `week`, `rank`, `cash`, `claimed`.

Trapper stock is saved in `vendor_stock.json`.

## 6. Security
The server validates every skinning and sale: carcass exists, is dead, is close and unskinned; distance to the vendor, accepted items, ownership, cooldown. The server removes carried carcasses itself so sales can't be faked or repeated, and rolls back if an item removal fails.

## 7. How-tos
- Add an animal: add it to `Config.Animals` with its rewards, and to `HuntingXP.Animals` for XP.
- Add items to your items file from `installation/shared_items.lua`.
- Turn XP off: `HuntingXP.Enabled = false`.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Nothing from skinning | Animal missing in `Config.Animals`, or carcass already skinned |
| Trapper prices low | Stock is full; wait for decay or `/resetvendorstock` |
| No leaderboard | Check `Leaderboard.Command` and `HuntingXP.Weekly.Enabled` |
| Missing item images | Check `Config.Image` |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, MirrorXP, SellBonus, ExtraYield }`, plus the global helpers `SkillsActive()` and `SkillPerk(src, perk)` defined at the end of `config.lua`.
- `HuntingXP.Award` calls `exports['rsg-skills']:AddXP(src, 'hunting', amount, 'hunting', { raw = true })` after the rep is added (raw so the two totals stay equal).
- The butcher adds `GetPerk(src, 'hunting', 'sell_bonus') / 100` to its bonus before computing the cash.
- Skinning adds `GetPerk(src, 'hunting', 'extra_yield')` to the existing `extraSkinChance`.
- The trapper vendor sale is not changed, because its prices are shown in the shop UI.
- rsg-skills imports the old `hunting` rep value once per character (`repImport`), so existing levels carry over.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-hunting 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`oxmysql`, `rsg-core`, `rsg-target`, `rsg-inventory`

### Database

Tables: `hunting_weekly`, `hunting_weekly_rewards`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.DeleteCarcass` | `false` | this will ensure the carcass is removed if true |
| `Config.Image` | `'rsg-inventory/html/images/'` | location where your item images are stored |
| `Config.AllowPushToTalkWhileOpen` | `true` | While NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.BlipSprite` | `'blip_shop_animal_trapper'` |  |
| `Config.BlipScale` | `0.2` |  |
| `Config.StockDecayMinutes` | `30` | trapper stock sells on every X minutes (0 = never, prices stay low once stocked) |
| `Config.StockDecayPercent` | `10` | % of each item's stock removed each time (each trapper has its own stock) |
| `Config.Bounty` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.Count` | `2` |  |
| `Config.ButcherBonus` | `50` |  |
| `Config.XPMultiplier` | `2` |  |
| `Config.MinReward` | `3` |  |
| `Config.Animals` | `{}` |  |
| `Config.Vendors` | `table` |  |
| `Config.HuntingXP` | `table` |  |
| `Config.RepName` | `'hunting'` |  |
| `Config.DefaultXP` | `1` |  |
| `Config.Notify` | `true` |  |
| `Config.ButcherXP` | `true` | butcher sales also give xp (base xp x quality multiplier below) |
| `Config.ButcherQualityMultiplier` | `{ poor = 1, good = 2, perfect = 3 }` |  |
| `Config.Levels` | `table` | extraSkinChance = % chance to get a 2nd copy of the main skinning reward |
| `Config.CleanKillMultiplier` | `1.5` | clean kill: skinning a perfect-quality animal multiplies its skinning xp (max 3) |
| `Config.Weekly` | `table` | weekly leaderboard (needs install.sql). weeks start Monday 00:00 UTC |
| `Config.Leaderboard` | `table` |  |
| `Config.Debug` | `false` |  |
| `Config.SellTime` | `10000` | butcher sell progress bar (ms) |
| `Config.SellFromHorse` | `true` | butcher also buys a carcass strapped to your horse |
| `Config.HorseCarcassRange` | `6.0` | max distance (m) between you and the carcass/horse |
| `Config.PoorMultiplier` | `1` | butcher cash/item multipliers by carcass quality |
| `Config.GoodMultiplier` | `2` |  |
| `Config.PerfectMultiplier` | `3` |  |
| `Config.KeyBind` | `'J'` | prompt key when Config.EnableTarget = false |
| `Config.EnableTarget` | `true` | rsg-target on butcher NPCs instead of prompts |
| `Config.ServerCooldown` | `2000` | per-player cooldown on skinning/butcher rewards (ms) |
| `Config.EnableLogging` | `true` | send butcher sales to rsg-log |
| `Config.WebhookName` | `'rsghunting'` |  |
| `Config.WebhookTitle` | `'RSG Hunting - Butcher'` |  |
| `Config.WebhookColour` | `'default'` |  |
| `Config.DistanceSpawn` | `20.0` | distance before spawning/despawning the butcher ped |
| `Config.FadeIn` | `true` | fade butcher peds in/out |
| `Config.Blip` | `table` |  |
| `Config.ButcherLocations` | `table` |  |
| `Config.Animal` | `table` |  |
| `Config.Skills` | `table` | The hunting XP, levels and leaderboard above keep working; this adds the shared rsg-skills 'hunting' skill on  |
| `Config.Skill` | `'hunting'` |  |
| `Config.MirrorXP` | `true` |  |
| `Config.SellBonus` | `true` |  |
| `Config.ExtraYield` | `true` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `GetDailyBounties` | `` | `server/bounty.lua` |
| `SendWebhook` | `` | `server/webhooks.lua` |
| `AwardHuntingXP` | `` | `server/xp.lua` |
| `GetHuntingXP` | `` | `server/xp.lua` |
| `GetHuntingLevel` | `src` | `server/xp.lua` |

```lua
-- example
local result = exports['rsg-hunting']:GetDailyBounties()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-hunting:server:getBounties` | server | `src, cb` | `server/bounty.lua` |
| `rsg-hunting:server:sellCarcass` | server | `src, cb, netId, quality` | `server/butcher.lua` |
| `rsg-hunting:server:getSellData` | server | `src, cb, vendorIndex` | `server/vendor.lua` |
| `rsg-hunting:server:sellBasket` | server | `src, cb, vendorIndex, basket` | `server/vendor.lua` |
| `rsg-hunting:server:claimWeekly` | server | `src, cb` | `server/xp.lua` |
| `rsg-hunting:server:getLeaderboard` | server | `src, cb, mode` | `server/xp.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-hunting:server:getBounties', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-hunting:server:giverewards` | server | `netId, quality` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-hunting:server:giverewards', netId, quality)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/resetvendorstock` |  | `server/vendor.lua` |
| `/huntingwebhooktest` | locale('wh_test_help') | `server/webhooks.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
