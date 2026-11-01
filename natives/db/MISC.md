# MISC natives (288)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ABSF
`0x134549B388167CBF` | `float ABSF(float value)` | build 1207

## ABSI
`0x0C214D5B8A38C828` | `int ABSI(int value)` | build 1207

## ACOS
`0x586690F0176DC575` | `float ACOS(float p0)` | build 1207

## ACTION_MANAGER_ENABLE_ACTION
`0x7ACF124C12A2B045` | `void ACTION_MANAGER_ENABLE_ACTION(Hash hash, BOOL enable)` | build 1207
Appears to remove stealth kill action from memory (?)

## ACTION_MANAGER_IS_ACTION_ENABLED
`0xFD0759658268FD8E` | `BOOL ACTION_MANAGER_IS_ACTION_ENABLED(Hash hash)` | build 1207

## ACTIVITY_FEED_ACTION_START_WITH_COMMAND_LINE
`0x91D657230BC208D2` | `void ACTIVITY_FEED_ACTION_START_WITH_COMMAND_LINE(const char* p0, const char* p1)` | build 1207
nullsub, doesn't do anything

## ACTIVITY_FEED_ACTION_START_WITH_COMMAND_LINE_ADD
`0x1694A053DFB61A34` | `void ACTIVITY_FEED_ACTION_START_WITH_COMMAND_LINE_ADD(const char* p0)` | build 1207
nullsub, doesn't do anything

## ACTIVITY_FEED_ADD_SUBSTRING_TO_CAPTION
`0x9935F76407C32539` | `void ACTIVITY_FEED_ADD_SUBSTRING_TO_CAPTION(const char* p0)` | build 1207
nullsub, doesn't do anything

## ACTIVITY_FEED_CREATE
`0xCC7FC854B956A128` | `void ACTIVITY_FEED_CREATE(char* p0, char* p1)` | build 1207
nullsub, doesn't do anything

## ACTIVITY_FEED_POST
`0xB16FC7B364D86585` | `void ACTIVITY_FEED_POST()` | build 1207
nullsub, doesn't do anything

## ADD_POP_MULTIPLIER_AREA
`0x5EBDA1A3B8CB5EF7` | `int ADD_POP_MULTIPLIER_AREA(float x1, float y1, float z1, float x2, float y2, float z2, float pedDensity, float trafficDensity, BOOL p8, BOOL p9)` | build 1207

## ADD_TACTICAL_NAV_MESH_POINT
`0xE4EE55E63FA9AF45` | `void ADD_TACTICAL_NAV_MESH_POINT(float x, float y, float z, int p3)` | build 1207
Params: p3 is 0 in R* Script utopia2

## ARE_STRINGS_EQUAL
`0xD3852F22AB713A1F` | `BOOL ARE_STRINGS_EQUAL(char* string1, char* string2)` | build 1207

## ASIN
`0x6E3C15D296C15583` | `float ASIN(float p0)` | build 1207

## ATAN
`0x503054DED0B78027` | `float ATAN(float p0)` | build 1207

## ATAN2
`0x965B220A066E3F07` | `float ATAN2(float p0, float p1)` | build 1207

## BLOCK_DISPATCH_SERVICE_RESOURCE_CREATION
`0x66947E61A44DE2C6` | `void BLOCK_DISPATCH_SERVICE_RESOURCE_CREATION(int dispatchService, BOOL toggle)` | build 1207
dispatchService: see ENABLE_DISPATCH_SERVICE

## CANCEL_ONSCREEN_KEYBOARD
`0x58A39BE597CE99CD` | `void CANCEL_ONSCREEN_KEYBOARD()` | build 1207
Old name: _CANCEL_ONSCREEN_KEYBOARD

