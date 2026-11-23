# rsg-deliveries

A wagon delivery system for RedM using the RSG Framework. Players pick up goods from NPC foremen at various towns and deliver them by wagon to destinations across the map for cash and item rewards.

Talking to a foreman opens a NUI contract board listing every destination from that hub. Selecting a route shows its distance, time limit, wagon, difficulty rating, a route-length bar, and the cash and item rewards (with item images when configured).

Version 3.3.0. Full technical reference (events, security model, troubleshooting): [DOCS.md](DOCS.md)

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-target](https://github.com/Rexshack-RedM/rsg-target)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [oxmysql](https://github.com/communityox/oxmysql) (streaks and leaderboard; the table is created automatically)
- Optional: rsg-skills, rsg-economy, rsg-reputation, rsg-society, rsg-ambush (each is skipped when not started)
- OneSync (needed for the server-side wagon check, see `Config.RequireWagonAtDestination`)

## How It Works

1. Talk to a foreman and pick a contract on the board.
2. The server checks you are at the hub, have no active delivery and are off cooldown, then the wagon spawns and a GPS route is set.
3. Drive the wagon to the marked drop-off before the time limit runs out. A wrecked or lost wagon, or dying, fails the contract.
4. When the wagon reaches the drop-off, the server checks the player, wagon and travel time, then pays the cash and rolls the item reward.

## Commands

| Command | Description |
|---------|-------------|
| `canceldelivery` | Cancels the active delivery (the cooldown still applies). Also declines an open return load |
| `returntrip` | Accepts the return load offered after a delivery (`Config.ReturnTrips.Command`) |

## Configuration

All options are in `shared/config.lua`.

### General Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Config.DistanceSpawn` | float | `20.0` | Distance at which NPCs spawn |
| `Config.FadeIn` | bool | `true` | Fade NPCs in/out on spawn/despawn |
| `Config.SpawnVehDistance` | float | `5.0` | Radius to check for blocking vehicles at cart spawn |
| `Config.DestinationMarker` | bool | `true` | Show destination marker on the ground |
| `Config.UIPosition` | string | `"top-center"` | rsg-core `DrawText` position for the timer UI |
| `Config.FadeIncrement` | int | `51` | Alpha step for NPC fade effect |
| `Config.DefaultDeliveryTime` | int | `30` | Time limit per delivery (minutes) |
| `Config.MaxRewardAmount` | int | `500` | Maximum cash reward cap |
| `Config.InteractionDistance` | float | `2.0` | NPC interaction range |
| `Config.ShowDeliveryTimerUI` | bool | `false` | Show the time remaining / distance text UI during a delivery |
| `Config.CompleteDistance` | float | `10.0` | How close the wagon must be to the drop-off to complete |

| `Config.MaxPayoutAmount` | int | `1000` | Hard cap on the final payout after every bonus |
| `Config.AutoDatabase` | bool | `true` | Create the `rsg_deliveries_stats` table on start. Set `false` and import `install.sql` to install manually |

### Features (all in `shared/config.lua`)

| Feature | Config | What it does |
|---|---|---|
| Teamster skill (rsg-skills) | `Config.Skills` | Awards XP per delivery. Perks `pay_bonus` (% extra cash) and `time_bonus` (% longer time limit) |
| Economy (rsg-economy) | `Config.Economy` | The payout is a `sell` quote for the hub's town: tax goes to the town treasury |
| Fragile cargo | `Config.Fragile`, route `fragile = true` | The server reads the wagon's health on arrival and scales the pay down to `MinPayPct`. The player is warned once below `WarnBelowPct` |
| Streaks | `Config.Streak` | Deliveries within `Window` seconds of each other add `BonusPerStep` % each, up to `MaxBonusPct` |
| Hot route | `Config.HotRoute` | One route per hub each day (rotates at midnight UTC) pays `BonusPct` % extra and is badged on the board |
| Return trips | `Config.ReturnTrips`, hub `noReturn = true` | After a delivery the wagon is kept for `OfferTime` seconds. Type `/returntrip` to haul a load back to the hub for `PayPct` % of the route's base pay |
| Ambush (rsg-ambush) | `Config.Ambush` | Ambush chance is multiplied while a contract is active; beating an ambush pays `BonusPct` % extra. Needs rsg-ambush 3.2.1+ |
| Job lock and company (rsg-society) | hub `job`, `minGrade`, `society`; `Config.Society` | Only the listed job(s) can take contracts at that hub. With `society` set the company account earns a `Cut` % (or pays the driver with `PayFromSociety = true`) |
| Leaderboard | contract board tab | Top 10 by deliveries, distance or earnings, plus your streak. Stored in `rsg_deliveries_stats` |

Hub example: `job = 'teamster', minGrade = 0, society = 'teamster'`. Only the active job is checked.

### Anti-Exploit Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Config.DeliveryCooldown` | int | `60` | Seconds between deliveries per player (`0` = off) |
| `Config.MaxAverageSpeed` | float | `25.0` | Deliveries finished faster than `distance / speed` seconds are rejected (teleport check) |
| `Config.RequireWagonAtDestination` | bool | `true` | Server checks the delivery wagon is at the drop-off (needs OneSync) |

Other server-side protections: only hub/route indexes come from the client, the start is distance-checked against the hub, the registered wagon must match the contract's model (the server waits up to 10 seconds for a newly spawned wagon to sync, and re-validates the wagon's model, creator and position on arrival if it was never registered), the completion event is consumed on first use, and delivery wagons are deleted on cancel, fail, completion, disconnect and resource stop.

