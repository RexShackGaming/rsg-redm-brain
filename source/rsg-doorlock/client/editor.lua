local RSGCore = exports['rsg-core']:GetCoreObject()

local editorOpen = false
local picking = false
local selected = {} -- { {hash, model, coords} }
local EditingId

---------------------------------------------
-- helpers
---------------------------------------------
local modelByHash
local function modelOf(hash)
    if not modelByHash then
        modelByHash = {}
        for _, d in ipairs(DoorHashes) do modelByHash[d[1]] = d[2] end
    end
    return modelByHash[hash] or locale('ui_door')
end

local function doorList()
    local list = {}
    for id, d in pairs(Doors) do
        local hashes = {}
        for i, h in ipairs(d.doors) do
            hashes[i] = { hash = h.hash, model = h.object and locale('ui_custom_door') or modelOf(h.hash), coords = { x = h.coords.x, y = h.coords.y, z = h.coords.z }, object = h.object, heading = h.heading }
        end
        list[#list + 1] = {
            id = id, name = d.name, jobs = d.jobs, distance = d.distance, locked = d.locked, doors = hashes,
            dist = math.floor(#(GetEntityCoords(cache.ped) - d.textCoords) + 0.5)
        }
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- MLO / custom doors are not in DoorHashes or the game's door system,
-- so we identify them by model + position and lock them by freezing the object
local function customDoorFromEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 3 then return nil end
    local c = GetEntityCoords(ent)
    local model = GetEntityModel(ent)
    local key = ('rsgdl_%d_%d_%d_%d'):format(model, math.floor(c.x * 10), math.floor(c.y * 10), math.floor(c.z * 10))
    return {
        hash = GetHashKey(key), model = locale('ui_custom_door'), coords = c,
        object = model, heading = GetEntityHeading(ent)
    }
end

local function managedHashes()
    local map = {}
    for id, d in pairs(Doors) do
        for _, h in ipairs(d.doors) do map[h.hash] = id end
    end
    return map
end

local function setEditorState(on)
    editorOpen = on
    LocalPlayer.state:set('doorEditor', on, false)
end

local localeSent = false
local function sendLocale()
    if localeSent then return end
    local dict = lib.getLocales and lib.getLocales()
    if not dict or not next(dict) then -- fallback for older ox_lib
        dict = json.decode(LoadResourceFile(GetCurrentResourceName(), 'locales/en.json') or '{}') or {}
    end
    SendNUIMessage({ action = 'locale', locale = dict })
    localeSent = true
end

local function openUI(extra)
    sendLocale()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        doors = doorList(),
        maxDoors = Config.MaxDoorsPerLock,
        defaultDistance = Config.DefaultDistance,
        pick = extra
    })
end

local function closeUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    setEditorState(false)
end

local function camDirection()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

