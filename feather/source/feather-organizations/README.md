# Feather Organizations

Alpha release 0.2.1 (2026-10-20): native Jobs and Access reader integration,
development fixtures and real employment/grant lifecycle acceptance. Config.DevMode
stays true at owner direction for early alpha/pre-alpha releases. No schema change.

Authoritative organization identity domain, independent of Society, Jobs, money,
permissions, or shop presentation. Native Feather; no legacy compatibility layer.

This alpha ships `Config.DevMode=true` with service-policy authorization enabled.
Development commands and exact fixture trust are enabled. The permanent
server-console `OrganizationsReleaseContractSmokeTest`
is read-only and checks readiness, policy mode, fixture exclusion, publisher state,
capabilities, and the canonical Valentine business. Its production-exclusion
checks intentionally fail in this alpha posture. Keep DevMode true for the
current alpha PR/release; historical production acceptance used another config.

## First slice

Contract 1 flat results, bounded readiness, defensive trusted type reads, and
checksummed resource-owned migrations. Initial types: business, government,
government_agency. Persisted UUIDs survive restart; display labels do not define
authority. Durable organization creation/read and lifecycle transitions are now
implemented, together with single-parent hierarchy. Interests, membership, client RPC, and gameplay UI remain
unavailable and are reported as zero.

Only Organizations writes `feather_organization_types` and
`feather_organization_schema_migrations`. Configured labels sync on startup
and advance revision only if changed. Removing a type from Config does not
delete/retire it or free its stable key; retirement is a future explicit operation.
The type catalog is bounded to 32; no unbounded organization dump is exposed.

## Durable identity slice

`CreateOrganization(request)` accepts exactly `requestId`, `organizationType`,
`organizationKey`, `legalName`, `displayName`, and `reasonCode`. IDs are bounded
to 128 characters, start alphanumeric, and use letters/numbers/dots/underscores/
colons/hyphens. Keys are lowercase, start with a letter, and use letters/numbers/
underscores (64 characters maximum). Names are bounded nonblank text without
control characters (legal 160 bytes, display 100 bytes). Reason is a bounded
64-character lowercase token. No client identity or initial status is accepted.

Creation requires actual invoking-resource membership in `trustedCreators` and
`trustedReaders`. Optional Core action `organizations.organization.create` is
controlled by `Config.Authorization.enabled` (currently false for development).
This slice uses resource/service principals, not client-provided actor identity.
Policy deny/unavailable cannot bypass trust or domain validation.

New records start `pending`, revision 1. Caller/request receipts bind all material
fields using length-prefixed fingerprints. Exact retry returns the original
creation snapshot/UUID with `replayed=true`; it is not a current-state query.
Changed payload returns `idempotency_conflict`. Global organization keys cannot
be reused under another request, even by the same resource. Entity, receipt, and
append-only creation audit commit together; rejected duplicate attempts roll back
their receipt. No resource-local identity or display-name fallback exists.

Trusted `GetOrganization({ organizationId })` and
`FindOrganizationByKey({ organizationKey })` return current defensive snapshots.
Creation owns `feather_organizations`, `feather_organization_creation_receipts`,
and `feather_organization_events`. Audit records are durable database facts;
broker publication, outbox delivery and audit query APIs are documented below.
Bounded listing, name edits, and single-parent hierarchy are documented below.

First run `OrganizationsCreationContractSmokeTest` (12/12, no entities created).
Then use `OrganizationsCreationLiveTest org-creation-001` with DevMode enabled.
It creates one real pending entity using fixed key `org_creation_test`, verifies
same-ID replay, payload conflict, global key conflict, and one entity/audit row.
Restart and repeat the exact original request ID; never use a fresh key/ID to
recover this test. Keep authorization enabled; DevMode remains true for alpha.

## Revision-checked lifecycle

`ChangeOrganizationStatus(request)` accepts exactly `organizationId`,
`expectedRevision`, `status`, `requestId`, and `reasonCode`. Revision is a numeric
integer, not a string. UUIDs normalize to lowercase. Stable request IDs/reasons
follow creation's limits. Use distinct IDs for creation and each intended change;
the audit namespace reserves each caller/request ID across organization operations.

