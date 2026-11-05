-- Native-only item metadata. Old clip/reserve documents are rejected, not imported.
WeaponMetadata = {}
local function throwable(definition) return definition.id=='throwable_tomahawk' end
local function utilityEnabled(definition)
    return WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Enabled() and WeaponNativeUtilityItem
        and WeaponNativeUtilityCatalog.Resolve(definition)~=nil
end
local function throwableEnabled()
    return WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled() and WeaponNativeThrowableItem
end
local function melee(definition)
    return definition.id=='melee_knife' or (WeaponNativeMeleeCatalog and WeaponNativeMeleeCatalog.Resolve(definition)~=nil)
end
local function meleeEnabled(definition)
    return WeaponNativeKnife and ((definition.id=='melee_knife' and WeaponNativeKnife.Enabled())
        or (WeaponNativeMeleeCatalog and WeaponNativeMeleeCatalog.Enabled() and WeaponNativeMeleeCatalog.Resolve(definition)~=nil))
end
function WeaponMetadata.Build(definition, options)
    options=type(options)=='table' and options or {}
    if options.loadedAmmo~=nil or options.reserveAmmo~=nil or options.chambered~=nil then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Item-owned ammunition fields are not supported')
    end
    if definition.slot=='utility' then
        if not utilityEnabled(definition) or options.ammo~=nil or options.ammunitionType~=nil
            or options.maintenance~=nil or options.attachments~=nil or options.cosmetics~=nil then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Native utility disabled or unsupported item fields')
        end
        local checked,why=WeaponNativeUtilityItem.Build(definition,{serialNumber=options.serialNumber,
            condition=options.condition,quality=options.quality,provenance=options.provenance,
            flags={stolen=options.stolen==true,evidence=options.evidence==true,disabled=options.disabled==true}})
        if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,why) end
        return WeaponResult.Ok(checked)
    end
    if throwable(definition) then
        if not throwableEnabled() or options.ammunitionType~=nil or options.ammo~=nil
            or options.maintenance~=nil or options.attachments~=nil or options.cosmetics~=nil then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Native throwable disabled or unsupported item fields')
        end
        local checked,why=WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber=options.serialNumber,
            condition=options.condition,quality=options.quality,provenance=options.provenance,
            flags={stolen=options.stolen==true,evidence=options.evidence==true,disabled=options.disabled==true}})
        if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,why) end
        return WeaponResult.Ok(checked)
    end
    if melee(definition) then
        if not meleeEnabled(definition) then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Native knife support is disabled')
        end
        if options.ammunitionType~=nil or options.maintenance~=nil or options.ammo~=nil
            or options.attachments~=nil or options.cosmetics~=nil then
            return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Knife ammunition/maintenance/customization is not supported')
        end
        local checked,why=WeaponNativeKnife.Build(definition,{serialNumber=options.serialNumber,condition=options.condition,
            quality=options.quality,provenance=options.provenance,
            flags={stolen=options.stolen==true,evidence=options.evidence==true,disabled=options.disabled==true}})
        if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,why) end
        return WeaponResult.Ok(checked)
    end
    local metadata={
        schemaVersion=WeaponConstants.MetadataSchemaVersion,weaponDefinitionId=definition.id,
        serialNumber=options.serialNumber,condition=options.condition or 100,quality=options.quality or 100,
        maintenance=options.maintenance or {degradation=0.0,permanentDegradation=0.0,damage=0.0,dirt=0.0,soot=0.0},
        ammo={ownership='character',type=options.ammunitionType or definition.ammunitionType},
        attachments=options.attachments or {},cosmetics=options.cosmetics or {},
        flags={stolen=options.stolen==true,evidence=options.evidence==true,disabled=options.disabled==true},
        provenance=options.provenance or {}
    }
    return WeaponMetadata.Validate(metadata,definition)
end
function WeaponMetadata.Validate(metadata,definition,correlationId)
    if Config.CharacterAmmunitionEnabled~=true or Config.CharacterAmmoTransportEnabled~=true then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Native firearm metadata is disabled',nil,correlationId)
    end
    if definition.slot=='utility' then
        if not utilityEnabled(definition) then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Native utility support is disabled') end
        local checked,why=WeaponNativeUtilityItem.Validate(metadata,definition)
        if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,why,nil,correlationId) end
        return WeaponResult.Ok(checked,correlationId)
    end
    if throwable(definition) then
        if not throwableEnabled() then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Native throwable support is disabled') end
        local checked,why=WeaponNativeThrowableItem.Validate(metadata,WeaponDefinitionCatalog)
        if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,why,nil,correlationId) end
        return WeaponResult.Ok(checked,correlationId)
    end
    if melee(definition) then
        if not meleeEnabled(definition) then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,'Native melee support is disabled') end
        local checked,why=WeaponNativeKnife.Validate(metadata,definition)
        if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,why,nil,correlationId) end
        return WeaponResult.Ok(checked,correlationId)
    end
    local checked,reason,errors=WeaponCharacterAmmoItem.Validate(metadata,definition)
    if not checked then return WeaponResult.Error(WeaponErrors.ITEM_INVALID,reason,errors,correlationId) end
    local attachments=DefinitionRegistry.ValidateAttachmentSet(definition.id,checked.attachments)
    if not attachments.ok then return attachments end
    return WeaponResult.Ok(checked,correlationId)
end
