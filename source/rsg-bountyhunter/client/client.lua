local RSGCore = exports['rsg-core']:GetCoreObject()

local clerks = {}        -- [officeId] = ped
local officeBlips = {}
local contract = nil     -- data sent by the server on accept
local target, gang = nil, {}
local areaBlip, targetBlip = nil, nil
local downNotified = false
local spawnFails = 0
local props = {}         -- hideout dressing
local alerted = false    -- outlaws idle until this turns true
local ambushDone = false
local currentOffice = nil
local uiOpen = false     -- true while the board has NUI focus
local opening = false    -- true while the board request is in flight

local MAX_SPAWN_FAILS = 3 -- outlaw spawn attempts before the hunter is told to abandon

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
    RSGCore.Functions.Notify({ title = locale('title'), description = desc, type = ntype, duration = duration or 7000 })
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
    for _, o in ipairs(props) do
        if DoesEntityExist(o) then SetEntityAsMissionEntity(o, true, true); DeleteEntity(o) end
    end
    props, alerted, ambushDone = {}, false, false
    target, gang = nil, {}
    contract = nil
    downNotified = false
    spawnFails = 0
end

---------------------------------
-- outlaw spawning
---------------------------------
-- c is the contract being spawned for: the contract can end while models load, so it is never read from the upvalue here
local function spawnOutlaw(c, model, x, y, z, behaviour, idle)
    local hash = loadModel(model)
    if not hash then return nil end
    local ped = CreatePed(hash, x, y, z, math.random(0, 359) + 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end

    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, joaat('REL_CRIMINALS'))
    SetPedAccuracy(ped, c.accuracy)
    -- GIVE_WEAPON_TO_PED 0x5E3BDDBCB83F3D84 (natives/db/WEAPON.md)
    GiveWeaponToPed(ped, joaat(c.weapons[math.random(#c.weapons)]), 100, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
    SetPedCombatAttributes(ped, 5, true)   -- ALWAYS_FIGHT
    SetPedCombatAttributes(ped, 46, true)  -- CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED

    if idle and c.scenarios and #c.scenarios > 0 then
        TaskStartScenarioInPlace(ped, joaat(c.scenarios[math.random(#c.scenarios)]), -1, true, false, false, false)
    elseif behaviour == 'flee' then
        TaskSmartFleePed(ped, PlayerPedId(), 400.0, -1, 0, 3.0, 0)
    else
        TaskCombatPed(ped, PlayerPedId(), 0, 16)
    end
    SetPedKeepTask(ped, true)
    return ped
end

-- wake the camp: the target flees or fights as its contract says, the gang opens fire
local function alertCamp(c)
    if alerted then return end
    alerted = true
    local me = PlayerPedId()
    if target and DoesEntityExist(target) then
        ClearPedTasks(target)
        if c.behaviour == 'flee' then TaskSmartFleePed(target, me, 400.0, -1, 0, 3.0, 0) else TaskCombatPed(target, me, 0, 16) end
        SetPedKeepTask(target, true)
    end
    for _, p in ipairs(gang) do
        if DoesEntityExist(p) then
            ClearPedTasks(p)
            TaskCombatPed(p, me, 0, 16)
            SetPedKeepTask(p, true)
        end
    end
end

local function spawnProps(c, h, z)
    for _, pr in ipairs(c.props or {}) do
        if contract ~= c then return end
        local hash = loadModel(pr.model)
        if hash then
            local px, py = h.x + pr.x, h.y + pr.y
            local obj = CreateObject(hash, px, py, groundZ(px, py, z) + pr.z, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            if obj and obj ~= 0 then
                SetEntityHeading(obj, pr.heading + 0.0)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                props[#props + 1] = obj
            end
        end
    end
end

-- riders waiting on the road back (the server decided this contract has an ambush)
local function spawnAmbush(c, pcoords)
    local cfg = Config.Ambush
    local n = math.random(cfg.Count[1], cfg.Count[2])
    for _ = 1, n do
        if contract ~= c then return end
        local ang = math.random() * 2.0 * math.pi
        local dist = cfg.SpawnRadius[1] + math.random() * (cfg.SpawnRadius[2] - cfg.SpawnRadius[1])
        local ax, ay = pcoords.x + math.cos(ang) * dist, pcoords.y + math.sin(ang) * dist
        local ped = spawnOutlaw(c, c.models[math.random(#c.models)], ax, ay, groundZ(ax, ay, pcoords.z), 'fight')
        if ped then
            if contract ~= c then deletePed(ped) return end
            gang[#gang + 1] = ped
        end
    end
    notify(locale('ambush_warning'), 'warning', 8000)
end

local function spawnOutlaws()
    local c = contract
    if not c or target then return end
    local h = c.hideout
    local z = groundZ(h.x, h.y, h.z)
    if contract ~= c or target then return end -- the contract may have ended while collision loaded

    spawnProps(c, h, z)
    local idle = c.idle == true
    local ped = spawnOutlaw(c, c.model, h.x, h.y, z, c.behaviour, idle)
    if contract ~= c then deletePed(ped) return end
    if not ped then
        spawnFails = spawnFails + 1
        if spawnFails >= MAX_SPAWN_FAILS then notify(locale('spawn_failed'), 'error', 10000) end
        return
    end
    target = ped

    local timeout = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(ped) and GetGameTimer() < timeout do
        NetworkRegisterEntityAsNetworked(ped)
        Wait(10)
    end
    TriggerServerEvent('rsg-bountyhunter:server:registerTarget', NetworkGetNetworkIdFromEntity(ped))

    for _ = 1, c.gang do
        if contract ~= c then return end
        local gx, gy = h.x + math.random(-8, 8), h.y + math.random(-8, 8)
        local member = spawnOutlaw(c, c.models[math.random(#c.models)], gx, gy, groundZ(gx, gy, z), 'fight', idle)
        if member then
            if contract ~= c then deletePed(member) return end
            gang[#gang + 1] = member
        end
    end

    if contract ~= c then return end
    -- let the server know which networked peds are the gang so it can see how many were left dead
    local ids = {}
    for _, p in ipairs(gang) do
        local t2 = GetGameTimer() + 1500
        while not NetworkGetEntityIsNetworked(p) and GetGameTimer() < t2 do NetworkRegisterEntityAsNetworked(p); Wait(10) end
        if NetworkGetEntityIsNetworked(p) then ids[#ids + 1] = NetworkGetNetworkIdFromEntity(p) end
    end
    if #ids > 0 then TriggerServerEvent('rsg-bountyhunter:server:registerGang', ids) end
    if contract == c then notify(locale('spotted', c.name), 'warning') end
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

-- contract on a real player (reputation / gang bounty): no hideout, the server moves the search area
RegisterNetEvent('rsg-bountyhunter:client:startPlayerContract', function(data)
    clearContract()
    contract = { name = data.name, player = true }
end)

RegisterNetEvent('rsg-bountyhunter:client:trackArea', function(area)
    if not contract or not contract.player or type(area) ~= 'table' then return end
    removeBlip(areaBlip)
    -- BLIP_ADD_FOR_RADIUS + BLIP_STYLE_AREA (useful_info_from_rpfs/blip_styles/README.md)
    areaBlip = BlipAddForRadius(joaat('BLIP_STYLE_AREA'), area.x, area.y, area.z, area.radius)
    setBlipName(areaBlip, locale('search_area', contract.name))
end)

-- the server asks the target's client whether they are hogtied (a bound target can be turned in alive)
RSGCore.Functions.CreateClientCallback('rsg-bountyhunter:client:isRestrained', function(cb)
    local hogtied = Citizen.InvokeNative(IS_PED_HOGTIED, PlayerPedId())
    cb(hogtied == true or hogtied == 1)
end)

RegisterNetEvent('rsg-bountyhunter:client:endContract', function(reason)
    clearContract(reason == 'completed')
end)

---------------------------------
-- contract loop (distance-gated)
---------------------------------
CreateThread(function()
    while true do
        local sleep = 2000
        if contract and not contract.player then
            local pcoords = GetEntityCoords(PlayerPedId())
            if not target then
                if spawnFails < MAX_SPAWN_FAILS and #(pcoords - contract.hideout) <= Config.SpawnDistance then
                    local ok, err = pcall(spawnOutlaws)
                    if not ok then
                        spawnFails = spawnFails + 1
                        print(('^1[rsg-bountyhunter] outlaw spawn error: %s^7'):format(tostring(err)))
                    end
                end
            elseif not DoesEntityExist(target) then
                removeBlip(targetBlip); targetBlip = nil
            else
                sleep = 1000
                if contract.idle and not alerted then
                    sleep = 500
                    local trigger = #(pcoords - GetEntityCoords(target)) <= (contract.alertDistance or 45.0)
                    if not trigger then
                        for _, p in ipairs(gang) do
                            if DoesEntityExist(p) and (#(pcoords - GetEntityCoords(p)) <= (contract.alertDistance or 45.0) or IsEntityDead(p)) then trigger = true break end
                        end
                    end
                    if trigger or IsEntityDead(target) or GetEntityHealth(target) < GetEntityMaxHealth(target) then alertCamp(contract) end
                end
                if contract.ambush and not ambushDone and (IsEntityDead(target) or Citizen.InvokeNative(IS_PED_HOGTIED, target)) then
                    local safe = #(pcoords - contract.hideout) >= Config.Ambush.MinDistance
                    if safe then
                        for _, o in ipairs(Config.Offices) do
                            if #(pcoords - vector3(o.coords.x, o.coords.y, o.coords.z)) < Config.Ambush.SafeOfficeRadius then safe = false break end
                        end
                    end
                    if safe then
                        ambushDone = true
                        local ok, err = pcall(spawnAmbush, contract, pcoords)
                        if not ok then print(('^1[rsg-bountyhunter] ambush error: %s^7'):format(tostring(err))) end
                    end
                end
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
-- NUI (push-to-talk stays usable while the board is open)
---------------------------------
local uiStrings = {
    'ui_wanted', 'ui_dead_or_alive', 'ui_brought_in', 'ui_alive', 'ui_dead', 'ui_earned', 'ui_posters',
    'ui_top_hunters', 'ui_active_contract', 'ui_abandon', 'ui_confirm_abandon', 'ui_take_contract', 'ui_no_posters',
    'ui_no_hunters', 'ui_locked', 'ui_bounties_count', 'ui_reward_alive', 'ui_reward_dead', 'ui_close',
    'ui_alive_only', 'ui_dead_only', 'ui_requires_level', 'ui_level', 'ui_streak',
}

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- KeepInput passes every key to the game, so block all controls except push-to-talk
local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            EnableControlAction(0, list[i], true)
            EnableControlAction(1, list[i], true)
            EnableControlAction(2, list[i], true)
        end
    end
end

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function openBoard(officeId)
    if uiOpen or opening then return end
    opening = true
    local data = RSGCore.Functions.AwaitCallback('rsg-bountyhunter:server:getBoard', 5000, officeId)
    opening = false
    if data and data.silent then return end -- throttled double click
    if not data or data.error then
        notify(locale(data and data.error or 'board_error'), 'error')
        return
    end
    local strings = {}
    for _, k in ipairs(uiStrings) do strings[k] = locale(k) end
    data.strings = strings

    currentOffice = officeId
    uiOpen = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', data = data })
end

-- runs only while the board is open: control whitelist for push-to-talk, and close the board if the player dies
CreateThread(function()
    while true do
        if not uiOpen then
            Wait(250)
        elseif IsEntityDead(PlayerPedId()) then
            closeUI()
        elseif Config.AllowPushToTalkWhileOpen then
            runPttWhitelist()
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNUICallback('close', function(_, cb) closeUI(); cb({}) end)

RegisterNUICallback('accept', function(body, cb)
    local id = tonumber(body and body.id)
    if not id then return cb({ ok = false }) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-bountyhunter:server:accept', 5000, currentOffice, id)
    cb({ ok = ok == true })
    if ok then closeUI() end
end)

RegisterNUICallback('abandon', function(_, cb)
    local ok = RSGCore.Functions.AwaitCallback('rsg-bountyhunter:server:abandon', 5000)
    cb({ ok = ok == true })
    if ok then closeUI() end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    closeUI()
    clearContract()
end)

---------------------------------
-- clerks, blips, rsg-target
---------------------------------
local function spawnClerk(office)
    local hash = loadModel(Config.ClerkModel)
    if not hash then return end
    local c = office.coords
    local ped = CreatePed(hash, c.x, c.y, c.z, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    PlaceEntityOnGroundProperly(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    clerks[office.id] = ped

    exports['rsg-target']:addLocalEntity(ped, {
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
            onSelect = function() RSGCore.Functions.TriggerCallback('rsg-bountyhunter:server:turnIn', function() end, office.id) end,
        },
    })
end

local function removeClerk(id)
    exports['rsg-target']:removeLocalEntity(clerks[id])
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
            local ped = clerks[office.id]
            if ped and not DoesEntityExist(ped) then -- deleted by something else: respawn it
                removeClerk(office.id)
                ped = nil
            end
            if near and not ped then
                spawnClerk(office)
            elseif not near and ped then
                removeClerk(office.id)
            end
        end
        Wait(2500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then
        uiOpen = false
        applyNuiFocus(false)
    end
    for id in pairs(clerks) do removeClerk(id) end
    for _, b in ipairs(officeBlips) do removeBlip(b) end
    for _, p in ipairs(gang) do deletePed(p) end
    clearContract()
end)
