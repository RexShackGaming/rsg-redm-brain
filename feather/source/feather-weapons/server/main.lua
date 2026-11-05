-- WeaponProvenanceService.Start() now calls DB.* (feather-mysql), which requires a yieldable
-- coroutine for every call, not just transactions; this whole startup sequence runs inside
-- CreateThread for that reason. The internal early `return`s below now exit the thread's
-- function body instead of the file chunk, which is equivalent for this sequential flow.
CreateThread(function()
    local function FailStartup(message, details)
        print(("[feather-weapons] startup failed: %s"):format(message))
        if details and Config.DevMode then print(json.encode(details)) end
        error(message)
    end

    local coreResult = CoreAdapter.CheckCapabilities()
    if not coreResult.ok then
        FailStartup(coreResult.error.message, coreResult.error.details)
        return
    end

    local characterResult = CoreAdapter.CheckCharacterCapabilities()
    if not characterResult.ok then
        FailStartup(characterResult.error.message, characterResult.error.details)
        return
    end

    if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true
        or Config.NativeAlphaRuntime~=true
        or not WeaponNativeEnrollment.Validate(Config) then
        FailStartup('native_only_configuration_required: no legacy fallback is available')
        return
    end
    local definitions=DefinitionRegistry.Start()
    if not definitions.ok then FailStartup(definitions.error.message,definitions.error.details); return end
    local readerReady,readerReason=WeaponNativeOwnershipReader.Install()
    if not readerReady then FailStartup(readerReason); return end
    local provenance=WeaponProvenanceService.Start()
    if not provenance.ok then FailStartup(provenance.error.message,provenance.error.details); return end
    WeaponMoveDelivery.Start()
    local installed,reason=WeaponCharacterAmmoInventoryProvider.Install()
    if not installed then FailStartup(reason); return end
    print('[feather-weapons] native access available to all current characters; ownership/session/data gates apply')
    print('[feather-weapons] scoped native-only firearms host ready; no legacy fallback')
end)
