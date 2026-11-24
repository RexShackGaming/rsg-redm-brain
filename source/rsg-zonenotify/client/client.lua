-- rsg-zonenotify
-- Shows a location banner (custom NUI or native RDR2) when you enter a new state, district or town.
-- Zone data lives in shared/zones.lua (ported from VORPCORE/vorp_zonenotify, credits: freedy69 / Bytesized).
local RSGCore = exports['rsg-core']:GetCoreObject()

local ZONE <const> = {
    STATE = 0, TOWN = 1, LAKE = 2, RIVER = 3, SWAMP = 5, OCEAN = 6,
    CREEK = 7, POND = 8, DISTRICT = 10, TEXT_PRINTED = 11, TEXT_WRITTEN = 12
}

local KVP_KEY   <const> = 'rsg-zonenotify:enabled' -- old on/off flag (2 = off), still read once
local PREFS_KEY <const> = 'rsg-zonenotify:prefs'
local LANDMARK_SCAN_MS <const> = 1500 -- landmark/water scan runs less often than the town/district/state check

local isLoggedIn  = false
local prefs       = { banners = true, sound = true, time = true, temperature = true, wind = true } -- per player, saved in KVP
local PREF_KEYS <const> = { banners = true, sound = true, time = true, temperature = true, wind = true }
local stored      = { state = 0, district = 0, town = 0 }
local pending     = nil -- banner waiting to show: { text, zoneType, hash, kind, since }
local lastManual  = 0
local lastScan    = 0
local discovered  = {}    -- [labelKey] = true, loaded from the server per character
local discoveredCount = 0
local discoveriesLoaded = false
local loadGeneration = 0  -- guards against a late callback from a previous character
local suppressed  = {}    -- [reason] = true, set by other resources (cinematic cameras etc.)
local bannerVisible = false
local currentZone = { state = nil, district = nil, town = nil } -- lower-case place keys, for the GetCurrentZone export

local function LoadPrefs()
    local raw = GetResourceKvpString(PREFS_KEY)
    if raw then
        local ok, t = pcall(json.decode, raw)
        if ok and type(t) == 'table' then
            for k in pairs(PREF_KEYS) do if type(t[k]) == 'boolean' then prefs[k] = t[k] end end
        end
    elseif GetResourceKvpInt(KVP_KEY) == 2 then
        prefs.banners = false -- migrate the old /zonenotify choice
    end
end

local function SavePrefs() SetResourceKvp(PREFS_KEY, json.encode(prefs)) end

-- sound/time/temperature/wind follow the player's choice only when player options are on
local function Pref(k) return not Config.PlayerOptions or prefs[k] end

LoadPrefs()

----------------------------------------------------------------
-- zone data (tables are shared, see shared/zones.lua)
----------------------------------------------------------------
local TOWNS, TEXT_WRITTEN, TEXT_PRINTED = Zones.TOWNS, Zones.TEXT_WRITTEN, Zones.TEXT_PRINTED
local LAKES, SWAMPS, OCEANS, CREEKS, PONDS = Zones.LAKES, Zones.SWAMPS, Zones.OCEANS, Zones.CREEKS, Zones.PONDS
local DISTRICTS, STATES, RIVERS = Zones.DISTRICTS, Zones.STATES, Zones.RIVERS

local CAVES <const> = {
    [`Q0304_TUNNEL_ENT`] = true,
    [`J_10P_TUNNEL_1A_INT`] = true,
    [`BAC_TUNNELCURVE_INT`] = true,
    [`L_14_CAVE_INT`] = true,
    [`GAP_MINE_INT`] = true,
    [`MIL_MINE_CAVE_INT`] = true,
    [`M05_BEARCAVE_MAIN`] = true,
    [`Q0304_TUNNEL_INT`] = true,
    [`ELH_SEACAVES_INT`] = true,
    [`L_08_TRAIN_TUNNEL2_INT`] = true,
    [`BAC_TUNNELEXIT_INT`] = true,
    [`BAC_TUNNELENT_INT`] = true,
    [`J_14_TUNNEL01_INT`] = true,
    [653987431] = true,
    [`BEA_01_INT`] = true,
    [`BAC_TUNNEL_INT`] = true,
    [`AGU_FUS_CAVE_INT`] = true,
    [`HEA_TUNNEL_02`] = true,
    [`Q0304_TUNNEL_EXIT`] = true,
    [`ANN_MINE_INT_MAIN`] = true,
    [1633500362] = true,
    [`J_16_TUNNEL_INT`] = true
}
local BEAVER_HOLLOW_CAVE <const> = vector3(2318.291, 1448.150, 84.413)
local BACCHUS_CUMBERLAND_HASH <const> = -138648964
local PRONGHORN_HASH <const> = -120578354

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------
-- normalise to signed 32-bit so it always matches the table keys
local function Signed(h)
    h = (h or 0) & 0xFFFFFFFF
    if h >= 0x80000000 then h = h - 0x100000000 end
    return h
