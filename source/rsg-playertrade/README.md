# rsg-playertrade

**Version:** 3.0.0 · **Requires:** `rsg-core`, `rsg-inventory` 3.6.0 or newer, `rsg-target` · **ox_lib:** not required

Secure two-way trading of items and cash between players. Technical details: [DOCS.md](DOCS.md).

## Features
- Side-by-side trade window: your items, your offer and their offer
- Items, stack quantities and cash; quality and weapon serial numbers are shown
- Two steps: both press **Ready**, wait a short lock delay, then both press **Confirm**
- Any change to either offer cancels both players' approval, and the other player is warned
- All-or-nothing swap on the server: if anything can't be moved, nothing moves
- Search box for your items; **Ready** pauses briefly when the other offer changes
- Declined requests have a cooldown
- Cancels if a player walks away, dies, is cuffed or disconnects, or after a time limit
- Requests don't open any window or take mouse focus until accepted
- Push-to-talk works while the window is open
- No database tables, items or images to install

## Installation
1. Update `rsg-inventory` to 3.6.0 or newer.
2. Put `rsg-playertrade` in `resources/[framework]`.
3. Add `ensure rsg-playertrade` to `server.cfg` after `rsg-core`, `rsg-target` and `rsg-inventory` (not needed if you already ensure the whole `[framework]` folder).
4. Restart the server.

## How to use
1. Stand next to a player, target them and choose **Offer Trade**, or type `/trade [server id]`.
2. They type `/tradeaccept`, or target you and choose **Offer Trade**. `/tradedecline` refuses.
3. Click an item to offer it (choose a quantity for stacks). Click it in your offer to remove it. Type a cash amount and press **Set**.
4. Both press **Ready**. Check the offers, then both press **Confirm**.
5. **Esc**, **Cancel** or the close button ends the trade.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `UseTarget` | `true` | rsg-target option on players |
| `Command` | `'trade'` | Request command (`false` disables) |
| `AcceptCommand` | `'tradeaccept'` | Accept command. Needed unless `UseTarget` or `Command` is on |
| `DeclineCommand` | `'tradedecline'` | Decline command |
| `Distance` | `3.0` | Metres to request and accept |
| `CancelDistance` | `5.0` | Metres at which a trade cancels |
| `RequestTimeout` | `20` | Seconds a request lasts |
| `RequestCooldown` | `5` | Seconds between requests |
| `DeclineCooldown` | `60` | Seconds before a declined player can ask the same person again |
| `TradeTimeout` | `300` | Seconds before a trade cancels |
| `LockSeconds` | `3` | Delay before Confirm unlocks |
| `MaxOfferSlots` | `12` | Item stacks per offer |
| `AllowCash` | `true` | Allow cash in offers |
| `MaxCash` | `100000` | Maximum cash per offer, in dollars |
| `BlacklistItems` | `{}` | Item names that can't be traded |
| `BlacklistTypes` | `{}` | Item types that can't be traded |
| `ImagePath` | rsg-inventory images | Item image folder |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working |
| `PushToTalkControls` | `INPUT_PUSH_TO_TALK` | Controls left enabled |

Bloodmoney can't be traded. The blacklists affect this resource only, not the inventory's Give option.

## Developer example
```lua
AddEventHandler('rsg-playertrade:server:completed', function(sides)
    for _, side in ipairs(sides) do print(side.citizenid, side.offer.cents, #side.offer.items) end
end)
```

## Locales
en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru. Set with `setr rsg:locale "de"`.

## Support
Support: https://rexshack.tebex.store
