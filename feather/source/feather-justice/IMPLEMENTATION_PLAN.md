# Justice implementation status

Justice 0.3.0 implements the master plan (FeatherFramework/feather-framework-docs,
`feather-justice/Feather_Justice_Master_Plan.md`) as written. This file tracks
status against the plan; it does not replace it.

## Delivery phases

| Phase | Implemented | Remaining gate (plan) |
|---|---|---|
| JUS0 discovery | BCC Law inventoried; provisional answers to the team decisions in [LAW_INTEGRATION.md](LAW_INTEGRATION.md) §2 | Acceptance of those answers by the Core, Law, Admin, Jobs, Licenses, Inventory, Contracts and UI maintainers; a second independent consumer |
| JUS1 foundation | Lifecycle, results, validation, structured logs, checksummed migrations, health, plan capability document, jurisdiction/statute repositories, provider and policy integration | Production policy model |
| JUS2 cases and parties | Plan statuses incl. draft/adjudicated/sealed, character and organization parties, bounded queries, defensive snapshots, privacy | — |
| JUS3 charges and warrants | Propose/file/amend/dispose, convictions via rulings, arrest/search/seizure/summons warrants, expiry | In-game run through a law MDT |
| JUS4 citations and custody | Warning and payable citations through Contracts, arrest/booking/release on warrant, judicial order or configured exception | Live payable citation run with Contracts; in-game booking |
| JUS5 evidence links | Inventory instance references, link lifecycle with dispositions, destroy guard, reconciliation | In-game collection and dispositions through a law resource |
| JUS6 rulings and sentences | Rulings, seven sentence types, Contracts fines/restitution, UTC terms, completion with external references | Licenses/Property/Assets execution of suspensions and forfeitures (consumer work) |
| JUS7 sealing, expungement, release | Seal/unseal/expunge at the service layer, retention jobs, operator remediation commands; first consumer (bcc-law 2.0.0-beta.1) on the 0.3.0 calls | Two-player release acceptance; the 1.0.0 freeze |

## Plan conformance

| Plan section | State |
|---|---|
| Domain design tables | The plan's table and column names; extension columns are commented in `server/schema.lua` |
| Public Contract 1 | All 48 operations under the plan's names |
| Events | The plan's 16 facts plus lifecycle facts; payload = safe identifiers and state |
| Invariants and security | Enforced in the service layer; sealed records filtered at repository/service boundaries |
| Suggested policy actions | All 15 used; additional actions listed in CONTRACT.md §12 |
| Cross-domain workflows | Each documents system of record, retry owner, idempotency, states, compensation, reconciliation (CONTRACT.md §13) |
| Persistence and privacy | Repository is the only SQL writer (ownership test); retention classes in OPERATIONS.md |
| Capability document | `contract='feather.justice'`, `version=1`, plan feature keys |
| Failure and restart | Caches rebuild from persistence; Justice and Core restart tested |
| Testing standard | Envelopes/codes, migrations (first run, rerun, checksum mismatch, partial failure), allow/deny/outage, transitions, stale revision and concurrency, idempotency, restart, stale session, pagination, privacy, sealed/expunged, Contracts and Inventory failure injection, repository ownership |
| Proposed smoke tests | All nine names exist; `<source>` accepts a character UUID or a server id |
| Operations and observability | Health, capabilities, AwaitReady, logs with correlation IDs, metrics, redacted audit query, runbooks, compatibility, reconciliation commands |
| Restrictions | Deferred, as the plan says ("If included after the initial release"); capability `restrictions=0` |
| Legacy migration | Not in scope |

## Decisions for team review

Provisional answers to the plan's team decisions are in LAW_INTEGRATION.md §2.
Choices the plan leaves open and this implementation made:
custody statuses `arrested → booked → released`; sentence statuses and the
`CompleteSentence` outcomes `served/vacated/commuted`; community-service task
progress kept by gameplay; case and jurisdiction type lists; hierarchy depth 4;
service-mode action list; rulings carry a subject (per-defendant verdicts);
`GetCase includeRelated` as the bounded case-file index.

## Verification

- `python3 tests/run.py` — 164 checks on a real MariaDB scratch schema (dropped
  afterwards), repository ownership 0 violations.
- Server acceptance on 2026-10-20, character UUIDs, nobody online:
  `JusticeMigrationSmokeTest` 26/26, `JusticePolicySmokeTest` 10/10,
  `JusticeAcceptanceTest` 66 passed, 0 failed (the optional Contracts, Inventory
  and organization parts were not run); cleanup left no records. The
  concurrent-edit check waited on the real row lock (299 ms) as intended; an
  expunge took 1.7 s for 33 queries (rare operation).
- Consumer: bcc-law 2.0.0-beta.1 runs its integration suite against this Justice
  on a scratch schema and passed its live console acceptance on 2026-10-21.

## Next

1. Team review of the provisional decisions (LAW_INTEGRATION.md §2).
2. Live payable citation run: `JusticeAcceptanceTest <actor> <subject> contracts`;
   optionally `item=<throwaway instance id>` and `org=<organization uuid>`, and
   `JusticeRestartChecklist prepare <actor> <subject>` → restart → `verify`.
3. Two-player acceptance with a law resource.
4. Freeze Contract 1 as 1.0.0.

Justice stores only references to Licenses, Property and Assets operations
(license suspensions, forfeitures); carrying them out belongs to those domains.
