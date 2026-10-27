# rsg-stables

Version 3.1.5. Horse and stables script for RSG Framework

Horse and stables system for the **RSG Framework** (RedM). Buy, stable, customise, care for and breed horses across multiple stable locations, all through a custom NUI. - **Multiple stables** – Valentine, Blackwater, Rhodes, Saint Denis and Strawberry out of the box, each with a stablehand NPC, map blip and horse preview spot. Add your own in config. - **Buy menu** – 100+ horse breeds/coats with h

Source: https://github.com/Rexshack-RedM/rsg-stables

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-stables:server:openDeadHorseInventory`, `rsg-stables:server:openHorseInventory`, `rsg-stables:server:saveHorsePosition`, `rsg-stables:server:wildHorseBroken`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-stables:client:horseDiedOfAge`, `rsg-stables:client:useBrush`, `rsg-stables:client:useFeed`, `rsg-stables:client:useLantern`, `rsg-stables:client:useStimulant`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Callbacks (lib.callback)

**server:** `rsg-stables:server:applyHorseCoat`, `rsg-stables:server:applyHorseTack`, `rsg-stables:server:brushHorse`, `rsg-stables:server:buyHorse`, `rsg-stables:server:claimWildHorse`, `rsg-stables:server:collectFoal`, `rsg-stables:server:feedHorse`, `rsg-stables:server:fleeStoreHorse`, `rsg-stables:server:getBreedingJobs`, `rsg-stables:server:getNearbyPlayers`, `rsg-stables:server:getStableHorses`, `rsg-stables:server:giveHorse`, `rsg-stables:server:horseDied`, `rsg-stables:server:insureHorse`, `rsg-stables:server:naturalDrink`, `rsg-stables:server:naturalGraze`, `rsg-stables:server:releaseHorse`, `rsg-stables:server:renameHorse`, `rsg-stables:server:restoreActiveHorse`, `rsg-stables:server:retrieveHorse`, `rsg-stables:server:reviveHorse`, `rsg-stables:server:startBreeding`, `rsg-stables:server:storeHorse`, `rsg-stables:server:toggleLantern`, `rsg-stables:server:transferHorse`, `rsg-stables:server:useStimulant`, `rsg-stables:server:waterHorse`

**client:** `rsg-stables:client:confirmHorseGift`

## Commands (RegisterCommand)

**client:** `/storehorse`

## Public (table) functions

**client/coat.lua:** `HorseCoat.Normalize(raw)`, `HorseCoat.Read(ped)`, `HorseCoat.Apply(ped, raw)`, `HorseCoat.ApplyNow(ped, raw)`

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`

## Database tables

`rsg_stables_breeding`, `rsg_stables_horses`
