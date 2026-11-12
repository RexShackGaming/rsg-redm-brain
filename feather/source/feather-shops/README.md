# Feather Shops

Current version: **0.4.0**.

## Weapons-owned gun stores and ammunition boxes

`Config.WeaponStoresEnabled=true` imports locations and offers from Weapons'
`shop_config.lua`. Set it false only for an intentional standalone Shops install
without Weapons. Ordinary offers remain in Shops config. The default old $25
Cattleman test offer has been removed; edit gun-store prices in Weapons instead.
The store menu groups firearms, ammunition, attachments and maintenance supplies.

Offer `packSize` is the number of Inventory items in one purchased unit. Quantity
on the quote/order is boxes; `unitPrice` is integer minor units per box and total
remains quantity times unitPrice. The quote and confirmation also report exact
delivered item quantity. Box size is server-owned and is saved on the immutable
order as `pack_size`; clients cannot supply it. Item delivery is capped at 100 per
order, while firearms remain exactly one canonical item per purchase.

Startup adds `shop_orders.pack_size INT UNSIGNED NOT NULL DEFAULT 1` when missing,
checks compatible storage, and preserves original migration checksums and old
orders/receipts. The old total-price constraint remains intact. Existing orders
retain one delivered item per purchased unit. Inventory must advertise package
delivery support before boxed offers can be admitted. No Economy code change is
needed. Upgrade these three resources together during a coordinated stop.

Prices and source catalog are captured at startup; a Weapons stop closes Shops
admission until Shops is restarted after Weapons. Changing config does not mutate
accepted orders. Catalog labels use the requesting player's feather-settings/Core
language and are refreshed when the menu opens; unavailable translations fall
back to the configured English label.

Offline checks: `tests/run_checkout.py --lupa-dir <local Lupa installation>` runs
the actual transaction composition plus catalog/source/schema and menu tests.
These model SQL/CFX and do not replace the focused live store purchase check.

Native Feather commerce. Shops owns catalogs, quotes and immutable orders;
Economy owns money, Inventory owns capacity/items, and Weapons owns canonical
firearm metadata and provenance. There is one atomic purchase path.

## Purchases

An accepted purchase commits wallet debit, business treasury credit, balanced
Economy journal/outbox, Inventory delivery, canonical firearm provenance and the
checkout receipt in one physical database transaction. A failure rolls them all
back. Preparing an immutable order and registering its recovery index happen
before this economic transaction; neither step charges or delivers anything.

Supported offers are ordinary stack items (including loose ammunition items) and
currently admitted native sidearms/long guns. Firearms are purchased one at a time
with a new serial and pristine canonical metadata. They are delivered to inventory,
not automatically equipped, and do not include ammunition. Generic unique items,
melee and utility purchases are not admitted by this first firearm checkout.

Prices remain server-configured integer minor units. Existing shop locations,
prices and item names are preserved. The initial live-test Valentine catalog contains an apple at 100 dollars minor
units ($1.00) and one Cattleman at 2,500 minor units ($25.00), as selected by the
server owner. To add another firearm offer, use its existing Inventory item name,
choose the price for your server, and set maximumQuantity=1. Do not substitute a
new item key or use developer issuance commands for normal purchases.

## Automatic recovery

The client saves its request before confirmation and polls a status-only route
after an uncertain response. The server also checks pending accepted attempts in
bounded batches, including while clients are disconnected. Recovery reads the
atomic receipt under the original order lock. If no purchase committed, it saves
a terminal rejection before allowing a new purchase. A separate request-key fence
also prevents a delayed original RPC from charging after status reported that no
order was accepted. Recovery never repeats a payment, grant or refund.

DB interruptions leave the request pending until independent readback succeeds.
Do not delete orders, receipts, provenance, request fences or pending indexes to
retry a purchase. These are durable economic evidence, not disposable caches.

The previous alpha execution/compensation tables are retained when present.
Completed orders are historical receipts only. Unresolved prior paid/accepted
orders or an incomplete old schema block startup for review; the new service does
not silently discard or reinterpret them. A new installation does not create the
retired execution/compensation tables.

## Requirements and settings

Use the compatible Inventory, Economy, Shops and Weapons checkout changes as one
batch. Inventory creates its checkout receipt table at startup; Shops installs
checksummed migrations 006 (attempt index) and 007 (request fences), preserving
existing migration checksums and economic data. Shops validates Inventory's
checkout contract before accepting purchases. Weapons is required for firearm
offers; ordinary items can be bought without a running Weapons resource.

The normal framework dependencies, including Organizations, Toolkit and Menu v2,
must be available. Native firearm runtime/ammunition transport must be enabled and
settled for the buyer. Config.DevMode stays false. Developer issuance/probe flags
are not needed for purchases. Reconciliation is always active; its poll interval,
delay and batch size remain configurable. The former enabled switch is retired.

Each player's language comes from feather-settings through Core's selected-locale
contract. Resource dictionaries use ui_shops_* keys, with English fallback when
the requested language lacks a translation. Visible menus close on language change
and rebuild on the next open; saved requests keep recovering.

## Operational interfaces

GetCapabilities, GetHealth, AwaitReady, ListShops and GetCatalog remain available.
CreateQuote and ValidateQuote remain trusted server interfaces. Player purchase
and status RPCs bind the actual current Core buyer; prices, accounts, native
metadata and internal transaction IDs are not accepted from client payloads.

ShopPurchaseState, ShopReconciliationState and ShopReleaseContractSmokeTest are
read-only console diagnostics. The former saga grant/refund acceptance commands
are retired. No startup fixture repair, item issuance or money grant is performed.

## Automated development checks

The four compatible sibling checkouts must exist; missing dependencies fail the
test run rather than skipping composition. From this repository, run:

```powershell
python tests/run_checkout.py --lupa-dir C:/coding/.test-deps
```

Use an appropriate installed Lua 5.4 lupa location, or omit --lupa-dir when it is
installed in Python. The runner loads the real Inventory transaction/capacity,
Shops RPC/order/recovery, Economy journal and Weapons metadata/provenance/export
code in separate caller-bound environments. SQL, networking and engine authority
are modeled. Passing this suite establishes component composition, not live CFX
callback transport, MariaDB contention, migration execution or RedM acceptance.
Those checks remain required before release.

The menu is pinned 3% from the top and left. Ammunition is grouped by family; offers use two lines for name and quantity/price, and dollars display with $. Transaction busy feedback remains active until asynchronous work completes. Requires the companion Menu v2 button-description update (2.0.0-alpha.10).
