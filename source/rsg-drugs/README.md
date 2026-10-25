# rsg-drugs

Drug production for RSG Framework (cannabis lab: drying, processing, packing bags & bricks with hired crew) plus a built-in player & NPC addiction system with rehab.

## Install
1. `ensure rsg-drugs`
2. Run `installation/install.sql` and add `installation/shared_items.lua` to `rsg-core/shared/items.lua`.
3. Lab settings: `shared/config.lua` · Addiction settings: `shared/config_addiction.lua` (`Config.Addiction`).

## Brick export (demand market)
Players at **Distributor or higher** (`Config.Export.MinLevel`) can sell `weed_brick` to a buyer NPC (`Config.Export.NPC`, ox_target *Talk business*). Settings: `shared/config_export.lua`.
- **Price follows supply**: an empty market pays `MaxPrice` (default $3,000); as the buyer's stock approaches `Saturation` (40 bricks) the price slides towards `MinPrice` ($800). Every brick sold raises his stock, so a big dump earns less per brick (each brick in a deal is priced in turn).
- **Recovers over time**: every `TickMinutes` the buyer offloads around `DrainPerHour` bricks/hour (±30%) and demand drifts randomly between `DemandMin`–`DemandMax`, so prices rise and fall realistically.
- The market is shared by all players and saved in resource KVP (survives restarts, no SQL).
- NUI shows the current price with trend, a price chart of recent market updates, a demand bar (Hungry → Steady → Saturated → Flooded) and an exact payout preview. Max `MaxPerSale` bricks per deal, `Cooldown` between deals.
- After a deal the panel closes and the same handover animation as NPC bag sales plays (`Config.Addiction.Selling.Anim`).
- Server-side checks: distance to the buyer, level, item count, cooldown; payout computed on the server. Each exported brick gives `Config.XP.Sell.weed_brick` XP (60).
- ⚠️ The default buyer coords are the Van Horn general store keeper's spot (rsg-shops). Move `Config.Export.NPC.coords` to your own location.

