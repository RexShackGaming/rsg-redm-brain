# rsg-drugs (v3.4.0)

Drug production for RSG Framework (cannabis lab: drying, processing, packing bags & bricks with hired crew), corner selling to NPCs with a haggle system, plus a built-in player & NPC addiction system with rehab.

## Requirements
`rsg-core` (3.0.3+), `rsg-inventory`, `rsg-target`, `oxmysql`. Optional: `rsg-consume` (alcohol), `rsg-hud` (stress relief), `rsg-weapons` (re-equip after rehab), `rsg-farming` (weed seeds). No ox_lib needed.

## Install
1. `ensure rsg-drugs` (after rsg-core, rsg-inventory and rsg-target)
2. Run `installation/install.sql` and add `installation/shared_items.lua` to `rsg-core/shared/items.lua`.
3. Lab settings: `shared/config.lua` · Addiction settings: `shared/config_addiction.lua` (`Config.Addiction`) · Corner selling: `shared/config_corner.lua` (`Config.Corner`).
4. Push-to-talk keeps working while a panel is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`). Panels close by themselves if you walk away from the NPC or die.

## Potency, heat and raids
- **Potency (0-100):** your crew's skill sets how potent what they make is (`Config.Quality.CrewPotency`), part of the input's potency carries through, and each stock type shows its potency in the lab panel. Withdrawn items carry `info.potency` and potency changes the sale price from `PriceMin` (x0.7) to `PriceMax` (x1.3). Bricks are exported best potency first.
- **Heat:** finishing bricks and bags, corner sales, exporting bricks and buyers who report you all build heat on your lab (see `Config.Heat`). Heat fades each shift. Above `RaidThreshold` there is a chance each shift that the lab is reported: on-duty law get a blip and a notification, you get a warning, and an officer can use *Raid Lab* on the processing NPC within `RaidWindowMinutes`. A raid destroys `SeizePercent` of every stock type and pays the officer `OfficerReward` (no reward for raiding your own lab). If the law is too slow your heat only drops to `HeatAfterEscape`.
- **Low wage chest:** you are warned when the chest covers fewer than `Config.Payroll.WarnShifts` shifts.

## Integrations (all optional)
- **rsg-skills:** a `drugs` skill is registered (`Config.Skills`). Drug XP feeds it. Perks: `sell_bonus` (corner sale and brick export price) and `speed_bonus` (crew output).
- **rsg-reputation:** dealing costs honor and standing in the nearest town, helping the law earns it (`Config.Reputation.Events`). In hostile towns most buyers ignore you.
- **rsg-economy:** corner sales use the town's market multiplier and push it down as you flood the town (`Config.Economy`). Needed for standing changes too (it provides the town lookup).

## Brick export (demand market)
Players at **Distributor or higher** (`Config.Export.MinLevel`) can sell `weed_brick` to a buyer NPC (`Config.Export.NPC`, rsg-target *Talk business*). Settings: `shared/config_export.lua`.
- **Price follows supply**: an empty market pays `MaxPrice` (default $3,000); as the buyer's stock approaches `Saturation` (40 bricks) the price slides towards `MinPrice` ($800). Every brick sold raises his stock, so a big dump earns less per brick (each brick in a deal is priced in turn).
- **Recovers over time**: every `TickMinutes` the buyer offloads around `DrainPerHour` bricks/hour (±30%) and demand drifts randomly between `DemandMin`–`DemandMax`, so prices rise and fall realistically.
- The market is shared by all players and saved in the `rsg_drugs_state` database table (survives restarts; created automatically).
- NUI shows the current price with trend, a price chart of recent market updates, a demand bar (Hungry → Steady → Saturated → Flooded) and an exact payout preview. Max `MaxPerSale` bricks per deal, `Cooldown` between deals.
- After a deal the panel closes and the same handover animation as corner sales plays (`Config.Corner.Anim`).
- Server-side checks: distance to the buyer, level, item count, cooldown; payout computed on the server. Each exported brick gives `Config.XP.Sell.weed_brick` XP (60).
- ⚠️ The default buyer coords are the Van Horn general store keeper's spot (rsg-shops). Move `Config.Export.NPC.coords` to your own location.

## Corner selling
Players sell what they carry on the street. Run **`/corner`** (`Config.Corner.Command`) to start working your spot, and run it again to stop.
- **Customers come to you.** While you work the corner an ambient townsperson within 40 m walks up to you; if nobody suitable is around (or they can't reach you) a customer is spawned 25-40 m away instead (`Config.Corner.Approach.Source`: `'both'` default, `'ambient'` or `'spawn'`), one every 12-35 seconds. When they arrive a haggle panel opens. After the deal spawned customers walk about 35 m away and are deleted; ambient ones go back to normal life. This repeats until you run out of stock or cancel with `/corner`.
- **You haggle.** The buyer wants up to `maxQty` of one of your items. You name a price per unit and they counter, back and forth, until:
  - they accept your price, or you press **Accept** on their counter: the goods and cash change hands and the handover animation plays;
  - they run out of patience (4-6 offers; asking far above their limit costs double) and walk off. An insulted buyer has a `CallLawChance`% chance to report you: on-duty law get a notification and a **Drug Selling Hotspot** blip, and you gain heat and lose honor and standing;
  - or you walk away (button or Esc). That costs nothing.
- Every buyer has a **hidden price limit** (90-135% of the street price) and a hidden opening offer, so a higher price pays more but risks the deal. The panel shows the street price as a starting point (`ShowStreetPrice`).
- **Street price** = the item's base price (`Config.Corner.Items`) x potency x the rsg-skills `sell_bonus` perk x the rsg-economy town multiplier.
- **Market average:** the haggle panel shows the average price per unit actually paid for that item over the last 40 sales by all players (`Config.Corner.Market`), once at least 3 sales exist, so you know roughly what weed is going for. It is saved in the database and survives restarts.
- You must stay within `Spot.LeaveRadius` (15 m) of where you started. The session also ends when you die, are jailed or in rehab, or run out of stock. On-duty law can't deal (`BlockLaw`).
- **Handover:** on a successful sale you and the buyer play the handover animation and a `s_drugpackage_02x` package visibly passes from your hand to theirs (`Config.Corner.Anim.Prop`: model, hand bone, `HandoffAt` timing and per-hand offsets so you can tune it in game; set `Enabled = false` for the animation only). Brick exports use the same handover.
- Each sale pays XP (`Config.XP.Sell`), builds heat (`Config.Heat.PerSale` per item), costs a little honor and standing, and is reported to the town market. In a town that is hostile to you most buyers ignore you (`Config.Reputation.HostileBuyMult`).
- Settings: `shared/config_corner.lua`. Sellable items: `weed_bag` and `weed_joint` by default, add more in `Config.Corner.Items`.
- The server runs the whole haggle and works out every price. The client only sends the price you type, and the server clamps and validates it.
- This replaces the old one-click *Sell Bag of Weed* target option and `Config.Addiction.Selling`.

### Buyers, ranks, stings and demand (3.7.0)
- **Buyer types** (`Config.Corner.Buyers`, picked by weight): *regular*, *tight wallet* (lower limit, more patient), *big spender* (higher limit, wants more, shorter fuse). The panel tags the non-regular ones.
- **Undercover stings** (`Config.Corner.Sting`): rarely a buyer is an undercover officer, only while enough law is on duty (`MinLaw`). Tells: an odd greeting, a generous offer shown straight away, and they accept almost anything. Taking the deal is a **bust**: the goods are seized, nobody is paid, heat rises and the law gets your exact position. Walk away if it smells wrong.
- **Corner rank** (`Config.Corner.Rank`): lifetime units sold on the corner (saved on the character) raise every price you get, Newcomer (+0%) up to Kingpin (+15%).
- **Demand** (`Config.Corner.Demand`): every unit sold pushes the street price down for everyone (up to -30%) and it recovers over time. Resets to normal on restart.
- **Town average:** where rsg-economy knows your town, the panel shows that town's average price when it has enough sales.
- **Investigating:** a hotspot blip shrinks while an on-duty officer stands inside it (`Config.Corner.Alert.ShrinkStep` / `MinRadius`) and fades after `Duration`. A bust shows the exact spot (`ExactRadius`).
- **Deal cap:** at most `Haggle.MaxDealsPerHour` (40) haggles per player per hour.

### Towns and regulars (3.4.0)
- **Towns** (`Config.Corner.Towns`, needs rsg-economy): each town can change the street price, how far buyers will go, how much heat sales create and how often a buyer is undercover. Keys are the rsg-economy region id in lower case; a town that isn't listed uses `Default`. Set `Config.Corner.Approach.Debug = true` to print the region of each buyer so you can copy the ids.
- **Regulars** (`Config.Corner.Regulars`): sell at a fair price (at or below street x `FairMult`) and the buyer may become one of your regulars (up to `Max`, saved on the character). A regular comes back now and then (`Return`, with a `CooldownMinutes` break), is tagged in the haggle panel, pays more (`CeilingBonus` % per level) and orders more (`QtyBonus`) as loyalty grows (`PerLevel` sales per level), and is never undercover. Insult one and you lose loyalty, and the regular for good at zero.
- **Bribes** (`Config.Heat.Bribe`): in the lab's Overview tab the owner can pay an officer (cost `Base` + heat x `PerHeat`). With a raid pending it has `SuccessChance` % to call the raid off (heat drops to `HeatAfterBribe`); if it fails the money is gone and heat rises by `FailHeat`. With no raid pending, once heat is at `MinHeat` it cuts `HeatCut` heat. One bribe per lab every `CooldownMinutes`, win or lose.

## Lab upgrades, events and leaderboard (3.7.0)
- **Upgrades tab** (`Config.Upgrades`): dryer, processor and packing bench add output per level (+10/+20/+35%), *Fire & security* lowers event risk (-25/-50/-75%). Paid in cash at the lab.
- **Random events** (`Config.Events`): each shift a lab with crew or stock has a `Chance`% (default 3) of an event. A worker on strike or owed pay may steal part of one stock type and quit; otherwise a fire destroys part of the fresh and dried weed. Owners who are offline see a notice next time they open the lab.
- **Leaderboard tab** (`Config.Board`): top dealers by money earned (corner and brick sales), with units sold and best potency. Stored in `rsg_drugs_state`.

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

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Locales are loaded by rsg-core. Pick one in `server.cfg` (falls back to `ox:locale`, then `en`):
```
setr rsg:locale de
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
- Voluntary: talk to the rehab doctor NPC at the Sisika gate (rsg-target *Check in to rehab*). Only offered while you are not already in rehab.
- Withdrawal is held at stage 1 during rehab and substances can't be used.
- **Inspect NPCs** (lawmen/medics on duty): rsg-target *Look them over* on an ambient NPC shows whether they're hooked. *Send to rehab* clears an NPC addict.
- **Rehab bonus**: lawmen/medics are paid `Config.Addiction.Rehab.Reward.Amount` (default $1) per admission, for players via `/rehab` and for NPCs via rsg-target (NPC rewards have a per-officer cooldown `NpcCooldown`, player admissions have `PlayerCooldown`, and there is no bonus for NPCs you sold to yourself). Only real addicts can be admitted by job holders, and no one already in rehab.

