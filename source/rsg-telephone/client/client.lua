local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Phones   = {}   -- [id] = data
local Spawned  = {}   -- [id] = entity
local Ringing  = {}   -- [id] = true
local lastBell = {}   -- [id] = last bell state sent to NUI
local CurrentPhone = nil   -- phone id the player is using
local InCall   = false     -- ringing out or connected
local UIOpen   = false
local placing  = false

-- RedM control hashes (rdr3_discoveries Controls/README.md)
local KEY_UP, KEY_DOWN     = 0x6319DB71, 0x05CA7C52
local KEY_LEFT, KEY_RIGHT  = 0xA65EBAB4, 0xDEB34313
local KEY_ACCEPT, KEY_BACK = 0xC7B5340A, 0x156F7119
local KEY_FWD, KEY_BWD     = 0xCEFD9220, 0xDE794E3E -- E / Q

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
local function inputLoop()
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
    end)
end

local function openUI(mode, info)
    local wasOpen = UIOpen
    UIOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    if not wasOpen then inputLoop() end
    local phone = Phones[CurrentPhone]
    -- payphone info is display only; the server decides what is charged
    local pay = (Config.Payphone.Enabled and phone and not phone.job and (not phone.owner or Config.Item.Payphone)) and {
        cost = Config.Payphone.CostPerMinute, max = Config.Payphone.MaxDeposit, coins = Config.Payphone.Coins,
        cash = ((RSGCore.Functions.GetPlayerData() or {}).money or {})[Config.Payphone.MoneyType] or 0,
    } or nil
    SendNUIMessage({ action = 'open', mode = mode, info = info, ui = UIText, pay = pay,
        phone = phone and { label = phone.label, number = phone.number } or nil })
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
    cb(lib.callback.await('rsg-telephone:server:getDirectory', false) or { entries = {} })
end)

RegisterNUICallback('setListed', function(data, cb)
    local ok, res = lib.callback.await('rsg-telephone:server:setListed', false, data.id, data.listed == true)
    if ok then
        lib.notify({ title = locale('title'), description = locale(data.listed and 'dir_shown' or 'dir_hidden'), type = 'success' })
        cb({ ok = true, entries = res })
    else
        if res then lib.notify({ title = locale('title'), description = res, type = 'error' }) end
        cb({ ok = false })
    end
end)

RegisterNUICallback('dial', function(data, cb)
    if not CurrentPhone or InCall then return cb({ ok = false }) end
    local ok, res = lib.callback.await('rsg-telephone:server:startCall', false, CurrentPhone, tostring(data.number or ''), tonumber(data.deposit) or 0)
    if ok then
        InCall = true
        cb({ ok = true, info = res })
    else
        if res then lib.notify({ title = locale('title'), description = res, type = 'error' }) end
        cb({ ok = false })
    end
end)

----------------------------------------------------------------
-- built-in voice line (Mumble natives)
----------------------------------------------------------------
local VoicePartner = nil
local voiceToken = 0

local function applyLine()
    if not VoicePartner then return end
    local t = Config.Voice.Target
    MumbleClearVoiceTarget(t)
    MumbleAddVoiceTargetPlayerByServerId(t, VoicePartner)
    if Config.Voice.KeepProximity then
        MumbleAddVoiceTargetChannel(t, MumbleGetVoiceChannelFromServerId(GetPlayerServerId(PlayerId())))
    end
    MumbleSetVoiceTarget(t)
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
        if not InCall then CurrentPhone = nil closeUI() end
    end)
end)

RegisterNetEvent('rsg-telephone:client:setRinging', function(phoneId, state)
    Ringing[phoneId] = state or nil
    if not state then
        lastBell[phoneId] = nil
        SendNUIMessage({ action = 'bell', id = phoneId, volume = 0 })
    end
end)