Mandatory trust: `trustedMutators` plus trusted read access. Ordinary mutators
can change only organizations created by that resource. `privilegedMutators`
explicitly permits cross-resource administration (Admin is configured). Optional
Core update/suspend/dissolve actions apply when Authorization is enabled.
This is resource-level control, not player ownership, membership, or job authority.

Allowed transitions:

- pending → active or dissolving
- active → suspended or dissolving
- suspended → active or dissolving
- dissolving → dissolved
- dissolved → none

Skipping dissolution, same-status changes, and terminal reactivation are rejected.
Lock the entity and compare expected revision inside the transaction. A successful
change increments revision once and atomically writes its payload-bound lifecycle
receipt and append-only audit event. Stale/invalid changes roll back the receipt.
Exact replay returns the original resulting revision/status, even if later changes
occurred; current reads remain the current-state authority. Altered retry payloads
fail. Retain the original request after timeout rather than issue a new one.

Dissolution does not delete the entity/free its key or touch accounts, employment,
property, licenses, or other domains. A trusted coordinating workflow must finish
any required downstream cleanup before explicitly completing dissolution; this
slice does not verify those external obligations or provide a worker for them.

Run `OrganizationsLifecycleContractSmokeTest`: expect 15/15, no state changes.
Dev-only `OrganizationsLifecycleLiveTest org-lifecycle-001` creates a separate
fixed-key test entity, activates/suspends/resumes it, stages/completes dissolution,
and verifies exact replay, changed-payload rejection, stale revision rejection,
terminal protection, six audit events, and rejected-receipt rollback. It never
touches the original creation-test entity, money, or items. Restart then repeat
the exact ID; expect dissolved revision 6 with allReplayed=true and still six
events. After these manifest additions run refresh before restarting the resource.

## Contention and real export-boundary acceptance

`OrganizationsConcurrencyTest org-concurrency-001` is dev-only. It creates one
separate entity at fixed key `org_concurrency_test`, then concurrently submits
activation and begin-dissolution against revision 1 using distinct request IDs.
Either contender may win: expect exactly one success, one `revision_conflict`,
revision 2, two audit events (creation + winner), one lifecycle receipt, and
successful exact winner replay. Loser receipt reservation must roll back.
The test uses an explicit completion counter and a 30-second watchdog; timeout
does not cancel database work. Retain IDs and inspect state rather than create
another attempt under new IDs. Repeating the original command checks stored
winner replay; it is not another fresh contention measurement.

Optional `feather-organizations-tests` exercises real Cfx calls from a different
resource. With DevMode true, it receives reader/creator/mutator trust but never
privileged override. `OrganizationsOwnershipBoundaryTest org-ownership-001`
rejects foreign mutation and caller injection, preserves the creation-test
organization, and allows/replays a separate fixture-owned entity's activation.
See its README for deployment. It is not shipped in default startup/recipe.
Stop/remove the fixture and disable DevMode before production. These acceptance
tests passed in development, including export-boundary replay across restart.
They do not certify Core policy/provider failure behavior.

## Directory and identity edits

Trusted `ListOrganizations({ limit?, cursor?, status?, organizationType? })` returns
`{ items, nextCursor? }`. Limit defaults to 20 and accepts numeric integers 1–50.
Rows sort by immutable organization key using database binary collation. Cursor
is the last returned key, exclusive; keep filters unchanged on subsequent pages.
No totals, offset dump, or unbounded list is exposed. Pagination is a live view,
not a frozen snapshot: concurrent inserts/edits may affect later pages.

`UpdateOrganizationIdentity({ organizationId, expectedRevision, requestId,
reasonCode, legalName, displayName })` requires both names and the same mandatory
mutator/owner-or-privileged gates as lifecycle changes. Optional Core update
authorization applies when enabled. UUID, key, type, and status cannot be edited.
Names follow creation's byte limits and nonblank/control-character validation.
Pending/active/suspended identities can be renamed; dissolving/dissolved records
cannot receive fresh edits. Unchanged names return `no_change` without revision
or audit changes. Stale expected revisions return `revision_conflict`.

