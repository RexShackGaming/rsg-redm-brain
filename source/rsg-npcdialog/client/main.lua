-- NPC list, local peds, blips and targeting
local RSGCore = exports['rsg-core']:GetCoreObject()

NPCList = {}        -- id -> public npc data
local spawned = {}  -- id -> { ped = entity }
local blips = {}
local markers = {}  -- id -> 'offer' | 'turnin' (decided by the server)

function Notify(desc, ntype)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

-- '@key' = locale string, anything else is shown as written
function Text(s)
    if type(s) == 'string' and s:sub(1, 1) == '@' then return locale(s:sub(2)) end
    return s
end

local function loadModel(model)
    local hash = joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

function CreateDialogPed(data)
    local hash = loadModel(data.model)
    if not hash then
        print(('[rsg-npcdialog] invalid or unloadable model "%s"'):format(tostring(data.model)))
        return nil
    end
    local c = data.coords
    local ped = CreatePed(hash, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return nil end
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    FreezeEntityPosition(ped, true)
    return ped
end

function GetNPCPed(id)
    return spawned[id] and spawned[id].ped
end

local function markerText(id)
    local m = markers[id]
    return m and locale('marker_' .. m)
end

local function addTarget(id, ped, data)
    local label = locale('target_talk', Text(data.name))
    local marker = markerText(id)
    if marker then label = ('%s (%s)'):format(label, marker) end
    exports['rsg-target']:addLocalEntity(ped, {{
        name = 'rsg-npcdialog:talk',
        icon = markers[id] and 'fa-solid fa-circle-exclamation' or 'fa-solid fa-comments',
        label = label,
        distance = data.distance,
        canInteract = function() return not IsDialogOpen() end,
        onSelect = function() OpenDialog(id) end,
    }})
end

local function despawn(id)
    local e = spawned[id]
    if not e then return end
    spawned[id] = nil
    if e.ped and DoesEntityExist(e.ped) then
        exports['rsg-target']:removeLocalEntity(e.ped, 'rsg-npcdialog:talk')
        DeletePed(e.ped)
    end
end

local function spawn(id, data)
    local entry = {}
    spawned[id] = entry -- reserve the slot while the model loads
    local ped = CreateDialogPed(data)
    -- the list may have changed while loading
    if spawned[id] ~= entry or NPCList[id] ~= data then
        if ped then DeletePed(ped) end
        if spawned[id] == entry then spawned[id] = nil end
        return
    end
    if not ped then
        -- the empty slot stays, so it is not retried every tick; cleared when the player walks away
        return
    end
    entry.ped = ped
    if data.scenario then
        TaskStartScenarioInPlace(ped, joaat(data.scenario), 0, true, false, false, false)
    end
    addTarget(id, ped, data)
end

local function removeBlips()
    for _, b in ipairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
end

local function refreshNpcBlips()
    removeBlips()
    for id, n in pairs(NPCList) do
        local marker = markers[id]
        if n.blip or (marker and Config.Markers.ShowBlip) then
            local b = BlipAddForCoords(1664425300, n.coords.x, n.coords.y, n.coords.z)
            SetBlipSprite(b, joaat(n.blip and n.blip.sprite or 'blip_ambient_npc'), true)
            SetBlipScale(b, 0.2)
            local name = Text(n.name)
            if marker then
                BlipAddModifier(b, joaat(marker == 'turnin' and Config.Markers.TurnInColour or Config.Markers.OfferColour))
                name = ('%s - %s'):format(name, markerText(id))
            end
            Citizen.InvokeNative(0x9CB1A1623062F402, b, name) -- SetBlipName
            blips[#blips + 1] = b
        end
    end
end

RegisterNetEvent('rsg-npcdialog:client:markers', function(new)
    local old = markers
    markers = new or {}
    local changed = false
    for id, e in pairs(spawned) do
        if old[id] ~= markers[id] and e.ped and DoesEntityExist(e.ped) and NPCList[id] then
            exports['rsg-target']:removeLocalEntity(e.ped, 'rsg-npcdialog:talk')
            addTarget(id, e.ped, NPCList[id])
        end
    end
    for id, m in pairs(markers) do
        if old[id] ~= m then changed = true end
    end
    for id in pairs(old) do
        if not markers[id] then changed = true end
    end
    if changed then refreshNpcBlips() end
end)

local function same(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function applyList(list)
    local new = {}
    for _, n in ipairs(list or {}) do new[n.id] = n end
    -- only respawn NPCs that changed, so other players' conversations are not disturbed
    local stale = {}
    for id in pairs(spawned) do
        if not same(new[id], NPCList[id]) then
            stale[#stale + 1] = id
        else
            new[id] = NPCList[id] -- keep the same table for a spawn that is still loading
        end
    end
    for _, id in ipairs(stale) do despawn(id) end
    NPCList = new

    refreshNpcBlips()
end

RegisterNetEvent('rsg-npcdialog:client:sync', applyList)

local function requestList()
    RSGCore.Functions.TriggerCallback('rsg-npcdialog:server:getNPCs', applyList)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', requestList)

CreateThread(function()
    Wait(1000)
    if LocalPlayer.state.isLoggedIn then requestList() end

    while true do
        local sleep = 1000
        local pos = GetEntityCoords(PlayerPedId())
        local loggedIn = LocalPlayer.state.isLoggedIn
        for id, n in pairs(NPCList) do
            local dist = #(pos - vector3(n.coords.x, n.coords.y, n.coords.z))
            if loggedIn and dist < Config.SpawnDistance then
                if not spawned[id] then CreateThread(function() spawn(id, n) end) end
                sleep = 500
            elseif spawned[id] and (not loggedIn or dist > Config.SpawnDistance + 5.0) then
                despawn(id)
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    CloseDialog(true)
    CloseEditor()
    CloseJournal()
    ClearQuests()
    markers = {}
    applyList({})
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CloseDialog(true)
    CloseEditor()
    CloseJournal()
    ClearQuests()
    local ids = {}
    for id in pairs(spawned) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do despawn(id) end
    removeBlips()
end)
