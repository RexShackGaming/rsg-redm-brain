JusticeConfig = {
    ReadinessTimeoutMs = 30000,
    -- Trust authenticates the resource; Core policy must separately authorize
    -- each actor/action. No development bypass or implicit staff override.
    TrustedResources = { ['bcc-law'] = true },
    DefinitionResources = { ['bcc-law'] = true },
    -- Actions a trusted resource may call without a player (service mode, Core
    -- policy source 0). Jail/court gameplay uses these for offline subjects.
    -- custody.view: GetCustodyStatus by character (placement/reconnect).
    -- sentence.view: ListActiveSentences for one defendant (no narrative terms).
    -- sentence.complete: report finished community service.
    SystemActions = {
        ['justice.custody.view'] = true,
        ['justice.sentence.view'] = true,
        ['justice.sentence.complete'] = true
    },
    -- Master plan, Jurisdictions: "a territory, county, town, court district, tribal
    -- authority, or server-defined legal region". Hierarchy is optional and bounded.
    JurisdictionTypes = { 'territory', 'state', 'county', 'town', 'court_district', 'tribal_authority', 'region' },
    MaximumJurisdictionDepth = 4,
    -- Master plan, Cases: investigation, prosecution, adjudication or another proceeding.
    -- 'citation' answers team decision 6: every citation lives in a case.
    CaseTypes = { 'investigation', 'criminal', 'civil', 'citation', 'administrative' },
    MaxPageSize = 25,
    OutboxBatchSize = 20,
    -- Each citation keeps the terms it was issued with. A citation without an amount is a warning.
    Citations = { Currency = 'dollars', MaximumAmount = 100000, MaximumDueSeconds = 2592000,
        TypeKey = 'justice_citation_v1' },
    -- Arrest without a warrant is off until the server defines lawful exceptions,
    -- e.g. Exceptions = { caught_in_the_act = true }. Keys are frozen per record.
    Custody = { Exceptions = {} },
    -- A ruling must come from an active judge participant on the case unless the
    -- actor holds justice.case.manage_all. Set false only if policy alone decides.
    Rulings = { RequireJudgeParticipant = true, MaximumFindings = 25 },
    Sentences = {
        -- Custodial and probation terms run on UTC wall time from activation and
        -- continue while the subject is offline.
        -- Community service completes through CompleteSentence when gameplay reports the last task.
        MaximumTermSeconds = 31536000,
        MaximumAmount = 1000000,
        MaximumDueSeconds = 2592000,
        MaximumServiceUnits = 1000,
        Currency = 'dollars',
        FineTypeKey = 'justice_sentence_fine_v1',
        RestitutionTypeKey = 'justice_sentence_restitution_v1',
        RetrySeconds = 15, BatchSize = 10, SettlementCheckSeconds = 300
    },
    Evidence = {
        -- Veto destruction of Inventory instances with an active case link.
        InventoryGuard = true,
        ReloadSeconds = 60
    },
    -- Retention is operator policy. nil keeps records forever (default).
    Retention = {
        DeliveredOutboxDays = 30,
        RedactClosedCaseNarrativesDays = nil,
        SweepSeconds = 3600
    },
    WarrantExpirySweepSeconds = 30,
    -- Structured console logs: slow operations always; rejections only when enabled.
    Logging = { SlowOperationMs = 1500, Rejections = false },
    -- Officer searches by character are always audited; identical automated
    -- service-mode reads (jail placement checks) once per window.
    AccessAudit = { ServiceRepeatSeconds = 3600 },
    -- Resources (besides TrustedResources) allowed to read the metrics export.
    MetricsReaders = { ['feather-admin'] = true }
}
