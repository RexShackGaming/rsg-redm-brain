# rsg-townhall 3.2.0 – Documentation

## Contents
1. [Overview](#overview)
2. [Files](#files)
3. [Data model](#data-model)
4. [Permissions](#permissions)
5. [Approval flow](#approval-flow)
6. [Features in detail](#features-in-detail)
7. [Configuration](#configuration)
8. [Exports](#exports)
9. [Events](#events)
10. [Callbacks](#callbacks)
11. [Integration examples](#integration-examples)
12. [Database schema](#database-schema)
13. [Security model](#security-model)
14. [Server owner how-tos](#server-owner-how-tos)
15. [Upgrading manually](#upgrading-manually)
16. [Troubleshooting](#troubleshooting)

## Overview
Clerk NPC (rsg-target) -> NUI -> rsg-core callbacks -> oxmysql. Jobs come from rsg-core's job definitions (`multijob_jobs`); hiring calls `AddPlayerJob`, removal `RemovePlayerJob` (both also work for offline citizens). The NUI reaches the server through one whitelisted NUI callback (`rpc`); every callback re-validates the player, the clerk distance, the permission scope and all arguments.

**Dependencies:** `rsg-core`, `rsg-target`, `rsg-inventory`, `oxmysql`.
**Optional:** `rsg-skills`, `rsg-reputation` (prerequisites), `rsg-society` (permission), `rsg-telegram` (offline notices), `rsg-log` (log channel `townhall`). A missing optional resource is skipped, never an error.

## Files
| Path | Purpose |
|---|---|
| `fxmanifest.lua` | Metadata, version, dependencies |
| `shared/config.lua` | All settings |
| `server/server.lua` | Database build, locations, permissions, callbacks, approval/probation/invite logic, exports |
| `server/sv_config.lua` | Server-only settings (`SvConfig.Webhook`, `SvConfig.Username`) |
| `server/versionchecker.lua` | GitHub version check |
| `client/client.lua` | Clerk NPCs, rsg-target option, NUI focus, `rpc` bridge, `UI_KEYS` (the only strings sent to the NUI) |
| `html/` | `index.html`, `style.css`, `script.js` (house style, built with `textContent`, no native dropdowns) |
| `locales/*.json` | 11 languages, identical keys |
| `exports/` | CSV statistics are written here |
| `install.sql` | Same schema as the auto-build |

## Data model
- **Posting**: `job`, `grade`, `title`, `description`, `requirements`, custom `questions` (JSON array of strings), `slots`, `filled_count`, `expires_at`, `location_id` (0 = all clerks), prerequisites (`req_items` JSON, `req_job`, `req_job_grade`, `req_extra` JSON `{ skill = { key, level }, honor = n, standing = { region, min } }`), `probation_days`, `status` = `open` / `filled` / `closed` / `expired`.
- **Application**: `posting_id`, `citizenid`, `answers` (JSON `[{ q, a }]`), `status` = `pending` / `interview` / `approved` / `rejected` / `closed` / `withdrawn`, `feedback`, `interview_note`, reviewer, `seen`, `notified`, `granted` (0 queued, 1 granted, 2 skipped/failed, 3 processing), `fee`, `refund`, claim (`claimed_by`, `claimed_by_name`, `claimed_at`).
- **Invite**: `citizenid`, `job`, `grade`, `message`, `probation_days`, inviter, `status` = `pending` / `accepted` / `declined` / `cancelled` / `expired`, `expires_at`.
- **Probation**: `citizenid`, `job`, `ends_at`, `source` (`application` / `invite`), `status` = `active` / `confirmed` / `ended`.
- **Manager**: `citizenid` + `job` (`*` = all jobs). **Location**: clerk position. **Resignation**: drives the re-apply cooldown. Also messages, templates and blacklist.

## Permissions
A caller's *scope* is the set of jobs they may post and review for. It is cached for 2 seconds per player.
- **Admin**: `RSGCore.Functions.HasPermission(src, Config.AdminPermission)`; every job, manager list, CSV export.
- **Manager**: row in `townhall_managers` (`*` = all jobs). If `Config.ManagerJob` is set, entries only count while the player holds that job.
- **Boss**: `Config.AllowBossManagement` and the active job has `isboss`; only for that job.
- **Society permission**: with `Config.UseSocietyPermission` and rsg-society running, a rank holding `townhall_post` in a job's society gets that job. The permission is registered with rsg-society on start (and again when rsg-society restarts). rsg-society shows the raw name `townhall_post` unless it has a `ui_perm_townhall_post` locale string.
- Boss grades can only be posted/invited by admins while `Config.RestrictBossGrades` is true. Reviewers cannot decide on their own character or one on their own licence (`Config.AllowSelfReview`).

## Approval flow
1. The application is claimed atomically (`pending`/`interview` -> `approved`); losing a race returns `err_already_reviewed`.
2. A seat is taken atomically (`filled_count + 1`, vacancy becomes `filled` with the last seat); failure reverts step 1.
3. Online applicant: `AddPlayerJob(source, job, grade, Config.BypassMaxJobs)`; failure reverts everything and the reviewer sees the reason. Offline applicant (`Config.AllowOfflineApproval`): stored as `granted = 0`, granted at next login, and a telegram is sent if rsg-telegram is running.
4. A probation row is created when the posting has `probation_days > 0`.
5. When the last seat goes, the remaining active applications become `closed` (fees refunded if `Config.RefundFeeWhenClosed`).
Rejection leaves the vacancy open. `tick()` (every `Config.ExpiryCheckMinutes`) expires vacancies, expires invitations and ends overdue probations.

## Features in detail

### Prerequisites
Checked on the server on `getVacancies` (shown as met/unmet) and again in `apply`. Items (`rsg-inventory` `HasItem`), held job and rank, rsg-skills `HasLevel`, rsg-reputation `HasHonor` and `HasStanding`. A requirement whose resource is stopped counts as met, so nobody gets locked out. Prerequisites are set when a vacancy is posted; editing an open vacancy changes texts, slots and expiry only (duplicate it to change requirements).

### Probation
Set per vacancy (`Config.ProbationOptions`) or per invitation. After hiring, the Manage -> Probation tab lists active probations: a boss **confirms** (job is permanent) or **ends** it (job removed). If nobody decides, the job is removed when `ends_at` passes. Resigning ends the probation record. Players see "On probation: N left" in My Jobs.

### Invitations
Manage -> Invitations: pick a job and rank, a citizen (server ID or citizen ID), an optional message and probation. The invitee gets a live notification or a telegram, and answers in My Applications. Accepting re-checks job restrictions, blacklist and job ownership, then grants the job. Limits: `Config.MaxPendingInvites` per citizen, one open invite per citizen and job, expiry `Config.InviteExpiryDays`.

### Claim and bulk review
A reviewer can **claim** an application for `Config.ClaimMinutes`; other reviewers cannot decide on it meanwhile (admins can override). Ticking several applications offers **bulk** approve/reject (same feedback for each, at most `Config.MaxBulkReview`); every application is still validated individually and the result reads "N decided, M failed".

### Statistics and CSV export
Manage -> Stats shows vacancies, applications, approval rate, average decision time, hires and average time to fill per job, for the windows in `Config.StatsDays`, limited to the caller's scope. Admins can export the same table to `exports/townhall_stats_<timestamp>.csv` inside the resource; cells starting with `= + - @` are prefixed so spreadsheets never run them as formulas.

### Notifications
Live notifications use rsg-core notify. Offline citizens get a telegram (`Config.TelegramNotify`) for interviews, queued approvals, rejections, invitations and probation results. Each applicant update sets `seen = 0` (unread dot) and `notified = 0` (login reminder not yet sent); the reminder sets `notified = 1`, so each update reminds at most once.

### Text safety
All player text passes `cleanText`: control characters and invisible/bidirectional code points (zero-width, soft hyphen, bidi overrides) are stripped, invalid UTF-8 is rejected, whitespace is trimmed and the length is checked.

### Expiry options per role
`Config.ExpiryOptions` may be keyed by role; first match wins: `admin` > `jobs[<job>]` > `manager` > `boss` > `default`. A plain list (`{ 0, 3, 7 }`) applies to everyone. `0` = never expires, so omit it from non-admin lists to forbid permanent vacancies.

### Fee, templates, blacklist, messages
- **Fee**: `Config.ApplicationFee` is taken just before the application is stored and refunded if storing fails; refunded when a vacancy closes before a decision (`Config.RefundFeeWhenClosed`).
- **Templates**: per-citizen validated JSON; loading only fills the form and the vacancy is re-validated when posted.
- **Blacklist**: one row per citizen and job (`*` = all jobs), checked in `apply` and `invitePlayer`.
- **Messages**: only while an application is `pending` or `interview`, capped by `Config.MaxMessages`.

### Push-to-talk
While the UI is open `SetNuiFocusKeepInput(true)` is used and every game control is disabled except `Config.PushToTalkControls`. Set `Config.AllowPushToTalkWhileOpen = false` for plain NUI focus.

## Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | false = import install.sql manually |
| `Config.NpcModel` | `'a_m_m_valtownfolk_01'` | Clerks are placed in game by an admin with /createtownhall and stored in the database. |
| `Config.NpcScenario` | `'WORLD_HUMAN_STAND_WAITING'` | set to nil/false for no scenario |
| `Config.SpawnDistance` | `60.0` | clerk spawns when the player is this close |
| `Config.TargetDistance` | `2.5` | rsg-target interaction distance |
| `Config.ServerDistance` | `12.0` | server only accepts Town Hall requests this close to a clerk |
| `Config.CloseDistance` | `8.0` | UI closes automatically when the player walks further than this |
| `Config.Commands` | `table` | Commands (admin placement) --------------------------------------------------- |
| `Config.AdminPermission` | `'admin'` | rsg-core permission level that can post/review ANY job and manage the manager list. |
| `Config.AllowBossManagement` | `true` | Players whose active job is a boss grade may post and review vacancies for their own job. |
| `Config.RestrictBossGrades` | `true` | Only admins may post vacancies for boss grades (isboss) when true. |
| `Config.ManagerJob` | `'government'` | Bosses never need to be on the list: with AllowBossManagement they can post for their own job by default. |
| `Config.AllowSelfReview` | `false` | A reviewer may never approve/reject their own application when false. |
| `Config.PostableJobs` | `{}` | Jobs that may be posted. Empty = any job from the database (multijob_jobs). |
| `Config.BlockedJobs` | `{ 'unemployed' }` | Jobs that can never be posted. |
| `Config.MaxOpenPostingsPerJob` | `5` |  |
| `Config.MaxActiveApplications` | `3` | pending applications per player |
| `Config.ReapplyCooldownHours` | `24` | wait after a rejection before re-applying to the same vacancy (0 = none) |
| `Config.RequireFeedback` | `true` | reviewer must write feedback for approve and reject |
| `Config.MinFeedbackLength` | `5` |  |
| `Config.MaxCustomQuestions` | `5` | extra questions the poster may add |
| `Config.BypassMaxJobs` | `false` | ignore the multijob max job limit |
| `Config.SetActiveJobOnApproval` | `false` | also switch the applicant's active job to the new one |
| `Config.MaxSlots` | `10` | seats per vacancy |
| `Config.ExpiryOptions` | `table` | A plain list such as { 0, 3, 7, 14, 30 } is still accepted and applies to everyone. |
| `Config.DefaultExpiryDays` | `14` | used when reopening a vacancy |
| `Config.ExpiryCheckMinutes` | `5` | how often vacancies, invitations and probations are checked |
| `Config.AllowMessages` | `true` | applicant and reviewers can exchange short messages while an application is open |
| `Config.MaxMessages` | `30` | per application |
| `Config.AllowEditApplication` | `true` | applicants can change their answers while the application is still open |
| `Config.ApplicationFee` | `0` | money taken when applying (0 = free) |
| `Config.RefundFeeWhenClosed` | `true` | refund the fee if the vacancy closes, fills or expires before a decision |
| `Config.ApplicationFeeAccount` | `'cash'` | 'cash' or 'bank' |
| `Config.AllowBlacklist` | `true` | reviewers can bar a citizen from one job (or all jobs, admins/all-job managers) |
| `Config.MaxTemplates` | `10` | saved vacancy templates per poster |
| `Config.ExpiryWarnHours` | `24` | warn the poster this long before a vacancy closes (0 = off) |
| `Config.AllowOfflineApproval` | `true` | approve offline applicants; the job is granted on their next login |
| `Config.AllowInterviews` | `true` | reviewers can invite an applicant to an interview before deciding |
| `Config.AllowResign` | `true` | players can resign from jobs in the "My Jobs" tab |
| `Config.ResignCooldownHours` | `24` | wait before applying for the same job again (0 = none) |
| `Config.PrerequisiteItems` | `{}` | Items a poster may require applicants to carry (rsg-inventory item names). Empty = no item prerequisites. |
| `Config.MaxPrerequisiteItems` | `3` |  |
| `Config.AllowJobPrerequisites` | `true` | "must already hold job X at rank Y or higher" (promotion paths) |
| `Config.AllowSkillPrerequisites` | `true` | "needs skill X at level Y" (rsg-skills); counts as met while rsg-skills is stopped |
| `Config.AllowReputationPrerequisites` | `true` | honor / regional standing minimums (rsg-reputation); counts as met while it is stopped |
| `Config.ReputationLimits` | `{ honor = { -1000, 1000 }, standing = { -100, 100 } }` | accepted ranges for typed numbers |
| `Config.UseSocietyPermission` | `true` | ranks with the society permission may post and review for their job (rsg-society) |
| `Config.SocietyPermission` | `'townhall_post'` | permission name (max 24 chars, letters/digits/underscore) |
| `Config.TelegramNotify` | `true` | offline players get a telegram (rsg-telegram) |
| `Config.TelegramSender` | `'Town Hall'` | telegram sender name |
| `Config.ProbationOptions` | `{ 0, 3, 7, 14 }` | probation lengths in days a poster can choose (0 = none) |
| `Config.AllowInvites` | `true` | direct invitations to a citizen |
| `Config.InviteExpiryDays` | `7` | invitation lifetime (0 = never) |
| `Config.MaxPendingInvites` | `3` | open invitations per citizen |
| `Config.AllowClaim` | `true` | reviewers can claim an application |
| `Config.ClaimMinutes` | `30` | a claim lapses after this long (admins can always override) |
| `Config.AllowBulkReview` | `true` | approve/reject several applications at once |
| `Config.MaxBulkReview` | `10` | applications per bulk action |
| `Config.StatsDays` | `{ 7, 30, 90, 0 }` | windows offered in the Stats tab (0 = all time) |
| `Config.StatsExportFolder` | `'exports'` | folder inside the resource for the CSV export |
| `Config.Limits` | `table` | Text limits (characters) ------------------------------------------------------- |
| `Config.Questions` | `table` | label = locale key. type = 'textarea' or 'text'. required defaults to true. |
| `Config.AllowPushToTalkWhileOpen` | `true` | While the UI is open, game controls are blocked but push-to-talk still works. |
| `Config.PushToTalkControls` | `table` |  |

Commands: `/createtownhall [name]` places a clerk where you stand, `/removetownhall` removes the nearest one within 5 m (admin permission).

## Exports
Server exports (`exports['rsg-townhall']:<name>`):

| Export | Returns |
|---|---|
| `HasPendingApplication(citizenid, job?)` | `true` if the citizen has an open application (optionally for one job) |
| `GetOpenVacancyCount(job)` | number of open vacancies for the job |
| `IsOnProbation(citizenid, job)` | `true` while the citizen's probation in that job is active |
| `IsBlacklisted(citizenid, job)` | `true` if barred from that job or from all jobs |

```lua
-- server: block a perk while the hire is still on probation
if exports['rsg-townhall']:IsOnProbation(Player.PlayerData.citizenid, 'sheriff') then
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = 'Sheriff', description = 'Not while on probation.', type = 'error' })
    return
end
```

Log channel: `rsg-log:server:CreateLog` with channel `townhall` (ignored if rsg-log is not running). Optional Discord webhook via `SvConfig.Webhook` (mention parsing is disabled).

## Events
| Event | Side | Payload | Description |
|---|---|---|---|
| `rsg-townhall:server:applicationDecided` | server (local) | `{ id, citizenid, job, grade, decision = 'approved'/'rejected', queued?, invite? }` | After a decision. For an accepted invitation `id = 0` and `invite = true` |
| `rsg-townhall:server:probationDecided` | server (local) | `{ citizenid, job, decision = 'confirmed'/'ended', expired? }` | After a boss decision or an automatic end (`expired = true`) |
| `rsg-townhall:client:syncLocations` | server -> client | `list` | Replaces the client's clerk list |
| `RSGCore:Server:PlayerLoaded` (listened) | core -> server | `Player` | Grants queued approvals, pays refunds, reminds about updates, invitations and waiting reviews |

```lua
-- server: pay a signing bonus when someone is hired (application or invitation)
AddEventHandler('rsg-townhall:server:applicationDecided', function(data)
    if data.decision ~= 'approved' or data.queued then return end
    local Player = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
    if Player and data.job == 'sheriff' then
        Player.Functions.AddMoney('cash', 25, 'townhall-signing-bonus')
    end
end)

-- server: react when a probation ends
AddEventHandler('rsg-townhall:server:probationDecided', function(data)
    print(('%s probation in %s: %s'):format(data.citizenid, data.job, data.decision))
end)
```

## Callbacks
All are `RSGCore.Functions.CreateCallback('rsg-townhall:server:<name>')`, answer `{ ok, err?, msg? }` and require the caller to be within `Config.ServerDistance` of a clerk (except `getLocations`). Read callbacks are limited to one call per 300 ms per player. The client NUI may only call the whitelisted names.

| Name | Who | Payload | Description |
|---|---|---|---|
| `getLocations` | client | – | Clerk list |
| `getPerms` | any | – | Permissions, limits, feature flags, `unseen` (incl. open invitations), `pending` reviews |
| `getVacancies` | any | – | Open postings with prerequisites (incl. skill/honor/standing), probation and the caller's state (`open`, `applied`, `cooldown`, `holds`, `blocked`, `locked`) |
| `apply` | any | `postingId`, `answers[]` | Submit an application |
| `getMyApplications` | any | – | Last 50 applications plus open `invites` |
| `markSeen` | any | – | Clear unread flags |
| `withdraw` | any | `applicationId` | Withdraw an open application |
| `editApplication` | applicant | `applicationId`, `answers[]` | Replace answers of an open application |
| `answerInvite` | invitee | `id`, `accept` (boolean) | Accept (grants the job) or decline an invitation |
| `getMyJobs` / `resign` | any | – / `job` | Own jobs (with `probationEnds`) / leave a job |
| `getManageData` | manager | – | Postings, applications (with claim info), jobs, skills, regions, probation, invitations, managers (admin), blacklist |
| `postJob` | manager | `job`, `grade`, `title`, `description`, `requirements`, `questions[]`, `slots`, `expiryDays`, `locationId`, `reqItems[]`, `reqJob`, `reqJobGrade`, `reqSkill`, `reqSkillLevel`, `reqHonor`, `reqStandingRegion`, `reqStanding`, `probationDays` | Publish a vacancy |
| `editPosting` | manager | `postingId`, texts, `slots`, optional `expiryDays` | Edit an open vacancy |
| `closePosting` / `reopenPosting` | manager | `postingId` | Close / reopen (or repost a filled one) |
| `requestInterview` | manager | `applicationId`, `message` | Move to `interview` |
| `review` | manager | `applicationId`, `decision`, `feedback` | Approve or reject |
| `bulkReview` | manager | `ids[]`, `decision`, `feedback` | Decide several (max `Config.MaxBulkReview`) |
| `claimApplication` | manager | `applicationId`, `release?` | Claim or release |
| `decideProbation` | manager | `id`, `decision` (`confirm`/`end`) | Decide an active probation |
| `invitePlayer` | manager | `job`, `grade`, `player`, `message?`, `probationDays?` | Send an invitation |
| `cancelInvite` | manager | `id` | Withdraw an open invitation |
| `getStats` | manager | `days` | Statistics rows for the caller's scope |
| `exportStats` | admin | `days` | Write the CSV, returns the file path in `msg` |
| `addManager` / `removeManager` | admin | `player`, `job` / `id` | Manager list |
| `getMessages` / `sendMessage` | applicant / reviewer | `applicationId` (+ `message`) | Application message thread |
| `getTemplates` / `saveTemplate` / `deleteTemplate` | manager | - / `name`, `data` / `id` | Vacancy templates |
| `addBlacklist` / `removeBlacklist` | manager (scope) | `player`, `job`, `reason` / `id` | Bar a citizen (`*` needs an all-jobs scope) |

```lua
-- client: ask for the caller's vacancies (the UI does the same through the rpc bridge)
RSGCore.Functions.TriggerCallback('rsg-townhall:server:getVacancies', function(res)
    if res.ok then print(#res.vacancies) end
end)
```

## Integration examples
```lua
-- server: only let confirmed staff use a sheriff stash
local cid = Player.PlayerData.citizenid
if exports['rsg-townhall']:IsOnProbation(cid, 'sheriff') then return end

-- server: stop a farm bot from spamming applications
if exports['rsg-townhall']:HasPendingApplication(cid) then return end

-- server: show a "we are hiring" sign
local open = exports['rsg-townhall']:GetOpenVacancyCount('doctor')
```
Society permission: in rsg-society open the job's Ranks tab and tick `townhall_post` for the ranks that may post and review (bosses always can).

## Database schema
Tables: `townhall_locations`, `townhall_managers`, `townhall_postings`, `townhall_applications`, `townhall_resignations`, `townhall_messages`, `townhall_templates`, `townhall_blacklist`, `townhall_probation`, `townhall_invites`. With `Config.AutoDatabase = true` they are created on start (`CREATE TABLE IF NOT EXISTS`) and missing columns on existing tables are added after an `INFORMATION_SCHEMA` check; nothing is dropped. For a manual install set it to `false` and import `install.sql`.

## Security model
- Every callback loads the player, checks the clerk distance on the server, validates type, length and range of every field and re-checks scope/ownership.
- Pay, rank, job and prerequisites come from rsg-core / rsg-inventory / rsg-skills / rsg-reputation on the server; the client sends only ids and text.
- State changes are atomic claims (`UPDATE ... WHERE status ...`): approvals, seats, refunds, invitations, claims, probation decisions and queued job grants cannot run twice.
- Rate limits on apply, post, review, bulk, claim, invite, probation, export and manager/blacklist changes; read callbacks 300 ms.
- Management queries are filtered by job scope in SQL. Bulk review and invitation counts are capped.
- SQL uses `?` parameters only; the NUI renders with `textContent`; the NUI bridge forwards a fixed list of callbacks; webhook embeds cannot ping; CSV cells are formula-safe.
- Other resources reacting to the events must do their own checks; the events are local server events and cannot be fired by clients.

## Server owner how-tos
- **Add a clerk**: stand at the spot, `/createtownhall <name>`; remove with `/removetownhall`.
- **Give posting rights**: Manage -> Managers (admin), a boss grade, or the `townhall_post` society permission.
- **Limit postable jobs**: `Config.PostableJobs = { 'sheriff', 'doctor' }`.
- **Change the questions**: edit `Config.Questions` (`label` is a locale key; add it to all 11 locale files).
- **Item prerequisites**: add rsg-inventory item names to `Config.PrerequisiteItems`.
- **Webhook**: `SvConfig.Webhook` in `server/sv_config.lua`.
- **Turn a feature off**: set its `Config.Allow...` flag to `false` (invites, claim, bulk review, skills/reputation prerequisites, telegram).

## Upgrading manually
With `Config.AutoDatabase = true` everything is added on start. For a manual install import the new tables from `install.sql` (`townhall_probation`, `townhall_invites`, `townhall_templates`, `townhall_blacklist`, `townhall_messages`) and run, skipping columns you already have:
```sql
ALTER TABLE townhall_postings ADD COLUMN warned TINYINT(1) NOT NULL DEFAULT 0;
ALTER TABLE townhall_postings ADD COLUMN req_extra TEXT NULL;
ALTER TABLE townhall_postings ADD COLUMN probation_days INT NOT NULL DEFAULT 0;
ALTER TABLE townhall_applications ADD COLUMN notified TINYINT(1) NOT NULL DEFAULT 1;
ALTER TABLE townhall_applications ADD COLUMN fee INT NOT NULL DEFAULT 0, ADD COLUMN refund INT NOT NULL DEFAULT 0;
ALTER TABLE townhall_applications ADD COLUMN claimed_by VARCHAR(50) NULL, ADD COLUMN claimed_by_name VARCHAR(100) NULL, ADD COLUMN claimed_at TIMESTAMP NULL DEFAULT NULL;
```

## Troubleshooting
| Problem | Check |
|---|---|
| Clerk does not appear | `/createtownhall`; `Config.NpcModel`; `rsg-target` started |
| "You are too far from the Town Hall." | `Config.ServerDistance`; the clerk must exist in `townhall_locations` |
| No jobs in the post form | Job must exist in `multijob_jobs`, not be in `BlockedJobs`, and be inside your scope |
| Skill / honor / standing fields missing | rsg-skills / rsg-reputation must be started and the matching `Config.Allow...Prerequisites` true |
| `townhall_post` shows as a raw name in rsg-society | Add `ui_perm_townhall_post` to rsg-society's locales |
| No telegrams for offline players | rsg-telegram started and `Config.TelegramNotify = true` |
| CSV export fails | The `exports/` folder must exist and be writable (ships with a `.gitkeep`) |
| Probation does not end exactly on time | Overdue probations are processed every `Config.ExpiryCheckMinutes` |
| Database errors on start | Set `Config.AutoDatabase = false` and import `install.sql` |

Support: https://rexshack.tebex.store
