# rsg-prison

Version 3.0.0. rsg-prison

**Complete prison system for RedM servers using RSG Core.** > Fully integrated jail and sentence system for RedM built on RSG Core. > Handles jailing, job removal, sentence timers, and automatic release with ox_lib prompts and blips.

Source: https://github.com/Rexshack-RedM/rsg-prison

**Dependencies:** `rsg-core`, `ox_lib`

## Net events registered

**server:** `rsg-prison:server:CheckRecordStatus`, `rsg-prison:server:FreePlayer`, `rsg-prison:server:GiveJailItems`, `rsg-prison:server:RemovePlayerJob`, `rsg-prison:server:SaveJailItems`, `rsg-prison:server:resetoutlawstatus`, `rsg-prison:server:updateSentance`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-prison:client:Enter`, `rsg-prison:client:freedom`, `rsg-prison:client:menu`, `rsg-prison:client:prisonclothes`, `rsg-prison:client:shop`, `rsg-prison:client:telegrammenu`

## Event handlers

**client:** `rsg-prison:client:jailZoneInOut`, `rsg-prison:client:prisonclothes`, `rsg-prison:client:shop`

## Server events it triggers in other resources

**client:** `InteractSound_SV:PlayWithinDistance`, `rsg-shops:server:openstore`
