# Changelog

All notable changes to rsg-townhall. Newest first.

## 3.2.0

New features
- **Skill and reputation prerequisites**: postings can require an rsg-skills level, minimum honor and regional standing (optional: `AllowSkillPrerequisites`, `AllowReputationPrerequisites`). A prerequisite whose resource is stopped counts as met.
- **rsg-society permission**: holders of the `townhall_post` society permission can post and review for their society (`UseSocietyPermission`, `SocietyPermission`). The permission is registered automatically.
- **Telegram notifications** for offline players via rsg-telegram (`TelegramNotify`, `TelegramSender`).
- **Probation**: postings can set a probation (`ProbationOptions`); a boss confirms or ends it, otherwise the job is removed automatically (checked every `ExpiryCheckMinutes`).
- **Direct invites** to a specific citizen (`AllowInvites`, `InviteExpiryDays`, `MaxPendingInvites`); players accept or decline in My Applications.
- **Claim and bulk review**: claim an application while reviewing it (`AllowClaim`, `ClaimMinutes`) and approve/reject several at once (`AllowBulkReview`, `MaxBulkReview`).
- **Stats tab** and admin **CSV export** into the `exports/` folder (`StatsDays`, `StatsExportFolder`).
- **Invisible/bidi character filter** in text cleaning.
- New export `IsOnProbation`; new event `rsg-townhall:server:probationDecided`; `applicationDecided` also fires for invites (`invite = true`).
- Database: new columns `req_extra`, `probation_days`, `claimed_by`, `claimed_by_name`, `claimed_at` and tables `townhall_probation`, `townhall_invites` (created/migrated automatically).
- 71 new locale keys in all 11 languages.
- Final review fixes: the periodic check can no longer stop after an error, resigning ends an open probation, accepting an invitation re-checks job restrictions and the blacklist, CSV cells starting with tab/CR are neutralised too.
- DOCS.md rewritten: features, config, exports, events, callbacks, examples, schema, security and manual upgrade SQL.

## 3.1.2

### Fixed
- Applying: the "vacancy still open" check is now part of the single INSERT, so an application can no longer land on a vacancy that filled, closed or expired a moment earlier (the fee is refunded and the applicant is told the vacancy is closed).
- Editing answers keeps working after the poster edits a vacancy's extra questions (answers are matched to the questions the applicant actually answered).
- Reverting a failed approval now also clears `closed_at` and `filled_by` when the vacancy is reopened.
- Applications left stuck mid-grant (`granted = 3`) by a crash or restart are returned to the login queue on start.
- NUI requests time out after 15 seconds instead of leaving the UI waiting forever if a server callback never answers.

### Changed
- Manage tab looks up online applicants in one pass instead of once per application.
- `rsg-inventory` added to the manifest dependencies (used for item prerequisites).

## 3.1.1

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.
