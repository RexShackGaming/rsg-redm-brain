# rsg-loading

A clean, configurable loading screen for RedM servers running the RSG Framework.

Full technical reference: [DOCS.md](DOCS.md)

![RedM](https://img.shields.io/badge/RedM-rdr3-red) ![Lua](https://img.shields.io/badge/Lua-5.4-blue) ![Version](https://img.shields.io/badge/version-3.0.3-green)

## Features

- Custom background image with adjustable dim
- Branded title and subtitle
- Live progress bar driven by RedM's native `loadFraction` events
- Rotating tips with fade transition and configurable interval
- Status text and in-game clock
- Simulated progress fallback, so it previews correctly in a normal browser
- Configurable safety-net auto-close (default 120 seconds) if the game never signals completion
- Holiday themes for Easter, Halloween, Christmas and New Year with their own colours, backgrounds, tips and particle effects (snow, bats, petals, fireworks)
- Automatic theme switching by date, including Easter's moving date
- Winter, spring, summer and autumn themes used the rest of the year when no holiday is active
- Text and layout configured through JSON, seasonal themes through `config.lua`
- Live server name and player count at the top of the screen
- Server news / rules panel (from locales)
- Background slideshow: give a list of images for the normal look or any theme
- Optional looping background music (SPACE toggles it, fades out on close)
- Discord link in the footer
- Particle density setting for low-end PCs (also reduced automatically when the OS has "reduce motion" on)
- Closes automatically when the player loads in (`RSGCore:Client:OnPlayerLoaded`)
- Roboto font bundled locally, so it works offline and with no Google Fonts

## Installation

1. Place the `rsg-loading` folder in your server's `resources` directory.
2. Add it to your `server.cfg`:
   ```cfg
   ensure rsg-loading
   ```
3. Restart the server.

> Only one resource can provide a `loadscreen`. Remove or stop any other loading screen resource.

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core) (server console locales only; ox_lib is no longer needed)

## Configuration

Visual settings live in `html/config.json`:

```json
{
  "background_image": "images/background.jpeg",
  "background_dim": 0.45,
  "tip_interval_seconds": 5,
  "auto_close_seconds": 120,
  "slideshow_seconds": 12,
  "music": "",
  "music_volume": 0.25,
  "discord": ""
}
```

