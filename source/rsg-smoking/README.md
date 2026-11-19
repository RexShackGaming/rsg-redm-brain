# rsg-smoking

Cigarettes, cigars, pipes and chewing tobacco for the RSG Framework (RedM).

**Version:** 3.0.0 | **Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target` (no ox_lib needed) | **Optional:** `rsg-hud` (stress relief), `rsg-drugs` (nicotine addiction)

Full technical documentation is in [DOCS.md](DOCS.md).

## Features

- One cigarette item: `cigarettes` is a pack with 20 uses (`Config.CigarettesPerPack`). Each smoke uses one, the cigarettes left are kept on the item (shown in the item details) and the pack is removed when empty
- Chewing tobacco tins hold 10 chews (`Config.ChewsPerTin`), counted the same way as the cigarette pack
- Match boxes: `matchbox` holds 30 lights, a light can fail (8% by default) and the owner is warned when the box runs low
- Share a light: a player without a lighter can ask for one, and nearby players with a lighter get an "Offer a light" option on them. The giver spends one light and the smoke starts for the other player
- Coughing: after a drag, worn-out players (low stamina or health) sometimes cough (animation only)
- Nicotine addiction through rsg-drugs (optional, off by default), with smoking refused during rehab
- Old `cigarette10` ... `cigarette1` packs still work and convert into a `cigarettes` pack when used (`Config.ConvertLegacyPacks`)
- Cigars, pipes (pipe plus pipe tobacco) and chewing tobacco
- Four cigarette stances for male characters, three for female characters
- Tap the smoke key for a short drag, hold it for a long drag
- Every action can be cancelled with the drop key, even mid-animation
- Stress relief on use, applied by the server through rsg-hud (configurable per item type)
- Nothing is consumed when the player cannot smoke (on a horse, in a wagon or boat, swimming, cuffed, already smoking, dead) or when the prop model cannot load
- Dropped cigarettes despawn automatically, so no entity build-up
- Fully localised (11 languages), rsg-core notifications, no ox_lib

## Installation

1. Place `rsg-smoking` in your resources folder.
2. Add the items from `installation/shared_items.lua` to your rsg-core shared items. Set `chewingtobacco` to `unique = true` (the new item file does this); old stacks are split automatically as they are used. Keep any existing `cigarette1`...`cigarette10` items in your shared items until players have used them up, so old packs still work. Shops and rewards should give `cigarettes` and `matchbox`; a pack or box with no stored uses counts as full.
3. Copy the images from `installation/images` into your rsg-inventory images folder.
4. Add `ensure rsg-smoking` to your `server.cfg` after `rsg-core`, `rsg-inventory` and `rsg-target`.

This script has no database tables.

### Optional

- **Shops:** in the rsg-stores admin menu (`/createshop`) add `cigarettes`, `matchbox`, `cigar`, `pipe`, `pipetobacco` and `chewingtobacco` to a shop's stock. Prices are set there.
- **Crafting:** paste `installation/crafting_recipes.lua` into rsg-crafting's `Config.Crafting`. Cigarettes are made from `tobacco_leaf` and `rolling_papers` (the same papers rsg-drugs uses for joints), match boxes from `resource_wood` and `resource_coal`.
- **Nicotine addiction:** paste `installation/rsg-drugs_tobacco.lua` into rsg-drugs `Config.Addiction.Substances`, then set `Config.Nicotine.Enabled = true` here.
- **Item details label:** rsg-inventory shows the item info as `cigarettes` / `matches` followed by the number. Add `info_cigarettes` and `info_matches` to the rsg-inventory locale files if you want nicer wording.

## Configuration (`config.lua`)

| Option | Default | Description |
|---|---|---|
| `Config.Prompts.DropKey` | `0x3B24C470` | Drop / put away / spit |
| `Config.Prompts.SmokeKey` | `0x07B8BEAF` | Smoke or chew |
| `Config.Prompts.ChangeKey` | `0xD51B784F` | Change stance |
| `Config.LongDragHoldTime` | `500` | Milliseconds to hold the smoke key for a long drag |
| `Config.DropDespawnTime` | `15000` | Milliseconds before a dropped cigarette is removed (`0` removes it at once) |
| `Config.CigaretteRelieveStress` | `5` | Stress relieved when a cigarette is lit |
| `Config.CigarRelieveStress` | `5` | Stress relieved when a cigar is lit |
| `Config.PipeRelieveStress` | `5` | Stress relieved when a pipe is lit |
| `Config.ChewingRelieveStress` | `5` | Stress relieved when chewing tobacco is used |
| `Config.Cough.Enabled` | `true` | Turn coughing on or off |
| `Config.Cough.Chance` | `35` | % chance to cough per drag while below a limit |
| `Config.Cough.StaminaBelow` / `HealthBelow` | `25` / `25` | Core values (0-100) at or below which coughing can happen |
| `Config.CigarettesPerPack` | `20` | Cigarettes in a full `cigarettes` pack |
| `Config.ChewsPerTin` | `10` | Chews in a full `chewingtobacco` tin |
| `Config.ConvertLegacyPacks` | `true` | Old `cigarette10`...`cigarette1` items convert to a `cigarettes` pack when used |
| `Config.LegacyPacks` | see file | Old pack items and how many cigarettes each held |
| `Config.LighterItems` | `matchbox` | Lighter items, checked in this order |
| `Config.Lighters` | see file | Per lighter: `uses`, `key`, `failChance`, `warnAt` |
| `Config.ShareLight.Enabled` | `true` | Allow asking for and offering a light |
| `Config.ShareLight.Distance` | `3.0` | Metres between the two players (checked on the server) |
| `Config.ShareLight.Timeout` | `30` | Seconds a request for a light stays open |
| `Config.ShareLight.OfferCooldown` | `2` | Seconds between offers from the same player |
| `Config.Nicotine.Enabled` | `false` | Report smoking to rsg-drugs as addiction |
| `Config.Nicotine.Substance` | `tobacco` | Substance key in rsg-drugs |
| `Config.Nicotine.BlockInRehab` | `true` | Refuse smoking while in rehab |
| `Config.Nicotine.Amount` | see file | Dependency gained per use, by kind |
| `Config.Smokables` | see file | Usable items: `kind`, `lighter`, `requires`, `consume`, `uses`, `key`, `legacy` |

## How to use

| Item | Needs | Result |
|---|---|---|
| `cigarettes` | the pack and a lighter | Uses one cigarette from the pack (20 per pack); the pack is removed when empty |
| `cigarette10` ... `cigarette1` (old) | the pack and a lighter | Converts into a `cigarettes` pack with the cigarettes left |
| `cigar` | `cigar` and a lighter | Consumes the cigar |
| `pipe` | `pipe`, `pipetobacco` and a lighter | Consumes the pipe tobacco, keeps the pipe |
| `chewingtobacco` | `chewingtobacco` | Uses one chew from the tin (10 per tin); the tin is removed when empty |

A lighter is a `matchbox` (30 lights, each light can fail). A failed light uses up the light but not the cigarette.

**No lighter?** Use the item anyway. You are told to ask someone nearby, and for 30 seconds players close to you who carry a lighter see an **Offer a light** option when they target you with rsg-target.

While smoking, the on-screen prompts let you drop the item, take a drag (tap or hold) and change stance.

## Developers

The four start events can be triggered by other client scripts if you want to start a session without the inventory item:

```lua
TriggerEvent('rsg-smoking:client:cigarette')
TriggerEvent('rsg-smoking:client:cigar')
TriggerEvent('rsg-smoking:client:pipe')
TriggerEvent('rsg-smoking:client:chewingtobacco')
```

Anything that should cost an item must remove it on the server first. See [DOCS.md](DOCS.md).

## Languages

en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru. Set the language with `setr rsg:locale de` in your `server.cfg`.

Support: https://rexshack.tebex.store
Buy me a coffee: https://buymeacoffee.com/rexshack
