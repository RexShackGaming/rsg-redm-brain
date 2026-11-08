# rsg-stables

Version 3.4.1. Horse and stables script for RSG Framework

Horse and stables system for the **RSG Framework** (RedM). Buy, stable, customise, care for and breed horses across multiple stable locations, all through a custom NUI. - **Multiple stables** – Valentine, Blackwater, Rhodes, Saint Denis and Strawberry out of the box, each with a stablehand NPC, map blip and horse preview spot. Add your own in config. - **Buy menu** – 100+ horse breeds/coats with h

Source: https://github.com/Rexshack-RedM/rsg-stables

**Dependencies:** `rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-stables']:Name)

**client:** `GetActiveHorseNeeds()`, `GetHorseBonusInfo()`

## Net events registered

**server:** `rsg-stables:server:openDeadHorseInventory`, `rsg-stables:server:openFieldSaddlebags`, `rsg-stables:server:openHorseInventory`, `rsg-stables:server:saveHorsePosition`, `rsg-stables:server:trainingRideTick`, `rsg-stables:server:wildHorseBroken`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-stables:client:fieldCorpse`, `rsg-stables:client:horseDiedOfAge`, `rsg-stables:client:raceRoute`, `rsg-stables:client:trainingUpdate`, `rsg-stables:client:useBrush`, `rsg-stables:client:useFeed`, `rsg-stables:client:useLantern`, `rsg-stables:client:useMedicine`, `rsg-stables:client:useReviver`, `rsg-stables:client:useStimulant`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

**client:** `rsg-stables:client:horseSpawned`, `rsg-stables:client:openTraining`, `rsg-stables:client:tackChanged`

## Commands (RegisterCommand)

**client:** `/storehorse`

## Public (table) functions

**client/coat.lua:** `HorseCoat.Normalize(raw)`, `HorseCoat.Read(ped)`, `HorseCoat.Apply(ped, raw)`, `HorseCoat.ApplyNow(ped, raw)`

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`

## Database tables

`rsg_stables_breeding`, `rsg_stables_horses`, `rsg_stables_races`
