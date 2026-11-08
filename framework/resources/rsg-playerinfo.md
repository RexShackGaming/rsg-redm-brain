# rsg-playerinfo

Version 3.0.0. rsg-playerinfo

**Player information / quick stats display for RedM (RSG Core).** > Shows a small context menu with the player's name and configurable stats (outlaw status, job, cash, banks, IDs, etc.). > Triggered via the `/info` command and shown in a custom NUI panel (RDR2 leather & gold style).

Source: https://github.com/Rexshack-RedM/rsg-playerinfo

**Dependencies:** `rsg-core`

Has NUI (`ui_page`).

## Net events registered

**client:** `rsg-playerstats:client:openPlayerStats`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-playerstats:server:getPlayerData`

## Commands (RSGCore.Commands.Add)

**server:** `/info`
