-- Lifecycle, events and workers (master plan: Failure and restart behavior, Events).
local J, Repo = Justice, Justice.Repo
local dependencies = { ['feather-core'] = true, ['feather-mysql'] = true, ['feather-character'] = true }
local running, declared, nextStartup = false, {}, 0

-- Committed facts. The plan's list (case.opened ... record.sealed) plus the
-- remaining lifecycle facts. Payloads are safe identifiers and state only.
local facts = {
    'jurisdiction.registered', 'jurisdiction.updated', 'statute.registered', 'statute.revised',
    'case.opened', 'case.updated', 'case.transitioned', 'party.added', 'party.removed',
    'charge.proposed', 'charge.filed', 'charge.amended', 'charge.disposed',
    'warrant.drafted', 'warrant.issued', 'warrant.served', 'warrant.recalled', 'warrant.quashed', 'warrant.expired',
    'citation.issued', 'citation.obligation_issued', 'citation.settled', 'citation.defaulted',
    'custody.started', 'custody.booked', 'custody.released',
    'ruling.recorded',
    'sentence.created', 'sentence.activated', 'sentence.obligation_issued', 'sentence.suspended', 'sentence.completed', 'sentence.defaulted',
    'evidence.linked', 'evidence.removed', 'evidence.missing',
    'record.sealed', 'record.unsealed', 'record.expunged'
}
J.Facts = facts

local function ValidateConfig()
    local c = JusticeConfig
    local function list(value) return type(value) == 'table' and #value > 0 end
    if not J.Integer(c.ReadinessTimeoutMs, 0, 60000) or not J.Integer(c.MaxPageSize, 1, 100)
        or not J.Integer(c.OutboxBatchSize, 1, 100) or not J.Integer(c.MaximumJurisdictionDepth, 1, 8)
        or not list(c.JurisdictionTypes) or not list(c.CaseTypes) or type(c.SystemActions) ~= 'table'
        or type(c.Rulings) ~= 'table' or type(c.Evidence) ~= 'table' or type(c.Custody) ~= 'table'
        or not J.Integer(c.WarrantExpirySweepSeconds, 5, 3600) or not J.CitationConfigValid() then error('invalid_config') end
    local s = c.Sentences
    if type(s) ~= 'table' or not J.Token(s.Currency, 32) or not J.Token(s.FineTypeKey, 48) or not J.Token(s.RestitutionTypeKey, 48)
        or not J.Integer(s.RetrySeconds, 1, 3600) or not J.Integer(s.BatchSize, 1, 25)
        or not J.Integer(s.SettlementCheckSeconds, 5, 86400) or not J.Integer(s.MaximumTermSeconds, 60, 315360000) then
        error('invalid_sentence_config')
    end
    if type(c.TrustedResources) ~= 'table' or type(c.DefinitionResources) ~= 'table' then error('invalid_config') end
    for resource, allowed in pairs(c.TrustedResources) do
        if type(resource) ~= 'string' or #resource > 64 or not resource:match('^[a-z0-9_-]+$') or type(allowed) ~= 'boolean' then
            error('invalid_config')
        end
    end
    for resource, allowed in pairs(c.DefinitionResources) do
        if type(allowed) ~= 'boolean' or (allowed and c.TrustedResources[resource] ~= true) then error('invalid_config') end
    end
end

