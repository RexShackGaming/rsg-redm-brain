# VEHICLE natives (387)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_ROAD_NODE_SPEED_ZONE
`0x4C221BAC54D735C3` | `int ADD_ROAD_NODE_SPEED_ZONE(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10)` | build 1207

## ARE_ANY_VEHICLE_SEATS_FREE
`0xA0A424505A1B6429` | `BOOL ARE_ANY_VEHICLE_SEATS_FREE(Vehicle vehicle)` | build 1207
Returns false if every seat is occupied.

## BRING_VEHICLE_TO_HALT
`0x260BE8F09E326A20` | `void BRING_VEHICLE_TO_HALT(Vehicle vehicle, float distance, int duration, BOOL unknown)` | build 1207
This native makes the vehicle stop immediately

distance defines how far it will travel until stopping.

## CAN_ANCHOR_BOAT_HERE
`0xC075176CFB8B4128` | `BOOL CAN_ANCHOR_BOAT_HERE(Vehicle vehicle)` | build 1207

## CAN_SHUFFLE_SEAT
`0xF8B2D32A2231FD24` | `BOOL CAN_SHUFFLE_SEAT(Vehicle vehicle, int seatIndex)` | build 1207
seatIndex: see CREATE_PED_INSIDE_VEHICLE

## CLEAR_LAST_DRIVEN_VEHICLE
`0x0EFC5DC62E67609B` | `void CLEAR_LAST_DRIVEN_VEHICLE()` | build 1207

## COPY_VEHICLE_DAMAGES
`0xDBC28A8C683CD80B` | `void COPY_VEHICLE_DAMAGES(Vehicle sourceVehicle, Vehicle targetVehicle)` | build 1207
Copies sourceVehicle's damage (broken bumpers, broken lights, etc.) to targetVehicle.

## CREATE_VEHICLE
`0xAF35D0D2583051B0` | `Vehicle CREATE_VEHICLE(Hash modelHash, float x, float y, float z, float heading, BOOL isNetwork, BOOL bScriptHostVeh, BOOL bDontAutoCreateDraftAnimals, BOOL p8)` | build 1207

## DELETE_ALL_TRAINS
`0xA3120A1385F17FF7` | `void DELETE_ALL_TRAINS()` | build 1207

## DELETE_MISSION_TRAIN
`0x0D3630FB07E8B570` | `void DELETE_MISSION_TRAIN(Vehicle* train)` | build 1207

## DELETE_VEHICLE
`0xE20A909D8C4A70F8` | `void DELETE_VEHICLE(Vehicle* vehicle)` | build 1207
Deletes a vehicle.
The vehicle must be a mission entity to delete, so call this before deleting: SET_ENTITY_AS_MISSION_ENTITY(vehicle, true, true);

eg how to use:
SET_ENTITY_AS_MISSION_ENTITY(vehicle, true, true);
DELETE_VEHICLE(&vehicle);

Deletes the specified vehicle, then sets the handle pointed to by the pointer to NULL.

## DISABLE_VEHICLE_WEAPON
`0x94B1E71B144356A5` | `void DISABLE_VEHICLE_WEAPON(BOOL disabled, Hash weaponHash, Vehicle vehicle, Ped owner)` | build 1207

## DOES_EXTRA_EXIST
`0xAF5E7E9A7620FFB5` | `BOOL DOES_EXTRA_EXIST(Vehicle vehicle, int extraId)` | build 1207

## EXPLODE_VEHICLE
`0x75DCED9EEC5769D7` | `void EXPLODE_VEHICLE(Vehicle vehicle, BOOL isAudible, BOOL isInvisible, Any p3, Any p4)` | build 1207
Explodes a selected vehicle.

Vehicle vehicle = Vehicle you want to explode.
BOOL isAudible = If explosion makes a sound.
BOOL isInvisible = If the explosion is invisible or not.

First BOOL does not give any visual explosion, the vehicle just falls apart completely but slowly and starts to burn.

## FORCE_PLAYBACK_RECORDED_VEHICLE_UPDATE
`0x59ECA796021B0539` | `void FORCE_PLAYBACK_RECORDED_VEHICLE_UPDATE(Vehicle vehicle, BOOL p1)` | build 1207
Often called after START_PLAYBACK_RECORDED_VEHICLE and SKIP_TIME_IN_PLAYBACK_RECORDED_VEHICLE; similar in use to FORCE_ENTITY_AI_AND_ANIMATION_UPDATE.

## GET_CLOSEST_VEHICLE
`0x52F45D033645181B` | `Vehicle GET_CLOSEST_VEHICLE(float x, float y, float z, float radius, Hash modelHash, int flags)` | build 1207

## GET_CURRENT_STATION_FOR_TRAIN
`0x86FA6D8B48667D75` | `int GET_CURRENT_STATION_FOR_TRAIN(Vehicle train)` | build 1207
Returns p1 for 0xBA958F68031DDBFC (stationIndex)

## GET_DRAFT_ANIMAL_COUNT
`0xA19447D83294E29F` | `BOOL GET_DRAFT_ANIMAL_COUNT(Vehicle vehicle, int* expected, int* actual)` | build 1207

## GET_DRIVER_OF_VEHICLE
`0x2963B5C1637E8A27` | `Ped GET_DRIVER_OF_VEHICLE(Vehicle vehicle)` | build 1207

## GET_LAST_DRIVEN_VEHICLE
`0xA94F3E0AB9695E19` | `Vehicle GET_LAST_DRIVEN_VEHICLE()` | build 1207

## GET_LAST_PED_IN_VEHICLE_SEAT
`0x74583B19FEEAFDA7` | `Ped GET_LAST_PED_IN_VEHICLE_SEAT(Vehicle vehicle, int seatIndex)` | build 1207
seatIndex: see CREATE_PED_INSIDE_VEHICLE

## GET_PED_IN_VEHICLE_SEAT
`0xBB40DD2270B65366` | `Ped GET_PED_IN_VEHICLE_SEAT(Vehicle vehicle, int seatIndex)` | build 1207
seatIndex: see CREATE_PED_INSIDE_VEHICLE

## GET_POSITION_OF_VEHICLE_RECORDING_AT_TIME
`0x1A00961A1BE94E5E` | `Vector3 GET_POSITION_OF_VEHICLE_RECORDING_AT_TIME(int recording, float time, char* script)` | build 1207
This native does no interpolation between pathpoints. The same position will be returned for all times up to the next pathpoint in the recording.

See REQUEST_VEHICLE_RECORDING

## GET_ROTATION_OF_VEHICLE_RECORDING_AT_TIME
`0x61787DD28B8CC0D5` | `Vector3 GET_ROTATION_OF_VEHICLE_RECORDING_AT_TIME(int recording, float time, char* script)` | build 1207
This native does no interpolation between pathpoints. The same rotation will be returned for all times up to the next pathpoint in the recording.

See REQUEST_VEHICLE_RECORDING

## GET_TIME_POSITION_IN_RECORDING
`0x233B51C7913FA031` | `float GET_TIME_POSITION_IN_RECORDING(Vehicle vehicle)` | build 1207

## GET_TRACK_INDEX_OF_TRAIN
`0x865FEC2FA899F29C` | `int GET_TRACK_INDEX_OF_TRAIN(Vehicle train)` | build 1207

## GET_TRAIN_CARRIAGE
`0xD0FB093A4CDB932C` | `Vehicle GET_TRAIN_CARRIAGE(Vehicle train, int trailerNumber)` | build 1207

## GET_VEHICLE_BODY_HEALTH
`0x42113B857E33C16E` | `float GET_VEHICLE_BODY_HEALTH(Vehicle vehicle)` | build 1207
Seems related to vehicle health, like the one in IV.
Max 1000, min 0.
Vehicle does not necessarily explode or become undrivable at 0.

## GET_VEHICLE_DOORS_LOCKED_FOR_PLAYER
`0xFA2CDDFEB8BC898B` | `BOOL GET_VEHICLE_DOORS_LOCKED_FOR_PLAYER(Vehicle vehicle, Player player)` | build 1207

## GET_VEHICLE_DOOR_LOCK_STATUS
`0xC867FD144F2469D3` | `int GET_VEHICLE_DOOR_LOCK_STATUS(Vehicle vehicle)` | build 1207

## GET_VEHICLE_ENGINE_HEALTH
`0x90DBFFAC43B22081` | `float GET_VEHICLE_ENGINE_HEALTH(Vehicle vehicle)` | build 1207
Returns 1000.0 if the function is unable to get the address of the specified vehicle or if it's not a vehicle.

Minimum: -4000
Maximum: 1000

-4000: Engine is destroyed
0 and below: Engine catches fire and health rapidly declines
300: Engine is smoking and losing functionality
1000: Engine is perfect

## GET_VEHICLE_ESTIMATED_MAX_SPEED
`0xFE52F34491529F0B` | `float GET_VEHICLE_ESTIMATED_MAX_SPEED(Vehicle vehicle)` | build 1207

## GET_VEHICLE_MAX_NUMBER_OF_PASSENGERS
`0xA9C55F1C15E62E06` | `int GET_VEHICLE_MAX_NUMBER_OF_PASSENGERS(Vehicle vehicle)` | build 1207

## GET_VEHICLE_MODEL_NUMBER_OF_SEATS
`0x9A578736FF3A17C3` | `int GET_VEHICLE_MODEL_NUMBER_OF_SEATS(Hash modelHash)` | build 1207

## GET_VEHICLE_NUMBER_OF_PASSENGERS
`0x59F3F16577CD79B2` | `int GET_VEHICLE_NUMBER_OF_PASSENGERS(Vehicle vehicle)` | build 1207
Gets the number of passengers, NOT including the driver. Use IS_VEHICLE_SEAT_FREE(Vehicle, -1) to also check for the driver

## GET_VEHICLE_PETROL_TANK_HEALTH
`0x1E5A9B356D5098BE` | `float GET_VEHICLE_PETROL_TANK_HEALTH(Vehicle vehicle)` | build 1207
1000 is max health

## GET_VEHICLE_TRAILER_VEHICLE
`0xCF867A239EC30741` | `BOOL GET_VEHICLE_TRAILER_VEHICLE(Vehicle vehicle, Vehicle* trailer)` | build 1207
Gets the trailer of a vehicle and puts it into the trailer parameter.

## HAS_INSTANT_FILL_VEHICLE_POPULATION_FINISHED
`0x2701D01D5E18FC31` | `BOOL HAS_INSTANT_FILL_VEHICLE_POPULATION_FINISHED()` | build 1207

## HAS_VEHICLE_ASSET_LOADED
`0xB935F3154BC913C8` | `BOOL HAS_VEHICLE_ASSET_LOADED(Hash vehicleAsset)` | build 1207

## HAS_VEHICLE_RECORDING_BEEN_LOADED
`0xBA9325BE372AB6EA` | `BOOL HAS_VEHICLE_RECORDING_BEEN_LOADED(int recording, char* script)` | build 1207
See REQUEST_VEHICLE_RECORDING

## INSTANTLY_FILL_VEHICLE_POPULATION
`0x1FF00DB43026B12F` | `void INSTANTLY_FILL_VEHICLE_POPULATION()` | build 1207

## IS_ANY_VEHICLE_NEAR_POINT
`0x5698BA4FD04D39C4` | `BOOL IS_ANY_VEHICLE_NEAR_POINT(float x, float y, float z, float radius)` | build 1207

## IS_DRAFT_VEHICLE
`0xEA44E97849E9F3DD` | `BOOL IS_DRAFT_VEHICLE(Vehicle vehicle)` | build 1207

## IS_ENTRY_POINT_FOR_SEAT_CLEAR
`0x80DDCCB2F4A3EB57` | `BOOL IS_ENTRY_POINT_FOR_SEAT_CLEAR(Ped ped, Vehicle vehicle, int seatIndex, BOOL side, BOOL onEnter)` | build 1207

