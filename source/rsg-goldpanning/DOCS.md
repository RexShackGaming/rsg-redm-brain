# rsg-goldpanning — Developer & Server Owner Docs

Version 3.1.0

## Contents
1. Architecture
2. Pan flow
3. Events
4. Security model
5. Configuration
6. Webhooks & logs
7. Persistence
8. How-tos
9. Troubleshooting

## 1. Architecture
| File | Side | Purpose |
|---|---|---|
| `shared/config.lua` | shared | Pan item, timings, rewards, anti-farm rules, allowed water zones |
| `client/client.lua` | client | Water/foot checks, prop, animations, progress bar |
| `server/sv_config.lua` | server | Webhook URLs and colours (never sent to clients) |
| `server/webhook.lua` | server | `SendGoldPanRewardWebhook`, `SendGoldPanExploitWebhook` globals |
| `server/server.lua` | server | Useable item, sessions, validation, rewards |
| `server/versionchecker.lua` | server | GitHub version check on start |

No ox_lib: locales come from `@rsg-core/shared/locale.lua`, notifications from `RSGCore:Client:Notify`, progress from `RSGCore.Functions.ProgressBar`.

## 2. Pan flow
1. Player uses `Config.PanItem` → server checks for an active session and the cooldown → `rsg-goldpanning:client:tryPan`.
2. Client checks on foot, not mounted/swimming, and in a water zone listed in `Config.WaterTypes` (`_GET_WATER_MAP_ZONE_AT_COORDS`, `0x5BA7A68A346A5A91`) → `rsg-goldpanning:server:startPan`.
3. Server re-checks the pan item, cooldown and spot memory, picks a random duration (`Config.PanTime.min`–`max`), stores the session and position → `rsg-goldpanning:client:beginPan(duration)`.
4. Client attaches `P_CS_MININGPAN01X`, plays the scoop then shake animation, runs the progress bar (`inv_busy` set while panning).
5. On finish → `rsg-goldpanning:server:claimPan`; on cancel → `rsg-goldpanning:server:cancelPan`.

## 3. Events
| Event | Direction | Args |
|---|---|---|
| `rsg-goldpanning:client:tryPan` | server → client | — |
| `rsg-goldpanning:client:beginPan` | server → client | `duration` (ms) |
| `rsg-goldpanning:server:startPan` | client → server | — |
| `rsg-goldpanning:server:claimPan` | client → server | — |
| `rsg-goldpanning:server:cancelPan` | client → server | — |

No exports or callbacks.

## 4. Security model
The client sends no data; the server decides everything.
- Claims need a server session, consumed on first use (no replays).
- Elapsed time must be within duration −1 s / +10 s.
- Player must not drift more than `Config.MaxDriftDistance` from the start spot.
- Spot memory (`MinMovementDistance` / `SpotMemoryTime`) is set on every claim, successful or not.
- Pan item is re-checked at start and at claim; `CanAddItem` before `AddItem`.
- Sessions older than duration + 10 s are dropped automatically.
- Exploit flags are throttled to one per player per 10 s so webhook spam isn't possible.
- Limitation: water type can only be read client-side. A cheater can start a pan outside water, but still has to wait the full timer, stand still, and move between spots, so it gives no speed advantage.

## 5. Configuration
| Option | Default | Description |
|---|---|---|
| `Config.PanItem` | `tool_goldpan` | Useable item |
| `Config.Cooldown` | `10` | Seconds between pan starts |
| `Config.PanTime` | crouch 6000, min 18000, max 34000 | ms |
| `Config.RewardItems` | `{ 'resource_gold_nugget' }` | One is picked at random |
| `Config.GoldChance` | `65` | % chance to find anything |
| `Config.RewardTiers` | 50/30/20 → 1/2/3 | Must total 100 (warning printed if not) |
| `Config.MinMovementDistance` | `1.5` | m from last spot |
| `Config.SpotMemoryTime` | `300000` | ms a spot stays panned out |
| `Config.MaxDriftDistance` | `3.0` | m allowed during a pan |
| `Config.WaterTypes` | 17 zones | `{ name, waterhash }` |
| `Config.Webhooks` / `Config.WebhookColors` | see `server/sv_config.lua` | Discord |

## 6. Webhooks & logs
- `rsg-log:server:CreateLog` with category `goldpanning` on every find.
- `SendGoldPanRewardWebhook(tier, playerName, charName, citizenid, itemLabel, amount, coords)`
- `SendGoldPanExploitWebhook(reason, playerName, src, details)`

## 7. Persistence
Nothing is saved. Sessions, cooldowns and spot memory are in memory and cleared on `playerDropped` or restart. No database.

## 8. How-tos
- **Add a river:** add `{ name = 'My Creek', waterhash = <hash> }` to `Config.WaterTypes`.
- **Add a reward:** make sure the item is in `rsg-core/shared/items.lua`, then add it to `Config.RewardItems`. Missing items are reported in the console on start.
- **Change language:** `setr rsg:locale de` in `server.cfg`.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| "You need to be standing in a river" in a real river | Zone not in `Config.WaterTypes` |
| Reward item error in console | Add the item to rsg-core shared items |
| Timing anomaly flags for normal players | Server hitching; raise `CLAIM_LATE_TOLERANCE` in `server/server.lua` |
| No webhooks | Set `Config.Webhooks.enabled` and the URLs in `server/sv_config.lua` |

---

Support: https://buymeacoffee.com/rexshack
