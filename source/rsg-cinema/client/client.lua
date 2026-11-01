local RSGCore = exports['rsg-core']:GetCoreObject()

-- config labels are locale keys: translate them once
for _, f in ipairs(Config.Films) do f.label = locale(f.label) end
for _, c in pairs(Config.Cinemas) do c.label = locale(c.label) end

-- Native hashes from rsg-redm-brain natives/db (GRAPHICS / HUD / ENTITY / OBJECT)
local N = {
    SET_TV_CHANNEL              = 0x593FAF7FC9401A56,
    SET_TV_CHANNEL_PLAYLIST     = 0xDEC6B25F5DC8925B,
    DRAW_TV_CHANNEL             = 0xC0A145540254A840,
    SET_TV_VOLUME               = 0x73A97068787D7231,
    SET_TV_AUDIO_FRONTEND       = 0x64437C98FCC5F291,
    ATTACH_TV_AUDIO_TO_ENTITY   = 0x40866A418EB8EFDE,
    IS_TVSHOW_CURRENTLY_PLAYING = 0x4D562223E0EB65F3,
    DRAW_ORDER_FLAG             = 0x32DE2BFFDA43E62A,
    REGISTER_NAMED_RT           = 0x98AF2BB6F62BD588,
    LINK_NAMED_RT               = 0x2F506B8556242DDB,
    IS_NAMED_RT_REGISTERED      = 0x3EE32F7964C40FE6,
    IS_NAMED_RT_LINKED          = 0x707032835FF09AE7,
    GET_NAMED_RT_RENDER_ID      = 0xB6762A85EE29AA60,
    RELEASE_NAMED_RT            = 0x0E692EE61761361F,
    SET_TEXT_RENDER_ID          = 0xE550CDE128D56757,
    PIN_CLOSEST_MAP_ENTITY      = 0x6F3068258A499E52,
    IS_MAP_ENTITY_PINNED        = 0x1FF441D7954F8709,
    GET_PINNED_MAP_ENTITY       = 0x4735E2A4BB83D9DA,
    UNPIN_MAP_ENTITY            = 0xD2B9C78537ED5759,
    GET_OBJECT_FROM_ENTITY      = 0x280BBE5601EAA983,
    SET_LIGHT_INTENSITY_OBJ     = 0xF49574E2332A8F06,
    LINK_RT_TO_LIGHT_OBJ        = 0x04D1D4E411CE52D0, -- named _SET_LIGHT_SCATTERING_DISABLED_FOR_OBJECT; Rockstar passes the render id
    BLIP_ADD_FOR_COORDS         = 0x554D9D53F696D002,
    SET_BLIP_SPRITE             = 0x74F74D3207ED525C,
    SET_BLIP_NAME               = 0x9CB1A1623062F402,
    ACTIVATE_ENTITY_SET         = 0x174D0AAB11CED739,
    DEACTIVATE_ENTITY_SET       = 0x33B81A2C07A51FFF,
    SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE,
}
local END_MARKER = joaat('END_OF_MOVIE_MARKER')
local SELLER_RANGE = 5.0 -- must match the server's nearSeller check

local peds, blips = {}, {}
local uiOpen, uiCinema = false, nil
local shows = {}   -- [cinemaId] = { playlist, ticket, notified, reported } for every film this client may watch
local watch = nil  -- the one cinema currently being drawn: { id, cfg, renderId, pin, obj, screenObj, lights, started }
local watcherRunning = false

local function notify(title, desc)
    RSGCore.Functions.Notify({ title = title, description = desc, type = 'inform', duration = 5000 })
end

local function loadModel(name)
    local hash = joaat(name)
    local ok = pcall(RSGCore.Functions.RequestModel, hash, 10000)
    if ok and HasModelLoaded(hash) then return hash end
    print(('[rsg-cinema] could not load model %s'):format(name))
end

