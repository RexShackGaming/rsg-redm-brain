# rsg-townhall – Documentation

## Contents
1. [Overview](#overview)
2. [Files](#files)
3. [Data model](#data-model)
4. [Callbacks](#callbacks)
5. [Events](#events)
6. [Permissions](#permissions)
7. [Approval flow](#approval-flow)
8. [Security model](#security-model)
9. [Database schema](#database-schema)
10. [Server owner how-tos](#server-owner-how-tos)
11. [Push-to-talk](#push-to-talk)
12. [Troubleshooting](#troubleshooting)

## Overview
Clerk NPC (rsg-target) -> NUI (80% screen) -> rsg-core callbacks -> oxmysql. Jobs come from rsg-core's job definitions (`multijob_jobs`), and approvals call `AddPlayerJob`. The resource has no exports; everything runs through callbacks that the NUI reaches via one whitelisted NUI callback (`rpc`).

## Files
| Path | Purpose |
|---|---|
| `fxmanifest.lua` | Dependencies: `rsg-core`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | All settings (see README) |
| `server/server.lua` | Database build, locations, permissions, callbacks, approval logic |
| `server/versionchecker.lua` | GitHub version check |
| `client/client.lua` | Clerk NPCs, rsg-target option, NUI focus, `rpc` bridge |
| `html/` | `index.html`, `style.css`, `script.js` (house style, no native dropdowns) |
| `locales/*.json` | 10 languages, identical keys |
| `install.sql` | Same schema as the auto-build |

## Data model
- **Posting**: `job`, `grade`, `title`, `description`, `requirements`, optional custom `questions` (JSON array of strings), `slots`, `filled_count`, `expires_at`, `location_id` (0 = all clerks), prerequisites (`req_items` JSON, `req_job`, `req_job_grade`), `status` = `open` / `filled` / `closed` / `expired`.
- **Application**: `posting_id`, `citizenid`, `answers` (JSON `[{ q, a }]`, question text is snapshotted), `status` = `pending` / `interview` / `approved` / `rejected` / `closed` / `withdrawn`, `feedback`, `interview_note`, reviewer, `seen` flag, `granted` (0 queued, 1 granted, 2 skipped/failed, 3 processing).
- **Manager**: `citizenid` + `job` (`*` = all jobs).
- **Location**: clerk position saved with `/createtownhall`.
- **Resignation**: `townhall_resignations` (citizenid, job, time) drives the re-apply cooldown.

## Callbacks
All are `RSGCore.Functions.CreateCallback('rsg-townhall:server:<name>')`, answer `{ ok, err? , msg? }` and require the player to be within `Config.ServerDistance` of a clerk.

| Name | Who | Payload | Description |
|---|---|---|---|
| `getLocations` | client | – | Clerk list (no distance check) |
| `getPerms` | any | – | `admin`, `manage`, `unseen`, `pending` (reviews waiting for the caller), limits |

Tab badges: **My applications** shows `unseen` (decisions not yet viewed, counted only for applications whose posting still exists) and clears as soon as the tab is opened (`markSeen`). **Manage** shows `pending` and refreshes from the live pending list each time the tab loads, so it drops after a review.
| `getVacancies` | any | – | Open postings with questions, slots, expiry, prerequisites and the caller's state (`open`, `applied`, `cooldown`, `holds`, `blocked`, `locked`) and the application `fee` |
| `apply` | any | `postingId`, `answers[]` | Submit an application |
| `getMyApplications` | any | – | Caller's last 50 applications |
| `markSeen` | any | – | Clears unread decision flags |
| `withdraw` | any | `applicationId` | Withdraw own pending application |
| `getManageData` | manager | – | Postings, pending/reviewed applications, postable jobs, managers (admin) |
| `getMyJobs` | any | – | Caller's jobs and whether resigning is allowed |
| `resign` | any | `job` | Leave a job and start the re-apply cooldown |
| `postJob` | manager | `job`, `grade`, `title`, `description`, `requirements`, `questions[]`, `slots`, `expiryDays`, `locationId`, `reqItems[]`, `reqJob`, `reqJobGrade` | Publish a vacancy |
| `editPosting` | manager | `postingId`, text fields, `slots`, optional `expiryDays` | Edit an open vacancy |
| `reopenPosting` | manager | `postingId` | Reopen a closed or expired vacancy |
| `requestInterview` | manager | `applicationId`, `message` | Move a pending application to `interview` and notify the applicant |
| `closePosting` | manager | `postingId` | Close a vacancy (pending applications are closed) |
| `review` | manager | `applicationId`, `decision` (`approve`/`reject`), `feedback` | Decide a pending or interview application |
| `addManager` / `removeManager` | admin | `player`, `job` / `id` | Manage the manager list |
| `getMessages` | applicant / reviewer | `applicationId` | Message thread of an application and whether sending is still possible |
| `sendMessage` | applicant / reviewer | `applicationId`, `message` | Add a message (open applications only, capped by `Config.MaxMessages`) |
| `editApplication` | applicant | `applicationId`, `answers[]` | Replace the answers of an open application |
| `getTemplates` / `saveTemplate` / `deleteTemplate` | manager | - / `name`, `data` / `id` | Per-poster vacancy templates |
| `addBlacklist` / `removeBlacklist` | manager (scope) | `player`, `job` (`*` = all jobs), `reason` / `id` | Bar a citizen from applying; `*` needs an all-jobs scope |

## Events
| Event | Direction | Description |
|---|---|---|
| `rsg-townhall:client:syncLocations` | server -> client | Replaces the client's clerk list |
| `RSGCore:Server:PlayerLoaded` (listened) | core -> server | Grants queued approvals, reminds applicants about unread updates and managers about waiting reviews |
| `rsg-townhall:server:applicationDecided` | server (local) | Fired after a decision: `{ id, citizenid, job, grade, decision = 'approved'/'rejected', queued? }` |

### Exports (server)
| Export | Returns |
|---|---|
| `exports['rsg-townhall']:HasPendingApplication(citizenid, job?)` | `true` if the citizen has an open application (optionally for one job) |
| `exports['rsg-townhall']:GetOpenVacancyCount(job)` | Number of open vacancies for the job |
| `exports['rsg-townhall']:IsBlacklisted(citizenid, job)` | `true` if barred from that job or from all jobs |

Log channel: `rsg-log:server:CreateLog` with channel `townhall` (ignored if rsg-log is not running).

## Permissions
- **Admin**: `RSGCore.Functions.HasPermission(src, Config.AdminPermission)`; any job, manager list.
- **Manager**: row in `townhall_managers`; `*` = all jobs, otherwise one job. If `Config.ManagerJob` is set, entries are ignored while the player does not hold that job, and `addManager` rejects an online target without it (offline targets are checked when they act).
- **Boss**: `Config.AllowBossManagement` and the player's *active* job is a boss grade (`isboss`); only for that job.
- Non-admins cannot post boss grades while `Config.RestrictBossGrades` is true.
- Reviewers cannot review their own application unless `Config.AllowSelfReview`.

## Approval flow
1. Application is claimed atomically (`pending` -> `approved`).
2. Vacancy is claimed atomically (`open` -> `filled`); losing a race reverts step 1.
3. Before step 1 the server checks that the applicant is not the reviewer's own alt (same license, unless `Config.AllowSelfReview`) and does not already hold the job (prevents an approval from changing the grade of a job they have).
4. The vacancy seat is claimed (`filled_count + 1`; the vacancy becomes `filled` when the last seat goes). Online applicant: `AddPlayerJob(source, job, grade, Config.BypassMaxJobs)`; on failure all steps are reverted and the reviewer gets the reason. Offline applicant (`Config.AllowOfflineApproval`): the application is stored as approved with `granted = 0` and the job is granted on their next login; if that fails the applicant is told to visit the Town Hall (`granted = 2`).
5. When the last seat is filled, other active applications for the vacancy become `closed` and online applicants are notified.
Rejection sets `rejected` and leaves the vacancy `open`. Interviews set `interview` and keep the application reviewable. A background thread closes vacancies whose `expires_at` has passed (`expired`).

**Prerequisites** are checked on the server at apply time (items via rsg-inventory `HasItem`, job via `HasPlayerJob` and rank). The interview notification uses rsg-core notify; rsg-telegram is not required.

## Security model
- Every callback loads the player, checks the clerk distance on the server and validates every field (type, length, existence).
- Pay, rank and job are read from rsg-core on the server; the client only sends ids and text.
- Rate limits on apply, post, review and manager changes.
- Reviewers cannot approve or reject their own character or another character on their own license.
- Management queries are filtered by job scope in SQL, so a manager never receives other jobs' applications.
- SQL uses `?` parameters only; the NUI renders text with `textContent` (no HTML injection).
- The client NUI bridge only forwards a fixed list of callback names.

## Database schema
See `install.sql`: `townhall_locations`, `townhall_managers`, `townhall_postings`, `townhall_applications`, `townhall_resignations`, `townhall_messages`, `townhall_templates`, `townhall_blacklist`. Existing installs are migrated automatically (missing columns are added from an `INFORMATION_SCHEMA` check). With `Config.AutoDatabase = true` they are created on start (`CREATE TABLE IF NOT EXISTS`).

## Server owner how-tos
- **Add a clerk**: stand at the spot, `/createtownhall <name>`. Remove with `/removetownhall` next to it.
- **Give someone posting rights**: Town Hall -> Manage -> Managers -> enter citizen ID or server ID and a job scope.
- **Limit postable jobs**: set `Config.PostableJobs = { 'sheriff', 'doctor' }`.
- **Change the questions**: edit `Config.Questions` (`label` is a locale key; add it to all 10 locale files).
- **Change the clerk**: `Config.NpcModel`, `Config.NpcScenario`.
- **Webhook**: set `SvConfig.Webhook` in `server/sv_config.lua`.
- **Allow items as prerequisites**: add rsg-inventory item names to `Config.PrerequisiteItems`.
- **Per-clerk boards**: when posting, pick a clerk location; "All clerks" shows the vacancy everywhere.

## Push-to-talk
While the UI is open, `SetNuiFocusKeepInput(true)` is used and every game control is disabled except `Config.PushToTalkControls`. Set `Config.AllowPushToTalkWhileOpen = false` to use plain NUI focus.

## Troubleshooting
| Problem | Check |
|---|---|
| Clerk does not appear | Run `/createtownhall`; check `Config.NpcModel`; ensure `rsg-target` is started |
| "You are too far from the Town Hall." | `Config.ServerDistance`; the clerk must exist server-side (`townhall_locations`) |
| No jobs in the post form | Job must exist in `multijob_jobs`, not be in `BlockedJobs`, and be inside your scope |
| Approval says applicant must be online | The job is granted immediately; ask them to log in |
| Database errors on start | Set `Config.AutoDatabase = false` and import `install.sql` |

Support: https://rexshack.tebex.store


## Applicant notifications

Each applicant update (interview, approval, rejection, vacancy closed/filled/expired) sets `seen = 0` (unread dot in the My Applications tab, cleared when the tab is opened) and `notified = 0` (login reminder not yet sent). The login reminder only counts rows with `seen = 0 AND notified = 0` and then sets `notified = 1`, so each update produces at most one reminder. Updates delivered live to an online applicant are marked `notified = 1` immediately. The `notified` column is added automatically to existing databases (existing rows default to `1`, so old updates stop reminding); manual installs can run `ALTER TABLE townhall_applications ADD COLUMN notified TINYINT(1) NOT NULL DEFAULT 1;`.


## Expiry options per role

`Config.ExpiryOptions` can be a table keyed by role. The first match wins: `admin` (Config.AdminPermission) > `jobs[<vacancy job>]` > `manager` (manager list) > `boss` > `default`. A role without a list falls back to `default`. A plain list (`{ 0, 3, 7 }`) still works and applies to everyone. `0` means never expires, so leave it out of the non-admin lists to forbid permanent vacancies. The server validates `postJob` and `editPosting` against the list for the vacancy's job; reopen/repost uses `Config.DefaultExpiryDays` if allowed, otherwise the first timed option. The UI receives the list per job (`getManageData.jobs[].expiry`, `postings[].expiry`).

## Security notes

- Every callback re-checks the player, the nearest clerk (`Config.ServerDistance`), scope (admin / manager / boss) and ownership on the server; the NUI only sends ids and text.
- Read callbacks (`getPerms`, `getVacancies`, `getMyApplications`, `getMyJobs`, `getManageData`) are rate limited to one call per 300 ms per player; writes use their own throttles.
- Reopening/reposting a boss-grade vacancy is admin-only while `Config.RestrictBossGrades` is on, the same as posting one.
- Discord webhook embeds disable mention parsing, so player-written text cannot ping roles or @everyone.

## Application fee, templates and blacklist

- **Fee**: with `Config.ApplicationFee > 0` the fee is removed from `Config.ApplicationFeeAccount` on the server just before the application is stored and refunded if storing fails. If the vacancy closes, fills or expires before the application is decided and `Config.RefundFeeWhenClosed` is on, the fee is stored in `townhall_applications.refund` and paid out once (immediately if the applicant is online, otherwise at next login); a decision or withdrawal gives no refund. Applicants see the fee in the application window.
- **Templates**: stored per citizen in `townhall_templates` as validated JSON (texts, job, rank, slots, expiry, prerequisites). Loading a template only fills the form; the vacancy is checked again when posted, so a template can never exceed the poster's current permissions.
- **Blacklist**: `townhall_blacklist` has one row per citizen and job (`*` = every job). It is checked in `apply` and shown to the applicant as *Barred*. Reviewers see and lift entries inside their scope only.
- **Messages**: `townhall_messages`, only while an application is `pending` or `interview`. A reviewer message re-flags the application as unread; an applicant message notifies the managers who are online.

## Upgrading to 3.1.0 manually

With `Config.AutoDatabase = true` everything is added on start. For a manual install run the new tables from `install.sql` plus: `ALTER TABLE townhall_postings ADD COLUMN warned TINYINT(1) NOT NULL DEFAULT 0;` and `ALTER TABLE townhall_applications ADD COLUMN fee INT NOT NULL DEFAULT 0, ADD COLUMN refund INT NOT NULL DEFAULT 0;` (and the `notified` column from 3.0.1 if you have not added it).
