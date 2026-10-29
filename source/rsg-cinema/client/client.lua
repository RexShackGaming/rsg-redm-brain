lib.locale()

-- config labels are locale keys: translate them once
for _, f in ipairs(Config.Films) do f.label = locale(f.label) end
for _, c in pairs(Config.Cinemas) do c.label = locale(c.label) end

-- Native hashes from rsg-redm-brain natives/db (GRAPHICS / HUD / ENTITY / OBJECT)
local N = {
    SET_TV_CHANNEL             = 0x593FAF7FC9401A56,
    SET_TV_CHANNEL_PLAYLIST    = 0xDEC6B25F5DC8925B,
    DRAW_TV_CHANNEL            = 0xC0A145540254A840,
    SET_TV_VOLUME              = 0x73A97068787D7231,
    SET_TV_AUDIO_FRONTEND      = 0x64437C98FCC5F291,
    ATTACH_TV_AUDIO_TO_ENTITY  = 0x40866A418EB8EFDE,
    IS_TVSHOW_CURRENTLY_PLAYING= 0x4D562223E0EB65F3,
    DRAW_ORDER_FLAG            = 0x32DE2BFFDA43E62A,
    REGISTER_NAMED_RT          = 0x98AF2BB6F62BD588,
    LINK_NAMED_RT              = 0x2F506B8556242DDB,
    IS_NAMED_RT_REGISTERED     = 0x3EE32F7964C40FE6,
    IS_NAMED_RT_LINKED         = 0x707032835FF09AE7,
    GET_NAMED_RT_RENDER_ID     = 0xB6762A85EE29AA60,
    RELEASE_NAMED_RT           = 0x0E692EE61761361F,
    SET_TEXT_RENDER_ID         = 0xE550CDE128D56757,
    PIN_CLOSEST_MAP_ENTITY     = 0x6F3068258A499E52,
    IS_MAP_ENTITY_PINNED       = 0x1FF441D7954F8709,
    GET_PINNED_MAP_ENTITY      = 0x4735E2A4BB83D9DA,
    UNPIN_MAP_ENTITY           = 0xD2B9C78537ED5759,
    GET_OBJECT_FROM_ENTITY     = 0x280BBE5601EAA983,
    SET_LIGHT_INTENSITY_OBJ    = 0xF49574E2332A8F06,
    LINK_RT_TO_LIGHT_OBJ       = 0x04D1D4E411CE52D0, -- named _SET_LIGHT_SCATTERING_DISABLED_FOR_OBJECT; Rockstar passes the render id
    BLIP_ADD_FOR_COORDS        = 0x554D9D53F696D002,
    SET_BLIP_SPRITE            = 0x74F74D3207ED525C,
    SET_BLIP_NAME              = 0x9CB1A1623062F402,
    ACTIVATE_ENTITY_SET        = 0x174D0AAB11CED739,
    DEACTIVATE_ENTITY_SET      = 0x33B81A2C07A51FFF,
}
local END_MARKER = joaat('END_OF_MOVIE_MARKER')

local peds, blips, points = {}, {}, {}
local uiOpen, uiCinema = false, nil
local active = nil -- { id, cfg, playlist, ticket, renderId, pin, obj, screenObj, lights, started }

---------------------------------------------------------------- film playback
local function setEntitySets(cfg, open)
    if not cfg.entitySets then return end
    local interior = GetInteriorAtCoords(cfg.centre.x, cfg.centre.y, cfg.centre.z)
    if not IsValidInterior(interior) then return end
    local on, off = cfg.entitySets.open, cfg.entitySets.closed
    if not open then on, off = off, on end
    Citizen.InvokeNative(N.DEACTIVATE_ENTITY_SET, interior, off, true)
    Citizen.InvokeNative(N.ACTIVATE_ENTITY_SET, interior, on, 0)
end

