# rsg-playertrade 3.0.0 — Documentation

## Contents
1. [Architecture](#1-architecture)
2. [Dependencies and installation](#2-dependencies-and-installation)
3. [Trade flow](#3-trade-flow)
4. [Data formats](#4-data-formats)
5. [Exports](#5-exports)
6. [Events](#6-events)
7. [NUI](#7-nui)
8. [Commands](#8-commands)
9. [Integration examples](#9-integration-examples)
10. [Configuration](#10-configuration)
11. [Security model](#11-security-model)
12. [Performance](#12-performance)
13. [Persistence, logging and database](#13-persistence-logging-and-database)
14. [Locales](#14-locales)
15. [Server owner guide](#15-server-owner-guide)
16. [Troubleshooting](#16-troubleshooting)

## 1. Architecture
| File | Job |
|---|---|
| `fxmanifest.lua` | Manifest and dependencies |
| `shared/config.lua` | Settings (shared, so players can read them) |
| `server/server.lua` | Requests, sessions, offers, approval, watchdog. Authoritative for everything |
| `client/client.lua` | NUI focus, push-to-talk whitelist, NUI callbacks, rsg-target option |
| `html/index.html`, `style.css`, `app.js` | Trade window. Display and input only |
| `locales/*.json` | Player-facing text |

This resource never moves items itself. The swap is `exports['rsg-inventory']:TradeItems`.

## 2. Dependencies and installation
`rsg-core`, `rsg-inventory` **3.6.0 or newer**, `rsg-target`. Optional: `rsg-log`. No ox_lib, oxmysql or database.

```cfg
ensure rsg-core
ensure rsg-inventory
ensure rsg-target
ensure rsg-playertrade
```
`rsg-inventory` 3.6.0 also unequips traded weapons when they are holstered. This relies on `rsg-weapons` (`GetUsedWeapons`); without it, only a weapon in the hands is removed.

## 3. Trade flow
```
request ──accept──> editing <──any offer change── ready / confirm
                       │  both Ready
                       v
                    locked (LockSeconds) ──both Confirm──> TradeItems ──> closed
```
1. **Request.** One incoming request per player, held for `RequestTimeout` seconds. Requesting someone who has already requested you accepts it. Both are told if it expires.
2. **Session.** Both inventory windows are closed and the trade window opens.
3. **Offers.** Each change raises `rev` and clears Ready and Confirm for both.
4. **Ready.** Carries the `rev` the player saw. Both offers can't be empty (one side may give a gift). Un-ready also clears both Confirms.
5. **Lock.** Once both are Ready, Confirm is accepted only after `LockSeconds`.
6. **Confirm.** When both confirm, the server rechecks character, condition and distance, then calls `TradeItems`.
7. **Result.** On success the session ends. If refused, nothing moves, the window stays open and approval is cleared. If the call errors, the session ends, players are told to check their items, and the console shows both citizenids.

A session also ends when a player cancels, disconnects, logs out, dies, enters last stand, is cuffed, moves beyond `CancelDistance`, changes routing bucket, the time limit passes or the resource stops. The client also cancels if the ped is dead or the pause menu opens.

## 4. Data formats

### Offer (passed to `TradeItems` and the completed event)
```lua
{
    items = {
        { slot = 3, name = 'bread', amount = 2, info = { quality = 88 } },
    },
    cents = 1250, -- cash in whole cents: $12.50
}
```

### Session (internal, server memory)
```lua
{
    ids = { requesterSrc, accepterSrc },
    names = { [src] = 'First Last' }, cids = { [src] = 'ABC12345' },
    offers = { [src] = { items = { [slot] = { name, label, image, amount, info } }, cents = 0 } },
    rev = 1, ready = { [src] = true }, confirmed = { [src] = true },
    lockedAt = nil,  -- game timer when both became ready
    started = 0,     -- game timer, for TradeTimeout
    seen = {},       -- [src] = signature of the item list last sent
    closed = nil,
}
```

### State (sent to each client)
```lua
{
    rev = 4, id = 7, name = 'Arthur Morgan',     -- the other player
    inventory = { ItemView, ... },               -- your tradable items
    cash = 24550,                                -- your cash, cents
    mine = { items = { ItemView, ... }, cents = 1250 },
    theirs = { items = { ItemView, ... }, cents = 0 },
    ready = { mine = true, theirs = false },
    confirmed = { mine = false, theirs = false },
    lockMs = 0,                                  -- ms until Confirm unlocks
}
-- ItemView = { slot, name, amount, label, image, quality?, serie? }
```

## 5. Exports
| Export | Side | Parameters | Returns |
|---|---|---|---|
| `IsTrading(src)` | server | player server id | `boolean` |

```lua
if exports['rsg-playertrade']:IsTrading(src) then return end -- e.g. before teleporting or jailing menus
```

## 6. Events

### Server net events (client → server)
| Event | Arguments | Server checks | Minimum gap |
|---|---|---|---|
| `rsg-playertrade:server:request` | `targetId` | both available, in range, not busy, request and decline cooldowns | 1000 ms, then `RequestCooldown` |
| `rsg-playertrade:server:setItem` | `slot, amount, name` (0 removes) | real stack, name, quantity, tradable, slot limit | 100 ms |
| `rsg-playertrade:server:setCash` | `dollars` | finite, 0 to `MaxCash`, affordable | 250 ms |
| `rsg-playertrade:server:ready` | `rev, state` | current `rev`, offers still valid, not both empty | 250 ms (un-ready: none) |
| `rsg-playertrade:server:confirm` | `rev` | current `rev`, both ready, lock elapsed | 250 ms |
| `rsg-playertrade:server:cancel` | none | has a session | none |

Events inside the minimum gap, or carrying an old `rev`, are dropped.

### Client events (server → client)
| Event | Arguments |
|---|---|
| `rsg-playertrade:client:open` | `state` |
| `rsg-playertrade:client:update` | `state` |
| `rsg-playertrade:client:close` | none |

### Server local event
`rsg-playertrade:server:completed` fires once after a successful swap. It is not a net event, so clients can't trigger it. The first entry is the player who sent the request.
```lua
{
    { source = 1, citizenid = 'ABC12345', offer = Offer }, -- what this player GAVE
    { source = 2, citizenid = 'XYZ98765', offer = Offer },
}
```

### Events used
`playerDropped`, `RSGCore:Server:OnPlayerUnload`, `RSGCore:Client:OnPlayerUnload`, `onResourceStop`. No callbacks or usable items.

## 7. NUI
| Lua → NUI (`action`) | Fields |
|---|---|
| `open` | `state, labels, imagePath, allowCash, lockSeconds` |
| `update` | `state` |
| `close` | none |

| NUI → Lua callback | Body |
|---|---|
| `setItem` | `{ slot, amount, name }` |
| `setCash` | `{ amount }` (dollars) |
| `ready` | `{ rev, state }` |
| `confirm` | `{ rev }` |
| `cancel` | `{}` |

Window behaviour: the search box filters your items by label or serial; clicking a single item adds or removes it; stacks open a quantity box (0 removes); Esc closes that box first, then cancels. When the other offer changes, their column flashes and **Ready** is disabled for `LockSeconds`. This pause is a window-side aid; the server protection is the `rev` check and lock delay. Focus goes through `applyNuiFocus`, with the push-to-talk whitelist running only while open.

## 8. Commands
| Command | Permission | Use |
|---|---|---|
| `/trade [id]` | everyone | Send a request |
| `/tradeaccept` | everyone | Accept your request |
| `/tradedecline` | everyone | Decline it |

Names come from the config; `false` disables one. If accept or decline is disabled, the request message shows `-` in its place. Players can still accept by targeting or `/trade`-ing the requester, if either is enabled.

## 9. Integration examples

### Audit or reputation after a trade (server)
```lua
AddEventHandler('rsg-playertrade:server:completed', function(sides)
    for i, side in ipairs(sides) do
        local other = sides[3 - i]
        print(('%s gave %s $%.2f and %d stack(s)'):format(
            side.citizenid, other.citizenid, side.offer.cents / 100, #side.offer.items))
        for _, item in ipairs(side.offer.items) do
            if item.info.serie then print(('  weapon %s now with %s'):format(item.info.serie, other.citizenid)) end
        end
    end
end)
```
The event reports a finished trade; it can't veto one.

### Offer a trade from your own menu (client)
```lua
local targetId = GetPlayerServerId(targetPlayerIndex)
TriggerServerEvent('rsg-playertrade:server:request', targetId)
```

### Block items from being traded (`shared/config.lua`)
```lua
Config.BlacklistItems = { sheriffbadge = true } -- by item name (use your own item names)
Config.BlacklistTypes = { weapon = true }       -- by item type
```

### Your own swap flow (server)
For scripts with their own consent screen. `TradeItems` does **not** check consent, distance or cooldowns, and ignores this resource's blacklists.
```lua
local item = exports['rsg-inventory']:GetItemBySlot(a, 3)
if not item then return end
local ok, reason, failedId = exports['rsg-inventory']:TradeItems(a, b,
    { items = { { slot = 3, name = item.name, amount = 1, info = item.info } }, cents = 0 },
    { items = {}, cents = 500 }) -- b pays $5
```
| `reason` | Meaning | Message shown by rsg-playertrade |
|---|---|---|
| `no_player` | a player is missing or both ids match | trade failed |
| `incapacitated` | dead, last stand or cuffed | trade failed |
| `offer_changed` | a stack no longer matches, is cash, or the offer is malformed | item changed |
| `no_cash` | can't afford the cash | cash could not be paid |
| `cash_unavailable` | cash items don't match the balance | cash could not be paid |
| `no_room` | weight, slot, stack or carry limit | can't carry |

## 10. Configuration
| Option | Default | Description |
|---|---|---|
| `UseTarget` | `true` | rsg-target **Offer Trade** option |
| `Command` / `AcceptCommand` / `DeclineCommand` | `'trade'` / `'tradeaccept'` / `'tradedecline'` | Command names, or `false` |
| `Distance` | `3.0` | Metres to request and accept |
| `CancelDistance` | `5.0` | Metres at which a session ends; keep above `Distance` |
| `RequestTimeout` | `20` | Seconds a request lasts |
| `RequestCooldown` | `5` | Seconds between one player's requests |
| `DeclineCooldown` | `60` | Seconds before a declined player can ask the same character again |
| `TradeTimeout` | `300` | Session time limit in seconds |
| `LockSeconds` | `3` | Delay before Confirm, and the Ready pause after a change |
| `MaxOfferSlots` | `12` | Stacks per offer |
| `AllowCash` | `true` | Show the cash box and accept cash |
| `MaxCash` | `100000` | Dollars per offer |
| `BlacklistItems` | `{}` | `{ item_name = true }` |
| `BlacklistTypes` | `{}` | `{ item_type = true }` |
| `ImagePath` | `nui://rsg-inventory/html/images/` | Item images |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled |

## 11. Security model
- Offers live on the server. Item data, quantities, tradability and cash come from the player's real data.
- An offered stack's metadata must be identical at the swap.
- `rev` plus the lock delay stop an offer changing under an approval.
- The session is removed before the completed event fires, so a trade can't be replayed.
- Distance, routing bucket, condition and character are checked on the server.
- Offline, unavailable and out-of-range targets get the same message from a new request.
- Only the `ItemView` fields are sent to the other player. **Other metadata isn't displayed** (for example custom contents or weapon attachments), although it travels with the item and is protected from changes during the trade.
- The window builds text with `textContent`.
- The swap is all-or-nothing in memory. Both players are saved straight afterwards as separate database writes; a server crash between them isn't covered.
- Weapons: attachments, names and engravings stored on the item move with it. Weapon database records such as `GetWeaponRecord` in rsg-weaponcomp are not reassigned by a trade.
- Unequipping happens on the owner's client, as with all rsg-weapons equipping.
- Blacklists apply to this resource only, not to Give, drops or stashes.

### What other scripts should check
Use `IsTrading(src)` before opening another focused window or moving a player. Treat `completed` as a report, and use your own checks if you call `TradeItems`.

## 12. Performance
- Idle: one server thread wakes every 500 ms with nothing to loop; the client checks every 250 ms.
- Per open trade: the watchdog reads each player once every 500 ms and sends an update only when offers, item quantities, quality or cash change.
- While the window is open with push-to-talk on, the client runs a per-frame control block.

## 13. Persistence, logging and database
No tables and nothing saved by this resource. Requests, sessions and decline cooldowns are lost on restart; open trades close with nothing moved. `rsg-inventory` saves both players after a swap.

Logs go to `rsg-log` channel `playerinventory`: one **Player trade** summary (names, citizenids, items, weapon serials, cash), plus rsg-inventory **Trade** lines per stack and payment.

## 14. Locales
`en` (master), `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Window labels start with `ui_`. `request_received` takes four `%s`: name, id, accept command, decline command. Set the language with `setr rsg:locale "de"`.

## 15. Server owner guide
- **Gift-free servers or bound items:** use the blacklists.
- **Cash through banks only:** set `AllowCash = false`.
- **Slower, safer trades:** raise `LockSeconds`.
- **Spam reports:** raise `RequestCooldown` and `DeclineCooldown`.
- **Disputes:** search rsg-log for **Player trade** by citizenid or weapon serial.

## 16. Troubleshooting
| Problem | Fix |
|---|---|
| Console `TradeItems errored` | Check `rsg-inventory` is 3.6.0+ and started, read the error, then check both citizenids' items and cash |
| "The cash could not be paid" | Balance and cash items differ, or the cash was spent. Relogging resyncs them |
| "Someone can't carry the items" | Weight, slots or `Config.ItemLimits` in rsg-inventory. Cash items count towards slots |
| "No player found" when they're nearby | They are out of range, in another routing bucket, dead or cuffed |
| "Wait a moment" | Request or decline cooldown |
| No target option | `UseTarget`, and start `rsg-target` first |
| Item missing from the list | Cash, blacklisted or hidden by the search box |
| Offer keeps resetting | The item is changing, for example through decay |
| Traded gun still on the character | Check rsg-inventory 3.6.0 client files are updated and `rsg-weapons` is running |

Support: https://rexshack.tebex.store
