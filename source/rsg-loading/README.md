# rsg-loading

A clean, configurable loading screen for RedM servers running the RSG Framework.

![RedM](https://img.shields.io/badge/RedM-rdr3-red) ![Lua](https://img.shields.io/badge/Lua-5.4-blue) ![Version](https://img.shields.io/badge/version-2.0.0-green)

## Features

- Custom background image with adjustable dim
- Branded title and subtitle
- Live progress bar driven by RedM's native `loadFraction` events
- Rotating tips with fade transition and configurable interval
- Status text and in-game clock
- Simulated progress fallback, so it previews correctly in a normal browser
- Safety net auto-close after 45 seconds if the game never signals completion
- Seasonal themes for Easter, Halloween and Christmas with their own colours, backgrounds, tips and particle effects (snow, bats, petals)
- Automatic theme switching by date, including Easter's moving date
- Winter, spring, summer and autumn themes used the rest of the year when no holiday is active
- Text and layout configured through JSON, seasonal themes through `config.lua`

## Installation

1. Place the `rsg-loading` folder in your server's `resources` directory.
2. Add it to your `server.cfg`:
   ```cfg
   ensure rsg-loading
   ```
3. Restart the server.

> Only one resource can provide a `loadscreen`. Remove or stop any other loading screen resource.

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib) (used for locales)

## Configuration

Visual settings live in `html/config.json`:

```json
{
  "background_image": "images/background.jpeg",
  "background_dim": 0.45,
  "tip_interval_seconds": 5
}
```

| Key | Description |
| --- | --- |
| `background_image` | Path relative to `html/`, or a full URL. Falls back to a dark gradient if missing. |
| `background_dim` | Darkness overlay on the background, `0` (none) to `1` (black). |
| `tip_interval_seconds` | Seconds between tip changes. |

## Languages

All text lives in the ox_lib locale files in `locales/`. Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

- **Loading screen language:** set `Config.Locale` in `config.lua` (the loading screen runs before ox_lib, so it can't read the `ox:locale` convar).
- **Server console language:** follows ox_lib's `setr ox:locale "de"` convar as usual.

Any key missing from a language falls back to `en.json`.

| Key | Description |
| --- | --- |
| `ui_brand_title` | Main heading. |
| `ui_brand_subtitle` | Line under the heading. |
| `ui_status_loading` / `ui_status_ready` | Status text while loading / when done. |
| `ui_footer_resource_name` | Text shown in the footer. |
| `ui_tip_1`, `ui_tip_2` ... | Tips rotated during loading. Add more by adding the next number. |
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
Config.Particles = true     -- falling snow / bats / petals
Config.MergeTips = true     -- true = add seasonal tips to your normal tips, false = replace them
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
| New Year | `12-31` to `01-02` | normal background |

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

- it receives an `endLoading` NUI message (`eventName` or `type`), or
- the 45-second safety timeout fires.

It then calls `shutdownLoadingScreenNui` itself. If you'd rather close it from Lua once the player has spawned or picked a character, add a client script such as:

```lua
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    ShutdownLoadingScreenNui()
end)
```

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
├── config.lua          # language + seasonal themes
├── locales/            # ox_lib locale files (all text)
│   ├── en.json
│   └── de.json, el.json, es.json, fr.json, ja.json, nl.json, pl.json, pt-br.json, ro.json
├── server/
│   └── versionchecker.lua
└── html/
    ├── index.html
    ├── style.css
    ├── script.js
    ├── config.json
    └── images/
        ├── background.jpeg
        ├── easter.jpeg
        ├── halloween.jpeg
        ├── christmas.jpeg
        ├── winter.jpeg
        ├── spring.jpeg
        ├── summer.jpeg
        └── autumn.jpeg
```

## Credits

Created by **RexShack** for the RSG Framework.
