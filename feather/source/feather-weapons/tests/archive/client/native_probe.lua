local settings = Config.NativeProbe or {}
if Config.CharacterAmmunitionEnabled==true or Config.CharacterAmmoTransportEnabled==true then return end

if Config.DevMode ~= true or settings.enabled ~= true then return end

local weaponName = settings.weapon or 'WEAPON_REVOLVER_CATTLEMAN'
local configuredOffhandWeaponName = settings.offhandWeapon or 'WEAPON_REVOLVER_SCHOFIELD'
local offhandWeaponName = configuredOffhandWeaponName
local ammoName = settings.ammo or 'AMMO_REVOLVER'
local weaponHash = joaat(weaponName)
local offhandWeaponHash = joaat(offhandWeaponName)
local ammoHash = joaat(ammoName)
local capacity = math.max(1, math.floor(tonumber(settings.capacity) or 6))
local primaryAttachPoint = math.floor(tonumber(settings.primaryAttachPoint) or 2)
local offhandAttachPoint = math.floor(tonumber(settings.offhandAttachPoint) or 3)
local interval = math.max(25, math.floor(tonumber(settings.observationIntervalMs) or 50))
local active = false
local watching = false
local dualWatching = false
local previousDual = nil
local previous = nil
local marks = {}
local markCounter = 0
local logicalItem = 'unlabeled'
local addReason = joaat('ADD_REASON_DEFAULT')
local nativeRemoveReason = joaat('REMOVE_REASON_CLIENT_PURGED')
local offhandUnlock = -200143754
local dualOverride = nil
local dualEntitlements = {}
local dualWeaponCopies = nil
local holsterProbeWeaponHash = nil
local holsterProbeWeaponName = nil
local holsterProbeAttachPoint = nil
local specialProbeAmmoHash = nil
local specialProbePending = false
local specialProbeRead = nil

local function NativeTrue(value)
    return value == true or value == 1
end

local function GetDualWieldAllowed(ped)
    return NativeTrue(GetAllowDualWield(ped))
end

local function SetDualWieldAllowed(ped, allowed)
    SetAllowDualWield(ped, allowed == true)
end

local function IsOffhandUnlocked()
    return NativeTrue(Citizen.InvokeNative(0xC4B660C7B6040E75, offhandUnlock)) -- UnlockIsUnlocked
end

local function IsOffhandVisible()
    return NativeTrue(Citizen.InvokeNative(0x8588A14B75AF096B, offhandUnlock)) -- UnlockIsVisible
end

local function SetOffhandUnlocked(unlocked)
    Citizen.InvokeNative(0x1B7C5ADA8A6910A0, offhandUnlock, unlocked == true) -- UnlockSetUnlocked
end

local function SetOffhandVisible(visible)
    Citizen.InvokeNative(0x46B901A8ECDB5A61, offhandUnlock, visible == true) -- UnlockSetVisible
end

local function AddNativeWardrobeEntitlement(itemName, slotId)
    local inventoryId = 1
    local itemHash = joaat(itemName)

    -- InventoryGetInventoryItemCountWithItemid
    local existing = math.max(0, math.floor(tonumber(Citizen.InvokeNative(0xE787F05DFC977BDE, inventoryId, itemHash, false)) or 0))
    if existing > 0 then
        return { ok = true, itemName = itemName, existing = true, count = existing }
    end

    -- ItemdatabaseIsKeyValid
    if not NativeTrue(Citizen.InvokeNative(0x6D5D51B188333FD1, itemHash, 0)) then
        return { ok = false, itemName = itemName, stage = 'item-invalid' }
    end

    local characterGuid = FeatherGuidWeapons.ResolveGuid(inventoryId, nil, joaat('CHARACTER'), 0xA1212100)
    if not characterGuid then
        return { ok = false, itemName = itemName, stage = 'character-guid' }
    end

    local wardrobeGuid = FeatherGuidWeapons.ResolveGuid(inventoryId, characterGuid, joaat('WARDROBE'), 0x3DABBFA7)
    if not wardrobeGuid then
        return { ok = false, itemName = itemName, stage = 'wardrobe-guid' }
    end

    local itemGuid = FeatherGuidWeapons.NewBuffer(8 * 13)
    local added = Citizen.InvokeNative(0xCB5D11F9508A928D, inventoryId, itemGuid, wardrobeGuid, itemHash, slotId, 1, addReason)
    if not NativeTrue(added) then
        return { ok = false, itemName = itemName, stage = 'add' }
    end

    -- InventoryEquipItemWithGuid
    local equipped = Citizen.InvokeNative(0x734311E2852760D0, inventoryId, itemGuid, true)
    if not NativeTrue(equipped) then
        -- InventoryRemoveInventoryItemWithGuid
        Citizen.InvokeNative(0x3E4E811480B3AE79, inventoryId, itemGuid, 1, joaat('REMOVE_REASON_DEFAULT'))
        return { ok = false, itemName = itemName, stage = 'equip' }
    end

    dualEntitlements[#dualEntitlements + 1] = {
        inventoryId = inventoryId,
        itemName = itemName,
        guid = itemGuid
    }
    return { ok = true, itemName = itemName, existing = false, count = 1 }
