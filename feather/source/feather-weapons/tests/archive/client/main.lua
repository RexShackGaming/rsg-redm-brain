-- Staging quarantine: never run the hybrid owner alongside character ammo.
-- This disables the whole old client (including non-firearms), not a completed
-- native replacement. Flags stay false until native/non-firearm hosting is ready.
if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then
    print('[feather-weapons] hybrid client disabled: native cutover staging; production host not ready')
    return
end
FeatherWeaponsClient = {}
local clientContract = 4
local equipped, offhand, pendingToken, pendingNativeWeaponName = nil, nil, nil, nil
local extraSlotNames = {
    'shoulder', 'back', 'melee', 'melee_secondary', 'melee_tertiary', 'melee_quaternary', 'melee_quinary', 'utility', 'utility_secondary', 'utility_tertiary', 'utility_quaternary', 'utility_quinary', 'utility_senary','utility_septenary', 'utility_octonary',
    'throwable', 'throwable_secondary', 'throwable_tertiary', 'throwable_quaternary', 'throwable_quinary', 'throwable_senary', 'throwable_septenary', 'throwable_octonary', 'throwable_nonary', 'throwable_denary'
}
local extraSlots = {
    shoulder = nil, back = nil, melee = nil, melee_secondary = nil,
    melee_tertiary = nil, melee_quaternary = nil, melee_quinary = nil, utility = nil, utility_secondary = nil, utility_tertiary = nil, utility_quaternary = nil, utility_quinary = nil, utility_senary = nil, utility_septenary = nil, utility_octonary = nil, throwable = nil, throwable_secondary = nil, throwable_tertiary = nil, throwable_quaternary = nil, throwable_quinary = nil, throwable_senary = nil, throwable_septenary = nil, throwable_octonary = nil, throwable_nonary = nil, throwable_denary = nil
}
local extraObserved = {
    shoulder = nil, back = nil, melee = nil, melee_secondary = nil,
    melee_tertiary = nil, melee_quaternary = nil, melee_quinary = nil, utility = nil, utility_secondary = nil, utility_tertiary = nil, utility_quaternary = nil, utility_quinary = nil, utility_senary = nil, utility_septenary = nil, utility_octonary = nil, throwable = nil, throwable_secondary = nil, throwable_tertiary = nil, throwable_quaternary = nil, throwable_quinary = nil, throwable_senary = nil, throwable_septenary = nil, throwable_octonary = nil, throwable_nonary = nil, throwable_denary = nil
}
local extraSyncInFlight = {
    shoulder = false, back = false, melee = false,
    melee_secondary = false, melee_tertiary = false, melee_quaternary = false, melee_quinary = false, utility = false, utility_secondary = false, utility_tertiary = false, utility_quaternary = false, utility_quinary = false, utility_senary = false, utility_septenary = false, utility_octonary = false,
    throwable = false, throwable_secondary = false, throwable_tertiary = false, throwable_quaternary = false, throwable_quinary = false, throwable_senary = false, throwable_septenary = false, throwable_octonary = false, throwable_nonary = false, throwable_denary = false
}
local longgunReloadInFlight = false
local syncInFlight, desiredAmmo, desiredLoaded = false, nil, nil
local unloadInFlight, unloadQueued = false, false
local inventoryWeaponInFlight = false
local attachmentReconcileUntil = 0
local BeginUnload
local FlushExtraSlot
local FlushPairConsumption
local RegisterCharacterLogoutCheckpoint
local RemoveNativeWeapon
local observerCorrectionPending = false
local singleRestoreSequence = 0
local singleNativeReady = false
local presentationRestoreInFlight = false
local checkpointWaiters = {}
local nativeRemoveReason = joaat('REMOVE_REASON_CLIENT_PURGED')
local pairSyncInFlight = false
local pairCheckpointPending = false
local pairObserved = nil
local pairConsumed = { primary = 0, offhand = 0 }
local pairSingleFallback = nil
local pairFallbackPending = nil
local offhandEntitlements = {}
local offhandRecoveryInFlight = false
local holsterSequence = 0
local maintenanceSyncInFlight = {}
local maintenanceBatchInFlight = false
local inventoryMutationCooldownUntil = 0
local logoutCheckpointInFlight = false
local characterRestoreGeneration = 0
local characterRestoreInFlight = false
local characterRestoreComplete = false
local characterRestoreAttempts = 0
local firearmPoolsInFlight = false
local firearmPoolsEpoch = 0

local recoverySuspended = false
local BeginDeathPoolCheckpoint
local deathPoolCheckpointPending = false
local deathPoolCheckpointFailed = false
local function SuspendForDeath()
    if not recoverySuspended and BeginDeathPoolCheckpoint then
        BeginDeathPoolCheckpoint()
    end
    recoverySuspended = true
end
local function LifeStateSuspended()
    local dead = IsEntityDead(PlayerPedId())
    if dead == true or dead == 1 then SuspendForDeath(); return true end
    if GetResourceState('feather-medical') == 'started' then
        local called, result = pcall(function() return exports['feather-medical']:GetLifeState() end)
        if called and result and result.ok and result.value.lifeState ~= 'alive' then
            SuspendForDeath()
            return true
        end
    end
    return recoverySuspended
end

local function FirearmPoolModuleReady()
    return type(FeatherFirearmPools) == 'table'
        and type(FeatherFirearmPools.Reset) == 'function'
        and type(FeatherFirearmPools.Restore) == 'function'
        and type(FeatherFirearmPools.Capture) == 'function'
        and type(FeatherFirearmPools.Accept) == 'function'
        and type(WeaponAmmunitionPools) == 'table'
        and type(WeaponAmmunitionPools.Allocate) == 'function'
end

local function NativeTrue(value)
    return value == true or value == 1
end

local function RemoveNativePairCopies()
    FeatherNativeWeaponCoordinator.Release('pair_removed')
end

local function PairNativeClips(primary, secondary)
    if type(primary) ~= 'table' or type(primary.nativeWeaponName) ~= 'string'
        or type(secondary) ~= 'table' or type(secondary.nativeWeaponName) ~= 'string' then
        return false, 0, false, 0
    end

    local ped = PlayerPedId()
    local primaryOk, primaryLoaded = GetAmmoInClip(ped, joaat(primary.nativeWeaponName))
    local offhandOk, offhandLoaded = GetAmmoInClip(ped, joaat(secondary.nativeWeaponName))

    return NativeTrue(primaryOk), primaryLoaded, NativeTrue(offhandOk), offhandLoaded
end

local function ObservablePairClips(primary, secondary)
    if type(primary) ~= 'table' or type(primary.nativeWeaponName) ~= 'string'
        or type(secondary) ~= 'table' or type(secondary.nativeWeaponName) ~= 'string' then
        return false, 0, false, 0
    end

    if pairSingleFallback == 'primary' then
        local ok, loaded = GetAmmoInClip(PlayerPedId(), joaat(primary.nativeWeaponName))
        return NativeTrue(ok), loaded, true, 0
    end

    if pairSingleFallback == 'offhand' then
        local ok, loaded = GetAmmoInClip(PlayerPedId(), joaat(secondary.nativeWeaponName))
        return true, 0, NativeTrue(ok), loaded
    end

    return PairNativeClips(primary, secondary)
end

local function PairNativeTotal(primary, secondary)
    if type(primary) ~= 'table' or type(primary.nativeAmmoName) ~= 'string'
        or type(secondary) ~= 'table' or type(secondary.nativeAmmoName) ~= 'string' then
        return 0
    end

    local ped = PlayerPedId()
    local primaryTotal = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, joaat(primary.nativeAmmoName))) or 0))
    if primary.nativeAmmoName == secondary.nativeAmmoName then return primaryTotal end

    -- RedM mirrors a materialized clip into the other ammo-type pool, and its
    -- per-GUID total getter mirrors the same value. Neither total can represent
    -- distinct Inventory ownership. Ownership changes only through confirmed
    -- per-weapon clip decreases, so expose the bounded escrow window here.
    return math.max(0, math.floor((tonumber(primary.ammo) or 0)
        + (tonumber(secondary.ammo) or 0)
        - (tonumber(pairConsumed.primary) or 0)
        - (tonumber(pairConsumed.offhand) or 0)))
end

local function IsDualSidearmPair(primary, secondary)
    if type(primary) ~= 'table' or type(primary.definitionId) ~= 'string'
        or type(secondary) ~= 'table' or type(secondary.definitionId) ~= 'string' then
        return false
    end

    local primaryDefinition = WeaponDefinitionCatalog.weapons[primary.definitionId]
    local secondaryDefinition = WeaponDefinitionCatalog.weapons[secondary.definitionId]

    return primaryDefinition and secondaryDefinition
        and primaryDefinition.slot == 'sidearm' and secondaryDefinition.slot == 'sidearm'
end

local function ActivateLoadedPairSlot(ped, slot, state)
    pairSingleFallback = slot
    SetAllowDualWield(ped, false)
    local depleted = slot == 'primary' and offhand or equipped
    local function LogFallbackAmmo(stage)
        if not Config.DevMode then return end
        for role, weapon in pairs({ survivor = state, depleted = depleted }) do
            if weapon.nativeWeaponName and weapon.nativeAmmoName then
                local ok, loaded = GetAmmoInClip(ped, joaat(weapon.nativeWeaponName))
                print(('[feather-weapons] fallback ammo stage=%s role=%s item=%s generation=%s ammo=%s authorized=%s pool=%s clipOk=%s clip=%s')
                    :format(stage, role, tostring(weapon.itemInstanceId), tostring(weapon.generation),
                        weapon.nativeAmmoName, tostring(weapon.ammo),
                        tostring(GetPedAmmoByType(ped, joaat(weapon.nativeAmmoName))),
                        tostring(NativeTrue(ok)), tostring(loaded)))
            end
        end
    end
    LogFallbackAmmo('before-removal')
    if depleted and depleted.nativeWeaponName then
        RemoveNativeWeapon(ped, joaat(depleted.nativeWeaponName))
        LogFallbackAmmo('after-removal')
        -- Removing an empty hand can leave its old clip in a distinct native
        -- pool. That residual makes the next checkpoint exceed the pair lease
        -- and blocks the ammunition menu even though Inventory unload succeeded.
        -- Never clear a shared pool or ammunition still owned by this item.
        if tonumber(depleted.ammo) == 0 and depleted.nativeAmmoName
            and depleted.nativeAmmoName ~= state.nativeAmmoName then
            SetPedAmmoByType(ped, joaat(depleted.nativeAmmoName), 0)
            LogFallbackAmmo('after-zero')
        end
    end
    -- Once dual wield is disabled, the surviving weapon must become the
    -- primary-hand selection (attach point 0), regardless of which pair slot
    -- owned it. Passing its holster point leaves RedM on the empty primary.
    SetCurrentPedWeapon(ped, joaat(state.nativeWeaponName), true, 0, false, false)
    LogFallbackAmmo('after-selection')
    Wait(0)
    LogFallbackAmmo('settled')
    if Config.DevMode then
        local selectedOk, selectedHash = GetCurrentPedWeapon(ped, true, 0, false)
        print(('[feather-weapons] pair depleted; single-weapon fallback slot=%s weapon=%s selected=%s/%s')
            :format(slot, tostring(state.nativeWeaponName), tostring(selectedOk), tostring(selectedHash)))
    end
end

local function AddOffhandEntitlement(itemName, slotId)
    local inventoryId = 1
    local itemHash = joaat(itemName)
    -- InventoryGetInventoryItemCountWithItemid
    local existing = math.max(0,
        math.floor(tonumber(Citizen.InvokeNative(0xE787F05DFC977BDE, inventoryId, itemHash, false)) or 0))
    if existing > 0 then return true end

    local characterGuid = FeatherGuidWeapons.ResolveGuid(inventoryId, nil, joaat('CHARACTER'), 0xA1212100)
    local wardrobeGuid = characterGuid and
        FeatherGuidWeapons.ResolveGuid(inventoryId, characterGuid, joaat('WARDROBE'), 0x3DABBFA7) or nil
    if not wardrobeGuid then return false end

    local itemGuid = FeatherGuidWeapons.NewBuffer(8 * 13)
    local added = Citizen.InvokeNative(0xCB5D11F9508A928D, -- InventoryAddItemWithGuid
        inventoryId,
        itemGuid,
        wardrobeGuid,
        itemHash,
        slotId,
        1,
        joaat('ADD_REASON_DEFAULT')
    )
    if not NativeTrue(added) then return false end

    -- InventoryEquipItemWithGuid
    if not NativeTrue(Citizen.InvokeNative(0x734311E2852760D0, inventoryId, itemGuid, true)) then
        Citizen.InvokeNative(0x3E4E811480B3AE79, inventoryId, itemGuid, 1,
            joaat('REMOVE_REASON_DEFAULT'))
        return false
    end

    offhandEntitlements[#offhandEntitlements + 1] = {
        inventoryId = inventoryId,
        guid = itemGuid,
        itemName = itemName,
        componentHash = itemName:match('^CLOTHING_') and itemHash or nil
    }

    if itemName:match('^CLOTHING_') then
        local ped = PlayerPedId()
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, itemHash, false, false, false)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, itemHash, false, true, false)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    end
    return true
end

local function EnsureOffhandEntitlement()
    if not (Config.Offhand and Config.Offhand.provisionNativeEntitlement) then
        return NativeTrue(GetAllowDualWield(PlayerPedId()))
    end

    local ped = PlayerPedId()
    local modelHash = GetEntityModel(ped)
    local model = modelHash == joaat('mp_male') and 'mp_male'
        or modelHash == joaat('mp_female') and 'mp_female' or nil
    local entitlements = model and Config.Offhand.nativeEntitlements[model] or nil
    if type(entitlements) ~= 'table' then return false end

    local provisioned = true
    for _, entitlement in ipairs(entitlements) do
        if not AddOffhandEntitlement(entitlement.itemName, entitlement.slotId) then
            provisioned = false
            break
        end
    end
    SetAllowDualWield(ped, true)

    return provisioned and NativeTrue(GetAllowDualWield(ped))
end

local function RemoveOffhandEntitlements()
    local ped = PlayerPedId()
    local variationChanged = false
    for index = #offhandEntitlements, 1, -1 do
        local value = offhandEntitlements[index]
        if value.componentHash then
            Citizen.InvokeNative(0x0D7FFA1B2F69ED82, ped, value.componentHash, 0, 0)
            variationChanged = true
        end
        Citizen.InvokeNative(0x3E4E811480B3AE79, -- InventoryRemoveInventoryItemWithGuid
            value.inventoryId,
            value.guid,
            1,
            joaat('REMOVE_REASON_DEFAULT')
        )
    end
    offhandEntitlements = {}
    if variationChanged then
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    end
end

RemoveNativeWeapon = function(ped, weaponHash)
    RemoveWeaponFromPed(ped, weaponHash, true, nativeRemoveReason)
end

local function ResolveCheckpointWaiters(result)
    local waiters = checkpointWaiters
    checkpointWaiters = {}
    for _, callback in ipairs(waiters) do
        callback(result)
    end
end

local function Notify(message)
    local called, result = pcall(function()
        return exports['feather-notify']:ShowNotification({
            style = 'right',
            message = message,
            duration = 3000
        })
    end)

    if not called then
        result = { ok = false, code = 'provider_unavailable' }
    end

    if (not result or result.ok ~= true) and Config.DevMode then
        print(('[feather-weapons] %s'):format(message))
    end
end

local function SameInstance(left, right)
    return left ~= nil and right ~= nil and tostring(left) == tostring(right)
end

local function SelectNativeAmmoType(ped, nativeWeaponName, nativeAmmoName)
    local weaponHash, ammoHash = joaat(nativeWeaponName), joaat(nativeAmmoName)
    -- Inventory use owns selection. The wheel must not select an unescrowed
    -- pool and turn its zero count into a false consumption checkpoint.
    for _, definition in pairs(WeaponDefinitionCatalog.weapons) do
        if definition.nativeWeaponName == nativeWeaponName then
            for _, id in ipairs(definition.ammunitionTypes) do
                local candidate = joaat(WeaponDefinitionCatalog.ammunition[id].nativeAmmoName)
                if candidate ~= ammoHash then
                    Citizen.InvokeNative(0xF0D728EEA3C99775, ped, weaponHash, candidate)
                end
            end
            break
        end
    end
    Citizen.InvokeNative(0x23FB9FACA28779C1, ped, weaponHash, ammoHash)
    Citizen.InvokeNative(0xCC9C4393523833E2, ped, weaponHash, ammoHash)
end

local function SetNativeAmmo(nativeAmmoName, amount, nativeWeaponName, loaded)
    if not nativeAmmoName then return end

    local ped = PlayerPedId()
    local ammoHash = joaat(nativeAmmoName)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local clipLoaded = loaded ~= nil
        and math.max(0, math.min(amount, math.floor(tonumber(loaded) or 0))) or nil
    local before = GetPedAmmoByType(ped, ammoHash)
    if nativeWeaponName and clipLoaded ~= nil then
        -- A hash-addressed clip write uses the native weapon's current type,
        -- not necessarily the Inventory-authorized pool being funded.
        SelectNativeAmmoType(ped, nativeWeaponName, nativeAmmoName)
        SetAmmoInClip(ped, joaat(nativeWeaponName), clipLoaded)
    end

    -- Apply the clip first and the approved total once. Setting the total
    -- before the clip causes RedM to add the clip a second time.
    Citizen.InvokeNative(0x5FD1E1F011E76D7E, ped, ammoHash, amount) -- SetPedAmmoByType

    if Config.DevMode then
        local afterTotal = GetPedAmmoByType(ped, ammoHash)
        print(('[feather-weapons] native ammo targetTotal=%s beforeTotal=%s afterTotal=%s loaded=%s'):format(
            tostring(amount), tostring(before), tostring(afterTotal), tostring(clipLoaded)))
    end
end

local function ApplyNativeAttachments(nativeWeaponName, attachments)
    local ped = PlayerPedId()
    local weaponHash = joaat(nativeWeaponName)
    for _, attachment in ipairs(attachments or {}) do
        local componentHash = joaat(attachment.nativeComponentName)
        local modelHash = Citizen.InvokeNative(0x59DE03442B6C9598, componentHash) -- GetWeaponComponentTypeModel
        if modelHash and modelHash ~= 0 then
            RequestModel(modelHash, false)
            local attempts = 0
            while not HasModelLoaded(modelHash) and attempts < 100 do
                attempts = attempts + 1
                Wait(0)
            end
        end

        Citizen.InvokeNative(0x74C9090FDD1BB48E, ped, componentHash, weaponHash, true) -- GiveWeaponComponentToEntity

        if modelHash and modelHash ~= 0 then
            SetModelAsNoLongerNeeded(modelHash)
        end
    end
end

local function ScheduleAttachmentReconciliation(nativeWeaponName, attachments)
    if not attachments or #attachments == 0 then return end

    attachmentReconcileUntil = GetGameTimer() + 15000
    for _, delay in ipairs({ 250, 1000 }) do
        SetTimeout(delay, function()
            local expected = (equipped and equipped.nativeWeaponName == nativeWeaponName)
                or pendingNativeWeaponName == nativeWeaponName
            if expected then
                ApplyNativeAttachments(nativeWeaponName, attachments)
            end
        end)
    end
end

local function NativeGrantAmount(nativeWeaponName)
    for _, definition in pairs(WeaponDefinitionCatalog.weapons or {}) do
        if definition.nativeWeaponName == nativeWeaponName then
            return math.max(0, math.floor(tonumber(definition.nativeGrantAmount) or 0))
        end
    end
    return 0
end

local function GiveApprovedNativeWeapon(nativeWeaponName, nativeAmmoName, amount, loaded, attachments, attachPoint)
    local ped = PlayerPedId()
    local ammoHash = nativeAmmoName and joaat(nativeAmmoName) or nil
    local weaponHash = joaat(nativeWeaponName)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local before = ammoHash and GetPedAmmoByType(ped, ammoHash) or nil
    -- RedM retains hidden clip state by weapon hash after removal. Clear that
    -- cache before recreating an Inventory-authorized weapon instance.
    SetPedAmmo(ped, weaponHash, 0)
    GiveWeaponToPed(
        ped,
        weaponHash,
        NativeGrantAmount(nativeWeaponName),
        false,
        true,
        math.floor(tonumber(attachPoint) or 0),
        false,
        0.5,
        1.0,
        joaat('ADD_REASON_DEFAULT'),
        true,
        0.0,
        false
    )

    if ammoHash then
        SelectNativeAmmoType(ped, nativeWeaponName, nativeAmmoName)
        SetPedAmmoByType(ped, ammoHash, 0)
    end

    loaded = math.max(0, math.min(amount, math.floor(tonumber(loaded) or 0)))
    if ammoHash then
        -- Pool resets can change the native current type. Reassert selection
        -- at the clip-write boundary instead of relying on earlier selection.
        SelectNativeAmmoType(ped, nativeWeaponName, nativeAmmoName)
        SetAmmoInClip(ped, weaponHash, loaded)
    end
    if ammoHash then
        SetPedAmmoByType(ped, ammoHash, amount)
    end

    ApplyNativeAttachments(nativeWeaponName, attachments)
    ScheduleAttachmentReconciliation(nativeWeaponName, attachments)

    if Config.DevMode then
        local after = ammoHash and GetPedAmmoByType(ped, ammoHash) or nil
        print(('[feather-weapons] native weapon granted total=%s nativeTotal=%s loaded=%s beforeTotal=%s'):format(
            tostring(amount), tostring(after), tostring(loaded), tostring(before)))
    end
end

