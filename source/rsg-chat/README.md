# rsg-chat

A chat resource for **RedM** servers running **RSG-Core**. It replaces the default chat. Every message shows the sender's in-character name, and the server checks each message before sending it to players.

## Features

- **Character names:** messages show the sender's character first and last name, falling back to their account name.
- **Server-side checks:** the server works out who sent each message and trims it, caps its length and rate-limits it, so clients can't fake an author or spam.
- **Out-of-character chat:** plain chat and `/ooc` are both sent to everyone with an `[OOC]` tag.
- **Server announcements (PSA):** a server-wide announcement event that other server scripts can trigger, and admins can trigger from a client.
- **Unknown commands:** mistyped commands show an ox_lib notification instead of failing silently.
- **Command suggestions:** shows suggestions for every command the player has permission to use, with translated help text for this resource's own commands.
- **Translations:** locale files for en, de, el, es, fr, ja, nl, pl, pt-br and ro, via ox_lib.
- **Themes:** supports `chat_theme` from other resources, plus customisable message templates and styling.
- **Auto-hide:** the chat hides while the screen is faded out or the pause menu is open.

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)

## Installation

1. Download the resource and put the `rsg-chat` folder in your server's `resources` directory, for example `resources/[rsg]/rsg-chat`.
2. Remove or stop any other chat resource, such as the default `chat`.
3. Make sure it starts **after** its dependencies in `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-chat
   ```
4. Restart the server.

## Configuration

### Server settings: `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.MaxMessageLength` | `256` | Maximum characters per message; anything longer is cut off. |
| `Config.MessageCooldown` | `1000` | Minimum time between messages per player, in milliseconds. |
| `Config.PSAPermission` | `'admin'` | RSG-Core permission a player needs to send a server PSA. |

### UI settings: `html/js/config.js`

| Option | Description |
|---|---|
| `templates` | Static message templates (`{0}`, `{1}`… are replaced by the message arguments). |
| `fadeTimeout` | How long (ms) the chat stays visible after the last message. |
| `suggestionLimit` | Maximum number of command suggestions shown at once. |
| `style` | Chat box `background`, `width` and `height`. |

Change the look in `html/css/style.css`.

### Language

Set the ox_lib locale in `server.cfg`:
```cfg
setr ox:locale en
```
To add a language, copy `locales/en.json` to a new file, for example `locales/it.json`, and translate the values.

## Usage

### Players

| Action | Description |
|---|---|
| **T** (default MP chat key) | Open the chat input. |
| Type a message + **Enter** | Send an out-of-character message to everyone. |
| `/ooc <message>` | Send an out-of-character message. |
| `/clearchat` | Clear your own chat window. |
| `/<command>` | Run any command; suggestions appear as you type. |

### Developers

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

**Intercept or cancel OOC messages** (server). `rsg-chat` fires `chatMessage` before broadcasting, and calling `CancelEvent()` blocks the message:
```lua
AddEventHandler('chatMessage', function(source, name, message)
    if message:find('badword') then CancelEvent() end
end)
```

**Other client events:** `chat:addTemplate`, `chat:removeSuggestion`, `chat:clear`.

## License

See [LICENSE](LICENSE).
