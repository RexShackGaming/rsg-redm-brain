# rsg-bountyhunter

**Version 3.5.0** · Dependencies: rsg-core, rsg-inventory, rsg-target, oxmysql · Full reference: [DOCS.md](DOCS.md)

Bounty hunting for RSG Framework (RedM). Take a wanted poster from the clerk at any sheriff's office, track the outlaw to their hideout, and bring them in dead or alive.

## Features
- Clerk NPC at each sheriff's office (rsg-target): **View Bounties** and **Turn In Bounty**
- NUI wanted board in the RSG leather & gold style: tiered posters (Petty / Wanted / Notorious) with random names, crimes and rewards
- The board re-rolls on a timer, and a poster someone has taken disappears for everyone else
- A search-area blip on the map; the outlaw and their gang spawn when you get close
- Petty outlaws flee, and the higher tiers fight back with their gang
- A bounty-target blip when you're close, marked as incapacitated once the target is dead or hogtied
- Bring the target to any office: alive pays the full reward, dead pays a reduced share
- Contract time limit with a warning before it runs out, an abandon option (NUI or `/abandonbounty`) and a cooldown before the next contract
- Personal stats and a Top Hunters leaderboard (cached)
- Optional job lock (`Config.RequiredJob`, one job or a list of jobs)
- Push-to-talk keeps working while the board is open (`Config.AllowPushToTalkWhileOpen`)
- Reputation bounties: players whose honor (rsg-reputation) drops to the outlaw level are posted on the board automatically (see below)
- The database table is created automatically on first start
- Fully translated: every player-facing string, NUI label, tier, crime, office name and Discord embed is in the locale files

