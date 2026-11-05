# Feather Audit

0.1.1 validates Access grant-preservation events and their transfer proof context.

Feather Audit provides server-only ingestion of reviewed domain events into an
append-only investigation projection. Domains retain their authoritative records.
This resource is under development; production producer onboarding is incomplete.
`feather-access` is registered for `access.grant.created@1` and
`access.grant.revoked@1`. Its source instance must match Config.SourceInstance.
Access retains its own authoritative grant state and transaction-bound outbox;
Audit provides the deduplicated investigation projection. The schemas restrict
events to reviewed grant metadata with security retention and restricted sensitivity.
Search, notifications, retention execution, redaction, and investigation exports
are not available yet.

## Installation

Start feather-mysql and feather-core before feather-audit:

```cfg
ensure feather-mysql
ensure feather-core
ensure feather-audit
```

Startup validates configuration and applies Audit-owned migrations. Back up the
database before an upgrade. Never edit applied migrations or their ledger.

## Server configuration

- Set Config.SourceInstance to a stable server/world identifier. Changing it
  changes the event deduplication scope.
- Register exact trusted resource names, event prefixes, versions, and rate limits
  in Config.Producers. Reviewed schemas must also be loaded by Audit.
- Keep Config.Development.smokeCommands=false on production servers. Remove
  temporary test-producer registrations after development acceptance.
- Keep Config.Notifications.enabled=false; outbound delivery is not implemented.
- Do not place passwords, webhook URLs, tokens, or connection strings in events.

## Health and capabilities

```lua
local health = exports['feather-audit']:GetHealth()
local capabilities = exports['feather-audit']:GetCapabilities()
```

These exports return plain tables. Health reports lifecycle status, readiness,
database status, migration count, and ingestion metrics. Capabilities describe
implemented features; a started resource is not necessarily ready for ingestion.

## Bounded metadata search (development)

```lua
local result = exports['feather-audit']:Search({
    fromEpoch = os.time() - 86400,
    toEpoch = os.time(),
    limit = 25,
    sourceResource = 'feather-shops'
}, actorSource)
```

Only the trusted Admin server adapter may supply a player source. The temporary
smoke producer is also trusted while development smoke commands are enabled.
Audit derives the active character session from Core and evaluates the named
Authority provider. Administrator/Owner require `staff.admin.audit.search`;
restricted events additionally require `staff.admin.audit.sensitive.view`
(Owner by default). Sealed events are excluded. Missing permissions or provider
failure return `forbidden`; session/permission changes during a read discard results.
Both capability decisions must use the same Authority policy version. Failure
to evaluate either capability fails closed rather than silently downgrading access.

Requests allow only integer `fromEpoch`, `toEpoch`, `limit` (1–50, default 25),
and optional exact `sourceResource`, `eventType`, `correlationId`, `eventId` filters.
Additional UUID filters `targetAccountId` and `targetCharacterId` match typed
targets. `adminAction` matches the approved action field only on Admin v1 events.
The window is limited to seven days. Success returns
`{ ok = true, value = { events = {...}, limit = n } }`. Events contain metadata
only; payload, context, summary, display names, and actor identifiers are omitted.
Each successful repository read records access transactionally. Validation,
read availability, and rate-limit errors use Contract 1 error envelopes.
Success also includes `nextCursor` when another page exists. Supply that cursor
with the exact same request to continue. Cursors expire after five minutes,
do not survive Audit restart, and are bound to caller, character session,
sensitivity permission, operation, and filters including limit. Invalid or
expired cursors return `invalid_cursor`. The server stores at most 256 live
cursors; saturation returns `cursor_capacity`. Ordering uses occurrence time
and Audit ID; this is a live keyset traversal, not a frozen database snapshot.

`GetEvent({ fromEpoch, toEpoch, eventId }, actorSource)` returns
`{ ok = true, value = { event = eventOrNil } }`. Hidden and absent events
return the same empty value. Limit and cursor are not accepted for detail reads.
An event may include `content = { context = approvedFields, projectionVersion = 1 }`.
Only scalar context fields listed in its loaded schema's `readProjection` return.
No projection is the metadata-only default. Example:
`readProjection = { sequence = 'internal', message = 'restricted' }`.
Internal fields require search access; restricted fields additionally require
sensitive access even when the event itself is internal. Fields must exist in
the context schema and be string, integer, or boolean; projected strings require
`maxBytes <= 1024`. Nested content is unsupported. Unknown schema versions,
malformed context, and invalid field values disclose no unapproved fields.
Raw JSON, payloads, summaries, actor/target IDs, and display names never return.

`GetCorrelation({ fromEpoch, toEpoch, correlationId, limit, cursor }, actorSource)`
returns the same paged result as Search, restricted to that correlation ID.
Both use the same trusted caller and Authority checks and create their own
non-recursive access records. Correlation results remain metadata-only.
The full search capability
remains false pending complete A3 acceptance and sensitive visibility fixtures.