----------------------------------------------------------------
-- targets / props
----------------------------------------------------------------
-- UX only: hide "Make Call" from players without the phone's job (server re-checks)
local function hasPhoneJob(p)
    if not p.job then return true end
    local job = (RSGCore.Functions.GetPlayerData() or {}).job
    if not job then return false end
    return (job.type and job.type:lower() == p.job) or (job.name and job.name:lower() == p.job) or false
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
    local ok, res = lib.callback.await('rsg-telephone:server:ownerUpdate', false, id, { label = form.label, listed = form.listed == true })
    lib.notify({ title = locale('title'), description = ok and locale('admin_saved') or res or locale('not_near'), type = ok and 'success' or 'error' })
end

local function pickupPhone(id)
    local p = Phones[id]
    if not p then return end
    local confirm = lib.alertDialog({ header = locale('target_pickup'), content = locale('pickup_confirm', p.number), centered = true, cancel = true })
    if confirm ~= 'confirm' then return end
    local ok, res = lib.callback.await('rsg-telephone:server:pickupPhone', false, id)
    lib.notify({ title = locale('title'), description = ok and locale('picked_up', p.number) or res or '', type = ok and 'success' or 'error' })
end

local function useCall(id)
    if InCall or UIOpen then return end
    CurrentPhone = id
    openUI('dial')
end

local function answer(id)
    if InCall or UIOpen then return end
    local ok, res = lib.callback.await('rsg-telephone:server:answer', false, id)
    if not ok then
        if res then lib.notify({ title = locale('title'), description = res, type = 'error' }) end
        return
    end
    CurrentPhone = id
    InCall = true
    openUI('connected', res)
end

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
local BadModel = {} -- [model] = retry time; a broken model must not stall the streaming loop

local function spawnPhone(p)
    if Spawned[p.id] then
        if not Roomed[p.id] then Roomed[p.id] = applyRoom(Spawned[p.id], p) end
        return
    end
    if BadModel[p.model] and GetGameTimer() < BadModel[p.model] then return end
    local model = joaat(p.model)
    local okModel = pcall(lib.requestModel, model, 5000)
    if not okModel or not HasModelLoaded(model) then
        BadModel[p.model] = GetGameTimer() + 60000
        return
    end
    -- the phone may have been removed / respawned while the model loaded
    if Phones[p.id] ~= p or Spawned[p.id] then SetModelAsNoLongerNeeded(model) return end
    -- NoOffset variants keep the exact saved Z (the plain natives shift by the model's bounds)
    local obj = CreateObjectNoOffset(model, p.x, p.y, p.z, false, false, false, false)
    FreezeEntityPosition(obj, true) -- freeze first so physics can't drop it
    SetEntityCoordsNoOffset(obj, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, p.heading)
    Roomed[p.id] = applyRoom(obj, p)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(model)
    Spawned[p.id] = obj

    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'rsg_telephone_call_' .. p.id,
            icon = 'fa-solid fa-phone',
            label = locale('target_call'),
            distance = Config.UseDistance,
            canInteract = function() return not InCall and not Ringing[p.id] and hasPhoneJob(Phones[p.id] or p) end,
            onSelect = function() useCall(p.id) end,
        },
        {
            name = 'rsg_telephone_answer_' .. p.id,
            icon = 'fa-solid fa-phone-volume',
            label = locale('target_answer'),
            distance = Config.UseDistance,
            canInteract = function() return Ringing[p.id] and not InCall end,
            onSelect = function() answer(p.id) end,
        },
        {
            name = 'rsg_telephone_settings_' .. p.id,
            icon = 'fa-solid fa-gear',
            label = locale('target_settings'),
            distance = Config.UseDistance,
            canInteract = function() return not InCall and not Ringing[p.id] and isOwner(Phones[p.id]) end,
            onSelect = function() ownerSettings(p.id) end,
        },
        {
            name = 'rsg_telephone_pickup_' .. p.id,
            icon = 'fa-solid fa-hand',
            label = locale('target_pickup'),
            distance = Config.UseDistance,
            canInteract = function() return not InCall and not Ringing[p.id] and isOwner(Phones[p.id]) end,
            onSelect = function() pickupPhone(p.id) end,
        },
    })
