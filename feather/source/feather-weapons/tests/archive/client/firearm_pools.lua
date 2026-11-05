-- Opt-in firearm pool observer; loaded legacy firearms cannot share this mode.
FeatherFirearmPools = {}
local snapshot
local hidden = {}
local rematerialize = {}
local function Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

function FeatherFirearmPools.Reset()
    snapshot = nil
    hidden = {}
    rematerialize = {}
end

local function SelectLonggunHashAmmo(ped, state, catalog)
    local weaponHash, ammoHash = joaat(state.nativeWeaponName), joaat(state.nativeAmmoName)
    for _, id in ipairs(catalog.weapons[state.definitionId].ammunitionTypes) do
        local candidate = joaat(catalog.ammunition[id].nativeAmmoName)
        if candidate ~= ammoHash then
            Citizen.InvokeNative(0xF0D728EEA3C99775, ped, weaponHash, candidate)
        end
    end
    Citizen.InvokeNative(0x23FB9FACA28779C1, ped, weaponHash, ammoHash)
    Citizen.InvokeNative(0xCC9C4393523833E2, ped, weaponHash, ammoHash)
    -- Hash getter reports default Regular even for live GUID-selected Express;
    -- it is diagnostic only, not a selection/restore readiness contract.
end

-- Per-weapon availability must be reapplied after native ammo selection.
-- Never remove the other item's escrow from the shared ped total.
function FeatherFirearmPools.UpdateLonggunWindow(ped, selectedWeapon, catalog)
    if not snapshot then return false end
    local blockedTypes = {}
    for slot, state in pairs(snapshot.states) do
        local definition = catalog.weapons[state.definitionId]
        if definition.slot == 'longgun' and selectedWeapon == joaat(state.nativeWeaponName)
            and (snapshot.owners[slot][state.ammunitionType] or 0) == 0 then
            -- Otherwise native auto-selection can borrow an alternate funded
            -- type when the empty gun's selected pool is hidden.
            for _, id in ipairs(definition.ammunitionTypes) do
                if (snapshot.owners[slot][id] or 0) == 0 then blockedTypes[id] = true end
            end
        end
    end
    for id, approved in pairs(snapshot.totals) do
        local owned = 0
        for _, pools in pairs(snapshot.owners) do owned = owned + (pools[id] or 0) end
        if approved ~= owned then return false end
        local hash = joaat(catalog.ammunition[id].nativeAmmoName)
        local native = GetPedAmmoByType(ped, hash)
        local escrow = hidden[id] or 0
        -- A shot or mutation must be checkpointed before changing exposure.
        if type(native) ~= 'number' or native + escrow ~= approved then return false end
    end
    for id, approved in pairs(snapshot.totals) do
        local hash = joaat(catalog.ammunition[id].nativeAmmoName)
        local escrow = hidden[id] or 0
        if blockedTypes[id] and escrow == 0 and approved > 0 then
            Citizen.InvokeNative(0xB6CFEC32E3742779, ped, hash, approved, 0xA07362E6)
            local remaining = GetPedAmmoByType(ped, hash)
            hidden[id] = approved - remaining
            for _, state in pairs(snapshot.states) do
                if state.ammunitionType == id and state.loaded > 0 then
                    rematerialize[state.nativeWeaponName] = true
                end
            end
        elseif not blockedTypes[id] and escrow > 0 then
            -- Return only the tracked escrow, never an authoritative refill.
            local before = GetPedAmmoByType(ped, hash)
            SetPedAmmoByType(ped, hash, before + escrow)
            local returned = GetPedAmmoByType(ped, hash)
            if returned > approved then
                Citizen.InvokeNative(0xB6CFEC32E3742779, ped, hash,
                    returned - approved, 0xA07362E6)
            end
            hidden[id] = math.max(0, approved - GetPedAmmoByType(ped, hash))
        end
    end
    for _, state in pairs(snapshot.states) do
        local id = state.ammunitionType
        if rematerialize[state.nativeWeaponName] and selectedWeapon == joaat(state.nativeWeaponName)
            and (hidden[id] or 0) == 0 then
            -- Removing a native type can auto-select an alternate owned type.
            -- Restore the accepted GUID selection before writing its clip;
            -- Capture must not turn that window artifact into a user change.
            if not FeatherGuidWeapons.SelectExistingAmmo(ped, state.nativeWeaponName, state.nativeAmmoName) then
                return false
            end
            local record = FeatherGuidWeapons.ResolveExisting(state.nativeWeaponName)
            local selectedHash = record and Citizen.InvokeNative(0xAF9D167A5656D6A6, ped, record.guid)
            local expectedHash = joaat(state.nativeAmmoName)
            if type(selectedHash) ~= 'number'
                or selectedHash % 4294967296 ~= expectedHash % 4294967296 then return false end
            SelectLonggunHashAmmo(ped, state, catalog)
            -- A clip write may ADD its loaded rounds to the ped total. Never
            -- retry it every frame or accept that increase as a new baseline.
            rematerialize[state.nativeWeaponName] = nil
            SetAmmoInClip(ped, selectedWeapon, state.loaded)
            local hash = joaat(catalog.ammunition[id].nativeAmmoName)
            local after = GetPedAmmoByType(ped, hash)
            if after > snapshot.totals[id] then
                Citizen.InvokeNative(0xB6CFEC32E3742779, ped, hash,
                    after - snapshot.totals[id], 0xA07362E6)
            end
            local ok, actual = GetAmmoInClip(ped, selectedWeapon)
            if (ok == true or ok == 1) and actual == state.loaded
                and GetPedAmmoByType(ped, joaat(catalog.ammunition[id].nativeAmmoName)) == snapshot.totals[id] then
                rematerialize[state.nativeWeaponName] = nil
            else
                return false
            end
        end
    end
    return true
