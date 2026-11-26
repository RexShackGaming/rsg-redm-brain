-- Quest journal, on-screen tracker, blips and kill detection.
-- Nothing here decides progress: the server does.
local RSGCore = exports['rsg-core']:GetCoreObject()

local data = { active = {}, completed = {} }
local blips = {}
local reported = {}    -- entity -> true
local journalOpen = false
local journalLoading = false
local killModels       -- set of model hashes wanted by open kill objectives, or nil
local trackerOn = GetResourceKvpInt('tracker_off') ~= 1 -- per-player setting (client KVP)
local pins             -- quest id -> true, loaded per character (client KVP)
local routed           -- quest id with a GPS route requested
local routeDrawn       -- signature of the route on the map, or nil

function IsJournalOpen() return journalOpen end

-------------------------------------------------
-- pinned quests and GPS route
-------------------------------------------------
local function pinKey()
    local playerData = RSGCore.Functions.GetPlayerData()
    local cid = playerData and playerData.citizenid
    return cid and ('pins_' .. cid)
end

local function loadPins()
    if pins then return pins end
    local k = pinKey()
    if not k then return {} end
    local raw = GetResourceKvpString(k)
    local ok, list = pcall(json.decode, raw or '[]')
    pins = {}
    if ok and type(list) == 'table' then
        for _, id in ipairs(list) do pins[id] = true end
    end
    return pins
end

