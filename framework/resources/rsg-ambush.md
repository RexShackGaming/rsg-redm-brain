# rsg-ambush

Version 3.0.1. rsg-ambush - random gang ambushes on the trail

Random gang ambushes for RSG Framework. While a player is riding outside of towns, every `Config.CheckInterval` seconds there's a `Config.TriggerChance`% roll. If it hits (and the server cooldown allows), a gang (O'Driscolls, Lemoyne Raiders, Murfree Brood or Skinner Brothers) spawns ahead of the player, partly on horseback, and attacks. Kill them and search the bodies (rsg-target) for cash, paid 

Source: https://github.com/Rexshack-RedM/rsg-ambush

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`

## Net events registered

**server:** `rsg-ambush:server:finish`, `rsg-ambush:server:registerPeds`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-ambush:client:force`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-ambush:server:loot`, `rsg-ambush:server:requestAmbush`

## Commands (RSGCore.Commands.Add)

**server:** `/testambush`
