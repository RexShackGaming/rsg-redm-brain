# rsg-goldclaim

A gold claim system for RedM (RSG-Core). Players place gold rockers, load them with paydirt and water, process the load into gold ore, and manage licensed or unlicensed claims. Every menu and dialog uses a custom RDR2 leather & gold NUI.

## Features

### Gold Claim / Rocker
- **Placeable gold rocker**: placement preview with rotation, which persists across restarts.
- **Licensed and unlicensed claims**: if you hold a `resource_gold_claim_license` (`Config.LicenseItem`) when placing, the license is used up and the claim becomes licensed, with a named zone, a map blip and enter/leave notifications. Without one, the claim is illegal.
- **LEO enforcement**: law enforcement (job type `Config.LeoJobType`) can destroy unlicensed claims and confiscate the rocker.
- **Async processing**: the server runs one cycle per `Config.ProcessingTime` and uses 1 water and 1 paydirt per cycle. Each cycle spawns a gold or paydirt output prop for the player who started it, so you can walk away.
- **Gold ore drops**: each gold pickup gives a random amount of `Config.GoldOreItem` (default `resource_gold_nugget`, amount `Config.GoldOreAmount`).
- **Gathering**: use a shovel in water to dig paydirt, or a bucket in water to fill it.
- **Degradation**: each rocker has a cron-based quality roll and is lost at 0%. Repair it with wood.
- **Rename claims**: owners of licensed claims can rename them (3 to 50 characters).

## Security model
Clients only ask for things. The server decides everything:
- Every rocker action checks that the player is near the rocker's **stored** server-side position.
- Placement checks distance, the per-character limit, spacing from other rockers, and the item. The model is always `Config.GoldRocker`, so a client-sent hash is never used.
- Output pickups are counted per rocker and per citizen, so a player can only claim outputs the server actually produced for them.
- Item and inventory changes go through `rsg-inventory` exports with `CanAddItem` checks, so items aren't lost when the inventory is full.
- Water and paydirt changes are atomic SQL updates, so spamming events can't push a rocker over its cap or process it twice. If a rocker fills up mid-action, the item is refunded.
- Pack-up and processing are locked against duplicate requests that arrive while the server is waiting on the database.
- Gathering, loading, repairing and renaming all have server cooldowns.

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation
1. **Database**: run `installation/rsg-goldclaim.sql`. If you are upgrading, run the two `ALTER TABLE` lines at the bottom of that file instead.
2. **Items**: add `installation/shared_items.lua` to `rsg-core/shared/items.lua`.
3. **Images**: copy the item images to `rsg-inventory/html/images/`.
4. **server.cfg**:
   ```
   ensure rsg-goldclaim
   ```

## Configuration
Everything lives in `shared/config.lua`. The key options are:

| Option | Default | Description |
|---|---|---|
| `NotifyPosition` | `'top-right'` | Where ox_lib notifications appear on screen |
| `NotifyDuration` | 10000 | How long notifications stay on screen (ms) |
| `MaxGoldRockers` | 4 | Rockers per character |
| `OwnerOnlyProcessing` | true | Only the owner can start processing |
| `LicenseItem` | `'resource_gold_claim_license'` | Item consumed to make a claim licensed |
| `LeoJobType` | `'leo'` | Job type that can destroy illegal claims |
| `DegradeChance` / `CronJob` | 5 / `*/30 * * * *` | Chance per rocker of losing 1% quality each cron run |
| `RepairWoodAmount` | 5 | Wood needed per repair |
| `ProcessingTime` | 60000 | Time per cycle in ms |
| `GoldChance` | 50 | % chance a cycle gives gold instead of paydirt |
| `MaxPaydirt` / `MaxWater` | 5 / 5 | Rocker capacity |
| `InteractDistance` / `PickupDistance` | 5.0 / 10.0 | Server-side distance checks |
| `PlaceMaxDistance` / `MinRockerSpacing` | 6.0 / 4.0 | Placement checks |
| `PropDrawDistance` | 60.0 | Distance at which rocker props stream in |
| `GoldOreItem` / `GoldOreAmount` | `resource_gold_nugget` / 1–5 | Item and amount given per gold pickup |
| `ClaimZoneRadius` | 20.0 | Zone radius of a licensed claim |
| `MaxClaimNameLength` | 50 | Max length of a claim name |



