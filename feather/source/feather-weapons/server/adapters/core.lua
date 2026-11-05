CoreAdapter = {}

local function IsUuid(value)
    return type(value) == "string" and value:match(
        "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
    ) ~= nil
end

function CoreAdapter.NormalizeCharacterId(value)
    if IsUuid(value) then return value:lower() end
    return nil
end

function CoreAdapter.CheckCapabilities()
    local ready = exports["feather-core"]:AwaitReady(10000)
    if type(ready) ~= "table" or ready.ok ~= true then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            "feather-core is not ready", ready and ready.error and ready.error.details)
    end

    local reported = exports["feather-core"]:GetCapabilities()
    if type(reported) ~= "table" or reported.ok ~= true or type(reported.value) ~= "table" then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            "feather-core returned an invalid capability contract")
    end

    local capabilities = reported.value
    local contractVersion = tonumber(capabilities.contract) or 0
    if contractVersion < Config.RequiredCoreContract then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE, "feather-core contract is too old", {
            required = Config.RequiredCoreContract,
            actual = capabilities.contract
        })
    end

    local features = type(capabilities.features) == "table" and capabilities.features or nil
    if not features or (tonumber(features.sessions) or 0) < 1 then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE, "feather-core session capability is unavailable")
    end
    return WeaponResult.Ok(capabilities)
end

function CoreAdapter.CheckCharacterCapabilities()
    if GetResourceState("feather-character") ~= "started" then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            "feather-character is not started")
    end

    local deadline = GetGameTimer() + math.max(0,
        math.floor(tonumber(Config.CharacterReadyTimeoutMs) or 30000))
    local healthCalled, health
    repeat
        healthCalled, health = pcall(function()
            return exports["feather-character"]:GetHealth()
        end)
        if healthCalled and type(health) == "table" and health.ok == true
            and type(health.value) == "table" and health.value.state == "ready" then
            break
        end
        if healthCalled and type(health) == "table" and type(health.value) == "table"
            and health.value.state == "failed" then
            break
        end
        Wait(100)
    until GetGameTimer() >= deadline

    if not healthCalled or type(health) ~= "table" or health.ok ~= true
        or type(health.value) ~= "table" or health.value.state ~= "ready" then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            "feather-character is not ready", {
                state = type(health) == "table" and type(health.value) == "table"
                    and health.value.state or nil
            })
    end

    local capabilitiesCalled, reported = pcall(function()
        return exports["feather-character"]:GetCapabilities()
    end)
    if not capabilitiesCalled or type(reported) ~= "table" or reported.ok ~= true
        or type(reported.value) ~= "table" then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            "feather-character returned an invalid capability contract")
    end

    local capabilities = reported.value
    local requiredContract = tonumber(Config.RequiredCharacterContract) or 1
    local features = type(capabilities.features) == "table" and capabilities.features or {}
    if (tonumber(capabilities.contract) or 0) < requiredContract
        or (tonumber(features.profiles) or 0) < 1
        or (tonumber(features.activation) or 0) < 1
        or (tonumber(features.spawn) or 0) < 1 then
        return WeaponResult.Error(WeaponErrors.DEPENDENCY_UNAVAILABLE,
            "feather-character contract is incompatible", {
                required = requiredContract,
                actual = capabilities.contract,
                features = features
            })
    end

    return WeaponResult.Ok(capabilities)
end

function CoreAdapter.ResolveSession(source)
    local result = exports["feather-core"]:GetSessionContext(tonumber(source))
    if type(result) ~= "table" or result.ok ~= true or type(result.value) ~= "table" then
        return WeaponResult.Error(WeaponErrors.CHARACTER_REQUIRED, "A current character session is required")
    end

    local session = result.value
    local characterId = CoreAdapter.NormalizeCharacterId(session.characterId)
    if not characterId then
        return WeaponResult.Error(WeaponErrors.CHARACTER_REQUIRED, "The current character identity is unsupported")
    end

    session.characterId = characterId
    return WeaponResult.Ok(session)
end

function CoreAdapter.IsSessionCurrent(source, sessionId, characterId)
    characterId = CoreAdapter.NormalizeCharacterId(characterId)
    if not characterId then return false end
    return exports["feather-core"]:IsSessionCurrent(tonumber(source), sessionId, characterId) == true
end
