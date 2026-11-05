-- Feather-owned adapter for weapon instances that must be addressed by native
-- inventory GUID instead of weapon hash. Keep third-party inventory code out of
-- this module; its behavior is defined by RedM natives and Feather's tests.
FeatherGuidWeapons = {}

local INVENTORY_ID = 1
local REMOVE_REASON = joaat('REMOVE_REASON_DEFAULT') -- 4152224061

local function NativeTrue(value)
    return value == true or value == 1
end

local function Buffer(length)
    return string.rep('\0', math.max(41, length))
end

local function Failure(code, message)
    return { ok = false, code = code, message = message }
end

function FeatherGuidWeapons.NewBuffer(length)
    return Buffer(length)
end

function FeatherGuidWeapons.ResolveGuid(inventoryId, parentGuid, category, slotId)
    local guid = Buffer(8 * 13)
    local resolved = Citizen.InvokeNative(0x886DFD3E185C8A89, -- InventoryGetGuidFromItemid
        inventoryId,
        parentGuid,
        category,
        slotId,
        guid
    )
    return NativeTrue(resolved) and guid or nil
end

local function CarriedWeaponsGuid()
    local character = FeatherGuidWeapons.ResolveGuid(INVENTORY_ID, nil, joaat('CHARACTER'), 0xA1212100)
    if not character then return nil end

    return FeatherGuidWeapons.ResolveGuid(INVENTORY_ID, character,
        joaat('CARRIED_WEAPONS'), joaat('SLOTID_CARRIED_WEAPONS'))
end

local function RemoveRecord(record)
    if not record or not record.guid then return false end

    return NativeTrue(Citizen.InvokeNative(0x3E4E811480B3AE79, -- InventoryRemoveInventoryItemWithGuid
        record.inventoryId,
        record.guid,
        1,
        REMOVE_REASON
    ))
end

-- Address an existing different-hash weapon without creating or moving native
-- inventory entries. Production rejects matching models before this is called.
function FeatherGuidWeapons.ResolveExisting(weaponName)
    local parent = CarriedWeaponsGuid()
    if not parent then return nil end
    local selectedGuid, selectedSlot
    for slot = 0, 1 do
        local guid = FeatherGuidWeapons.ResolveGuid(INVENTORY_ID, parent,
            joaat(weaponName), joaat(('SLOTID_WEAPON_%d'):format(slot)))
        if guid then
            if selectedGuid then return nil end
            selectedGuid = guid
            selectedSlot = slot
        end
    end
    if not selectedGuid then return nil end
    return {
        inventoryId = INVENTORY_ID,
        guid = selectedGuid,
        slot = selectedSlot,
        weaponName = weaponName
    }
end

function FeatherGuidWeapons.SelectExistingAmmo(ped, weaponName, ammoName)
    local record = FeatherGuidWeapons.ResolveExisting(weaponName)
    if not record then return false end
    local expectedAmmoHash = joaat(ammoName)
    Citizen.InvokeNative(0xEBE46B501BC3FBCF, ped, record.guid, expectedAmmoHash)
    -- Do not activate a different-hash production weapon by GUID here. Live
    -- validation showed that doing so can remove both pair members from the
    -- hash-addressable clip surface. GiveWeaponToPed already established their
    -- attach points; this call changes only the selected ammunition entry.
    local actual = tonumber(Citizen.InvokeNative(0xAF9D167A5656D6A6, ped, record.guid))
    if Config.DevMode then
        print(('[feather-weapons] inventory ammo readback weapon=%s expected=%s guidActual=%s hashActual=%s')
            :format(weaponName, tostring(expectedAmmoHash), tostring(actual),
                tostring(Citizen.InvokeNative(0x7FEAD38B326B9F74, ped, joaat(weaponName)))))
    end
    record.ammoHash = expectedAmmoHash
    return true, record
end

function FeatherGuidWeapons.HasSelectedAmmo(ped, record, ammoName)
    if not record or not record.guid or type(ammoName) ~= 'string' then return false end
    local actual = tonumber(Citizen.InvokeNative(0xAF9D167A5656D6A6, ped, record.guid))
    return actual ~= nil and (math.floor(actual) & 0xffffffff)
        == (joaat(ammoName) & 0xffffffff)
end

function FeatherGuidWeapons.SetSelectedAmmo(ped, record, ammoName)
    if not record or not record.guid or type(ammoName) ~= 'string' then return false end
    Citizen.InvokeNative(0xEBE46B501BC3FBCF, ped, record.guid, joaat(ammoName))
    return true
end

