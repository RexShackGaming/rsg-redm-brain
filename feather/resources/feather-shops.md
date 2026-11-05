# feather-shops

Version 0.2.0. Authoritative commerce workflows for the Feather Framework

Feather-native commerce service. Original BCC Shops is reference only; this resource has no VORP compatibility layer or legacy table dependency. Shipped defaults are production-safe: `Config.DevMode=false` and manifest metadata

Source: https://github.com/FeatherFramework/feather-shops

**Dependencies:** `feather-mysql`, `feather-core`, `feather-economy`, `feather-organizations`, `feather-inventory`, `feather-toolkit`, `feather-menu-v2`, `feather-admin`

## Exports (call as exports['feather-shops']:Name)

**server:** `AwaitReady(timeoutMs)`, `CreateQuote(request, source)`, `GetCapabilities()`, `GetCatalog(shopId)`, `GetHealth()`, `ListShops()`, `PrepareOrder(request, source)`, `ValidateQuote(quoteId, source)`

## Commands (RegisterCommand)

**server:** `/ShopCompensationFenceTest`, `/ShopDeliveryRefundConcurrencyTest`, `/ShopFulfillmentLiveTest`, `/ShopPurchaseConcurrencyReplayTest`, `/ShopPurchaseConcurrencyTest`, `/ShopPurchaseInsufficientTest`, `/ShopPurchaseLiveTest`, `/ShopPurchaseRecoveryTest`, `/ShopPurchaseState`, `/ShopReconciliationState`, `/ShopRefundDeliveredTest`, `/ShopRefundLiveTest`, `/ShopReleaseContractSmokeTest`

**client:** `/ShopPurchaseClientTest`, `/ShopPurchaseRangeClientTest`, `/ShopQuoteClientTest`

## Public (table) functions

**server/main.lua:** `ShopService.RegisterDevCommand(name,handler,restricted)`

**server/orders.lua:** `ShopOrders.Start()`

**server/organizations.lua:** `ShopOrganizations.GetId(shopId)`, `ShopOrganizations.Settlement(shopId,currency,orderId)`, `ShopOrganizations.CommerceState(result,id)`, `ShopOrganizations.CheckCommerce(shopId)`, `ShopOrganizations.Start()`

**server/player_routes.lua:** `ShopPlayerRoutes.Start()`

**server/purchases.lua:** `ShopPurchases.Start()`
