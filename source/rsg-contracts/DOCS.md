# rsg-contracts 3.0.0 documentation

Contents: files, lifecycle, events and callbacks, persistence, security, database, troubleshooting.

## Files
- `server/server.lua`: all rules, money, items and expiry
- `server/database.lua`: automatic tables (same schema as `install.sql`)
- `client/client.lua`: window, `/contracts`, office targets
- `html/`: window; `shared/config.lua`: settings

## Lifecycle
`offered` → `active` → `closed` (supply orders). Jobs: `active` → `review` → `closed`, or `review` → `disputed` → `closed`.
The buyer can approve a job while it is still active.
Outcomes: `offer_expired`, `offer_declined`, `offer_withdrawn`, `delivered`, `approved`, `review_expired`, `deadline_missed`, `gave_up`, `mutual_cancel`, `ruled_worker`, `ruled_buyer`, `dispute_expired`.
Expiry is checked every 30 seconds. Deadlines use real time, so server downtime counts.

## Events and callbacks
No exports.

| Name | Kind | Purpose |
|---|---|---|
| `rsg-contracts:server:getState` | callback | Contracts, claims, nearby server IDs |
| `rsg-contracts:server:getItems` | callback | Orderable items (`value`, `label`) |
| `rsg-contracts:server:getPaper` (id) | callback | Contract details for a paper holder |
| `rsg-contracts:server:action` (name, data) | callback | `create`, `sign`, `decline`, `deliver`, `finish`, `approve`, `dispute`, `giveup`, `cancel`, `rule`, `collect` |
| `rsg-contracts:client:paper` (id) | net event | Shows a paper copy |
| `rsg-contracts:server:closed` (contract, outcome) | server event | For logging, tax or reputation scripts. Money fields are `pay_cents` and `deposit_cents` |

## Persistence
Open contracts are loaded when the resource starts. Closing a contract writes the status and every payout (claims) in one database transaction. A claim row is deleted before it is paid, and written back if the payment fails.

## Security
- Every action is checked on the server: the player's role, contract status, distance, limits, items and cash. Dead, downed or cuffed players can't act.
- Changes run one at a time, so two requests can't act on the same contract together. Actions are rate limited.
- Arbiters must be on duty and can't rule on their own contract.
- Player text is length limited and displayed as plain text. SQL is parameterised.
- Player data is saved after money or items move.
- **Known limits:** a server crash between a database write and a player save can lose or repeat a transfer. A crash between deleting a claim and paying it loses that claim.
- **Abuse to watch:** if no arbiter is available, a buyer can dispute honest work and get part of the payment back through `DisputeDefault`. Use `worker` if that is a problem on your server.
- Players can use contracts to move money or goods to each other. Closed contracts are logged through `rsg-log` (`default` channel).
- If you enable honor rewards, two players could farm them. `HonorMinPay` only makes this harder.

## Database
`rsg_contracts` holds contracts (closed ones are kept as history). `rsg_contract_claims` holds money and items waiting for collection (`cents`, or `item`, `amount` and JSON `info`). See `install.sql`.
Delivered items keep their metadata. Item decay stored as metadata may continue while goods wait; check this against your inventory settings.

## Troubleshooting
| Problem | Check |
|---|---|
| Window doesn't open | Server console for database errors; the resource ignores requests until its tables load |
| No one to select | Players must be within `SignDistance` before opening the New contract tab |
| Deliver or Collect greyed out | Stand within `OfficeDistance` of an office, then reopen the window |
| Not enough goods | Fully decayed items don't count |
| No paper copy | `contract_paper` is in the shared items and there is inventory room |
| No dispute tab | Your job type or name is in the arbiter settings and you are on duty |

Support: https://rexshack.tebex.store
