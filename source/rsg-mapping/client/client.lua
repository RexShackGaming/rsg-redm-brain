lib.locale()

local drawing, drawRadius, drawList = false, Config.DefaultRadius, {}
local uiOpen = false
local selected = nil
local viewCam, viewing = nil, false
local Saved = {} -- [hash] = { label, state }

---------------------------------------------------------------------
-- saved state sync
---------------------------------------------------------------------
local function applySaved(hash, e)
    if not e or e.state == nil then return end
    if e.state == 1 or e.state == true then RequestImap(hash) else RemoveImap(hash) end
end

local function loadSaved(list)
    Saved = {}
    for _, e in ipairs(list or {}) do
        Saved[e.hash] = { label = e.label, state = e.state }
        applySaved(e.hash, Saved[e.hash])
    end
end

RegisterNetEvent('rsg-mapping:client:syncAll', loadSaved)

RegisterNetEvent('rsg-mapping:client:update', function(hash, e)
    Saved[hash] = e or nil
    if e then applySaved(hash, e) end
    if uiOpen then SendNUIMessage({ action = 'saved', hash = hash, label = e and e.label or nil, state = e and e.state }) end
end)

local function fetchSaved()
    for _ = 1, 10 do
        local ok, list = pcall(lib.callback.await, 'rsg-mapping:server:getSaved', false)
        if ok then return loadSaved(list) end
        Wait(2000)
    end
end
CreateThread(function() Wait(1000); fetchSaved() end)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', fetchSaved)

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function toHex(h) return ('0x%08X'):format(h & 0xFFFFFFFF) end

local function canUse()
    local ok, res = pcall(lib.callback.await, 'rsg-mapping:server:canUse', false)
    return ok and res
end

local function notify(desc, ntype)
    lib.notify({ title = locale('cl_title'), description = desc, type = ntype or 'inform', duration = 4000 })
end

local function clampRadius(r)
    r = tonumber(r) or Config.DefaultRadius
    return math.min(math.max(r, 1.0), Config.MaxRadius)
end

local function num(v) return tonumber(v) and (tonumber(v) + 0.0) or nil end

local function isActive(hash)
    local a = IsImapActive(hash)
    return a == true or a == 1
end

local function decorate(v)
    v.active = isActive(v.hash)
    local e = Saved[v.hash]
    if e then v.label = e.label; v.saved = e.state end
    return v
end

-- returns list sorted by distance of { hash, name, x, y, z, dist, active, label, saved }
local function scan(radius)
    local p = GetEntityCoords(cache.ped)
    local px, py, pz = p.x, p.y, p.z
    local r2, res = radius * radius, {}
    for i = 1, #ImapData do
        local d = ImapData[i]
        local dx, dy = d[3] - px, d[4] - py
        local flat = dx * dx + dy * dy
        if flat <= r2 and not (d[3] == -1.0 and d[4] == -1.0) then -- skip entries with unknown coords
            local dz = d[5] - pz
            res[#res + 1] = { hash = d[1], name = d[2], x = d[3], y = d[4], z = d[5], dist = math.sqrt(flat + dz * dz) }
        end
    end
    table.sort(res, function(a, b) return a.dist < b.dist end)
    for i = 1, #res do decorate(res[i]) end
    return res
end

---------------------------------------------------------------------
-- 3D labels
---------------------------------------------------------------------
local function drawText3D(x, y, z, text, r, g, b)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextColor(r, g, b, 215)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), sx, sy)
end

local function startDrawing()
    -- scan thread: builds the draw list (with pre-built text + coords) once per refresh
    CreateThread(function()
        while drawing do
            local list = scan(drawRadius)
            for i = 1, #list do
                local v = list[i]
                v.pos = vector3(v.x, v.y, v.z)
                v.text = (v.label and (v.label .. '\n' .. v.name) or v.name) .. '\n' .. toHex(v.hash)
            end
            drawList = list
            Wait(Config.DrawRefresh)
        end
        drawList = {}
    end)
    -- render thread
    CreateThread(function()
        local maxDist = Config.DrawDistance
        while drawing do
            local p = GetEntityCoords(cache.ped)
            for i = 1, #drawList do
                local v = drawList[i]
                if #(p - v.pos) <= maxDist then
                    if v.active then drawText3D(v.x, v.y, v.z, v.text, 80, 220, 100)
                    else drawText3D(v.x, v.y, v.z, v.text, 200, 200, 200) end
                end
            end
            Wait(0)
        end
    end)
