# rsg-npcdialog

Version 3.1.1. NPC dialog system for the RSG Framework

NPC dialog and quest system for the RSG Framework (RedM). Version **3.1.1**. Branching conversations with a cinematic camera, written in config files, registered by other scripts, or built in-game by admins. Full developer and server owner documentation is in [DOCS.md](DOCS.md). **Dependencies:** rsg-core, rsg-inventory, rsg-target, rsg-gizmo, oxmysql

Source: https://github.com/Rexshack-RedM/rsg-npcdialog

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-npcdialog']:Name)

**server:** `AbandonQuest(src, id)`, `AddQuestProgress(src, questId, objectiveId, amount)`, `ClearFlag(src, flag)`, `CloseDialog(src)`, `CompleteQuest(src, id)`, `GetQuestState(src, id)`, `HasFlag(src, flag)`, `OpenDialog(src, npcId, node)`, `RegisterAction(name, cb)`, `RegisterCondition(name, cb)`, `RegisterNPC(def)`, `RegisterQuest(raw)`, `RemoveNPC(id)`, `RemoveQuest(id)`, `ResetProgress(citizenid, npcId)`, `SetFlag(src, flag)`, `StartQuest(src, id)`

**client:** `Close()`, `IsOpen()`, `Open(npcId)`, `OpenJournal()`

## Net events registered

**server:** `rsg-npcdialog:server:closed`, `rsg-npcdialog:server:questKill`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-npcdialog:client:close`, `rsg-npcdialog:client:markers`, `rsg-npcdialog:client:openEditor`, `rsg-npcdialog:client:quests`, `rsg-npcdialog:client:show`, `rsg-npcdialog:client:sync`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerDropped`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-npcdialog:server:abandonQuest`, `rsg-npcdialog:server:canEdit`, `rsg-npcdialog:server:choose`, `rsg-npcdialog:server:delete`, `rsg-npcdialog:server:editorData`, `rsg-npcdialog:server:getNPCs`, `rsg-npcdialog:server:getQuests`, `rsg-npcdialog:server:open`, `rsg-npcdialog:server:save`

## Public (table) functions

**server/database.lua:** `DB.Setup()`, `DB.LoadNPCs()`, `DB.SaveNPC(id, data, by)`, `DB.DeleteNPC(id)`, `DB.LoadQuests()`, `DB.SaveQuest(id, data, by)`, `DB.DeleteQuest(id)`, `DB.QuestStates(cid)`, `DB.SaveQuestState(cid, questId, state)`, `DB.Progress(cid)`, `DB.Set(cid, kind, name, value)`, `DB.Reset(cid, npcId)`, `DB.Unload(cid)`

**server/engine.lua:** `Engine.Meets(src, Player, progress, r, npcId)`, `Engine.Transact(src, Player, cost, reward, reason)`, `Engine.Progression(src, reward, reason)`

**server/quests.lua:** `Quests.Add(raw, source, owner)`, `Quests.Remove(id)`, `Quests.State(src, Player, progress, id)`, `Quests.EverCompleted(Player, id)`, `Quests.View(src)`, `Quests.Sync(src, force)`, `Quests.SyncAll()`, `Quests.CanStart(src, Player, progress, id)`, `Quests.Start(src, id)`, `Quests.Abandon(src, id)`, `Quests.Complete(src, id, extraCost, extraReward)`, `Quests.OnTalk(src, npcId, node, choice)`, `Quests.OnNode(src, npcId, node)`, `Quests.AddProgress(src, questId, objectiveId, amount)`, `Quests.Forget(src)`

**server/validate.lua:** `Validate.NPC(def)`, `Validate.Quest(def)`

**server/world.lua:** `World.Hour()`, `World.Weather()`, `World.InHours(hour, from, to)`, `World.Period(kind, at)`, `World.NextReset(kind, now)`, `World.Hash(s)`, `World.WaitText(seconds)`

## Database tables

`rsg_npcdialog_npcs`, `rsg_npcdialog_progress`, `rsg_npcdialog_quest_progress`, `rsg_npcdialog_quests`