end

local function RemoveProbeEntitlements()
    for index = #dualEntitlements, 1, -1 do
        local entitlement = dualEntitlements[index]

        -- InventoryRemoveInventoryItemWithGuid
        local removed = Citizen.InvokeNative(0x3E4E811480B3AE79, entitlement.inventoryId, entitlement.guid, 1, joaat('REMOVE_REASON_DEFAULT'))
        print(('[WeaponNativeProbe] dual-entitlement remove item=%s removed=%s'):format(entitlement.itemName, tostring(NativeTrue(removed))))
    end
    dualEntitlements = {}
end

local function RemoveProbeWeaponCopies()
    for _, outcome in ipairs(FeatherGuidWeapons.Destroy(dualWeaponCopies)) do
        local copy = outcome.record
        print(('[WeaponNativeProbe] dual-copy remove slot=%d weapon=%s removed=%s'):format(copy.slot, copy.weaponName, tostring(outcome.removed)))
    end
    dualWeaponCopies = nil
end

local function ReassertIdenticalWeaponPair(ped)
    return FeatherGuidWeapons.Activate(ped, dualWeaponCopies)
end

local function DualGuidSnapshot()
    local ped = PlayerPedId()
    local selectedOk, selected = GetCurrentPedWeapon(ped, true, 0, false)
    local snapshot = {
        selected = NativeTrue(selectedOk) and selected or 0,
        total = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0)),
        slots = {}
    }
    for _, copy in ipairs(dualWeaponCopies and dualWeaponCopies.records or {}) do
        local ok, loaded = FeatherGuidWeapons.ReadClip(ped, copy)
        snapshot.slots[#snapshot.slots + 1] = {
            slot = copy.slot,
            ok = ok,
            loaded = loaded,
            weaponTotal = FeatherGuidWeapons.ReadTotal(ped, copy)
        }
    end

    table.sort(snapshot.slots, function(left, right)
        return left.slot < right.slot
    end)

    local signature = { tostring(snapshot.selected), tostring(snapshot.total) }
    for _, slot in ipairs(snapshot.slots) do
        signature[#signature + 1] = ('%d:%s:%d:%d'):format(slot.slot, tostring(slot.ok), slot.loaded, slot.weaponTotal)
    end

    snapshot.signature = table.concat(signature, '|')
    return snapshot
end

local function PrintDualGuidSnapshot(label, snapshot)
    local slots = {}
    for _, slot in ipairs(snapshot.slots) do
        slots[#slots + 1] = ('slot%d=%d/%d clipOk=%s'):format(
            slot.slot, slot.loaded, slot.weaponTotal, tostring(slot.ok))
    end
    print(('[WeaponNativeProbe] dual-watch %s selected=%s total=%d guidAmmo=[%s]'):format(
        label, tostring(snapshot.selected), snapshot.total, table.concat(slots, ', ')))
end

local function AddIdenticalWeaponPair(ped, weapon)
    local created = FeatherGuidWeapons.CreateMatchingPair(ped, weapon)
    if not created.ok then
        return false, false, created.code or 'create-failed', 'not-ready'
    end

    dualWeaponCopies = created.value
    return true, true, 'ready', 'ready'
end

local function InventoryWeaponActive()
    local state = FeatherWeaponsClient and FeatherWeaponsClient.GetDiagnosticState
        and FeatherWeaponsClient.GetDiagnosticState() or nil
    return state and state.equipped == true, state
end

local function Clip(ped)
    local ok, amount = GetAmmoInClip(ped, weaponHash)
    return NativeTrue(ok), math.max(0, math.floor(tonumber(amount) or 0))
end

local function CurrentWeapon(ped)
    local ok, hash = GetCurrentPedWeapon(ped, true, 0, false)
    return NativeTrue(ok) and hash or 0
end

local function CurrentWeaponAt(ped, p2, attachPoint, p4)
    local ok, hash = GetCurrentPedWeapon(ped, p2, attachPoint, p4)
    return NativeTrue(ok), hash or 0
end

local function Snapshot()
    local ped = PlayerPedId()
    local clipOk, loaded = Clip(ped)
    local carried = Citizen.InvokeNative(0xD806CD2A4F2C2996, ped)
    return {
        time = GetGameTimer(),
        ped = ped,
        selected = CurrentWeapon(ped),
        weapon = weaponHash,
        clipOk = clipOk,
        loaded = loaded,
        weaponTotal = math.max(0, math.floor(tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)),
        ammoTypeTotal = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0)),
        reloading = NativeTrue(IsPedReloading(ped)),
        shooting = NativeTrue(IsPedShooting(ped)),
        dead = NativeTrue(IsEntityDead(ped)),
        mounted = NativeTrue(IsPedOnMount(ped)),
        walking = NativeTrue(IsPedWalking(ped)),
        running = NativeTrue(IsPedRunning(ped)),
        sprinting = NativeTrue(IsPedSprinting(ped)),
        inCover = NativeTrue(IsPedInCover(ped, true, true)),
        firstPersonAim = NativeTrue(IsFirstPersonAimCamActive()),
        carrying = carried ~= nil and carried ~= false and carried ~= 0,
        logicalItem = logicalItem
    }