### NPC addicts
- Ambient buyers can get hooked when a corner sale is made with an item that has `addicts = true` (`Config.Corner.Items`, chance `Config.Addiction.NPC.SaleChance`). Spawned customers are deleted after the deal and never get hooked. A hooked buyer comes back after `Config.Corner.AddictRebuyMinutes` (5); `Config.Addiction.NPC.AmbientPopTypes` can make the server confirm a buyer is a real ambient ped before it can be hooked (off by default: set `Config.Corner.Approach.Debug = true` to print population types first); other ambient buyers only ever buy once. Hooked NPCs stagger, brace against walls and ragdoll in withdrawal, and periodically smoke to feed their habit.
- NPC addicts are tracked on the **server** by network id and flagged with the `rsgAddict` entity statebag, so every lawman can see and rehab them, and clients can't fake an addict. The staggering/smoking behaviour plays on the seller's client. Settings: `Config.Addiction.NPC`.
- Other scripts can add the visual addict behaviour to a ped: `exports['rsg-drugs']:NpcSoldWeedBag(ped)` (client, visual only).

### Install
1. Addiction is built into rsg-drugs — just `ensure rsg-drugs` after rsg-consume. Remove the old `rsg-addiction` resource if you had it.
2. Alcohol: items are consumed by **rsg-consume**; this script listens to the server event `rsg-consume:server:consumed` (needs rsg-consume 3.3.0+). Nothing else needed.
3. Opium: this script makes `opium_resin` usable (it is a hook for your own gathering or crafting script; nothing here produces it). Tobacco is fed by rsg-smoking.
4. Weed: this script makes `weed_joint` usable (smoking). Add it from `installation/shared_items.lua` and add a `weed_joint.png` to rsg-inventory images.
4. No SQL needed. Data lives in player metadata `addiction` and is mirrored to the `addiction` statebag.