end

local function ZoneAt(c, zoneType)
    -- _GET_MAP_ZONE_AT_COORDS
    return Signed(Citizen.InvokeNative(0x43AD8FC02B429D33, c.x, c.y, c.z, zoneType, Citizen.ResultAsInteger()))
end

local function FeedBusy()
    -- UI_FEED_GET_CURRENT_MESSAGE
    return Citizen.InvokeNative(0xC17F69E1418CD11F, 2, Citizen.ResultAsInteger()) ~= 0
end

local PREFIXES <const> = { 'DISTRICT_', 'STATE_', 'TOWN_', 'WATER_', 'LANDMARK_', 'HIDEOUT_', 'SETTLEMENT_', 'HOMESTEAD_' }
local SMALL_WORDS <const> = { OF = true, THE = true, DE = true, LA = true, DEL = true, AND = true }

-- 'district_cumberland_forest' -> 'Cumberland Forest'
local function Prettify(key)
    local s = key:upper()
    for _, p in ipairs(PREFIXES) do
        if s:sub(1, #p) == p then s = s:sub(#p + 1) break end
    end
    local words, i = {}, 0
    for w in s:gmatch('[^_]+') do
        i = i + 1
        if i > 1 and SMALL_WORDS[w] then
            words[#words + 1] = w:lower()
        else
            words[#words + 1] = w:sub(1, 1) .. w:sub(2):lower()
        end
    end
    return table.concat(words, ' ')
end

local function IsGoodLabel(txt, key)
    return txt and txt ~= '' and txt ~= 'NULL' and txt:upper() ~= key:upper() and not txt:find('_')
end

-- turn a game label key (e.g. 'district_heartlands') into its display text (cached: GetLabelText is a native call)
local labelCache = {}
local function Label(key)
    key = Zones.Original[key] or key -- place keys from the server are lower-case
    local cached = labelCache[key]
    if cached then return cached end
    local name
    if Config.LabelNames and Config.LabelNames[key] then
        name = Config.LabelNames[key]
    else
        for _, k in ipairs({ key, key:upper() }) do
            local ok, txt = pcall(GetLabelText, k)
            if ok and IsGoodLabel(txt, key) then name = txt break end
        end
    end
    name = name or Prettify(key)
    labelCache[key] = name
    return name
end

local function Notify(title, description, duration, nType)
    RSGCore.Functions.Notify({ title = title, description = description, type = nType or 'inform', duration = duration, icon = 'fa-solid fa-map-location-dot' })
end

----------------------------------------------------------------
-- discovery / flavour / sound
----------------------------------------------------------------
-- only places that exist in shared/zones.lua can be discovered (the server checks the same list)
local function ValidKey(key)
    return type(key) == 'string' and Zones.Keys[key:lower()] == true
end

-- returns true the first time this character sees a place
local function MarkDiscovered(key)
    if not Config.Discovery.Enabled or not discoveriesLoaded or not ValidKey(key) then return false end
    local k = key:lower()
    if discovered[k] then return false end
    discovered[k] = true
    discoveredCount = discoveredCount + 1
    TriggerServerEvent('rsg-zonenotify:server:discover', k, GetEntityCoords(PlayerPedId()))
    return true
end

local function ZoneMessage(key)
    local msgKey = Config.ZoneMessages and (Config.ZoneMessages[key] or Config.ZoneMessages[key:lower()])
    return msgKey and locale(msgKey) or nil
end

local function PlaySound(kind)
    if not Config.Sound.Enabled or not Pref('sound') then return end
    SendNUIMessage({ action = 'sound', kind = kind, file = Config.Sound.Files[kind], volume = Config.Sound.Volume })
end

----------------------------------------------------------------
-- bottom line (time | temperature | wind) as parts: { text = '14:05', code = '~COLOR_WHITE~' }
----------------------------------------------------------------
local function FormatTime(h, m)
    if ShouldUse_24HourClock() then return ('%02d:%02d'):format(h, m) end
    local period = locale(h >= 12 and 'cl_time_pm' or 'cl_time_am')
    h = h % 12
    return ('%d:%02d%s'):format(h == 0 and 12 or h, m, period)
end

local function GetBottomParts(c)
    local parts = {}
    local gameMetric = ShouldUseMetricTemperature()
    local tempUnit, speedUnit = Config.TemperatureUnit or 'auto', Config.SpeedUnit or 'auto'
    local celsius = tempUnit == 'celsius' or (tempUnit ~= 'fahrenheit' and gameMetric)
    local kmh = speedUnit == 'kmh' or (speedUnit ~= 'mph' and gameMetric)

    if Config.ShowTime and Pref('time') then
        local h, m = GetClockHours(), GetClockMinutes()
        local night = h >= Config.NightStart or h < Config.NightEnd
        parts[#parts + 1] = { text = FormatTime(h, m), code = night and Config.TimeNightColor or Config.TimeDayColor }
    end

    if Config.ShowTemperature and Pref('temperature') then
        local t = GetTemperatureAtCoords(c.x, c.y, c.z)
        parts[#parts + 1] = {
            text = celsius and locale('cl_temp_c', math.ceil(t)) or locale('cl_temp_f', math.ceil(t * 9 / 5 + 32)),
            code = t < Config.TemperatureColdDegree and Config.TemperatureColdColor or Config.TemperatureHotColor,
        }
    end

    if Config.ShowWind and Pref('wind') then
        local w = GetWindSpeed()
        parts[#parts + 1] = {
            text = kmh and locale('cl_wind_kph', math.floor(w)) or locale('cl_wind_mph', math.floor(w * 0.621371)),
            code = Config.WindColor,
        }
    end

    return parts
end

-- '~COLOR_X~' -> 'COLOR_X'
local function CodeName(code)
    return type(code) == 'string' and code:match('^~([%w_]+)~$') or nil
end

local function NativeBottomText(parts)
    local out = {}
    for i, p in ipairs(parts) do out[i] = (p.code or '') .. p.text end
    return table.concat(out, ' ~COLOR_WHITE~| ')
end

----------------------------------------------------------------
-- banner output
----------------------------------------------------------------
local function ShowLocationUi(parts, topText, mode, zoneKind)
    local title = Label(topText)
    mode = mode or Config.DisplayMode
    local isNew = MarkDiscovered(topText)
    local flavour = ZoneMessage(topText)
    local stamp = isNew and Config.Discovery.ShowStamp and locale('cl_discovered') or nil
    PlaySound(isNew and 'discovery' or (zoneKind or 'manual'))

    if mode == 'nui' then
        local nuiParts = {}
        for i, p in ipairs(parts) do
            local name = CodeName(p.code)
            nuiParts[i] = { text = p.text, color = name and Config.NuiColors[name] or nil }
        end
        SendNUIMessage({ action = 'show', title = title, parts = nuiParts, duration = Config.DisplayTime, stamp = stamp, flavour = flavour, queue = Config.BannerQueue })
        bannerVisible = true
        return
    end

    if mode == 'notify' then
        local plain = {}
        for i, p in ipairs(parts) do plain[i] = p.text end
        local desc = table.concat(plain, ' | ')
        if flavour then desc = flavour .. '\n' .. desc end
        if stamp then desc = stamp .. ' - ' .. desc end
        Notify(title, desc, Config.DisplayTime)
        return
    end

    local bottom = NativeBottomText(parts)
    local str1 = CreateVarString(10, 'LITERAL_STRING', title)
    local str2 = CreateVarString(10, 'LITERAL_STRING', (stamp and (stamp .. ' ~COLOR_WHITE~| ') or '') .. (flavour and (flavour .. ' ~COLOR_WHITE~| ') or '') .. bottom)
    local struct1 = DataView.ArrayBuffer(8 * 7)
    local struct2 = DataView.ArrayBuffer(8 * 5)
    struct1:SetInt32(8 * 0, Config.DisplayTime)
    struct2:SetInt64(8 * 1, str1)
    struct2:SetInt64(8 * 2, str2)
    -- _UI_FEED_POST_LOCATION_SHARD(duration*, data*, p2, p3)
    local id = Citizen.InvokeNative(0xD05590C1AB38F068, struct1:Buffer(), struct2:Buffer(), 0, 1, Citizen.ResultAsInteger())
    if Config.Debug then print(('[rsg-zonenotify] shard posted id=%s title=%s'):format(tostring(id), title)) end
end

local function HideBanner()
    SendNUIMessage({ action = 'hide' })
    bannerVisible = false
end

-- scripted cameras (rsg-moviemaker, cutscenes) and other resources can hide the banner
local function IsSuppressed()
    if next(suppressed) or LocalPlayer.state.hideZoneBanner then return true end
    if Config.HideWhileScriptedCam then
        -- GET_RENDERING_CAM 0x03A8931ECC8015D6 (VORPCORE/RDR3natives)
        local cam = GetRenderingCam()
        if cam and cam ~= -1 and cam ~= 0 and DoesCamExist(cam) then return true end
    end
    return false
end

----------------------------------------------------------------
-- lookups
----------------------------------------------------------------
local function GetWaterName(c)
    local district = ZoneAt(c, ZONE.DISTRICT)
    local river = ZoneAt(c, ZONE.RIVER)

    if river == `WATER_KAMASSA_RIVER` then
        if district == 178647645 then return 'WATER_KAMASSA_RIVER_BLUEWATER_MARSH' end
        if district == 2025841068 then return 'WATER_KAMASSA_RIVER_BAYOU_NWA' end
        return 'WATER_KAMASSA_RIVER'
    elseif river == `WATER_SAN_LUIS_RIVER` then
        return district == 426773653 and 'WATER_SAN_LUIS_RIVER_NEW_AUSTIN' or 'water_san_luis_river_west_elizabeth'
    end

    return LAKES[ZoneAt(c, ZONE.LAKE)] or RIVERS[river] or SWAMPS[ZoneAt(c, ZONE.SWAMP)]
        or OCEANS[ZoneAt(c, ZONE.OCEAN)] or CREEKS[ZoneAt(c, ZONE.CREEK)] or PONDS[ZoneAt(c, ZONE.POND)]
end

local function GetMiscName(c)
    -- show "Beaver Hollow" inside the cave too
    local cave = GetInteriorAtCoords(BEAVER_HOLLOW_CAVE.x, BEAVER_HOLLOW_CAVE.y, BEAVER_HOLLOW_CAVE.z)
    if cave ~= 0 and GetInteriorAtCoords(c.x, c.y, c.z) == cave then
        return 'HIDEOUT_BEAVER_HOLLOW'
    end

    local printed = ZoneAt(c, ZONE.TEXT_PRINTED)

    -- Bacchus Bridge and Cumberland Falls share a zone
    if printed == BACCHUS_CUMBERLAND_HASH then
        local district = ZoneAt(c, ZONE.DISTRICT)
        if district == 1835499550 or district == -120156735 then return 'LANDMARK_BACCHUS_BRIDGE' end
        if ZoneAt(c, ZONE.RIVER) == 370072007 then return 'LANDMARK_CUMBERLAND_FALLS' end
        return nil
    end

    local written = ZoneAt(c, ZONE.TEXT_WRITTEN)
    if written == PRONGHORN_HASH and not IsIplActiveByHash(`PRO_MANSION_INT_MILO`) then
        written = 0
    end

    return TEXT_WRITTEN[written] or TEXT_PRINTED[printed]
end

-- town > water > landmark > district > state
local function GetFullLocationName(c)
    return TOWNS[ZoneAt(c, ZONE.TOWN)]
        or GetWaterName(c)
        or GetMiscName(c)
        or DISTRICTS[ZoneAt(c, ZONE.DISTRICT)]
        or STATES[ZoneAt(c, ZONE.STATE)]
end

local function IsInteriorACave(interior)
    local _, nameHash = GetInteriorLocationAndNamehash(interior)
    return CAVES[nameHash] == true
end

----------------------------------------------------------------
-- zone change banners
----------------------------------------------------------------
local function CanShowBanner()
    return prefs.banners and not IsSuppressed() and not IsScreenFadedOut() and not IsPauseMenuActive() and not IsEntityDead(PlayerPedId())
end

-- lower-case place keys of the zones the player is in (nil = unmapped), for the GetCurrentZone export
local function SetCurrentZone(state, district, town)
    local s, d, t = STATES[state], DISTRICTS[district], TOWNS[town]
    currentZone.state, currentZone.district, currentZone.town = s and s:lower(), d and d:lower(), t and t:lower()
end

local function ResetStored(c)
    stored.state    = ZoneAt(c, ZONE.STATE)
    stored.district = ZoneAt(c, ZONE.DISTRICT)
    stored.town     = ZoneAt(c, ZONE.TOWN)
    SetCurrentZone(stored.state, stored.district, stored.town)
    pending = nil
end

local KIND_BY_TYPE <const> = { [ZONE.TOWN] = 'town', [ZONE.DISTRICT] = 'district', [ZONE.STATE] = 'state' }

local function MakePending(text, zoneType, hash)
    return { text = text, zoneType = zoneType, hash = hash, kind = KIND_BY_TYPE[zoneType], since = GetGameTimer() }
end

-- best banner for where the player is now (town > district > state), skipping unmapped zones
local function BestBannerFor(state, district, town, townChanged, districtChanged, stateChanged)
    if townChanged and town ~= 0 and Config.Notify.Town and TOWNS[town] then
        return MakePending(TOWNS[town], ZONE.TOWN, town)
    end
    -- leaving a town counts as re-entering the surrounding district (but walking into an unmapped town does not)
    if (districtChanged or (townChanged and town == 0)) and district ~= 0 and Config.Notify.District and DISTRICTS[district] then
        return MakePending(DISTRICTS[district], ZONE.DISTRICT, district)
    end
    if (stateChanged or districtChanged or townChanged) and state ~= 0 and Config.Notify.State and STATES[state] then
        -- only fall back to the state when the state really changed, or the district is unmapped
        if stateChanged or not DISTRICTS[district] then
            return MakePending(STATES[state], ZONE.STATE, state)
        end
    end
    return nil
end

local function FireZoneChanged(kind, key)
    TriggerEvent('rsg-zonenotify:client:zoneChanged', { kind = kind, key = key:lower(), name = Label(key) })
end

local function CheckZones(c)
    local state    = ZoneAt(c, ZONE.STATE)
    local district = ZoneAt(c, ZONE.DISTRICT)
    local town     = ZoneAt(c, ZONE.TOWN)

    local townChanged     = town ~= stored.town
    local districtChanged = district ~= stored.district
    local stateChanged    = state ~= stored.state

    if Config.Debug and (townChanged or districtChanged or stateChanged) then
        print(('[rsg-zonenotify] state=%s district=%s town=%s'):format(state, district, town))
    end

    -- other scripts can listen to this whatever the banner settings are
    local sKey, dKey, tKey = STATES[state], DISTRICTS[district], TOWNS[town]
    if stateChanged or districtChanged or townChanged then SetCurrentZone(state, district, town) end
    if stateChanged and sKey then FireZoneChanged('state', sKey) end
    if districtChanged and dKey then FireZoneChanged('district', dKey) end
    if townChanged and tKey then FireZoneChanged('town', tKey) end

    -- leaving a town, or crossing into an unmapped area, only matters when we land somewhere mapped
    local onlyLeftTown = townChanged and town == 0 and not districtChanged and not stateChanged
    if onlyLeftTown and not Config.Notify.LeaveTown then townChanged = false end

    local newPending = BestBannerFor(state, district, town, townChanged, districtChanged, stateChanged)

    -- first visit to a landmark, lake or river shows a banner once per character (scanned less often: it costs ~10 natives)
    if not newPending and not pending and Config.Discovery.Enabled and Config.Discovery.Landmarks and discoveriesLoaded then
        local now = GetGameTimer()
        if now - lastScan >= LANDMARK_SCAN_MS then
            lastScan = now
            local lm = GetWaterName(c) or GetMiscName(c)
            if lm and not discovered[lm:lower()] then
                newPending = { text = lm, kind = 'landmark', since = now, coords = c }
            end
        end
    end

    stored.state, stored.district, stored.town = state, district, town
    if newPending then pending = newPending end

    if not pending then return end

    -- banners are switched off by the player: the place still counts as discovered (silently)
    if not prefs.banners then
        MarkDiscovered(pending.text)
        pending = nil
        return
    end

    -- drop it if the player already left that zone
    if pending.zoneType and ZoneAt(c, pending.zoneType) ~= pending.hash then
        pending = nil
        return
    end
    if pending.coords and #(c - pending.coords) > 150.0 then
        pending = nil
        return
    end

    if not CanShowBanner() then
        if Config.Debug then print('[rsg-zonenotify] banner held: faded/paused/dead/disabled') end
        return
    end

    -- wait for the feed to be free, but never forever (other feed messages / tooltips can hold it)
    if Config.DisplayMode == 'native' and FeedBusy() and GetGameTimer() - pending.since < Config.MaxFeedWait then return end

    local moving = Config.DisplayMode == 'native' and GetEntitySpeed(PlayerPedId()) > Config.MovingSpeed
    if moving and Config.WhileMoving == 'wait' then return end -- hold until the player slows down

    if Config.Debug then print('[rsg-zonenotify] showing ' .. pending.text) end
    local text, kind = pending.text, pending.kind
    pending = nil
    ShowLocationUi(GetBottomParts(c), text, (moving and Config.WhileMoving == 'notify') and 'notify' or nil, kind)
end

----------------------------------------------------------------
-- manual "where am I"
----------------------------------------------------------------
local function ShowCurrentLocation()
    if not isLoggedIn or IsPauseMenuActive() or IsScreenFadedOut() or IsEntityDead(PlayerPedId()) then return end

    local now = GetGameTimer()
    if now - lastManual < Config.ManualCooldown then return end
    lastManual = now

    if Config.DisplayMode == 'native' and FeedBusy() then return end

    local ped = PlayerPedId()
    local interior = GetInteriorFromEntity(ped)
    if interior ~= 0 and not IsInteriorACave(interior) then
        Notify(locale('cl_title'), locale('cl_indoors'))
        return
    end

    local c = GetEntityCoords(ped)
    local name = GetFullLocationName(c)
    if not name then
        Notify(locale('cl_title'), locale('cl_unknown'))
        return
    end

    ShowLocationUi(GetBottomParts(c), name)
end

----------------------------------------------------------------
-- threads
----------------------------------------------------------------
CreateThread(function()
    while true do
        if not isLoggedIn then
            Wait(1000)
        else
            if bannerVisible and IsSuppressed() then HideBanner() end
            local ok, err = pcall(CheckZones, GetEntityCoords(PlayerPedId()))
            if not ok then
                pending = nil
                print('^1[rsg-zonenotify] error: ' .. tostring(err) .. '^7')
            end
            Wait(Config.CheckInterval)
        end
    end
end)

-- "where am I" key: rebindable key mapping (key NAME in Config.Key, e.g. 'L'), or the old control-hash polling
if Config.Key then
    if Config.UseKeyMapping and type(Config.Key) == 'string' then
        RSGCore.Functions.RegisterKey('rsgzonenotify_location', locale('key_location'), Config.Key, ShowCurrentLocation, nil, {
            canTrigger = function() return isLoggedIn and not IsPauseMenuActive() end,
        })
    elseif type(Config.Key) == 'number' then
        CreateThread(function()
            while true do
                if isLoggedIn then
                    if IsControlJustPressed(0, Config.Key) then ShowCurrentLocation() end
                    Wait(0)
                else
                    Wait(1000)
                end
            end
        end)
    end
end

----------------------------------------------------------------
-- journal (NUI): places found per category, leaderboard, options
----------------------------------------------------------------
local journalOpen = false
local uiFocus     = false
local lastJournal = 0

-- one place for every focus change, so push-to-talk keeps working while the journal is open
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- keep-input passes every key to the game: block all controls except push-to-talk while the journal is up
local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

local function CloseJournal()
    if not journalOpen then return end
    journalOpen = false
    uiFocus = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'journalClose' })
end

-- close the journal if the player dies or the pause menu opens
CreateThread(function()
    while true do
        if journalOpen then
            if IsEntityDead(PlayerPedId()) or IsPauseMenuActive() then CloseJournal() end
            Wait(250)
        else
            Wait(500)
        end
    end
end)

local JOURNAL_TEXT <const> = {
    'title', 'subtitle', 'cat_state', 'cat_district', 'cat_town', 'cat_landmark', 'cat_water', 'tab_leaderboard',
    'tab_options', 'claimed', 'overall', 'close', 'you', 'lb_empty', 'places', 'milestones',
    'opt_banners', 'opt_sound', 'opt_time', 'opt_temperature', 'opt_wind', 'on', 'off',
}

local function JournalText()
    local t = {}
    for _, k in ipairs(JOURNAL_TEXT) do t[k] = locale('journal_' .. k) end
    return t
end

local function BuildJournal(data, startTab)
    local found = {}
    for _, k in ipairs(data.discovered or {}) do found[k] = true end
    local claimed = data.claimed or {}
    local milestones = Config.Milestones or {}

    local categories = {}
    if Config.Discovery.Enabled then
        for _, kind in ipairs(Zones.KindOrder) do
            local places, count = {}, 0
            for _, key in ipairs(Zones.KindKeys[kind]) do
                local isFound = found[key] == true
                if isFound then count = count + 1 end
                if isFound or Config.Journal.ShowUndiscovered then
                    places[#places + 1] = { name = Label(key), found = isFound }
                else
                    places[#places + 1] = { name = '???', found = false }
                end
            end
            table.sort(places, function(a, b)
                if a.found ~= b.found then return a.found end
                return a.name < b.name
            end)
            local reward = milestones.Enabled and milestones.Categories and milestones.Categories[kind] or nil
            categories[#categories + 1] = {
                kind = kind, label = locale('journal_cat_' .. kind), found = count, total = #Zones.KindKeys[kind],
                reward = reward and { cash = reward.cash or 0, xp = reward.xp or 0 } or nil,
                claimed = claimed['cat_' .. kind] == true, places = places,
            }
        end
    end

    local overall = {}
    if Config.Discovery.Enabled and milestones.Enabled and milestones.Overall then
        local thresholds = {}
        for t in pairs(milestones.Overall) do thresholds[#thresholds + 1] = t end
        table.sort(thresholds)
        for _, t in ipairs(thresholds) do
            local r = milestones.Overall[t]
            overall[#overall + 1] = { percent = t, cash = r.cash or 0, xp = r.xp or 0, claimed = claimed['all_' .. t] == true }
        end
    end

    local board = {}
    for i, r in ipairs(data.leaderboard or {}) do
        board[i] = { rank = r.rank, name = r.name or locale('journal_anonymous', r.rank), found = r.found, me = r.me == true }
    end

    return {
        action = 'journal',
        tab = startTab,
        found = data.found or 0,
        total = Zones.KeyCount,
        categories = categories,
        overall = overall,
        leaderboard = board,
        showLeaderboard = Config.Leaderboard.Enabled and Config.Discovery.Enabled,
        prefs = prefs,
        toggles = { banners = true, sound = Config.PlayerOptions, time = Config.PlayerOptions and Config.ShowTime, temperature = Config.PlayerOptions and Config.ShowTemperature, wind = Config.PlayerOptions and Config.ShowWind },
        text = JournalText(),
    }
end

local function OpenJournal(startTab)
    if not Config.Journal.Enabled or journalOpen or not isLoggedIn then return end
    if IsPauseMenuActive() or IsScreenFadedOut() or IsEntityDead(PlayerPedId()) then return end
    local now = GetGameTimer()
    if now - lastJournal < 1000 then return end
    lastJournal = now

    CreateThread(function()
        local data = { discovered = {}, claimed = {}, leaderboard = {}, found = 0 }
        if Config.Discovery.Enabled then
            data = RSGCore.Functions.AwaitCallback('rsg-zonenotify:server:getJournal', 5000)
            if not data then
                Notify(locale('cl_title'), locale('cl_journal_unavailable'), 4000, 'error')
                return
            end
        end
        if journalOpen or not isLoggedIn then return end
        journalOpen = true
        uiFocus = true
        applyNuiFocus(true)
        SendNUIMessage(BuildJournal(data, startTab))
    end)
end

RegisterNUICallback('journalClose', function(_, cb)
    CloseJournal()
    cb('ok')
end)

-- the player flips an option in the journal; only known keys and booleans are accepted
RegisterNUICallback('journalPref', function(data, cb)
    if type(data) == 'table' and PREF_KEYS[data.key] and type(data.value) == 'boolean' then
        if data.key == 'banners' or Config.PlayerOptions then
            prefs[data.key] = data.value
            SavePrefs()
            if data.key == 'banners' and not data.value then pending = nil; HideBanner() end
        end
    end
    cb(prefs)
end)

----------------------------------------------------------------
-- rewards and milestones (the server decides and pays; this only shows the result)
----------------------------------------------------------------
RegisterNetEvent('rsg-zonenotify:client:reward', function(data)
    if type(data) ~= 'table' or not ValidKey(data.key) then return end
    local parts = {}
    local cash, xp = math.floor(tonumber(data.cash) or 0), math.floor(tonumber(data.xp) or 0)
    if cash > 0 then parts[#parts + 1] = locale('cl_reward_cash', cash) end
    if xp > 0 then parts[#parts + 1] = locale('cl_reward_xp', xp) end
    if #parts == 0 then return end
    Notify(Label(data.key), table.concat(parts, '  '), 5000, 'success')
end)

RegisterNetEvent('rsg-zonenotify:client:milestone', function(data)
    if type(data) ~= 'table' then return end
    local what
    if type(data.kind) == 'string' and Zones.KindCount[data.kind] then
        what = locale('cl_milestone_category', locale('journal_cat_' .. data.kind))
    elseif tonumber(data.percent) then
        what = locale('cl_milestone_overall', math.floor(tonumber(data.percent)) .. '%')
    else
        return
    end
    local cash, xp = math.floor(tonumber(data.cash) or 0), math.floor(tonumber(data.xp) or 0)
    if cash > 0 then what = what .. '\n' .. locale('cl_reward_cash', cash) end
    if xp > 0 then what = what .. (cash > 0 and '  ' or '\n') .. locale('cl_reward_xp', xp) end
    PlaySound('discovery')
    Notify(locale('cl_milestone_title'), what, 8000, 'success')
end)

----------------------------------------------------------------
-- commands
----------------------------------------------------------------
local suggestions = {}
local function AddCommand(name, helpKey, handler)
    if not name then return end
    RegisterCommand(name, handler, false)
    suggestions[#suggestions + 1] = { name = '/' .. name, help = helpKey }
end

local function RegisterSuggestions()
    for _, s in ipairs(suggestions) do TriggerEvent('chat:addSuggestion', s.name, locale(s.help)) end
end

local function CountDiscovered() return discoveredCount end

AddCommand(Config.Command, 'cl_cmd_location', ShowCurrentLocation)

AddCommand(Config.ToggleCommand, 'cl_cmd_toggle', function()
    prefs.banners = not prefs.banners
    SavePrefs()
    if not prefs.banners then pending = nil; HideBanner() end
    Notify(locale('cl_title'), locale(prefs.banners and 'cl_enabled' or 'cl_disabled'))
end)

if Config.Journal.Enabled then
    AddCommand(Config.Journal.Command, 'cl_cmd_journal', function() OpenJournal() end)
    if Config.UseKeyMapping and type(Config.Journal.Key) == 'string' then
        RSGCore.Functions.RegisterKey('rsgzonenotify_journal', locale('key_journal'), Config.Journal.Key, function() OpenJournal() end, nil, {
            canTrigger = function() return isLoggedIn and not IsPauseMenuActive() end,
        })
    end
end

if Config.Discovery.Enabled then
    AddCommand(Config.Discovery.Command, 'cl_cmd_places', function()
        Notify(locale('cl_title'), locale('cl_places', CountDiscovered(), Zones.KeyCount))
    end)
end

RegisterSuggestions()
-- the chat resource may start after (or restart without) us
AddEventHandler('onClientResourceStart', function(res)
    if res == 'chat' or res == 'rsg-chat' then RegisterSuggestions() end
end)

if Config.Debug then -- test command: /zonetest [delay seconds]
    RegisterCommand('zonetest', function(_, args)
        local delay = tonumber(args[1]) or 0
        if delay > 0 then print(('[rsg-zonenotify] banner in %ds - start riding'):format(delay)) end
        SetTimeout(delay * 1000, function()
            ShowLocationUi(GetBottomParts(GetEntityCoords(PlayerPedId())), 'district_heartlands')
        end)
    end, false)
end

----------------------------------------------------------------
-- player state
----------------------------------------------------------------
local function OnLoaded()
    if Config.Debug then print('[rsg-zonenotify] player loaded, zone checks running') end
    ResetStored(GetEntityCoords(PlayerPedId())) -- no banner on spawn
    isLoggedIn = true
    discovered, discoveredCount, discoveriesLoaded = {}, 0, false
    loadGeneration = loadGeneration + 1
    local generation = loadGeneration
    if Config.Discovery.Enabled then
        RSGCore.Functions.TriggerCallback('rsg-zonenotify:server:getDiscoveries', function(list)
            if generation ~= loadGeneration then return end -- character changed while waiting
            for _, k in ipairs(list or {}) do
                if not discovered[k] then discovered[k] = true; discoveredCount = discoveredCount + 1 end
            end
            discoveriesLoaded = true
        end)
    end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', OnLoaded)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    if journalOpen then CloseJournal() end
    isLoggedIn = false
    pending = nil
    loadGeneration = loadGeneration + 1
    discovered, discoveredCount, discoveriesLoaded = {}, 0, false
    HideBanner()
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then OnLoaded() end
end)

AddEventHandler('onResourceStop', function(res)
    if suppressed[res] then suppressed[res] = nil end -- a resource that suppressed us is gone
    if res ~= GetCurrentResourceName() then return end
    if journalOpen then CloseJournal() end
    for _, s in ipairs(suggestions) do TriggerEvent('chat:removeSuggestion', s.name) end
    HideBanner()
end)

----------------------------------------------------------------
-- custom banners (other resources: ferry, trams, guarma...)
----------------------------------------------------------------
local function ShowBanner(title, subtitle, duration)
    if type(title) ~= 'string' or title == '' or not isLoggedIn or not prefs.banners or IsSuppressed() then return false end
    title = title:sub(1, 64)
    subtitle = type(subtitle) == 'string' and subtitle:sub(1, 120) or nil
    duration = math.min(math.max(tonumber(duration) or Config.DisplayTime, 1000), 15000)
    PlaySound('custom')
    if Config.DisplayMode == 'nui' then
        SendNUIMessage({ action = 'show', title = title, flavour = subtitle, parts = {}, duration = duration, queue = Config.BannerQueue })
        bannerVisible = true
    else
        Notify(title, subtitle or '', duration)
    end
    return true
end

RegisterNetEvent('rsg-zonenotify:client:showBanner', function(data)
    if type(data) ~= 'table' then return end
    ShowBanner(data.title, data.subtitle, data.duration)
end)

-- other resources hide the banner while their camera runs: SetSuppressed('moviemaker', true)
local function SetSuppressed(reason, state)
    if type(reason) ~= 'string' then return end
    suppressed[reason] = state and true or nil
    if state then pending = nil; HideBanner() end
end

exports('ShowCurrentLocation', ShowCurrentLocation)
exports('ShowBanner', ShowBanner)
exports('SetSuppressed', SetSuppressed)
exports('IsDiscovered', function(key) return type(key) == 'string' and discovered[key:lower()] == true end)
exports('GetDiscoveryCount', CountDiscovered)
exports('OpenJournal', function(tab) OpenJournal(tab) end)
exports('CloseJournal', CloseJournal)
-- { state = 'state_lemoyne', district = 'district_heartlands', town = 'town_valentine' } (lower-case keys, nil when unmapped)
exports('GetCurrentZone', function() return { state = currentZone.state, district = currentZone.district, town = currentZone.town } end)
