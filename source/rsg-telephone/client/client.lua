local RSGCore = exports['rsg-core']:GetCoreObject()

local Phones       = {}   -- [id] = data
local Spawned      = {}   -- [id] = entity
local Ringing      = {}   -- [id] = true
local lastBell     = {}   -- [id] = last bell state sent to NUI
local CurrentPhone = nil  -- phone id the player is using
local InCall       = false -- ringing out or connected
local UIOpen       = false
local Placing      = false
local AdminOpen    = false
local ModelRetry   = {}   -- [model] = next request time; never blocks the streaming loop
local AllowedJobs  = {}   -- job names/types from every job the character holds
local WallCache    = {}   -- [phoneId] = { t, v } muffled result for the bell loop
local jobGeneration = 0   -- ignores job callbacks that return after a player unload
local phoneGeneration = 0 -- ignores phone loads that return after a player unload

local function notify(msg, nType)
    if not msg then return end
    RSGCore.Functions.Notify({ title = locale('title'), description = msg, type = nType or 'inform' })
end

----------------------------------------------------------------
-- NUI
----------------------------------------------------------------
-- NUI strings come from the locale file so the UI can be translated
local UIText = {
    title = locale('title'), ready = locale('ui_ready'), dialling = locale('ui_dialling'),
    ringing = locale('ui_ringing'), connected = locale('ui_connected'), ended = locale('call_ended'),
    call = locale('ui_call'), end_call = locale('ui_end_call'), search = locale('ui_search'),
    empty = locale('ui_empty'), clear = locale('ui_clear'), credit = locale('ui_credit'), per_min = locale('ui_per_min'), coin_return = locale('ui_return'), no_cash = locale('pay_no_money'), mins_left = locale('ui_mins_left'), hide = locale('ui_hide'), show = locale('ui_show'), hidden = locale('ui_hidden'), directory = locale('ui_directory'), close = locale('ui_close'),
}

-- The phone screen needs NUI focus, but full focus swallows the push-to-talk key and the
-- caller can't be heard. Keep game input alive and block everything except push-to-talk.
local INPUT_PUSH_TO_TALK = 0x4BC9DABB
local inputActive = false

local function startInputLoop()
    if inputActive then return end
    inputActive = true
    CreateThread(function()
        while UIOpen do
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            EnableControlAction(0, INPUT_PUSH_TO_TALK, true)
            EnableControlAction(1, INPUT_PUSH_TO_TALK, true)
            EnableControlAction(2, INPUT_PUSH_TO_TALK, true)
            Wait(0)
        end
        inputActive = false
    end)
end

local function isPayphonePhone(phone)
    return Config.Payphone.Enabled and Config.Payphone.CostPerMinute > 0 and phone and not phone.job
        and (not phone.owner or Config.Item.Payphone)
end

local function openUI(mode, info)
    UIOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    startInputLoop()

    local phone = Phones[CurrentPhone]
    -- payphone info is display only; the server decides what is charged
    local pay
    if isPayphonePhone(phone) then
        local playerData = RSGCore.Functions.GetPlayerData() or {}
        pay = {
            cost = Config.Payphone.CostPerMinute,
            max = Config.Payphone.MaxDeposit,
            coins = Config.Payphone.Coins,
            cash = ((playerData.money or {})[Config.Payphone.MoneyType] or 0),
        }
    end

    SendNUIMessage({
        action = 'open', mode = mode, info = info, ui = UIText, pay = pay,
        phone = phone and { label = phone.label, number = phone.number } or nil,
    })
end

local function closeUI()
    UIOpen = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local stopVoice
local function resetCall()
    if stopVoice then stopVoice() end
    InCall = false
    CurrentPhone = nil
    closeUI()
end

----------------------------------------------------------------
-- confirm dialog (replaces lib.alertDialog)
----------------------------------------------------------------
local pendingConfirm = nil

RegisterNUICallback('confirmResult', function(data, cb)
    cb('ok')
    local promise = pendingConfirm
    pendingConfirm = nil
    if promise then promise:resolve(data and data.ok == true) end
end)