### Discord Webhook (`SvConfig.Webhook` in `server/sv_config.lua`)

The webhook lives in a server-only file so the URL is never sent to clients.

| Option | Type | Description |
|--------|------|-------------|
| `url` | string | Webhook URL, leave empty to disable |
| `title` | string | Embed title |
| `color` | int | Embed colour (decimal) |
| `footer` | string | Embed footer text |

Logs delivery started, completed, cancelled and failed events.

### Delivery UI Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Config.ShowRewardImages` | bool | `true` | Show reward item images in the delivery UI |
| `Config.ImagePath` | string | `"nui://rsg-inventory/html/images/"` | Folder item images are loaded from |
| `Config.WagonLabels` | table | `{ cart01 = 'Supply Cart' }` | Friendly wagon names shown in the UI (falls back to the model name) |

Item images use the `image` field from `RSGCore.Shared.Items` (or `<itemname>.png` if none is set). To override the image for a single reward, add `image = 'myimage.png'` (or a full `nui://` / `https://` URL) inside that delivery's `itemreward` block. Missing images fall back to a box icon.

Difficulty (Easy / Moderate / Hard) is based on each route's distance relative to the longest route at the same hub.

### Reward Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Config.RewardPerDistance` | float | `0.01` | Cash per meter traveled |
| `Config.BaseReward` | int | `0` | Base cash added to distance-based rewards |

### Blip Settings (`Config.Blip`)

| Option | Type | Default |
|--------|------|---------|
| `blipSprite` | string | `"blip_ambient_delivery"` |
| `blipScale` | float | `0.2` |

### Delivery Locations (`Config.DeliveryLocations`)

An array of hub locations. Each hub has:

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Display name shown as the contract board title |
| `npcmodel` | string | Ped model for the NPC foreman |
| `npccoords` | vector4 | NPC spawn position |
| `cartSpawn` | vector4 | Wagon spawn position |
| `deliveries` | array | List of destination routes from this hub |

Each delivery entry has:

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Destination name |
| `description` | string | Route description |
| `wagonModel` | string | Wagon model hash name |
| `cargo` | string | Cargo prop set |
| `light` | string | Lantern prop set |
| `deliveryLoc` | vector3 | Drop-off coordinates |
| `reward` | object | Reward configuration (see below) |

#### Reward Configuration

Each delivery supports three reward types, each with an `activation` toggle:

**Distance-based (`priceByDistance`)**
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `multiplier` | float | `1.0` | Multiplier applied to the distance reward (`distance × RewardPerDistance × multiplier`) |

**Fixed price (`priceByConfig`)**
| Field | Type | Description |
|-------|------|-------------|
| `price` | float | Fixed cash amount |

**Item reward (`itemreward`)**
| Field | Type | Description |
|-------|------|-------------|
| `itemname` | string | Item name from rsg-core items |
| `itemamount` | int/table | Fixed amount, or `{min, max}` for a random range |
| `chance` | float or nil | Probability (0.0–1.0); `nil` = always |
| `image` | string or nil | Optional image override for the UI (file name in `Config.ImagePath` or a full URL) |

All rewards are worked out on the server from the config. The cash total is capped at `Config.MaxRewardAmount`. If the player's inventory is full, the item bonus is lost but the cash is still paid.

## Locales

Player-facing text, including the contract board UI, ships in en, de, el, es, fr, ja, nl, pl, pt-br, ro and ru (`locales/*.json`, loaded by rsg-core). Set the language with `setr rsg:locale de` in your server config.

## Adding New Deliveries

Add a new entry to `Config.DeliveryLocations` following the existing structure, or add a new route to an existing hub's `deliveries` array. Wagon models and prop sets can be referenced from [rdr3_discoveries](https://github.com/femga/rdr3_discoveries).

## Changelog

### 3.3.0
- New: teamster skill and economy hooks, fragile cargo, delivery streaks, daily hot route, return trips (`/returntrip`), ambush chance and bonus, job-locked hubs with society cut or payout, and a leaderboard tab on the contract board.
- New database table `rsg_deliveries_stats` (created automatically, `install.sql` included). Needs oxmysql.
- The start callback now returns `{ seconds, fragile }` instead of `true`.

### 3.2.1
- Security: wagon registration now requires the player to have created the wagon and refuses one already used by another delivery. Rejected completions now clean up the wagon and apply the cooldown.
- Fixes: 15s timer grace, players are told when a start or completion is rejected, no double start from the board, foreman model failures no longer retry every tick.
- Optimization: delivery loop and foreman loop sleep when nothing needs per-frame work.

### 3.2.0
- Optional rsg-reputation integration: `delivery` action on a completed delivery (`Config.Reputation`).

### 3.1.1
- Fixed deliveries being rejected with "You need to bring the wagon to the drop-off" (and no reward) while the player was in the delivery wagon. The wagon was reported to the server before it had synced, so it was never registered. The server now waits for the wagon to sync, and can validate it again on arrival.
- The server console now prints the reason whenever the wagon check rejects a delivery.

## Support

If you find this resource useful, you can support development here: https://buymeacoffee.com/rexshack

## rsg-reputation integration

Optional. With `rsg-reputation` started, a completed delivery applies the `delivery` action: standing in the town of the delivery hub you started from (`Config.Reputation.Regions`). Set `Config.Reputation.Enabled = false` to turn it off.

