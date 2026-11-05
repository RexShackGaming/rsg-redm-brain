-- Read-only check of scoped issuing (Config.IssueReasons, journal.lua MayPost).
-- It swaps in a test resource and restores the configuration; nothing is posted.

RegisterCommand('EconomyIssueReasonGateSmokeTest', function(source)
    if source ~= 0 then return end
    local Check, Result = EconomyTests.Counter('EconomyIssueReasonGateSmokeTest')
    local LISTED, OTHER = 'economy-gate-payer', 'economy-gate-other'
    local reasons = Config.IssueReasons
    Config.IssueReasons = { [LISTED] = { ['gate.payout'] = true } }
    local called, failure = xpcall(function()
        local May = EconomyJournal.MayPost
        Check('capability advertised', EconomyAPI.GetCapabilities().value.features.scopedIssue == 1)
        Check('listed reason may issue', May('issue', LISTED, 'gate.payout'))
        Check('other reason refused', not May('issue', LISTED, 'gate.other'))
        Check('listed resource cannot destroy', not May('destroy', LISTED, 'gate.payout'))
        Check('listed reason gives no transfer right', not May('transfer', LISTED, 'gate.payout'))
        Check('unlisted resource refused', not May('issue', OTHER, 'gate.payout'))
        Check('trusted supplier keeps any reason', May('issue', 'feather-economy', 'gate.anything'))
        Check('no resource name refused', not May('issue', nil, 'gate.payout'))
    end, debug.traceback)
    Config.IssueReasons = reasons
    if not called then print('[EconomyIssueReasonGateSmokeTest] FAIL ' .. tostring(failure)) end
    local passed, total = Result()
    print(('[EconomyIssueReasonGateSmokeTest] done %d/%d passed (configuration only; nothing posted)'):format(passed, total))
end, true)