## Usage
1. Use a `tool_goldrocker` item. Rotate it with the arrow keys, then hold left mouse to place it or right mouse to cancel.
2. Dig paydirt with a `tool_rocker_shovel` and fill a `tool_rocker_bucket_empty` while standing in water.
3. Target the rocker to **Add Paydirt** and **Add Water**.
4. Open the rocker menu and choose **Start Processing**.
5. Pick up each output prop as it appears. Unclaimed outputs are kept by the server: if your inventory is full the prop comes back, and they respawn after a relog (until the server restarts).
6. Keep the rocker repaired. Packing it up requires 100% condition.
7. Use or sell the gold nuggets through your own smelter or shop scripts.

## Discord Webhooks
All logging is server-side. Configure it in `server/sv_config.lua`, which is a **server-only** file so webhook URLs are never sent to clients.

1. In Discord, open **Channel Settings → Integrations → Webhooks → New Webhook** and copy the URL.
2. Paste each URL into `SvConfig.Webhooks.Channels`. Any channel you leave empty falls back to `default`. If `default` is also empty, that log is skipped.
3. Run `goldclaim_webhooktest` in the **server console** to send a test embed for every enabled event.

| Event | Channel | Logged data |
|---|---|---|
| `rocker_placed` | placement | Rocker ID, licensed, claim name, coords, rockers owned |
| `rocker_packed` | placement | Rocker ID, claim name |
| `rocker_lost` | placement | Rocker lost at 0% condition (owner, Citizen ID) |
| `processing_started` | processing | Cycles, water/paydirt, condition |
| `gold_pickup` | processing | Gold ore amount |
| `paydirt_pickup` | processing | Off by default because it is noisy |
| `illegal_placed` | law | Unlicensed claim placed, with coords |
| `leo_destroyed` | law | Officer, job/grade, owner's Citizen ID |
| `claim_renamed` | claims | Old and new name |
| `suspicious` | security | Events fired from far away, non-LEO destroy |

Every embed includes the character name, server ID, Citizen ID, Discord mention, license and coords. You can toggle each of these with `ShowIdentifiers`. Each event can be turned on or off and given its own colour or channel in `SvConfig.Webhooks.Events`.

- **Role pings:** `SecurityPingRole` pings a role on suspicious activity.
- **Rate limiting:** embeds are batched (up to 10 per message) and queued per channel. When Discord returns 429, the batch is requeued and resent after `retry_after`. The queue is capped by `MaxQueueSize`.
- **Using it from other code:** call `Webhook.Log(event, src, title, { { 'Field', value }, ... }, { description, ping })` or `Webhook.Suspicious(src, reason, fields)`.

## Localisation
All text is in `locales/*.json` (ox_lib locales). This includes notifications, menus, placement prompts, NUI buttons, Discord webhook embeds. There is no hardcoded text in the Lua or the NUI.