local function Startup()
    if running or GetGameTimer() < nextStartup then return end
    nextStartup = GetGameTimer() + 5000
    running = true
    local generation = J.Generation()
    CreateThread(function()
        local ok, failure = pcall(function()
            ValidateConfig()
            local core = J.Call('feather-core', 'AwaitReady', JusticeConfig.ReadinessTimeoutMs)
            local caps = J.Call('feather-core', 'GetCapabilities')
            if not core.ok or not caps.ok or type(caps.value) ~= 'table' or caps.value.contract ~= 1 then error('core_unavailable') end
            if DB.awaitReady(JusticeConfig.ReadinessTimeoutMs) ~= true then error('database_unavailable') end
            local character = J.Call('feather-character', 'GetHealth')
            if not character.ok or type(character.value) ~= 'table' or character.value.state ~= 'ready' then error('character_unavailable') end
            J.Migrate()
            if generation ~= J.Generation() then error('startup_cancelled') end
            for _, fact in ipairs(facts) do
                local name = 'justice.' .. fact .. '.v1'
                if not declared[name] then
                    local registration = J.Call('feather-core', 'DeclareEvent', name,
                        { contract = 1, maxPayloadBytes = 1024, maxDepth = 2, maxNodes = 16 })
                    if not registration.ok then error('event_registration_failed') end
                    if generation ~= J.Generation() then error('startup_cancelled') end
                    declared[name] = true
                end
            end
        end)
        if ok then
            -- Optional neighbours: their absence never blocks readiness.
            pcall(J.ReloadEvidenceIndex)
            pcall(J.InstallEvidenceGuard)
            pcall(J.SubscribeContracts)
        end
        running = false
        if generation ~= J.Generation() then return end
        local previous = J.Health().value.state
        J.State(ok and 'ready' or 'failed', ok and 'records_ready' or 'startup_failed')
        if previous ~= (ok and 'ready' or 'failed') then
            local reason = ok and '' or (' reason=' .. tostring(type(failure) == 'table' and failure.code or failure):match('^[^\n]*'):sub(1, 160))
            print('[feather-justice] event=startup.' .. (ok and 'ready' or 'failed') .. reason)
        end
    end)
end
Startup()
AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' then declared = {}; J.ResetContractSubscriptions() end
    if resource == 'feather-contracts' then J.ResetContractSubscriptions() end
    if resource == 'feather-inventory' then J.EvidenceGuardLost() end
    -- Unregister first: a guard pointing at a stopped resource would veto every destroy.
    if resource == GetCurrentResourceName() then J.RemoveEvidenceGuard() end
    if dependencies[resource] or resource == GetCurrentResourceName() then J.State('degraded', 'dependency_stopped') end
end)
AddEventHandler('onResourceStart', function(resource) if dependencies[resource] then Startup() end end)

local lastSweep, lastRetention, lastReload = 0, 0, 0
local function Publish()
    for _, row in ipairs(Repo.PendingOutbox(JusticeConfig.OutboxBatchSize)) do
        if not J.Ready() then break end
        local payload = json.decode(row.payload_json)
        local result = J.Call('feather-core', 'PublishEvent', row.fact, payload)
        if result.ok then Repo.MarkDelivered(row.event_id) end
    end
end
-- At-least-once delivery, ordered per record; consumers deduplicate by eventId.
CreateThread(function()
    while true do
        Wait(1000)
        if J.Ready() then
            local core = J.Call('feather-core', 'GetHealth')
            local character = J.Call('feather-character', 'GetHealth')
            local databaseOk, databaseReady = pcall(DB.isReady)
            if not core.ok or type(core.value) ~= 'table' or core.value.state ~= 'ready'
                or not character.ok or type(character.value) ~= 'table' or character.value.state ~= 'ready'
                or not databaseOk or databaseReady ~= true then
                J.State('degraded', 'dependency_unavailable')
            end
        end
        if not J.Ready() then Startup() end
        if J.Ready() then
            J.ProcessWorkflows()
            local now = GetGameTimer()
            if now - lastSweep >= JusticeConfig.WarrantExpirySweepSeconds * 1000 then
                lastSweep = now
                pcall(J.SweepWarrants)
                pcall(J.SweepSentences)
                pcall(J.SubscribeContracts)
                if not J.EvidenceGuardActive() then pcall(J.InstallEvidenceGuard) end
            end
            if now - lastReload >= JusticeConfig.Evidence.ReloadSeconds * 1000 then
                lastReload = now
                pcall(J.ReloadEvidenceIndex)
            end
            if now - lastRetention >= (JusticeConfig.Retention.SweepSeconds or 3600) * 1000 then
                lastRetention = now
                pcall(J.RunRetention, false)
            end
            if not pcall(Publish) then print('[feather-justice] event=outbox.retry') end
        end
    end
end)