## IS_PLAYBACK_GOING_ON_FOR_VEHICLE
`0x02774B3A9034278F` | `BOOL IS_PLAYBACK_GOING_ON_FOR_VEHICLE(Vehicle vehicle)` | build 1207

## IS_PLAYBACK_USING_AI_GOING_ON_FOR_VEHICLE
`0x5A7472606EC5B7C1` | `BOOL IS_PLAYBACK_USING_AI_GOING_ON_FOR_VEHICLE(Vehicle vehicle)` | build 1207

## IS_SEAT_WARP_ONLY
`0x7892685BF6D9775E` | `BOOL IS_SEAT_WARP_ONLY(Vehicle vehicle, int seatIndex)` | build 1207
seatIndex: see CREATE_PED_INSIDE_VEHICLE

## IS_THIS_MODEL_A_BOAT
`0x799CFC7C5B743B15` | `BOOL IS_THIS_MODEL_A_BOAT(Hash model)` | build 1207

## IS_THIS_MODEL_A_TRAIN
`0xFC08C8F8C1EDF174` | `BOOL IS_THIS_MODEL_A_TRAIN(Hash model)` | build 1207

## IS_TRAIN_WAITING_AT_STATION
`0xE887BD31D97793F6` | `BOOL IS_TRAIN_WAITING_AT_STATION(Vehicle train)` | build 1207

