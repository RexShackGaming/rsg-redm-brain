local function Register(name, handler)
    exports(name, function(...)
        local called, result = pcall(handler, ...)
        if not called then
            print(('[feather-access] event=export.failed operation=%s'):format(name))
            return Access.Err('internal_error', 'Access operation failed.')
        end
        return result
    end)
end

Register('GetCapabilities', Access.GetCapabilities)
Register('GetHealth', Access.GetHealth)
Register('AwaitReady', Access.AwaitReady)

local function ProviderExport(name, handler)
    Register(name, function(request)
        -- Capture caller before yielding. Payload fields never establish ownership.
        local caller = GetInvokingResource()
        return handler(request, caller)
    end)
end

ProviderExport('RegisterTargetProvider', Access.Providers.RegisterTarget)
ProviderExport('UnregisterTargetProvider', Access.Providers.UnregisterTarget)
ProviderExport('RegisterMembershipProvider', Access.Providers.RegisterMembership)
ProviderExport('UnregisterMembershipProvider', Access.Providers.UnregisterMembership)
ProviderExport('ResolveTargetContext', Access.Providers.ResolveTarget)
ProviderExport('ResolveMembershipContext', Access.Providers.ResolveMembership)
ProviderExport('GrantCapability', function(request, caller) return Access.InventoryFence.Mutate(Access.Grants.Grant, request, caller) end)
ProviderExport('RevokeGrant', function(request, caller) return Access.InventoryFence.Mutate(Access.Grants.Revoke, request, caller) end)
ProviderExport('CheckCapability', Access.Grants.Check)
ProviderExport('ListTargetGrants', Access.Grants.ListTarget)
ProviderExport('ListGranteeGrants', Access.Grants.ListGrantee)
ProviderExport('FindOperation', Access.Grants.Find)
ProviderExport('PreparePreservation', function(request,caller)return Access.InventoryFence.Mutate(Access.Preservation.Prepare,request,caller)end)
ProviderExport('ResolvePreservationManifest', Access.Preservation.Resolve)
ProviderExport('AdoptPreservation', function(request,caller)return Access.InventoryFence.Mutate(Access.Preservation.Adopt,request,caller)end)
ProviderExport('AuditFixtureControl', Access.Audit.Fixture)
ProviderExport('EmploymentFixtureScope', Access.Employment.Fixture)
Register('WithInventoryFence', function(callback)
    local caller = GetInvokingResource()
    return Access.InventoryFence.Run(callback, caller)
end)
Register('ValidateInventoryFence', function(token)
    return Access.InventoryFence.Valid(token, GetInvokingResource())
end)