---------------------------------------------
-- world picking mode
---------------------------------------------
local function startPicking()
    picking = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    sendLocale()

    local managed = managedHashes()
    local nearby, lastScan = {}, 0
    local keyEnter, keyBack = RSGCore.Shared.Keybinds['ENTER'], RSGCore.Shared.Keybinds['BACKSPACE']
    local lastText

    CreateThread(function()
        while picking do
            local ped = cache.ped
            local pcoords = GetEntityCoords(ped)

            -- rescan the door list around the player twice a second
            if GetGameTimer() - lastScan > 500 then
                lastScan = GetGameTimer()
                nearby = {}
                for _, d in ipairs(DoorHashes) do
                    local v = vector3(d[3], d[4], d[5])
                    if #(pcoords - v) < 25.0 then nearby[#nearby + 1] = { hash = d[1], model = d[2], coords = v } end
                end
            end

            -- aim ray
            local camPos = GetGameplayCamCoord()
            local target = camPos + camDirection() * 20.0
            local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, target.x, target.y, target.z, -1, ped, 0)
            local _, hit, hitPos, _, hitEnt = GetShapeTestResult(ray)
            local aimPos = (hit == 1 or hit == true) and hitPos or target

            local best, bestDist
            for _, d in ipairs(nearby) do
                local dist = #(aimPos - d.coords)
                if dist < Config.PickRange and (not bestDist or dist < bestDist) then best, bestDist = d, dist end
            end

            -- nothing from the vanilla list: try the object we are aiming at (MLO doors)
            if not best and Config.AllowCustomDoors and (hit == 1 or hit == true) then
                best = customDoorFromEntity(hitEnt)
            end

            -- draw selected doors green, aimed door white
            for _, s in ipairs(selected) do
                DrawLine(pcoords.x, pcoords.y, pcoords.z, s.coords.x, s.coords.y, s.coords.z + 1.0, 80, 220, 90, 255)
            end

            local hud = { count = #selected, max = Config.MaxDoorsPerLock }
            if best then
                DrawLine(pcoords.x, pcoords.y, pcoords.z, best.coords.x, best.coords.y, best.coords.z + 1.0, 255, 255, 255, 255)
                local owner = managed[best.hash]
                hud.model, hud.hash = best.model, best.hash
                for _, sd in ipairs(selected) do
                    if sd.hash == best.hash then hud.selected = true break end
                end
                if owner and owner ~= EditingId then
                    hud.inUse = Doors[owner] and Doors[owner].name or ('#' .. owner)
                end
            end
            local key = json.encode(hud)
            if key ~= lastText then
                SendNUIMessage({ action = 'pickHud', hud = hud })
                lastText = key
            end

            DisableControlAction(0, `INPUT_ATTACK`, true)
            if IsDisabledControlJustReleased(0, keyEnter) or IsControlJustReleased(0, keyEnter) then
                if best then
                    local found
                    for i, s in ipairs(selected) do
                        if s.hash == best.hash then found = i break end
                    end
                    if found then
                        table.remove(selected, found)
                        SendNUIMessage({ action = 'pickFeedback', type = 'removed', text = best.model })
                    elseif #selected < Config.MaxDoorsPerLock then
                        selected[#selected + 1] = best
                        SendNUIMessage({ action = 'pickFeedback', type = 'added', text = best.model })
                    else
                        SendNUIMessage({ action = 'pickFeedback', type = 'error', text = locale('err_too_many') })
                    end
                    lastText = nil
                else
                    SendNUIMessage({ action = 'pickFeedback', type = 'error', text = locale('pick_none') })
                end
            elseif IsControlJustReleased(0, keyBack) or IsDisabledControlJustReleased(0, keyBack) then
                picking = false
            end
            Wait(0)
        end

        SendNUIMessage({ action = 'pickHud', hud = false })
        local out = {}
        for i, s in ipairs(selected) do
            out[i] = { hash = s.hash, model = s.model, coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z }, object = s.object, heading = s.heading }
        end
        openUI(out)
    end)
end

---------------------------------------------
-- open / NUI callbacks
---------------------------------------------
RegisterNetEvent('rsg-doorlock:client:openEditor', function()
    if editorOpen then return end
    if not lib.callback.await('rsg-doorlock:server:admin:check', false) then return end
    setEditorState(true)
    openUI()
end)

AddEventHandler('rsg-doorlock:client:editorRefresh', function()
    if editorOpen and not picking then
        SendNUIMessage({ action = 'refresh', doors = doorList() })
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('pick', function(data, cb)
    EditingId = tonumber(data.id)
    selected = {}
    for _, d in ipairs(data.doors or {}) do
        if type(d.hash) == 'number' and d.coords then
            selected[#selected + 1] = {
                hash = d.hash, model = d.object and locale('ui_custom_door') or modelOf(d.hash),
                coords = vector3(d.coords.x, d.coords.y, d.coords.z),
                object = tonumber(d.object), heading = tonumber(d.heading)
            }
        end
    end
    cb('ok')
    startPicking()
end)

RegisterNUICallback('save', function(data, cb)
    local ok, res, a, b = lib.callback.await('rsg-doorlock:server:admin:save', false, data)
    cb({ ok = ok, id = res, error = not ok and locale(res or 'err_invalid', a, b) or nil, message = ok and locale('saved') or nil })
end)

RegisterNUICallback('delete', function(data, cb)
    local ok = lib.callback.await('rsg-doorlock:server:admin:delete', false, data.id)
    cb({ ok = ok, message = ok and locale('deleted') or locale('err_invalid') })
end)

RegisterNUICallback('teleport', function(data, cb)
    local door = Doors[tonumber(data.id)]
    if door then
        local c = door.textCoords
        SetEntityCoords(cache.ped, c.x, c.y, c.z - 1.0, false, false, false, false)
        TriggerServerEvent('rsg-doorlock:server:admin:teleported', door.id or tonumber(data.id))
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if editorOpen then
        picking = false
        SetNuiFocus(false, false)
        LocalPlayer.state:set('doorEditor', false, false)
    end
end)
