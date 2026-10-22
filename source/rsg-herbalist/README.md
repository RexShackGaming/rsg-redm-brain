# rsg-herbalist

A herb gathering, tonic crafting, and mystery box script for **RSG-Core** RedM servers, by RexShack.

Players gather herbs from world-placed nodes, brew them into tonics at a mortar & pestle, and can stumble on a roaming mystery box that relocates around the map every so often. Every gather, craft, and loot roll is validated server-side, and an optional Discord webhook system can log activity (and flag likely exploiting) to your Discord.

---

## Features

### Herb gathering
- Hundreds of herb/orchid spawn points across the map (`shared/zones_data.lua`), grouped into zones, each zone spawning a fixed rotation of plant types.
- Nodes stream in/out as players approach (composite entity pickups, not peds/objects), so there's no meaningful client-side load cost even with thousands of spawn points defined.
- Press the game's native "pick up" binding near a node to gather; a progress bar (via `ox_lib`) plays the gather animation.
- Gathered nodes go empty and regrow after a configurable cooldown, becoming a new (server-picked) plant type from the same zone so it isn't the same herb every time.
- Every gather is validated server-side: the client only sends a spawn **id**; the server knows which plant is live there, checks it isn't already picked, that the player is within range and not on cooldown, and that they have room before granting the item.
- Spawn ids come from `shared/spawns.lua`, which builds the same deterministic list on client and server (no float-formatted coordinate keys, so no client/server mismatches).

### Tonic crafting
- Four configurable tonic recipes (Healing, Stamina, Snake Oil Antidote, Energy), each with its own ingredients, craft time, and output.
- The **only** entry point is using the `mortarpestle` inventory item - there's no command or export, so there's exactly one door in.
- A draggable, NUI-based crafting menu shows every recipe, how many of each ingredient the player is currently carrying, and whether they have enough to craft.
- The server independently re-validates the job lock, ingredient counts, and craft cooldown on every request - the NUI is purely presentational and can't be used to grant anything on its own.
- Optional job lock (`Config.LockTonicCraftingToJob`) restricts crafting to a specific job.
- Crafting plays a configurable animation sequence and scripted camera. Ingredients are only taken when the craft **finishes** (the server checks the recipe time actually elapsed and re-checks ingredients and inventory space), so cancelling or disconnecting mid-craft never loses anything.
- Finished tonics apply a configurable health/stamina boost when consumed, using the same "overpower" native the game's own tonics use, with a shared cooldown between tonic uses to prevent chain-drinking.

### Mystery box
- A single box exists on the map at a time, picked from a configurable list of coordinates, and relocates to a new spot on a timer (or immediately after being looted).
- Opening it (in range, on a cooldown) rolls a random haul: several regular herbs plus exactly one guaranteed rare orchid. If the player can't carry the haul the box stays put. Unknown items in the loot pools are skipped with a console warning at start.
- Same server-authoritative validation as gathering: distance, cooldown, and one-shot looting so two players can't loot the same box.

### Discord webhook logging
- Optional, fully configurable per event category (`shared/webhook_config.lua`): tonic crafting, mystery box loot, herb gathering, resource start/stop, and version checks each have their own on/off switch and webhook URL, so you can route them to different channels.
- Built-in **anti-cheat alerting**: distance violations, plant-mismatch attempts, cooldown spam, and other rejected requests are tracked per player and only escalate to a Discord alert once a player racks up repeated violations in a short window - so one packet hiccup won't spam your log channel, but a real exploit attempt will.
- Queued delivery that respects Discord's rate limits, with automatic retry on HTTP 429.

### Version checking
- On start, checks the resource's version against `version.txt` in the [rsg-versioncheckers](https://github.com/Rexshack-RedM/rsg-versioncheckers) GitHub repo and prints a warning to console if you're out of date.

---

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)

All three must be started **before** `rsg-herbalist` in your `server.cfg`.

---

## Installation