end

function FeatherFirearmPools.Restore(ped, slots, catalog)
    hidden = {}
    rematerialize = {}
    local owners, states, totals = {}, {}, {}
    -- Validate the entire mode before touching any native pool or selection.
    for _, state in pairs(slots) do
        local definition = catalog.weapons[state.definitionId]
        if definition and (definition.slot == 'sidearm' or definition.slot == 'longgun')
            and not state.ammoPools and (tonumber(state.ammo) or 0) > 0 then
            snapshot = nil
            return false, 'mixed_firearm_pool_modes'
        end
    end
    for slot, state in pairs(slots) do
        local definition = catalog.weapons[state.definitionId]
        if state.ammoPools and definition and definition.family ~= 'throwing_knife' then
            states[slot], owners[slot] = Copy(state), {}
            for _, id in ipairs(definition.ammunitionTypes) do
                local amount = state.ammoPools[id] or 0
                owners[slot][id] = amount
                local hash = joaat(catalog.ammunition[id].nativeAmmoName)
                totals[id] = (totals[id] or 0) + amount
                Citizen.InvokeNative(amount > 0 and 0x23FB9FACA28779C1 or 0xF0D728EEA3C99775,
                    ped, joaat(state.nativeWeaponName), hash)
            end
            if not FeatherGuidWeapons.SelectExistingAmmo(ped, state.nativeWeaponName, state.nativeAmmoName) then
                snapshot = nil
                return false, 'native_type_selection_failed'
            end
            if definition.slot == 'longgun' then SelectLonggunHashAmmo(ped, state, catalog) end
            SetAmmoInClip(ped, joaat(state.nativeWeaponName), state.loaded)
        end
    end
    FeatherNativeWeaponCoordinator.RestorePoolTotals(ped, slots, catalog)
    local observed = {}
    for id in pairs(totals) do
        observed[id] = GetPedAmmoByType(ped, joaat(catalog.ammunition[id].nativeAmmoName))
        if observed[id] ~= totals[id] then
            print(('[feather-weapons] firearm pool restore mismatch type=%s approved=%s native=%s')
                :format(tostring(id), tostring(totals[id]), tostring(observed[id])))
            snapshot = nil
            return false, 'native_pool_restore_mismatch'
        end
    end
    snapshot = { states = states, owners = owners, totals = observed }
    return true
end