Identity changes, payload-bound receipts, and audit records commit together.
Length-prefixed fingerprints bind all material fields. Exact retry returns its
original name/revision snapshot, even after later edits; use GetOrganization for
current state. Request IDs must be distinct across organization operations. A
failed attempt rolls back receipt reservation. Migration 004 adds the identity
receipt table without changing applied foundation/creation/lifecycle migrations.

Recorded development acceptance commands (all passed, including exact restart
replay and the identity export-boundary fixture):

- `OrganizationsDirectoryContractSmokeTest`: 13/13 read-only checks.
- `OrganizationsIdentityContractSmokeTest`: 12/12, no edits.
- `OrganizationsIdentityLiveTest org-identity-001`: a separate fixed-key entity
  renamed/restored to revision 3, replay/mismatch/stale/no-change checks, blocked
  edits to the dissolved lifecycle-test entity, and three audit events.
- Repeat the live test with the same ID after restart, never a new request.
- Optional fixture `OrganizationsIdentityBoundaryTest org-identity-boundary-001`
  verifies real exported bounded reads, foreign rename denial, and fixture-owned
  edit/replay (requires earlier ownership fixture acceptance).

After manifest additions run refresh then restart Organizations; start the
optional fixture again only when testing its cross-resource calls. No gameplay
UI or recipe entry is added by this slice.

### Shared identity/lifecycle revision contention

Dev-only `OrganizationsIdentityLifecycleConcurrencyTest org-identity-race-001`
creates one separate fixed-key entity and races a rename against begin-dissolution
at revision 1. Either operation may win. Expect one success, one revision conflict,
revision 2, two audit events including creation, exactly one receipt across both
mutation tables, consistent winner-only names/status, and exact winner replay.
No previous acceptance entity, money, or item changes. This entity stays pending
and renamed, or dissolving with original names, depending on the winner.

The completion counter has a 30-second watchdog; timeout does not cancel DB work.
Keep original IDs for inspection/retry. Restart replay validates persisted winner
state, not a second fresh race. This cross-operation test and restart replay passed
with lifecycle winning and the edit rejected as stale. Policy-provider failures
and broad pagination contention remain gates.

## Single-parent hierarchy

`SetParentOrganization({ organizationId, parentOrganizationId, expectedRevision,
requestId, reasonCode })` and `RemoveParentOrganization({ organizationId,
expectedRevision, requestId, reasonCode })` use the same mandatory mutator/reader
trust as edits. Ordinary callers must own the child and proposed parent; explicit
privileged mutators may cross owner boundaries. Optional Core action is
`organizations.relationship.manage`. This is structural control, not player
membership or an implicit permission to use the parent's accounts/facilities.

Each child has at most one parent. Reject self-parent, cycles, unchanged links,
stale child revision, and fresh changes involving dissolving/dissolved child or
proposed parent. Existing links are preserved if lifecycle later changes; status
does not cascade to children. Removal changes only the link, not identity.
Only the child revision advances; parent revision/status is untouched.

All graph writers first lock a persisted guard row, then validate within their
transaction. Parent changes, child revision, durable receipt, and audit event
commit together. The graph is bounded to 4096 links and 32 ancestry links;
validation includes descendants so moving a subtree cannot exceed the depth cap.
These are deliberately small-foundation limits, not unbounded graph support.
Snapshot reads include `parentOrganizationId` when linked. Exact change replay
returns the original receipt and does not undo a later removal/reparent.

Trusted `ListOrganizationChildren({ organizationId, limit?, cursor? })` uses the
same 1–50 stable-key pagination as the directory and requires an existing parent.
`ListOrganizations` also accepts `parentOrganizationId` as a filter. Neither
query recursively dumps the tree or inherits authorization from a relationship.
Migration 005 adds parent links, serialization guard, and hierarchy receipts;
applied migrations remain unchanged. No typed relationships are implemented.

Recorded hierarchy acceptance:

- `OrganizationsHierarchyContractSmokeTest`: expect 13/13, no link changes.
- `OrganizationsHierarchyLiveTest org-hierarchy-001`: creates three separate
  pending entities, links a chain, rejects cycle/stale/mismatched requests,
  removes one link, and replays the old set without restoring it. Six audit
  events and rejected-receipt rollback are required; restart uses the same ID.