local function RestoreApprovedNativePair(primary, secondary)
    if type(primary) ~= 'table' or type(primary.nativeWeaponName) ~= 'string'
        or type(primary.nativeAmmoName) ~= 'string'
        or type(secondary) ~= 'table' or type(secondary.nativeWeaponName) ~= 'string'
        or type(secondary.nativeAmmoName) ~= 'string' then
        return false, 'Approved weapon pair state is incomplete.'
    end

    local primaryAmmo = math.max(0, math.floor(tonumber(primary.ammo) or 0))
    local secondaryAmmo = math.max(0, math.floor(tonumber(secondary.ammo) or 0))
    local primaryLoaded = math.max(0, math.floor(tonumber(primary.loaded) or 0))
    local secondaryLoaded = math.max(0, math.floor(tonumber(secondary.loaded) or 0))
    local primaryReserve = math.max(0, math.floor(tonumber(primary.reserve) or (primaryAmmo - primaryLoaded)))
    local secondaryReserve = math.max(0, math.floor(tonumber(secondary.reserve) or (secondaryAmmo - secondaryLoaded)))
    local dualSidearms = IsDualSidearmPair(primary, secondary)
    if dualSidearms and not EnsureOffhandEntitlement() then
        return false, 'Offhand holster entitlement is unavailable.'
    end

    local ped = PlayerPedId()
    local primaryPoint = math.floor(tonumber(Config.Offhand.primaryAttachPoint) or 2)
    local offhandPoint = math.floor(tonumber(Config.Offhand.offhandAttachPoint) or 3)
    local primaryHash = joaat(primary.nativeWeaponName)
    local secondaryHash = joaat(secondary.nativeWeaponName)
    local identical = primaryHash == secondaryHash
    if identical then
        return false, 'Matching weapon models cannot be equipped together.'
    end

    local sharedAmmo = primary.nativeAmmoName == secondary.nativeAmmoName
    if dualSidearms then
        -- Match single-weapon restore: clear hash-cached ammunition before
        -- recreating either hand. Clear both first because their default ammo
        -- pools may overlap even when their approved selected types differ.
        SetPedAmmo(ped, primaryHash, 0)
        SetPedAmmo(ped, secondaryHash, 0)
        GiveWeaponToPed(ped, primaryHash, 0, true, false,
            primaryPoint, false, 0.5, 1.0, joaat('ADD_REASON_DEFAULT'), true, 0.0, false)

        GiveWeaponToPed(ped, secondaryHash, 0, true, false,
            offhandPoint, false, 0.5, 1.0, joaat('ADD_REASON_DEFAULT'), true, 0.0, false)
    else
        -- A mixed sidearm/long-gun loadout is not a dual-wield pair. Let RedM
        -- place both ordinary weapons in their native wheel/holster slots.
        GiveApprovedNativeWeapon(primary.nativeWeaponName, primary.nativeAmmoName,
            primaryAmmo, primaryLoaded, primary.attachments)
        GiveApprovedNativeWeapon(secondary.nativeWeaponName, secondary.nativeAmmoName,
            secondaryAmmo, secondaryLoaded, secondary.attachments)
    end

    -- Make approved distinct ammunition available before requesting selection.
    -- RedM credits materialized clips to the hash-reported type even when the
    -- Inventory GUID selects a special type, so subtract those future credits
    -- from the initial pool targets. This avoids an excess that native setters
    -- cannot lower after the clips exist.
    if not sharedAmmo then
        local primaryAmmoHash = joaat(primary.nativeAmmoName)
        local secondaryAmmoHash = joaat(secondary.nativeAmmoName)
        local primarySelectedHash = tonumber(Citizen.InvokeNative(
            0x7FEAD38B326B9F74, ped, primaryHash))
        local secondarySelectedHash = tonumber(Citizen.InvokeNative(
            0x7FEAD38B326B9F74, ped, secondaryHash))
        local function SameHash(left, right)
            return left ~= nil and (math.floor(left) & 0xffffffff) == (right & 0xffffffff)
        end
        local function CreditedClipTotal(ammoHash)
            local total = 0
            if SameHash(primarySelectedHash, ammoHash) then total = total + primaryLoaded end
            if SameHash(secondarySelectedHash, ammoHash) then total = total + secondaryLoaded end
            return total
        end
        SetPedAmmoByType(ped, primaryAmmoHash,
            math.max(0, primaryAmmo - CreditedClipTotal(primaryAmmoHash)))
        SetPedAmmoByType(ped, secondaryAmmoHash,
            math.max(0, secondaryAmmo - CreditedClipTotal(secondaryAmmoHash)))
    end

    -- Select each approved type before materializing its native clip.
    SelectNativeAmmoType(ped, primary.nativeWeaponName, primary.nativeAmmoName)
    SelectNativeAmmoType(ped, secondary.nativeWeaponName, secondary.nativeAmmoName)
    if not sharedAmmo then
        if dualSidearms then
            local primarySelected, primaryRecord = FeatherGuidWeapons.SelectExistingAmmo(ped,
                primary.nativeWeaponName, primary.nativeAmmoName)
            local secondarySelected, secondaryRecord = FeatherGuidWeapons.SelectExistingAmmo(ped,
                secondary.nativeWeaponName, secondary.nativeAmmoName)
            if Config.DevMode then
                print(('[feather-weapons] pair inventory ammo entries resolved primary=%s secondary=%s')
                    :format(tostring(primarySelected), tostring(secondarySelected)))
            end
            if not primarySelected or not secondarySelected then
                return false, 'Native weapon inventory ammunition selection could not be verified.'
            end
            -- A different-hash pair still has one Inventory GUID per weapon.
            -- The hash getter can keep reporting the default type even though
            -- the GUID getter reports the selected special type, so readiness
            -- must follow the identity that was actually mutated.
            local typesReady = false
            for _ = 1, 40 do
                local primaryReady = primaryAmmo == 0 or FeatherGuidWeapons.HasSelectedAmmo(
                    ped, primaryRecord, primary.nativeAmmoName)
                local secondaryReady = secondaryAmmo == 0 or FeatherGuidWeapons.HasSelectedAmmo(
                    ped, secondaryRecord, secondary.nativeAmmoName)
                if primaryReady and secondaryReady then
                    typesReady = true
                    break
                end
                if not primaryReady then
                    FeatherGuidWeapons.SetSelectedAmmo(ped, primaryRecord, primary.nativeAmmoName)
                end
                if not secondaryReady then
                    FeatherGuidWeapons.SetSelectedAmmo(ped, secondaryRecord, secondary.nativeAmmoName)
                end
                Wait(50)
            end
            if not typesReady then
                return false, 'Native weapon inventory ammunition types did not become ready.'
            end
        else
            -- Long-gun inventory entries are not GUID-addressed by this adapter.
            -- Continue to require the hash-based selection used by their native
            -- restore path.
            local function MatchesAmmo(weaponHash, nativeAmmoName)
                local selected = tonumber(Citizen.InvokeNative(0x7FEAD38B326B9F74, ped, weaponHash))
                return selected ~= nil and (math.floor(selected) & 0xffffffff)
                    == (joaat(nativeAmmoName) & 0xffffffff)
            end
            local typesReady = false
            for _ = 1, 40 do
                if MatchesAmmo(primaryHash, primary.nativeAmmoName)
                    and MatchesAmmo(secondaryHash, secondary.nativeAmmoName) then
                    typesReady = true
                    break
                end
                Wait(50)
            end
            if not typesReady then
                return false, 'Native weapon pair ammunition types did not become ready.'
            end
        end

    end
    -- Shared pools are seeded as aggregate reserve; distinct pools use the
    -- per-hand conventions documented below.
    if sharedAmmo then
        SetPedAmmoByType(ped, joaat(primary.nativeAmmoName), math.max(0,
            primaryAmmo + secondaryAmmo - primaryLoaded - secondaryLoaded))
    else
        -- Distinct pools were normalized immediately after selection, before
        -- either clip was materialized.
    end

    local primaryReady, secondaryReady = false, false
    local function LogClipWrite(stage, result)
        if not Config.DevMode or sharedAmmo then return end
        for role, value in pairs({ primary = primary, secondary = secondary }) do
            local weaponHash = joaat(value.nativeWeaponName)
            local selectedAmmo = Citizen.InvokeNative(0x7FEAD38B326B9F74, ped, weaponHash)
            local clipOk, clip = GetAmmoInClip(ped, weaponHash)
            print(('[feather-weapons] pair clip write stage=%s result=%s role=%s item=%s expectedAmmoHash=%s selectedAmmoHash=%s pool=%s clipOk=%s clip=%s')
                :format(stage, tostring(result), role, tostring(value.itemInstanceId),
                    tostring(joaat(value.nativeAmmoName)), tostring(selectedAmmo),
                    tostring(GetPedAmmoByType(ped, joaat(value.nativeAmmoName))),
                    tostring(NativeTrue(clipOk)), tostring(clip)))
        end
    end
    for attempt = 1, 40 do
        if attempt == 1 then LogClipWrite('before-primary') end
        local primaryWritten = SetAmmoInClip(ped, primaryHash, primaryLoaded)
        if attempt == 1 then LogClipWrite('after-primary', primaryWritten) end
        local secondaryWritten = SetAmmoInClip(ped, secondaryHash, secondaryLoaded)
        if attempt == 1 then LogClipWrite('after-secondary', secondaryWritten) end
        local primaryOk, observedPrimaryLoaded = GetAmmoInClip(ped, primaryHash)
        local secondaryOk, observedSecondaryLoaded = GetAmmoInClip(ped, secondaryHash)
        -- Empty ownership is not proof that a native weapon materialized.
        -- Require a readable zero clip too, otherwise an absent empty hand
        -- bypasses the activation retry and restore incorrectly reports success.
        primaryReady = NativeTrue(primaryOk)
            and math.max(0, math.floor(tonumber(observedPrimaryLoaded) or 0)) == primaryLoaded
        secondaryReady = NativeTrue(secondaryOk)
            and math.max(0, math.floor(tonumber(observedSecondaryLoaded) or 0)) == secondaryLoaded
        if primaryReady and secondaryReady then break end
        -- A cold restore or a rebuild after single-hand fallback can leave one
        -- weapon present in Inventory but without a hash-addressable clip.
        -- Selecting that weapon at its persisted attach point materializes the
        -- missing clip surface; the next bounded retry performs the write.
        if dualSidearms then
            if not primaryReady then
                SetCurrentPedWeapon(ped, primaryHash, true, primaryPoint, false, false)
            end
            if not secondaryReady then
                SetCurrentPedWeapon(ped, secondaryHash, true, offhandPoint, false, false)
            end
        end
        Wait(50)
    end

    if not primaryReady or not secondaryReady then
        return false, 'Native weapon pair did not become ready.'
    end

    if sharedAmmo then
        -- Depending on which hand RedM activates while the GUIDs materialize,
        -- SetAmmoInClip can leave the shared pool counting only one clip. Once
        -- both clips exist, assert the complete authorized aggregate and then
        -- reassert each clip without changing per-item escrow ownership.
        SetPedAmmoByType(ped, joaat(primary.nativeAmmoName),
            math.max(0, primaryAmmo + secondaryAmmo))
        SetAmmoInClip(ped, primaryHash, primaryLoaded)
        SetAmmoInClip(ped, secondaryHash, secondaryLoaded)
        SetPedAmmoByType(ped, joaat(primary.nativeAmmoName),
            math.max(0, primaryAmmo + secondaryAmmo))
    end

    ApplyNativeAttachments(primary.nativeWeaponName, primary.attachments)
    ApplyNativeAttachments(secondary.nativeWeaponName, secondary.attachments)

    if dualSidearms then
        SetCurrentPedWeapon(ped, primaryHash, true, primaryPoint, false, false)
    end

    if not sharedAmmo and not (primary.ammoPools and secondary.ammoPools) then
        -- Legacy single-type pairs require per-selected-type equality. Pool
        -- pairs also own inactive types, so their full-loadout aggregate is
        -- restored and verified by FeatherFirearmPools during reconciliation.
        -- Both pools were pre-seeded for RedM's observed clip-credit behavior.
        Wait(0)
        local primaryAmmoHash = joaat(primary.nativeAmmoName)
        local secondaryAmmoHash = joaat(secondary.nativeAmmoName)
        local function LogDistinctPools(stage)
            if not Config.DevMode then return end
            local function LogWeapon(role, state, weaponHash, ammoHash, approvedTotal, approvedLoaded)
                local clipOk, clip = GetAmmoInClip(ped, weaponHash)
                local pool = tonumber(GetPedAmmoByType(ped, ammoHash))
                -- Preserve unavailable reads rather than reporting a false zero.
                -- Native pool semantics are under validation; delta is diagnostic
                -- only and must never be used to grant or persist ammunition.
                print(('[feather-weapons] distinct pair pools stage=%s role=%s dualSidearms=%s item=%s generation=%s weapon=%s ammo=%s approvedTotal=%d approvedLoaded=%d pool=%s clipOk=%s clip=%s delta=%s')
                    :format(stage, role, tostring(dualSidearms), tostring(state.itemInstanceId),
                        tostring(state.generation), state.nativeWeaponName, state.nativeAmmoName,
                        approvedTotal, approvedLoaded, tostring(pool), tostring(NativeTrue(clipOk)),
                        tostring(clip), pool and tostring(pool - approvedTotal) or 'unavailable'))
            end
            LogWeapon('primary', primary, primaryHash, primaryAmmoHash, primaryAmmo, primaryLoaded)
            LogWeapon('secondary', secondary, secondaryHash, secondaryAmmoHash, secondaryAmmo, secondaryLoaded)
        end
        LogDistinctPools('materialized')
        -- Some weapon models materialize a readable clip without crediting it
        -- to the native ammo-type pool (observed with Mauser). Raise only a
        -- measured deficit; this is wheel presentation bounded by approved
        -- escrow and cannot create persistent ownership.
        for _, value in ipairs({
            { ammoHash = primaryAmmoHash, approved = primaryAmmo },
            { ammoHash = secondaryAmmoHash, approved = secondaryAmmo }
        }) do
            local observed = math.max(0, math.floor(tonumber(
                GetPedAmmoByType(ped, value.ammoHash)) or 0))
            local deficit = math.max(0, value.approved - observed)
            if deficit > 0 then
                Citizen.InvokeNative(0x106A811C6D3035F3, ped, value.ammoHash,
                    deficit, joaat('ADD_REASON_DEFAULT')) -- GiveAmmoToPedByType
            end
        end
        Wait(0)
        local function PoolMatchesApproved(ammoHash, approved)
            local observed = math.max(0, math.floor(tonumber(
                GetPedAmmoByType(ped, ammoHash)) or 0))
            -- An empty counterpart can still display the funded weapon's clip
            -- in its default pool. It owns no rounds and fallback removes it,
            -- so exact wheel equality applies only to funded pools.
            return approved == 0 or observed == approved
        end
        if not PoolMatchesApproved(primaryAmmoHash, primaryAmmo)
            or not PoolMatchesApproved(secondaryAmmoHash, secondaryAmmo) then
            return false, 'Native ammunition pools did not match the approved pair totals.'
        end
        LogDistinctPools('offhand-normalized')
        LogDistinctPools('primary-normalized')
        Wait(0)
        LogDistinctPools('wheel-normalized')
        LogDistinctPools('settled')
    end

    return true
end

local function NativePairAvailable(primary, secondary)
    if IsDualSidearmPair(primary, secondary)
        and not NativeTrue(GetAllowDualWield(PlayerPedId())) then
        return false
    end

    local primaryOk, _, secondaryOk = PairNativeClips(primary, secondary)
    return primaryOk and secondaryOk
end

local function ResetNativeAmmo(reason, nativeAmmoName)
    if not (Config.Runtime and Config.Runtime.authoritativeNativeAmmo) then return end

    local ped = PlayerPedId()
    local before = nativeAmmoName and GetPedAmmoByType(ped, joaat(nativeAmmoName)) or nil
    Citizen.InvokeNative(0x1B83C0DEEBCBB214, ped) -- RemoveAllPedAmmo
    if Config.DevMode then
        local after = nativeAmmoName and GetPedAmmoByType(ped, joaat(nativeAmmoName)) or nil
        print(('[feather-weapons] native ammo reset reason=%s before=%s after=%s'):format(
            tostring(reason), tostring(before), tostring(after)))
    end
end

local function RestoreApprovedNativeWeapon(nativeWeaponName, nativeAmmoName, amount, loaded, attachments)
    RemoveNativeWeapon(PlayerPedId(), joaat(nativeWeaponName))
    ResetNativeAmmo('ammo-restored', nativeAmmoName)
    GiveApprovedNativeWeapon(nativeWeaponName, nativeAmmoName, amount, loaded, attachments)
end

local function ClearNativeWeapon()
    firearmPoolsEpoch = firearmPoolsEpoch + 1
    if FirearmPoolModuleReady() then FeatherFirearmPools.Reset() end
    holsterSequence = holsterSequence + 1
    presentationRestoreInFlight = false
    singleRestoreSequence = singleRestoreSequence + 1
    singleNativeReady = false
    local nativeWeaponName = equipped and equipped.nativeWeaponName or pendingNativeWeaponName
    local nativeAmmoName = equipped and equipped.nativeAmmoName or nil
    RemoveNativePairCopies()

    if nativeWeaponName then
        RemoveNativeWeapon(PlayerPedId(), joaat(nativeWeaponName))
    end

    if offhand and offhand.nativeWeaponName then
        RemoveNativeWeapon(PlayerPedId(), joaat(offhand.nativeWeaponName))
    end

    for _, slot in ipairs(extraSlotNames) do
        local state = extraSlots[slot]
        if state and state.nativeWeaponName then
            RemoveNativeWeapon(PlayerPedId(), joaat(state.nativeWeaponName))
        end
    end

    ResetNativeAmmo('weapon-cleared', nativeAmmoName)
    RemoveOffhandEntitlements()

    equipped, offhand, pendingToken, pendingNativeWeaponName, desiredAmmo, desiredLoaded, syncInFlight = nil, nil, nil, nil, nil, nil, false
    extraSlots = {
        shoulder = nil, back = nil, melee = nil, melee_secondary = nil,
        melee_tertiary = nil, melee_quaternary = nil, melee_quinary = nil, utility = nil, utility_secondary = nil, utility_tertiary = nil, utility_quaternary = nil, utility_quinary = nil, utility_senary = nil, utility_septenary = nil, utility_octonary = nil, throwable = nil, throwable_secondary = nil, throwable_tertiary = nil, throwable_quaternary = nil, throwable_quinary = nil, throwable_senary = nil, throwable_septenary = nil, throwable_octonary = nil, throwable_nonary = nil, throwable_denary = nil
    }
    extraObserved = {
        shoulder = nil, back = nil, melee = nil, melee_secondary = nil,
        melee_tertiary = nil, melee_quaternary = nil, melee_quinary = nil, utility = nil, utility_secondary = nil, utility_tertiary = nil, utility_quaternary = nil, utility_quinary = nil, utility_senary = nil, utility_septenary = nil, utility_octonary = nil, throwable = nil, throwable_secondary = nil, throwable_tertiary = nil, throwable_quaternary = nil, throwable_quinary = nil, throwable_senary = nil, throwable_septenary = nil, throwable_octonary = nil, throwable_nonary = nil, throwable_denary = nil
    }
    extraSyncInFlight = {
        shoulder = false, back = false, melee = false,
        melee_secondary = false, melee_tertiary = false, melee_quaternary = false, melee_quinary = false, utility = false, utility_secondary = false, utility_tertiary = false, utility_quaternary = false, utility_quinary = false, utility_senary = false, utility_septenary = false, utility_octonary = false,
        throwable = false, throwable_secondary = false, throwable_tertiary = false, throwable_quaternary = false, throwable_quinary = false, throwable_senary = false, throwable_septenary = false, throwable_octonary = false, throwable_nonary = false, throwable_denary = false
    }
    pairSyncInFlight, pairCheckpointPending, pairObserved = false, false, nil
    pairConsumed = { primary = 0, offhand = 0 }
    pairSingleFallback = nil
    pairFallbackPending = nil
    unloadInFlight, unloadQueued = false, false
    observerCorrectionPending = false
    logoutCheckpointInFlight = false
    ResolveCheckpointWaiters({ ok = false, code = 'session_cleared', message = 'Weapon session was cleared.' })
    attachmentReconcileUntil = 0
end

local function SlotState(slot)
    if slot == 'primary' then return equipped end

    if slot == 'offhand' then return offhand end

    return extraSlots[slot]
end

local function SlotLabel(slot)
    return ({
        primary = 'Primary', offhand = 'Offhand', shoulder = 'Shoulder', back = 'Back',
        melee = 'Melee', melee_secondary = 'Second Melee', melee_tertiary = 'Third Melee',
        utility = 'Utility', utility_secondary = 'Second Utility', utility_tertiary = 'Third Utility', utility_quaternary = 'Fourth Utility', utility_quinary = 'Fifth Utility', utility_senary = 'Sixth Utility', utility_septenary = 'Seventh Utility', utility_octonary = 'Eighth Utility', melee_quaternary = 'Fourth Melee', melee_quinary = 'Fifth Melee', throwable = 'Throwable',
        throwable_secondary = 'Second Throwable', throwable_tertiary = 'Third Throwable', throwable_quaternary = 'Fourth Throwable', throwable_quinary = 'Fifth Throwable', throwable_senary = 'Sixth Throwable', throwable_septenary = 'Seventh Throwable', throwable_octonary = 'Eighth Throwable', throwable_nonary = 'Ninth Throwable', throwable_denary = 'Tenth Throwable'
    })[slot] or slot
end

local function FirearmPoolSlots()
    local slots = {}
    for _, slot in ipairs({ 'primary', 'offhand', 'shoulder', 'back' }) do
        local state = SlotState(slot)
        if state and state.ammoPools then slots[slot] = state end
    end
    return slots
end

local function FirearmPoolsActive()
    return next(FirearmPoolSlots()) ~= nil
end

local function FlushFirearmPools(callback, deathBoundary)
    callback = callback or function() end
    if not deathBoundary and LifeStateSuspended() then
        callback({ok = true, value = {deferred = true, reason = 'character_not_alive'}})
        return
    end
    if not FirearmPoolModuleReady() then
        callback({ ok = false, error = { code = 'firearm_pool_module_missing',
            message = 'Deploy client/firearm_pools.lua, shared/ammunition_pools.lua and the updated fxmanifest.lua.' } })
        return
    end
    -- Pool batches and periodic maintenance can touch the same equipped item
    -- metadata. Keep their Inventory transactions mutually exclusive; letting
    -- a multi-item pool batch overlap a single-item maintenance write produced
    -- repeatable InnoDB deadlocks under live firing checkpoints.
    if firearmPoolsInFlight or maintenanceBatchInFlight then
        SetTimeout(50, function() FlushFirearmPools(callback, deathBoundary) end)
        return
    end
    local capture, failure, detail = FeatherFirearmPools.Capture(PlayerPedId(), WeaponDefinitionCatalog)
    if not capture then
        callback({ ok = false, error = { code = failure, detail = detail,
            message = 'Firearm pool observation is not safe to checkpoint.' } })
        return
    end
    local changed = false
    for slot, report in pairs(capture.reports) do
        local state = SlotState(slot)
        if not state or not SameInstance(state.itemInstanceId, report.itemInstanceId)
            or state.generation ~= report.generation then
            callback({ ok = false, error = { code = 'stale_pool_capture' } }); return
        end
        if state.ammunitionType ~= report.ammunitionType or state.loaded ~= report.loaded then changed = true end
        for id, total in pairs(report.pools) do
            if total ~= (state.ammoPools[id] or 0) then changed = true end
        end
    end
    if not changed then
        FeatherFirearmPools.Accept(capture)
        callback({ ok = true, value = { unchanged = true } }); return
    end
    firearmPoolsInFlight = true
    local epoch = firearmPoolsEpoch
    FeatherCore.RPC.Call('feather-weapons:ammo:syncPoolBatch', { slots = capture.reports }, function(result, rpcError)
        firearmPoolsInFlight = false
        if epoch ~= firearmPoolsEpoch then
            callback({ ok = false, error = { code = 'pool_restore_changed' } }); return
        end
        if result and result.ok then
            for slot, value in pairs(result.value.slots) do
                local state = SlotState(slot)
                state.ammoPools = value.pools
                state.ammunitionType = value.ammunitionType
                state.nativeAmmoName = WeaponDefinitionCatalog.ammunition[value.ammunitionType].nativeAmmoName
                state.ammo, state.loaded, state.reserve = value.total, value.loaded, value.reserve
            end
            FeatherFirearmPools.Accept(capture)
            if equipped then desiredAmmo, desiredLoaded = equipped.ammo, equipped.loaded end
        end
        callback(result or { ok = false, error = rpcError })
    end)
end

-- One final bounded pool observation before dead-state suspension. Native clip
-- losses must still exactly explain shared pool losses via Capture/Allocate.
BeginDeathPoolCheckpoint = function()
    if not FirearmPoolsActive() or deathPoolCheckpointPending then return end
    deathPoolCheckpointPending = true
    deathPoolCheckpointFailed = false
    local epoch, generation = firearmPoolsEpoch, characterRestoreGeneration
    local attempts = 0
    local function drain()
        if epoch ~= firearmPoolsEpoch or generation ~= characterRestoreGeneration then
            deathPoolCheckpointPending = false
            return
        end
        if firearmPoolsInFlight or maintenanceBatchInFlight then
            SetTimeout(50, drain)
            return
        end
        attempts = attempts + 1
        FlushFirearmPools(function(result)
            if result and result.ok then
                deathPoolCheckpointPending = false
                print('[feather-weapons] death pool checkpoint PASS')
            elseif attempts < 3 then
                SetTimeout(100, drain)
            else
                -- Fail closed: recovery must not restore stale ownership.
                deathPoolCheckpointFailed = true
                print('[feather-weapons] death pool checkpoint FAILED; recovery restore blocked')
            end
        end, true)
    end
    SetTimeout(0, drain)
end

CreateThread(function()
    while true do
        while LifeStateSuspended() do Wait(100) end
        Wait(250)
        if characterRestoreComplete and not characterRestoreInFlight
            and not inventoryWeaponInFlight and not logoutCheckpointInFlight then
            local slots = {}
            for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
                slots[slot] = SlotState(slot)
            end
            local removed = FeatherNativeWeaponCoordinator.ClearUnfundedPools(
                PlayerPedId(), slots, WeaponDefinitionCatalog)
            if Config.DevMode then
                for name, result in pairs(removed) do
                    print(('[feather-weapons] unfunded ammo cleanup type=%s before=%s after=%s')
                        :format(name, tostring(result.before), tostring(result.after)))
                end
            end
        end
    end
end)

local function RefreshSharedLonggunPools()
    local pools = {}
    for _, slot in ipairs({ 'shoulder', 'back' }) do
        local state = extraSlots[slot]
        if state and not state.ammoPools and type(state.nativeAmmoName) == 'string' then
            local observed = extraObserved[slot]
            local pool = pools[state.nativeAmmoName] or {
                count = 0, authorized = 0, loaded = 0, weapons = {}
            }
            local consumed = math.max(0, math.floor(tonumber(observed and observed.consumed) or 0))
            local loaded = math.max(0, math.floor(tonumber(observed and observed.loaded)
                or tonumber(state.loaded) or 0))
            pool.count = pool.count + 1
            pool.authorized = pool.authorized
                + math.max(0, math.floor(tonumber(state.ammo) or 0) - consumed)
            pool.loaded = pool.loaded + loaded
            pool.weapons[#pool.weapons + 1] = {
                nativeWeaponName = state.nativeWeaponName,
                loaded = loaded
            }
            pools[state.nativeAmmoName] = pool
        end
    end

    local ped = PlayerPedId()
    for nativeAmmoName, pool in pairs(pools) do
        if pool.count > 1 then
            SetPedAmmoByType(ped, joaat(nativeAmmoName), pool.loaded)
            for _, weapon in ipairs(pool.weapons) do
                if type(weapon.nativeWeaponName) == 'string' then
                    SetAmmoInClip(ped, joaat(weapon.nativeWeaponName), weapon.loaded)
                end
            end
            SetPedAmmoByType(ped, joaat(nativeAmmoName), pool.loaded)
            if Config.DevMode then
                print(('[feather-weapons] shared long-gun pool authorized=%d nativeClips=%d')
                    :format(pool.authorized, pool.loaded))
            end
        end
    end
end

local function ClearSidearmsPreservingLongguns()
    RemoveNativePairCopies()
    if equipped and equipped.nativeWeaponName then
        RemoveNativeWeapon(PlayerPedId(), joaat(equipped.nativeWeaponName))
    end

    if offhand and offhand.nativeWeaponName then
        RemoveNativeWeapon(PlayerPedId(), joaat(offhand.nativeWeaponName))
    end

    RemoveOffhandEntitlements()
    equipped, offhand, desiredAmmo, desiredLoaded, syncInFlight = nil, nil, nil, nil, false
    pairSyncInFlight, pairCheckpointPending, pairObserved = false, false, nil
    pairConsumed = { primary = 0, offhand = 0 }
    pairSingleFallback = nil
    pairFallbackPending = nil
end

local function CopyAmmoPools(pools)
    if type(pools) ~= 'table' then return nil end
    local result = {}
    for id, total in pairs(pools) do result[id] = total end
    return result
end

