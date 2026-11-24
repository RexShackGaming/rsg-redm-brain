# rsg-radio

Version 3.3.2. rsg-radio - field radio (frequencies, job channels) on top of rsg-voice

Field radio for **RSG Framework (RedM)**, built on [rsg-voice](https://github.com/Rexshack-RedM/rsg-voice). Players with a radio item tune to a frequency and talk to everyone else on it, at any distance. Lawmen, medics (or any job, job type or gang you configure) get restricted channels. Version 3.3.2 · Requires rsg-core 3.0.3+, rsg-inventory, oxmysql and rsg-voice 3.2.0+ (radio volume, mute, sign

Source: https://github.com/Rexshack-RedM/rsg-radio

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-voice`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-radio']:Name)

**server:** `GetBattery(src)`, `GetFrequency(src)`

## Net events registered

**server:** `rsg-radio:server:addFavorite`, `rsg-radio:server:admin:`, `rsg-radio:server:cycleFavorite`, `rsg-radio:server:deletePrivate`, `rsg-radio:server:hogtied`, `rsg-radio:server:join`, `rsg-radio:server:leave`, `rsg-radio:server:panelClosed`, `rsg-radio:server:removeFavorite`, `rsg-radio:server:savePrivate`, `rsg-radio:server:setSettings`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Player:SetPlayerData`, `rsg-radio:client:admin:data`, `rsg-radio:client:admin:open`, `rsg-radio:client:battery`, `rsg-radio:client:hud`, `rsg-radio:client:open`, `rsg-radio:client:state`, `rsg-voice:client:radioTalk`

## Event handlers

**server:** `RSGCore:Player:SetPlayerData`, `RSGCore:Server:OnGangUpdate`, `RSGCore:Server:OnJobUpdate`, `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:SetDuty`, `rsg-voice:server:radioChanged`, `rsg-voice:server:radioTalkChanged`

**client:** `rsg-voice:client:onRadioTalk`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-radio:server:admin:getData`, `rsg-radio:server:getState`

## Commands (RSGCore.Commands.Add)

**server:** `/radioadmin`, `/radiodeleteprivate`, `/radiokick`, `/radiolist`, `/radiomute`, `/radiounmute`

## Commands (RegisterCommand)

**client:** `/+rsgradio_nextfav`, `/+rsgradio_prevfav`, `/-rsgradio_nextfav`, `/-rsgradio_prevfav`

## Database tables

`rsg_radio_private`