end

local function Same(left, right)
    if not left or not right then return false end

    for _, key in ipairs({ 'selected', 'clipOk', 'loaded', 'weaponTotal', 'ammoTypeTotal',
        'reloading', 'shooting', 'dead', 'mounted', 'walking', 'running', 'sprinting',
        'inCover', 'firstPersonAim', 'carrying' }) do
        if left[key] ~= right[key] then return false end
    end
    return true
end

local function PrintSnapshot(label, snapshot)
    print(('[WeaponNativeProbe] %s item=%s selected=%s expected=%s clipOk=%s loaded=%d weaponTotal=%d '
        .. 'ammoTypeTotal=%d reloading=%s shooting=%s dead=%s mounted=%s walking=%s running=%s '
        .. 'sprinting=%s cover=%s firstPersonAim=%s carrying=%s'):format(
        tostring(label), tostring(snapshot.logicalItem), tostring(snapshot.selected), tostring(snapshot.weapon),
        tostring(snapshot.clipOk), snapshot.loaded, snapshot.weaponTotal, snapshot.ammoTypeTotal,
        tostring(snapshot.reloading),
        tostring(snapshot.shooting), tostring(snapshot.dead), tostring(snapshot.mounted),
        tostring(snapshot.walking), tostring(snapshot.running), tostring(snapshot.sprinting),
        tostring(snapshot.inCover), tostring(snapshot.firstPersonAim),
        tostring(snapshot.carrying)))
end

local function RefuseInventoryWeapon()
    local isActive, state = InventoryWeaponActive()
    if not isActive then return false end

    print(('[WeaponNativeProbe] REFUSED -- unequip Inventory weapon item=%s definition=%s first'):format(
        tostring(state.itemInstanceId), tostring(state.definitionId)))
    return true
end

local function RestoreDualWieldState()
    if not dualOverride then return end

    local ped = PlayerPedId()
    SetDualWieldAllowed(ped, dualOverride.allowed)
    SetOffhandUnlocked(dualOverride.unlocked)
    SetOffhandVisible(dualOverride.visible)
    print(('[WeaponNativeProbe] dual-allow restored allowed=%s unlocked=%s visible=%s'):format(
        tostring(GetDualWieldAllowed(ped)),
        tostring(IsOffhandUnlocked()),
        tostring(IsOffhandVisible())))
    dualOverride = nil
end

