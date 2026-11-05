local Assert = _G.TestAssert
local reads, phase, revoke, replace = 0, 0, false, false
Config.Development.smokeCommands = true
FeatherAudit = { GetHealth = function() return { ready = true } end }
FeatherAuditRateLimit = { Allow = function() return true end }
FeatherAuditSearch = { Read = function()
    reads = reads + 1
    phase = 1
    return { ok = true, value = { events = {} } }
end }
local entitled, providerAvailable = true, true
local sensitiveLost, versionDrift, sensitiveFailure = false, false, false
exports = { ['feather-core'] = {
    GetSessionContext = function()
        return { ok = true, value = { accountId = 'account', characterId = 'character',
            sessionId = replace and phase == 1 and 'new-session' or 'session', generation = 1 } }
    end,
    GetProvider = function()
        if not providerAvailable then return { ok = false } end
        return { ok = true, value = { provider = { owner = 'feather-authority' },
            implementation = { Evaluate = function(capability)
                local isSensitive = capability == 'staff.admin.audit.sensitive.view'
                if sensitiveFailure and isSensitive then return { ok = false } end
                return { ok = true, value = { allowed = entitled and not (revoke and phase == 1)
                    and not (sensitiveLost and isSensitive and phase == 1),
                    policyVersion = versionDrift and isSensitive and 2 or 1 } }
            end } } }
    end
} }
dofile('server/services/authorization.lua')
local result = FeatherAuditAuthorization.Search({}, 1, 'untrusted')
Assert.equal('forbidden', result.code)
Assert.equal(0, reads)
entitled = false
result = FeatherAuditAuthorization.Search(false, 1, 'feather-admin')
Assert.equal('forbidden', result.code)
Assert.equal(0, reads)
entitled = true
result = FeatherAuditAuthorization.Search({}, 1, 'feather-admin')
Assert.truthy(result.ok)
phase, revoke = 0, true
result = FeatherAuditAuthorization.Search({}, 1, 'feather-admin')
Assert.equal('forbidden', result.code, 'revocation after yielding must discard results')
phase, revoke, replace = 0, false, true
result = FeatherAuditAuthorization.Search({}, 1, 'feather-admin')
Assert.equal('forbidden', result.code, 'new session must not receive old results')
phase, replace, providerAvailable = 0, false, false
result = FeatherAuditAuthorization.Search({}, 1, 'feather-admin')
Assert.equal('forbidden', result.code)
Assert.equal('forbidden', FeatherAuditAuthorization.Search({}, 0, 'feather-admin').code)
providerAvailable, phase, sensitiveLost = true, 0, true
Assert.equal('forbidden', FeatherAuditAuthorization.Search({}, 1, 'feather-admin').code,
    'loss of sensitive permission after reading must discard the result')
phase, sensitiveLost, versionDrift = 0, false, true
local before = reads
Assert.equal('forbidden', FeatherAuditAuthorization.Search({}, 1, 'feather-admin').code)
Assert.equal(before, reads, 'mixed policy versions must fail before query')
versionDrift, sensitiveFailure = false, true
Assert.equal('forbidden', FeatherAuditAuthorization.Search({}, 1, 'feather-admin').code)
Assert.equal(before, reads, 'sensitive evaluation failure must not degrade to an ordinary read')
