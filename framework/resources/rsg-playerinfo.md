# rsg-playerinfo

Version 2.0.1. rsg-playerinfo

**Player information / quick stats display for RedM (RSG Core).** > Shows a small context menu with the player's name and configurable stats (outlaw status, job, cash, banks, IDs, etc.). > Triggered via the `/info` command and built with lib contexts (ox_lib).

Source: https://github.com/Rexshack-RedM/rsg-playerinfo

**Dependencies:** `rsg-core`, `ox_lib`

## Net events registered

**client:** `rsg-playerstats:client:openPlayerStats`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-playerstats:server:getPlayerData`

## Commands (RSGCore.Commands.Add)

**server:** `/info`
