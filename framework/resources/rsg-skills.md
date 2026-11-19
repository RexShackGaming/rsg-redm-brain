# rsg-skills

Version 3.0.0. Framework-wide skills, XP, levels, perks and leaderboards for RSG Framework

Framework-wide skills for the RSG Framework: one shared place for XP, levels, rank titles, perks and leaderboards, so hunting, mining, farming and every other script can use the same progression instead of each keeping its own. Version 3.0.0 · Requires `rsg-core` and `oxmysql` · No ox_lib, no target and no inventory dependency Full developer and server owner documentation is in [DOCS.md](DOCS.md).

Source: https://github.com/Rexshack-RedM/rsg-skills

**Dependencies:** `oxmysql`, `rsg-core`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-skills']:Name)

**server:** `AddXP(...)`, `GetBoost(...)`, `GetLevel(...)`, `GetLevelByCitizenId(...)`, `GetPerk(...)`, `GetProgress(...)`, `GetSkillDefinitions(...)`, `GetSkills(...)`, `GetXP(...)`, `HasLevel(...)`, `RegisterSkill(...)`, `RemoveXP(...)`, `SetLevel(...)`, `SetXP(...)`

**client:** `CloseSkills()`, `GetLevel(skill)`, `GetPerk(skill, perk)`, `GetSkills()`, `GetXP(skill)`, `HasLevel(skill, level)`, `OpenSkills()`

## Net events registered

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-skills:client:sync`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`

**client:** `RSGCore:Client:OnPlayerUnload`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-skills:server:getLeaderboard`, `rsg-skills:server:getSkills`

## Commands (RSGCore.Commands.Add)

**server:** `/addskillxp`, `/resetskill`, `/setskilllevel`, `/setskillxp`, `/skillboost`, `/skillinfo`

## Public (table) functions

**server/database.lua:** `RSGSkills.WaitReady()`, `RSGSkills.WeekNumber(t)`, `RSGSkills.Load(src)`, `RSGSkills.Flush(awaitIt, onlyCid)`

**server/skills.lua:** `RSGSkills.RegisterSkill(key, def)`, `RSGSkills.SetBoost(mult, minutes)`, `RSGSkills.GetBoost()`, `RSGSkills.SyncClient(src, onlySkill)`, `RSGSkills.AddXP(src, skill, amount, reason, opts)`, `RSGSkills.RemoveXP(src, skill, amount)`, `RSGSkills.SetXP(src, skill, xp)`, `RSGSkills.SetLevel(src, skill, level)`, `RSGSkills.GetXP(src, skill)`, `RSGSkills.GetLevel(src, skill)`, `RSGSkills.HasLevel(src, skill, level)`, `RSGSkills.GetPerk(src, skill, perk)`, `RSGSkills.GetProgress(src, skill)`, `RSGSkills.GetSkills(src)`, `RSGSkills.GetSkillDefinitions()`, `RSGSkills.GetLevelByCitizenId(citizenid, skill)`, `RSGSkills.BuildPanel(src)`, `RSGSkills.LevelOfXP(skill, xp)`

## Database tables

`rsg_skills`, `rsg_skills_weekly`