- Optional fixture `OrganizationsHierarchyBoundaryTest org-hierarchy-boundary-001`
  denies foreign child/parent linkage and permits owned set/replay/children reads.
  It requires prior ownership/identity fixture acceptance and adds one parent
  entity; no money, employment, or item data changes.

Contract passed 13/13. Live hierarchy and exact restart replay passed with six
events, cycle/stale/mismatch rejection, and the removed link staying absent.
Actual export-boundary tests and restart passed for foreign child/parent denial,
owned linking/replay, bounded children, and unchanged foreign target.

Dev-only `OrganizationsHierarchyConcurrencyTest org-hierarchy-race-001` is the
remaining pending gate. It creates two separate entities and concurrently submits
A → B and B → A. Either contender may win; require one commit, one hierarchy-cycle
rejection, one link/receipt, three events including both creations, unchanged
parent revision, and exact winner replay. A bounded 30-second watchdog does not
cancel DB work. Retain original IDs on timeout or restart; repeating the test
replays the persisted winner rather than running another fresh race. No money,
items, or earlier acceptance entities change.
Run refresh after manifest additions, then restart Organizations. Stop the
optional fixture after testing and disable DevMode before production.

## Installation and first acceptance

Place in `resources/[feather]/feather-organizations`. Start feather-mysql and feather-core first.
No Economy or Character dependency; do not change their activation for this slice.
Run in the server console:

```text
refresh
ensure feather-organizations
OrganizationsFoundationSmokeTest
```

Expect 13/13 read-only passes. Then restart the resource and rerun to validate
startup/migration replay. Checksummed applied migrations must not be modified.
Database failures/checksum mismatches fail readiness; inspect server startup logs.
This resource is not automatically added to the recipe yet.

## Server exports

`GetCapabilities()`, `GetHealth()`, `AwaitReady(timeoutMs)` (default 30000,
integer 0–60000) return `{ ok = true, value = ... }` or flat
`{ ok = false, code, message, details }`.
`GetOrganizationType(key)` and `ListOrganizationTypes()` require the actual Cfx
invoking resource in `Config.Access.trustedReaders`. They return copies and are
readiness-gated. No client may supply a trusted resource identity.

Types are initial classifications, not capabilities or active organization
entities. Runtime type registration/providers remain future work.
Restarting Core can stop this consumer; start it again after Core
is ready. Cross-resource methods must be checked with IsCallable rather than
Lua function-only checks when provider tables are introduced.

## Audit history and publication

## Controlling-interest preparation

Authorization is now enabled by default. Admin's server-only service policy
explicitly grants Organizations-broker calls on behalf of Organizations or Admin
the six configured organization actions. The actual Core caller must match the
configured broker; subject.resource alone cannot grant authority. Player calls
remain on Admin's existing role path. Fixture/service consumers need their own
explicit policy grants as well as Organizations trust/ownership. No fixture policy
grant is installed by default. Missing Admin/provider fails closed for mutations;
readiness does not itself guarantee policy availability. Start Admin before making
organization changes, and do not use the authorization-disabled policy harness
under this default production configuration.

`OrganizationsServicePolicyLiveTest <stable requestId> <character UUID>` verifies
real creation and character-owner grant/revoke through Admin's installed service
policy with authorization enabled. No provider/configuration changes occur.
Expect revision 3, one revoked interest, three audit/outbox records and two
interest receipts. Repeat the exact IDs after restart for original receipt replay.
Live and restart acceptance passed with authorization enabled and the installed
Admin provider unchanged. The optional fixture's unauthorized-principal test also
passed before/after restart, denying owned mutations/creation/retries/spoofing.

`ListOrganizationInterestTypes()` provides an isolated trusted-reader catalog:
character founders, character/organization owners, and organization controllers.
These are control facts, not employment or access grants. Shares and percentages
are excluded. Strict internal grant validation binds the organization, holder,
type, expected revision and reason; self-control and injected fields are rejected.
Durable grant/revoke exports are now implemented (`controllingInterests=1`,
`interestTypes=1`), with character-owner acceptance passed. UUID shape validation alone does not
establish holder existence. Run `OrganizationsInterestContractSmokeTest`
for 18 checks with no interests created.

