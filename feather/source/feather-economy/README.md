# Feather Economy

Authoritative monetary accounting for the Feather Framework. Economy owns
currencies, accounts, balances, an immutable balanced journal, idempotent
monetary operations and a transactional outbox. Gameplay resources own prices,
menus, fulfillment and the reason money moves; they call Economy exports and
never keep or change balances themselves.

## Status

Current version: 0.5.2 (Contract 1). Adds scoped Stables horse-trade seller payouts and payment reversals. Paid horse/package trades passed Stables live acceptance; refund fault injection remains an offline test. The general live acceptance record below dates from 2026-10-13.

### Passed

Recorded on the development server:

- Foundation 6/6, account contract 7/7, transfer contract 7/7, journal audit
  5/5 (pending=0 at every checkpoint).
- Supply with idempotent replay and payload-mismatch rejection; balanced
  issue/destroy.
- Concurrency: two competing spends against one balance commit exactly once;
  the other fails with `insufficient_funds`. Injected failure after the balance
  writes rolls back the balances and the journal.
- Shop acceptance: purchases, insufficient funds, payment reversal, treasury
  settlement, worker recovery across a full server restart and with the buyer
  offline, competing purchases, and delivery racing a refund.
- Treasury provisioning 6/6 with stable identities across restart; settlement
  account-type gate 8/8.
- Production surface (`EconomyReleaseContractSmokeTest`) 7/7 on 2026-09-18:
  DevMode off, supply policy on, development commands absent.
- HUD wallet reads and Character wallet provisioning.
- Ownership check: 0 errors over every resource the server starts.

Release gates, passed on the development server (DevMode) on 2026-10-13:

- `EconomyReleaseGateSmokeTest` 23/23 (read-only): migration rerun and
  checksums, checksum mismatch, history limits, offsets and ordering, journal
  integrity, outbox backlog, and supply policy failing closed (the live Core
  policy answered `service_forbidden`).
- `EconomyMigrationFaultTest` 8/8: invalid shape, checksum mismatch and a
  failing migration apply nothing; a pending migration applies once.
- `EconomyHistoryPaginationTest` 10/10.
- `EconomyRestartTest` 10/10 across a full server restart: balance, journal,
  pending outbox events delivered, idempotent replay, payload conflict.
- Startup with a failing migration: `state=failed`, `migration_failed` naming
  the migration and statement, nothing kept; dependents fail to start.
- Migration 007 applied on an existing install.

Production profile (DevMode off) on 2026-10-13, all read-only: release
contract 7/7, release gate 23/23, foundation 6/6, account contract 7/7, bank
contract 14/14, transaction read 9/9, journal audit 5/5 (pending=0), and
ownership check 0 errors.

### Open

- Admin money commands target only connected characters; offline correction
  and Admin Economy screens are not available yet.
- Not implemented: account closure, holds, credit, `GetBalance`,
  `ListTransactions`, account-created/closed events.
- History is offset-paged: entries posted between two page reads shift later
  pages. Each entry carries `sequence` so a consumer can drop repeats; cursor
  paging is not implemented.
- Economy has no backup tooling. Back up all `economy_*` tables together, in
  one consistent snapshot.
- Clean deployment from a recipe with merged upstream resources has not been
  validated.

## Fresh install

1. Requirements: MySQL 8.0 or MariaDB 10.6 or later (single-statement DDL is
   atomic, and the release gate uses window functions), `feather-mysql`,
   `feather-core`, and a Core policy provider (for example `feather-admin`)
   for currency supply.
2. Start order:

   ```text
   ensure feather-mysql
   ensure feather-core
   ensure feather-economy
   ```

3. Keep `Config.DevMode = false` and `Config.Authorization.enabled = true`.
4. Add each consumer to the access groups it needs in `config.lua` (see
   Access groups below). Start with none: an unlisted resource can read
   nothing and move nothing.
5. Grant `economy.currency.issue` and `economy.currency.destroy` in the policy
   provider only to resources that must create or destroy currency (for
   example staff money commands, or a bank's one-time balance import). Trust
   lists never allow supply on their own.
6. Start the server. The first start creates the tables and applies migrations
   001 to 007. From the console:

   ```text
   EconomyHealthReport
   EconomyFoundationSmokeTest
   EconomyReleaseContractSmokeTest
   EconomyReleaseGateSmokeTest
   ```

   Expect `state=ready`, then every test `done N/N passed`.

Upgrading an existing install applies only the missing migrations. Migration
007 rebuilds `economy_entries` to add a column, which briefly locks the table.
Run it while the server is quiet.

## Contract

All operations use Core's flat result envelope:

```lua
{ ok = true, value = value, meta = optionalTable }
{ ok = false, code = 'stable_code', message = 'Safe summary', details = optionalTable }
```

Amounts are integers in the currency's smallest unit (`dollars` and `gold`
have precision 2, so 2500 is 25.00). Exports are server-only; Cfx supplies the
calling resource, which is checked against `Config.Access`.