local function ApprovedState(approved)
    return {
        slot = approved.slot or 'primary',
        itemInstanceId = approved.itemInstanceId,
        serialNumber = approved.serialNumber,
        definitionId = approved.definitionId,
        nativeWeaponName = approved.nativeWeaponName,
        ammunitionType = approved.ammunitionType,
        nativeAmmoName = approved.nativeAmmoName,
        ammoPools = CopyAmmoPools(approved.ammoPools),
        ammo = tonumber(approved.ammo) or 0,
        condition = tonumber(approved.condition),
        maintenance = type(approved.maintenance) == 'table' and approved.maintenance or {
            degradation = 0.0,
            permanentDegradation = 0.0,
            damage = 0.0,
            dirt = 0.0,
            soot = 0.0
        },
        loaded = tonumber(approved.loaded) or 0,
        reserve = tonumber(approved.reserve) or 0,
        capacity = math.max(0, math.floor(tonumber(approved.capacity) or 0)),
        generation = tonumber(approved.generation),
        sessionId = approved.sessionId,
        attachments = approved.attachments or {}
    }
end

local function RestoreKnifePools(state, observed)
    if not state.ammoPools then return end
    local ped, weapon = PlayerPedId(), joaat(state.nativeWeaponName)
    local definition = WeaponDefinitionCatalog.weapons[state.definitionId]
    if definition.family ~= 'throwing_knife' then return end
    observed.pools, observed.poolReady = CopyAmmoPools(state.ammoPools), {}
    for _, id in ipairs(definition.ammunitionTypes) do
        local ammunition = WeaponDefinitionCatalog.ammunition[id]
        local amount, hash = state.ammoPools[id] or 0, joaat(ammunition.nativeAmmoName)
        observed.pools[id] = amount
        Citizen.InvokeNative(amount > 0 and 0x23FB9FACA28779C1 or 0xF0D728EEA3C99775, ped, weapon, hash)
        SetPedAmmoByType(ped, hash, amount)
    end
    Citizen.InvokeNative(0xCC9C4393523833E2, ped, weapon, joaat(state.nativeAmmoName))
    for _, id in ipairs(definition.ammunitionTypes) do
        local hash = joaat(WeaponDefinitionCatalog.ammunition[id].nativeAmmoName)
        observed.poolReady[id] = tonumber(GetPedAmmoByType(ped, hash)) == (state.ammoPools[id] or 0)
        if not observed.poolReady[id] then
            Notify('A knife pool failed verification. Saved ammunition is preserved for unloading.')
        end
    end
end

local function ObserveKnifePools(state, observed)
    if not observed.pools then observed.pools, observed.poolReady = CopyAmmoPools(state.ammoPools), {} end
    local definition, ped = WeaponDefinitionCatalog.weapons[state.definitionId], PlayerPedId()
    for _, id in ipairs(definition.ammunitionTypes) do
        local approved = state.ammoPools[id] or 0
        if observed.pools[id] == nil then observed.pools[id] = approved end
        local native = math.max(0, tonumber(GetPedAmmoByType(ped,
            joaat(WeaponDefinitionCatalog.ammunition[id].nativeAmmoName))) or 0)
        local simulated = Config.DevMode and observed.simulatePoolFailure and id == state.ammunitionType
        if not observed.poolReady[id] and not simulated and native == approved then observed.poolReady[id] = true end
        if observed.poolReady[id] and not simulated then
            -- Pickup conversion is not ownership. Only observe decreases.
            observed.pools[id] = math.min(observed.pools[id] or approved, native)
        end
    end
    local selectedOk, selectedWeapon = GetCurrentPedWeapon(ped, true, 0, false)
    if NativeTrue(selectedOk) and selectedWeapon == joaat(state.nativeWeaponName) then
        local called, hash = pcall(function()
            local object = Citizen.InvokeNative(0x6CA484C9A7377E4F, ped, false)
            if type(object) ~= 'number' or object == 0 then return nil end
            return Citizen.InvokeNative(0x7E7B19A4355FEE13, ped, object)
        end)
        if called and type(hash) == 'number' then
            for _, id in ipairs(definition.ammunitionTypes) do
                if hash % 4294967296 == joaat(WeaponDefinitionCatalog.ammunition[id].nativeAmmoName) % 4294967296 then
                    observed.selectedType = id
                end
            end
        end
    end
end

local function AwaitSingleNativeRestore(state)
    singleRestoreSequence = singleRestoreSequence + 1
    -- Pool firearms are verified as a complete loadout, not by legacy
    -- single-type corrections which can materialize a duplicate native clip.
    if state.ammoPools then return end
    local sequence = singleRestoreSequence
    singleNativeReady = false
    CreateThread(function()
        local ped = PlayerPedId()
        local weaponHash = joaat(state.nativeWeaponName)
        local ammoHash = joaat(state.nativeAmmoName)
        for _ = 1, 40 do
            if sequence ~= singleRestoreSequence or not equipped
                or not SameInstance(equipped.itemInstanceId, state.itemInstanceId)
                or equipped.generation ~= state.generation then
                return
            end

            local clipOk, clipAmount = GetAmmoInClip(ped, weaponHash)
            local observedLoaded = math.max(0, math.floor(tonumber(clipAmount) or 0))
            local nativeTotal = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
            if nativeTotal < state.ammo then
                -- Re-equipping the same sidearm can leave RedM's wheel cache
                -- exposing only its materialized clip. Restore only the
                -- server-approved deficit; this cannot create ownership.
                Citizen.InvokeNative(0x106A811C6D3035F3, ped, ammoHash,
                    state.ammo - nativeTotal, joaat('ADD_REASON_DEFAULT')) -- GiveAmmoToPedByType
                nativeTotal = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
            elseif nativeTotal > state.ammo then
                SetPedAmmoByType(ped, ammoHash, state.ammo)
                nativeTotal = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
            end
            if NativeTrue(clipOk) and observedLoaded == state.loaded
                and nativeTotal == state.ammo then
                singleNativeReady = true
                if Config.DevMode then
                    print(('[feather-weapons] native single weapon ready item=%s total=%s')
                        :format(tostring(state.itemInstanceId), tostring(nativeTotal)))
                end
                return
            end
            if nativeTotal == state.ammo and observedLoaded ~= state.loaded then
                SetAmmoInClip(ped, weaponHash, state.loaded)
            end
            Wait(50)
        end

        if Config.DevMode and sequence == singleRestoreSequence then
            print(('[feather-weapons] native single weapon restore deferred item=%s expectedTotal=%s')
                :format(tostring(state.itemInstanceId), tostring(state.ammo)))
        end
    end)
end

local function ApplySlotMaintenance(slot, state)
    if not state then return false end

    return FeatherNativeMaintenance.Apply(PlayerPedId(), slot, state)
end

local function ScheduleMaintenanceRestore()
    for _, delay in ipairs({ 0, 250, 1000 }) do
        SetTimeout(delay, function()
            ApplySlotMaintenance('primary', equipped)
            ApplySlotMaintenance('offhand', offhand)
            ApplySlotMaintenance('shoulder', extraSlots.shoulder)
            ApplySlotMaintenance('back', extraSlots.back)
            ApplySlotMaintenance('melee', extraSlots.melee)
            ApplySlotMaintenance('melee_secondary', extraSlots.melee_secondary)
            ApplySlotMaintenance('melee_tertiary', extraSlots.melee_tertiary)
            ApplySlotMaintenance('utility', extraSlots.utility)
            ApplySlotMaintenance('utility_secondary', extraSlots.utility_secondary)
            ApplySlotMaintenance('utility_tertiary', extraSlots.utility_tertiary)
            ApplySlotMaintenance('utility_quaternary', extraSlots.utility_quaternary)
            ApplySlotMaintenance('utility_quinary', extraSlots.utility_quinary)
            ApplySlotMaintenance('utility_senary', extraSlots.utility_senary)
            ApplySlotMaintenance('utility_septenary', extraSlots.utility_septenary)
            ApplySlotMaintenance('utility_octonary', extraSlots.utility_octonary)
            ApplySlotMaintenance('melee_quaternary', extraSlots.melee_quaternary)
            ApplySlotMaintenance('melee_quinary', extraSlots.melee_quinary)
            ApplySlotMaintenance('throwable', extraSlots.throwable)
            ApplySlotMaintenance('throwable_secondary', extraSlots.throwable_secondary)
            ApplySlotMaintenance('throwable_tertiary', extraSlots.throwable_tertiary)
            ApplySlotMaintenance('throwable_quaternary', extraSlots.throwable_quaternary)
            ApplySlotMaintenance('throwable_quinary', extraSlots.throwable_quinary)
            ApplySlotMaintenance('throwable_senary', extraSlots.throwable_senary)
            ApplySlotMaintenance('throwable_septenary', extraSlots.throwable_septenary)
            ApplySlotMaintenance('throwable_octonary', extraSlots.throwable_octonary)
            ApplySlotMaintenance('throwable_nonary', extraSlots.throwable_nonary)
            ApplySlotMaintenance('throwable_denary', extraSlots.throwable_denary)
        end)
    end
end

local function SyncSlotMaintenance(slot, state, callback)
    local cooldown = inventoryMutationCooldownUntil - GetGameTimer()
    if cooldown > 0 then
        SetTimeout(cooldown, function() SyncSlotMaintenance(slot, state, callback) end)
        return
    end

    if not state or maintenanceSyncInFlight[slot] then
        if callback then callback({ ok = true, value = { skipped = true } }) end
        return
    end

    local ammoBusy = (slot == 'primary' and (syncInFlight or pairSyncInFlight))
        or (slot == 'offhand' and pairSyncInFlight)
        or (extraSyncInFlight[slot] == true)
    if ammoBusy then
        if callback then callback({ ok = true, value = { deferred = true } }) end
        return
    end

    local observed = FeatherNativeMaintenance.Read(PlayerPedId(), slot, state)
    if not observed then
        if callback then callback({ ok = true, value = { unavailable = true } }) end
        return
    end

    local saved, changed = state.maintenance or {}, false
    for _, field in ipairs({ 'degradation', 'permanentDegradation', 'damage', 'dirt', 'soot' }) do
        if math.abs((tonumber(observed[field]) or 0.0) - (tonumber(saved[field]) or 0.0)) >= 0.005 then
            changed = true
            break
        end
    end

    if not changed then
        if callback then callback({ ok = true, value = { unchanged = true } }) end
        return
    end

    maintenanceSyncInFlight[slot] = true
    local itemInstanceId, generation = state.itemInstanceId, state.generation
    FeatherCore.RPC.Call('feather-weapons:maintenance:sync', {
        slot = slot,
        itemInstanceId = itemInstanceId,
        generation = generation,
        maintenance = observed
    }, function(result, rpcError)
        inventoryMutationCooldownUntil = GetGameTimer() + 150
        maintenanceSyncInFlight[slot] = nil
        local current = SlotState(slot)
        if current and SameInstance(current.itemInstanceId, itemInstanceId)
            and current.generation == generation and result and result.ok then
            current.maintenance = result.value.maintenance
            current.condition = tonumber(result.value.condition) or current.condition
        elseif result and not result.ok and Config.DevMode then
            local failure = result.error or result
            print(('[feather-weapons] maintenance checkpoint failed slot=%s code=%s'):format(
                slot, tostring(failure.code)))
        end

        if callback then
            callback(result or rpcError or {
                ok = false,
                code = 'maintenance_checkpoint_failed',
                message = 'Native weapon maintenance could not be saved.'
            })
        end
    end)
end