local function ClearNativeTestState(ped)
    if specialProbeAmmoHash then
        local amount = math.max(0, tonumber(GetPedAmmoByType(ped, specialProbeAmmoHash)) or 0)
        if amount > 0 then
            Citizen.InvokeNative(0xB6CFEC32E3742779, ped, specialProbeAmmoHash, amount, 0xA07362E6)
        end
        print(('[WeaponNativeProbe] special cleanup requested=%s remaining=%s')
            :format(tostring(amount), tostring(GetPedAmmoByType(ped, specialProbeAmmoHash))))
        specialProbeAmmoHash = nil
        specialProbeRead = nil
    end
    -- SetPedAmmoByType(..., 0) did not lower an existing pool on the tested
    -- runtime. Remove the observed amount while its weapon is still present;
    -- removing the weapon first left the prior ceiling behind.
    local amount = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
    if amount > 0 then
        -- RemoveAmmoFromPedByType, REMOVE_REASON_DEBUG
        Citizen.InvokeNative(0xB6CFEC32E3742779, ped, ammoHash, amount, 0xA07362E6)
    end

    local afterTypeRemoval = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
    RemoveProbeWeaponCopies()
    RemoveWeaponFromPed(ped, weaponHash, true, nativeRemoveReason)
    if offhandWeaponHash ~= weaponHash then
        RemoveWeaponFromPed(ped, offhandWeaponHash, true, nativeRemoveReason)
    end
    if holsterProbeWeaponHash
        and holsterProbeWeaponHash ~= weaponHash
        and holsterProbeWeaponHash ~= offhandWeaponHash then
        RemoveWeaponFromPed(ped, holsterProbeWeaponHash, true, nativeRemoveReason)
    end

    holsterProbeWeaponHash = nil
    holsterProbeWeaponName = nil
    holsterProbeAttachPoint = nil

    local afterWeaponRemoval = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
    print(('[WeaponNativeProbe] cleanup requested=%d afterType=%d afterWeapon=%d'):format(
        amount, afterTypeRemoval, afterWeaponRemoval))
end

local function HolsterProbePoints(ped)
    local points = {}
    for attachPoint = 0, 15 do
        local ok, hash = CurrentWeaponAt(ped, true, attachPoint, true)
        local entity = GetCurrentPedWeaponEntityIndex(ped, attachPoint)
        if NativeTrue(ok) or (entity and entity ~= 0) then
            points[#points + 1] = ('%d=%s/%s'):format(
                attachPoint, tostring(NativeTrue(ok) and hash or 0), tostring(entity or 0))
        end
    end
    return #points > 0 and table.concat(points, ', ') or 'none'
end

local function GiveProbeWeapon(ped, hash, attachPoint, allowMultipleCopies, forceInHand, forceInHolster)
    GiveWeaponToPed(
        ped,
        hash,
        0,
        forceInHand == true,
        forceInHolster == true,
        attachPoint,
        allowMultipleCopies == true,
        0.5,
        1.0,
        addReason,
        true,
        0.0,
        false
    )
end

RegisterCommand('WeaponNativeProbePrepare', function(_, args)
    if RefuseInventoryWeapon() then return end

    local loaded = math.floor(tonumber(args and args[1]) or capacity)
    local total = math.floor(tonumber(args and args[2]) or loaded)
    logicalItem = tostring(args and args[3] or 'unlabeled')
    loaded = math.max(0, math.min(capacity, loaded))
    total = math.max(loaded, total)

    local ped = PlayerPedId()
    ClearNativeTestState(ped)
    GiveProbeWeapon(ped, weaponHash, 0, false, false, true)

    local clipSet = SetAmmoInClip(ped, weaponHash, loaded)
    SetPedAmmoByType(ped, ammoHash, total)
    SetCurrentPedWeapon(ped, weaponHash, true, 0, false, false)

    active = true
    previous = Snapshot()
    print(('[WeaponNativeProbe] prepare requestedLoaded=%d requestedTotal=%d clipSet=%s'):format(loaded, total, tostring(clipSet)))
    PrintSnapshot('prepared', previous)
    local setupPassed = previous.selected == weaponHash and previous.clipOk
        and previous.loaded == loaded and previous.weaponTotal == total
        and previous.ammoTypeTotal == total
    print(('[WeaponNativeProbe] setup %s'):format(setupPassed and 'PASS' or 'FAIL'))
end, false)

