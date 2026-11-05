-- Admission is available to every character. Callers must still authenticate
-- Core identity and enforce runtime, session, epoch and item ownership gates.
-- Historical test allowlist fields are ignored; admission never grants/migrates data.
WeaponNativeEnrollment={}
function WeaponNativeEnrollment.Validate(config)
    if type(config)~='table' then return nil,'native_enrollment_config_required' end
    return {},nil,{mode='all'}
end
function WeaponNativeEnrollment.Allows(config,characterId)
    -- Core/Inventory independently normalize the authoritative character UUID.
    -- This layer only rejects unusable identities; it is no longer an ACL.
    return type(config)=='table' and type(characterId)=='string'
        and #characterId>0 and #characterId<=128
        and characterId:match('^[%w_-]+$')~=nil and characterId~='*'
end

WeaponConstants = {
    ContractVersion = 1,
    MetadataSchemaVersion = 2,
    DefinitionKinds = {
        weapon = true,
        ammunition = true,
        attachment = true
    },
    LoadoutSlots = {
        "utility", "utility_secondary", "utility_tertiary", "utility_quaternary", "utility_quinary", "utility_senary","utility_septenary", "utility_octonary", "primary", "offhand", "shoulder", "back",
        "melee", "melee_secondary", "melee_tertiary", "melee_quaternary", "melee_quinary",
        "throwable", "throwable_secondary", "throwable_tertiary", "throwable_quaternary", "throwable_quinary", "throwable_senary", "throwable_septenary", "throwable_octonary", "throwable_nonary", "throwable_denary"
    },
    UtilitySlots = { utility = true, utility_secondary = true, utility_tertiary = true, utility_quaternary = true, utility_quinary = true, utility_senary = true, utility_septenary = true, utility_octonary = true },
    SidearmSlots = { primary = true, offhand = true },
    LonggunSlots = { shoulder = true, back = true },
    MeleeSlots = {
        melee = true, melee_secondary = true, melee_tertiary = true, melee_quaternary = true, melee_quinary = true
    },
    ThrowableSlots = { throwable = true, throwable_secondary = true, throwable_tertiary = true, throwable_quaternary = true, throwable_quinary = true, throwable_senary = true, throwable_septenary = true, throwable_octonary = true, throwable_nonary = true, throwable_denary = true },
    WeaponSlots = {
        utility = true,
        melee = true,
        sidearm = true,
        longgun = true,
        throwable = true
    },
    AttachmentSlots = {
        barrel = true,
        grip = true,
        magazine = true,
        muzzle = true,
        sight = true,
        stock = true,
        wrap = true
    }
}