local function InsertWeapon(ped, parentGuid, weaponName)
    local guid = Buffer(8 * 13)
    local added = Citizen.InvokeNative(0xCB5D11F9508A928D, -- InventoryAddItemWithGuid
        INVENTORY_ID,
        guid,
        parentGuid,
        joaat(weaponName),
        joaat('SLOTID_WEAPON_0'),
        1,
        joaat('ADD_REASON_DEFAULT') -- 752097756
    )

    if not NativeTrue(added) then
        return nil, 'insert_failed'
    end

    local record = {
        inventoryId = INVENTORY_ID,
        guid = guid,
        slot = 0,
        weaponName = weaponName
    }
    if not NativeTrue(Citizen.InvokeNative(0x734311E2852760D0, INVENTORY_ID, guid, true)) then -- InventoryEquipItemWithGuid
        RemoveRecord(record)
        return nil, 'inventory_equip_failed'
    end

    Citizen.InvokeNative(0x12FB95FE3D579238, -- SetCurrentPedWeaponByGuid
        ped,
        record.guid,
        true,
        record.slot,
        false,
        false
    )
    return record
end

local function RelocateWeapon(record, parentGuid, destinationSlot)
    local replacementGuid = Buffer(8 * 13)
    local moved = Citizen.InvokeNative(0xDCCAA7C3BFD88862, -- InventoryMoveInventoryItem
        record.inventoryId,
        record.guid,
        parentGuid,
        joaat(('SLOTID_WEAPON_%d'):format(destinationSlot)),
        1,
        replacementGuid
    )
    if not NativeTrue(moved) then return false end

    record.guid = replacementGuid
    record.slot = destinationSlot
    return true
end

function FeatherGuidWeapons.Activate(ped, pair)
    if not pair or not pair.primary or not pair.offhand then return false end
    -- RedM preserves both equal-hash instances when slot 0 is activated first
    -- and slot 1 last. Hash-based selection cannot identify either instance.
    for _, record in ipairs({ pair.offhand, pair.primary }) do
        Citizen.InvokeNative(0x12FB95FE3D579238, -- SetCurrentPedWeaponByGuid
            ped,
            record.guid,
            true,
            record.slot,
            false,
            false
        )
    end
    return true
end

function FeatherGuidWeapons.CreateMatchingPair(ped, weaponName)
    if not ped or ped == 0 or type(weaponName) ~= 'string' or weaponName == '' then
        return Failure('invalid_input', 'A ped and native weapon name are required.')
    end

    if not NativeTrue(Citizen.InvokeNative(0x6D5D51B188333FD1, joaat(weaponName), 0)) then -- ItemdatabaseIsKeyValid
        return Failure('invalid_weapon', 'The native weapon item is unavailable.')
    end

    local parentGuid = CarriedWeaponsGuid()
    if not parentGuid then
        return Failure('inventory_unavailable', 'Carried weapon inventory is unavailable.')
    end

    local primary, primaryError = InsertWeapon(ped, parentGuid, weaponName)
    if not primary then return Failure(primaryError, 'Primary weapon insertion failed.') end

    if not RelocateWeapon(primary, parentGuid, 1) then
        RemoveRecord(primary)
        return Failure('slot_move_failed', 'Primary weapon could not move to native slot 1.')
    end

    local offhand, offhandError = InsertWeapon(ped, parentGuid, weaponName)
    if not offhand then
        RemoveRecord(primary)
        return Failure(offhandError, 'Offhand weapon insertion failed.')
    end

    local pair = {
        primary = primary,
        offhand = offhand,
        records = { primary, offhand }
    }
    FeatherGuidWeapons.Activate(ped, pair)
    return { ok = true, value = pair }
end

function FeatherGuidWeapons.AwaitInventoryReady(timeoutMs)
    local deadline = GetGameTimer() + math.max(1000, math.floor(tonumber(timeoutMs) or 5000))
    local stableFrames = 0
    local previousGuid = nil
    while GetGameTimer() < deadline do
        local guid = CarriedWeaponsGuid()
        if guid and previousGuid and guid == previousGuid then
            stableFrames = stableFrames + 1
        else
            stableFrames = 0
        end
        previousGuid = guid
        if stableFrames >= 30 then return true end
        Wait(0)
    end
    return false
end

function FeatherGuidWeapons.ReadClip(ped, record)
    if not record or not record.guid then return false, 0 end

    local amount = Buffer(4)
    local readable = Citizen.InvokeNative(0x678F00858980F516, ped, amount, record.guid) -- GetAmmoInClipByInventoryUid
    local loaded = string.unpack('i4', amount)
    return NativeTrue(readable), math.max(0, math.floor(tonumber(loaded) or 0))
end

function FeatherGuidWeapons.ReadTotal(ped, record)
    if not record or not record.guid then return 0 end

    -- GetPedWeaponAmmoFromGuid
    return math.max(0, math.floor(tonumber(Citizen.InvokeNative(0x4823F13A21F51964, ped, record.guid)) or 0))
end

function FeatherGuidWeapons.Destroy(pair)
    if not pair then return {} end

    local outcomes = {}
    for _, record in ipairs({ pair.offhand, pair.primary }) do
        if record then
            outcomes[#outcomes + 1] = { record = record, removed = RemoveRecord(record) }
        end
    end
    return outcomes
end
