lib.locale()

-- Anim scene natives (names/usage from the decompiled show_nbx_* scripts)
local function CreateScene(dict, flags, playlist)
    return Citizen.InvokeNative(0x1FCA98E33C1437B3, dict, flags, playlist or 0, false, true, Citizen.ResultAsInteger()) -- _CREATE_ANIM_SCENE
end
local function LoadScene(s)            Citizen.InvokeNative(0xAF068580194D9DC7, s) end                       -- LOAD_ANIM_SCENE
local function IsSceneLoaded(s)        return Citizen.InvokeNative(0x477122B8D05E7968, s, true, false) end   -- IS_ANIM_SCENE_LOADED
local function SetSceneOrigin(s, c, r) Citizen.InvokeNative(0x020894BF17A02EF2, s, c.x, c.y, c.z, r.x, r.y, r.z, 2) end -- SET_ANIM_SCENE_ORIGIN
local function SetSceneEntity(s, n, e) Citizen.InvokeNative(0x8B720AD451CA2AB3, s, n, e, 0) end             -- SET_ANIM_SCENE_ENTITY
local function StartScene(s)           Citizen.InvokeNative(0xF4D94AF761768700, s) end                       -- START_ANIM_SCENE
local function SceneExists(s)          return s and s ~= 0 and Citizen.InvokeNative(0x25557E324489393C, s) end -- DOES_ANIM_SCENE_EXIST
local function SceneFinished(s)        return Citizen.InvokeNative(0xD8254CB2C586412B, s, false) end         -- IS_ANIM_SCENE_FINISHED
local function DeleteScene(s)          Citizen.InvokeNative(0x84EEDB2C6E650000, s) end                       -- DELETE_ANIM_SCENE
local function RequestPlaylist(s, n)   Citizen.InvokeNative(0xDF7B5144E25CD3FE, s, n) end                    -- REQUEST_ANIM_SCENE_PLAY_LIST
local function PlaylistLoaded(s, n)    return Citizen.InvokeNative(0x23E33CB9F4A3F547, s, n) end             -- (unnamed, used in show_nbx_cancan.c func_142)
local function SetPlaylist(s, n)       Citizen.InvokeNative(0x15598CFB25F3DC7E, s, n, true) end              -- SET_ANIM_SCENE_PLAY_LIST
local function PlaylistActive(s, n)    return Citizen.InvokeNative(0x1F0E401031E20146, s, n) end             -- _IS_ANIM_SCENE_PLAYBACK_LIST_PHASE_ACTIVE
local function ReleasePlaylist(s, n)   Citizen.InvokeNative(0xAE6ADA8FE7E84ACC, s, n) end                    -- _RELEASE_ANIM_SCENE_PLAY_LIST
local function ScenePhase(s)           return Citizen.InvokeNative(0x3FBC3F51BF12DFBF, s, Citizen.ResultAsFloat()) end -- GET_ANIM_SCENE_PHASE

local sellerPed, sellerBlip
-- one table per show run; `show` is the current run. A replaced/stopped run cleans up only its own entities.
local function newRun(active)
    return { active = active, peds = {}, props = {}, scene = nil, audience = {}, rope = nil, ropeAnchor = nil }
end
local show = newRun(false)

-- the curtain is persistent while you're near the theatre (as in the RDR2 theatre), not per show
local curtain = { obj = nil, scene = nil, playlist = nil }

local function loadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model, false)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function waitFor(fn, ms)
    local timeout = GetGameTimer() + (ms or 10000)
    while not fn() do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

-- request -> wait loaded -> set (same order as func_142/func_145 in the show_nbx_* scripts)
local function switchPlaylist(s, playlist)
    if not SceneExists(s) then return false end
    RequestPlaylist(s, playlist)
    waitFor(function() return PlaylistLoaded(s, playlist) end, 5000)
    SetPlaylist(s, playlist)
    return true
end

---------------------------------------------------------------------
-- curtain (show_nbx_cancan.c func_161/func_164 create, func_17 open/close)
---------------------------------------------------------------------
local function removeCurtain()
    if SceneExists(curtain.scene) then DeleteScene(curtain.scene) end
    if curtain.obj and DoesEntityExist(curtain.obj) then DeleteEntity(curtain.obj) end
    curtain = { obj = nil, scene = nil, playlist = nil }
end

