# Operations — Justice 0.3.0

Runbooks for server operators (master plan: Operations and observability,
Retention classes). Commands are server-console only. **Read-only** commands are
safe on production; **development** commands write records under their own owner
namespace (`justice-acceptance`) with a constructed actor and always clean up.

## Console commands

| Command | Kind | Purpose |
|---|---|---|
| `JusticeContractSmokeTest` | read-only | Release, readiness, plan feature flags |
| `JusticeMigrationSmokeTest` | read-only | Every migration applied with the expected checksum; all tables present |
| `JusticePolicySmokeTest [playerId]` | read-only | Real Core policy: service-mode grants, no blanket grants, untrusted callers refused (its probe uses a UUID of no character, so no real access history is written); with a player id also the session path and that player's decisions |
| `JusticeStatus`, `JusticeMetrics [reset]` | read-only | Health, workflows, per-export and per-dependency metrics, backlog |
| `JusticeAccessAudit <characterUuid>` | read-only | Who searched for a character, when, through which action. Officer searches are recorded every time; identical automated service-mode reads once per `AccessAudit.ServiceRepeatSeconds` (3600) |
| `JusticeWorkflowRetry <recordUuid>` | operator | Brings a Contracts workflow forward (never edits legal state) |
| `JusticeEvidenceReconcile` | operator | Marks inventory evidence deleted outside Justice as `missing` |
| `JusticeRetentionRun [apply]` | operator | Dry run (default) or apply the configured retention |
| `JusticeCaseSmokeTest <actor> <subject> [org=<uuid>]` | development | Draft/open, replay, conflicts, stale revision, concurrent edits, parties, case file index |
| `JusticeWarrantSmokeTest <actor> <subject>` | development | All warrant types and transitions, audited subject search |
| `JusticeCitationSmokeTest <actor> <subject> [contracts]` | development | Warning citation; with `contracts` a $1 payable citation |
| `JusticeCustodySmokeTest <actor> <subject>` | development | Arrest on warrant (served atomically), conflict, booking, status in service mode |
| `JusticeEvidenceSmokeTest <actor> <subject> [item=<id>]` | development | Links, duplicate, disposition; with `item` the Inventory guard (nothing destroyed) |
| `JusticeAcceptanceTest <actor> <subject> [contracts] [item=<id>] [org=<uuid>]` | development | All of the above plus rulings, sentences, judicial custody, 65 s of real deadlines, sealing and expungement |
| `JusticeRestartChecklist prepare <actor> <subject>` → `restart feather-justice` → start the resources that depend on it → `JusticeRestartChecklist verify` | development | State, outbox, Inventory guard and the sentence worker survive a real restart |
| `JusticeAcceptanceCleanup` | development | Removes leftover `justice-acceptance` records |

`<actor>`/`<subject>` are character UUIDs (nobody needs to be online) or online
server ids. Core policy and sessions are exercised only by `JusticePolicySmokeTest`.

## Metrics and logs

`exports['feather-justice']:GetMetrics()` (trusted consumers and
`JusticeConfig.MetricsReaders`, default `feather-admin`) returns
`{ release, state, uptimeMs, operations, providers, backlog, evidenceGuard }`:
per export calls, results by code, replays, average and maximum ms; per
dependency call timing and failures; backlog of undelivered outbox rows (and the
oldest age), workflows and workflow errors, active custody, active custodial
sentences, sealed cases. No IDs, characters or narratives.

Logs are one line, `key=value`, never narrative text:
`event=operation.slow|rejected operation=<export> caller=<resource> code=<code> ms=<n> correlation=<correlationId or requestId>`;
`event=transaction.error operation=<fact> code=<db code> sqlState=<state>`;
`event=workflow.retry`, `event=outbox.retry`, `event=startup.ready|failed`.
Slow operations (`Logging.SlowOperationMs`) are always logged; rejections only with
`Logging.Rejections=true`.

Watch: growing `outboxPending`/`outboxOldestSeconds` (Core broker down);
`workflowErrors` > 0 (Contracts refusing — check its trust and `JusticeStatus`);
rising `revision_conflict` (officers editing the same record); high provider `avgMs`.

## Retention classes (master plan: Retention classes)

The plan asks the team to define retention per class. Current policy: **keep**.

| Class | Current handling |
|---|---|
| Draft cases | Kept; a draft can be dismissed |
| Closed/dismissed cases | Kept; optional narrative redaction after `Retention.RedactClosedCaseNarrativesDays` (off) |
| Warrants, citations, custody records | Kept with their full lifecycle |
| Convictions and acquittals | Kept on the charge and the ruling |
| Sealed/expunged records | Kept; sealed hidden, expunged narratives replaced |
| Audit facts and access audit | Kept |
| Delivered outbox rows | Deleted after `Retention.DeliveredOutboxDays` (30) |

## Backup, restore and rollback

Back up all Justice tables together (they reference each other):

```bash
mysqldump --single-transaction <database> $(mysql -N -e "SELECT GROUP_CONCAT(TABLE_NAME SEPARATOR ' ') \
  FROM information_schema.TABLES WHERE TABLE_SCHEMA='<database>' AND TABLE_NAME LIKE 'justice\_%'") \
  > justice-$(date +%F).sql
```

Restore: stop Justice and its consumers, import the dump, start Justice, run
`JusticeMigrationSmokeTest` and `JusticeStatus`. Contracts obligations and
Inventory items are not in this dump; restoring Justice older than Contracts is
reconciled by the workflow worker (settled stays settled). Undelivered outbox
rows are published again (consumers deduplicate). Sentences whose deadline passed
complete on the next sweep. Never restore a single table.

Rollback of a release: stop Justice, restore the backup taken before the upgrade,
deploy the previous release. A schema downgrade is never done in place.

## Sealed records

Seal, unseal and expunge only through the exports, never SQL. Backups contain
sealed and pre-expunge text: restrict them like sealed material and decide, after
an expunge, whether older backups must be destroyed (server policy). Hard deletion
is only for development cleanup or a documented integrity remediation after a backup.

## Compatibility

Tested combination for Justice 0.3.0:

| Dependency | Version | Notes |
|---|---|---|
| feather-core | 0.5.2 | Contract 1: sessions, policy, events, `SubscribeEvent` |
| feather-mysql | 0.2.0 | |
| feather-character | 0.7.1 | `character-profile` provider |
| feather-contracts | 0.2.0 | optional; lists `feather-justice` in `trustedIssuers` |
| feather-inventory | 0.6.0 | optional; evidence references and destroy guard |
| feather-organizations | 0.2.0 | optional; lists `feather-justice` in `trustedReaders` |
| feather-admin | 0.15.0 | policy provider; service grants for the consumer |
| bcc-law | 2.0.0-beta.1 | consumer (MDT, custody, court, jail, evidence) |
