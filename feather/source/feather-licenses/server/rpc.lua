LicenseRoutes = {}
local Ok, Err = Licenses.Ok, Licenses.Err

-- Players see their own licenses, not issuer internals or scope.
local function Public(license)
    return {
        licenseId = license.licenseId,
        licenseKey = license.licenseKey,
        label = license.label,
        status = license.status,
        valid = license.valid,
        expired = license.expired,
        issuedAt = license.issuedAt,
        expiresAt = license.expiresAt
    }
end

-- Client-callable routes are read-only. Every mutation stays a trusted server
-- export; the character is always derived from the caller's Core session.
local routes = {
    {
        name = 'licenses.held.list.v1',
        handler = function(payload, source)
            if not Licenses.IsReady() then
                return Err('not_ready', 'Licenses is not ready.')
            end
            local session = exports['feather-core']:GetSessionContext(source)
            if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
                or not Licenses.Uuid(session.value.characterId) then
                return Err('character_required', 'An active character is required.')
            end
            local listed = LicenseRecords.QueryByHolder('character', session.value.characterId:lower(), {
                licenseKey = payload.licenseKey,
                includeRevoked = false,
                includeScope = false,
                limit = Config.Limits.maxClientLicenses
            })
            if not listed.ok then
                return listed
            end
            local licenses = {}
            for _, license in ipairs(listed.value.items) do
                licenses[#licenses + 1] = Public(license)
            end
            return Ok({ licenses = licenses })
        end,
        options = {
            contract = 1,
            direction = 'client_to_server',
            requireCharacter = true,
            windowMs = 5000,
            maxCalls = 5,
            maxPayloadBytes = 128,
            maxDepth = 2,
            maxNodes = 4,
            validatePayload = function(payload)
                if type(payload) ~= 'table' then
                    return false, 'licenses.held.list.v1 requires a table payload.'
                end
                for field in pairs(payload) do
                    if field ~= 'licenseKey' then
                        return false, 'licenses.held.list.v1 accepts only licenseKey.'
                    end
                end
                if payload.licenseKey ~= nil and not Licenses.Key(payload.licenseKey, 48) then
                    return false, 'licenses.held.list.v1 license key is invalid.'
                end
                return true
            end
        }
    }
}

function LicenseRoutes.Register()
    for _, route in ipairs(routes) do
        local result = exports['feather-core']:RegisterRpc(route.name, route.handler, route.options)
        if type(result) ~= 'table' or not result.ok then
            return Err('dependency_unavailable', 'Could not register licenses RPC route.', {
                route = route.name,
                code = type(result) == 'table' and result.code or 'invalid_result'
            })
        end
    end
    return Ok(#routes)
end