local spawning = false
local function spawnCurtain()
    while spawning do Wait(50) end -- the proximity thread and the show thread can both call this
    if curtain.obj and DoesEntityExist(curtain.obj) and SceneExists(curtain.scene) then return true end
    spawning = true
    local ok = false
    removeCurtain()
    local c = Config.Curtain
    if loadModel(c.model) then
        curtain.obj = CreateObject(c.model, c.coords.x, c.coords.y, c.coords.z, false, false, false, false, true)
        SetModelAsNoLongerNeeded(c.model)
        curtain.scene = CreateScene(c.sceneDict, 0, c.closed)
        LoadScene(curtain.scene)
        if waitFor(function() return IsSceneLoaded(curtain.scene) end) then
            SetSceneEntity(curtain.scene, c.entity, curtain.obj)
            StartScene(curtain.scene)
            curtain.playlist = c.closed
            ok = true
        else
            removeCurtain()
        end
    end
    spawning = false
    return ok
end

-- request -> re-attach CURTAIN -> set -> wait until active -> release the previous playlist
local curtainBusy = false
local function playCurtain(playlist)
    while curtainBusy do Wait(50) end -- an old run closing and a new run opening must not overlap
    if not spawnCurtain() or curtain.playlist == playlist then return end
    curtainBusy = true
    local s, prev = curtain.scene, curtain.playlist
    RequestPlaylist(s, playlist)
    if waitFor(function() return PlaylistLoaded(s, playlist) end, 5000) then
        SetSceneEntity(s, Config.Curtain.entity, curtain.obj)
        SetPlaylist(s, playlist)
        waitFor(function() return PlaylistActive(s, playlist) end, 3000)
        if prev and PlaylistLoaded(s, prev) then ReleasePlaylist(s, prev) end
        curtain.playlist = playlist
    end
    curtainBusy = false
end

-- keep the curtain in place while the player is near the stage
CreateThread(function()
    while true do
        local near = #(GetEntityCoords(cache.ped) - Config.Stage) < Config.CurtainRange
        if near then spawnCurtain() elseif curtain.obj and not show.active then removeCurtain() end
        Wait(near and 5000 or 2000)
    end
end)

