local Assert = _G.TestAssert
local oldConfig, oldExports, oldAdmin, oldDatabase = Config, exports, FeatherAdmin, AdminDatabase
Config, FeatherAdmin = {}, {}
dofile('../feather-admin/configs/permissions.lua')
dofile('../feather-admin/configs/authority_actions.lua')
local callback
AdminDatabase = { OnReady = function(value) callback = value end }
local roles, added = {}, 0
local function eligible(tier, action)
    local required = Config.permissions[action]
    return required == 'moderator' or (tier.precedence >= 2 and required == 'administrator')
        or (tier.precedence >= 3 and required == 'owner')
end
for _, tier in ipairs(Config.authority.roles) do
    local grants = {}
    for action, key in pairs(Config.authorityActions) do
        if action ~= 'audit.search' and action ~= 'audit.sensitive.view' and eligible(tier, action) then
            grants[#grants + 1] = { status = 'active', capabilityKey = key }
        end
    end
    roles[tier.roleKey] = { roleId = tier.roleKey, grants = grants, revision = #grants + 1 }
end
exports = { ['feather-authority'] = {
    AwaitReady = function() return { ok = true } end,
    RegisterCapabilities = function(_, request)
        Assert.equal('admin-authority-capabilities-005', request.requestId)
        Assert.equal(90, #request.capabilities)
        return { ok = true, value = { replayed = true } }
    end,
    CreateRole = function(_, request)
        return { ok = true, value = { roleId = request.roleKey, replayed = true } }
    end,
    ListRoleGrants = function(_, request) return { ok = true, value = roles[request.roleId].grants } end,
    GetRole = function(_, request) return { ok = true, value = roles[request.roleId] } end,
    GrantRoleCapability = function(_, request)
        local role = roles[request.roleId]
        Assert.equal(role.revision, request.expectedRevision)
        role.grants[#role.grants + 1] = { status = 'active', capabilityKey = request.capabilityKey }
        role.revision = role.revision + 1
        added = added + 1
        return { ok = true, value = { roleRevision = role.revision, replayed = false } }
    end
} }
Wait = function() end
dofile('../feather-admin/server/services/authority_catalog.lua')
callback()
Assert.truthy(FeatherAdmin.AuthorityCatalog.ready)
Assert.equal(3, added, 'administrator gets search; owner gets search and sensitive view')
local result = FeatherAdmin.AuthorityCatalog.result
Assert.equal(33, result.moderator)
Assert.equal(67, result.administrator)
Assert.equal(90, result.owner)
Assert.equal(190, result.totalGrants)
callback()
Assert.truthy(FeatherAdmin.AuthorityCatalog.ready)
Assert.equal(3, added, 'second startup must not add duplicate grants')
Config, exports, FeatherAdmin, AdminDatabase = oldConfig, oldExports, oldAdmin, oldDatabase