## CLEAR_ANGLED_AREA_OF_VEHICLES
`0xA4D83115C1E02F8A` | `void CLEAR_ANGLED_AREA_OF_VEHICLES(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## CLEAR_AREA
`0x3B882A96EA77D5B1` | `void CLEAR_AREA(float x, float y, float z, float radius, int flag)` | build 1207
Possible flag names:
ALL_BASE = 0,
PROJECTILES = 1,
BROADCAST = 524288,
AMBIENT_POPULATION = 1048576

## CLEAR_BIT
`0x7D1D4A3602B6AD4E` | `void CLEAR_BIT(int* address, int offset)` | build 1207

## CLEAR_OVERRIDE_WEATHER
`0x80A398F16FFE3CC3` | `void CLEAR_OVERRIDE_WEATHER()` | build 1207

## CLEAR_TACTICAL_NAV_MESH_POINTS
`0xD93B6516C6878267` | `void CLEAR_TACTICAL_NAV_MESH_POINTS()` | build 1207

## CLEAR_WEATHER_TYPE_PERSIST
`0xD85DFE5C131E4AE9` | `void CLEAR_WEATHER_TYPE_PERSIST()` | build 1207

## COMPARE_STRINGS
`0xBFBB74A15EFC149B` | `int COMPARE_STRINGS(char* str1, char* str2, BOOL matchCase, int maxLength)` | build 1207

## COPY_SCRIPT_STRUCT
`0xF7AC7DC0DEE7C9BE` | `void COPY_SCRIPT_STRUCT(Any* dst, Any* src, int size)` | build 1207
Old name: _COPY_MEMORY

## CREATE_INCIDENT
`0x3F892CAF67444AE7` | `BOOL CREATE_INCIDENT(int dispatchService, float x, float y, float z, int numUnits, float radius, int* outIncidentID, Any p7, Any p8)` | build 1207
dispatchService: see ENABLE_DISPATCH_SERVICE

## DELETE_INCIDENT
`0x5CFD0F0D6AAE0AEE` | `void DELETE_INCIDENT(int incidentId)` | build 1207
Delete an incident with a given id.

## DISABLE_LOOTING_COMPOSITE_LOOTABLE_THIS_FRAME
`0x40D72189F46D2E15` | `void DISABLE_LOOTING_COMPOSITE_LOOTABLE_THIS_FRAME(int compositeId, BOOL disable)` | build 1207
disables prompt eat

## DISPLAY_ONSCREEN_KEYBOARD
`0x044131118D8DB3CD` | `void DISPLAY_ONSCREEN_KEYBOARD(int textType, char* windowTitle, char* p2, char* defaultText, char* defaultConcat1, char* defaultConcat2, char* defaultConcat3, int maxInputLength)` | build 1207
enum eOnscreenKeyboardTextType
{
	KTEXTTYPE_INVALID = -1,
	KTEXTTYPE_DEFAULT,
	KTEXTTYPE_EMAIL,
	KTEXTTYPE_PASSWORD,
	KTEXTTYPE_NUMERIC,
	KTEXTTYPE_ALPHABET,
	KTEXTTYPE_GAMERTAG,
	KTEXTTYPE_FILENAME,
	KTEXTTYPE_COUNT
};

## DOES_POP_MULTIPLIER_AREA_EXIST
`0x03BA619C81A646B3` | `BOOL DOES_POP_MULTIPLIER_AREA_EXIST(int id)` | build 1207

## ENABLE_DISPATCH_SERVICE
`0x50E52637EF70EF77` | `void ENABLE_DISPATCH_SERVICE(int dispatchService, BOOL toggle)` | build 1207
enum DispatchType
{
	DT_Invalid,
	DT_PoliceAutomobile,
	DT_PoliceHelicopter,
	DT_FireDepartment,
	DT_SwatAutomobile,
	DT_AmbulanceDepartment,
	DT_PoliceRiders,
	DT_PoliceVehicleRequest,
	DT_PoliceRoadBlock,
	DT_PoliceAutomobileWaitPulledOver,
	DT_PoliceAutomobileWaitCruising,
	DT_Gangs,
	DT_SwatHelicopter,
	DT_PoliceBoat,
	DT_ArmyVehicle,
	DT_OnFoot,
	DT_PoliceDogs
};

## FIRE_SINGLE_BULLET
`0xCBC9A21F6A2A679C` | `void FIRE_SINGLE_BULLET(Any* args)` | build 1207
```lua
struct FireSingleBulletArgs
{
  float xStart;
  float yStart;
  float zStart;
  float xEnd;
  float yEnd;
  float zEnd;
  Hash weaponHash;
  float damage;
  float p8;
  Entity instigator;
  Entity entity2;
  Entity entity3;
  BOOL p12;
  BOOL p13;
  BOOL p14;
  BOOL p15;
  BOOL p16;
  Any p17;
  BOOL p18;
  BOOL p19;
}
```

## FORCE_LIGHTNING_FLASH
`0x369DB5B2510FA080` | `void FORCE_LIGHTNING_FLASH()` | build 1207
creates single lightning+thunder at random position

## GAME_FRAMEWORK_MANAGER_INIT
`0x4CABE596D632E4B0` | `BOOL GAME_FRAMEWORK_MANAGER_INIT(Hash transitionMode)` | build 1207

## GET_ANGLE_BETWEEN_2D_VECTORS
`0xD0DFE1C486097BBB` | `float GET_ANGLE_BETWEEN_2D_VECTORS(float x1, float y1, float x2, float y2)` | build 1207

## GET_BENCHMARK_ITERATIONS
`0x22FC52CF470CC98D` | `int GET_BENCHMARK_ITERATIONS()` | build 1207
Returns value of the '-benchmarkIterations' command line option.

Old name: _GET_BENCHMARK_ITERATIONS_FROM_COMMAND_LINE

## GET_BENCHMARK_PASS
`0x9297DACF3A2CDFF7` | `int GET_BENCHMARK_PASS()` | build 1207
Returns value of the '-benchmarkPass' command line option.

Old name: _GET_BENCHMARK_PASS_FROM_COMMAND_LINE

## GET_BITS_IN_RANGE
`0x68E1352AF48F905D` | `int GET_BITS_IN_RANGE(int var, int rangeStart, int rangeEnd)` | build 1207

## GET_CLOSEST_POINT_ON_LINE
`0x83ACC65D9ACEC5EF` | `Vector3 GET_CLOSEST_POINT_ON_LINE(float p0, float p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, BOOL p9)` | build 1207

## GET_COORDS_OF_PROJECTILE_TYPE_WITHIN_DISTANCE
`0xD73C960A681052DF` | `BOOL GET_COORDS_OF_PROJECTILE_TYPE_WITHIN_DISTANCE(Ped ped, Hash weaponHash, float distance, Vector3* outCoords, BOOL p4, BOOL mustBeOwnedByThisPed)` | build 1207

## GET_CURR_WEATHER_STATE
`0x0AC679B2342F14F2` | `void GET_CURR_WEATHER_STATE(Hash* weatherType1, Hash* weatherType2, float* percentWeather2)` | build 1207
Params: percentWeather2: 0f - 0.75f in R* Scripts

Old name: _GET_WEATHER_TYPE_TRANSITION

## GET_DISTANCE_BETWEEN_COORDS
`0x0BE7F4E3CDBAFB28` | `float GET_DISTANCE_BETWEEN_COORDS(float x1, float y1, float z1, float x2, float y2, float z2, BOOL useZ)` | build 1207
If useZ is false, only the 2D plane (X-Y) will be considered for calculating the distance.

Consider using this faster native instead: BUILTIN::VDIST - DVIST always takes in consideration the 3D coordinates.

## GET_FRAME_COUNT
`0x77DFA958FCF100C1` | `int GET_FRAME_COUNT()` | build 1207

## GET_FRAME_TIME
`0x5E72022914CE3C38` | `float GET_FRAME_TIME()` | build 1207

## GET_GAME_TIMER
`0x4F67E8ECA7D3F667` | `int GET_GAME_TIMER()` | build 1207

## GET_GROUND_Z_AND_NORMAL_FOR_3D_COORD
`0x2A29CA9A6319E6AB` | `BOOL GET_GROUND_Z_AND_NORMAL_FOR_3D_COORD(float x, float y, float z, float* groundZ, Vector3* normal)` | build 1207

## GET_GROUND_Z_FOR_3D_COORD
`0x24FA4267BB8D2431` | `BOOL GET_GROUND_Z_FOR_3D_COORD(float x, float y, float z, float* groundZ, BOOL p4)` | build 1207

## GET_HASH_KEY
`0xFD340785ADF8CFB7` | `Hash GET_HASH_KEY(char* string)` | build 1207
Computes a hash for the given string. It is hashed using Jenkins' One-at-a-Time hash algorithm (https://en.wikipedia.org/wiki/Jenkins_hash_function)
Note: this implementation is case-insensitive.

## GET_HEADING_FROM_VECTOR_2D
`0x38D5202FF9271C62` | `float GET_HEADING_FROM_VECTOR_2D(float dx, float dy)` | build 1207
dx = x1 - x2
dy = y1 - y2

## GET_LINE_PLANE_INTERSECTION
`0xAB6A04CEC428258B` | `BOOL GET_LINE_PLANE_INTERSECTION(float p0, float p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, float p9, float p10, float p11, float* p12)` | build 1207

## GET_MISSION_FLAG
`0xB15CD1CF58771DE1` | `BOOL GET_MISSION_FLAG()` | build 1207

## GET_MODEL_DIMENSIONS
`0xDCB8DDD5D054A7E7` | `void GET_MODEL_DIMENSIONS(Hash modelHash, Vector3* minimum, Vector3* maximum)` | build 1207

## GET_NUMBER_OF_FREE_STACKS_OF_THIS_SIZE
`0x40DC2907A9697EF7` | `int GET_NUMBER_OF_FREE_STACKS_OF_THIS_SIZE(int stackSize)` | build 1207

## GET_NUMBER_OF_MICROSECONDS_SINCE_LAST_CALL
`0xB0CE5E5ED8BB3581` | `int GET_NUMBER_OF_MICROSECONDS_SINCE_LAST_CALL()` | build 1207

## GET_ONSCREEN_KEYBOARD_RESULT
`0xAFB4CF58A4A292B1` | `const char* GET_ONSCREEN_KEYBOARD_RESULT()` | build 1207
Returns NULL unless UPDATE_ONSCREEN_KEYBOARD() returns 1 in the same tick.

## GET_PROJECTILE_OF_PROJECTILE_TYPE_WITHIN_DISTANCE
`0x9578986A6105A6AD` | `BOOL GET_PROJECTILE_OF_PROJECTILE_TYPE_WITHIN_DISTANCE(Ped ped, Hash weaponHash, float distance, Vector3* outCoords, Object* outProjectile, BOOL p5, BOOL mustBeOwnedByThisPed)` | build 1207

## GET_RAIN_LEVEL
`0x931B5F4CC130224B` | `float GET_RAIN_LEVEL()` | build 1207

## GET_RANDOM_EVENT_FLAG
`0x924D54E5698AE3E0` | `BOOL GET_RANDOM_EVENT_FLAG()` | build 1207

## GET_RANDOM_FLOAT_IN_RANGE
`0xE29F927A961F8AAA` | `float GET_RANDOM_FLOAT_IN_RANGE(float startRange, float endRange)` | build 1207

## GET_RANDOM_INT_IN_RANGE
`0xD53343AA4FB7DD28` | `int GET_RANDOM_INT_IN_RANGE(int startRange, int endRange)` | build 1207

## GET_REAL_WORLD_TIME
`0x2E036F0480B8BF02` | `int GET_REAL_WORLD_TIME()` | build 1207
Returns GET_GAME_TIMER() / 1000
Only used in rcm_pearson1.ysc

## GET_SCRIPT_TIME_WITHIN_FRAME_IN_MICROSECONDS
`0x63219768C586667C` | `int GET_SCRIPT_TIME_WITHIN_FRAME_IN_MICROSECONDS()` | build 1207

## GET_SNOW_LEVEL
`0x1E5D727041BE1709` | `float GET_SNOW_LEVEL()` | build 1207

## GET_SYSTEM_TIME
`0xBE7F225417E35A7C` | `int GET_SYSTEM_TIME()` | build 1207

## GET_SYSTEM_TIME_STEP
`0x3F3172FEAE3AFE1C` | `float GET_SYSTEM_TIME_STEP()` | build 1207
Old name: _GET_BENCHMARK_TIME

## GET_WIND_DIRECTION
`0xF703E82F3FE14A5F` | `Vector3 GET_WIND_DIRECTION()` | build 1207

## GET_WIND_SPEED
`0xFFB7E74E041150A4` | `float GET_WIND_SPEED()` | build 1207

## HAS_BULLET_IMPACTED_IN_AREA
`0xC153E5BCCF411814` | `BOOL HAS_BULLET_IMPACTED_IN_AREA(float x, float y, float z, float p3, BOOL p4, BOOL p5)` | build 1207
p3 - possibly radius?

## HAS_BULLET_IMPACTED_IN_BOX
`0x3B6A4C05FB2B33AC` | `BOOL HAS_BULLET_IMPACTED_IN_BOX(float p0, float p1, float p2, float p3, float p4, float p5, BOOL p6, BOOL p7)` | build 1207

## IGNORE_NEXT_RESTART
`0x6C9FF40FF1B69F8F` | `void IGNORE_NEXT_RESTART(BOOL toggle)` | build 1207

## INFORM_CODE_OF_CONTENT_ID_OF_CURRENT_UGC_MISSION
`0x708DF841B8F27AA2` | `void INFORM_CODE_OF_CONTENT_ID_OF_CURRENT_UGC_MISSION(const char* p0)` | build 1207

## IS_BIT_SET
`0x4ED6CFDFE8D4131A` | `BOOL IS_BIT_SET(int address, int offset)` | build 1207

## IS_BULLET_IN_ANGLED_AREA
`0x9D09D8493747CF02` | `BOOL IS_BULLET_IN_ANGLED_AREA(float p0, float p1, float p2, float p3, float p4, float p5, float p6, BOOL p7)` | build 1207

## IS_BULLET_IN_AREA
`0xC652FD308772D79E` | `BOOL IS_BULLET_IN_AREA(float p0, float p1, float p2, float p3, BOOL p4)` | build 1207

## IS_BULLET_IN_BOX
`0xC128137C52152741` | `BOOL IS_BULLET_IN_BOX(float p0, float p1, float p2, float p3, float p4, float p5, BOOL p6)` | build 1207

## IS_DURANGO_VERSION
`0xD1CCC2A2639D325F` | `BOOL IS_DURANGO_VERSION()` | build 1207
Hardcoded to return false.
Checks for XBOXONE Game Build.

## IS_GAME_SESSION_STATE_MACHINE_IDLE
`0xF9E7DBB39080640B` | `BOOL IS_GAME_SESSION_STATE_MACHINE_IDLE()` | build 1207

## IS_INCIDENT_VALID
`0x39F2B1BAD412246A` | `BOOL IS_INCIDENT_VALID(int incidentId)` | build 1207

## IS_MAG_DEMO_1_ACTIVE
`0x5FC9357C26DAEFCE` | `BOOL IS_MAG_DEMO_1_ACTIVE()` | build 1207
magdemo = magazine demo, i. e. for magazines such as IGN, pre play phases to prepare articles etc. - example 2012 builds for V
Hardcoded to return false.

## IS_MINIGAME_IN_PROGRESS
`0xF4D8BCD052E7EA1B` | `BOOL IS_MINIGAME_IN_PROGRESS()` | build 1207

## IS_ORBIS_VERSION
`0x88CFAE250D3E0C71` | `BOOL IS_ORBIS_VERSION()` | build 1207
Hardcoded to return false.
Checks for PS4 Game Build.

## IS_PC_VERSION
`0xB0FB6CFAA5A1C833` | `BOOL IS_PC_VERSION()` | build 1207
Hardcoded to return true.

## IS_POSITION_OCCUPIED
`0x825CA3ED43831015` | `BOOL IS_POSITION_OCCUPIED(float x, float y, float z, float range, BOOL p4, BOOL p5, BOOL p6, BOOL p7, BOOL p8, Any p9, BOOL p10)` | build 1207

## IS_PROJECTILE_IN_AREA
`0x05B0061EFDFC8941` | `BOOL IS_PROJECTILE_IN_AREA(float x1, float y1, float z1, float x2, float y2, float z2, BOOL ownedByPlayer)` | build 1207
Determines whether there is a projectile within the specified coordinates. The coordinates form a rectangle.

ownedByPlayer = only projectiles fired by the player will be detected.

## IS_PROJECTILE_TYPE_IN_ANGLED_AREA
`0x928431F4133CD3D4` | `BOOL IS_PROJECTILE_TYPE_IN_ANGLED_AREA(float p0, float p1, float p2, float p3, float p4, float p5, float p6, Any p7, BOOL p8)` | build 1207

## IS_PROJECTILE_TYPE_IN_AREA
`0x04965FB9E14235C7` | `BOOL IS_PROJECTILE_TYPE_IN_AREA(float xMin, float yMin, float zMin, float xMax, float yMax, float zMax, Hash weaponType, BOOL isPlayer)` | build 1207
Determines whether there is a projectile of a specific type within the specified coordinates. The coordinates form a rectangle.

## IS_PROJECTILE_TYPE_WITHIN_DISTANCE
`0xF51C9BAAD9ED64C4` | `BOOL IS_PROJECTILE_TYPE_WITHIN_DISTANCE(float p0, float p1, float p2, Any p3, float p4, BOOL p5)` | build 1207

## IS_STADIA_VERSION
`0x268AB8420A9E4ED7` | `BOOL IS_STADIA_VERSION()` | build 1207
Hardcoded to return false.

## IS_STRING_NULL
`0x602102324604D96B` | `BOOL IS_STRING_NULL(const char* string)` | build 1207

## IS_STRING_NULL_OR_EMPTY
`0x2CF12F9ACF18F048` | `BOOL IS_STRING_NULL_OR_EMPTY(const char* string)` | build 1207

## IS_STRING_NULL_OR_EMPTY_OR_SPACES
`0x375F5870A7B8BEC1` | `BOOL IS_STRING_NULL_OR_EMPTY_OR_SPACES(const char* string)` | build 1207
Returns true if the entire string consists only of space characters.

## NETWORK_SET_SCRIPT_IS_SAFE_FOR_NETWORK_GAME
`0x3D0EAC6385DD6100` | `void NETWORK_SET_SCRIPT_IS_SAFE_FOR_NETWORK_GAME()` | build 1207

## NEXT_ONSCREEN_KEYBOARD_RESULT_WILL_DISPLAY_USING_THESE_FONTS
`0x5CB71EAA1429A358` | `void NEXT_ONSCREEN_KEYBOARD_RESULT_WILL_DISPLAY_USING_THESE_FONTS(int fontBitField)` | build 1207

## OVERRIDE_SAVE_HOUSE
`0xB2C69E11A37B5AF0` | `BOOL OVERRIDE_SAVE_HOUSE(BOOL override, float x, float y, float z, float heading, BOOL isAutosave, Vector3* returnCoords, float* returnHeading)` | build 1207

## PAUSE_DEATH_ARREST_RESTART
`0x66AB6B6C7E72F393` | `void PAUSE_DEATH_ARREST_RESTART(BOOL toggle)` | build 1207

## POPULATE_NOW
`0xEA6DC3A8ADD2005F` | `void POPULATE_NOW()` | build 1207
spawns a few distant/out-of-sight peds, vehicles, animals etc each time it is called

## REGISTER_INTERACTION_LOCKON_PROMPT
`0x870708A6E147A9AD` | `BOOL REGISTER_INTERACTION_LOCKON_PROMPT(Entity entity, const char* text, float radius, float p3, int flag, float p5, float p6, Prompt prompt, BOOL p8, int p9)` | build 1207
p3 is usually the same value of radius
p8 determines whether the ILO prompt is a lock on prompt with RMB

## REMOVE_DISPATCH_SPAWN_BLOCKING_AREA
`0x49F751F6868DDC5B` | `void REMOVE_DISPATCH_SPAWN_BLOCKING_AREA(Any p0)` | build 1207

## REMOVE_POP_MULTIPLIER_AREA
`0x88CB484364EFB37A` | `void REMOVE_POP_MULTIPLIER_AREA(int id, BOOL p1)` | build 1207

## RESET_DISPATCH_IDEAL_SPAWN_DISTANCE
`0xC7817264BC4B6377` | `void RESET_DISPATCH_IDEAL_SPAWN_DISTANCE()` | build 1207

## RESET_END_USER_BENCHMARK
`0xECBABD0307FB216F` | `void RESET_END_USER_BENCHMARK()` | build 1207
Begins with RESET_*. Next character in the name is either D or E.

Old name: _RESET_BENCHMARK_RECORDING

## RESET_SCRIPT_TIME_WITHIN_FRAME
`0x1411A7CBC3A6EB7B` | `void RESET_SCRIPT_TIME_WITHIN_FRAME()` | build 1207

## RESET_WANTED_RESPONSE_NUM_PEDS_TO_SPAWN
`0xEF42F56F69877125` | `void RESET_WANTED_RESPONSE_NUM_PEDS_TO_SPAWN()` | build 1207

## SAVE_END_USER_BENCHMARK
`0xF4743E2ECC02B3DA` | `void SAVE_END_USER_BENCHMARK()` | build 1207
Saves the benchmark recording to %USERPROFILE%\Documents\Rockstar Games\Red Dead Redemption 2\Benchmarks and submits some metrics.

Old name: _SAVE_BENCHMARK_RECORDING

## SCRIPT_RACE_GET_PLAYER_SPLIT_TIME
`0x769E848C66E3C2BB` | `BOOL SCRIPT_RACE_GET_PLAYER_SPLIT_TIME(Any p0, Any* p1, Any* p2)` | build 1207

## SCRIPT_RACE_INIT
`0x8AE059F47158417E` | `void SCRIPT_RACE_INIT(int numCheckpoints, int numLaps, int numPlayers, Any p3)` | build 1207

## SCRIPT_RACE_PLAYER_HIT_CHECKPOINT
`0xBA62B4D80FA66BD6` | `void SCRIPT_RACE_PLAYER_HIT_CHECKPOINT(int part, int checkpoint, int lap, int time)` | build 1207

## SCRIPT_RACE_SHUTDOWN
`0x334CE0DA4FAF330C` | `void SCRIPT_RACE_SHUTDOWN()` | build 1207

## SET_BIT
`0xF73FBE4845C43B5B` | `void SET_BIT(int* address, int offset)` | build 1207

## SET_BITS_IN_RANGE
`0x324DC1CEF57F31E6` | `void SET_BITS_IN_RANGE(int* var, int rangeStart, int rangeEnd, int p3)` | build 1207

## SET_CHEAT_ACTIVE
`0xD4958E8CF0DE0DD0` | `void SET_CHEAT_ACTIVE(int cheatId)` | build 1207
Cheats are GTA IV cheats:

0 = unknown
1 = unknown (same as 0)
2 = Max Health and Armor
3 = Raise Wanted Level
4 = Lower Wanted Level
5 = unknown (does nothing)
6 = Change Weather
7 = Spawn Annihilator
8 = Spawn NRG 900
9 = Spawn FBI
10 = Spawn Jetmax
11 = Spawn Comet
12 = Spawn Turismo
13 = Spawn Cognoscenti
14 = Spawn Super GT
15 = Spawn Sanchez

Initially used in Max Payne 3, that's why we know the name.

## SET_CREDITS_ACTIVE
`0xD37BECF862DA726F` | `void SET_CREDITS_ACTIVE(BOOL toggle)` | build 1207

## SET_CURR_WEATHER_STATE
`0xFA3E3CA8A1DE6D5D` | `void SET_CURR_WEATHER_STATE(Hash weatherType1, Hash weatherType2, float percentWeather2, BOOL enabled)` | build 1207
Params: BOOL p3 is always true

Old name: _SET_WEATHER_TYPE_TRANSITION

## SET_DISPATCH_IDEAL_SPAWN_DISTANCE
`0xEAB6823B82FBD283` | `void SET_DISPATCH_IDEAL_SPAWN_DISTANCE(float fIdealSpawnDistance)` | build 1207

## SET_FADE_IN_AFTER_DEATH_ARREST
`0xDF3B5846DE5904AF` | `void SET_FADE_IN_AFTER_DEATH_ARREST(BOOL toggle)` | build 1207
Sets whether the game should fade in after the player dies or is arrested.

## SET_FADE_IN_AFTER_LOAD
`0xAC806C4CAB973517` | `void SET_FADE_IN_AFTER_LOAD(BOOL toggle)` | build 1207

## SET_GAME_PAUSED
`0xFAEC088D28B1DE4A` | `void SET_GAME_PAUSED(BOOL toggle)` | build 1207
Make sure to call this from the correct thread if you're using multiple threads because all other threads except the one which is calling SET_GAME_PAUSED will be paused.

## SET_MISSION_FLAG
`0x36694B456BE80D0A` | `void SET_MISSION_FLAG(BOOL toggle)` | build 1207
If true, the player can't save the game.

## SET_PED_DECOMPOSED
`0x674B90BE1115846D` | `void SET_PED_DECOMPOSED(Ped ped, BOOL toggle)` | build 1207

## SET_RAIN
`0x193DFC0526830FD6` | `void SET_RAIN(float intensity)` | build 1207
Old name: _SET_RAIN_LEVEL

## SET_RANDOM_EVENT_FLAG
`0xB1ADCCC4150C6473` | `void SET_RANDOM_EVENT_FLAG(BOOL toggle)` | build 1207
If the parameter is true, sets the random event flag to true, if the parameter is false, the function does nothing at all.
Does nothing if the mission flag is set.

## SET_RANDOM_SEED
`0x5CD7A49104AFCB6B` | `void SET_RANDOM_SEED(int seed)` | build 1207

## SET_RANDOM_WEATHER_TYPE
`0x6E5A7FBEECAB3C72` | `void SET_RANDOM_WEATHER_TYPE(BOOL p0, BOOL p1)` | build 1207

## SET_SUPER_JUMP_THIS_FRAME
`0xB3E9BE963F10C445` | `void SET_SUPER_JUMP_THIS_FRAME(Player player)` | build 1207

## SET_THIS_SCRIPT_CAN_BE_PAUSED
`0x3215376E79F6EA18` | `void SET_THIS_SCRIPT_CAN_BE_PAUSED(BOOL toggle)` | build 1207

## SET_THIS_SCRIPT_CAN_REMOVE_BLIPS_CREATED_BY_ANY_SCRIPT
`0x8ABD939C2E5D00ED` | `void SET_THIS_SCRIPT_CAN_REMOVE_BLIPS_CREATED_BY_ANY_SCRIPT(BOOL toggle)` | build 1207

## SET_TIME_SCALE
`0x9682AF6050854856` | `void SET_TIME_SCALE(float timeScale)` | build 1207
Maximum value is 1.0f
At a value of 0.0f the game will still run at a minimum time scale.

## SET_WEATHER_TYPE
`0x59174F1AFE095B5A` | `void SET_WEATHER_TYPE(Hash weatherType, BOOL p1, BOOL p2, BOOL transition, float transitionTime, BOOL p5)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/weather/weather_types.lua

