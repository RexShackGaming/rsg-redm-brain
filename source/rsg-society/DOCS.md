# rsg-society 3.2.0 – Documentation

## Contents
1. Architecture 2. Data 3. Permissions 4. Payroll 5. Fines 6. Exports 7. Events 8. Commands 9. rsg-core change 10. Migration 11. Security 12. Database 13. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `server/database.lua` | `Soc` namespace, builds tables from `install.sql` |
| `server/main.lua` | Access/permission resolution, bank (`Soc.Credit/Debit`), audit, load, public exports |
| `server/members.lua` | Gang and job membership, invites, mirrors gangs into rsg-core |
| `server/finance.lua` | Wages, gang payroll timer, fines |
| `server/callbacks.lua` | NUI callbacks (`open`, `tab`, `act`, `createGang`) |
| `server/migration.lua` | One-time import |
| `server/commands.lua` | Admin commands, desk locations |
| `client/main.lua`, `html/*` | Desks, prompts, blips, NUI |

Jobs: membership stays in rsg-core (multi-job); this resource reads the grade. Gangs: membership lives in `rsg_society_members` and is mirrored to rsg-core with `SetGangs` / `Player.Functions.SetGang`.

## 2. Data
Money is stored in cents (`balance_cents`) and cached in memory; changes are delta SQL updates and a ledger row each. Tables: `rsg_societies`, `rsg_society_ranks`, `rsg_society_perms`, `rsg_society_members`, `rsg_society_ledger`, `rsg_society_audit`, `rsg_society_fines`, `rsg_society_locations`, `rsg_society_meta` (also holds each announcement as key `motd:<name>`).

## 3. Permissions
`members hire fire promote finance deposit withdraw payroll bonus storage fines finevoid audit announce ranks settings`; gangs also `disband equipment upgrade bounty`. Bosses have all. A rank can only grant permissions its editor holds. Other scripts add their own with `RegisterPermission`.

## 4. Payroll
rsg-core calls `ProcessWage` for each wage. `'paid'`: society debited, core pays the player. `'skipped'`: balance too low, nobody is paid, employee and bosses are notified. `'unmanaged'`: not a society job or payroll off, core pays as before. If core fails to pay after `'paid'`, it calls `RefundWage`. Gangs: `Config.Payroll.GangInterval` minutes, highest rank first, same skip rule.
`ProcessWage` and `RefundWage` move society money, so they only answer the resource named in `Config.Payroll.TrustedWageCaller` (`rsg-core`); any other caller gets `'unmanaged'` / `false`.

## 5. Fines
Amount limits in `Config.Fines`. Collected from `PayWith` in order. With `AllowPartial` the rest stays unpaid and is collected on login/payroll. Credited to the society ledger as `fine`. One person may issue at most `Config.Fines.IssueLimit` fines per `IssueWindowMinutes` (0 = no limit), so a rogue member cannot empty a player in seconds. Only one collection runs per player at a time, so a fine can never be charged twice.

## 5b. Money controls and features (3.2.0)
- `Config.OnDuty`: when `Enabled`, the listed actions (`deposit withdraw payroll bonus fine transfer_funds`) need the player on duty.
- `Config.Withdraw.DailyLimit`: sum of `withdraw` ledger rows in the last 24 h per player; bosses skip it when `BossesExempt`.
- `bonus`: needs the `bonus` permission and an online member of the same society; capped by `Config.Bonus.Max`, paid from the account, logged as `bonus`.
- `transfer_funds`: only when `Config.Transfers.Enabled`; target must be another society (same type if `SameTypeOnly`); capped by `Transfers.Max`.
- `motd`: needs `announce`, shown on the overview (max `Config.Motd.MaxLength`).
- `rank_add` / `rank_delete`: gangs only, `ranks` permission.
- Storage log tab: reads `exports['rsg-inventory']:GetStashHistory('society_<name>', 100)`; needs `audit`.
- Ledger tab accepts a kind filter; the CSV is copied to the clipboard.