end

local function setDrawing(on, radius)
    if radius then drawRadius = clampRadius(radius) end
    if on and not drawing then drawing = true; startDrawing()
    elseif not on then drawing = false end
end

---------------------------------------------------------------------
-- view camera (orbits the selected IMAP)
---------------------------------------------------------------------
local function stopView()
    if not viewing then return end
    viewing = false
    RenderScriptCams(false, true, 600, true, true)
    if viewCam then DestroyCam(viewCam, false); viewCam = nil end
    ClearFocus()
end

local function startView(x, y, z)
    stopView()
    viewing = true
    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0) -- stream the area around the IMAP
    viewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local dist, height = Config.ViewDistance, Config.ViewHeight
    SetCamCoord(viewCam, x + dist, y, z + height)
    PointCamAtCoord(viewCam, x, y, z)
    SetCamFov(viewCam, 50.0)
    RenderScriptCams(true, true, 800, true, true)
    CreateThread(function()
        local ang = 0.0
        while viewing and viewCam do
            ang = ang + GetFrameTime() * Config.ViewOrbitSpeed
            SetCamCoord(viewCam, x + math.cos(ang) * dist, y + math.sin(ang) * dist, z + height)
            PointCamAtCoord(viewCam, x, y, z)
            Wait(0)
        end
    end)
end

---------------------------------------------------------------------
-- selected IMAP highlight (in world)
---------------------------------------------------------------------
local MARKER_CYLINDER = 0x94FDAE17

local function highlightLoop()
    CreateThread(function()
        local t = 0
        while selected do
            local s = selected
            t = t + GetFrameTime()
            local pulse = 0.5 + 0.5 * math.sin(t * 4.0)
            local r, g, b = 255, 255, 255
            if s.active then r, g, b = 90, 220, 110 end
            -- pulsing ring on the ground + tall beam (DRAW_MARKER)
            Citizen.InvokeNative(0x2A32FAA57B937173, MARKER_CYLINDER, s.x, s.y, s.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                Config.HighlightSize + pulse, Config.HighlightSize + pulse, 0.25, r, g, b, 90 + math.floor(pulse * 80), false, false, 2, false, nil, nil, false)
            Citizen.InvokeNative(0x2A32FAA57B937173, MARKER_CYLINDER, s.x, s.y, s.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.25, 0.25, Config.HighlightBeam, r, g, b, 120, false, false, 2, false, nil, nil, false)
            local p = GetEntityCoords(cache.ped)
            DrawLine(p.x, p.y, p.z, s.x, s.y, s.z, r, g, b, 200)
            drawText3D(s.x, s.y, s.z + 1.0, s.text, r, g, b)
            Wait(0)
        end
    end)
end

local function clearRoute()
    ClearGpsMultiRoute()
end

---------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------
local uiStrings -- built once, sent to NUI on open
local function getUiStrings()
    if uiStrings then return uiStrings end
    uiStrings = {}
    for _, k in ipairs({
        'ui_title', 'ui_found', 'ui_active_count', 'ui_search', 'ui_radius', 'ui_all', 'ui_active', 'ui_inactive',
        'ui_labels_on', 'ui_labels_off', 'ui_rescan', 'ui_close', 'ui_none', 'ui_outside', 'ui_unnamed',
        'ui_imap', 'ui_label_ph', 'ui_save', 'ui_status', 'ui_saved_state', 'ui_distance', 'ui_hash', 'ui_coords',
        'ui_saved_none', 'ui_enabled', 'ui_disabled', 'ui_enable', 'ui_disable', 'ui_waypoint', 'ui_view', 'ui_exit_view',
        'ui_copy_name', 'ui_copy_hash', 'ui_copy_lua', 'ui_copy_coords', 'ui_forget', 'ui_back', 'ui_state_saved',
        't_imap', 't_success', 't_error', 't_copied', 't_not_found', 't_enabled', 't_disabled', 't_waypoint',
        't_label_saved', 't_label_cleared', 't_forgot',
    }) do uiStrings[k] = locale(k) end
    return uiStrings
end

local function openUI(radius)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        radius = radius,
        items = scan(radius),
        labels = drawing,
        maxResults = Config.MaxResults,
        strings = getUiStrings(),
    })
end

local function closeUI()
    uiOpen = false
    selected = nil
    stopView()
    SetNuiFocus(false, false)
end