### Commands
| Command | Who | |
|---|---|---|
| `/corner` | everyone | Start or stop corner selling (NPCs come to you and you haggle). Command name: `Config.Corner.Command` |
| `/addiction` | everyone | Status panel (NUI) |
| `/rehab [id] [minutes?]` | leo / medic / admin | Send a player to rehab (job holders: addicts only, pays the rehab bonus) |
| `/clearaddiction [id]` | admin | Wipe addiction |
| `/setaddiction [id] [alcohol\|weed] [0-100]` | admin | Set dependency |

### Exports (server)
```lua
exports['rsg-drugs']:AddUse(src, 'weed', 10)   -- register a use from your own (trusted) server code
exports['rsg-drugs']:GetAddiction(src)        -- { rehab = secs, subs = { alcohol = {level, craving}, ... } }
exports['rsg-drugs']:IsInRehab(src)
exports['rsg-drugs']:IsCornerSelling(src)    -- true while the player is working the corner
exports['rsg-drugs']:StopCorner(src)          -- end their corner session (e.g. from your own jail script)
```

### Data sources
- Alcohol item names: `rsg-consume/shared/config.lua` · `weed_joint`: `installation/shared_items.lua`
- Sisika coords: `rsg-prison/config.lua`
- `DRUNK_SHAKE`, `SHAKE_GAMEPLAY_CAM`: `natives/db/CAM.md` · `_SET_PED_DRUNKNESS 0x406CCF555B04FAD3`: `natives/db/PED.md`
- Stamina core `_GET/_SET_ATTRIBUTE_CORE_VALUE` (index 1): `natives/db/ATTRIBUTE.md`
- `playerdrugshalluc01`: rdr3_discoveries `graphics/animpostfx` · `PlayerHealthPoorCS`: rsg-consume config
- Scenarios `WORLD_HUMAN_SMOKE`, `WORLD_HUMAN_DRINKING`, `WORLD_HUMAN_DRUNK_BRACE_WALL_NO_VOMIT`: rdr3_discoveries `animations/scenarios`

Support the Project : https://rexshack.tebex.store/

## Database

Tables (`rsg_drugs_labs`, `rsg_drugs_state`) are created automatically on first start while `Config.AutoDatabase = true` (default); the database user needs `CREATE` permission. To install manually, set `Config.AutoDatabase = false` in the config and import `installation/install.sql` once.