-- Baseline experiment: one model, one special type, no production adapter,
-- normalization loop, GUID activation, or Inventory ammunition mutation.
RegisterCommand('WeaponNativeProbeSpecial', function()
    if RefuseInventoryWeapon() or specialProbePending then return end
    if weaponName ~= 'WEAPON_REVOLVER_CATTLEMAN' or ammoName ~= 'AMMO_REVOLVER' then
        print('[WeaponNativeProbe] REFUSED -- baseline requires Cattleman and regular probe defaults')
        return
    end
    specialProbePending = true
    -- Local state can be empty after a failed restore while server leases remain.
    FeatherCore.RPC.Call('feather-weapons:state:get', {}, function(result)
        specialProbePending = false
        if not result or not result.ok or type(result.value) ~= 'table'
            or type(result.value.slots) ~= 'table' then
            print('[WeaponNativeProbe] REFUSED -- server weapon state unavailable')
            return
        end
        if next(result.value.slots) ~= nil or RefuseInventoryWeapon() then
            print('[WeaponNativeProbe] REFUSED -- unequip all Inventory weapon slots first')
            return
        end
        local ped = PlayerPedId()
        ClearNativeTestState(ped)
        watching, dualWatching = false, false
        specialProbeAmmoHash = joaat('AMMO_REVOLVER_HIGH_VELOCITY')
        active = true
        local function Read(stage)
            local ok, clip = GetAmmoInClip(ped, weaponHash)
            print(('[WeaponNativeProbe] special stage=%s expected=%s selected=%s regular=%s highVelocity=%s clipOk=%s clip=%s')
                :format(stage, tostring(specialProbeAmmoHash),
                    tostring(Citizen.InvokeNative(0x7FEAD38B326B9F74, ped, weaponHash)),
                    tostring(GetPedAmmoByType(ped, ammoHash)),
                    tostring(GetPedAmmoByType(ped, specialProbeAmmoHash)),
                    tostring(NativeTrue(ok)), tostring(clip)))
        end
        specialProbeRead = Read
        GiveProbeWeapon(ped, weaponHash, 0, false, false, true)
        Read('created')
        SetPedAmmoByType(ped, specialProbeAmmoHash, 12)
        Read('seeded')
        Citizen.InvokeNative(0x23FB9FACA28779C1, ped, weaponHash, specialProbeAmmoHash)
        Citizen.InvokeNative(0xCC9C4393523833E2, ped, weaponHash, specialProbeAmmoHash)
        Read('type-requested')
        SetCurrentPedWeapon(ped, weaponHash, true, 0, false, false)
        Read('activated')
        print('[WeaponNativeProbe] special native-reload baseline ready; no clip write; draw/reload normally then run WeaponNativeProbeStatus')
    end)
end, false)

RegisterCommand('WeaponNativeProbeDualPrepare', function(_, args)
    if RefuseInventoryWeapon() then return end

    local primaryLoaded = math.max(0, math.min(capacity, math.floor(tonumber(args and args[1]) or capacity)))
    local offhandLoaded = math.max(0, math.min(capacity, math.floor(tonumber(args and args[2]) or capacity)))
    local total = math.max(primaryLoaded + offhandLoaded, math.floor(tonumber(args and args[3]) or (primaryLoaded + offhandLoaded)))
    local ped = PlayerPedId()

    ClearNativeTestState(ped)
    offhandWeaponName = tostring(args and args[4] or configuredOffhandWeaponName)
    offhandWeaponHash = joaat(offhandWeaponName)
    local primaryGranted, offhandGranted = true, true
    local primaryStage, offhandStage = 'hash-grant', 'hash-grant'
    if offhandWeaponHash == weaponHash then
        primaryGranted, offhandGranted, primaryStage, offhandStage =
            AddIdenticalWeaponPair(ped, weaponName)
    else
        GiveProbeWeapon(ped, weaponHash, primaryAttachPoint, false, true, false)
        GiveProbeWeapon(ped, offhandWeaponHash, offhandAttachPoint, false, true, false)
    end

    -- The offhand weapon entity is not queryable immediately after its grant.
    -- Distinct hashes can receive their clips directly after this settle point;
    -- identical hashes must remain GUID-managed below.
    Wait(100)
    local sameHash = offhandWeaponHash == weaponHash
    local primaryClipSet, offhandClipSet
    if sameHash then
        -- SET_AMMO_IN_CLIP is hash-addressed and cannot select one of two
        -- identical GUID-backed weapons. Calling it here can collapse RedM's
        -- active dual pair to either hand. Let native reload populate both
        -- GUID clips from the shared pool instead.
        primaryClipSet, offhandClipSet = 'guid-managed', 'guid-managed'
    else
        primaryClipSet = SetAmmoInClip(ped, weaponHash, primaryLoaded)
        offhandClipSet = SetAmmoInClip(ped, offhandWeaponHash, offhandLoaded)
    end

    SetPedAmmoByType(ped, ammoHash, total)

    if sameHash then
        ReassertIdenticalWeaponPair(ped)
        SetDualWieldAllowed(ped, true)
        Wait(1000)
        MakePedReload(ped)
        Wait(100)
    else
        SetCurrentPedWeapon(ped, weaponHash, true, primaryAttachPoint, false, false)
    end

    SetDualWieldAllowed(ped, true)

    local primaryClipOk, observedPrimary = GetAmmoInClip(ped, weaponHash)
    local offhandClipOk, observedOffhand = GetAmmoInClip(ped, offhandWeaponHash)
    local selected = CurrentWeapon(ped)
    local observedTotal = math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0))
    active = true
    print(('[WeaponNativeProbe] dual-prepare primary=%s offhand=%s selected=%s total=%d '
        .. 'primaryLoaded=%d primaryClipOk=%s primarySet=%s offhandLoaded=%d offhandClipOk=%s offhandSet=%s '
        .. 'attachPoints=%d/%d sameHash=%s grants=%s/%s stages=%s/%s dualAllowed=%s'):format(
        weaponName, offhandWeaponName, tostring(selected), observedTotal,
        math.max(0, math.floor(tonumber(observedPrimary) or 0)), tostring(NativeTrue(primaryClipOk)),
        tostring(primaryClipSet), math.max(0, math.floor(tonumber(observedOffhand) or 0)),
        tostring(NativeTrue(offhandClipOk)), tostring(offhandClipSet), primaryAttachPoint,
        offhandAttachPoint, tostring(sameHash),
        tostring(primaryGranted), tostring(offhandGranted), primaryStage, offhandStage,
        tostring(GetDualWieldAllowed(ped))
    ))
