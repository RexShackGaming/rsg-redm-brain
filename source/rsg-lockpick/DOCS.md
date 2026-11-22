# rsg-lockpick: Documentation (v3.1.0)

Guide for server owners and developers. For features and installation see [README.md](README.md).

## Contents
1. Architecture
2. Data formats
3. Server exports
4. Client exports
5. Events and callbacks
6. Integration examples
7. Saving and persistence
8. Security model
9. Database
10. Server owner guide
11. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest. Loads `@rsg-core/shared/locale.lua`, config, client and server scripts and the NUI files |
| `shared/config.lua` | All settings plus `Config.Clamp` and `Config.Build` (shared option builder) |
| `client/main.lua` | Client API, NUI focus (`applyNuiFocus` + push-to-talk whitelist), session/token handling, sounds, optional animation, server-ticket handling, cleanup |
| `server/main.lua` | `StartAttempt` and tickets, result validation, lockpick item wear, rsg-skills perks/XP, rsg-reputation, lawman alerts |
| `html/index.html` | Panel markup and the inline SVG lock |
| `html/style.css` | House "leather and gold" style (monochrome accent, no vignette) |
| `html/script.js` | Game loop (requestAnimationFrame, delta-time), input (mouse, keyboard, gamepad), timer, animation, result and sound reporting |
| `locales/*.json` | Translations: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (16 keys each) |

## 2. Data formats
**Options table** (all keys optional; every value is clamped to `Config.Limits`):

| Key | Default | Meaning |
|---|---|---|
| `preset` | none | `easy`, `medium` or `hard` (see `Config.Presets`); explicit keys below override it |
| `pins` | 1 | Picks available (integer, 1 to 10) |
| `pinDamage` | 20 | Damage per jam tick (1 to 100, pick health is 100) |
| `damageInterval` | 150 | ms between jam damage ticks (50 to 1000) |
| `solvePadding` | 4 | Sweet-spot half-width in degrees (1 to 30) |
| `maxDistFromSolve` | 45 | Degrees from the sweet spot at which the cylinder is fully blocked (10 to 90) |
| `mouseSmoothing` | 2 | Mouse divisor (0.5 to 10) |
| `turnSpeed` | 120 | Cylinder speed in degrees per second (40 to 400) |
| `timeLimit` | 0 | Seconds for the whole attempt, `0` = no timer (0 to 300) |

Order of precedence: `Config.Defaults` < preset < explicit options. On the server, skill perks and lockpick condition are applied on top (section 8).

The pick range is -90 to +90 degrees; a fresh random sweet spot is chosen every attempt. The cylinder's allowed travel scales from 100% inside the sweet spot down to 2% at `maxDistFromSolve`.

**StartAttempt `data` table:**

| Key | Meaning |
|---|---|
| `preset`, `options` | Difficulty, as above |
| `coords`, `radius` | `vector3` the player must stay near (checked at start and at result); `radius` defaults to `Config.Server.DefaultRadius` |
| `alert` | `false` = never alert lawmen; a number 0-1 = alert chance; omitted = `Config.Alert` chances |
| `noItem` | `true` = do not require or wear the lockpick item for this attempt |

**Outcomes:** `'success'`, `'fail'` (pick broken, time up, rejected solve) or `'cancel'` (Esc/✕/B, death, disconnect, timeout, busy).

## 3. Server exports
| Export | Parameters | Returns |
|---|---|---|
| `StartAttempt(src, data, cb)` | player id, `data` table, `cb(success, reason)` | `true, ticketId` or `false, reason`. If it returns `false`, `cb` is also called with `(false, reason)` |
| `CancelAttempt(src)` | player id | `boolean` (an attempt was cancelled) |
| `HasActiveAttempt(src)` | player id | `boolean` |

`cb` reasons: `success`, `fail`, `cancel`, `too_fast`, `too_far`, `expired`, `dropped`, `stopped`, `cancelled`, and for refusals `no_player`, `busy`, `cooldown`, `no_item`, `too_far`.

