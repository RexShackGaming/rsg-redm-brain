lib.locale()

local clerks = {}        -- [officeId] = ped
local officeBlips = {}
local contract = nil     -- data sent by the server on accept
local target, gang = nil, {}
local areaBlip, targetBlip = nil, nil
local downNotified = false
local currentOffice = nil
local uiOpen = false

-- natives without a Lua name in RedM (hashes from natives/db)
local SET_BLIP_NAME              = 0x9CB1A1623062F402 -- _SET_BLIP_NAME (MAP.md)
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE -- _SET_RANDOM_OUTFIT_VARIATION (PED.md)
local IS_PED_HOGTIED             = 0x3AA24CCC0D451379 -- IS_PED_HOGTIED (PED.md)

---------------------------------
-- helpers
---------------------------------
local function loadModel(model)
    local hash = joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function setBlipName(blip, text)
    Citizen.InvokeNative(SET_BLIP_NAME, blip, CreateVarString(10, 'LITERAL_STRING', text))
end

local function removeBlip(b)
    if b and DoesBlipExist(b) then RemoveBlip(b) end
end

local function deletePed(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
    end
end

local function groundZ(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    for _ = 1, 20 do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + 100.0, false)
        if found then return gz end
        Wait(50)
    end
    return z
end

local function notify(desc, ntype, duration)
    lib.notify({ title = locale('title'), description = desc, type = ntype, duration = duration or 7000 })
end

---------------------------------
-- contract cleanup
---------------------------------
-- keepTarget: on completion the server has already deleted the target ped
local function clearContract(keepTarget)
    removeBlip(areaBlip); areaBlip = nil
    removeBlip(targetBlip); targetBlip = nil
    for _, p in ipairs(gang) do
        if DoesEntityExist(p) then SetEntityAsNoLongerNeeded(p) end
    end
    if not keepTarget then deletePed(target) end
    target, gang = nil, {}
    contract = nil
    downNotified = false
end

---------------------------------
-- outlaw spawning
---------------------------------
local function spawnOutlaw(model, x, y, z, behaviour)
    local hash = loadModel(model)
    if not hash then return nil end
    local ped = CreatePed(hash, x, y, z, math.random(0, 359) + 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return nil end

    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, joaat('REL_CRIMINALS'))
    SetPedAccuracy(ped, contract.accuracy)
    -- GIVE_WEAPON_TO_PED 0x5E3BDDBCB83F3D84 (natives/db/WEAPON.md)
    GiveWeaponToPed(ped, joaat(contract.weapons[math.random(#contract.weapons)]), 100, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
    SetPedCombatAttributes(ped, 5, true)   -- ALWAYS_FIGHT
    SetPedCombatAttributes(ped, 46, true)  -- CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED

    local player = PlayerPedId()
    if behaviour == 'flee' then
        TaskSmartFleePed(ped, player, 400.0, -1, 0, 3.0, 0)
    else
        TaskCombatPed(ped, player, 0, 16)
    end
    SetPedKeepTask(ped, true)
    return ped
end

local function spawnOutlaws()
    local h = contract.hideout
    local z = groundZ(h.x, h.y, h.z)
    if not contract then return end -- contract may have ended while collision loaded

    target = spawnOutlaw(contract.model, h.x, h.y, z, contract.behaviour)
    if not target then return end

    local timeout = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(target) and GetGameTimer() < timeout do
        NetworkRegisterEntityAsNetworked(target)
        Wait(10)
    end
    TriggerServerEvent('rsg-bountyhunter:server:registerTarget', NetworkGetNetworkIdFromEntity(target))

    for _ = 1, contract.gang do
        local gx, gy = h.x + math.random(-8, 8), h.y + math.random(-8, 8)
        local ped = spawnOutlaw(contract.models[math.random(#contract.models)], gx, gy, groundZ(gx, gy, z), 'fight')
        if ped then gang[#gang + 1] = ped end
    end

    notify(locale('spotted', contract.name), 'warning')
end

---------------------------------
-- server -> client
---------------------------------
RegisterNetEvent('rsg-bountyhunter:client:startContract', function(data)
    clearContract()
    contract = data
    contract.hideout = vector3(data.hideout.x, data.hideout.y, data.hideout.z)

    -- offset the area centre so the hideout isn't dead centre
    local r = math.floor(Config.SearchRadius * 0.5)
    local cx, cy = contract.hideout.x + math.random(-r, r), contract.hideout.y + math.random(-r, r)
    -- BLIP_ADD_FOR_RADIUS + BLIP_STYLE_AREA (useful_info_from_rpfs/blip_styles/README.md)
    areaBlip = BlipAddForRadius(joaat('BLIP_STYLE_AREA'), cx, cy, contract.hideout.z, Config.SearchRadius)
    setBlipName(areaBlip, locale('search_area', contract.name))
end)

RegisterNetEvent('rsg-bountyhunter:client:endContract', function(reason)
    clearContract(reason == 'completed')
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    clearContract()
end)

---------------------------------
-- contract loop (distance-gated)
---------------------------------
CreateThread(function()
    while true do
        local sleep = 2000
        if contract then
            local pcoords = GetEntityCoords(PlayerPedId())
            if not target then
                if #(pcoords - contract.hideout) <= Config.SpawnDistance then spawnOutlaws() end
            elseif DoesEntityExist(target) then
                sleep = 1000
                if not targetBlip and #(pcoords - GetEntityCoords(target)) <= Config.TargetBlipDistance then
                    removeBlip(areaBlip); areaBlip = nil
                    -- BLIP_STYLE_BOUNTY_TARGET (useful_info_from_rpfs/blip_styles/README.md)
                    targetBlip = BlipAddForEntity(joaat('BLIP_STYLE_BOUNTY_TARGET'), target)
                    setBlipName(targetBlip, locale('target_blip'))
                end
                if not downNotified and (IsEntityDead(target) or Citizen.InvokeNative(IS_PED_HOGTIED, target)) then
                    downNotified = true
                    notify(locale('target_down', contract.name), 'success', 8000)
                    if targetBlip then
                        -- BLIP_MODIFIER_BOUNTY_TARGET_INCAPACITATED (useful_info_from_rpfs/blip_modifiers/README.md)
                        BlipAddModifier(targetBlip, joaat('BLIP_MODIFIER_BOUNTY_TARGET_INCAPACITATED'))
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------
-- NUI
---------------------------------
local uiStrings = {
    'ui_wanted', 'ui_dead_or_alive', 'ui_brought_in', 'ui_alive', 'ui_dead', 'ui_earned', 'ui_posters',
    'ui_top_hunters', 'ui_active_contract', 'ui_abandon', 'ui_take_contract', 'ui_no_posters', 'ui_no_hunters',
    'ui_locked', 'ui_bounties_count', 'ui_reward_alive', 'ui_reward_dead', 'ui_close',
}

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openBoard(officeId)
    local data = lib.callback.await('rsg-bountyhunter:server:getBoard', false, officeId)
    if not data or data.error then
        notify(locale(data and data.error or 'board_error'), 'error')
        return
    end
    local strings = {}
    for _, k in ipairs(uiStrings) do strings[k] = locale(k) end
    data.strings = strings

    currentOffice = officeId
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

RegisterNUICallback('close', function(_, cb) closeUI(); cb({}) end)

RegisterNUICallback('accept', function(body, cb)
    local ok = lib.callback.await('rsg-bountyhunter:server:accept', false, currentOffice, body.id)
    cb({ ok = ok })
    if ok then closeUI() end
end)

RegisterNUICallback('abandon', function(_, cb)
    local ok = lib.callback.await('rsg-bountyhunter:server:abandon', false)
    cb({ ok = ok })
    if ok then closeUI() end
end)

---------------------------------
-- clerks, blips, ox_target
---------------------------------
local function spawnClerk(office)
    local hash = loadModel(Config.ClerkModel)
    if not hash then return end
    local c = office.coords
    local ped = CreatePed(hash, c.x, c.y, c.z, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    PlaceEntityOnGroundProperly(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    clerks[office.id] = ped

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'bh_board',
            label = locale('view_bounties'),
            icon = 'fa-solid fa-scroll',
            distance = Config.InteractDistance,
            onSelect = function() openBoard(office.id) end,
        },
        {
            name = 'bh_turnin',
            label = locale('turn_in'),
            icon = 'fa-solid fa-handcuffs',
            distance = Config.InteractDistance,
            canInteract = function() return contract ~= nil end,
            onSelect = function() lib.callback.await('rsg-bountyhunter:server:turnIn', false, office.id) end,
        },
    })
end

local function removeClerk(id)
    exports.ox_target:removeLocalEntity(clerks[id])
    deletePed(clerks[id])
    clerks[id] = nil
end

CreateThread(function()
    for _, office in ipairs(Config.Offices) do
        if office.blip then
            local c = office.coords
            local blip = BlipAddForCoords(1664425300, c.x, c.y, c.z)
            SetBlipSprite(blip, Config.OfficeBlipSprite, true)
            SetBlipScale(blip, 0.2)
            setBlipName(blip, locale('office_blip'))
            officeBlips[#officeBlips + 1] = blip
        end
    end

    while true do
        local pcoords = GetEntityCoords(PlayerPedId())
        for _, office in ipairs(Config.Offices) do
            local near = #(pcoords - office.coords.xyz) < Config.ClerkSpawnDistance
            if near and not clerks[office.id] then
                spawnClerk(office)
            elseif not near and clerks[office.id] then
                removeClerk(office.id)
            end
        end
        Wait(2500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    for id in pairs(clerks) do removeClerk(id) end
    for _, b in ipairs(officeBlips) do removeBlip(b) end
    for _, p in ipairs(gang) do deletePed(p) end
    clearContract()
end)