function FeatherFirearmPools.Capture(ped, catalog)
    if not snapshot then return nil, 'pools_not_ready' end
    local observed, shots, states = {}, {}, Copy(snapshot.states)
    for id in pairs(snapshot.totals) do
        observed[id] = GetPedAmmoByType(ped, joaat(catalog.ammunition[id].nativeAmmoName)) + (hidden[id] or 0)
        if observed[id] > snapshot.totals[id] then return nil, 'native_pool_increased' end
    end
    local unchangedPools = true
    for id, amount in pairs(snapshot.totals) do
        if observed[id] ~= amount then unchangedPools = false break end
    end
    local currentOk, currentWeapon = GetCurrentPedWeapon(ped, true, 0, false)
    local unarmed = (currentOk == true or currentOk == 1)
        and currentWeapon == joaat('WEAPON_UNARMED')
    for slot, state in pairs(states) do
        local definition = catalog.weapons[state.definitionId]
        local record = FeatherGuidWeapons.ResolveExisting(state.nativeWeaponName)
        local selectedHash = record and Citizen.InvokeNative(0xAF9D167A5656D6A6, ped, record.guid)
        if not record then return nil, 'weapon_guid_not_ready' end
        local selected
        for _, id in ipairs(definition.ammunitionTypes) do
            if type(selectedHash) == 'number' and selectedHash % 4294967296
                == joaat(catalog.ammunition[id].nativeAmmoName) % 4294967296 then selected = id end
        end
        if not selected then return nil, 'unknown_native_type' end
        local ok, loaded = GetAmmoInClip(ped, joaat(state.nativeWeaponName))
        if rematerialize[state.nativeWeaponName] then
            if not unchangedPools then return nil, 'window_selection_not_ready' end
            -- Both the missing clip and an alternate type are temporary native
            -- window effects. Preserve the accepted selection until restored.
            selected, loaded, ok = state.ammunitionType, state.loaded, true
        end
        local empty = true
        for _, amount in pairs(snapshot.owners[slot]) do
            if amount > 0 then empty = false break end
        end
        if ok ~= true and ok ~= 1 then
            if empty then loaded = 0 else return nil, 'clip_not_ready' end
        end
        if type(loaded) ~= 'number' or loaded < 0 or loaded % 1 ~= 0
            or loaded > definition.capacity then return nil, 'invalid_native_clip' end
        -- Removing a depleted counterpart can collapse a holstered survivor's
        -- hash clip surface to zero. No pool decrease means no shot to charge.
        -- Keep its approved loaded state until the native clip rematerializes.
        if loaded == 0 and state.loaded > 0 and selected == state.ammunitionType
            and ((unchangedPools and unarmed)
                or (definition.slot == 'longgun' and (currentOk == true or currentOk == 1)
                    and currentWeapon ~= joaat(state.nativeWeaponName))) then
            loaded = state.loaded
        end
        if selected == state.ammunitionType then
            local decrease = math.max(0, state.loaded - loaded)
            shots[slot] = { [selected] = decrease }
        end
        state.ammunitionType, state.loaded = selected, loaded
        state.nativeAmmoName = catalog.ammunition[selected].nativeAmmoName
    end
    local owners, failure = WeaponAmmunitionPools.Allocate(
        snapshot.totals, observed, snapshot.owners, shots)
    if not owners then
        local details = {}
        for id, before in pairs(snapshot.totals) do
            local attributed = 0
            for _, report in pairs(shots) do attributed = attributed + (report[id] or 0) end
            if type(observed[id]) ~= 'number' or math.max(0, before - observed[id]) ~= attributed then
                details[#details + 1] = ('%s before=%s native=%s clipDecrease=%s'):format(
                    id, tostring(before), tostring(observed[id]), tostring(attributed))
            end
        end
        for slot, state in pairs(states) do
            local hashType = Citizen.InvokeNative(0x7FEAD38B326B9F74, ped, joaat(state.nativeWeaponName))
            details[#details + 1] = ('slot=%s selected=%s previous=%s loaded=%s previousLoaded=%s hashType=%s'):format(
                slot, tostring(state.ammunitionType), tostring(snapshot.states[slot].ammunitionType),
                tostring(state.loaded), tostring(snapshot.states[slot].loaded), tostring(hashType))
        end
        return nil, failure, table.concat(details, '; ')
    end
    local reports = {}
    for slot, state in pairs(states) do
        if state.loaded > (owners[slot][state.ammunitionType] or 0) then
            -- A native reload can borrow from another weapon's shared reserve.
            -- Correct the clip only when every pool is unchanged and no shot
            -- is pending; never rebuild totals to conceal consumption.
            for id, before in pairs(snapshot.totals) do
                if observed[id] ~= before then return nil, 'clip_crossed_item_ownership' end
            end
            local bounded = owners[slot][state.ammunitionType] or 0
            SetAmmoInClip(ped, joaat(state.nativeWeaponName), bounded)
            local ok, actual = GetAmmoInClip(ped, joaat(state.nativeWeaponName))
            if not (empty and ok ~= true and ok ~= 1)
                and ((ok ~= true and ok ~= 1) or actual ~= bounded) then
                return nil, 'clip_ownership_correction_failed'
            end
            for id, amount in pairs(observed) do
                if GetPedAmmoByType(ped, joaat(catalog.ammunition[id].nativeAmmoName)) + (hidden[id] or 0) ~= amount then
                    return nil, 'clip_correction_changed_pool'
                end
            end
            state.loaded = bounded
        end
        reports[slot] = { itemInstanceId = state.itemInstanceId, generation = state.generation,
            ammunitionType = state.ammunitionType, loaded = state.loaded, pools = owners[slot] }
    end
    -- Caller owns commit timing; a failed RPC must never advance the baseline.
    return { reports = reports, next = { states = states, owners = owners, totals = observed } }
end

function FeatherFirearmPools.Accept(capture)
    snapshot = capture.next
end