local function confirmDialog(title, text, yesText, noText)
    if pendingConfirm then return false end
    local wasOpen = UIOpen
    pendingConfirm = promise.new()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'confirmShow', title = title or locale('title'), text = text or '',
        yes = yesText or locale('confirm_yes'), no = noText or locale('form_cancel'),
    })
    local ok = Citizen.Await(pendingConfirm)
    SendNUIMessage({ action = 'confirmHide' })
    if wasOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocus(false, false)
    end
    return ok == true
end

----------------------------------------------------------------
-- built-in voice line (Mumble natives)
----------------------------------------------------------------
local VoicePartner = nil
local voiceToken = 0

local function applyLine()
    if not VoicePartner then return end
    local target = Config.Voice.Target
    MumbleClearVoiceTarget(target)
    MumbleAddVoiceTargetPlayerByServerId(target, VoicePartner)
    if Config.Voice.KeepProximity then
        MumbleAddVoiceTargetChannel(target, MumbleGetVoiceChannelFromServerId(GetPlayerServerId(PlayerId())))
    end
    MumbleSetVoiceTarget(target)
    MumbleSetVolumeOverrideByServerId(VoicePartner, Config.Voice.Volume)
end

function stopVoice()
    if not VoicePartner then return end
    MumbleSetVolumeOverrideByServerId(VoicePartner, -1.0)
    MumbleClearVoiceTarget(Config.Voice.Target)
    MumbleSetVoiceTarget(Config.Voice.DefaultTarget)
    VoicePartner = nil
end

RegisterNetEvent('rsg-telephone:client:startVoice', function(partner)
    VoicePartner = tonumber(partner)
    if not VoicePartner then return end
    applyLine()
    voiceToken = voiceToken + 1
    local token = voiceToken -- only one refresh loop alive at a time
    CreateThread(function()
        while VoicePartner and token == voiceToken do
            Wait(Config.Voice.Refresh)
            applyLine()
        end
    end)
end)

----------------------------------------------------------------
-- server -> client call events
----------------------------------------------------------------
RegisterNetEvent('rsg-telephone:client:credit', function(left, cost)
    SendNUIMessage({ action = 'credit', left = left, cost = cost })
end)

RegisterNetEvent('rsg-telephone:client:callConnected', function(info)
    SendNUIMessage({ action = 'connected', info = info })
end)

RegisterNetEvent('rsg-telephone:client:callEnded', function(reason)
    stopVoice()
    if UIOpen then SendNUIMessage({ action = 'ended', reason = reason }) end
    InCall = false
    SetTimeout(1200, function()
        if not InCall then
            CurrentPhone = nil
            closeUI()
        end
    end)
end)

RegisterNetEvent('rsg-telephone:client:setRinging', function(phoneId, state)
    Ringing[phoneId] = state or nil
    if not state then
        lastBell[phoneId] = nil
        WallCache[phoneId] = nil
        SendNUIMessage({ action = 'bell', id = phoneId, volume = 0 })
    end
end)

----------------------------------------------------------------
-- jobs / ownership
----------------------------------------------------------------
local function refreshJobs()
    local generation = jobGeneration
    RSGCore.Functions.TriggerCallback('rsg-telephone:server:myJobs', function(jobs)
        if generation ~= jobGeneration then return end
        local map = {}
        if type(jobs) == 'table' then
            for _, job in ipairs(jobs) do
                if type(job) == 'string' then map[job] = true end
            end
        end
        AllowedJobs = map
    end)
end

-- UX only: hide "Make Call" from players without the phone's job (server re-checks)
local function hasPhoneJob(p)
    if not p or not p.job then return true end
    return AllowedJobs[p.job] == true
end

local function isOwner(p)
    if not p or not p.owner then return false end
    return (RSGCore.Functions.GetPlayerData() or {}).citizenid == p.owner
end

local askPhoneDetails -- defined in the placement section

