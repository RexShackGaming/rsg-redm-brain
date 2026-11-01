# rsg-voice

Version 3.0.4. rsg-voice - proximity voice for RSG Framework

Proximity voice for **RSG Framework (RedM)**, built on RedM's native Mumble voice. It adds selectable voice ranges, a draggable HUD, riding parties (group voice), automatic muting while dead or cuffed, and a server-enforced admin mute. - **Proximity voice ranges**: Whisper (2.5m), Normal (8m), Shout (20m) and Trail (35m), all configurable. - **Cycle range** with a key (default **]**) or the `/voic

Source: https://github.com/Rexshack-RedM/rsg-voice

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-voice']:Name)

**server:** `GetPartyMembers(src)`, `IsInParty(src)`, `IsPlayerMuted(src)`, `SetPlayerMuted(src, state, reason)`

**client:** `GetPartyMembers()`, `GetVoiceRange()`, `IsInParty()`, `IsMuted()`, `IsPlayerTalking(sid)`, `SetMuteOverride(state, reason)`, `SetVoiceRangeIndex(i)`

## Net events registered

**server:** `rsg-voice:server:partyInvite`, `rsg-voice:server:partyKick`, `rsg-voice:server:partyLeave`, `rsg-voice:server:partyRespond`, `rsg-voice:server:partyWaypoint`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Player:SetPlayerData`, `rsg-voice:client:muteState`, `rsg-voice:client:partyInvite`, `rsg-voice:client:partyPositions`, `rsg-voice:client:partyUpdate`, `rsg-voice:client:partyWaypoint`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-voice:server:getParty`, `rsg-voice:server:isMuted`

## Database tables

`rsg_voice_mutes`
