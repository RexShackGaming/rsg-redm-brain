local Assert = _G.TestAssert
local savedAdmin, savedExports, savedPrint = FeatherAdmin, exports, print
local commands, output, reads = {}, {}, 0
local searchGrant, sensitiveGrant = true, true
RegisterCommand = function(name, callback) commands[name] = callback end
print = function(line) output[#output + 1] = line end
FeatherAdmin = { CanUse = function(_, action)
    return action == 'audit.search' and searchGrant or action == 'audit.sensitive.view' and sensitiveGrant
end }
local pauseResult = { ok = false, code = 'forbidden', meta = { developmentPauseCompleted = true } }
exports = { ['feather-audit'] = {
    GetVisibilitySmokeFixture = function()
        reads = reads + 1
        return { fromEpoch = 1, toEpoch = 2, correlationId = 'workflow', restrictedId = 'restricted', sealedId = 'sealed' }
    end,
    Search = function(_, request)
        reads = reads + 1
        if not request.correlationId then return pauseResult end
        return { ok = true, value = { events = { {}, {} } } }
    end,
    GetEvent = function(_, request)
        return { ok = true, value = { event = request.eventId == 'restricted' and { eventId = 'restricted' } or nil } }
    end,
    GetCorrelation = function() return { ok = true, value = { events = { {}, {} } } } end
} }
dofile('../feather-admin/server/services/authority_contract.lua')
commands.AdminAuditVisibilityLiveTest(0, { '1', 'standard' })
Assert.truthy(output[#output]:find('FAIL precondition', 1, true))
Assert.equal(0, reads, 'Owner must not run the standard-reader test')
commands.AdminAuditVisibilityLiveTest(0, { '1', 'sensitive' })
Assert.truthy(output[#output]:find('PASS mode=sensitive', 1, true))
searchGrant, sensitiveGrant = false, false
local before = reads
commands.AdminAuditPausedReadLiveTest(0, { '1' })
Assert.truthy(output[#output]:find('FAIL precondition', 1, true))
Assert.equal(before, reads, 'nonstaff must not start an in-flight test')
searchGrant = true
commands.AdminAuditPausedReadLiveTest(0, { '1' })
Assert.truthy(output[#output]:find('PASS resultDiscarded', 1, true))
pauseResult = { ok = false, code = 'forbidden' }
commands.AdminAuditPausedReadLiveTest(0, { '1' })
Assert.truthy(output[#output]:find('FAIL pause did not complete', 1, true))
FeatherAdmin, exports, print = savedAdmin, savedExports, savedPrint
