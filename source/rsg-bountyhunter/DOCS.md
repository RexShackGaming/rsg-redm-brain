# rsg-bountyhunter – Docs (v3.0.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Board, timers, distances, offices, tiers |
| `client/client.lua` | Clerks, NUI board, hideout and outlaw spawning, blips |
| `server/server.lua` | Board, contracts, turn-in, stats, leaderboard |
| `server/sv_config.lua`, `server/webhooks.lua` | Webhook settings and Discord embeds |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI wanted board (leather and gold style) |
| `install.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
1. Talk to the clerk NPC (rsg-target) at a sheriff's office: **View Bounties** or **Turn In Bounty**.
2. The NUI wanted board shows tiered posters (Petty / Wanted / Notorious) with random names, crimes and rewards. The board re-rolls on a timer, and a poster someone has taken disappears for everyone else.
3. Accept a poster: a search-area blip appears. The outlaw and their gang spawn when you get close. Petty outlaws flee; higher tiers fight back with their gang.
4. A bounty-target blip shows when you are close, and is marked incapacitated once the target is dead or hogtied.
5. Bring the target to any office. Alive pays the full reward; dead pays `deadMultiplier` of it.
6. Contracts have a time limit with a warning, an abandon option (NUI or `/abandonbounty`) and a cooldown before the next one.
7. Personal stats and a Top Hunters leaderboard (cached).

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Print distance checks |
| `RequiredJob` | `nil` | Job lock for contracts (server checked) |
| `MoneyType` | `'cash'` | Reward account |
| `BoardSize` | `6` | Posters on the board |
| `RefreshMinutes` | `30` | Board re-roll interval |
| `ContractMinutes` | `30` | Time to bring the target in |
| `WarnMinutes` | `5` | Warning before expiry |
| `AcceptCooldown` | `120` | Seconds before another contract after abandon/fail/expiry |
| `MinHuntSeconds` | `60` | Anti-exploit minimum between finding and turning in |
| `AbandonCommand` | `'abandonbounty'` | `false` to disable |
| `InteractDistance` / `ServerCheckDistance` / `DeliverRadius` | `3.0` / `10.0` / `12.0` | Distances |
| `ClerkSpawnDistance` | `60.0` | Clerk spawn range |
| `SpawnDistance` | `150.0` | Outlaws spawn when you are this close |
| `SearchRadius` | `120.0` | Search area blip size |
| `TargetBlipDistance` | `60.0` | Target blip range |
| `LeaderboardSize` / `LeaderboardCache` | `5` / `60` | Leaderboard |
| `ClerkModel` | `s_m_m_valdeputy_01` | Clerk ped |
| `Offices` | list | Valentine, Rhodes, Blackwater, Saint Denis: `id`, `label` (locale key), `coords`, `blip` |
| `Tiers` | table | Per tier: `label`, `rewardAlive {min,max}`, `deadMultiplier`, `gang {min,max}`, `behaviour` (`flee`/`fight`), `accuracy`, `models`, `weapons` |

Webhook URLs and the test command are in `server/sv_config.lua`.

## 4. Events and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-bountyhunter:server:getBoard` | callback | `(officeId)` |
| `rsg-bountyhunter:server:accept` | callback | `(officeId, posterId)` |
| `rsg-bountyhunter:server:abandon` | callback | Abandon the current contract |
| `rsg-bountyhunter:server:registerTarget` | server event | `(netId)` the spawned outlaw |
| `rsg-bountyhunter:server:turnIn` | callback | `(officeId)` |
| `rsg-bountyhunter:client:startContract` | client event | `(data)` |
| `rsg-bountyhunter:client:endContract` | client event | `(reason)` |

| Command | Who | What |
|---|---|---|
| `/abandonbounty` | everyone | Abandon your current contract |
| `/bountywebhooktest` | admin | Send a test Discord embed (name from `sv_config.lua`, `false` disables) |

## 5. Database
```sql
CREATE TABLE IF NOT EXISTS `rsg_bountyhunter` (
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL DEFAULT '',
    `completed` INT NOT NULL DEFAULT 0,
    `alive` INT NOT NULL DEFAULT 0,
    `dead` INT NOT NULL DEFAULT 0,
    `earned` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Created automatically on first start; `install.sql` is the manual option.

## 6. Security
The server owns the board and contracts. It checks distance to the clerk, the job lock, that the target is the registered entity within `DeliverRadius`, the minimum hunt time, contract expiry and cooldowns, and computes the payout itself.

## 7. How-tos
- Job-lock the script: `RequiredJob = 'bountyhunter'`.
- Add an office: add an `Offices` entry with a unique `id` and a locale label.
- Make tiers harder: raise `accuracy` or the `gang` range.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Clerk missing | Move within `ClerkSpawnDistance`; check coords |
| Can't accept | Cooldown after abandon/fail, or a job lock |
| Turn-in refused | Target must be within `DeliverRadius` of the office and the hunt long enough |
| Poster gone | Another hunter took it, or the board re-rolled |

Support the Project : https://rexshack.tebex.store/
