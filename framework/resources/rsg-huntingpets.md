# rsg-huntingpets

Version 3.1.0. rsg-huntingpets

A combined RedM / RSG-Core resource that adds hunting dogs **and** hunting birds to your server in one package, with a single leather-and-gold themed NUI shop for buying, selling and managing both. Built on `ox_lib` and `ox_target`. - 11 purchasable dog breeds (Husky, Mutt, Labrador Retriever, Rufus, Coon Hound, Hound Dog, Border Collie, Poodle, Foxhound, Australian Shepherd, Street Dog). - Follow

Source: https://github.com/Rexshack-RedM/rsg-huntingpets

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`

Has NUI (`ui_page`).

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-huntingpets:checktalk`, `rsg-huntingpets:client:birdSold`, `rsg-huntingpets:client:dogAnimations`, `rsg-huntingpets:client:dogFed`, `rsg-huntingpets:client:openShop`, `rsg-huntingpets:client:putawayDog`, `rsg-huntingpets:client:sellDogConfirm`, `rsg-huntingpets:client:spawnBird`, `rsg-huntingpets:client:spawnDog`, `rsg-huntingpets:sell:finishsell`, `rsg-huntingpets:sell:gotpoints_c`, `rsg-huntingpets:sell:updatepoints`, `rsg-huntingpets:sell:updatepoints1`, `rsg-huntingpets:start_sell`, `rsg-huntingpets:starthunt`

## Event handlers

**server:** `rsg-huntingpets:addscavengeditem`, `rsg-huntingpets:addxp`, `rsg-huntingpets:check_sell`, `rsg-huntingpets:checkhunt`, `rsg-huntingpets:sell:buyoffer`, `rsg-huntingpets:sell:create`, `rsg-huntingpets:sell:getpoints`, `rsg-huntingpets:sell:stop`, `rsg-huntingpets:server:buyBird`, `rsg-huntingpets:server:buyDog`, `rsg-huntingpets:server:callBird`, `rsg-huntingpets:server:callDog`, `rsg-huntingpets:server:feedDog`, `rsg-huntingpets:server:loadBird`, `rsg-huntingpets:server:loadDog`, `rsg-huntingpets:server:sellBird`, `rsg-huntingpets:server:sellDog`

**client:** `rsg-huntingpets:checktalk`, `rsg-huntingpets:client:dogFed`, `rsg-huntingpets:client:putawayDog`, `rsg-huntingpets:client:sellDogConfirm`, `rsg-huntingpets:client:spawnBird`, `rsg-huntingpets:client:spawnDog`, `rsg-huntingpets:sell:finishsell`, `rsg-huntingpets:sell:gotpoints_c`, `rsg-huntingpets:sell:updatepoints`, `rsg-huntingpets:sell:updatepoints1`, `rsg-huntingpets:starthunt`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-huntingpets:server:getPetData`, `rsg-huntingpets:server:getShopData`, `rsg-huntingpets:server:selectBird`, `rsg-huntingpets:server:selectDog`

## Commands (RegisterCommand)

**client:** `/callbird`, `/calldog`, `/fleebird`, `/fleedog`

## Database tables

`IF`, `player_birds`, `player_dogs`, `player_selected_pets`