```lua
local ready = exports['feather-economy']:AwaitReady(30000)
local capabilities = exports['feather-economy']:GetCapabilities()
local dollars = exports['feather-economy']:GetCurrency('dollars')

local wallets = exports['feather-economy']:EnsureCharacterWallets({
    characterId = characterId
})

local paid = exports['feather-economy']:Transfer({
    fromAccountId = buyerWalletId,
    toAccountId = recipientWalletId,
    currency = 'dollars',
    amount = 2500,
    reasonCode = 'shop.purchase',
    referenceType = 'shop_order',
    referenceId = orderId,
    idempotencyKey = requestId
}, context)
```

| Export | Access group | Purpose |
|---|---|---|
| `GetCapabilities`, `GetHealth`, `AwaitReady`, `GetCurrency`, `ListCurrencies` | none | Lifecycle and currency catalog |
| `GetAccount({ accountId })`, `FindAccountsByOwner({ ownerType, ownerId })`, `GetSystemAccount({ currency, accountType })` | `trustedReaders` | Account and balance reads |
| `GetTransaction({ transactionId })` | `trustedReaders` | One journal transaction, for reconciliation |
| `ListAccountEntries({ accountId, limit, offset })` | `trustedReaders` (see Account history) | Account history |
| `EnsureCharacterWallets({ characterId })` | `trustedProvisioners` | One zero-balance wallet per currency |
| `EnsureOrganizationTreasuries({ organizationId })` | `trustedTreasuryProvisioners` | One treasury per currency for an active organization |
| `EnsureCharacterBankAccounts({ characterId, accountRef })` | `trustedBankProvisioners` | Character bank accounts (see Operated accounts) |
| `EnsureOperatedTreasury({ organizationId })` | `trustedTreasuryOperators` | Bind an organization treasury to the caller |
| `RegisterOperatedReasons({ reasons })` | `trustedBankTransactors` or `trustedTreasuryOperators` | Register the caller's reason codes |
| `Transfer(request, context)` | `trustedTransactors` | Move funds between two accounts |
| `ReversePayment({ transactionId }, context)` | `trustedReversers` | Exact reversal of the caller's own shop payment |
| `Issue(request, context)`, `Destroy(request, context)` | `trustedSuppliers` and a Core policy grant | Create or destroy currency |

Every mutation takes a stable `idempotencyKey` (letters, digits and `._:-`). The
first request binds the key to its payload: an exact retry returns the original
result with `replayed = true`, and a changed payload fails with
`idempotency_conflict`. Retry a timeout with the same key, never a new one.