-- show_movie_magic_lantern.c func_264: spawn the hidden render-target object the film is linked to
local function spawnScreenObject(cfg)
    local model = joaat(cfg.linkModel)
    if not lib.requestModel(model, 10000) then
        print(('[rsg-cinema] could not load screen model %s'):format(cfg.linkModel))
        return nil
    end
    local sc = cfg.screen
    local obj = CreateObjectNoOffset(model, sc.x, sc.y, sc.z, false, false, false, true)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return nil end
    SetEntityRotation(obj, 0.0, 0.0, sc.w, 2, true)
    SetEntityVisible(obj, false)
    SetEntityDynamic(obj, false)
    FreezeEntityPosition(obj, true)
    return obj
end

-- show_movie_magic_lantern.c func_262
local function setupScreen(cfg, me)
    if not me.screenObj or not DoesEntityExist(me.screenObj) then
        me.screenObj = spawnScreenObject(cfg)
        if not me.screenObj then return nil end
    end
    if not Citizen.InvokeNative(N.IS_NAMED_RT_REGISTERED, cfg.renderTarget) then
        Citizen.InvokeNative(N.REGISTER_NAMED_RT, cfg.renderTarget, false)
        Citizen.InvokeNative(N.LINK_NAMED_RT, joaat(cfg.linkModel))
        if not Citizen.InvokeNative(N.IS_NAMED_RT_LINKED, joaat(cfg.linkModel)) then
            Citizen.InvokeNative(N.RELEASE_NAMED_RT, cfg.renderTarget)
            if Config.Debug then print('[rsg-cinema] render target failed to link for', cfg.label) end
            return nil
        end
    end
    local renderId = Citizen.InvokeNative(N.GET_NAMED_RT_RENDER_ID, cfg.renderTarget, Citizen.ResultAsInteger())
    local p = cfg.projector
    local pin = Citizen.InvokeNative(N.PIN_CLOSEST_MAP_ENTITY, joaat(cfg.projModel), p.x, p.y, p.z, 7, Citizen.ResultAsInteger())
    local obj, timeout = 0, GetGameTimer() + 5000
    while GetGameTimer() < timeout do
        if pin and Citizen.InvokeNative(N.IS_MAP_ENTITY_PINNED, pin) then
            local ent = Citizen.InvokeNative(N.GET_PINNED_MAP_ENTITY, pin, Citizen.ResultAsInteger())
            obj = Citizen.InvokeNative(N.GET_OBJECT_FROM_ENTITY, ent, Citizen.ResultAsInteger())
            if obj ~= 0 and DoesEntityExist(obj) then break end
        end
        Wait(100)
    end
    if obj == 0 or not DoesEntityExist(obj) then
        if Config.Debug then print('[rsg-cinema] projector light not found for', cfg.label) end
        return renderId, pin, nil
    end
    Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, obj, 0.0)
    Citizen.InvokeNative(N.LINK_RT_TO_LIGHT_OBJ, obj, renderId)
    return renderId, pin, obj
end

