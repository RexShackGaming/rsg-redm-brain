-- rsg-zonenotify
-- Shows a location banner (custom NUI or native RDR2) when you enter a new state, district or town.
-- Zone data ported from VORPCORE/vorp_zonenotify (credits: freedy69 / Bytesized).
lib.locale()

local ZONE <const> = {
    STATE = 0, TOWN = 1, LAKE = 2, RIVER = 3, SWAMP = 5, OCEAN = 6,
    CREEK = 7, POND = 8, DISTRICT = 10, TEXT_PRINTED = 11, TEXT_WRITTEN = 12
}

local KVP_KEY <const> = 'rsg-zonenotify:enabled'

local isLoggedIn  = false
local enabled     = GetResourceKvpInt(KVP_KEY) ~= 2 -- 2 = player turned banners off
local stored      = { state = 0, district = 0, town = 0 }
local pending     = nil -- banner waiting for the feed to be free: { text, zoneType, hash }
local lastManual  = 0

----------------------------------------------------------------
-- zone data (built once, not on every lookup)
----------------------------------------------------------------
local TOWNS <const> = {
    [459833523] = 'TOWN_VALENTINE',    -- valentine
    [2046780049] = 'TOWN_RHODES',      -- rhodes
    [-765540529] = 'TOWN_SAINTDENIS',  -- saint denis
    [427683330] = 'TOWN_STRAWBERRY',   -- strawberry
    [1053078005] = 'TOWN_BLACKWATER',  -- blackwater
    [-744494798] = 'TOWN_ARMADILLO',   -- armadillo
    [-1524959147] = 'TOWN_TUMBLEWEED', -- tumbleweed
    [7359335] = 'TOWN_ANNESBURG',      -- annesburg
    [2126321341] = 'TOWN_VANHORN',     -- van horn
    [201158410] = 'TOWN_MANICATO',
    [1463094051] = 'SETTLEMENT_MANZANITA_POST'
}

