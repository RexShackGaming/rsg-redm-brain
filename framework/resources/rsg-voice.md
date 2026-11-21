# rsg-voice

Version 3.2.0. rsg-voice - proximity voice for RSG Framework

Proximity voice for **RSG Framework (RedM)**, built on RedM's native Mumble voice. It adds selectable voice ranges, a draggable HUD, riding parties (group voice), automatic muting while dead or cuffed, and a server-enforced admin mute. - **Proximity voice ranges**: Whisper (2.5m), Normal (8m), Shout (20m) and Trail (35m), all configurable. - **Cycle range** with a key (default **]**) or the `/voic

Source: https://github.com/Rexshack-RedM/rsg-voice

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-voice']:Name)

**server:** `GetPartyMembers(src)`, `GetPlayerRadio(src)`, `GetRadioMembers(freq)`, `IsInParty(src)`, `IsPlayerMuted(src)`, `JoinRadio(src, freq)`, `LeaveRadio(src)`, `SetPlayerMuted(src, state, reason)`

**client:** `GetPartyMembers()`, `GetRadio()`, `GetRadioSignal()`, `GetRadioTalkKey()`, `GetRadioVolume()`, `GetVoiceRange()`, `IsCallActive()`, `IsInParty()`, `IsMuted()`, `IsPlayerTalking(sid)`, `IsRadioMuted()`, `IsRadioTalking()`, `SetCallActive(state)`, `SetMuteOverride(state, reason)`, `SetRadioMuted(state)`, `SetRadioSignal(q)`, `SetRadioVolume(v)`, `SetVoiceRangeIndex(i)`

## Net events registered

**server:** `rsg-voice:server:partyInvite`, `rsg-voice:server:partyKick`, `rsg-voice:server:partyLeave`, `rsg-voice:server:partyRespond`, `rsg-voice:server:partyWaypoint`, `rsg-voice:server:radioTalk`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Player:SetPlayerData`, `rsg-voice:client:muteState`, `rsg-voice:client:partyInvite`, `rsg-voice:client:partyPositions`, `rsg-voice:client:partyUpdate`, `rsg-voice:client:partyWaypoint`, `rsg-voice:client:radioTalk`, `rsg-voice:client:radioUpdate`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-voice:server:getParty`, `rsg-voice:server:isMuted`

## Commands (RegisterCommand)

**client:** `/+rsgvoice_radio`, `/-rsgvoice_radio`

## Database tables

`rsg_voice_mutes`