## Seeds
Dryers have a small chance (`Config.SeedChance`, default 2% per fresh weed dried) to find a `seedweed` (rsg-farming's weed seed). Found seeds are stored in the lab (shown in the Overview stock) and collected from **Supplies → Collect → Weed Seeds**, so you can replant with rsg-farming. Change the item in `Config.Items.seed`.

## Reputation (XP)
Drug work earns XP, stored as rsg-core rep `drugs` (`metadata.rep.drugs`). Settings: `Config.XP` in `shared/config.lua`.
- **Production**: the lab owner earns XP for every finished unit their crew makes (default: bag 1 XP, brick 50 XP; dried/processed 0). XP earned while offline is banked and paid the next time the owner opens the lab.
- **Selling**: each weed bag sold to an NPC gives 2 XP.
- **Levels**: Street Kid → Peddler → Dealer → Supplier → Distributor → Kingpin (thresholds in `Config.XP.Levels`). Level and progress show at the top of the lab Overview, with a notification on level-up.
- **Brick packing lock**: anyone can run a lab, but `weed_brick` packing needs the owner to be `Config.XP.BrickMinLevel` or higher (default 5 = Distributor, so Distributor and Kingpin). Below that, packers can't be switched to bricks and any brick packers sit idle (shown as locked in the UI). Enforced on the server; bricks already made can still be collected. Drop below the level (e.g. after jail) and brick packing stops until you earn it back.
- **Jail**: when a player starts an rsg-prison sentence their drug XP (and any XP banked in their lab) is reset to 0 and no XP can be earned while jailed (`Config.XP.ResetOnJail`). The wipe also triggers on any XP check while `metadata.injail > 0`, so it can't be dodged. Rehab doesn't count.
- All XP is granted server-side from config values; clients can't send amounts.

```lua
-- server exports, e.g. from a brick delivery script
exports['rsg-drugs']:AddXP(src, 25, 'delivery') -- add a "xp_reason_delivery" locale key for a custom label
exports['rsg-drugs']:GetXP(src)                 -- { xp, level, label, from, to }
exports['rsg-drugs']:ResetXP(src)               -- wipe to 0, returns XP removed
```

## Languages
Every player-facing string (notifications, targets, commands, NUI panels, HUD and the config labels for skills, roles, packing, XP levels, substances and withdrawal stages) is in `locales/*.json`.

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Pick one with the ox_lib convar in `server.cfg`:
```
setr ox:locale de
```
Config labels use `cfg_*` keys (e.g. `label = locale('cfg_skill_1')`). You can still put a plain string there if you only run one language. Discord logs stay in English (admin-only).

## Discord logs
Every important action is logged to Discord as an embed with the character name, citizen ID, server ID, license, Discord mention and coords. Settings: `server/config_discord.lua` (**server-only**, so webhook URLs are never sent to clients).

1. In Discord: *Channel settings → Integrations → Webhooks → New Webhook → Copy URL*.
2. Paste URLs into `ConfigDiscord.Webhooks` (one channel per category), or just set `ConfigDiscord.Default` to send everything to one channel. Set a category to `false` to switch it off.

| Category | What's logged |
|---|---|
| `lab` | hire, fire, packer reassign, weed deposits, pantry stock, product collected, payroll funded |
| `sales` | weed bag sales (price, addict/ambient buyer), refusals that alert the law |
| `export` | brick exports (bricks, payout, average per brick, buyer stock, demand) |
| `xp` | level ups, XP resets (jail / `ResetXP`) |
| `rehab` | player admissions (who, by whom, minutes), voluntary check-ins, releases, escape attempts, NPC rehabs, bonuses paid |
| `admin` | `/clearaddiction`, `/setaddiction` |
| `security` | lab requests out of range, invalid hire requests, officers sending their own customers to rehab |

- Logs are queued and batched (up to 10 embeds per message every `FlushSeconds`) with automatic back-off on Discord rate limits (HTTP 429), so busy servers don't get webhooks blocked.
- `MinDeposit` / `MinWithdraw` filter out small transactions to cut noise.
- Other server resources can write into the same channels:
```lua
exports['rsg-drugs']:DiscordLog('sales', 'Delivery completed', src, { { 'Bricks', 5 }, { 'Payout', '$12000' } })
```

## Addiction

Player & NPC addiction system for RSG Framework (alcohol and weed). Keep feeding the habit or suffer withdrawal; the only way to get clean is a stint in rehab at Sisika.

### How it works
- **Dependency (0-100)** rises every time a configured item is used. Past the substance's `threshold` the player is **hooked**.
- While hooked, **craving** grows every `Config.Addiction.TickInterval` seconds. Using the substance resets craving to 0 (but raises dependency further).
- Craving drives **withdrawal stages**:
  1. *Uneasy* – light camera shake, small stress gain
  2. *Shaking* – heavier shake, groggy screen effect, stamina capped at 50, stumbles while moving
  3. *Withdrawal* – severe shake, stamina capped at 20, frequent stumbles, more stress
- **Smoking a joint gives a boost**: refills Stamina and Dead Eye cores, fortifies (gold) them for 45s and relieves 30 stress via rsg-hud. All tunable in `Config.Addiction.Substances.weed.boost`. The catch: each joint also raises dependency.
- Not hooked? Dependency slowly decays on its own.
- **Rehab** wipes all addictions after the timer is served (online time only). Players are teleported into Sisika and fenced in; on completion they're released at the gate.
- Lawmen (job type `leo`), medics (`medic`) or admins: `/rehab [id] [minutes]` (target within 5m unless admin).
- Voluntary: talk to the rehab doctor NPC at the Sisika gate (ox_target *Check in to rehab*). Only offered while you are not already in rehab.
- Withdrawal is held at stage 1 during rehab and substances can't be used.
- **Inspect NPCs** (lawmen/medics on duty): ox_target *Look them over* on an ambient NPC shows whether they're hooked. *Send to rehab* clears an NPC addict.
- **Rehab bonus**: lawmen/medics are paid `Config.Addiction.Rehab.Reward.Amount` (default $1) per admission, for players via `/rehab` and for NPCs via ox_target (NPC rewards have a per-officer cooldown, and no bonus for NPCs you sold to yourself). Only real addicts can be admitted by job holders, and no one already in rehab.

### Selling weed bags to NPCs
- Players carrying a `weed_bag` get *Sell Bag of Weed* on ambient NPCs (shop/script NPCs and riders are excluded).
- **Addicted NPCs always buy.** Others buy `BuyChance`% of the time and become weed addicts.
- A refusing NPC runs off, can't be asked again, and reports it: on-duty law (`AlertJobTypes` / `AlertJobs`) gets a notification and a pulsing **Drug Selling Hotspot** radius blip near the spot for `AlertDuration` seconds. Repeated refusals in one area build up a visible hotspot.
- **NPC addicts** stagger (ped drunkness), brace against walls and ragdoll in withdrawal, and periodically smoke to feed their habit.
- NPC addicts are tracked on the **server** by network id and flagged with the `rsgAddict` entity statebag, so every lawman can see and rehab them, and clients can't fake an addict to force a sale. The staggering/smoking behaviour plays on the seller's client. The server must see the NPC within 4m to allow a sale (`RequireNetworkedPed`); set it to `false` only if your population peds aren't networked. Settings: `Config.Addiction.Selling` and `Config.Addiction.NPC`.
- Other scripts can add the visual addict behaviour to a ped: `exports['rsg-drugs']:NpcSoldWeedBag(ped)` (client, visual only).

### Install
1. Addiction is built into rsg-drugs — just `ensure rsg-drugs` after rsg-consume. Remove the old `rsg-addiction` resource if you had it.
2. Alcohol: items are consumed by **rsg-consume**; this script listens to `rsg-consume:client:consume`. Nothing else needed.
3. Weed: this script makes `weed_joint` usable (smoking). Add it from `installation/shared_items.lua` and add a `weed_joint.png` to rsg-inventory images.
4. No SQL needed. Data lives in player metadata `addiction` and is mirrored to the `addiction` statebag.

### Commands
| Command | Who | |
|---|---|---|
| `/addiction` | everyone | Status panel (NUI) |
| `/rehab [id] [minutes?]` | leo / medic / admin | Send a player to rehab (job holders: addicts only, pays the rehab bonus) |
| `/clearaddiction [id]` | admin | Wipe addiction |
| `/setaddiction [id] [alcohol\|weed] [0-100]` | admin | Set dependency |

### Exports (server)
```lua
exports['rsg-drugs']:AddUse(src, 'weed', 10)   -- register a use from your own (trusted) server code
exports['rsg-drugs']:GetAddiction(src)        -- { rehab = secs, subs = { alcohol = {level, craving}, ... } }
exports['rsg-drugs']:IsInRehab(src)
```

### Data sources
- Alcohol item names: `rsg-consume/shared/config.lua` · `weed_joint`: `installation/shared_items.lua`
- Sisika coords: `rsg-prison/config.lua`
- `DRUNK_SHAKE`, `SHAKE_GAMEPLAY_CAM`: `natives/db/CAM.md` · `_SET_PED_DRUNKNESS 0x406CCF555B04FAD3`: `natives/db/PED.md`
- Stamina core `_GET/_SET_ATTRIBUTE_CORE_VALUE` (index 1): `natives/db/ATTRIBUTE.md`
- `playerdrugshalluc01`: rdr3_discoveries `graphics/animpostfx` · `PlayerHealthPoorCS`: rsg-consume config
- Scenarios `WORLD_HUMAN_SMOKE`, `WORLD_HUMAN_DRINKING`, `WORLD_HUMAN_DRUNK_BRACE_WALL_NO_VOMIT`: rdr3_discoveries `animations/scenarios`

Support: https://buymeacoffee.com/rexshack