local TEXT_WRITTEN <const> = {
    [1350749955] = 'LANDMARK_MERKINS_WALLER',
    [1062452343] = 'LANDMARK_MACOMBS_END',
    [30800579] = 'LANDMARK_HAGEN_ORCHARDS',
    [866178028] = 'HIDEOUT_SHADY_BELLE',
    [930788089] = 'LANDMARK_SILTWATER_STRAND',
    [-419963911] = 'SETTLEMENT_APPLESEED_TIMBER_CO',
    [1212679502] = 'LANDMARK_BERYLS_DREAM',
    [-828659305] = 'SETTLEMENT_FORT_RIGGS_HOLDING_CAMP',
    [-103399754] = 'HIDEOUT_HANGING_DOG_RANCH',
    [-576782619] = 'HOMESTEAD_LONE_MULE_STEAD',
    [-1521776363] = 'HOMESTEAD_PAINTED_SKY',
    [-120578354] = 'SETTLEMENT_PRONGHORN_RANCH', -- only shown when the mansion IPL is active (see below)
    [-504005310] = 'HOMESTEAD_SHEPHERDS_RISE',
    [-1161186391] = 'HOMESTEAD_WATSONS_CABIN',
    [580715948] = 'LANDMARK_CANEBREAK_MANOR',
    [1082216465] = 'LANDMARK_COPPERHEAD_LANDING',
    [-61172588] = 'SETTLEMENT_COOTS_CHAPEL',
    [1544029611] = 'SETTLEMENT_RIDGEWOOD_FARM',
    [738939338] = 'LANDMARK_RILEYS_CHARGE',
    [-146460093] = 'HOMESTEAD_FIRWOOD_RISE',
    [2056953687] = 'HIDEOUT_SIX_POINT_CABIN',
    [39999178] = 'HIDEOUT_GAPTOOTH_BREACH',
    [1677148641] = 'SETTLEMENT_BEECHERS_HOPE',
    [-1043500161] = 'HOMESTEAD_ADLER_RANCH',
    [-2034338067] = 'HOMESTEAD_CHEZ_PORTER',
    [-1496551068] = 'HIDEOUT_COLTER',
    [2132554759] = 'LANDMARK_MILLESANI_CLAIM',
    [-438809735] = 'LANDMARK_THE_LOFT',
    [-291091669] = 'LANDMARK_OLD_GREENBANK_MILL',
    [-1902025470] = 'HOMESTEAD_CARMODY_DELL',
    [492552869] = 'SETTLEMENT_CORNWALL_KEROSENE_TAR',
    [-1472363892] = 'HOMESTEAD_GUTHRIE_FARM',
    [-657053325] = 'HOMESTEAD_DOWNES_RANCH',
    [-870780939] = 'LANDMARK_GRANGERS_HOGGERY',
    [1767462106] = 'HOMESTEAD_LARNED_SOD',
    [229479634] = 'LANDMARK_LUCKYS_CABIN',
    [219097977] = 'HOMESTEAD_ABERDEEN_PIG_FARM',
    [-425430549] = 'SETTLEMENT_BUTCHER_CREEK',
    [-969933882] = 'LANDMARK_BLACK_BALSAM_RISE',
    [-645154787] = 'HOMESTEAD_DOVERHILL',
    [-1592070727] = 'HOMESTEAD_MACLEANS_HOUSE',
    [1016304714] = 'LANDMARK_MOSSY_FLATS',
    [-154855189] = 'HOMESTEAD_WILLARDS_REST',
    [1701820039] = 'HOMESTEAD_CATFISH_JACKSONS',
    [1830267951] = 'HIDEOUT_CLEMENS_POINT',
    [522499758] = 'HOMESTEAD_COMPSONS_STEAD',
    [-1769528472] = 'HOMESTEAD_HILL_HAVEN_RANCH',
    [770707682] = 'HOMESTEAD_LONNIES_SHACK',
    [-259784188] = 'LANDMARK_RADLEYS_PASTURE',
    [-264897431] = 'LANDMARK_BEAR_CLAW',
    [1557904547] = 'SETTLEMENT_CENTRAL_UNION_RAILROAD_CAMP',
    [-1419869345] = 'LANDMARK_TANNERS_REACH',
    [690770514] = 'LANDMARK_VALLEY_VIEW',
    [-545967610] = 'LANDMARK_EWING_BASIN',
    -- test the ones below
    [`W_5_BEAVER_HOLLOW`] = 'HIDEOUT_BEAVER_HOLLOW',
    [`w_4_pleasance`] = 'LANDMARK_PLEASANCE_HOUSE',
    [`w_5_limpany`] = 'SETTLEMENT_LIMPANY',
    [`W_4_SCRATCHING_POST`] = 'LANDMARK_SCRATCHING_POST',
    [`W_4_ODDFELLOWS_REST`] = 'LANDMARK_ODDFELLOWS_REST',
    [`W_4_RATTLESNAKE_HOLLOW`] = 'LANDMARK_RATTLESNAKE_HOLLOW',
    [`W_4_SILENT_STEAD`] = 'LANDMARK_SILENT_STEAD',
    [`W_4_THE_HANGING_ROCK`] = 'LANDMARK_THE_HANGING_ROCK',
    [`W_4_THE_OLD_BACCHUS_PLACE`] = 'LANDMARK_THE_OLD_BACCHUS_PLACE',
    [`W_4_TWO_CROWS`] = 'LANDMARK_TWO_CROWS',
    [`W_4_REPENTANCE`] = 'LANDMARK_REPENTANCE',
    [`W_4_PIKES_BASIN`] = 'HIDEOUT_PIKES_BASIN',
    [`W_4_EL_NIDO`] = 'SETTLEMENT_EL_NIDO',
    [`W_4_BRITTLEBRUSH_TRAWL`] = 'LANDMARK_BRITTLEBUSH_TRAWL',
    [`W_4_VENTERS_PLACE`] = 'LANDMARK_VENTERS_PLACE',
    [`W_5_CHADWICK_FARM`] = 'HOMESTEAD_CHADWICK_FARM',
    [`W_5_BLACK_BONE_FOREST`] = 'LANDMARK_BLACK_BONE_FOREST',
    [`W_4_CUEVA_SECA`] = 'LANDMARK_CUEVA_SECA',
    [`W_4_SOLOMONS_FOLLY`] = 'HIDEOUT_SOLOMONS_FOLLY',
    [`W_5_FORT_BRENNAND`] = 'LANDMARK_FORT_BRENNAND',
    [`W_4_HORSESHOE_OVERLOOK`] = 'HIDEOUT_HORSESHOE_OVERLOOK',
    [`W_4_RIO_DEL_LOBO_HOUSE`] = 'LANDMARK_RIO_DEL_LOBO_HOUSE',
    [`W_5_BROKEN_TREE`] = 'LANDMARK_BROKEN_TREE',
    [`W_4_FACE_ROCK`] = 'LANDMARK_FACE_ROCK',
    [`W_4_NEKOTI_ROCK`] = 'LANDMARK_NEKOTI_ROCK'
}

