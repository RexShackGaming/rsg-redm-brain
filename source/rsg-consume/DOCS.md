# rsg-consume — Developer Docs

## Flow
1. Player uses an item listed in `Config.Consumables[category]`.
2. **Server** removes the item and stores a one-time token in `pending[src]`.
3. Server triggers `rsg-consume:client:consume(itemName, category)`; client plays the category animation.
4. Client applies **alcohol** and **stress**, fires `rsg-consume:client:onConsume(data)`, then calls `rsg-consume:server:finish(true)`.
5. Server consumes the token, applies **hunger/thirst**, and gives `giveItem` (e.g. `emptybottle`).
   If the client could not play it (busy, passed out, dead) it sends `finish(false)` and the item is refunded.

## Hunger / thirst
- Applied server-side in `applyNeeds(src, data)`: new value = current statebag value + config amount, clamped 0-100.
- Uses `exports['rsg-hud']:SetNeed(src, key, value)` when rsg-hud is started. That is a trusted write that bypasses the rsg-hud gain limiter (`Config.MaxNeedGainPerMinute`), and it can't race the server decay loop.
- Fallback without rsg-hud: `hud:client:UpdateHunger` / `hud:client:UpdateThirst` with the absolute value.
- Negative values (e.g. spirits `thirst = -10`) reduce the stat.

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

Generated from the source of **rsg-consume 3.1.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Consumables` | `table` | stress: positive relieves stress, negative adds stress \| hunger/thirst: added to current value (0-100) |
| `Config.AlcoholSystem` | `table` | AlcoholSystem Configuration |
| `Config.AlcoholEffects` | `table` |  |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-consume:client:consume` | client | `itemName, category` | `client/client.lua` |
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