Internal holder resolution uses Character's persisted Contract 1 profile provider,
not a player session or direct Character table access. Character holders and
organization holders must be active; unavailable providers, mismatched identities,
missing and inactive holders fail closed. Only type/UUID/status are projected.
This adds no Character dependency to Organizations startup: character resolution
is readiness-gated when invoked. No public holder lookup route/export is added.
Run `OrganizationsHolderContractSmokeTest` for 10 read-only checks, then
`OrganizationsHolderLiveTest character <UUID>` with the character offline to
verify real persisted lookup. Real offline character and active organization
lookup acceptance passed; the holder contract passed 10/10.

`GrantOrganizationInterest(request)` and `RevokeOrganizationInterest(request)`
accept exactly `organizationId`, `expectedRevision`, `requestId`, `reasonCode`,
`interestType`, `holderType`, and `holderId`. Actual trusted mutators must own the
target organization or have configured privileged override. Optional Core policy
uses `organizations.interest.manage`. Both operations advance the shared target
revision and atomically persist the interest state, payload-bound receipt, audit
and outbox event. Replays return the original receipt without altering current
state. The holder/type tuple has one stable interest UUID; regranting a revoked
tuple reuses it. Same-state changes reject rather than create another interest.
Grants require an active persisted holder and a pending/active/suspended target.
Revokes allow dissolving targets and do not require the holder to remain active
or present; dissolved targets reject fresh changes. This does not impose exclusive
ownership, control inheritance, shares, employment, or automatic access rights.
Character validation uses its provider, not a cross-domain SQL transaction;
future deletion reconciliation remains a separate integration gate.
The new server-only events `organizations.organization.interest_granted.v1` and
`organizations.organization.interest_revoked.v1` include interest UUID/type/status,
but omit holder UUIDs and private names. No public interest listing is added.

`ListOrganizationInterests({organizationId, limit?, cursor?, status?})` is a private
trusted-auditor read (also requires trusted-reader readiness). Auditors can inspect
only organizations created by their resource unless explicitly privileged.
Unlike broker events, this authorized projection includes holder UUID/type, plus
interest UUID/type/status and last-change organization revision; it never includes
names, profiles or account IDs. The default limit is 20, maximum 50 numeric integer.
Pages sort by stable interest UUID ascending. Follow `nextCursor` with the same
organization and optional active/revoked filter; unrelated/filter-mismatched cursors
are rejected. This is a live view, not a snapshot, and filter membership can change
between pages. It does not verify holders still exist on every historical read.
No player route, all-organization enumeration or holder-based search is exposed.
Run `OrganizationsInterestReadContractSmokeTest` for 12 read-only checks; real
pagination, privacy and cross-resource read acceptance passed as recorded below.

`OrganizationsInterestReadLiveTest <stable requestId> <character UUID>` creates
one fixed-key test organization, grants character owner/founder and organization
controller interests, then revokes the character owner. It uses the active
`org_event_test_child` organization as controller. Expect revision 5, three
interests (two active/one revoked), five audit/outbox records and four interest
receipts. Live and restart acceptance passed with unchanged IDs/counts.
It checks full and filtered pagination, cursor boundaries, projection
privacy and isolation. Repeat the same request ID and character UUID after restart.

Development-only `OrganizationsInterestLiveTest <stable requestId> <character UUID>`
creates one fixed-key organization and grants, revokes, then regrants one owner
interest. It checks stable interest identity, original receipt replay without
reverting current state, stale/no-op/mismatch/missing-holder rejection, rejection
rollback and event privacy. Expect revision 4, one active interest, three interest
receipts, and four audit/outbox records including creation. Repeat the exact
request ID and character UUID after restart; do not use fresh IDs to recover the
fixed key. No money, inventory, employment or permissions are changed.