## 6. Exports (server)
| Export | Returns |
|---|---|
| `GetAccount(name)` / `GetBalance(name)` | balance (dollars); job societies are created on demand |
| `GetGangAccount(name)` | balance |
| `AddMoney(name, amount, reason, actor?)` / `RemoveMoney(...)` (also `AddGangMoney`, `RemoveGangMoney`) | bool (remove fails if balance is too low) |
| `GetSociety(name)`, `GetSocieties(type?)`, `GetPlayerSocieties(id)` | society info |
| `HasPermission(id, name, perm)`, `IsBoss(id, name)` | bool (`id` = server id or citizenid) |
| `GetMembers(name)` | member list |
| `Audit(name, actorCid, action, detail, targetCid)` | writes an audit row |
| `RegisterPermission(perm, gangOnly)` | adds a permission |
| `ProcessWage(src, job, amount)` / `RefundWage(job, amount)` | used by rsg-core |
| `RunPayroll(name)` | runs gang payroll now |
| `IssueFine(src, targetId, name, amount, reason)` | ok, fineId or locale key |
| `GetPlayerGang(id)`, `CreateGang(label, ownerCid)`, `AddMember(name, id, level)`, `RemoveMember(name, id)`, `SetMemberLevel(name, id, level)` | gang API |
| `SetGangInfo(name, { label?, color?, tag? })` -> `ok, reasonKey` | rename, recolour or retag a gang (same rules as the Settings tab; the colour must be one of `Config.Gang.Colors`) |
| `DisbandGang(name)` -> `ok, balance` | deletes a gang; the balance (dollars) is returned, not paid out |
| `GetRanks(name)` -> `{ { level, name, boss } }` | ranks of a society, lowest first |
| `SetGangOwner(name, citizenid)` -> `ok` | changes the recorded owner of a gang (ranks are changed with `SetMemberLevel`) |
| `AddRank(name, rankName)` -> `ok, level` | gangs: adds a rank below the lowest boss rank (max `Config.Gang.MaxRanks`) |
| `RemoveRank(name, level)` -> `ok` | gangs: deletes a non-boss rank; its members move one rank down. Needs at least 3 ranks |
| `IsReady()` -> boolean | true once all societies are loaded; other resources wait for it at start |
| `OpenStorage(src, name)` | opens the stash (checks access) |

## 7. Events (server)
`rsg-society:server:ready`, `balanceChanged`, `memberJoined`, `memberLeft`, `rankChanged`, `gangCreated`, `gangDisbanded`, `gangUpdated` (name, label, colour, tag or owner changed), `fineIssued`. Legacy `rsg-bossmenu:client:mainmenu` and `rsg-gangmenu:client:mainmenu` still open the menu.

## 8. Commands
`/society`, `/gang`, `/fines`, `/payfines`; admin: `/addsociety <job>`, `/societydesk <society>`, `/removesocietydesk`, `/societyfunds <society> <add|remove> <amount>`, `/societymigrate`, `/removegang <id>`. Key: rebindable in the game's key settings (`Config.UseKeyMapping`).

## 9. rsg-core change
In `server/functions.lua`, `PaycheckInterval` asks `exports['rsg-society']:ProcessWage` before paying when `RSGConfig.Money.PayCheckSociety = true`, and skips the wage on `'skipped'`. Without rsg-society started, core pays as it always did.

## 10. Migration
On first start (`Config.Migration`): `management_funds` balances, core gangs with members or money, and rsg-gangs data (`rsg_gangs`, `rsg_gang_members`, `rsg_gang_logs`) are imported once; markers in `rsg_society_meta`. Re-run with `/societymigrate`. Static gangs in `shared/gangs.lua` remain but are overridden at runtime.
**rsg-gangs (3.5.0 and newer)** uses these exports and events for gang identity, members, ranks, permissions and the bank, and keeps only its gameplay data (wagon, equipment, turf, bounties...). Start rsg-society before it. The `rsg_gang_members` table is only read by the one-time import.

## 11. Security
All amounts, ranks and targets are validated on the server; distance checks on desks, hiring, fining; per-player cooldown; rank hierarchy enforced (no acting on equal/higher ranks except bosses when `AllowEqualRank`); SQL uses parameters; NUI renders user text with `textContent`. Opening the menu and loading tabs are throttled per player (`Config.ReadCooldown`), menu actions by `Config.ActionCooldown`. A callback that errors answers with a generic error instead of leaving the menu waiting. Reloading the data (`/societymigrate`) swaps the new tables in at once, so wages and menus keep working during the reload. Disbanding a gang also deletes its ledger, audit rows and fines, because the internal name can be reused by a new gang.

## 12. Database
Created automatically from `install.sql` (`Config.AutoDatabase`). Manual: import `install.sql`.

## 13. Troubleshooting
| Problem | Fix |
|---|---|
| Wages still paid with empty account | `PayCheckSociety` false, or core patch missing, or society payroll off, or the caller is not `Config.Payroll.TrustedWageCaller` |
| "Slow down" in the menu | You hit `Config.ActionCooldown` / `Config.ReadCooldown`; wait a moment |
| "too many fines recently" | `Config.Fines.IssueLimit` reached for that issuer |
| Menu says system starting | Wait for jobs to load; check console |
| Old balances missing | Check `rsg_society_meta` markers, run `/societymigrate` |

Support: https://rexshack.tebex.store
