# feather-shops

Version 0.3.0. Authoritative commerce workflows for the Feather Framework

Native Feather commerce. Shops owns catalogs, quotes and immutable orders; Economy owns money, Inventory owns capacity/items, and Weapons owns canonical firearm metadata and provenance. There is one atomic purchase path.

Source: https://github.com/FeatherFramework/feather-shops

**Dependencies:** `feather-mysql`, `feather-core`, `feather-economy`, `feather-organizations`, `feather-inventory`, `feather-toolkit`, `feather-menu-v2`, `feather-admin`

## Exports (call as exports['feather-shops']:Name)

**server:** `AwaitReady(timeoutMs)`, `CreateQuote(request, source)`, `GetCapabilities()`, `GetCatalog(shopId)`, `GetHealth()`, `ListShops()`, `PrepareOrder(request, source)`, `ValidateCheckoutPermit(id,order)`, `ValidateQuote(quoteId, source)`

## Event handlers

**client:** `feather-core:locale:changed`

## Commands (RegisterCommand)

**server:** `/ShopPurchaseState`, `/ShopReconciliationState`, `/ShopReleaseContractSmokeTest`

## Public (table) functions

**server/main.lua:** `ShopService.RegisterDevCommand(name,handler,restricted)`

**server/orders.lua:** `ShopOrders.Start()`, `ShopOrders.ResolveRequest(request,source)`

**server/organizations.lua:** `ShopOrganizations.GetId(shopId)`, `ShopOrganizations.Settlement(shopId,currency,orderId)`, `ShopOrganizations.CommerceState(result,id)`, `ShopOrganizations.CheckCommerce(shopId)`, `ShopOrganizations.Start()`

**server/player_routes.lua:** `ShopPlayerRoutes.Start()`

**server/purchases.lua:** `ShopPurchases.Start()`, `ShopPurchases.RecoverPurchase(id,originalFailure)`, `ShopPurchases.Status(id)`, `ShopPurchases.Purchase(id,source)`, `ShopPurchases.IsActive(id)`
