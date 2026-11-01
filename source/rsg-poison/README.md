# rsg-poison

A poison / antidote system for **RSG-Core** RedM servers. Players can be poisoned by poison ammo (throwing knives, arrows) or venomous snake bites, take ongoing health drain until cured, and are cured with a consumable `tonic_antidote` item. Poison state persists across logout, disconnect, and server restarts, and every meaningful event can be logged to Discord.

## Features

- **Poison sources** — poison-tipped throwing knives / arrows, poison-throwable weapons (e.g. poison bottles), and configurable snake ped models all inflict poison on hit, detected via the game's native damage event (no polling of player health every frame).
- **Ongoing health drain** — while poisoned and untreated, the player steadily loses health on a configurable interval until cured or killed.
- **Antidote item** — a `useable` `tonic_antidote` item triggers a drinking animation/prop and cures the player, consuming one item on use.
- **Persistent state** — poison status is saved to the player's metadata, so it survives logoff, disconnects, kicks, and server restarts. On reconnect, a still-poisoned player automatically resumes the effect (with a quieter "still poisoned" notice instead of the initial alert).
- **Server-authoritative cure validation** — the server does not blindly trust a client claiming "I'm cured." A cure is only accepted when it comes from a validated antidote use or an actual (server-checked) death, and only once the antidote's drink animation could genuinely have finished. Anything else is rejected and logged as a possible exploit attempt.
- **NUI status indicator** — an on-screen "POISONED" indicator fades in/out, with its label driven from the locale file rather than hardcoded HTML.
- **Full localization** — all client and server user-facing strings live in `locales/*.json` via `ox_lib`'s `lib.locale()`/`locale()`, so adding another language is just adding another locale file.
- **Discord webhook logging** — optional, fully configurable per-event webhook logging (poisoned, resumed, antidote used, died while poisoned, rejected/exploit cure attempts), with its own rate-limited send queue so you never get Discord 429s.
- **Version checker** — checks a GitHub-hosted `version.txt` on resource start and warns in the server console if you're running an outdated build.

## Requirements

- [RSG-Core](https://github.com/Rexshack-RedM/rsg-core) framework
- [ox_lib](https://github.com/Rexshack-RedM/ox_lib)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- RedM / FiveM server with `lua54` and the standard `rdr3` game build

## Installation

1. Download/clone this resource into your server's resources folder, e.g. `resources/[rsg]/rsg-poison`.
2. Make sure `ox_lib` and `rsg-core` are started **before** this resource in your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-poison
   ```
3. Add the `tonic_antidote` item to your inventory's shared items. The definition is provided for you in `installation/shared_items.lua` — copy that line into your inventory resource's `shared/items.lua` (or equivalent):
   ```lua
   tonic_antidote = { name = 'tonic_antidote', label = 'Snake Oil Antidote', weight = 0.5, type = 'item', image = 'tonic_antidote.png', unique = false, useable = true, shouldClose = true, category = 'herbalist', description = 'Counters poison and venom.' },
   ```
4. Copy `installation/tonic_antidote.png` into your inventory resource's item image folder (wherever it serves item icons from, e.g. `html/images/items/`).
5. Restart your server (or `refresh` + `ensure rsg-poison`).

No database/SQL setup is required — poison state is stored on the player object's metadata, not a separate table.

## Configuration

### `shared/config.lua`

General gameplay tuning, shared to both client and server:

| Setting | Description |
|---|---|
| `Config.Snakes` | List of snake ped models (`{ model = '...' }`) whose bite inflicts poison. |
| `Config.PoisonAmmo` | List of ammo hash names (e.g. `AMMO_ARROW_POISON`) that inflict poison on hit. |
| `Config.PoisonWeapons` | List of weapon hash names (e.g. `WEAPON_THROWN_POISONBOTTLE`) that inflict poison on hit directly, without needing a separate poison ammo type. |
| `Config.PoisonTickInterval` | How often (ms) health drains while poisoned and untreated. |
| `Config.PoisonHealthDrainBase` | How much health is removed per drain tick. |

### Languages (`locales/*.json`)

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language in `server.cfg` with `setr ox:locale de` (ox_lib). Covers notifications, the NUI indicator, the test command and Discord log text.

### `locales/en.json`

All player-facing text (notification titles/descriptions, the NUI indicator label) lives here as key/value pairs, loaded via `ox_lib`'s `lib.locale()`. To add another language, copy this file to e.g. `locales/fr.json`, translate the values, and set `ox_lib`'s locale convar/config to that language — keys must stay identical.

### `server/webhook_config.lua` — Discord logging

Server-only (webhook URLs are never sent to clients).

| Setting | Description |
|---|---|
| `Enabled` / `Debug` | Master switch; `Debug` prints sends and failures to the console. |
| `ServerName`, `BotName`, `AvatarUrl` | Footer text and webhook identity. |
| `Urls.*` | Per-event webhook URLs; blank falls back to `Urls.default`. All blank = logging off. |
| `Events.*` | Per-event on/off (`antidoteDenied` is off by default as it's noisy). |
| `Mentions.*` | Optional role ping per event, e.g. ping staff on `exploitAttempt`. |
| `Include.*` | Which player info goes in embeds: character, citizen ID, job, Discord mention, license, Steam, health, coords. |
| `Colors.*` | Embed colour per event. |
| `SendIntervalMs`, `MaxQueue`, `MaxRetries` | Queue tuning. Discord 429s are retried after `retry_after`. |
| `TestCommandAce` | Who may run `/poisonwebhooktest`. |

**Logged events:** `cured` (via export), `poisoned` (with cause: snake / poison ammo / poison weapon), `resumed`, `antidoteUsed` (with time spent poisoned), `antidoteWasted`, `antidoteDenied`, `death`, `exploitAttempt` (forged cures, invalid data, throttled to one per player per 30s), `system` (resource start, test command).

**Test:** run `/poisonwebhooktest` in-game or from the server console to send a test embed to every configured URL.

**From other resources:**
```lua
exports['rsg-poison']:SendPoisonLog('poisoned', {
    title = 'Custom Log',
    description = 'Something happened',
    src = source,                                  -- optional: attaches player info
    fields = { { name = 'Extra', value = 'data' } } -- optional
})
```

## Exports (server)

```lua
-- Cure a player (e.g. from a medic job). Returns true if they were poisoned.
exports['rsg-poison']:CurePlayer(src)

-- Check whether a player is currently poisoned.
exports['rsg-poison']:IsPoisoned(src)
```

Cures done through `CurePlayer` are logged under the `cured` webhook event.

## Usage

- Getting hit by poison ammo or bitten by a configured snake automatically poisons the player, shows a warning notification, and starts the health drain.
- Using the `tonic_antidote` item while poisoned plays a drinking animation and cures the player; using it while not poisoned just tells the player they don't need it (no item is consumed).
- If a player disconnects/relogs/the server restarts while still poisoned, the effect automatically resumes once their character loads back in.

## Support / Updates

This resource includes an automatic version checker (`server/versionchecker.lua`) that compares your installed version against the latest release on startup and prints a warning to the server console if you're out of date.

Support: https://buymeacoffee.com/rexshack