## Security
- The server decides posters, rewards, hideouts and payouts. The client only sends a poster id and an office id.
- Opening the board, accepting and turning in are all distance-checked on the server (`Config.ServerCheckDistance`).
- A target is only registered if it's the right model, it's at the hideout and the hunter is actually there.
- On turn-in, the server checks that the target ped is within `Config.DeliverRadius` of the office and reads whether it's alive or dead itself.
- `Config.MinHuntSeconds` blocks instant turn-ins (for example, teleporting the ped to the office), and the minimum grows with the hideout to office distance (`Config.MaxTravelSpeed`). Attempts are printed to the console and logged to Discord.
- A target ped can only be registered once, and only by the player who owns it, so another hunter cannot steal your target.
- One turn-in is processed at a time per player.
- The contract is removed before payment, so it can't be claimed twice.
- Contracts are cleared on character logout or disconnect, and that counts as an abandon: the cooldown is tracked per character, so relogging can't be used to re-roll contracts.
- Opening the board is rate-limited per player to stop database spam.
- Gang bounties (needs rsg-gangs 3.4.0+): a gang can post a bounty on one player or on a rival gang. Hunters follow a moving search area and bring the player (or any online member of the gang) to an office dead, hogtied or cuffed. A gang cannot take its own bounty. See `PostBounty` in DOCS.md.
- Reputation bounties are decided and paid by the server: the target must be within `DeliverRadius` of the office and secured (dead or cuffed from server data, hogtied from the target's own client), the hunt must last `MinHuntSeconds`, you cannot hunt yourself or (by default) your own gang, and a collected player cannot be re-posted for `RepostCooldownMinutes`.

## Install
1. Drop `rsg-bountyhunter` into your resources and `ensure rsg-bountyhunter` after rsg-core, rsg-target and oxmysql. ox_lib is not required.
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
Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru` (in `locales/`).

Locales are loaded by rsg-core. Set the language in your `server.cfg`, for example:
```
setr rsg:locale de
```
(falls back to `ox:locale`, then `en`).
Tier labels, crimes and office names in `shared/config.lua` are locale keys (`tier_petty`, `crime_murder`, `office_valentine`...). To add your own, add the key to every locale file. Outlaw first and last names are proper nouns and stay in the config.

## Config highlights
| Option | Default | Purpose |
|---|---|---|
| `RequiredJob` | `nil` | Job name (or `{ 'job1', 'job2' }`) needed to take contracts |
| `ContractMinutes` / `WarnMinutes` | 30 / 5 | Time limit and when to warn the hunter |
| `AcceptCooldown` | 120 | Seconds before the next contract after an abandon, fail or expiry |
| `ServerCheckDistance` | 10.0 | Server anti-cheat radius around each office |
| `DeliverRadius` | 12.0 | How close the target must be to the office |
| `MinHuntSeconds` | 60 | Minimum time between finding the target and turning it in |
| `MaxTravelSpeed` | 25.0 | Metres per second used to scale the minimum hunt time with the hideout to office distance, `0` = off |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk usable while the board is open (all other controls stay blocked) |
| `AbandonCommand` | `abandonbounty` | Command to abandon from anywhere, `false` to disable |
| `Debug` | `false` | Prints server distance checks (useful when tuning office coords) |

## Optional features (3.5.0)
Every feature below has a switch in `shared/config.lua`. Integrations with other resources only run while that resource is started.

| Feature | Config | Needs | What it does |
|---|---|---|---|
| Dead or alive conditions | `Config.Conditions` | | "Alive only" posters pay nothing for a corpse and fail the contract; "dead only" posters refuse a live target |
| Hunter progression | `Config.Skills` | rsg-skills | `bounty_hunting` skill, XP per capture, higher tiers need a level, a perk adds a % to NPC rewards |
| Streak and gang bonus | `Config.Streak`, `Config.GangBonus` | | Bonus % for back-to-back captures and for gang members left dead (counted by the server) |
| Evidence items | `Config.Evidence` | rsg-inventory | Tier based item drops on turn-in. Add `installation/items.lua` to rsg-core `shared/items.lua` and supply the three images |
| Regional rewards | `Config.Economy` | rsg-economy | Reward multiplier per region, optionally paid from the treasury |
| Telegrams | `Config.Telegram` | rsg-telegram | A player is told when a bounty is posted on them and when they are brought in |
| Jail | `Config.Jail` | rsg-lawman, rsg-prison | A player brought in alive is sentenced (reputation bounties by default, sponsored ones optional) |
| Hideouts | `Config.Hideout` | | Props, outlaws idle until you get close or someone is hurt |
| Ambush | `Config.Ambush` | | Riders can wait on the road back (chance rolled by the server) |
| Search area | `Config.Reputation.RerollEvery` | | The moving search circle on a player target re-rolls its offset every few updates |

Bonuses apply to NPC contracts only. Sponsored and reputation payouts are fixed.

Sponsors can withdraw a poster with `exports['rsg-bountyhunter']:CancelBounty(ref)` (see DOCS.md).

## Troubleshooting
- **"You are too far from the sheriff's office"**: the office `coords` are too far from where the clerk stands. Set `Config.Debug = true`, try again and read the distance in the server console.
- **"The bounty board is unavailable"**: check the server console for a red database error.
- **"The sheriff is still verifying the capture"**: the target was turned in faster than the hunt could take. Wait the number of seconds shown.
- **Evidence items never drop**: the items are missing from `RSGCore.Shared.Items`; the console prints a one-time warning. Paste `installation/items.lua` into rsg-core `shared/items.lua`.
- **Outlaws stand still**: they idle until you come within `Config.Hideout.AlertDistance`. If they never move even then, a name in `Config.Hideout.Scenarios` is wrong; test it in game or empty the list.
- **"Something went wrong at the hideout"**: the outlaw could not spawn (bad ped model or no ground at the hideout coords). Fix the entry in `Config.Hideouts` / `Config.Tiers`, then abandon and retry.

## Dependencies
rsg-core, rsg-target, oxmysql (rsg-reputation optional, for reputation bounties and the delivery honor reward)

## Reputation bounties

Optional, needs `rsg-reputation`. When a player's honor falls to `Config.ReputationBounty.Threshold` (default -600, the Outlaw tier) a poster with their character name appears on every board, and they are told. Lawmen (`ExemptJobTypes`), jailed players and players on the repost cooldown are never posted.

For the hunter it works like a normal contract, but the target is the real player:
1. Take the poster at the clerk. A search area follows the target on your map (offset, never the exact spot) and updates every `TrackSeconds`.
2. Kill the player, or hogtie or cuff them, and bring them to a sheriff's office within the time limit.
3. Use **Turn In Bounty**. Alive (hogtied / cuffed) pays the full reward, dead pays `DeadMultiplier` of it. A dead target must still be at the office, so mind your respawn timer in rsg-medic.

The reward is `BaseReward + PerPoint x (honor points below the threshold)`, capped at `MaxReward`, and follows the target's honor while the poster is untaken. The poster is removed when honor rises above `ClearAbove`, the player is jailed or leaves, or it is collected. Nothing extra is stored in the database.

| Option (`Config.ReputationBounty`) | Default | Purpose |
|---|---|---|
| `Enabled` | `true` | Turn the feature off |
| `Threshold` / `ClearAbove` | -600 / -400 | Post at or below, remove above (keep `ClearAbove` higher) |
| `BaseReward` / `PerPoint` / `MaxReward` | 100 / 0.5 / 500 | Alive reward formula |
| `DeadMultiplier` | 0.5 | Share paid for a dead target |
| `ExemptJobTypes` | `{ 'leo' }` | Job types that are never posted |
| `SkipJailed` | `true` | Do not post jailed players |
| `BlockSameGang` | `true` | A hunter cannot take a bounty on their own gang |
| `RepostCooldownMinutes` | 120 | No new poster for a player after they were brought in |
| `TrackSeconds` / `TrackRadius` | 30 / 250.0 | Moving search area refresh and size |
| `SweepSeconds` | 60 | Re-check of every online player (jail, decay, cooldown) |
| `NotifyTarget` | `true` | Tell the player when posted, cleared or brought in |

## rsg-reputation integration

Optional. With `rsg-reputation` started, a delivered bounty applies the `bounty_delivered` action (honor and standing in the town of the office you turned the target in at). Set `Config.Reputation.Enabled = false` to turn it off. Office ids map to reputation regions through `Config.Reputation.Regions`.


Support the Project : https://rexshack.tebex.store/

## Database

Tables (`rsg_bountyhunter`) are created automatically on first start while `Config.AutoDatabase = true` (default); the database user needs `CREATE` permission. To install manually, set `Config.AutoDatabase = false` in the config and import `install.sql` once.
