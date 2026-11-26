# rsg-contracts 3.0.0

Written contracts between players, with the payment held by the server.
Needs `rsg-core`, `rsg-inventory`, `rsg-target` and `oxmysql`. `rsg-reputation` is optional.
See [DOCS.md](DOCS.md) for technical details.

## Features
- **Supply orders:** items are checked and handed over at a post office, and the contract completes automatically.
- **Paid jobs:** the worker marks the job finished and the buyer approves or disputes it.
- Payment is taken when the offer is sent. The worker's optional deposit is taken at signing.
- Real-time deadlines, mutual cancellation, giving up, and disputes decided by on-duty lawmen (configurable).
- Payments, refunds and delivered goods wait at a post office, so nobody has to be online to be paid.
- A paper copy item for both players.

## Install
1. Put `rsg-contracts` in your `[framework]` folder.
2. Check that `contract_paper` is in `rsg-core/shared/items.lua`:
```lua
contract_paper = { name = 'contract_paper', label = 'Contract Paper', weight = 10, type = 'item', image = 'contract_paper.png', unique = true, useable = true, shouldClose = true, description = 'A signed contract', category = 'document' },
```
3. Optionally add `contract_paper.png` to `rsg-inventory/html/images/`.
4. `ensure rsg-contracts` after its dependencies.
5. Tables are created automatically. To install them manually, set `Config.AutoDatabase = false` and import `install.sql`.

## How to use
1. Stand next to the other player, type `/contracts`, open **New contract** and send the offer. They are listed by server ID.
2. They type `/contracts` and choose **Sign** or **Decline**. You must still be standing together to sign.
3. **Supply order:** the worker goes to a post office, opens `/contracts` and chooses **Deliver goods**. All goods are delivered at once.
4. **Paid job:** the worker chooses **Mark finished**. The buyer then chooses **Approve and pay** or **Dispute**.
5. At a post office, use the **Contract office** target, then **Collect all**.

| Situation | Result |
|---|---|
| Offer declined, withdrawn or expired | Buyer gets the payment back |
| Delivered or approved | Worker gets the payment and their deposit |
| Buyer doesn't respond to a finished job | Worker is paid after `ReviewHours` |
| Deadline missed or worker gives up | Buyer gets the payment and the deposit |
| Both agree to cancel | Each gets their own money back |
| Dispute: worker wins / buyer wins | The winner gets the payment and the deposit |
| Dispute not decided in time | `DisputeDefault` (by default the payment is split and the deposit returned) |

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| VersionCheck / AutoDatabase | true | Update check / create tables |
| Command | `contracts` | Opens the window; false disables it, leaving only the office targets |
| Offices | 8 post offices | Delivery and collection points |
| TargetRadius / OfficeDistance / SignDistance | 1.5 / 4.0 / 5.0 | Metres |
| MinPay / MaxPay / MaxDeposit | 1 / 5000 / 1000 | Dollars |
| MinHours / MaxHours | 1 / 168 | Deadline range in real hours |
| MaxQuantity / MaxOpen | 500 / 5 | Order size / open contracts written per player |
| MaxTitle / MaxDetails | 60 / 500 | Text length (keep MaxTitle at 255 or less) |
| OfferHours / ReviewHours / DisputeHours | 1 / 48 / 72 | Timeouts |
| DisputeDefault | `split` | `split`, `worker` or `buyer` |
| ArbiterJobTypes / ArbiterJobs | `leo` / none | Who decides disputes (on duty) |
| BlacklistItems / BlacklistTypes | cash, paper / weapons | Items that can't be ordered |
| PaperItem | `contract_paper` | false disables paper copies |
| HonorCompleted / HonorBroken / HonorMinPay | 0 / -2 / 25 | rsg-reputation honor |
| AllowPushToTalkWhileOpen / PushToTalkControls | true | Push-to-talk while the window is open |

## For developers
```lua
AddEventHandler('rsg-contracts:server:closed', function(contract, outcome)
    print(contract.id, outcome)
end)
```

## Languages
en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru

Support: https://rexshack.tebex.store
