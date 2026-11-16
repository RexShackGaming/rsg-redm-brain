# rsg-cards

Version 3.2.0. Collectable cigarette cards for the RSG Framework

Collectable cigarette cards for the RSG Framework: 144 cards in 12 sets, found in the world, pulled from card packs, traded with collectors and sold to card vendors. **Version:** 3.2.0 · **Requires:** `rsg-core`, `rsg-inventory` (3.2.0+ for the Bundle Sets button), `rsg-target`, `rsg-gizmo`, `oxmysql` · **Optional:** `interact-sound`, `rsg-log` · **ox_lib:** not required > Server owners and develo

Source: https://github.com/Rexshack-RedM/rsg-cards

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-cards:server:boxClosed`, `rsg-cards:server:claimUnclaimed`, `rsg-cards:server:closePack`, `rsg-cards:server:openShop`, `rsg-cards:server:pointAdd`, `rsg-cards:server:pointMove`, `rsg-cards:server:pointRemove`, `rsg-cards:server:ptradeCancel`, `rsg-cards:server:ptradeOffer`, `rsg-cards:server:ptradeReady`, `rsg-cards:server:ptradeRequest`, `rsg-cards:server:ptradeRespond`, `rsg-inventory:server:move`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-cards:client:boxOpened`, `rsg-cards:client:editorMove`, `rsg-cards:client:editorPlace`, `rsg-cards:client:editorRemove`, `rsg-cards:client:editorToggle`, `rsg-cards:client:inspectCard`, `rsg-cards:client:openCollection`, `rsg-cards:client:openPack`, `rsg-cards:client:setPoint`, `rsg-cards:client:tradeClosed`, `rsg-cards:client:tradeInvite`, `rsg-cards:client:tradeState`

## Event handlers

**server:** `rsg-inventory:stashAction`

**client:** `rsg-cards:client:openTrades`, `rsg-cards:client:openVendor`, `rsg-cards:client:revealCard`, `rsg-cards:client:takecard`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-cards:server:flipCard`, `rsg-cards:server:getCollection`, `rsg-cards:server:getPickups`, `rsg-cards:server:getPoints`, `rsg-cards:server:getTrades`, `rsg-cards:server:getVendor`, `rsg-cards:server:makeSet`, `rsg-cards:server:pickupCard`, `rsg-cards:server:sell`, `rsg-cards:server:sellAll`, `rsg-cards:server:sellDuplicates`, `rsg-cards:server:trade`

## Commands (RSGCore.Commands.Add)

**server:** `/cardedit`, `/cardmissing`, `/cardmove`, `/cardplace`, `/cardremove`, `/refreshcardtrades`

## Server events it triggers in other resources

**client:** `InteractSound_SV:PlayOnSource`

## Public (table) functions

**client/client.lua:** `CardsClient.loadModel(model)`

**server/collection.lua:** `CardsServer.saveProfile(Player)`, `CardsServer.markFound(Player, card)`

**server/server.lua:** `CardsServer.notify(src, description, notifyType)`, `CardsServer.log(message)`, `CardsServer.playerTag(Player)`, `CardsServer.isNear(src, coords, radius)`, `CardsServer.throttle(src, key, seconds)`, `CardsServer.itemLabel(name)`, `CardsServer.itemImage(name)`, `CardsServer.dbReady()`, `CardsServer.whenReady(fn)`, `CardsServer.round(value)`, `CardsServer.getBoxIds(src)`, `CardsServer.countCards(src, scope)`, `CardsServer.removeCards(src, name, amount, reason, scope, touched)`, `CardsServer.saveStashes(stashes)`, `CardsServer.findLocation(src, locations, id, radius)`

## Database tables

`rsg_cards_bonuses`, `rsg_cards_boxes`, `rsg_cards_collection`, `rsg_cards_pickups`, `rsg_cards_points`, `rsg_cards_profiles`, `rsg_cards_unclaimed`
