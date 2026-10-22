# rsg-deliveries

A wagon delivery system for RedM using the RSG Framework. Players pick up goods from NPC foremen at various towns and deliver them by wagon to destinations across the map for cash and item rewards.

Talking to a foreman opens a NUI contract board listing every destination from that hub. Selecting a route shows its distance, time limit, wagon, difficulty rating, a route-length bar, and the cash and item rewards (with item images when configured).

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)
- [ox_target](https://github.com/Rexshack-RedM/ox_target)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- OneSync (needed for the server-side wagon check, see `Config.RequireWagonAtDestination`)

## How It Works

1. Talk to a foreman and pick a contract on the board.
2. The server checks you are at the hub, have no active delivery and are off cooldown, then the wagon spawns and a GPS route is set.
3. Drive the wagon to the marked drop-off before the time limit runs out. A wrecked or lost wagon fails the contract.
4. When the wagon reaches the drop-off, the server checks the player, wagon and travel time, then pays the cash and rolls the item reward.

## Commands

| Command | Description |
|---------|-------------|
| `canceldelivery` | Cancels the active delivery |

## Configuration

All options are in `shared/config.lua`.

### General Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Config.DistanceSpawn` | float | `20.0` | Distance at which NPCs spawn |
| `Config.FadeIn` | bool | `true` | Fade NPCs in/out on spawn/despawn |
| `Config.SpawnVehDistance` | float | `5.0` | Radius to check for blocking vehicles at cart spawn |
| `Config.DestinationMarker` | bool | `true` | Show destination marker on the ground |
| `Config.UIPosition` | string | `"top-center"` | ox_lib text UI position |
| `Config.FadeIncrement` | int | `51` | Alpha step for NPC fade effect |
| `Config.DefaultDeliveryTime` | int | `30` | Time limit per delivery (minutes) |
| `Config.MaxRewardAmount` | int | `500` | Maximum cash reward cap |
| `Config.InteractionDistance` | float | `2.0` | NPC interaction range |
| `Config.ShowDeliveryTimerUI` | bool | `false` | Show the time remaining / distance text UI during a delivery |
| `Config.CompleteDistance` | float | `10.0` | How close the wagon must be to the drop-off to complete |

### Anti-Exploit Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Config.DeliveryCooldown` | int | `60` | Seconds between deliveries per player (`0` = off) |
| `Config.MaxAverageSpeed` | float | `25.0` | Deliveries finished faster than `distance / speed` seconds are rejected (teleport check) |
| `Config.RequireWagonAtDestination` | bool | `true` | Server checks the delivery wagon is at the drop-off (needs OneSync) |

### Discord Webhook (`Config.Webhook`)

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

Player-facing text, including the contract board UI, is in `locales/en.json`. Copy it to a new file (for example `locales/de.json`) to translate, and set `ox:locale` in your server config.

## Adding New Deliveries

Add a new entry to `Config.DeliveryLocations` following the existing structure, or add a new route to an existing hub's `deliveries` array. Wagon models and prop sets can be referenced from [rdr3_discoveries](https://github.com/femga/rdr3_discoveries).

## Support

If you find this resource useful, you can support development here: https://buymeacoffee.com/rexshack