end

local function despawnPhone(id)
    local obj = Spawned[id]
    if obj then
        exports.ox_target:removeLocalEntity(obj)
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
    if Blips[id] then RemoveBlip(Blips[id]) Blips[id] = nil end
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
    p.pos = vector3(p.x, p.y, p.z) -- cached for the streaming / bell loops
    Phones[p.id] = p
    addBlip(p)
end

local function setPhones(list)
    for id in pairs(Spawned) do despawnPhone(id) end
    for id in pairs(Blips) do removeBlip(id) end
    Phones = {}
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
end)

local function loadPhones()
    local list, ringing = lib.callback.await('rsg-telephone:server:getPhones', false)
    setPhones(list)
    Ringing, lastBell = {}, {}
    for _, id in ipairs(ringing or {}) do Ringing[id] = true end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadPhones)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then loadPhones() end
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
    local _, hit, endCoords = GetShapeTestResult(ray)
    return hit == 1 and #(endCoords - from) < dist - 0.6 -- ignore the wall the phone is mounted on
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
    return vol, pan, wallBetween(cam, pos + vector3(0.0, 0.0, 0.1))
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
            end
        end
        Wait(any and 100 or 750)
    end
end)

----------------------------------------------------------------
-- admin placement
----------------------------------------------------------------
local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function cameraRay(dist)
    local camPos = GetGameplayCamCoord()
    local dest = camPos + rotToDir(GetGameplayCamRot(2)) * dist
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(ray)
    return hit == 1, endCoords
end

-- phone details form (NUI) -> resolves with { label, model, number, listed, job } or nil
local pendingForm = nil
local validModel = {}
for _, m in ipairs(Config.Models) do validModel[m.value] = true end

RegisterNUICallback('placeForm', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    local p = pendingForm
    pendingForm = nil
    if not p then return end
    if type(data) ~= 'table' or data.cancel or not validModel[data.model] then return p:resolve(nil) end
    p:resolve(data)
end)

-- mode: 'admin' (all fields), 'player' (label/prop/listing), 'settings' (label/listing, prefilled)
function askPhoneDetails(mode, preset)
    if pendingForm or UIOpen then return end
    pendingForm = promise.new()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'formShow', models = Config.Models, mode = mode or 'admin', preset = preset, ui = {
        title = locale(mode == 'settings' and 'settings_title' or 'input_title'), save = locale('admin_save'),
        label = locale('input_label'), model = locale('input_model'),
        number = locale('input_number'), listed = locale('input_listed'), job = locale('input_job'), confirm = locale('form_confirm'),
        cancel = locale('form_cancel'), invalid = locale('number_invalid'), required = locale('form_label_required'), job_hint = locale('form_job_hint'),
    } })
    return Citizen.Await(pendingForm)
end

