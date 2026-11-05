# Feather Jobs

Alpha release 0.2.1 (2026-10-20): Config.DevMode stays true for this early-alpha
release at owner direction. Native organization fixtures are supplied by the sibling
feather-jobs-tests resource. Run NativeDomainFixtureTest <stableRun> [characterUUID|serverID]
from the console: 13/13 with a character, 10/10 without. It prints the exact
read-only JobsNativeIntegrationSmokeTest commands (7/7 each). Retain the same run
ID and character for replay after restart. Production-default guidance and prior
Society acceptance below describe their separate release/historical configurations.
No production-default toggle is required during this development increment.

Authoritative job domain for the Feather Framework: job definitions, grades,
character assignments, the optional active assignment, and per-assignment duty
state. Independent of societies, ranks, wages, payroll, uniforms, locations,
licenses, and general permissions; those remain with gameplay resources and
other domains. Native Feather; no legacy compatibility layer.

Version 0.2.1. [Contract 1](CONTRACT.md) is proposed for freezing; `CONTRACT.md`
is the reference to code against, this README explains the model and setup.

Implements phases J0–J3 of the Jobs master plan (`feather-framework-docs`,
`feather-jobs/Feather_Jobs_Master_Plan.md`) on the Contract 1 service kernel. J4
(Society adapter) is delivered by `bcc-society` 2.0.0. The current J5 consumers
(bcc-doorlocks, bcc-craft, bcc-stables, bcc-banks and bcc-housing) use
`CheckAssignment` in their Feather ports. Code integration and live acceptance
are tracked separately below. J6 has no legacy job fields left on the Feather
side.

This alpha ships `Config.DevMode=true` with service-policy authorization enabled.
Development commands and exact development fixture trust are enabled. The
permanent server-console `JobsReleaseContractSmokeTest` is
read-only and checks readiness, policy mode, development-command and fixture
exclusion, publisher state, migrations, the client route, assignment integrity
(open slots match open assignments; every active selection points at an open
assignment of the same character), and capabilities.
Its production-exclusion checks intentionally fail under this alpha configuration;
keep DevMode true for the current alpha PR/release. Historical production-posture
results below were obtained with a different configuration.

Production-surface acceptance passed 10/10 on 2026-10-02: Jobs ready, DevMode
disabled, development commands absent, fixture trust absent, authorization
enabled, publisher running, migration ledger intact, client route owned,
untrusted reader denied, and capabilities advertised. bcc-society started on
this configuration with its job types, organization link and owner assignment.

Development acceptance passed on 2026-10-02:

- `JobsLifecycleSmokeTest` passed 20/20 (registration, idempotent replay and
  conflict, untrusted denial, grade ordinals, open-slot uniqueness, stale
  revision, grade change, duty, foreign mutation denial, terminal end,
  operation lookup, audit history).
- `JobsConsumerLiveTest` (from `[test]/feather-jobs-tests`) passed 14/14 from a
  second resource: caller ownership, consumer grants, foreign-job denial, and
  event delivery.
- `SocietyLiveTest` (bcc-society) passed 9/9 against Jobs as the reference
  consumer.

Live acceptance with bcc-society 2.0.0 passed on 2026-10-11, two players:

- `SocietyLiveTest` passed 12/12 (hire, promote, fire across two characters).
- Offline changes: hire, promote (`nurse` 0 to `doctor` 10 on the same
  assignment, revision 3 to 4) and fire of a character who was not connected.
- Restart recovery: a restart right after a queued hire left no open workflow.
- Duty: on/off and disconnect changed only the duty state, never the job or grade.
- Two employers: one character held jobs at two societies; the active job
  switched and ending one assignment left the other open.
- Second consumer: the bcc-doorlocks job door check (`CheckAssignment` with
  `dutyState = 'on_duty'`) passed on 2026-10-17 (see below).

Acceptance of 0.2.0 on 2026-10-17, nobody connected (character UUIDs):

- `JobsReleaseContractSmokeTest` passed 11/11, including assignment integrity.
- `JobsLifecycleSmokeTest` passed 26/26, including two employers for one job,
  the on-duty filter, active job switching, ending one assignment while the
  other stays, and the stored reference.
