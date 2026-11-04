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

Support: https://buymeacoffee.com/rexshack