local function pinnedObject(pin)
    if not pin or pin == 0 or not Citizen.InvokeNative(N.IS_MAP_ENTITY_PINNED, pin) then return nil end
    local ent = Citizen.InvokeNative(N.GET_PINNED_MAP_ENTITY, pin, Citizen.ResultAsInteger())
    local obj = Citizen.InvokeNative(N.GET_OBJECT_FROM_ENTITY, ent, Citizen.ResultAsInteger())
    if obj ~= 0 and DoesEntityExist(obj) then return obj end
end

---------------------------------------------------------------- screen setup
local function setEntitySets(cfg, open)
    if not cfg.entitySets then return end
    local interior = GetInteriorAtCoords(cfg.centre.x, cfg.centre.y, cfg.centre.z)
    if not IsValidInterior(interior) then return end
    local on, off = cfg.entitySets.open, cfg.entitySets.closed
    if not open then on, off = off, on end
    Citizen.InvokeNative(N.DEACTIVATE_ENTITY_SET, interior, off, true)
    Citizen.InvokeNative(N.ACTIVATE_ENTITY_SET, interior, on, 0)
end

-- show_movie_magic_lantern.c func_264: hidden render-target object the film is linked to
local function spawnScreenObject(cfg)
    local model = loadModel(cfg.linkModel)
    if not model then return nil end
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

-- show_movie_magic_lantern.c func_262. Returns false when the render target can't be set up.
local function setupScreen(w)
    local cfg = w.cfg
    w.screenObj = spawnScreenObject(cfg)
    if not w.screenObj then return false end
    if not Citizen.InvokeNative(N.IS_NAMED_RT_REGISTERED, cfg.renderTarget) then
        Citizen.InvokeNative(N.REGISTER_NAMED_RT, cfg.renderTarget, false)
        Citizen.InvokeNative(N.LINK_NAMED_RT, joaat(cfg.linkModel))
        if not Citizen.InvokeNative(N.IS_NAMED_RT_LINKED, joaat(cfg.linkModel)) then
            Citizen.InvokeNative(N.RELEASE_NAMED_RT, cfg.renderTarget)
            if Config.Debug then print('[rsg-cinema] render target failed to link for', cfg.label) end
            return false
        end
    end
    w.renderId = Citizen.InvokeNative(N.GET_NAMED_RT_RENDER_ID, cfg.renderTarget, Citizen.ResultAsInteger())
    local p = cfg.projector
    w.pin = Citizen.InvokeNative(N.PIN_CLOSEST_MAP_ENTITY, joaat(cfg.projModel), p.x, p.y, p.z, 7, Citizen.ResultAsInteger())
    local timeout = GetGameTimer() + 5000
    repeat
        w.obj = pinnedObject(w.pin)
        if not w.obj then Wait(100) end
    until w.obj or GetGameTimer() > timeout
    if w.obj then
        Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, w.obj, 0.0)
        Citizen.InvokeNative(N.LINK_RT_TO_LIGHT_OBJ, w.obj, w.renderId)
    elseif Config.Debug then
        print('[rsg-cinema] projector light not found for', cfg.label)
    end
    return true
end

---------------------------------------------------------------- house lights (func_258 / func_259)
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
                l.obj = pinnedObject(l.pin)
                if not l.obj then missing = true end
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
    repeat
        local t = math.min(1.0, (GetGameTimer() - start) / math.max(1, ms))
        local v = from + (to - from) * t
        for _, l in ipairs(list) do
            if l.obj and DoesEntityExist(l.obj) then Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, l.obj, v + 0.0) end
        end
        if t < 1.0 then Wait(0) end
    until t >= 1.0
end

local function dimLights(w)
    if w.lights or not w.cfg.lights then return end
    local token = { pending = true }
    w.lights = token -- placeholder while pinning (pinning waits for the map, so it runs off the draw loop)
    CreateThread(function()
        local list = pinLights(w.cfg)
        if w.lights ~= token then -- film stopped / player left while pinning
            for _, l in ipairs(list) do Citizen.InvokeNative(N.UNPIN_MAP_ENTITY, l.pin) end
            return
        end
        w.lights = list
        fadeLights(list, 1.0, Config.LightsDim, Config.LightsFade)
    end)