local function CheckpointMaintenance(callback)
    if LifeStateSuspended() then callback({ok = true, value = {deferred = true}}); return end
    if maintenanceBatchInFlight or firearmPoolsInFlight then
        callback({ ok = true, value = { deferred = true } })
        return
    end

    local states = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local state = SlotState(slot)
        if state then states[#states + 1] = { slot = slot, state = state } end
    end

    if #states == 0 then
        callback({ ok = true, value = { skipped = true } })
        return
    end

    maintenanceBatchInFlight = true
    local failure
    local function SyncNext(index)
        if index > #states then
            maintenanceBatchInFlight = false
            callback(failure or { ok = true })
            return
        end

        local value = states[index]
        SyncSlotMaintenance(value.slot, value.state, function(result)
            if result and result.ok ~= true then failure = failure or result end
            SyncNext(index + 1)
        end)
    end
    SyncNext(1)
end

local function ApplyApprovedPair(primary, secondary)
    if equipped and offhand
        and SameInstance(equipped.itemInstanceId, primary.itemInstanceId)
        and SameInstance(offhand.itemInstanceId, secondary.itemInstanceId)
        and equipped.generation == tonumber(primary.generation)
        and offhand.generation == tonumber(secondary.generation)
        and NativePairAvailable(primary, secondary) then
        equipped, offhand = ApprovedState(primary), ApprovedState(secondary)
        ScheduleMaintenanceRestore()
        return true
    end

    local restoringFromSingleFallback = pairSingleFallback ~= nil
    ClearNativeWeapon()
    if restoringFromSingleFallback then
        -- Removing a depleted hand promotes its survivor into RedM's primary
        -- attachment. Rebuilding the pair in that same native frame can leave
        -- the survivor bound to its promoted slot, so the requested offhand
        -- clip never materializes. Give removal one bounded transition before
        -- recreating the persisted primary/offhand layout.
        Wait(100)
    end
    equipped, offhand = ApprovedState(primary), ApprovedState(secondary)
    local restored, message = RestoreApprovedNativePair(equipped, offhand)
    if not restored then
        ClearNativeWeapon()
        return false, message
    end

    local primaryOk, primaryLoaded, offhandOk, offhandLoaded = PairNativeClips(equipped, offhand)
    pairObserved = {
        primary = primaryOk and math.max(0, math.floor(tonumber(primaryLoaded) or 0)) or 0,
        offhand = offhandOk and math.max(0, math.floor(tonumber(offhandLoaded) or 0)) or 0,
        total = PairNativeTotal(equipped, offhand)
    }
    FeatherNativeWeaponCoordinator.TrackAmmoWindows(PlayerPedId(), {
        primary = equipped,
        offhand = offhand
    })
    pairConsumed = { primary = 0, offhand = 0 }
    SetTimeout(0, function()
        if equipped and offhand
            and SameInstance(equipped.itemInstanceId, primary.itemInstanceId)
            and SameInstance(offhand.itemInstanceId, secondary.itemInstanceId) then
            local nativeLoaded = pairObserved.primary + pairObserved.offhand
            local approvedLoaded = equipped.loaded + offhand.loaded
            if nativeLoaded > 0 or approvedLoaded == 0 then
                FlushPairConsumption()
            elseif Config.DevMode then
                print('[feather-weapons] initial pair checkpoint deferred: native clips did not materialize')
            end
        end
    end)

    if Config.DevMode then
        print(('[feather-weapons] pair restored primary=%s/%s offhand=%s/%s total=%d loaded=%d/%d')
            :format(tostring(equipped.itemInstanceId), equipped.nativeWeaponName, tostring(offhand.itemInstanceId),
                offhand.nativeWeaponName, pairObserved.total, pairObserved.primary, pairObserved.offhand))
    end
    ScheduleMaintenanceRestore()
    return true
end

local function ApplyApprovedWeapon(approved)
    local alreadyApplied = not offhand
        and ((equipped and SameInstance(equipped.itemInstanceId, approved.itemInstanceId))
            or (pendingNativeWeaponName == approved.nativeWeaponName)
        )
    if not alreadyApplied then
        ClearNativeWeapon()
    end

    -- Even when the same Inventory instance is still materialized, RedM can
    -- rebuild its wheel entry from the clip alone during a holster/re-equip.
    -- Re-grant the approved snapshot so the wheel cache includes reserve.
    GiveApprovedNativeWeapon(approved.nativeWeaponName, approved.nativeAmmoName, approved.ammo, approved.loaded,
        approved.attachments)

    equipped = ApprovedState(approved)
    desiredAmmo = equipped.ammo
    desiredLoaded = equipped.loaded
    AwaitSingleNativeRestore(equipped)

    ScheduleMaintenanceRestore()
end

local function FlushConsumption()
    if LifeStateSuspended() then return end
    if FirearmPoolsActive() then FlushFirearmPools(ResolveCheckpointWaiters); return end
    if maintenanceSyncInFlight.primary then
        SetTimeout(50, FlushConsumption)
        return
    end

    if syncInFlight then return end

    if not equipped then
        ResolveCheckpointWaiters({ ok = true, value = { skipped = true } })
        return
    end

    if desiredAmmo == nil or desiredAmmo > equipped.ammo then
        ResolveCheckpointWaiters({
            ok = false,
            code = 'invalid_native_state',
            message =
            'Native ammunition state is invalid.'
        })
        return
    end

    if desiredAmmo == equipped.ammo and desiredLoaded == equipped.loaded then
        ResolveCheckpointWaiters({
            ok = true,
            value = {
                total = equipped.ammo, loaded = equipped.loaded, reserve = equipped.reserve
            }
        })
        return
    end

    syncInFlight = true
    local submitted = desiredAmmo
    local submittedLoaded = desiredLoaded or (equipped.loaded or 0)
    local leaseItem = equipped.itemInstanceId
    local leaseGeneration = equipped.generation
    FeatherCore.RPC.Call('feather-weapons:ammo:sync', {
        total = submitted,
        loaded = submittedLoaded,
        itemInstanceId = leaseItem,
        generation = leaseGeneration
    }, function(result)
        syncInFlight = false
        if not equipped or not SameInstance(equipped.itemInstanceId, leaseItem)
            or equipped.generation ~= leaseGeneration then
            return
        end

        if result and result.ok then
            equipped.ammo = tonumber(result.value.total) or submitted
            equipped.loaded = tonumber(result.value.loaded) or submittedLoaded
            equipped.reserve = tonumber(result.value.reserve) or (equipped.ammo - equipped.loaded)
            equipped.condition = tonumber(result.value.condition) or equipped.condition
            if Config.DevMode then
                print(('[feather-weapons] checkpoint consumed=%s total=%s loaded=%s condition=%s'):format(
                    tostring(result.value.consumed), tostring(equipped.ammo),
                    tostring(equipped.loaded), tostring(equipped.condition)))
            end

            if result.value.broken then
                print('[feather-weapons] weapon condition is broken')
                ClearNativeWeapon()
                return
            end

            if desiredAmmo > equipped.ammo then
                desiredAmmo = equipped.ammo
            end
        else
            ResolveCheckpointWaiters(result or {
                ok = false,
                code = 'checkpoint_failed',
                message = 'Weapon state could not be saved.'
            })
            FeatherWeaponsClient.Reconcile()
            return
        end

        if desiredAmmo < equipped.ammo or desiredLoaded ~= equipped.loaded then
            FlushConsumption()
        else
            ResolveCheckpointWaiters({
                ok = true,
                value = {
                    total = equipped.ammo, loaded = equipped.loaded, reserve = equipped.reserve
                }
            })
        end

        if unloadQueued then
            unloadQueued = false
            BeginUnload()
        end
    end)
end

local function CaptureNativeState()
    if LifeStateSuspended() then return end
    if not equipped then return true end

    local ped = PlayerPedId()
    local clipOk, clipAmount = GetAmmoInClip(ped, joaat(equipped.nativeWeaponName))
    local observedTotal = math.max(0, math.floor(tonumber(
        GetPedAmmoByType(ped, joaat(equipped.nativeAmmoName))) or 0))
    if observedTotal > equipped.ammo then return false end

    desiredAmmo = observedTotal
    if clipOk == true or clipOk == 1 then
        desiredLoaded = math.max(0, math.min(observedTotal, math.floor(tonumber(clipAmount) or 0)))
    end

    return true
end

local function CapturePairNativeState()
    local primary = equipped
    local secondary = offhand
    if not primary or not secondary then return false end

    local primaryOk, primaryLoaded, offhandOk, offhandLoaded = ObservablePairClips(primary, secondary)
    if not primaryOk or not offhandOk then return false end

    local total = PairNativeTotal(primary, secondary)
    primaryLoaded = math.max(0, math.floor(tonumber(primaryLoaded) or 0))
    offhandLoaded = math.max(0, math.floor(tonumber(offhandLoaded) or 0))
    local observed = pairObserved or {
        primary = primaryLoaded,
        offhand = offhandLoaded,
        total = total
    }
    pairObserved = observed
    if primaryLoaded < observed.primary then
        pairConsumed.primary = pairConsumed.primary + (observed.primary - primaryLoaded)
    end

    if offhandLoaded < observed.offhand then
        pairConsumed.offhand = pairConsumed.offhand + (observed.offhand - offhandLoaded)
    end

    observed.primary = primaryLoaded
    observed.offhand = offhandLoaded
    observed.total = total
    return total <= (primary.ammo + secondary.ammo)
end

FlushPairConsumption = function()
    if LifeStateSuspended() then return end
    if FirearmPoolsActive() then FlushFirearmPools(ResolveCheckpointWaiters); return end
    local cooldown = inventoryMutationCooldownUntil - GetGameTimer()
    if cooldown > 0 then
        SetTimeout(cooldown, FlushPairConsumption)
        return
    end

    if maintenanceSyncInFlight.primary or maintenanceSyncInFlight.offhand then
        SetTimeout(50, FlushPairConsumption)
        return
    end

    if pairSyncInFlight then return end

    local captured = CapturePairNativeState()
    local capturedBeforeFallback = pairSingleFallback and pairObserved
        and (pairConsumed.primary > 0 or pairConsumed.offhand > 0)
    if not captured and not capturedBeforeFallback then
        ResolveCheckpointWaiters({
            ok = false,
            code = 'invalid_native_state',
            message = 'Native pair ammunition state is invalid.'
        })
        return
    end

    local observed = pairObserved
    local primary = equipped
    local secondary = offhand
    if not observed or not primary or not secondary then
        ResolveCheckpointWaiters({
            ok = false,
            code = 'pair_state_changed',
            message = 'Weapon pair changed before its ammunition checkpoint.'
        })
        return
    end

    -- RedM may reload both distinct weapon hashes from one shared native ammo
    -- pool even when only one Inventory instance owns reserve. Clamp any clip
    -- increase that the corresponding instance cannot fund before persisting it.
    if primary.nativeAmmoName == secondary.nativeAmmoName then
        local ped = PlayerPedId()
        for slot, state in pairs({ primary = primary, offhand = secondary }) do
            local consumed = pairConsumed[slot]
            local authorizedLoaded = math.max(0,
                (tonumber(state.loaded) or 0) - consumed + (tonumber(state.reserve) or 0))
            if observed[slot] > authorizedLoaded then
                SetAmmoInClip(ped, joaat(state.nativeWeaponName), authorizedLoaded)
                if Config.DevMode then
                    print(('[feather-weapons] blocked shared native reload slot=%s observed=%d restored=%d reserve=%d')
                        :format(slot, observed[slot], authorizedLoaded,
                            math.max(0, math.floor(tonumber(state.reserve) or 0))))
                end
                observed[slot] = authorizedLoaded
            end
        end
    end

    local submitted = {
        -- Native totals are only a bounded runtime window. Inventory-backed
        -- ownership is reduced exclusively by confirmed per-GUID shots.
        total = math.max(0, primary.ammo + secondary.ammo - pairConsumed.primary - pairConsumed.offhand),
        primaryLoaded = observed.primary,
        offhandLoaded = observed.offhand,
        primaryConsumed = pairConsumed.primary,
        offhandConsumed = pairConsumed.offhand,
        primaryItem = primary.itemInstanceId,
        offhandItem = secondary.itemInstanceId,
        primaryGeneration = primary.generation,
        offhandGeneration = secondary.generation
    }
    if submitted.primaryConsumed == 0 and submitted.offhandConsumed == 0
        and submitted.primaryLoaded == primary.loaded
        and submitted.offhandLoaded == secondary.loaded
        and submitted.total == primary.ammo + secondary.ammo then
        ResolveCheckpointWaiters({
            ok = true,
            value = {
                total = submitted.total,
                slots = { primary = primary, offhand = secondary }
            }
        })
        return
    end

    pairSyncInFlight = true
    FeatherCore.RPC.Call('feather-weapons:ammo:pairSync', {
        total = submitted.total,
        slots = {
            primary = {
                itemInstanceId = submitted.primaryItem,
                generation = submitted.primaryGeneration,
                loaded = submitted.primaryLoaded,
                consumed = submitted.primaryConsumed
            },
            offhand = {
                itemInstanceId = submitted.offhandItem,
                generation = submitted.offhandGeneration,
                loaded = submitted.offhandLoaded,
                consumed = submitted.offhandConsumed
            }
        }
    }, function(result)
        inventoryMutationCooldownUntil = GetGameTimer() + 150
        pairSyncInFlight = false
        local currentPrimary = equipped
        local currentOffhand = offhand
        local currentObserved = pairObserved
        if not currentPrimary or not currentOffhand or not currentObserved
            or not SameInstance(currentPrimary.itemInstanceId, submitted.primaryItem)
            or not SameInstance(currentOffhand.itemInstanceId, submitted.offhandItem) then
            return
        end

        if not result or not result.ok then
            ResolveCheckpointWaiters(result or {
                ok = false,
                code = 'checkpoint_failed',
                message = 'Weapon pair state could not be saved.'
            })
            FeatherWeaponsClient.Reconcile()
            return
        end

        for slot, state in pairs({ primary = currentPrimary, offhand = currentOffhand }) do
            local value = result.value.slots[slot]
            state.ammo = tonumber(value.total) or state.ammo
            state.loaded = tonumber(value.loaded) or state.loaded
            state.reserve = tonumber(value.reserve) or state.reserve
            state.condition = tonumber(value.condition) or state.condition
            pairConsumed[slot] = math.max(0, pairConsumed[slot] - (slot == 'primary'
                and submitted.primaryConsumed or submitted.offhandConsumed))
        end

        -- Depletion fallback is a presentation change, so apply it only after
        -- the zero-round observation has been committed to both item records.
        if pairFallbackPending and not pairSingleFallback then
            local fallbackSlot = pairFallbackPending
            local depleted = fallbackSlot == 'primary' and currentOffhand or currentPrimary
            local survivor = fallbackSlot == 'primary' and currentPrimary or currentOffhand
            if (tonumber(depleted.loaded) or 0) == 0
                and (tonumber(survivor.loaded) or 0) > 0 then
                pairFallbackPending = nil
                ActivateLoadedPairSlot(PlayerPedId(), fallbackSlot, survivor)
            end
        end

        if currentPrimary.nativeAmmoName == currentOffhand.nativeAmmoName then
            FeatherNativeWeaponCoordinator.ReplenishAmmoWindows(PlayerPedId(), {
                primary = currentPrimary,
                offhand = currentOffhand
            })
        else
            -- Independent native pools already account for their own clips.
            -- Replenishing them through SetPedAmmoByType can mint a round when
            -- RedM applies selected-weapon reserve semantics.
            FeatherNativeWeaponCoordinator.TrackAmmoWindows(PlayerPedId(), {
                primary = currentPrimary,
                offhand = currentOffhand
            })
        end
        currentObserved.total = PairNativeTotal(currentPrimary, currentOffhand)

        if pairConsumed.primary > 0 or pairConsumed.offhand > 0
            or currentObserved.primary ~= currentPrimary.loaded
            or currentObserved.offhand ~= currentOffhand.loaded then
            FlushPairConsumption()
        else
            ResolveCheckpointWaiters(result)
        end
    end)
end

function FeatherWeaponsClient.Checkpoint(callback, skipExtras)
    callback = type(callback) == 'function' and callback or function(_result) end
    if LifeStateSuspended() then
        callback({ok = true, value = {deferred = true, reason = 'character_not_alive'}})
        return
    end

    if FirearmPoolsActive() and not skipExtras then
        FlushFirearmPools(function(result)
            if not result or not result.ok then callback(result); return end
            -- Firearms have committed atomically; independently checkpoint knives.
            local slots = {}
            for _, slot in ipairs(extraSlotNames) do
                if extraSlots[slot] and WeaponConstants.ThrowableSlots[slot] then slots[#slots + 1] = slot end
            end
            local function Next(index)
                if index > #slots then callback(result); return end
                FlushExtraSlot(slots[index], function(value)
                    if not value or not value.ok then callback(value); return end
                    Next(index + 1)
                end)
            end
            Next(1)
        end)
        return
    end

    local extras = {}
    for _, slot in ipairs({ 'shoulder', 'back', 'throwable', 'throwable_secondary', 'throwable_tertiary', 'throwable_quaternary', 'throwable_quinary', 'throwable_senary', 'throwable_septenary', 'throwable_octonary', 'throwable_nonary', 'throwable_denary' }) do
        if extraSlots[slot] then extras[#extras + 1] = slot end
    end
    if not skipExtras and #extras > 0 then
        local index
        index = function(position)
            if position > #extras then
                FeatherWeaponsClient.Checkpoint(callback, true)
                return
            end
            local slot = extras[position]
            FlushExtraSlot(slot, function(result)
                if not result or not result.ok then
                    callback(result); return
                end
                index(position + 1)
            end)
        end
        index(1)
        return
    end

    checkpointWaiters[#checkpointWaiters + 1] = callback
    if offhand then
        FlushPairConsumption()
        return
    end

    if not CaptureNativeState() then
        ResolveCheckpointWaiters({
            ok = false,
            code = 'invalid_native_state',
            message = 'Native ammunition exceeded the active weapon lease.'
        })
        return
    end

    FlushConsumption()
end

local function ScheduleRestoredWeaponsHolster()
    holsterSequence = holsterSequence + 1
    local sequence = holsterSequence
    presentationRestoreInFlight = true
    singleRestoreSequence = singleRestoreSequence + 1
    singleNativeReady = false
    local expected = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local state = SlotState(slot)
        expected[slot] = state and {
            itemInstanceId = state.itemInstanceId,
            generation = state.generation
        } or false
    end

    for _, delay in ipairs({ 0, 250, 750, 1500, 3000 }) do
        SetTimeout(delay, function()
            if sequence ~= holsterSequence then return end
            for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
                local state, wanted = SlotState(slot), expected[slot]
                if (wanted == false and state ~= nil)
                    or (wanted ~= false and (not state
                        or not SameInstance(state.itemInstanceId, wanted.itemInstanceId)
                        or tonumber(state.generation) ~= tonumber(wanted.generation))) then
                    return
                end
            end
            if equipped and offhand and (equipped.loaded + offhand.loaded) > 0 then
                local primaryOk, primaryLoaded, offhandOk, offhandLoaded =
                    PairNativeClips(equipped, offhand)
                if (not primaryOk and equipped.loaded > 0) or (not offhandOk and offhand.loaded > 0)
                    or (math.max(0, tonumber(primaryLoaded) or 0)
                        + math.max(0, tonumber(offhandLoaded) or 0)) == 0 then
                    if Config.DevMode and delay == 3000 then
                        print('[feather-weapons] restored weapons holster deferred: native clips are not ready')
                    end
                    return
                end
            end
            -- Pair creation and native reload can select a hand after the
            -- reconcile callback returns. Reassert unarmed through that short
            -- settle window so character/resource restores finish holstered.
            local ped = PlayerPedId()
            HolsterPedWeapons(ped, true, true, true, true)
            SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true, 0, false, false)

            if delay == 3000 then
                if equipped and not offhand then
                    -- Character selection can also leave a single sidearm's
                    -- wheel cache showing only its clip while the ammo-type
                    -- pool remains exact. Recreate it after the character
                    -- settles for the same reason as an isolated long gun.
                    GiveApprovedNativeWeapon(equipped.nativeWeaponName,
                        equipped.nativeAmmoName, equipped.ammo, equipped.loaded,
                        equipped.attachments)
                    AwaitSingleNativeRestore(equipped)
                elseif equipped and offhand then
                    local primaryOk, primaryLoaded, offhandOk, offhandLoaded =
                        PairNativeClips(equipped, offhand)
                    pairObserved = {
                        primary = primaryOk and math.max(0, math.floor(tonumber(primaryLoaded) or 0)) or 0,
                        offhand = offhandOk and math.max(0, math.floor(tonumber(offhandLoaded) or 0)) or 0,
                        total = PairNativeTotal(equipped, offhand)
                    }
                end
                for _, slot in ipairs({ 'shoulder', 'back' }) do
                    local state = extraSlots[slot]
                    local other = extraSlots[slot == 'shoulder' and 'back' or 'shoulder']
                    if state and (not other
                        or other.nativeAmmoName ~= state.nativeAmmoName) then
                        -- Character selection can rebuild RedM's per-weapon
                        -- wheel cache after the first grant. The ammo-type pool
                        -- remains exact, but the wheel then exposes only the
                        -- loaded clip until the weapon instance is recreated.
                        -- Recreate isolated long guns after the character has
                        -- settled so wheel, pool, and persisted total agree.
                        GiveApprovedNativeWeapon(state.nativeWeaponName,
                            state.nativeAmmoName, state.ammo, state.loaded,
                            state.attachments)
                    end
                end
                if FirearmPoolsActive() then
                    local allSlots = {}
                    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do allSlots[slot] = SlotState(slot) end
                    firearmPoolsEpoch = firearmPoolsEpoch + 1
                    local ready, failure = FeatherFirearmPools.Restore(ped, allSlots, WeaponDefinitionCatalog)
                    if not ready then
                        characterRestoreComplete = false
                        print(('[feather-weapons] settled firearm pool restore failed code=%s'):format(tostring(failure)))
                        Notify('Weapon ammunition restoration failed after holstering. Do not fire; restart weapons.')
                    end
                else
                    RefreshSharedLonggunPools()
                end
                presentationRestoreInFlight = false
            end

            if Config.DevMode and delay == 3000 then
                print(('[feather-weapons] restored weapons holstered=%s'):format(
                    tostring(NativeTrue(Citizen.InvokeNative(0xBDD9C235D8D1052E, ped))))) -- IsPedCurrentWeaponHolstered
            end
        end)
    end
end

function FeatherWeaponsClient.Reconcile(callback, options)
    options = type(options) == 'table' and options or {}
    FeatherCore.RPC.Call('feather-weapons:state:get', {}, function(result, rpcError)
        if not result or not result.ok then
            local failure = result and result.error or rpcError
            Notify(failure and failure.message or 'Weapon state could not be restored.')
            if Config.DevMode then
                print(('[feather-weapons] reconcile failed code=%s message=%s'):format(
                    tostring(failure and failure.code), tostring(failure and failure.message)))
            end
            if callback then
                callback(result, rpcError)
            end
            return
        end

        local slots = type(result.value.slots) == 'table' and result.value.slots or {}
        for _, slot in ipairs({ 'primary', 'offhand', 'shoulder', 'back' }) do
            if slots[slot] and slots[slot].ammoPools and not FirearmPoolModuleReady() then
                local failure = { ok = false, error = { code = 'firearm_pool_module_missing',
                    message = 'Firearm pool module missing. Deploy the complete Weapons resource and updated manifest.' } }
                Notify(failure.error.message)
                print('[feather-weapons] firearm pool module missing: client/firearm_pools.lua, shared/ammunition_pools.lua or updated fxmanifest.lua not loaded')
                if callback then callback(failure) end
                return
            end
        end
        if slots.primary and slots.offhand then
            local applied, message = ApplyApprovedPair(slots.primary, slots.offhand)
            if not applied then
                local failure = {
                    ok = false,
                    error = {
                        code = 'native_pair_restore_failed',
                        message = message or 'Unable to restore the weapon pair.'
                    }
                }
                Notify(failure.error.message)
                if callback then callback(failure) end
                return
            end
        elseif slots.primary then
            ApplyApprovedWeapon(slots.primary)
        elseif slots.shoulder or slots.back or slots.melee or slots.melee_secondary
            or slots.melee_tertiary or slots.utility_senary or slots.utility_septenary or slots.utility_octonary or slots.utility_quinary or slots.utility_quaternary or slots.utility_tertiary or slots.utility_secondary or slots.utility or slots.melee_quinary or slots.melee_quaternary or slots.throwable
            or slots.throwable_secondary or slots.throwable_tertiary or slots.throwable_quaternary or slots.throwable_quinary or slots.throwable_senary or slots.throwable_septenary or slots.throwable_octonary or slots.throwable_nonary or slots.throwable_denary then
            ClearSidearmsPreservingLongguns()
        else
            ClearNativeWeapon()
        end

        for _, slot in ipairs(extraSlotNames) do
            local approved = slots[slot]
            if approved then
                local state = ApprovedState(approved)
                local previous = extraSlots[slot]
                extraSlots[slot] = state
                extraObserved[slot] = { loaded = state.loaded, consumed = 0, recovered = 0 }
                if not previous
                    or not SameInstance(previous.itemInstanceId, state.itemInstanceId)
                    or previous.generation ~= state.generation then
                    if previous then
                        RemoveNativeWeapon(PlayerPedId(), joaat(previous.nativeWeaponName))
                    end
                    -- Feather owns the persistent logical slot, but RedM must
                    -- own the physical RIFLE/RIFLE_ALTERNATE placement. Forcing
                    -- point 9 or 10 can leave the alternate long gun visible
                    -- and selectable while unable to aim or fire.
                    GiveApprovedNativeWeapon(state.nativeWeaponName, state.nativeAmmoName,
                        state.ammo, state.loaded, state.attachments)
                end
                RestoreKnifePools(state, extraObserved[slot])
            else
                local stale = extraSlots[slot]
                if stale then
                    if type(stale.nativeWeaponName) == 'string' then
                        RemoveNativeWeapon(PlayerPedId(), joaat(stale.nativeWeaponName))
                    end
                    extraSlots[slot], extraObserved[slot] = nil, nil
                end
            end
        end

        if FirearmPoolsActive() then
            local allSlots = {}
            for _, slot in ipairs(WeaponConstants.LoadoutSlots) do allSlots[slot] = SlotState(slot) end
            firearmPoolsEpoch = firearmPoolsEpoch + 1
            local ready, failure = FeatherFirearmPools.Restore(PlayerPedId(), allSlots, WeaponDefinitionCatalog)
            if not ready then
                singleRestoreSequence = singleRestoreSequence + 1
                singleNativeReady = false
                local result = { ok = false, error = { code = failure, message = 'Funded firearm pools could not be restored.' } }
                print(('[feather-weapons] firearm pool restore failed code=%s'):format(tostring(failure)))
                Notify(result.error.message)
                if callback then callback(result) end
                return
            end
        else
            if FirearmPoolModuleReady() then FeatherFirearmPools.Reset() end
            RefreshSharedLonggunPools()
        end
        ScheduleMaintenanceRestore()
        if options.holster == true and (equipped or offhand or extraSlots.shoulder or extraSlots.back
            or extraSlots.melee or extraSlots.melee_secondary or extraSlots.melee_tertiary
            or extraSlots.utility_senary or extraSlots.utility_septenary or extraSlots.utility_octonary or extraSlots.utility_quinary or extraSlots.utility_quaternary or extraSlots.utility_tertiary or extraSlots.utility_secondary or extraSlots.utility or extraSlots.melee_quinary or extraSlots.melee_quaternary or extraSlots.throwable
            or extraSlots.throwable_secondary or extraSlots.throwable_tertiary or extraSlots.throwable_quaternary or extraSlots.throwable_quinary or extraSlots.throwable_senary or extraSlots.throwable_septenary or extraSlots.throwable_octonary or extraSlots.throwable_nonary or extraSlots.throwable_denary) then
            ScheduleRestoredWeaponsHolster()
        end

        if callback then
            callback(result)
        end
    end)
end

local function ThrowablePoolReady(slot, state, observed)
    if not WeaponConstants.ThrowableSlots[slot] then return true end
    if observed.nativePoolReady then return true end
    local approvedTotal = math.max(0, math.floor(tonumber(state.ammo) or 0))
    local nativeTotal = type(state.nativeAmmoName) == 'string' and math.max(0,
        math.floor(tonumber(GetPedAmmoByType(PlayerPedId(), joaat(state.nativeAmmoName))) or 0)) or 0
    if Config.DevMode and observed.simulatePoolFailure == true then
        nativeTotal = 0
    end
    if nativeTotal == approvedTotal then
        observed.nativePoolReady = true
        return true
    end
    -- A pool that never accepted the approved balance is not evidence of a
    -- throw. Preserve escrow so the owner can unload the exact selected type.
    if not observed.nativePoolWarning then
        observed.nativePoolWarning = true
        Notify('Throwable ammunition could not be verified in the native pool. Saved ammunition is preserved; unload it before changing types.')
        print(('[feather-weapons] throwable pool unverified slot=%s ammo=%s approved=%s native=%s')
            :format(slot, tostring(state.nativeAmmoName), tostring(approvedTotal), tostring(nativeTotal)))
    end
    return false
end

FlushExtraSlot = function(slot, callback)
    if LifeStateSuspended() then
        if callback then callback({ok = true, value = {deferred = true}}) end
        return
    end
    -- A partial/failed restore exposes transient zero native pools. Never
    -- persist those as shots while character startup is still rebuilding.
    if characterRestoreInFlight or not characterRestoreComplete then
        if callback then callback({ ok = false, error = { code = 'restore_not_ready',
            message = 'Ammunition checkpoint deferred until character restore completes.' } }) end
        return
    end
    if (slot == 'shoulder' or slot == 'back') and extraSlots[slot] and extraSlots[slot].ammoPools then
        FlushFirearmPools(callback)
        return
    end
    if maintenanceSyncInFlight[slot] then
        SetTimeout(50, function() FlushExtraSlot(slot, callback) end)
        return
    end

    local state = extraSlots[slot]
    local observed = extraObserved[slot]
    if extraSyncInFlight[slot] and callback then
        SetTimeout(50, function() FlushExtraSlot(slot, callback) end)
        return
    end
    if not state or not observed or extraSyncInFlight[slot] then
        if callback then callback({ ok = true, value = { skipped = true } }) end
        return
    end

    if state.ammoPools then
        ObserveKnifePools(state, observed)
        local selected = observed.selectedType or state.ammunitionType
        local changed = selected ~= state.ammunitionType
        for id, total in pairs(observed.pools) do
            if total ~= (state.ammoPools[id] or 0) then changed = true end
        end
        if not changed then
            if callback then callback({ ok = true, value = state }) end
            return
        end
        extraSyncInFlight[slot] = true
        local item, generation = state.itemInstanceId, state.generation
        FeatherCore.RPC.Call('feather-weapons:ammo:syncPools', {
            slot = slot, itemInstanceId = item, generation = generation,
            pools = CopyAmmoPools(observed.pools), ammunitionType = selected
        }, function(result, rpcError)
            extraSyncInFlight[slot] = false
            local current = extraSlots[slot]
            if current and SameInstance(current.itemInstanceId, item) and current.generation == generation then
                if result and result.ok then
                    current.ammoPools = CopyAmmoPools(result.value.pools)
                    current.ammunitionType = result.value.ammunitionType
                    current.nativeAmmoName = WeaponDefinitionCatalog.ammunition[current.ammunitionType].nativeAmmoName
                    current.ammo, current.loaded, current.reserve = result.value.total, result.value.loaded, result.value.reserve
                else
                    Notify('Knife pool checkpoint failed; restoring saved ownership.')
                    FeatherWeaponsClient.Reconcile()
                end
            end
            if callback then callback(result or { ok = false, error = rpcError }) end
        end)
        return
    end

    if not ThrowablePoolReady(slot, state, observed) then
        if callback then callback({ ok = true, value = state }) end
        return
    end

    local total = math.max(0, state.ammo - observed.consumed
        + math.floor(tonumber(observed.recovered) or 0))
    if observed.consumed == 0 and (tonumber(observed.recovered) or 0) == 0
        and observed.loaded == state.loaded then
        if callback then callback({ ok = true, value = state }) end
        return
    end

    extraSyncInFlight[slot] = true
    local itemInstanceId, generation = state.itemInstanceId, state.generation
    local submittedConsumed = observed.consumed
    local submittedRecovered = math.max(0, math.floor(tonumber(observed.recovered) or 0))
    FeatherCore.RPC.Call('feather-weapons:ammo:sync', {
        slot = slot,
        total = total,
        loaded = math.min(total, observed.loaded),
        itemInstanceId = itemInstanceId,
        generation = generation
    }, function(result, rpcError)
        extraSyncInFlight[slot] = false
        local current = extraSlots[slot]
        if not current or not SameInstance(current.itemInstanceId, itemInstanceId)
            or current.generation ~= generation then
            return
        end

        if result and result.ok then
            current.ammo = tonumber(result.value.total) or total
            current.loaded = tonumber(result.value.loaded) or observed.loaded
            current.reserve = tonumber(result.value.reserve) or (current.ammo - current.loaded)
            current.condition = tonumber(result.value.condition) or current.condition
            observed.consumed = math.max(0, observed.consumed - submittedConsumed)
            observed.recovered = math.max(0,
                math.floor(tonumber(observed.recovered) or 0) - submittedRecovered)
            if result.value.broken then
                ClearNativeWeapon()
                FeatherWeaponsClient.Reconcile()
            end
        else
            FeatherWeaponsClient.Reconcile()
        end

        if callback then callback(result or { ok = false, error = rpcError }) end
    end)
end

local function RecoverLostOffhandEntitlement()
    if offhandRecoveryInFlight or not equipped or not offhand then return end

    offhandRecoveryInFlight = true
    FeatherWeaponsClient.Checkpoint(function(checkpoint)
        if Config.DevMode then
            print(('[feather-weapons] offhand entitlement lost nativeCheckpoint=%s recovery=authoritative')
                :format(checkpoint and checkpoint.ok and 'available' or 'unavailable'))
        end

        ClearNativeWeapon()
        FeatherWeaponsClient.Reconcile(function(result)
            offhandRecoveryInFlight = false
            if not result or not result.ok then
                Notify('Offhand entitlement was lost and the weapon pair could not be restored.')
            end
        end)
    end)
end

function FeatherWeaponsClient.Equip(itemInstanceId, callback, slot)
    slot = slot or 'auto'
    FeatherCore.RPC.Call('feather-weapons:equip:request', { itemInstanceId = itemInstanceId, slot = slot }, function(result, rpcError)
    if not result or not result.ok then
        if callback then callback(result, rpcError) end
        return
    end

    local authorization = result.value
    pendingToken, pendingNativeWeaponName = authorization.token, authorization.nativeWeaponName

    FeatherCore.RPC.Call('feather-weapons:equip:acknowledge', { token = authorization.token },
        function(ack, ackError)
            if not ack or not ack.ok then
                pendingToken, pendingNativeWeaponName = nil, nil
                if callback then
                    callback(ack, ackError)
                end
                return
            end

            pendingToken, pendingNativeWeaponName = nil, nil
            FeatherWeaponsClient.Reconcile(function(reconciled, reconcileError)
                if callback then callback(reconciled, reconcileError) end
            end)
        end)
    end)
end

function FeatherWeaponsClient.Unequip(callback, slot)
    slot = slot or 'primary'
    -- Unequip is a persistence boundary. Save every active clip before any
    -- native weapon is removed so teardown cannot be mistaken for firing.
    FeatherWeaponsClient.Checkpoint(function(checkpoint)
        if not checkpoint or checkpoint.ok ~= true then
            if callback then
                callback(checkpoint or {
                    ok = false,
                    error = { message = 'Weapon state could not be saved before unequipping.' }
                })
            end
            return
        end

        FeatherCore.RPC.Call('feather-weapons:equip:unequip', { slot = slot }, function(result, rpcError)
            if result and result.ok then
                ClearNativeWeapon()
                FeatherWeaponsClient.Reconcile()
            end

            if callback then
                callback(result, rpcError)
            end
        end)
    end)
end

-- Read-only state used by isolated development diagnostics. The probe must not
-- replace or mutate an Inventory-authorized weapon.
function FeatherWeaponsClient.GetDiagnosticState()
    if not equipped and not offhand and not extraSlots.shoulder and not extraSlots.back
        and not extraSlots.melee and not extraSlots.melee_secondary
        and not extraSlots.melee_tertiary and not extraSlots.utility_senary and not extraSlots.utility_septenary and not extraSlots.utility_octonary and not extraSlots.utility_quinary and not extraSlots.utility_quaternary and not extraSlots.utility_tertiary and not extraSlots.utility_secondary and not extraSlots.utility and not extraSlots.melee_quinary and not extraSlots.melee_quaternary
        and not extraSlots.throwable and not extraSlots.throwable_secondary and not extraSlots.throwable_tertiary and not extraSlots.throwable_quaternary and not extraSlots.throwable_quinary and not extraSlots.throwable_senary and not extraSlots.throwable_septenary and not extraSlots.throwable_octonary and not extraSlots.throwable_nonary and not extraSlots.throwable_denary then
        return { equipped = false }
    end

    return {
        equipped = true,
        itemInstanceId = equipped and equipped.itemInstanceId or nil,
        definitionId = equipped and equipped.definitionId or nil,
        nativeWeaponName = equipped and equipped.nativeWeaponName or nil,
        nativeAmmoName = equipped and equipped.nativeAmmoName or nil,
        generation = equipped and equipped.generation or nil,
        sessionId = equipped and equipped.sessionId or nil,
        offhand = offhand and {
            itemInstanceId = offhand.itemInstanceId,
            definitionId = offhand.definitionId,
            nativeWeaponName = offhand.nativeWeaponName,
            generation = offhand.generation
        } or nil,
        shoulder = extraSlots.shoulder,
        back = extraSlots.back,
        melee = extraSlots.melee,
        melee_secondary = extraSlots.melee_secondary,
        melee_tertiary = extraSlots.melee_tertiary,
        utility = extraSlots.utility,
        utility_secondary = extraSlots.utility_secondary,
        utility_tertiary = extraSlots.utility_tertiary,
        utility_quaternary = extraSlots.utility_quaternary,
        utility_quinary = extraSlots.utility_quinary,
        utility_senary = extraSlots.utility_senary,
        utility_septenary = extraSlots.utility_septenary,
        utility_octonary = extraSlots.utility_octonary,
        melee_quaternary = extraSlots.melee_quaternary,
        melee_quinary = extraSlots.melee_quinary,
        throwable = extraSlots.throwable,
        throwable_secondary = extraSlots.throwable_secondary,
        throwable_tertiary = extraSlots.throwable_tertiary,
        throwable_quaternary = extraSlots.throwable_quaternary, throwable_quinary = extraSlots.throwable_quinary, throwable_senary = extraSlots.throwable_senary, throwable_septenary = extraSlots.throwable_septenary, throwable_octonary = extraSlots.throwable_octonary, throwable_nonary = extraSlots.throwable_nonary, throwable_denary = extraSlots.throwable_denary
    }
end

function FeatherWeaponsClient.Unload(amount, callback)
    local function performUnload()
        FeatherCore.RPC.Call('feather-weapons:ammo:unload', { amount = amount }, function(result, rpcError)
        if result and result.ok then
            local slot = result.value.slot or 'primary'
            local state = SlotState(slot)
            if state then
                state.ammo = tonumber(result.value.total) or 0
                state.loaded = tonumber(result.value.loaded) or 0
                state.reserve = tonumber(result.value.reserve) or 0
            end

            -- Rebuild every native ammo pool from authoritative slot metadata.
            ClearNativeWeapon()
            FeatherWeaponsClient.Reconcile()
        end

        if callback then
            callback(result, rpcError)
        end
        end)
    end
    for _, slot in ipairs(extraSlotNames) do
        if extraSlots[slot] and extraSlots[slot].ammoPools then
            FeatherWeaponsClient.Checkpoint(function(result)
                if not result or not result.ok then
                    if callback then callback(result or { ok = false, error = { message = 'Knife checkpoint failed' } }) end
                    return
                end
                performUnload()
            end)
            return
        end
    end
    performUnload()
end

BeginUnload = function()
    if unloadInFlight then return end

    if not equipped and not offhand and not extraSlots.shoulder and not extraSlots.back
        and not extraSlots.melee and not extraSlots.melee_secondary
        and not extraSlots.melee_tertiary and not extraSlots.utility_senary and not extraSlots.utility_septenary and not extraSlots.utility_octonary and not extraSlots.utility_quinary and not extraSlots.utility_quaternary and not extraSlots.utility_tertiary and not extraSlots.utility_secondary and not extraSlots.utility and not extraSlots.melee_quinary and not extraSlots.melee_quaternary
        and not extraSlots.throwable and not extraSlots.throwable_secondary and not extraSlots.throwable_tertiary and not extraSlots.throwable_quaternary and not extraSlots.throwable_quinary and not extraSlots.throwable_senary and not extraSlots.throwable_septenary and not extraSlots.throwable_octonary and not extraSlots.throwable_nonary and not extraSlots.throwable_denary then
        Notify('No weapon is equipped.')
        return
    end

    if equipped and (syncInFlight or (desiredAmmo ~= nil and desiredAmmo < equipped.ammo)) then
        unloadQueued = true
        FlushConsumption()
        return
    end

    local function unloadAfterCheckpoint()
        FeatherWeaponsClient.Unload(nil, function(result, rpcError)
            unloadInFlight = false
            if result and result.ok then
                Notify(('Unloaded %s round%s.'):format(
                    tostring(result.value.moved), result.value.moved == 1 and '' or 's'))
                return
            end

            local failure = result and result.error or rpcError
            Notify(failure and failure.message or 'Unable to unload.')
        end)
    end

    unloadInFlight = true
    if offhand then
        FeatherWeaponsClient.Checkpoint(function(checkpoint)
            if not checkpoint or checkpoint.ok ~= true then
                unloadInFlight = false
                local failure = checkpoint and (checkpoint.error or checkpoint)
                Notify(failure and failure.message
                    or 'Unable to checkpoint the weapon pair before unloading.')
                return
            end
            unloadAfterCheckpoint()
        end)
        return
    end
    unloadAfterCheckpoint()
end

function FeatherWeaponsClient.Repair(slot, callback)
    slot = slot or 'primary'
    local state = SlotState(slot)
    if not state then
        if callback then callback({ ok = false, error = { message = 'No weapon is equipped in that slot.' } }) end
        return
    end

    FeatherCore.RPC.Call('feather-weapons:repair', {
        slot = slot,
        itemInstanceId = state.itemInstanceId,
        generation = state.generation
    }, function(result, rpcError)
        if result and result.ok and state and SameInstance(state.itemInstanceId, result.value.itemInstanceId) then
            state.condition = tonumber(result.value.condition) or state.condition
            state.maintenance = result.value.maintenance or state.maintenance
            ScheduleMaintenanceRestore()
        end

        if callback then callback(result, rpcError) end
    end)
end

local function UseInventoryWeaponFromAuthoritativeState(itemInstanceId)
    for _, slot in ipairs(extraSlotNames) do
        local state = extraSlots[slot]
        if state and SameInstance(state.itemInstanceId, itemInstanceId) then
            FeatherWeaponsClient.Unequip(function(result, rpcError)
                inventoryWeaponInFlight = false
                if result and result.ok then
                    Notify('Weapon unequipped.')
                    return
                end
                local failure = result and result.error or rpcError
                Notify(failure and failure.message or 'Unable to unequip this weapon.')
            end, slot)
            return
        end
    end

    if offhand and SameInstance(offhand.itemInstanceId, itemInstanceId) then
        FeatherWeaponsClient.Unequip(function(result, rpcError)
            inventoryWeaponInFlight = false
            if result and result.ok then
                Notify('Offhand weapon unequipped.')
                return
            end

            local failure = result and result.error or rpcError
            Notify(failure and failure.message or 'Unable to unequip this weapon.')
        end, 'offhand')
        return
    end

    if equipped and SameInstance(equipped.itemInstanceId, itemInstanceId) then
        local promoting = offhand ~= nil
        FeatherWeaponsClient.Unequip(function(result, rpcError)
            inventoryWeaponInFlight = false
            if result and result.ok then
                Notify(promoting and 'Primary removed; offhand promoted.' or 'Weapon unequipped.')
                return
            end

            local failure = result and result.error or rpcError
            Notify(failure and failure.message or 'Unable to unequip this weapon.')
        end, 'primary')
        return
    end

    local requestedSlot = 'auto'
    FeatherWeaponsClient.Equip(itemInstanceId, function(result, rpcError)
        inventoryWeaponInFlight = false
        if result and result.ok then
            Notify('Weapon equipped.')
            if Config.DevMode then
                print(('[feather-weapons] inventory equip succeeded item=%s'):format(tostring(itemInstanceId)))
            end
            return
        end

        local failure = result and result.error or rpcError
        Notify(failure and failure.message or 'Unable to equip this weapon.')
        if Config.DevMode then
            print(('[feather-weapons] inventory equip failed item=%s code=%s message=%s'):format(
                tostring(itemInstanceId), tostring(failure and failure.code), tostring(failure and failure.message)))
        end
    end, requestedSlot)
end

RegisterNetEvent('feather-weapons:client:useInventoryWeapon', function(itemInstanceId)
    if inventoryWeaponInFlight then return end

    if Config.DevMode then
        print(('[feather-weapons] inventory weapon requested item=%s'):format(tostring(itemInstanceId)))
    end

    inventoryWeaponInFlight = true
    -- Inventory use is a toggle. Refresh the server-owned slots first so a
    -- resource restart cannot turn an unequip click into a duplicate equip.
    FeatherWeaponsClient.Reconcile(function(result, rpcError)
        if not result or not result.ok then
            inventoryWeaponInFlight = false
            return
        end
        -- A failed native restore clears local state, but server equipment
        -- remains authoritative. Recover the toggle using the returned slot
        -- rather than treating an already-equipped item as a new equip request.
        if not equipped and not offhand and not extraSlots.shoulder and not extraSlots.back
            and not extraSlots.melee and not extraSlots.melee_secondary
            and not extraSlots.melee_tertiary and not extraSlots.utility_senary and not extraSlots.utility_septenary and not extraSlots.utility_octonary and not extraSlots.utility_quinary and not extraSlots.utility_quaternary and not extraSlots.utility_tertiary and not extraSlots.utility_secondary and not extraSlots.utility and not extraSlots.melee_quinary and not extraSlots.melee_quaternary
            and not extraSlots.throwable and not extraSlots.throwable_secondary and not extraSlots.throwable_tertiary and not extraSlots.throwable_quaternary and not extraSlots.throwable_quinary and not extraSlots.throwable_senary and not extraSlots.throwable_septenary and not extraSlots.throwable_octonary and not extraSlots.throwable_nonary and not extraSlots.throwable_denary then
            for slot, approved in pairs(result.value and result.value.slots or {}) do
                if SameInstance(approved.itemInstanceId, itemInstanceId) then
                    FeatherWeaponsClient.Unequip(function(removed, error)
                        inventoryWeaponInFlight = false
                        local failure = removed and removed.error or error
                        Notify(removed and removed.ok and 'Weapon unequipped.'
                            or (failure and failure.message or 'Unable to unequip this weapon.'))
                    end, slot)
                    return
                end
            end
        end
        UseInventoryWeaponFromAuthoritativeState(itemInstanceId)
    end)
end)

local BuildModificationMenu

local function HandleAttachmentResult(result)
    if result and result.ok then
        local slot = result.value.slot or 'primary'
        local state = SlotState(slot)
        if not state or not SameInstance(state.itemInstanceId, result.value.itemInstanceId) then
            Notify('Weapon state changed; reconciling attachments.')
            FeatherWeaponsClient.Reconcile()
            return
        end

        state.attachments = result.value.attachments or {}
        local message = result.value.installed and 'Attachment installed.' or 'Attachment removed.'
        if offhand then
            ClearNativeWeapon()
            FeatherWeaponsClient.Reconcile(function(reconciled)
                Notify(reconciled and reconciled.ok and message
                    or 'Attachment changed, but the weapon pair could not be restored.')
                if reconciled and reconciled.ok and BuildModificationMenu then
                    BuildModificationMenu(slot)
                end
            end)
        else
            RestoreApprovedNativeWeapon(state.nativeWeaponName, state.nativeAmmoName, state.ammo,
                state.loaded, state.attachments)
            Notify(message)
            if BuildModificationMenu then BuildModificationMenu(slot) end
        end
        return
    end

    local failure = result and result.error
    Notify(failure and failure.message or 'Unable to modify this weapon.')
end

local function RequestAttachmentMutation(route, request)
    FeatherWeaponsClient.Checkpoint(function(checkpoint)
        if not checkpoint or not checkpoint.ok then
            local failure = checkpoint and checkpoint.error or nil
            Notify(failure and failure.message
                or 'Unable to checkpoint weapon ammunition before modification.')
            return
        end

        FeatherCore.RPC.Call(route, request, function(result, rpcError)
            HandleAttachmentResult(result or { ok = false, error = rpcError })
        end)
    end)
end

RegisterNetEvent('feather-weapons:client:attachmentResult', HandleAttachmentResult)

local Menu = exports['feather-menu-v2']
local ModificationMenu, RepairMenu, AmmunitionMenu
local AmmunitionActivityPage, ammunitionActivityInFlight = nil, false
local ammunitionActivityReturnPage = nil
local ammunitionActivitySequence = 0
local ModificationPages = {}
local ammunitionInventory = {}
local menuSequence = 0

local function MenuValue(result)
    if type(result) ~= 'table' or result.ok ~= true then
        error(('Weapon menu: %s'):format(type(result) == 'table' and result.message or 'invalid provider response'))
    end

    return result.value
end

local function CloseWeaponMenu(menuId)
    menuSequence = menuSequence + 1
    if menuId then MenuValue(Menu:CloseMenu(menuId)) end
end

local function CreateWeaponMenu(key)
    return MenuValue(Menu:CreateMenu({
        key = key,
        draggable = true,
        closable = true,
        size = { width = '28rem', maxHeight = '85vh' },
        theme = { preset = 'redemption', accent = '#CC9900' }
    })).menuId
end

local function CreateWeaponPage(menuId, key)
    return { menuId = menuId, id = MenuValue(Menu:CreatePage(menuId, { key = key })).pageId, count = 0 }
end

local function AddWeaponElement(page, kind, settings, callback)
    page.count = page.count + 1
    settings.key = settings.key or ('%s-%d'):format(kind, page.count)

    return MenuValue(Menu:AddElement(page.menuId, page.id, kind, settings, callback))
end

local function OpenWeaponPage(page)
    MenuValue(Menu:OpenMenu(page.menuId, { pageId = page.id }))
end

-- Readiness waits run in a thread; closing or replacing a request cancels stale opens.
local function WithWeaponMenuReady(build)
    menuSequence = menuSequence + 1
    local sequence = menuSequence
    CreateThread(function()
        local success, problem = pcall(function()
            MenuValue(Menu:AwaitReady(5000))
            if sequence ~= menuSequence then return end
            build()
        end)

        if not success then
            print(('[feather-weapons] %s'):format(tostring(problem)))
            Notify('Unable to open the weapon menu. Check feather-menu-v2 readiness.')
        end
    end)
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= 'feather-menu-v2' then return end

    menuSequence = menuSequence + 1
    ModificationMenu, RepairMenu, AmmunitionMenu = nil, nil, nil
    AmmunitionActivityPage, ammunitionActivityInFlight = nil, false
    ammunitionActivityReturnPage = nil
    ammunitionActivitySequence = ammunitionActivitySequence + 1
    ModificationPages = {}
end)

local function ResetModificationPages()
    if ModificationMenu then MenuValue(Menu:DestroyMenu(ModificationMenu)) end

    ModificationMenu = CreateWeaponMenu('modifications')
    ModificationPages = {}
end

local function NearGunsmithStation()
    local settings = Config.Attachments or {}
    if settings.requireStation ~= true then return true end

    local position = GetEntityCoords(PlayerPedId(), false, true)
    local distance = tonumber(settings.interactionDistance) or 2.0
    for _, station in pairs(settings.stations or {}) do
        local coords = station.coords
        if coords then
            local dx, dy, dz = position.x - coords.x, position.y - coords.y, position.z - coords.z
            if math.sqrt(dx * dx + dy * dy + dz * dz) <= distance then return true end
        end
    end
    return false
end

local BuildModificationPage

BuildModificationMenu = function(preferredSlot)
    if not equipped and not offhand and not extraSlots.shoulder and not extraSlots.back
        and not extraSlots.melee and not extraSlots.melee_secondary
        and not extraSlots.melee_tertiary and not extraSlots.utility_senary and not extraSlots.utility_septenary and not extraSlots.utility_octonary and not extraSlots.utility_quinary and not extraSlots.utility_quaternary and not extraSlots.utility_tertiary and not extraSlots.utility_secondary and not extraSlots.utility and not extraSlots.melee_quinary and not extraSlots.melee_quaternary
        and not extraSlots.throwable and not extraSlots.throwable_secondary and not extraSlots.throwable_tertiary and not extraSlots.throwable_quaternary and not extraSlots.throwable_quinary and not extraSlots.throwable_senary and not extraSlots.throwable_septenary and not extraSlots.throwable_octonary and not extraSlots.throwable_nonary and not extraSlots.throwable_denary then
        Notify('Equip a weapon before modifying it.')
        return
    end

    if not NearGunsmithStation() then
        Notify('Visit a gunsmith bench to modify this weapon.')
        return
    end

    ResetModificationPages()
    local occupied = 0
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        if SlotState(slot) then
            ModificationPages[slot] = BuildModificationPage(slot)
            occupied = occupied + 1
        end
    end

    if occupied > 1 then
        local selector = CreateWeaponPage(ModificationMenu, 'feather-weapons:select-weapon-slot')
        ModificationPages.selector = selector

        AddWeaponElement(selector, 'header', { value = 'Weapon Modifications', slot = 'header' })

        AddWeaponElement(selector, 'subheader', { value = 'Choose a weapon', slot = 'header' })

        for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
            local selected = SlotState(slot)
            if selected then
                AddWeaponElement(selector, 'button', {
                    label = ('%s: %s'):format(SlotLabel(slot), selected.definitionId or 'Equipped weapon'),
                    slot = 'content'
                }, function()
                    MenuValue(Menu:NavigateToPage(ModificationMenu, ModificationPages[slot].id))
                end)
            end
        end

        if preferredSlot and ModificationPages[preferredSlot] then
            OpenWeaponPage(ModificationPages[preferredSlot])
            return
        end
        OpenWeaponPage(selector)
        return
    end

    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        if ModificationPages[slot] then
            OpenWeaponPage(ModificationPages[slot]); return
        end
    end
end

BuildModificationPage = function(slot)
    local selected = SlotState(slot)
    if not selected then return nil end
    local weaponDefinition = WeaponDefinitionCatalog.weapons[selected.definitionId]

    local page = CreateWeaponPage(ModificationMenu, ('feather-weapons:installed-attachments:%s'):format(slot))

    AddWeaponElement(page, 'header', { value = 'Weapon Modifications', slot = 'header' })

    AddWeaponElement(page, 'subheader', {
        value = ('%s: %s'):format(SlotLabel(slot),
            weaponDefinition and weaponDefinition.label or selected.definitionId or 'Equipped weapon'),
        slot = 'header'
    })

    AddWeaponElement(page, 'line', { slot = 'header' })

    AddWeaponElement(page, 'textdisplay', {
        value = ('Serial: %s'):format(selected.serialNumber or 'Unknown'),
        slot = 'content'
    })

    local installedBySlot, installedIds = {}, {}
    for _, installed in ipairs(selected.attachments or {}) do
        installedBySlot[installed.slot] = installed
        installedIds[installed.definitionId] = true
    end
    local requiredBy = {}
    for attachmentId in pairs(installedIds) do
        local definition = WeaponDefinitionCatalog.attachments[attachmentId]
        for _, prerequisiteId in ipairs(definition and definition.prerequisites or {}) do
            requiredBy[prerequisiteId] = requiredBy[prerequisiteId] or {}
            requiredBy[prerequisiteId][#requiredBy[prerequisiteId] + 1] =
                definition.label or attachmentId:gsub('_', ' ')
        end
    end

    local slotNames = {}
    for slotName in pairs(weaponDefinition and weaponDefinition.attachmentSlots or {}) do
        slotNames[#slotNames + 1] = slotName
    end
    table.sort(slotNames)

    for _, slotName in ipairs(slotNames) do
        local installed = installedBySlot[slotName]
        if installed then
            local attachmentId = installed.definitionId
            local definition = WeaponDefinitionCatalog.attachments[attachmentId]
            local label = definition and definition.label or attachmentId:gsub('_', ' ')
            AddWeaponElement(page, 'textdisplay', {
                value = ('%s: %s'):format(
                    slotName:gsub('^%l', string.upper), label),
                slot = 'content'
            })
            if requiredBy[attachmentId] then
                table.sort(requiredBy[attachmentId])
                AddWeaponElement(page, 'textdisplay', {
                    value = ('Required by: %s'):format(table.concat(requiredBy[attachmentId], ', ')),
                    slot = 'content'
                })
            else
                AddWeaponElement(page, 'button', {
                    label = ('Remove %s'):format(label),
                    slot = 'content'
                }, function()
                    RequestAttachmentMutation('feather-weapons:attachment:remove', {
                        attachmentId = attachmentId,
                        slot = slot,
                        itemInstanceId = selected.itemInstanceId,
                        generation = selected.generation
                    })
                end)
            end
        else
            local defaultLabel = weaponDefinition.attachmentDefaults
                and weaponDefinition.attachmentDefaults[slotName] or nil
            if defaultLabel then
                AddWeaponElement(page, 'textdisplay', {
                    value = ('%s: %s'):format(
                        slotName:gsub('^%l', string.upper), defaultLabel),
                    slot = 'content'
                })
            end
            for _, attachmentId in ipairs(weaponDefinition.attachmentSlots[slotName]) do
                local definition = WeaponDefinitionCatalog.attachments[attachmentId]
                local missing = {}
                for _, prerequisiteId in ipairs(definition and definition.prerequisites or {}) do
                    if not installedIds[prerequisiteId] then
                        local prerequisite = WeaponDefinitionCatalog.attachments[prerequisiteId]
                        missing[#missing + 1] = prerequisite and prerequisite.label
                            or prerequisiteId:gsub('_', ' ')
                    end
                end
                local conflicts = {}
                for installedId in pairs(installedIds) do
                    local installedDefinition = WeaponDefinitionCatalog.attachments[installedId]
                    local conflicted = false
                    for _, conflictId in ipairs(definition and definition.conflicts or {}) do
                        if conflictId == installedId then conflicted = true; break end
                    end
                    if not conflicted then
                        for _, conflictId in ipairs(
                            installedDefinition and installedDefinition.conflicts or {}) do
                            if conflictId == attachmentId then conflicted = true; break end
                        end
                    end
                    if conflicted then
                        conflicts[#conflicts + 1] = installedDefinition and installedDefinition.label
                            or installedId:gsub('_', ' ')
                    end
                end
                if #missing > 0 then
                    table.sort(missing)
                    AddWeaponElement(page, 'textdisplay', {
                        value = ('%s - Requires %s'):format(
                            definition and definition.label or attachmentId:gsub('_', ' '),
                            table.concat(missing, ', ')),
                        slot = 'content'
                    })
                elseif #conflicts > 0 then
                    table.sort(conflicts)
                    AddWeaponElement(page, 'textdisplay', {
                        value = ('%s - Conflicts with %s'):format(
                            definition and definition.label or attachmentId:gsub('_', ' '),
                            table.concat(conflicts, ', ')),
                        slot = 'content'
                    })
                else
                    AddWeaponElement(page, 'button', {
                        label = ('Install %s'):format(
                            definition and definition.label or attachmentId:gsub('_', ' ')),
                        slot = 'content'
                    }, function()
                        RequestAttachmentMutation('feather-weapons:attachment:install', {
                            attachmentId = attachmentId,
                            slot = slot,
                            itemInstanceId = selected.itemInstanceId,
                            generation = selected.generation
                        })
                    end)
                end
            end
        end
    end

    if not selected.attachments or #selected.attachments == 0 then
        AddWeaponElement(page, 'textdisplay', { value = 'No attachments are installed.', slot = 'content' })
    end

    if ModificationPages.selector then
        AddWeaponElement(page, 'button', { label = 'Back to weapons', slot = 'footer' }, function()
            local selector = ModificationPages.selector
            if selector then MenuValue(Menu:NavigateToPage(ModificationMenu, selector.id)) end
        end)
    end

    return page
end

local function HandleRepairResult(result)
    if result and result.ok then
        local slot = result.value.slot or 'primary'
        local state = SlotState(slot)
        if state and SameInstance(state.itemInstanceId, result.value.itemInstanceId) then
            state.condition = tonumber(result.value.condition) or state.condition
            state.maintenance = result.value.maintenance or state.maintenance
            ScheduleMaintenanceRestore()
        end

        Notify(('Weapon repaired by %s%%.'):format(tostring(result.value.restored)))
        if result.value.reconcile then FeatherWeaponsClient.Reconcile() end
        return
    end

    local failure = result and result.error
    Notify(failure and failure.message or 'Unable to repair this weapon.')
end

RegisterNetEvent('feather-weapons:client:inventoryRepairResult', HandleRepairResult)

local function OpenModificationMenu()
    WithWeaponMenuReady(BuildModificationMenu)
end

local OpenAmmunitionMenu

local function StopAmmunitionActivity(returnPage)
    returnPage = returnPage or ammunitionActivityReturnPage
    ammunitionActivityInFlight = false
    ammunitionActivityReturnPage = nil
    ammunitionActivitySequence = ammunitionActivitySequence + 1
    if returnPage and AmmunitionMenu then
        MenuValue(Menu:NavigateToPage(AmmunitionMenu, returnPage.id))
    end
end

local function StartAmmunitionActivity(returnPage, operation)
    if ammunitionActivityInFlight or not AmmunitionActivityPage then return false end

    ammunitionActivityInFlight = true
    ammunitionActivityReturnPage = returnPage
    ammunitionActivitySequence = ammunitionActivitySequence + 1
    local sequence = ammunitionActivitySequence
    MenuValue(Menu:SetElementValue(AmmunitionMenu, AmmunitionActivityPage.id,
        AmmunitionActivityPage.statusElementId, operation .. '...'))
    MenuValue(Menu:NavigateToPage(AmmunitionMenu, AmmunitionActivityPage.id))
    CreateThread(function()
        local step = 0
        while ammunitionActivityInFlight and sequence == ammunitionActivitySequence do
            Wait(350)
            if not ammunitionActivityInFlight or sequence ~= ammunitionActivitySequence then return end

            step = (step % 3) + 1
            local result = Menu:SetElementValue(AmmunitionMenu, AmmunitionActivityPage.id,
                AmmunitionActivityPage.statusElementId, operation .. string.rep('.', step))
            if type(result) ~= 'table' or result.ok ~= true then
                StopAmmunitionActivity(returnPage)
                return
            end
        end
    end)
    return true
end

local function AmmunitionVariantLabel(definition, ammunitionId)
    local label = definition and definition.label or ammunitionId or 'Unknown'

    return label:match('%s%-%s(.+)$') or label
end

local function AmmunitionUnitLabels(weapon)
    local family = type(weapon) == 'table' and weapon.family or nil
    if family == 'bow' then return 'arrow', 'arrows' end
    if family == 'shotgun' then return 'shell', 'shells' end
    if family == 'throwing_knife' then return 'knife', 'knives' end
    if family == 'tomahawk' then return 'tomahawk', 'tomahawks' end
    if family == 'bolas' then return 'bola', 'bolas' end
    if family == 'dynamite' then return 'stick', 'sticks' end
    if family == 'molotov' then return 'bottle', 'bottles' end
    if family == 'poisonbottle' then return 'bottle', 'bottles' end
    return 'cartridge', 'cartridges'
end

local function RequestManagedAmmunition(route, request, action)
    FeatherWeaponsClient.Checkpoint(function(checkpoint)
        if not checkpoint or not checkpoint.ok then
            local failure = checkpoint and checkpoint.error or nil
            Notify(failure and failure.message or 'Unable to save the weapon before changing ammunition.')
            StopAmmunitionActivity(action and action.returnPage)
            return
        end

        FeatherCore.RPC.Call(route, request, function(result, rpcError)
            result = result or { ok = false, error = rpcError }
            if not result.ok then
                local failure = result.error or rpcError
                Notify(failure and failure.message or 'Unable to change weapon ammunition.')
                StopAmmunitionActivity(action and action.returnPage)
                return
            end

            local moved = tonumber(result.value and result.value.moved) or 0
            local weaponLabel = action and action.weaponLabel or SlotLabel(request.slot)
            local ammunitionLabel = action and action.ammunitionLabel or 'cartridges'
            local ammunitionUnit = moved == 1
                and (action and action.ammunitionUnitSingular or 'cartridge')
                or (action and action.ammunitionUnitPlural or 'cartridges')
            if action and action.kind == 'unload' then
                Notify(('Unloaded %d %s %s from %s.'):format(
                    moved, ammunitionLabel, ammunitionUnit, weaponLabel))
            elseif action and action.kind == 'switch' then
                Notify(('Switched %s to %s; loaded %d %s.'):format(
                    weaponLabel, ammunitionLabel, moved, ammunitionUnit))
            else
                Notify(('Loaded %d %s %s into %s.'):format(
                    moved, ammunitionLabel, ammunitionUnit, weaponLabel))
            end

            ClearNativeWeapon()
            FeatherWeaponsClient.Reconcile(function(reconciled)
                if reconciled and reconciled.ok then
                    OpenAmmunitionMenu(request.slot)
                else
                    StopAmmunitionActivity(action and action.returnPage)
                end
            end)
        end)
    end)
end

local function LoadedContainerLabel(weapon)
    if weapon.family == 'revolver' then return 'Cylinder' end

    if weapon.family == 'shotgun' then return 'Chamber/tube' end

    if weapon.family == 'bow' then return 'Nocked' end

    if weapon.family == 'throwing_knife' then return 'Readied' end

    if weapon.family == 'tomahawk' then return 'Readied' end
    if weapon.family == 'bolas' then return 'Readied' end
    if weapon.family == 'dynamite' then return 'Readied' end
    if weapon.family == 'molotov' then return 'Readied' end
    if weapon.family == 'poisonbottle' then return 'Readied' end

    return 'Magazine'
end

local function AmmunitionCapacityRemaining(slot, selected, ammunitionId, definition)
    local maximum = math.max(tonumber(selected.capacity) or 1,
        math.floor(tonumber(Config.Escrow and Config.Escrow.maxTotal)
            or tonumber(selected.capacity) or 1))
    local definitionMaximum = definition and tonumber(definition.maxTotal) or nil
    if definitionMaximum then
        maximum = math.min(maximum, math.floor(definitionMaximum))
    end

    local occupied = selected.ammoPools and (selected.ammoPools[ammunitionId] or 0)
        or (selected.ammunitionType == ammunitionId and (tonumber(selected.ammo) or 0) or 0)
    for _, candidate in ipairs(WeaponConstants.LoadoutSlots) do
        local other = candidate ~= slot and SlotState(candidate) or nil
        if other and definition then
            if other.ammoPools then
                occupied = occupied + (tonumber(other.ammoPools[ammunitionId]) or 0)
            elseif other.nativeAmmoName == definition.nativeAmmoName then
                occupied = occupied + (tonumber(other.ammo) or 0)
            end
        end
    end

    return math.max(0, maximum - occupied)
end

local function BuildAmmunitionPage(slot)
    local selected = SlotState(slot)
    if not selected then return nil end

    local page = CreateWeaponPage(AmmunitionMenu, ('feather-weapons:ammunition:%s'):format(slot))
    local section
    local AddElement = AddWeaponElement
    local function AddWeaponElement(target, kind, settings, callback)
        if settings.slot == 'content' and kind ~= 'accordion' then settings.section = section end
        return AddElement(target, kind, settings, callback)
    end
    local weapon = WeaponDefinitionCatalog.weapons[selected.definitionId] or {}
    local current = WeaponDefinitionCatalog.ammunition[selected.ammunitionType] or {}
    local unitSingular, unitPlural = AmmunitionUnitLabels(weapon)

    AddWeaponElement(page, 'header', { value = 'Ammunition Management', slot = 'header' })

    AddWeaponElement(page, 'subheader', {
        value = ('%s: %s'):format(SlotLabel(slot), weapon.label or selected.definitionId),
        slot = 'header'
    })

    AddWeaponElement(page, 'textdisplay', {
        value = ('Selected: %s'):format(AmmunitionVariantLabel(current, selected.ammunitionType)),
        slot = 'content'
    })

    AddWeaponElement(page, 'textdisplay', {
        value = ('%s: %d  |  Reserve: %d  |  Total: %d'):format(
            LoadedContainerLabel(weapon),
            tonumber(selected.loaded) or 0,
            tonumber(selected.reserve) or 0,
            tonumber(selected.ammo) or 0),
        slot = 'content'
    })

    AddWeaponElement(page, 'line', { slot = 'content' })

    local ownedTotal = 0
    if selected.ammoPools then
        local options = {}
        for _, id in ipairs(weapon.ammunitionTypes or {}) do
            local ammunitionId, amount = id, selected.ammoPools[id] or 0
            local definition = WeaponDefinitionCatalog.ammunition[id]
            ownedTotal = ownedTotal + amount
            if amount > 0 or id == selected.ammunitionType then
                options[#options + 1] = { value = ammunitionId,
                    label = ('%s — %d available%s'):format(AmmunitionVariantLabel(definition, id), amount,
                        id == selected.ammunitionType and ' (selected)' or ''),
                    disabled = amount == 0 and id ~= selected.ammunitionType }
            end
        end
        if #options > 0 then
            AddWeaponElement(page, 'dropdown', { key = 'selected-ammo', label = 'Ammo type in use',
                value = selected.ammunitionType, options = options, persist = false, slot = 'content' }, function(event)
                if event.value == selected.ammunitionType then return end
                if not StartAmmunitionActivity(page, 'Selecting ammunition') then return end
                local definition = WeaponDefinitionCatalog.ammunition[event.value]
                RequestManagedAmmunition('feather-weapons:ammo:switchSlot', {
                    slot = slot, ammunitionType = event.value,
                    itemInstanceId = selected.itemInstanceId, generation = selected.generation
                }, { kind = 'switch', weaponLabel = weapon.label,
                    ammunitionLabel = definition.label, returnPage = page })
            end)
        end
        AddWeaponElement(page, 'line', { slot = 'content' })
    end

    local function AddUnloadActions()
        AddWeaponElement(page, 'accordion', { key = 'unload-ammo', label = 'Return ammo to inventory', value = false, slot = 'content' })
        section = 'unload-ammo'
        if selected.ammoPools and ownedTotal > 0 then
            AddWeaponElement(page, 'button', { label = 'Unload all ammunition types', slot = 'content' }, function()
                if not StartAmmunitionActivity(page, 'Unloading all ammunition types') then return end
                RequestManagedAmmunition('feather-weapons:ammo:unload', {
                    slot = slot, allTypes = true, itemInstanceId = selected.itemInstanceId,
                    generation = selected.generation
                }, { kind = 'unload', weaponLabel = weapon.label,
                    ammunitionLabel = 'all ammunition types', ammunitionUnitSingular = unitSingular,
                    ammunitionUnitPlural = unitPlural, returnPage = page })
            end)
        end

    if (tonumber(selected.ammo) or 0) > 0 then
        local unloadAmount = math.min(10, tonumber(selected.ammo) or 0)
        AddWeaponElement(page, 'button', {
            label = ('Unload %d %s — %s'):format(
                unloadAmount, unloadAmount == 1 and unitSingular or unitPlural,
                AmmunitionVariantLabel(current, selected.ammunitionType)),
            slot = 'content'
        }, function()
            if not StartAmmunitionActivity(page, 'Unloading ammunition') then return end
            RequestManagedAmmunition('feather-weapons:ammo:unload', {
                slot = slot,
                amount = unloadAmount,
                itemInstanceId = selected.itemInstanceId,
                generation = selected.generation
            }, {
                kind = 'unload',
                weaponLabel = weapon.label or selected.definitionId,
                ammunitionLabel = AmmunitionVariantLabel(current, selected.ammunitionType),
                ammunitionUnitSingular = unitSingular,
                ammunitionUnitPlural = unitPlural,
                returnPage = page
            })
        end)

        if (tonumber(selected.ammo) or 0) > unloadAmount then
        AddWeaponElement(page, 'button', {
            label = ('Unload selected type — %s (%d)'):format(
                AmmunitionVariantLabel(current, selected.ammunitionType), selected.ammo), slot = 'content'
        }, function()
            if not StartAmmunitionActivity(page, 'Unloading ammunition') then return end
            RequestManagedAmmunition('feather-weapons:ammo:unload', {
                slot = slot,
                itemInstanceId = selected.itemInstanceId,
                generation = selected.generation
            }, {
                kind = 'unload',
                weaponLabel = weapon.label or selected.definitionId,
                ammunitionLabel = AmmunitionVariantLabel(current, selected.ammunitionType),
                ammunitionUnitSingular = unitSingular,
                ammunitionUnitPlural = unitPlural,
                returnPage = page
            })
        end)
        end
    end
    end

    AddWeaponElement(page, 'accordion', { key = 'load-ammo', label = 'Load from inventory', value = true, slot = 'content' })
    section = 'load-ammo'
    local availableChoices = 0
    for _, id in ipairs(weapon.ammunitionTypes or {}) do
        local ammunitionId = id
        local definition = WeaponDefinitionCatalog.ammunition[ammunitionId]
        local available = math.max(0, math.floor(tonumber(ammunitionInventory[ammunitionId]) or 0))
        if definition and available > 0 then
            local loadLimit = tonumber(Config.Escrow and Config.Escrow.refillAmount) or 50
            local remaining = AmmunitionCapacityRemaining(slot, selected, ammunitionId, definition)
            local loadAmount = math.min(loadLimit, available, remaining)
            if loadAmount > 0 then
                local switching = not selected.ammoPools and (tonumber(selected.ammo) or 0) > 0
                    and selected.ammunitionType ~= ammunitionId
                availableChoices = availableChoices + 1
                AddWeaponElement(page, 'button', {
                    label = switching
                        and ('Switch to %s — load %d / inventory %d'):format(AmmunitionVariantLabel(definition, ammunitionId), loadAmount, available)
                        or ('Load %d %s — inventory %d'):format(loadAmount, AmmunitionVariantLabel(definition, ammunitionId), available),
                    slot = 'content'
                }, function()
                    if not StartAmmunitionActivity(page,
                            switching and 'Switching ammunition' or 'Loading ammunition') then
                        return
                    end

                    RequestManagedAmmunition(switching
                        and 'feather-weapons:ammo:switchSlot'
                        or 'feather-weapons:ammo:loadSlot', {
                            slot = slot,
                            amount = loadAmount,
                            ammunitionType = ammunitionId,
                            itemInstanceId = selected.itemInstanceId,
                            generation = selected.generation
                        }, {
                            kind = switching and 'switch' or 'load',
                            weaponLabel = weapon.label or selected.definitionId,
                            ammunitionLabel = AmmunitionVariantLabel(definition, ammunitionId),
                            ammunitionUnitSingular = unitSingular,
                            ammunitionUnitPlural = unitPlural,
                            returnPage = page
                        })
                end)
            end
        end
    end

    if availableChoices == 0 then
        AddWeaponElement(page, 'textdisplay', {
            value = 'No ammunition available to load. Inventory may be empty or this ammo type may be full.',
            slot = 'content'
        })
    end

    if ownedTotal > 0 or (tonumber(selected.ammo) or 0) > 0 then AddUnloadActions() end

    return page
end

local function BuildAmmunitionMenu(initialSlot)
    local occupied = {}
    for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
        local state = SlotState(slot)
        local definition = state and WeaponDefinitionCatalog.weapons[state.definitionId] or nil
        if state and definition and definition.usesAmmunition ~= false then
            occupied[#occupied + 1] = slot
        end
    end

    if #occupied == 0 then
        Notify('Equip a weapon before managing ammunition.')
        return
    end

    ammunitionActivityInFlight = false
    ammunitionActivityReturnPage = nil
    ammunitionActivitySequence = ammunitionActivitySequence + 1
    if AmmunitionMenu then MenuValue(Menu:DestroyMenu(AmmunitionMenu)) end

    AmmunitionMenu = CreateWeaponMenu('ammunition-management')
    AmmunitionActivityPage = CreateWeaponPage(AmmunitionMenu, 'feather-weapons:ammunition-activity')
    AddWeaponElement(AmmunitionActivityPage, 'header', {
        value = 'Ammunition Management', slot = 'header'
    })

    AddWeaponElement(AmmunitionActivityPage, 'subheader', {
        value = 'Updating weapon', slot = 'header'
    })

    AmmunitionActivityPage.statusElementId = AddWeaponElement(
        AmmunitionActivityPage, 'textdisplay', {
            value = 'Working...', slot = 'content'
        }).elementId
    AddWeaponElement(AmmunitionActivityPage, 'textdisplay', {
        value = 'Please wait. Inventory and weapon state are being synchronized.',
        slot = 'content'
    })

    local pages = {}
    for _, slot in ipairs(occupied) do pages[slot] = BuildAmmunitionPage(slot) end

    if #occupied == 1 then
        local onlyPage = pages[occupied[1]]
        if onlyPage then OpenWeaponPage(onlyPage) end
        return
    end

    local selector = CreateWeaponPage(AmmunitionMenu, 'feather-weapons:ammunition-select-slot')
    AddWeaponElement(selector, 'header', { value = 'Ammunition Management', slot = 'header' })
    AddWeaponElement(selector, 'subheader', { value = 'Choose a weapon', slot = 'header' })
    for _, slot in ipairs(occupied) do
        local selectedSlot = slot
        local selected = SlotState(selectedSlot)
        local targetPage = pages[selectedSlot]
        if selected and targetPage then
            local weapon = WeaponDefinitionCatalog.weapons[selected.definitionId] or {}
            AddWeaponElement(selector, 'button', {
                label = ('%s: %s (%d/%d)'):format(SlotLabel(selectedSlot),
                    weapon.label or selected.definitionId,
                    tonumber(selected.loaded) or 0, tonumber(selected.ammo) or 0),
                slot = 'content'
            }, function()
                MenuValue(Menu:NavigateToPage(AmmunitionMenu, targetPage.id))
            end)
        end
    end

    for _, slot in ipairs(occupied) do
        local page = pages[slot]
        if page then
            AddWeaponElement(page, 'button', { label = 'Back to weapons', slot = 'footer' }, function()
                MenuValue(Menu:NavigateToPage(AmmunitionMenu, selector.id))
            end)
        end
    end

    local initialPage = initialSlot and pages[initialSlot] or nil
    OpenWeaponPage(initialPage or selector)
end

OpenAmmunitionMenu = function(initialSlot)
    FeatherWeaponsClient.Checkpoint(function(result)
        if not result or not result.ok then
            local failure = result and (result.error or result) or nil
            Notify(failure and failure.message
                or 'Unable to save weapon ammunition before opening the menu.')
            StopAmmunitionActivity()
            return
        end

        FeatherCore.RPC.Call('feather-weapons:ammo:availability', {}, function(availability, rpcError)
            if not availability or not availability.ok then
                local failure = availability and availability.error or rpcError
                Notify(failure and failure.message or 'Unable to read Inventory ammunition.')
                StopAmmunitionActivity()
                return
            end

            ammunitionInventory = availability.value.quantities or {}
            WithWeaponMenuReady(function() BuildAmmunitionMenu(initialSlot) end)
        end)
    end)
end

local function BuildRepairMenu(selectionSlots)
    local choices = {}
    if type(selectionSlots) == 'table' and #selectionSlots > 0 then
        choices = selectionSlots
    else
        for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
            local state = SlotState(slot)
            if state then
                choices[#choices + 1] = {
                    key = 'slot:' .. slot,
                    location = slot,
                    definitionId = state.definitionId,
                    condition = state.condition
                }
            end
        end
    end

    if #choices < 1 then
        Notify('The equipped weapons changed before repair selection.')
        return
    end

    if RepairMenu then MenuValue(Menu:DestroyMenu(RepairMenu)) end

    RepairMenu = CreateWeaponMenu('repair-selection')
    local RepairPage = CreateWeaponPage(RepairMenu, 'repair-slot')
    AddWeaponElement(RepairPage, 'header', { value = 'Repair Weapon', slot = 'header' })
    AddWeaponElement(RepairPage, 'subheader', { value = 'Choose a weapon', slot = 'header' })

    for _, choice in ipairs(choices) do
        local selected = choice
        local location = ({
            primary = true, offhand = true, shoulder = true, back = true,
            melee = true, melee_secondary = true, melee_tertiary = true, melee_quaternary = true, melee_quinary = true, utility = true, utility_secondary = true, utility_tertiary = true, utility_quaternary = true, utility_quinary = true, utility_senary = true, utility_septenary = true, utility_octonary = true,
            throwable = true, throwable_secondary = true, throwable_tertiary = true, throwable_quaternary = true, throwable_quinary = true, throwable_senary = true, throwable_septenary = true, throwable_octonary = true, throwable_nonary = true, throwable_denary = true
        })[choice.location]
            and SlotLabel(choice.location) or tostring(choice.location or 'Inventory')
        AddWeaponElement(RepairPage, 'button', { label = ('%s: %s (%s%%)'):format(location,
                choice.definitionId or 'Weapon', tostring(choice.condition or 0)),
            slot = 'content'
        }, function()
            CloseWeaponMenu(RepairMenu)
            FeatherCore.RPC.Call('feather-weapons:repair:select', { key = selected.key }, function(result, rpcError)
                HandleRepairResult(result or { ok = false, error = rpcError })
            end)
        end)
    end

    OpenWeaponPage(RepairPage)
end

RegisterNetEvent('feather-weapons:client:repairSlotRequested', function(selectionSlots)
    WithWeaponMenuReady(function() BuildRepairMenu(selectionSlots) end)
end)

RegisterNetEvent('feather-weapons:client:clearAuthorization', function(token)
    if pendingToken == token then
        ClearNativeWeapon()
    end
end)

RegisterNetEvent('feather-weapons:client:inventoryAmmoResult', function(result)
    if result and result.reconcile then
        ClearNativeWeapon()
        FeatherWeaponsClient.Reconcile()
        Notify(result.ok and ('Escrowed %s cartridges.'):format(tostring(result.value.moved))
            or (result.error and result.error.message or 'Unable to escrow ammunition.'))
        return
    end

    if result and result.ok and (equipped or offhand or extraSlots.shoulder or extraSlots.back
        or extraSlots.melee or extraSlots.melee_secondary or extraSlots.melee_tertiary
        or extraSlots.utility_senary or extraSlots.utility_septenary or extraSlots.utility_octonary or extraSlots.utility_quinary or extraSlots.utility_quaternary or extraSlots.utility_tertiary or extraSlots.utility_secondary or extraSlots.utility or extraSlots.melee_quinary or extraSlots.melee_quaternary or extraSlots.throwable
        or extraSlots.throwable_secondary or extraSlots.throwable_tertiary or extraSlots.throwable_quaternary or extraSlots.throwable_quinary or extraSlots.throwable_senary or extraSlots.throwable_septenary or extraSlots.throwable_octonary or extraSlots.throwable_nonary or extraSlots.throwable_denary) then
        local slot = result.value.slot or 'primary'
        local state = SlotState(slot)
        if not state then
            Notify('The selected weapon slot is no longer equipped.')
            return
        end

        if state.ammoPools then
            ClearNativeWeapon()
            FeatherWeaponsClient.Reconcile()
            Notify('Ammunition pools updated.')
            return
        end

        state.ammo = tonumber(result.value.total) or state.ammo
        state.loaded = tonumber(result.value.loaded) or state.loaded
        state.reserve = tonumber(result.value.reserve) or (state.ammo - state.loaded)
        if slot == 'primary' or slot == 'offhand' then
            local primary = equipped
            local secondary = offhand
            if not primary then
                Notify('Primary weapon state changed while updating ammunition.')
                FeatherWeaponsClient.Reconcile()
                return
            end

            if secondary then
                if pairSingleFallback and primary.loaded > 0 and secondary.loaded > 0 then
                    local restored, message = RestoreApprovedNativePair(primary, secondary)
                    if not restored then
                        Notify(message or 'Unable to restore the reloaded weapon pair.')
                        FeatherWeaponsClient.Reconcile()
                        return
                    end

                    pairSingleFallback, pairFallbackPending = nil, nil
                    local primaryOk, primaryLoaded, offhandOk, offhandLoaded = PairNativeClips(primary, secondary)
                    pairObserved = {
                        primary = primaryOk and math.max(0, math.floor(tonumber(primaryLoaded) or 0)) or 0,
                        offhand = offhandOk and math.max(0, math.floor(tonumber(offhandLoaded) or 0)) or 0,
                        total = PairNativeTotal(primary, secondary)
                    }
                    FeatherNativeWeaponCoordinator.TrackAmmoWindows(PlayerPedId(), {
                        primary = primary,
                        offhand = secondary
                    })
                    if Config.DevMode then
                        print(('[feather-weapons] funded pair restored slot=%s loaded=%d/%d')
                            :format(slot, pairObserved.primary, pairObserved.offhand))
                    end
                end

                local pairTotal = primary.ammo + secondary.ammo
                if primary.nativeAmmoName == secondary.nativeAmmoName then
                    SetPedAmmoByType(PlayerPedId(), joaat(primary.nativeAmmoName), pairTotal)
                else
                    SetPedAmmoByType(PlayerPedId(), joaat(state.nativeAmmoName), state.ammo)
                end

                pairObserved = pairObserved or {}
                pairObserved.total = PairNativeTotal(primary, secondary)
                FeatherNativeWeaponCoordinator.TrackAmmoWindows(PlayerPedId(), {
                    primary = primary,
                    offhand = secondary
                })
            else
                desiredAmmo, desiredLoaded = primary.ammo, primary.loaded
                SetNativeAmmo(result.value.nativeAmmoName or primary.nativeAmmoName,
                    primary.ammo, primary.nativeWeaponName, primary.loaded)
            end
        else
            extraObserved[slot] = { loaded = state.loaded, consumed = 0, recovered = 0 }
            SetNativeAmmo(state.nativeAmmoName, state.ammo,
                state.nativeWeaponName, state.loaded)
        end

        Notify(('Escrowed %s cartridge%s.'):format(
            tostring(result.value.moved), result.value.moved == 1 and '' or 's'))
        return
    end

    local failure = result and result.error
    Notify(failure and failure.message or 'Unable to escrow ammunition.')
end)

RegisterNetEvent('feather-weapons:client:clear', ClearNativeWeapon)

RegisterNetEvent('feather-weapons:client:reconcile', function()
    FeatherWeaponsClient.Reconcile()
end)

RegisterNetEvent('feather-weapons:client:forceReconcile', function()
    ClearNativeWeapon()
    FeatherWeaponsClient.Reconcile()
end)

if Config.Controls and Config.Controls.unload and Config.Controls.unload.enabled then
    local unloadControl = Config.Controls.unload
    RegisterCommand(unloadControl.command, BeginUnload, false)
    RegisterKeyMapping(unloadControl.command, 'Unload equipped weapon', 'keyboard', unloadControl.defaultKey or 'U')
end

if Config.Controls and Config.Controls.modify and Config.Controls.modify.enabled then
    local modifyControl = Config.Controls.modify
    RegisterCommand(modifyControl.command, OpenModificationMenu, false)
    RegisterKeyMapping(modifyControl.command, 'Modify equipped weapon', 'keyboard', modifyControl.defaultKey or 'F6')
end

if Config.Controls and Config.Controls.ammunition and Config.Controls.ammunition.enabled then
    local ammunitionControl = Config.Controls.ammunition
    RegisterCommand(ammunitionControl.command, function() OpenAmmunitionMenu() end, false)
    RegisterKeyMapping(ammunitionControl.command, 'Manage equipped weapon ammunition', 'keyboard', ammunitionControl.defaultKey or 'F7')
end

CreateThread(function()
    local interval = math.max(1000, math.floor(tonumber(Config.Runtime and Config.Runtime.maintenanceCheckpointMs) or 5000))
    while true do
        while LifeStateSuspended() do Wait(100) end
        Wait(interval)
        CheckpointMaintenance(function() end)
    end
end)

CreateThread(function()
    local runtimeConfig = Config.Runtime or {}
    local observationInterval = math.max(25, math.floor(tonumber(runtimeConfig.observationIntervalMs) or 50))
    local checkpointDebounce = math.max(0, math.floor(tonumber(runtimeConfig.checkpointDebounceMs) or 250))
    local wasDead = false
    local fireWindowUntil = 0

    while true do
        while LifeStateSuspended() do Wait(100) end
        if equipped and not offhand and desiredAmmo ~= nil and singleNativeReady
            and not presentationRestoreInFlight and not FirearmPoolsActive() then
            local ped = PlayerPedId()
            if NativeTrue(IsPedShooting(ped)) then fireWindowUntil = GetGameTimer() + 250 end

            local itemInstanceId = equipped.itemInstanceId
            local generation = equipped.generation
            local ammoHash = equipped.nativeAmmoName and joaat(equipped.nativeAmmoName) or nil
            if ammoHash then
                local clipOk, clipAmount = GetAmmoInClip(ped, joaat(equipped.nativeWeaponName))
                local observed = math.max(0,
                    math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
                local clipChanged = false
                local previousLoaded = desiredLoaded
                local observedLoaded = previousLoaded or 0
                if clipOk == true or clipOk == 1 then
                    observedLoaded = math.max(0, math.floor(tonumber(clipAmount) or 0))
                    local lematModeTransition = equipped.definitionId == 'revolver_lemat'
                        and previousLoaded ~= nil and observedLoaded < previousLoaded
                        and observed >= desiredAmmo
                    if lematModeTransition then
                        observedLoaded = previousLoaded
                    else
                        clipChanged = desiredLoaded ~= nil and observedLoaded ~= desiredLoaded
                        desiredLoaded = observedLoaded
                    end
                end

                local firing = GetGameTimer() <= fireWindowUntil
                local clipConsumed = firing and previousLoaded ~= nil
                    and math.max(0, previousLoaded - observedLoaded) or 0
                -- A lower native total is an authoritative consumption signal
                -- even if IsPedShooting was missed or the wheel auto-reloaded
                -- before this observer sampled the clip. This also recovers a
                -- pending shot after a read-only reconcile refreshed local
                -- state from the slightly older server snapshot.
                if observed < desiredAmmo or (firing and clipConsumed > 0) then
                    desiredAmmo = math.max(0, math.min(observed,
                        desiredAmmo - clipConsumed))
                    SetTimeout(checkpointDebounce, function()
                        if equipped and SameInstance(equipped.itemInstanceId, itemInstanceId)
                            and equipped.generation == generation then
                            FlushConsumption()
                        end
                    end)
                elseif clipChanged then
                    SetTimeout(checkpointDebounce, function()
                        if equipped and SameInstance(equipped.itemInstanceId, itemInstanceId)
                            and equipped.generation == generation then
                            FlushConsumption()
                        end
                    end)
                elseif observed > equipped.ammo and not observerCorrectionPending then
                    observerCorrectionPending = true
                    if Config.DevMode then
                        print(('[feather-weapons] native ammo exceeded lease observed=%d approved=%d generation=%s')
                            :format(observed, equipped.ammo, tostring(generation)))
                    end
                    FeatherWeaponsClient.Reconcile()
                elseif observed <= equipped.ammo then
                    observerCorrectionPending = false
                end
            end

            local deadState = IsEntityDead(PlayerPedId())
            local dead = deadState == true or deadState == 1
            if dead and not wasDead then
                -- Death is a persistence boundary. Capture and submit immediately;
                -- ordinary firing/reload observations remain debounced.
                CaptureNativeState()
                FlushConsumption()
            end

            wasDead = dead
            Wait(observationInterval)
        else
            wasDead = false
            Wait(500)
        end
    end
end)

CreateThread(function()
    local runtimeConfig = Config.Runtime or {}
    local observationInterval = math.max(25, math.floor(tonumber(runtimeConfig.observationIntervalMs) or 50))
    local checkpointDebounce = math.max(0, math.floor(tonumber(runtimeConfig.checkpointDebounceMs) or 250))

    while true do
        while LifeStateSuspended() do Wait(100) end
        if equipped and offhand and pairObserved and not presentationRestoreInFlight and not FirearmPoolsActive() then
            local ped = PlayerPedId()
            if IsDualSidearmPair(equipped, offhand) and not pairSingleFallback
                and not NativeTrue(GetAllowDualWield(ped)) then
                RecoverLostOffhandEntitlement()
                Wait(500)
            else
                local primaryOk, primaryLoaded, offhandOk, offhandLoaded =
                    ObservablePairClips(equipped, offhand)
                if primaryOk and offhandOk then
                    primaryLoaded = math.max(0, math.floor(tonumber(primaryLoaded) or 0))
                    offhandLoaded = math.max(0, math.floor(tonumber(offhandLoaded) or 0))
                    local total = PairNativeTotal(equipped, offhand)
                    if pairSingleFallback then
                        if primaryLoaded > 0 and offhandLoaded > 0 then
                            pairSingleFallback = nil
                            pairFallbackPending = nil
                            EnsureOffhandEntitlement()
                            if Config.DevMode then
                                print('[feather-weapons] pair reloaded; dual-wield restored')
                            end
                        end
                    elseif primaryLoaded == 0 and offhandLoaded > 0 then
                        local newlyConsumed = math.max(0, pairObserved.primary - primaryLoaded)
                        local remaining = (tonumber(equipped.ammo) or 0)
                            - pairConsumed.primary - newlyConsumed
                        pairFallbackPending = remaining <= 0 and 'offhand' or nil
                    elseif offhandLoaded == 0 and primaryLoaded > 0 then
                        local newlyConsumed = math.max(0, pairObserved.offhand - offhandLoaded)
                        local remaining = (tonumber(offhand.ammo) or 0)
                            - pairConsumed.offhand - newlyConsumed
                        pairFallbackPending = remaining <= 0 and 'primary' or nil
                    else
                        pairFallbackPending = nil
                    end

                    if primaryLoaded < pairObserved.primary then
                        pairConsumed.primary = pairConsumed.primary + (pairObserved.primary - primaryLoaded)
                    end

                    if offhandLoaded < pairObserved.offhand then
                        pairConsumed.offhand = pairConsumed.offhand + (pairObserved.offhand - offhandLoaded)
                    end

                    local changed = primaryLoaded ~= pairObserved.primary
                        or offhandLoaded ~= pairObserved.offhand or total ~= pairObserved.total
                    pairObserved.primary, pairObserved.offhand, pairObserved.total = primaryLoaded, offhandLoaded, total
                    if changed and not pairCheckpointPending then
                        pairCheckpointPending = true
                        SetTimeout(checkpointDebounce, function()
                            pairCheckpointPending = false
                            if equipped and offhand then
                                FlushPairConsumption()
                            end
                        end)
                    elseif not changed and pairFallbackPending and not pairSingleFallback then
                        -- On restore, an empty clip is already authoritative and
                        -- needs no checkpoint before entering single-weapon mode.
                        local fallbackSlot = pairFallbackPending
                        local survivor = fallbackSlot == 'primary' and equipped or offhand
                        pairFallbackPending = nil
                        ActivateLoadedPairSlot(ped, fallbackSlot, survivor)
                    end
                end
                Wait(observationInterval)
            end
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    local runtimeConfig = Config.Runtime or {}
    local observationInterval = math.max(25, math.floor(tonumber(runtimeConfig.observationIntervalMs) or 50))
    local checkpointDebounce = math.max(0, math.floor(tonumber(runtimeConfig.checkpointDebounceMs) or 250))
    local fireWindowUntil = 0
    local wasShooting = false
    local shotSequence = 0
    local attributedShotSequence = 0
    local shotWeapon
    while true do
        while LifeStateSuspended() do Wait(100) end
        local active = false
        local ped = PlayerPedId()
        local selectedOk, selectedWeapon = GetCurrentPedWeapon(ped, true, 0, false)
        local shooting = NativeTrue(IsPedShooting(ped))
        if shooting then
            fireWindowUntil = GetGameTimer() + 250
            if not wasShooting then
                shotSequence = shotSequence + 1
                shotWeapon = NativeTrue(selectedOk) and selectedWeapon or nil
            end
        end
        wasShooting = shooting

        for _, slot in ipairs({ 'shoulder', 'back', 'throwable', 'throwable_secondary', 'throwable_tertiary', 'throwable_quaternary', 'throwable_quinary', 'throwable_senary', 'throwable_septenary', 'throwable_octonary', 'throwable_nonary', 'throwable_denary' }) do
            local state = extraSlots[slot]
            local observed = extraObserved[slot]
            if state and observed and state.ammoPools and WeaponConstants.ThrowableSlots[slot]
                and characterRestoreComplete and not characterRestoreInFlight and not logoutCheckpointInFlight then
                active = true
                ObserveKnifePools(state, observed)
                if not extraSyncInFlight[slot] and GetGameTimer() >= (observed.nextPoolSync or 0) then
                    observed.nextPoolSync = GetGameTimer() + 500
                    FlushExtraSlot(slot)
                end
            end
            if state and observed and not logoutCheckpointInFlight
                and characterRestoreComplete and not characterRestoreInFlight
                and not state.ammoPools
                and ThrowablePoolReady(slot, state, observed) then
                active = true
                local weaponHash = joaat(state.nativeWeaponName)
                local clipOk, clipAmount = GetAmmoInClip(ped, weaponHash)
                local poolRecovery = 0
                if WeaponConstants.ThrowableSlots[slot]
                    and type(state.nativeAmmoName) == 'string' then
                    -- Throwable inventory is represented by the ammo-type pool.
                    -- Some builds do not expose a firearm-style clip surface,
                    -- so synthesize the one readied item from the owned pool.
                    local authorized = math.max(0, math.floor(tonumber(state.ammo) or 0)
                        - math.floor(tonumber(observed.consumed) or 0)
                        + math.floor(tonumber(observed.recovered) or 0))
                    local nativeTotal = math.max(0, math.floor(tonumber(
                        GetPedAmmoByType(ped, joaat(state.nativeAmmoName))) or 0))
                    if nativeTotal > authorized then
                        -- The server accepts this increase only against recovery
                        -- credit created by previously committed throws.
                        poolRecovery = nativeTotal - authorized
                        observed.recovered = math.floor(tonumber(observed.recovered) or 0)
                            + poolRecovery
                    end
                    clipAmount = math.min(1, nativeTotal)
                    clipOk = true
                end
                if NativeTrue(clipOk) then
                    local loaded = math.max(0, math.floor(tonumber(clipAmount) or 0))
                    local clipDecrease = math.max(0, observed.loaded - loaded)
                    local otherSlot = slot == 'shoulder' and 'back' or 'shoulder'
                    local other = extraSlots[otherSlot]
                    local isolatedAmmoPool = not other
                        or other.nativeAmmoName ~= state.nativeAmmoName
                    local poolDecrease = 0
                    if isolatedAmmoPool and state.nativeAmmoName then
                        local authorized = math.max(0,
                            (tonumber(state.ammo) or 0) - observed.consumed
                                + math.floor(tonumber(observed.recovered) or 0))
                        local nativeTotal = math.max(0, math.floor(tonumber(
                            GetPedAmmoByType(ped, joaat(state.nativeAmmoName))) or 0))
                        poolDecrease = math.max(0, authorized - nativeTotal)
                    end
                    local selectedShot = clipDecrease > 0
                        and GetGameTimer() <= fireWindowUntil
                        and NativeTrue(selectedOk) and selectedWeapon == weaponHash
                    if isolatedAmmoPool and clipDecrease > 0
                        and poolDecrease == 0 and not selectedShot then
                        -- Character teardown and some holster transitions expose
                        -- a transient zero clip while the owned ammo-type total
                        -- remains unchanged. Do not persist that presentation
                        -- artifact as an empty magazine.
                        loaded = observed.loaded
                        clipDecrease = 0
                    end
                    local sharedShot = not isolatedAmmoPool
                        and NativeTrue(selectedOk) and selectedWeapon == weaponHash
                        and (clipDecrease > 0
                            or (shotSequence > attributedShotSequence and shotWeapon == weaponHash))
                    if poolDecrease > 0 or selectedShot or sharedShot then
                        observed.consumed = observed.consumed
                            + math.max(poolDecrease, selectedShot and clipDecrease or 0,
                                sharedShot and math.max(1, clipDecrease) or 0)
                        if sharedShot then attributedShotSequence = shotSequence end
                    end

                    local changed = loaded ~= observed.loaded or poolDecrease > 0
                        or poolRecovery > 0 or sharedShot
                    observed.loaded = loaded
                    if changed then
                        local itemInstanceId, generation = state.itemInstanceId, state.generation
                        SetTimeout(checkpointDebounce, function()
                            local current = extraSlots[slot]
                            if current and SameInstance(current.itemInstanceId, itemInstanceId)
                                and current.generation == generation then
                                FlushExtraSlot(slot)
                            end
                        end)
                    end
                end
            end
        end
        Wait(active and observationInterval or 500)
    end
end)

-- RedM cannot keep a reserve visible for two different long-gun hashes that
-- share an ammunition type. Expose only the selected weapon's reload amount,
-- then return the native pool to the combined clips when the animation ends.
-- Empty longguns must not see another item's native reserve. The pool module
-- tracks hidden escrow and rematerializes the funded clip on switch-back.
CreateThread(function()
    while true do
        while LifeStateSuspended() do Wait(100) end
        local ped = PlayerPedId()
        local selectedOk, selectedWeapon = GetCurrentPedWeapon(ped, true, 0, false)
        local blocked
        if NativeTrue(selectedOk) and not characterRestoreInFlight
            and not presentationRestoreInFlight and not inventoryWeaponInFlight
            and not firearmPoolsInFlight and not maintenanceBatchInFlight then
            FeatherFirearmPools.UpdateLonggunWindow(ped, selectedWeapon, WeaponDefinitionCatalog)
            for _, slot in ipairs({ 'shoulder', 'back' }) do
                local state = extraSlots[slot]
                local other = extraSlots[slot == 'shoulder' and 'back' or 'shoulder']
                if state and state.ammoPools and other
                    and state.nativeAmmoName == other.nativeAmmoName
                    and selectedWeapon == joaat(state.nativeWeaponName)
                    and (state.ammoPools[state.ammunitionType] or 0) == 0
                    and (other.ammo or 0) > 0 then
                    blocked = state
                    break
                end
            end
        end
        if blocked then
            DisableControlAction(0, joaat('INPUT_RELOAD'), true)
            DisableControlAction(0, joaat('INPUT_ATTACK'), true)
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        while LifeStateSuspended() do Wait(100) end
        local ped = PlayerPedId()
        local selectedOk, selectedWeapon = GetCurrentPedWeapon(ped, true, 0, false)
        local selectedSlot, selectedState
        if NativeTrue(selectedOk) then
            for _, slot in ipairs({ 'shoulder', 'back' }) do
                local state = extraSlots[slot]
                local other = extraSlots[slot == 'shoulder' and 'back' or 'shoulder']
                if state and other and not state.ammoPools and type(state.nativeAmmoName) == 'string'
                    and type(state.nativeWeaponName) == 'string'
                    and state.nativeAmmoName == other.nativeAmmoName
                    and joaat(state.nativeWeaponName) == selectedWeapon then
                    selectedSlot, selectedState = slot, state
                    break
                end
            end
        end

        if selectedState and selectedSlot then
            DisableControlAction(0, joaat('INPUT_RELOAD'), true)
            if IsDisabledControlJustPressed(0, joaat('INPUT_RELOAD'))
                and not longgunReloadInFlight then
                local nativeAmmoName = selectedState.nativeAmmoName
                local loadedTotal = 0
                local selectedLoaded = math.max(0,
                    math.floor(tonumber(selectedState.loaded) or 0))
                local authorized = 0
                local intendedClips = {}
                for _, slot in ipairs({ 'shoulder', 'back' }) do
                    local state = extraSlots[slot]
                    if state and state.nativeAmmoName == nativeAmmoName then
                        local clipOk, loaded = GetAmmoInClip(ped, joaat(state.nativeWeaponName))
                        loaded = NativeTrue(clipOk) and math.max(0, math.floor(tonumber(loaded) or 0)) or state.loaded
                        local observed = extraObserved[slot]
                        intendedClips[slot] = math.max(0, math.floor(tonumber(observed and observed.loaded) or state.loaded or loaded))
                        loadedTotal = loadedTotal + intendedClips[slot]
                        authorized = authorized + math.max(0,
                            math.floor(tonumber(state.ammo) or 0)
                                - math.floor(tonumber(observed and observed.consumed) or 0))
                        if slot == selectedSlot then selectedLoaded = loaded end
                    end
                end

                local capacity = math.max(selectedLoaded, math.floor(tonumber(selectedState.capacity) or 0))
                local amount = math.min(math.max(0, capacity - selectedLoaded), math.max(0, authorized - loadedTotal))
                if amount > 0 then
                    intendedClips[selectedSlot] = selectedLoaded + amount
                    longgunReloadInFlight = true
                    if Config.DevMode then
                        print(('[feather-weapons] shared long-gun reload requested slot=%s loaded=%d amount=%d authorized=%d clips=%d')
                            :format(selectedSlot, selectedLoaded, amount, authorized, loadedTotal))
                    end
                    Citizen.InvokeNative(0x106A811C6D3035F3, ped, joaat(nativeAmmoName), amount, joaat('ADD_REASON_DEFAULT')) -- AddAmmoToPedByType
                    MakePedReload(ped)
                    CreateThread(function()
                        local deadline = GetGameTimer() + 2000
                        repeat
                            Wait(25)
                        until NativeTrue(IsPedReloading(ped))
                            or GetGameTimer() >= deadline
                        if not NativeTrue(IsPedReloading(ped)) then
                            TaskReloadWeapon(ped, false)
                            deadline = GetGameTimer() + 3000
                            repeat
                                Wait(25)
                            until NativeTrue(IsPedReloading(ped))
                                or GetGameTimer() >= deadline
                        end

                        local started = NativeTrue(IsPedReloading(ped))
                        if NativeTrue(IsPedReloading(ped)) then
                            deadline = GetGameTimer() + 5000
                            repeat
                                Wait(25)
                            until not NativeTrue(IsPedReloading(ped))
                                or GetGameTimer() >= deadline
                        end

                        local clipTotal = 0
                        for _, slot in ipairs({ 'shoulder', 'back' }) do
                            local state = extraSlots[slot]
                            if state and state.nativeAmmoName == nativeAmmoName then
                                local loaded = math.max(0, math.floor(tonumber(intendedClips[slot]) or state.loaded or 0))
                                SetAmmoInClip(ped, joaat(state.nativeWeaponName), loaded)
                                extraObserved[slot] = { loaded = loaded, consumed = 0, recovered = 0 }
                                clipTotal = clipTotal + loaded
                            end
                        end

                        SetPedAmmoByType(ped, joaat(nativeAmmoName), clipTotal)
                        longgunReloadInFlight = false
                        FlushExtraSlot(selectedSlot)
                        if Config.DevMode then
                            print(('[feather-weapons] shared long-gun reload %s slot=%s nativeClips=%d')
                                :format(started and 'complete' or 'failed', selectedSlot, clipTotal))
                        end
                    end)
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        while LifeStateSuspended() do Wait(100) end
        if equipped and equipped.attachments and #equipped.attachments > 0 and GetGameTimer() < attachmentReconcileUntil then
            ApplyNativeAttachments(equipped.nativeWeaponName, equipped.attachments)
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

local RestoreRuntimeWeapons

local function CharacterIsActive()
    if GetResourceState('feather-character') ~= 'started' then return false end
    local called, active = pcall(function()
        return exports['feather-character']:HasActiveCharacter()
    end)
    return called and active == true
end

local function ScheduleCharacterRestore(generation, delayMs, reason)
    SetTimeout(delayMs, function()
        if generation ~= characterRestoreGeneration or characterRestoreComplete
            or characterRestoreInFlight or not CharacterIsActive() then
            return
        end
        RestoreRuntimeWeapons(reason)
    end)
end

local function BeginCharacterRestoreWindow(reason)
    characterRestoreGeneration = characterRestoreGeneration + 1
    characterRestoreInFlight = false
    characterRestoreComplete = false
    characterRestoreAttempts = 0
    local generation = characterRestoreGeneration
    ScheduleCharacterRestore(generation, math.max(1000, math.floor(tonumber(
        Config.Runtime and Config.Runtime.characterRestoreFallbackMs) or 6000)), reason)
    return generation
end

RestoreRuntimeWeapons = function(reason)
    if LifeStateSuspended() then return end
    if characterRestoreComplete or characterRestoreInFlight or not CharacterIsActive() then
        return
    end

    local runtimeConfig = Config.Runtime or {}
    local maxAttempts = math.max(1, math.floor(tonumber(
        runtimeConfig.characterRestoreMaxAttempts) or 3))
    if characterRestoreAttempts >= maxAttempts then
        if Config.DevMode then
            print(('[feather-weapons] character restore abandoned attempts=%d reason=%s')
                :format(characterRestoreAttempts, tostring(reason)))
        end
        return
    end

    characterRestoreAttempts = characterRestoreAttempts + 1
    characterRestoreInFlight = true
    local generation = characterRestoreGeneration
    CreateThread(function()
        -- Native inventory preparation may discard weapon instances. Block
        -- observation and invalidate any earlier restore before invoking it.
        singleRestoreSequence = singleRestoreSequence + 1
        singleNativeReady = false
        local prepared = FeatherNativeWeaponCoordinator.PrepareCharacterRestore(
            PlayerPedId(), 5000)
        if generation ~= characterRestoreGeneration then
            return
        end
        if not CharacterIsActive() then
            characterRestoreInFlight = false
            return
        end
        if not prepared.ok then
            characterRestoreInFlight = false
            Notify(prepared.message or 'The native carried-weapon inventory did not become ready.')
            if Config.DevMode then
                print(('[feather-weapons] restore deferred code=%s message=%s'):format(tostring(prepared.code), tostring(prepared.message)))
            end
            ScheduleCharacterRestore(generation, math.max(250, math.floor(tonumber(
                runtimeConfig.characterRestoreRetryMs) or 2000)), 'prepare-retry')
            return
        end

        if Config.DevMode then
            print('[feather-weapons] native character weapon inventory prepared')
        end
        -- Reconciliation must recreate every approved instance after native
        -- preparation; stale local state must never suppress that grant.
        ClearNativeWeapon()
        FeatherWeaponsClient.Reconcile(function(result)
            if generation ~= characterRestoreGeneration then return end
            characterRestoreInFlight = false
            characterRestoreComplete = type(result) == 'table' and result.ok == true
            if not characterRestoreComplete then
                local failure = type(result) == 'table' and result.error and result.error.code
                if failure then
                    print(('[feather-weapons] character restore failed code=%s'):format(tostring(failure)))
                end
                if failure == 'mixed_firearm_pool_modes' or failure == 'firearm_pool_module_missing' then
                    characterRestoreAttempts = maxAttempts
                    print(('[feather-weapons] character restore blocked code=%s; correct the loadout or deployment before retrying')
                        :format(tostring(failure)))
                    return
                end
                ScheduleCharacterRestore(generation, math.max(250, math.floor(tonumber(
                    runtimeConfig.characterRestoreRetryMs) or 2000)), 'reconcile-retry')
            elseif Config.DevMode then
                print(('[feather-weapons] character restore complete attempt=%d reason=%s')
                    :format(characterRestoreAttempts, tostring(reason)))
            end
        end, { holster = true })
    end)
end

AddEventHandler('Feather:Character:Spawned', function()
    RegisterCharacterLogoutCheckpoint()
    BeginCharacterRestoreWindow('spawn-fallback')
end)

AddEventHandler('feather-character:client:runtime-ready.v1', function()
    RestoreRuntimeWeapons('character-runtime-ready')
end)

AddEventHandler('feather-medical:client:condition-changed.v1', function()
    local called, result = pcall(function() return exports['feather-medical']:GetLifeState() end)
    if not called or not result or not result.ok then return end
    if result.value.lifeState ~= 'alive' then
        SuspendForDeath()
        return
    end
    if recoverySuspended then
        if deathPoolCheckpointPending then
            if deathPoolCheckpointFailed then
                print('[feather-weapons] recovery restore blocked by failed death pool checkpoint')
                return
            end
            print('[feather-weapons] recovery waiting for death pool checkpoint')
            SetTimeout(100, function()
                TriggerEvent('feather-medical:client:condition-changed.v1')
            end)
            return
        end
        recoverySuspended = false
        BeginCharacterRestoreWindow('medical-recovery')
        local generation = characterRestoreGeneration
        local function RestoreAfterWrites()
            if generation ~= characterRestoreGeneration or LifeStateSuspended() then return end
            if firearmPoolsInFlight or syncInFlight or pairSyncInFlight or maintenanceBatchInFlight
                or extraSyncInFlight.shoulder or extraSyncInFlight.back then
                SetTimeout(50, RestoreAfterWrites)
                return
            end
            RestoreRuntimeWeapons('medical-recovery')
        end
        RestoreAfterWrites()
    end
end)

RegisterNetEvent('feather-weapons:client:runtime-ready', function()
    RestoreRuntimeWeapons('weapons-runtime-ready')
end)

CreateThread(function()
    local lastWarning, warningEpoch
    local retryAfter = 0
    local retryEpoch
    while true do
        while LifeStateSuspended() do Wait(100) end
        Wait(100)
        if characterRestoreComplete and FirearmPoolsActive() and not firearmPoolsInFlight
            and not characterRestoreInFlight and not presentationRestoreInFlight
            and not inventoryWeaponInFlight and not logoutCheckpointInFlight
            and (retryEpoch ~= firearmPoolsEpoch or GetGameTimer() >= retryAfter) then
            FlushFirearmPools(function(result)
                if result and not result.ok then
                    local code = tostring(result.error and result.error.code)
                    retryEpoch = firearmPoolsEpoch
                    retryAfter = GetGameTimer() + (code == 'rate_limited' and 15000 or 2000)
                    if Config.DevMode and (lastWarning ~= code or warningEpoch ~= firearmPoolsEpoch) then
                        print(('[feather-weapons] firearm pool checkpoint deferred code=%s message=%s detail=%s')
                            :format(code, tostring(result.error and result.error.message),
                                tostring(result.error and result.error.detail)))
                    end
                    lastWarning, warningEpoch = code, firearmPoolsEpoch
                else
                    lastWarning, warningEpoch = nil, nil
                    retryAfter, retryEpoch = 0, nil
                end
            end)
        end
    end
end)

AddEventHandler('Feather:Character:Logout', function()
    recoverySuspended = false
    deathPoolCheckpointPending, deathPoolCheckpointFailed = false, false
    characterRestoreGeneration = characterRestoreGeneration + 1
    characterRestoreInFlight = false
    characterRestoreComplete = false
    characterRestoreAttempts = 0
    inventoryWeaponInFlight = false
    ClearNativeWeapon()
end)

RegisterCharacterLogoutCheckpoint = function()
    if GetResourceState('feather-character') ~= 'started' then return end

    local called, result = pcall(function()
        return exports['feather-character']:RegisterLogoutCheckpoint('feather-weapons:runtime', 'CheckpointBeforeLogout')
    end)

    if Config.DevMode then
        local passed = called and result and result.ok == true
        local failure = type(result) == 'table' and (result.error or result) or nil
        print(('[feather-weapons] character logout checkpoint registration %s code=%s message=%s'):format(
            passed and 'PASS' or 'FAIL',
            tostring(passed and 'none' or (failure and failure.code) or 'export_error'),
            tostring(passed and 'none' or (failure and failure.message) or result)))
    end
end

exports('CheckpointBeforeLogout', function()
    logoutCheckpointInFlight = true
    SetTimeout(5000, function()
        logoutCheckpointInFlight = false
    end)

    local deadline = GetGameTimer() + 2000
    while (firearmPoolsInFlight or longgunReloadInFlight or syncInFlight or pairSyncInFlight
            or extraSyncInFlight.shoulder or extraSyncInFlight.back or extraSyncInFlight.melee
            or extraSyncInFlight.melee_secondary or extraSyncInFlight.melee_tertiary
            or extraSyncInFlight.utility_senary or extraSyncInFlight.utility_septenary or extraSyncInFlight.utility_octonary or extraSyncInFlight.utility_quinary or extraSyncInFlight.utility_quaternary or extraSyncInFlight.utility_tertiary or extraSyncInFlight.utility_secondary or extraSyncInFlight.utility or extraSyncInFlight.melee_quinary or extraSyncInFlight.melee_quaternary or extraSyncInFlight.throwable
            or extraSyncInFlight.throwable_secondary
            or extraSyncInFlight.throwable_tertiary or extraSyncInFlight.throwable_quaternary or extraSyncInFlight.throwable_quinary or extraSyncInFlight.throwable_senary or extraSyncInFlight.throwable_septenary or extraSyncInFlight.throwable_octonary or extraSyncInFlight.throwable_nonary or extraSyncInFlight.throwable_denary
            or maintenanceSyncInFlight.primary or maintenanceSyncInFlight.offhand
            or maintenanceSyncInFlight.shoulder or maintenanceSyncInFlight.back
            or maintenanceSyncInFlight.melee or maintenanceSyncInFlight.melee_secondary
            or maintenanceSyncInFlight.melee_tertiary or maintenanceSyncInFlight.utility_senary or maintenanceSyncInFlight.utility_septenary or maintenanceSyncInFlight.utility_octonary or maintenanceSyncInFlight.utility_quinary or maintenanceSyncInFlight.utility_quaternary or maintenanceSyncInFlight.utility_tertiary or maintenanceSyncInFlight.utility_secondary or maintenanceSyncInFlight.utility or maintenanceSyncInFlight.melee_quinary or maintenanceSyncInFlight.melee_quaternary
            or maintenanceSyncInFlight.throwable
            or maintenanceSyncInFlight.throwable_secondary
            or maintenanceSyncInFlight.throwable_tertiary or maintenanceSyncInFlight.throwable_quaternary or maintenanceSyncInFlight.throwable_quinary or maintenanceSyncInFlight.throwable_senary or maintenanceSyncInFlight.throwable_septenary or maintenanceSyncInFlight.throwable_octonary or maintenanceSyncInFlight.throwable_nonary or maintenanceSyncInFlight.throwable_denary)
        and GetGameTimer() < deadline do
        Wait(25)
    end

    local maintenancePending = promise.new()
    CheckpointMaintenance(function(result)
        maintenancePending:resolve(result)
    end)

    local maintenance = Citizen.Await(maintenancePending)
    if not maintenance or maintenance.ok ~= true then
        logoutCheckpointInFlight = false
        return maintenance
    end

    local pending = promise.new()
    FeatherWeaponsClient.Checkpoint(function(checkpoint)
        pending:resolve(checkpoint)
    end)

    local checkpoint = Citizen.Await(pending)
    if not checkpoint or checkpoint.ok ~= true then
        logoutCheckpointInFlight = false
    end
    if Config.DevMode then
        print(('[feather-weapons] logout checkpoint %s total=%s loaded=%s'):format(
            checkpoint and checkpoint.ok and 'PASS' or 'FAIL',
            tostring(checkpoint and checkpoint.value and checkpoint.value.total),
            tostring(checkpoint and checkpoint.value and checkpoint.value.loaded)))
    end
    return checkpoint
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RegisterCharacterLogoutCheckpoint()
        local generation = BeginCharacterRestoreWindow('resource-start-fallback')
        -- Client scripts can start before the restarted server listener is
        -- registered. Send the handshake after both environments have had
        -- time to finish loading. The bounded restore window remains the
        -- fallback if that event is still missed.
        SetTimeout(500, function()
            if generation == characterRestoreGeneration and not characterRestoreComplete then
                TriggerServerEvent('feather-weapons:server:client-ready')
            end
        end)
    elseif resourceName == 'feather-character' then
        RegisterCharacterLogoutCheckpoint()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearNativeWeapon()
    end
end)

if Config.DevMode then
    -- Read-only context for the opt-in death timing harness.
    function FeatherWeaponsClient.GetShotDeathContext(mode)
        if mode == 'longguns' then
            local shoulder, back = extraSlots.shoulder, extraSlots.back
            if not shoulder or not back or LifeStateSuspended()
                or not shoulder.nativeAmmoName
                or shoulder.nativeAmmoName ~= back.nativeAmmoName then return nil end
            local selectedOk, selectedHash = GetCurrentPedWeapon(PlayerPedId(), true, 0, true)
            if not NativeTrue(selectedOk) or (selectedHash ~= joaat(shoulder.nativeWeaponName)
                and selectedHash ~= joaat(back.nativeWeaponName)) then return nil end
            return {
                primary = shoulder.itemInstanceId, offhand = back.itemInstanceId,
                primaryGeneration = shoulder.generation, offhandGeneration = back.generation,
                epoch = firearmPoolsEpoch, restoreGeneration = characterRestoreGeneration,
                ammoHash = joaat(shoulder.nativeAmmoName), selectedHash = selectedHash,
                expected = (shoulder.ammo or 0) + (back.ammo or 0)
            }
        end
        if not equipped or not offhand or LifeStateSuspended()
            or equipped.nativeAmmoName ~= offhand.nativeAmmoName
            or not equipped.nativeAmmoName then return nil end
        return {
            primary = equipped.itemInstanceId, offhand = offhand.itemInstanceId,
            primaryGeneration = equipped.generation, offhandGeneration = offhand.generation,
            epoch = firearmPoolsEpoch, restoreGeneration = characterRestoreGeneration,
            ammoHash = joaat(equipped.nativeAmmoName),
            expected = (equipped.ammo or 0) + (offhand.ammo or 0)
        }
    end
    print(('[feather-weapons] client contract=%d dualSlots=true primaryPromotion=true'):format(clientContract))

    RegisterCommand('weaponmaintenance', function()
        local ped = PlayerPedId()
        for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
            local state = SlotState(slot)
            if state then
                local saved = state.maintenance or {}
                local native = FeatherNativeMaintenance.Read(ped, slot, state)
                print(('[feather-weapons] maintenance slot=%s item=%s condition=%s saved=%.3f/%.3f/%.3f/%.3f/%.3f native=%s')
                    :format(slot, tostring(state.itemInstanceId), tostring(state.condition),
                        tonumber(saved.degradation) or 0.0,
                        tonumber(saved.permanentDegradation) or 0.0,
                        tonumber(saved.damage) or 0.0,
                        tonumber(saved.dirt) or 0.0,
                        tonumber(saved.soot) or 0.0,
                        native and ('%.3f/%.3f/%.3f/%.3f/%.3f@%s'):format(
                            native.degradation, native.permanentDegradation,
                            native.damage, native.dirt, native.soot,
                            tostring(native.attachPoint)) or 'unavailable'))
            end
        end
    end, false)

    -- Compatibility is a native-definition observation, not unlock or live
    -- availability evidence. Do not grant ammo or guess unlock IDs from hashes.

    RegisterCommand('weaponthrowablecapacity', function(_, args)
        local slot = args and args[1] or 'throwable_tertiary'
        local state = extraSlots[slot]
        if not WeaponConstants.ThrowableSlots[slot] or not state then
            Notify('Equip a throwable in the requested slot first.')
            return
        end
        local called, nativeOk, maximum = pcall(function()
            return GetMaxAmmo(PlayerPedId(), joaat(state.nativeWeaponName))
        end)
        print(('[feather-weapons] throwable capacity slot=%s weapon=%s query=%s nativeOk=%s maximum=%s current=%s; read-only')
            :format(slot, state.nativeWeaponName, tostring(called), tostring(nativeOk),
                tostring(maximum), tostring(GetPedAmmoByType(PlayerPedId(), joaat(state.nativeAmmoName)))))
    end, false)

    -- Observe wheel selection without enabling variants, changing native pools,
    -- or treating a native pickup as Inventory ownership. Verify this query on
    -- the target RedM build before wiring it into multi-pool checkpoints.
    local throwableSelectionProbeRunning = false
    RegisterCommand('weaponthrowableselection', function(_, args)
        local slot = args and args[1] or 'throwable_secondary'
        local state = extraSlots[slot]
        if not WeaponConstants.ThrowableSlots[slot] or not state then
            Notify('Equip a throwable in the requested slot first.')
            return
        end
        if throwableSelectionProbeRunning then
            Notify('A throwable selection probe is already running.')
            return
        end
        local seconds = tonumber(args and args[2]) or 15
        if seconds ~= seconds then seconds = 15 end
        seconds = math.max(1, math.min(30, math.floor(seconds)))
        local definition = WeaponDefinitionCatalog.weapons[state.definitionId]
        local item, generation = state.itemInstanceId, state.generation
        local deadline = GetGameTimer() + seconds * 1000
        local previous
        throwableSelectionProbeRunning = true
        print(('[feather-weapons] throwable selection probe slot=%s duration=%ss; cycle wheel ammunition, read-only')
            :format(slot, seconds))
        CreateThread(function()
            while GetGameTimer() < deadline do
                local current = extraSlots[slot]
                if not current or current.itemInstanceId ~= item or current.generation ~= generation then
                    print('[feather-weapons] throwable selection probe stopped: equipped lease changed')
                    break
                end
                local ped = PlayerPedId()
                local called, ammoHash = pcall(function()
                    return GetPedAmmoTypeFromWeapon(ped, joaat(current.nativeWeaponName))
                end)
                local function MatchAmmo(hash)
                    if type(hash) ~= 'number' then return 'unknown' end
                    for _, ammunitionType in ipairs(definition and definition.ammunitionTypes or {}) do
                        local ammunition = WeaponDefinitionCatalog.ammunition[ammunitionType]
                        if ammunition and hash % 4294967296
                            == joaat(ammunition.nativeAmmoName) % 4294967296 then
                            return ammunitionType
                        end
                    end
                    return 'unknown'
                end
                local matched = called and MatchAmmo(ammoHash) or 'unknown'
                local selectedOk, selectedWeapon = GetCurrentPedWeapon(ped, true, 0, false)
                local activeCarrier = NativeTrue(selectedOk) and type(selectedWeapon) == 'number'
                    and selectedWeapon % 4294967296 == joaat(current.nativeWeaponName) % 4294967296
                local objects = {}
                -- Read-only getters, not _GET_WEAPON_OBJECT_FROM_PED, which
                -- detaches/removes the weapon. Observe both BOOL variants:
                -- their hand/selection behavior still needs a live check.
                for _, hand in ipairs({ false, true }) do
                    local objectCalled, object, objectHash = pcall(function()
                        local weaponObject = Citizen.InvokeNative(0x6CA484C9A7377E4F, ped, hand)
                        if type(weaponObject) ~= 'number' or weaponObject == 0 then
                            return weaponObject, nil
                        end
                        return weaponObject, Citizen.InvokeNative(0x7E7B19A4355FEE13, ped, weaponObject)
                    end)
                    objects[#objects + 1] = ('hand=%s/query=%s/object=%s/hash=%s/matched=%s')
                        :format(tostring(hand), tostring(objectCalled), tostring(object),
                            tostring(objectHash), objectCalled and MatchAmmo(objectHash) or 'unknown')
                end
                local pools = {}
                for _, ammunitionType in ipairs(definition and definition.ammunitionTypes or {}) do
                    local ammunition = WeaponDefinitionCatalog.ammunition[ammunitionType]
                    if ammunition then
                        local hash = joaat(ammunition.nativeAmmoName)
                        pools[#pools + 1] = ('%s=%s'):format(ammunition.nativeAmmoName,
                            tostring(GetPedAmmoByType(ped, hash)))
                    end
                end
                local sample = ('query=%s hash=%s matched=%s approved=%s activeCarrier=%s selected=%s/%s objects=[%s] pools=[%s]')
                    :format(tostring(called), tostring(ammoHash), matched,
                        tostring(current.ammunitionType), tostring(activeCarrier),
                        tostring(selectedOk), tostring(selectedWeapon), table.concat(objects, ', '),
                        table.concat(pools, ', '))
                if sample ~= previous then
                    print(('[feather-weapons] throwable selection slot=%s %s; read-only'):format(slot, sample))
                    previous = sample
                end
                Wait(100)
            end
            throwableSelectionProbeRunning = false
            print('[feather-weapons] throwable selection probe complete; no ownership or native state changed')
        end)
    end, false)

    RegisterCommand('weaponthrowablepoolfailure', function(_, args)
        local slot = args and args[1] or 'throwable'
        local state = extraSlots[slot]
        if not WeaponConstants.ThrowableSlots[slot] or not state
            or not state.nativeAmmoName or (tonumber(state.ammo) or 0) < 1
            or extraSyncInFlight[slot] or inventoryWeaponInFlight
            or logoutCheckpointInFlight then
            Notify('Load a throwable and wait for pending operations before testing native pool failure.')
            return
        end
        -- Simulate a fresh application that never accepted its approved pool.
        -- Override only the verification read. Native setters may immediately
        -- restore the real pool, so zeroing them is not a reliable fault test.
        -- A new observation on unload/reconcile clears this lease-local fault.
        extraObserved[slot] = {
            loaded = state.loaded, consumed = 0, recovered = 0,
            simulatePoolFailure = true
        }
        ThrowablePoolReady(slot, state, extraObserved[slot])
        print(('[feather-weapons] simulated throwable application failure slot=%s item=%s approved=%s; inspect metadata, then unload to verify conservation')
            :format(slot, tostring(state.itemInstanceId), tostring(state.ammo)))
    end, false)

    -- Read-only native snapshot that can capture a broken wheel/holster
    -- presentation without repairing or replacing coordinator-owned GUIDs.
    RegisterCommand('weaponruntime', function()
        local ped = PlayerPedId()
        local coordinator = FeatherNativeWeaponCoordinator.GetStatus()
        local selectedOk, selected = GetCurrentPedWeapon(ped, true, 0, false)
        print(('[feather-weapons] runtime state=%s epoch=%s reason=%s selected=%s/%s dual=%s')
            :format(tostring(coordinator.state), tostring(coordinator.epoch),
                tostring(coordinator.reason), tostring(selectedOk), tostring(selected),
                tostring(NativeTrue(GetAllowDualWield(ped)))))

        print(('[feather-weapons] runtime checkpoint pair=%s inFlight=%s pending=%s consumed=%s/%s observed=%s/%s/%s')
            :format(tostring(equipped ~= nil and offhand ~= nil),
                tostring(pairSyncInFlight), tostring(pairCheckpointPending),
                tostring(pairConsumed.primary), tostring(pairConsumed.offhand),
                tostring(pairObserved and pairObserved.primary),
                tostring(pairObserved and pairObserved.offhand),
                tostring(pairObserved and pairObserved.total)))
        print(('[feather-weapons] runtime checkpoint longguns inFlight=%s/%s consumed=%s/%s observed=%s/%s')
            :format(tostring(extraSyncInFlight.shoulder), tostring(extraSyncInFlight.back),
                tostring(extraObserved.shoulder and rawget(extraObserved.shoulder, 'consumed')),
                tostring(extraObserved.back and rawget(extraObserved.back, 'consumed')),
                tostring(extraObserved.shoulder and rawget(extraObserved.shoulder, 'loaded')),
                tostring(extraObserved.back and rawget(extraObserved.back, 'loaded'))))
        for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
            local state = SlotState(slot)
            if state then
                local clipOk, loaded
                if (slot == 'primary' or slot == 'offhand') and equipped and offhand then
                    local primaryOk, primaryLoaded, offhandOk, offhandLoaded = PairNativeClips(equipped, offhand)
                    if slot == 'primary' then
                        clipOk, loaded = primaryOk, primaryLoaded
                    else
                        clipOk, loaded = offhandOk, offhandLoaded
                    end
                elseif WeaponConstants.ThrowableSlots[slot]
                    and type(state.nativeAmmoName) == 'string' then
                    loaded = math.min(1, math.max(0, math.floor(tonumber(
                        GetPedAmmoByType(ped, joaat(state.nativeAmmoName))) or 0)))
                    clipOk = true
                else
                    clipOk, loaded = GetAmmoInClip(ped, joaat(state.nativeWeaponName))
                end

                local nativeOwned = NativeTrue(Citizen.InvokeNative(
                    0x8DECB02F88F428BC, ped, joaat(state.nativeWeaponName), 0, false)) -- HasPedGotWeapon
                print(('[feather-weapons] runtime local %s item=%s generation=%s total=%s loaded=%s reserve=%s nativeLoaded=%s clipOk=%s nativeOwned=%s')
                    :format(slot, tostring(state.itemInstanceId), tostring(state.generation),
                        tostring(state.ammo), tostring(state.loaded), tostring(state.reserve),
                        tostring(loaded), tostring(clipOk), tostring(nativeOwned)))
                if WeaponConstants.ThrowableSlots[slot] and not state.ammoPools then
                    local observed = extraObserved[slot]
                    print(('[feather-weapons] runtime throwable verification slot=%s ready=%s simulatedFailure=%s')
                        :format(slot, tostring(observed and observed.nativePoolReady == true),
                            tostring(Config.DevMode and observed and observed.simulatePoolFailure == true)))
                end
            end
        end

        local reportedPools = {}
        for _, slot in ipairs(WeaponConstants.LoadoutSlots) do
            local state = SlotState(slot)
            if state and state.nativeAmmoName and not reportedPools[state.nativeAmmoName] then
                reportedPools[state.nativeAmmoName] = true
                print(('[feather-weapons] runtime ammo %s nativeTotal=%s')
                    :format(state.nativeAmmoName, tostring(GetPedAmmoByType(ped, joaat(state.nativeAmmoName)))))
            end
            if state and state.nativeAmmoName then
                if state.ammoPools then
                    local observed = extraObserved[slot]
                    for id, amount in pairs(state.ammoPools) do
                        print(('[feather-weapons] runtime ammo pool slot=%s type=%s saved=%s observed=%s ready=%s')
                            :format(slot, id, tostring(amount), tostring(observed and observed.pools and observed.pools[id]),
                                tostring(observed and observed.poolReady and observed.poolReady[id])))
                    end
                end
                local definition = WeaponDefinitionCatalog.weapons[state.definitionId]
                for _, id in ipairs(definition and definition.ammunitionTypes or {}) do
                    local ammunition = WeaponDefinitionCatalog.ammunition[id]
                    local nativeName = ammunition and ammunition.nativeAmmoName
                    if nativeName and not reportedPools[nativeName] then
                        reportedPools[nativeName] = true
                        print(('[feather-weapons] runtime ammo %s nativeTotal=%s unselected=true')
                            :format(nativeName, tostring(GetPedAmmoByType(ped, joaat(nativeName)))))
                    end
                end
            end
        end

        for _, slot in ipairs({ 'primary', 'offhand' }) do
            local state = coordinator.slots[slot]
            if state then
                local clipOk, loaded = FeatherGuidWeapons.ReadClip(ped, state.guidRecord)
                local total = FeatherGuidWeapons.ReadTotal(ped, state.guidRecord)
                print(('[feather-weapons] runtime %s item=%s weapon=%s nativeSlot=%s clip=%s/%s total=%s')
                    :format(slot, tostring(state.itemInstanceId),
                        tostring(state.nativeWeaponName),
                        tostring(state.guidRecord and state.guidRecord.slot),
                        tostring(clipOk), tostring(loaded), tostring(total)))
            end
        end

        local points = {}
        for _, attachPoint in ipairs({ 0, 1, 2, 3,
            Config.Loadout.shoulderAttachPoint, Config.Loadout.backAttachPoint }) do
            local present, weaponHash = GetCurrentPedWeapon(ped, true, attachPoint, true)
            points[#points + 1] = ('%d=%s/%s/%s'):format(attachPoint, tostring(present), tostring(weaponHash),
                tostring(GetCurrentPedWeaponEntityIndex(ped, attachPoint)))
        end
        print(('[feather-weapons] runtime points [%s]'):format(table.concat(points, ', ')))
    end, false)

    RegisterCommand('weaponstate', function()
        -- Diagnostics must not rebuild native weapons or disturb a depletion
        -- fallback. Query server authority directly and only print the result.
        FeatherCore.RPC.Call('feather-weapons:state:get', {}, function(result, rpcError)
            if result and result.ok then
                local coordinator = FeatherNativeWeaponCoordinator.GetStatus()
                local coordinatorPrimary = coordinator.slots.primary
                local coordinatorOffhand = coordinator.slots.offhand
                print(('[feather-weapons] coordinator state=%s epoch=%s reason=%s primary=%s offhand=%s')
                    :format(tostring(coordinator.state), tostring(coordinator.epoch),
                        tostring(coordinator.reason),
                        tostring(coordinatorPrimary and coordinatorPrimary.itemInstanceId),
                        tostring(coordinatorOffhand and coordinatorOffhand.itemInstanceId)))
                for nativeAmmoName, window in pairs(coordinator.ammoWindows or {}) do
                    print(('[feather-weapons] coordinator ammo=%s authorized=%s ceiling=%s observed=%s')
                        :format(tostring(nativeAmmoName), tostring(window.authorized),
                            tostring(window.ceiling), tostring(window.observed)))
                end

                local state = result.value.equipped
                local slots = result.value.slots or {}
                local secondary = slots.offhand
                print(('[feather-weapons] state equipped=%s primaryEquipped=%s item=%s serial=%s generation=%s total=%s loaded=%s reserve=%s condition=%s')
                    :format(
                        tostring(next(slots) ~= nil), tostring(state ~= nil),
                        tostring(state and state.itemInstanceId),
                        tostring(state and state.serialNumber),
                        tostring(state and state.generation),
                        tostring(state and state.ammo), tostring(state and state.loaded),
                        tostring(state and state.reserve), tostring(state and state.condition)))
                if state then
                    print(('[feather-weapons] ammo type=%s native=%s'):format(tostring(state.ammunitionType), tostring(state.nativeAmmoName)))
                    local attachmentIds = {}
                    for _, attachment in ipairs(state.attachments or {}) do
                        attachmentIds[#attachmentIds + 1] = tostring(attachment.definitionId)
                    end

                    print(('[feather-weapons] attachments count=%s ids=%s'):format(
                        tostring(#attachmentIds), #attachmentIds > 0 and table.concat(attachmentIds, ',') or 'none'))

                    local ped = PlayerPedId()
                    local clipOk, nativeLoaded
                    if secondary then
                        clipOk, nativeLoaded = PairNativeClips(state, secondary)
                    else
                        clipOk, nativeLoaded = GetAmmoInClip(ped, joaat(state.nativeWeaponName))
                    end

                    local nativeTotal = GetPedAmmoByType(ped, joaat(state.nativeAmmoName))
                    print(('[feather-weapons] native total=%s loaded=%s clipOk=%s'):format(
                        tostring(nativeTotal), tostring(nativeLoaded), tostring(clipOk)))
                end

                if secondary then
                    print(('[feather-weapons] offhand ammo type=%s native=%s'):format(
                        tostring(secondary.ammunitionType), tostring(secondary.nativeAmmoName)))
                    local _, _, clipOk, nativeLoaded = PairNativeClips(state, secondary)
                    print(('[feather-weapons] offhand item=%s serial=%s generation=%s total=%s loaded=%s reserve=%s condition=%s attachments=%s nativeLoaded=%s clipOk=%s')
                    :format(
                        tostring(secondary.itemInstanceId), tostring(secondary.serialNumber),
                        tostring(secondary.generation),
                        tostring(secondary.ammo), tostring(secondary.loaded),
                        tostring(secondary.reserve), tostring(secondary.condition),
                        tostring(#(secondary.attachments or {})),
                        tostring(nativeLoaded), tostring(clipOk)
                    ))

                    print(('[feather-weapons] pair nativeTotal=%s consumed=%s/%s'):format(
                        tostring(PairNativeTotal(state, secondary)),
                        tostring(pairConsumed.primary), tostring(pairConsumed.offhand)
                    ))
                end

                for _, slot in ipairs({ 'shoulder', 'back' }) do
                    local longgun = result.value.slots and result.value.slots[slot] or nil
                    if longgun then
                        local clipOk, nativeLoaded = GetAmmoInClip(
                            PlayerPedId(), joaat(longgun.nativeWeaponName))
                        local nativeTotal = GetPedAmmoByType(
                            PlayerPedId(), joaat(longgun.nativeAmmoName))
                        local attachPoint = slot == 'shoulder'
                            and Config.Loadout.shoulderAttachPoint or Config.Loadout.backAttachPoint
                        local attachOk, attachedWeapon = GetCurrentPedWeapon(
                            PlayerPedId(), true, attachPoint, true)
                        print(('[feather-weapons] %s item=%s serial=%s definition=%s generation=%s total=%s loaded=%s reserve=%s condition=%s ammoType=%s nativeAmmo=%s nativeTotal=%s nativeLoaded=%s clipOk=%s attachPoint=%s attached=%s/%s')
                            :format(slot, tostring(longgun.itemInstanceId),
                                tostring(longgun.serialNumber), tostring(longgun.definitionId),
                                tostring(longgun.generation),
                                tostring(longgun.ammo), tostring(longgun.loaded),
                                tostring(longgun.reserve), tostring(longgun.condition),
                                tostring(longgun.ammunitionType), tostring(longgun.nativeAmmoName),
                                tostring(nativeTotal), tostring(nativeLoaded), tostring(clipOk), tostring(attachPoint),
                                tostring(attachOk), tostring(attachedWeapon)))
                    end
                end
                return
            end

            local failure = result and result.error or rpcError
            print(('[feather-weapons] state failed: %s'):format(failure and
            (tostring(failure.code) .. ' - ' .. tostring(failure.message)) or 'no response'))
        end)
    end, false)

    RegisterCommand('WeaponDualEntitlementRemove', function()
        if not offhand then
            print('[feather-weapons] offhand entitlement remove skipped: no offhand equipped')
            return
        end

        RemoveOffhandEntitlements()
        SetAllowDualWield(PlayerPedId(), false)
        print('[feather-weapons] offhand entitlement removed; awaiting fail-closed recovery')
    end, false)
end

exports('initiate', function() return FeatherWeaponsClient end)

FeatherWeaponsClientReady = true
