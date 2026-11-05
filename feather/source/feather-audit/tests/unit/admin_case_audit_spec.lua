local Assert = _G.TestAssert
local routes, inserts = {}, 0
local allowed, visible = true, true
local account = '11111111-1111-1111-1111-111111111111'
local eventId = '22222222-2222-2222-2222-222222222222'
AdminDatabase = { ready = true }
Config.cases = {}
FeatherAdmin = { RegisterRPC = function(name, fn) routes[name] = fn end,
    RequirePermission = function() return true end, CanUse = function() return allowed end,
    CheckTargetAccountHierarchy = function() return true end,
    Identity = { Resolve = function() return { accountId = 'actor', characterId = 'character' } end },
    Core = { User = { GetLicense = function() return 'license:actor' end } } }
GetPlayerName = function() return 'Actor' end
TriggerClientEvent = function() end
AdminAudit = { RecordTarget = function() end }
DB = { one = function() return { id = 1, status = 'open', targetAccountId = account } end,
    insert = function(_, caseId, kind, id) Assert.equal('audit', kind); Assert.equal(eventId, id); inserts = inserts + 1 end }
exports = { ['feather-audit'] = { GetEvent = function(_, query, source)
    Assert.equal(account, query.targetAccountId, 'cross-account links checked at Audit read boundary')
    Assert.equal(eventId, query.eventId)
    Assert.equal('feather-admin', query.sourceResource)
    return { ok = true, value = { event = visible and { eventId = eventId } or nil } }
end } }
dofile('../feather-admin/server/services/cases.lua')
local route = routes['feather-admin:cases:link']
route({ caseId = 1, kind = 'audit', recordId = eventId }, nil, 1)
Assert.equal(1, inserts, 'UUID link stored')
visible = false
route({ caseId = 1, kind = 'audit', recordId = eventId }, nil, 1)
Assert.equal(1, inserts, 'hidden or wrong-account event cannot be linked')
allowed = false
route({ caseId = 1, kind = 'audit', recordId = eventId }, nil, 1)
Assert.equal(1, inserts, 'missing Audit permission cannot link')
local sqlText, parameters
DB = { transaction = function(callback) return callback({ query = function(sql, ...)
    sqlText, parameters = sql, table.pack(...); return {}
end, exec = function() end }) end }
dofile('server/repositories/search.lua')
FeatherAuditSearchRepository.Read({ fromEpoch = 1, toEpoch = 2, limit = 25,
    targetAccountId = account, targetCharacterId = eventId, adminAction = 'staff.role.assign' },
    { type = 'character', id = 'actor', sensitive = false })
Assert.truthy(sqlText:find("t.target_type = 'account'", 1, true))
Assert.truthy(sqlText:find("t.target_type = 'character'", 1, true))
Assert.falsy(sqlText:find(account, 1, true), 'identities are parameters')
local _, count = sqlText:gsub('%?', '')
Assert.equal(parameters.n, count)
