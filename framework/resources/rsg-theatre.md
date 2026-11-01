# rsg-theatre

Version 3.0.0. Theatre Raleur (Saint Denis) stage shows

Theatre Raleur (Saint Denis) stage shows for RSG Framework, rebuilt from Rockstar's `show_nbx_*` scripts. - Ticket seller NPC at the theatre ticket fence (ox_target) with a playbill NUI - Server-scheduled shows (rotation or random) every `Config.ShowInterval` minutes

Source: https://github.com/Rexshack-RedM/rsg-theatre

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`, `rsg-doorlock`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-theatre:server:buyTicket`, `rsg-theatre:server:showFinished`

**client:** `rsg-theatre:client:playShow`, `rsg-theatre:client:stopShow`

## Callbacks (lib.callback)

**server:** `rsg-theatre:server:getPlaybill`