local function ownerSettings(id)
    local p = Phones[id]
    if not p or UIOpen then return end
    local form = askPhoneDetails('settings', { label = p.label, listed = p.listed ~= false, number = p.number })
    if not form then return end
    local ok, res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:ownerUpdate', nil, id,
        { label = form.label, listed = form.listed == true })
    notify(ok and locale('admin_saved') or res or locale('not_near'), ok and 'success' or 'error')
end

local function pickupPhone(id)
    local p = Phones[id]
    if not p then return end
    if not confirmDialog(locale('target_pickup'), locale('pickup_confirm', p.number)) then return end
    local ok, res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:pickupPhone', nil, id)
    notify(ok and locale('picked_up', p.number) or res or '', ok and 'success' or 'error')
end

local function useCall(id)
    if InCall or UIOpen then return end
    CurrentPhone = id
    openUI('dial')
end

local function answer(id)
    if InCall or UIOpen then return end
    local ok, res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:answer', nil, id)
    if not ok then
        if res then notify(res, 'error') end
        return
    end
    CurrentPhone = id
    InCall = true
    openUI('connected', res)
end

----------------------------------------------------------------
-- targets / props
----------------------------------------------------------------
-- Props created inside a building must be put in the interior room or they won't render.
-- Natives from alloc8or rdr3-nativedb: GET_INTERIOR_AT_COORDS, GET_INTERIOR_FROM_ENTITY,
-- GET_ROOM_KEY_FROM_ENTITY, FORCE_ROOM_FOR_ENTITY (0xBC29A9894C976945)
local function applyRoom(obj, p)
    local interior = GetInteriorAtCoords(p.x, p.y, p.z)
    if not interior or interior == 0 then return true end
    local room = p.room or 0
    if room == 0 then
        -- older phones: borrow the player's room if they're in the same interior
        local ped = PlayerPedId()
        if GetInteriorFromEntity(ped) ~= interior then return false end
        room = GetRoomKeyFromEntity(ped)
    end
    ForceRoomForEntity(obj, interior, room)
    return true
end

local Roomed = {}

