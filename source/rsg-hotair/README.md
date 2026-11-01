# rsg-hotair

Hireable hot air balloons for RedM servers running the **RSG-Core** framework. Players hire a balloon at a dock, pilot it (or ride along as a passenger), and store it again when they're done. Includes its own weight-limited storage stash per balloon, full ox_target integration, an ox_lib-driven multi-language NUI, and a live on-screen flight control HUD.

## Features

- **Hire / store flow** — players hire a balloon from a dock NPC for a flat, configurable cash fee. No timers, no cooldowns, no fuel to manage. Storing the balloon returns it to the dock system and wipes its storage stash.
- **Pilot + passengers** — one pilot seat plus up to 4 basket seats. Passengers target the balloon to board and can disembark at any time; the pilot can force everyone off before storing.
- **Custom flight model** — momentum-based drift controls (not the default RDR3 aircraft handling): burner to climb, WASD to drift, an altitude lock toggle, a brake, and a configurable altitude ceiling.
- **Live on-screen controls HUD** — a persistent panel on the left of the screen listing every flight control, with each key badge lighting up green in real time while it's actually held down.
- **Per-player balloon storage** — each player gets their own weight/slot-limited stash (via `rsg-inventory`) tied to their currently-hired balloon, accessible by targeting it. The stash is wiped whenever the balloon is stored, so it's not a permanent personal locker.
- **ox_target integration everywhere** — hire, pilot, open storage, store, board, and disembark are all ox_target options on the dock NPCs and the balloon itself; no `uiprompt` or other prompt dependency.
- **Multi-language ox_lib NUI** — every player-facing string (server callbacks, client notifications, ox_target labels, and the full HTML/JS panel) is driven by `ox_lib` locale files. Ships with 10 languages out of the box: English, German, Greek, Spanish, French, Japanese, Dutch, Polish, Brazilian Portuguese, and Romanian.
- **Exploit-hardened server logic** — server-side ownership validation on balloon registration (a client can't claim someone else's networked entity), distance/speed checks before boarding or storing, and no client-trusted state for money or ownership.
- **Multiple docks** — add as many hire docks as you like in the config; each spawns its own NPC, blip, and target automatically.

## Dependencies