local TEXT_PRINTED <const> = {
    [894611678] = 'SETTLEMENT_LAGRAS',
    [466986025] = 'HIDEOUT_LAKAY',
    [-1225359404] = 'LANDMARK_MONTOS_REST',
    [1573733873] = 'LANDMARK_OWANJILA_DAM',
    [769580703] = 'LANDMARK_RIGGS_STATION',
    [-1532919875] = 'TOWN_MACFARLANES_RANCH',
    [1453682244] = 'LANDMARK_WALLACE_STATION',
    [1106871234] = 'SETTLEMENT_SISIKA_PENITENTIARY',
    [-1988735197] = 'HIDEOUT_TWIN_ROCKS',
    [-99881305] = 'SETTLEMENT_FORT_WALLACE',
    [-864457539] = 'SETTLEMENT_RATHSKELLER_FORK',
    [721024961] = 'LANDMARK_QUAKERS_COVE',
    --[1737121879] = 'LANDMARK_QUAKERS_COVE', -- prolly not correct, this is hash for P_3_SAN_LUIS_RIVER
    [422513214] = 'LANDMARK_CALUMET_RAVINE',
    [-735849380] = 'SETTLEMENT_WAPITI',
    [1246510947] = 'LANDMARK_WINDOW_ROCK',
    [-2038495927] = 'LANDMARK_TEMPEST_RIM',
    [-1288973891] = 'SETTLEMENT_AGUASDULCES',
    [-2028095666] = 'LANDMARK_CINCO_TORRES',
    [1073515151] = 'LANDMARK_LA_CAPILLA',
    [903669278] = 'SETTLEMENT_THIEVES_LANDING',
    [206751400] = 'LANDMARK_BACCHUS_BRIDGE', -- so this IS correct
    [350117545] = 'SETTLEMENT_EMERALD_RANCH',
    [-847222477] = 'LANDMARK_FLATNECK_STATION',
    -- [-2001518509] = 'HIDEOUT_BEAVER_HOLLOW',
    [`P_5_BRANDYWINE_DROP`] = 'LANDMARK_BRANDYWINE_DROP', -- USED TO BE 1595262844, TEST THIS
    [1490773376] = 'LANDMARK_ROANOKE_VALLEY',
    [-745404624] = 'SETTLEMENT_BENEDICT_POINT',
    [-1037423548] = 'HIDEOUT_FORT_MERCER',
    [278622988] = 'SETTLEMENT_PLAINVIEW',
    [-166839571] = 'SETTLEMENT_BRAITHWAITE_MANOR',
    [-67181220] = 'LANDMARK_BOLGER_GLADE',
    [2084778330] = 'SETTLEMENT_CALIGA_HALL',
    -- check these
    [`P_3_MOUNT_HAGEN`] = 'LANDMARK_MOUNT_HAGEN',
    [`P_4_JORGES_GAP`] = 'LANDMARK_JORGES_GAP',
    [`p_4_mercer_station`] = 'LANDMARK_MERCER_STATION',
    [`P_4_BENEDICT_PASS`] = 'LANDMARK_BENEDICT_PASS',
    [`P_4_MANTECA_FALLS`] = 'WATER_MANTECA_FALLS',
    [`P_4_MOUNT_SHANN`] = 'WATER_MOUNT_SHANN',
    [`P_4_THREE_SISTERS`] = 'LANDMARK_THREE_SISTERS',
    [`P_3_ERIS_FIELD`] = 'LANDMARK_ERIS_FIELD',
    [`P_4_GRANITE_PASS`] = 'LANDMARK_GRANITE_PASS',
    [`P_4_CITADEL_ROCK`] = 'LANDMARK_CITADEL_ROCK',
    [`P_3_DEWBERRY_CREEK`] = 'LANDMARK_DEWBERRY_CREEK',
    [`P_4_DIABLO_RIDGE`] = 'LANDMARK_DIABLO_RIDGE',
    [`P_4_DONNER_FALLS`] = 'LANDMARK_DONNER_FALLS',
    [`P_4_CALIBANS_SEAT`] = 'LANDMARK_CALIBANS_SEAT',
    [`P_4_RIO_DEL_LOBO_ROCK`] = 'LANDMARK_RIO_DEL_LOBO_ROCK',
    [`P_4_BARDS_CROSSING`] = 'LANDMARK_BARDS_CROSSING',
    [`P_3_HEARTLAND_OVERFLOW`] = 'LANDMARK_HEARTLAND_OVERFLOW'
}

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

