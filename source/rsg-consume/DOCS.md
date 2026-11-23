# rsg-consume — Developer Docs

## Flow
1. Player uses an item listed in `Config.Consumables[category]`.
2. **Server** removes the item and stores a one-time token in `pending[src]`.
3. Server triggers `rsg-consume:client:consume(itemName, category)`; client plays the category animation.
4. Client applies **alcohol**, fires `rsg-consume:client:onConsume(data)`, then calls `rsg-consume:server:finish(true)`.
5. Server consumes the token, applies **hunger/thirst/stress**, and gives `giveItem` (e.g. `emptybottle`).
   If the client could not play it (busy, passed out, dead, swimming, ragdolled, failed animation) it sends `finish(false)` and the item is refunded.
   If `finish(true)` arrives sooner than `Config.MinDuration[category]` ms after the item was used, it is treated as a skipped animation: nothing is applied and the item is refunded.

## Hunger / thirst
- Applied server-side in `applyNeeds(src, data)`: new value = current statebag value + config amount, clamped 0-100.
- Uses `exports['rsg-hud']:SetNeed(src, key, value)` when rsg-hud is started. That is a trusted write that bypasses the rsg-hud gain limiter (`Config.MaxNeedGainPerMinute`), and it can't race the server decay loop.
- Fallback without rsg-hud: `hud:client:UpdateHunger` / `hud:client:UpdateThirst` with the absolute value.
- Negative values (e.g. spirits `thirst = -10`) reduce the stat.

## Stress
Applied server-side in `applyNeeds` through `exports['rsg-hud']:RelieveStress(src, n)` (positive config value) or `GainStress(src, n)` (negative config value). Needs rsg-hud; without it stress is skipped.

## Alcohol
- Level is client-side and resets on character unload and on death.
- Drunk walk is scaled between `MinDrunkLevel` (at `DrunkThreshold`) and `MaxDrunkLevel` (at `PassOutThreshold`) when `ScaleDrunkness` is true.
- Pass-out: vomit (`VomitDuration`), sleep on the ground for `SleepDuration` in total (the fade-out runs inside it), wake up, groggy for `GroggyDuration`.

## Features (3.3.0)
All in `shared/config.lua`, each with an `Enabled` switch.

| Feature | Config | How it works |
|---|---|---|
| Fullness limit | `Fullness` | Server refuses (item not removed) when the only needs an item restores are >= `BlockAt`. Alcohol items are never blocked. |
| Quality | `Quality` | `info.quality` from the inventory slot scales positive hunger/thirst between `MinFactor` and 1. |
| Spoilage | `Spoilage` | Quality below `Below` in `Categories` rolls a sickness chance on the server; effects drop to `EffectFactor`, thirst/stress penalties apply, client plays vomit. |
| Tolerance | `Tolerance` | Metadata `alcoholtolerance` (+ `alcoholtolerancetime`). Threshold multiplier sent to the client with the consume event and via `rsg-consume:server:getTolerance` on load. |
| Hangover | `Hangover` | Client reports `rsg-consume:server:passedOut` after waking; server applies the penalty (60 s cooldown). |
| Cancel | `Cancel`, `Duration` | Client polls the key and sends `finish(true, true)`. Server computes progress from its own timer. |
| Buffs | `Buffs`, item `buff` | Server builds the buff table; client runs health / stamina (`RESTORE_PED_STAMINA`) ticks. |
| Warmth | `Warmth`, item `warmth` | Server sends degrees + seconds; client calls `exports['rsg-hud']:AddWarmth`. |
| Bars | `Bars` | Target options per item on a sphere zone. Server re-checks distance, price, cash, fullness, then starts the consumption. |
| Share | `Share` | Target option per item on players. Server checks distance, space and the item, then moves one item. |

## Server API
- `exports['rsg-consume']:GetTolerance(src)` returns the current tolerance (0-`Tolerance.Max`).
- Event `rsg-consume:server:consumed(src, itemName, category, data, meta)` (local server event). `meta = { progress, spoiled, bar }`.

## Categories (animation)
| Category | Animation | Prop |
|---|---|---|
| `Eat` | sandwich bite | `propname` |
| `Drink` | bottle chug (item interaction when mounted) | `propname` |
| `Stew` | bowl + spoon interaction | fixed |
| `Hotdrinks` | coffee mug | fixed |
| `Eatcanned` | canned food | `propname` |

## Item fields
`hunger`, `thirst`, `stress` (positive relieves, negative adds), `alcohol`, `propname`, `giveItem` (optional).

## Events
- `rsg-consume:client:onConsume(data)` (client, local), which other resources can hook.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-consume 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Consumables` | `table` | stress: positive relieves stress, negative adds stress \| hunger/thirst: added to current value (0-100) |
| `Config.AlcoholSystem` | `table` | AlcoholSystem Configuration |
| `Config.AlcoholEffects` | `table` |  |
| `Config.Fullness`, `Quality`, `Spoilage`, `Tolerance`, `Hangover`, `Cancel`, `Duration`, `Buffs`, `Warmth`, `Share`, `Bars` | `table` | See Features (3.3.0) |
| `Config.MinDuration` | `table` | Minimum ms per category before the server accepts "finished" |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-consume:client:consume` | client | `itemName, category, extra` | `client/client.lua` |
| `rsg-consume:client:tolerance` / `sick` / `buff` / `warmth` | client | server-sent effects | `client/client.lua` |
| `rsg-consume:server:finish` | server | `consumed, cancelled` | `server/server.lua` |
| `rsg-consume:server:bar` / `share` / `passedOut` | server | `barIndex, itemName` / `targetId, itemName` / none | `server/server.lua` |
| `rsg-consume:server:consumed` | server (local) | `src, itemName, category, data, meta` | `server/server.lua` |
| `rsg-consume:server:finish` | server | `consumed` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-consume:server:finish', consumed)
-- from a server script
TriggerClientEvent('rsg-consume:client:consume', source, itemName, category)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
