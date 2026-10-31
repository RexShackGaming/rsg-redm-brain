# RedM Brain — entry point for AI assistants

You are helping build RedM resources for a server running the **RSG Framework (rsg-core 3.0.3)**, Lua 5.4, oxmysql and rsg-target (replaces ox_target). ox_lib is being phased out: rsg-core now provides notify, callbacks and multi-job.
Read this file first, then open only the files you need for the task.

## Golden rules
1. **Never guess** hashes, model names, anim dicts, scenarios, flag IDs, item names or native hashes. Look them up in `data/rdr3_discoveries/` (open `MAP.md`, then search the file; never read big files whole), `natives/db/`, `data/rdr3-native-enums/` (flag/enum values for natives), `natives/` or `server/environment.md` (cross-check online via `data/redm-info.md` or `data/redm-forge.md`). Tell the user which file each value came from.
2. **Never trust the client.** All money and item changes happen on the server, after validation (`conventions/security.md`).
3. Notifications go through **rsg-core** (`RSGCore.Functions.Notify` / `RSGCore:Client:Notify`), never ox_lib. Player-facing text goes in **locales** (`conventions/notify-locales.md`).
4. NUI follows the house style (`ui/design-standard.md`, `ui/theme.css`). No vignette.
5. New resources start from `templates/rsg-template/`.
6. Give complete, runnable code split by file path. Put coords, timers, prices and text in config or locales.
7. If sources disagree, follow this precedence: `server/environment.md` > `source/` (real code) > `framework/` > everything else.
8. **Before calling any RSG resource's export, event or callback, check `framework/resources/<resource>.md`** for the exact name and parameters. If you need behaviour details, read that resource's code in `source/<resource>/`.
9. When building something similar to an existing RSG resource (shops, jobs, NUI menus, placeable props), study that resource in `source/` first and follow its patterns.
10. When converting a VORP script, follow `vorp/README.md` (conversion map + porting checklist). Never use VORP APIs in RSG scripts unless asked.

## Map
| Folder | Use it for |
|---|---|
| `server/environment.md` | What's installed on this server, item names, resources that are removed |
| `conventions/` | Coding style, security rules, notify/locale rules |
| `framework/` | Hand-written RSGCore, rsg-inventory and rsg-banking guides |
| `framework/resources/` | **Generated** API reference for ~70 RSG resources: exports with params, net events, callbacks, usable items, commands, DB tables |
| `source/` | Code-only mirror of the Rexshack-RedM repos (filled by `tools/refresh.sh`). Search it for real examples |
| `tools/` | Refresh scripts that re-pull the repos and regenerate the reference |
| `natives/` | RedM natives guides: ped AI/combat, game events, prompts, blips, entities |
| `natives/db/` | **Full natives database** (~8k, hash + signature + notes). Grep `INDEX.tsv` first |
| `data/rdr3-decompiled-scripts.md` | **RDR3 decompiled SP scripts** (Halen84, build 1491.50): how Rockstar calls natives in real gameplay. Grep `data/rdr3-decompiled/1491.50/` if cloned |
| `data/rdr3-native-enums.md` | **Native flags & enums** (Halen84): config/reset flags, combat attributes, prompt types, task types, door IDs, HUD contexts, etc. Grep `data/rdr3-native-enums/INDEX.tsv` by native name |
| `data/redm-info.md` | redm.info online lookup: what's on the site and its local equivalents |
| `data/redm-forge.md` | RedM Forge (redm-forge.vercel.app): models/hashes with 3D preview, world map coords, animation builder |
| `data/rdr3_discoveries/` | **Local copy of femga/rdr3_discoveries**: peds, props, anims, scenarios, weapons, PTFX, blips, controls, doors, interiors, AI flags, events. Start at `MAP.md`, then search the file |
| `data/README.md` | Fallback lookup index (Forza RedM-AI-Knowledge-Brain) for things not in rdr3_discoveries |
| `patterns/` | Tested snippets: secure server events, NUI bridge, entity cleanup, prompts |
| `templates/rsg-template/` | Skeleton resource to copy for new scripts |
| `ui/` | NUI design standard and drop-in theme CSS |
| `audit/` | Checklist for auditing or converting existing scripts |
| `vorp/` | **VORP Core reference only** (not installed): API guide + RSG ⇄ VORP conversion map (`vorp/README.md`), official docs, generated API per resource, code mirror. Use when porting VORP scripts or the user asks for VORP/bridge support |

## Workflow for a new script
1. Read `server/environment.md` and `conventions/coding-rules.md`.
2. Copy `templates/rsg-template/` and rename it (`rsg-<name>`).
3. Find similar RSG resources in `framework/resources/README.md` and read their code in `source/`.
4. Pull APIs from `framework/` and natives from `natives/`. Look up any data values.
5. Before finishing, check the script against `audit/audit-checklist.md`.