local LAKES <const> = {
    [`WATER_AURORA_BASIN`] = 'WATER_AURORA_BASIN',
    [`WATER_BARROW_LAGOON`] = 'WATER_BARROW_LAGOON',
    [`WATER_ELYSIAN_POOL`] = 'WATER_ELYSIAN_POOL',
    [`WATER_FLAT_IRON_LAKE`] = 'WATER_FLAT_IRON_LAKE',
    [`WATER_HEARTLANDS_OVERFLOW`] = 'LANDMARK_HEARTLAND_OVERFLOW',
    [`WATER_LAKE_DON_JULIO`] = 'WATER_LAKE_DON_JULIO',
    [`WATER_LAKE_ISABELLA`] = 'WATER_LAKE_ISABELLA',
    [`WATER_O_CREAGHS_RUN`] = 'WATER_OCREAGHS_RUN',
    [`WATER_OWANJILA`] = 'WATER_OWANJILA',
    [`WATER_SEA_OF_CORONADO`] = 'WATER_SEA_OF_CORONADO'
}

local SWAMPS <const> = {
    [`WATER_BAYOU_NWA`] = 'district_bayou_nwa'
}

local OCEANS <const> = {
    [`WATER_BAHIA_DE_LA_PAZ`] = 'WATER_BAHIA_DE_LA_PAZ'
}

local CREEKS <const> = {
    [`WATER_DEADBOOT_CREEK`] = 'WATER_DEADBOOT_CREEK',
    [`WATER_HAWKS_EYE_CREEK`] = 'WATER_HAWKS_EYE_CREEK',
    [`WATER_RINGNECK_CREEK`] = 'WATER_RINGNECK_CREEK',
    [`WATER_SPIDER_GORGE`] = 'WATER_SPIDER_GORGE',
    [`WATER_STILLWATER_CREEK`] = 'WATER_STILLWATER_CREEK',
    [`WATER_WHINYARD_STRAIT`] = 'WATER_WHINYARD_STRAIT'
}

local PONDS <const> = {
    [`WATER_CAIRN_LAKE`] = 'WATER_CAIRN_LAKE',
    [`WATER_CATTIAL_POND`] = 'WATER_CATTAIL_POND',
    [`WATER_HOT_SPRINGS`] = 'WATER_COTORRA_SPRINGS',
    [`WATER_MATTLOCK_POND`] = 'WATER_MATTLOCK_POND',
    [`WATER_MOONSTONE_POND`] = 'WATER_MOONSTONE_POND',
    [`WATER_SOUTHFIELD_FLATS`] = 'WATER_SOUTHFIELD_FLATS'
}

