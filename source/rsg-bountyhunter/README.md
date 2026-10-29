# rsg-bountyhunter

Bounty hunting for RSG Framework (RedM). Take a wanted poster from the clerk at any sheriff's office, track the outlaw to their hideout, and bring them in dead or alive.

## Features
- Clerk NPC at each sheriff's office (ox_target): **View Bounties** and **Turn In Bounty**
- NUI wanted board in the RSG leather & gold style: tiered posters (Petty / Wanted / Notorious) with random names, crimes and rewards
- The board re-rolls on a timer, and a poster someone has taken disappears for everyone else
- A search-area blip on the map; the outlaw and their gang spawn when you get close
- Petty outlaws flee, and the higher tiers fight back with their gang
- A bounty-target blip when you're close, marked as incapacitated once the target is dead or hogtied
- Bring the target to any office: alive pays the full reward, dead pays a reduced share
- Contract time limit with a warning before it runs out, an abandon option (NUI or `/abandonbounty`) and a cooldown before the next contract
- Personal stats and a Top Hunters leaderboard (cached)
- Optional job lock (`Config.RequiredJob`)
- The database table is created automatically on first start
- Fully translated: every player-facing string, NUI label, tier, crime, office name and Discord embed is in the locale files

## Security
- The server decides posters, rewards, hideouts and payouts. The client only sends a poster id and an office id.
- Opening the board, accepting and turning in are all distance-checked on the server (`Config.ServerCheckDistance`).
- A target is only registered if it's the right model, it's at the hideout and the hunter is actually there.
- On turn-in, the server checks that the target ped is within `Config.DeliverRadius` of the office and reads whether it's alive or dead itself.
- `Config.MinHuntSeconds` blocks instant turn-ins (for example, teleporting the ped to the office). Attempts are printed to the console.
- The contract is removed before payment, so it can't be claimed twice.
- Contracts are cleared on character logout or disconnect.

## Install
1. Drop `rsg-bountyhunter` into your resources and `ensure rsg-bountyhunter` after rsg-core, ox_lib, ox_target and oxmysql.
2. The `rsg_bountyhunter` table is created on start (`install.sql` is included as a manual fallback).
3. Optional: add your Discord webhook URLs in `server/sv_config.lua`.
4. Set your own hideout coords in `Config.Hideouts` (the shipped ones are only examples) and tune the clerk positions in `Config.Offices`.

## Discord webhooks
Set up in `server/sv_config.lua` (server only, so your URLs never reach clients).

| Category | Events |
|---|---|
| `contracts` | Contract accepted, abandoned, expired, failed (target lost) |
| `payouts` | Bounty turned in: target, alive/dead, amount paid, office, hunt time |
| `exploits` | Fake target registration (wrong model, wrong place, hunter not there) and instant turn-ins (teleports). Can ping a staff role with `PingOnExploit` |
| `system` | Resource start, board refresh (off by default), test messages |

- Paste a webhook URL into each `Urls` category (one channel each, or reuse the same URL). Leave a category `''` to turn it off.
- Turn individual events on or off in `Events`, and change embed colours in `Colors`.
- Every embed shows the character name, citizen ID, job and server ID, plus optionally the license, Discord mention and coords (`ShowIdentifiers`, `ShowCoords`).
- Messages go through a per-URL queue that respects Discord's rate limits and retries after a `429`.
- `/bountywebhooktest` (admin) sends a test embed to every configured URL.
- `UseRsgLog = true` also mirrors events to rsg-log.

## Languages
Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro` (in `locales/`).

The language follows ox_lib's server setting. Put this in your `server.cfg`, for example:
```
setr ox:locale de
```
Tier labels, crimes and office names in `shared/config.lua` are locale keys (`tier_petty`, `crime_murder`, `office_valentine`...). To add your own, add the key to every locale file. Outlaw first and last names are proper nouns and stay in the config.

## Config highlights
| Option | Default | Purpose |
|---|---|---|
| `RequiredJob` | `nil` | Job name needed to take contracts |
| `ContractMinutes` / `WarnMinutes` | 30 / 5 | Time limit and when to warn the hunter |
| `AcceptCooldown` | 120 | Seconds before the next contract after an abandon, fail or expiry |
| `ServerCheckDistance` | 10.0 | Server anti-cheat radius around each office |
| `DeliverRadius` | 12.0 | How close the target must be to the office |
| `MinHuntSeconds` | 60 | Minimum time between finding the target and turning it in |
| `AbandonCommand` | `abandonbounty` | Command to abandon from anywhere, `false` to disable |
| `Debug` | `false` | Prints server distance checks (useful when tuning office coords) |

## Troubleshooting
- **"You are too far from the sheriff's office"**: the office `coords` are too far from where the clerk stands. Set `Config.Debug = true`, try again and read the distance in the server console.
- **"The bounty board is unavailable"**: check the server console for a red database error.

## Dependencies
rsg-core, ox_lib, ox_target, oxmysql

Support: https://buymeacoffee.com/rexshack
