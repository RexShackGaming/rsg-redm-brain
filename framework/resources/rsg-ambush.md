# rsg-ambush

Version 3.2.1. rsg-ambush - random gang ambushes on the trail

Version 3.2.1 · Random gang ambushes for RSG Framework · [Full docs](DOCS.md) While a player is riding outside of towns, every `Config.CheckInterval` seconds the server rolls a chance for an ambush. If it hits (and the cooldown allows), a warning sounds, then a gang (O'Driscolls, Lemoyne Raiders, Murfree Brood or Skinner Brothers) appears ahead of the player, partly on horseback, and attacks. Beat

Source: https://github.com/Rexshack-RedM/rsg-ambush

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`

## Net events registered

**server:** `rsg-ambush:server:claimWin`, `rsg-ambush:server:finish`, `rsg-ambush:server:registerPeds`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-ambush:client:force`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-ambush:server:loot`, `rsg-ambush:server:requestAmbush`

## Commands (RSGCore.Commands.Add)

**server:** `/testambush`
