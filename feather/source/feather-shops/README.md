# Feather Shops

Feather-native commerce service. Original BCC Shops is reference only; this
resource has no VORP compatibility layer or legacy table dependency.

Shipped defaults are production-safe: `Config.DevMode=false` and manifest metadata
`shops_dev_tests 'false'`. Server/client acceptance commands are not registered in
that profile. `ShopPurchaseState`, `ShopReconciliationState`, health/capability
exports, and the read-only `ShopReleaseContractSmokeTest` remain available to the
server console. To run development acceptance locally, deliberately enable both
flags and restart (run `refresh` if manifest metadata changed); disable both and
restart before packaging. DevMode also grants Admin quote/order test trust, so it
must not be enabled merely for diagnostics.

## Foundation slice

- Contract 1 result envelopes, health, capabilities, and bounded readiness.
- Core and Economy readiness/contract validation.
- Checksummed schema migration and UUID shop/offer identities.
- Server-configured NPC catalog persisted with integer minor-unit prices.
- Public read-only catalog snapshots and source-bound player quote/purchase RPCs.
- Durable prepared orders with buyer/quote-bound request IDs and restart replay.

Config is authoritative for the initial catalog. Startup synchronizes configured
shops and offers and disables rows removed from configuration. Do not edit these
tables manually. Catalog reads return copies, not mutable service state.

The initial Valentine apple offer costs 100 dollars minor units ($1.00).
Quote validation checks the active Inventory definition and rejects weapons and
unique items. Weapons and unique-item commerce remain deferred.

## Load order

Start feather-mysql, feather-core, feather-economy, feather-inventory, then feather-shops.

## Server exports

`GetCapabilities()`, `GetHealth()`, `AwaitReady(timeoutMs)`,
`ListShops()`, and `GetCatalog(shopId)` return Contract 1 envelopes.
Catalog snapshots contain public offer data, not owner balances or credentials.

Trusted server callers may use `CreateQuote(request, actorSource)` and
`ValidateQuote(quoteId, actorSource)`. Quote requests accept only `shopId`,
`offerId`, and a numeric integer `quantity`. Player RPC handlers supply their
actual Core-bound caller source, never a request field.

Quotes have a UUID, authoritative integer total, material catalog revision,
Inventory definition ID, expiry, and server-only buyer/session identity. Never
forward the entire server quote to a client. A buyer has one outstanding quote;
creating another replaces it. Quotes expire after 30 seconds and do not survive
resource restart. Payment will require a durable order, not this temporary quote.
Validation rechecks the session, proximity, currency, definition, and revision.

`PrepareOrder({ requestId = stableId, quoteId = quoteUuid }, actorSource)` is
restricted to the same trusted server callers. It snapshots the quote and buyer
in `shop_orders`, with one order per caller/request ID. A different quote or buyer
using that ID receives `idempotency_conflict`. An exact retry returns the original
order with `replayed=true`, including after restart or quote expiry. Receipt
replay requires a current session belonging to the original account/character;
it does not authorize payment or fulfillment using expired quoted terms.

Order receipts remain `prepared`; executions and compensation are tracked in
separate durable tables. Existing accepted intents reconcile automatically.
These records intentionally remain as development receipts; do not delete them
to retry an operation. Like quotes, order snapshots contain server-only identity.

## Purchase coordinator acceptance

The immutable prepared receipt remains in `shop_orders`. Migration 003 adds
`shop_order_executions` for `payment_pending`, `paid`, `fulfilled`, and `rejected`.
This preserves the applied catalog/order migrations. The coordinator is internal
behind source-bound player routes; no generic payment or refund export is exposed.

Payment intent fixes the buyer wallet, currency, amount, and Economy system sink
before charging. Economy resolves the sink through its trusted `GetSystemAccount`
export; Shops stores no independent ledger balance or system-owner configuration.
NPC purchases currently settle to the system sink, not a merchant/business wallet.

Recovery reuses `shop-payment:<order UUID>` and `shop-fulfillment:<order UUID>`.
Exact payment/grant receipts replay after restart. Only definitive insufficient
funds is terminal; uncertain payment errors remain `payment_pending`, and failed
delivery remains `paid` with an operator-visible error. State updates are
conditional and do not regress completed executions. Runtime concurrent calls
for one order are rejected; downstream durable keys protect interrupted calls.
Refund retries reconfirm Inventory's durable cancellation fence before attempting
the original payment reversal; unavailable proof blocks the refund.
The reconciliation worker retries existing incomplete payment/delivery intents
and existing compensation requests. It never automatically chooses compensation.