Included languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`

To set the server language, add this to your `server.cfg`:
```
setr ox:locale de
```
Any key missing from a translation falls back to `en`. To add a language, copy `en.json`, translate the values, and keep every `%s` placeholder.

## Changelog
### 3.1.1
- Security: fixed a gold rocker duplication exploit. Firing the pack-up event twice quickly could return two rockers. The server now re-checks the rocker after its database read, and pack-up has a cooldown.
- Security: fixed processing being started twice on the same rocker by two quick requests, which doubled the output rate.
- Fix: if two players loaded a nearly-full rocker at the same time, one lost their paydirt or water. The item is now refunded.
- Fix: picking up an output with a full inventory deleted the prop while the server kept it, so it could never be collected. The prop now respawns.
- Fix: vegetation cleared around a rocker was never restored after the rocker was removed.
- Fix: starting processing on a broken rocker (0%) silently did nothing; it now tells you to repair it.
- UX: unclaimed outputs respawn after a relog or character switch, and outputs are spread out slightly instead of stacking on one spot.
- Optimisation: the degradation cron now runs one SQL update instead of one per rocker.
- Cleanup: removed unused CSS (toasts, confirm options, modal lines) and the matching dead JS, and merged a duplicated branch in placement.

### 3.1.0
- Reworked the shovel dig animation: new shovel grip offsets, smoother anim blend, and a cosmetic dirt pile (`Config.DigDirtPile`) left after digging.
- Removed all ox_lib progress bars. Timed actions now just play their scenario for the configured time without freezing the player; walk away or press Backspace/Esc to cancel. Removed the now-unused progress label locale keys.

### 3.0.3
- Fix: paydirt output props could never be picked up (server looked up the wrong pending key and errored).
- Fix: claim licences never worked: the code checked `goldclaimlicense` but the item is `resource_gold_claim_license`. Now `Config.LicenseItem`.
- Fix: `tool_rocker_bucket_full` was registered with the wrong `name` in `shared_items.lua`, so adding water failed.
- Fix: `Config.NotifyDuration` was documented but missing; notifications now use it (default 10s).
- Fix: vegetation modifiers stacked up every time a rocker streamed back in; each rocker now adds its modifier only once.
- Fix: processing consumed water/paydirt at the start of a cycle, so stopping mid-cycle lost them. It now consumes at the end, and stops if the rocker breaks.
- Security: the load cooldown now matches the add paydirt / water action time, so the event can't be fired faster than the animation.
- Security: rocker info (owner, contents) is only returned to players near that rocker.
- Items: paydirt, full bucket and the licence are no longer marked `useable` (they have no use handler).
- Docs: corrected item names and the `installation/` folder path.

### 3.0.2
- All notifications now stay on screen for 10 seconds. This can be changed with `Config.NotifyDuration`.

### 3.0.1
- All notifications, including claim zone enter/leave messages, now appear in the top right. The position can be changed with `Config.NotifyPosition`.

### 3.0.0
- Removed the Gold Agent entirely: NPCs, blips, menu, bar selling, config, locale keys, the `sell` webhook event and the `economy` channel.
- Removed `client/goldagent.lua` and `client/npcs.lua`.
- Removed `resource_gold_bar` and `resource_silver_bar` from `install/shared_items.lua`.

### 2.5.0
- Removed smelting from the Gold Agent, along with its settings, locale keys and webhook event. Gold Agents now only buy gold and silver bars.

### 2.4.0
- Replaced the small, medium and large gold nuggets with a single `resource_gold_ore` item.
- Smelting now asks only for the number of bars, using `Config.GoldOreSmelt` ore per bar.
- Removed `smallnugget`, `mediumnugget` and `largenugget` from `install/shared_items.lua`.

### 2.3.0
- Moved all remaining text (UI tooltips, blip name, webhook embeds) into locales.
- Added translations: de, el, es, fr, ja, nl, pl, pt-br, ro.

### 2.2.0
- Added a Discord webhook system: 10 events, 7 channels, batching, 429 handling, role pings, suspicious-activity logs and a console test command.
- Replaced the `rsg-log` call with a webhook log.

### 2.1.0
- Security: added server-side distance checks to every rocker, agent and pickup event.
- Security: placement no longer trusts the model hash sent by the client.
- Security: smelting is now timed by the server.
- Security: output pickups are counted per citizen, and loading uses atomic SQL updates.
- Security: added `CanAddItem` checks and cooldowns.
- Fix: the degradation roll was shared by every rocker. Each rocker now rolls on its own.
- Fix: the placement offset and heading were wrong unless you faced north.
- Fix: new players didn't get prop data because `PlayerLoaded` was the wrong kind of event.
- Fix: outputs from earlier cycles were overwritten.
- Fix: processing kept running after a rocker was removed.
- Fix: the LEO target option was evaluated once at spawn. It is now checked live.
- Fix: oxmysql boolean `licensed` values are now normalised.
- Fix: success notifications appeared even when the server rejected the action.
- Optimisation: rocker props now stream in and out by distance, all claim zones share one thread, and the 5-minute broadcast of all props was removed.
- UX: unavailable actions are disabled with a reason, and sell and smelt results are notified.
- UX: the amount field is now numeric, Enter submits, and the NUI labels are localised.
- Cleanup: notify helpers are shared in `client/utils.lua`.
- Cleanup: removed unused config keys, the unused confirm and alert dialogs, debug prints, legacy callbacks and the unused `resource_silver_ore` item.

## Credits
- Originally two scripts: `mack-goldclaim` and `mack-smelter`.
