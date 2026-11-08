# rsg-noticeboard

Version 3.1.0. rsg-noticeboard - player notice boards with NUI, fees, expiry/renewal and admin management

Town notice boards for the RSG Framework (RedM). Players use rsg-target on a bounty board to read notices and pin their own: events, wanted posters, items for sale and more. - **rsg-target** on `mp005_p_mp_bountyboard01x` and `mp005_p_mp_bountyboard02x`, covering the game's own boards and admin-placed ones - **Separate boards per town**: every board, including ones out in the wilds, shows the noti

Source: https://github.com/Rexshack-RedM/rsg-noticeboard

**Dependencies:** `rsg-core`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**client:** `rsg-noticeboard:client:expiryWarning`, `rsg-noticeboard:client:openAdmin`, `rsg-noticeboard:client:syncBoards`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

## Public (table) functions

**client/placer.lua:** `Placer.Start(model, cb)`, `Placer.Stop()`

**server/webhooks.lua:** `Webhook.PlayerFields(src, Player)`, `Webhook.NoticeFields(n)`, `Webhook.Send(event, data)`

**shared/config.lua:** `Config.Localize(prefix, list)`

## Database tables

`rsg_noticeboard_boards`, `rsg_noticeboard_notices`