## SET_WIND_DIRECTION
`0xB56C4F5F57A45600` | `void SET_WIND_DIRECTION(float direction)` | build 1207

## SET_WIND_SPEED
`0xD00C2D82DC04A99F` | `void SET_WIND_SPEED(float speed)` | build 1207

## SHOOT_SINGLE_BULLET_BETWEEN_COORDS
`0x867654CBC7606F2C` | `void SHOOT_SINGLE_BULLET_BETWEEN_COORDS(float x1, float y1, float z1, float x2, float y2, float z2, int damage, BOOL p7, Hash weaponHash, Ped ownerPed, BOOL isAudible, BOOL isInvisible, float speed, BOOL p13)` | build 1207

## SHOULD_USE_METRIC_MEASUREMENTS
`0x4FB556ACEFA93098` | `BOOL SHOULD_USE_METRIC_MEASUREMENTS()` | build 1207
Returns whether the game's measurement system is set to metric.

## START_END_USER_BENCHMARK
`0x29D1F6DF864A094E` | `void START_END_USER_BENCHMARK()` | build 1207
Begins with START_*. Next character in the name is either D or E.

Old name: _START_BENCHMARK_RECORDING

## STOP_CURRENT_LOADING_PROGRESS_TIMER
`0xA565FAC215CBC77D` | `void STOP_CURRENT_LOADING_PROGRESS_TIMER()` | build 1207
nullsub, doesn't do anything