---------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------
local function cleanupShow(run)
    run = run or show
    run.active = false
    if SceneExists(run.scene) then DeleteScene(run.scene) end
    for _, ped in pairs(run.peds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    for _, obj in pairs(run.props) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    if run.rope and Citizen.InvokeNative(0xFD5448BE3111ED96, run.rope) then -- DOES_ROPE_EXIST
        Citizen.InvokeNative(0x52B4829281364649, Citizen.PointerValueIntInitialized(run.rope)) -- DELETE_ROPE
    end
    if run.ropeAnchor and DoesEntityExist(run.ropeAnchor) then DeleteEntity(run.ropeAnchor) end
    for _, ped in ipairs(run.audience) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    run.peds, run.props, run.audience, run.scene, run.rope, run.ropeAnchor = {}, {}, {}, nil, nil, nil
    if show == run then show = newRun(false) end
end

---------------------------------------------------------------------
-- NPC audience (seated with the same scenario + seat list as show_nbx_cancan.c)
---------------------------------------------------------------------
local function seatTaken(seat, reserved)
    if reserved and #(reserved.xyz - seat.xyz) < 0.6 then return true end
    for _, id in ipairs(GetActivePlayers()) do
        if #(GetEntityCoords(GetPlayerPed(id)) - seat.xyz) < 0.6 then return true end
    end
    return false
end

local function seatPed(model, seat)
    if not loadModel(model) then return nil end
    local ped = CreatePed(model, seat.x, seat.y, seat.z, seat.w, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    TaskStartScenarioAtPosition(ped, Config.Audience.scenario, seat.x, seat.y, seat.z, seat.w, -1, false, true, 0, 0.25, false)
    return ped
end

local function pickModel(a, seat)
    local model = Citizen.InvokeNative(0x6B12ED8C77E8567B, a.popSet, 0, -156825994, false, true, seat.x, seat.y, seat.z, Citizen.ResultAsInteger()) -- GET_RANDOM_MODEL_FROM_POPULATION_SET
    if not model or model == 0 or not IsModelValid(model) then
        model = a.fallbackModels[math.random(#a.fallbackModels)]
    end
    return model
end

local function spawnAudience(run, data)
    local a = Config.Audience
    local v = data.volunteer
    -- the volunteer sits in the audience but belongs to the act, so they're always spawned
    -- and stored with the performers (attached to the scene with the rest of run.peds)
    if v and not seatTaken(v.seat) then
        run.peds[v.entity] = seatPed(v.model, v.seat)
    end
    if not a or not a.enabled then return end
    for _, seat in ipairs(a.seats) do
        if not run.active then return end
        if math.random() <= a.fill and not seatTaken(seat, v and v.seat) then
            local ped = seatPed(pickModel(a, seat), seat)
            if ped then run.audience[#run.audience + 1] = ped end
        end
    end
end

---------------------------------------------------------------------
-- rope (same steps as show_nbx_escapenoose.c: anchor -> freeze -> _ADD_ROPE_2 -> attach)
---------------------------------------------------------------------
local function spawnRope(run, r)
    local target = run.props[r.prop]
    if not target or not DoesEntityExist(target) or not loadModel(r.anchorModel) then return end
    local a = r.anchorCoords
    run.ropeAnchor = CreateObject(r.anchorModel, a.x, a.y, a.z, false, false, false, false, true)
    SetModelAsNoLongerNeeded(r.anchorModel)
    waitFor(function() return DoesEntityHavePhysics(run.ropeAnchor) end, 3000)
    SetEntityCoords(run.ropeAnchor, a.x, a.y, a.z, true, false, true, true)
    FreezeEntityPosition(run.ropeAnchor, true)
    local c = r.coords
    run.rope = Citizen.InvokeNative(0xE9C59F6809373A99, c.x, c.y, c.z, 0.0, 0.0, 0.0, r.length, r.ropeType, false, -1, -1.0, Citizen.ResultAsInteger()) -- _ADD_ROPE_2
    Citizen.InvokeNative(0x462FF2A432733A44, run.rope, run.ropeAnchor, target, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0) -- _ATTACH_ENTITIES_TO_ROPE_2
    Citizen.InvokeNative(0x522FA3F490E2F7AC, run.rope, 1, 1) -- unnamed, called right after attaching in the script
end

---------------------------------------------------------------------
-- show playback (all entities are local to this client)
---------------------------------------------------------------------
RegisterNetEvent('rsg-theatre:client:playShow', function(index)
    local data = Config.Shows[index]
    if not data then return end
    if show.active then show.active = false end -- a new show replaces the old one; its thread cleans itself up
    local run = newRun(true)
    show = run

    -- every blocking step can be interrupted by a stop or a newer show
    local function aborted()
        if run.active then return false end
        cleanupShow(run)
        return true
    end

    lib.notify({ title = locale('cl_title'), description = locale('cl_show_starting', locale('show_' .. data.id)), type = 'inform' })

    -- curtain should already be there (closed); make sure
    local c = Config.Curtain
    spawnCurtain()
    spawnAudience(run, data)
    if aborted() then return end

    -- performers and props start backstage; the scene walks them on
    local spawn = Config.Backstage
    for name, model in pairs(data.peds) do
        if loadModel(model) then
            local ped = CreatePed(model, spawn.x, spawn.y, spawn.z, 0.0, false, false, false, false)
            Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetEntityInvincible(ped, true)
            run.peds[name] = ped
            SetModelAsNoLongerNeeded(model)
        end
    end
    for name, model in pairs(data.props) do
        if loadModel(model) then
            run.props[name] = CreateObject(model, spawn.x, spawn.y, spawn.z, false, false, false, false, true)
            SetModelAsNoLongerNeeded(model)
        end
    end
    if aborted() then return end

    -- performance scene (same order as show_nbx_cancan.c: create -> origin/entities -> load -> start)
    run.scene = CreateScene(data.scene, data.flags or 2, data.playlist)
    if data.origin then SetSceneOrigin(run.scene, data.origin.coords, data.origin.rot) end -- nil = origin baked into the scene
    for name, ent in pairs(run.peds) do SetSceneEntity(run.scene, name, ent) end
    for name, ent in pairs(run.props) do SetSceneEntity(run.scene, name, ent) end
    LoadScene(run.scene)

    if not waitFor(function() return not run.active or IsSceneLoaded(run.scene) end, 15000) or aborted() then
        if run.active then
            lib.notify({ title = locale('cl_title'), description = locale('cl_show_failed'), type = 'error' })
            cleanupShow(run)
            TriggerServerEvent('rsg-theatre:server:showFinished')
        end
        return
    end

    if data.rope then spawnRope(run, data.rope) end
    playCurtain(c.open)
    Wait(Config.CurtainOpenDelay)
    if aborted() then return end
    StartScene(run.scene)

    -- optional follow-on playlists: move to the next one as the current one ends
    -- (the show_nbx_* scripts switch at phase >= 0.99, then wait for the new playlist to go active)
    local sequence = data.sequence or {}
    local step, waitingFor = 1, nil
    local completed = false
    local endTime = GetGameTimer() + (Config.MaxShowLength * 1000)
    while run.active and GetGameTimer() < endTime do
        Wait(#sequence > 0 and 100 or 500)
        if not SceneExists(run.scene) then break end
        if #(GetEntityCoords(cache.ped) - Config.Stage) > Config.AudienceRadius * 2 then break end
        if waitingFor then
            if PlaylistActive(run.scene, waitingFor) then waitingFor = nil end
        elseif step <= #sequence then
            if ScenePhase(run.scene) >= 0.99 then
                waitingFor = sequence[step]
                switchPlaylist(run.scene, waitingFor)
                step = step + 1
            end
        elseif SceneFinished(run.scene) or ScenePhase(run.scene) >= 0.999 then
            completed = true
            break
        end
    end

    -- replaced by a newer show: just remove our entities, the new run owns the curtain
    if show ~= run then cleanupShow(run) return end

    if run.active then
        playCurtain(c.close)
        Wait(Config.CurtainCloseDelay)
        if completed then
            lib.notify({ title = locale('cl_title'), description = locale('cl_show_over'), type = 'success' })
        end
    end
    cleanupShow(run)
    if curtain.playlist ~= c.closed and curtain.playlist ~= c.close then
        playCurtain(c.close) -- stopped early: still bring the curtain down
    end
    TriggerServerEvent('rsg-theatre:server:showFinished')
end)

-- admin forced a new show: end this one straight away (no curtain call)
RegisterNetEvent('rsg-theatre:client:stopShow', function()
    show.active = false
end)

---------------------------------------------------------------------
-- ticket seller + NUI playbill
---------------------------------------------------------------------
local function openPlaybill()
    local bill = lib.callback.await('rsg-theatre:server:getPlaybill', false)
    if not bill then return end
    if show.active then return end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = bill,
        locale = {
            title = locale('ui_title'), subtitle = locale('ui_subtitle'),
            next = locale('ui_next_show'),
            starts = bill.minutes > 0 and locale('ui_starts_in', bill.minutes) or locale('ui_starts_soon'),
            running = locale('ui_running'), price = locale('ui_price'),
            buy = locale('ui_buy'), owned = locale('ui_owned'), close = locale('ui_close'),
            currency = locale('ui_currency'),
        }
    })
end

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buy', function(_, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('rsg-theatre:server:buyTicket')
    cb('ok')
end)

CreateThread(function()
    local s = Config.TicketSeller
    sellerBlip = BlipAddForCoords(1664425300, s.coords.x, s.coords.y, s.coords.z)
    SetBlipSprite(sellerBlip, s.blip.sprite, true)
    Citizen.InvokeNative(0x9CB1A1623062F402, sellerBlip, locale('blip_name')) -- _SET_BLIP_NAME

    if not loadModel(s.model) then return end
    sellerPed = CreatePed(s.model, s.coords.x, s.coords.y, s.coords.z - 1.0, s.coords.w, false, false, false, false)
    Citizen.InvokeNative(0x283978A15512B2FE, sellerPed, true)
    SetEntityInvincible(sellerPed, true)
    SetBlockingOfNonTemporaryEvents(sellerPed, true)
    FreezeEntityPosition(sellerPed, true)
    SetModelAsNoLongerNeeded(s.model)

    exports.ox_target:addLocalEntity(sellerPed, {
        {
            name = 'rsg_theatre_ticket',
            icon = 'fa-solid fa-ticket',
            label = locale('cl_target'),
            distance = s.targetDistance,
            onSelect = openPlaybill,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    cleanupShow()
    removeCurtain()
    if sellerPed and DoesEntityExist(sellerPed) then
        exports.ox_target:removeLocalEntity(sellerPed, 'rsg_theatre_ticket')
        DeleteEntity(sellerPed)
    end
    if sellerBlip then RemoveBlip(sellerBlip) end
end)