- bcc-doorlocks as second consumer: for a bcc-society `doctor` off duty,
  `DoorlocksJobCheck` reported the job held and the door closed; after
  `SocietyDevDuty <character> on 3` the door opened; after `off 3` it was
  closed again.

## Native organization wiring check

`JobsNativeIntegrationSmokeTest <organizationUUID> <active|inactive|missing>`
is console-only and read-only, available with either DevMode setting. Use an
existing organization UUID with its expected eligibility, or a known absent UUID
with `missing`. Expect 7/7: readiness, enabled policy, native definition/assignment
policy grants, foreign-principal denial and real organization employer validation.
It does not create assignments or alter organizations/providers. Organizations
must trust Jobs as a reader; Admin must load the exact native Jobs service grants.
Restart those resources after their config changes, then restart Jobs. No manifest
change or refresh is required for this increment. Historical Society acceptance
above does not establish this native integration's live acceptance.

## Dependencies

```text
feather-mysql
feather-core
```

At runtime, assignment creation also needs the `character-profile` provider
(feather-character). Organization employers are validated through
feather-organizations when that employer type is used. Service policy is decided
by the default Core policy provider (feather-admin).

## Startup order

Start Jobs after Core, Character, Organizations and Authority, and before Admin
and job consumers:

```text
ensure feather-mysql
ensure feather-core
ensure feather-character
ensure feather-organizations
ensure feather-authority
ensure feather-jobs
ensure feather-admin
```

The first start applies four checksummed migrations and logs
`event=startup.ready migrationsApplied=4 routes=1`. Later starts apply none (an
upgrade from 0.1.0 applies one: `004_job_event_references`).

## Installation and first acceptance

Place in `resources/[feather]/feather-jobs`, add it to `server.cfg` in the order
above, and run in the server console:

```text
refresh
ensure feather-jobs
JobsReleaseContractSmokeTest
```

Expect 11/11 only with the historical production configuration. The current alpha
keeps DevMode true; use the native fixture checks above for this release.

The mutating acceptance tests need `Config.DevMode=true` on an isolated
development server. Enable it, restart feather-jobs, and run it for a character
(a UUID works offline) whose active job, if any, is not owned by another
resource; a character without a job is simplest:

```text
JobsLifecycleSmokeTest <serverId|characterUuid>
```

Expect 26/26. The test mutates data: it registers a uniquely keyed `smoke_*`
job, assigns it, adds the same job for a second employer (a separate
assignment), checks that an on-duty filter skips the off-duty one, switches the
active job, ends one assignment while the other stays, records a reference,
walks grade and duty changes, ends the assignments, and retires the job. It
runs as feather-jobs, so it needs both Jobs policy actions granted to
`feather-jobs` while it runs.

The optional `feather-jobs-tests` fixture is not included in this repository
or the current development-server resources. The recorded 14/14 result above
is historical acceptance evidence. To rerun it, first obtain the fixture used
for that acceptance run.

With the fixture installed on an isolated development server, add its policy grant
(`Config.servicePolicy['feather-jobs']['feather-jobs-tests']` with
`jobs.definition.manage` and `jobs.assignment.manage`) to feather-admin, restart
feather-admin, then:

```text
ensure feather-jobs-tests
JobsConsumerLiveTest <serverId>
```

Expect 14/14 for that fixture version. Remove its policy grant, stop the fixture,
restart feather-jobs and feather-admin afterwards if policy config changed.
Keep DevMode true for the current alpha release.

If the first mutation returns `authorization_denied`, restart feather-admin so it
loads the `['feather-jobs']` service-policy grants.

## Production posture

The following describes a future production posture, not this alpha's shipped
DevMode=true configuration. No toggle is required for the alpha release:

```text
JobsReleaseContractSmokeTest
```

Expect 11/11: the development lifecycle command is not registered and the
`feather-jobs-tests` fixture receives no trust. Each resource that registers
definitions or changes assignments needs its own entry in
`Config.servicePolicy['feather-jobs']` in feather-admin. The development server
already grants `bcc-society` both `jobs.definition.manage` and
`jobs.assignment.manage`. Verify these grants in the Admin configuration you
deploy; Jobs does not install them. Resources that only read need
`trustedReaders` and no mutation grant.

## Ownership and decisions

