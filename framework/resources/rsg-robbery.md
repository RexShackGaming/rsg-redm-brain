# rsg-robbery

Version 3.0.0. Player-to-player robbery system for RSG Framework

Player-to-player robbery system for RedM / RSG Core. **Approach** a player and get close (within ~2.5m) **Target them** using the third-eye targeting system (press the target key) they need to have hands up

Source: https://github.com/Rexshack-RedM/rsg-robbery

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`

## Net events registered

**server:** `rsg-inventory:server:closeInventory`, `rsg-robbery:server:confirmrobbery`, `rsg-robbery:server:robplayer`, `rsg-robbery:server:uncuffplayer`

**client:** `rsg-robbery:client:getcuffed`, `rsg-robbery:client:uncuffed`, `rsg-robbery:client:verifyhandsup`

## Commands (RSGCore.Commands.Add)

**server:** `/uncuff`
