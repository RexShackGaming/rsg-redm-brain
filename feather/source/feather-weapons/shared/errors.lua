WeaponErrors = {
    INVALID_DEFINITION = "WEAPON_INVALID_DEFINITION",
    DEFINITION_NOT_FOUND = "WEAPON_DEFINITION_NOT_FOUND",
    DEPENDENCY_UNAVAILABLE = "WEAPON_DEPENDENCY_UNAVAILABLE",
    CHARACTER_REQUIRED = "WEAPON_CHARACTER_REQUIRED",
    SESSION_EXPIRED = "WEAPON_SESSION_EXPIRED",
    INVENTORY_UNAVAILABLE = "WEAPON_INVENTORY_UNAVAILABLE",
    ITEM_NOT_FOUND = "WEAPON_ITEM_NOT_FOUND",
    ITEM_NOT_OWNED = "WEAPON_ITEM_NOT_OWNED",
    ITEM_INVALID = "WEAPON_ITEM_INVALID",
    CONDITION_BROKEN = "WEAPON_CONDITION_BROKEN",
    OPERATION_CONFLICT = "WEAPON_OPERATION_CONFLICT",
    AUTHORIZATION_INVALID = "WEAPON_AUTHORIZATION_INVALID",
    NOT_EQUIPPED = "WEAPON_NOT_EQUIPPED",
    NOT_IMPLEMENTED = "WEAPON_NOT_IMPLEMENTED"
}

WeaponResult = {}

function WeaponResult.Ok(value, correlationId)
    return { ok = true, value = value, correlationId = correlationId }
end

function WeaponResult.Error(code, message, details, correlationId)
    return {
        ok = false,
        error = { code = code, message = message, details = details or {} },
        correlationId = correlationId
    }
end