local DISTRICTS <const> = {
    [2025841068] = 'district_bayou_nwa',
    [822658194] = 'district_big_valley',
    [1308232528] = 'district_bluewater_marsh',
    [1835499550] = 'district_cumberland_forest',
    [476637847] = 'DISTRICT_GREAT_PLAINS',
    [1645618177] = 'district_grizzlies', -- grizzlies west
    [-120156735] = 'district_grizzlies', -- grizzlies east
    [-512529193] = 'district_guarma',
    [131399519] = 'district_heartlands',
    [178647645] = 'district_roanoake_ridge',
    [-864275692] = 'district_scarlett_meadows',
    [1684533001] = 'district_tall_Trees',
    [-2066240242] = 'district_gaptooth_ridge',
    [-2145992129] = 'district_rio_bravo',
    [-108848014] = 'district_cholla_springs',
    [892930832] = 'DISTRICT_HENNIGANS_STEAD'
}

local STATES <const> = {
    [`Ambarino`] = 'STATE_AMBARINO',
    [`Guarma`] = 'state_guarma',
    [`lemoyne`] = 'state_lemoyne',
    [`LowerWestElizabeth`] = 'state_west_elizabeth',
    [`UpperWestElizabeth`] = 'state_west_elizabeth',
    [`WestElizabeth`] = 'state_west_elizabeth',
    [`NewAustin`] = 'state_new_austin',
    [`NewHanover`] = 'state_new_hanover'
}