local function spawnPhone(p)
    if Spawned[p.id] then
        if not Roomed[p.id] then Roomed[p.id] = applyRoom(Spawned[p.id], p) end
        return
    end

    local model = joaat(p.model)
    if not HasModelLoaded(model) then
        local now = GetGameTimer()
        if not ModelRetry[p.model] or now >= ModelRetry[p.model] then
            ModelRetry[p.model] = now + 3000 -- retry an invalid model every few seconds instead of stalling
            RequestModel(model)
        end
        return
    end
    ModelRetry[p.model] = nil

    -- the phone may have been removed / respawned while the model loaded
    if Phones[p.id] ~= p or Spawned[p.id] then SetModelAsNoLongerNeeded(model) return end

    -- NoOffset variants keep the exact saved Z (the plain natives shift by the model's bounds)
    local obj = CreateObjectNoOffset(model, p.x, p.y, p.z, false, false, false, false)
    if not obj or obj == 0 then SetModelAsNoLongerNeeded(model) return end
    FreezeEntityPosition(obj, true) -- freeze first so physics can't drop it
    SetEntityCoordsNoOffset(obj, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, p.heading or 0.0)
    Roomed[p.id] = applyRoom(obj, p)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(model)
    Spawned[p.id] = obj

    exports['rsg-target']:addLocalEntity(obj, {
        {
            name = 'rsg_telephone_call_' .. p.id,
            icon = 'fa-solid fa-phone',
            label = locale('target_call'),
            distance = Config.UseDistance,
            canInteract = function() return not InCall and not Ringing[p.id] and hasPhoneJob(Phones[p.id] or p) end,
            onSelect = function() CreateThread(function() useCall(p.id) end) end,
        },
        {
            name = 'rsg_telephone_answer_' .. p.id,
            icon = 'fa-solid fa-phone-volume',
            label = locale('target_answer'),
            distance = Config.UseDistance,
            canInteract = function() return Ringing[p.id] and not InCall end,
            onSelect = function() CreateThread(function() answer(p.id) end) end,
        },
        {
            name = 'rsg_telephone_settings_' .. p.id,
            icon = 'fa-solid fa-gear',
            label = locale('target_settings'),
            distance = Config.UseDistance,
            canInteract = function() return not InCall and not Ringing[p.id] and isOwner(Phones[p.id]) end,
            onSelect = function() CreateThread(function() ownerSettings(p.id) end) end,
        },
        {
            name = 'rsg_telephone_pickup_' .. p.id,
            icon = 'fa-solid fa-hand',
            label = locale('target_pickup'),
            distance = Config.UseDistance,
            canInteract = function() return not InCall and not Ringing[p.id] and isOwner(Phones[p.id]) end,
            onSelect = function() CreateThread(function() pickupPhone(p.id) end) end,
        },
    })
end

local function despawnPhone(id)
    local obj = Spawned[id]
    if obj then
        exports['rsg-target']:removeLocalEntity(obj)
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        Spawned[id] = nil
        Roomed[id] = nil
    end
end

----------------------------------------------------------------
-- map blips
----------------------------------------------------------------
local Blips = {}

local function removeBlip(id)
    if Blips[id] then
        RemoveBlip(Blips[id])
        Blips[id] = nil
    end
end

local function addBlip(p)
    if not Config.Blip.Enabled then return end
    removeBlip(p.id)
    local blip = BlipAddForCoords(1664425300, p.x, p.y, p.z)
    SetBlipSprite(blip, joaat(Config.Blip.Sprite), true)
    SetBlipScale(blip, Config.Blip.Scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, p.label or locale('title')) -- SetBlipName
    Blips[p.id] = blip
end

local function addPhone(p)
    if type(p) ~= 'table' or not p.id then return end
    p.pos = vector3(p.x, p.y, p.z) -- cached for the streaming / bell loops
    Phones[p.id] = p
    addBlip(p)
end

local function setPhones(list)
    for id in pairs(Spawned) do despawnPhone(id) end
    for id in pairs(Blips) do removeBlip(id) end
    Phones, Ringing, lastBell, ModelRetry, WallCache = {}, {}, {}, {}, {}
    for _, p in ipairs(list or {}) do addPhone(p) end
end

RegisterNetEvent('rsg-telephone:client:syncPhones', setPhones)

RegisterNetEvent('rsg-telephone:client:addPhone', addPhone)

-- admin edit: a model change needs a respawn, a label change needs a new blip name
RegisterNetEvent('rsg-telephone:client:updatePhone', function(p)
    local old = Phones[p.id]
    if old and old.model ~= p.model then despawnPhone(p.id) end
    addPhone(p)
end)

RegisterNetEvent('rsg-telephone:client:removePhone', function(id)
    removeBlip(id)
    despawnPhone(id)
    Phones[id] = nil
    Ringing[id] = nil
    lastBell[id] = nil
    WallCache[id] = nil
    if CurrentPhone == id then resetCall() end
end)

local function loadPhones()
    local generation = phoneGeneration
    local list, ringing = RSGCore.Functions.AwaitCallback('rsg-telephone:server:getPhones')
    if generation ~= phoneGeneration then return end
    -- a timed-out callback returns nil: keep the current phones instead of wiping them
    if type(list) ~= 'table' then return end
    setPhones(list)
    for _, id in ipairs(ringing or {}) do Ringing[id] = true end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    refreshJobs()
    loadPhones()
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', refreshJobs)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    jobGeneration = jobGeneration + 1
    phoneGeneration = phoneGeneration + 1
    AllowedJobs = {}
    setPhones({})
    resetCall()
    if Placing then
        Placing = false
        exports['rsg-gizmo']:Cancel()
    end
    AdminOpen = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminClose' })
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then
        refreshJobs()
        loadPhones()
    end
end)

-- stream props in/out around the player
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, p in pairs(Phones) do
            local d = #(pos - p.pos)
            if d <= Config.SpawnDistance then spawnPhone(p) else despawnPhone(id) end
        end
        Wait(500)
    end
