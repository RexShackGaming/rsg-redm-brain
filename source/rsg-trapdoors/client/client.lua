local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local ANIM_DICT = 'mech_cover@env@doors@unlocked@generic@base@push_return@bow@left@no_lean'

-- runtime state per door id: { entity, open, progress, animToken, animating, owner }
local doors = {}
local modelToIds = {}

for id, cfg in pairs(Config.Trapdoors) do
    local open = GlobalState['trapdoor:' .. id] == true
    doors[id] = {
        entity = 0, open = open, progress = open and 1.0 or 0.0, animToken = 0, animating = false,
        owner = GlobalState['trapdoorCode:' .. id] or false, -- owner citizenid when a passcode is set
    }
    local hash = joaat(cfg.model)
    modelToIds[hash] = modelToIds[hash] or {}
    modelToIds[hash][#modelToIds[hash] + 1] = id
end

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function lerp(a, b, t) return a + (b - a) * t end

local function lerpAngle(a, b, t)
    local delta = (b - a + 180.0) % 360.0 - 180.0
    return a + delta * t
end

local function findEntity(cfg)
    local p = cfg.closedPosition
    local ent = GetClosestObjectOfType(p.x, p.y, p.z, 3.0, joaat(cfg.model), false, false, false)
    return DoesEntityExist(ent) and ent or 0
end

-- pose is always derived from config + progress (0 = closed, 1 = open).
-- Never read rotation back from the entity: at -90 pitch GetEntityRotation
-- returns gimbal-locked angles, which made the door twist when closing.
local function applyPose(ent, cfg, p)
    local a, b = cfg.closedPosition, cfg.openPosition
    local ra, rb = cfg.closedRotation, cfg.openRotation
    SetEntityCoordsNoOffset(ent, lerp(a.x, b.x, p), lerp(a.y, b.y, p), lerp(a.z, b.z, p), false, false, false)
    SetEntityRotation(ent, lerpAngle(ra.x, rb.x, p), lerpAngle(ra.y, rb.y, p), lerpAngle(ra.z, rb.z, p), 2, true)
end

local function placeInstant(id)
    local d = doors[id]
    d.progress = d.open and 1.0 or 0.0
    if d.entity ~= 0 then applyPose(d.entity, Config.Trapdoors[id], d.progress) end
end

local function animate(id)
    local d, cfg = doors[id], Config.Trapdoors[id]
    local ent = d.entity
    if ent == 0 or not DoesEntityExist(ent) then return end

    d.animToken = d.animToken + 1
    local token = d.animToken
    d.animating = true

    local from = d.progress
    local to = d.open and 1.0 or 0.0
    local duration = math.max(Config.MoveDuration * math.abs(to - from), 1)
    local startTime = GetGameTimer()

    CreateThread(function()
        while true do
            if d.animToken ~= token or not DoesEntityExist(ent) then return end
            local t = math.min((GetGameTimer() - startTime) / duration, 1.0)
            local e = t * t * (3.0 - 2.0 * t) -- smoothstep
            d.progress = lerp(from, to, e)
            applyPose(ent, cfg, d.progress)
            if t >= 1.0 then break end
            Wait(0)
        end
        d.animating = false
    end)
end

-- resolve which configured door a targeted entity belongs to
local function idFromEntity(entity)
    local ids = modelToIds[GetEntityModel(entity)]
    if not ids then return end
    for i = 1, #ids do
        if doors[ids[i]].entity == entity then return ids[i] end
    end
    -- entity not cached yet (just streamed in) - match by proximity
    local coords = GetEntityCoords(entity)
    for i = 1, #ids do
        if #(coords - Config.Trapdoors[ids[i]].closedPosition) < 3.0 then return ids[i] end
    end
end

---------------------------------------------------------------------
-- state sync (server -> clients via GlobalState)
---------------------------------------------------------------------
for id in pairs(Config.Trapdoors) do
    AddStateBagChangeHandler('trapdoor:' .. id, 'global', function(_, _, value)
        local d = doors[id]
        d.open = value == true
        if d.entity ~= 0 then animate(id) end
    end)
    AddStateBagChangeHandler('trapdoorCode:' .. id, 'global', function(_, _, value)
        doors[id].owner = value or false
    end)
end

-- keep entity handles fresh as props stream in/out and snap them to the synced state
CreateThread(function()
    while true do
        local pCoords = GetEntityCoords(PlayerPedId())
        for id, cfg in pairs(Config.Trapdoors) do
            local d = doors[id]
            if #(pCoords - cfg.closedPosition) <= Config.StreamDistance then
                local ent = findEntity(cfg)
                if ent ~= d.entity then
                    d.entity = ent
                    if ent ~= 0 then placeInstant(id) end
                end
            elseif d.entity ~= 0 then
                d.entity = 0
            end
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------
-- passcode keypad (NUI)
---------------------------------------------------------------------
local keypadDoor -- id of the door the keypad is open for

local uiStrings = {
    subtitle = locale('ui_subtitle'),
    enter = locale('ui_enter'), set = locale('ui_set'), confirm = locale('ui_confirm'),
    current = locale('ui_current'), new = locale('ui_new'), confirmNew = locale('ui_confirm_new'),
    btnConfirm = locale('ui_btn_confirm'), btnCancel = locale('ui_btn_cancel'),
    hint = locale('ui_hint'), mismatch = locale('code_mismatch'),
    clear = locale('ui_key_clear'), close = locale('ui_btn_close'),
}

local function playPushAnim()
    if lib.requestAnimDict(ANIM_DICT, 2000) then
        TaskPlayAnim(cache.ped, ANIM_DICT, 'open', 8.0, -8.0, -1, 0, 0, false, false, false)
        RemoveAnimDict(ANIM_DICT)
    end
end

local function closeKeypad()
    keypadDoor = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openKeypad(id, mode)
    keypadDoor = id
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        mode = mode, -- 'unlock' | 'set' | 'change'
        title = locale(Config.Trapdoors[id].label or id),
        strings = uiStrings,
    })
