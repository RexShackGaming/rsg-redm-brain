# RedM Brain

A knowledge base that AI assistants (Claude, ChatGPT, Cursor, Copilot, etc.) load **before** writing RedM / RSG Framework scripts. It gives the AI the facts it would otherwise guess: what's installed on the server, real RSG exports and events, native signatures, game hashes, the house coding rules and the NUI style.

The result: scripts that use the right item names, call real exports, keep money/items server-side, and look like the rest of your server.

> **AI entry point:** [`CLAUDE.md`](CLAUDE.md). Claude Code reads it automatically when this folder is opened as a project. For any other tool, attach or paste it first.

---

## Contents

1. [What's in the brain](#whats-in-the-brain)
2. [Quick start](#quick-start)
3. [Using it with different AI tools](#using-it-with-different-ai-tools)
4. [Creating a new RSG script, step by step](#creating-a-new-rsg-script-step-by-step)
5. [Writing good prompts](#writing-good-prompts)
6. [Looking things up](#looking-things-up)
7. [The template resource](#the-template-resource)
8. [Core rules every script must follow](#core-rules-every-script-must-follow)
9. [Auditing and converting existing scripts](#auditing-and-converting-existing-scripts)
10. [Keeping the brain up to date](#keeping-the-brain-up-to-date)
11. [Troubleshooting](#troubleshooting)
    - see also [Windows setup](#windows-setup)
12. [Credits](#credits)

---

## What's in the brain

| Folder / file | What it holds | When to use it |
|---|---|---|
| `CLAUDE.md` | Golden rules, folder map and workflow for the AI | Always loaded first |
| `server/environment.md` | **Source of truth**: installed resources, removed ones, server item names | Every script |
| `conventions/coding-rules.md` | Lua style, structure, config/locale layout | Every script |
| `conventions/security.md` | Server-authoritative rules: validation, distance, cooldowns, permissions | Anything touching money, items or jobs |
| `conventions/notify-locales.md` | ox_lib notifications and `lib.locale()` usage | Any player-facing text |
| `framework/rsg-core.md`, `rsg-inventory.md`, `rsg-banking.md` | Hand-written guides to the core APIs | Player data, items, money |
| `framework/resources/` | **Generated** API reference for ~70 RSG resources: exports, net events, callbacks, usable items, commands, DB tables | Before calling another RSG resource |
| `framework/other-exports.md` | ox_lib / ox_target / other third-party exports | Menus, targets, zones |
| `source/` | Code-only mirror of the Rexshack-RedM repos | Real examples to copy patterns from |
| `natives/` | Guides: ped AI & combat, game events, prompts / blips / entities | Native-heavy client code |
| `natives/db/` | Full natives database (~8k natives, hash + signature + notes) by namespace, with `INDEX.tsv` | Checking a native's exact name/params |
| `data/rdr3_discoveries/` | Local copy of femga/rdr3_discoveries: peds, props, anims, scenarios, weapons, PTFX, controls, doors, interiors, AI flags, clothing | Any model, hash, anim or flag |
| `data/rdr3_discoveries/MAP.md` | Index of the folder above with sample line formats | Start here for data lookups |
| `data/rdr3-decompiled-scripts.md` | Guide to the decompiled RDR2 singleplayer scripts (optional local clone in `data/rdr3-decompiled/`) | Seeing how Rockstar calls natives; recreating RDR2 features |
| `data/redm-info.md`, `data/redm-forge.md` | Online lookup sites and what they cover | Cross-checking / 3D previews / coords |
| `data/README.md` | Fallback lookup index | Things rdr3_discoveries lacks |
| `patterns/` | Tested snippets: secure reward event, NUI bridge, entity cleanup, ox_target | Building blocks |
| `templates/rsg-template/` | Skeleton resource (client/server/shared/html/locales/sql) | Every new script |
| `ui/design-standard.md`, `ui/theme.css` | NUI house style and drop-in CSS | Any NUI |
| `audit/` | Audit checklist and report procedure | Reviewing or converting scripts |
| `tools/` | Refresh scripts and generators | Updating the brain |
| `vorp/` | VORP Core reference (not installed): API guide, RSG ⇄ VORP conversion map, official docs, generated API for ~40 VORPCORE resources, code mirror | Porting VORP scripts to RSG, or framework-bridge scripts |

**Precedence when sources disagree:** `server/environment.md` > `source/` (real code) > `framework/` > everything else.

---

## Quick start

1. Clone the repo:
   ```bash
   git clone https://github.com/RexShackGaming/rsg-redm-brain.git
   ```
2. (Optional but recommended) refresh the RSG source mirror and API reference:
   ```bash
   cd rsg-redm-brain/tools
   ./refresh.sh          # Linux / macOS / Git Bash
   ```
   On Windows, see [Windows setup](#windows-setup) below.
3. Check `server/environment.md` matches **your** server (resources, item names). Edit it if not.
4. Open the folder in your AI tool (see below) and ask for a script.

### Windows setup

Requirements: [Git for Windows](https://git-scm.com/download/win) and [Python 3](https://www.python.org/downloads/) installed and on your PATH (tick *"Add python.exe to PATH"* in the installer). Check with `git --version` and `python --version`.

**Changing to the brain folder.** The command depends on your terminal. In Command Prompt, plain `cd` won't switch drives.

| Terminal | Command |
|---|---|
| Command Prompt (cmd) | `cd /d D:\GitHub\rex-scripts\rsg-redm-brain` |
| PowerShell | `cd "D:\GitHub\rex-scripts\rsg-redm-brain"` |
| Git Bash | `cd /d/GitHub/rex-scripts/rsg-redm-brain` |

Replace the path with wherever you cloned the brain. If you get *"path not found"*, check the spelling with `dir D:\GitHub\rex-scripts`.

**Running the refresh.** The script lives in `tools\`, and Command Prompt can't run `.ps1` files directly. That's what causes the error *"'.\refresh.ps1' is not recognized as an internal or external command"*.

From **PowerShell** (recommended):
```powershell
cd "D:\GitHub\rex-scripts\rsg-redm-brain\tools"
.\refresh.ps1
```

From **Command Prompt**:
```cmd
cd /d D:\GitHub\rex-scripts\rsg-redm-brain\tools
powershell -ExecutionPolicy Bypass -File .\refresh.ps1
```

From **Git Bash**:
```bash
cd /d/GitHub/rex-scripts/rsg-redm-brain/tools
./refresh.sh
```

If PowerShell says *"running scripts is disabled on this system"*, allow local scripts for your account once:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**Searching on Windows.** The `rg` examples in [Looking things up](#looking-things-up) work in any terminal once ripgrep is installed (`winget install BurntSushi.ripgrep.MSVC`). Without it, use PowerShell:
```powershell
Select-String -Path natives\db\INDEX.tsv -Pattern "TASK_START_SCENARIO"
Get-ChildItem data\rdr3_discoveries\peds -Recurse | Select-String "a_c_horse_arabian"
```
or Command Prompt:
```cmd
findstr /s /i "a_c_horse_arabian" data\rdr3_discoveries\peds\*
```

---

## Using it with different AI tools

### Claude Code (best experience)
Open the `rsg-redm-brain` folder as the project, or add it as an extra directory alongside the folder you're building in:
```bash
cd rsg-redm-brain && claude
# or, from your resource folder:
claude --add-dir ../rsg-redm-brain
```
`CLAUDE.md` loads automatically. Claude can grep `natives/db/INDEX.tsv`, `data/rdr3_discoveries/` and `source/` itself, so it looks values up instead of guessing.

### Cursor / Windsurf / VS Code Copilot
- Add the brain folder to the workspace.
- Reference `CLAUDE.md` in your rules file (e.g. `.cursorrules` or `.github/copilot-instructions.md`): *"Before writing RedM code, follow rsg-redm-brain/CLAUDE.md."*
- Mention files with `@` (e.g. `@server/environment.md @framework/resources/rsg-stables.md`) when the task needs them.

### ChatGPT / Claude.ai / other chat tools (no file access)
These can't search the folder, so you feed them the right files:
1. Paste or attach `CLAUDE.md`, `server/environment.md`, `conventions/coding-rules.md` and `conventions/security.md`.
2. Add task-specific files: the relevant `framework/resources/<resource>.md`, `natives/*.md`, `ui/design-standard.md` + `ui/theme.css` for NUI.
3. For data values, search the files yourself (see [Looking things up](#looking-things-up)) and paste the matching lines. **Never attach big data files whole.**

A Claude.ai Project works well: add the core files above as project knowledge so every chat starts with them.

---

## Creating a new RSG script, step by step

### 1. Describe the feature
Write down what it does, who uses it (all players, a job, admins), what it costs or rewards, and whether it needs NUI, a database table, props/peds or blips.

### 2. Start from the template
```bash
cp -r templates/rsg-template ../rsg-mything
```
Rename `rsg-template` in `fxmanifest.lua` and the README. Naming: `rsg-<name>` for server scripts.

### 3. Find a similar RSG resource
Open `framework/resources/README.md` and pick the closest match, then study its code in `source/<resource>/`:

| Building... | Look at |
|---|---|
| A shop or NPC trader | `rsg-stores`, `rsg-trader`, `rsg-npcs` |
| A job with grades / boss menu | `rsg-multijob`, `rsg-bossmenu`, `rsg-lawman`, `rsg-medic` |
| A crafting / processing NUI | `rsg-moonshine`, `rsg-crafting`, `rsg-cooking`, `rsg-smelting` |
| Placeable / persistent props | `rsg-farming`, `rsg-goldclaim`, `rsg-noticeboard` |
| Gathering / resource loop | `rsg-mining`, `rsg-lumberjack`, `rsg-herbalist`, `rsg-goldpanning` |
| Property / ownership | `rsg-housing`, `rsg-ranch` |
| Horses / wagons | `rsg-stables`, `rsg-wagons` |
| Usable items | `rsg-consume`, `rsg-canteen` |

### 4. Gather the APIs
- Player, money, jobs: `framework/rsg-core.md`
- Items: `framework/rsg-inventory.md`
- Bank: `framework/rsg-banking.md`
- Another resource: `framework/resources/<resource>.md` (exact export/event names and params)
- Menus, targets, zones, progress bars: `framework/other-exports.md`

### 5. Look up every game value
Models, anims, scenarios, controls, blip sprites, PTFX, flags, native names. See [Looking things up](#looking-things-up). Ask the AI to say which file each value came from.

### 6. Build it in the standard layout
```
rsg-mything/
├─ fxmanifest.lua       # lua54, ox_lib init, dependencies
├─ shared/config.lua    # coords, prices, timers, toggles
├─ client/client.lua    # targets, prompts, peds/props, NUI open/close
├─ server/server.lua    # ALL money/item/DB changes, validation
├─ locales/en.json      # every player-facing string
├─ html/                # NUI (index.html, style.css, script.js)
├─ install.sql          # tables, if any
└─ README.md
```
Copy building blocks from `patterns/`:
- `server-reward-event.lua` for any buy/sell/reward event
- `nui-bridge.lua` for NUI open, close and callbacks
- `entity-cleanup.lua` for spawning and cleaning up peds, props and blips
- `ox-target.lua` for interaction points

### 7. Style the NUI
Link `ui/theme.css` and follow `ui/design-standard.md` (Roboto, monochrome palette, no vignette). Always release focus on close and on resource stop.

### 8. Audit before you ship
Run the script through `audit/audit-checklist.md` (or ask the AI to, using `audit/ai-procedure.md`). Fix anything that fails, then test in-game.

### 9. Feed it back
Anything you learned the hard way goes back into the brain (see [Keeping the brain up to date](#keeping-the-brain-up-to-date)).

---

## Writing good prompts

A good prompt names the feature, the players involved, the economy, the interaction method and the resources to integrate with.

**Weak:** *"make a fishing shop script"*

**Strong:**
> Using the RedM brain, create `rsg-baitshop`. An NPC shopkeeper at a config location, interacted with via ox_target, opens an NUI shop in the house style. Players buy bait items for cash; prices come from server config. Follow `patterns/server-reward-event.lua` for the purchase event (distance check, cooldown, CanAddItem, RemoveMoney result checked). Look up the NPC model in `data/rdr3_discoveries/peds` and tell me which file it came from. Add a blip. All text in `locales/en.json`. Give complete files by path.

Useful phrases:
- *"Check `framework/resources/rsg-X.md` before calling any rsg-X export."*
- *"Study `source/rsg-moonshine` and follow its structure."*
- *"Don't guess hashes; cite the brain file for each one."*
- *"Audit the result against `audit/audit-checklist.md` before finishing."*
- *"Job-locked to `<job>` grade 2+, checked on the server."*

Iterating: ask for one feature at a time (e.g. "now add a boss menu"), and paste in-game errors (F8 console / server console) verbatim when something breaks.

---

## Looking things up

The data folders are big. **Search them, don't open them whole.** Examples (ripgrep; `grep -ri` works too, or `Select-String` on Windows):

```bash
# Natives: exact name, hash and namespace
rg -i "TASK_START_SCENARIO" natives/db/INDEX.tsv
rg -i -A5 "0x524B54361229154F" natives/db/

# Ped / animal models
rg -i "a_c_horse_arabian" data/rdr3_discoveries/peds

# Props
rg -i "p_chair" data/rdr3_discoveries/objects/object_list.lua

# Scenarios and anims
rg -i "WORLD_HUMAN_SMOKE" data/rdr3_discoveries/animations
rg -i "mech_loco" data/rdr3_discoveries/animations/ingameanims/ingameanims_list.lua

# Control hashes for prompts
rg -i "INPUT_INTERACT" data/rdr3_discoveries/Controls

# Weapons, PTFX, doors, interiors
rg -i "WEAPON_REVOLVER" data/rdr3_discoveries/weapons
rg -i "fire" data/rdr3_discoveries/graphics/ptfx
rg -i "valentine" data/rdr3_discoveries/doorHashes/doorhashes.lua

# How Rockstar uses a native (needs the decompiled scripts cloned)
rg -l "TASK_START_SCENARIO_IN_PLACE" data/rdr3-decompiled/1491.50

# How an RSG resource really does something
rg -i "RegisterNetEvent" source/rsg-stores
rg -i "exports\['rsg-inventory'\]" source/
```

Where to look for what:

| Need | Look in |
|---|---|
| Native name / params / hash | `natives/db/INDEX.tsv` → `natives/db/<NAMESPACE>.md` |
| Ped AI, combat, relationships | `natives/ped-ai-combat.md`, `data/rdr3_discoveries/AI/` |
| Game events (damage, loot, etc.) | `natives/game-events.md`, `data/rdr3_discoveries/AI/EVENTS/` |
| Prompts, blips, entity handling | `natives/prompts-blips-entities.md` |
| Models, props, anims, sounds, clothes | `data/rdr3_discoveries/MAP.md` then the folder |
| Blip sprites, textures, colours | `data/rdr3_discoveries/useful_info_from_rpfs/` |
| How a native is really used / RDR2 feature logic | `data/rdr3-decompiled-scripts.md` → grep `data/rdr3-decompiled/1491.50/` |
| Coords / 3D previews | `data/redm-forge.md`, `data/redm-info.md` |
| RSG export / event / callback | `framework/resources/<resource>.md` |
| Server item names | `server/environment.md` |

If something isn't in the brain, the AI should say so rather than invent it. Verify it online (redm.info / RedM Forge), then add it.

---

## The template resource

`templates/rsg-template/` is a working skeleton:

| File | Purpose |
|---|---|
| `fxmanifest.lua` | `cerulean`, `rdr3`, `lua54`, ox_lib init, oxmysql, NUI files, dependencies (`rsg-core`, `rsg-inventory`, `ox_lib`, `oxmysql`, `ox_target`) |
| `shared/config.lua` | All tunables: coords, prices, timers |
| `client/client.lua` | Client logic, NUI bridge |
| `server/server.lua` | Validated server events and callbacks |
| `locales/en.json` | Strings for `lib.locale()` |
| `html/` | NUI using the house style |
| `install.sql` | Database tables |
| `README.md` | Resource docs (install steps, config, support link) |

Remove the `html/` folder and `ui_page`/`files` entries if the script has no NUI; remove `install.sql` and the oxmysql line if it has no database.

---

## Core rules every script must follow

1. **Never guess** hashes, models, anims, scenarios, flags, items or natives. Look them up and cite the file.
2. **Server is authoritative.** Money, items, jobs and DB writes happen only in server files, after validation: nil-check the player, validate every client argument, take prices from server config, check distance, job/grade and cooldowns, `CanAddItem` before `AddItem`, check the `RemoveMoney` result, use `?` SQL params.
3. **Notifications** via ox_lib (`lib.notify` / `ox_lib:notify`).
4. **Locales** for all player-facing text (`locales/en.json` + `lib.locale()`).
5. **NUI** follows `ui/design-standard.md` and `ui/theme.css`, no vignette, focus released on close and stop.
6. **Clean up** entities, blips, prompts and zones in `onResourceStop`; no needless `Wait(0)` loops, distance-gate everything.
7. **Respect the environment:** use the installed systems in `server/environment.md` and never depend on removed ones.
8. **Config, not code**, for coords, timers, prices and text. Deliver complete, runnable files split by path.

---

## Auditing and converting existing scripts

To review a script, or port one from VORP / RedEM / an older RSG version:

> Audit `rsg-mything` using `audit/ai-procedure.md` and `audit/audit-checklist.md`. Report each failure with file and line, then give fixed files.

The checklist covers security, notifications, locales, environment (removed resources, item names), lifecycle/performance and NUI. For conversions, also ask the AI to map every framework call to its RSG equivalent from `framework/` and flag anything with no direct match.

---

## Keeping the brain up to date

- **RSG updates:** run `tools/refresh.sh` (or `refresh.ps1`). It re-pulls the Rexshack-RedM repos into `source/` (code only) and regenerates `framework/resources/` via `tools/extract.py`. `source/LAST_REFRESH.txt` shows when it last ran. Add repos missing from the txAdmin recipe to `tools/extra-repos.txt`.
- **Server changes:** update `server/environment.md` whenever you add/remove a resource or rename an item.
- **Lessons learned:** when a native needs a specific call order or a value turns out wrong, add it to the relevant `natives/` or `conventions/` file.
- **Reusable code:** drop working snippets from finished scripts into `patterns/` and list them in `patterns/README.md`.
- **Natives / data:** `tools/build_natives.py` rebuilds `natives/db/`; `tools/map_discoveries.py` regenerates `data/rdr3_discoveries/MAP.md`.
- Keep files small and focused. AI does best when it can load just the file it needs.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| AI invents an export or event | Point it at `framework/resources/<resource>.md`; if missing, run the refresh |
| AI uses weathersync / rsg-horses / `RSGCore.Shared.Jobs` | Remind it to read `server/environment.md` |
| Wrong item name | Check `server/environment.md` and `rsg-core/shared/items.lua` in `source/` |
| Hash or model doesn't work in-game | Ask which file it came from, re-check via `data/redm-forge.md` / `data/redm-info.md` |
| AI loads a huge data file and loses context | Tell it to grep, per `data/rdr3_discoveries/MAP.md` |
| NUI stuck on screen | Ensure `SetNuiFocus(false, false)` on close and `onResourceStop` (`patterns/nui-bridge.lua`) |
| `'.\refresh.ps1' is not recognized` | You're in Command Prompt or the wrong folder; see [Windows setup](#windows-setup) |
| `cd` won't change to `D:\...` in cmd | Use `cd /d D:\...`; see [Windows setup](#windows-setup) |
| Exploit found | Re-run `audit/audit-checklist.md` section 1 and follow `conventions/security.md` |

---

## Credits

The brain is built on the work of these projects and sites. All credit for the underlying data goes to them; please support and star their work.

| Source | What it provides | Used in |
|---|---|---|
| [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries) | RDR2/RedM game data: peds, props, anims, scenarios, weapons, PTFX, controls, doors, interiors, AI flags, events, clothing | `data/rdr3_discoveries/` |
| [VORPCORE/RDR3natives](https://github.com/VORPCORE/RDR3natives) | Native names, hashes, signatures and notes | `natives/db/` |
| [CitizenFX / Cfx.re](https://github.com/citizenfx) | RedM itself and the CFX natives | `natives/db/CFX.md` |
| [Rexshack-RedM (RSG Framework)](https://github.com/Rexshack-RedM) | rsg-core and the RSG resources, plus the [txAdmin recipe](https://github.com/Rexshack-RedM/txAdminRecipe) | `source/`, `framework/` |
| [Forza-Studios/RedM-AI-Knowledge-Brain](https://github.com/Forza-Studios/RedM-AI-Knowledge-Brain) | Fallback lookup index for game data | `data/README.md` |
| [Halen84/RDR3-Decompiled-Scripts](https://github.com/Halen84/RDR3-Decompiled-Scripts) (mirrored at [RexShack/RDR3-Decompiled-Scripts](https://github.com/RexShack/RDR3-Decompiled-Scripts)) | Decompiled RDR2 singleplayer scripts, build 1491.50 | `data/rdr3-decompiled-scripts.md` |
| [redm.info (RedM Index)](https://redm.info/) | Searchable natives, hashes, clothes, blips and props | `data/redm-info.md` |
| [RedM Forge](https://redm-forge.vercel.app/) by DatMayo | Model previews with 3D view, world map coords, animation builder | `data/redm-forge.md` |
| [Overextended](https://github.com/overextended) | ox_lib, ox_target, oxmysql | `framework/other-exports.md`, `patterns/` |

redm.info credits its own sources as rdr3natives.com, VORPCORE/RDR3natives, CitizenFX shared natives and femga/rdr3_discoveries.

This project is unofficial and not affiliated with Rockstar Games, Take-Two Interactive or Cfx.re.

---

Support: https://buymeacoffee.com/rexshack
