-- rsg-zonenotify zone data (shared: the client names places, the server whitelists discovery keys)
-- Zone data ported from VORPCORE/vorp_zonenotify (credits: freedy69 / Bytesized).
Zones = {}

Zones.TOWNS = {
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

Zones.TEXT_WRITTEN = {
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

Zones.TEXT_PRINTED = {
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

Zones.LAKES = {
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

Zones.SWAMPS = {
    [`WATER_BAYOU_NWA`] = 'district_bayou_nwa'
}

Zones.OCEANS = {
    [`WATER_BAHIA_DE_LA_PAZ`] = 'WATER_BAHIA_DE_LA_PAZ'
}

Zones.CREEKS = {
    [`WATER_DEADBOOT_CREEK`] = 'WATER_DEADBOOT_CREEK',
    [`WATER_HAWKS_EYE_CREEK`] = 'WATER_HAWKS_EYE_CREEK',
    [`WATER_RINGNECK_CREEK`] = 'WATER_RINGNECK_CREEK',
    [`WATER_SPIDER_GORGE`] = 'WATER_SPIDER_GORGE',
    [`WATER_STILLWATER_CREEK`] = 'WATER_STILLWATER_CREEK',
    [`WATER_WHINYARD_STRAIT`] = 'WATER_WHINYARD_STRAIT'
}

Zones.PONDS = {
    [`WATER_CAIRN_LAKE`] = 'WATER_CAIRN_LAKE',
    [`WATER_CATTIAL_POND`] = 'WATER_CATTAIL_POND',
    [`WATER_HOT_SPRINGS`] = 'WATER_COTORRA_SPRINGS',
    [`WATER_MATTLOCK_POND`] = 'WATER_MATTLOCK_POND',
    [`WATER_MOONSTONE_POND`] = 'WATER_MOONSTONE_POND',
    [`WATER_SOUTHFIELD_FLATS`] = 'WATER_SOUTHFIELD_FLATS'
}

Zones.DISTRICTS = {
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

Zones.STATES = {
    [`Ambarino`] = 'STATE_AMBARINO',
    [`Guarma`] = 'state_guarma',
    [`lemoyne`] = 'state_lemoyne',
    [`LowerWestElizabeth`] = 'state_west_elizabeth',
    [`UpperWestElizabeth`] = 'state_west_elizabeth',
    [`WestElizabeth`] = 'state_west_elizabeth',
    [`NewAustin`] = 'state_new_austin',
    [`NewHanover`] = 'state_new_hanover'
}

Zones.RIVERS = {
    [`WATER_ARROYO_DE_LA_VIBORA`] = 'WATER_ARROYO_DE_LA_VIBORA',
    [`WATER_DAKOTA_RIVER`] = 'WATER_DAKOTA_RIVER',
    [`WATER_LANNAHECHEE_RIVER`] = 'WATER_LANNAHECHEE_RIVER',
    [`WATER_LITTLE_CREEK_RIVER`] = 'WATER_LITTLE_CREEK_RIVER',
    [`WATER_LOWER_MONTANA_RIVER`] = 'WATER_LOWER_MONTANA_RIVER',
    [`WATER_UPPER_MONTANA_RIVER`] = 'WATER_UPPER_MONTANA_RIVER'
}

----------------------------------------------------------------
-- every place key a character can discover (lower-case), with its category.
-- Zones.Keys      [key] = true          (server whitelist)
-- Zones.Kind      [key] = 'state' | 'district' | 'town' | 'landmark' | 'water'
-- Zones.KindKeys  [kind] = { key, ... } (sorted)
-- Zones.KindCount [kind] = n,  Zones.KeyCount = total
----------------------------------------------------------------
Zones.KindOrder = { 'state', 'district', 'town', 'landmark', 'water' }

local KIND_TABLES <const> = {
    { 'state',    { 'STATES' } },
    { 'district', { 'DISTRICTS' } },
    { 'town',     { 'TOWNS' } },
    { 'water',    { 'LAKES', 'RIVERS', 'SWAMPS', 'OCEANS', 'CREEKS', 'PONDS' } },
    { 'landmark', { 'TEXT_WRITTEN', 'TEXT_PRINTED' } },
}

-- names built in code (client GetWaterName / GetMiscName)
local EXTRA <const> = {
    { 'water',    'WATER_KAMASSA_RIVER' },
    { 'water',    'WATER_KAMASSA_RIVER_BLUEWATER_MARSH' },
    { 'water',    'WATER_KAMASSA_RIVER_BAYOU_NWA' },
    { 'water',    'WATER_SAN_LUIS_RIVER_NEW_AUSTIN' },
    { 'water',    'water_san_luis_river_west_elizabeth' },
    { 'landmark', 'HIDEOUT_BEAVER_HOLLOW' },
    { 'landmark', 'LANDMARK_BACCHUS_BRIDGE' },
    { 'landmark', 'LANDMARK_CUMBERLAND_FALLS' },
}

Zones.Keys, Zones.Kind, Zones.KindKeys, Zones.KindCount, Zones.Original = {}, {}, {}, {}, {}  -- Original[lower] = key as written (label keys are case sensitive)
Zones.KeyCount = 0
for _, kind in ipairs(Zones.KindOrder) do Zones.KindKeys[kind] = {}; Zones.KindCount[kind] = 0 end

local function addKey(kind, key)
    if Zones.Keys[key:lower()] then return end -- first category wins
    local original = key
    key = key:lower()
    Zones.Keys[key] = true
    Zones.Original[key] = original
    Zones.Kind[key] = kind
    Zones.KindKeys[kind][#Zones.KindKeys[kind] + 1] = key
    Zones.KindCount[kind] = Zones.KindCount[kind] + 1
    Zones.KeyCount = Zones.KeyCount + 1
end

for _, group in ipairs(KIND_TABLES) do
    for _, name in ipairs(group[2]) do
        for _, key in pairs(Zones[name]) do addKey(group[1], key) end
    end
end
for _, e in ipairs(EXTRA) do addKey(e[1], e[2]) end
for _, kind in ipairs(Zones.KindOrder) do table.sort(Zones.KindKeys[kind]) end
