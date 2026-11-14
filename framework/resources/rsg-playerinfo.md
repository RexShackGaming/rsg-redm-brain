# rsg-playerinfo

Version 3.1.0. rsg-playerinfo

**Full-screen player information dashboard for RedM (RSG Core).** > `/info` opens a dashboard that fills 80% of the screen (configurable) showing everything about your character: money, identity, job, condition and reputation. RDR2 "leather & gold" house style. Version 3.1.0 · Full technical details in [DOCS.md](DOCS.md)

Source: https://github.com/Rexshack-RedM/rsg-playerinfo

**Dependencies:** `rsg-core`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-playerinfo']:Name)

**server:** `DamageBone(src, key, amount)`, `GetBones(src)`, `GetSeverity(src, what)`, `HealBones(src, key)`, `OpenPlayerInfo(src)`

**client:** `AreEffectsEnabled()`, `BandageBones()`, `ClosePlayerInfo()`, `DamageBone(key, amount)`, `GetBoneHealth()`, `GetBoneStatus(key)`, `GetSeverity(what)`, `GetSplints()`, `HasInjury(what)`, `HealBones(key)`, `IsPlayerInfoOpen()`, `OpenPlayerInfo()`, `SetEffectsEnabled(state)`, `SplintBones()`

## Net events registered

**server:** `rsg-playerinfo:server:saveBones`, `rsg-playerinfo:server:treatCancel`, `rsg-playerinfo:server:treatDone`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-medic:client:heal`, `rsg-medic:client:revive`, `rsg-playerinfo:client:applyTreatment`, `rsg-playerinfo:client:damageBone`, `rsg-playerinfo:client:healBones`, `rsg-playerinfo:client:openExam`, `rsg-playerinfo:client:useTreatment`, `rsg-playerstats:client:openPlayerStats`

## Event handlers

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-playerinfo:client:boneWorsened`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-playerstats:server:getPlayerData`

## Commands (RSGCore.Commands.Add)

**server:** `/healbones`, `/info`

## Public (table) functions

**client/bones.lua:** `BoneTracker.severity(value)`, `BoneTracker.status(value)`, `BoneTracker.get()`, `BoneTracker.getSplints()`, `BoneTracker.heal(key)`, `BoneTracker.bandage()`, `BoneTracker.splint()`, `BoneTracker.canBandage()`, `BoneTracker.canSplint()`, `BoneTracker.damage(key, amount)`