end)

-- ring audio: volume falls off with distance, pans left/right from the camera, muffles behind walls
local function wallBetween(from, to)
    local dist = #(to - from)
    if dist < 1.0 then return false end
    local ray = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 1, PlayerPedId(), 0) -- 1 = world only
    local status, hit, endCoords
    repeat
        Wait(0) -- GetShapeTestResult is asynchronous; poll until complete
        status, hit, endCoords = GetShapeTestResult(ray)
    until status ~= 1
    -- status 2 = no result (ray failed); endCoords is nil in that case
    if status ~= 0 or not endCoords then return false end
    return (hit == 1 or hit == true) and #(endCoords - from) < dist - 0.6 -- ignore the wall the phone is mounted on
end

local function bellState(p)
    local cam = GetGameplayCamCoord()
    local pos = p.pos
    local d = #(GetEntityCoords(PlayerPedId()) - pos)
    if d > Config.RingDistance then return 0, 0, false end
    local vol = (1.0 - d / Config.RingDistance) ^ 1.6
    -- camera right vector from heading; pan = how far right of the camera the phone is (-1..1)
    local h = math.rad(GetGameplayCamRot(2).z)
    local dx, dy = pos.x - cam.x, pos.y - cam.y
    local len = math.sqrt(dx * dx + dy * dy)
    local pan = len > 0.3 and ((dx * math.cos(h) + dy * math.sin(h)) / len) * 0.85 or 0

    -- raycasts are comparatively expensive: refresh the wall result a few times per second, per phone
    local now = GetGameTimer()
    local cached = WallCache[p.id]
    local muffled
    if cached and now - cached.t < 500 then
        muffled = cached.v
    else
        muffled = wallBetween(cam, pos + vector3(0.0, 0.0, 0.1))
        WallCache[p.id] = { t = now, v = muffled }
    end
    return vol, pan, muffled
end

CreateThread(function()
    while true do
        local any = false
        for id in pairs(Ringing) do
            local p = Phones[id]
            if p then
                any = true
                local vol, pan, muffled = bellState(p)
                local key = ('%.2f|%.2f|%s'):format(vol, pan, muffled and 1 or 0)
                if lastBell[id] ~= key then
                    lastBell[id] = key
                    SendNUIMessage({ action = 'bell', id = id, volume = vol, pan = pan, muffled = muffled })
                end
            else
                WallCache[id] = nil
            end
        end
        Wait(any and 100 or 750)
    end
end)

----------------------------------------------------------------
-- phone NUI callbacks
----------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    if InCall then TriggerServerEvent('rsg-telephone:server:hangUp') end
    resetCall()
    cb('ok')
end)

RegisterNUICallback('hangUp', function(_, cb)
    TriggerServerEvent('rsg-telephone:server:hangUp')
    resetCall()
    cb('ok')
end)

RegisterNUICallback('getDirectory', function(_, cb)
    local res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:getDirectory')
    cb(res or { entries = {} })
end)

RegisterNUICallback('setListed', function(data, cb)
    local ok, res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:setListed', nil, data.id, data.listed == true)
    if ok then
        notify(locale(data.listed and 'dir_shown' or 'dir_hidden'), 'success')
        cb({ ok = true, entries = res })
    else
        if res then notify(res, 'error') end
        cb({ ok = false })
    end
end)

RegisterNUICallback('dial', function(data, cb)
    if not CurrentPhone or InCall then return cb({ ok = false }) end
    local ok, res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:startCall', nil,
        CurrentPhone, tostring(data.number or ''), tonumber(data.deposit) or 0)
    if ok then
        InCall = true
        cb({ ok = true, info = res })
    else
        if res then notify(res, 'error') end
        cb({ ok = false })
    end
end)

----------------------------------------------------------------
-- phone details form (NUI) -> resolves with { label, model, number, listed, job } or nil
----------------------------------------------------------------
local pendingForm = nil
local pendingFormMode = nil
local validModel = {}
for _, m in ipairs(Config.Models) do validModel[m.value] = true end

