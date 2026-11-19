# rsg-smoking documentation

Technical reference for server owners and developers. For a short overview and installation see [README.md](README.md).

## Contents

1. [Overview](#overview)
2. [Files](#files)
3. [Dependencies and load order](#dependencies-and-load-order)
4. [Items](#items)
5. [How a use works](#how-a-use-works)
6. [Configuration reference](#configuration-reference)
7. [Config.Smokables](#configsmokables)
8. [Multi-use items](#multi-use-items)
9. [Lighters and sharing a light](#lighters-and-sharing-a-light)
10. [Coughing](#coughing)
11. [Integrations](#integrations)
12. [Events, callbacks and state bags](#events-callbacks-and-state-bags)
13. [Server reference](#server-reference)
14. [Client session engine](#client-session-engine)
15. [Animation data format](#animation-data-format)
16. [Security model](#security-model)
17. [Persistence](#persistence)
18. [Performance](#performance)
19. [Locales](#locales)
20. [Examples](#examples)
21. [Testing checklist](#testing-checklist)
22. [Troubleshooting](#troubleshooting)

## Overview

rsg-smoking adds cigarettes, cigars, pipes and chewing tobacco. The **server** owns everything that matters: it validates the use, spends lighters, packs and items, relieves stress through rsg-hud and reports nicotine to rsg-drugs. The **client** only runs the animation session (props, prompts, animations) once the server has started it.

Key points:

- Usable items are registered from `Config.Smokables`. Adding an item there is enough to make it usable.
- Cigarettes, chewing tobacco and match boxes are single non-stacking items that count down their own uses (stored in the item info).
- There are no commands, no exports, no database tables and no admin menu. Other scripts interact through the item inventory, the two client/server events below and one state bag.

## Files

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Loads rsg-core locales, `config.lua`, client and server scripts. Depends on rsg-core, rsg-inventory and rsg-target |
| `config.lua` | Every option (see the [reference](#configuration-reference)) and the `Config.Smokables` item table. Loaded on both sides |
| `server/server.lua` | Registers usable items, validates, spends lighters and packs, shares lights, relieves stress, reports nicotine, starts the client session |
| `server/versionchecker.lua` | Compares the resource version with `version.txt` in the `rex-versioncheckers` repository and prints a console message |
| `client/client.lua` | Animation sessions, props, prompts, coughing, the "Offer a light" target, cleanup |
| `locales/*.json` | Player-facing text (10 languages, identical keys) |
| `installation/shared_items.lua` | Items to add to rsg-core shared items |
| `installation/images/` | Inventory images (`cigarettes.png`, `matchbox.png`, `cigar.png`, `pipe.png`, `pipetobacco.png`, `chewingtobacco.png` and the old `cigarette1`...`cigarette10`) |
| `installation/crafting_recipes.lua` | Paste-in recipes for rsg-crafting |
| `installation/rsg-drugs_tobacco.lua` | Paste-in substance for rsg-drugs nicotine addiction |

## Dependencies and load order

| Resource | Needed for | Required |
|---|---|---|
| `rsg-core` | Core object, usable items, notifications, callbacks, locales | Yes |
| `rsg-inventory` | Item checks, `RemoveItem`, `AddItem`, `SetItemInfo`, client `HasItem` | Yes |
| `rsg-target` | The "Offer a light" option on players | Yes (listed in `dependencies`) |
| `rsg-hud` | Server export `RelieveStress` | No. Without it there is no stress relief |
| `rsg-drugs` | Nicotine addiction and the rehab block | No. Only used when `Config.Nicotine.Enabled` |

```cfg
ensure rsg-core
ensure rsg-inventory
ensure rsg-target
ensure rsg-smoking
```

ox_lib is not used.

## Items

All items are in `installation/shared_items.lua`.

| Item | Type | `unique` | Notes |
|---|---|---|---|
| `cigarettes` | Pack, 20 cigarettes | `true` | Count in `info.cigarettes` |
| `chewingtobacco` | Tin, 10 chews | `true` | Count in `info.chews` |
| `matchbox` | Box, 30 lights | `true` | Count in `info.matches`. Not usable directly, it is only a lighter |
| `cigar` | Single cigar | `false` | Consumed on use |
| `pipe` | The pipe | `true` | Kept on use |
| `pipetobacco` | Loose tobacco | `false` | Consumed by the pipe. Not usable on its own |
| `cigarette1` ... `cigarette10` | Old packs | `true` | Only needed while old packs exist. Converted to `cigarettes` on use |

Item definition example:

```lua
cigarettes = { name = 'cigarettes', label = 'Pack of Cigarettes', weight = 100, type = 'item', image = 'cigarettes.png', unique = true, useable = true, shouldClose = true, description = 'A pack of 20 cigarettes' },
```

Multi-use items must be `unique = true`. Otherwise rsg-inventory would stack them and could not keep a separate count on each.

## How a use works

```
player uses item
      |
      v
rsg-inventory -> usable item handler (server)              runUse(): busy[src] lock, pcall
      |
      v
useSmokable()
  1. GetPlayer, not dead / handcuffed, not in rehab (Config.Nicotine)
  2. used item found by slot, `requires` items present
  3. multi-use item with no uses left? remove it, stop
  4. lighter needed? findLighter(giver) ---- none ----> askForLight() and stop
  5. AwaitClientCallback('rsg-smoking:client:canSmoke', src, 3000, kind)
        client: session? blockReason()? prop model loads?   -> 'ok' or a reason
  6. item and lighter checked again (the client call yielded)
  7. useLighter(): spend a light, roll failChance            -- fail: notify, stop
  8. spend the item: pack use / legacy conversion / consume
  9. relieveStress(), addNicotine()
 10. TriggerClientEvent('rsg-smoking:client:<kind>')        -> client session starts
```

Detail per step:

1. The server checks the player exists and is not `isdead` or `ishandcuffed`. With `Config.Nicotine.Enabled` and `BlockInRehab` it also refuses while `rsg-drugs:IsInRehab`.
2. The item is looked up by the slot rsg-inventory reports, falling back to the first stack of that name. Every item in `requires` must be present (they are not consumed). A missing item shows `missing_item` with the item label.
3. A multi-use item reading 0 uses (or below) is removed and `pack_empty` / `chew_empty` is shown.
4. For `lighter = true` smokables the server looks for a lighter in `Config.LighterItems` order. With none, and `Config.ShareLight.Enabled`, a request is stored and the player is told to ask for a light (see [sharing a light](#lighters-and-sharing-a-light)). With sharing off, `missing_item` names the first lighter item.
5. The client answers `ok`, `busy`, `mounted`, `vehicle`, `swimming` or `now`. It also loads the prop model for the kind first, so an item is never taken for a smoke that cannot be shown. Anything but `ok` (or no answer within 3 seconds) shows the matching `cannot_*` message and consumes nothing.
6. The callback yields, so the server re-reads the item slot and the lighter before spending anything.
7. A lighter with `uses` loses one. With `failChance` there is a chance the light fails: the light is spent, `match_failed` is shown, and the cigarette is not touched.
8. Spending the item:
   - **Multi-use** (`uses`): `SetItemInfo` with the count lowered by one, or `RemoveItem` when it was the last use. A stack of more than one unit is split: one unit is removed and one re-added with the lowered count.
   - **Legacy pack** (`legacy`): old item removed, a `cigarettes` pack added with `legacy - 1` cigarettes (`CanAddItem` first). If the add fails the old pack is handed back and nothing is smoked.
   - **Everything else**: `consume` (default: the used item) is removed.
9. Stress is relieved with `exports['rsg-hud']:RelieveStress(src, amount)` and nicotine is reported with `exports['rsg-drugs']:AddUse(src, substance, amount)`.
10. The client event starts the session.

`busy[src]` stops two uses overlapping while step 5 is waiting. It is cleared when the use finishes, errors, or the player drops.

## Configuration reference

Every option in `config.lua`.

### Prompt keys and behaviour

| Option | Default | Description |
|---|---|---|
| `Config.Prompts.DropKey` | `0x3B24C470` | Drop / put away / spit. Also cancels any animation |
| `Config.Prompts.SmokeKey` | `0x07B8BEAF` | Smoke or chew. Tap = short drag, hold = long drag |
| `Config.Prompts.ChangeKey` | `0xD51B784F` | Change stance |
| `Config.LongDragHoldTime` | `500` | Milliseconds the smoke key must be held for a long drag |
| `Config.DropDespawnTime` | `15000` | Milliseconds a dropped cigarette stays before removal (`0` removes it at once) |

### Stress

Applied by the server through rsg-hud when a smoke starts.

| Option | Default | Description |
|---|---|---|
| `Config.CigaretteRelieveStress` | `5` | Cigarettes (also the old packs) |
| `Config.CigarRelieveStress` | `5` | Cigars |
| `Config.PipeRelieveStress` | `5` | Pipe |
| `Config.ChewingRelieveStress` | `5` | Chewing tobacco |

### Coughing

| Option | Default | Description |
|---|---|---|
| `Config.Cough.Enabled` | `true` | Turn coughing on or off |
| `Config.Cough.Chance` | `35` | % chance per drag while below a limit |
| `Config.Cough.StaminaBelow` | `25` | Stamina core value (0-100) at or below which coughing can happen |
| `Config.Cough.HealthBelow` | `25` | Health core value (0-100) at or below which coughing can happen |

### Packs

| Option | Default | Description |
|---|---|---|
| `Config.CigarettesPerPack` | `20` | Cigarettes in a full `cigarettes` pack |
| `Config.ChewsPerTin` | `10` | Chews in a full `chewingtobacco` tin |
| `Config.ConvertLegacyPacks` | `true` | Register the old pack items so using one converts it to a `cigarettes` pack |
| `Config.LegacyPacks` | `cigarette10 = 10` ... `cigarette1 = 1` | Old pack item and how many cigarettes it held |

### Lighters

| Option | Default | Description |
|---|---|---|
| `Config.LighterItems` | `{ 'matchbox' }` | Lighter items in the order they are used |
| `Config.Lighters.<item>.uses` | `30` for `matchbox` | Lights in a full box. Leave out for a lighter that is never used up |
| `Config.Lighters.<item>.key` | `'matches'` for `matchbox` | Info field holding the lights left |
| `Config.Lighters.<item>.failChance` | `8` for `matchbox` | % chance a light fails |
| `Config.Lighters.<item>.warnAt` | `5` for `matchbox` | Notify the owner of the lights left once this few remain |

### Sharing a light

| Option | Default | Description |
|---|---|---|
| `Config.ShareLight.Enabled` | `true` | Allow asking for and offering a light. Off: a player without a lighter just sees `missing_item` |
| `Config.ShareLight.Distance` | `3.0` | Metres between the two players, checked with server positions |
| `Config.ShareLight.Timeout` | `30` | Seconds a request for a light stays open |
| `Config.ShareLight.OfferCooldown` | `2` | Seconds between offers from the same player |

### Nicotine addiction

| Option | Default | Description |
|---|---|---|
| `Config.Nicotine.Enabled` | `false` | Report each smoke to rsg-drugs and apply the rehab block |
| `Config.Nicotine.Substance` | `'tobacco'` | Substance key in rsg-drugs `Config.Addiction.Substances` |
| `Config.Nicotine.BlockInRehab` | `true` | Refuse smoking while in rehab |
| `Config.Nicotine.Amount` | `cigarette = 4, cigar = 6, pipe = 4, chewingtobacco = 5` | Dependency gained per use (0-100 scale), by kind |

## Config.Smokables

Maps an item name to how it behaves. The server registers a usable item for every key.

```lua
Config.Smokables = {
    cigarettes     = { kind = 'cigarette', lighter = true, uses = Config.CigarettesPerPack, key = 'cigarettes' },
    cigar          = { kind = 'cigar',     lighter = true },
    pipe           = { kind = 'pipe',      lighter = true, requires = { 'pipetobacco' }, consume = 'pipetobacco' },
    chewingtobacco = { kind = 'chewingtobacco', uses = Config.ChewsPerTin, key = 'chews', leftMsg = 'chew_left', emptyMsg = 'chew_empty' },
}
```

| Field | Type | Description |
|---|---|---|
| `kind` | string | **Required.** `cigarette`, `cigar`, `pipe` or `chewingtobacco`. Selects the animation session, the stress option and the nicotine amount |
| `lighter` | boolean | Needs a lighter from `Config.LighterItems` |
| `requires` | string[] | Items that must be in the inventory but are not consumed |
| `consume` | string | Item removed on use. Defaults to the item being used. Ignored for multi-use and legacy items |
| `uses` | number | Marks a multi-use item. Maximum uses |
| `key` | string | Info field holding the uses left. Default `uses` |
| `leftMsg` | string | Locale key shown with the uses left (`%d`). Default `pack_left` |
| `emptyMsg` | string | Locale key shown when the last use is taken. Default `pack_empty` |
| `legacy` | number | Old pack item holding this many cigarettes. Converted to a `cigarettes` pack on use |

## Multi-use items

The cigarette pack, the chewing tin and the match box all store their count in the item info. rsg-inventory shows every primitive info field in the item details, so players see `cigarettes 15`, `chews 7` or `matches 22`.

| Item | Info field | Full size |
|---|---|---|
| `cigarettes` | `cigarettes` | `Config.CigarettesPerPack` (20) |
| `chewingtobacco` | `chews` | `Config.ChewsPerTin` (10) |
| `matchbox` | `matches` | `Config.Lighters.matchbox.uses` (30) |

Rules (`usesLeft` and `spendUse` in `server/server.lua`):

- A missing count means a **full** item, so other scripts can add them with no info.
- The count is clamped to `0 ... max`, so an edited or oversized value cannot give extra uses.
- The first version of the pack stored `info.uses`. It is still read when `info[key]` is missing, and removed the next time the item is written.
- The item is removed when the count reaches 0. It is never left at 0.
- A stack of more than one unit (from before the item became `unique`) is split: one unit is removed and one is re-added with the lowered count. If the re-add fails the unit is restored untouched and the use is cancelled.

## Lighters and sharing a light

`Config.LighterItems` lists lighter items in order, and `Config.Lighters[item]` describes each one (see the [reference](#lighters)). The first lighter the player carries is used.

| Lighter | Behaviour |
|---|---|
| `matchbox` | 30 lights. Each light has an 8% chance to fail. The owner is told how many are left once 5 or fewer remain |

A failed light spends the light and shows `match_failed` to the smoker. Nothing else is consumed, so the player can try again.

### Sharing a light

```
smoker uses a smokable with no lighter
  -> server stores pending[smoker] = { item, slot, expires }
  -> server sets state bag  Player(smoker).state.smokingNeedsLight = true
  -> smoker is told to ask someone nearby

for Config.ShareLight.Timeout seconds, a nearby player with a lighter sees
the rsg-target option "Offer a light" on the smoker
  -> client sends  rsg-smoking:server:offerLight(smokerId)
  -> server checks the request, the distance, the giver, the cooldown
  -> the normal use flow runs for the smoker, with the giver's lighter
  -> one light from the giver, one cigarette from the smoker, both are notified
```

Server-side checks in `rsg-smoking:server:offerLight`:

1. `Config.ShareLight.Enabled`.
2. `targetId` is an integer, is not the sender, and both players exist.
3. The sender is not on `OfferCooldown`.
4. The sender is not dead or handcuffed.
5. The target has an open request that has not expired, and is not in the middle of another use.
6. The smokable of the request still exists in `Config.Smokables`.
7. The distance between `GetEntityCoords(GetPlayerPed(...))` of both players is at most `Config.ShareLight.Distance`.
8. The sender carries a lighter.

The request is cleared as soon as the smoker starts any use, expires after `Timeout`, or when the smoker disconnects.

## Coughing

`Config.Cough`. After a drag (cigarette stances and the pipe), if the **health core** or **stamina core** is at or below its limit, there is a `Chance`% roll for a cough gesture. It is an animation only and takes nothing from the player. Cigars and chewing tobacco do not cough.

| Detail | Value |
|---|---|
| Core values | `_GET_ATTRIBUTE_CORE_VALUE` (`0x36731AC041289BB1`): 0 = health, 1 = stamina |
| Dictionary | `ai_gestures@gen_male@standing@speaker` or `ai_gestures@gen_female@standing@speaker` |
| Animations | `cough_high_l_001`, `cough_high_r_001`, `cough_low_l_001`, `cough_low_r_001`, `cough_medium_l_002`, `cough_medium_r_002` (one at random) |
| Flag | `30` (upper body), blend-in `0.0`, then the base animation resumes |

The cough can be cancelled with the drop key like every other animation.

## Integrations

| Resource | Used for | If missing |
|---|---|---|
| rsg-hud | Server export `RelieveStress(src, amount)` | No stress relief |
| rsg-drugs | `AddUse(src, substance, amount)` and `IsInRehab(src)` | Nicotine does nothing |
| rsg-stores | Add items to a shop in its admin menu | |
| rsg-crafting | Paste `installation/crafting_recipes.lua` into `Config.Crafting` | |

### rsg-hud (stress)

rsg-hud has server-owned needs (`Config.ServerNeeds`): it decays stress on the server and limits how much a client may change per minute. A client-side `hud:client:RelieveStress` is therefore unreliable, so rsg-smoking calls the server export:

```lua
if GetResourceState('rsg-hud') == 'started' then
    exports['rsg-hud']:RelieveStress(src, 5)
end
```

### rsg-drugs (nicotine)

rsg-drugs only knows the substances in its own `Config.Addiction.Substances`. To use nicotine:

1. Paste this into `rsg-drugs/shared/config_addiction.lua`, inside `Config.Addiction.Substances`:

```lua
tobacco = {
    label         = 'Tobacco',
    registerItems = false,   -- rsg-smoking reports each use itself
    items         = {},      -- no items for rsg-drugs to hook
    threshold     = 50,      -- dependency level at which the player is "hooked"
    decay         = 2,       -- level lost per tick while NOT hooked
    cravingRate   = 3,       -- craving gained per tick while hooked and not feeding
},
```

2. Set `Config.Nicotine.Enabled = true` in rsg-smoking.

Each smoke then calls `exports['rsg-drugs']:AddUse(src, 'tobacco', amount)`, which raises the dependency and resets craving, so smoking feeds the habit. If rsg-drugs refuses the call (substance missing), one console warning names the missing substance. While the player is in rehab (`IsInRehab`) smoking is refused with `in_rehab`.

### rsg-stores (shops)

Shops are created in game with `/createshop`, so no code is needed. Add `cigarettes`, `matchbox`, `cigar`, `pipe`, `pipetobacco` and `chewingtobacco` to a shop's stock in its admin menu and set the prices there.

### rsg-crafting (recipes)

Paste `installation/crafting_recipes.lua` into `Config.Crafting`:

```lua
{
    category = 'Smoking',
    receive = 'cigarettes', giveamount = 1,
    crafttime = 15000, requiredxp = 0, xpreward = 1,
    ingredients = {
        { item = 'tobacco_leaf',   amount = 4 },
        { item = 'rolling_papers', amount = 2 },
    },
},
{
    category = 'Smoking',
    receive = 'matchbox', giveamount = 1,
    crafttime = 10000, requiredxp = 0, xpreward = 1,
    ingredients = {
        { item = 'resource_wood', amount = 1 },
        { item = 'resource_coal', amount = 1 },
    },
},
```

`tobacco_leaf` comes from rsg-farming and `rolling_papers` is the same item rsg-drugs uses for joints. rsg-crafting adds the result with no item info, so a crafted pack or box is full.

## Events, callbacks and state bags

There are no exports and no commands.

| Name | Side | Direction | Description |
|---|---|---|---|
| `rsg-smoking:client:cigarette` | client event | server -> client | Starts a cigarette session |
| `rsg-smoking:client:cigar` | client event | server -> client | Starts a cigar session |
| `rsg-smoking:client:pipe` | client event | server -> client | Starts a pipe session |
| `rsg-smoking:client:chewingtobacco` | client event | server -> client | Starts a chewing tobacco session |
| `rsg-smoking:client:canSmoke` | client callback | server -> client | Argument: the item kind. Returns `ok`, `busy`, `mounted`, `vehicle`, `swimming` or `now` |
| `rsg-smoking:server:offerLight` | server net event | client -> server | Argument: the server id of the player who asked for a light. Fully validated (see above) |
| `smokingNeedsLight` | state bag on a player | server -> everyone | `true` while that player's request for a light is open, `nil` otherwise |

The four start events are registered for every key of `KINDS` in `client/client.lua`. They ignore the call if a session is already running. They do **not** touch the inventory, so a script that triggers them directly decides for itself what that use costs.

`canSmoke` reason codes:

| Code | Meaning | Locale key shown |
|---|---|---|
| `ok` | Nothing in the way | none |
| `busy` | A session is already running | `cannot_busy` |
| `mounted` | On a horse | `cannot_mounted` |
| `vehicle` | In a wagon or boat | `cannot_vehicle` |
| `swimming` | Swimming | `cannot_swimming` |
| `now` | Dead, ragdolled, cuffed, hogtied, or the prop model would not load. Also used when the client did not answer in 3 seconds | `cannot_now` |

## Server reference

Functions in `server/server.lua` (all local to the file).

| Function | Purpose |
|---|---|
| `notify(src, text, type)` | Sends an rsg-core notification titled `notify_title` |
| `itemLabel(name)` | Item label from `RSGCore.Shared.Items`, or the name |
| `drugsRunning()` / `inRehab(src)` | rsg-drugs state and rehab check |
| `relieveStress(src, kind)` | Calls the rsg-hud export using the `Config.*RelieveStress` option of the kind |
| `addNicotine(src, kind)` | Calls rsg-drugs `AddUse`. Warns once if it is refused |
| `usesKey(def)` | Info field name for a multi-use definition |
| `usesLeft(info, def)` | Uses left, clamped to `0 ... def.uses`. Missing = full |
| `spendUse(owner, itemName, slot, invItem, def, reason)` | Takes one use. Returns uses left, or nil on failure. Removes the item at 0 |
| `findLighter(src)` | First lighter the player carries: `{ name, slot, item, def }` |
| `useLighter(owner, lighter, smoker)` | Spends a light and rolls `failChance`. false = do not smoke |
| `clearPending(src)` / `askForLight(src, item, slot)` | Open and close a request for a light and the `smokingNeedsLight` state bag |
| `useSmokable(src, itemName, def, usedItem, lightFrom)` | The whole use flow. `lightFrom` is the giver's server id for a shared light |
| `runUse(...)` | Wraps `useSmokable` in the `busy` lock and `pcall` |

State tables: `busy[src]` (use in progress), `pending[src]` (`{ item, slot, expires }`), `offerAt[src]` (last offer time). All are cleared on `playerDropped`.

## Client session engine

There is one active session at a time. `session` holds:

| Field | Description |
|---|---|
| `dicts` | Set of animation dictionaries loaded for the session, released at the end |
| `prompts` | Prompt handles by slot: `drop`, `use`, `stance` |
| `prop` / `propMode` | The prop in hand and what happens to it at the end: `'drop'` (falls and despawns, cigarettes) or `'delete'` |
| `stance` | Current cigarette stance letter |
| `dropRequested` | Set when the drop key was pressed during an animation |

Flow of `startSession(kind)`: create `session`, run the kind's function inside `pcall`, then `cleanup()` inside `pcall`, then clear `session`. A failure anywhere cannot leave a stale session behind.

| Helper | Purpose |
|---|---|
| `blockReason()` / `interrupted()` | Why the player cannot smoke (dead, ragdolled, cuffed, hogtied, mounted, in a wagon or boat, swimming) |
| `yes(v)` | `v == true or v == 1`. Some RedM natives return 1/0, and 0 is truthy in Lua |
| `loadAnimDict` / `useDict` / `loadModel` | Request with a 5 second timeout. `useDict` also records the dictionary for release |
| `play(dict, anim, duration, flag, blendIn)` | `TaskPlayAnim` on the player |
| `waitForAnim(dict, anim)` | Waits (5 s timeout) until the animation is playing |
| `waitOrCancel(ms)` | Waits; returns false early when the drop key is released or the player is interrupted. The state check runs 4 times a second, the key every frame |
| `spawnProp` / `attach` / `deleteProp` / `releaseProp` | Create a networked prop, attach it to a bone, delete it, or detach it and despawn it after `Config.DropDespawnTime` |
| `addPrompt` / `showPrompts` | Create a prompt for a slot / show or hide slots |
| `interact(isPlaying, onDrop, onStance, onUse)` | The shared control loop |
| `shouldCough` / `cough` | The coughing roll and gesture |

### `interact`

Shows the prompts and loops until the player drops the item, is interrupted, or the base animation stops. Every frame it reads the three keys; every 250 ms it checks `interrupted()` and `isPlaying()`.

- Drop key released: `onDrop()` then exit.
- Change key released: hide the action prompts, `onStance()`. A false return means the player cancelled or was interrupted.
- Smoke key pressed then released: the hold time decides tap or long (`Config.LongDragHoldTime`), `onUse(isLong)`.

### Per-kind timeline

| Kind | Intro | Prompts | Use | Exit |
|---|---|---|---|---|
| `cigarette` | Male: enter anim then four attach changes (~7 s). Female: attach and 2.5 s | drop, smoke, stance | Tap or hold plays that stance's drag, then back to base | Exit animation, the cigarette falls |
| `cigar` | 1 s | drop only | The held animation loops; attack/aim controls are blocked | The cigar is deleted |
| `pipe` | 9 s transition | put away, smoke, stance | Tap: 22.6 s idle. Stance: 5 s `wip_base` | 6 s put-away, the pipe is deleted |
| `chewingtobacco` | 2.5 s, the tin appears for 6 s, then 3.5 s | spit, chew, stance | Random idle from 8 dictionaries. Stance swaps A and B | 5.5 s spit |

### Cleanup

`cleanup()` deletes the prompts, drops or deletes the prop, clears secondary tasks, releases the dictionaries and (if the player is alive) clears tasks after 100 ms. On resource stop all prompts, props and the "Offer a light" target are removed.

### Props

Every prop is registered as `props[entity] = modelHash`. `deleteProp` and the shutdown cleanup only delete an entity when its model still matches, so a recycled entity handle can never delete someone else's entity.

| Kind | Model |
|---|---|
| `cigarette` | `P_CIGARETTE01X` |
| `cigar` | `P_CIGAR01X` |
| `pipe` | `P_PIPE01X` |
| `chewingtobacco` | `S_TOBACCOTIN01X` |

## Animation data format

Cigarette animations are data tables (`CIGARETTE.male`, `CIGARETTE.female`) so stances can be added without new code.

```lua
CIGARETTE.female = {
    start  = 'c',                    -- stance used first
    order  = { 'c', 'b', 'a' },      -- order the stance key cycles through
    stances = {
        b = {
            base  = { dict, anim },            -- looped idle
            tap   = { dict, anim, durationMs },-- short drag
            hold  = { dict, anim, durationMs },-- long drag
            trans = { dict, anim, durationMs },-- optional: played before leaving this stance
        },
    },
    exit = { dict = ..., anim = ..., before = ms, after = ms, push = true },
}
```

`exit.before` is how long the exit animation plays before the prop is released, `exit.after` how long it plays after. `push = true` gives the falling cigarette a downward push.

Every dictionary, animation and prop name must exist: look them up in `data/rdr3_discoveries/animations` of the RedM brain rather than guessing.

## Security model

- Everything that changes the inventory happens on the server, from the usable item handler. The client cannot ask for an item.
- The server never takes an item, an amount or a reward from the client. Items, lighters and uses are spent by inventory slot, so a client cannot choose which stack is used or how many uses are taken.
- `rsg-smoking:server:offerLight` is the only event a client can send. It does nothing unless the target has an open, unexpired request, both players are in range by **server** position, the giver holds a lighter and is not dead or cuffed, and the giver is not on cooldown. It cannot be used to receive items.
- `RemoveItem`, `SetItemInfo` and `AddItem` results are checked. A failure cancels the use (or restores the old pack) instead of starting a free smoke.
- The `canSmoke` callback only avoids wasting items. A modified client can answer `ok`, which only lets it spend its own item.
- Stress and nicotine are applied by the server. Nothing the client reports changes them.
- The client can still run the start events on itself (animation only, no items or stress). That gives it nothing it could not already do locally.
- No SQL, no money, no NUI.

## Persistence

No database tables. Counts live in the item info, which rsg-inventory saves with the inventory. The share-light requests and the `smokingNeedsLight` state bag are in memory only and are gone after a restart or disconnect.

## Performance

- Nothing runs while nobody is smoking. The only thread at startup registers the "Offer a light" target once and ends.
- During a session the control loop runs every frame (needed to read keys). State checks run every 250 ms. A session ends on death, ragdoll, mount, vehicle, swimming or losing the base animation.
- Animation dictionaries and models are released at the end of every session.
- Server work happens only when an item is used or a light is offered.

## Locales

All text is in `locales/<lang>.json`, loaded by rsg-core (`@rsg-core/shared/locale.lua`). Languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro. `en.json` is the master. When you add a key, add it to every language file with the same placeholders. The language comes from `setr rsg:locale <lang>`.

| Key | Placeholder | Used for |
|---|---|---|
| `notify_title` | | Notification title |
| `missing_item` | `%s` item label | Missing required item |
| `cannot_busy`, `cannot_mounted`, `cannot_swimming`, `cannot_vehicle`, `cannot_now` | | Reasons the client refused |
| `pack_left` | `%d` | Cigarettes left in the pack |
| `pack_empty` | | Pack finished |
| `chew_left` | `%d` | Chews left in the tin |
| `chew_empty` | | Tin finished |
| `box_left` | `%d` | Matches left in the box |
| `box_empty` | | Last match used |
| `match_failed` | | The light failed |
| `need_light` | | Asked to find a light |
| `light_shared`, `light_received` | | Notifications to the giver and the smoker |
| `in_rehab` | | Smoking refused during rehab |
| `target_give_light` | | The "Offer a light" target label |
| `prompt_drop`, `prompt_put_away`, `prompt_spit` | | Exit prompt per item type |
| `prompt_smoke`, `prompt_chew`, `prompt_stance` | | Action prompts |

## Examples

### Give a full pack or box (server)

```lua
-- no info = full
exports['rsg-inventory']:AddItem(src, 'cigarettes', 1)

-- or with a count
exports['rsg-inventory']:AddItem(src, 'matchbox', 1, { matches = 10 })
exports['rsg-inventory']:AddItem(src, 'cigarettes', 1, { cigarettes = 5 })

-- always check there is room first
if exports['rsg-inventory']:CanAddItem(src, 'cigarettes', 1) then
    exports['rsg-inventory']:AddItem(src, 'cigarettes', 1, nil, nil, 'my-script-reward')
end
```

### Read how many cigarettes are left (server)

```lua
local item = exports['rsg-inventory']:GetItemByName(src, 'cigarettes')
if item then
    -- a missing count means a full pack
    local left = tonumber(item.info and item.info.cigarettes) or 20
    print(('player %s has %d cigarettes in the pack'):format(src, left))
end
```

### Start a smoke from your own item (server)

The start events do not touch the inventory, so take the item first and check the result:

```lua
RSGCore.Functions.CreateUseableItem('my_cigar_box', function(source, item)
    local src = source
    if not exports['rsg-inventory']:RemoveItem(src, 'my_cigar_box', 1, item and item.slot, 'my-script') then return end
    TriggerClientEvent('rsg-smoking:client:cigar', src)
end)
```

### React to a player asking for a light (client)

```lua
-- true while that player has an open request for a light
local function needsLight(serverId)
    return Player(serverId).state.smokingNeedsLight == true
end
```

### Add a lighter item (config only)

```lua
-- config.lua
Config.LighterItems = { 'lighter', 'matchbox' }
Config.Lighters = {
    lighter  = {},                                                        -- never used up, never fails
    matchbox = { uses = 30, key = 'matches', failChance = 8, warnAt = 5 },
}
```

Add `lighter` to your shared items as a normal item (`unique = false`, `useable = false`).

### Add a new multi-use item (config + locales)

A box of 5 cigarillos that need a lighter and count down like the pack:

```lua
-- config.lua
Config.Smokables.cigarillos = {
    kind = 'cigarette', lighter = true,
    uses = 5, key = 'cigarillos',
    leftMsg = 'cigarillo_left', emptyMsg = 'cigarillo_empty',
}
```

```lua
-- shared items (unique = true so each box keeps its own count)
cigarillos = { name = 'cigarillos', label = 'Box of Cigarillos', weight = 100, type = 'item', image = 'cigarillos.png', unique = true, useable = true, shouldClose = true, description = 'A box of 5 cigarillos' },
```

```json
"cigarillo_left": "%d cigarillos left in the box.",
"cigarillo_empty": "The box is empty."
```

Add both keys to all 10 locale files. The item reuses the cigarette animations because its `kind` is `cigarette`.

### Add a new kind (cigarillo with its own stress and nicotine)

A new kind needs entries in four places. This one reuses the cigar session:

```lua
-- config.lua
Config.CigarilloRelieveStress = 3
Config.Nicotine.Amount.cigarillo = 3
Config.Smokables.cigarillo = { kind = 'cigarillo', lighter = true }
```

```lua
-- server/server.lua: map the kind to its stress option
local STRESS = {
    -- ...existing kinds...
    cigarillo = 'CigarilloRelieveStress',
}
```

```lua
-- client/client.lua: the prop model to preload, and the session function
local PROP_MODELS = {
    -- ...existing kinds...
    cigarillo = 'P_CIGAR01X',
}

local KINDS = {
    -- ...existing kinds...
    cigarillo = runCigar, -- the start event rsg-smoking:client:cigarillo is registered automatically
}
```

An unknown kind in `STRESS` simply gives no stress, and one missing from `PROP_MODELS` skips the model preload.

### Add a female stance (animation data)

```lua
-- client/client.lua, inside CIGARETTE.female.stances
d = {
    base = { 'amb_rest@world_human_smoking@female_a@base', 'base' },
    tap  = { 'amb_rest@world_human_smoking@female_a@idle_a', 'idle_a', 6000 },
    hold = { 'amb_rest@world_human_smoking@female_a@idle_b', 'idle_d', 9000 },
},
-- and add it to the cycle:
-- order = { 'c', 'b', 'a', 'd' },
```

Check the dictionary and animation names and read each animation's real duration (`GetAnimDuration`) before choosing the millisecond values.

### Cap the number of cigarettes per player (server, example hook)

rsg-smoking has no events to hook, but you can wrap the same item with your own handler registered **after** it only if you remove the original from `Config.Smokables`. The simplest approach is to give players fewer cigarettes:

```lua
-- config.lua
Config.CigarettesPerPack = 10
```

## Testing checklist

1. Use `cigarettes` with a `matchbox`: pack and box counts drop by one each, and the animation plays.
2. Set `Config.Lighters.matchbox.failChance = 100`: the box loses a match, the pack keeps its count, `match_failed` shows.
3. Remove all lighters and use a pack: `need_light` shows and the state bag is set. With a second player nearby holding a lighter, the **Offer a light** option appears and works. Out of range or after 30 seconds it does not.
4. Use a pack with 1 cigarette left: it is removed and `pack_empty` shows.
5. Use an old `cigarette5`: it becomes a `cigarettes` pack with 4.
6. Use on a horse, in a wagon, swimming, cuffed: refused with the right message and nothing consumed.
7. Press the drop key at every stage of every kind: the session ends cleanly and the prop is removed.
8. Female character: all three cigarette stances work.
9. With rsg-drugs and `Config.Nicotine.Enabled`: `/addiction` shows the tobacco dependency rising, and smoking is refused in rehab.
10. `restart rsg-smoking` while smoking: props, prompts and the target are removed.

## Troubleshooting

| Problem | Check |
|---|---|
| "You can't do that right now" | The client refused or did not answer. Check the F8 console for `model failed to load` (the prop preload) and for errors from `client/client.lua` |
| "You need a light" | The player needs a `matchbox`, or someone nearby who has one (see sharing a light) |
| "Offer a light" never shows | `Config.ShareLight.Enabled`, the request is still open (30 s), you carry a lighter, you are close, rsg-target is running |
| Nicotine does nothing | `Config.Nicotine.Enabled`, rsg-drugs started, the `tobacco` substance added to rsg-drugs. The console prints a warning when rsg-drugs refuses it |
| Pack, tin or box shows no count | The count appears after the first use (a missing count means full). Check the item is `unique = true` |
| A pack never decreases | The item is not `unique = true`, or the item name is not the key in `Config.Smokables` |
| Nothing happens when using an item | The item name matches a key in `Config.Smokables` and rsg-inventory is started |
| Old `cigarette10`...`cigarette1` do nothing | `Config.ConvertLegacyPacks = true` and the old items still exist in your shared items |
| Prop or animation missing | The console shows `model failed to load` or `animation dictionary failed to load` with the name |
| Stress does not drop | rsg-hud must be started. The server calls its `RelieveStress` export |
| Version check says it cannot run | `version.txt` for `rsg-smoking` must exist in the version checker repository |
| Female character plays male pipe or chewing animations | Expected: no female versions of those animations were found |

Support: https://rexshack.tebex.store
Buy me a coffee: https://buymeacoffee.com/rexshack

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-smoking 3.0.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Prompts` | `table` |  |
| `Config.DropKey` | `0x3B24C470` |  |
| `Config.SmokeKey` | `0x07B8BEAF` |  |
| `Config.ChangeKey` | `0xD51B784F` |  |
| `Config.LongDragHoldTime` | `500` | ms the smoke key must be held for a long drag (cigarettes) |
| `Config.DropDespawnTime` | `15000` | ms a dropped cigarette stays on the ground before it is removed (0 = remove at once) |
| `Config.CigaretteRelieveStress` | `5` |  |
| `Config.CigarRelieveStress` | `5` |  |
| `Config.PipeRelieveStress` | `5` |  |
| `Config.ChewingRelieveStress` | `5` |  |
| `Config.Cough` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.Chance` | `35` |  |
| `Config.StaminaBelow` | `25` |  |
| `Config.HealthBelow` | `25` |  |
| `Config.CigarettesPerPack` | `20` |  |
| `Config.ChewsPerTin` | `10` | chews in a full 'chewingtobacco' tin (same system as the pack) |
| `Config.ConvertLegacyPacks` | `true` | 'cigarettes' pack holding the remaining cigarettes (number = cigarettes the old pack held). |
| `Config.LegacyPacks` | `table` |  |
| `Config.LighterItems` | `{ 'matchbox' }` |  |
| `Config.Lighters` | `table` |  |
| `Config.ShareLight` | `table` |  |
| `Config.Distance` | `3.0` |  |
| `Config.Timeout` | `30` |  |
| `Config.OfferCooldown` | `2` |  |
| `Config.Nicotine` | `table` |  |
| `Config.Substance` | `'tobacco'` |  |
| `Config.BlockInRehab` | `true` |  |
| `Config.Amount` | `table` |  |
| `Config.Smokables` | `table` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-smoking:client:canSmoke` | client | `cb, kind` | `client/client.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-smoking:client:canSmoke', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-smoking:client:` | client | `` | `client/client.lua` |
| `rsg-smoking:server:offerLight` | server | `targetId` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-smoking:server:offerLight', targetId)
-- from a server script
TriggerClientEvent('rsg-smoking:client:', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