## STOP_END_USER_BENCHMARK
`0xB89AEC71AFF2B599` | `void STOP_END_USER_BENCHMARK()` | build 1207
Begins with STOP_*. Next character in the name is either D or E.

Old name: _STOP_BENCHMARK_RECORDING

## STRING_TO_INT
`0xF2DD2298B3AF23E2` | `BOOL STRING_TO_INT(const char* string, int* outInteger)` | build 1207
Returns false if it's a null or empty string or if the string is too long. outInteger will be set to -999 in that case.

## TAN
`0x8C13DB96497B7ABF` | `float TAN(float p0)` | build 1207

## UI_STARTED_END_USER_BENCHMARK
`0x4FFA0386A6216113` | `BOOL UI_STARTED_END_USER_BENCHMARK()` | build 1207
Hardcoded to return false.

Old name: _UI_IS_SINGLEPLAYER_PAUSE_MENU_ACTIVE

## UNREGISTER_INTERACTION_LOCKON_PROMPT
`0xE98D55C5983F2509` | `BOOL UNREGISTER_INTERACTION_LOCKON_PROMPT(Entity entity)` | build 1207

## UPDATE_ONSCREEN_KEYBOARD
`0x37DF360F235A3893` | `int UPDATE_ONSCREEN_KEYBOARD()` | build 1207
Returns the current status of the onscreen keyboard, and updates the output.

