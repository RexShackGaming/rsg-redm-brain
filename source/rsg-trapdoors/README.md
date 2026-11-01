# rsg-trapdoors

Synced, animated trapdoors for **RSG-Core (RedM)** with an optional 4-digit passcode lock, a themed keypad UI, Discord webhook logging and full multi-language support.

---

## Features

- **Server-synced trapdoors** – open/close state is held by the server and pushed to every client through `GlobalState`, so every player sees the same thing, including players who stream in later.
- **Smooth animation** – time-based eased movement (not frame-rate dependent) that can be reversed mid-swing without twisting the prop.
- **Auto-close** – open trapdoors close themselves after a configurable time.
- **Passcode lock**
  - Any player can **Set Passcode** on a trapdoor that doesn't have one and becomes its owner.
  - Locked trapdoors show a keypad when opened; closing never needs the code.
  - The owner can **Change Passcode** (current code → new code → confirm).
  - Wrong guesses trigger a lockout per character, which survives relogging.
  - Codes are saved in the `rsg_trapdoors` SQL table (created automatically) and are never sent to clients.
  - Admin command to remove a passcode.
- **Keypad UI** – dark leather-and-gold RDR2 style, usable by mouse or keyboard.
- **Discord webhooks** – door, passcode and security logs across three channels, with batching, rate-limit handling and flood protection.
- **Secure by design** – the client only ever sends a door id (and a code). The server validates the id, the player, the distance to the door, cooldowns and ownership before anything happens.
- **Localised** – every player-facing, UI and log string comes from ox_lib locales. Ships with `en, de, el, es, fr, ja, nl, pl, pt-br, ro`.
- **ox_target** interaction with context-aware options (Open / Close / Set Passcode / Change Passcode).

---

## Dependencies

