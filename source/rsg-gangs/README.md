# rsg-gangs

Player-run gangs ("outfits") for the RSG Framework: ranks and permissions, a shared bank, a chuck wagon that acts as the gang base, deployable camp equipment, crafting stations and an upgradable strongbox stash.

Version 3.5.0. Full reference: [DOCS.md](DOCS.md).

Gang membership, ranks, permissions and the bank are handled by **rsg-society**. rsg-gangs adds the gameplay: wagon, camp equipment, crafting, strongbox, turf, bounties, rivals and the staff panel.

## Dependencies

- rsg-core
- rsg-inventory
- rsg-target
- rsg-gizmo
- rsg-wellpump
- rsg-society (3.1.0 or newer)
- oxmysql

No ox_lib and no ox_target are needed.

## Features

- Create, rename, recolour and disband a gang; invite, accept or decline, kick, promote, demote and hand over leadership
- Configurable ranks with per-rank permissions (`invite`, `kick`, `promote`, `demote`, `deposit`, `withdraw`, `upgrade`, `disband`, `rename`, `setcolor`, `equipment`)
- Shared gang bank with server-side limits
- Gang chuck wagon that spawns when players are nearby, only members can drive it, and its parking spot follows it automatically (restarting the resource removes and respawns it cleanly, target included)
- Camp equipment (tent, torches, hitching posts, campfire, crafting table, strongbox) placed with rsg-gizmo near the wagon
- Crafting stations, a well pump that fills buckets and gives a drink (through rsg-wellpump), and a tiered strongbox stash tied to deployed equipment
- Territories: claim turf by standing in it; owned turf pays income into the gang bank and shows on the map
- Activity log (bank, members, equipment, turf, upkeep) readable by officers and above
- Member map blips: online gang members see each other on the map
- Weekly upkeep taken from the gang bank; gangs that keep missing it are disbanded
- Gang bounties: ranks with the `bounty` permission open the Bounty tab, enter an amount and pick a target from a dropdown: a player from the list of online players, or a rival gang for hunters to go after. The amount is held from the gang bank and shown on every rsg-bountyhunter board; unclaimed money is returned
- Rivalries: confirmed kills between members of different gangs are counted per rival gang (needs rsg-core 3.4.0+)
- Gang honor (average member honor from rsg-reputation) shown in the UI, and turf claims affect the claimer's reputation
- Turf raids: a gang can contest a rival territory by out-numbering its defenders inside it; captured turf is protected for a while
- Gang tags (`[TAG]` in the UI, `GetGangTag` export for chat resources), wagon on the member map, and a per-player map blip toggle
- Leaderboard tab with turf and rival-kill points and an optional monthly season reset
- Optional Discord webhook for gang activity (`server/sv_config.lua`, never sent to players)
- Rank-restricted strongbox access
- Staff admin panel (`/gangadmin`): a full NUI to manage every gang, territory and player (see Usage)
- Push-to-talk keeps working while the menu is open
- Exports for other scripts, optional rsg-log logging, version checker
- Translations: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru

## Installation

1. Put `rsg-gangs` in your resources folder.
2. Add it to `server.cfg` after its dependencies:

```
ensure oxmysql
ensure rsg-core
ensure rsg-inventory
ensure rsg-target
ensure rsg-gizmo
ensure rsg-wellpump
ensure rsg-society
ensure rsg-gangs
```

3. Database: the eight tables (`rsg_gangs`, `rsg_gang_members`, `rsg_gang_equipment`, `rsg_gang_logs`, `rsg_gang_territories`, `rsg_gang_bounties`, `rsg_gang_rivals`, `rsg_gang_state`) are created automatically on first start. To install by hand, set `Config.AutoDatabase = false` and import `installation/rsg-gangs.sql`.
   - Upgrading from 2.0.x: the new `name` column on `rsg_gang_members` is added automatically. By hand, run the `ALTER TABLE` line at the bottom of `installation/rsg-gangs.sql`.
4. Make sure every item used by your crafting recipes exists in your items list (the server prints a warning on start for any that do not).
5. Set your language with `setr rsg:locale en` (any of the languages above).

## Configuration

Everything is in `shared/config.lua`.

| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Create the tables on start. Set `false` to import `install` SQL manually |
| `Config.VersionCheck` | `true` | Print a console message when a newer version exists |
| `Config.Command` | `'setupgang'` | Command that opens the gang menu |
| `Config.CreateGangCost` | per file | Cash cost to found a gang |
| `Config.MaxMembers` | per file | Member limit (0 = unlimited) |
| `Config.MaxBankBalance` | `2000000000` | Largest balance a gang bank may hold |
| `Config.InviteExpireSeconds` | `120` | How long an invite stays valid |
| `Config.Ranks` | per file | Rank choices in the staff panel only. Real ranks and permissions are set per gang in rsg-society |
| `Config.Notify.duration` | `5000` | Notification length in ms |
| `Config.Logging` | disabled | Send events to rsg-log (`enabled`, `channel`) |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk usable while the UI is open |
| `Config.PushToTalkControls` | `0x4BC9DABB` | Controls left active while the UI is open |
| `Config.WagonInteractDistance` | `40.0` | Max distance from the wagon to manage equipment |
| `Config.StationInteractDistance` | `6.0` | Max distance from a crafting station, the well pump or the strongbox |
| `Config.RespawnProximityRadius` / `DespawnProximityRadius` | `80.0` / `100.0` | How close a player must be for a saved wagon or prop to spawn, and how far everyone must be for it to be removed |
| `Config.DebugWagon` | `false` | Print wagon spawn, save and despawn steps to the server console |
| `Config.GangVehicle` | per file | Wagon model, spawn search, driving restriction, target menu |
| `Config.GangEquipment` | per file | Equipment props, limits and placement range |
| `Config.WellPump` | enabled | Well pump targets: `equipmentId` (`wellpump`), `targetIcon`, `drink` (`true`), `drinkIcon`, `requirePermission` (`false`). Bucket items, uses, fill time and drinking are set in rsg-wellpump |
| `Config.Crafting` | per file | Stations and recipes |
| `Config.GangStash` | per file | Strongbox and storage tiers; `minWeight` = lowest rank weight that may open it (default `1`) |
| `Config.ActivityLog` | enabled | `keep` entries per gang (200), `show` in the UI (50), `minWeight` rank weight that can read it (2) |
| `Config.MemberBlips` | enabled | `interval` ms between position updates (3000) |
| `Config.Upkeep` | enabled | `intervalHours` (168), `cost` (2500), `maxMissed` unpaid cycles before disbanding (3) |
| `Config.Reputation` | enabled | Needs rsg-reputation. `claimAction` (`'gang_territory'`, added to rsg-reputation 3.0.0+) is applied to the claimer in the territory's `region`; `refreshMinutes` (5) controls the gang honor average |
| `Config.Raids` | enabled | `minAttackers`, `holdSeconds`, `durationSeconds`, `cooldownMinutes`, `protectMinutes`, `requireDefenderOnline` |
| `Config.Tags` | enabled | `minLength`, `maxLength` (needs the `rename` permission to set) |
| `Config.Leaderboard` | enabled | `size`, `turfPoints`, `killPoints`, `monthlyReset` |
| `SvConfig.Webhook` | disabled | In `server/sv_config.lua`: `Enabled`, `Url`, `Name`, `Actions` (needs `Config.ActivityLog.enabled`) |
| `Config.Rivalry` | enabled | `pairCooldownSeconds` (300): the same killer and victim count once per window |
| `Config.Bounties` | enabled | Needs rsg-bountyhunter 3.4.0+. `minReward`, `maxReward`, `maxActive`, `expireHours`, `targetPlayers` (bounties on a player), `targetGangs` (bounties on a rival gang); needs the `bounty` permission |
| `Config.Admin` | enabled | Staff panel: `enabled`, `command` (`'gangadmin'`), `permission` (`'admin'`, an rsg-core permission), `logLines` (100 log rows shown per gang) |
| `Config.Territories` | enabled | `maxPerGang`, `incomeIntervalMinutes`, `requireOnlineMember`, and `list` of `{ id, label, coords, radius, claimCost, income }` (the shipped coordinates are examples) |

Territories are claimed, abandoned and raided with the `upgrade` permission, and gang bounties need the `bounty` permission. Both are on Co-Leader and Leader in the shipped ranks; add them to custom rank lists.

## Usage

Players:

| Command | Description |
|---|---|
| `/setupgang` | Open the gang menu (members open it at the wagon when the target menu is on) |
| `/gangaccept` | Accept a pending invite |
| `/gangdecline` | Decline a pending invite |

Admins (rsg-core `admin` permission):

| Command | Description |
|---|---|
| `/creategangadmin <name> <label>` | Create a gang with no members |
| `/disbandgangadmin <name>` | Disband a gang |
| `/addgangmember <id> <gang> [rank]` | Put a player into a gang |
| `/setgangwagon <gang>` | Move the gang's wagon spot to your position |
| `/gangadmin` | Open the staff admin panel (`Config.Admin.permission`) |

Staff admin panel: a large NUI with four tabs. **Gangs** lists every gang with search and opens a detail view with sub-tabs Details (rename, tag, colour, stash tier, upkeep reset, wagon here/clear, rivals reset, delete), Members (add, kick, set rank, transfer leader), Bank (add, remove, set), Assets (pack or clear equipment, territories) and Log. **Territories** lets staff assign, free or end a raid on any turf. **Players** lists online players and puts them into a gang. **Create** founds a gang with no members. Every action is re-checked on the server (permission, rate limit, validation) and written to the gang's activity log.

Flow: found a gang, your wagon appears, open the menu at the wagon, set up equipment near it, craft and store at your stations.

## For developers

```lua
local gang = exports['rsg-gangs']:GetPlayerGang(citizenid)       -- { name, label, color, rank } or nil
local isLeader = exports['rsg-gangs']:IsGangLeader(citizenid)
exports['rsg-gangs']:AddGangBank('delobo', 500, 'heist payout')   -- true / false
```

All exports, events, the wagon system, the staff panel and more examples are in DOCS.md.

Support: https://rexshack.tebex.store