---------------------------------------------------------------- house lights (func_258 / func_259)
-- Pins each map light, then fades its intensity between 1.0 (normal) and Config.LightsDim
local function pinLights(cfg)
    local list = {}
    for _, group in ipairs(cfg.lights or {}) do
        local model = joaat(group.model)
        for _, c in ipairs(group.coords) do
            local pin = Citizen.InvokeNative(N.PIN_CLOSEST_MAP_ENTITY, model, c.x, c.y, c.z, 7, Citizen.ResultAsInteger())
            if pin and pin ~= 0 then list[#list + 1] = { pin = pin } end
        end
    end
    local timeout = GetGameTimer() + 3000
    repeat
        local missing = false
        for _, l in ipairs(list) do
            if not l.obj then
                if Citizen.InvokeNative(N.IS_MAP_ENTITY_PINNED, l.pin) then
                    local ent = Citizen.InvokeNative(N.GET_PINNED_MAP_ENTITY, l.pin, Citizen.ResultAsInteger())
                    local obj = Citizen.InvokeNative(N.GET_OBJECT_FROM_ENTITY, ent, Citizen.ResultAsInteger())
                    if obj ~= 0 and DoesEntityExist(obj) then l.obj = obj else missing = true end
                else
                    missing = true
                end
            end
        end
        if missing then Wait(100) end
    until not missing or GetGameTimer() > timeout
    if Config.Debug then
        local found = 0
        for _, l in ipairs(list) do if l.obj then found = found + 1 end end
        print(('[rsg-cinema] house lights found %d / %d'):format(found, #list))
    end
    return list
end

local function fadeLights(list, from, to, ms)
    local start = GetGameTimer()
    while true do
        local t = math.min(1.0, (GetGameTimer() - start) / math.max(1, ms))
        local v = from + (to - from) * t
        for _, l in ipairs(list) do
            if l.obj and DoesEntityExist(l.obj) then Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, l.obj, v + 0.0) end
        end
        if t >= 1.0 then break end
        Wait(0)
    end
end

local function dimLights(me)
    if me.lights or not me.cfg.lights then return end
    local token = {}
    me.lights = token -- placeholder while pinning (pinning waits for the map, so it runs off the draw loop)
    CreateThread(function()
        local list = pinLights(me.cfg)
        if me.lights ~= token then -- film stopped / player left while pinning
            for _, l in ipairs(list) do Citizen.InvokeNative(N.UNPIN_MAP_ENTITY, l.pin) end
            return
        end
        me.lights = list
        fadeLights(list, 1.0, Config.LightsDim, Config.LightsFade)
    end)
end

local function restoreLights(me, instant)
    local list = me.lights
    if not list then return end
    me.lights = nil
    local function finish()
        fadeLights(list, Config.LightsDim, 1.0, instant and 0 or Config.LightsFade)
        for _, l in ipairs(list) do Citizen.InvokeNative(N.UNPIN_MAP_ENTITY, l.pin) end
    end
    if instant then finish() else CreateThread(finish) end -- instant runs now so resource stop can't leave lights dimmed
end

local function stopFilm(instant)
    if not active then return end
    restoreLights(active, instant)
    Citizen.InvokeNative(N.SET_TV_CHANNEL, -1)
    if active.obj and DoesEntityExist(active.obj) then Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, active.obj, 0.0) end
    if active.pin then Citizen.InvokeNative(N.UNPIN_MAP_ENTITY, active.pin) end
    if Citizen.InvokeNative(N.IS_NAMED_RT_REGISTERED, active.cfg.renderTarget) then
        Citizen.InvokeNative(N.RELEASE_NAMED_RT, active.cfg.renderTarget)
    end
    if active.screenObj and DoesEntityExist(active.screenObj) then DeleteObject(active.screenObj) end
    setEntitySets(active.cfg, false)
    active = nil
end

-- show_movie_magic_lantern.c func_50
local function playFilm()
    local cfg = active.cfg
    setEntitySets(cfg, true)
    Citizen.InvokeNative(N.SET_TV_AUDIO_FRONTEND, false)
    Citizen.InvokeNative(N.SET_TV_VOLUME, cfg.volume + 0.0)
    if not active.obj and active.screenObj then -- no projector light found: show the film on the screen object (func_50)
        SetEntityVisible(active.screenObj, true)
        Citizen.InvokeNative(N.ATTACH_TV_AUDIO_TO_ENTITY, active.screenObj)
    end
    if active.obj then
        Citizen.InvokeNative(N.ATTACH_TV_AUDIO_TO_ENTITY, active.obj)
        Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, active.obj, 5.0)
    end
    Citizen.InvokeNative(N.SET_TV_CHANNEL, -1)
    Citizen.InvokeNative(N.SET_TV_CHANNEL_PLAYLIST, 0, active.playlist, true)
    Citizen.InvokeNative(N.SET_TV_CHANNEL, 0)
    dimLights(active)
    active.started = true
end

