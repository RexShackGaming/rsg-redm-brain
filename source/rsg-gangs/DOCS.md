# rsg-gangs documentation

For server owners and developers. Version 3.0.0.

## Contents

1. Files
2. Data model and database
3. Permissions and ranks
4. Server exports
5. Events
6. Security model
7. How-tos
8. Troubleshooting

## 1. Files

| File | Purpose |
|---|---|
| `shared/config.lua` | All settings |
| `server/main.lua` | Gang state, database, ranks, bank, membership, exports, shared `RSGGangs` helper table |
| `server/commands.lua` | Player and admin commands |
| `server/wagon.lua` | Wagon registration, saving and proximity streaming |
| `server/equipment.lua` | Camp equipment placement, packing and proximity streaming |
| `server/crafting.lua` | Crafting at deployed stations |
| `server/stash.lua` | Strongbox stash and tier upgrades |
| `server/features.lua` | Territories, upkeep, activity log reads/pruning, member blip broadcast |
| `server/sv_config.lua` | Server-only settings (Discord webhook) |
| `server/versionchecker.lua` | Optional update check |
| `client/main.lua` | NUI focus (with push-to-talk), state, NUI callbacks |
| `client/vehicle.lua` | Wagon spawn, driving restriction, parking save |
| `client/equipment.lua` | Prop spawn, rsg-gizmo placement, rsg-target options |
| `client/crafting.lua` | Opens the crafting view |
| `client/features.lua` | Territory and member blips, log and territory NUI callbacks |
| `html/` | NUI (`index.html`, `style.css`, `app.js`); text comes from the locale files |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (identical keys) |
| `installation/rsg-gangs.sql` | Manual schema (kept identical to the automatic one) |

## 2. Data model and database

Tables are created on start when `Config.AutoDatabase = true`. The `ensureDatabase` function runs the same statements as `installation/rsg-gangs.sql` and adds missing columns (`rsg_gang_members.name`, `rsg_gangs.upkeep_due`, `rsg_gangs.upkeep_missed`) with non-destructive `ALTER TABLE` statements after checking `INFORMATION_SCHEMA`.

| Table | Columns |
|---|---|
| `rsg_gangs` | `name` (key), `label`, `color`, `bank`, `owner`, `created_at`, `wagon_x/y/z/heading`, `stash_tier`, `stash_id`, `upkeep_due` (unix time), `upkeep_missed`, `tag` |
| `rsg_gang_members` | `citizenid` (key), `gang_name`, `rank`, `name`, `joined_at` |
| `rsg_gang_equipment` | `id`, `gang_name`, `item_id`, `x`, `y`, `z`, `heading`, `created_at` |
| `rsg_gang_logs` | `id`, `gang_name`, `citizenid`, `actor`, `action`, `detail`, `created_at` |
| `rsg_gang_rivals` | `gang_name`, `rival_name`, `kills` (kills by the first gang against the second) |
| `rsg_gang_bounties` | `id`, `gang_name`, `reward`, `created_at` (escrow ledger) |
| `rsg_gang_territories` | `territory_id` (key), `gang_name`, `claimed_at` |

