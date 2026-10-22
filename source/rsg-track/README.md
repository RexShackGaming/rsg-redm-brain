# rsg-track

A custom horse race track builder and race manager for **RSG-Core** RedM servers. Players (or staff) lay out a checkpoint route in the open world with a couple of keybinds, save it to the database, invite riders, and run multi-lap races with automatic winner tracking, cash rewards, and optional Discord logging — all through a themed NUI menu.

---

## Features

- **In-world track creation** — press `J` to drop the start and intermediate checkpoints, `G` to drop the finish at your current position. Particle-effect rings mark every checkpoint (red = start, gold = mid-points, green = finish) and rotate to always face nearby players.
- **Persistent, shareable tracks** — finished tracks are named and saved to MySQL, so any track built once can be reloaded and reused by everyone on the server, indefinitely.
- **Full race lifecycle** — join, start, run (with a 10-second countdown), and finish, with GPS routing to the next checkpoint and live progress toasts.
- **Multi-lap support** — 1–5 laps, configurable per race by an admin before it starts.
- **Automatic results & rewards** — the first rider to finish wins a configurable cash reward; all finishers are recorded with their placement, a podium/winners screen pops up automatically, and the last 5 race results are kept for a "previous races" history view.
- **Themed NUI menu** (`J` near a track's start, or `/racerace`) — create/load/delete tracks, join/leave/start a race, adjust laps and max checkpoints, view current participants, and view results/winners, all from an in-game panel.
- **Server-authoritative race logic** — lap counts, race state, and finish timing are all tracked server-side (not trusted from the client), so the race can't be won by sending a fake "finished" event or an inflated lap count.
- **Admin-gated race control** — starting a track edit, deleting tracks, changing lap count/marker limits, and resetting a race all require an RSGCore permission (configurable), so random players can't grief an ongoing race.
- **Optional Discord webhook logging** — track created/deleted, race started/finished (with full standings), settings changes, and database errors can all be posted to a Discord channel as embeds.
- **Full localization** — every player-facing string (menu, toasts, prompts) is driven by JSON locale files. Ships with **10 languages**: English, German, Greek, Spanish, French, Japanese, Dutch, Polish, Brazilian Portuguese, and Romanian (plus existing Italian/Russian files).
- **Version checker** — pings GitHub on resource start and warns in the server console if a newer version of the resource is available.

---

## Dependencies

Install and start these **before** `rsg-track` in your `server.cfg`:

| Resource | Purpose |
|---|---|
| [`rsg-core`](https://github.com/Rexshack-RedM) | Framework — player data, money, permissions |
| [`ox_lib`](https://github.com/overextended/ox_lib) | Client-side notifications (`lib.notify`) |
| [`oxmysql`](https://github.com/overextended/oxmysql) | MySQL/MariaDB queries |

A MySQL/MariaDB database reachable by `oxmysql` is required. The `horse_race_tracks` table is created automatically on first resource start — no manual migration needed.

---

## Installation

1. Download or clone this resource into your server's `resources` directory as `rsg-track`.
2. Add it to your `server.cfg` **after** its dependencies:

   ```cfg
   ensure rsg-core
   ensure ox_lib
   ensure oxmysql
   ensure rsg-track
   ```

3. Start (or restart) your server. On first start, `rsg-track` automatically creates its `horse_race_tracks` table:

   ```sql
   CREATE TABLE IF NOT EXISTS horse_race_tracks (
       track_id   INT AUTO_INCREMENT PRIMARY KEY,
       name       VARCHAR(50) NOT NULL,
       points     JSON NOT NULL,
       timestamp  DATETIME DEFAULT CURRENT_TIMESTAMP
   )
   ```

4. In-game, run `/racerace` (or `/race`) to open the menu and confirm the resource loaded correctly.

---

## Configuration

All settings live in **`shared/config.lua`**.

### Language

```lua
Config.Locale = 'en'
```

Set to any of the shipped language codes: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro` (also `it` and `ru` if present in `locales/`). If a translation is missing a key, or the code doesn't match a file in `locales/`, it silently falls back to English — the resource never errors from a missing/partial locale.

To add a new language, drop a `locales/<code>.json` file with the same keys as `locales/en.json` and set `Config.Locale` to that code.

### Discord webhooks

```lua
Config.Webhook = {
    enabled = false,       -- master switch — nothing posts until this is true
    url = '',              -- fallback webhook URL used by any event without its own url
    botName = 'RSG-Track',
    botAvatar = '',        -- optional avatar image URL for the webhook
    footer = 'RSG-Track Logs',
    minIntervalMs = 350,   -- min gap between posts to the same URL (rate-limit safety)

    events = {
        trackCreated    = { enabled = true, url = '', color = 3066993  },
        trackDeleted    = { enabled = true, url = '', color = 15158332 },
        raceStarted     = { enabled = true, url = '', color = 3447003  },
        raceFinished    = { enabled = true, url = '', color = 15844367 },
        raceReset       = { enabled = true, url = '', color = 9807270  },
        settingsChanged = { enabled = true, url = '', color = 9936031  },
        dbError         = { enabled = true, url = '', color = 10038562 },
    }
}
```

1. In Discord: **Channel Settings → Integrations → Webhooks → New Webhook**, copy its URL.
2. Paste it into `Config.Webhook.url` and set `enabled = true`.
3. Optionally give any individual event its own `url` (e.g. route `dbError` to a private staff-only channel, keep `raceFinished` in a public results channel) — leave an event's `url` blank to fall back to the shared `Config.Webhook.url`.
4. Disable any event you don't want logged by setting its `enabled = false`.

Once configured, confirm it works with the built-in test command (see [Commands](#commands) below) before relying on it.

**What gets logged:** track created/deleted (who, track name/ID, point count), lap count/max marker changes (who, old → new value), race started (who, rider count, laps, checkpoints), race finished (full standings, reward, laps), manual race reset (who), and database failures (table creation / track save errors). Webhook embeds are always in English regardless of `Config.Locale`, since they're aimed at server admins in Discord rather than players in-game.

### Other tunables (server-side)

These live at the top of **`server/server.lua`** rather than `shared/config.lua`, since they're server-authoritative and not meant to be player-visible:

| Variable | Default | Purpose |
|---|---|---|
| `rewardAmount` | `100` | Cash paid to the race winner (1st place) via `Player.Functions.AddMoney('cash', ...)`. |
| `maxMarkers` | `15` | Default max checkpoints allowed per track (2–30). Adjustable live in-menu by an admin. |
| `loadLatestTrackOnRestart` | `false` | If `true`, the most recently saved track auto-loads as the active track on resource start/restart. Off by default so a restart doesn't silently start a race track without a menu choice. |
| `RACE_ADMIN_PERMISSION` | `'admin'` | RSGCore permission required to delete tracks, load a track, change lap count/max markers, or reset a race. Set to `''` to let any player perform these actions (not recommended on a live server). |
| `MIN_SECONDS_PER_LAP` | `8` | Minimum plausible seconds per lap, used to reject implausibly fast finish claims (anti-cheat floor). Tune down only if your shortest real track can genuinely be run faster than this. |

---

## Usage

### For players

1. **Open the menu** — press `J` while standing near a currently-loaded track's start marker, or run `/racerace` (alias `/race`) from anywhere.
2. **Join a race** — from the menu, select *Join Race* once a track is loaded and no race is currently running.
3. **Race** — once an admin starts the race, a 10-second countdown plays, then GPS routes you to each checkpoint in order. Ride through each marker to register it; the last checkpoint is the finish line. Complete the configured number of laps to finish.
4. **View results** — the *View Winners* option (and an automatic popup for anyone still watching when the race ends) shows the podium and full finisher list. Reward money is paid automatically to whoever finishes 1st.

### For track builders / admins

1. Open the menu (`/racerace`) and select **Create Track**.
2. In the world: press **J** once to set the **start** point, press **J** again for each additional checkpoint, then press **G** at your current position to set the **finish** and complete the route (minimum 2 points, start + finish).
3. Name the track when prompted — it's saved to the database and becomes the active track immediately.
4. From the menu you can also:
   - **Load Saved Track** — swap in any previously saved track (requires the configured admin permission).
   - **Delete Saved Track** — permanently remove a saved track (requires admin permission).
   - **Set Laps** (1–5) and **Set Max Markers** (2–30) — configure the current/next race (requires admin permission).
   - **Reset Track** — clear the active track and any in-progress race state (requires admin permission).

### Commands

| Command | Description |
|---|---|
| `/racerace`, `/race` | Open the race menu. |
| `/racewebhooktest` | Server console or in-game admin command. Posts a test embed to your configured Discord webhook so you can confirm the URL and formatting work before going live. |

---

## Permissions

Track/race administration (delete track, load track, set laps, set max markers, reset race) requires the RSGCore permission named in `RACE_ADMIN_PERMISSION` (`'admin'` by default) — grant it through however your server manages RSGCore permissions/ACE. Joining a race, creating a new track, and viewing results are open to all players by design.

---

## Localization

All player-facing text lives in `locales/<lang>.json` and is loaded according to `Config.Locale`. Shipped languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro` (plus `it`, `ru`). Every string supports `%s` placeholders for dynamic values (player names, counts, etc.) via Lua's `string.format` on the server/client, and the NUI mirrors the same key/value pairs through a `T(key, fallback, ...args)` helper in `html/script.js`.

---

## Troubleshooting

- **Menu doesn't open / `/racerace` does nothing** — confirm `rsg-core`, `ox_lib`, and `oxmysql` all started successfully before `rsg-track` in your `server.cfg`.
- **"Failed to save track!" toast** — check your server console for a `[rsg-track] Failed to save track: ...` line; this usually means `oxmysql` can't reach the database, or the track name exceeds 50 characters (names are trimmed and truncated automatically, but very unusual input can still fail).
- **Discord messages not arriving** — confirm `Config.Webhook.enabled = true`, the URL is a valid `https://discord.com/api/webhooks/...` link, and run `/racewebhooktest` to isolate the issue from your race flow.
- **"Cannot change markers/laps/delete/load/reset" with no toast** — these actions silently no-op for players without the `RACE_ADMIN_PERMISSION` permission; this is expected, not a bug.
