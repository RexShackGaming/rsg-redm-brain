FeatherNativeMaintenance = {}

local preferredPoints = {
    primary = { 1, 2, 0, 3 },
    offhand = { 0, 3, 1, 2 },
    shoulder = { 10, 9 },
    back = { 9, 10 },
    melee = { 0, 1, 2, 3 },
    melee_secondary = { 0, 1, 2, 3 },
    melee_tertiary = { 0, 1, 2, 3 },
    melee_quaternary = { 0, 1, 2, 3 },
    melee_quinary = { 0, 1, 2, 3 },
    utility = { 0, 1, 2, 3 },
    utility_secondary = { 0, 1, 2, 3 },
    utility_tertiary = { 0, 1, 2, 3 },
    utility_quaternary = { 0, 1, 2, 3 },
    utility_quinary = { 0, 1, 2, 3 },
    utility_senary = { 0, 1, 2, 3 },
    utility_septenary = { 0, 1, 2, 3 },
    utility_octonary = { 0, 1, 2, 3 },
    throwable = { 0, 1, 2, 3 },
    throwable_secondary = { 0, 1, 2, 3 },
    throwable_tertiary = { 0, 1, 2, 3 },
    throwable_quaternary = { 0, 1, 2, 3 },
    throwable_quinary = { 0, 1, 2, 3 },
    throwable_senary = { 0, 1, 2, 3 },
    throwable_septenary = { 0, 1, 2, 3 },
    throwable_octonary = { 0, 1, 2, 3 },
    throwable_nonary = { 0, 1, 2, 3 },
    throwable_denary = { 0, 1, 2, 3 }
}

local function NativeTrue(value)
    return value == true or value == 1
end

local function Unit(value)
    return math.max(0.0, math.min(1.0, tonumber(value) or 0.0))
end

local function ObjectAt(ped, point, weaponHash)
    local present, current = GetCurrentPedWeapon(ped, true, point, false)
    if not NativeTrue(present) or current ~= weaponHash then return nil end
    local entity = GetCurrentPedWeaponEntityIndex(ped, point)
    if not entity or entity == 0 then return nil end
    local object = GetObjectIndexFromEntityIndex(entity)
    return object and object ~= 0 and object or nil
end

function FeatherNativeMaintenance.ResolveObject(ped, slot, nativeWeaponName)
    if not ped or ped == 0 or type(nativeWeaponName) ~= 'string' then return nil end
    local hash = joaat(nativeWeaponName)
    for _, point in ipairs(preferredPoints[slot] or {}) do
        local object = ObjectAt(ped, point, hash)
        if object then return object, point end
    end
    for point = 0, 29 do
        local object = ObjectAt(ped, point, hash)
        if object then return object, point end
    end
    return nil
end

function FeatherNativeMaintenance.Read(ped, slot, state)
    local object, point = FeatherNativeMaintenance.ResolveObject(
        ped, slot, state and state.nativeWeaponName)
    if not object then return nil end
    return {
        degradation = Unit(GetWeaponDegradation(object)),
        permanentDegradation = Unit(GetWeaponPermanentDegradation(object)),
        damage = Unit(GetWeaponDamage(object)),
        dirt = Unit(GetWeaponDirt(object)),
        soot = Unit(GetWeaponSoot(object)),
        attachPoint = point
    }
end

function FeatherNativeMaintenance.Apply(ped, slot, state)
    local object = FeatherNativeMaintenance.ResolveObject(
        ped, slot, state and state.nativeWeaponName)
    local value = state and state.maintenance
    if not object or type(value) ~= 'table' then return false end
    local permanent = Unit(value.permanentDegradation)
    SetWeaponDegradation(object, math.max(permanent, Unit(value.degradation)))
    SetWeaponDamage(object, math.max(permanent, Unit(value.damage)), false)
    SetWeaponDirt(object, Unit(value.dirt), false)
    SetWeaponSoot(object, Unit(value.soot), false)
    return true
end
