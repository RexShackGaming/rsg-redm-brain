# RDR3 Decompiled Scripts (singleplayer game scripts)

Repo: https://github.com/RexShack/RDR3-Decompiled-Scripts
(fork of https://github.com/Halen84/RDR3-Decompiled-Scripts, original work by **Halen84**)

Decompiled RDR2 singleplayer game scripts, build **1491.50**. About 1,640 `.c` files in one folder (`1491.50/`), one file per game script. They show **how Rockstar itself calls the natives**: the call order, the arguments, and the flags and hashes used in real gameplay.

## When to use it
- A native's params or call order are unclear in `natives/db/`: see how a real script calls it.
- Recreating an RDR2 feature (minigames, hangings, robberies, shops, camps, hunting, herbs) and wanting the original logic.
- Finding real anim dicts, scenarios, prompts, audio, databindings or UI flow used together.

Use it as **reference**, not as code to paste: it's decompiled C-like pseudo-code with generic names (`func_123`, `Local_45`, `iParam0`). Rewrite the logic in clean Lua.

## Getting it locally
It's large, so it isn't stored in the brain. Clone it next to the brain (or into `data/rdr3-decompiled/`, which `.gitignore` excludes):
```bash
git clone --depth 1 https://github.com/RexShack/RDR3-Decompiled-Scripts.git data/rdr3-decompiled
```
Files are then at `data/rdr3-decompiled/1491.50/<script>.c`.

## How to search (never open a file whole; many are several MB)
```bash
# Which scripts use a native, and how
rg -l "TASK_START_SCENARIO_IN_PLACE" data/rdr3-decompiled/1491.50
rg -n -C3 "_UIPROMPT_SET_HOLD_MODE" data/rdr3-decompiled/1491.50/fillet_sp.c

# Find the script for a feature
ls data/rdr3-decompiled/1491.50 | rg -i "hanging|fillet|poker|moonshine"
```
Natives may appear by name or as a hash (`0x...`). If a name search finds nothing, grep the hash from `natives/db/INDEX.tsv`.

## Script name prefixes
| Prefix | Count | What |
|---|---|---|
| `cv_` | ~395 | Conversations / ambient context (chores, interactions) |
| `rcm_` | ~156 | Random-character (stranger) missions |
| `beat_` | ~119 | Random world encounters (e.g. `beat_public_hanging`, `beat_moonshine_camp`) |
| `av_` | ~109 | Ambient vignettes |
| `herb_` | ~50 | Herb / plant gathering |
| `spd_` | ~47 | Story-mission-related scripts |
| `ambush_`, `coachrobberies_`, `hideout_` | | Ambushes, coach robberies, gang hideouts |
| `shop_`, `shack_`, `camp_` | | Shops, shacks, camp activities |
| `hunting_`, `train_`, `law_`, `prisoner_`, `loanshark_` | | Hunting, trains, law, prisoners, debt collection |
| `act_` | | Activities (e.g. `act_gen_poker`, `act_bankrobbery01`, `act_camp_dominoes_light`) |
| `fillet_sp`, `fivefinger*` | | Five Finger Fillet minigame |

## Notes
- Singleplayer build 1491.50. Most natives behave the same in RedM, but always confirm the signature in `natives/db/` and test in-game.
- Singleplayer-only systems (story flags, mission state, `player_zero` models) don't exist on a RedM server. Strip them out.
- Cite the script file a value or call order came from.