RegisterNetEvent('rsg-cinema:client:startFilm', function(id, playlist, filmLabel, ticket)
    local cfg = Config.Cinemas[id]
    if not cfg or type(playlist) ~= 'string' then return end
    stopFilm()
    active = { id = id, cfg = cfg, playlist = playlist, ticket = ticket, started = false }
    if ticket or #(GetEntityCoords(cache.ped) - cfg.centre) <= Config.WatchRadius then
        lib.notify({ title = cfg.label, description = locale('cl_film_starting', filmLabel), type = 'inform' })
        active.notified = true
    end

    CreateThread(function()
        local me = active
        local reported = false
        while active == me do
            local dist = #(GetEntityCoords(cache.ped) - cfg.centre)
            if dist <= Config.WatchRadius then
                if not me.renderId then
                    me.renderId, me.pin, me.obj = setupScreen(cfg, me)
                    if not me.renderId then Wait(1000) goto continue end
                end
                if not me.started then playFilm() end
                -- func_66: draw the channel onto the render target every frame
                Citizen.InvokeNative(N.DRAW_ORDER_FLAG)
                Citizen.InvokeNative(N.SET_TEXT_RENDER_ID, me.renderId)
                local d = cfg.draw
                Citizen.InvokeNative(N.DRAW_TV_CHANNEL, d.x, d.y, d.w, d.h, 0.0, 255, 255, 255, 128)
                -- func_67: end of film
                if not reported and Citizen.InvokeNative(N.IS_TVSHOW_CURRENTLY_PLAYING, END_MARKER) then
                    reported = true
                    TriggerServerEvent('rsg-cinema:server:filmEnded', id)
                end
                Wait(0)
            else
                if me.started then -- walked out: pause the screen, restart from the top on return
                    Citizen.InvokeNative(N.SET_TV_CHANNEL, -1)
                    restoreLights(me, true)
                    me.started = false
                end
                Wait(1000)
            end
            ::continue::
        end
    end)
end)

RegisterNetEvent('rsg-cinema:client:stopFilm', function(id)
    if not active or active.id ~= id then return end
    local tell = active.notified or active.started
    stopFilm()
    if tell then lib.notify({ title = Config.Cinemas[id].label, description = locale('cl_film_over'), type = 'inform' }) end
end)

---------------------------------------------------------------- ticket NUI
local savedDraws = {} -- last saved picture settings; admin previews are rolled back to these on close

local function applyDraw(id, d)
    local cfg = Config.Cinemas[id]
    if not cfg or type(d) ~= 'table' then return end
    savedDraws[id] = { x = d.x, y = d.y, w = d.w, h = d.h }
    cfg.draw = { x = d.x, y = d.y, w = d.w, h = d.h }
end

local function closeUI()
    if not uiOpen then return end
    uiOpen, uiCinema = false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    for id, d in pairs(savedDraws) do applyDraw(id, d) end
end

local function ticketText()
    return {
        subtitle = locale('ui_subtitle'), nowShowing = locale('ui_now_showing'), startsIn = locale('ui_starts_in'),
        playing = locale('ui_playing'), soon = locale('ui_not_on_sale'), price = locale('ui_price'),
        buy = locale('ui_buy'), owned = locale('ui_owned'), close = locale('ui_close'),
    }
end

local function openTickets(id)
    if uiOpen then return end
    local info = lib.callback.await('rsg-cinema:server:getInfo', false, id)
    if not info then return end
    uiOpen, uiCinema = true, id
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = info, text = ticketText() })
end

RegisterNUICallback('close', function(_, cb) closeUI() cb('ok') end)

---------------------------------------------------------------- admin NUI
local function adminText()
    local keys = { 'adm_title','adm_subtitle','adm_playing','adm_idle','adm_next_in','adm_running','adm_tickets',
        'adm_public','adm_film','adm_start','adm_stop','adm_refresh','adm_empty',
        'adm_picture','adm_pos_x','adm_pos_y','adm_width','adm_height','adm_save','adm_reset','adm_preview_note' }
    local t = {}
    for _, k in ipairs(keys) do t[k] = locale(k) end
    return t
end