| Resource | Purpose |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework / player data |
| [oxmysql](https://github.com/overextended/oxmysql) | Stores passcodes in the database |
| [ox_lib](https://github.com/overextended/ox_lib) | Callbacks, locales, notifications, commands |
| [ox_target](https://github.com/overextended/ox_target) | Interaction options on the trapdoor props |

---

## Installation

1. Drop the `rsg-trapdoors` folder into your resources directory.
2. Make sure the dependencies start **before** it in `server.cfg`:

   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure rsg-core
   ensure ox_target
   ensure rsg-trapdoors
   ```

3. **No database setup needed** – the script builds its own tables on first start and upgrades them automatically on future updates (see [Database](#database)).
4. *(Optional)* Set the language – see [Languages](#languages).
5. *(Optional)* Add your Discord webhook URLs – see [Discord webhooks](#discord-webhooks).
6. Restart the server (or `ensure rsg-trapdoors`).

---

## File structure

```
rsg-trapdoors/
├── client/client.lua        -- sync, animation, ox_target options, keypad bridge
├── server/sv_config.lua     -- webhook + database config (SERVER ONLY)
├── server/database.lua      -- automatic database installer / migrations
├── server/logs.lua          -- Discord webhook logger
├── server/server.lua        -- state, passcodes, validation
├── server/versionchecker.lua
├── shared/config.lua        -- general + trapdoor config
├── html/                    -- keypad UI (index.html, style.css, script.js)
├── locales/*.json           -- translations
├── rsg_trapdoors.sql        -- optional manual table import
└── fxmanifest.lua
```

---

## Configuration

### General – `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.MoveDuration` | `2000` | Open/close animation time in ms. |
| `Config.AutoCloseTime` | `30000` | ms before an open trapdoor closes itself. `0` disables auto-close. |
| `Config.PlayerCooldown` | `1000` | ms between requests per player (anti-spam). |
| `Config.StreamDistance` | `100.0` | Distance at which clients look for and sync the prop. |
| `Config.MaxCodeAttempts` | `3` | Wrong passcodes before a lockout. |
| `Config.CodeLockoutTime` | `60000` | Lockout length in ms. |
| `Config.AdminResetCommand` | `'resettrapdoorcode'` | Name of the admin reset command. |

### Adding a trapdoor

Each entry in `Config.Trapdoors` is one physical trapdoor. The **key is its unique id** (used in commands and logs).

```lua
Config.Trapdoors = {
    rhodes_gunsmith = {
        label            = 'door_rhodes_gunsmith',        -- locale key for the display name
        model            = 'p_gunsmithtrapdoor01x',       -- prop model name
        closedPosition   = vec3(1326.04, -1326.38, 76.92),
        openPosition     = vec3(1326.07, -1326.36, 76.98),
        closedRotation   = vec3(0.0, 0.0, 165.0),         -- pitch, roll, yaw (degrees)
        openRotation     = vec3(-90.0, 0.0, 165.0),
        interactDistance = 2.0,
    },
}
```

- The prop must already exist in the world at (or within 3m of) `closedPosition` – the script finds and moves the existing map prop, it doesn't spawn one.
- Rotations use rotation order 2. A typical floor trapdoor opens by setting pitch to `-90.0`; a side-hinged door changes yaw instead.
- Add the `label` key (e.g. `"door_my_new_door": "My New Door"`) to **every** file in `locales/`.

### Discord webhooks – `server/sv_config.lua`

> ⚠️ This file is **server-only** so clients never download your webhook URLs. Never move it into `shared/`.

```lua
WebhookConfig.Enabled = true

WebhookConfig.Channels = {
    doors    = 'https://discord.com/api/webhooks/...', -- open / close / auto-close
    passcode = 'https://discord.com/api/webhooks/...', -- set / changed / admin reset
    security = 'https://discord.com/api/webhooks/...', -- wrong codes, lockouts, exploit attempts
}
```

Leave a URL empty (`''`) to disable that channel.

| Option | Default | Description |
|---|---|---|
| `AvatarUrl` | `''` | Optional avatar image for the webhook. |
| `ServerName` | `'RSG Server'` | Shown in the embed footer. |
| `ShowIdentifiers` | `true` | Include license / steam / discord identifiers. |
| `MentionDiscord` | `true` | Show a `<@id>` mention (never actually pings). |
| `ShowCoords` | `false` | Include the player's coords. |
| `LogPasscodes` | `false` | Show real codes as Discord spoilers. Leave off unless needed. |
| `SendInterval` | `2000` | ms between batches per channel. |
| `MaxEmbedsPerMsg` | `10` | Embeds per message (Discord max 10). |
| `MaxRetries` | `3` | Retries for failed / rate-limited sends. |
| `SuspiciousThrottle` | `10000` | Same player + same reason logged once per window. |

Each event can be toggled, recoloured or moved to another channel in `WebhookConfig.Events`:

| Event | Default channel | Default | Logged when |
|---|---|---|---|
| `door_open` | doors | on | A trapdoor is opened (shows whether a passcode was used) |
| `door_close` | doors | on | A player closes a trapdoor |
| `door_autoclose` | doors | **off** | A trapdoor auto-closes |
| `code_set` | passcode | on | A passcode is set (owner assigned) |
| `code_changed` | passcode | on | The owner changes the passcode |
| `code_reset` | passcode | on | An admin removes a passcode |
| `code_wrong` | security | on | A wrong passcode is entered |
| `code_lockout` | security | on | A player hits the attempt limit |
| `suspicious` | security | on | Invalid door id, too-far interaction, non-owner change attempt, setting a code on an already-locked door |

Embed titles, field names and the bot name are translated through the `log_*` locale keys.

Other resources can reuse the logger:

```lua
exports['rsg-trapdoors']:Log('suspicious', source, {
    door = 'rhodes_gunsmith',
    description = 'Custom message',
    fields = { { name = 'Extra', value = 'something', inline = true } },
})
```

---

## Database

Passcodes are stored in the `rsg_trapdoors` table via oxmysql. The script installs and maintains this itself:

- On start it creates any missing tables and applies any pending schema migrations, printing the result in the server console, e.g. `[rsg-trapdoors] database installed (schema v1)`.
- The applied schema version is tracked in a small `rsg_trapdoors_schema` table, so each migration only ever runs once.
- If the install fails, the error is printed and trapdoor interaction stays disabled until it's fixed, so locked doors can never be opened without their code.

To manage the schema yourself instead, set this in `server/sv_config.lua` and import `rsg_trapdoors.sql`:

```lua
DatabaseConfig = {
    AutoInstall = false,
}
```

---

## Languages

Set the language with the ox_lib convar in `server.cfg`:

```cfg
setr ox:locale en
```

Available: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

This controls player notifications, target options, the keypad UI and the Discord log text.

**Adding a language:** copy `locales/en.json` to `locales/<code>.json` and translate the values. Keep every key and keep `%s` placeholders in place.

---

## Usage

### Players

Aim at a trapdoor with ox_target to see the available options:

| Option | Shown when | What it does |
|---|---|---|
| **Open** | Trapdoor is closed | Opens it straight away if it has no passcode, otherwise shows the keypad. |
| **Close** | Trapdoor is open | Closes it. Never needs a code. |
| **Set Passcode** | No passcode set yet | Enter a 4-digit code, then confirm it. You become the owner. |
| **Change Passcode** | You own the passcode | Enter the current code, the new code, then confirm. |

**Keypad controls**

| Input | Action |
|---|---|
| `0`–`9` / click digits | Enter a digit |
| `Backspace` / ⌫ | Delete last digit |
| `Delete` / `C` | Clear all digits |
| `Enter` / Confirm | Submit |
| `Esc` / Cancel / ✕ | Close the keypad |

After `Config.MaxCodeAttempts` wrong codes you're locked out of that trapdoor for `Config.CodeLockoutTime`.

### Admins

```
/resettrapdoorcode <door id>
```

Removes the passcode and owner from a trapdoor (e.g. `/resettrapdoorcode strawberry`). Requires `group.admin`. It can also be run from the server console. The next player can then set a new passcode.

---

## Security notes

- Clients never send positions, rotations or state – only a door id and, when needed, a code. The server decides the result.
- Every request checks: valid door id, loaded RSG player, server-side distance to the door, per-player cooldown and, for passcodes, format, ownership and lockout.
- Passcodes are stored in the `rsg_trapdoors` SQL table and never replicated to clients. Clients only know whether a door is locked and the owner's citizenid (used to show **Change Passcode**).
- Webhook URLs live in a server-only file.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| No target options on the trapdoor | Check `ox_target` is started before this resource and that the prop exists within 3m of `closedPosition`. |
| Trapdoor doesn't move for other players | Make sure `closedPosition` matches the prop's real world position. |
| Keypad text is blank | The locale file for your `ox:locale` is missing keys – compare it with `en.json`. |
| Discord logs not arriving | Check the channel URL isn't empty, `WebhookConfig.Enabled = true`, the event is `enabled`, and watch the server console for `webhook failed` messages. |

---

## Credits

Original script by **RMS and Phil Mcracken**.
