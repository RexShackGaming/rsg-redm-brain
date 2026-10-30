# rsg-chat

A chat resource for **RedM** servers running **RSG-Core**. It replaces the default chat with channels that admins manage in-game, and a chat window each player can move, resize and style to suit themselves. Every message shows the sender's in-character name, and the server checks each message before sending it to players.

## Features

### Channels (managed in-game from an admin panel)
- **Admin panel:** `/chatadmin` opens a channel manager. Admins can create, edit, enable, disable, delete and reorder channels without restarting anything. Channels are stored in the database.
- **Custom colour per channel:** type a hex code or pick a preset, with a live preview.
- **Optional prefixes:** turn the prefix on or off per channel, for example `[OOC] Turchiron: Hello` or `[Trade] Turchiron: Selling a horse`.
- **Message range per channel:**
  - **Global:** everyone.
  - **Local:** players within a set distance.
  - **Regional:** the same as local, but with a wider radius.
  - **Group:** only certain jobs or gangs, with an optional "must be on duty" rule.
- **Permission lock:** a channel can require an RSG-Core permission level (for example a staff channel).
- **Message length per channel:** each channel has its own character limit, under an overall server cap.
- **Slash command per channel:** for example `/ooc`, `/l`, `/trade`, `/staff`.
- **Live sync:** changes reach players straight away. Each player only sees the channels they can use, and the list updates when their job or gang changes.

### Player chat window
- **Switchable channels:** click a channel tab, press **Tab** / **Shift+Tab**, or use `/channel <id>`. The selected channel stays active until the player changes it.
- **Movable:** drag the header to put the chat anywhere on screen.
- **Resizable:** drag the bottom-right corner to change the width and height.
- **Font size:** adjustable.
- **Background transparency:** adjustable from fully clear to solid.
- **Timestamps:** turn on or off.
- **Message history:** choose how many messages are kept, and scroll back through them (mouse wheel or Page Up / Page Down while chat is open).
- **Auto-hide:** fade out or hide after a chosen number of seconds without activity, or keep the chat always visible.
- **Turn chat off completely:** hide the chat box and drop incoming messages, with the "Show chat box" switch or `/togglechat`.
- **Reset layout:** put everything back to the server defaults.
- **Saved per player:** all of these settings are stored on the player's own PC, so they survive restarts.
- **Character counter:** shows how many characters are left for the active channel.

### General
- **Character names:** messages show the sender's character first and last name, falling back to their account name.
- **Server-side checks:** the server works out the sender, checks channel access and range, trims messages, caps their length and rate-limits them, so clients can't fake an author, post in channels they can't use, or spam.
- **Server announcements (PSA):** a server-wide announcement event that other server scripts can trigger, and admins can trigger from a client.
- **Unknown commands:** mistyped commands show an ox_lib notification instead of failing silently.
- **Command suggestions:** shows suggestions for every command the player has permission to use, including each channel's command.
- **Message history recall:** the Up and Down arrow keys bring back messages you sent earlier.
- **Hides automatically** while the screen is faded out or the pause menu is open.
- **Translations:** locale files for en, de, el, es, fr, ja, nl, pl, pt-br and ro, via ox_lib.
- **Themes:** supports `chat_theme` from other resources, plus customisable message templates.
- **Logging:** channel changes made in the admin panel are logged through `rsg-log`.

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation

1. Put the `rsg-chat` folder in your server's `resources` directory, for example `resources/[rsg]/rsg-chat`.
2. Remove or stop any other chat resource, such as the default `chat`.
3. Make sure it starts **after** its dependencies in `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure rsg-core
   ensure rsg-chat
   ```
4. Restart the server. The `rsg_chat_channels` table is created automatically on first start. `install.sql` is included if you'd rather create it yourself.

## Configuration

### Server settings: `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.AdminPermission` | `'admin'` | Permission needed for `/chatadmin`. |
| `Config.PSAPermission` | `'admin'` | Permission needed to send a server PSA from a client. |
| `Config.MessageCooldown` | `1000` | Minimum time between messages per player, in milliseconds. |
| `Config.HardMaxLength` | `512` | Overall character cap; no channel can be set higher. |
| `Config.DefaultChannel` | `'ooc'` | Channel players start on (falls back to the first channel they can use). |
| `Config.MaxHistoryCap` | `250` | Highest message history players can choose. |
| `Config.DistanceLimits` | `2` – `5000` | Allowed distance range (metres) for local and regional channels. |
| `Config.PermissionLevels` | `''`, helper … god | Permission levels offered in the admin panel (`''` = everyone). |
| `Config.DefaultSettings` | see file | Default chat layout for new players, and what "Reset layout" restores. |
| `Config.Channels` | OOC, Local, Trade, Staff | Starting channels, **used only on first start** when the table is empty. After that, manage channels with `/chatadmin`. |