Development-only `GetVisibilitySmokeFixture()` returns the current test IDs/window
only to the Admin server resource while smokeCommands is enabled. It returns nil
otherwise and does not expose event payloads. This helper is not a production API.

## Ingestion API v1

**Export:** `Ingest`
**Transport name:** `audit.ingest.v1`
**Availability:** Server only

### Registration

Audit accepts only exact invoking resources registered in `Config.Producers`. A registration limits source instance, event-type prefixes, event versions, and requests per minute.

```lua
Config.Producers = {
    ['feather-economy'] = {
        enabled = true,
        sourceInstance = 'frontier-1',
        eventPrefixes = { 'economy.' },
        versions = { [1] = true },
        maxPerMinute = 600
    }
}
```

The corresponding event schemas must also be loaded by Audit. Registration alone does not allow an unknown event type.

### Call

```lua
local response = exports['feather-audit']:Ingest(event)
```

Audit obtains the invoking resource from the Cfx runtime. It does not accept a caller-supplied producer identity argument. Never wrap this export in a client-accessible network event.

### Responses

```lua
{
    result = 'accepted',
    auditEventId = 'database UUID',
    warnings = {}
}

{
    result = 'duplicate',
    auditEventId = 'original database UUID',
    warnings = {}
}

{
    result = 'retryable_rejection',
    code = 'audit_not_ready | producer_rate_limited | database_error | quarantine_unavailable',
    warnings = {}
}

{
    result = 'quarantined',
    auditEventId = 'present only for an identity conflict with an existing event',
    code = 'stable rejection code',
    path = '$.bounded.field.path',
    warnings = {}
}
```

The producer marks `accepted` and `duplicate` as delivered. It retries `retryable_rejection` with backoff. It stops automatic retry and alerts operators for `quarantined`.

Thrown export errors or timeouts are treated as retryable because Audit may have committed before acknowledgement was lost.

### Security behavior

- Unregistered resources are rejected without creating quarantine rows.
- A registered caller cannot claim another `sourceResource` or unexpected `sourceInstance`.
- Event type/version must be permitted by both registration and a loaded schema.
- Quarantine stores identity and bounded diagnostics, never the raw rejected payload.
- No notification provider runs during A2 ingestion.

## Producer kit API

The producer kit constructs and validates `audit_event.v1` records and manages the transport-independent outbox state machine. It is pure Lua so a domain can commit locally while `feather-audit` is stopped or absent.

### Dependency order

Load these files into the producer resource in order:

```text
shared/constants.lua
shared/results.lua
shared/contract/canonical.lua
shared/contract/registry.lua
shared/contract/validator.lua
producer/event_id.lua
producer/event_builder.lua
producer/outbox.lua
owned event schemas
```

For now, producers should vendor a reviewed version of those files. Referencing live Audit exports for event construction or outbox insertion is prohibited because it would make authoritative mutations depend on Audit availability. A future framework contract package may replace vendoring.

### Repository adapter

`FeatherAuditProducerOutbox.Create` requires a repository with:

- `insert(transaction, row)` — insert into the producer's outbox using the caller's existing domain transaction.
- `lease(batchSize, owner, expiresAt, now)` — atomically claim eligible rows and reclaim expired leases.
- `markDelivered(row, auditEventId, result, now)`.
- `markRetry(row, nextAttemptAt, resultCode, attemptCount)`.
- `markQuarantined(row, resultCode, now)`.

The kit deliberately does not provide a generic `oxmysql` repository yet. Each domain's transaction wrapper must be understood and tested before an adapter can honestly guarantee that the domain mutation and outbox insert share one transaction.

### Transport adapter

The transport provides `ingest(event, canonicalPayload)` and returns:

```lua
{ result = 'accepted', auditEventId = '...' }
{ result = 'duplicate', auditEventId = '...' }
{ result = 'retryable_rejection', code = '...' }
{ result = 'quarantined', code = '...' }
```

Timeouts and thrown errors are treated as retryable because Audit may have committed before the acknowledgement was lost.

The initial Cfx transport implementation calls:

```lua
local result = exports['feather-audit']:Ingest(event)
```

Audit independently canonicalizes and validates the event; it does not trust the producer's supplied canonical payload. See [Ingestion API](#ingestion-api-v1).

### Transaction rule

Call `Enqueue` with the active domain transaction before that transaction commits. Do not call it after commit, from an in-memory event handler, or as a replacement for a durable outbox.

See [Producer Requirements](../feather-framework-docs/feather-audit/PRODUCER_REQUIREMENTS.md) and [Event Contract](../feather-framework-docs/feather-audit/EVENT_CONTRACT.md) for the normative rules.

## Additional documentation

Design, development phases, acceptance procedures, and results live in
[feather-framework-docs](../feather-framework-docs/feather-audit/Feather_Audit_Master_Plan.md).