Jobs owns job definitions and stable keys, grade definitions and ordering,
character assignments with their lifecycle and provenance, explicit duty state,
the optional active assignment, and the audit facts for all of them.

It does not own society or business definitions, society ranks or manager
permissions, job locations, NPCs, prompts, uniforms, crafting, missions, wage
rules, payroll, licenses, or general authorization roles.

The J0 decisions follow the master plan's recommendations and are configurable:

- **Multiple assignments:** up to `Config.Assignments.maxOpenPerCharacter` (8)
  open assignments per character.
- **Active assignment:** optional (`Config.ActiveAssignment.enabled`). A
  character's first open assignment becomes active automatically.
- **Duty:** a per-assignment enum: `off_duty`, `on_duty`, `suspended`. Never an
  `off` prefix on a job name.
- **Definition governance:** definitions are persisted in Jobs and owned by the
  registering resource. A resource may only assign jobs it owns unless
  `Config.Assignments.allowForeignJobs` is enabled or it is privileged.
- **Society ranks:** an explicit rank → grade mapping, owned by the consumer.
  Jobs never infers it.
- **Offline changes:** allowed. The character UUID resolves through the Character
  provider.

An open assignment is unique per character + job + employer, so two employers
can assign the same job to the same character without overwriting each other.

## Server exports

All exports return the Contract 1 envelope `{ ok = true, value = ... }` or the
flat `{ ok = false, code, message, details }`. The caller is the actual Cfx
invoking resource and must be listed in the matching `Config.Access` group. No
client may supply a trusted resource, account, or character identity.

`GetCapabilities()`, `GetHealth()`, and `AwaitReady(timeoutMs)` (default 30000,
integer 0–60000) report lifecycle.

Every mutation takes a stable `requestId` (at most 128 characters) and a
namespaced `reasonCode` such as `society.hire`. It also accepts an optional
`actorSource` (the player who triggered it; Jobs derives that player's account
and character from Core), an optional `correlationId`, and an optional
`referenceType` + `referenceId` (the caller's record behind the change, for
example `society_membership` and its ID), stored on the audit event and
published with it. Retrying a request ID
with the same payload replays the stored result with `replayed = true`; reusing it
with a different payload returns `idempotency_conflict`.

- `RegisterJobDefinition` — `jobKey`, `label`, optional `metadataVersion`. The caller becomes the owner.
- `UpdateJobDefinition` — `jobId`, `expectedRevision`, and any of `label`, `status`, `metadataVersion`.
- `DefineGrade` — `jobId`, `gradeKey`, `label`, `ordinal` (0–1000, unique per job), optional `status`. Pass `expectedRevision` to update an existing grade.
- `CreateAssignment` — `characterId`, `jobId` or `jobKey`, `gradeId` or `gradeKey`, `provenanceType`, `provenanceId`, optional `employerType` + `employerId`, optional `dutyState`.
- `ChangeAssignmentGrade` — `assignmentId`, `expectedRevision`, `gradeId` or `gradeKey` (same job).
- `SetDutyState` — `assignmentId`, `expectedRevision`, `dutyState`. Never changes job or grade.
- `SetActiveAssignment` — `characterId`, `assignmentId` (or `false` to clear), `expectedRevision` of the character state (`0` initially).
- `EndAssignment` — `assignmentId`, `expectedRevision`. Terminal; resets duty and clears the active selection when it pointed here.

Reads:

- `GetJobDefinition({ jobId })` or `({ jobKey })` — the definition with grades by ordinal.
- `ListJobDefinitions({ ownerResource?, status?, limit?, cursor? })` — bounded pages.
- `GetAssignment({ assignmentId })`
- `ListCharacterAssignments({ characterId, includeEnded?, limit?, cursor? })` — newest first.
- `GetEffectiveJobSnapshot({ characterId })` — active assignment, open assignments, state revision.
- `CheckAssignment({ characterId, jobKey, gradeKey?, minGradeOrdinal?, employerType?, employerId?, dutyState?, activeOnly? })` — returns `{ matched, assignment? }`.
- `FindOperation({ requestId })` — the caller's stored result, for timeout recovery.
- `InspectJobHistory({ aggregateType, aggregateId, limit?, cursor? })` — audit trail; owners read their own aggregates, privileged auditors read all.

`CheckAssignment` returns facts only. The consuming resource still decides
whether those facts permit an action.