- [`rsg-core`](https://github.com/Rexshack-RedM/rsg-core)
- [`ox_lib`](https://github.com/overextended/ox_lib)
- [`ox_target`](https://github.com/overextended/ox_target)
- [`rsg-inventory`](https://github.com/Rexshack-RedM/rsg-inventory)

All four must be started **before** `rsg-hotair` in your `server.cfg`.

## Installation

1. Download/copy the `rsg-hotair` folder into your server's `resources` directory (in whatever category folder you use, e.g. `resources/[rsg]/rsg-hotair`).
2. Make sure the dependencies above are installed and already ensured/started.
3. Add it to your `server.cfg`, after the dependencies:
   ```cfg
   ensure rsg-core
   ensure ox_lib
   ensure ox_target
   ensure rsg-inventory
   ensure rsg-hotair
   ```
4. Restart your server (or the resource, if the dependencies are already running).

Whenever you edit any file in this resource, you must copy the changed files into your live `resources` folder and restart the resource — editing a working copy elsewhere has no effect on the running server until it's deployed there.

## Configuration

All settings live in `config.lua`.

| Setting | Description |
|---|---|
| `Config.Model` | The balloon vehicle model/hash to spawn. |
| `Config.HirePrice` | Flat cash cost to hire a balloon. |
| `Config.PassengerOffsets` | Table of 4 `vector3` offsets (relative to the balloon) where passengers attach — one per basket seat. |
| `Config.CruiseSpeed` | Drift added per tick while a direction key is held (normal speed). |
| `Config.BoostSpeed` | Drift added per tick while the boost/traversal control is held. |
| `Config.MaxAltitudeAGL` | Maximum height (meters above ground level) the balloon can climb to. |
| `Config.StoreMaxSpeed` | Balloon must be moving slower than this (m/s) to be stored. |
| `Config.StoreMaxHeightAGL` | Balloon must be lower than this (meters AGL) to be stored. |
| `Config.BoardMaxSpeed` | Same speed limit, but for boarding/piloting instead of storing. |
| `Config.BoardMaxHeightAGL` | Same height limit, but for boarding/piloting instead of storing. |
| `Config.TargetDistance` | ox_target interaction distance for the balloon (it's a large entity, so this is larger than a typical ped/object target). |
| `Config.StorageMaxWeight` | Max weight (in `rsg-inventory` units) of each player's balloon storage stash. |
| `Config.StorageMaxSlots` | Max slot count of each player's balloon storage stash. |
| `Config.Docks` | A list of hire docks. Add as many entries as you like — each one automatically gets its own NPC ped, map blip, and ox_target hire option. Each entry needs: `label` (display name), `npcModel`, `npcCoords` (`vector4`, includes heading), `spawnCoords`/`spawnHeading` (where the hired balloon spawns), and a `blip` table (`sprite`, `scale`, `name`). |

### Adding another dock

Copy an existing entry in `Config.Docks` and change the label, ped model, coordinates, and blip:

```lua
Config.Docks = {
    {
        label = 'Valentine Meadow',
        npcModel = 'A_M_M_RANCHER_01',
        npcCoords = vector4(-151.93, 669.44, 116.37, 187.32),
        spawnCoords = vector3(-148.78, 664.59, 115.26),
        spawnHeading = 45.0,
        blip = { sprite = -1258576797, scale = 0.2, name = 'Balloon Hire' },
    },
    {
        label = 'Blackwater Docks',
        npcModel = 'A_M_M_RANCHER_01',
        npcCoords = vector4(-800.0, -1400.0, 43.0, 90.0),
        spawnCoords = vector3(-795.0, -1395.0, 43.0),
        spawnHeading = 90.0,
        blip = { sprite = -1258576797, scale = 0.2, name = 'Balloon Hire' },
    },
}
```

### Changing the language

Player-facing text is pulled from `locales/*.json` via `ox_lib`. The resource ships English (`en`), German (`de`), Greek (`el`), Spanish (`es`), French (`fr`), Japanese (`ja`), Dutch (`nl`), Polish (`pl`), Brazilian Portuguese (`pt-br`), and Romanian (`ro`).

The active language is controlled by `ox_lib`'s standard convar, which applies server-wide to every `ox_lib`-based resource — it isn't set per-resource. Add this to your `server.cfg` (before `ensure ox_lib`) and set it to whichever language code you want:

```cfg
setr ox:locale "de"
```

If you want to add or edit a language, create/edit the matching `locales/<code>.json` file, keeping the same nested keys as `locales/en.json`.

## Usage

### For players

1. Head to a balloon dock (shown on the map with a balloon blip) and target the dock NPC.
2. Choose **Hire Balloon** to pay the hire fee and spawn a balloon at that dock. Only one balloon may be hired per player at a time.
3. Target the balloon and choose **Pilot Balloon** to fly it, or **Board Balloon** to ride as a passenger (up to 4 passengers, basket seats).
4. While piloting, use the flight controls (see below) — a control panel appears on the left side of the screen showing every key, and each key lights up green while held.
5. To access your balloon's storage, target it and choose **Open Storage**.
6. To put the balloon away, land it, bring it to a complete stop, and either target it and choose **Store Balloon** or sound the horn. Storing wipes the storage stash, so retrieve anything you want to keep first.
7. Passengers can target the balloon at any time to **Disembark**.

### Flight controls

| Key | Action |
|---|---|
| **Shift** | Burner — ascend |
| **W** | Drift forward |
| **A** | Drift left |
| **D** | Drift right |
| **S** | Drift backward |
| **Space** | Toggle altitude lock (holds current height) |
| **R** | Brake |
| **Horn** | Store the balloon (must be landed and stopped) |

Exiting the vehicle normally is locked while airborne — use the pilot/passenger disembark options instead, or store/land the balloon first.

### For server owners / developers

- All server-side logic lives in `server/server.lua`: hire/store validation, ownership registration, seat management, and the storage stash (via `rsg-inventory`).
- All client-side logic lives in `client/client.lua`: flight physics, ox_target registration, NUI messaging, and the flight-control HUD.
- The NUI panel is a single self-contained page at `html/index.html`; it receives a `setLocale` message from the client with every translated string, so no text is hardcoded into the page itself.
- Debug/console `print()` lines in `server.lua` are intentionally left in English — they're server-console diagnostics, not player-facing text.