end

local function restoreLights(w, instant)
    local list = w.lights
    w.lights = nil
    if not list or list.pending then return end
    local function finish()
        fadeLights(list, Config.LightsDim, 1.0, instant and 0 or Config.LightsFade)
        for _, l in ipairs(list) do Citizen.InvokeNative(N.UNPIN_MAP_ENTITY, l.pin) end
    end
    if instant then finish() else CreateThread(finish) end -- instant runs now so resource stop can't leave lights dimmed
end

---------------------------------------------------------------- playback
-- show_movie_magic_lantern.c func_50
local function playFilm(w)
    local cfg = w.cfg
    setEntitySets(cfg, true)
    Citizen.InvokeNative(N.SET_TV_AUDIO_FRONTEND, false)
    Citizen.InvokeNative(N.SET_TV_VOLUME, cfg.volume + 0.0)
    if w.obj then
        Citizen.InvokeNative(N.ATTACH_TV_AUDIO_TO_ENTITY, w.obj)
        Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, w.obj, 5.0)
    else -- no projector light found: show the film on the screen object itself
        SetEntityVisible(w.screenObj, true)
        Citizen.InvokeNative(N.ATTACH_TV_AUDIO_TO_ENTITY, w.screenObj)
    end
    Citizen.InvokeNative(N.SET_TV_CHANNEL, -1)
    Citizen.InvokeNative(N.SET_TV_CHANNEL_PLAYLIST, 0, shows[w.id].playlist, true)
    Citizen.InvokeNative(N.SET_TV_CHANNEL, 0)
    dimLights(w)
    w.started = true
end

-- tears down everything the watched cinema created; walking back in restarts the film from the top
local function stopWatching(instant, w)
    w = w or watch
    if not w then return end
    if watch == w then watch = nil end
    restoreLights(w, instant)
    Citizen.InvokeNative(N.SET_TV_CHANNEL, -1)
    if w.obj and DoesEntityExist(w.obj) then Citizen.InvokeNative(N.SET_LIGHT_INTENSITY_OBJ, w.obj, 0.0) end
    if w.pin then Citizen.InvokeNative(N.UNPIN_MAP_ENTITY, w.pin) end
    if Citizen.InvokeNative(N.IS_NAMED_RT_REGISTERED, w.cfg.renderTarget) then
        Citizen.InvokeNative(N.RELEASE_NAMED_RT, w.cfg.renderTarget)
    end
    if w.screenObj and DoesEntityExist(w.screenObj) then DeleteObject(w.screenObj) end
    setEntitySets(w.cfg, false)
end

local function inside(cfg)
    return #(GetEntityCoords(PlayerPedId()) - cfg.centre) <= Config.WatchRadius
end

-- One thread for all cinemas: draws the film of whichever running show the player is inside
local function runWatcher()
    if watcherRunning then return end
    watcherRunning = true
    CreateThread(function()
        while next(shows) do
            if not watch then
                for id, show in pairs(shows) do
                    local cfg = Config.Cinemas[id]
                    if inside(cfg) then
                        local w = { id = id, cfg = cfg }
                        watch = w
                        -- setup yields; the show may stop meanwhile, so re-check before playing
                        if setupScreen(w) and shows[id] == show and watch == w then
                            playFilm(w)
                        else
                            stopWatching(true, w)
                        end
                        break
                    end
                end
                if not watch then Wait(1000) end
            elseif not shows[watch.id] or not inside(watch.cfg) then
                stopWatching(true)
            else
                -- func_66: draw the channel onto the render target every frame
                local d = watch.cfg.draw
                Citizen.InvokeNative(N.DRAW_ORDER_FLAG)
                Citizen.InvokeNative(N.SET_TEXT_RENDER_ID, watch.renderId)
                Citizen.InvokeNative(N.DRAW_TV_CHANNEL, d.x, d.y, d.w, d.h, 0.0, 255, 255, 255, 128)
                -- func_67: end of film
                local show = shows[watch.id]
                if not show.reported and Citizen.InvokeNative(N.IS_TVSHOW_CURRENTLY_PLAYING, END_MARKER) then
                    show.reported = true
                    TriggerServerEvent('rsg-cinema:server:filmEnded', watch.id)
                end
                Wait(0)
            end
        end
        stopWatching(true)
        watcherRunning = false
    end)