Members and equipment are removed automatically when their gang row is deleted. The strongbox stash lives in rsg-inventory under `rsg_gang_stash_<stash_id>`; rsg-inventory keeps that inventory after a gang is disbanded (clear it with rsg-inventory's own tools if you want it gone).

## 3. Permissions and ranks

Ranks are in `Config.Ranks` (`name`, `label`, `weight`, `isLeader`, `permissions`). Weights must be consecutive from 0; the server prints warnings for bad rank setups.

Permissions: `invite`, `kick`, `promote`, `demote`, `deposit`, `withdraw`, `upgrade`, `disband`, `rename`, `setcolor`, `equipment`.

Rules enforced on the server:
- You can only kick, promote or demote members of a lower weight than your own.
- A promotion can never reach your own weight.
- The leader cannot leave while others remain; use leadership transfer first. The last member leaving removes the gang, its wagon and its equipment.
- `withdraw` lets a member take gang money out; review which ranks have it. Storage upgrades use `upgrade`.

## 4. Server exports

| Export | Returns |
|---|---|
| `GetPlayerGang(citizenid)` | `{ name, label, color, rank }` or `nil` |
| `GetGangData(gangName)` | Full gang table (label, color, bank, members, equipment, stash tiers) or `nil` |
| `IsGangLeader(citizenid)` | boolean |
| `HasGangPermission(citizenid, permission)` | boolean |
| `GetGangMembers(gangName)` | List of members or `nil` |
| `GetGangBank(gangName)` | Balance or `nil` |
| `AddGangBank(gangName, amount, reason?)` | `true` on success (whole positive amount, capped by `Config.MaxBankBalance`) |
| `RemoveGangBank(gangName, amount, reason?)` | `true` on success (fails if funds are short) |

```lua
local ok = exports['rsg-gangs']:RemoveGangBank('delobo', 250, 'ammo order')
if ok then -- hand over the goods end
```

## 5. Events

Client to server events are internal (`rsg-gangs:server:*`); they are validated and rate limited. Server to client: `rsg-gangs:client:setState`, `openMenu`, `closeMenu`, wagon and equipment registry events. Other resources should use the exports instead.

### Features added in 2.2.0 to 3.0.0

- **Activity log**: `RSGGangs.AddLog(gang, citizenid, action, ...)` stores a row; the UI renders it with the `log_<action>` locale key, filling `%s` from the `|`-separated detail. Read access needs `Config.ActivityLog.minWeight`. Old rows are pruned to `keep` every 30 minutes.
- **Territories**: events `rsg-gangs:server:claimTerritory(id)` and `abandonTerritory(id)` (permission `upgrade`, 1.5 s cooldown). Claiming checks the config entry, that the player is inside its radius (server position), the per-gang limit, the free state and the bank balance; the ownership row is inserted with `INSERT IGNORE` first so two gangs cannot both win. Income is paid every `incomeIntervalMinutes` (only while a member is online when `requireOnlineMember` is true). Territories are freed when a gang is destroyed.
- **Upkeep**: a thread checks every minute; when `upkeep_due` passes the cost is removed from the bank. A failed payment increments `upkeep_missed`; at `maxMissed` the gang is disbanded. Paying resets the counter.
- **Member blips**: the server sends each member only the positions of the other online members of their own gang (`rsg-gangs:client:memberBlips`). Positions come from the server, not the client.
- **Reputation (rsg-reputation)**: gang honor is the rounded average of `GetHonorByCitizenId` over all members, cached and refreshed every `Config.Reputation.refreshMinutes`. A territory claim calls `ApplyAction(src, Config.Reputation.claimAction, territory.region)`. rsg-reputation has no gang concept, so gang-versus-gang standing is tracked by rsg-gangs itself (see Rivalries).
- **Rivalries (rsg-core 3.4.0+)**: listens to the server-only `RSGCore:Server:OnPlayerKilled` event (validated and killer-confirmed by rsg-core). A kill between members of two different gangs adds 1 to `rsg_gang_rivals(gang_name, rival_name, kills)`; the same killer and victim only count once per `Config.Rivalry.pairCooldownSeconds`. The Overview tab shows each rival's kills and deaths and both gangs' logs get an entry.
- **Bounties (rsg-bountyhunter 3.2.0+)**: `rsg-gangs:server:postBounty(amount)` (permission `withdraw`, 2 s cooldown, amount within `minReward`..`maxReward`, `maxActive` per gang) moves the amount from the bank into escrow (`rsg_gang_bounties`) and calls `exports['rsg-bountyhunter']:PostBounty`. When the poster closes, bountyhunter fires the server-only event `rsg-bountyhunter:server:posterClosed(ref, reason, paid)`: on `completed` the unpaid remainder (a dead target pays less) returns to the bank, on `expired` the full amount returns. The bountyhunter board is in memory, so escrow left over from a restart is refunded when rsg-gangs starts.
- **Raids**: `rsg-gangs:server:startRaid(id)` (permission `upgrade`, 2 s cooldown). Requires an owned, unprotected territory of another gang, the caller inside it, `minAttackers` raiders inside, a defender online (if configured), and no active raid or cooldown for the raiding gang. Every 5 seconds the server counts members of both gangs inside the radius (server positions); time counts toward `holdSeconds` only while attackers out-number defenders. Reaching it transfers ownership (database updated, protection starts); running out `durationSeconds` first defends it.
- **Tags**: `rsg-gangs:server:setTag(tag)` (permission `rename`) upper-cases and strips non-alphanumerics, then checks `minLength`..`maxLength`. `exports['rsg-gangs']:GetGangTag(src)` returns the tag or `nil`.
- **Leaderboard**: score = turf x `turfPoints` + rival kills x `killPoints`. With `monthlyReset`, the first check in a new calendar month clears `rsg_gang_rivals` (the season is stored with a server KVP).
- **Member blips**: each player can hide themselves and stop receiving blips (stored in a client KVP, sent to the server on state load); the gang wagon's saved position is shown on the same map.
- **Webhook**: `server/sv_config.lua` is server-only, so the URL never reaches players. Messages are queued (one per 1.5 s, max 50 waiting) and use the `log_<action>` locale text of the server language. Only actions listed in `SvConfig.Webhook.Actions` are sent, and only while the activity log is enabled.
- **Bounty permission**: posting a gang bounty needs `bounty` (was `withdraw` before 3.0.0).
- **Stash rank**: `Config.GangStash.minWeight` is checked in `openGangStash`.

## 6. Security model

- Every action re-checks rank, permission and gang membership on the server; the NUI only sends requests.
- Amounts must be whole, positive, finite and within limits; bank changes use delta SQL, so overlapping updates cannot overwrite each other. Deposits refund on failure.
- Names are cleaned (no control characters or markup) and length checked.
- Per-player cooldowns on every action.
- Wagon and equipment reports need a one-time server grant, the entity must exist, be the right type and model, and the player must be near it. Duplicate spawns are deleted.
- Equipment placement requires the player at the wagon, a grant from the server, a spot within `maxPlacementDistance` of the wagon, and respects `maxDeployed`.
- Crafting and the stash need the player next to the gang's own deployed station; `CanAddItem` is checked and ingredients are refunded if the reward cannot be given.
- Invites expire (`Config.InviteExpireSeconds`) and are cleared when a gang is disbanded.

Other scripts that move gang money should call `AddGangBank` / `RemoveGangBank` and do their own distance and permission checks.

## 7. How-tos

- Add equipment: add an entry to `Config.GangEquipment` (unique `id`, `prop`, `maxPlacementDistance`, `maxDeployed`). Never rename an `id` already in use.
- Add a recipe: add it to a station in `Config.Crafting.stations`; its items must exist in rsg-core items.
- Change the language: `setr rsg:locale <code>`.
- Push-to-talk: `Config.AllowPushToTalkWhileOpen` and `Config.PushToTalkControls`.
- Logging: set `Config.Logging.enabled = true` and `channel` (needs rsg-log).
- Fix a bad wagon spot: stand where it should be and run `/setgangwagon <gang>`.

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| "Failed to load gangs" in console | Tables missing: enable `Config.AutoDatabase` or import the SQL |
| Wagon never appears | Check `Config.GangVehicle.enabled`, then use `/setgangwagon` near the gang |
| Target options missing | `rsg-target` must start before `rsg-gangs` |
| Placement does nothing | `rsg-gizmo` must be started; stay within the placement range of the wagon |
| Config warning about an item | Add the item to your items list or fix the recipe |
| Ranks cannot upgrade storage | Add `'upgrade'` to that rank's permissions |

Support: https://rexshack.tebex.store
