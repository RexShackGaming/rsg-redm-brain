# rsg-trapdoors – Developer & Server Owner Docs

Version 2.1.0. For installation and player usage see [README.md](README.md).

## Contents
1. Architecture
2. Data & state
3. Callbacks and events
4. Exports
5. Security model
6. Database schema
7. How-tos
8. Troubleshooting

---

## 1. Architecture

| File | Side | Role |
|---|---|---|
| `shared/config.lua` | shared | Timings, passcode rules, `Config.Trapdoors` |
| `server/sv_config.lua` | server | Webhooks (`WebhookConfig`) and `DatabaseConfig.AutoInstall` |
| `server/database.lua` | server | `TrapdoorDB.Install()` – numbered migrations tracked in `rsg_trapdoors_schema` |
| `server/server.lua` | server | Door state, passcodes, validation, lockouts, admin command |
| `server/logs.lua` | server | Batched Discord logger (`TrapdoorLog`, export `Log`) |
| `server/versionchecker.lua` | server | GitHub version check |
| `client/client.lua` | client | Finds the map props, animates them, rsg-target options, keypad bridge |
| `html/*` | NUI | Keypad (modes `unlock`, `set`, `change`, `remove`) |

The script moves **existing map props** – it never spawns them.

## 2. Data & state

| GlobalState key | Value | Meaning |
|---|---|---|
| `trapdoor:<id>` | `bool` | Door open |
| `trapdoorCode:<id>` | `citizenid` or `false` | Owner of the passcode (codes themselves never leave the server) |

Server memory: `codes[id] = { code, owner }`, `failures[license][id] = { count, lockUntil }`.
All doors start closed on resource start. Open doors auto-close after `Config.AutoCloseTime`.

## 3. Callbacks and events

All callbacks are rsg-core callbacks (`RSGCore.Functions.CreateCallback`) and return `ok, message`.

| Name | Type | Args | Notes |
|---|---|---|---|
| `rsg-trapdoors:server:open` | callback | `id, code?` | Code required only when the door is locked |
| `rsg-trapdoors:server:setCode` | callback | `id, newCode` | Fails if a code exists or codes are disabled |
| `rsg-trapdoors:server:changeCode` | callback | `id, current, newCode` | Owner only |
| `rsg-trapdoors:server:removeCode` | callback | `id, current` | Owner only |
| `rsg-trapdoors:server:close` | net event | `id` | Never needs a code |

NUI callbacks: `close`, `submit` (`{ mode, code?, newCode? }`).

Command: `/<Config.AdminResetCommand> <id>` (rsg-core `admin`, also console).

## 4. Exports

```lua
-- server: write to the trapdoor Discord logger
exports['rsg-trapdoors']:Log(event, source, { door = id, description = 'text', fields = { { name = 'x', value = 'y', inline = true } } })
```
`event` must be a key of `WebhookConfig.Events`.

## 5. Security model

Every client request goes through `validate()` on the server:
1. Door id must exist in `Config.Trapdoors` (otherwise logged as `suspicious`).
2. RSG player must be loaded and the database ready.
3. Per-player cooldown `Config.PlayerCooldown`.
4. Server-side distance: `interactDistance + 3.0` from `closedPosition` (else `suspicious`).
5. Passcode: 4 digits, owner check by citizenid, lockout after `Config.MaxCodeAttempts` per **licence** (character swapping does not reset it).

The script handles no money or items. Codes are stored in plain text in SQL – restrict DB access accordingly.

## 6. Database schema

```sql
CREATE TABLE IF NOT EXISTS `rsg_trapdoors` (
    `door_id`    VARCHAR(64) NOT NULL,
    `passcode`   CHAR(4)     NOT NULL,
    `owner`      VARCHAR(50) NOT NULL,
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`door_id`)
);
```
Built automatically when `DatabaseConfig.AutoInstall = true` (default). Set it to `false` and import `rsg_trapdoors.sql` to install manually. New schema changes go in as a new numbered migration in `server/database.lua` and in `rsg_trapdoors.sql`.

## 7. How-tos

- **Add a door:** add an entry to `Config.Trapdoors` (see README) and its `label` key to all 10 locale files.
- **Public door that nobody can lock:** set `allowCode = false` on that door.
- **Admin-only passcodes:** `Config.AllowPlayerCodes = false`.
- **Clear a squatted door:** `/resettrapdoorcode <id>`.

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| No target options | Start `rsg-target` first; prop must be within 3 m of `closedPosition`. |
| Keypad does nothing | Check the server console for `database install failed`; requests are ignored until the DB is ready. |
| Text shows keys | Locale file for `rsg:locale` is missing keys – compare with `en.json`. |
| "Set Passcode" missing | `Config.AllowPlayerCodes` is false or the door has `allowCode = false`. |

---

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-trapdoors 3.0.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`, `rsg-target`

### Database

Tables: `rsg_trapdoors`, `rsg_trapdoors_schema`.

For a manual install set `Config.AutoDatabase = false` and import `rsg_trapdoors.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.MoveDuration` | `2000` | ms the open/close animation takes |
| `Config.AutoCloseTime` | `30000` | ms before an open trapdoor closes itself (0 = never) |
| `Config.PlayerCooldown` | `1000` | ms between toggle requests per player |
| `Config.StreamDistance` | `100.0` | distance at which clients look for / sync the prop |
| `Config.AllowPlayerCodes` | `true` | false = only admins can manage passcodes (stops players locking public doors). Per door: allowCode = false |
| `Config.MaxCodeAttempts` | `3` | wrong guesses before a player is locked out of that door |
| `Config.CodeLockoutTime` | `60000` | ms lockout after too many wrong guesses |
| `Config.AdminResetCommand` | `'resettrapdoorcode'` | /resettrapdoorcode <door id> (group.admin) |
| `Config.Trapdoors` | `table` | rotations are pitch/roll/yaw in degrees (rotation order 2) |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `Log` | `` | `server/logs.lua` |

```lua
-- example
local result = exports['rsg-trapdoors']:Log()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-trapdoors:server:open` | server | `src, cb, id, code` | `server/server.lua` |
| `rsg-trapdoors:server:setCode` | server | `src, cb, id, newCode` | `server/server.lua` |
| `rsg-trapdoors:server:changeCode` | server | `src, cb, id, current, newCode` | `server/server.lua` |
| `rsg-trapdoors:server:removeCode` | server | `src, cb, id, current` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-trapdoors:server:open', function(result)
    -- use result
end, id, code)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-trapdoors:server:close` | server | `id` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-trapdoors:server:close', id)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