RegisterNetEvent('rsg-telephone:client:startPlacement', function(opts)
    opts = type(opts) == 'table' and opts or {}
    local isItem = opts.item == true
    local function cancelled()
        if isItem then TriggerServerEvent('rsg-telephone:server:cancelPlace') end
        lib.notify({ title = locale('title'), description = locale('place_cancel'), type = 'inform' })
    end
    if placing then return end -- the server ignores a second item use while one is pending
    if UIOpen then return isItem and TriggerServerEvent('rsg-telephone:server:cancelPlace') or nil end

    local form
    if isItem and opts.preset then
        form = { label = opts.preset.label, model = opts.preset.model, listed = true } -- saved phone: no form
        if not validModel[form.model] then return cancelled() end
        lib.notify({ title = locale('title'), description = locale('item_replace', opts.preset.number), type = 'inform' })
    else
        form = askPhoneDetails(isItem and 'player' or 'admin')
    end
    if not form then return cancelled() end
    local input = { tostring(form.label or ''):sub(1, 64), form.model, (tostring(form.number or ''):gsub('%D', '')):sub(1, 16), form.listed == true, tostring(form.job or '') }

    local modelHash = joaat(input[2])
    if not pcall(lib.requestModel, modelHash, 5000) then return cancelled() end

    placing = true
    local ped = PlayerPedId()
    local pedPos = GetEntityCoords(ped)
    local ghost = CreateObjectNoOffset(modelHash, pedPos.x, pedPos.y, pedPos.z, false, false, false, false)
    SetEntityAlpha(ghost, 170, false)
    local placeInterior, placeRoom = GetInteriorFromEntity(ped), GetRoomKeyFromEntity(ped)
    if placeInterior ~= 0 then ForceRoomForEntity(ghost, placeInterior, placeRoom) end
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    local heading, zOff, fOff = GetEntityHeading(ped) + 180.0, 0.0, 0.0
    SendNUIMessage({ action = 'placeShow', ui = {
        title = locale('place_title'), rotate = locale('place_rotate'), height = locale('place_height'), move = locale('place_move'), distance = locale('place_distance'),
        place = locale('place_confirm'), cancel = locale('place_cancel_key'), key_enter = locale('key_enter'), key_back = locale('key_back'),
        heading = locale('place_heading'), offset = locale('place_offset'),
    } })
    local lastSent = ''

    -- the Enter that submitted the form must not also place the phone
    Wait(250)
    while IsControlPressed(0, KEY_ACCEPT) or IsDisabledControlPressed(0, KEY_ACCEPT) do Wait(0) end

    local confirmed, coords = false, nil
    while placing do
        Wait(0)
        local hit, pos = cameraRay(8.0)
        if hit then
            -- forward/back along the camera's flat direction (away from / towards you)
            local camH = math.rad(GetGameplayCamRot(2).z)
            coords = vector3(pos.x - math.sin(camH) * fOff, pos.y + math.cos(camH) * fOff, pos.z + zOff)
            SetEntityCoordsNoOffset(ghost, coords.x, coords.y, coords.z, false, false, false)
            SetEntityHeading(ghost, heading)
            -- follow the admin between rooms / in and out of buildings so the ghost always renders
            placeInterior, placeRoom = GetInteriorFromEntity(ped), GetRoomKeyFromEntity(ped)
            if placeInterior ~= 0 then ForceRoomForEntity(ghost, placeInterior, placeRoom) end
        end
        DisableControlAction(0, KEY_UP, true)
        DisableControlAction(0, KEY_DOWN, true)
        DisableControlAction(0, KEY_FWD, true)
        DisableControlAction(0, KEY_BWD, true)
        if IsDisabledControlPressed(0, KEY_FWD) then fOff = math.min(fOff + 0.01, 2.0) end
        if IsDisabledControlPressed(0, KEY_BWD) then fOff = math.max(fOff - 0.01, -2.0) end
        if IsControlPressed(0, KEY_LEFT) then heading = heading + 1.5 end
        if IsControlPressed(0, KEY_RIGHT) then heading = heading - 1.5 end
        if IsDisabledControlPressed(0, KEY_UP) then zOff = zOff + 0.01 end
        if IsDisabledControlPressed(0, KEY_DOWN) then zOff = zOff - 0.01 end
        if IsControlJustPressed(0, KEY_ACCEPT) and coords then confirmed = true placing = false end
        if IsControlJustPressed(0, KEY_BACK) then placing = false end

        -- key feedback for the placement panel; only sent when something changes
        local keys = {
            left = IsControlPressed(0, KEY_LEFT), right = IsControlPressed(0, KEY_RIGHT),
            up = IsDisabledControlPressed(0, KEY_UP), down = IsDisabledControlPressed(0, KEY_DOWN),
            enter = IsControlPressed(0, KEY_ACCEPT), back = IsControlPressed(0, KEY_BACK),
            fwd = IsDisabledControlPressed(0, KEY_FWD), bwd = IsDisabledControlPressed(0, KEY_BWD),
        }
        local h, z = math.floor(heading % 360.0), ('%.2f'):format(zOff)
        local f = ('%.2f'):format(fOff)
        local sig = ('%s%s%s%s%s%s%s%s%d%s%s%s'):format(keys.left and 1 or 0, keys.right and 1 or 0, keys.up and 1 or 0,
            keys.down and 1 or 0, keys.enter and 1 or 0, keys.back and 1 or 0, keys.fwd and 1 or 0, keys.bwd and 1 or 0,
            h, z, f, coords and 1 or 0)
        if sig ~= lastSent then
            lastSent = sig
            SendNUIMessage({ action = 'placeUpdate', keys = keys, heading = h, offset = z, forward = f, valid = coords ~= nil })
        end
    end

    SendNUIMessage({ action = 'placeHide' })
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    SetModelAsNoLongerNeeded(modelHash)

    if not confirmed then return cancelled() end

    local ok, res = lib.callback.await('rsg-telephone:server:createPhone', false, {
        item = isItem, label = input[1], model = input[2], number = input[3], listed = input[4], job = input[5],
        x = coords.x, y = coords.y, z = coords.z, heading = heading % 360.0,
        room = placeInterior ~= 0 and placeRoom or 0,
    })
    if ok then
        lib.notify({ title = locale('title'), description = locale('placed', res), type = 'success' })
    elseif res then
        lib.notify({ title = locale('title'), description = res, type = 'error' })
    end
end)