local RIVERS <const> = {
    [`WATER_ARROYO_DE_LA_VIBORA`] = 'WATER_ARROYO_DE_LA_VIBORA',
    [`WATER_DAKOTA_RIVER`] = 'WATER_DAKOTA_RIVER',
    [`WATER_LANNAHECHEE_RIVER`] = 'WATER_LANNAHECHEE_RIVER',
    [`WATER_LITTLE_CREEK_RIVER`] = 'WATER_LITTLE_CREEK_RIVER',
    [`WATER_LOWER_MONTANA_RIVER`] = 'WATER_LOWER_MONTANA_RIVER',
    [`WATER_UPPER_MONTANA_RIVER`] = 'WATER_UPPER_MONTANA_RIVER'
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

local function GetBigInt(value)
    local buf = DataView.ArrayBuffer(16)
    buf:SetInt64(0, value)
    return buf:GetInt64(0)
end

local function FeedBusy()
    -- UI_FEED_GET_CURRENT_MESSAGE
    return Citizen.InvokeNative(0xC17F69E1418CD11F, 2, Citizen.ResultAsInteger()) ~= 0
end

-- turn a game label key (e.g. 'district_heartlands') into its display text
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

-- turn a game label key (e.g. 'district_heartlands') into its display text
local function Label(key)
    if Config.LabelNames and Config.LabelNames[key] then return Config.LabelNames[key] end
    for _, k in ipairs({ key, key:upper() }) do
        local ok, txt = pcall(GetLabelText, k)
        if ok and IsGoodLabel(txt, key) then return txt end
    end
    return Prettify(key)
end

local function StripCodes(text)
    return (text:gsub('~[%w_]+~', ''))
end

local function ShowLocationUi(bottomText, topText, mode)
    local title = Label(topText)
    mode = mode or Config.DisplayMode

    if mode == 'nui' then
        -- split "~COLOR_X~text ~COLOR_WHITE~| ~COLOR_Y~text" into coloured parts
        local parts = {}
        for seg in (bottomText .. ' ~COLOR_WHITE~| '):gmatch('(.-) ~COLOR_WHITE~| ') do
            local code, txt = seg:match('^~([%w_]+)~(.*)$')
            txt = StripCodes(txt or seg)
            if txt ~= '' then
                parts[#parts + 1] = { text = txt, color = code and Config.NuiColors[code] or nil }
            end
        end
        SendNUIMessage({ action = 'show', title = title, parts = parts, duration = Config.DisplayTime })
        return
    end

    if mode == 'notify' then
        lib.notify({ title = title, description = StripCodes(bottomText), type = 'inform', duration = Config.DisplayTime })
        return
    end

    local str1 = CreateVarString(10, 'LITERAL_STRING', title)
    local str2 = CreateVarString(10, 'LITERAL_STRING', bottomText)
    local struct1 = DataView.ArrayBuffer(8 * 7)
    local struct2 = DataView.ArrayBuffer(8 * 5)
    struct1:SetInt32(8 * 0, Config.DisplayTime)
    struct2:SetInt64(8 * 1, GetBigInt(str1))
    struct2:SetInt64(8 * 2, GetBigInt(str2))
    -- _UI_FEED_POST_LOCATION_SHARD(duration*, data*, p2, p3)
    local id = Citizen.InvokeNative(0xD05590C1AB38F068, struct1:Buffer(), struct2:Buffer(), 0, 1, Citizen.ResultAsInteger())
    if Config.Debug then print(('[rsg-zonenotify] shard posted id=%s title=%s'):format(tostring(id), title)) end
end

local function FormatTime(h, m)
    if ShouldUse_24HourClock() then return ('%02d:%02d'):format(h, m) end
    local period = locale(h >= 12 and 'cl_time_pm' or 'cl_time_am')
    h = h % 12
    return ('%d:%02d%s'):format(h == 0 and 12 or h, m, period)
end

local function GetBottomText(c)
    local parts = {}
    local gameMetric = ShouldUseMetricTemperature()
    local tempUnit, speedUnit = Config.TemperatureUnit or 'auto', Config.SpeedUnit or 'auto'
    local celsius = tempUnit == 'celsius' or (tempUnit ~= 'fahrenheit' and gameMetric)
    local kmh = speedUnit == 'kmh' or (speedUnit ~= 'mph' and gameMetric)

    if Config.ShowTime then
        local h, m = GetClockHours(), GetClockMinutes()
        local night = h >= Config.NightStart or h < Config.NightEnd
        parts[#parts + 1] = (night and Config.TimeNightColor or Config.TimeDayColor) .. FormatTime(h, m)
    end

    if Config.ShowTemperature then
        local t = GetTemperatureAtCoords(c.x, c.y, c.z)
        local col = t < Config.TemperatureColdDegree and Config.TemperatureColdColor or Config.TemperatureHotColor
        parts[#parts + 1] = col .. (celsius and locale('cl_temp_c', math.ceil(t)) or locale('cl_temp_f', math.ceil(t * 9 / 5 + 32)))
    end

    if Config.ShowWind then
        local w = GetWindSpeed()
        parts[#parts + 1] = Config.WindColor .. (kmh and locale('cl_wind_kph', math.floor(w)) or locale('cl_wind_mph', math.floor(w * 0.621371)))
    end

    return table.concat(parts, ' ~COLOR_WHITE~| ')
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
    return enabled and not IsScreenFadedOut() and not IsPauseMenuActive() and not IsEntityDead(cache.ped)
end

local function ResetStored(c)
    stored.state    = ZoneAt(c, ZONE.STATE)
    stored.district = ZoneAt(c, ZONE.DISTRICT)
    stored.town     = ZoneAt(c, ZONE.TOWN)
    pending = nil
end

local function MakePending(text, zoneType, hash)
    return { text = text, zoneType = zoneType, hash = hash, since = GetGameTimer() }
end

-- best banner for where the player is now (town > district > state), skipping unmapped zones
local function BestBannerFor(state, district, town, townChanged, districtChanged, stateChanged)
    if townChanged and town ~= 0 and Config.Notify.Town and TOWNS[town] then
        return MakePending(TOWNS[town], ZONE.TOWN, town)
    end
    -- leaving a town counts as re-entering the surrounding district
    if (districtChanged or townChanged) and district ~= 0 and Config.Notify.District and DISTRICTS[district] then
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

    -- leaving a town, or crossing into an unmapped area, only matters when we land somewhere mapped
    local onlyLeftTown = townChanged and town == 0 and not districtChanged and not stateChanged
    if onlyLeftTown and not Config.Notify.LeaveTown then townChanged = false end

    local newPending = BestBannerFor(state, district, town, townChanged, districtChanged, stateChanged)

    stored.state, stored.district, stored.town = state, district, town
    if newPending then pending = newPending end

    if not pending then return end

    -- drop it if the player already left that zone
    if ZoneAt(c, pending.zoneType) ~= pending.hash then
        pending = nil
        return
    end

    if not CanShowBanner() then
        if Config.Debug then print('[rsg-zonenotify] banner held: faded/paused/dead/disabled') end
        return
    end

    -- wait for the feed to be free, but never forever (other feed messages / tooltips can hold it)
    if Config.DisplayMode == 'native' and FeedBusy() and GetGameTimer() - pending.since < Config.MaxFeedWait then return end

    local moving = Config.DisplayMode == 'native' and GetEntitySpeed(cache.ped) > Config.MovingSpeed
    if moving and Config.WhileMoving == 'wait' then return end -- hold until the player slows down

    if Config.Debug then print('[rsg-zonenotify] showing ' .. pending.text) end
    local text = pending.text
    pending = nil
    ShowLocationUi(GetBottomText(c), text, (moving and Config.WhileMoving == 'notify') and 'notify' or nil)
end

----------------------------------------------------------------
-- manual "where am I"
----------------------------------------------------------------
local function ShowCurrentLocation()
    if not isLoggedIn or IsPauseMenuActive() or IsScreenFadedOut() or IsEntityDead(cache.ped) then return end

    local now = GetGameTimer()
    if now - lastManual < Config.ManualCooldown then return end
    lastManual = now

    if Config.DisplayMode == 'native' and FeedBusy() then return end

    local ped = cache.ped
    local interior = GetInteriorFromEntity(ped)
    if interior ~= 0 and not IsInteriorACave(interior) then
        lib.notify({ title = locale('cl_title'), description = locale('cl_indoors'), type = 'inform' })
        return
    end

    local c = GetEntityCoords(ped)
    local name = GetFullLocationName(c)
    if not name then
        lib.notify({ title = locale('cl_title'), description = locale('cl_unknown'), type = 'inform' })
        return
    end

    ShowLocationUi(GetBottomText(c), name)
end

----------------------------------------------------------------
-- threads
----------------------------------------------------------------
CreateThread(function()
    while true do
        if isLoggedIn then
            local ok, err = pcall(CheckZones, GetEntityCoords(cache.ped))
            if not ok then
                pending = nil
                print('^1[rsg-zonenotify] error: ' .. tostring(err) .. '^7')
            end
            Wait(Config.CheckInterval)
        else
            Wait(1000)
        end
    end
end)

if Config.Key then
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

----------------------------------------------------------------
-- commands
----------------------------------------------------------------
if Config.Command then
    RegisterCommand(Config.Command, ShowCurrentLocation, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, locale('cl_cmd_location'))
end

if Config.ToggleCommand then
    RegisterCommand(Config.ToggleCommand, function()
        enabled = not enabled
        SetResourceKvpInt(KVP_KEY, enabled and 1 or 2)
        if not enabled then pending = nil; SendNUIMessage({ action = 'hide' }) end
        lib.notify({ title = locale('cl_title'), description = locale(enabled and 'cl_enabled' or 'cl_disabled'), type = 'inform' })
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.ToggleCommand, locale('cl_cmd_toggle'))
end

----------------------------------------------------------------
-- player state
----------------------------------------------------------------
local function OnLoaded()
    if Config.Debug then print('[rsg-zonenotify] player loaded, zone checks running') end
    ResetStored(GetEntityCoords(cache.ped)) -- no banner on spawn
    isLoggedIn = true
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', OnLoaded)

local function HideBanner()
    if Config.DisplayMode == 'nui' then SendNUIMessage({ action = 'hide' }) end
end

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    pending = nil
    HideBanner()
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then OnLoaded() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Config.Command then TriggerEvent('chat:removeSuggestion', '/' .. Config.Command) end
    if Config.ToggleCommand then TriggerEvent('chat:removeSuggestion', '/' .. Config.ToggleCommand) end
end)

if Config.Debug then -- test command: /zonetest [delay seconds]
    RegisterCommand('zonetest', function(_, args)
        local delay = tonumber(args[1]) or 0
        if delay > 0 then print(('[rsg-zonenotify] banner in %ds - start riding'):format(delay)) end
        SetTimeout(delay * 1000, function()
            ShowLocationUi(GetBottomText(GetEntityCoords(cache.ped)), 'district_heartlands')
        end)
    end, false)
end

exports('ShowCurrentLocation', ShowCurrentLocation)