Run the first dev-only acceptance test with the buyer near the test shop:

```text
ShopPurchaseInsufficientTest 1 purchase-insufficient-001
```

Use a fresh request ID. This requires a wallet below the two-item purchase price
and otherwise aborts before attempting a purchase. Expect `PASS state=rejected
balancesUnchanged=true retryRejected=true`, with no Inventory grant.
`ShopPurchaseState <order UUID>` prints the durable execution for operators.
Successful-purchase and interruption tests follow this rejection gate.

### Funded purchase test

Economy's dev-only server-console command `EconomyShopFundingTest <source>
<stable fundingId>` issues exactly 200 dollars minor units. Funding retries are
payload-bound and durable. Shops is not added to Economy's trusted suppliers.
The test funds are spent into the system sink; this is not a balance-restoring
round trip. These commands may create real development balances and items.

```text
EconomyShopFundingTest 1 shop-fund-001
ShopPurchaseLiveTest 1 purchase-live-001
```

The buyer must be near the shop for the first purchase. Expect state=fulfilled,
amount=200, chargedOnce=true, replayed=true, fulfillmentReplayed=true,
sameInstances=true. Two apples are delivered. Repeat the purchase command using
the same request ID after restarting Shops; there must be no additional charge
or grant. Do not fund again with a new ID just to retry a completed purchase.
The live test refuses existing incomplete orders; they need explicit recovery,
not another order ID. Player payments use this coordinator; refunds remain server-only.

### Interrupted purchase tests

`ShopPurchaseRecoveryTest <source> <requestId> payment|grant|retry` is dev-only.
Both preparation modes use a fresh funded two-apple order near the test shop.
`payment` stops after Economy commits, before Shops records the transaction ID.
`grant` stops after Inventory commits, before Shops stores its fulfillment result.
The respective execution states remain `payment_pending` and `paid`.

```text
EconomyShopFundingTest 1 recovery-fund-payment-001
ShopPurchaseRecoveryTest 1 recovery-payment-001 payment
# restart Shops, without funding again
ShopPurchaseRecoveryTest 1 recovery-payment-001 retry

