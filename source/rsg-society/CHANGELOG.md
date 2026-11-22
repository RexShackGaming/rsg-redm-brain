# Changelog

## 3.4.0
- New: `RemoveJobSociety(name)` server export. Removes a job society and returns its balance (dollars) so the calling resource can pay it out. Refuses gangs and societies named in `Config.Jobs` / `Config.Locations`. Used by rsg-stores 3.2.0 to clean up when a player-owned store closes.
- The admin panel's *Remove society* action now shares the same code (`Soc.DeleteJobSociety`); behaviour is unchanged.
- Docs: listed `EnsureJobSociety` in the export table.

## 3.3.0
- New: admin panel, opened with `/societyadmin` (or a rebindable key). Tabs: Dashboard, Societies, Players, Desks, Fines, Audit, Tools. Manages every society: create job societies and gangs, funds, payroll, members, ranks and permissions, ledger, audit, fines, storage, disband or remove, place and remove desks, import, reload and prune.
- Every admin call is a server callback that checks `Config.AdminPermission` again, is throttled and validates its arguments. Admin actions are audited as `Name [admin]`.
- New config: `Config.Admin` (`Enabled`, `Command`, `Key`, `MaxFunds`).
- 91 new locale keys in all 11 languages (`ui_adm_*`, `sv_adm_*`, `key_admin`, `ui_create_short`).

## 3.2.1
- Added the `EnsureJobSociety(jobName)` server export: creates a job's society when the job exists in rsg-core. Used by rsg-ranch so every ranch has its own society.

## 3.2.0
- New: `bonus` (one-off payment to an online member) and `announce` (message of the day) permissions and actions.
- New: optional money controls, all off by default: `Config.OnDuty`, `Config.Withdraw.DailyLimit`, `Config.Transfers`.
- New: ledger filter by kind and "Copy CSV"; members search with online-only filter; storage log tab.
- New: gangs can add and delete ranks (`Config.Gang.MaxRanks`); exports `AddRank` and `RemoveRank`.
- Not included: two-person approval and fine appeals / payment plans (they need new request tables and a reviewer UI).
- 39 new locale keys in all 11 languages.

## 3.1.1
- Fix: a fine could be charged twice when two collections overlapped (login, payroll tick, `/payfines`, a new fine). Only one collection runs per player now.
- Fix: a disbanded gang left its ledger, audit rows and unpaid fines behind, and a new gang with the same name inherited them. They are deleted with the gang.
- Fix: reloading the data (`/societymigrate`) emptied the live tables while it ran, so job wages were paid without touching the account. The new tables are swapped in at once.
- Fix: saving a gang rank sent two requests and the second was often rejected by the action cooldown. Name, wage and permissions are one request now (the `rankmeta` action is gone, `perms` takes `meta`).
- Fix: gang names without latin letters (Russian, Greek, Japanese...) were refused, and name length was counted in bytes. Names are counted in characters and get an internal id like `gang_2`.
- Fix: the invite window now closes itself when the invite expires, and an expired or stale invite tells the player instead of failing silently. The rank is checked again on accept.
- Fix: imported balances were truncated instead of rounded (19.99 became 19.98).
- Fix: `Config.VersionCheck` was never defined, so the version check never ran.
- Security: `ProcessWage` and `RefundWage` only answer `rsg-core` (`Config.Payroll.TrustedWageCaller`).
- Security: new `Config.Fines.IssueLimit` / `IssueWindowMinutes` cap how many fines one person can issue.
- Security: opening the menu and loading tabs are throttled (`Config.ReadCooldown`); a failing callback now answers instead of timing out.
- Clean-up: removed the unused `moreButton`, the redundant `uiFocus` flag and the Font Awesome download (two icons are drawn with CSS). The push-to-talk loop only runs while the menu is open. The three "load more" lists share one helper, and a failed "load more" no longer loses its button.
- Speed: member lists and gang payroll build the rank table once instead of once per member.
- New locale key in all 11 languages: `sv_err_fine_limit`, `sv_err_invite_gone`.

## 3.1.0
- New exports for gang resources: `SetGangInfo`, `DisbandGang`, `GetRanks`, `SetGangOwner` and `IsReady`.
- New server event `rsg-society:server:gangUpdated` (name, colour, tag or owner of a gang changed).
- The Settings tab now uses the same code as `SetGangInfo`, so both behave the same.
- rsg-gangs 3.5.0 builds on these: it no longer keeps its own members, ranks or bank.

## 3.0.1
- Fix: job societies (vallaw, medic and so on) were not created and the desk showed "something went wrong". Job data is now read from rsg-core's live job definitions instead of a stale copy of RSGCore.Shared.Jobs.

## 3.0.0
- First release. Replaces rsg-bossmenu and rsg-gangmenu.
- Members, ranks, permissions, bank, payroll (skips an empty account), storage, fines, audit trail, API, import of old data.