Status Codes:

0 - User still editing
1 - User has finished editing
2 - User has canceled editing
3 - Keyboard isn't active

## VAR_STRING
`0xFA925AC00EB830B9` | `const char* VAR_STRING(int flags, ...)` | build 1207
Note: The first bit in 'flags' must not be set.
It is also required to pass at least one extra argument (this must be a text label string or hash).
When passing a hash, flags should be 0.

## WATER_OVERRIDE_SET_OCEANWAVEMAXAMPLITUDE
`0xF06C5B66DE20B2B8` | `void WATER_OVERRIDE_SET_OCEANWAVEMAXAMPLITUDE(float maxAmplitude)` | build 1207
Only used in smuggler2 script

## WATER_OVERRIDE_SET_SHOREWAVEAMPLITUDE
`0x55123D5A7D9D3C42` | `void WATER_OVERRIDE_SET_SHOREWAVEAMPLITUDE(float amplitude)` | build 1207
Only used in smuggler2 script

## _0x0358B8A41916C613
`0x0358B8A41916C613` | `Any _0x0358B8A41916C613(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x0730E518486DEEC3
`0x0730E518486DEEC3` | `void _0x0730E518486DEEC3(Any p0)` | build 1207

## _0x0A487CC74A517FB5
`0x0A487CC74A517FB5` | `void _0x0A487CC74A517FB5(Any p0)` | build 1207

## _0x0D0AE5081F88CFE1
`0x0D0AE5081F88CFE1` | `BOOL _0x0D0AE5081F88CFE1(Hash p0)` | build 1207

## _0x1096603B519C905F
`0x1096603B519C905F` | `void _0x1096603B519C905F(const char* name)` | build 1207
_SET_MISSION_NAME_*(FOR_ACTIVITY?/MINIGAME?)

## _0x154340E87D8CC178
`0x154340E87D8CC178` | `void _0x154340E87D8CC178(Any p0)` | build 1207

## _0x183672FE838A661B
`0x183672FE838A661B` | `void _0x183672FE838A661B(Any* data)` | build 1207

## _0x243CEDE8F916B994
`0x243CEDE8F916B994` | `void _0x243CEDE8F916B994()` | build 1207

## _0x2916B30DC6C41179
`0x2916B30DC6C41179` | `void _0x2916B30DC6C41179(Hash weatherType)` | build 1207

## _0x33982467B1E349EF
`0x33982467B1E349EF` | `Any _0x33982467B1E349EF(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0x35165C658077CD0B
`0x35165C658077CD0B` | `Any _0x35165C658077CD0B()` | build 1207

## _0x38C0C9CAE1544500
`0x38C0C9CAE1544500` | `void _0x38C0C9CAE1544500(Hash p0)` | build 1207

## _0x38C2BF94D15F464D
`0x38C2BF94D15F464D` | `Any _0x38C2BF94D15F464D(Any p0)` | build 1207

## _0x3A87FDA8F1B6CDFB
`0x3A87FDA8F1B6CDFB` | `void _0x3A87FDA8F1B6CDFB(Any p0, Any p1, Any p2)` | build 1207

## _0x3C3C7B1B5EC08764
`0x3C3C7B1B5EC08764` | `void _0x3C3C7B1B5EC08764()` | build 1207

## _0x4647842FE8F31C1E
`0x4647842FE8F31C1E` | `void _0x4647842FE8F31C1E(Any p0, Any p1)` | build 1207

## _0x49C44FE78A135A1D
`0x49C44FE78A135A1D` | `void _0x49C44FE78A135A1D(Any p0)` | build 1207

## _0x49F3241C28EBBFBC
`0x49F3241C28EBBFBC` | `void _0x49F3241C28EBBFBC(int p0)` | build 1207

## _0x4B0501A468B749F8
`0x4B0501A468B749F8` | `void _0x4B0501A468B749F8()` | build 1207

## _0x4B101DBCC9482F2D
`0x4B101DBCC9482F2D` | `BOOL _0x4B101DBCC9482F2D(Ped ped)` | build 1207

## _0x4D5C9CC7E7E23E09
`0x4D5C9CC7E7E23E09` | `void _0x4D5C9CC7E7E23E09()` | build 1207

## _0x553D67295DDD2309
`0x553D67295DDD2309` | `void _0x553D67295DDD2309(Entity entity)` | build 1207
UPDATE_PICKUP_COLLECTIBLE: set Eagle Eye fountain
_J*, _K*, _L*

## _0x5801BE2DF2AF07EC
`0x5801BE2DF2AF07EC` | `void _0x5801BE2DF2AF07EC(Any p0)` | build 1207

## _0x5B4A8121A47D844D
`0x5B4A8121A47D844D` | `Any _0x5B4A8121A47D844D(Any p0)` | build 1207

## _0x627B68D9CE6EE8DE
`0x627B68D9CE6EE8DE` | `Any _0x627B68D9CE6EE8DE(Any p0)` | build 1207

## _0x68319452C5064ABA
`0x68319452C5064ABA` | `void _0x68319452C5064ABA(Any p0, Any p1)` | build 1207

## _0x6BCF7B5CD338281A
`0x6BCF7B5CD338281A` | `void _0x6BCF7B5CD338281A(Any p0, Any p1, Any p2)` | build 1207
_SET_DISPATCH_*, unused

## _0x6BED40493A1AFDB8
`0x6BED40493A1AFDB8` | `void _0x6BED40493A1AFDB8(Any* p0, float p1)` | build 1207

## _0x6C7B68D3CE60E8DE
`0x6C7B68D3CE60E8DE` | `Any _0x6C7B68D3CE60E8DE(Any p0)` | build 1207

## _0x6F02B5E50511721E
`0x6F02B5E50511721E` | `Any _0x6F02B5E50511721E(Any p0)` | build 1207

## _0x745808BB01CEC6B9
`0x745808BB01CEC6B9` | `void _0x745808BB01CEC6B9(float p0)` | build 1207

## _0x74ACA66484CEBAF0
`0x74ACA66484CEBAF0` | `void _0x74ACA66484CEBAF0(Any p0)` | build 1207

## _0x7CF96F1250EF3221
`0x7CF96F1250EF3221` | `Any _0x7CF96F1250EF3221(Any p0)` | build 1207

## _0x7FA58CED69405F9A
`0x7FA58CED69405F9A` | `void _0x7FA58CED69405F9A(Any p0, Any p1)` | build 1207

## _0x8314FC2013ECE2DA
`0x8314FC2013ECE2DA` | `Any _0x8314FC2013ECE2DA(Any p0, Any p1, Any p2)` | build 1207

## _0x8BB99B85444544D9
`0x8BB99B85444544D9` | `Any _0x8BB99B85444544D9(Any p0, Any p1)` | build 1207

## _0x8C0F6A3D7236DEEB
`0x8C0F6A3D7236DEEB` | `void _0x8C0F6A3D7236DEEB(Any p0, Any p1)` | build 1207

## _0x8DB104CCEBCD58C5
`0x8DB104CCEBCD58C5` | `Any _0x8DB104CCEBCD58C5(Any p0, Any p1)` | build 1207

## _0x94FCADCF9F0C368E
`0x94FCADCF9F0C368E` | `void _0x94FCADCF9F0C368E(Any p0)` | build 1207

## _0x96282005C5C6801F
`0x96282005C5C6801F` | `void _0x96282005C5C6801F(Any p0, Any p1)` | build 1311

## _0x9A252AA23D7098F2
`0x9A252AA23D7098F2` | `void _0x9A252AA23D7098F2()` | build 1207

## _0x9BF2C0C568C61641
`0x9BF2C0C568C61641` | `void _0x9BF2C0C568C61641(Any p0)` | build 1207

## _0xA08111B053D84B4D
`0xA08111B053D84B4D` | `void _0xA08111B053D84B4D(Any p0)` | build 1207
_CLEAR*

## _0xA3A8926951471C82
`0xA3A8926951471C82` | `void _0xA3A8926951471C82()` | build 1207

## _0xA9342743B634A462
`0xA9342743B634A462` | `void _0xA9342743B634A462(Any p0)` | build 1207
nullsub, doesn't do anything

## _0xAB26DEEE120FD3FD
`0xAB26DEEE120FD3FD` | `void _0xAB26DEEE120FD3FD(Any p0, Any p1)` | build 1207

## _0xAD44856A1CD29635
`0xAD44856A1CD29635` | `void _0xAD44856A1CD29635(Any p0, Any p1, Any p2)` | build 1207

## _0xAF3A84C7DE6A1DC5
`0xAF3A84C7DE6A1DC5` | `void _0xAF3A84C7DE6A1DC5(Any p0, Any p1)` | build 1207

## _0xAF530E56505D1BD6
`0xAF530E56505D1BD6` | `Any _0xAF530E56505D1BD6(Any p0)` | build 1207
Hardcoded to return one/true.

## _0xB08C4FA25BC29DB9
`0xB08C4FA25BC29DB9` | `void _0xB08C4FA25BC29DB9(Any p0)` | build 1207

## _0xB1F6665AA54DCD5C
`0xB1F6665AA54DCD5C` | `Any _0xB1F6665AA54DCD5C(Hash p0)` | build 1207

## _0xB711EB4BC8D06013
`0xB711EB4BC8D06013` | `void _0xB711EB4BC8D06013()` | build 1207
nullsub, doesn't do anything

## _0xBB282CF5D2333FB8
`0xBB282CF5D2333FB8` | `void _0xBB282CF5D2333FB8(Any p0, Any p1)` | build 1207

## _0xCC1BAF72D571DB8D
`0xCC1BAF72D571DB8D` | `Any _0xCC1BAF72D571DB8D(Any p0, Any p1, Any p2)` | build 1207

## _0xCC3EDC5614B03F61
`0xCC3EDC5614B03F61` | `void _0xCC3EDC5614B03F61(int p0)` | build 1207

## _0xD3F943B88F55376A
`0xD3F943B88F55376A` | `void _0xD3F943B88F55376A(Hash weatherType)` | build 1207

## _0xDA4D8EB04E8E2928
`0xDA4D8EB04E8E2928` | `void _0xDA4D8EB04E8E2928(Any p0)` | build 1207

## _0xDBDA48EC456ED908
`0xDBDA48EC456ED908` | `void _0xDBDA48EC456ED908()` | build 1436

## _0xDC057B86FC157031
`0xDC057B86FC157031` | `Any _0xDC057B86FC157031()` | build 1207
Hardcoded to return one/true.

## _0xDE2C3B74D2B3705C
`0xDE2C3B74D2B3705C` | `void _0xDE2C3B74D2B3705C(Any p0, Any p1)` | build 1207

## _0xEB946B9E579729AD
`0xEB946B9E579729AD` | `void _0xEB946B9E579729AD(Ped ped, Any p1)` | build 1207
Not implemented.

## _0xF569E33FB72ED28E
`0xF569E33FB72ED28E` | `void _0xF569E33FB72ED28E()` | build 1207

## _0xF63FA29D4A9ACA86
`0xF63FA29D4A9ACA86` | `void _0xF63FA29D4A9ACA86(Any p0, Any p1)` | build 1207

## _0xF650DCF5D6F312C1
`0xF650DCF5D6F312C1` | `void _0xF650DCF5D6F312C1(Any p0)` | build 1232

## _0xF81C53561D15F330
`0xF81C53561D15F330` | `const char* _0xF81C53561D15F330()` | build 1207

## _0xFC6ECB9170145ECE
`0xFC6ECB9170145ECE` | `void _0xFC6ECB9170145ECE()` | build 1207

## _0xFF252E2BAFB7330F
`0xFF252E2BAFB7330F` | `void _0xFF252E2BAFB7330F(Any p0)` | build 1207
nullsub, doesn't do anything

## _ADD_DISPATCH_SPAWN_BLOCKING_AREA
`0xA2D5A26208421426` | `Any _ADD_DISPATCH_SPAWN_BLOCKING_AREA(Volume volume)` | build 1207

## _ADD_POP_MULTIPLIER_VOLUME
`0x3233C4EC0514C7EC` | `int _ADD_POP_MULTIPLIER_VOLUME(Volume volume, float pedDensity, float vehicleDensity, BOOL p3, BOOL p4)` | build 1207
Only used in script function PROCESS_ZONE_CREATION
Returns Pop multiplier volume ID

## _CLEAR_ALL_BIT_FLAGS
`0xD2D74F89DF844A50` | `void _CLEAR_ALL_BIT_FLAGS(Any* bitFlags)` | build 1207

## _CLEAR_BIT_FLAG
`0xB909149F2BB5F6DA` | `void _CLEAR_BIT_FLAG(Any* bitFlags, int flag)` | build 1207

## _CLEAR_VOLUME_AREA
`0x2FCD528A397E5C88` | `void _CLEAR_VOLUME_AREA(Volume volume, int flag)` | build 1207

## _CLEAR_WEATHER_TYPE_PERSIST_OVERTIME
`0xCE7690C0A0D1C36D` | `void _CLEAR_WEATHER_TYPE_PERSIST_OVERTIME(int milliseconds)` | build 1207

## _CLEAR_WEATHER_VARIATION
`0x0E71C80FA4EC8147` | `void _CLEAR_WEATHER_VARIATION(const char* weatherType, BOOL p1)` | build 1207

## _COUNT_BIT_FLAGS
`0xE704838F36F93B7B` | `int _COUNT_BIT_FLAGS(Any* bitFlags)` | build 1355

## _CREATE_AI_MEMORY
`0x88BC5F4AEF77FC4E` | `void _CREATE_AI_MEMORY(Any* args, int aiMemoryType)` | build 1207
aiMemoryType: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/_CREATE_AI_MEMORY

## _CREATE_COLOR_STRING
`0xBCC2CFADEA1AEA6C` | `const char* _CREATE_COLOR_STRING(int rgb)` | build 1207
Returns a formatted string (0x%x)

## _CREATE_INCIDENT_WITH_ENTITIES
`0xAB3D3F45436DB1D8` | `BOOL _CREATE_INCIDENT_WITH_ENTITIES(int dispatchService, float x, float y, float z, ItemSet itemSet, float radius, int* outIncidentID)` | build 1207
dispatchService: see ENABLE_DISPATCH_SERVICE

The entities must be added to itemSet.

## _DISABLE_COMPOSITE_PICK_PROMPT_THIS_FRAME
`0x082C043C7AFC3747` | `void _DISABLE_COMPOSITE_PICK_PROMPT_THIS_FRAME(int compositeId, BOOL disable)` | build 1207
disables composite Pick prompt

## _DOES_ITEM_HAVE_VALID_BASE
`0xBDC6E364C9C78178` | `BOOL _DOES_ITEM_HAVE_VALID_BASE(ScrHandle item)` | build 1207

## _DOES_POP_MULTIPLIER_AREA_EXIST_FOR_VOLUME
`0x39D6DACE323A20B6` | `BOOL _DOES_POP_MULTIPLIER_AREA_EXIST_FOR_VOLUME(Volume volume)` | build 1207

## _DOES_STRING_EXIST_IN_STRING
`0x9382D5D43D2AA6FF` | `BOOL _DOES_STRING_EXIST_IN_STRING(char* string1, char* string2)` | build 1207

## _FORCE_LIGHTNING_FLASH_AT_COORDS
`0x67943537D179597C` | `void _FORCE_LIGHTNING_FLASH_AT_COORDS(float x, float y, float z, float p3)` | build 1207
p3 is always -1.0f in the scripts

## _GAME_FRAMEWORK_MANAGER_GET_MODE
`0xFAED234C7F53ABEB` | `Hash _GAME_FRAMEWORK_MANAGER_GET_MODE()` | build 1207

## _GAME_FRAMEWORK_MANAGER_SHUTDOWN
`0xAFF2FD8ADD927585` | `void _GAME_FRAMEWORK_MANAGER_SHUTDOWN()` | build 1207

## _GET_AI_PED_DOES_HAVE_EVENT_MEMORY
`0xFDF38E2B711BF78E` | `BOOL _GET_AI_PED_DOES_HAVE_EVENT_MEMORY(Any* args, int p1)` | build 1207

## _GET_EASING_CURVE_VALUE
`0xEF50E344A8F93784` | `float _GET_EASING_CURVE_VALUE(float t, float b, float d, int easingCurveType)` | build 1207
https://easings.net/

enum class eEasingCurveType
{
	TYPE_LINEAR,
	TYPE_QUADRATIC_IN,
	TYPE_QUADRATIC_OUT,
	TYPE_QUADRATIC_INOUT,
	TYPE_CUBIC_IN,
	TYPE_CUBIC_OUT,
	TYPE_CUBIC_INOUT,
	TYPE_QUARTIC_IN,
	TYPE_QUARTIC_OUT,
	TYPE_QUARTIC_INOUT,
	TYPE_QUINTIC_IN,
	TYPE_QUINTIC_OUT,
	TYPE_QUINTIC_INOUT,
	TYPE_EXPONENTIAL_IN,
	TYPE_EXPONENTIAL_OUT,
	TYPE_EXPONENTIAL_INOUT,
	TYPE_SINE_IN,
	TYPE_SINE_OUT,
	TYPE_SINE_INOUT,
	TYPE_CIRCULAR_IN,
	TYPE_CIRCULAR_OUT,
	TYPE_CIRCULAR_INOUT,
	TYPE_BOUNCE_IN,
	TYPE_BOUNCE_OUT,
	TYPE_BOUNCE_INOUT,
	TYPE_CUSTOM
};

## _GET_ENTITY_FROM_ITEM
`0xEE04C0AFD4EFAF0E` | `Entity _GET_ENTITY_FROM_ITEM(ScrHandle item)` | build 1207

## _GET_FORCED_WEATHER
`0xDD560ABEF5D3784C` | `void _GET_FORCED_WEATHER(Hash* weather, Hash* p1)` | build 1207
Returns the weather type that has been set by a script

## _GET_GAME_TIMER_NON_SCALED_CLIPPED
`0x483B8C542103AD72` | `int _GET_GAME_TIMER_NON_SCALED_CLIPPED()` | build 1207
Returns rage::fwTimer::sm_nonScaledClippedTime

## _GET_GROUND_Z_AND_MATERIAL_FOR_3D_COORD
`0xBBE5B63EFFB08E68` | `BOOL _GET_GROUND_Z_AND_MATERIAL_FOR_3D_COORD(Any coords, int flags, float* groundZ, Hash* material, int* outFlags)` | build 1207
Outputs the ground Z axis, its material and flags.Input flags are 17, 129 or 3423 in R* scripts.similar to flags of shapes test native

## _GET_ITEM_TYPE
`0xDC8D2FF478DF9553` | `int _GET_ITEM_TYPE(ScrHandle handle)` | build 1207
0 = invalid
1 = CEntity
2 = rage::volBase
3 = rage::volSphere
4 = rage::volBox
5 = rage::volAggregate
6 = rage::volCylinder
7 = CScriptedCoverPoint
8 = rage::ptfxScriptInfo
9 = CPed
10 = CVehicle
11 = CObject
12 = CItemSet
13 = CPersistentCharacter

## _GET_LOOTING_EVENT_HAS_FIRED
`0xF9B91C5129EABC08` | `BOOL _GET_LOOTING_EVENT_HAS_FIRED(Ped ped, char* eventName)` | build 1207
Event names in the scripts: MGBegin, MGEnd, ReadyForCut

## _GET_MAX_NUM_INSTRUCTIONS
`0xC43CD2668B204419` | `int _GET_MAX_NUM_INSTRUCTIONS()` | build 1207

## _GET_NEXT_WEATHER_TYPE_HASH_NAME
`0x51021D36F62AAA83` | `Hash _GET_NEXT_WEATHER_TYPE_HASH_NAME()` | build 1207

## _GET_NUMBER_OF_BULLETS_IMPACTED_ENTITY
`0x970339EFA4FDE518` | `int _GET_NUMBER_OF_BULLETS_IMPACTED_ENTITY(Entity entity, BOOL p1, BOOL p2)` | build 1207
returns the number of bullets that hit the entity

## _GET_NUMBER_OF_BULLETS_IN_AREA
`0xDC416CA762BC4F43` | `int _GET_NUMBER_OF_BULLETS_IN_AREA(float x, float y, float z, float radius, BOOL p4, BOOL p5)` | build 1207
returns the number of bullets that were shot in the area

## _GET_NUMBER_OF_INSTRUCTIONS
`0x72904D3D62AF5839` | `int _GET_NUMBER_OF_INSTRUCTIONS()` | build 1207

## _GET_OBJECT_FROM_INDEXED_ITEM
`0x18013392501CE5DC` | `Object _GET_OBJECT_FROM_INDEXED_ITEM(ScrHandle item)` | build 1207

## _GET_PED_FROM_INDEXED_ITEM
`0x3FFB15534067DCD4` | `Ped _GET_PED_FROM_INDEXED_ITEM(ScrHandle item)` | build 1207

## _GET_PREV_WEATHER_TYPE_HASH_NAME
`0x4BEB42AEBCA732E9` | `Hash _GET_PREV_WEATHER_TYPE_HASH_NAME()` | build 1207

## _GET_RANDOM_WEATHER_TYPE
`0x1359C181BC625503` | `Hash _GET_RANDOM_WEATHER_TYPE()` | build 1207

## _GET_RANDOM_WEATHER_TYPE_INDEX
`0x7F4CE164D9A11DFE` | `int _GET_RANDOM_WEATHER_TYPE_INDEX()` | build 1207

## _GET_STATUS_OF_SAVEGAME_OPERATION
`0x1B065A2BF7953815` | `int _GET_STATUS_OF_SAVEGAME_OPERATION(int p0)` | build 1207
Only 0 and 1 are valid for p0, higher values causes the native to return 2.

## _GET_STRING_FROM_BOOL
`0xF216F74101968DB0` | `const char* _GET_STRING_FROM_BOOL(BOOL value)` | build 1207

## _GET_STRING_FROM_FLOAT
`0x2B6846401D68E563` | `const char* _GET_STRING_FROM_FLOAT(float value, int digits)` | build 1207

## _GET_STRING_FROM_VECTOR
`0x6C4DBF553885F9EB` | `const char* _GET_STRING_FROM_VECTOR(float x, float y, float z)` | build 1207
Returns a string in the following format: <<%.4f,%.4f,%.4f>>

## _GET_TEMPERATURE_AT_COORDS
`0xB98B78C3768AF6E0` | `float _GET_TEMPERATURE_AT_COORDS(float x, float y, float z)` | build 1207

## _GET_VEHICLE_FROM_INDEXED_ITEM
`0xE578C8AE173719B3` | `Vehicle _GET_VEHICLE_FROM_INDEXED_ITEM(ScrHandle item)` | build 1207

## _GET_VOLUME_FROM_INDEXED_ITEM
`0xF18AF483DF70BBDE` | `Volume _GET_VOLUME_FROM_INDEXED_ITEM(ScrHandle item)` | build 1207

## _HAS_BULLET_IMPACTED_ENTITY
`0x7A76104CC2CC69E8` | `BOOL _HAS_BULLET_IMPACTED_ENTITY(Entity entity, BOOL p1, BOOL p2)` | build 1207
returns true if a bullet impacted the entity

## _INT_TO_STRING
`0xCF11C0CEB40C401B` | `void _INT_TO_STRING(int value, const char* format, char* buffer)` | build 1207
Note: the buffer should be exactly 32 bytes long

## _IS_ANY_BIT_FLAG_SET
`0x80E9C316EF84DD81` | `BOOL _IS_ANY_BIT_FLAG_SET(Any* bitFlags)` | build 1207

## _IS_BASE_A_COVER_POINT
`0xFEC1D4B5C82C176F` | `BOOL _IS_BASE_A_COVER_POINT(ScrHandle handle)` | build 1207

## _IS_BASE_A_PERSISTENT_CHARACTER
`0x716F17F8A0419F95` | `BOOL _IS_BASE_A_PERSISTENT_CHARACTER(ScrHandle handle)` | build 1207

## _IS_BIT_FLAG_SET
`0x8F4F050054005C27` | `BOOL _IS_BIT_FLAG_SET(Any* bitFlags, int flag)` | build 1207

## _IS_GLOBAL_BLOCK_VALID
`0xACB7E1418A8B6E32` | `BOOL _IS_GLOBAL_BLOCK_VALID(int index)` | build 1207

## _IS_MISSION_CREATOR_ACTIVE
`0xF236C84C6ADFCB2F` | `BOOL _IS_MISSION_CREATOR_ACTIVE()` | build 1207

## _IS_PED_DECOMPOSED
`0x5170DDA6D63ACAAA` | `BOOL _IS_PED_DECOMPOSED(Ped ped)` | build 1207

## _IS_PLAYER_OWNING_STANDALONE_SP
`0x36040772DF5E59A0` | `BOOL _IS_PLAYER_OWNING_STANDALONE_SP()` | build 1355

## _LOOT_TABLES_GET_INFO
`0x48E4D50F87A96AA5` | `void _LOOT_TABLES_GET_INFO(Ped ped, BOOL p1, BOOL p2, Hash lootTableKey, Any* p4, Any p5)` | build 1207

## _QUEUE_SAVEGAME_OPERATION
`0x279B0696DA4657EB` | `BOOL _QUEUE_SAVEGAME_OPERATION(int p0)` | build 1207
p0 must be < 2

## _READ_INT_AS_FLOAT
`0xD2C9126410DFA1B2` | `float _READ_INT_AS_FLOAT(int value)` | build 1207
Reads the passed value as floating point value and returns it.
Example: _READ_INT_AS_FLOAT(0x3F800000) returns 1.0f because 0x3F800000 is the hexadecimal representation of 1.0f.

## _REMOVE_POP_MULTIPLIER_AREA_FOR_VOLUME
`0xBD090F5B1DB82189` | `void _REMOVE_POP_MULTIPLIER_AREA_FOR_VOLUME(Volume volume, int p1)` | build 1207

## _RESET_DISPATCH_MAX_SPAWN_DISTANCE
`0x54EC7B6BC72BAD69` | `void _RESET_DISPATCH_MAX_SPAWN_DISTANCE()` | build 1207

## _RESET_DISPATCH_MIN_SPAWN_DISTANCE
`0x96498D922D8D0D0A` | `void _RESET_DISPATCH_MIN_SPAWN_DISTANCE()` | build 1207

## _SET_AI_MEMORY_REACTIONS_ENABLED
`0x6AC4AF46A6B8DFB2` | `void _SET_AI_MEMORY_REACTIONS_ENABLED(BOOL enabled)` | build 1207
Used in CAIConditionAmbientAIMemoryReactionsEnabled

## _SET_BIT_FLAG
`0xE84AAC1B22A73E99` | `void _SET_BIT_FLAG(Any* bitFlags, int flag)` | build 1207
Similar to SET_BIT but specifically designed for large (>32 flags) bit flag sets.
The flags are stored in an int array where each int has the ability to hold 32 flags.
Flags 0-31 would be stored in the first int, flags 32-63 in the second int, etc.

## _SET_DISPATCH_MAX_SPAWN_DISTANCE
`0x89314FB3463E28DE` | `void _SET_DISPATCH_MAX_SPAWN_DISTANCE(float maxSpawnDistance)` | build 1207

## _SET_DISPATCH_MIN_SPAWN_DISTANCE
`0x27A1B170AA8AF84C` | `void _SET_DISPATCH_MIN_SPAWN_DISTANCE(float minSpawnDistance)` | build 1207

## _SET_GAME_LOGIC_PAUSED
`0x550F05CFFBD63C8C` | `void _SET_GAME_LOGIC_PAUSED()` | build 1232
Note: this native was added in build 1232.56

## _SET_GLOBAL_BLOCK_IS_LOADED
`0xE97240065406CB80` | `void _SET_GLOBAL_BLOCK_IS_LOADED(int index, BOOL toggle)` | build 1207

## _SET_INCIDENT_UNK
`0x9617B6E5F6537B63` | `void _SET_INCIDENT_UNK(int incidentId)` | build 1207

## _SET_LOOT_PELT_SATCHEL_ITEM
`0x9B47971234169990` | `void _SET_LOOT_PELT_SATCHEL_ITEM(Ped ped, Any item)` | build 1207

## _SET_OVERRIDE_WEATHER
`0xBE83CAE8ED77A94F` | `void _SET_OVERRIDE_WEATHER(Hash weatherType)` | build 1207

## _SET_SNOW_LEVEL
`0xF6BEE7E80EC5CA40` | `void _SET_SNOW_LEVEL(float level)` | build 1207

## _SET_WEATHER_TYPE_2
`0x2C6A07AF9AEDABD8` | `void _SET_WEATHER_TYPE_2(Hash weatherType, int p1, int p2, int p3, BOOL p4)` | build 1207

## _SET_WEATHER_TYPE_FROZEN
`0xD74ACDF7DB8114AF` | `void _SET_WEATHER_TYPE_FROZEN(BOOL toggle)` | build 1207

## _SET_WEATHER_VARIATION
`0x3373779BAF7CAF48` | `void _SET_WEATHER_VARIATION(char* weatherType, char* variation)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/weather/weather_variations.lua

## _SHOULD_USE_24_HOUR_CLOCK
`0x0177CF20345F44DD` | `BOOL _SHOULD_USE_24_HOUR_CLOCK()` | build 1207

## _SHOULD_USE_METRIC_MEASUREMENTS_2
`0x58BCDC75BA52110A` | `BOOL _SHOULD_USE_METRIC_MEASUREMENTS_2()` | build 1207
Same as SHOULD_USE_METRIC_MEASUREMENTS

## _SHOULD_USE_METRIC_TEMPERATURE
`0xFF4AAF3275BAAB4F` | `BOOL _SHOULD_USE_METRIC_TEMPERATURE()` | build 1207

## _SHOULD_USE_METRIC_WEIGHT
`0x8F24157FEDB85EA2` | `BOOL _SHOULD_USE_METRIC_WEIGHT()` | build 1207

## _STRING_SPLIT_AND_COUNT_SEGMENTS
`0x94E8CA3DEE952789` | `int _STRING_SPLIT_AND_COUNT_SEGMENTS(char* inputString, char* delimiters)` | build 1207
Not officially named 
, Counts the number of segments in a string that are separated by specified delimiter characters, ignoring consecutive delimiters.
```lua
local count = N_0x94e8ca3dee952789('AAA_BB-AAA_BB;AAA_BB,AAA_BB.AAA_BB;AAA_BB-', '-,;.');
// Returns 6, counts all segments separated by '-', ',', ';', or '.', while ignoring consecutive delimiters.
```