EconomyShopFundingTest 1 recovery-fund-grant-001
ShopPurchaseRecoveryTest 1 recovery-grant-001 grant
# restart Inventory and manually start Shops; do not fund again
ShopPurchaseRecoveryTest 1 recovery-grant-001 retry
```

Retry expects state=fulfilled, noSecondCharge=true, paymentReplayed=true,
grantReplayed=true, and unchanged balances. After-grant retry additionally
requires grantRecovered=true from the coordinator's persisted Inventory result.
Payment interruption delivers two apples on recovery; grant interruption delivers
them before the restart, and retry must deliver none. Each scenario spends its
200 minor-unit test funding. Retain the order request ID if any stage fails.

### Cancellation fence acceptance

Inventory's trusted `CancelCharacterItemGrant` accepts the same payload and caller
namespace as `GrantCharacterItemOnce`. Both serialize on the same durable receipt.
Cancellation commits a terminal no-delivery outcome; later grants return
`grant_cancelled`. Exact cancellation retries replay, and altered payloads return
`idempotency_conflict`. A previously committed delivery blocks cancellation with
`grant_already_delivered`, even if its items were subsequently consumed or moved.
This reuses Inventory's transaction runner and receipt table, not a second grant
or reservation system.

Migration 004 adds separate compensation states: cancellation_pending,
refund_pending, refunded, and delivery_committed. Internal compensation accepts
only recorded paid orders, persists intent before cancellation, and reverses
the original payment only after Inventory confirms durable no-delivery. Purchase
retries block while compensation is pending or refunded. If Inventory reports
committed delivery, refund is refused and fulfillment recovery remains allowed.
Refund errors retain the same pending intent and payment UUID for retry. No client
refund route exists.

### Background reconciliation

`Config.Reconciliation` enables bounded recovery (5-second polling, 15-second
minimum retry age, at most 10 sequential attempts per batch). Accepted payment
intents use their stored buyer and account identities, including while the buyer
is offline. No fresh session, proximity, or expired quote is used to retarget an
accepted payment. Prepared orders without payment intent are excluded. Refund
recovery requires existing compensation intent and keeps the cancellation fence.
Permanent dependency failures remain visible and retry at the configured pace;
attempt timestamps advance to prevent repeatedly failing orders starving others.
`ShopReconciliationState` prints worker state and counters. Attempt logs include
the order UUID, workflow, success, and error code. No new compensation decision or
client mutation route is introduced.

Dev interruption tests are no longer guaranteed to remain pending indefinitely:
the worker can complete eligible intents once they reach the configured age.
Restart recovery acceptance should inspect `ShopPurchaseState` and worker logs,
then replay the original test request to verify no duplicate charge or grant.

Committed-but-unacknowledged delivery acceptance uses a fresh funded order:

```text
ShopPurchaseRecoveryTest 1 refund-delivered-001 grant
# restart Shops
ShopRefundDeliveredTest 1 refund-delivered-001
```

The grant checkpoint delivers two apples while leaving execution paid. The
delivered test requires an existing committed Inventory receipt before attempting
compensation, verifies repeated refund refusal and unchanged balances, then
recovers fulfillment with the same instance IDs and no additional grants.
Expect refundRefused=true, balancesUnchanged=true, state=fulfilled,
sameInstances=true. Use existing 200 test funding if still available, not new
funding. The purchase consumes that balance; it is deliberately not refundable.

For initial acceptance, fund a fresh two-apple order near the test shop:

```text
EconomyShopFundingTest 1 refund-fund-001
ShopPurchaseRecoveryTest 1 refund-live-001 undelivered
ShopRefundLiveTest 1 refund-live-001 refund
```

The undelivered checkpoint records payment without attempting an item grant.
Refund expects state=refunded, refundedOnce=true, replayed=true,
deliveryBlocked=true. Funding remains in the buyer wallet after reversal; this
test does not destroy the test funding. For restart replay, repeat the refund
command with mode retry, without new funding. For the acknowledgement-interruption
scenario use a fresh funded undelivered order and mode interrupt, restart Shops,
then use mode retry. Never use a new order/request ID to recover an uncertain refund.

```text
ShopCompensationFenceTest 1 purchase-live-001
```

Expect 5/5 passes and cancellationFirstReplayed=false. The test cancels an isolated
`dev-cancel:<order UUID>` key and verifies the actual fulfilled purchase cannot be
cancelled. It moves no funds and grants no items. Restart Inventory, manually
start Shops if stopped by dependency shutdown, and repeat the same command;
cancellationFirstReplayed must become true.

## Inventory fulfillment acceptance

Inventory's trusted `GrantCharacterItemOnce` export atomically commits ordinary
item grants and a payload-bound durable receipt in `inventory_grant_receipts`.
Its request contains `grantId`, `characterId`, `definitionId`, `itemName`, and
integer `quantity`. Exact retries return the original instance IDs; altered
payloads fail with `idempotency_conflict`. Capacity failures roll back the receipt
and items together. Unique items still require their owning issuer.

With Shops `DevMode=true`, the server-console-only `ShopFulfillmentLiveTest`
grants a prepared order's items once using `dev-order:<order UUID>`. This is a
free acceptance grant, isolated from future production payment keys. It neither
changes the order state nor moves money. Nothing fulfills automatically.

```text
InventoryFulfillmentContractSmokeTest
ShopFulfillmentLiveTest 1 order-test-001
```

The first command expects 6/6 passes and grants nothing. The second expects
quantity=2, firstReplayed=false, replayed=true, sameInstances=true, and
mismatchRejected=true. It creates two apples. Restart Inventory (then manually
start Shops if dependency shutdown stopped it) and rerun the same command;
firstReplayed must now be true and no additional apples should appear. These
are server Lua changes; no Inventory UI build or generated assets are involved.

## Tests

Run in the server console:

```text
ShopFoundationSmokeTest
ShopQuoteContractSmokeTest
ShopQuoteLiveTest <active source near Valentine test shop>
ShopOrderContractSmokeTest
ShopOrderPersistenceTest <active source> <fresh requestId> prepare
# restart feather-shops, then:
ShopOrderPersistenceTest <active source> <same requestId> retry
```

Restart feather-shops and repeat. UUIDs and configured prices must remain
unchanged; startup should report zero migrations applied on subsequent runs.

The quote contract test expects 11/11 passes. The live test requires the player
within four metres of the configured shop at -322.13, 803.65, 117.88 and expects
quantity=2, total=200. Outside that range it must reject with `out_of_range`.
Neither test moves funds, provisions wallets, or grants items.

The order contract test expects 7/7 passes. Prepare requires proximity to the
test shop; retry is a stored receipt lookup and does not require proximity.
Persistence tests expect status=prepared, replayed=true, mismatchRejected=true,
count=1 and an unchanged order UUID after restart. They create no inventory items
and make no Economy calls.

## Next slice

Player-facing client interaction/UI and end-to-end RPC acceptance tests.

## Player RPC contract

`shops.wallets.v1` accepts an empty payload and reads only the current caller's
open character wallets through Economy. It returns currency, label, integer
minor-unit balance, and catalog precision, never account/owner identifiers.
Session identity is rechecked after dependency reads. This is a read, not wallet
provisioning. Shop browsing, quote confirmation, and purchase result pages refresh
these balances; failed reads show unavailable rather than fabricated zero funds.
The display is a snapshot, not purchase authority. Economy still checks funds
atomically when charging. HUD integration remains separate.

The first interaction UI uses Toolkit's hold-B Browse shop prompt within three
metres of a catalog location and Feather Menu v2. Select an offer, enter quantity,
review the server quote, then explicitly confirm payment. Escape/Close releases
menu focus. Closing review does not purchase. Uncertain purchase responses retain
the exact request in client KVP, including across restart; reopening offers Retry
saved purchase rather than minting another payment. Terminal unpaid rejections
return safeToClear confirmation and restore browsing. Unaccepted expired requests
are explicitly confirmed not_accepted by the server and restore browsing too;
accepted payment intents never clear merely because their quote expired. No generic client
discard/refund mechanism is supplied. Server quote/purchase validation remains
authoritative if the player moves away. The initial dollars/gold catalog uses
two-decimal formatting. No shopkeeper entity, stock management, or selling UI yet.

The read-only `shops.catalog.v1` RPC supplies locations/offers to authenticated clients
before character activation without sharing server access configuration. Quote, wallet,
and purchase routes continue to require an active character. Toolkit and Menu v2 are dependencies. After
manifest changes run refresh, then restart feather-shops. UI acceptance starts with
opening, browsing, cancelling review, and Escape before testing funded confirmation.

`shops.quote.v1` accepts only `{ shopId, offerId, quantity }`. It requires an active
character and proximity. Its public quote contains id, shop/offer IDs, item,
quantity, currency, integer price/total, revision, and expiry; no buyer identity.

`shops.purchase.v1` accepts only `{ quoteId, requestId }`. Generate one stable
request ID per intended purchase and preserve both fields on an uncertain retry;
do not create a fresh request ID or quote to retry a payment. New payment intent
requires the original live quote and proximity. Accepted intent retries replay
stored terms for the original buyer. Completed responses contain only orderId,
state, quantity, currency, total, and replayed. Failures omit server-only details.
Core enforces character binding, bounded payloads, and per-source rate limits.
No player refund route exists. Server reconciliation remains authoritative.

Run `ShopPlayerRouteContractSmokeTest`: expect 11/11 passes with no funds moved.
This verifies registration policy, payload rejection, and response projection;
actual client transport and funded purchase acceptance are the next test gate.

### Client quote transport acceptance

With manifest metadata `shops_dev_tests 'true'`, run `ShopQuoteClientTest near`
in the client's F8 console within four metres of the Valentine test shop.
Expect 6/6 passes using the actual Core RPC transport, with no funds moved or
items granted. Move outside the range and run `ShopQuoteClientTest far`; expect
PASS outOfRange=true. These tests target the development apple offer and replace
the caller's outstanding quote. They do not purchase or persist a client quote.
Set the metadata to false to disable client acceptance commands. Server DevMode
remains a separate switch. After adding manifest files, run refresh then restart
feather-shops before testing.

### Client purchase acceptance

For movement between quote and purchase, with the menu closed run F8
`ShopPurchaseRangeClientTest prepare` near the test shop. Walk at least six metres
away, then run `ShopPurchaseRangeClientTest confirm` within the 30-second quote
lifetime. Expect PASS purchaseRejected=true code=out_of_range. The test preflights
local distance to avoid accidentally submitting an in-range purchase, but the
server decides proximity. A timed-out mutation keeps its exact request in KVP;
do not prepare another quote to recover it. Confirm uses the saved request if
present. An expired quote fails this range test and must be tested again with a
fresh preparation only after explicit safe-to-clear confirmation.

With the same client development switch enabled, use a funded wallet near the
test shop and run in F8 `ShopPurchaseClientTest client-purchase-001`. This is a
real two-apple purchase costing 200 minor units. The client saves its request and
quote in resource KVP before sending payment, then retries exactly those fields
and checks the public fulfilled receipt. Never reuse a key for another intended
purchase, server, or character; retries must use the original buyer.

After PASS, run server-console `ShopPurchaseLiveTest <current source>
client-purchase-001`. Existing fulfilled orders replay without new charges;
the server verifies unchanged wallet/sink balances and the same Inventory instances.
Inspect the initial wallet decrease and two-item inventory increase too: the
client receipt alone does not prove exactly-once charging. After restarting Shops,
repeat the same client command to exercise its persisted request. No fresh quote
or funding is needed. Uncertain failures preserve the saved request; share the
error and retain that ID rather than creating another purchase to recover.
Player-owned shops, selling, management UI, and NPC buying are deferred.
## Canonical organization links

Shops now depends on Organizations Contract 1 and the installed Admin service
policy. Start Admin and Organizations before Shops. Configured organization
bootstrap keys/names are immutable request payloads, not runtime rename settings.
Startup creates/replays a business identity, activates/replays its original
activation and persists `shop_organization_links` with its canonical UUID.
Existing links cannot be rebound. Failure between organization creation and local
link commit is recovered by original request replay, not shadow IDs or dual writes.
GetCatalog includes `organizationId`; public location projections remain unchanged.
Shops has non-privileged creator/mutator and creator-scoped audit trust; Admin policy
grants it only create/update actions. Restart does not resume a suspended/dissolved
organization: activation replay is a historical receipt, not a new lifecycle edit.
New payments now use Economy's organization treasury accounts; existing accepted
payment destinations remain fixed. Recipe/deployment integration must add
Organizations and the configured Admin service policy before Shops.
After manifest changes run `refresh` and restart the touched resources. Run
`ShopOrganizationContractSmokeTest` for 8 read-only checks with the default shop,
then restart Shops and repeat to verify stable linkage and bootstrap audit counts.

New quote creation and quote validation now require the canonical business to
currently resolve as active. Missing/unavailable/malformed identity fails closed;
pending/suspended/dissolving/dissolved businesses reject `organization_inactive`.
Quote validation is used before first durable payment intent; existing intents
remain recoverable without a current quote/business-status gate, preserving prior
delivery/refund obligations. Organization UUID participates in catalog revision.
These are last-look API checks, not a cross-domain transaction with suspension.
Client startup waits on replicated server readiness before requesting the catalog;
the signal is only a timing hint, never authorization. Run
`ShopOrganizationCommerceContractSmokeTest` for 11 read-only checks. Recorded
commerce lifecycle and startup-warning results follow.
Commerce contract acceptance passed 11/11 and restart catalog warnings were absent.
Admin's `ShopOrganizationLifecycleLiveTest <nearby buyer source> <stable requestId>`
prepares a quote, suspends the linked business, verifies new quote/validation/order
rejection with unchanged buyer balances and no order, then resumes and quotes again.
Admin quote/order trust is installed only in Shops DevMode; no payment API trust is
added. The console-only test uses Admin's existing policy/privileged lifecycle
authority and attempts resume on failure. Repeat its original ID to check historical
receipt replay (not a fresh lifecycle gate test). Run without unrelated transactions
for reliable before/after balance comparisons. It inspects the latest 50 audit
events to recover original lifecycle revisions; missing historical evidence fails
closed on request binding rather than silently issuing replacement requests.
Live lifecycle quote/order gating passed with unchanged balances, no persisted
order and business resumed. Historical receipt replay passed without fresh changes.

For controlled inactive-business recovery acceptance, dev-only
`ShopReconciliationTestControl pause|resume` temporarily pauses worker polling.
Pause before creating a fresh interrupted order; it cannot cancel in-flight work.
Restart clears the pause. Admin's console-only `ShopBusinessLifecycleControl
suspend|resume <stable requestId> <expected revision>` changes only the first
configured shop's canonical organization using normal policy/ownership checks.
Retain original IDs/revisions on retries. Always resume both business and worker
after testing. No default reconciliation configuration is changed.
Worker recovery of an already-paid order while suspended passed: fulfillment
completed, exact replay produced no second charge or grant, and wallet remained
200. Business resumed at revision 6 and worker resumed; closing audit passed 5/5.
# Business treasury settlement

New payment intents resolve the linked organization's currency treasury through
Economy's allowlisted provisioning API. The final quote and business lifecycle
checks still precede intent acceptance. Payment intent stores the chosen account
UUID permanently; recovery and refunds use that original destination, never the
current catalog. Previously accepted system-sink orders are not migrated or
recharged. No fallback to the shared sink is permitted for new purchases.

`ShopPurchaseLiveTest` verifies the wallet debit, destination credit, stored
destination, exact replay, and stable delivery instances, and reports settlement
type, owner, and balance. Existing recovery and refund tests use stored accounts,
including while a business is inactive. Organization lifecycle lookup remains a
last-look check rather than an atomic cross-resource suspension/payment fence.
Treasury management and withdrawals are not exposed to players in this slice.
Live treasury purchase acceptance passed with amount=200, chargedOnce=true,
stable delivery instances, and canonical business treasury credit=200. Undelivered
treasury refund restored the buyer's 200 exactly once and blocked delivery.
Final journal audit for that checkpoint passed 5/5 with pending=0 and published=60.
Treasury purchase and refund recovery across full server restart subsequently
passed, as did both flows while the buyer was offline and reconnected on a changed
source (2026-09-18). Exact retries preserved charge/refund and delivery identities;
offline refunded delivery remained blocked. Closing audit passed 5/5, pending=0,
published=68. These results are manual development acceptance, not blanket release readiness.

## Competing purchase development test

`ShopPurchaseConcurrencyTest <nearby buyer source> <fresh requestId>` requires
DevMode, an active business, and a wallet containing exactly the first offer's
two-item price (200 dollars minor units for default apples). Stay near the shop,
keep the session unchanged, and avoid unrelated purchases or funding during the
test. Two ordinary prepared orders share one valid quote, with separate `:a`/`:b`
request IDs, and run concurrently through the real purchase coordinator.

The test expects one fulfillment and one insufficient-funds rejection, checks
treasury credit/wallet conservation and stored destinations, then verifies both
outcome replays and the winner's original Inventory instance receipt. The losing
execution must have no payment UUID or fulfillment receipt. It adds no Inventory
API and never writes Inventory or Economy tables. A pass purchases two real items
and leaves the wallet empty; it does not restore funds or remove items.

Fresh IDs are required; this is not a restart/replay harness. Failure prints order
IDs for inspection, not instructions to invent replacement IDs. A timed-out call
may still finish; restart before another concurrency test, and inspect/recover
original orders first. Pausing the worker is recommended for isolated testing;
always resume it afterward.

Live concurrency acceptance passed with `shop-concurrency-002`: one fulfilled
purchase, one insufficient-funds rejection, treasury delta=200, wallet=0, stable
winner delivery replay, and no losing execution fulfillment. Worker resumed;
closing journal audit passed 5/5 with pending=0 and published=71 (2026-09-18).
The first run had one pre-intent internal error and one fulfilled purchase; winner
replay verified no duplicates. Its underlying database cause was not established.
Checkout now reads existing wallets/treasuries before provisioning only missing
accounts, avoiding unnecessary provisioning locks. No Inventory API was added.

After full server restart, `ShopPurchaseConcurrencyReplayTest 2
shop-concurrency-002` passed using the original pair: the fulfilled winner replayed
the same payment and Inventory instances, the loser remained rejected without
payment or fulfillment, and wallet=0/treasury=1000 stayed unchanged. Closing
journal audit again passed 5/5 with pending=0 and published=71. This replay command
requires the original buyer and existing pair; it never funds or prepares orders.

## Delivery versus refund concurrency

`ShopDeliveryRefundConcurrencyTest <source> <paid-undelivered requestId>
[delivery-first|refund-first]` races the existing purchase and compensation
coordinators. Exactly one contender enters the per-order runtime mutex; retrying
both sides then proves Inventory's durable grant/cancellation receipt fixes one
terminal outcome. The command requires the original active buyer and never creates,
funds, or retargets an order. Use the existing recovery test to prepare the paid
undelivered order and pause the worker during the race.

Both orderings passed live and across restart on 2026-09-18. Delivery-first
fulfilled instances 105/106, refused refund, and retained wallet=0/treasury=1200.
Refund-first restored wallet=200, returned treasury=1200, and permanently blocked
delivery. Terminal replay changed no balances or items. The first delivery-first
run exposed an overly strict test assertion because fulfilled orders reject
compensation before creating a `delivery_committed` compensation row; the durable
Inventory delivered receipt and fulfilled execution are the terminal evidence.
The corrected replay passed. Closing audit passed 5/5, pending=0, published=76.
