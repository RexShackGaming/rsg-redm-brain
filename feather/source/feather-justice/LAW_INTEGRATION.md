# BCC Law integration

How bcc-law, the first law gameplay resource built on Feather Justice, uses it.
It is also a reference for any other law resource: Justice keeps the legal
records, the law resource owns the interactions, and a third-party law script can
replace bcc-law without changes to Justice. The API itself is
[CONTRACT.md](CONTRACT.md); the architecture source is the Justice master plan
(`feather-framework-docs/feather-justice/Feather_Justice_Master_Plan.md`).

## 1. Ownership (plan: Ownership, BCC Law boundary)

| Concern | Owner |
|---|---|
| Jurisdictions, statutes, cases, parties, charges, warrants, citations, custody authority, rulings, sentences, evidence links, sealing, legal audit | Justice |
| Restraint, escort, search, transport, booking interaction, jail placement, community-service tasks, MDT, alerts, commands | bcc-law |
| Fine and restitution obligations and payment | Contracts / Economy |
| Item instances and evidence lockers | Inventory |
| Duty, grade, commission | Jobs / Licenses |
| Who may do what | Core policy (feather-admin provider) |

bcc-law keeps no shadow legal tables, never reads Justice tables and only uses
exports.

## 2. Team decisions (plan: Team review decisions)

Provisional answers, for review by the team:

| # | Answer for 0.3.0 |
|---|---|
| 1 | Everything in the plan's Contract 1 list; restrictions deferred as the plan says |
| 2 | The law resource registers its jurisdictions and statutes at setup (`bcc-law:new_hanover`, `bcc-law:new_hanover.<offense>`) |
| 3 | `DefinitionResources` (`bcc-law`) with service policy `justice.definition.manage` |
| 4 | Policy sees `subject.warrantType`; rulings need the case judge (`Rulings.RequireJudgeParticipant`) |
| 5 | Warrantless custody disabled (`Custody.Exceptions` empty) |
| 6 | A citation lives in a case (case type `citation` is available) |
| 7 | Case eligibility as in CONTRACT.md §4; sealed records need `justice.case.view_sealed` |
| 8 | custodial, fine, restitution, probation, community_service, license_suspension, forfeiture |
| 9 | Records kept; sealing hides; expunge redacts irreversibly; narrative redaction of old closed cases is opt-in |
| 10 | Organizations are parties through feather-organizations (suspect, defendant, victim, witness) |
| 11 | The law resource's own plan |
| 12 | Open (court, jail or MDT consumer) |
| — | Custodial and probation time runs on UTC wall time and continues offline |
| — | Community-service task progress is law gameplay state; the law resource calls `CompleteSentence` when the units are done |

## 3. Calling rules

As CONTRACT.md §1. In short: one table per call; `actorSource` for players;
character UUIDs; `requestId` + `reasonCode` (+ optional `correlationId`) on every
mutation; after an unknown outcome retry with the same `requestId`;
`expectedRevision` on edits; re-read and let the officer confirm after
`revision_conflict`; stored results are history, so read the current state
before any physical action.

## 4. What bcc-law calls

| bcc-law action | Justice |
|---|---|
| Console setup (`LawSetupJurisdictions`, `LawSetupStatutes`) | `RegisterJurisdiction`, `GetJurisdiction`, `RegisterStatute`, without a player |
| MDT case file | `ListCases`, `OpenCase`, `GetCase { includeRelated }`, `UpdateCaseSummary`, `TransitionCase`, `AddCaseParty`, `RemoveCaseParty`, `ListCaseParties` |
| Charges | `ProposeCharge`, `FileCharge`, `AmendCharge`, `DisposeCharge`, `ListCharges` |
| Penal-code editor (judges) | `ListStatutes`, `RegisterStatute`, `GetStatute` + `ReviseStatute` |
| Warrants | `CreateWarrantDraft`, `IssueWarrant`, `ServeWarrant`, `RecallWarrant`, `QuashWarrant`, `ListActiveWarrants` |
| Restraint | `GetWarrant` (an active arrest warrant naming the subject); after the arrest `GetCustodyStatus { custodyId }` |
| Arrest | `RecordArrest { authorityType = 'warrant' or 'judicial_order' }`; a warrant is served in the same transaction and the restraint then rests on the custody record |
| Booking and release | `BookCustody` (officer and subject together at the facility), `ReleaseCustody` |
| Search | `GetWarrant` (a search warrant), then `ServeWarrant` when the search is finished |
| Citations | `IssueCitation`, `ListCitations`; the person pays the fine through Contracts |
| Court | `RecordRuling`, `CreateSentence`, `ActivateSentence`, `SuspendSentence`, `CompleteSentence` |
| Jail and community service | `GetCustodyStatus { subjectCharacterId }`, `ListActiveSentences { defendantCharacterId }`, `CompleteSentence { outcome = 'served' }`, without a player |
| Evidence | `LinkEvidence`, `ListCaseEvidence`, `RemoveEvidenceLink { disposition }`; a `destroyed` item is then destroyed through Inventory's public `DestroyInstances`, a `returned` item is handed back by staff |
| Privacy and history | `SealCase`, `UnsealCase`, `ExpungeRecord`, `GetRecordHistory` |