`context` carries `actorCharacterId` (the character acting), `actorSource` (a
player's server id, if any) and `correlationId`. Economy records them in the
journal.

### Supply

`Issue({ accountId, currency, amount, reasonCode, ... })` moves value from the
currency's system source to the account. `Destroy` moves it from the account to
the system sink. With `Config.Authorization.enabled`, each call asks Core
`Authorize('economy.currency.issue' | 'economy.currency.destroy')` with the
caller as `subject.resource`. Only an explicit allow lets it through. A missing
provider, a denial, an invalid decision or an error raised by the call returns
`authorization_denied`, with `details.policyCode` naming the cause.

### Account history

`ListAccountEntries({ accountId, limit, offset })` returns entries newest first,
in posting order. `limit` is 1 to `Config.Limits.maximumPageSize` (default:
the maximum), and `offset` is 0 to 100000. Each entry has `entryId`,
`sequence`, `transactionId`, `operation`, `currency`, signed `amount`,
`resultingBalance`, `reasonCode`, `referenceType`, `referenceId`,
`sourceResource`, `counterpartyAccountId` and `postedAt`.

History is private. Resources in `privilegedHistoryReaders` read any account.
Other trusted readers read only the accounts they serve: bank transactors read
character bank accounts, and a treasury operator reads the treasury bound to it.
Unknown and foreign accounts return the same `authorization_denied`.

### Transactions

`GetTransaction({ transactionId })` returns `operation`, `status`, `currency`,
`amount` (the total moved), `reasonCode`, `referenceType`, `referenceId`,
`sourceResource`, `correlationId`, `createdAt`, `postedAt` and `entries`
(`accountId`, signed `amount`). A caller reads only transactions it posted,
unless it is a privileged history reader. Unknown and foreign transactions both
return `transaction_not_found`. Capability feature: `transactionRead`.

## Access groups

`Config.Access` lists resources by name. Feather resources are active in
`config.lua`; known consumers are listed under them, commented out. Uncomment
a resource's line in every group where it appears, add your own the same way,
and restart feather-economy. A resource cannot trust itself; only the config
decides. Grant each consumer only what it uses:

| Group | Allows |
|---|---|
| `trustedReaders` | Account, system account and transaction reads; history within the rules above |
| `trustedProvisioners` | Character wallets |
| `trustedTreasuryProvisioners` | Organization treasuries |
| `trustedBankProvisioners` | Character bank accounts |
| `trustedTransactors` | `Transfer` (v1 rules, or registered reasons) |
| `trustedBankTransactors` | Registering reasons with bank shapes; also needs `trustedTransactors` |
| `trustedTreasuryOperators` | Binding treasuries and registering treasury shapes; also needs `trustedTransactors` |
| `privilegedHistoryReaders` | History and transactions of any account |
| `trustedReversers` | `ReversePayment` |
| `trustedSuppliers` | `Issue` and `Destroy`, still subject to the Core policy |

For example, a HUD needs `trustedReaders`. A shop needs readers,
provisioners, transactors and reversers (plus treasury provisioners if it
settles into business treasuries), but not suppliers. A bank resource
needs readers, provisioners, bank provisioners, transactors, bank transactors
and treasury operators.

## Operated accounts

Economy's v1 transfer rules cover wallets, the system sink and shop settlement
into organization treasuries. Banks and businesses need more movements, but
Economy does not know their reason codes. An operator resource registers its
own codes on every start, and maps each one to movement shapes Economy knows:

```lua
exports['feather-economy']:RegisterOperatedReasons({ reasons = {
    ['bank.deposit'] = 'actor_wallet_to_bank',
    ['bank.withdraw'] = 'bank_to_actor_wallet',
    ['bank.fee'] = 'bank_to_sink',
    ['bank.loan.payout'] = { 'operated_to_wallet', 'operated_to_bank' }
} })
```

| Shape | Movement | Group |
|---|---|---|
| `actor_wallet_to_bank`, `bank_to_actor_wallet` | The acting character's wallet to or from a bank account | bank transactors |
| `bank_to_bank`, `bank_to_sink` | Between bank accounts; bank to the system sink | bank transactors |
| `actor_wallet_to_operated`, `operated_to_actor_wallet` | Acting character's wallet to or from the caller's treasury | treasury operators |
| `operated_to_wallet`, `operated_to_sink` | The caller's treasury to any wallet, or to the sink | treasury operators |
| `bank_to_operated`, `operated_to_bank` | Bank account to or from the caller's treasury | bank transactors and treasury operators |
| `issue_to_bank`, `issue_to_operated` | Create currency into a bank account or the caller's treasury | supply (see below) |

Rules:

- A code belongs to one resource at a time and is released when it stops.
  Codes starting with `shop.` or `economy.` are reserved.
- Re-registering replaces the caller's codes. A rejected registration keeps
  the earlier ones.
- "Acting character" is `context.actorCharacterId`. Without an actor, only a
  movement between one character's own accounts qualifies.
- `EnsureCharacterBankAccounts({ characterId, accountRef })` gives a character
  one bank account per currency for each `accountRef` (for example one per
  branch).
- `EnsureOperatedTreasury({ organizationId })` binds an active organization's
  treasuries to the caller, permanently (migration 006). Every treasury shape
  requires the treasury to be bound to the caller; a treasury bound to another
  resource returns `operator_conflict`.
- Supply shapes create currency only when `Config.OperatorSupply[resource]`
  lists the exact code and the Core policy grants `economy.currency.issue`.
  Nothing destroys from a bank account.

## Payment reversals

`ReversePayment({ transactionId = originalUuid }, context)` reverses the
caller's own committed payment within its configured reversal scope. Legacy
`shop.purchase`/`shop_order` remains supported for existing callers. The
original journal supplies the amount, currency and accounts (system sink or
treasury back to the buyer's wallet). No amount, destination or key can be
chosen: the deterministic key `reversal:<transaction>` allows one refund, also
after restart. The original entries are checked under lock. Closed accounts,
insufficient sink or treasury funds, and wallet limits fail without posting.
The caller must first durably fence delivery as cancelled; Economy does not infer
delivery status.

## Organization treasuries

`EnsureOrganizationTreasuries({ organizationId })` resolves an active
organization through `feather-organizations` at call time (no startup
dependency) and provisions one zero-balance treasury per currency.
Provisioning grants no spending rights. Without an operator binding, a treasury
receives only `shop.purchase` transfers with a UUID `shop_order` reference and
pays out only through payment reversals.

## Migrations

Migrations live in `server/migrations/` and run in id order at startup.
`economy_schema_migrations` records each one with a checksum.

- Never edit an applied migration. A changed checksum stops startup with
  `migration_checksum_mismatch`, before any newer migration runs. Put the
  change in a new migration.
- A migration is either one statement, which the database applies atomically,
  or only `CREATE TABLE IF NOT EXISTS` statements for `economy_*` tables. Other
  shapes are rejected before anything runs.
- When a statement fails, tables created by that migration are dropped again
  and startup fails with `migration_failed`. The error names the migration, the
  statement number, the database's reason and what to do next. Nothing is
  recorded, so the migration runs whole on the next start.

`EconomyHealthReport` prints the readiness state and any failure.
`AwaitReady` returns `not_ready` with the same health details.

## Validation

Run these from the server console. None needs a player online. Where a test
takes a character, pass the character's UUID (or the server id of a connected
player). A UUID must already own Economy accounts (Character provisions
wallets on first activation), so a mistyped or foreign UUID is refused.

### Production profile (read-only)

| Command | Expected |
|---|---|
| `EconomyHealthReport` | `state=ready phase=ready` |
| `EconomyFoundationSmokeTest` | `done 6/6 passed` |
| `EconomyAccountContractSmokeTest` | `done 7/7 passed (read-only)` |
| `EconomyJournalAuditSmokeTest` | `done 5/5 passed ... (read-only)` |
| `EconomyReleaseContractSmokeTest` | `done 7/7 passed (read-only)` |
| `EconomyReleaseGateSmokeTest` | `done 23/23 passed (read-only)` (19 when no account has two entries yet) |
| `EconomyBankAccountGateSmokeTest` | every line PASS (in-memory test operators; no funds moved) |
| `EconomyBankContractSmokeTest` | every line PASS (no accounts created) |
| `EconomyTransactionReadSmokeTest` | every line PASS (read-only) |

`EconomyReleaseGateSmokeTest` checks that the Core policy grants Economy
itself no supply. The paging checks use the account with the most entries, so
run it while that account is quiet.

### Development profile (`Config.DevMode = true`; changes data)

| Command | Expected |
|---|---|
| `EconomyMigrationFaultTest` | `done 8/8 passed` |
| `EconomyHistoryPaginationTest <character> <fresh id>` | `done 10/10 passed`, wallet back to its balance |
| `EconomyRestartTest prepare <character> <fresh id>`, restart the server, `EconomyRestartTest verify <character> <same id>` | `PREPARED ...`, then `done 10/10 passed` |
| `EconomyWalletProvisionTest <character>` | `PASS ... idempotent=true` |
| `EconomyTransferContractSmokeTest <character>` | `done 7/7 passed (no funds moved)` |
| `EconomySupplyTest <character> <fresh id>` | `PASS`; issues and destroys 100.00 |
| `EconomyTransferLiveTest <sender> <recipient> <fresh id>` | `PASS ... restored=true` |
| `EconomyConcurrencyTest <sender> <recipient> <fresh id>` | `PASS injectedRollback=true committed=1 insufficient=1 ...` |
| `EconomyBankLiveTest <character> <fresh id>` | `PASS`; the character needs 6.00 and pays a 0.50 fee |
| `EconomyShopFundingTest <character> <stable id> [dollars\|gold] [1-10000]` | `PASS`; creates development funds that stay |

Development tests post test funds through the journal as `feather-economy`,
below the Core policy gate. `EconomyRestartTest prepare` pauses the outbox so
its two events are still pending at restart. `verify` checks the balance, the
journal, outbox delivery, replay and payload conflict, then removes the test
funds.

To prove that a migration fault stops startup:

```text
set economy_dev_migration_fault failure     (or: checksum, invalid)
restart feather-economy
EconomyHealthReport
```

Expect `state=failed` and `failure code=migration_failed` (or
`migration_checksum_mismatch`, `invalid_migration`), with the migration id in
the details. Restart the whole server afterwards to clear the convar and the
stopped dependents. Switch DevMode off and restart before packaging.

### Ownership check (no other balance writers)

Only feather-economy may write its tables, and no resource may keep or change
balances on its own. Run it from the server folder, the one that holds
`server.cfg` (Node.js, no dependencies):

```text
node "resources/[feather]/feather-economy/tools/ownership-check.js" resources --cfg server.cfg
```

From inside `resources`, use
`node "[feather]/feather-economy/tools/ownership-check.js" . --cfg ../server.cfg`.

`--cfg` limits the scan to resources server.cfg ensures or starts; leave it out
to scan everything. Errors (exit code 1): SQL that writes an `economy_*` table,
`UPDATE ... SET` of a money column (`money`, `gold`, `rol`, `cash`, `balance`,
`ledger`), and VORP or Cfx example currency calls (`addCurrency`,
`removeMoney`, `exports.money`, ...). Direct reads of `economy_*` tables are
warnings, errors with `--strict`. `--allow <resource>` skips a resource being
retired. The expected result is `0 error(s) -> PASS`.

### Scoped Stables payment reversals

`GetCapabilities().value.features.scopedPaymentReversals == 1` advertises support.
Config.Access.trustedReversers admits bcc-stables; Config.ReversiblePayments
restricts its originals to stables.horse_purchase or stables.tack_purchase with
referenceType stables_order and a UUID referenceId. Reversals use
stables.payment_reversal. A caller with an explicit scope does not inherit shop
scopes. Existing shop callers retain their current behavior.

```lua
local result = exports['feather-economy']:ReversePayment({
    transactionId = savedPaymentTransactionId
}, { actorCharacterId = originalBuyerCharacterId, correlationId = operationId })
```

The invoking resource determines authority; context.resource cannot impersonate
another caller. No refund amount, currency, account or idempotency key is accepted.
The original entries and configured scope are checked again under the SQL lock;
the deterministic original-transaction key permits one refund. Closed accounts,
insufficient receiving-account funds and wallet limits still refuse cleanly.
This adds no escrow or treasury spending shape. Persist delivery cancellation
before calling; an unknown outcome must retain the operation for reconciliation.

Server-console `EconomyStablesReversalContractSmokeTest` checks 7 configuration/
refusal conditions after startup without moving funds; DevMode is not required.
It does not prove successful live refunds or concurrent/restart SQL recovery.
Offline regressions (nine scenarios, including Shops, caller isolation, original
scope/entry checks, replay and rollback) run with optional Lua 5.4/lupa:

```text
python tests/run_lua.py --lupa-dir <optional-lupa-directory>
```

Merge the new trustedReversers entry and ReversiblePayments block into deployed
configuration, preserving custom settings. Deploy config.lua, server/main.lua,
server/services/foundation.lua and server/services/journal.lua together. Existing
manifest/scripts only: no refresh required for this change. Restart Economy and
its consumers in dependency order, or use one server restart with the Inventory
update. No new Economy migration. Preserve reversal scopes while unsettled
operations exist; changing/removing a scope can block recovery, not authorize a
second refund. No live financial acceptance is claimed by the offline tests.
## Read-only payout preflight

`CheckIssue(request, context)` uses the actual invoking resource, configured Issue
reason and the same Core supply authorization as Issue, then verifies the character
wallet and open system source. Success returns `{allowed=true,sourceAccountId}`;
it posts no journal, receipt or balance changes. Recheck at gameplay confirmation;
actual Issue still authorizes and journals independently, so later failure remains
a durable consumer obligation rather than permission to recreate surrendered goods.
Stables buy-back uses the exact `stables.tack_sale` reason and a server-only Core
service grant for Economy's Stables principal. No unrestricted supplier trust is
required. Original Issue/Destroy behavior and authorization are retained.

Stables player tack trades add exact scopes `stables.tack_trade_payment` /
`stables_tack_trade` -> `stables.tack_trade_refund`, and Issue reason
`stables.tack_trade_sale`. Existing Core supply authorization remains mandatory;
no unrestricted supplier grant or new money API. Stables skips Economy for free
handovers. Paid trades capture buyer payment before custody and settle seller
credit after Inventory's transfer receipt; only certain failed custody refunds.
10 reversal regression scenarios plus issue preflight pass; live trades pending.
