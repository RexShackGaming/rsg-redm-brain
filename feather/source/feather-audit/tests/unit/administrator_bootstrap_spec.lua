local Assert = _G.TestAssert
local oldAdmin, oldExports, oldConfig, oldPrint, oldAudit = FeatherAdmin, exports, Config, print, AdminAudit
local commands, messages, writes, refreshes, audits = {}, {}, 0, 0, 0
local precedence, loaded = 0, true
Config = { authority = { roles = {
    { key = 'administrator', roleKey = 'staff.admin.administrator', label = 'Administrator', precedence = 2 }
} } }
FeatherAdmin = {
    RegisterRPC = function() end,
    Identity = {
        Resolve = function() return loaded and { accountId = 'account', characterId = 'separate-character' } or nil end,
        GetStaff = function() return { roleKey = 'staff.admin.owner', roleName = 'Owner', rolePrecedence = precedence } end
    },
    IsAuthorized = function() return true end,
    GetPermissions = function() return {} end
}
RegisterCommand = function(name, callback) commands[name] = callback end
print = function(message) messages[#messages + 1] = message end
TriggerClientEvent = function() refreshes = refreshes + 1 end
AdminAudit = { RecordTarget = function(source, action, target)
    Assert.equal(0, source)
    Assert.equal('staff.administrator.bootstrap', action)
    Assert.equal('separate-character', target.characterId)
    audits = audits + 1
end }
exports = { ['feather-authority'] = {
    FindRoleByKey = function(_, request)
        Assert.equal('staff.admin.administrator', request.roleKey)
        return { ok = true, value = { roleId = 'administrator-role', revision = 66 } }
    end,
    ReplaceOwnedStaffAssignment = function(_, request)
        Assert.equal('character', request.subjectType)
        Assert.equal('separate-character', request.subjectId)
        Assert.equal('administrator-role', request.roleId)
        Assert.equal(66, request.expectedRoleRevision)
        Assert.equal('feather_admin.administrator_bootstrap', request.reasonCode)
        writes = writes + 1
        return { ok = true, value = { assignmentId = 'new-assignment', replayed = false } }
    end
} }
dofile('../feather-admin/server/services/staff_management.lua')
commands.AdminBootstrapAdministrator(1, { '1', 'request-1' })
Assert.equal(0, writes, 'players cannot invoke bootstrap')
precedence = 3
commands.AdminBootstrapAdministrator(0, { '1', 'request-1' })
Assert.equal(0, writes, 'existing Owner must not be replaced')
Assert.truthy(messages[#messages]:find('already has Owner', 1, true))
precedence = 0
commands.AdminBootstrapAdministrator(0, { '1', 'bad request' })
Assert.equal(0, writes)
loaded = false
commands.AdminBootstrapAdministrator(0, { '1', 'request-1' })
Assert.equal(0, writes)
loaded = true
commands.AdminBootstrapAdministrator(0, { '1', 'request-1' })
Assert.equal(1, writes)
Assert.equal(2, refreshes)
Assert.equal(1, audits)
Assert.truthy(messages[#messages]:find('PASS character=separate-character', 1, true))
local roleKey, paused, failRestore = 'staff.admin.administrator', false, false
FeatherAdmin.Identity.GetStaff = function() return roleKey ~= 'player' and {
    roleKey = roleKey, roleName = 'Administrator', rolePrecedence = 2 } or nil end
exports['feather-core'] = { GetSessionContext = function()
    return { ok = true, value = { sessionId = 'same-session', characterId = 'separate-character' } }
end }
exports['feather-audit'] = { IsDevelopmentReadPaused = function() return paused end }
GetPlayers = function() return { '1' } end
AdminAudit.RecordTarget = function() end
exports['feather-authority'].ReplaceOwnedStaffAssignment = function(_, request)
    if request.roleId and failRestore then return { ok = false } end
    roleKey = request.roleId and 'staff.admin.administrator' or 'player'
    writes = writes + 1
    return { ok = true, value = {} }
end
commands.AdminAuditRevokeTestRole(1, { '1', 'test' })
commands.AdminAuditRevokeTestRole(0, { '1', 'test' })
Assert.equal(1, writes, 'no player invocation or revocation outside a pause')
paused = true
roleKey = 'staff.admin.owner'
commands.AdminAuditRevokeTestRole(0, { '1', 'test' })
Assert.equal(1, writes, 'Owner protected')
roleKey = 'staff.admin.administrator'
commands.AdminAuditRevokeTestRole(0, { '1', 'test' })
Assert.equal(2, writes)
Assert.equal('player', roleKey)
failRestore = true
commands.AdminAuditRestoreTestRole(0, { 'test' })
Assert.equal('player', roleKey)
failRestore = false
commands.AdminAuditRestoreTestRole(0, { 'test' })
Assert.equal(3, writes)
Assert.equal('staff.admin.administrator', roleKey)
Assert.truthy(messages[#messages]:find('sameSession=true', 1, true))
commands.AdminAuditRestoreTestRole(0, { 'test' })
Assert.equal(3, writes, 'repeat restore does not write')
Config.authority.roles[#Config.authority.roles + 1] = {
    roleKey = 'staff.admin.owner', label = 'Owner', precedence = 3 }
exports['feather-authority'].FindRoleByKey = function(_, request)
    return { ok = true, value = { roleId = request.roleKey, revision = 1 } }
end
exports['feather-authority'].ReplaceOwnedStaffAssignment = function(_, request)
    writes = writes + 1
    roleKey = request.roleId or 'player'
    return { ok = true, value = {} }
end
FeatherAdmin.CanUse = function(_, action)
    return action == 'audit.search' and roleKey ~= 'player'
        or action == 'audit.sensitive.view' and roleKey == 'staff.admin.owner'
end
roleKey = 'staff.admin.owner'
paused = false
commands.AdminAuditDowngradeTestOwner(0, { '1', 'owner-test' })
Assert.equal(3, writes, 'Owner downgrade requires actual pause')
paused = true
commands.AdminAuditDowngradeTestOwner(1, { '1', 'owner-test' })
Assert.equal(3, writes, 'players cannot downgrade Owner')
commands.AdminAuditDowngradeTestOwner(0, { '1', 'owner-test' })
Assert.equal('staff.admin.administrator', roleKey)
Assert.truthy(messages[#messages]:find('PASS searchGranted=true sensitiveGranted=false sameSession=true', 1, true))
commands.AdminAuditRestoreTestRole(0, { 'owner-test' })
Assert.equal('staff.admin.owner', roleKey)
Assert.truthy(messages[#messages]:find('restoredRole=staff.admin.owner', 1, true))
FeatherAdmin, exports, Config, print, AdminAudit = oldAdmin, oldExports, oldConfig, oldPrint, oldAudit