end

RegisterNetEvent('rsg-cinema:client:startFilm', function(id, playlist, filmLabel, ticket)
    local cfg = Config.Cinemas[id]
    if not cfg or type(playlist) ~= 'string' then return end
    if watch and watch.id == id and watch.started then stopWatching(true) end -- restart cleanly if already showing here
    local show = { playlist = playlist, ticket = ticket }
    shows[id] = show
    if ticket or inside(cfg) then
        notify(cfg.label, locale('cl_film_starting', filmLabel))
        show.notified = true
    end
    runWatcher()
end)

RegisterNetEvent('rsg-cinema:client:stopFilm', function(id)
    local show = shows[id]
    if not show then return end
    local tell = show.notified or (watch and watch.id == id)
    shows[id] = nil
    if watch and watch.id == id and watch.started then stopWatching(false) end -- mid-setup: the watcher cleans up
    if tell then notify(Config.Cinemas[id].label, locale('cl_film_over')) end
end)

---------------------------------------------------------------- picture settings
local savedDraws = {} -- last saved picture settings; admin previews are rolled back to these on close

local function applyDraw(id, d)
    local cfg = Config.Cinemas[id]
    if not cfg or type(d) ~= 'table' then return end
    savedDraws[id] = { x = d.x, y = d.y, w = d.w, h = d.h }
    cfg.draw = { x = d.x, y = d.y, w = d.w, h = d.h }
end
RegisterNetEvent('rsg-cinema:client:setDraw', applyDraw)

CreateThread(function()
    local draws = RSGCore.Functions.AwaitCallback('rsg-cinema:server:getDraws', 10000)
    for id, cfg in pairs(Config.Cinemas) do applyDraw(id, (draws and draws[id]) or cfg.draw) end
end)

---------------------------------------------------------------- NUI
local function closeUI()
    if not uiOpen then return end
    uiOpen, uiCinema = false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    for id, d in pairs(savedDraws) do applyDraw(id, d) end
end
RegisterNUICallback('close', function(_, cb) closeUI() cb('ok') end)

local function ticketText()
    return {
        subtitle = locale('ui_subtitle'), nowShowing = locale('ui_now_showing'), startsIn = locale('ui_starts_in'),
        playing = locale('ui_playing'), soon = locale('ui_not_on_sale'), price = locale('ui_price'),
        buy = locale('ui_buy'), owned = locale('ui_owned'), close = locale('ui_close'),
    }
end

local function sellerDistance(id)
    local s = Config.Cinemas[id].seller.coords
    return #(GetEntityCoords(PlayerPedId()) - vector3(s.x, s.y, s.z))
end

local function sendTicketInfo(info)
    if not info then return closeUI() end
    if uiOpen and uiCinema then SendNUIMessage({ action = 'open', data = info, text = ticketText() }) end
end

local function openTickets(id)
    if uiOpen then return end
    local info = RSGCore.Functions.AwaitCallback('rsg-cinema:server:getInfo', 5000, id)
    if not info then return end
    uiOpen, uiCinema = true, id
    SetNuiFocus(true, true)
    sendTicketInfo(info)
    -- keep the panel live (sales opening, show starting) and close it if the player walks off
    CreateThread(function()
        local ticks = 0
        while uiOpen and uiCinema == id do
            Wait(1000)
            if not uiOpen or uiCinema ~= id then break end
            if sellerDistance(id) > SELLER_RANGE then closeUI() break end
            ticks = ticks + 1
            if ticks % 5 == 0 then
                sendTicketInfo(RSGCore.Functions.AwaitCallback('rsg-cinema:server:getInfo', 5000, id))
            end
        end
    end)