local function savePins()
    local k = pinKey()
    if not k or not pins then return end
    local list = {}
    for id in pairs(pins) do list[#list + 1] = id end
    SetResourceKvp(k, json.encode(list))
end

local function activeQuest(id)
    for _, q in ipairs(data.active) do
        if q.id == id then return q end
    end
end

-- only ever clears a route this resource drew
local function clearRoute()
    if not routeDrawn then return end
    routeDrawn = nil
    ClearGpsMultiRoute()
end

local function updateRoute()
    local q = routed and activeQuest(routed)
    if routed and not q then routed = nil end
    local t = q and q.target
    if not t then return clearRoute() end -- kept: it returns when the quest has a place again
    local signature = ('%.1f:%.1f:%.1f'):format(t.x, t.y, t.z)
    if signature == routeDrawn then return end
    ClearGpsMultiRoute()
    StartGpsMultiRoute(joaat(Config.Quests.GpsColour), true, true)
    AddPointToGpsMultiRoute(t.x + 0.0, t.y + 0.0, t.z + 0.0)
    SetGpsMultiRouteRender(true)
    routeDrawn = signature
end

-- forget pins of quests that are no longer active
local function prunePins()
    local changed = false
    for id in pairs(loadPins()) do
        if not activeQuest(id) then pins[id], changed = nil, true end
    end
    if changed then savePins() end
end

local function localised()
    local out = { active = {}, completed = {} }
    for _, q in ipairs(data.active) do
        local objectives = {}
        for i, o in ipairs(q.objectives) do
            objectives[i] = { label = Text(o.label), current = o.current, count = o.count, done = o.done, open = o.open }
        end
        out.active[#out.active + 1] = {
            id = q.id, name = Text(q.name), description = Text(q.description),
            ready = q.ready and not q.autoComplete, objectives = objectives,
            reset = q.reset and locale('qj_' .. q.reset) or nil,
            pinned = loadPins()[q.id] == true, hasRoute = q.target ~= nil, routed = routed == q.id,
        }
    end
    for _, q in ipairs(data.completed) do
        out.completed[#out.completed + 1] = { id = q.id, name = Text(q.name), times = q.times }
    end
    return out
end

local function lang()
    local out = {}
    for _, k in ipairs({ 'journal', 'subtitle', 'active', 'completed', 'empty', 'abandon', 'abandon_confirm',
        'ready', 'times', 'cancel', 'confirm', 'pin', 'unpin', 'route', 'route_stop' }) do
        out[k] = locale('qj_' .. k)
    end
    return out
end

local hidden = false
local function pushTracker()
    local quests, pinned = localised().active, {}
    for _, q in ipairs(quests) do
        if q.pinned then pinned[#pinned + 1] = q end
    end
    SendNUIMessage({
        action = 'tracker', quests = #pinned > 0 and pinned or quests, lang = { ready = locale('qj_ready') },
        visible = trackerOn and not hidden, max = Config.Quests.TrackerMax, position = Config.Quests.TrackerPosition,
    })
end

local function removeBlips()
    for _, b in ipairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
end

local blipSignature = ''
local function refreshBlips()
    local wanted, signature = {}, {}
    for _, q in ipairs(data.active) do
        for _, o in ipairs(q.objectives) do
            if o.coords then
                wanted[#wanted + 1] = { coords = o.coords, label = Text(o.label) }
                signature[#signature + 1] = ('%s:%s:%.1f:%.1f'):format(q.id, o.id, o.coords.x, o.coords.y)
            end
        end
    end
    signature = table.concat(signature, '|')
    if signature == blipSignature then return end
    blipSignature = signature
    removeBlips()
    for _, w in ipairs(wanted) do
        local b = BlipAddForCoords(1664425300, w.coords.x, w.coords.y, w.coords.z)
        SetBlipSprite(b, joaat('blip_ambient_npc'), true)
        SetBlipScale(b, 0.2)
        Citizen.InvokeNative(0x9CB1A1623062F402, b, w.label) -- SetBlipName
        blips[#blips + 1] = b
    end
end

local function updateKillModels()
    local set
    for _, q in ipairs(data.active) do
        for _, o in ipairs(q.objectives) do
            for _, m in ipairs(o.models or {}) do
                set = set or {}
                set[joaat(m) & 0xFFFFFFFF] = true
            end
        end
    end
    killModels = set
end

local function apply(view)
    if not view then return end
    data = { active = view.active or {}, completed = view.completed or {} }
    prunePins()
    updateRoute()
    updateKillModels()
    refreshBlips()
    pushTracker()
    if journalOpen then SendNUIMessage({ action = 'journalData', data = localised() }) end
end

RegisterNetEvent('rsg-npcdialog:client:quests', apply)

function ClearQuests()
    data = { active = {}, completed = {} }
    pins, routed = nil, nil
    clearRoute()
    killModels = nil
    removeBlips()
    blipSignature = ''
    pushTracker()
end

local function request()
    RSGCore.Functions.TriggerCallback('rsg-npcdialog:server:getQuests', apply)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    request()
end)

CreateThread(function()
    Wait(2000)
    if LocalPlayer.state.isLoggedIn then request() end
end)

-------------------------------------------------
-- journal
-------------------------------------------------
function CloseJournal()
    if not journalOpen then return end
    journalOpen = false
    SendNUIMessage({ action = 'journalClose' })
    SetUIFocus(false)
end

local function openJournal()
    if journalOpen or journalLoading then return end
    if not LocalPlayer.state.isLoggedIn or IsDialogOpen() or IsEditorOpen() or IsPauseMenuActive() then return end
    journalLoading = true
    local view = RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:getQuests', 5000)
    journalLoading = false
    if not view then return Notify(locale('sv_failed'), 'error') end
    if journalOpen or IsDialogOpen() or IsEditorOpen() then return end
    apply(view)
    journalOpen = true
    SetUIFocus(true)
    SendNUIMessage({ action = 'journalOpen', data = localised(), lang = lang() })
end

RegisterCommand(Config.Quests.JournalCommand, function() CreateThread(openJournal) end, false)

RegisterCommand(Config.Quests.TrackerCommand, function()
    trackerOn = not trackerOn
    SetResourceKvpInt('tracker_off', trackerOn and 0 or 1)
    pushTracker()
end, false)

-- rebindable in the game's key settings (needs rsg-core 3.5.0+; the command always works)
CreateThread(function()
    pcall(function()
        exports['rsg-core']:RegisterKey('rsgnpcdialog_journal', locale('key_journal'), Config.Quests.JournalKey,
            function() CreateThread(openJournal) end)
    end)
end)

RegisterNUICallback('journalClose', function(_, cb)
    cb('ok')
    CloseJournal()
end)

RegisterNUICallback('journalAbandon', function(body, cb)
    cb('ok')
    RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:abandonQuest', 5000, body.id)
end)

local function redraw()
    pushTracker()
    if journalOpen then SendNUIMessage({ action = 'journalData', data = localised() }) end
end

RegisterNUICallback('journalPin', function(body, cb)
    cb('ok')
    if not journalOpen or not activeQuest(body.id) or not pinKey() then return end
    local set = loadPins()
    set[body.id] = (not set[body.id]) or nil
    savePins()
    redraw()
end)

RegisterNUICallback('journalRoute', function(body, cb)
    cb('ok')
    local q = journalOpen and activeQuest(body.id)
    if not q then return end
    if routed == q.id then
        routed = nil
    elseif q.target then
        routed = q.id
    end
    updateRoute()
    redraw()
end)

exports('OpenJournal', function() CreateThread(openJournal) end)

-------------------------------------------------
-- hide the tracker behind other screens
-------------------------------------------------
CreateThread(function()
    while true do
        Wait(500)
        local now = IsDialogOpen() or IsEditorOpen() or journalOpen or IsPauseMenuActive() or not LocalPlayer.state.isLoggedIn
        if now ~= hidden then
            hidden = now
            pushTracker()
        end
    end
end)

-------------------------------------------------
-- kill detection: only runs while a kill objective is open
-------------------------------------------------
CreateThread(function()
    local alive = {} -- entity -> true once seen living, so old bodies are never reported
    while true do
        local models = killModels
        if not models then
            alive, reported = {}, {}
            Wait(2000)
        else
            Wait(800)
            -- entity handles are reused: forget peds that no longer exist
            for ped in pairs(alive) do
                if not DoesEntityExist(ped) then alive[ped] = nil end
            end
            for ped in pairs(reported) do
                if not DoesEntityExist(ped) then reported[ped] = nil end
            end
            local me = PlayerPedId()
            local mount = GetMount(me)
            local pos = GetEntityCoords(me)
            for _, ped in ipairs(GetGamePool('CPed')) do
                if ped ~= me and not reported[ped] and models[GetEntityModel(ped) & 0xFFFFFFFF]
                    and #(pos - GetEntityCoords(ped)) <= Config.Quests.KillRange then
                    if not IsEntityDead(ped) then
                        alive[ped] = true
                    elseif alive[ped] then
                        local killer = GetPedSourceOfDeath(ped)
                        if (killer == me or (mount ~= 0 and killer == mount)) and NetworkGetEntityIsNetworked(ped) then
                            reported[ped] = true
                            TriggerServerEvent('rsg-npcdialog:server:questKill', NetworkGetNetworkIdFromEntity(ped))
                            Wait(800) -- the server accepts one report at a time
                        end
                    end
                end
            end
        end
    end
end)
