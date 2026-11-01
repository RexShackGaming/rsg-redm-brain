# rsg-mining

Mine lease and NPC worker management for **RSG-Core (RedM)**.

Lease a mine from its foreman, hire a crew of miners, keep them fed, watered, equipped and paid, and collect the ore they dig while you're away.

## Features

- **Mine leases.** Each mine is leased by one player for a set time, and the holder can extend the lease from the foreman.
- **Hiring board.** Candidates have random skill levels, and the board refreshes on a timer.
- **Worker needs.** Workers use bread, water and pickaxes from the mine stores automatically.
- **Wages.** Every shift a worker works is paid from the mine's payroll fund. If the fund runs dry, the workers **go on strike** until it's topped up.
- **Skill progression.** Workers improve on the job. Higher skill finds more ore and unlocks precious metals and gems.
- **Ore storage.** Storage has a cap per mine. You can collect each item on its own or collect everything at once, and the script checks inventory space before adding anything.
- **Foreman ledger.** The ledger is an NUI window you can drag around, styled in the RDR2 theme, and it shows real item images from rsg-inventory.
- **Discord logging.** Every lease, hire, dismissal, deposit, collection, payroll change and strike is logged to Discord webhooks, with staff alerts for large amounts.
- **Server-side security.** Every action is validated on the server: you must hold the lease, be standing at the mine and not be spamming actions.

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Drop `rsg-mining` into your resources folder.
2. Add `ensure rsg-mining` to your server.cfg **after** the dependencies.
3. Make sure the items in `Config.Supplies` and the ores in each mine exist in your rsg-core shared items.
4. Copy the images in `installation/images` into `rsg-inventory/html/images` and add the items from `installation/shared_items.lua` to your shared items if you don't already have them.
5. Start the server. The database tables `rsg_mining` and `rsg_mining_workers` are created automatically, and older installs are upgraded automatically too (works on both MySQL and MariaDB). If you'd rather set the database up by hand, run `installation/rsg-mining.sql` first.

## How it plays

1. Go to the foreman (the mine blip) and buy a lease.
2. **Hire** miners. A miner's wage per shift goes up with their skill.
3. **Supplies:** deposit bread, water and pickaxes.
4. **Overview → Payroll:** pay money in. The panel shows how many shifts the fund covers.
5. Every `Config.WorkInterval` minutes, each worker eats, drinks, wears down their pickaxe, gets paid and digs ore.
6. **Storage:** collect the ore.

A worker stops working when any of these happens:

| Status | Cause | Fix |
|---|---|---|
| On strike | The payroll fund can't cover their wage | Pay into the payroll |
| Hungry / Thirsty | No bread or water left in stores | Deposit supplies |
| No pickaxe | Their pickaxe broke and the stores have none | Deposit pickaxes |
| Storage full | Ore storage has hit its cap | Collect the ore |

Workers are only paid for shifts they actually work. When a lease expires, the workers leave and the holder is told (if online). If the same player re-leases, their stores, storage and payroll are kept. If a different player leases the mine next, its stores, storage and **payroll** are reset, so withdraw unused wages before your lease runs out.

The ledger closes on its own if you walk more than `ManageDistance` from the foreman, and the lease and hiring-board timers count down live while it's open.

## Configuration (`shared/config.lua`)

| Option | Description |
|---|---|
| `MoneyType` | Which money type is used for every payment: `cash` or `bank` |
| `ImagePath` | Where the item images are loaded from (defaults to rsg-inventory) |
| `ManageDistance` | How close to the foreman (checked server-side) a player must be to use the ledger |
| `ActionCooldown` | Minimum time (ms) between ledger actions per player |
| `LeaseDurationHours`, `AllowRenew`, `MaxLeaseHours` | Lease length and renewal rules |
| `WorkInterval` | Minutes per shift |
| `FoodDrain`, `WaterDrain`, `PickaxeWear` | How much each need drops per shift |
| `WageBase`, `WagePerSkill` | Wage per shift = `ceil(base + skill × perSkill)` |
| `MaxPayroll`, `AllowWithdraw` | The payroll fund's cap and whether players can withdraw from it |
| `CandidateCount`, `CandidateRefresh`, `HireBaseCost`, `HireCostPerSkill`, `CandidateSkillMax` | Hiring board settings |
| `SkillGainPerCycle`, `SkillChanceBonus`, `SkillAmountBonus` | How workers progress |
| `Mines` | Foreman location, lease price, worker cap, storage cap, blip and ore table for each mine (`minSkill` gates rare ores) |

## Discord webhooks

The webhook settings live in `server/sv_webhooks_config.lua`. That file is **server-only**, so clients never see the webhook URLs. Don't move these settings into `shared/config.lua`.

1. In Discord, go to Channel Settings → Integrations → Webhooks → New Webhook, then copy the URL.
2. Paste it into `WebhookConfig.DefaultUrl`. To send certain events to a different channel, set that event's own `url`.
3. Restart the resource and run `rsgmining_webhooktest` in the server console. Only the console or players with the `command.rsgmining_webhooktest` ace can run it.

| Event | When it fires |
|---|---|
| `lease_bought` / `lease_renewed` | A player buys or extends a lease (shows the price and when it expires) |
| `lease_expired` | A lease runs out (shows how many workers were released and the payroll left) |
| `worker_hired` / `worker_fired` | A crew change (shows the worker's name, skill and cost) |
| `supplies_added` | Bread, water or pickaxes are deposited |
| `ore_collected` | Ore is collected, sent as one post that lists every item |
| `wages_added` / `wages_withdrawn` | The payroll changes (shows the amount and the new fund balance) |
| `workers_strike` | Workers go on strike because the payroll is short |

Each post includes the character name, citizen ID and server ID. With `ShowIdentifiers` on, it also includes the player's name, a Discord mention and their license.

Set `alertAbove` on an event to flag large amounts: the post turns red and pings `AlertMention`.

Posts are queued per webhook and sent no faster than one every `SendInterval` (2.1s by default), which keeps them under Discord's rate limit. If Discord replies with a 429 (rate limited), the post is retried. Set `Enabled = false` to turn all webhook logging off.

## Locales

All the text players and staff see is in `locales/*.json`, using the ox_lib locale system. That covers notifications, the foreman ledger window and the Discord webhook posts.

The included languages are: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br` and `ro`.

To choose a language, set it in your server.cfg:

```
setr ox:locale de
```

How the keys are grouped:

- **No prefix:** notifications and dialogs
- **`ui_`:** text in the ledger window. These are passed to the window when it opens.
- **`status_`:** worker status labels
- **`wh_`:** Discord webhook titles and field names

`%s` placeholders are filled in order. To add a language, copy `en.json`, translate the values and keep every `%s`.

## Changelog

### 3.0.0 (audit pass)

- Fixed: the `wages` column upgrade used MariaDB-only syntax and stopped the script loading on MySQL.
- Fixed: rapid hire requests could push a crew past `maxWorkers` while the database insert was pending.
- Fixed: Discord posts retried after a 429 could get stuck in the queue until the next event.
- Fixed: lease-expiry notice and log never fired when the mine had no workers.
- Fixed: the foreman ped could spawn after you had already left the area (and leak), or hang forever if the model failed.
- Changed: deposits and collections use the `rsg-inventory` exports directly.
- Changed: "Collect all" sends one combined notification instead of one per item.
- UX: the ledger can't be opened twice, auto-closes when you walk away, keeps typed amounts on refresh, has live countdowns, a throttled refresh button, and Escape only acts when it's open.

## License

See `LICENSE`.
