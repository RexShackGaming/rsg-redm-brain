# rsg-cards

Version 3.0.4. Collectable cigarette cards for the RSG Framework

Collectable cigarette cards for the RSG Framework: 144 cards in 12 sets, found in the world, pulled from card packs, traded with collectors and sold to card vendors. **Version:** 3.0.3 · **Requires:** `rsg-core`, `rsg-inventory` (3.2.0+ for the Bundle Sets button), `rsg-target`, `oxmysql` · **Optional:** `interact-sound`, `rsg-log` · **ox_lib:** not required > Server owners and developers: see **[

Source: https://github.com/Rexshack-RedM/rsg-cards

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-cards:server:boxClosed`, `rsg-cards:server:closePack`, `rsg-cards:server:openShop`, `rsg-inventory:server:move`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-cards:client:boxOpened`, `rsg-cards:client:inspectCard`, `rsg-cards:client:openPack`

## Event handlers

**server:** `rsg-inventory:stashAction`

**client:** `rsg-cards:client:openTrades`, `rsg-cards:client:openVendor`, `rsg-cards:client:revealCard`, `rsg-cards:client:takecard`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-cards:server:flipCard`, `rsg-cards:server:getPickups`, `rsg-cards:server:getTrades`, `rsg-cards:server:getVendor`, `rsg-cards:server:makeSet`, `rsg-cards:server:pickupCard`, `rsg-cards:server:sell`, `rsg-cards:server:sellAll`, `rsg-cards:server:trade`

## Commands (RSGCore.Commands.Add)

**server:** `/refreshcardtrades`

## Server events it triggers in other resources

**client:** `InteractSound_SV:PlayOnSource`

## Public (table) functions

**server/server.lua:** `CardsServer.notify(src, description, notifyType)`, `CardsServer.log(message)`, `CardsServer.playerTag(Player)`, `CardsServer.isNear(src, coords, radius)`, `CardsServer.throttle(src, key, seconds)`, `CardsServer.itemLabel(name)`, `CardsServer.itemImage(name)`, `CardsServer.round(value)`, `CardsServer.getBoxIds(src)`, `CardsServer.countCards(src, scope)`, `CardsServer.removeCards(src, name, amount, reason, scope)`

## Database tables

`rsg_cards_boxes`, `rsg_cards_collection`, `rsg_cards_pickups`