| Key | Description |
| --- | --- |
| `background_image` | Path relative to `html/` or a full URL, or a list of them for a slideshow, e.g. `["images/a.jpeg", "images/b.jpeg"]`. Falls back to a dark gradient if missing. |
| `background_dim` | Darkness overlay on the background, `0` (none) to `1` (black). |
| `tip_interval_seconds` | Seconds between tip changes. |
| `auto_close_seconds` | Close the screen after this many seconds if the game never signals completion. `0` disables it (recommended if your spawn/character script calls `ShutdownLoadingScreenNui`). Default `120`. |
| `slideshow_seconds` | Seconds per image when `background_image` (or a theme's `background`) is a list. `0` = no rotation. |
| `music` | Music file inside `html/` (e.g. `music/theme.ogg`; put files in `html/music/`) or a URL. Blank = no music. |
| `music_volume` | `0` to `1`. |
| `discord` | Text shown in the footer, e.g. `discord.gg/yourserver`. Blank hides it. |

## Languages

All text lives in the locale files in `locales/`. Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

- **Loading screen language:** set `Config.Locale` in `config.lua` (the loading screen runs before any Lua, so it can't read the `rsg:locale` convar).
- **Server console language:** follows rsg-core's `setr rsg:locale "de"` convar (falls back to `ox:locale`).

Any key missing from a language falls back to `en.json`.

| Key | Description |
| --- | --- |
| `ui_brand_title` | Main heading. |
| `ui_brand_subtitle` | Line under the heading. |
| `ui_status_loading` / `ui_status_ready` | Status text while loading / when done. |
| `ui_footer_resource_name` | Text shown in the footer. |
| `ui_tip_1`, `ui_tip_2` ... | Tips rotated during loading. Add more by adding the next number. |
| `ui_news_title`, `ui_news_1`, `ui_news_2` ... | News / rules panel. Remove all `ui_news_N` keys to hide the panel. |
| `ui_players` | Player count text, `%s / %s players`. |
| `ui_music_hint` | Hint shown when music is enabled. |
| `theme_<name>_subtitle` | Subtitle for a holiday or season theme (e.g. `theme_halloween_subtitle`). |
| `theme_<name>_tip_1` ... | Tips for a holiday or season theme. |
| `sv_*` | Server version checker messages. |

To add a language, copy `en.json` to `<code>.json` and translate the values.

### Changing the background

Drop your image into `html/images/` and update `background_image` in `config.json`. Any file in `html/images/` is included automatically by the manifest. Keep images reasonably sized (a compressed 1920×1080 JPEG is ideal) so the screen appears quickly.

## Seasonal themes

Seasonal themes are configured in `config.lua` in the resource root. The loading screen reads this file directly, because it shows before any Lua scripts run. Keep it to plain values (strings, numbers, booleans and tables); functions and logic are not supported.

```lua
Config.Theme     = 'auto'   -- 'auto', 'default', 'easter', 'halloween', 'christmas' or 'newyear'
Config.Particles = true     -- snow / bats / petals / leaves / fireflies / fireworks
Config.MergeTips = true     -- true = add seasonal tips to your normal tips, false = replace them
Config.ParticleDensity = 1.0       -- 0.1 - 1.0, lower for low-end PCs
Config.CloseOnPlayerLoaded = true  -- close when RSGCore:Client:OnPlayerLoaded fires
Config.ServerInfo = true           -- show server name + player count
```

| `Config.Theme` | Behaviour |
| --- | --- |
| `'auto'` | Uses the holiday theme whose date window contains today; if none, the matching season theme (when `Config.UseSeasons = true`); otherwise the normal look. |
| `'default'` | Never uses a seasonal theme. |
| `'easter'` / `'halloween'` / `'christmas'` / `'newyear'` | Forces that holiday theme all year. Useful for testing. |
| `'winter'` / `'spring'` / `'summer'` / `'autumn'` | Forces that season theme all year. |

### Default date windows

| Theme | Window | Background |
| --- | --- | --- |
| Easter | 7 days before Easter Sunday to 1 day after (calculated each year) | `images/easter.jpeg` |
| Halloween | `10-15` to `11-01` | `images/halloween.jpeg` |
| Christmas | `12-01` to `12-30` | `images/christmas.jpeg` |
| New Year | `12-31` to `01-02` | `images/newyear.jpeg` |

Dates use the player's local clock in `MM-DD` format. A window can wrap the new year, e.g. `start = '12-01', finish = '01-06'`.

### Season themes

When no holiday is active, `Config.Seasons` is checked. Holidays always take priority (so Christmas wins over winter in December). Set `Config.UseSeasons = false` to show your normal look instead.

| Season | Window | Particles | Background |
| --- | --- | --- | --- |
| Winter | `12-01` to `02-28` (leap day included) | snow | `images/winter.jpeg` |
| Spring | `03-01` to `05-31` | petals | `images/spring.jpeg` |
| Summer | `06-01` to `08-31` | fireflies | `images/summer.jpeg` |
| Autumn | `09-01` to `11-30` | leaves | `images/autumn.jpeg` |

### Theme options

Holiday entries in `Config.Themes` and season entries in `Config.Seasons` support the same options:

| Key | Description |
| --- | --- |
| `enabled` | Set `false` to skip this theme in `auto` mode. |
| `start` / `finish` | Date window in `MM-DD`. |
| `easterDaysBefore` / `easterDaysAfter` | Easter only: days either side of Easter Sunday. |
| `seal` / `divider` | Symbols shown in the round seal and the divider. |
| `particles` | `'snow'`, `'bats'`, `'petals'`, `'leaves'`, `'fireflies'`, `'fireworks'`, or `''` for none. |
| `background` | Image path inside `html/` or a URL. Blank keeps the normal background. |
| `backgroundDim` | Darkness overlay for this theme, `0` to `1`. |
| `colors` | `accent`, `accent2` (progress bar gradient and highlights), `border`, `panel`, `panel2`, `text`, `muted`. |

Theme subtitles and tips are set in `locales/<lang>.json` (see Languages).

To use your own seasonal artwork, drop the image into `html/images/` and change that theme's `background` path.

## How it closes

The manifest sets `loadscreen_manual_shutdown 'yes'`. The screen closes when:

- the player loads in (`RSGCore:Client:OnPlayerLoaded`, when `Config.CloseOnPlayerLoaded = true`),
- it receives an `endLoading` NUI message (`eventName` or `type`), or
- the `auto_close_seconds` safety timeout fires (default 120s, `0` to disable).

It then calls `shutdownLoadingScreenNui` itself. Your character script can also close it at any time with `ShutdownLoadingScreenNui()`.

## Custom status messages

Any NUI message containing a `statusText` string updates the status line, e.g. from a client script:

```lua
SendLoadingScreenMessage(json.encode({ statusText = 'Loading world…' }))
```

## Previewing

Serve the resource folder with a local web server so `fetch` can read the config files (e.g. `npx serve .` from the resource root), then open `/html/index.html`. Progress is simulated. Set `Config.Theme` to a season to preview it.

## File structure

```
rsg-loading/
├── fxmanifest.lua
├── README.md / DOCS.md
├── config.lua          # language + seasonal themes
├── locales/            # locale files (all text)
│   ├── en.json
│   └── de.json, el.json, es.json, fr.json, ja.json, nl.json, pl.json, pt-br.json, ro.json
├── client/
│   └── client.lua      # closes on player loaded
├── server/
│   ├── server.lua      # live server info handover
│   └── versionchecker.lua
└── html/
    ├── index.html
    ├── style.css
    ├── script.js
    ├── config.json
    ├── fonts.css + fonts/   # bundled Roboto
    ├── music/               # optional music files
    └── images/
        ├── background.jpeg
        ├── easter.jpeg
        ├── halloween.jpeg
        ├── christmas.jpeg
        ├── newyear.jpeg
        ├── winter.jpeg
        ├── spring.jpeg
        ├── summer.jpeg
        └── autumn.jpeg
```

## Credits

Created by **RexShack** for the RSG Framework.

Support: https://buymeacoffee.com/rexshack