end, false)

RegisterCommand('WeaponNativeProbeHolsterPrepare', function(_, args)
    if RefuseInventoryWeapon() then return end

    local requestedPoint = math.floor(tonumber(args and args[1]) or offhandAttachPoint)
    if requestedPoint < 0 or requestedPoint > 15 then
        print('[WeaponNativeProbe] holster-prepare attach point must be between 0 and 15')
        return
    end

    local requestedWeapon = tostring(args and args[2] or 'WEAPON_PISTOL_M1899')
    local requestedHash = joaat(requestedWeapon)
    local ped = PlayerPedId()

    ClearNativeTestState(ped)
    holsterProbeWeaponName = requestedWeapon
    holsterProbeWeaponHash = requestedHash
    holsterProbeAttachPoint = requestedPoint

    GiveProbeWeapon(ped, weaponHash, primaryAttachPoint, false, false, true)
    GiveProbeWeapon(ped, requestedHash, requestedPoint, false, false, true)
    SetDualWieldAllowed(ped, true)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true, 0, false, false)
    Citizen.InvokeNative(0x94A3C1B804D291EC, ped, true, true, true, true) -- HolsterPedWeapons
    Wait(250)

    active = true
    print(('[WeaponNativeProbe] holster-prepare primary=%s attach%d test=%s attach%d selected=%s points=[%s]'):format(
        weaponName, primaryAttachPoint, requestedWeapon, requestedPoint,
        tostring(CurrentWeapon(ped)), HolsterProbePoints(ped)))
end, false)

RegisterCommand('WeaponNativeProbeHolsterStatus', function()
    local ped = PlayerPedId()
    print(('[WeaponNativeProbe] holster-status test=%s requestedAttach=%s selected=%s points=[%s]'):format(
        tostring(holsterProbeWeaponName), tostring(holsterProbeAttachPoint),
        tostring(CurrentWeapon(ped)), HolsterProbePoints(ped)))
end, false)

RegisterCommand('WeaponNativeProbeDualAllow', function(_, args)
    if RefuseInventoryWeapon() then return end

    local requested = tostring(args and args[1] or 'on'):lower()
    if requested == 'off' or requested == 'false' or requested == '0' then
        RestoreDualWieldState()
        return
    end

    local ped = PlayerPedId()
    if not dualOverride then
        dualOverride = {
            allowed = GetDualWieldAllowed(ped),
            unlocked = IsOffhandUnlocked(),
            visible = IsOffhandVisible()
        }
    end

    SetOffhandUnlocked(true)
    SetOffhandVisible(true)
    SetDualWieldAllowed(ped, true)
    print(('[WeaponNativeProbe] dual-allow requested=true allowed=%s unlocked=%s visible=%s'):format(
        tostring(GetDualWieldAllowed(ped)),
        tostring(IsOffhandUnlocked()),
        tostring(IsOffhandVisible())
    ))
end, false)