## IS_VEHICLE_DOOR_FULLY_OPEN
`0x7AE191143C7A9107` | `BOOL IS_VEHICLE_DOOR_FULLY_OPEN(Vehicle vehicle, int doorId)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT

## IS_VEHICLE_DRIVEABLE
`0xB86D29B10F627379` | `BOOL IS_VEHICLE_DRIVEABLE(Vehicle vehicle, BOOL p1, BOOL p2)` | build 1207

## IS_VEHICLE_EXTRA_TURNED_ON
`0xFA9A55D9C4351625` | `BOOL IS_VEHICLE_EXTRA_TURNED_ON(Vehicle vehicle, int extraId)` | build 1207

## IS_VEHICLE_IN_BURNOUT
`0x3F5029A8FC060C48` | `BOOL IS_VEHICLE_IN_BURNOUT(Vehicle vehicle)` | build 1207

## IS_VEHICLE_MODEL
`0x0045A54EC7A22455` | `BOOL IS_VEHICLE_MODEL(Vehicle vehicle, Hash model)` | build 1207

## IS_VEHICLE_ON_ALL_WHEELS
`0x0D5D119529654EE0` | `BOOL IS_VEHICLE_ON_ALL_WHEELS(Vehicle vehicle)` | build 1207

## IS_VEHICLE_SEAT_FREE
`0xE052C1B1CAA4ECE4` | `BOOL IS_VEHICLE_SEAT_FREE(Vehicle vehicle, int seatIndex)` | build 1207
seatIndex: see CREATE_PED_INSIDE_VEHICLE
Use GET_VEHICLE_MAX_NUMBER_OF_PASSENGERS(vehicle) - 1 for last seat index.

## IS_VEHICLE_STOPPED
`0x78C3311A73135241` | `BOOL IS_VEHICLE_STOPPED(Vehicle vehicle)` | build 1207
Returns true if the vehicle's current speed is less than, or equal to 0.0025f.

For some vehicles it returns true if the current speed is <= 0.00039999999.

## IS_VEHICLE_STUCK_TIMER_UP
`0x1ABA9753939503C5` | `BOOL IS_VEHICLE_STUCK_TIMER_UP(Vehicle vehicle, int stuckType, int ms)` | build 1207
VEH_STUCK_ON_ROOF = 0,
VEH_STUCK_ON_SIDE,
VEH_STUCK_HUNG_UP,
VEH_STUCK_JAMMED

## IS_VEHICLE_VISIBLE
`0x424910CD5DE8C246` | `BOOL IS_VEHICLE_VISIBLE(Vehicle vehicle)` | build 1207
Requires a visibility tracker on the vehicle (TRACK_VEHICLE_VISIBILITY)

## IS_VEHICLE_WINDOW_INTACT
`0x0E7910A63E05B12C` | `BOOL IS_VEHICLE_WINDOW_INTACT(Vehicle vehicle, int windowIndex)` | build 1436

## IS_VEHICLE_WRECKED
`0xDDBEA5506C848227` | `BOOL IS_VEHICLE_WRECKED(Vehicle vehicle)` | build 1207

## LOCK_DOORS_WHEN_NO_LONGER_NEEDED
`0x1EF36558FBDE2DAA` | `void LOCK_DOORS_WHEN_NO_LONGER_NEEDED(Vehicle vehicle)` | build 1207

## MODIFY_VEHICLE_TOP_SPEED
`0x35AD938C74CACD6A` | `void MODIFY_VEHICLE_TOP_SPEED(Vehicle vehicle, float value)` | build 1207

## REMOVE_ROAD_NODE_SPEED_ZONE
`0xFE9AB3354ACE6C9C` | `BOOL REMOVE_ROAD_NODE_SPEED_ZONE(int speedzone)` | build 1207

## REMOVE_VEHICLES_FROM_GENERATORS_IN_AREA
`0xC619A44639BC0CB4` | `void REMOVE_VEHICLES_FROM_GENERATORS_IN_AREA(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## REMOVE_VEHICLE_ASSET
`0x888A4E675B38F5AD` | `void REMOVE_VEHICLE_ASSET(Hash vehicleAsset)` | build 1207

## REMOVE_VEHICLE_RECORDING
`0x139E35755418F6AA` | `void REMOVE_VEHICLE_RECORDING(Any p0, Any* p1)` | build 1207
See REQUEST_VEHICLE_RECORDING

## REMOVE_VEHICLE_WINDOW
`0x745F15A215F2DDF1` | `void REMOVE_VEHICLE_WINDOW(Vehicle vehicle, int windowIndex)` | build 1207
windowIndex:
0 = Front Right Window
1 = Front Left Window
2 = Back Right Window
3 = Back Left Window

## REQUEST_VEHICLE_ASSET
`0x81A15811460FAB3A` | `void REQUEST_VEHICLE_ASSET(Hash vehicleHash, int vehicleAsset)` | build 1207

## REQUEST_VEHICLE_HIGH_DETAIL_MODEL
`0x84B81EF78BD22357` | `void REQUEST_VEHICLE_HIGH_DETAIL_MODEL(Vehicle vehicle)` | build 1207

## REQUEST_VEHICLE_RECORDING
`0xC474CF16EDA45DC9` | `void REQUEST_VEHICLE_RECORDING(int recording, char* script)` | build 1207
Request the vehicle recording defined by the lowercase format string "%s%03d.yvr". For example, REQUEST_VEHICLE_RECORDING(1, "FBIs1UBER") corresponds to fbis1uber001.yvr.
For all vehicle recording/playback natives, "script" is a common prefix that usually corresponds to the script/mission the recording is used in, "recording" is its int suffix, and "id" corresponds to a unique identifier within the recording streaming module.
(GTA) Note that only 24 recordings (hardcoded in multiple places) can ever active at a given time before clobbering begins.

## RESET_VEHICLE_STUCK_TIMER
`0x23298B468F7D88B6` | `void RESET_VEHICLE_STUCK_TIMER(Vehicle vehicle, int nullAttributes)` | build 1207

## SET_ALLOW_VEHICLE_EXPLODES_ON_CONTACT
`0x8D3230A0ED7DE39F` | `void SET_ALLOW_VEHICLE_EXPLODES_ON_CONTACT(Vehicle vehicle, BOOL p1)` | build 1207

## SET_ALL_VEHICLE_GENERATORS_ACTIVE
`0x3D596E6E88A02C24` | `void SET_ALL_VEHICLE_GENERATORS_ACTIVE()` | build 1207

## SET_ALL_VEHICLE_GENERATORS_ACTIVE_IN_AREA
`0xBBB134FB9D50C0CC` | `void SET_ALL_VEHICLE_GENERATORS_ACTIVE_IN_AREA(float x1, float y1, float z1, float x2, float y2, float z2, BOOL p6, BOOL p7)` | build 1207

## SET_BOAT_ANCHOR
`0xAEAB044F05B92659` | `void SET_BOAT_ANCHOR(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_BOAT_LOW_LOD_ANCHOR_DISTANCE
`0xE3261532550D6A9F` | `void SET_BOAT_LOW_LOD_ANCHOR_DISTANCE(Vehicle vehicle, float value)` | build 1207
Value: mostly 99999.9f

Old name: _SET_BOAT_MOVEMENT_RESISTANCE

## SET_BOAT_REMAINS_ANCHORED_WHILE_PLAYER_IS_DRIVER
`0x286771F3059A37A7` | `void SET_BOAT_REMAINS_ANCHORED_WHILE_PLAYER_IS_DRIVER(Vehicle vehicle, BOOL p1, BOOL p2)` | build 1207
Old name: _SET_BOAT_FROZEN_WHEN_ANCHORED

## SET_BOAT_SINKS_WHEN_WRECKED
`0x62A6D317A011EA1D` | `void SET_BOAT_SINKS_WHEN_WRECKED(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_BREAKABLE_VEHICLE_LOCKS_UNBREAKABLE
`0xBC4735F48CD983EF` | `void SET_BREAKABLE_VEHICLE_LOCKS_UNBREAKABLE(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_DISABLE_RANDOM_TRAINS_THIS_FRAME
`0xD4288603E8766FF7` | `void SET_DISABLE_RANDOM_TRAINS_THIS_FRAME(BOOL toggle)` | build 1207
nullsub, doesn't do anything

## SET_DISABLE_SUPERDUMMY
`0x1716D787D9B94202` | `void SET_DISABLE_SUPERDUMMY(Vehicle vehicle, BOOL disable)` | build 1232
Old name: _SET_DISABLE_SUPERDUMMY_MODE

## SET_DISABLE_VEHICLE_ENGINE_FIRES
`0xD146EE5F2B06B95E` | `void SET_DISABLE_VEHICLE_ENGINE_FIRES(Vehicle vehicle, BOOL p1)` | build 1207

## SET_DISABLE_VEHICLE_PETROL_TANK_DAMAGE
`0x5795FBE7A2001C14` | `void SET_DISABLE_VEHICLE_PETROL_TANK_DAMAGE(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_DISABLE_VEHICLE_PETROL_TANK_FIRES
`0xB70986AB19B04AFF` | `void SET_DISABLE_VEHICLE_PETROL_TANK_FIRES(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_DONT_ALLOW_PLAYER_TO_ENTER_VEHICLE_IF_LOCKED_FOR_PLAYER
`0x63DC1F22C903B709` | `void SET_DONT_ALLOW_PLAYER_TO_ENTER_VEHICLE_IF_LOCKED_FOR_PLAYER(Vehicle vehicle, BOOL p1)` | build 1207

## SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF
`0x081FB9D6422F804C` | `void SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Vehicle vehicle, int doorId, BOOL isBreakable)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT

Old name: _SET_VEHICLE_DOOR_CAN_BREAK

## SET_ENABLE_VEHICLE_SLIPSTREAMING
`0x73F1E4F6DF26FE30` | `void SET_ENABLE_VEHICLE_SLIPSTREAMING(BOOL p0)` | build 1207

## SET_FORCE_HD_VEHICLE
`0x373CB1283308BD7B` | `void SET_FORCE_HD_VEHICLE(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_FORCE_LOW_LOD_ANCHOR_MODE
`0x75B49ACD73617437` | `void SET_FORCE_LOW_LOD_ANCHOR_MODE(Vehicle vehicle, BOOL p1)` | build 1207
Sets boat to be anchored on spawn, called together with SET_BOAT_ANCHOR and _SET_BOAT_ANCHOR_BUOYANCY_COEFFICIENT

## SET_FORCE_VEHICLE_ENGINE_DAMAGE_BY_BULLET
`0x7F8E2B131E1DCA6C` | `void SET_FORCE_VEHICLE_ENGINE_DAMAGE_BY_BULLET(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_MISSION_TRAIN_AS_NO_LONGER_NEEDED
`0xBBE7648349B49BE8` | `void SET_MISSION_TRAIN_AS_NO_LONGER_NEEDED(Vehicle* train, int flags)` | build 1207
flags = 0: DEFAULT; 1: KEEP_OLD_SPEED

## SET_MISSION_TRAIN_COORDS
`0x7632755962AB9922` | `void SET_MISSION_TRAIN_COORDS(Vehicle train, float x, float y, float z)` | build 1207

## SET_PARKED_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME
`0xFEDFA97638D61D4A` | `void SET_PARKED_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## SET_PED_OWNS_VEHICLE
`0x838C216C2B05A009` | `void SET_PED_OWNS_VEHICLE(Ped ped, Vehicle vehicle)` | build 1207

## SET_PLAYBACK_SPEED
`0xD78084EED4CD94C6` | `void SET_PLAYBACK_SPEED(Vehicle vehicle, float speed)` | build 1207

## SET_RANDOM_BOATS
`0xF44D446D4E36DB87` | `void SET_RANDOM_BOATS(BOOL toggle)` | build 1207

## SET_RANDOM_TRAINS
`0x1156C6EE7E82A98A` | `void SET_RANDOM_TRAINS(BOOL toggle)` | build 1207

## SET_RANDOM_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME
`0x1F91D44490E1EA0C` | `void SET_RANDOM_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## SET_TRAIN_CRUISE_SPEED
`0x01021EB2E96B793C` | `void SET_TRAIN_CRUISE_SPEED(Vehicle train, float speed)` | build 1207

## SET_TRAIN_OFFSET_FROM_STATION
`0x8EC47DD4300BF063` | `void SET_TRAIN_OFFSET_FROM_STATION(Vehicle train, float offset)` | build 1207

## SET_TRAIN_SPEED
`0xDFBA6BBFF7CCAFBB` | `void SET_TRAIN_SPEED(Vehicle train, float speed)` | build 1207

## SET_VEHICLE_AI_CAN_USE_EXCLUSIVE_SEATS
`0x0893DAFBFA67110E` | `void SET_VEHICLE_AI_CAN_USE_EXCLUSIVE_SEATS(Vehicle vehicle, BOOL toggle)` | build 1207
Used to be incorrectly named SET_VEHICLE_EXCLUSIVE_DRIVER

## SET_VEHICLE_ALLOW_HOMING_MISSLE_LOCKON
`0x1240E8596A8308B9` | `void SET_VEHICLE_ALLOW_HOMING_MISSLE_LOCKON(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_ALLOW_NO_PASSENGERS_LOCKON
`0xECB9E9BC887E8060` | `void SET_VEHICLE_ALLOW_NO_PASSENGERS_LOCKON(Vehicle vehicle, BOOL toggle)` | build 1207
Makes the vehicle accept no passengers.

## SET_VEHICLE_AUTOMATICALLY_ATTACHES
`0x501354951CD942DE` | `Any SET_VEHICLE_AUTOMATICALLY_ATTACHES(Vehicle vehicle, BOOL p1, Any p2)` | build 1207

## SET_VEHICLE_BODY_HEALTH
`0x55CCAAE4F28C67A0` | `void SET_VEHICLE_BODY_HEALTH(Vehicle vehicle, float value)` | build 1207

## SET_VEHICLE_BROKEN_PARTS_DONT_AFFECT_AI_HANDLING
`0xCEC4CA2CAB8FA98C` | `void SET_VEHICLE_BROKEN_PARTS_DONT_AFFECT_AI_HANDLING(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_CAN_BE_TARGETTED
`0x05254BA0B44ADC16` | `void SET_VEHICLE_CAN_BE_TARGETTED(Vehicle vehicle, BOOL state)` | build 1207

## SET_VEHICLE_CAN_BE_USED_BY_FLEEING_PEDS
`0xE42952510F84AFDB` | `void SET_VEHICLE_CAN_BE_USED_BY_FLEEING_PEDS(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_CAN_BE_VISIBLY_DAMAGED
`0x4BF8131AE811541C` | `void SET_VEHICLE_CAN_BE_VISIBLY_DAMAGED(Vehicle vehicle, BOOL state)` | build 1207

## SET_VEHICLE_CAN_BREAK
`0xC5ED9D59B4646611` | `void SET_VEHICLE_CAN_BREAK(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_CAN_EJECT_PASSENGERS_IF_LOCKED
`0x065D03A9D6B2C6B5` | `void SET_VEHICLE_CAN_EJECT_PASSENGERS_IF_LOCKED(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_DAMAGE
`0x1D7678F81452BB41` | `void SET_VEHICLE_DAMAGE(Vehicle vehicle, float xOffset, float yOffset, float zOffset, float damage, float radius, BOOL p6)` | build 1207
Apply damage to vehicle at a location. Location is relative to vehicle model (not world).

Radius of effect damage applied in a sphere at impact location

## SET_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME
`0x606374EBFC27B133` | `void SET_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## SET_VEHICLE_DIRT_LEVEL
`0x758C3460EE915D0A` | `void SET_VEHICLE_DIRT_LEVEL(Vehicle vehicle, float dirtLevel)` | build 1207

## SET_VEHICLE_DOORS_LOCKED
`0x96F78A6A075D55D9` | `void SET_VEHICLE_DOORS_LOCKED(Vehicle vehicle, int doorLockStatus)` | build 1207

## SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS
`0x2381977DA948F8DC` | `void SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_DOORS_LOCKED_FOR_PLAYER
`0x359A8EA1FB8D6F0F` | `void SET_VEHICLE_DOORS_LOCKED_FOR_PLAYER(Vehicle vehicle, Player player, BOOL toggle)` | build 1207

## SET_VEHICLE_DOORS_LOCKED_FOR_TEAM
`0xE712BC978770F105` | `void SET_VEHICLE_DOORS_LOCKED_FOR_TEAM(Vehicle vehicle, int team, BOOL toggle)` | build 1207

## SET_VEHICLE_DOORS_SHUT
`0xA4FFCD645B11F25A` | `void SET_VEHICLE_DOORS_SHUT(Vehicle vehicle, BOOL closeInstantly)` | build 1207
Closes all doors of a vehicle:

## SET_VEHICLE_DOORS_TO_OPEN_AT_ANY_DISTANCE
`0x362CEDD2A41E0747` | `void SET_VEHICLE_DOORS_TO_OPEN_AT_ANY_DISTANCE(Vehicle vehicle, BOOL toggle)` | build 1232

## SET_VEHICLE_DOOR_BROKEN
`0x9666CF20A1C6D780` | `void SET_VEHICLE_DOOR_BROKEN(Vehicle vehicle, int doorId, BOOL deleteDoor)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT

## SET_VEHICLE_DOOR_CONTROL
`0xD57F10EBBA814ECF` | `void SET_VEHICLE_DOOR_CONTROL(Vehicle vehicle, int doorId, int speed, float angle)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT

## SET_VEHICLE_DOOR_LATCHED
`0x06F8A202EB312A3C` | `void SET_VEHICLE_DOOR_LATCHED(Vehicle vehicle, int doorId, BOOL p2, BOOL p3, BOOL p4)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT

## SET_VEHICLE_DOOR_OPEN
`0x550CE392A4672412` | `void SET_VEHICLE_DOOR_OPEN(Vehicle vehicle, int doorId, BOOL loose, BOOL openInstantly)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT
Can also be used on trains and its wagons

## SET_VEHICLE_DOOR_SHUT
`0x6A3C24B91FD0EA09` | `void SET_VEHICLE_DOOR_SHUT(Vehicle vehicle, int doorId, BOOL closeInstantly)` | build 1207
doorId: enum eDoorId
{
	VEH_EXT_DOOR_INVALID_ID = -1,
	VEH_EXT_DOOR_DSIDE_F,
	VEH_EXT_DOOR_DSIDE_M,
	VEH_EXT_DOOR_DSIDE_M1,
	VEH_EXT_DOOR_DSIDE_M2,
	VEH_EXT_DOOR_DSIDE_R,
	VEH_EXT_DOOR_PSIDE_F,
	VEH_EXT_DOOR_PSIDE_M,
	VEH_EXT_DOOR_PSIDE_M1,
	VEH_EXT_DOOR_PSIDE_M2,
	VEH_EXT_DOOR_PSIDE_R,
	VEH_EXT_BONNET,
	VEH_EXT_BOOT
};

## SET_VEHICLE_ENGINE_CAN_DEGRADE
`0x48E4C137A71C2688` | `void SET_VEHICLE_ENGINE_CAN_DEGRADE(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_ENGINE_HEALTH
`0x8BDC5B998B4654EF` | `void SET_VEHICLE_ENGINE_HEALTH(Vehicle vehicle, float health)` | build 1207
1000 is max health
Begins leaking gas at around 650 health
-999.90002441406 appears to be minimum health, although nothing special occurs <- false statement

-------------------------
Minimum: -4000
Maximum: 1000

-4000: Engine is destroyed
0 and below: Engine catches fire and health rapidly declines
300: Engine is smoking and losing functionality
1000: Engine is perfect

## SET_VEHICLE_ENGINE_ON
`0xB64CFA14CB9A2E78` | `void SET_VEHICLE_ENGINE_ON(Vehicle vehicle, BOOL value, BOOL instantly)` | build 1207
Starts or stops the engine on the specified vehicle.

vehicle: The vehicle to start or stop the engine on.
value: true to turn the vehicle on; false to turn it off.
instantly: if true, the vehicle will be set to the state immediately; otherwise, the current driver will physically turn on or off the engine.

## SET_VEHICLE_EXCLUSIVE_DRIVER
`0xC6B9BF123B9463B6` | `void SET_VEHICLE_EXCLUSIVE_DRIVER(Vehicle vehicle, Ped ped, int index)` | build 1207
index: 0 - 1

Used to be incorrectly named _SET_VEHICLE_EXCLUSIVE_DRIVER_2

## SET_VEHICLE_EXPLODES_ON_HIGH_EXPLOSION_DAMAGE
`0xA402939C6761E1A3` | `void SET_VEHICLE_EXPLODES_ON_HIGH_EXPLOSION_DAMAGE(Vehicle vehicle, BOOL toggle)` | build 1207
Sets a vehicle to be strongly resistant to explosions. p0 is the vehicle; set p1 to false to toggle the effect on/off.

## SET_VEHICLE_EXTRA
`0xBB6F89150BC9D16B` | `void SET_VEHICLE_EXTRA(Vehicle vehicle, int extraId, BOOL disable)` | build 1207
Note: only some vehicle have extras
https://github.com/femga/rdr3_discoveries/blob/master/vehicles/vehicle_modding/vehicle_extras.lua

## SET_VEHICLE_FIXED
`0x79811282A9D1AE56` | `void SET_VEHICLE_FIXED(Vehicle vehicle)` | build 1207
This fixes a vehicle.
If the vehicle's engine's broken then you cannot fix it with this native.

## SET_VEHICLE_FORWARD_SPEED
`0xF9F92AF49F12F6E7` | `void SET_VEHICLE_FORWARD_SPEED(Vehicle vehicle, float speed)` | build 1207

## SET_VEHICLE_HANDBRAKE
`0x91BE51AEC4E99710` | `void SET_VEHICLE_HANDBRAKE(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_HAS_BEEN_OWNED_BY_PLAYER
`0xBB5A3FA8ED3979C5` | `void SET_VEHICLE_HAS_BEEN_OWNED_BY_PLAYER(Vehicle vehicle, BOOL owned)` | build 1207

## SET_VEHICLE_HAS_STRONG_AXLES
`0x252253C8A45AA1FC` | `void SET_VEHICLE_HAS_STRONG_AXLES(Vehicle vehicle, BOOL toggle)` | build 1207
if true, axles won't bend.

## SET_VEHICLE_HAS_UNBREAKABLE_LIGHTS
`0xC903855E028A05F2` | `void SET_VEHICLE_HAS_UNBREAKABLE_LIGHTS(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_INACTIVE_DURING_PLAYBACK
`0x4EA71B4C9DB3C3F1` | `void SET_VEHICLE_INACTIVE_DURING_PLAYBACK(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_INDIVIDUAL_DOORS_LOCKED
`0xA9F1D75195CC40F6` | `void SET_VEHICLE_INDIVIDUAL_DOORS_LOCKED(Vehicle vehicle, int doorId, int doorLockStatus)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT

## SET_VEHICLE_INFLUENCES_WANTED_LEVEL
`0xC1842F40FD501DA2` | `void SET_VEHICLE_INFLUENCES_WANTED_LEVEL(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_IS_CONSIDERED_BY_PLAYER
`0x54800D386C5825E5` | `void SET_VEHICLE_IS_CONSIDERED_BY_PLAYER(Vehicle vehicle, BOOL toggle)` | build 1207
Setting this to false, makes the specified vehicle to where if you press Y your character doesn't even attempt the animation to enter the vehicle. Hence it's not considered aka ignored.

## SET_VEHICLE_IS_STOLEN
`0x6C32FC81DFF25C9A` | `void SET_VEHICLE_IS_STOLEN(Vehicle vehicle, BOOL isStolen)` | build 1207

## SET_VEHICLE_KEEP_ENGINE_ON_WHEN_ABANDONED
`0x1549BA7FE83A2383` | `void SET_VEHICLE_KEEP_ENGINE_ON_WHEN_ABANDONED(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_LIGHTS
`0x629F0A0E952CAE7D` | `void SET_VEHICLE_LIGHTS(Vehicle vehicle, int state)` | build 1207
Sets the vehicle's lights state.

## SET_VEHICLE_LIMIT_SPEED_WHEN_PLAYER_INACTIVE
`0x8F75941C86EEBFCA` | `void SET_VEHICLE_LIMIT_SPEED_WHEN_PLAYER_INACTIVE(Vehicle vehicle, BOOL p1)` | build 1207
_SET_VEHICLE_LI*

## SET_VEHICLE_LOD_MULTIPLIER
`0x5F5E2B1B9EAECC0F` | `void SET_VEHICLE_LOD_MULTIPLIER(Vehicle vehicle, float multiplier)` | build 1207

## SET_VEHICLE_MAY_BE_USED_BY_GOTO_POINT_ANY_MEANS
`0x7549B9E841940695` | `void SET_VEHICLE_MAY_BE_USED_BY_GOTO_POINT_ANY_MEANS(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_NOT_STEALABLE_AMBIENTLY
`0x09C970AE59ABF6B2` | `void SET_VEHICLE_NOT_STEALABLE_AMBIENTLY(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_ON_GROUND_PROPERLY
`0x7263332501E07F52` | `BOOL SET_VEHICLE_ON_GROUND_PROPERLY(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_PETROL_TANK_HEALTH
`0x6AB2918EE3BEC94C` | `void SET_VEHICLE_PETROL_TANK_HEALTH(Vehicle vehicle, float health)` | build 1207
1000 is max health

## SET_VEHICLE_PROVIDES_COVER
`0x652712478F1721F4` | `void SET_VEHICLE_PROVIDES_COVER(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_RESPECTS_LOCKS_WHEN_HAS_DRIVER
`0x33992A808DF1C1BA` | `void SET_VEHICLE_RESPECTS_LOCKS_WHEN_HAS_DRIVER(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_SHOOT_AT_TARGET
`0xB79BE78C665B3E6D` | `void SET_VEHICLE_SHOOT_AT_TARGET(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## SET_VEHICLE_STAYS_FROZEN_WHEN_CLEANED_UP
`0x23A3AB86E0807721` | `void SET_VEHICLE_STAYS_FROZEN_WHEN_CLEANED_UP(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_STEER_BIAS
`0x84DAAE11E9EE4FC3` | `void SET_VEHICLE_STEER_BIAS(Vehicle vehicle, float value)` | build 1207
Locks the vehicle's steering to the desired angle, explained below.

Requires to be called onTick. Steering is unlocked the moment the function stops being called on the vehicle.

Steer bias:
-1.0 = full right
0.0 = centered steering
1.0 = full left

## SET_VEHICLE_STOP_INSTANTLY_WHEN_PLAYER_INACTIVE
`0xC84E138448507567` | `void SET_VEHICLE_STOP_INSTANTLY_WHEN_PLAYER_INACTIVE(Vehicle vehicle, BOOL p1)` | build 1207

## SET_VEHICLE_STRONG
`0xAB315515C9F8803D` | `void SET_VEHICLE_STRONG(Vehicle vehicle, BOOL toggle)` | build 1207
If set to true, vehicle will not take crash damage, but is still susceptible to damage from bullets and explosives

## SET_VEHICLE_TYRES_CAN_BURST
`0xEBD0A4E935106FE5` | `void SET_VEHICLE_TYRES_CAN_BURST(Vehicle vehicle, BOOL toggle)` | build 1207
Allows you to toggle bulletproof tires.

## SET_VEHICLE_UNDRIVEABLE
`0x6E884BAB713A2A94` | `void SET_VEHICLE_UNDRIVEABLE(Vehicle vehicle, BOOL toggle)` | build 1207

## SET_VEHICLE_WHEELS_CAN_BREAK
`0x839137C40275FB77` | `void SET_VEHICLE_WHEELS_CAN_BREAK(Vehicle vehicle, BOOL enabled)` | build 1207

## SET_VEHICLE_WHEELS_CAN_BREAK_OFF_WHEN_BLOW_UP
`0xC462C79379ABBCB1` | `void SET_VEHICLE_WHEELS_CAN_BREAK_OFF_WHEN_BLOW_UP(Vehicle vehicle, BOOL toggle)` | build 1207

## SKIP_TIME_IN_PLAYBACK_RECORDED_VEHICLE
`0x5F5E6379C59EFC56` | `void SKIP_TIME_IN_PLAYBACK_RECORDED_VEHICLE(Vehicle vehicle, float time)` | build 1207
SET_TIME_POSITION_IN_RECORDING can be emulated by: desired_time - GET_TIME_POSITION_IN_RECORDING(vehicle)

## START_PLAYBACK_RECORDED_VEHICLE
`0x4932B84E3276508E` | `void START_PLAYBACK_RECORDED_VEHICLE(Vehicle vehicle, int recording, char* script, BOOL p3)` | build 1207
p3 is some flag related to 'trailers' (invokes CVehicle::GetTrailer).

See REQUEST_VEHICLE_RECORDING

## START_VEHICLE_HORN
`0xB4E3BFC39CA16057` | `void START_VEHICLE_HORN(Vehicle vehicle, int duration, Hash mode, BOOL forever)` | build 1207
Sounds the horn for the specified vehicle.

vehicle: The vehicle to activate the horn for.
mode: The hash of "NORMAL" or "HELDDOWN". Can be 0.
duration: The duration to sound the horn, in milliseconds.

Note: If a player is in the vehicle, it will only sound briefly.

## STOP_BRINGING_VEHICLE_TO_HALT
`0x7C06330BFDDA182E` | `void STOP_BRINGING_VEHICLE_TO_HALT(Vehicle vehicle)` | build 1207
Old name: _STOP_BRING_VEHICLE_TO_HALT

## STOP_PLAYBACK_RECORDED_VEHICLE
`0xBF9B4D6267E8C26D` | `void STOP_PLAYBACK_RECORDED_VEHICLE(Vehicle vehicle)` | build 1207

## TRACK_VEHICLE_VISIBILITY
`0x1F3969B140DEE157` | `void TRACK_VEHICLE_VISIBILITY(Vehicle vehicle)` | build 1207

## _0x012701ED938B85DE
`0x012701ED938B85DE` | `void _0x012701ED938B85DE(float p0, float p1)` | build 1207
Only used in SP Scripts.
Related to Vehicle Speed.

## _0x0355FE37240E2C77
`0x0355FE37240E2C77` | `void _0x0355FE37240E2C77(Any p0, Any p1)` | build 1207

## _0x04F0579DBDD32F34
`0x04F0579DBDD32F34` | `void _0x04F0579DBDD32F34(Vehicle vehicle)` | build 1207
_SET_VEHICLE_*

## _0x0516FAE561276EFC
`0x0516FAE561276EFC` | `BOOL _0x0516FAE561276EFC(int trackIndex)` | build 1207
Takes value returned from 0x45853F4E17D847D5

## _0x0794199B25E499E1
`0x0794199B25E499E1` | `void _0x0794199B25E499E1(Vehicle wagon, BOOL p1)` | build 1207
_SET_VEHICLE_S*

## _0x0CD7914D17A970AB
`0x0CD7914D17A970AB` | `void _0x0CD7914D17A970AB(Any p0, Any p1)` | build 1207

## _0x0D5FDF0D36FA10CD
`0x0D5FDF0D36FA10CD` | `void _0x0D5FDF0D36FA10CD(int trackIndex)` | build 1207

## _0x0F7F603BDE08C4D3
`0x0F7F603BDE08C4D3` | `void _0x0F7F603BDE08C4D3(Any p0)` | build 1207

## _0x0FDDEE66E3465726
`0x0FDDEE66E3465726` | `Any _0x0FDDEE66E3465726(Any p0)` | build 1207

## _0x104D9A7B1C0D0783
`0x104D9A7B1C0D0783` | `void _0x104D9A7B1C0D0783(Vehicle vehicle, float p1)` | build 1207

## _0x1180A2974D251B7B
`0x1180A2974D251B7B` | `int _0x1180A2974D251B7B(Vehicle train)` | build 1207
Returns p1 for 0xBA958F68031DDBFC (stationIndex)
_GET_N* (NEAREST_STATION_FOR_TRAIN?)

## _0x12F6C6ED3EFF42DE
`0x12F6C6ED3EFF42DE` | `void _0x12F6C6ED3EFF42DE(Vehicle vehicle, float x, float y, float z)` | build 1207
Params: coords = GET_ENTITY_VELOCITY
_SET_VELOCITY*

## _0x13EB275BF81636D1
`0x13EB275BF81636D1` | `void _0x13EB275BF81636D1(Any p0, Any p1)` | build 1207

## _0x14DA8C4BC2CCD90A
`0x14DA8C4BC2CCD90A` | `Any _0x14DA8C4BC2CCD90A(Any p0)` | build 1207

## _0x15206E88FF7617DF
`0x15206E88FF7617DF` | `void _0x15206E88FF7617DF(int trackIndex, float p1)` | build 1207

## _0x15CC8C33D7FFCC4A
`0x15CC8C33D7FFCC4A` | `void _0x15CC8C33D7FFCC4A(Vehicle vehicle, int p1)` | build 1436

## _0x160C1B5AB48AB87C
`0x160C1B5AB48AB87C` | `void _0x160C1B5AB48AB87C(Vehicle train, float p1)` | build 1207

## _0x165BE2001E5E4B75
`0x165BE2001E5E4B75` | `void _0x165BE2001E5E4B75(Any p0)` | build 1207

## _0x16B86A49E072AA85
`0x16B86A49E072AA85` | `void _0x16B86A49E072AA85()` | build 1207

## _0x172E9DD35858DCD7
`0x172E9DD35858DCD7` | `void _0x172E9DD35858DCD7(Any p0)` | build 1207

## _0x1A861F899EBBE17C
`0x1A861F899EBBE17C` | `void _0x1A861F899EBBE17C(Vehicle train, BOOL p1)` | build 1207

## _0x2045429505158D1A
`0x2045429505158D1A` | `Any _0x2045429505158D1A(Any p0)` | build 1207

## _0x23F66C36F8E5EAAB
`0x23F66C36F8E5EAAB` | `void _0x23F66C36F8E5EAAB(Any p0, Any p1)` | build 1207

## _0x27E3F2B57209FA54
`0x27E3F2B57209FA54` | `void _0x27E3F2B57209FA54(Any p0, Any p1)` | build 1207

## _0x2A7413168F6CD5A8
`0x2A7413168F6CD5A8` | `void _0x2A7413168F6CD5A8()` | build 1207

## _0x2BB2B5BCF0DF8008
`0x2BB2B5BCF0DF8008` | `void _0x2BB2B5BCF0DF8008(Any p0, Any p1)` | build 1207

## _0x2C46D2A591D8C322
`0x2C46D2A591D8C322` | `Any _0x2C46D2A591D8C322(Any p0, Any p1, Any p2)` | build 1207

## _0x3053064F909B5F42
`0x3053064F909B5F42` | `void _0x3053064F909B5F42(Any p0, Any p1)` | build 1207

## _0x3137EDC899E6DAE4
`0x3137EDC899E6DAE4` | `void _0x3137EDC899E6DAE4(Any p0, Any p1)` | build 1355

## _0x331CBD247FC5DAA8
`0x331CBD247FC5DAA8` | `int _0x331CBD247FC5DAA8(Hash configHash, float x, float y, float z, BOOL direction, BOOL p5)` | build 1207
Returns trackIndex

## _0x34BCF6209B9668A7
`0x34BCF6209B9668A7` | `void _0x34BCF6209B9668A7(int trackIndex, Any p1)` | build 1207

## _0x37D238BE69F7378A
`0x37D238BE69F7378A` | `BOOL _0x37D238BE69F7378A(int trackIndex)` | build 1207

## _0x38E7DD70A242D5CB
`0x38E7DD70A242D5CB` | `void _0x38E7DD70A242D5CB(int trackIndex, int p1)` | build 1207

## _0x3ABFA128F5BF5A70
`0x3ABFA128F5BF5A70` | `void _0x3ABFA128F5BF5A70(Hash trainTrack, int junctionIndex, BOOL enabled)` | build 1207
Called together with 0xE6C5E2125EB210C1 in R* Script medium_update

## _0x3D86997A86FEEF0D
`0x3D86997A86FEEF0D` | `void _0x3D86997A86FEEF0D(Any p0, Any p1)` | build 1207

## _0x41365DB586CD9E8E
`0x41365DB586CD9E8E` | `void _0x41365DB586CD9E8E(int trackIndex, float p1)` | build 1207

## _0x41F0B254DDF71473
`0x41F0B254DDF71473` | `void _0x41F0B254DDF71473(Vehicle wagon)` | build 1207
_H*

## _0x427C919E9809E370
`0x427C919E9809E370` | `void _0x427C919E9809E370(int trackIndex, int p1)` | build 1207

## _0x485B05EF05B9AEE9
`0x485B05EF05B9AEE9` | `void _0x485B05EF05B9AEE9(Any p0, Any p1)` | build 1207

## _0x4C05B42A8D937796
`0x4C05B42A8D937796` | `void _0x4C05B42A8D937796()` | build 1207

## _0x4C60C333F9CCA2B6
`0x4C60C333F9CCA2B6` | `void _0x4C60C333F9CCA2B6(Vehicle vehicle, BOOL p1)` | build 1207
Params: p1 usually true in R* Scripts
_SET_DRAFT_VEHICLE_*

## _0x5AADC7BBBB1BCEEB
`0x5AADC7BBBB1BCEEB` | `void _0x5AADC7BBBB1BCEEB(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x615B3B8E73634509
`0x615B3B8E73634509` | `void _0x615B3B8E73634509(int trackIndex, float p1)` | build 1207

## _0x63509DDF102E08E8
`0x63509DDF102E08E8` | `void _0x63509DDF102E08E8(int trackIndex, int p1)` | build 1207

## _0x6355602C02EDC6DF
`0x6355602C02EDC6DF` | `void _0x6355602C02EDC6DF(Entity entity, Any p1)` | build 1207
Only used in R* Script beat_train_holdup: p1 = 1

## _0x6703872EC09BC158
`0x6703872EC09BC158` | `void _0x6703872EC09BC158(Any p0, Any p1)` | build 1207

## _0x68830738A6BFB370
`0x68830738A6BFB370` | `void _0x68830738A6BFB370(Any p0, Any p1)` | build 1207

## _0x697DF68F3A761A50
`0x697DF68F3A761A50` | `void _0x697DF68F3A761A50(Any p0)` | build 1207

## _0x6B34BE961F639E21
`0x6B34BE961F639E21` | `void _0x6B34BE961F639E21(int trackIndex, int p1)` | build 1207

## _0x6B53F4B811E583D2
`0x6B53F4B811E583D2` | `void _0x6B53F4B811E583D2(Vehicle vehicle, BOOL toggle)` | build 1207

## _0x6C87F49BFA181DB5
`0x6C87F49BFA181DB5` | `int _0x6C87F49BFA181DB5(float x, float y, float z)` | build 1207
Returns trackIndex

## _0x6DE072AC8A95FFC1
`0x6DE072AC8A95FFC1` | `void _0x6DE072AC8A95FFC1(Vehicle vehicle, BOOL p1)` | build 1207
_SET_INSTANTLY_* - _SET_MISSION_TRAIN*

## _0x6EA1273D525427F4
`0x6EA1273D525427F4` | `void _0x6EA1273D525427F4(Any p0, Any p1, Any p2)` | build 1207

## _0x6FD7BDF10304363A
`0x6FD7BDF10304363A` | `void _0x6FD7BDF10304363A(Any p0, Any p1)` | build 1207

## _0x703D4FB366DA4452
`0x703D4FB366DA4452` | `void _0x703D4FB366DA4452(Any p0, Any p1)` | build 1207

## _0x718EB706B6E998A0
`0x718EB706B6E998A0` | `void _0x718EB706B6E998A0(int trackIndex)` | build 1207

## _0x73118A3EE9C9B6DB
`0x73118A3EE9C9B6DB` | `void _0x73118A3EE9C9B6DB(Vehicle wagon, int p1, BOOL p2)` | build 1207
_SET_VEHICLE_WHEELS_*

## _0x7408B5C66BA31ADB
`0x7408B5C66BA31ADB` | `void _0x7408B5C66BA31ADB(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10)` | build 1207

## _0x750D42C013F64AE7
`0x750D42C013F64AE7` | `void _0x750D42C013F64AE7(Any p0, Any p1)` | build 1207

## _0x762FDC4C19E5A981
`0x762FDC4C19E5A981` | `void _0x762FDC4C19E5A981(Entity trainCarriage, BOOL p1)` | build 1207
Seems to be related while setting a (door) state of specific trains (midlandboxcar05x, privateboxcar01x, privateboxcar02x, midlandrefrigeratorCar, privateArmoured, armoredCar01x)

## _0x7840576C50A13DBA
`0x7840576C50A13DBA` | `void _0x7840576C50A13DBA(Vehicle train, BOOL p1)` | build 1207

## _0x7BE0746539DEF0C8
`0x7BE0746539DEF0C8` | `Any _0x7BE0746539DEF0C8(Any p0, Any p1)` | build 1207

## _0x8379E05871AD24E0
`0x8379E05871AD24E0` | `void _0x8379E05871AD24E0()` | build 1207

## _0x850CE59DEC2028F3
`0x850CE59DEC2028F3` | `void _0x850CE59DEC2028F3(Vehicle vehicle, Any p1)` | build 1207

## _0x873AAF600CC36DAC
`0x873AAF600CC36DAC` | `void _0x873AAF600CC36DAC(Any p0)` | build 1207

## _0x87B974E54C71BA7B
`0x87B974E54C71BA7B` | `void _0x87B974E54C71BA7B(Vehicle vehicle, BOOL p1)` | build 1207

## _0x8878FF3EEE2868A9
`0x8878FF3EEE2868A9` | `void _0x8878FF3EEE2868A9(Any p0, Any p1)` | build 1207

## _0x8DECD262602548B9
`0x8DECD262602548B9` | `void _0x8DECD262602548B9(Any p0, Any p1)` | build 1207

## _0x9868C0D0134855F7
`0x9868C0D0134855F7` | `void _0x9868C0D0134855F7(Any p0)` | build 1207
nullsub, doesn't do anything

## _0x98A7598C579EE871
`0x98A7598C579EE871` | `void _0x98A7598C579EE871(Any p0, Any p1, Any p2)` | build 1207

## _0x9E8711C81AA17876
`0x9E8711C81AA17876` | `void _0x9E8711C81AA17876(Vehicle vehicle, BOOL p1)` | build 1207
Forcing high LOD buoyancy for vehicle: p1 = false
_SET_A*

## _0xA230A5DDE12ED374
`0xA230A5DDE12ED374` | `void _0xA230A5DDE12ED374(Any p0)` | build 1207

## _0xA72B1BF3857B94D7
`0xA72B1BF3857B94D7` | `void _0xA72B1BF3857B94D7(Vehicle train, BOOL p1)` | build 1207

## _0xA7966807953A18EE
`0xA7966807953A18EE` | `void _0xA7966807953A18EE(int trackIndex, float p1)` | build 1207

## _0xA9E185D498B9AC67
`0xA9E185D498B9AC67` | `Any _0xA9E185D498B9AC67(Any p0, Any p1)` | build 1207

## _0xAE7E66A61E7C17A5
`0xAE7E66A61E7C17A5` | `void _0xAE7E66A61E7C17A5(Vehicle train, BOOL p1)` | build 1207
_SET_TRAIN_*

## _0xB4241AD8F5AEE9ED
`0xB4241AD8F5AEE9ED` | `BOOL _0xB4241AD8F5AEE9ED(int trackIndex)` | build 1207

## _0xB961DD799A837BD7
`0xB961DD799A837BD7` | `void _0xB961DD799A837BD7()` | build 1207

## _0xC325A6BAA62CF8A2
`0xC325A6BAA62CF8A2` | `void _0xC325A6BAA62CF8A2(Vehicle vehicle, BOOL p1)` | build 1207
Used in Script Function MC_LOCAL_SETUP_VEH - enabling transitions

## _0xC351394B932A6A50
`0xC351394B932A6A50` | `void _0xC351394B932A6A50(Any p0)` | build 1207

## _0xC399CC89FBA05DA0
`0xC399CC89FBA05DA0` | `void _0xC399CC89FBA05DA0(Vehicle vehicle, BOOL p1)` | build 1207

## _0xC4A2C11FC0D41916
`0xC4A2C11FC0D41916` | `void _0xC4A2C11FC0D41916(Vehicle vehicle, BOOL p1)` | build 1207
_SET_DRAFT_VEHICLE_(STOP?)*

## _0xCACAB2B123BBDBD6
`0xCACAB2B123BBDBD6` | `Any _0xCACAB2B123BBDBD6(Any p0, Any p1, Any p2)` | build 1207

## _0xCAFF2C9747103C02
`0xCAFF2C9747103C02` | `Any _0xCAFF2C9747103C02(Any p0, Any p1, Any p2)` | build 1207

## _0xCBC7B6F9A56B79F6
`0xCBC7B6F9A56B79F6` | `void _0xCBC7B6F9A56B79F6(Any p0, Any p1)` | build 1207

## _0xCBF88256E44D5D39
`0xCBF88256E44D5D39` | `void _0xCBF88256E44D5D39(Vehicle vehicle, BOOL p1)` | build 1207
Used in Script Function MC_LOCAL_SETUP_VEH - enabling transitions

## _0xCEB1F1EED484A5B4
`0xCEB1F1EED484A5B4` | `void _0xCEB1F1EED484A5B4(Any p0, Any p1)` | build 1207

## _0xCF342503CA4C8DF1
`0xCF342503CA4C8DF1` | `void _0xCF342503CA4C8DF1(Vehicle vehicle, float p1)` | build 1207

## _0xD0116DF21E6C7B36
`0xD0116DF21E6C7B36` | `Any _0xD0116DF21E6C7B36(Any p0, Any p1)` | build 1207

## _0xD0AABE5B9F8FA589
`0xD0AABE5B9F8FA589` | `void _0xD0AABE5B9F8FA589(int trackIndex, float p1)` | build 1207

## _0xD0BA1853D76683C8
`0xD0BA1853D76683C8` | `void _0xD0BA1853D76683C8(int trackIndex, float x, float y, float z, Any p4)` | build 1207

## _0xD1DF5E54F4ACBE1A
`0xD1DF5E54F4ACBE1A` | `Any _0xD1DF5E54F4ACBE1A(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0xD21A3D421E7F09F7
`0xD21A3D421E7F09F7` | `void _0xD21A3D421E7F09F7(Any p0, Any p1)` | build 1207

## _0xD4907EF4334C7602
`0xD4907EF4334C7602` | `void _0xD4907EF4334C7602(Any p0, Any p1)` | build 1207

## _0xD826690B5CF3BEFF
`0xD826690B5CF3BEFF` | `void _0xD826690B5CF3BEFF(Vehicle vehicle, Any p1)` | build 1207

## _0xD9BF3ED8EFB67EA3
`0xD9BF3ED8EFB67EA3` | `Any _0xD9BF3ED8EFB67EA3(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xDC0556D0F484ECAA
`0xDC0556D0F484ECAA` | `void _0xDC0556D0F484ECAA(Any p0)` | build 1207

## _0xDC69F6913CCA0B99
`0xDC69F6913CCA0B99` | `void _0xDC69F6913CCA0B99(Any p0, Any p1)` | build 1207

## _0xDD100CE1EBBF37E3
`0xDD100CE1EBBF37E3` | `void _0xDD100CE1EBBF37E3(Any p0, Any p1)` | build 1207

## _0xDE8C5B9F65017FA1
`0xDE8C5B9F65017FA1` | `Any _0xDE8C5B9F65017FA1(Vehicle train)` | build 1207

## _0xE12F5ED49F44D40D
`0xE12F5ED49F44D40D` | `void _0xE12F5ED49F44D40D(Any p0)` | build 1207

## _0xE1C0F8781BF130C2
`0xE1C0F8781BF130C2` | `BOOL _0xE1C0F8781BF130C2(Vehicle wagon, int p1)` | build 1207
Only used in R* SP Script rcm_abigail31: p1 = 5
_GET_VEHICLE_T* - _GET_VO*

## _0xE682002DB1F30669
`0xE682002DB1F30669` | `void _0xE682002DB1F30669(Any p0)` | build 1207

## _0xE777DDF3E78397E8
`0xE777DDF3E78397E8` | `Any _0xE777DDF3E78397E8(Any p0)` | build 1207

## _0xE78993FF9022C064
`0xE78993FF9022C064` | `void _0xE78993FF9022C064(Any p0)` | build 1207

## _0xEF28A614B4B264B8
`0xEF28A614B4B264B8` | `void _0xEF28A614B4B264B8(Vehicle train, BOOL p1)` | build 1207
_SET_TRAIN_*

## _0xF57DB8E83DCD8349
`0xF57DB8E83DCD8349` | `Any _0xF57DB8E83DCD8349(Any p0)` | build 1207

## _0xF5EA41C1408695FB
`0xF5EA41C1408695FB` | `Any _0xF5EA41C1408695FB(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xF8F7DA13CFBD4532
`0xF8F7DA13CFBD4532` | `void _0xF8F7DA13CFBD4532(int trackIndex, BOOL p1)` | build 1207

## _0xFC4F15A7DDDC47B1
`0xFC4F15A7DDDC47B1` | `void _0xFC4F15A7DDDC47B1(Vehicle vehicle, BOOL p1)` | build 1207
_SET_DRAFT_VEHICLE_*

## _0xFF2B1F59FB892F14
`0xFF2B1F59FB892F14` | `void _0xFF2B1F59FB892F14(Any p0)` | build 1207

## _0xFFFE15B433300B8C
`0xFFFE15B433300B8C` | `void _0xFFFE15B433300B8C(Any p0, Any p1, Any p2)` | build 1207

## _ADD_TRAIN_TEMPORARY_STOP
`0x41503629D1139ABC` | `void _ADD_TRAIN_TEMPORARY_STOP(Vehicle train, int trackIndex, float x, float y, float z)` | build 1207

## _ARE_ANY_VEHICLE_WHEELS_DESTROYED
`0x18714953CCED17D3` | `BOOL _ARE_ANY_VEHICLE_WHEELS_DESTROYED(Vehicle vehicle)` | build 1207
returns true if any wheel is destroyed/detached

## _ATTACH_DRAFT_VEHICLE_HARNESS_PED
`0x316CDB5B6E8F4110` | `BOOL _ATTACH_DRAFT_VEHICLE_HARNESS_PED(Ped mount, Vehicle draft, int harnessId)` | build 1207

## _BREAK_OFF_DRAFT_WHEEL
`0xC372B6A88F6E4AD8` | `void _BREAK_OFF_DRAFT_WHEEL(Vehicle vehicle, int wheelIndex, float destroyingForce)` | build 1207
Params: destroyingForce is usually 100f in R* Scripts
Similar to 0xD4F5EFB55769D272, _A*

## _BREAK_OFF_VEHICLE_PADLOCK
`0x9D12796EF4BF9EA9` | `void _BREAK_OFF_VEHICLE_PADLOCK(Vehicle vehicle)` | build 1207
Breaks off the padlock of a vehicle if the vehicle contains the closed compartment to be looted

## _BREAK_OFF_VEHICLE_WHEEL
`0xD4F5EFB55769D272` | `Entity _BREAK_OFF_VEHICLE_WHEEL(Vehicle vehicle, int wheelIndex)` | build 1207
wheelIndex 0: left, wheelIndex 1: right, 4 & 5: unknown

## _BREAK_VEHICLE_STRAPS
`0xD1EFA8D68BF5D63D` | `void _BREAK_VEHICLE_STRAPS(Vehicle vehicle, float x, float y, float z)` | build 1207
Only used to break draft vehicle log straps. Coords is always equal to the vehicle coords.

## _CREATE_DRAFT_VEHICLE
`0x214651FB1DFEBA89` | `Vehicle _CREATE_DRAFT_VEHICLE(Hash modelHash, float x, float y, float z, float heading, BOOL isNetwork, BOOL bScriptHostVeh, BOOL bDontAutoCreateDraftAnimals, Hash draftAnimalPopGroup, BOOL p9)` | build 1207
Identical to CREATE_VEHICLE but allows to set draftAnimalPopGroup (see popgroups.#mt for DRAFT_HORSES_*)

## _CREATE_MISSION_TRAIN
`0xC239DBD9A57D2A71` | `Vehicle _CREATE_MISSION_TRAIN(Hash configHash, float x, float y, float z, BOOL direction, BOOL passengers, BOOL p6, BOOL conductor)` | build 1207
configHash: https://alloc8or.re/rdr3/doc/enums/eTrainConfig.txt
For more information, see trainconfigs.ymt
To make the train AI controlled, set conductor to true and set the speed once.

## _DELETE_VEHICLE_LANTERNS
`0xE1A83D4A3B5D7938` | `BOOL _DELETE_VEHICLE_LANTERNS(Vehicle vehicle)` | build 1207
Spawn without lanterns set

## _DETACH_DRAFT_VEHICLE_HARNESS_FROM_INDEX
`0x4402960666000E62` | `BOOL _DETACH_DRAFT_VEHICLE_HARNESS_FROM_INDEX(Vehicle draft, int harnessId)` | build 1207

## _DETACH_DRAFT_VEHICLE_HARNESS_PED
`0xB36D3EC70963BE60` | `BOOL _DETACH_DRAFT_VEHICLE_HARNESS_PED(Vehicle draft, Ped ped)` | build 1207

## _DETACH_WAGON_ENTITY_FROM_TRAIN
`0x54CBDD6E1B4CB4DF` | `void _DETACH_WAGON_ENTITY_FROM_TRAIN(Entity entity)` | build 1207
Only used in train_robbery4 R* Script
_C* - _DEL*

## _DETERMINE_VEHICLE_COMPARTMENT_STATE
`0x877EA24EB1614495` | `BOOL _DETERMINE_VEHICLE_COMPARTMENT_STATE(Any* outState, Vehicle vehicle, Ped ped)` | build 1207
Determines the interaction/storage state of a vehicle rear compartment or storage area.
Returns whether the query was successful and writes a state value to outState
Observed states:
* 1  = Compartment available / unopened
* 57 = Vehicle has no valid compartment/storage
* 72 = Compartment opened, resolved or depleted

## _DOES_TRAIN_EXIST_ON_TRACK
`0xC29996A337BDD099` | `BOOL _DOES_TRAIN_EXIST_ON_TRACK(int trackIndex)` | build 1207

## _FADE_AND_DESTROY_VEHICLE
`0x35DC1877312FBA0F` | `void _FADE_AND_DESTROY_VEHICLE(Vehicle* vehicle)` | build 1207

## _GET_ALL_TRAIN_WAGON_PASSENGERS
`0x0E558D3A49D759D6` | `int _GET_ALL_TRAIN_WAGON_PASSENGERS(Vehicle train, ItemSet itemset)` | build 1207
Collects all passenger peds (excluding the driver) from the specified wagon-type vehicle and adds them as indexed items to the provided itemset.
Notes:
- Always clear the itemset before calling.
- Returns 0 if the wagon is empty or auto-population is disabled
  (ENTITY::_0x119A5714578F4E05(wagon, false)).
- Itemset may contain dead peds; filter with IS_ENTITY_DEAD if needed.
- Often used alongside wagon auto-population management.

## _GET_BALLOON_OBJECT_FROM_VEHICLE
`0x0BA4250D20007C2E` | `Entity _GET_BALLOON_OBJECT_FROM_VEHICLE(Vehicle vehicle)` | build 1207
Returns the balloon object attached to a hot air balloon vehicle. 

If the input vehicle is a hot air balloon, the native returns the object entity
that represents the balloon itself (the inflated top part). 
If the vehicle is not balloon-type or the balloon object does not exist,the function returns 0. 
Always validate the returned handle with ENTITY::DOES_ENTITY_EXIST.
Notes:
- Only useful for hot air balloon vehicles.
- The returned handle is typically an OBJECT, not a PED or VEHICLE.

## _GET_BREAKABLE_VEHICLE_LOCKS_STATE
`0xE015CF1F2C0959D8` | `int _GET_BREAKABLE_VEHICLE_LOCKS_STATE(Vehicle vehicle)` | build 1207

## _GET_BREAKABLE_VEHICLE_LOCK_OBJECT
`0x58F2244C1286D09A` | `Object _GET_BREAKABLE_VEHICLE_LOCK_OBJECT(Vehicle vehicle, int index)` | build 1207

## _GET_CHECKPOINT_TRAIN_SPAWN_LOCATION
`0x35D302397E524939` | `Vector3 _GET_CHECKPOINT_TRAIN_SPAWN_LOCATION(int trackIndex, float x, float y, float z, float distance, BOOL direction)` | build 1207

## _GET_CURRENT_TRACK_FOR_TRAIN
`0xAF787E081AC4A8EE` | `int _GET_CURRENT_TRACK_FOR_TRAIN(Vehicle train)` | build 1207
Returns p0 for 0xBA958F68031DDBFC (trackIndex)

## _GET_DRAFT_VEHICLE_DESIRED_SPEED
`0xC6D7DDC843176701` | `float _GET_DRAFT_VEHICLE_DESIRED_SPEED(Vehicle vehicle)` | build 1207
Returns rage::NumericLimits<float>::kMax (3.402823466e+38) if vehicle is not a valid vehicle of type VEHICLE_TYPE_DRAFT.

## _GET_JUNCTION_COORDS_FOR_TRAIN_TRACK
`0x785639D89F8451AB` | `Vector3 _GET_JUNCTION_COORDS_FOR_TRAIN_TRACK(Hash trainTrack, int junctionIndex)` | build 1207
Returns the world coordinates of a junction node for the given train track configuration. trainTrack: see _RETURN_TRAIN_INFO_FROM_HANDLE.

## _GET_NEAREST_TRAIN_TRACK_POSITION
`0x6DE03BCC15E81710` | `Vector3 _GET_NEAREST_TRAIN_TRACK_POSITION(float x, float y, float z)` | build 1207

## _GET_NUM_BREAKABLE_VEHICLE_LOCK_OBJECTS
`0x2FA86833E3617E2D` | `int _GET_NUM_BREAKABLE_VEHICLE_LOCK_OBJECTS(Vehicle vehicle)` | build 1207

## _GET_NUM_CARS_FROM_TRAIN_CONFIG
`0x635423D55CA84FC8` | `int _GET_NUM_CARS_FROM_TRAIN_CONFIG(Hash trainConfig)` | build 1207
Returns amount for CAN_REGISTER_MISSION_VEHICLES

## _GET_NUM_DRAFT_VEHICLE_HARNESS_PED
`0x5B1A26BB18E7D451` | `int _GET_NUM_DRAFT_VEHICLE_HARNESS_PED(Hash modelHash)` | build 1207
Returns number of horses a wagon can have

## _GET_NUM_DRAFT_VEHICLE_LOGS
`0x288CBB414C3C2FBB` | `int _GET_NUM_DRAFT_VEHICLE_LOGS(Vehicle vehicle)` | build 1207
Return the number of logs on a draft vehicle.

## _GET_NUM_DRAFT_VEHICLE_STRAPS
`0x1121B07088ED3013` | `int _GET_NUM_DRAFT_VEHICLE_STRAPS(Vehicle vehicle)` | build 1207
Return the number of straps that hold the logs of a draft vehicle.

## _GET_PED_IN_DRAFT_HARNESS
`0xA8BA0BAE0173457B` | `Ped _GET_PED_IN_DRAFT_HARNESS(Vehicle vehicle, int harnessId)` | build 1207
enum eDraftHarness
{
	DRAFT_HARNESS_LR,
	DRAFT_HARNESS_RR,
	DRAFT_HARNESS_LM,
	DRAFT_HARNESS_RM,
	DRAFT_HARNESS_LF,
	DRAFT_HARNESS_RF,
	DRAFT_HARNESS_COUNT
};

## _GET_ROWING_OARS
`0xA6E210FB4283B767` | `void _GET_ROWING_OARS(Vehicle vehicle, Entity* left, Entity* right)` | build 1207
Returns handles of boat paddles entities.

## _GET_STATION_COORDS_FROM_TRAIN_STATION_DATA
`0xBA958F68031DDBFC` | `Vector3 _GET_STATION_COORDS_FROM_TRAIN_STATION_DATA(int trackIndex, int stationIndex)` | build 1207
Returns Coords of vStation
p0 - NET_TRAIN_MANAGER_GET_TRAIN_STATION_DATA
_GET_P* - _GET_T*

## _GET_STATION_FROM_TRAIN_STATION_INDEX
`0x9CC94A948EAF5372` | `Hash _GET_STATION_FROM_TRAIN_STATION_INDEX(int trackIndex, int stationIndex)` | build 1207
Returns the station hash for a track and station index.
- trackIndex: int — From 0 to 24
- stationIndex: int — From 0 to 7

## _GET_TRACK_AMOUNT_OF_VISIBLE_PIXELS
`0x13C190302369308B` | `int _GET_TRACK_AMOUNT_OF_VISIBLE_PIXELS(Vehicle vehicle)` | build 1207
Requires a visibility tracker on the vehicle (TRACK_VEHICLE_VISIBILITY)

## _GET_TRACK_INDEX_FROM_COORDS
`0x85D39F5E3B6D7EB0` | `int _GET_TRACK_INDEX_FROM_COORDS(float x, float y, float z)` | build 1207
Returns trackIndex
_E* - _F*

## _GET_TRAIN_CAR
`0x671A07C9A1CD50A5` | `Entity _GET_TRAIN_CAR(Vehicle train)` | build 1207
Returns train car, use GET_TRAIN_CARRIAGE when trailerNumber is bigger than 0

## _GET_TRAIN_CARRIAGE_TRAILER_NUMBER
`0x60B7D1DCC312697D` | `int _GET_TRAIN_CARRIAGE_TRAILER_NUMBER(Vehicle train)` | build 1207
Returns iNumCars - to be used with GET_TRAIN_CARRIAGE (trailerNumber)
_C* (O, P, Q, R)

## _GET_TRAIN_DIRECTION
`0x3C9628A811CBD724` | `BOOL _GET_TRAIN_DIRECTION(Vehicle train)` | build 1207

## _GET_TRAIN_DIRECTION_FROM_INDEX
`0x67995318F5FAA496` | `BOOL _GET_TRAIN_DIRECTION_FROM_INDEX(int trackIndex)` | build 1207
https://i.imgur.com/1rHibjW.jpg

## _GET_TRAIN_MODEL_FROM_TRAIN_CONFIG_BY_CAR_INDEX
`0x8DF5F6A19F99F0D5` | `Hash _GET_TRAIN_MODEL_FROM_TRAIN_CONFIG_BY_CAR_INDEX(Hash trainConfig, int trainCarIndex)` | build 1207
Returns modelHash

## _GET_TRAIN_POSITION_ON_TRACK
`0x1E8A921112891651` | `Vector3 _GET_TRAIN_POSITION_ON_TRACK(int trackIndex)` | build 1207

## _GET_TRAIN_TRACK_FROM_TRAIN_VEHICLE
`0x45853F4E17D847D5` | `int _GET_TRAIN_TRACK_FROM_TRAIN_VEHICLE(Vehicle train)` | build 1207
Returns trackIndex

## _GET_TRAIN_TRACK_JUNCTION_AT_COORDS
`0x86AFC343CF7F0B34` | `BOOL _GET_TRAIN_TRACK_JUNCTION_AT_COORDS(Hash trainTrack, float x, float y, float z, int* junctionIndex)` | build 1207
Outputs junctionIndex, to be used with 0xE6C5E2125EB210C1

## _GET_TRAIN_VEHICLE_FROM_TRACK_INDEX
`0x6E585A616ABB8401` | `Vehicle _GET_TRAIN_VEHICLE_FROM_TRACK_INDEX(int trackIndex)` | build 1207
Returns train

## _GET_VEHICLE_DOORS_LOCKED_FOR_TEAM
`0xDD1E1393D966D39A` | `BOOL _GET_VEHICLE_DOORS_LOCKED_FOR_TEAM(Vehicle vehicle, int team)` | build 1207

## _GET_VEHICLE_IS_PROP_SET_APPLIED
`0xD798DF5DB67B1659` | `BOOL _GET_VEHICLE_IS_PROP_SET_APPLIED(Vehicle vehicle)` | build 1207

## _GET_VEHICLE_LIVERY
`0xBB765B8FD49A796C` | `int _GET_VEHICLE_LIVERY(Vehicle vehicle)` | build 1207

## _GET_VEHICLE_OWNER
`0xB729679356A889AE` | `Entity _GET_VEHICLE_OWNER(Vehicle vehicle)` | build 1207

## _GET_VEHICLE_TINT
`0xA44D65E6C624526F` | `int _GET_VEHICLE_TINT(Vehicle vehicle)` | build 1207

## _GET_VEHICLE_TURRET_SEAT
`0xFF5791B7639C2A46` | `BOOL _GET_VEHICLE_TURRET_SEAT(Vehicle vehicle, int* seatIndex)` | build 1207

## _HAS_TRAIN_LOADED
`0xBD3C4A2ED509205E` | `BOOL _HAS_TRAIN_LOADED(Vehicle train)` | build 1207

## _HIDE_HORSE_REINS
`0x201B8ED4FF7FE9F5` | `void _HIDE_HORSE_REINS(Vehicle vehicle)` | build 1207

## _IS_BOAT_GROUNDED
`0x30D86B2B7622D0EB` | `BOOL _IS_BOAT_GROUNDED(Vehicle vehicle)` | build 1207

## _IS_PED_EXCLUSIVE_DRIVER_OF_VEHICLE
`0xB213D2A560B2E48B` | `BOOL _IS_PED_EXCLUSIVE_DRIVER_OF_VEHICLE(Ped ped, Vehicle vehicle, int* outIndex)` | build 1207

## _IS_SPAWN_POSITION_VALID_FOR_TRAIN
`0xF05DFAF1ADFEF2CD` | `BOOL _IS_SPAWN_POSITION_VALID_FOR_TRAIN(Hash trainConfig, float x, float y, float z, BOOL direction, BOOL p5)` | build 1207
Return true if the specified train can be spawned at the location (automatically snap to the nearest track from coords) with the direction.

## _IS_THIS_MODEL_A_DRAFT_VEHICLE
`0xB9D5BDDA88E1BB66` | `BOOL _IS_THIS_MODEL_A_DRAFT_VEHICLE(Hash model)` | build 1207

## _IS_VEHICLE_BROUGHT_TO_HALT
`0x404527BC03DA0E6C` | `BOOL _IS_VEHICLE_BROUGHT_TO_HALT(Vehicle vehicle)` | build 1207
Only returns true if BRING_VEHICLE_TO_HALT is called on vehicle beforehand

## _IS_VEHICLE_COLLIDING_WITH_VEGETATION
`0x51C7694E140FAE43` | `BOOL _IS_VEHICLE_COLLIDING_WITH_VEGETATION(Vehicle vehicle)` | build 1207
true if the vehicle is colliding with vegetation/bushes, false if it is in the clear.

## _IS_VEHICLE_DOOR_BROKEN
`0xE979BB5602AD3402` | `BOOL _IS_VEHICLE_DOOR_BROKEN(Vehicle vehicle, int doorId)` | build 1207
doorId: see SET_VEHICLE_DOOR_SHUT

## _IS_VEHICLE_FADING_OUT
`0x5136B284B67B35C7` | `BOOL _IS_VEHICLE_FADING_OUT(Vehicle vehicle)` | build 1207

## _IS_VEHICLE_ON_FIRE
`0x0E3BF7ED4169EC43` | `BOOL _IS_VEHICLE_ON_FIRE(Vehicle vehicle)` | build 1207

## _IS_VEHICLE_WHEEL_DESTROYED
`0xCB2CA620C48BC875` | `BOOL _IS_VEHICLE_WHEEL_DESTROYED(Vehicle vehicle, int wheel)` | build 1207

## _RECOVER_DRAFT_VEHICLE_FALLING_LOG
`0x42404D57D621601A` | `Any _RECOVER_DRAFT_VEHICLE_FALLING_LOG(Vehicle vehicle)` | build 1207
Returns the log prop entity that is currently detaching/falling from a draft (log) wagon. Returns 0 if no log is in the falling phase. R* scripts call this repeatedly to fetch each fallen piece, then apply forces to it.

## _REQUEST_VEHICLE_ASSET_ANIMS
`0xCF9DA72002FC16BF` | `void _REQUEST_VEHICLE_ASSET_ANIMS(Ped ped, Entity entity, int vehicleAsset)` | build 1207

## _RETURN_TRAIN_INFO_FROM_HANDLE
`0x09034479E6E3E269` | `BOOL _RETURN_TRAIN_INFO_FROM_HANDLE(Vehicle train, Hash* trainTrack, int* junctionIndex)` | build 1207
Outputs track hash and junction index on given train vehicle handle.
_RESET_VEHICLE_* (?)
```lua
local trainTrack, junctionIndex = Citizen.InvokeNative(0x09034479E6E3E269, train, Citizen.PointerValueInt(), Citizen.PointerValueInt())
```

## _SET_ALL_JUNCTIONS_CLEARED
`0x138398153824E332` | `void _SET_ALL_JUNCTIONS_CLEARED()` | build 1207

## _SET_ALL_VEHICLE_GENERATORS_DISABLED_FOR_VOLUME
`0x424FFCB9F0D2D4B5` | `void _SET_ALL_VEHICLE_GENERATORS_DISABLED_FOR_VOLUME(Volume volume, BOOL toggle)` | build 1207

## _SET_BALLOON_FACE_DIRECTION_THIS_FRAME
`0xB42C87521D1BDD2F` | `void _SET_BALLOON_FACE_DIRECTION_THIS_FRAME(Vehicle vehicle, float x, float y, float z)` | build 1207
Makes the balloon face the specified direction to fly towards it must be called every frame until it reaches destination

## _SET_BALLOON_HOVER_STATE
`0x7C9E45A4CED2E8DA` | `void _SET_BALLOON_HOVER_STATE(Vehicle balloon, float p1)` | build 1207
Params: 1.0f will make balloon hover

## _SET_BALLOON_ROUTE
`0x2200AB13CBD10F4E` | `void _SET_BALLOON_ROUTE(Vehicle vehicle, float x, float y, float z, BOOL autoDrive, float speedMultiplier)` | build 1207
Makes the balloon go to the specified coordinates must be called every frame until it reaches destination if autoDrive is false,other wise player must drive it manually

## _SET_BATCH_TARP_HEIGHT
`0x31F343383F19C987` | `void _SET_BATCH_TARP_HEIGHT(Vehicle vehicle, float height, BOOL immediately)` | build 1207
Total height is calculated using: cargo ratio + pelt ratio (by pelt count)
Screenshot: https://imgur.com/a/nsomtiv

## _SET_DRAFT_ANIMAL_RANDOM_SEED
`0x8C6D9A399126C194` | `void _SET_DRAFT_ANIMAL_RANDOM_SEED(Vehicle vehicle, int seed)` | build 1207

## _SET_DRAFT_VEHICLE_ALLOW_DRAFT_ANIMAL_AUTO_CREATION
`0x87344305778E5415` | `void _SET_DRAFT_VEHICLE_ALLOW_DRAFT_ANIMAL_AUTO_CREATION(Vehicle vehicle, BOOL allow)` | build 1207

## _SET_DRAFT_VEHICLE_ANIMALS_CAN_DETACH
`0x6090A031C69F384E` | `void _SET_DRAFT_VEHICLE_ANIMALS_CAN_DETACH(Vehicle draft, BOOL canDetach)` | build 1207

## _SET_DRAFT_VEHICLE_DESIRED_SPEED
`0x0C3F0F7F92CA847C` | `void _SET_DRAFT_VEHICLE_DESIRED_SPEED(Vehicle vehicle, float speed)` | build 1207

## _SET_DRAFT_VEHICLE_YOKE_CAN_BREAK
`0x226C6A4E3346D288` | `void _SET_DRAFT_VEHICLE_YOKE_CAN_BREAK(Vehicle draft, BOOL canBreak)` | build 1207

## _SET_FORCE_COACH_ROBBERY_LOOT
`0xF489F94BFEE12BB0` | `void _SET_FORCE_COACH_ROBBERY_LOOT(Vehicle vehicle, Hash coachrobberyLoot)` | build 1207
Hashes: COACH2_BOOT_LOOT_ITEMS_COACHROB_RSC, COACH2_BOOT_LOOT_ITEMS_COACHROB, COACH2_MARY3

## _SET_FORCE_HIGH_LOD_VEHICLE
`0x1098CDA477890165` | `void _SET_FORCE_HIGH_LOD_VEHICLE(Vehicle vehicle, BOOL p1)` | build 1207

## _SET_HORSE_TRAFFIC_GROUPING_DISTRIBUTION
`0xF5FFB08976911B50` | `void _SET_HORSE_TRAFFIC_GROUPING_DISTRIBUTION(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _SET_MISSION_TRAIN_WARP_TO_COORDS
`0xC9EA26893C9E4024` | `void _SET_MISSION_TRAIN_WARP_TO_COORDS(Vehicle train, float x, float y, float z, BOOL direction)` | build 1207
Notice: BOOL p4 was wrongly named takePassengers (?)
Can be used to rotate the train by setting the BOOL direction

## _SET_OARS_ROWING_SPEED
`0x6835AFEA10E186F4` | `void _SET_OARS_ROWING_SPEED(Vehicle vehicle, int speed)` | build 1207
3 speeds (1-3), higher it is faster it will be

## _SET_RANDOM_TRAINS_WHISTLE_ENABLED
`0x1BFBAFCC6760FF02` | `void _SET_RANDOM_TRAINS_WHISTLE_ENABLED(Vehicle train, BOOL enabled)` | build 1207

## _SET_TRAIN_COLLISION_AVOIDANCE_ENABLED
`0xE6BD7DD3FD474415` | `void _SET_TRAIN_COLLISION_AVOIDANCE_ENABLED(Vehicle train, BOOL enabled)` | build 1207
Enables or disables collision avoidance behavior for AI-controlled trains.

When enabled, the train will automatically stop if an obstacle or possible
collision is detected ahead on the track. When disabled, the train will
continue moving without reacting to obstacles

## _SET_TRAIN_DESTRUCTION_ENABLED
`0x07E2E21E799080A0` | `void _SET_TRAIN_DESTRUCTION_ENABLED(Vehicle train, BOOL enabled)` | build 1207
Enables/disables damage/explosion flags on the engine and all attached cars; typically set true before EXPLODE_VEHICLE.

## _SET_TRAIN_ENABLE_REVERSING
`0x06A09A6E0C6D2A84` | `void _SET_TRAIN_ENABLE_REVERSING(Vehicle train, BOOL enabled)` | build 1207
true to enable train reversing moving backwards, false to not allow reversing

## _SET_TRAIN_HALT
`0x3660BCAB3A6BB734` | `void _SET_TRAIN_HALT(Vehicle train)` | build 1207

## _SET_TRAIN_LEAVE_STATION
`0x787E43477746876F` | `void _SET_TRAIN_LEAVE_STATION(Vehicle train)` | build 1207
Restarts the train

## _SET_TRAIN_MAX_SPEED
`0x9F29999DFDF2AEB8` | `void _SET_TRAIN_MAX_SPEED(Vehicle train, float speed)` | build 1207
Maximum possible speed is 30.0 (108 km/h)

## _SET_TRAIN_STOPS_FOR_STATIONS
`0x4182C037AA1F0091` | `void _SET_TRAIN_STOPS_FOR_STATIONS(Vehicle train, BOOL toggle)` | build 1207

## _SET_TRAIN_TRACK_JUNCTION_SWITCH
`0xE6C5E2125EB210C1` | `void _SET_TRAIN_TRACK_JUNCTION_SWITCH(Hash trainTrack, int junctionIndex, BOOL enabled)` | build 1207
trainTrack: FREIGHT_GROUP, TRAINS3, BRAITHWAITES2_TRACK_CONFIG, TRAINS_OLD_WEST01, TRAINS_OLD_WEST03, TRAINS_NB1, TRAINS_INTERSECTION1_ANN

## _SET_VEHICLE_COMPARTMENT_DOOR_OPEN
`0xF6E3D38869D0F7AD` | `void _SET_VEHICLE_COMPARTMENT_DOOR_OPEN(Vehicle vehicle)` | build 1207
Opens the compartment door of a vehicle if it has one, dropping the tailgate, opening a built-in lockbox, or revealing a hidden smuggler compartment

## _SET_VEHICLE_DETERIORATION
`0x8E5DA070BAD3279E` | `void _SET_VEHICLE_DETERIORATION(Vehicle vehicle, float amount, int p2, BOOL p3)` | build 1207

## _SET_VEHICLE_DIRT_LEVEL_2
`0xBAE0EEDF93F05EAA` | `void _SET_VEHICLE_DIRT_LEVEL_2(Vehicle vehicle, float dirtLevel)` | build 1207
dirtLevel: 0.0 - 1.0

## _SET_VEHICLE_IS_IN_HURRY
`0xCE1531927AD6C9F8` | `void _SET_VEHICLE_IS_IN_HURRY(Vehicle vehicle, BOOL enabled)` | build 1207

## _SET_VEHICLE_LIVERY
`0xF89D82A0582E46ED` | `void _SET_VEHICLE_LIVERY(Vehicle vehicle, int liveryIndex)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/vehicles/vehicle_modding/vehicle_liveries.lua

## _SET_VEHICLE_LOD_LEVEL
`0x3FA7D7D1E0EA809E` | `void _SET_VEHICLE_LOD_LEVEL(Vehicle vehicle, int lodLevel)` | build 1207
Ranges from -1 to 2? (internal type is int8)
https://imgur.com/a/bPzHcft

## _SET_VEHICLE_MUD_LEVEL
`0x4D15E49764CB328A` | `void _SET_VEHICLE_MUD_LEVEL(Vehicle vehicle, float mudLevel)` | build 1207
mudLevel: 0.0 - 1.0

## _SET_VEHICLE_ROAD_LINK_FORCED
`0xC2E62678D602853C` | `void _SET_VEHICLE_ROAD_LINK_FORCED(Vehicle vehicle, float startX, float startY, float startZ, float endX, float endY, float endZ)` | build 1207
Picks the road/path link nearest (start to end) and stores it on the vehicle's driving component (used by R* Scripts to choose an exit link).

## _SET_VEHICLE_SNOW_LEVEL
`0x6F73EFAB11651D7F` | `void _SET_VEHICLE_SNOW_LEVEL(Vehicle vehicle, float snowLevel)` | build 1207
snowLevel: 0.0 - 1.0

## _SET_VEHICLE_STOP_DISTANCE
`0xA13028E22564A1BD` | `void _SET_VEHICLE_STOP_DISTANCE(Vehicle vehicle, float distance)` | build 1207
Sets the stop distance of a vehicle when there something in it's way that forces it to stop or sets the view distance of the vehicle making it stop at a distance

## _SET_VEHICLE_TINT
`0x8268B098F6FCA4E2` | `void _SET_VEHICLE_TINT(Vehicle vehicle, int tintId)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/vehicles/vehicle_modding/vehicle_tints.lua

## _SET_VEHICLE_WET_LEVEL
`0x5AABB09F6FBD1F87` | `void _SET_VEHICLE_WET_LEVEL(Vehicle vehicle, float wetLevel)` | build 1207
wetLevel: 0.0 - 1.0

## _SHOW_HORSE_REINS
`0x41CDA90EE3450921` | `void _SHOW_HORSE_REINS(Vehicle vehicle)` | build 1207

## _TRIGGER_TRAIN_WHISTLE
`0xCFE122EC635CC2B2` | `void _TRIGGER_TRAIN_WHISTLE(Vehicle train, char* whistleSequence, BOOL p2, BOOL p3)` | build 1207
whistleSequence: ACKNOWLEDGE, BACKING_UP, CROSSING, DANGER, MOVING, NEXT_STATION, PASSING, STOPPED
p2 = true seems to mute the sound
