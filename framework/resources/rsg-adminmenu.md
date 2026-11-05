# rsg-adminmenu

Version 3.1.2. rsg-adminmenu

A full staff admin panel for **RSG Framework (RedM)**: a React NUI with tiered staff roles, player management, reports and tickets, logging, admin chat, world tools and server controls. **Version:** 3.1.0 · **Requires:** rsg-core, rsg-inventory, oxmysql · Developer and owner reference: [DOCS.md](DOCS.md) - **Dashboard**: live server stats, a greeting for the admin (their Discord name when a bot to

Source: https://github.com/Rexshack-RedM/rsg-adminmenu

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-adminmenu:server:`, `rsg-adminmenu:server:claimreport`, `rsg-adminmenu:server:createreport`, `rsg-adminmenu:server:deletereport`, `rsg-adminmenu:server:financeadd`, `rsg-adminmenu:server:financeremove`, `rsg-adminmenu:server:releasereport`, `rsg-adminmenu:server:replyreport`, `rsg-adminmenu:server:resolvereport`

**client:** `rsg-adminmenu:client:adminchatmessage`, `rsg-adminmenu:client:applyworldsettings`, `rsg-adminmenu:client:cleararea`, `rsg-adminmenu:client:clearweapons`, `rsg-adminmenu:client:drainstaminaplayer`, `rsg-adminmenu:client:drunkplayer`, `rsg-adminmenu:client:everyoneattackplayer`, `rsg-adminmenu:client:forceclose`, `rsg-adminmenu:client:hauntedplayer`, `rsg-adminmenu:client:horsebuckplayer`, `rsg-adminmenu:client:jumpscareplayer`, `rsg-adminmenu:client:killplayer`, `rsg-adminmenu:client:lightningplayer`, `rsg-adminmenu:client:newreportnotification`, `rsg-adminmenu:client:openadminmenu`, `rsg-adminmenu:client:openreportmenu`, `rsg-adminmenu:client:playerfire`, `rsg-adminmenu:client:ragdollplayer`, `rsg-adminmenu:client:reportreplynotification`, `rsg-adminmenu:client:spawnentity`, `rsg-adminmenu:client:spectateplayer`, `rsg-adminmenu:client:syncblips`, `rsg-adminmenu:client:wildattack`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`, `playerConnecting`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-adminmenu:server:`, `rsg-adminmenu:server:addadmin`, `rsg-adminmenu:server:addblip`, `rsg-adminmenu:server:addteleportlocation`, `rsg-adminmenu:server:addwhitelist`, `rsg-adminmenu:server:changeadminrole`, `rsg-adminmenu:server:cleararea`, `rsg-adminmenu:server:createadminchatmessage`, `rsg-adminmenu:server:deleteblip`, `rsg-adminmenu:server:deletehistoryentry`, `rsg-adminmenu:server:deleteteleportlocation`, `rsg-adminmenu:server:getPlayerData`, `rsg-adminmenu:server:getadminchatmessages`, `rsg-adminmenu:server:getadmins`, `rsg-adminmenu:server:getallitems`, `rsg-adminmenu:server:getallplayersmanaged`, `rsg-adminmenu:server:getallreports`, `rsg-adminmenu:server:getblips`, `rsg-adminmenu:server:getbotlogo`, `rsg-adminmenu:server:getdashboardstats`, `rsg-adminmenu:server:getlogs`, `rsg-adminmenu:server:getmyreports`, `rsg-adminmenu:server:getplayerhistory`, `rsg-adminmenu:server:getplayerinfo`, `rsg-adminmenu:server:getplayers`, `rsg-adminmenu:server:getreportdetails`, `rsg-adminmenu:server:getresources`, `rsg-adminmenu:server:getroleconfig`, `rsg-adminmenu:server:getserverstate`, `rsg-adminmenu:server:getstatistics`, `rsg-adminmenu:server:getteleportlocations`, `rsg-adminmenu:server:getwebhooksettings`, `rsg-adminmenu:server:getwhitelist`, `rsg-adminmenu:server:getworldsettings`, `rsg-adminmenu:server:kickallplayers`, `rsg-adminmenu:server:refreshresources`, `rsg-adminmenu:server:removeadmin`, `rsg-adminmenu:server:removeplayeritem`, `rsg-adminmenu:server:removewhitelist`, `rsg-adminmenu:server:savewebhooksettings`, `rsg-adminmenu:server:selfrevive`, `rsg-adminmenu:server:selftool`, `rsg-adminmenu:server:sendannouncement`, `rsg-adminmenu:server:sendlogtodiscord`, `rsg-adminmenu:server:setwhiteliststatus`, `rsg-adminmenu:server:spawnentity`, `rsg-adminmenu:server:togglecloseserver`, `rsg-adminmenu:server:unbanplayer`, `rsg-adminmenu:server:updateblip`

## Commands (RSGCore.Commands.Add)

**server:** `/adminmenu`, `/report`

## Public (table) functions

**client/client_doorid.lua:** `DoorIds.IsEnabled()`, `DoorIds.SetEnabled(state)`

**client/nui.lua:** `NUI.SendMessage(action, data)`, `NUI.Open(data)`, `NUI.Close()`, `NUI.IsOpen()`

## Database tables

`admin_activity_log`, `admin_chat_messages`, `admin_logs`, `admin_player_history`, `admin_report_messages`, `admin_report_nearby_players`, `admin_reports`, `admin_roles`, `admin_whitelist`, `adminmenu_blips`, `adminmenu_custom_items`, `adminmenu_settings`, `adminmenu_teleports`, `player_playtime`