## 4. Client exports
| Export | Parameters | Returns |
|---|---|---|
| `Lockpick(options)` | options table (optional, `preset` allowed) | `success` (boolean), `outcome`. Blocks until the attempt ends; call from a thread or event handler |
| `IsLockpicking()` | none | `boolean` |
| `CancelLockpick()` | none | nothing. Closes the UI; the caller receives `false, 'cancel'` |

These client-only calls are **not** server-validated. Use `StartAttempt` for anything that matters.

## 5. Events and callbacks
| Event | Side | Parameters |
|---|---|---|
| `rsg-lockpick:client:openLockpick` | client (local only) | `callback(success, outcome)`, `options` (optional) |
| `rsg-lockpick:client:ticketStart` | client (from server) | internal: `ticketId`, resolved options |
| `rsg-lockpick:client:ticketCancel` | client (from server) | internal |
| `rsg-lockpick:server:ticketResult` | server (from client) | internal: `ticketId`, `outcome`; validated against the player's own active ticket |
| `rsg-lockpick:server:finished` | server (local) | `src, success, data`. Fired after every server-issued attempt, for logging or extra hooks |

`openLockpick` is registered with `AddEventHandler`, so the server cannot trigger it remotely. Its callback is called exactly once per request: success, failure, cancel, death, resource stop, or refusal because an attempt is already open.

NUI callbacks (internal): `result` (`{ token, success }`), `exit`, `sfx` (`{ name }`).

## 6. Integration examples
```lua
-- Door or container script, server side
RegisterNetEvent('myres:server:tryLockpick', function(doorId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local door = Doors[doorId]                       -- your own server data
    if not door or door.unlocked then return end     -- your own state checks

    exports['rsg-lockpick']:StartAttempt(src, {
        preset = door.difficulty or 'medium',
        coords = door.coords, radius = 3.0,
    }, function(success, reason)
        if success then
            door.unlocked = true                     -- act ONLY here, on the server
            -- tell clients / grant loot
        end
    end)
end)
```
```lua
-- React to every attempt (logging, stats, extra alerts)
AddEventHandler('rsg-lockpick:server:finished', function(src, success, data)
    -- data is the table the starter passed to StartAttempt
end)
```
Per-door difficulty in rsg-doorlock, or safes and chests in other scripts, is just a matter of the owning script calling `StartAttempt` with its own preset and coordinates; this resource does not modify other resources.

## 7. Saving and persistence
Nothing is saved by this resource. Lockpick condition is stored by rsg-inventory in the item's `info.quality`; skill XP is stored by rsg-skills.

## 8. Security model
**What a server-issued attempt (`StartAttempt`) enforces**
- The player must exist, have no other open attempt, be past the cooldown and (when `coords` is given) be within range; the lockpick item is required unless `noItem` is set.
- Difficulty is computed on the server: preset + caller options, then skill perks (wider sweet spot, less damage, extra picks), then pick condition (worse pick = more damage), then clamped to `Config.Limits`.
- One single-use ticket per player. A result is accepted only for that player's own ticket id, before it expires (`Server.TicketTTL`), and never twice.
- A solve reported faster than `Server.MinSolveTime` on the server clock is converted to a failure, as is a solve reported when the player has moved out of range.
- Wear, breakage, XP and lawman alerts happen on the server, with amounts and chances from config only. A cancel never wears the item, gives XP or alerts.
- Tickets are cleaned up on disconnect, timeout and resource stop.

**What it cannot enforce**
The minigame itself runs on the client. A modified client can still report `success` after the minimum time, from the right place, holding the item, and the server cannot see the game. The ticket system stops unsolicited results, replays, instant solves and remote calls; it does not make cheating impossible. Keep stakes proportionate: add your own rate limits, logging (`rsg-lockpick:server:finished`) and ban rules for high-value targets.

**Client-only calls** (`Lockpick`, the event) are trivially fakeable. Never grant rewards, unlock doors or touch money or items from their result alone.

