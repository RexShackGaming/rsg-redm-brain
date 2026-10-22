# rsg-voice

Version 3.0.3. rsg-voice - proximity voice for RSG Framework

Proximity voice for **RSG Framework (RedM)**, built on RedM's native Mumble voice. It adds selectable voice ranges, a draggable HUD, riding parties (group voice), automatic muting while dead or cuffed, and a server-enforced admin mute. - **Proximity voice ranges**: Whisper (2.5m), Normal (8m), Shout (20m) and Trail (35m), all configurable. - **Cycle range** with a key (default **]**) or the `/voic

Source: https://github.com/Rexshack-RedM/rsg-voice

**Dependencies:** `rsg-core`, `ox_lib`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-voice']:Name)

**client:** `GetVoiceRange()`, `IsMuted()`, `SetVoiceRangeIndex(i)`

## Net events registered

**server:** `rsg-voice:server:partyInvite`, `rsg-voice:server:partyKick`, `rsg-voice:server:partyLeave`, `rsg-voice:server:partyRespond`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Player:SetPlayerData`, `rsg-voice:client:adminMute`, `rsg-voice:client:partyInvite`, `rsg-voice:client:partyUpdate`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`

## Callbacks (lib.callback)

**server:** `rsg-voice:server:getParty`, `rsg-voice:server:isMuted`