RegisterNUICallback('close', function(_, cb) closeUI(); cb('ok') end)

RegisterNUICallback('scan', function(data, cb)
    cb(scan(clampRadius(data.radius)))
end)

RegisterNUICallback('toggle', function(data, cb)
    local hash = math.tointeger(tonumber(data.hash))
    if not hash then return cb(false) end
    if data.enable then RequestImap(hash) else RemoveImap(hash) end
    Wait(100)
    local a = isActive(hash)
    if selected and selected.hash == hash then selected.active = a end
    if Config.PersistToggles then
        TriggerServerEvent('rsg-mapping:server:setState', hash, data.name, data.enable and true or false)
    end
    cb({ active = a, saved = Config.PersistToggles and (data.enable and 1 or 0) or nil })
end)

-- look up a hash anywhere on the map (not limited to radius)
RegisterNUICallback('findHash', function(data, cb)
    local h = math.tointeger(tonumber(data.hash))
    if not h then return cb({}) end
    if h > 0x7FFFFFFF then h = h - 0x100000000 end -- unsigned -> signed
    local p = GetEntityCoords(cache.ped)
    for i = 1, #ImapData do
        local d = ImapData[i]
        if d[1] == h then
            local v = decorate({ hash = d[1], name = d[2], x = d[3], y = d[4], z = d[5], global = true })
            v.dist = #(p - vector3(d[3], d[4], d[5]))
            return cb({ v })
        end
    end
    cb({})
end)

RegisterNUICallback('setLabel', function(data, cb)
    TriggerServerEvent('rsg-mapping:server:setLabel', data.hash, data.name, data.label)
    cb('ok')
end)

RegisterNUICallback('forgetState', function(data, cb)
    TriggerServerEvent('rsg-mapping:server:setState', data.hash, data.name, nil)
    cb('ok')
end)

RegisterNUICallback('view', function(data, cb)
    local x, y, z = num(data.x), num(data.y), num(data.z)
    if data.on and x and y and z then startView(x, y, z) else stopView() end
    cb({ on = viewing })
end)

RegisterNUICallback('toggleLabels', function(data, cb)
    setDrawing(not drawing, data.radius)
    cb({ on = drawing })
end)

RegisterNUICallback('waypoint', function(data, cb)
    local x, y, z = num(data.x), num(data.y), num(data.z)
    if not (x and y and z) then return cb(false) end
    clearRoute()
    StartGpsMultiRoute(GetHashKey('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(x, y, z)
    SetGpsMultiRouteRender(true)
    cb('ok')
end)

RegisterNUICallback('select', function(data, cb)
    local x, y, z, hash = num(data.x), num(data.y), num(data.z), math.tointeger(tonumber(data.hash))
    if not (x and y and z and hash) then return cb(false) end
    local wasOff = selected == nil
    if selected and selected.hash ~= hash then stopView() end
    local name = tostring(data.name or '')
    selected = { x = x, y = y, z = z, hash = hash, active = data.active == true, text = name .. '\n' .. toHex(hash) }
    if wasOff then highlightLoop() end
    cb('ok')
end)

RegisterNUICallback('deselect', function(_, cb) selected = nil; stopView(); cb('ok') end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    drawing, selected = false, nil
    if viewing then RenderScriptCams(false, false, 0, true, true); ClearFocus() end
    clearRoute()
end)

---------------------------------------------------------------------
-- commands
---------------------------------------------------------------------
RegisterCommand(Config.Command, function(_, args)
    if uiOpen then return end
    if not canUse() then return notify(locale('cl_no_perm'), 'error') end
    openUI(clampRadius(args[1]))
end, false)

RegisterCommand(Config.DrawCommand, function(_, args)
    if not canUse() then return notify(locale('cl_no_perm'), 'error') end
    if drawing and not args[1] then
        setDrawing(false)
        return notify(locale('cl_draw_off'))
    end
    setDrawing(true, args[1])
    notify(locale('cl_draw_on', math.floor(drawRadius)), 'success')
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.Command, locale('cl_cmd_open'), {
    { name = 'radius', help = locale('cl_cmd_radius_default', Config.DefaultRadius) } })
TriggerEvent('chat:addSuggestion', '/' .. Config.DrawCommand, locale('cl_cmd_draw'), {
    { name = 'radius', help = locale('cl_cmd_radius') } })

exports('GetNearbyImaps', function(radius) return scan(clampRadius(radius)) end)