RegisterNUICallback('placeForm', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    local promise = pendingForm
    local mode = pendingFormMode
    pendingForm = nil
    pendingFormMode = nil
    if not promise then return end
    if type(data) ~= 'table' or data.cancel then return promise:resolve(nil) end
    -- settings only edit the label/listing, so they don't submit a model
    if mode ~= 'settings' and not validModel[data.model] then return promise:resolve(nil) end
    promise:resolve(data)
end)

-- mode: 'admin' (all fields), 'player' (label/prop/listing), 'settings' (label/listing, prefilled)
function askPhoneDetails(mode, preset)
    if pendingForm or UIOpen then return end
    pendingForm = promise.new()
    pendingFormMode = mode or 'admin'
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'formShow', models = Config.Models, mode = mode or 'admin', preset = preset,
        ui = {
            title = locale(mode == 'settings' and 'settings_title' or 'input_title'), save = locale('admin_save'),
            label = locale('input_label'), model = locale('input_model'),
            number = locale('input_number'), listed = locale('input_listed'), job = locale('input_job'), confirm = locale('form_confirm'),
            cancel = locale('form_cancel'), invalid = locale('number_invalid'), required = locale('form_label_required'), job_hint = locale('form_job_hint'),
        },
    })
    return Citizen.Await(pendingForm)
end

-- a character switch or logout must not leave a blocked form/confirm promise behind
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    if pendingForm then pendingForm:resolve(nil) pendingForm = nil pendingFormMode = nil end
    if pendingConfirm then pendingConfirm:resolve(false) pendingConfirm = nil end
end)

----------------------------------------------------------------
-- placement (rsg-gizmo)
----------------------------------------------------------------
RegisterNetEvent('rsg-telephone:client:startPlacement', function(opts)
    CreateThread(function()
        opts = type(opts) == 'table' and opts or {}
        local isItem = opts.item == true

        local function cancelled()
            if isItem then TriggerServerEvent('rsg-telephone:server:cancelPlace') end
            notify(locale('place_cancel'), 'inform')
        end

        if Placing then return end -- the server ignores a second item use while one is pending
        if UIOpen then
            if isItem then TriggerServerEvent('rsg-telephone:server:cancelPlace') end
            return
        end

        Placing = true
        local form
        if isItem and opts.preset then
            -- saved phone: reuse its prop, label and number, no form
            form = { label = opts.preset.label, model = opts.preset.model, listed = true }
            if not validModel[form.model] then
                Placing = false
                return cancelled()
            end
            notify(locale('item_replace', opts.preset.number), 'inform')
        else
            form = askPhoneDetails(isItem and 'player' or 'admin')
            if not form then
                Placing = false
                return cancelled()
            end
        end

        local label = tostring(form.label or ''):sub(1, 64)
        local number = (tostring(form.number or ''):gsub('%D', '')):sub(1, 16)
        local job = tostring(form.job or '')
        local listed = form.listed == true

        local result = exports['rsg-gizmo']:Place(form.model, {
            title = locale('place_title'),
            maxDistance = Config.PlaceDistance,
            rotation = 'z',
        })
        if not result then
            Placing = false
            return cancelled()
        end

        local coords = result.coords
        local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        local room = 0
        if interior and interior ~= 0 then
            local ped = PlayerPedId()
            if GetInteriorFromEntity(ped) == interior then room = GetRoomKeyFromEntity(ped) end
        end

        local ok, res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:createPhone', nil, {
            item = isItem, label = label, model = form.model, number = number, listed = listed, job = job,
            x = coords.x, y = coords.y, z = coords.z,
            heading = result.heading or (result.rotation and result.rotation.z) or 0.0,
            rotation = result.rotation,
            room = room,
        })
        Placing = false

        if ok then
            notify(locale('placed', res), 'success')
        else
            notify(res or locale('db_error'), 'error')
        end
    end)
end)

