-- Conversation: NUI, camera and safety checks
local RSGCore = exports['rsg-core']:GetCoreObject()

local current        -- { npcId, session, cam, hidPlayer, health }
local opening = false
local uiFocus = false
local blocking = false

-------------------------------------------------
-- NUI focus (push-to-talk keeps working)
-------------------------------------------------
-- runs only while a UI is open, and blocks controls from the very first frame
local function blockControls()
    if blocking then return end
    blocking = true
    CreateThread(function()
        while uiFocus do
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, c in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, c, true)
                EnableControlAction(1, c, true)
                EnableControlAction(2, c, true)
            end
            Wait(0)
        end
        blocking = false
    end)
end

function SetUIFocus(enable)
    uiFocus = enable
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
            blockControls()
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

function IsDialogOpen() return current ~= nil or opening end

-------------------------------------------------
-- camera
-------------------------------------------------
local function startCamera(state, npcPed)
    if not Config.Camera.enabled or not npcPed or not DoesEntityExist(npcPed) then return end
    local o, l = Config.Camera.offset, Config.Camera.lookAt
    local from = GetOffsetFromEntityInWorldCoords(npcPed, o.x, o.y, o.z)
    local at = GetOffsetFromEntityInWorldCoords(npcPed, l.x, l.y, l.z)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, from.x, from.y, from.z)
    SetCamFov(cam, Config.Camera.fov)
    PointCamAtCoord(cam, at.x, at.y, at.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, Config.Camera.easeMs, true, true)
    state.cam = cam
    if Config.Camera.hidePlayer then
        state.hidPlayer = PlayerPedId()
        SetEntityAlpha(state.hidPlayer, 0, false)
    end
end

local function stopCamera(state, instant)
    if state.hidPlayer and DoesEntityExist(state.hidPlayer) then ResetEntityAlpha(state.hidPlayer) end
    if state.cam then
        RenderScriptCams(false, not instant, Config.Camera.easeMs, true, true)
        SetCamActive(state.cam, false)
        DestroyCam(state.cam, false)
    end
end

-------------------------------------------------
-- open / close
-------------------------------------------------
local function localise(view)
    view.name, view.title, view.text = Text(view.name), Text(view.title), Text(view.text)
    for _, c in ipairs(view.choices) do c.label = Text(c.label) end
    return view
end

function CloseDialog(instant)
    local state = current
    if not state then return end
    current = nil
    SendNUIMessage({ action = 'dialogClose' })
    SetUIFocus(false)
    stopCamera(state, instant)
    if Config.HideRadar then DisplayRadar(true) end
    TriggerServerEvent('rsg-npcdialog:server:closed', state.session)
    TriggerEvent('rsg-npcdialog:client:closed', state.npcId)
end

local function showView(npcId, view)
    CloseDialog(true)
    CloseEditor()
    CloseJournal()
    local state = { npcId = npcId, session = view.session, health = GetEntityHealth(PlayerPedId()) }
    current = state
    local ped = GetNPCPed(npcId)
    startCamera(state, ped)
    if Config.HideRadar then DisplayRadar(false) end
    SetUIFocus(true)
    SendNUIMessage({
        action = 'dialogOpen', view = localise(view), typeSpeed = Config.TypeSpeed,
        lang = { leave = locale('ui_leave'), skip = locale('ui_skip'), locked = locale('ui_locked') },
    })
    TriggerEvent('rsg-npcdialog:client:opened', npcId)

    -- leave the conversation if something happens to the player
    CreateThread(function()
        local startPos = GetEntityCoords(PlayerPedId())
        while current == state do
            local me = PlayerPedId()
            if IsEntityDead(me) or GetEntityHealth(me) < state.health or #(GetEntityCoords(me) - startPos) > 3.0 then
                CloseDialog()
                break
            end
            state.health = GetEntityHealth(me)
            Wait(200)
        end
    end)
end

function OpenDialog(npcId)
    if IsDialogOpen() or IsEditorOpen() or IsJournalOpen() then return false end
    local me = PlayerPedId()
    if IsEntityDead(me) or IsPedOnMount(me) or IsPedInAnyVehicle(me, false) then return false end
    opening = true
    local view = RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:open', 5000, npcId)
    opening = false
    if not view then return false end
    showView(npcId, view)
    return true
end

RegisterNetEvent('rsg-npcdialog:client:show', showView)

-- the server ended the conversation (NPC edited, removed, or closed by another script)
RegisterNetEvent('rsg-npcdialog:client:close', function() CloseDialog() end)

-------------------------------------------------
-- NUI callbacks
-------------------------------------------------
RegisterNUICallback('dialogChoose', function(data, cb)
    cb('ok')
    local state = current
    if not state then return end
    local result = RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:choose', 8000, state.session, tonumber(data.index))
    if current ~= state then return end
    if not result then
        SendNUIMessage({ action = 'dialogUnlock' }) -- too fast or timed out: let them try again
    elseif result.close then
        CloseDialog()
    else
        SendNUIMessage({ action = 'dialogNode', view = localise(result.view) })
    end
end)

RegisterNUICallback('dialogClose', function(_, cb)
    cb('ok')
    CloseDialog()
end)

exports('Open', OpenDialog)
exports('IsOpen', IsDialogOpen)
exports('Close', function() CloseDialog() end)