`OrganizationsInterestConcurrencyTest <stable requestId> <character UUID>` submits
owner/founder grants at the same revision on a separate fixed-key organization.
Expect one commit, one revision conflict, revision 2, one interest/receipt and two
audit/outbox records including creation. Repeat the exact IDs after restart to
verify winner replay. The watchdog bounds the test wait, not database execution.
Live and restart acceptance passed with founder winning, one stale owner grant,
revision 2, one interest/receipt and two audit/outbox records. Character-owner
grant/revoke/regrant and separate export ownership boundaries also passed before
and after restart. Organization-holder mutations, bounded private interest reads,
mixed-operation races and production authorization tests remain pending.

## Event publication

`OrganizationsInterestPolicyContractSmokeTest` checks the isolated interest policy
decision gate (11 checks), with no provider registration/configuration changes or
database writes. Explicit boolean allow is required; deny, missing/malformed
decisions, unavailable evaluator and thrown exceptions all fail closed. Request
attribution is copied and contains no player identity claims. Production interest
writes use the same gate around Core Authorize when policy is enabled, followed
by independent creator/privileged ownership checks. This does not establish live
Core-provider or cross-resource ownership-under-allow acceptance.

`OrganizationsInterestPolicyLiveTest <stable requestId> <character UUID>` is a
development-only real Core authorization test. Run only on an empty server with
authorization initially disabled and no installed policy providers; it refuses
otherwise. It creates one main-owned test organization and uses the existing
fixture-owned `org_interest_fixture` for foreign ownership rejection. Its temporary
default provider allows only the exact test action/caller/subject/correlation
namespace, denying other requests. The harness temporarily enables authorization,
checks grant allow, revoke deny/malformed/exception/unavailable rejection and
foreign grant denial despite policy allow, then restores the setting and removes
the provider on success/failure. Background callers may see temporary denials;
do not run during other framework tests. Expect revision 2, one active interest
and two audit/outbox records. Repeat the same request ID and character UUID after
restart. Controlled exception cases may print expected Core policy error logs.
No Core or Character code changes are required. This is acceptance-harness
coverage of the temporary provider, not the current production configuration.
Authorization is now enabled by default with Admin's explicit service-principal
grants; this older harness requires its documented isolated test configuration.
Live and restart acceptance passed with the same organization UUID, revision 2,
two audit/outbox records, ownership enforced and cleanup confirmed. The isolated
decision gate passed 11/11. Since feather-admin installs a default policy provider,
stop it temporarily on the empty development server for this harness and restore
it with `ensure feather-admin` afterward. The harness never replaces it. Admin's
player-role policy is separate from its now-installed service-principal grants.

`OrganizationsInterestHolderLifecycleTest <stable requestId>` creates a target
and organization controller, activates the holder and grants a controller interest.
It suspends the holder, rejects a fresh owner grant, reads and revokes the existing
interest, resumes the holder and regrants the same controller tuple. Expect both
organizations at revision 4, one active interest with stable UUID and eight total
audit/outbox records. Repeat the original request ID after restart. This verifies
explicit cleanup, not cascading status changes or inferred access permissions.
Live and restart holder suspension/resume acceptance passed with stable IDs,
both revisions at 4 and eight audit/outbox records.

`OrganizationsHolderGrantConcurrencyTest <stable requestId>` races organization
holder suspension against a new controller grant on a different target. Both may
commit if grant locks/validates the active holder first (five total audit/outbox
records); otherwise grant rejects `holder_inactive` (four records, no grant receipt).
The holder ends suspended at revision 3; the target is revision 2 or 1 accordingly.
Suspension does not revoke a previously committed interest. Repeat the original
ID after restart to verify persisted outcomes and replay, not a fresh race.
Live and restart acceptance passed for suspension-first: holder revision 3,
target revision 1, zero interests, four audit/outbox records and no grant receipt.
The grant-first concurrency branch is supported by the test but not yet accepted.

`OrganizationsHolderGrantOrderingTest <stable requestId>` deterministically commits
an organization controller grant before suspending its holder. It verifies the
committed interest remains active/readable, original receipts replay, fresh grants
reject `holder_inactive`, and rejection creates no receipt. Expect target revision
2, holder revision 3, one interest and five audit/outbox records. Repeat the original
request ID after restart. This tests grant-first ordered semantics, not concurrent
overlap or a scheduler-selected grant-first race winner.

