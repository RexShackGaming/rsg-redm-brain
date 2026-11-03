# rsg-loading — Technical Docs

## Contents
1. Architecture
2. Config sources
3. Theme selection
4. NUI messages
5. Closing the loading screen
6. Locales
7. Security
8. Troubleshooting

## 1. Architecture

| File | Role |
| --- | --- |
| `fxmanifest.lua` | Declares `loadscreen 'html/index.html'` with `loadscreen_manual_shutdown 'yes'`. Loads `@rsg-core/shared/locale.lua` for the server version checker. |
| `config.lua` | Language and seasonal themes. **Never executed as Lua by the screen** — `html/script.js` fetches it and parses it with a small Lua-literal parser. Plain values only. |
| `html/config.json` | Background, dim, tip interval, auto-close timeout. |
| `html/script.js` | Loads config + locale, picks a theme, drives progress, tips, particles and closing. |
| `html/style.css` | House style (Roboto, monochrome panel); theme colours are CSS variables overridden at runtime. |
| `locales/*.json` | All text; shared by the screen (`ui_*`, `theme_*`) and server console (`sv_*`). |
| `client/client.lua` | On `RSGCore:Client:OnPlayerLoaded` (if `Config.CloseOnPlayerLoaded`) sends `endLoading` and calls `ShutdownLoadingScreenNui()`. |
| `server/server.lua` | On `playerConnecting` (if `Config.ServerInfo`) calls `deferrals.handover({ rsgLoading = { players, maxPlayers, serverName } })`. The screen reads it from `window.nuiHandoverData`. Server name = `sv_projectName`, else `sv_hostname`, with `^n` colour codes removed. |
| `html/fonts.css`, `html/fonts/` | Bundled Roboto (latin, latin-ext, greek; 400/500/700 + 400 italic). Japanese falls back to system fonts. |
| `server/versionchecker.lua` | Compares `version` in fxmanifest with `rsg-versioncheckers/main/rsg-loading/version.txt`. |

No database, no exports, no callbacks. `config.lua` is also loaded as a shared script so client/server Lua can read it.

## 2. Config sources

- `config.lua` parser supports: `Config = {}`, `Config.A.B = value`, strings (`'`, `"`, `[[ ]]`), numbers, booleans, `nil`, nested tables, `--` and `--[[ ]]` comments. Functions, variables and expressions are ignored/return `null`.
- `html/config.json` keys: `background_image` (string or list), `background_dim` (0–1), `tip_interval_seconds`, `auto_close_seconds` (0 = off), `slideshow_seconds` (0 = no rotation), `music`, `music_volume` (0–1), `discord`.
- `Config.ParticleDensity` scales particle counts and fireworks frequency (0.1–1). `prefers-reduced-motion` caps it at 0.3.
- A theme's `background` / `backgroundDim` override the config.json values while it is active.

## 3. Theme selection (`pickTheme`)

1. `Config.Theme = 'default'` or `'none'` → no theme.
2. Any other non-`auto` value → that key from `Config.Themes` or `Config.Seasons`.
3. `auto` → first enabled entry of `Config.Themes` whose window contains today (player's local clock), then `Config.Seasons` if `Config.UseSeasons ~= false`.

Windows are `MM-DD`, inclusive, may wrap the year. Feb 29 counts as Feb 28 when a window finishes on `02-28`. Easter (no `start`) uses the Anonymous Gregorian algorithm ± `easterDaysBefore` / `easterDaysAfter`.

Holiday order matters only if windows overlap: Lua table key order is preserved as written.

## 4. NUI messages

| Message | Effect |
| --- | --- |
| `{ loadFraction = 0..1 }` (native) | Sets real progress; stops simulated progress. |
| `{ eventName = 'endLoading' }` or `{ type = 'endLoading' }` | Finishes and closes the screen. |
| `{ statusText = '...' }` | Replaces the status line. |

```lua
SendLoadingScreenMessage(json.encode({ statusText = 'Loading world…' }))
SendLoadingScreenMessage(json.encode({ type = 'endLoading' }))
```

## 5. Closing

`finishLoading()` runs once: stops all timers, particles and the slideshow, fades out music, shows `ui_status_ready`, then calls `invokeNative('shutdownLoadingScreenNui')` after 400 ms. Triggered by `endLoading` (sent by `client/client.lua` on player loaded) or the `auto_close_seconds` timeout. A character-selection script may call `ShutdownLoadingScreenNui()` earlier; calling it twice is harmless.

## 6. Locales

Screen language = `Config.Locale`; missing keys fall back to `en.json`. Tips are collected from `ui_tip_1`, `ui_tip_2`… stopping at the first gap. Theme text: `theme_<name>_subtitle`, `theme_<name>_tip_N`. News panel: `ui_news_title` + `ui_news_N` (hidden when there are none). `ui_players` takes two `%s` (players, max). `ui_music_hint` shows only when music is set. All 10 languages ship with identical keys: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

## 7. Security

The loading screen handles no money, items or player data. All text is inserted with `textContent` (no HTML injection). Background URLs come only from server-owned config files.

## 8. Troubleshooting

| Problem | Fix |
| --- | --- |
| Screen never appears | Only one resource may declare `loadscreen`; remove others. |
| Closes before character select | Raise or disable `auto_close_seconds`; close it from Lua instead. |
| Never closes | Something must send `endLoading` or call `ShutdownLoadingScreenNui`; keep `auto_close_seconds` > 0. |
| Theme not applied | Check `Config.Theme`, `enabled`, date format `MM-DD`, and that `config.lua` has no functions/expressions. |
| Text blank | `Config.Locale` must match a file in `locales/`. |
| No player count | `Config.ServerInfo = true`; the handover only exists when joining a real server, not in a browser preview. |
| Music silent | Check the `music` path (inside `html/`), `music_volume` > 0, and that the file is `.ogg`/`.mp3`. SPACE toggles it; key input may not reach the screen on every client build. |
| Slow first paint | Compress backgrounds (~200–400 KB JPEG at 1920×1080). |

Support: https://buymeacoffee.com/rexshack