## 5. Jail placement and reconnect

On character load and on every placement check bcc-law calls
`GetCustodyStatus { subjectCharacterId }` (without a player; audited, identical
automated reads at most once per hour per character) and:
- confines if `custodialSentence.status == 'active'` and `serverTime < endsAt`;
  the countdown is `endsAt - serverTime`; it never restarts `termSeconds`, never
  trusts a client clock and never decrements time itself;
- releases when there is no `custodialSentence` (completed or vacated) or
  `serverTime >= endsAt` (Justice's sweep records the completion and releases the
  custody record in the same transaction);
- for community service, counts finished tasks itself and calls
  `CompleteSentence { outcome = 'served' }` once at the end (same `requestId` on retry).

Probation and community service of a defendant: `ListActiveSentences
{ defendantCharacterId }` (without a player, probation conditions are not returned).

## 6. Policy (feather-admin)

- Player actions: bcc-law passes `actorSource`, and feather-admin's
  `configs/law_acceptance_policy.lua` (mode `qualified`) asks bcc-law's
  `EvaluateActionPolicy` for its 40 actions. Officer actions need on-duty police
  and a peace-officer commission, judicial actions a judge assignment and a
  judicial commission, legal actions either. Issuing search and seizure
  warrants, evidence dispositions, rulings, imposing and changing sentences,
  managing the penal code, sealing, expunging, reading sealed records and the
  audit are judicial; `justice.audit.view` also needs the
  feather-admin `staff.admin.audit.search` permission. Justice then checks case
  membership.
- Calls without a player: `Config.servicePolicy['feather-justice']['bcc-law']` in
  feather-admin's `configs/service_policy.lua` grants `justice.definition.view`,
  `justice.definition.manage`, `justice.custody.view`, `justice.sentence.view` and
  `justice.sentence.complete`.
- feather-organizations lists `feather-justice` in `trustedReaders`;
  feather-contracts lists it in `trustedIssuers`.

## 7. Events a law resource can react to

Payload `{ eventId, kind, recordId, revision, status, caseId, jurisdictionId, subjectCharacterId }`;
deduplicate by `eventId`. Useful: `justice.warrant.issued/served/recalled/quashed/expired.v1`,
`justice.custody.started/booked/released.v1`, `justice.sentence.activated/suspended/completed.v1`,
`justice.citation.issued/settled/defaulted.v1`, `justice.record.sealed.v1`.
The payload carries `subjectCharacterId` and `status`, so restraint and jail
state can be updated without an extra read; read the record before acting.

## 8. Rules both sides keep (plan: Invariants and security)

No client-submitted issuer, authority or trusted subject; no SQL on Justice
tables; a physical failure never erases a legal record; logs without narratives;
fail closed when Justice is unavailable; tests offline with character UUIDs.

## 9. Verification

- Justice: `python3 tests/run.py --server-cfg <server.cfg>` (real MariaDB scratch
  schema, dropped afterwards) and the console smoke tests in OPERATIONS.md.
- bcc-law: `python3 tests/run.py --server-cfg <server.cfg>` in bcc-law runs it
  with this Justice on a scratch schema (two offline characters), then the
  two-player checklist in bcc-law's `docs/ACCEPTANCE_TESTS.md`.
