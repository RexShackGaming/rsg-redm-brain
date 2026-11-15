# rsg-townhall

**Version 3.0.0** · Dependencies: `rsg-core` (multi-job built in), `rsg-target`, `oxmysql`

A Town Hall employment office for RSG Framework. Players walk up to a clerk NPC, open the Town Hall from the target menu and browse **vacant whitelisted jobs**. They apply with a form, a manager or admin reviews the application, and an approval grants the job and rank (with feedback). Rejections give feedback and the vacancy stays open.

Full developer / server-owner documentation: [DOCS.md](DOCS.md)

## Features
- Clerk NPC placed in game by admins (`/createtownhall`), targetable with rsg-target
- Full NUI covering 80% of the screen (house "leather & gold" style, pure HTML dropdowns)
- **Vacancies** tab: job tiles with title, job, rank, pay, description and requirements
- **Application form**: standard questions (configurable) plus extra questions added by the poster
- **My Applications** tab: status, your answers and the reviewer's feedback (unread dot + login reminder)
- **Manage** tab (admins, approved managers, optionally job bosses): review queue, post a job, close vacancies, manager list (admin only)
- Review modal shows whether the applicant is online; the Manage tab shows a badge with applications waiting
- **Offline approval**: approving an offline applicant queues the job and it is granted on their next login (`Config.AllowOfflineApproval`)
- **Interview step**: reviewers can invite an applicant to an interview (message + in-game notification) before deciding (`Config.AllowInterviews`)
- **Edit / reopen / repost** vacancies from the Vacancies sub-tab (closed and expired ones can be reopened)
- **Multiple slots and expiry**: one vacancy can fill several seats and can auto-close after 3/7/14/30 days (`Config.MaxSlots`, `Config.ExpiryOptions`)
- **Resign** from the **My Jobs** tab, with a re-apply cooldown (`Config.AllowResign`, `Config.ResignCooldownHours`)
- **Prerequisites**: required items (`Config.PrerequisiteItems`) and/or a minimum rank in another job; applicants see which they meet
- **Per-clerk boards**: a vacancy can be tied to one clerk location or shown at all clerks
- **Webhook logging**: Discord webhook in `server/sv_config.lua` plus rsg-log
- Approve = job + rank granted through rsg-core multi-job, vacancy removed from the board, other pending applicants told the position is gone
- Reject = applicant sees the feedback, the vacancy stays open (optional re-apply cooldown)
- Push-to-talk keeps working while the UI is open
- Tables are created automatically on first start
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro

## Installation
1. Make sure `rsg-core`, `rsg-target` and `oxmysql` are started before this resource.
2. Put `rsg-townhall` in your resources folder and add `ensure rsg-townhall` to `server.cfg`.
3. Database: tables are created automatically on first start. To install manually, set `Config.AutoDatabase = false` and import `install.sql`.
4. Join the server as an admin, stand where the clerk should be and run `/createtownhall Valentine Town Hall` (name optional).
5. Language follows the `rsg:locale` convar, e.g. `setr rsg:locale de`.

## Player flow
1. Target the clerk and choose **Open Town Hall**.
2. **Vacancies**: click a tile, read the description and requirements, answer the questions, **Submit application**.
3. A reviewer approves or rejects it. You are notified in game; open **My Applications** to read the feedback.

## Staff flow
- **Admin** (`Config.AdminPermission`, default `admin`): post and review any job, manage the manager list.
- **Manager**: added by an admin with a citizen ID or server ID, scoped to all jobs or a single job.
- **Boss** (optional): a player whose active job is a boss grade manages their own job.
- Manage tab: *Applications* (review), *Vacancies* (close), *Post a job*, *Managers* (admin only).
- Online applicants get the job immediately; offline applicants are queued and granted on login (if disabled, approval needs them online).
- *Request interview* needs a message in the feedback box; the applicant sees it under My Applications and the application moves to *Interview* until decided.

## Commands
| Command | Permission | Description |
|---|---|---|
| `/createtownhall [name]` | `Config.AdminPermission` | Places a clerk at your position (saved to the database) |
| `/removetownhall` | `Config.AdminPermission` | Removes the nearest clerk (within 5m) |

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `AutoDatabase` | `true` | Create tables automatically; `false` = import `install.sql` |
| `NpcModel` / `NpcScenario` | `a_m_m_valtownfolk_01` / `WORLD_HUMAN_STAND_WAITING` | Clerk ped and idle scenario |
| `SpawnDistance` / `TargetDistance` | `60.0` / `2.5` | Clerk spawn range / target range |
| `ServerDistance` | `12.0` | Server rejects requests when no clerk is this close |
| `CloseDistance` | `8.0` | UI closes when the player walks this far away |
| `Commands` | see file | Command names |
| `AdminPermission` | `admin` | rsg-core permission level for full access |
| `AllowBossManagement` | `true` | Boss-grade players manage their own job |
| `RestrictBossGrades` | `true` | Only admins may post boss grades |
| `AllowSelfReview` | `false` | Reviewers may review their own application |
| `PostableJobs` / `BlockedJobs` | `{}` / `{ 'unemployed' }` | Allow / deny lists (empty allow list = any job) |
| `MaxOpenPostingsPerJob` | `5` | Open vacancies per job |
| `MaxActiveApplications` | `3` | Pending applications per player |
| `ReapplyCooldownHours` | `24` | Wait after a rejection (`0` = none) |
| `RequireFeedback` / `MinFeedbackLength` | `true` / `5` | Reviewer feedback rules |
| `MaxCustomQuestions` | `5` | Extra questions a poster may add |
| `BypassMaxJobs` | `false` | Ignore the multi-job maximum on approval |
| `SetActiveJobOnApproval` | `false` | Also switch the new job to the active job |
| `MaxSlots` | `10` | Highest number of seats per vacancy |
| `ExpiryOptions` / `DefaultExpiryDays` | `{0,3,7,14,30}` / `14` | Expiry choices in days (`0` = never) and the default |
| `ExpiryCheckMinutes` | `5` | How often expired vacancies are closed |
| `AllowOfflineApproval` | `true` | Queue approval for offline applicants |
| `AllowInterviews` | `true` | Enable the interview step |
| `AllowResign` / `ResignCooldownHours` | `true` / `24` | Resign from My Jobs and the wait before re-applying to that job |
| `PrerequisiteItems` / `MaxPrerequisiteItems` | `{}` / `3` | Items a poster may require (rsg-inventory names) and the cap per vacancy |
| `AllowJobPrerequisites` | `true` | Allow "must hold job X at rank Y" |
| `Limits` | see file | Text length limits |
| `Questions` | 4 questions | Standard application questions (locale keys) |
| `AllowPushToTalkWhileOpen` / `PushToTalkControls` | `true` / PTT control | Block game controls but keep push-to-talk while the UI is open |

## Webhook
Set `SvConfig.Webhook` in `server/sv_config.lua` to a Discord webhook URL (leave empty to disable). Postings, edits, interviews, decisions, resignations and queued grants are logged there and to `rsg-log` (channel `townhall`).

## Developer notes
- Jobs are read from rsg-core (`GetJobDefinition(s)`); approval uses `exports['rsg-core']:AddPlayerJob`.
- No ox_lib, no ox_target: rsg-core callbacks, notify and locales, rsg-target for the clerk.

Support: https://rexshack.tebex.store
Buy Me a Coffee: https://buymeacoffee.com/rexshack