RegisterCommand('WeaponNativeProbeDualEntitle', function()
    if RefuseInventoryWeapon() then return end

    local ped = PlayerPedId()
    local modelHash = GetEntityModel(ped)
    local model = modelHash == joaat('mp_male') and 'mp_male'
        or modelHash == joaat('mp_female') and 'mp_female' or nil
    local entitlements = model and Config.Offhand.nativeEntitlements[model] or nil
    if type(entitlements) ~= 'table' then
        print(('[WeaponNativeProbe] no offhand entitlement policy for model=%s')
            :format(tostring(modelHash)))
        return
    end

    local outcomes = {}
    for _, entitlement in ipairs(entitlements) do
        outcomes[#outcomes + 1] = AddNativeWardrobeEntitlement(
            entitlement.itemName, entitlement.slotId)
    end

    SetDualWieldAllowed(ped, true)
    for _, outcome in ipairs(outcomes) do
        print(('[WeaponNativeProbe] dual-entitlement item=%s result=%s/%s existing=%s'):format(
            outcome.itemName, tostring(outcome.ok), tostring(outcome.stage or 'ready'),
            tostring(outcome.existing == true)
        ))
    end

    print(('[WeaponNativeProbe] dual-entitlement allowed=%s'):format(tostring(GetDualWieldAllowed(ped))))
end, false)

RegisterCommand('WeaponNativeProbeDualStatus', function()
    local ped = PlayerPedId()
    local primaryClipOk, primaryLoaded = GetAmmoInClip(ped, weaponHash)
    local offhandClipOk, offhandLoaded = GetAmmoInClip(ped, offhandWeaponHash)
    local handOk, handWeapon = CurrentWeaponAt(ped, false, 0, true)
    local primaryOk, primaryWeapon = CurrentWeaponAt(ped, true, primaryAttachPoint, true)
    local offhandOk, offhandWeapon = CurrentWeaponAt(ped, true, offhandAttachPoint, true)
    local primaryEntity = GetCurrentPedWeaponEntityIndex(ped, primaryAttachPoint)
    local offhandEntity = GetCurrentPedWeaponEntityIndex(ped, offhandAttachPoint)
    local slot0Ok, slot0Weapon = CurrentWeaponAt(ped, true, 0, true)
    local slot1Ok, slot1Weapon = CurrentWeaponAt(ped, true, 1, true)
    local slot0Entity = GetCurrentPedWeaponEntityIndex(ped, 0)
    local slot1Entity = GetCurrentPedWeaponEntityIndex(ped, 1)
    local guidState = {}
    for _, copy in ipairs(dualWeaponCopies and dualWeaponCopies.records or {}) do
        local guidClipOk, guidLoaded = FeatherGuidWeapons.ReadClip(ped, copy)
        guidState[#guidState + 1] = ('slot%d=%d/%d clipOk=%s'):format(
            copy.slot, guidLoaded, FeatherGuidWeapons.ReadTotal(ped, copy), tostring(guidClipOk))
    end

    print(('[WeaponNativeProbe] dual-status primary=%s offhand=%s selected=%s total=%d '
        .. 'primaryLoaded=%d primaryClipOk=%s primaryWeaponTotal=%d '
        .. 'offhandLoaded=%d offhandClipOk=%s offhandWeaponTotal=%d '
        .. 'hand=%s/%s slot0=%s/%s entity=%s slot1=%s/%s entity=%s '
        .. 'attach%d=%s/%s entity=%s attach%d=%s/%s entity=%s copies=%d guidAmmo=[%s]'):format(
        weaponName, offhandWeaponName, tostring(CurrentWeapon(ped)),
        math.max(0, math.floor(tonumber(GetPedAmmoByType(ped, ammoHash)) or 0)),
        math.max(0, math.floor(tonumber(primaryLoaded) or 0)), tostring(NativeTrue(primaryClipOk)),
        math.max(0, math.floor(tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)),
        math.max(0, math.floor(tonumber(offhandLoaded) or 0)), tostring(NativeTrue(offhandClipOk)),
        math.max(0, math.floor(tonumber(GetAmmoInPedWeapon(ped, offhandWeaponHash)) or 0)),
        tostring(handOk), tostring(handWeapon), tostring(slot0Ok), tostring(slot0Weapon),
        tostring(slot0Entity), tostring(slot1Ok), tostring(slot1Weapon), tostring(slot1Entity),
        primaryAttachPoint, tostring(primaryOk),
        tostring(primaryWeapon), tostring(primaryEntity), offhandAttachPoint, tostring(offhandOk),
        tostring(offhandWeapon), tostring(offhandEntity),
        dualWeaponCopies and #(dualWeaponCopies.records or {}) or 0,
        table.concat(guidState, ', ')
    ))
end, false)