RegisterNetEvent('rsg-cinema:client:openAdmin', function()
    if uiOpen then return end
    local data = lib.callback.await('rsg-cinema:server:adminData', false)
    if not data then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAdmin', data = data, text = adminText() })
end)

RegisterNUICallback('adminAction', function(body, cb)
    TriggerServerEvent('rsg-cinema:server:adminAction', body.action, body.id, body.filmIndex)
    Wait(300)
    cb(lib.callback.await('rsg-cinema:server:adminData', false) or {})
end)

-- live preview only on this client; saving goes through the server
RegisterNUICallback('previewDraw', function(body, cb)
    local cfg = Config.Cinemas[body.id]
    if cfg and type(body.draw) == 'table' then
        local d = cfg.draw
        for _, k in ipairs({ 'x', 'y', 'w', 'h' }) do d[k] = tonumber(body.draw[k]) or d[k] end
    end
    cb('ok')
end)

RegisterNUICallback('saveDraw', function(body, cb)
    TriggerServerEvent('rsg-cinema:server:adminSetDraw', body.id, body.draw)
    cb('ok')
end)

RegisterNetEvent('rsg-cinema:client:setDraw', applyDraw)

CreateThread(function()
    for id, cfg in pairs(Config.Cinemas) do applyDraw(id, cfg.draw) end
    local draws = lib.callback.await('rsg-cinema:server:getDraws', false)
    for id, d in pairs(draws or {}) do applyDraw(id, d) end
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    cb(lib.callback.await('rsg-cinema:server:adminData', false) or {})
end)
RegisterNUICallback('buy', function(_, cb)
    if not uiCinema then return cb('ok') end
    local info = lib.callback.await('rsg-cinema:server:buyTicket', false, uiCinema)
    if info and uiOpen then SendNUIMessage({ action = 'open', data = info, text = ticketText() }) end
    cb('ok')
end)

---------------------------------------------------------------- world setup
local function despawnSeller(id)
    local ped = peds[id]
    if not ped then return end
    peds[id] = nil
    exports.ox_target:removeLocalEntity(ped)
    if DoesEntityExist(ped) then DeletePed(ped) end
end

local function spawnSeller(id, cfg)
    if peds[id] then return end
    local s = cfg.seller
    local model = joaat(s.model)
    if not lib.requestModel(model, 10000) then return end
    local ped = CreatePed(model, s.coords.x, s.coords.y, s.coords.z - 1.0, s.coords.w, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SET_RANDOM_OUTFIT_VARIATION
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    peds[id] = ped
    exports.ox_target:addLocalEntity(ped, {
        { name = 'rsg-cinema:tickets:' .. id, icon = 'fa-solid fa-ticket', label = locale('cl_target_tickets'), distance = 2.5,
          onSelect = function() openTickets(id) end },
    })
end

CreateThread(function()
    for id, cfg in pairs(Config.Cinemas) do
        if cfg.enabled then
            if cfg.blip then
                local b = Citizen.InvokeNative(N.BLIP_ADD_FOR_COORDS, 1664425300, cfg.centre.x, cfg.centre.y, cfg.centre.z)
                Citizen.InvokeNative(N.SET_BLIP_SPRITE, b, joaat(cfg.blip.sprite), true)
                SetBlipScale(b, cfg.blip.scale)
                Citizen.InvokeNative(N.SET_BLIP_NAME, b, cfg.label)
                blips[#blips + 1] = b
            end
            local sc = cfg.seller.coords
            points[#points + 1] = lib.points.new({
                coords = vector3(sc.x, sc.y, sc.z), distance = Config.SellerSpawnDistance,
                onEnter = function() spawnSeller(id, cfg) end,
                onExit = function() despawnSeller(id) end,
            })
        end
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() TriggerServerEvent('rsg-cinema:server:sync') end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    stopFilm(true)
    if uiOpen then SetNuiFocus(false, false) end
    for _, p in ipairs(points) do p:remove() end
    for id in pairs(peds) do despawnSeller(id) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