Common failure codes: `authorization_denied`, `policy_unavailable` (Jobs fails
closed), `revision_conflict` (`details.revision` holds the current value),
`idempotency_conflict`, `assignment_exists` (`details.assignmentId`),
`job_key_conflict`, `no_change`, and `transaction_failed` (retry with the same
request ID, or call `FindOperation` first).

## Contract

```lua
local Jobs = exports['feather-jobs']

-- On start: register owned definitions with stable request IDs (replays on restart).
local job = Jobs:RegisterJobDefinition({
    requestId = 'definition:blacksmith', jobKey = 'blacksmith',
    label = 'Blacksmith', reasonCode = 'society.setup'
})
Jobs:DefineGrade({
    requestId = 'grade:blacksmith:apprentice', jobId = job.value.jobId,
    gradeKey = 'apprentice', label = 'Apprentice', ordinal = 0,
    reasonCode = 'society.setup'
})

-- Hire: the consumer has validated its own rule and stored a pending membership.
local result = Jobs:CreateAssignment({
    requestId = ('hire:%s'):format(membershipId),
    characterId = targetCharacterId,
    jobKey = 'blacksmith', gradeKey = 'apprentice',
    employerType = 'organization', employerId = organizationId,
    provenanceType = 'society_membership', provenanceId = membershipId,
    reasonCode = 'society.hire', actorSource = source
})

-- Elsewhere: facts for a door, crafting bench or billing rule.
local check = Jobs:CheckAssignment({
    characterId = characterId, jobKey = 'blacksmith',
    minGradeOrdinal = 10, dutyState = 'on_duty'
})
```

## Client route

`jobs.snapshot.get.v1` takes an empty payload and returns the calling player's
own open assignments, without owner or provenance internals. It requires an
active character and is rate limited. Clients cannot mutate anything.

## Event publication

Committed facts are written to the `feather_job_events` audit table and the
`feather_job_outbox` in the same transaction as the change, then published
through Core:

```text
jobs.definition.registered.v1
jobs.definition.updated.v1
jobs.grade.defined.v1
jobs.assignment.created.v1
jobs.assignment.grade_changed.v1
jobs.assignment.duty_changed.v1
jobs.assignment.activated.v1
jobs.assignment.ended.v1
```

`jobs.definition.updated.v1` and `jobs.grade.defined.v1` extend the master plan's
list so definition and grade changes carry the same audit trail as assignments.
Payloads are bounded to 4096 bytes.

## Configuration and access

`Config.Access` holds the trusted resource groups: `trustedReaders`,
`trustedRegistrars` (with `privilegedRegistrars`), `trustedAssigners` (with
`privilegedAssigners`), and `trustedAuditors` (with `privilegedAuditors`). A
privileged entry must also be in its trusted group. Each consumer that mutates
Jobs additionally needs `jobs.definition.manage` and/or `jobs.assignment.manage` in
`Config.servicePolicy['feather-jobs'][<resource>]` of feather-admin; restart
feather-admin after changing it.

`Config.EmployerTypes` lists the accepted employer types: `organization`
(validated through feather-organizations, which must list `feather-jobs` in its
`trustedReaders`) and `society` (trusted to the owning resource).

Current consumers:

| Resource | Access | Uses |
|---|---|---|
| `bcc-society` | readers, registrars, assigners, auditors + service grant | Reference consumer: job types, hire/promote/fire, duty, active job |
| `bcc-doorlocks` | `trustedReaders` | Job doors (`CheckAssignment`) |
| `bcc-craft` | `trustedReaders` | Job-restricted crafting (`CheckAssignment`) |
| `bcc-stables` | `trustedReaders` | Trainer-only taming and training (`Config.trainerJob`) |
| `bcc-banks` | `trustedReaders` | Bank administration by job (`Config.Admin.jobs`, default `banker`) |
| `bcc-housing` | `trustedReaders` | Realtor staff and agent shops by job (`Config.Admin.jobs`, agent `jobs`) |

The development fixture `feather-jobs-tests` is trusted only while DevMode is on.

### Adding a consumer

Keep the entries already in each list and add the new resource. Then restart, in
this order: `feather-organizations` (if changed), `feather-jobs`, `feather-admin`
(if changed), and the consumer last.

