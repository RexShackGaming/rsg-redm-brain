local Assert = _G.TestAssert
local routes, events, timers, sent = {}, {}, {}, {}
local canSearch, sensitive, changed = true, false, false
local sourceSession = 'original'
local revokeDuringRead = false
local receivedQuery
FeatherAdmin = { RegisterRPC = function(name, fn) routes[name] = fn end,
    CanUse = function(_, action) return action == 'audit.search' and canSearch or action == 'audit.sensitive.view' and sensitive end }
exports = { ['feather-core'] = { GetSessionContext = function()
    return { ok = true, value = { sessionId = sourceSession, characterId = 'character', accountId = 'account' } }
end }, ['feather-audit'] = { Search = function(_, query)
    receivedQuery = query
    if changed then sourceSession = 'new-session' end
    if revokeDuringRead then canSearch = false end
    return { ok = true, value = { events = {} } }
end } }
TriggerClientEvent = function(_, _, ticket, mode, result) sent[#sent + 1] = result end
dofile('../feather-admin/server/services/framework_audit.lua')
local route = routes['feather-admin:framework-audit:read']
route({ ticket = 1, mode = 'search', query = {} }, nil, 1)
Assert.truthy(sent[1].ok)
canSearch = false
route({ ticket = 2, mode = 'search', query = false }, nil, 1)
Assert.equal('forbidden', sent[2].code, 'authorization before validation')
canSearch, changed = true, true
route({ ticket = 3, mode = 'search', query = {} }, nil, 1)
Assert.equal(2, #sent, 'no response to a replacement session')
changed = false
revokeDuringRead = true
route({ ticket = 4, mode = 'search', query = {} }, nil, 1)
Assert.equal('forbidden', sent[3].code, 'adapter discards content after permission loss')
canSearch = true
revokeDuringRead = false
route({ ticket = 5, mode = 'search', query = { hours = 24, limit = 25 } }, nil, 1)
Assert.equal(86400, receivedQuery.toEpoch - receivedQuery.fromEpoch)
Assert.equal(nil, receivedQuery.hours)
local window = sent[4].value.window
route({ ticket = 6, mode = 'search', query = { hours = 8 } }, nil, 1)
Assert.equal('invalid_request', sent[5].code)
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
SetTimeout = function(_, fn) timers[#timers + 1] = fn end
InMenu = true
AdminUI = { openSequence = 0, CanUse = function() return canSearch end,
    OpenFrameworkAudit = function() AdminUI.currentPage = 'framework_audit'; AdminUI.openSequence = AdminUI.openSequence + 1 end,
    OpenFrameworkAuditDetail = function() AdminUI.currentPage = 'framework_audit_detail'; AdminUI.openSequence = AdminUI.openSequence + 1 end }
Feather = { RPC = { Notify = function() end } }
dofile('../feather-admin/client/services/framework_audit.lua')
local state, result = AdminFrameworkAudit, { ok = true, value = { events = { { eventId = 'row' } }, nextCursor = 'cursor' } }
local oldOs = os
os = nil -- RedM client environment has no os library.
state.Search()
Assert.equal(24, state.query.hours)
result.value.window = window
local first = state.ticket
events['feather-admin:framework-audit:result'](first, 'search', result)
Assert.equal('row', state.rows[1].eventId, 'response survives loading-page render')
Assert.equal(window.fromEpoch, state.query.fromEpoch)
Assert.equal(nil, state.query.hours, 'pagination retains fixed server window')
state.Search()
events['feather-admin:framework-audit:result'](first, 'search', result)
Assert.truthy(state.pending, 'old response ignored')
AdminUI.currentPage = 'elsewhere'
events['feather-admin:framework-audit:result'](state.ticket, 'search', result)
Assert.equal(0, #state.rows, 'navigation cancels cached content')
state.Search()
events['Feather:Character:Logout']()
Assert.equal(nil, state.pending)
Assert.equal(0, #state.rows)
state.Search()
canSearch = false
events['feather-admin:framework-audit:result'](state.ticket, 'search', result)
Assert.equal(0, #state.rows, 'permission loss discards response')
canSearch = true
local pages, navigation = {}, nil
AdminTranslate = function(key) return key end
AdminUI.RegisterPage = function(key) pages[key] = true; return { key = key .. '-generation' } end
AdminUI.OpenPage = function(key) Assert.truthy(pages[key], 'logical page key required'); AdminUI.currentPage = key end
AdminUI.RegisterNavigationItem = function(_, item) navigation = item end
for _, name in ipairs({ 'AddFooter', 'AddFooterButton', 'AddHeader', 'AddArrows', 'AddInput', 'AddButton', 'AddLine', 'AddText' }) do
    AdminUI[name] = function() end
end
dofile('../feather-admin/client/ui/pages/framework_audit.lua')
Assert.equal('audit.search', navigation.permission)
AdminUI.OpenFrameworkAudit()
Assert.equal('framework_audit', AdminUI.currentPage)
state.detail = { eventId = 'fixture', content = { context = { sequence = 7 } } }
AdminUI.OpenFrameworkAuditDetail()
Assert.equal('framework_audit_detail', AdminUI.currentPage)
os = oldOs
