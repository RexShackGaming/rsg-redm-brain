# Server environment

This file is the source of truth. It overrides anything else in the brain.

## Core stack
- rsg-core 3.0.3, rsg-inventory, rsg-banking v3
- `[standalone]`: ox_lib, oxmysql, ox_target, PolyZone, pma-voice, interact-sound, xsound, progressbar, rNotify
- `[framework]` holds the `rsg-*` resources. `[community]` holds third-party resources (Nt_Blackjack, Nt_Holdem).

## Installed systems (use these)
| Need | Resource |
|---|---|
| Weather / time | rsg-weather (github.com/Rexshack-RedM/rsg-weather) |
| Horses | rsg-stables (github.com/Rexshack-RedM/rsg-stables) |
| Jobs | rsg-multijob (github.com/Rexshack-RedM/rsg-multijob) |
| Telegrams | rsg-telegram (github.com/Rexshack-RedM/rsg-telegram) |
| Clothing | rsg-wardrobe (github.com/Rexshack-RedM/rsg-wardrobe) |
| Targeting | ox_target (some older scripts reference rsg-target) |

## Removed or not installed (never depend on these)
- **weathersync** has been removed. Use rsg-weather.
- **rsg-horses** is not installed. Use rsg-stables.
- **RSGCore.Shared.Jobs** is no longer where jobs are defined. Jobs live in the database via rsg-multijob.

## Item names on this server
| Thing | Item name |
|---|---|
| Wood | `resource_wood` |
| Coal | `resource_coal` |
| Filled water bucket | `fullbucket` |
| Cash / bloodmoney (money items enabled) | `dollar`/`cent`, `blood_dollar`/`blood_cent`. Always use AddMoney/RemoveMoney, never add these directly |

## House snippets
Adjust thirst client-side:
```lua
TriggerEvent('hud:client:UpdateThirst', math.max(0, math.min(100, (LocalPlayer.state.thirst or 0) + amount)))
```

## Scripts in development
rsg-housing (monthly rent at the property, eviction for unpaid rent, no estate agents), rsg-drugs (cannabis: drying, pressing bricks via NUI, deliveries/bags), rsg-lawman (with an NUI MDT modelled on rsg-mdt), rex-spawner (admin ped spawner NUI), rsg-noticeboard (paid, timed notices on bounty boards), rsg-bankrobbery (safe cracking via ox_target plus an NUI minigame).

## README footer for released scripts
`Support: https://buymeacoffee.com/rexshack`