**A resource that only checks jobs** (doors, crafting, shops) needs one entry, in
`feather-jobs/config.lua`:

```lua
Access = {
    trustedReaders = { ['feather-jobs'] = true, ['feather-admin'] = true,
        ['bcc-society'] = true, ['my-doors'] = true },
    -- other groups unchanged
}
```

It then calls `CheckAssignment` and needs no service grant. Without the entry
every check returns `authorization_denied`.

**A resource that defines jobs or hires, promotes and fires** (a society or job
center) needs four groups in `feather-jobs/config.lua`:

```lua
Access = {
    trustedReaders    = { --[[ ... ]] ['my-society'] = true },
    trustedRegistrars = { --[[ ... ]] ['my-society'] = true }, -- RegisterJobDefinition, DefineGrade
    trustedAssigners  = { --[[ ... ]] ['my-society'] = true }, -- CreateAssignment, ChangeAssignmentGrade,
                                                               -- SetDutyState, SetActiveAssignment, EndAssignment
    trustedAuditors   = { --[[ ... ]] ['my-society'] = true }, -- InspectJobHistory on its own records
    -- privileged* groups: leave them to feather-admin
}
```

and a service grant in `feather-admin/configs/service_policy.lua`. The outer key
is the domain asking (`feather-jobs`), the inner key the calling resource:

```lua
Config.servicePolicy = {
    -- existing domains unchanged
    ['feather-jobs'] = {
        ['my-society'] = {
            ['jobs.definition.manage'] = true, -- register job types and grades
            ['jobs.assignment.manage'] = true  -- hire, promote, duty, fire
        }
    }
}
```

A missing trust entry fails with `authorization_denied` ("not trusted"); a missing
grant fails with `authorization_denied` from the policy, or `policy_unavailable`
when feather-admin is not started.

**Organization employers.** Assignments with `employerType = 'organization'` are
validated through feather-organizations, which must trust Jobs as a reader in
`feather-organizations/config.lua`:

```lua
Access = {
    trustedReaders = { --[[ ... ]] ['feather-jobs'] = true },
}
```

**Consumer configuration examples.** Job rules live in the consumer, as job keys
and grade ordinals that Jobs knows:

```lua
-- bcc-doorlocks config.lua: doors store job keys; opening asks CheckAssignment.
Config.JobAccess = { requireOnDuty = true }   -- dutyState = 'on_duty'

-- bcc-craft configs/*.lua: one recipe limited to chefs of grade 10 or higher.
requiredJobs = { { 'chef', 10 } },            -- { jobKey, minimum grade ordinal }

-- bcc-stables config/main.lua: trainers only.
Config.trainerJob = { { name = 'trainer', grade = 0 } }
```

The job keys must exist in Jobs: they are registered by the resource that owns
them (bcc-society registers its `Config.Jobs` types on start).

## Database access

Only Jobs writes `feather_job_definitions`, `feather_job_grades`,
`feather_job_assignments`, `feather_job_character_state`, `feather_job_receipts`,
`feather_job_events`, `feather_job_outbox`, and `feather_job_schema_migrations`.
Consumers must use the exports above and never query these tables. Applied
migrations are checksummed and must not be modified; a mismatch fails readiness.

Mutations keep round trips low because every database statement costs about
one server tick. A freshly reserved receipt is not read back; event IDs (and the
assignment ID and timestamp) come from one query; events and outbox rows are
written with one multi-row insert each. `CreateAssignment` takes 9 queries (10
when it also selects the active assignment), down from 19.

## Remaining work

- **J5 live validation:** the current consumers listed above are integrated
  through `CheckAssignment`, including housing realtor and agent-shop checks.
  The bcc-doorlocks on-duty door check passed offline on 2026-10-17
  (`DoorlocksJobCheck <characterUuid> <jobKey>` before and after
  `SocietyDevDuty <characterUuid> on <society id>`). Validate the other
  consumers' job and grade rules in game before declaring their gameplay
  acceptance complete.
- **J6 legacy removal:** feather-character has no job fields or job mutators.
  The listed Feather consumer ports use Jobs rather than legacy character fields.
- **Optional acceptance fixture:** restore `feather-jobs-tests` separately if
  the historical second-resource acceptance needs to be rerun.
