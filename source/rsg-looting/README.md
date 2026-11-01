# rsg-looting

Secure NPC looting and player robbery for **RSG Framework (RedM)**, with ox_lib notifications, multi-language support and Discord webhook logging.

---

## Features

### NPC Looting
- Loot dead NPCs with **ox_target** (third-eye a body → *Loot Body*), with a search animation and progress bar.
- Looted bodies are flagged server side (entity state bag) so the prompt disappears for everyone.
- Random reward on every body: **common** or **rare** item plus a small amount of cash.
- Configurable rare chance, item pools and cash ranges.
- Optional lawman alert (via `rsg-lawman`) when a body is looted.
- Increases the player's outlaw status on successful loot / robbery (configurable).

### Player Robbery
- Rob a nearby player who is **dead**, **handcuffed** or has their **hands up**.
- Takes the victim's cash and/or blood money (toggle each) and opens their inventory.
- Progress bar with animation; can be cancelled.
- Per-victim cooldown so the same player can't be robbed repeatedly.
- Robber is told if the victim had no money on them.

### Security
- All rewards are decided and given **server side**; the client never chooses items or amounts.
- Server validates every loot: the entity exists, is an NPC, is dead, is within range and hasn't already been looted.
- Per-player loot cooldown stops event spamming.
- Robbery is checked by server-side distance, victim state and cooldown. The hands-up check asks the **victim's** client, so the robber can't fake it.
- Robbery must be approved by the server first and the reward event is only accepted after the progress bar time has passed, so cheaters can't skip it or rob without approval.
- The victim's hands-up check times out after 3 seconds, so an unresponsive client can't hang the robber.
- Inventory space is checked before items are added.

### Discord Webhooks
- Three separate channels: **loot**, **rob** and **exploit** (rejected / suspicious requests).
- Rich embeds with character name, citizen ID, player name, license, Discord mention and coordinates.
- Built-in send queue that respects Discord rate limits (retries on HTTP 429).
- Webhook URLs are kept in a **server-only** file so players can't read them.

### Localisation
- All player-facing and webhook text uses ox_lib locales.
- Included languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

---

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [rsg-lawman](https://github.com/Rexshack-RedM/rsg-lawman)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)
- OneSync enabled (used for server-side entity checks)

---

## Installation

1. Download the resource and place the `rsg-looting` folder in your `resources` directory (e.g. `resources/[rsg]/rsg-looting`).
2. Make sure all dependencies are started **before** this resource.
3. Add to your `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure ox_target
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-lawman
   ensure rsg-looting
   ```
4. Set your server language (optional, defaults to English):
   ```cfg
   setr ox:locale en
   ```
5. Add the items you want to use to `Config.CommonItems` / `Config.RareItems` (they must exist in `rsg-core/shared/items.lua`).
6. (Optional) Add your Discord webhook URLs in `server/sv_webhooks_config.lua`.
7. Restart your server.

---

## Configuration

### `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.CommonItems` | `{ 'bread', 'water' }` | Item pool for common loot |
| `Config.RareItems` | `{ 'bread', 'water' }` | Item pool for rare loot |
| `Config.RareChance` | `5` | % chance a body gives rare loot |
| `Config.CommonCash` | `{ 1, 5 }` | Min / max cash with common loot |
| `Config.RareCash` | `{ 5, 10 }` | Min / max cash with rare loot |
| `Config.LootTime` | `3000` | ms searching the body (progress bar) |
| `Config.LootDistance` | `3.0` | Max distance to the body (checked on server) |
| `Config.LootCooldown` | `3` | Seconds between loot rewards per player |
| `Config.LawAlert` | `true` | Alert lawmen when a body is looted |
| `Config.RobDistance` | `2.5` | Max distance to rob a player |
| `Config.RobCooldown` | `60` | Seconds before the same victim can be robbed again |
| `Config.TakeCash` | `true` | Take the victim's cash |
| `Config.TakeBloodMoney` | `true` | Take the victim's blood money |
| `Config.OutlawLoot` | `10` | `players.outlawstatus` added per successful loot (`0` = off) |
| `Config.OutlawRob` | `50` | `players.outlawstatus` added per successful robbery (`0` = off) |

### `server/sv_webhooks_config.lua`

| Option | Default | Description |
|---|---|---|
| `Enabled` | `true` | Master switch for all webhooks |
| `BotName` | `'RSG Looting'` | Name shown on Discord messages |
| `AvatarUrl` | `''` | Optional avatar image URL |
| `Footer` | `'rsg-looting'` | Embed footer text |
| `ShowIdentifiers` | `true` | Show license / Discord identifiers in embeds |
| `Webhooks.loot` | `''` | Webhook URL for NPC loot logs |
| `Webhooks.rob` | `''` | Webhook URL for player robbery logs |
| `Webhooks.exploit` | `''` | Webhook URL for suspicious activity logs |
| `LogCommonLoot` | `true` | Set `false` to only log rare loot |
| `Colors` | — | Embed colours per log type |

Leave any webhook URL empty (`''`) to disable that channel.

> ⚠️ Never move webhook URLs into `shared/config.lua`. Shared files are sent to every client.

---

## Usage

### Looting NPCs
1. Kill an NPC.
2. Target the body with ox_target and choose **Loot Body**.
3. When the search finishes, the server gives you a random item and some cash.

Each body can only be rewarded once.

### Robbing Players
Robbery is started with the client event:

```lua
TriggerEvent('rsg-looting:client:RobPlayer')
```

Hook this into your radial menu, target system or a command, for example:

```lua
RegisterCommand('rob', function()
    TriggerEvent('rsg-looting:client:RobPlayer')
end, false)
```

The target must be within `Config.RobDistance` and be **dead**, **handcuffed** or have their **hands up** (`script_proc@robberies@homestead@lonnies_shack@deception` / `hands_up_loop`). If your hands-up script uses a different animation, update `HANDSUP_DICT` / `HANDSUP_ANIM` at the top of `client/client.lua`.

### Sending Custom Webhooks (other resources)

```lua
exports['rsg-looting']:SendWebhook('loot', {
    title = 'Custom Log',
    description = 'Something happened',
    color = 0xFFFFFF,
})
```

Channel must be `loot`, `rob` or `exploit`.

---

## Adding a Language

1. Copy `locales/en.json` to `locales/<code>.json` (e.g. `it.json`).
2. Translate the values. Keep every `%s` placeholder.
3. Set `setr ox:locale <code>` in your `server.cfg`.

---

## File Structure

```
rsg-looting/
├── client/
│   └── client.lua
├── locales/
│   ├── en.json  de.json  el.json  es.json  fr.json
│   └── ja.json  nl.json  pl.json  pt-br.json  ro.json
├── server/
│   ├── server.lua
│   ├── sv_webhooks.lua
│   ├── sv_webhooks_config.lua
│   └── versionchecker.lua
├── shared/
│   └── config.lua
├── fxmanifest.lua
└── README.md
```

---

## Credits

- **RexShack / Rexshack-RedM**

## Support

If you enjoy this script, you can support development here: https://buymeacoffee.com/rexshack