----------------------------------------------------------------
-- admin panel
----------------------------------------------------------------
local AdminOpen = false

local function adminCall(name, ...)
    local ok, res = lib.callback.await('rsg-telephone:server:' .. name, false, ...)
    if not ok and res then lib.notify({ title = locale('title'), description = res, type = 'error' }) end
    return ok, res
end

RegisterNetEvent('rsg-telephone:client:openAdmin', function()
    if UIOpen or AdminOpen or placing then return end
    local data = lib.callback.await('rsg-telephone:server:adminList', false)
    if not data then return end
    AdminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'adminOpen', data = data, ui = {
        title = locale('admin_title'), search = locale('ui_search'), phones = locale('admin_phones'), calls = locale('admin_calls'),
        label = locale('input_label'), number = locale('admin_number'), model = locale('input_model'), job = locale('input_job'),
        listed = locale('input_listed'), save = locale('admin_save'), delete = locale('admin_delete'), teleport = locale('admin_teleport'),
        waypoint = locale('admin_waypoint'), endcall = locale('admin_endcall'), add = locale('admin_add'), empty = locale('ui_empty'),
        select = locale('admin_select'), confirm = locale('admin_confirm_delete'), cancel = locale('form_cancel'),
        idle = locale('admin_idle'), ringing = locale('admin_ringing'), incall = locale('admin_incall'),
        payphone = locale('payphone'), owned = locale('admin_owned'), stored = locale('admin_stored'), close = locale('ui_close'),
        required = locale('form_label_required'), invalid = locale('number_invalid'), hidden = locale('ui_hidden'), anyone = locale('admin_anyone'),
    } })
end)

local function closeAdmin()
    AdminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminClose' })
end

RegisterNUICallback('adminClose', function(_, cb) closeAdmin() cb('ok') end)

RegisterNUICallback('adminRefresh', function(_, cb)
    cb(lib.callback.await('rsg-telephone:server:adminList', false) or false)
end)

RegisterNUICallback('adminSave', function(d, cb)
    local ok, res = adminCall('adminUpdate', d.id, d)
    if ok then lib.notify({ title = locale('title'), description = locale('admin_saved'), type = 'success' }) end
    cb(ok and res or false)
end)

RegisterNUICallback('adminDelete', function(d, cb)
    local ok, res = adminCall('adminDelete', d.id)
    if ok then lib.notify({ title = locale('title'), description = locale('admin_deleted'), type = 'success' }) end
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
    lib.notify({ title = locale('title'), description = locale('admin_waypoint_set', p.label), type = 'inform' })
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
    if placing then placing = false SendNUIMessage({ action = 'placeHide' }) end
    if pendingForm then pendingForm:resolve(nil) pendingForm = nil end
end)