**Default layout (`Config.DefaultSettings`):**

| Key | Default | Description |
|---|---|---|
| `x`, `y` | `1.5`, `2.5` | Position, in % of the screen. |
| `w`, `h` | `30`, `32` | Size, in % of the screen. |
| `fontSize` | `15` | Text size in px. |
| `opacity` | `55` | Background opacity, 0–100. |
| `timestamps` | `false` | Show the time each message was sent. |
| `history` | `100` | Messages kept and scrollable. |
| `autoHide` | `'fade'` | `'fade'`, `'hide'` or `'never'`. |
| `hideDelay` | `10` | Seconds without activity before fading or hiding. |
| `chatOff` | `false` | Chat box turned off completely. |

### Channel options (admin panel)

| Field | Description |
|---|---|
| Name | Label shown on the channel tab. |
| Channel id | Unique id (letters, numbers, `_`), used by `/channel <id>` and exports. |
| Command | Optional slash command that sends straight to this channel (no `/`). |
| Prefix / Show prefix | Tag shown before the sender's name, e.g. `[Trade]`. |
| Text colour | Hex colour for the whole message line. |
| Range | Global, Local, Regional or Group. |
| Distance | Radius in metres (Local and Regional only). |
| Jobs / Gangs | Comma-separated job or gang names that can use the channel (Group only). |
| Must be on duty | Job members must be on duty (Group only). |
| Required permission | RSG-Core permission level needed to see and use the channel. |
| Max characters | Message length limit for this channel. |
| Enabled | Turn the channel off without deleting it. |

### UI settings: `html/js/config.js`

| Option | Description |
|---|---|
| `templates` | Static message templates (`{0}`, `{1}`… are replaced by the message arguments). |
| `suggestionLimit` | Maximum number of command suggestions shown at once. |
| `defaultSettings` | Fallback layout used until the client sends `Config.DefaultSettings`. |

Change the look in `html/css/style.css`.

### Language

Set the ox_lib locale in `server.cfg`:
```cfg
setr ox:locale en
```
To add a language, copy `locales/en.json` to a new file, for example `locales/it.json`, and translate the values. Only `en.json` has the text for the new panels so far.

## Usage

### Players

| Action | Description |
|---|---|
| **T** (default MP chat key) | Open the chat input. |
| Type a message + **Enter** | Send to your active channel. |
| **Tab** / **Shift+Tab** | Switch to the next or previous channel. |
| Click a channel tab | Switch channel. |
| **⚙** button | Open chat settings. |
| Drag the header / corner | Move or resize the chat (while it's open). |
| **Up** / **Down** | Recall messages you sent earlier. |
| **Page Up** / **Page Down**, mouse wheel | Scroll the chat history. |
| **Esc** | Close the chat. |
| `/<channel command> <message>` | Send straight to a channel, e.g. `/ooc`, `/l`, `/trade`. |
| `/channel <id>` | Change your active channel. |
| `/chatsettings` | Open chat settings. |
| `/togglechat` | Turn the chat box on or off. |
| `/clearchat` | Clear your own chat window. |

### Admins

| Command | Description |
|---|---|
| `/chatadmin` | Open the channel manager (needs `Config.AdminPermission`). |

### Developers

**Send a message into a channel** (server). It only reaches players who can use that channel:
```lua
exports['rsg-chat']:SendChannelMessage('staff', 'Server', 'Restart in 5 minutes')
```

**Get all channels** (server):
```lua
local channels = exports['rsg-chat']:GetChannels()
```

**Send a message to a player** (`-1` sends it to everyone):
```lua
TriggerClientEvent('chat:addMessage', source, {
    template = '<div class="chat-message">{0}: {1}</div>',
    args = { 'System', 'Hello world' },
})
```

**Server-wide announcement (PSA)** from a server script. Clients can trigger it too, but only if they have `Config.PSAPermission`:
```lua
TriggerEvent('chat:server:ServerPSA', 'Server restart in 5 minutes!')
```

**Add a command suggestion** (client):
```lua
TriggerEvent('chat:addSuggestion', '/mycommand', 'What it does', {
    { name = 'target', help = 'Player ID' },
})
```

**Intercept or cancel messages** (server). `rsg-chat` fires `chatMessage` before sending any channel message, and calling `CancelEvent()` blocks it:
```lua
AddEventHandler('chatMessage', function(source, name, message)
    if message:find('badword') then CancelEvent() end
end)
```

**Other client events:** `chat:addTemplate`, `chat:removeSuggestion`, `chat:clear`. Older scripts that send plain chat through `_chat:messageEntered` are posted to the default channel.

## License

See [LICENSE](LICENSE).

Support: https://buymeacoffee.com/rexshack