RegisterCommand('WeaponNativeProbeStatus', function(_, args)
    if specialProbeRead then
        specialProbeRead('status')
        return
    end
    PrintSnapshot(args and args[1] or 'status', Snapshot())
end, false)

RegisterCommand('WeaponNativeProbeWatch', function()
    watching = not watching
    previous = Snapshot()
    print(('[WeaponNativeProbe] watch=%s intervalMs=%d'):format(tostring(watching), interval))
    if watching then PrintSnapshot('watch-start', previous) end
end, false)

RegisterCommand('WeaponNativeProbeDualWatch', function()
    dualWatching = not dualWatching
    previousDual = dualWatching and DualGuidSnapshot() or nil
    print(('[WeaponNativeProbe] dual-watch=%s intervalMs=%d'):format(tostring(dualWatching), interval))
    if previousDual then PrintDualGuidSnapshot('start', previousDual) end
end, false)

RegisterCommand('WeaponNativeProbeMark', function(_, args)
    markCounter = markCounter + 1
    local name = args and args[1] or ('mark-' .. tostring(markCounter))
    marks[name] = Snapshot()
    PrintSnapshot('mark:' .. name, marks[name])
end, false)

RegisterCommand('WeaponNativeProbeCompare', function(_, args)
    local leftName, rightName = args and args[1], args and args[2]
    local left, right = leftName and marks[leftName], rightName and marks[rightName]
    if not left or not right then
        print('[WeaponNativeProbe] compare requires two existing mark names')
        return
    end

    print(('[WeaponNativeProbe] compare %s->%s pedChanged=%s selected=%s->%s dead=%s->%s '
        .. 'loaded=%+d weaponTotal=%+d ammoTypeTotal=%+d'):format(
        leftName, rightName, tostring(left.ped ~= right.ped), tostring(left.selected),
        tostring(right.selected), tostring(left.dead), tostring(right.dead),
        right.loaded - left.loaded, right.weaponTotal - left.weaponTotal,
        right.ammoTypeTotal - left.ammoTypeTotal
    ))
end, false)

RegisterCommand('WeaponNativeProbeClear', function()
    if RefuseInventoryWeapon() then
        RemoveProbeEntitlements()
        RestoreDualWieldState()
        return
    end

    local ped = PlayerPedId()
    ClearNativeTestState(ped)
    RemoveProbeEntitlements()
    RestoreDualWieldState()
    offhandWeaponName = configuredOffhandWeaponName
    offhandWeaponHash = joaat(offhandWeaponName)
    active, watching, dualWatching, previous, previousDual, marks, markCounter, logicalItem =
        false, false, false, nil, nil, {}, 0, 'unlabeled'
    print('[WeaponNativeProbe] cleared')
end, false)

CreateThread(function()
    while true do
        if active and watching then
            local ok, current = pcall(Snapshot)
            if not ok then
                watching = false
                print(('[WeaponNativeProbe] observer stopped after snapshot error: %s'):format(tostring(current)))
            else
                if not Same(previous, current) then PrintSnapshot('transition', current) end
                previous = current
            end
            Wait(interval)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        if active and dualWatching then
            local ok, current = pcall(DualGuidSnapshot)
            if not ok then
                dualWatching = false
                print(('[WeaponNativeProbe] dual observer stopped after snapshot error: %s'):format(
                    tostring(current)))
            else
                if not previousDual or previousDual.signature ~= current.signature then
                    PrintDualGuidSnapshot('transition', current)
                end
                previousDual = current
            end
            Wait(interval)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local hasInventoryWeapon = InventoryWeaponActive()
    if active and not hasInventoryWeapon then
        ClearNativeTestState(PlayerPedId())
    end

    RemoveProbeEntitlements()
    RestoreDualWieldState()
end)

print(('[WeaponNativeProbe] ready weapon=%s offhand=%s ammo=%s; isolated from production weapon leases'):format(
    weaponName, offhandWeaponName, ammoName))