end

RegisterNUICallback('buy', function(_, cb)
    cb('ok')
    if not uiCinema then return end
    sendTicketInfo(RSGCore.Functions.AwaitCallback('rsg-cinema:server:buyTicket', 5000, uiCinema))
end)

local function adminText()
    local keys = { 'adm_title', 'adm_subtitle', 'adm_playing', 'adm_idle', 'adm_next_in', 'adm_running', 'adm_tickets',
        'adm_public', 'adm_film', 'adm_start', 'adm_stop', 'adm_refresh', 'adm_empty',
        'adm_picture', 'adm_pos_x', 'adm_pos_y', 'adm_width', 'adm_height', 'adm_save', 'adm_reset', 'adm_preview_note' }
    local t = {}
    for _, k in ipairs(keys) do t[k] = locale(k) end
    return t
end

RegisterNetEvent('rsg-cinema:client:openAdmin', function()
    if uiOpen then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-cinema:server:adminData', 5000)
    if not data then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAdmin', data = data, text = adminText() })
end)

RegisterNUICallback('adminAction', function(body, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-cinema:server:adminAction', 5000, body.action, body.id, body.filmIndex) or {})
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-cinema:server:adminData', 5000) or {})
end)

-- live preview only on this client; saving goes through the server
RegisterNUICallback('previewDraw', function(body, cb)
    local cfg = Config.Cinemas[body.id]
    if cfg and type(body.draw) == 'table' then
        for _, k in ipairs({ 'x', 'y', 'w', 'h' }) do cfg.draw[k] = tonumber(body.draw[k]) or cfg.draw[k] end
    end
    cb('ok')
end)

RegisterNUICallback('saveDraw', function(body, cb)
    TriggerServerEvent('rsg-cinema:server:adminSetDraw', body.id, body.draw)
    cb('ok')
end)

---------------------------------------------------------------- ticket sellers
local function despawnSeller(id)
    local ped = peds[id]
    if not ped then return end
    peds[id] = nil
    exports['rsg-target']:removeLocalEntity(ped)
    if DoesEntityExist(ped) then DeletePed(ped) end
end

local function spawnSeller(id, cfg)
    local s = cfg.seller
    local model = loadModel(s.model)
    if not model or peds[id] then return end
    local ped = CreatePed(model, s.coords.x, s.coords.y, s.coords.z - 1.0, s.coords.w, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    Citizen.InvokeNative(N.SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    peds[id] = ped
    exports['rsg-target']:addLocalEntity(ped, {
        { name = 'rsg-cinema:tickets:' .. id, icon = 'fa-solid fa-ticket', label = locale('cl_target_tickets'), distance = 2.5,
          onSelect = function() openTickets(id) end },
    })
end

CreateThread(function()
    for _, cfg in pairs(Config.Cinemas) do
        if cfg.enabled and cfg.blip then
            local b = Citizen.InvokeNative(N.BLIP_ADD_FOR_COORDS, 1664425300, cfg.centre.x, cfg.centre.y, cfg.centre.z)
            Citizen.InvokeNative(N.SET_BLIP_SPRITE, b, joaat(cfg.blip.sprite), true)
            SetBlipScale(b, cfg.blip.scale)
            Citizen.InvokeNative(N.SET_BLIP_NAME, b, cfg.label)
            blips[#blips + 1] = b
        end
    end
    -- spawn sellers only while a player is nearby
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, cfg in pairs(Config.Cinemas) do
            if cfg.enabled then
                local s = cfg.seller.coords
                local near = #(pos - vector3(s.x, s.y, s.z)) <= Config.SellerSpawnDistance
                if near and not peds[id] then spawnSeller(id, cfg)
                elseif not near and peds[id] then despawnSeller(id) end
            end
        end
        Wait(1000)
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() TriggerServerEvent('rsg-cinema:server:sync') end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    shows = {}
    stopWatching(true)
    if uiOpen then SetNuiFocus(false, false) end
    for id in pairs(peds) do despawnSeller(id) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
