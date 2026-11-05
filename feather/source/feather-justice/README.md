# Feather Justice

The authoritative registry of legal records for the Feather Framework:
jurisdictions and their statutes (the penal code), cases and their parties,
charges, warrants, citations, arrest and custody authority, rulings, sentences,
evidence references, sealing and expungement. Justice owns each record's
identity, status and history, and keeps an audit trail of every change.

Justice does not own gameplay. Investigations, MDT screens, restraints,
transport, jail cells, community-service tasks and courtroom play stay in the
gameplay resources, which ask Justice what legal authority exists and record
legal facts through it. Fines and restitution are feather-contracts obligations
paid through feather-economy; evidence items stay in feather-inventory.

## Status

Version 0.3.0. Phases JUS0 to JUS7 of the
[Justice master plan](https://github.com/FeatherFramework/feather-framework-docs/blob/main/feather-justice/Feather_Justice_Master_Plan.md)
are implemented with the plan's tables, operation names, statuses, events and
smoke tests; see [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
[CONTRACT.md](CONTRACT.md) is the public contract, proposed for freezing as
Contract 1. It is frozen with 1.0.0.

Server acceptance on 2026-10-20, nobody connected (character UUIDs):
`JusticeMigrationSmokeTest` 26/26; `JusticePolicySmokeTest` 10/10;
`JusticeAcceptanceTest` 66 passed, 0 failed (the optional Contracts, Inventory
and organization parts were not run). bcc-law (MDT, arrest and booking, court,
jail, evidence) is built on it; [LAW_INTEGRATION.md](LAW_INTEGRATION.md) shows
which calls it makes.

## Requirements

```text
feather-mysql
feather-core
feather-character
```

At runtime, characters resolve through Core sessions and the `character-profile`
provider (feather-character), whether or not they are online. Optional:
feather-contracts (payable citations, fines and restitution; it must list
`feather-justice` in `trustedIssuers`), feather-inventory (verifies evidence items
and blocks destroying linked ones) and feather-organizations (organizations as
case parties; it must list `feather-justice` in `trustedReaders`). Without them
Justice still starts and the related operations fail closed or wait and retry.
Policy is decided by Core's default policy provider (feather-admin).

## Installation

1. Place the resource in `resources/[feather]/feather-justice`.
2. Start it after Core, Character and the optional resources, and before
   feather-admin and the resources that use it:

   ```cfg
   ensure feather-mysql
   ensure feather-core
   ensure feather-character
   ensure feather-organizations
   ensure feather-contracts
   ensure feather-inventory
   ensure feather-justice
   ensure feather-admin
   ```

3. Trust each resource that uses Justice (see
   [Configuration and access](#configuration-and-access)) and restart
   feather-justice and feather-admin.

The first start applies seven checksummed migrations (17 tables) and logs
`event=startup.ready`. Later starts apply none. Resources that depend on Justice
stop when it restarts; start them again.

## Verification

Read-only, safe on a live server:

```text
JusticeContractSmokeTest
JusticeMigrationSmokeTest
JusticePolicySmokeTest [serverId]
```

`JusticeContractSmokeTest` prints the release, readiness and the capability
flags; expect `ready=true` and `1` for every feature you use (`evidenceGuard`
needs feather-inventory). `JusticeMigrationSmokeTest`
expects 26/26 (every migration with its checksum, every table).
`JusticePolicySmokeTest` expects 10/10 (service grants, no blanket grants,
untrusted callers refused); with the server ID of a connected player it also
checks that player's decisions.

The development tests write records under their own owner namespace
(`justice-acceptance`) with a constructed actor and always clean up. Nobody
needs to be online: pass two different characters as character UUIDs (or server
IDs of connected players).

```text
JusticeAcceptanceTest <serverId|characterUuid> <otherServerId|otherCharacterUuid> [contracts] [item=<id>] [org=<uuid>]
```

Expect 0 failed. It runs every smoke scenario (cases, warrants, citations,
custody, evidence) plus rulings, all sentence types, judicial custody, about 65
seconds of real deadlines, sealing and expungement. `contracts` adds a payable
citation through feather-contracts, `item=` a throwaway Inventory instance for
the evidence guard (nothing is destroyed), `org=` an organization party. The
single scenarios (`JusticeCaseSmokeTest`, `JusticeWarrantSmokeTest`,
`JusticeCitationSmokeTest`, `JusticeCustodySmokeTest`, `JusticeEvidenceSmokeTest`)
and `JusticeRestartChecklist` are described in [OPERATIONS.md](OPERATIONS.md).

Outside the server, `python3 tests/run.py --server-cfg <path to server.cfg>` runs
the real code on a throwaway MariaDB schema (always dropped), with Core,
Character, Contracts, Inventory and Organizations mocked at their export
boundary: 164 checks. It needs Python 3 and the MariaDB and Lua 5.4 libraries.

## Model

- **Jurisdiction:** a legal area (`territory`, `state`, `county`, `town`,
  `court_district`, `tribal_authority`, `region`) with a stable key namespaced
  by the registering resource (`bcc-law:new_hanover`), optionally inside a parent
  (at most 4 levels).
- **Statute:** an offense of a jurisdiction (`bcc-law:new_hanover.theft.petty`) with a
  title, category, severity (`infraction`, `misdemeanor`, `felony`), an optional
  effective window and advisory fine and custody ranges. A revision bumps its
  `definitionVersion`; charges keep the version they were proposed with.
- **Case:** `caseId`, type (`investigation`, `criminal`, `civil`, `citation`,
  `administrative`), title and summary. Status: `draft`, `open`, `filed`,
  `pending_hearing`, `adjudicated` (only from a verdict), `closed`, `dismissed`,
  and `sealed` (only by sealing), which hides it. The allowed transitions are in
  [CONTRACT.md](CONTRACT.md).
- **Party:** a character or organization in a case role: `suspect`,
  `defendant`, `victim`, `witness`, `reporting_officer`,
  `investigating_officer`, `prosecutor`, `defense_counsel`, `judge`.
  Organizations may only be suspect, defendant, victim or witness.
- **Charge:** a statute against a defendant, with a count: `proposed`, `filed`,
  `amended`, `withdrawn`, `dismissed`, `convicted`, `acquitted`.
- **Warrant:** `arrest`, `search`, `seizure` or `summons` for one subject:
  `draft`, `active` until `expiresAt`, `served`, `recalled`, `quashed`, `expired`.
- **Citation:** a warning (no amount, `issued`) or a payable fine that becomes a
  Contracts obligation: `pending`, `issued`, `defaulted` (still payable), `settled`.
- **Custody:** arrest on an authority (`warrant`, `judicial_order` or a
  configured exception): `arrested` → `booked` → `released`. A character has at
  most one unreleased custody record.
- **Ruling:** `verdict` (a finding per filed charge of its subject),
  `dismissal` or `order`. Rulings never change.
- **Sentence:** `custodial`, `probation`, `community_service`, `fine`,
  `restitution`, `license_suspension` or `forfeiture`, with typed terms. Status:
  `pending`, `activating` (a fine's obligation is being issued), `active`,
  `suspended` (custodial, probation and community service only), `completing`
  (an obligation is being cancelled) and `completed`, with outcome `served`,
  `vacated` or `commuted`.
- **Evidence link:** an Inventory item instance or an external reference linked
  to a case; removing it may record a disposition (`returned`, `destroyed`,
  `forfeited`).

## Rules

- **Trust and policy.** Only resources in `TrustedResources` may call Justice,
  and Core policy must allow each action for the acting player (`actorSource`).
  Trust alone allows nothing.
- **Case access.** A player reads a case they opened or hold an active role in,
  or with `justice.case.view_all`; changes need the opener, the investigating
  officer, prosecutor or judge, or `justice.case.manage_all`. Role labels never
  grant policy.
- **Sealed records** are hidden from every read and list without
  `justice.case.view_sealed` and cannot change. Only a closed or dismissed case
  with no active warrant, custody, sentence or unpaid fine can be sealed.
  Expunging a sealed case replaces its narratives permanently.
- **Rulings** need the case's judge (`Rulings.RequireJudgeParticipant`). A
  verdict covers every filed charge of its subject; convictions and acquittals
  come only from rulings.
- **Time.** Warrants expire exactly at `expiresAt`. Custodial and probation
  terms run on UTC wall time from activation and continue while the subject is
  offline; a sweep completes them and releases the related custody.
- **Money and items.** Justice moves neither. A fine or restitution completes
  only when Contracts confirms payment; a paid debt is never refunded.
- **Searches by character** (subject or defendant filters, custody status by
  character) are written to the access audit.
- **Without a player** a trusted resource may call only the actions in
  `SystemActions` and the definition operations, and Core service policy must
  allow them.

## Server exports

All exports take one request table and return `{ ok = true, value = ... }` or
`{ ok = false, code, message }`; unknown fields are refused. The caller is the
Cfx invoking resource and must be in `TrustedResources` (definition changes also
in `DefinitionResources`).

Every mutation takes a stable `requestId` (at most 128 characters), a
namespaced `reasonCode` (at most 64) such as `law.case.open`, an optional
`correlationId`, and `actorSource`, the server ID of the acting player (Justice
reads the character from Core). Retrying a request ID with the same payload
replays the stored result with `replayed = true`; reusing it with a different
payload returns `idempotency_conflict`. Changes take the record's
`expectedRevision` (child records: `expectedCaseRevision`). Times are Unix
milliseconds; lists return up to 25 items and `nextCursor`. Every field is in
[CONTRACT.md](CONTRACT.md).

### Definitions

| Export | Fields | Policy action |
|---|---|---|
| `RegisterJurisdiction` | `jurisdictionKey`, `label`, `jurisdictionType`, optional `parentJurisdictionId` | `justice.definition.manage` |
| `UpdateJurisdiction` | `jurisdictionId`, `expectedRevision`, optional `label`, `status` (`active`, `retired`) | `justice.definition.manage` |
| `GetJurisdiction`, `ListJurisdictions` | `jurisdictionId` or `jurisdictionKey`; list: optional `parentJurisdictionId`, `status` | `justice.definition.view` |
| `RegisterStatute` | `jurisdictionId`, `statuteKey`, `title`, `category`, `severityClass`, optional `description`, `effectiveFrom`, `effectiveUntil`, `recommendedFine`, `recommendedCustodySeconds` (`{ min, max }`) | `justice.definition.manage` |
| `ReviseStatute` | `statuteId`, `expectedRevision`, any of the above, optional `status` | `justice.definition.manage` |
| `GetStatute`, `ListStatutes` | `statuteId` or `statuteKey`; list: `jurisdictionId`, optional `status` | `justice.definition.view` |

### Cases and parties

| Export | Fields | Policy action |
|---|---|---|
| `OpenCase` | `jurisdictionId`, `caseType`, `title`, `summary`, optional `status` (`draft`, `open`) | `justice.case.open` |
| `GetCase` | `caseId`, optional `includeRelated` (the case's warrants, custody, rulings and sentences) | `justice.case.view` |
| `ListCases` | `jurisdictionId`, optional `status`, `caseType` | `justice.case.view` |
| `UpdateCaseSummary` | `caseId`, `expectedRevision`, `summary`, optional `title` | `justice.case.update` |
| `TransitionCase` | `caseId`, `expectedRevision`, `status` | `justice.case.transition` |
| `AddCaseParty` | `caseId`, `expectedCaseRevision`, `partyType`, `partyIdReference`, `partyRole` | `justice.party.manage` |
| `RemoveCaseParty` | `partyId`, `expectedRevision` | `justice.party.manage` |
| `ListCaseParties` | `caseId`, optional `includeRemoved` | `justice.party.view` |

### Charges and warrants

| Export | Fields | Policy action |
|---|---|---|
| `ProposeCharge` | `caseId`, `expectedCaseRevision`, `defendantCharacterId`, `statuteId`, `count` | `justice.charge.propose` |
| `FileCharge` | `chargeId`, `expectedRevision` | `justice.charge.file` |
| `AmendCharge` | `chargeId`, `expectedRevision`, optional `statuteId`, `count` | `justice.charge.amend` |
| `DisposeCharge` | `chargeId`, `expectedRevision`, `disposition` (`withdrawn`, `dismissed`) | `justice.charge.dispose` |
| `ListCharges` | `caseId`, or `defendantCharacterId` + `jurisdictionId`; optional `status` | `justice.charge.view` |
| `CreateWarrantDraft` | `caseId`, `expectedCaseRevision`, `subjectCharacterId`, `warrantType`, `basisSummary`, `validForSeconds` | `justice.warrant.draft` |
| `IssueWarrant`, `ServeWarrant`, `RecallWarrant`, `QuashWarrant` | `warrantId`, `expectedRevision` | `justice.warrant.issue`, `.serve`, `.recall`, `.quash` |
| `GetWarrant`, `ListActiveWarrants` | `warrantId`; list: `jurisdictionId` or `caseId`, optional `subjectCharacterId`, `warrantType` | `justice.warrant.view` |

### Citations and custody

| Export | Fields | Policy action |
|---|---|---|
| `IssueCitation` | `caseId`, `expectedCaseRevision`, `subjectCharacterId`, `statuteId`, `basisSummary`, and for a fine `amount` + `dueInSeconds` | `justice.citation.issue` |
| `GetCitation`, `ListCitations` | `citationId`; list: `caseId`, or `subjectCharacterId` + `jurisdictionId` | `justice.citation.view` |
| `RecordArrest` | `caseId`, `authorityType`, and `authorityId` + `expectedAuthorityRevision` (warrant, judicial order) or `subjectCharacterId` (exception) | `justice.custody.record` (+ `justice.warrant.serve` for a warrant) |
| `BookCustody` | `custodyId`, `expectedRevision`, `facilityKey` | `justice.custody.record` |
| `ReleaseCustody` | `custodyId`, `expectedRevision`, `releaseReason` | `justice.custody.release` |
| `GetCustodyStatus` | `custodyId`, or `subjectCharacterId` (custody and the custodial term with `remainingMs`) | `justice.custody.view` |

### Rulings and sentences

| Export | Fields | Policy action |
|---|---|---|
| `RecordRuling` | `caseId`, `expectedCaseRevision`, `rulingType`, `summary`, `subjectCharacterId` (verdict; optional otherwise), and `findings` (verdict) or `outcome` (order) | `justice.ruling.record` |
| `CreateSentence` | `caseId`, `expectedCaseRevision`, `rulingId` (a convicting verdict), `sentenceType`, `terms` | `justice.sentence.impose` |
| `ActivateSentence` | `sentenceId`, `expectedRevision` (also resumes a suspended sentence) | `justice.sentence.activate` |
| `SuspendSentence` | `sentenceId`, `expectedRevision` | `justice.sentence.suspend` |
| `CompleteSentence` | `sentenceId`, `expectedRevision`, `outcome` (`served`, `vacated`, `commuted`), optional `effectReference` | `justice.sentence.complete` |
| `GetSentence`, `ListActiveSentences` | `sentenceId`; list: `jurisdictionId`, `caseId` or `defendantCharacterId`, optional `sentenceType` | `justice.sentence.view` |

### Evidence and records

| Export | Fields | Policy action |
|---|---|---|
| `LinkEvidence` | `caseId`, `expectedCaseRevision`, `evidenceType` (`inventory_item`, `external`), `evidenceId`, `relationship`, optional `description`, `subjectCharacterId` | `justice.evidence.link` |
| `RemoveEvidenceLink` | `evidenceLinkId`, `expectedRevision`, optional `disposition` (`returned`, `destroyed`, `forfeited`) | `justice.evidence.link` |
| `ListCaseEvidence` | `caseId`, optional `includeRemoved` | `justice.evidence.view` |
| `SealCase`, `UnsealCase` | `caseId`, `expectedRevision` | `justice.record.seal` (unseal also `justice.case.view_sealed`) |
| `ExpungeRecord` | `caseId`, `expectedRevision` | `justice.record.expunge` + `justice.case.view_sealed` |
| `GetRecordHistory` | `recordId`, optional `limit` | `justice.audit.view` |

`GetHealth`, `GetCapabilities` (`contract = 'feather.justice'`, `version = 1`,
feature flags), `AwaitReady(timeoutMs)` and `GetMetrics()` report the runtime.

### Record snapshot

Snapshots use the plan's column names in camelCase, plus `kind` and `recordId`.
Child records also carry `jurisdictionId`.

```lua
{
    kind = 'case',
    recordId = 'uuid',             -- same as caseId
    caseId = 'uuid',
    jurisdictionId = 'uuid',
    caseType = 'criminal',
    status = 'open',               -- draft | open | filed | pending_hearing | adjudicated | closed | dismissed | sealed
    title = 'Store theft',
    summary = 'Goods taken from the general store.',
    openedByCharacterId = 'character-uuid',
    openedByResource = 'bcc-law',
    openedAt = 1760000000000,      -- Unix ms
    closedAt = nil,
    sealedAt = nil,
    revision = 1
}
```

### Failure codes

| Code | Meaning |
|---|---|
| `invalid_input` | Missing, unknown or out-of-range field |
| `not_ready`, `policy_unavailable` | Justice or the policy provider is not ready |
| `authorization_denied` | Untrusted caller, or policy refused the action |
| `session_expired`, `actor_required` | The acting player changed, or the action needs a player |
| `not_found` | No such record, or the actor may not see it |
| `revision_conflict` | `expectedRevision` is stale; read and try again |
| `idempotency_conflict` | The request ID was used with a different payload |
| `transaction_failed` | Not confirmed; retry with the same request ID |
| `invalid_transition`, `case_closed`, `case_open` | Not allowed in the record's current status |
| `custody_conflict`, `sentence_conflict` | The character already has unreleased custody or an active custodial sentence |
| `judge_required`, `findings_incomplete`, `conviction_required` | Court rules not met |
| `seal_blocked` | The case still has an active warrant, custody, sentence or unpaid fine |

The complete list is in [CONTRACT.md](CONTRACT.md).

## Example

```lua
local Justice = exports['feather-justice']

-- bcc-law's console setup, without a player (needs the service grants below).
-- Stable request IDs: a rerun replays the stored result.
local jurisdiction = Justice:RegisterJurisdiction({
    requestId = 'law-jurisdiction:new_hanover:v2', reasonCode = 'law.setup',
    jurisdictionKey = 'bcc-law:new_hanover', label = 'New Hanover', jurisdictionType = 'county'
})
Justice:RegisterStatute({
    requestId = 'law-statute:new_hanover:theft.petty:v1', reasonCode = 'law.setup',
    jurisdictionId = jurisdiction.value.jurisdictionId, statuteKey = 'bcc-law:new_hanover.theft.petty',
    title = 'Petty theft', category = 'theft', severityClass = 'misdemeanor',
    recommendedFine = { min = 2500, max = 10000 }, recommendedCustodySeconds = { min = 300, max = 900 }
})

-- An officer opens a case from the MDT and names the suspect; the officer is the
-- acting player. bcc-law prefixes the client's request ID with the character UUID.
local case = Justice:OpenCase({
    actorSource = source, requestId = officerCharacterId .. ':' .. requestId, reasonCode = 'law.case.open',
    jurisdictionId = jurisdiction.value.jurisdictionId, caseType = 'criminal',
    title = 'Store theft', summary = 'Goods taken from the general store.'
})
if case.ok then
    Justice:AddCaseParty({
        actorSource = source, requestId = officerCharacterId .. ':' .. partyRequestId, reasonCode = 'law.party.add',
        caseId = case.value.caseId, expectedCaseRevision = case.value.revision,
        partyType = 'character', partyIdReference = suspectCharacterId, partyRole = 'suspect'
    })
end

-- bcc-law's jail placement, no player needed: the prisoner's custody and custodial term.
local status = Justice:GetCustodyStatus({ subjectCharacterId = suspectCharacterId })
local term = status.ok and status.value.custodialSentence
if term and term.status == 'active' and status.value.serverTime < term.endsAt then
    -- keep the character in the cell until term.endsAt
end
```

## Client route

None. Players reach Justice only through gameplay resources (an MDT, for
example) that call the server exports for them.

## Events

Each change writes an audit fact to `justice_audit_events` and an event to
`justice_outbox` in the same transaction; the outbox is then published through
Core:

```text
justice.jurisdiction.registered.v1   justice.jurisdiction.updated.v1
justice.statute.registered.v1        justice.statute.revised.v1
justice.case.opened.v1               justice.case.updated.v1
justice.case.transitioned.v1         justice.party.added.v1
justice.party.removed.v1             justice.charge.proposed.v1
justice.charge.filed.v1              justice.charge.amended.v1
justice.charge.disposed.v1           justice.warrant.drafted.v1
justice.warrant.issued.v1            justice.warrant.served.v1
justice.warrant.recalled.v1          justice.warrant.quashed.v1
justice.warrant.expired.v1           justice.citation.issued.v1
justice.citation.obligation_issued.v1
justice.citation.settled.v1          justice.citation.defaulted.v1
justice.custody.started.v1           justice.custody.booked.v1
justice.custody.released.v1          justice.ruling.recorded.v1
justice.sentence.created.v1          justice.sentence.activated.v1
justice.sentence.obligation_issued.v1
justice.sentence.suspended.v1        justice.sentence.completed.v1
justice.sentence.defaulted.v1        justice.evidence.linked.v1
justice.evidence.removed.v1          justice.evidence.missing.v1
justice.record.sealed.v1             justice.record.unsealed.v1
justice.record.expunged.v1
```

Payloads are `{ eventId, kind, recordId, revision, status, caseId,
jurisdictionId, subjectCharacterId }`: identifiers and state, never narrative.
Delivery is at least once and ordered per record; deduplicate by `eventId`.

## Configuration and access

| Setting | Purpose |
|---|---|
| `TrustedResources` | Resources that may call Justice |
| `DefinitionResources` | Trusted resources that may register and revise jurisdictions and statutes |
| `SystemActions` | Actions a trusted resource may call without a player (default: `justice.custody.view`, `justice.sentence.view`, `justice.sentence.complete`) |
| `JurisdictionTypes`, `MaximumJurisdictionDepth`, `CaseTypes` | Allowed types and hierarchy depth |
| `Citations` | Currency, maximum amount and due time, obligation type of payable citations |
| `Sentences` | Maximum term, amount and service units; currency and obligation types of fines and restitution; worker timing |
| `Custody.Exceptions` | Lawful arrests without a warrant (none by default) |
| `Rulings` | Judge participant required, findings limit |
| `Evidence` | Inventory destroy guard for linked items |
| `Retention` | Delivered outbox age; optional narrative redaction of closed cases |
| `WarrantExpirySweepSeconds`, `Logging`, `AccessAudit`, `MetricsReaders` | Operations |

A resource that uses Justice is listed in `config.lua`. The shipped
configuration trusts `bcc-law`; add another law resource the same way:

```lua
TrustedResources = { ['bcc-law'] = true },
DefinitionResources = { ['bcc-law'] = true }, -- only if it registers jurisdictions and statutes
```

Trust alone does not allow changes. Player actions (`justice.case.open`,
`justice.warrant.issue`, … listed in [CONTRACT.md](CONTRACT.md)) are decided by
Core's policy provider for the acting player. Calls without a player need
grants in feather-admin's `configs/service_policy.lua`:

```lua
Config.servicePolicy['feather-justice'] = {
    ['bcc-law'] = {
        ['justice.definition.view'] = true,   -- read jurisdictions and statutes
        ['justice.definition.manage'] = true, -- register them
        ['justice.custody.view'] = true,      -- custody status by character (jail placement)
        ['justice.sentence.view'] = true,     -- a defendant's active sentences
        ['justice.sentence.complete'] = true  -- report finished community service
    }
}
```

Restart feather-justice and feather-admin after changing them.

## Database

Only Justice writes `justice_jurisdictions`, `justice_statutes`,
`justice_cases`, `justice_case_parties`, `justice_charges`, `justice_warrants`,
`justice_citations`, `justice_custody_records`, `justice_rulings`,
`justice_sentences`, `justice_evidence_links`, `justice_receipts`,
`justice_audit_events`, `justice_outbox`, `justice_access_audit`,
`justice_workflows` and `justice_schema_migrations`; all its SQL is in
`server/repository.lua`. Other resources must use the exports and never query
these tables. Applied migrations are checksummed and must not be edited; a
mismatch fails readiness. Backup, restore and retention: [OPERATIONS.md](OPERATIONS.md).

## Not in this release

- Restrictions (protective orders and similar), which the master plan adds after
  the initial release.
- Importing records from other law systems.
- Carrying out license suspensions and forfeitures: Justice records the
  sentence; the owning domain (Licenses, Property, Assets) executes it and the
  completion carries its `effectReference`.
