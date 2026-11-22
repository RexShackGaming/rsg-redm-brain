# rsg-society

Version 3.4.0. Societies for the RSG Framework: members, ranks, permissions, finances, payroll, storage, fines, audit trail and an API. Replaces rsg-bossmenu and rsg-gangmenu and owns gang membership.

One resource for everything a job or gang organisation needs: members and ranks, permissions, a bank account, payroll, shared storage, fines and a full audit trail, plus an API so other scripts can plug in. It replaces **rsg-bossmenu** and **rsg-gangmenu** (it `provide`s both names) and becomes the single source of truth for gang membership. Dependencies: `rsg-core` (3.5.0+), `rsg-inventory`, `oxm

Source: https://github.com/Rexshack-RedM/rsg-society

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-society']:Name)

**server:** `AddGangMoney(name, amount, reason, actor)`, `AddMember(name, id, level)`, `AddMoney(name, amount, reason, actor)`, `AddRank(name, rankName)`, `Audit(name, actorCid, action, detail, targetCid)`, `CreateGang(label, ownerCid)`, `DisbandGang(name)`, `EnsureJobSociety(name)`, `GetAccount(name)`, `GetBalance(name)`, `GetGangAccount(name)`, `GetMembers(name)`, `GetPlayerGang(id)`, `GetPlayerSocieties(id)`, `GetRanks(name)`, `GetSocieties(sType)`, `GetSociety(name)`, `HasPermission(id, name, perm)`, `IsBoss(id, name)`, `IsReady()`, `IssueFine(src, targetId, name, amount, reason)`, `OpenStorage(src, name)`, `ProcessWage(src, jobName, amount)`, `RefundWage(jobName, amount)`, `RegisterPermission(perm, gangOnly)`, `RemoveGangMoney(name, amount, reason, actor)`, `RemoveJobSociety(name)`, `RemoveMember(name, id)`, `RemoveMoney(name, amount, reason, actor)`, `RemoveRank(name, level)`, `RunPayroll(name)`, `SetGangInfo(name, data)`, `SetGangOwner(name, cid)`, `SetMemberLevel(name, id, level)`

## Net events registered

**server:** `rsg-society:server:inviteReply`, `rsg-society:server:requestLocations`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `rsg-bossmenu:client:mainmenu`, `rsg-gangmenu:client:mainmenu`, `rsg-society:client:invite`, `rsg-society:client:locations`, `rsg-society:client:openDesk`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`, `rsg-multijob:server:jobsLoaded`

## Commands (RSGCore.Commands.Add)

**server:** `/addsociety`, `/fines`, `/payfines`, `/removegang`, `/removesocietydesk`, `/societydesk`, `/societyfunds`, `/societymigrate`

## Public (table) functions

**server/admin.lua:** `Tabs.dashboard()`, `Tabs.job_options()`, `Tabs.societies(_, arg)`, `Tabs.s_overview(_, arg)`, `Tabs.s_members(_, arg)`, `Tabs.s_ranks(_, arg)`, `Tabs.s_ledger(_, arg)`, `Tabs.s_audit(_, arg)`, `Tabs.s_fines(_, arg)`, `Tabs.audit(_, arg)`, `Tabs.fines(_, arg)`, `Tabs.players(_, arg)`, `Tabs.player(_, arg)`, `Tabs.desks()`, `Tabs.tools()`, `Actions.create_job(ctx, data)`, `Actions.create_gang(ctx, data)`, `Soc.DeleteJobSociety(name)`, `Actions.delete_job(ctx, data)`, `Actions.disband(ctx, data)`, `Actions.funds(ctx, data)`, `Actions.payroll(ctx, data)`, `Actions.run_payroll(_, data)`, `Actions.gang_info(ctx, data)`, `Actions.set_owner(ctx, data)`, `Actions.member_add(ctx, data)`, `Actions.member_level(ctx, data)`, `Actions.member_remove(ctx, data)`, `Actions.rank_save(ctx, data)`, `Actions.rank_add(ctx, data)`, `Actions.rank_delete(ctx, data)`, `Actions.fine_void(ctx, data)`, `Actions.fines_forgive(ctx, data)`, `Actions.desk_add(ctx, data)`, `Actions.desk_remove(ctx, data)`, `Actions.desk_goto(_, data)`, `Actions.storage_open(ctx, data)`, `Actions.migrate()`, `Actions.reload()`, `Actions.prune(ctx, data)`

