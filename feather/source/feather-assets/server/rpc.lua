AssetRoutes = {}
local Ok, Err = Assets.Ok, Assets.Err

-- Players see their own assets, not manager, provenance or metadata internals.
local function Public(asset)
    return {
        assetId = asset.assetId,
        assetType = asset.assetType,
        modelKey = asset.modelKey,
        status = asset.status
    }
end

-- Client-callable routes are read-only. Every mutation stays a trusted server
-- export; the character is always derived from the caller's Core session.
local routes = {
    {
        name = 'assets.owned.list.v1',
        handler = function(payload, source)
            if not Assets.IsReady() then
                return Err('not_ready', 'Assets is not ready.')
            end
            local session = exports['feather-core']:GetSessionContext(source)
            if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
                or not Assets.Uuid(session.value.characterId) then
                return Err('character_required', 'An active character is required.')
            end
            local listed = AssetRecords.QueryByHolder('character', session.value.characterId:lower(), {
                assetType = payload.assetType,
                includeMetadata = false,
                limit = Config.Limits.maxClientAssets
            })
            if not listed.ok then
                return listed
            end
            local assets = {}
            for _, asset in ipairs(listed.value.items) do
                assets[#assets + 1] = Public(asset)
            end
            return Ok({ assets = assets })
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
                    return false, 'assets.owned.list.v1 requires a table payload.'
                end
                for field in pairs(payload) do
                    if field ~= 'assetType' then
                        return false, 'assets.owned.list.v1 accepts only assetType.'
                    end
                end
                if payload.assetType ~= nil and not Config.AssetTypes[payload.assetType] then
                    return false, 'assets.owned.list.v1 asset type is not configured.'
                end
                return true
            end
        }
    }
}

function AssetRoutes.Register()
    for _, route in ipairs(routes) do
        local result = exports['feather-core']:RegisterRpc(route.name, route.handler, route.options)
        if type(result) ~= 'table' or not result.ok then
            return Err('dependency_unavailable', 'Could not register assets RPC route.', {
                route = route.name,
                code = type(result) == 'table' and result.code or 'invalid_result'
            })
        end
    end
    return Ok(#routes)
end