----------------------------------------------------------------
-- admin panel
----------------------------------------------------------------
local function adminCall(name, ...)
    local ok, res = RSGCore.Functions.AwaitCallback('rsg-telephone:server:' .. name, nil, ...)
    if not ok and res then notify(res, 'error') end
    return ok, res
end

RegisterNetEvent('rsg-telephone:client:openAdmin', function()
    CreateThread(function()
        if UIOpen or AdminOpen or Placing then return end
        local data = RSGCore.Functions.AwaitCallback('rsg-telephone:server:adminList')
        if not data then return end
        AdminOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'adminOpen', data = data,
            ui = {
                title = locale('admin_title'), search = locale('ui_search'), phones = locale('admin_phones'), calls = locale('admin_calls'),
                label = locale('input_label'), number = locale('admin_number'), model = locale('input_model'), job = locale('input_job'),
                listed = locale('input_listed'), save = locale('admin_save'), delete = locale('admin_delete'), teleport = locale('admin_teleport'),
                waypoint = locale('admin_waypoint'), endcall = locale('admin_endcall'), add = locale('admin_add'), empty = locale('ui_empty'),
                select = locale('admin_select'), confirm = locale('admin_confirm_delete'), cancel = locale('form_cancel'),
                idle = locale('admin_idle'), ringing = locale('admin_ringing'), incall = locale('admin_incall'),
                payphone = locale('payphone'), owned = locale('admin_owned'), stored = locale('admin_stored'), close = locale('ui_close'),
                required = locale('form_label_required'), invalid = locale('number_invalid'), hidden = locale('ui_hidden'), anyone = locale('admin_anyone'),
            },
        })
    end)
end)

local function closeAdmin()
    AdminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminClose' })
end

RegisterNUICallback('adminClose', function(_, cb)
    closeAdmin()
    cb('ok')
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-telephone:server:adminList') or false)
end)

RegisterNUICallback('adminSave', function(d, cb)
    local ok, res = adminCall('adminUpdate', d.id, d)
    if ok then notify(locale('admin_saved'), 'success') end
    cb(ok and res or false)
end)

RegisterNUICallback('adminDelete', function(d, cb)
    local ok, res = adminCall('adminDelete', d.id)
    if ok then notify(locale('admin_deleted'), 'success') end
    cb(ok and res or false)
end)

RegisterNUICallback('adminEndCall', function(d, cb)
    local ok, res = adminCall('adminEndCall', d.id)
    cb(ok and res or false)
end)

RegisterNUICallback('adminTeleport', function(d, cb)
    cb('ok')
    local p = Phones[tonumber(d.id)]
    if not p then return end
    closeAdmin()
    local ped = PlayerPedId()
    DoScreenFadeOut(300) Wait(350)
    SetEntityCoords(ped, p.x, p.y, p.z + 0.5, false, false, false, false)
    Wait(500) DoScreenFadeIn(300)
end)

RegisterNUICallback('adminWaypoint', function(d, cb)
    cb('ok')
    local p = Phones[tonumber(d.id)]
    if not p then return end
    ClearGpsMultiRoute()
    StartGpsMultiRoute(joaat('COLOR_YELLOW'), true, true)
    AddPointToGpsMultiRoute(p.x, p.y, p.z)
    SetGpsMultiRouteRender(true)
    notify(locale('admin_waypoint_set', p.label), 'inform')
end)

RegisterNUICallback('adminAdd', function(_, cb)
    cb('ok')
    closeAdmin()
    TriggerEvent('rsg-telephone:client:startPlacement') -- server still checks permission on create
end)

----------------------------------------------------------------
-- cleanup
----------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Spawned) do despawnPhone(id) end
    for id in pairs(Blips) do removeBlip(id) end
    stopVoice()
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    UIOpen = false
    AdminOpen = false
    Placing = false
    if pendingForm then pendingForm:resolve(nil) pendingForm = nil pendingFormMode = nil end
    if pendingConfirm then pendingConfirm:resolve(false) pendingConfirm = nil end
end)
