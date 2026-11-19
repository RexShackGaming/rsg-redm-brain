# rsg-reputation

Honor and regional standing for the RSG Framework. Every character has one **honor** score (how honorable they are overall) and a **standing** in each state and town (how that place sees them, from infamy to fame). Other scripts report what players do, and read the result to change prices, lawman reactions and access.

Version 3.0.0 · Requires `rsg-core` and `oxmysql` · No ox_lib, no target and no inventory dependency

Full developer and server owner documentation is in [DOCS.md](DOCS.md).

## Features
- **Honor** per character (-1000 to +1000) with seven labelled tiers, from Notorious to Exemplary.
- **Standing** per region (-100 to +100) for 5 states plus Guarma and 10 towns. A change in a town also moves its state (configurable spill-over).
- Standing tiers carry a **price modifier** and a **hostile** flag, so shops can charge more and lawmen can react without each script inventing its own rules.
- **Named actions** (`theft`, `robbery`, `murder`, `bounty_delivered`, ...) defined in config. Scripts report `ApplyAction(src, 'robbery', 'valentine')` and you tune the numbers in one place.
- Optional daily **decay** toward neutral, for honor and for standing. It also applies while players are offline.
- Reputation panel (`/reputation`) in the RSG house style, with a centred bar per region.
- Server-only changes: clients can never change a reputation. Scripts use server exports.
- Notifications for changes and tier changes through rsg-core notify, plus server events other scripts can listen to.
- Client read-only exports (honor, standing, tiers, price modifier, hostile).
- Admin commands to add, set, reset and inspect reputation (also from the server console).
- Push-to-talk keeps working while the panel is open.
- Database tables are created automatically.

## Installation
1. Copy the `rsg-reputation` folder into your resources.
2. Start it after `oxmysql` and `rsg-core`, and before any script that uses it:
   ```
   ensure oxmysql
   ensure rsg-core
   ensure rsg-reputation
   ```
3. Database: the tables (`rsg_reputation`, `rsg_reputation_standing`) are created automatically on first start. To install manually instead, set `Config.AutoDatabase = false` in `shared/config.lua` and import `install.sql`.
4. Optional: set the language with `setr rsg:locale de` in `server.cfg` (see Locales).
5. Reputation does nothing on its own. Scripts must report actions (`ApplyAction`, `AddHonor`, `AddStanding`) and read results (`GetPriceModifier`, `IsHostile`, `HasHonor`). No existing RSG resource does this yet.

## Configuration
All options are in `shared/config.lua`.

| Option | Default | Description |
| --- | --- | --- |
| `AutoDatabase` | `true` | Create the tables on start. Set `false` and import `install.sql` to do it by hand. |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the panel is open. |
| `PushToTalkControls` | `0x4BC9DABB` | Controls left enabled while the panel has focus. |
| `Command` | `'reputation'` | Chat command that opens the panel (`''` to disable). |
| `AdminPermission` | `'admin'` | Permission level for the admin commands. |
| `NotifyChanges` | `true` | Small "Honor +5" / "Valentine standing -8" notifications. |
| `NotifyTierChange` | `true` | Notification when a player enters a new tier. |
| `SaveInterval` | `60` | Seconds between saves of changed values. Also saved on logout and when the resource stops. |
| `MaxChangePerCall` | `200` | Safety cap on one `AddHonor` / `AddStanding` call. |
| `Honor` | `Min -1000, Max 1000, Start 0, Decay off` | Range, starting value, optional decay and the tier list. |
| `Standing` | `Min -100, Max 100, ParentSpill 0.5, Decay 2/day` | Range, spill-over to the state, decay and the tier list (with `priceModifier` and `hostile`). |
| `Regions` | 15 regions | Region ids, labels, type (`state` / `town`), `parent` state and panel `order`. |
| `Actions` | 9 actions | Named changes: `{ honor = n, standing = n }`. |

## How to use
**Players**
- `/reputation` opens the panel. Use it again, the close button or Escape to close it.
- Honor is shown at the top. Below it every region the player is known in shows a bar (left is infamy, right is fame), the tier name, a hostile mark and the price change. "Show all" lists every region.

**Admin commands** (permission `Config.AdminPermission`; `id` is the player's server ID, the player must be online; region ids are the keys in `Config.Regions`, such as `valentine`)

| Command | Description |
| --- | --- |
| `/addhonor [id] [amount]` | Add honor (negative removes). |
| `/sethonor [id] [value]` | Set honor to an exact value. |
| `/addstanding [id] [region] [amount]` | Add standing in a region (spill-over applies). |
| `/setstanding [id] [region] [value]` | Set standing in a region to an exact value. |
| `/resetreputation [id]` | Reset honor and all standing to the starting values. |
| `/reputationinfo [id]` | Show a player's honor and the regions they have standing in. |

## For developers
Server side, report what the player did and let the config decide the numbers:
```lua
-- apply a named action (honor always, standing only when a region is given)
exports['rsg-reputation']:ApplyAction(src, 'robbery', 'valentine')

-- or change values directly
exports['rsg-reputation']:AddHonor(src, 5, 'helped a stranger')
exports['rsg-reputation']:AddStanding(src, 'rhodes', -10, 'brawl')

-- read the result
local mod = exports['rsg-reputation']:GetPriceModifier(src, 'valentine') -- e.g. 0.10 = 10% dearer
price = price * (1 + mod)
if exports['rsg-reputation']:IsHostile(src, 'saint_denis') then return end
if not exports['rsg-reputation']:HasHonor(src, 400) then return end
```
Listen for tier changes:
```lua
AddEventHandler('rsg-reputation:server:tierChanged', function(src, kind, region, oldTier, newTier)
    -- kind is 'honor' or 'standing'; region is nil for honor
end)
```
All exports, events and callbacks are in [DOCS.md](DOCS.md).

## Locales
Ships with `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br` and `ro`, all with the same keys. Tier names are locale keys (`honor_*`, `standing_*`) and region labels may be plain text or a locale key; a new tier or region needs matching entries only if you use a locale key for it.

## Notes
- Regions are passed by the calling script (for example the town a shop belongs to). The resource does not detect the player's location by itself.
- Decay is applied lazily: when a player loads, and every 30 minutes for online players. A day is a block of 86,400 seconds since the last decay.
- Values are saved every `SaveInterval` seconds, on logout and when the resource stops. A hard server crash can lose up to one interval of changes.

---
Support the Project : https://rexshack.tebex.store/