1. Drop the `rsg-herbalist` folder into your server's `resources` directory.
2. *(Only if you job-lock crafting with `Config.LockTonicCraftingToJob`)* create a `herbalist` job. If your server uses **rsg-multijob**, jobs live in the database, so add it there; `installation/shared_jobs.lua` shows the grades/fields to use. On a stock rsg-core install, paste it into `rsg-core/shared/jobs.lua` instead.
3. Add the items in `installation/shared_items.lua` to your `rsg-core` (or `rsg-inventory`, depending on your setup) `shared/items.lua`. This covers every herb, all four tonics, and the `mortarpestle` crafting item.
4. Copy every file in `installation/images/` into your inventory resource's item image folder (wherever `rsg-inventory` serves item icons from - commonly `rsg-inventory/html/images/`). This covers all the herb icons and the mortar & pestle icon.
   - Tonic icons (`tonic_*.png`) are included too. The crafting UI loads icons from `Config.InventoryImagePath` (default `nui://rsg-inventory/html/images/`) - change it if your inventory serves images from elsewhere.
5. Add `ensure rsg-herbalist` to your `server.cfg`, after `rsg-core`, `rsg-inventory`, and `ox_lib`.
6. Start the server. On first start, `Config.Debug = false` by default - flip it to `true` temporarily if you want verbose per-gather/per-craft console tracing while testing.

---

## Configuration

All gameplay settings live in `shared/config.lua`. Webhook settings are in their own file, `shared/webhook_config.lua` (see below).

### General

| Setting | Description |
|---|---|
| `Config.Debug` | Verbose console tracing for gathering, crafting, and streaming. Leave `false` in production. |
| `Config.InventoryImagePath` | Where the crafting UI loads item icons from. |

### Herb node streaming & pickup ranges

| Setting | Description |
|---|---|
| `Config.ScopeRangeLoad` / `Config.ScopeRangeUnload` | Distance (world units) at which a node streams in / streams back out. |
| `Config.NearbyRange` | Radius refreshed once a second for interaction checks; must comfortably exceed `PickupRange` plus how far a player can travel between refreshes. |
| `Config.PickupRange` | Client-side distance within which a node can actually be picked up. |
| `Config.CompositeLoadTimeoutMs` | Max time to wait for a composite asset to stream in before giving up on that node. |

### Gathering