**Other checks in the client**: one attempt at a time, session token on NUI results, solves faster than `Config.MinSolveTime` become failures, overrides clamped to limits, attempt cancelled on death and resource stop, NUI focus always released. The sweet spot is regenerated on every attempt.

## 9. Database
None.

## 10. Server owner guide
- **Language**: `setr rsg:locale de` (any of the 11 codes) in `server.cfg`.
- **Easier or harder**: edit `Config.Defaults` or `Config.Presets`, or have scripts pass a preset per lock.
- **Lockpick item**: set `Config.Item.Name` to your item; set `Config.Item.Enabled = false` to turn off the requirement, wear and breakage entirely.
- **Wear tuning**: `Item.Wear.Success`, `Item.Wear.Fail` (quality points, 100 = new) and `Item.Wear.BreakChanceOnFail`. A stack of picks shares one quality; when a pick breaks, the next one in the stack starts at 100.
- **Skill**: the *lockpicking* skill registers itself in rsg-skills at start (and again when rsg-skills restarts). Edit `Config.Skill.Definition.perks` for the level curve. Add `perk_lockpick_sweet_spot`, `perk_lockpick_pick_damage` and `perk_lockpick_extra_pick` to rsg-skills' locales for readable names.
- **Reputation**: a script that knows the lock is a crime passes `reputation = { action = 'theft', region = 'valentine' }` in the `StartAttempt` data. On a successful attempt (not on a failure or cancel) the server calls `exports['rsg-reputation']:ApplyAction(src, action, region)`, so the honor and standing numbers come from rsg-reputation's `Config.Actions`. `region` is optional (without it only honor changes) and must be a region id from rsg-reputation. Only actions listed in `Config.Reputation.Actions` (`theft`, `robbery`) are accepted; `Config.Reputation.DefaultAction` applies to successful attempts that pass nothing (default `nil`). Skipped when rsg-reputation is not started. The data comes from the calling server script, never from a client.
- **Alerts**: `Config.Alert`. They go to on-duty players whose job type is `Config.Alert.JobType` (`leo`), through rsg-lawman's `rsg-lawman:client:lawmanAlert`.
- **Push-to-talk**: keep `Config.AllowPushToTalkWhileOpen = true`; add more controls to `Config.PushToTalkControls` if needed.
- **Sounds and animation**: `Config.Sounds` can be edited or disabled; `Config.Animation` is off by default (see troubleshooting).

## 11. Troubleshooting
| Symptom | Cause / fix |
|---|---|
| UI text shows keys or is empty | `rsg-core` started after this resource, or a missing locale file. Check `ensure` order and `rsg:locale` |
| `StartAttempt` returns `no_item` | Player has no `Config.Item.Name` item. Console warns at start if the item is missing from `RSGCore.Shared.Items` |
| Attempt refused with `cooldown` or `busy` | `Server.Cooldown` not elapsed, or the player already has an open attempt |
| Skill does not appear in rsg-skills | `Config.Skill.Enabled = false`, rsg-skills not started, or it started before this resource; restart rsg-skills or this resource |
| Perk names show as raw keys | Add `perk_lockpick_*` keys to rsg-skills' locales |
| No lawman alerts | rsg-lawman not started, no on-duty player with the configured job type, `alert = false` on the call, or the chance roll / `MinGap` blocked it |
| No sound | The soundset may not be available at that moment on your build; change the entry in `Config.Sounds` |
| Animation looks wrong | Expected: it is a door-handle clip. Leave `Config.Animation.Enabled = false` or change `Dict`/`Name` |
| Gamepad does nothing | Set `Config.Controller = true`; the UI uses the standard Gamepad API layout, so non-standard pads may not map |
| Can't talk while the UI is open | `Config.AllowPushToTalkWhileOpen` is `false`, or your voice resource uses another control; add it to `PushToTalkControls` |
| Old script uses `lockpickCallback` or the `callback` NUI event | Removed in 3.0.0; use the event or exports above |
| Console: `reported a solve in N ms, counted as a failure` | A result arrived faster than `Server.MinSolveTime`; likely a cheat or a script bug |

Support: https://rexshack.tebex.store
