# rsg-chat – Docs (v3.2.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `oxmysql` |
| `shared/config.lua` | Permissions, limits, default layout, seed channels |
| `client/cl_chat.lua` | Chat UI bridge, channel sync, settings, admin panel |
| `server/main.lua` | Channels, message routing, PSA, admin callbacks |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI (Vue, styles, dropdowns, suggestions) |
| `install.sql` | Optional manual table |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Replaces the default chat with channels managed in game by admins (`/chatadmin`), stored in the database.
- Each channel has a colour, optional prefix, range (`global`, `local`, `regional`, `group`), optional permission lock, its own length limit and a slash command (e.g. `/ooc`).
- `group` channels are limited to jobs or gangs, with an optional "on duty" rule.
- Changes sync to players at once. Players only see channels they can use, and the list updates on job or gang change.
- Players switch channels with the tabs, Tab / Shift+Tab or `/channel <id>`.
- Per-player window settings (position, size, font, opacity, timestamps, history, auto-hide) are stored on the player's PC.
- Messages show the character's first and last name.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `AdminPermission` | `'admin'` | Permission for `/chatadmin` |
| `PSAPermission` | `'admin'` | Permission to send a server PSA |
| `MessageCooldown` | `1000` | ms between messages per player |
| `HardMaxLength` | `512` | Absolute message cap |
| `DefaultChannel` | `'ooc'` | Starting channel |
| `MaxHistoryCap` | `250` | Highest history value a player can pick |
| `DistanceLimits` | `{2, 5000}` | Distance range the admin panel accepts (m) |
| `PermissionLevels` | list | Levels offered in the admin panel |
| `DefaultSettings` | table | Default window layout |
| `Channels` | list | Seed channels, only used when the table is empty |

Channel fields: `id`, `label`, `command`, `prefix`, `showPrefix`, `color`, `range`, `distance`, `maxLength`, plus `jobs`, `gangs`, `permission`, on-duty option.

## 4. Exports, events and commands
| Name | Side | Notes |
|---|---|---|
| `SendChannelMessage(channelId, author, text)` | server export | `exports['rsg-chat']:SendChannelMessage('staff', 'Server', 'Restart in 5 minutes')` |
| `GetChannels()` | server export | Channel list |
| `rsg-chat:server:send` | server event | `(channelId, message)` |
| `rsg-chat:server:requestChannels` | server event | Request the channel list |
| `chat:server:ServerPSA` | server event | `(message)` server-wide announcement (needs `PSAPermission` from a client) |
| `rsg-chat:server:adminGetChannels` and other `admin…` | callbacks | Admin panel actions, permission-checked |
| `rsg-chat:client:syncChannels` | client event | `(list, defaultId)` |
| `rsg-chat:client:channelMessage` | client event | `(payload)` |
| `rsg-chat:client:openAdmin` | client event | Open the admin panel |

| Command | Who | What |
|---|---|---|
| `/chatadmin` | `AdminPermission` | Channel manager |
| `/channel <id>` | everyone | Switch channel |
| `/chatsettings` | everyone | Window settings |
| `/togglechat` | everyone | Hide/show the chat box |
| `/clearchat` | everyone | Clear your own chat |
| one per channel | per channel | e.g. `/ooc`, `/l`, `/trade`, `/staff` |

## 5. Database
```sql
CREATE TABLE IF NOT EXISTS `rsg_chat_channels` (
  `id` VARCHAR(32) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `sort` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
);
```
Created on first start. The seed `Config.Channels` are only imported while the table is empty.

## 6. Security
The server works out the sender, checks channel access and range, trims messages, caps length and rate-limits. Clients cannot fake an author or post in channels they can't use. Admin callbacks are permission-checked. PSAs from a client need `PSAPermission`.

## 7. How-tos
- Add a staff channel: `/chatadmin` → new channel → set `permission` to `mod` or `admin`.
- Announce from a script: `exports['rsg-chat']:SendChannelMessage('ooc', 'Server', 'Welcome!')`.
- Reset a player's layout: they use the Reset layout button in chat settings.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Channel missing | Player lacks the job, gang or permission |
| Config channel edits ignored | Seed channels only apply to an empty table; use `/chatadmin` |
| Chat hidden | Player ran `/togglechat` |
| Message rejected | Over the channel limit or `MessageCooldown` |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-chat 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`

### Database

Tables: `rsg_chat_channels`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.AdminPermission` | `'admin'` | rsg-core permission for /chatadmin (channel manager) |
| `Config.PSAPermission` | `'admin'` | rsg-core permission needed to send a SERVER PSA |
| `Config.MessageCooldown` | `1000` | ms between chat messages per player (all channels) |
| `Config.HardMaxLength` | `512` | absolute cap; a channel's own limit can't go above this |
| `Config.DefaultChannel` | `'ooc'` | channel players start on (falls back to the first one they can use) |
| `Config.MaxHistoryCap` | `250` | highest "message history" value players can pick |
| `Config.DistanceLimits` | `{ min = 2, max = 5000 }` | Distance limits the admin panel will accept (metres) |
| `Config.PermissionLevels` | `{ '', 'helper', 'mod', 'admin', 'headadmin', 'developer', 'god' }` | Permission levels offered in the admin panel dropdown ('' = everyone) |
| `Config.DefaultSettings` | `table` |  |
| `Config.Channels` | `table` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `SendChannelMessage` | `channelId, author, text` | `server/main.lua` |
| `GetChannels` | `` | `server/main.lua` |

```lua
-- example
local result = exports['rsg-chat']:SendChannelMessage(channelId, author, text)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-chat:server:adminGetChannels` | server | `src, cb` | `server/main.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-chat:server:adminGetChannels', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `chatMessage` | client | `` | `client/cl_chat.lua` |
| `chat:addTemplate` | client | `` | `client/cl_chat.lua` |
| `chat:addMessage` | client | `` | `client/cl_chat.lua` |
| `chat:addSuggestion` | client | `` | `client/cl_chat.lua` |
| `chat:addSuggestions` | client | `` | `client/cl_chat.lua` |
| `chat:removeSuggestion` | client | `` | `client/cl_chat.lua` |
| `chat:clear` | client | `` | `client/cl_chat.lua` |
| `__cfx_internal:serverPrint` | client | `` | `client/cl_chat.lua` |
| `rsg-chat:client:syncChannels` | client | `list, defaultId` | `client/cl_chat.lua` |
| `rsg-chat:client:channelMessage` | client | `payload` | `client/cl_chat.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/cl_chat.lua` |
| `RSGCore:Client:OnJobUpdate` | client | `` | `client/cl_chat.lua` |
| `RSGCore:Client:OnGangUpdate` | client | `` | `client/cl_chat.lua` |
| `rsg-chat:client:openAdmin` | client | `` | `client/cl_chat.lua` |
| `rsg-chat:server:send` | server | `channelId, message` | `server/main.lua` |
| `_chat:messageEntered` | server | `_, _, message` | `server/main.lua` |
| `rsg-chat:server:requestChannels` | server | `` | `server/main.lua` |
| `__cfx_internal:commandFallback` | server | `command` | `server/main.lua` |
| `chat:server:ServerPSA` | server | `message` | `server/main.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-chat:server:send', channelId, message)
-- from a server script
TriggerClientEvent('chatMessage', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/chatsettings` |  | `client/cl_chat.lua` |
| `/togglechat` |  | `client/cl_chat.lua` |
| `/channel` |  | `client/cl_chat.lua` |
| `/chatadmin` | locale('help_chatadmin') | `server/main.lua` |
| `/clearchat` |  | `server/main.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