Development-only `OrganizationsInterestLifecycleTest <stable requestId> <character UUID>`
creates a separate fixed-key organization, grants one owner, starts dissolution,
rejects new grants, revokes the existing interest and finishes dissolution.
It checks terminal mutation rejection, preserved original receipts, readable
revoked interests/history, revision 5 and five audit/outbox records. Repeat the
exact request ID and holder UUID after restart. This is explicit cleanup, not
automatic revocation of every interest when an organization dissolves.
Live and restart cleanup acceptance passed at dissolved revision 5 with unchanged
audit/outbox counts and original receipt/history reads intact.

`OrganizationsInterestLifecycleConcurrencyTest <stable requestId> <character UUID>`
competes an owner grant with begin-dissolution at revision 1 on a separate fixed
test organization. Either winner is valid: require one commit/one stale rejection,
revision 2, winner-consistent lifecycle/interest state, one mutation receipt and
two audit/outbox records. Repeat the exact request ID/holder UUID after restart.
Live and restart mixed-race acceptance passed with lifecycle winning, revision 2,
dissolving state, zero interests, one receipt and unchanged audit/outbox counts.
Private read contract passed 12/12; multi-page/filtered read and separate fixture
ownership checks passed before and after restart. Remaining gates include
organization-holder lifecycle changes, production policy decisions and consumer
integration; no automatic interest cleanup or implicit permission grants exist.

Every new committed creation, lifecycle, identity, or parent change writes an
audit record and outbox record in the same database transaction. Request replays
do not enqueue another event. The server-only Core broker events are
`organizations.organization.created.v1`, `organizations.organization.status_changed.v1`,
`organizations.organization.identity_changed.v1`, and `organizations.organization.parent_changed.v1`.
Payloads contain stable event/organization IDs, revision and request attribution,
with relevant status/parent details; legal/display names are excluded.
Publication is at least once: deduplicate by `eventId` and read authoritative
current state. Published means broker acceptance, not durable subscriber receipt.
Existing audit records are not backfilled into the outbox.

`InspectOrganizationHistory({organizationId, limit?, cursor?})` requires an actual
trusted auditor that is also a trusted reader. Non-privileged auditors may only
inspect organizations created by their resource. Pages default to 20, maximum
50, newest first by timestamp/event UUID, with `items` and optional `nextCursor`.
Keep the organization ID unchanged when following cursors. This is a live view,
not a frozen snapshot. No public/client history route is provided.

After manifest changes run `refresh`, then `restart feather-organizations`.
Run `OrganizationsEventContractSmokeTest` for 12/12 read-only checks.
Live broker publication, pagination and request replay passed, including after
restart. The separate fixture also passed creator-scoped audit access and
injection rejection before/after restart.

Development-only `OrganizationsEventRecoveryTest <stable requestId> prepare`
stops publication using the existing publisher lifecycle and commits one test
creation with a pending outbox record. Restart Organizations, then run the same
command with `retry` to verify publication and exact creation replay. Always
restart after prepare, including on failure: it pauses the whole publisher.
The fixed test key requires retaining the original request ID on every rerun.
Pending publication recovery passed across resource restart: the original event
ID was published, creation replayed, and exactly one audit/outbox record remained.

## Database access

The manifest imports `@feather-mysql/lib/DB.lua`. Queries use `DB.query`,
`DB.one`, `DB.value`, `DB.insert` and `DB.exec`, with positional values after
SQL. The library yields, returns plain values and raises database failures into
Organizations' existing error boundaries.

Creation, lifecycle, identity, hierarchy and interest changes use
`DB.transaction(function(tx) ... end)`. Every transactional statement uses
`tx.*`, including receipts, events and outbox rows. Only a confirmed commit
returns domain success. Retry uncertain outcomes with the same request ID.

Start `feather-mysql`, `feather-core`, then `feather-organizations`. Startup waits
for `DB.awaitReady` before applying migrations. Restart Organizations after
restarting the database provider. Run `OrganizationsReleaseContractSmokeTest` on
staging; development smoke commands require `Config.DevMode`.