**server/callbacks.lua:** `Tabs.members(ctx)`, `Tabs.nearby(ctx, arg)`, `Tabs.ranks(ctx)`, `Tabs.finance(ctx, arg)`, `Tabs.fines(ctx, arg)`, `Tabs.audit(ctx, arg)`, `Tabs.stash(ctx)`, `Tabs.settings(ctx)`, `Actions.invite(ctx, data)`, `Actions.fire(ctx, data)`, `Actions.setrank(ctx, data)`, `Actions.transfer(ctx, data)`, `Actions.deposit(ctx, data)`, `Actions.withdraw(ctx, data)`, `Actions.payroll(ctx, data)`, `Actions.perms(ctx, data)`, `Actions.bonus(ctx, data)`, `Actions.transfer_funds(ctx, data)`, `Actions.motd(ctx, data)`, `Actions.rank_add(ctx, data)`, `Actions.rank_delete(ctx, data)`, `Actions.fine(ctx, data)`, `Actions.voidfine(ctx, data)`, `Actions.storage(ctx)`, `Actions.settings(ctx, data)`, `Actions.leave(ctx)`, `Actions.disband(ctx, data)`

**server/finance.lua:** `Soc.RunGangPayroll(name)`, `Soc.CollectFines(Player)`, `Soc.IsCollecting(cid)`, `Soc.Owed(cid)`, `Soc.IssueFine(issuer, targetCid, name, amount, reason)`, `Soc.VoidFine(name, fineId, actorCid, actorName)`, `Soc.FineRows(name, before)`

**server/main.lua:** `Soc.Notify(src, title, description, nType)`, `Soc.ToCents(amount)`, `Soc.FullName(charinfo)`, `Soc.PlayerName(Player)`, `Soc.OnCooldown(src)`, `Soc.OnReadCooldown(src)`, `Soc.JobDef(name)`, `Soc.JobExists(name)`, `Soc.Label(name)`, `Soc.PermList(sType)`, `Soc.IsValidPerm(sType, perm)`, `Soc.Grades(name)`, `Soc.GradeOf(name, level)`, `Soc.PermsFor(name, level, boss)`, `Soc.JobLevel(cid, jobName, Player)`, `Soc.Access(cid, name, Player)`, `Soc.SocietiesOf(cid)`, `Soc.NearDesk(src, name)`, `Soc.LocationList()`, `Soc.BroadcastLocations(target)`, `Soc.Audit(name, actorCid, actorName, action, detail, targetCid, targetName)`, `Soc.Credit(name, cents, kind, note, cid, actor)`, `Soc.Debit(name, cents, kind, note, cid, actor)`, `Soc.RegisterRow(name, sType, label, opts)`, `Soc.EnsureJob(name, await)`, `Soc.Load()`, `Soc.OnStart(priority, fn)`, `Soc.GetMembers(name)`

**server/members.lua:** `Soc.CanManage(acc, targetLevel)`, `Soc.MaxAssignable(acc)`, `Soc.SyncGangDef(name)`, `Soc.ApplyMember(cid)`, `Soc.MemberRows(name, acc, myCid)`, `Soc.AddGangMember(name, cid, charName, level)`, `Soc.RemoveGangMember(name, cid)`, `Soc.SetGangLevel(name, cid, level)`, `Soc.AddJobMember(name, cid, level)`, `Soc.RemoveJobMember(name, cid)`, `Soc.SetJobLevel(name, cid, level)`, `Soc.SendInvite(src, targetSrc, name, level)`, `Soc.LabelTaken(label, exceptName)`, `Soc.SeedRanks(name, defs, await)`, `Soc.CreateGang(label, ownerCid, ownerName, opts)`, `Soc.SetInfo(name, data, actorCid, actorName)`, `Soc.DisbandGang(name)`, `Soc.AddRank(name, rankName)`, `Soc.RemoveRank(name, level)`

**server/migration.lua:** `Soc.Migrate(force)`

## Database tables

`rsg_societies`, `rsg_society_audit`, `rsg_society_fines`, `rsg_society_ledger`, `rsg_society_locations`, `rsg_society_members`, `rsg_society_meta`, `rsg_society_perms`, `rsg_society_ranks`
