# rsg-hunting – Docs (v3.2.2)

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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

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

Support the Project : https://rexshack.tebex.store/