end

RegisterNUICallback('close', function(_, cb)
    closeKeypad()
    cb(1)
end)

RegisterNUICallback('submit', function(data, cb)
    local id = keypadDoor
    if not id then return cb({ ok = false }) end

    local ok, msg
    if data.mode == 'unlock' then
        ok, msg = lib.callback.await('rsg-trapdoors:server:open', false, id, data.code)
    elseif data.mode == 'set' then
        ok, msg = lib.callback.await('rsg-trapdoors:server:setCode', false, id, data.newCode)
    elseif data.mode == 'change' then
        ok, msg = lib.callback.await('rsg-trapdoors:server:changeCode', false, id, data.code, data.newCode)
    end

    cb({ ok = ok == true, message = msg })

    if ok then
        closeKeypad()
        if data.mode == 'unlock' then
            playPushAnim()
        elseif msg then
            lib.notify({ title = locale('notify_title'), description = msg, type = 'success', duration = 4000 })
        end
    end
end)

---------------------------------------------------------------------
-- interaction
---------------------------------------------------------------------
local function myCitizenId()
    local pd = RSGCore.Functions.GetPlayerData()
    return pd and pd.citizenid
end

local function openDoor(data)
    local id = idFromEntity(data.entity)
    if not id or doors[id].animating then return end

    if doors[id].owner then
        return openKeypad(id, 'unlock')
    end

    local ok, msg = lib.callback.await('rsg-trapdoors:server:open', false, id)
    if ok then
        playPushAnim()
    elseif msg then
        lib.notify({ title = locale('notify_title'), description = msg, type = 'error', duration = 4000 })
    end
end

local function closeDoor(data)
    local id = idFromEntity(data.entity)
    if not id or doors[id].animating then return end
    playPushAnim()
    TriggerServerEvent('rsg-trapdoors:server:close', id)
end

local function doorFor(entity)
    local id = idFromEntity(entity)
    return id and doors[id], id
end

local models = {}
for hash in pairs(modelToIds) do models[#models + 1] = hash end

local optionNames = { 'rsg_trapdoor_open', 'rsg_trapdoor_close', 'rsg_trapdoor_setcode', 'rsg_trapdoor_changecode' }

exports.ox_target:addModel(models, {
    {
        name = optionNames[1],
        icon = 'fas fa-door-open',
        label = locale('target_open'),
        distance = 2.0,
        canInteract = function(entity)
            local d = doorFor(entity)
            return d and not d.animating and not d.open
        end,
        onSelect = openDoor,
    },
    {
        name = optionNames[2],
        icon = 'fas fa-door-closed',
        label = locale('target_close'),
        distance = 2.0,
        canInteract = function(entity)
            local d = doorFor(entity)
            return d and not d.animating and d.open
        end,
        onSelect = closeDoor,
    },
    {
        name = optionNames[3],
        icon = 'fas fa-lock',
        label = locale('target_set_code'),
        distance = 2.0,
        canInteract = function(entity)
            local d = doorFor(entity)
            return d and not d.owner
        end,
        onSelect = function(data)
            local _, id = doorFor(data.entity)
            if id then openKeypad(id, 'set') end
        end,
    },
    {
        name = optionNames[4],
        icon = 'fas fa-key',
        label = locale('target_change_code'),
        distance = 2.0,
        canInteract = function(entity)
            local d = doorFor(entity)
            return d and d.owner and d.owner == myCitizenId()
        end,
        onSelect = function(data)
            local _, id = doorFor(data.entity)
            if id then openKeypad(id, 'change') end
        end,
    },
})

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if keypadDoor then SetNuiFocus(false, false) end
    exports.ox_target:removeModel(models, optionNames)
    for id, d in pairs(doors) do
        d.animToken = d.animToken + 1
        d.open = false
        placeInstant(id)
    end
end)