| Setting | Description |
|---|---|
| `Config.GatherDurationMs` | Length of the gather progress bar. |
| `Config.GatherCooldownMs` | Server-side minimum time between gather attempts, per player. |
| `Config.ScopeRangeGather` | Server-side distance check before a gather is accepted (tighter than the client's streaming range). |
| `Config.SuppressionWearoffSeconds` | How long a gathered node stays empty before it regrows (as a new random plant from its zone). |

### Tonic crafting

| Setting | Description |
|---|---|
| `Config.TonicCraftingEnabled` | Master switch for the whole crafting system. |
| `Config.TonicCraftCooldownMs` | Server-side minimum time between craft requests, per player. |
| `Config.TonicCraftProgressBarEnabled` | Show a cancellable `ox_lib` progress circle during crafting. If `false`, crafting still takes the recipe's full duration, it just isn't shown or cancellable. |
| `Config.TonicCraftAnim` | Animation dict/clips played during crafting, with a fallback generic scenario if disabled or the dict fails to stream in. |
| `Config.TonicCraftCamera` | Scripted camera framing the player during the crafting animation. |
| `Config.TonicAttributeIndex` | RDR3 ped-attribute indices used for the health/stamina "overpower" boost natives - only change if a game build shifts the enum ordering. |
| `Config.TonicDrinkAnim` | Animation (and hand prop) played when a finished tonic is drunk. |
| `Config.TonicEffects` | Per-tonic health/stamina boost applied on consumption, keyed by item name. |
| `Config.TonicUseCooldownMs` | Minimum time between drinking tonics, shared across every tonic flavour. |
| `Config.LockTonicCraftingToJob` / `Config.TonicCraftingJobName` | Restrict crafting to a specific job (any grade). |
| `Config.Tonics` | The recipe list itself - id, label, description, image, craft duration, ingredients, and output for each tonic. Add/remove/edit entries here to change what can be crafted. |

### Mystery box

All under `Config.MysteryBox`:

| Setting | Description |
|---|---|
| `enabled` | Master switch. |
| `prop` | The physical prop model players see and interact with. |
| `coords` | Every possible spawn location; one is "live" at a time. |
| `relocateAfterSeconds` | How long the box sits at its current spot before relocating (also triggered immediately by a successful loot). |
| `pickupRange` / `scopeRangeGather` / `scopeRangeLoad` / `scopeRangeUnload` | Same meaning as the equivalent herb-node settings, scoped to the box. |
| `herbCountMin` / `herbCountMax` / `herbPool` | How many regular herbs (picked with repetition) are rolled per box, and the pool they're drawn from. |
| `orchidPool` | Exactly one entry from this pool is guaranteed in every box - the "rare" reward. |

### Discord webhooks (`shared/webhook_config.lua`)

| Setting | Description |
|---|---|
| `Config.Webhook.enabled` | Master switch for the whole system. |
| `Config.Webhook.botName` / `botAvatar` | Display name/avatar Discord shows for the webhook messages. |
| `Config.Webhook.queueIntervalMs` | Delay between queued sends, to stay under Discord's rate limit. |
| `Config.Webhook.maxRetries` | How many times a rate-limited (HTTP 429) message is retried before being dropped. |
| `Config.Webhook.identifiers` | Which player identifiers (Discord mention, Steam, license) to include on embeds. |
| `Config.Webhook.categories.<name>.enabled` / `.url` | Per-category on/off switch and webhook URL. Categories: `craft`, `mysterybox`, `anticheat` (on by default), `gather`, `resource`, `version` (off by default - high volume or low value unless you want them). |
| `Config.Webhook.categories.anticheat.mentionRoleId` | Optional Discord role ID to `@`-mention on every anti-cheat alert. |
| `Config.Webhook.antiCheat.violationWindowMs` / `.violationThreshold` | How many rejected requests from the same player, within what time window, before an anti-cheat alert actually fires (and re-fires every `violationThreshold` violations after that). |

To enable a category, set its `enabled = true` and paste a Discord webhook URL into its `url`. Leaving the URL blank silently disables that category even if `enabled = true`.

### Locales

Player-facing text (notifications, progress bar labels, the "open mystery box" prompt) lives in `locales/en.json`. Add another file in the same folder (e.g. `locales/de.json`) and switch `lib.locale()`'s language via `ox_lib`'s locale convention to translate.

---

## File overview

```
fxmanifest.lua              resource manifest
client/
  exports.js                 low-level composite-entity creation export
  client.lua                 herb node streaming, gathering, tonic crafting UI/animations
  mysterybox.lua              mystery box prop streaming + interaction
  controls.lua                "pick up" input binding helper
server/
  webhook.lua                 Discord webhook queue/delivery + anti-cheat violation tracking
  server.lua                   gather validation, tonic crafting validation, item granting
  mysterybox.lua               mystery box location/loot authority
  versionchecker.lua           GitHub version check on start
shared/
  config.lua                   gameplay config
  webhook_config.lua            Discord webhook config
  spawns.lua                    deterministic herb spawn list (shared ids for client/server)
  zones_data.lua                herb spawn point data
html/                         tonic crafting NUI (index.html, script.js, style.css)
locales/                      player-facing text (en, de, el, es, fr, ja, nl, pl, pt-br, ro)
installation/
  shared_items.lua              item definitions to copy into rsg-core/rsg-inventory
  shared_jobs.lua                herbalist job definition to copy into rsg-core
  images/                       herb/orchid/mortar & pestle icons to copy into your inventory's image folder
```

---

## Support

If you find this useful, you can support development here: https://buymeacoffee.com/rexshack
