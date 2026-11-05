-- The console smoke scenarios (JusticeAcceptanceTest = all of them) on the real
-- schema, with Contracts, Inventory and an organization enabled.
return function(t)
    local J = Justice
    local options = { contracts = true, item = '501', organizationId = t.organization }
    -- Simulated passage of real time: move the stored deadlines into the past.
    options.fastClock = function(run)
        t.ago('justice_sentences', 'ends_at', 'sentence_id', run.waitTerm.sentenceId, 1000)
        if run.shortWarrant then t.ago('justice_warrants', 'expires_at', 'warrant_id', run.shortWarrant.warrantId, 1000) end
    end
    local run = J.RunScenarios('JusticeAcceptanceTest', t.actor, t.subject, options, J.AcceptanceScenarios)
    t.check('acceptance scenarios ran', run ~= nil)
    t.check('acceptance scenarios passed', run and run.failed == 0, run and run.failed)
    t.check('nothing skipped with all options', run and run.skipped == 1, run and run.skipped) -- sealing is skipped: a payable citation stays open
    t.check('cleanup removed every acceptance record', t.sql.value("SELECT COUNT(*) FROM justice_cases WHERE opened_by_resource='justice-acceptance'") == 0
        and t.sql.value("SELECT COUNT(*) FROM justice_jurisdictions WHERE owner_resource='justice-acceptance'") == 0)
    -- Without Contracts the privacy scenario runs to completion (seal, unseal, expunge).
    run = J.RunScenarios('JusticeAcceptanceTest', t.actor, t.subject, { fastClock = options.fastClock, item = '501' }, J.AcceptanceScenarios)
    t.check('acceptance without Contracts passed', run and run.failed == 0, run and run.failed)
    t.check('privacy scenario ran (only Contracts and organization skipped)', run and run.skipped == 3, run and run.skipped)
    for name in pairs({ JusticeCaseSmokeTest = 1, JusticeWarrantSmokeTest = 1, JusticeCitationSmokeTest = 1,
        JusticeCustodySmokeTest = 1, JusticeEvidenceSmokeTest = 1, JusticeAcceptanceTest = 1, JusticeRestartChecklist = 1,
        JusticeMigrationSmokeTest = 1, JusticePolicySmokeTest = 1, JusticeContractSmokeTest = 1 }) do
        t.check('console command ' .. name .. ' registered', type(t.commands[name]) == 'function')
    end
end
