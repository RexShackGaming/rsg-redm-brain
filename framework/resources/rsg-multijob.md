# rsg-multijob

Version 3.1.2. rsg-multijob

A multi-job system for **RSG-Core** (RedM). Lets players hold and switch between several jobs at once, gives admins a command to strip a job from a player, keeps `rsg-bossmenu` firings in sync, and logs everything to Discord via webhooks. Version: `3.1.0` - **Multiple jobs per character** — players can hold up to a configurable number of jobs at the same time (`Config.MaxJobs`), stored per `citize

Source: https://github.com/Rexshack-RedM/rsg-multijob

Has NUI (`ui_page`).

## Exports (call as exports['rsg-multijob']:Name)

**server:** `AddJob(identifier, job, grade, bypassMax)`, `CanTakeJob(identifier, job, bypassMax)`, `GetJobCount(identifier)`, `GetJobDefinition(name)`, `GetJobDefinitions()`, `GetJobs(identifier)`, `HasJob(identifier, job)`, `RemoveJob(identifier, job)`

## Net events registered

**server:** `rsg-bossmenu:server:FireEmployee`, `rsg-multijob:server:changeJob`, `rsg-multijob:server:deleteJob`

**client:** `RSGCore:Client:OnJobUpdate`, `rsg-multijob:client:openAdmin`, `rsg-multijob:client:openmenu`, `rsg-multijob:client:refreshJobs`

## Event handlers

**server:** `RSGCore:Server:OnJobUpdate`

## Callbacks (lib.callback)

**server:** `rsg-multijob:server:admin:deleteJob`, `rsg-multijob:server:admin:getJobs`, `rsg-multijob:server:admin:importCore`, `rsg-multijob:server:admin:saveJob`, `rsg-multijob:server:myJobs`

## Commands (RSGCore.Commands.Add)

**server:** `/myjobs`, `/removejob`

## Server events it triggers in other resources

**client:** `RSGCore:ToggleDuty`

## Public (table) functions

**server/jobs.lua:** `JobRegistry.IsLoaded()`, `JobRegistry.Get(name)`, `JobRegistry.All()`, `JobRegistry.Save(input, isNew)`, `JobRegistry.Delete(name)`, `JobRegistry.ImportFromCore()`, `JobRegistry.HolderCounts()`

**server/webhook.lua:** `Webhook.Send(eventName, data)`

## Database tables

`multijob_jobs`, `player_jobs`
