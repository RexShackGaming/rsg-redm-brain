# Feather Justice — Contract 1 (0.3.0, proposed)

The public contract of `feather-justice`, implementing the master plan's
*Public Contract 1* (`feather-framework-docs/feather-justice/Feather_Justice_Master_Plan.md`).
Operation names, tables, statuses and events follow the plan. Where the plan
leaves detail open, the choice made here is marked **(decision)** and listed in
[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for team review. The contract
is not frozen; 1.0.0 freezes it.

## 1. Conventions (plan: Shared Contract 1 conventions)

- One request table per call; result `{ ok=true, value }` or `{ ok=false, code, message }`.
  Unknown fields are rejected with `invalid_input`.
- `actorSource` is the acting player's server id; Justice derives the character
  from Core. Character references are canonical UUIDs (`CHAR(36)`).
- Mutations: `requestId` (1–128), `reasonCode` (1–64), optional `correlationId`
  (1–128, stored with the audit fact and used in logs). An identical retry returns
  the stored result with `replayed=true`; a changed payload under the same id
  returns `idempotency_conflict`. After `transaction_failed` or a timeout, retry
  with the same `requestId`.
- Edits take `expectedRevision` (or `expectedCaseRevision`/`expectedAuthorityRevision`).
- Times are UTC epoch milliseconds from the database clock (`*At` fields).
- Lists are keyset pages: `limit` 1–25, `cursor` = last id, `nextCursor` in the result.
- Service mode: calls without `actorSource` are accepted only for the actions in
  `JusticeConfig.SystemActions` (`justice.custody.view`, `justice.sentence.view`,
  `justice.sentence.complete`); Core evaluates them as service policy. **(decision)**
- Trusted callers are `JusticeConfig.TrustedResources`. Every call also passes Core
  policy and, for case data, case eligibility (§4).

Snapshots use the plan's column names in camelCase plus `kind` and `recordId`
(for example a case: `caseId, jurisdictionId, caseType, status, title, summary,
openedByCharacterId, openedByResource, openedAt, closedAt, sealedAt, revision`).
Child snapshots also carry `jurisdictionId`.

## 2. Definition operations

| Operation | Fields | Policy |
|---|---|---|
| `RegisterJurisdiction` | `jurisdictionKey` (`<owner>:<name>`), `label`, `jurisdictionType`, `parentJurisdictionId?` | `justice.definition.manage` |
| `UpdateJurisdiction` | `jurisdictionId`, `expectedRevision`, `label?`, `status?` (`active`/`retired`) | `justice.definition.manage` |
| `GetJurisdiction` | `jurisdictionId` or `jurisdictionKey` | `justice.definition.view` |
| `ListJurisdictions` | `parentJurisdictionId?`, `status?`, page | `justice.definition.view` |
| `RegisterStatute` | `jurisdictionId`, `statuteKey` (`<jurisdictionKey>.<name>`), `title`, `category`, `severityClass` (`infraction`/`misdemeanor`/`felony`), `description?`, `effectiveFrom?`, `effectiveUntil?`, `recommendedFine?`, `recommendedCustodySeconds?` (`{min,max}`) | `justice.definition.manage` |
| `ReviseStatute` | `statuteId`, `expectedRevision`, any of the above, `status?` | `justice.definition.manage` |
| `GetStatute` | `statuteId` or `statuteKey` | `justice.definition.view` |
| `ListStatutes` | `jurisdictionId`, `status?`, page | `justice.definition.view` |

Jurisdiction types: `territory, state, county, town, court_district, tribal_authority, region`
(config); hierarchy depth ≤ 4 **(decision)**. A statute applies while `active` and
inside its effective window. Content revisions bump `definitionVersion`; charges
keep the snapshot they were proposed with. Definitions are resource-owned and
callable without a player (service mode).

## 3. Case operations

| Operation | Fields | Policy |
|---|---|---|
| `OpenCase` | `jurisdictionId`, `caseType`, `title` (≤180), `summary` (≤4000), `status?` (`draft`/`open`) | `justice.case.open` |
| `GetCase` | `caseId`, `includeRelated?` (bounded index of warrants, custody, rulings, sentences: 25 each with `truncated`) | `justice.case.view` |
| `ListCases` | `jurisdictionId`, `status?`, `caseType?`, page | `justice.case.view` |
| `UpdateCaseSummary` | `caseId`, `expectedRevision`, `summary`, `title?` | `justice.case.update` |
| `TransitionCase` | `caseId`, `expectedRevision`, `status` | `justice.case.transition` |
| `AddCaseParty` | `caseId`, `expectedCaseRevision`, `partyType` (`character`/`organization`), `partyIdReference`, `partyRole` | `justice.party.manage` |
| `RemoveCaseParty` | `partyId`, `expectedRevision` | `justice.party.manage` |
| `ListCaseParties` | `caseId`, `includeRemoved?`, page | `justice.party.view` |

Case types: `investigation, criminal, civil, citation, administrative` (config).
Statuses (plan): `draft → open → filed ⇄ pending_hearing`, `filed → closed`,
`draft/open/filed/pending_hearing → dismissed`, `adjudicated → closed`.
`adjudicated` comes only from a verdict, `sealed` only from `SealCase`. Closing a
case does not revoke warrants or complete sentences (plan).

Party roles (plan): suspect, defendant, victim, witness, reporting_officer,
investigating_officer, prosecutor, defense_counsel, judge. Organizations
(verified through feather-organizations, must be active) may be suspect,
defendant, victim or witness. One active slot per party and role.

## 4. Case eligibility and privacy (plan: Query rules, Privacy, Sealing)

An authorized actor may read a case if they opened it, hold an active character
role among reporting_officer, investigating_officer, prosecutor, defense_counsel,
judge, or are granted `justice.case.view_all`; writing needs opener,
investigating_officer, prosecutor, judge or `justice.case.manage_all`. Role labels
never grant policy. Sealed cases and every record in them are excluded from all
reads and lists unless the actor holds `justice.case.view_sealed`, and are
read-only. Character searches (subject or defendant filters, `GetCustodyStatus`
by character) are privileged and written to the access audit: every officer search,
and identical automated service-mode reads once per `AccessAudit.ServiceRepeatSeconds`.

## 5. Charge operations

| Operation | Fields | Policy |
|---|---|---|
| `ProposeCharge` | `caseId`, `expectedCaseRevision`, `defendantCharacterId`, `statuteId`, `count` (1–100) | `justice.charge.propose` |
| `FileCharge` | `chargeId`, `expectedRevision` | `justice.charge.file` |
| `AmendCharge` | `chargeId`, `expectedRevision`, `statuteId?`, `count?` | `justice.charge.amend` |
| `DisposeCharge` | `chargeId`, `expectedRevision`, `disposition` (`withdrawn`/`dismissed`) | `justice.charge.dispose` |
| `ListCharges` | `caseId`, or `defendantCharacterId` + `jurisdictionId`; `status?`, page | `justice.charge.view` |

Statuses/dispositions (plan): proposed, filed, amended, dismissed, convicted,
acquitted, withdrawn. An amendment marks the charge `amended` and returns the new
charge (`amendsChargeId`). Convictions and acquittals come only from `RecordRuling`.

## 6. Warrant operations

| Operation | Fields | Policy |
|---|---|---|
| `CreateWarrantDraft` | `caseId`, `expectedCaseRevision`, `subjectCharacterId`, `warrantType` (`arrest`/`search`/`seizure`/`summons`), `basisSummary` (≤2000), `validForSeconds` (60–2592000) | `justice.warrant.draft` |
| `IssueWarrant` / `ServeWarrant` / `RecallWarrant` / `QuashWarrant` | `warrantId`, `expectedRevision` | `justice.warrant.issue` / `.serve` / `.recall` / `.quash` |
| `GetWarrant` | `warrantId` | `justice.warrant.view` |
| `ListActiveWarrants` | `jurisdictionId` or `caseId`; `subjectCharacterId?`, `warrantType?`, page | `justice.warrant.view` |

Statuses (plan): draft, active, served, expired, recalled, quashed. Policy
receives `subject.warrantType`, so a server can require a judge for some types
(team decision 4). Reads derive `expired` exactly at `expiresAt` (`storedStatus`
shows the stored value); a sweep persists it (`justice.warrant.expired.v1`).

## 7. Citation and custody operations

| Operation | Fields | Policy |
|---|---|---|
| `IssueCitation` | `caseId`, `expectedCaseRevision`, `subjectCharacterId`, `statuteId`, `basisSummary`, and for a fine `amount` + `dueInSeconds` | `justice.citation.issue` |
| `GetCitation` | `citationId` | `justice.citation.view` |
| `ListCitations` | `caseId`, or `subjectCharacterId` + `jurisdictionId`; `status?`, page | `justice.citation.view` |
| `RecordArrest` | `caseId`, `authorityType`, `authorityId`, `expectedAuthorityRevision` (warrant/order) or `subjectCharacterId` (exception) | `justice.custody.record` (+ `justice.warrant.serve` for a warrant) |
| `BookCustody` | `custodyId`, `expectedRevision`, `facilityKey` | `justice.custody.record` |
| `ReleaseCustody` | `custodyId`, `expectedRevision`, `releaseReason` | `justice.custody.release` |
| `GetCustodyStatus` | `custodyId`, or `subjectCharacterId` (service mode allowed) | `justice.custody.view` |

A citation without an amount is a warning (`issued`, no obligation, plan). A fine
is `pending` until Contracts issues the obligation, then `issued`, `defaulted`
(still payable) and `settled` only when Contracts confirms payment.

Custody authority (plan): `warrant` (an active arrest warrant of the case, served
in the same transaction), `judicial_order` (an active custodial sentence) or
`exception` (keys enabled in `JusticeConfig.Custody.Exceptions`, none by default —
team decision 5). Statuses: `arrested → booked → released` **(decision)**; one
unreleased record per character. `GetCustodyStatus` by character returns
`{ subjectCharacterId, serverTime, custody?, custodialSentence? }` where
`custodialSentence` carries `startsAt`, `endsAt`, `remainingMs`, `facilityKey`.

## 8. Ruling and sentence operations

| Operation | Fields | Policy |
|---|---|---|
| `RecordRuling` | `caseId`, `expectedCaseRevision`, `rulingType` (`verdict`/`dismissal`/`order`), `summary`, `subjectCharacterId` (verdict; optional for dismissal/order), `findings` (verdict) or `outcome` (order) | `justice.ruling.record` |
| `CreateSentence` | `caseId`, `expectedCaseRevision`, `rulingId` (convicting verdict), `sentenceType`, `terms` | `justice.sentence.impose` |
| `ActivateSentence` | `sentenceId`, `expectedRevision` (also resumes a suspended sentence) | `justice.sentence.activate` |
| `SuspendSentence` | `sentenceId`, `expectedRevision` | `justice.sentence.suspend` |
| `CompleteSentence` | `sentenceId`, `expectedRevision`, `outcome` (`served`/`vacated`/`commuted`), `effectReference?` | `justice.sentence.complete` |
| `GetSentence` | `sentenceId` | `justice.sentence.view` |
| `ListActiveSentences` | `jurisdictionId`, `caseId` or `defendantCharacterId` (service mode: one defendant); `sentenceType?`, page | `justice.sentence.view` |

Rulings need the case judge (an active `judge` party; `Rulings.RequireJudgeParticipant`,
team decision 4) and are immutable. A verdict's `findings` list every filed charge
of the subject once (`convicted`/`acquitted`); the case becomes `adjudicated` when
no charge remains open. A dismissal dismisses filed and withdraws proposed charges
(of the subject, or all), and the case becomes `dismissed` when nothing remains.

Sentence types and terms (plan): custodial `{termSeconds, facilityKey?}`,
probation `{termSeconds, conditionsSummary}`, community_service `{units, taskKey}`,
fine `{amount, dueInSeconds}`, restitution `{amount, dueInSeconds, creditorCharacterId}`,
license_suspension `{licenseKey, termSeconds?}`, forfeiture `{targetType, targetReference}`.
Statuses: pending, activating, active, suspended, completing, completed (with
`outcome`). Custodial and probation terms run on UTC wall time from activation and
continue while the subject is offline; a sweep completes them at `endsAt` and
releases the subject's custody in the same case or on that order in the same
transaction. One active or suspended custodial sentence per character. Judges
suspend, vacate and commute. Community service is completed by `CompleteSentence`
(service mode allowed for this only). License suspension and forfeiture complete
with the executing domain's `effectReference` (plan workflows). Fines and
restitution complete only when Contracts confirms settlement; vacating them
cancels the obligation first (`completing`), and a debt already paid completes as
`served` (no refund here).

## 9. Evidence and record-access operations

| Operation | Fields | Policy |
|---|---|---|
| `LinkEvidence` | `caseId`, `expectedCaseRevision`, `evidenceType` (`inventory_item`/`external`), `evidenceId`, `relationship` (`collected`/`submitted`/`examined`/`exhibit`), `description?`, `subjectCharacterId?` | `justice.evidence.link` |
| `RemoveEvidenceLink` | `evidenceLinkId`, `expectedRevision`, `disposition?` (`returned`/`destroyed`/`forfeited`) | `justice.evidence.link` |
| `ListCaseEvidence` | `caseId`, `includeRemoved?`, page | `justice.evidence.view` |
| `SealCase` | `caseId`, `expectedRevision` | `justice.record.seal` |
| `UnsealCase` | `caseId`, `expectedRevision` | `justice.record.seal` + `justice.case.view_sealed` |
| `ExpungeRecord` | `caseId`, `expectedRevision` | `justice.record.expunge` + `justice.case.view_sealed` |

`inventory_item` ids are Inventory instance ids (decimal strings), verified at
link time; while linked, an Inventory destroy guard vetoes destroying the item.
Removing the link with a disposition is the plan's immutable disposition record.
Items deleted outside the guard become `missing` (`JusticeEvidenceReconcile`).

Only closed or dismissed cases can be sealed (`case_open`); sealing is refused
while an unexpired active warrant, unreleased custody, an unfinished sentence or an
unsettled fine remains (`seal_blocked`). Unseal restores the previous status.
Expunge requires a sealed case, replaces narratives with `[expunged]` (case,
warrant and citation bases, ruling summaries, probation conditions; evidence
descriptions removed) including stored receipts, and cannot be undone.

## 10. Runtime and operations exports (plan: Operations and observability)

`GetHealth`, `GetCapabilities` (plan capability document: `contract='feather.justice'`,
`version=1`, `features`), `AwaitReady(timeoutMs)`, `GetMetrics()` (trusted
consumers and `MetricsReaders`), `GetRecordHistory { recordId, limit? }` (policy
`justice.audit.view`; facts with actor, reason, correlation ID; sealed cases need
`justice.case.view_sealed`). Console commands: [OPERATIONS.md](OPERATIONS.md).

## 11. Events (plan: Events)

`justice.<fact>.v1`, published after commit from the outbox, at least once and
ordered per record (deduplicate by `eventId`). Payload:
`{ eventId, kind, recordId, revision, status, caseId?, jurisdictionId?, subjectCharacterId? }`
— safe identifiers and state, never narrative. Facts: the plan's case.opened,
case.transitioned, party.added, charge.filed, charge.disposed, warrant.issued,
warrant.served, warrant.recalled, citation.issued, custody.started,
custody.released, ruling.recorded, sentence.activated, sentence.completed,
evidence.linked, record.sealed, plus jurisdiction.registered/updated,
statute.registered/revised, case.updated, party.removed, charge.proposed/amended,
warrant.drafted/quashed/expired, citation.obligation_issued/settled/defaulted,
custody.booked, sentence.created/obligation_issued/suspended/defaulted,
evidence.removed/missing, record.unsealed/expunged.

## 12. Policy actions

Plan-suggested: `justice.case.open`, `case.view`, `case.view_sealed`,
`charge.file`, `charge.dispose`, `warrant.issue`, `warrant.serve`,
`warrant.recall`, `citation.issue`, `custody.record`, `ruling.record`,
`sentence.impose`, `evidence.link`, `record.seal`, `record.expunge`. Also used:
`justice.definition.manage/view`, `case.update/transition/view_all/manage_all`,
`party.manage/view`, `charge.propose/amend/view`, `warrant.draft/quash/view`,
`citation.view`, `custody.release/view`, `sentence.activate/suspend/complete/view`,
`evidence.view`, `audit.view`.

## 13. Cross-domain workflows (plan: Cross-domain workflows)

| Workflow | System of record per step | Retry owner / idempotency scope | Pending and failed states | Compensation | Reconciliation |
|---|---|---|---|---|---|
| Citation and fine | Law: interaction; Justice: citation; Contracts: obligation; Economy: payment | Justice worker; Contracts request ids `justice:citation:draft/issue:<id>` | `pending` until issued (refusal recorded as `last_code`, retried); `issued`/`defaulted` watched | none: a citation is not cancelled by Justice | `JusticeStatus`, `JusticeWorkflowRetry <id>` |
| Arrest and custody | Law: restraint/transport; Justice: custody authority and warrant service | Law retries `RecordArrest` with the same `requestId` | `arrested` until `BookCustody`; placement failure → `ReleaseCustody` with a reason | the served warrant stays served (plan: physical failure does not erase the record) | `GetCustodyStatus` |
| Evidence collection | Law: collection; Inventory: instance/locker; Justice: link | Law retries `LinkEvidence` with the same `requestId` | link failure after collection stays explicit and retryable | `RemoveEvidenceLink` with a disposition | `JusticeEvidenceReconcile` |
| Sentence and fine/restitution | Justice: sentence; Contracts: obligation; Economy: settlement | Justice worker; `justice:sentence:draft/issue/cancel:<id>` | `activating`, `active` (watched), `completing` (cancel pending) | vacate cancels the obligation; a paid debt is never refunded | `JusticeStatus`, `JusticeWorkflowRetry <id>` |
| Sentence and jail | Justice: term and authority; Law: confinement | Justice sweep (`justice:sentence:term:<id>`) | `active` until `endsAt`, `suspended` frozen | completion releases the related custody atomically | `GetCustodyStatus`, `JusticeRestartChecklist` |
| License suspension / forfeiture | Justice: order; Licenses/Property/Assets: execution | executing domain; Justice stores its reference | `active` until `CompleteSentence` with `effectReference` | judge may vacate/commute | `ListActiveSentences` |

## 14. Error codes

`invalid_input, not_ready, authorization_denied, policy_unavailable, actor_required,
session_expired, not_found, revision_conflict, idempotency_conflict,
transaction_failed, operation_failed, invalid_transition, no_change, key_conflict,
jurisdiction_unavailable, jurisdiction_mismatch, hierarchy_too_deep, case_closed,
case_open, party_exists, subject_not_found, subject_inactive, character_unavailable,
organization_not_found, organization_inactive, organization_unavailable,
statute_mismatch, warrant_expired, exception_not_allowed, custody_conflict,
judge_required, findings_incomplete, charge_not_filed, conviction_required,
sentence_conflict, sentence_elapsed, term_not_served, workflow_pending,
settlement_required, effect_reference_required, evidence_exists,
evidence_not_found, inventory_unavailable, seal_blocked, invalid_config`.
Workflow-only codes (in `JusticeStatus`): `settlement_pending, obligation_mismatch`.
