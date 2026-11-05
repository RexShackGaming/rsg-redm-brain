WeaponAPI = {}

function WeaponAPI.GetCapabilities()
        local issuance=IssuanceService~=nil and type(IssuanceService.NativeAvailable)=='function'
            and IssuanceService.NativeAvailable()==true
        return {contractVersion=WeaponConstants.ContractVersion,
            ready=Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
                and Config.NativeAlphaRuntime==true
                and WeaponCharacterAmmoInventoryProvider.Status()=='ready',
            definitions=DefinitionRegistry.Counts(),
            features={nativeAlphaFirearms=true,scopedCharacterOnly=false,
                issuance=issuance,secureIssuance=issuance,idempotentIssuance=issuance,
                issuancePayloadBinding=issuance,issuanceRecovery=issuance,
                legacyGameplay=false,equip=false,ammunitionManagement=false,repair=false,
                attachmentTransactions=false,productionReady=false,
                evidenceHolds=WeaponEvidenceService~=nil and WeaponEvidenceService.NativeAvailable~=nil
                    and WeaponEvidenceService.NativeAvailable()==true
                    and WeaponCharacterAmmoInventoryProvider.Status()=='ready',destruction=false,
                administrativeHoldGuards=WeaponCharacterAmmoInventoryProvider.Status()=='ready',
                ownershipTransitionEvents=WeaponNativeOwnershipReader~=nil and WeaponNativeOwnershipReader.IsReady()==true
                    and WeaponProvenanceService.IsReady()==true,
                durableProvenance=WeaponProvenanceService.IsReady()==true,
                serialInspection=WeaponProvenanceService.IsReady()==true}}
end

function WeaponAPI.GetDefinition(kind, id)
    return DefinitionRegistry.Get(kind, id)
end

function WeaponAPI.ListDefinitions(kind)
    return DefinitionRegistry.List(kind)
end

function WeaponAPI.ListCompatibleAttachments(weaponId)
    return DefinitionRegistry.ListCompatibleAttachments(weaponId)
end

function WeaponAPI.IssueWeapon(request, context, invokingResource)
    context = type(context) == "table" and context or {}
    context.resource = invokingResource or GetInvokingResource()
    return IssuanceService.Issue(context, request, context.resource)
end

function WeaponAPI.DestroyWeapon(request, context, invokingResource)
    return WeaponOwnershipService.Destroy(context, request, invokingResource)
end

function WeaponAPI.InspectWeaponHistory(request, context, invokingResource)
    return WeaponProvenanceService.Inspect(request, context, invokingResource)
end

function WeaponAPI.HoldEvidence(request, context, resource)
    return WeaponEvidenceService.Hold(context, request, resource)
end

function WeaponAPI.ReleaseEvidence(request, context, resource)
    return WeaponEvidenceService.Release(context, request, resource)
end

exports("initiate", function()
    return {
        GetCapabilities = WeaponAPI.GetCapabilities,
        Definitions = { Get = WeaponAPI.GetDefinition, List = WeaponAPI.ListDefinitions, ListCompatibleAttachments = WeaponAPI.ListCompatibleAttachments },
        Metadata = { Build = WeaponMetadata.Build, Validate = WeaponMetadata.Validate },
        Inspection = {
            History = function(request, context)
                return WeaponAPI.InspectWeaponHistory(request, context, GetInvokingResource())
            end
        },
        Issuance = { Issue = function(request, context)
            return WeaponAPI.IssueWeapon(request, context, GetInvokingResource())
        end },
        Ownership = {
            Destroy = function(request, context)
                local invokingResource = GetInvokingResource()
                return WeaponAPI.DestroyWeapon(request, context, invokingResource)
            end,
            HoldEvidence = function(request, context)
                return WeaponAPI.HoldEvidence(request, context, GetInvokingResource())
            end,
            ReleaseEvidence = function(request, context)
                return WeaponAPI.ReleaseEvidence(request, context, GetInvokingResource())
            end
        }
    }
end)

-- Stable cross-resource issuance entry point. Consumers should use this
-- named export instead of relying on nested functions surviving Cfx's API
-- table boundary.
exports("IssueWeapon", function(request, context)
    return WeaponAPI.IssueWeapon(request, context, GetInvokingResource())
end)

exports("DestroyWeapon", function(request, context)
    local invokingResource = GetInvokingResource()
    return WeaponAPI.DestroyWeapon(request, context, invokingResource)
end)

exports("InspectWeaponHistory", function(request, context)
    return WeaponAPI.InspectWeaponHistory(request, context, GetInvokingResource())
end)

exports("HoldWeaponEvidence", function(request, context)
    return WeaponAPI.HoldEvidence(request, context, GetInvokingResource())
end)

exports("ReleaseWeaponEvidence", function(request, context)
    return WeaponAPI.ReleaseEvidence(request, context, GetInvokingResource())
end)
