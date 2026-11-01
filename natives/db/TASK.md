# TASK natives (640)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_COVER_BLOCKING_AREA
`0x45C597097DD7CB81` | `void ADD_COVER_BLOCKING_AREA(float playerX, float playerY, float playerZ, float radiusX, float radiusY, float radiusZ, BOOL p6, BOOL p7, BOOL p8, BOOL p9)` | build 1207

## ADD_COVER_POINT
`0xD5C12A75C7B9497F` | `ScrHandle ADD_COVER_POINT(float p0, float p1, float p2, float p3, Any p4, Any p5, Any p6, BOOL p7)` | build 1207

## ADD_FLEE_TARGET_PED
`0x3923EC958249657D` | `void ADD_FLEE_TARGET_PED(Ped ped, Ped targetPed, float p2)` | build 1207
Params: p2 is always -1.f in R* Scripts

## ADD_PATROL_ROUTE_LINK
`0x23083260DEC3A551` | `void ADD_PATROL_ROUTE_LINK(int node1, int node2)` | build 1207

## ADD_PATROL_ROUTE_NODE
`0x8EDF950167586B7C` | `void ADD_PATROL_ROUTE_NODE(int nodeId, char* scenarioName, float x, float y, float z, float lookPosX, float lookPosY, float lookPosZ, int duration, BOOL p9)` | build 1207

## ARE_COMPOSITE_LOOTABLE_ENTITY_DEF_ASSETS_LOADED
`0x5E5D96BE25E9DF68` | `BOOL ARE_COMPOSITE_LOOTABLE_ENTITY_DEF_ASSETS_LOADED(Hash asset)` | build 1207
Returns true when requested asset is loaded

## ASSISTED_MOVEMENT_IS_ROUTE_LOADED
`0x60F9A4393A21F741` | `BOOL ASSISTED_MOVEMENT_IS_ROUTE_LOADED(char* route)` | build 1207

## ASSISTED_MOVEMENT_REMOVE_ROUTE
`0x3548536485DD792B` | `void ASSISTED_MOVEMENT_REMOVE_ROUTE(char* route)` | build 1207

## ASSISTED_MOVEMENT_SET_ROUTE_PROPERTIES
`0xD5002D78B7162E1B` | `void ASSISTED_MOVEMENT_SET_ROUTE_PROPERTIES(char* route, int props)` | build 1207

## CAN_START_ITEM_INTERACTION
`0x2D19BC4DF626CBE7` | `BOOL CAN_START_ITEM_INTERACTION(Ped ped, Hash itemHash, Hash interactionAnimHash, int p3)` | build 1207

## CLEAR_DRIVEBY_TASK_UNDERNEATH_DRIVING_TASK
`0xC35B5CDB2824CF69` | `void CLEAR_DRIVEBY_TASK_UNDERNEATH_DRIVING_TASK(Ped ped)` | build 1207

## CLEAR_PED_SECONDARY_TASK
`0x176CECF6F920D707` | `void CLEAR_PED_SECONDARY_TASK(Ped ped)` | build 1207

## CLEAR_PED_TASKS
`0xE1EF3C1216AFF2CD` | `void CLEAR_PED_TASKS(Ped ped, BOOL p1, BOOL p2)` | build 1207

## CLEAR_PED_TASKS_IMMEDIATELY
`0xAAA34F8A7CB32098` | `void CLEAR_PED_TASKS_IMMEDIATELY(Ped ped, BOOL p1, BOOL resetCrouch)` | build 1207
Immediately stops the pedestrian from whatever it's doing. They stop fighting, animations, etc. they forget what they were doing.

resetCrouch TRUE = ped will stand up if crouching, FALSE = ped will remain crouching if crouched

## CLEAR_SEQUENCE_TASK
`0x3841422E9C488D8C` | `void CLEAR_SEQUENCE_TASK(int* taskSequenceId)` | build 1207

## CLOSE_PATROL_ROUTE
`0xB043ECA801B8CBC1` | `void CLOSE_PATROL_ROUTE()` | build 1207

## CLOSE_SEQUENCE_TASK
`0x39E72BC99E6360CB` | `void CLOSE_SEQUENCE_TASK(int taskSequenceId)` | build 1207

## CREATE_PATROL_ROUTE
`0xAF8A443CCC8018DC` | `void CREATE_PATROL_ROUTE()` | build 1207

## CREATE_SCENARIO_POINT_HASH
`0x94B745CE41DB58A1` | `int CREATE_SCENARIO_POINT_HASH(Hash scenarioHash, float x, float y, float z, float heading, Any p5, Any p6, BOOL p7)` | build 1207
Returns scenario

## CREATE_SCENARIO_POINT_HASH_ATTACHED_TO_ENTITY
`0x794AB1379A74064D` | `int CREATE_SCENARIO_POINT_HASH_ATTACHED_TO_ENTITY(Entity entity, Hash scenarioHash, float x, float y, float z, float heading, Any p6, Any p7, BOOL p8)` | build 1207
Returns scenario

## DELETE_PATROL_ROUTE
`0x7767DD9D65E91319` | `void DELETE_PATROL_ROUTE(char* patrolRoute)` | build 1207

## DOES_SCENARIO_EXIST_IN_AREA
`0x5A59271FFADD33C1` | `BOOL DOES_SCENARIO_EXIST_IN_AREA(float x, float y, float z, float radius, BOOL p4, Any p5, BOOL p6)` | build 1207

## DOES_SCENARIO_GROUP_EXIST
`0xF9034C136C9E00D3` | `BOOL DOES_SCENARIO_GROUP_EXIST(char* scenarioGroup)` | build 1207

## DOES_SCENARIO_OF_TYPE_EXIST_IN_AREA_HASH
`0x6EEAD6AF637DA752` | `BOOL DOES_SCENARIO_OF_TYPE_EXIST_IN_AREA_HASH(float x, float y, float z, Hash typeHash, float radius, BOOL p5)` | build 1207

## DOES_SCENARIO_POINT_EXIST
`0x841475AC96E794D1` | `BOOL DOES_SCENARIO_POINT_EXIST(int scenario)` | build 1207

## DOES_SCRIPTED_COVER_POINT_EXIST_AT_COORDS
`0xA98B8E3C088E5A31` | `BOOL DOES_SCRIPTED_COVER_POINT_EXIST_AT_COORDS(Any p0, Any p1, Any p2, Any p3)` | build 1207
Checks if there is a cover point at position

## END_DUEL
`0xEED08A3A98B847E2` | `void END_DUEL(Ped ped, BOOL p1, float p2)` | build 1207

## FIND_SCENARIO_OF_TYPE_HASH
`0xF533D68FF970D190` | `int FIND_SCENARIO_OF_TYPE_HASH(float xPos, float yPos, float zPos, Hash scenarioType, float distance, Any p5, BOOL p6)` | build 1207

## FORCE_SCENARIO_GROUP_PRIORITY
`0x444C910A5058E568` | `void FORCE_SCENARIO_GROUP_PRIORITY(Any p0, Any p1)` | build 1207

## GET_ACTIVE_VEHICLE_MISSION_TYPE
`0x534AEBA6E5ED4CAB` | `int GET_ACTIVE_VEHICLE_MISSION_TYPE(Vehicle vehicle)` | build 1207

## GET_IS_CARRIABLE_ENTITY
`0x0CCFE72B43C9CF96` | `BOOL GET_IS_CARRIABLE_ENTITY(Entity entity)` | build 1207

## GET_IS_PED_AIMING_IN_THE_AIR
`0x8785E6E40C7A8819` | `BOOL GET_IS_PED_AIMING_IN_THE_AIR(Ped ped)` | build 1207

## GET_IS_TASK_ACTIVE
`0xB0760331C7AA4155` | `BOOL GET_IS_TASK_ACTIVE(Ped ped, int taskIndex)` | build 1207

## GET_IS_WAYPOINT_RECORDING_LOADED
`0xCB4E8BE8A0063C5D` | `BOOL GET_IS_WAYPOINT_RECORDING_LOADED(char* waypointRecording)` | build 1207

## GET_ITEM_INTERACTION_ITEM_ID
`0x804425C4BBD00883` | `Hash GET_ITEM_INTERACTION_ITEM_ID(Ped ped)` | build 1207

## GET_ITEM_INTERACTION_PROMPT_PROGRESS
`0xBC864A70AD55E0C1` | `float GET_ITEM_INTERACTION_PROMPT_PROGRESS(Ped ped, Hash inputContext)` | build 1207

## GET_ITEM_INTERACTION_STATE
`0x6AA3DCA2C6F5EB6D` | `Hash GET_ITEM_INTERACTION_STATE(Ped ped)` | build 1207

## GET_PED_DESIRED_MOVE_BLEND_RATIO
`0x8517D4A6CA8513ED` | `float GET_PED_DESIRED_MOVE_BLEND_RATIO(Ped ped)` | build 1207

## GET_PED_WAYPOINT_DISTANCE
`0xE6A877C64CAF1BC5` | `float GET_PED_WAYPOINT_DISTANCE(Ped ped)` | build 1207

## GET_PED_WAYPOINT_OVERRIDE_SPEED
`0xD39A2F3E7FCAFF08` | `float GET_PED_WAYPOINT_OVERRIDE_SPEED(Ped ped)` | build 1207

## GET_PED_WAYPOINT_PROGRESS
`0x2720AAA75001E094` | `int GET_PED_WAYPOINT_PROGRESS(Ped ped)` | build 1207

## GET_PROP_FOR_SCENARIO_POINT
`0x295514F198EFD0CA` | `Entity GET_PROP_FOR_SCENARIO_POINT(int scenarioPoint, char* name)` | build 1207
Old name: _GET_SCENARIO_POINT_ENTITY

## GET_RANSACK_SCENARIO_POINT_PED_IS_USING
`0xD04241BBF6D03A5E` | `Any GET_RANSACK_SCENARIO_POINT_PED_IS_USING(Ped ped)` | build 1207

## GET_SCENARIO_POINTS_IN_AREA
`0x345EC3B7EBDE1CB5` | `int GET_SCENARIO_POINTS_IN_AREA(float posX, float posY, float posZ, float radius, Any scenariosInRadius, int size)` | build 1207
Note: scenariosInRadius is an array, and its size and values should be aligned to 8 bytes.

## GET_SCRIPTED_COVER_POINT_COORDS
`0x594A1028FC2A3E85` | `Vector3 GET_SCRIPTED_COVER_POINT_COORDS(ScrHandle coverpoint)` | build 1207

## GET_SCRIPT_TASK_STATUS
`0x77F1BEB8863288D5` | `int GET_SCRIPT_TASK_STATUS(Ped ped, Hash taskHash, BOOL p2)` | build 1207
Gets the status of a script-assigned task, and returns an int between 0-8
taskHash: https://alloc8or.re/rdr3/doc/enums/eScriptTaskHash.txt 

WAITING_TO_START_TASK = 0,
PERFORMING_TASK
DORMANT_TASK
VACANT_STAGE
GROUP_TASK_STAGE
ATTRACTOR_SCRIPT_TASK_STAGE
SECONDARY_TASK_STAGE
TASK_NOT_FOUND
FINISHED_TASK

## GET_SEQUENCE_PROGRESS
`0x00A9010CFE1E3533` | `int GET_SEQUENCE_PROGRESS(Ped ped)` | build 1207
returned values:
0 to 7 = task that's currently in progress, 0 meaning the first one.
-1 no task sequence in progress.

## GET_TASK_MOVE_NETWORK_EVENT
`0xB4F47213DF45A64C` | `BOOL GET_TASK_MOVE_NETWORK_EVENT(Ped ped, char* eventName)` | build 1207

## GET_TASK_MOVE_NETWORK_STATE
`0x717E4D1F2048376D` | `const char* GET_TASK_MOVE_NETWORK_STATE(Ped ped)` | build 1207

## GET_VEHICLE_WAYPOINT_PLAYBACK_OVERRIDE_SPEED
`0x3DC971EB22F73447` | `Any GET_VEHICLE_WAYPOINT_PLAYBACK_OVERRIDE_SPEED(Any p0)` | build 1207

## GET_VEHICLE_WAYPOINT_PROGRESS
`0x9824CFF8FC66E159` | `int GET_VEHICLE_WAYPOINT_PROGRESS(Vehicle vehicle)` | build 1207

## GET_VEHICLE_WAYPOINT_TARGET_POINT
`0x416B62AC8B9E5BBD` | `int GET_VEHICLE_WAYPOINT_TARGET_POINT(Vehicle vehicle)` | build 1207

## GET_WAYPOINT_DISTANCE_ALONG_ROUTE
`0xA5B769058763E497` | `float GET_WAYPOINT_DISTANCE_ALONG_ROUTE(char* waypointRecording, int p1)` | build 1207

## IS_DRIVEBY_TASK_UNDERNEATH_DRIVING_TASK
`0x8785E6E40C7A8818` | `BOOL IS_DRIVEBY_TASK_UNDERNEATH_DRIVING_TASK(Ped ped)` | build 1207

## IS_EMOTE_TASK_RUNNING
`0xCF9B71C0AF824036` | `BOOL IS_EMOTE_TASK_RUNNING(Ped ped, Any p1)` | build 1355

## IS_MOUNTED_WEAPON_TASK_UNDERNEATH_DRIVING_TASK
`0xA320EF046186FA3B` | `BOOL IS_MOUNTED_WEAPON_TASK_UNDERNEATH_DRIVING_TASK(Ped ped)` | build 1207

## IS_MOVE_BLEND_RATIO_RUNNING
`0xD4D8636C0199A939` | `BOOL IS_MOVE_BLEND_RATIO_RUNNING(float moveBlendRatio)` | build 1207

## IS_MOVE_BLEND_RATIO_SPRINTING
`0x24A2AD74FA9814E2` | `BOOL IS_MOVE_BLEND_RATIO_SPRINTING(float moveBlendRatio)` | build 1207

## IS_MOVE_BLEND_RATIO_STILL
`0x349CE7B56DAFD95C` | `BOOL IS_MOVE_BLEND_RATIO_STILL(float moveBlendRatio)` | build 1207

## IS_MOVE_BLEND_RATIO_WALKING
`0xF133BBBE91E1691F` | `BOOL IS_MOVE_BLEND_RATIO_WALKING(float moveBlendRatio)` | build 1207

## IS_PED_ACTIVE_IN_SCENARIO
`0xAA135F9482C82CC3` | `BOOL IS_PED_ACTIVE_IN_SCENARIO(Ped ped, int scenario)` | build 1207

## IS_PED_BEING_ARRESTED
`0x90A09F3A45FED688` | `BOOL IS_PED_BEING_ARRESTED(Ped ped)` | build 1207
This function is hard-coded to always return false.

## IS_PED_CUFFED
`0x74E559B3BC910685` | `BOOL IS_PED_CUFFED(Ped ped)` | build 1207

## IS_PED_EXITING_SCENARIO
`0x0C3CB2E600C8977D` | `BOOL IS_PED_EXITING_SCENARIO(Ped ped, BOOL p1)` | build 1207

## IS_PED_GETTING_UP
`0x2A74E1D5F2F00EEC` | `BOOL IS_PED_GETTING_UP(Ped ped)` | build 1207

## IS_PED_IN_HIT_REACT
`0xF330A5C062B29BED` | `BOOL IS_PED_IN_HIT_REACT(Ped ped)` | build 1207

## IS_PED_IN_WRITHE
`0xDEB6D52126E7D640` | `BOOL IS_PED_IN_WRITHE(Ped ped)` | build 1207
This native checks if a ped is on the ground, in pain from a (gunshot) wound.

## IS_PED_RUNNING
`0xC5286FFC176F28A2` | `BOOL IS_PED_RUNNING(Ped ped)` | build 1207

## IS_PED_RUNNING_INSPECTION_TASK
`0x038B1F1674F0E242` | `BOOL IS_PED_RUNNING_INSPECTION_TASK(Ped ped)` | build 1207

## IS_PED_RUNNING_TASK_ITEM_INTERACTION
`0xEC7E480FF8BD0BED` | `BOOL IS_PED_RUNNING_TASK_ITEM_INTERACTION(Ped ped)` | build 1207

## IS_PED_SCENARIO_REACT_LOOKING
`0x916B8E075ABC8B4E` | `BOOL IS_PED_SCENARIO_REACT_LOOKING(Ped ped, BOOL p1)` | build 1207

## IS_PED_SPRINTING
`0x57E457CD2C0FC168` | `BOOL IS_PED_SPRINTING(Ped ped)` | build 1207

## IS_PED_STILL
`0xAC29253EEF8F0180` | `BOOL IS_PED_STILL(Ped ped)` | build 1207

## IS_PED_WALKING
`0xDE4C184B2B9B071A` | `BOOL IS_PED_WALKING(Ped ped)` | build 1207

## IS_SCENARIO_GROUP_ENABLED
`0x367A09DED4E05B99` | `BOOL IS_SCENARIO_GROUP_ENABLED(char* scenarioGroup)` | build 1207

## IS_SCENARIO_OCCUPIED
`0x788756D73AC2E07C` | `BOOL IS_SCENARIO_OCCUPIED(float p0, float p1, float p2, float p3, BOOL p4)` | build 1207

## IS_SCENARIO_TYPE_ENABLED
`0x3A815DB3EA088722` | `BOOL IS_SCENARIO_TYPE_ENABLED(char* scenarioType)` | build 1207

## IS_TASK_MOVE_NETWORK_ACTIVE
`0x921CE12C489C4C41` | `BOOL IS_TASK_MOVE_NETWORK_ACTIVE(Ped ped)` | build 1207

## IS_TASK_MOVE_NETWORK_READY_FOR_TRANSITION
`0x30ED88D5E0C56A37` | `BOOL IS_TASK_MOVE_NETWORK_READY_FOR_TRANSITION(Ped ped)` | build 1207

## IS_TEAM_CARRIABLE_ENTITY
`0x559A6F8C5133B4EE` | `BOOL IS_TEAM_CARRIABLE_ENTITY(Any p0, Any p1)` | build 1207

## IS_WAYPOINT_PLAYBACK_GOING_ON_FOR_PED
`0xE03B3F2D3DC59B64` | `BOOL IS_WAYPOINT_PLAYBACK_GOING_ON_FOR_PED(Ped ped, char* waypointRecording)` | build 1207

## IS_WAYPOINT_PLAYBACK_GOING_ON_FOR_VEHICLE
`0xF5134943EA29868C` | `BOOL IS_WAYPOINT_PLAYBACK_GOING_ON_FOR_VEHICLE(Any p0, Any p1)` | build 1207

## MAKE_OBJECT_NOT_CARRIABLE
`0x67BFCED22909834D` | `void MAKE_OBJECT_NOT_CARRIABLE(Object object)` | build 1207

## OPEN_PATROL_ROUTE
`0xA36BFB5EE89F3D82` | `void OPEN_PATROL_ROUTE(char* patrolRoute)` | build 1207
Note: patrolRoute must be prefixed with 'miss_' for it to be valid

## OPEN_SEQUENCE_TASK
`0xE8854A4326B9E12B` | `void OPEN_SEQUENCE_TASK(int* taskSequenceId)` | build 1207

## PED_HAS_USE_SCENARIO_TASK
`0x295E3CCEC879CCD7` | `BOOL PED_HAS_USE_SCENARIO_TASK(Ped ped)` | build 1207

## PLAY_ANIM_ON_RUNNING_SCENARIO
`0x748040460F8DF5DC` | `void PLAY_ANIM_ON_RUNNING_SCENARIO(Ped ped, char* animDict, char* animName)` | build 1207

## PLAY_ENTITY_SCRIPTED_ANIM
`0x77A1EEC547E7FCF1` | `void PLAY_ENTITY_SCRIPTED_ANIM(Entity entity, Any args)` | build 1207

## REACT_LOOK_AT
`0xE7FA07624574B79A` | `void REACT_LOOK_AT(Ped ped, Ped targetPed, int lookIntensity, int exitAnimation, float duration, int p5, Ped targetPed2, Any p7, Any p8)` | build 1207
lookIntensity: see SET_PED_SHOULD_PLAY_FLEE_SCENARIO_EXIT

exitAnimation: LOOK_RETURN_GENERIC = 1,
LOOK_RETURN_DISMISSIVE = 2,
LOOK_RETURN_RELIEVED = 3

## REACT_LOOK_AT_END
`0x541E5B41DCA45828` | `void REACT_LOOK_AT_END(Ped ped, int exitAnimation, BOOL p2)` | build 1207

## REMOVE_ALL_COVER_BLOCKING_AREAS
`0xDB6708C0B46F56D8` | `void REMOVE_ALL_COVER_BLOCKING_AREAS()` | build 1207

## REMOVE_COVER_POINT
`0xAE287C923D891715` | `void REMOVE_COVER_POINT(ScrHandle coverpoint)` | build 1207

## REMOVE_WAYPOINT_RECORDING
`0xFF1B8B4AA1C25DC8` | `void REMOVE_WAYPOINT_RECORDING(char* waypointRecording)` | build 1207

## REQUEST_TASK_MOVE_NETWORK_STATE_TRANSITION
`0xD01015C7316AE176` | `void REQUEST_TASK_MOVE_NETWORK_STATE_TRANSITION(Ped ped, char* name)` | build 1207

## REQUEST_WAYPOINT_RECORDING
`0x9EEFB62EB27B5792` | `void REQUEST_WAYPOINT_RECORDING(char* waypointRecording)` | build 1207

## RESET_SCENARIO_GROUPS_ENABLED
`0xDD902D0349AFAD3A` | `void RESET_SCENARIO_GROUPS_ENABLED()` | build 1207

## RESET_SCENARIO_TYPES_ENABLED
`0x0D40EE2A7F2B2D6D` | `void RESET_SCENARIO_TYPES_ENABLED()` | build 1207

## SET_ANIM_FILTER
`0x87B66D77D545DB66` | `void SET_ANIM_FILTER(Entity entity, char* filterName, int priority, BOOL secondary)` | build 1207

## SET_ANIM_RATE
`0x032D49C5E359C847` | `void SET_ANIM_RATE(Any p0, float p1, Any p2, BOOL p3)` | build 1207

## SET_DRIVEBY_TASK_TARGET
`0xE5B302114D8162EE` | `void SET_DRIVEBY_TASK_TARGET(Ped shootingPed, Ped targetPed, Vehicle targetVehicle, float x, float y, float z)` | build 1207

## SET_DRIVE_TASK_CRUISE_SPEED
`0x5C9B84BD7D31D908` | `void SET_DRIVE_TASK_CRUISE_SPEED(Ped driver, float cruiseSpeed)` | build 1207

## SET_DRIVE_TASK_MAX_CRUISE_SPEED
`0x404A5AA9B9F0B746` | `void SET_DRIVE_TASK_MAX_CRUISE_SPEED(Ped ped, float maxCruiseSpeed)` | build 1207
Not implemented.

## SET_ENABLE_SPEED_RESTRAIN_FOR_WAYPOINT_RECORDING_LEADER
`0x295F03DC97BEEBC1` | `void SET_ENABLE_SPEED_RESTRAIN_FOR_WAYPOINT_RECORDING_LEADER(Any p0, Any p1)` | build 1207

## SET_ENHANCED_BREAK_FREE
`0x1BF9D36A5EAFFBAE` | `BOOL SET_ENHANCED_BREAK_FREE(Ped ped, BOOL p1, char* clipset)` | build 1207
clipset: CLIPSET@MECH_HOGTIE@HUMAN@BREAKOUT_MG@GROUND, CLIPSET@MECH_HOGTIE@HUMAN@BREAKOUT_MG@SHOULDER, CLIPSET@MECH_HOGTIE@HUMAN@BREAKOUT_MG@MOUNT
clipset can also be 0

## SET_HIGH_FALL_TASK
`0x8C825BDC7741D37C` | `void SET_HIGH_FALL_TASK(Ped ped, int p1, int p2, int p3)` | build 1207
Makes the ped ragdoll like when falling from a great height

## SET_PED_DESIRED_MOVE_BLEND_RATIO
`0x1E982AC8716912C5` | `void SET_PED_DESIRED_MOVE_BLEND_RATIO(Ped ped, float p1)` | build 1207

## SET_PED_PATH_AVOID_FIRE
`0x4455517B28441E60` | `void SET_PED_PATH_AVOID_FIRE(Ped ped, BOOL avoidFire)` | build 1207

## SET_PED_PATH_CAN_DROP_FROM_HEIGHT
`0xE361C5C71C431A4F` | `void SET_PED_PATH_CAN_DROP_FROM_HEIGHT(Ped ped, BOOL toggle)` | build 1207

## SET_PED_PATH_CAN_USE_CLIMBOVERS
`0x8E06A6FE76C9EFF4` | `void SET_PED_PATH_CAN_USE_CLIMBOVERS(Ped ped, BOOL toggle)` | build 1207

## SET_PED_PATH_CAN_USE_LADDERS
`0x77A5B103C87F476E` | `void SET_PED_PATH_CAN_USE_LADDERS(Ped ped, BOOL toggle)` | build 1207

## SET_PED_PATH_CLIMB_COST_MODIFIER
`0x88E32DB8C1A4AA4B` | `void SET_PED_PATH_CLIMB_COST_MODIFIER(Ped ped, float modifier)` | build 1207

## SET_PED_PATH_DEEP_SNOW_COST_MODIFIER
`0xE8C296B75EACC357` | `void SET_PED_PATH_DEEP_SNOW_COST_MODIFIER(Ped ped, float modifier)` | build 1207

## SET_PED_PATH_FOLIAGE_COST_MODIFIER
`0x3AD8EFF9703BE657` | `void SET_PED_PATH_FOLIAGE_COST_MODIFIER(Ped ped, float modifier)` | build 1207

## SET_PED_PATH_MAY_ENTER_WATER
`0xF35425A4204367EC` | `void SET_PED_PATH_MAY_ENTER_WATER(Ped ped, BOOL mayEnterWater)` | build 1207

## SET_PED_PATH_PREFER_TO_AVOID_WATER
`0x38FE1EC73743793C` | `void SET_PED_PATH_PREFER_TO_AVOID_WATER(Ped ped, BOOL avoidWater, float p2)` | build 1207

## SET_PED_WAYPOINT_ROUTE_OFFSET
`0xED98E10B0AFCE4B4` | `Any SET_PED_WAYPOINT_ROUTE_OFFSET(Ped ped, float p1, float p2, float p3)` | build 1207

## SET_SCENARIO_GROUP_ENABLED
`0x02C8E5B49848664E` | `void SET_SCENARIO_GROUP_ENABLED(char* scenarioGroup, BOOL toggle)` | build 1207

## SET_SCENARIO_TYPE_ENABLED
`0xEB47EC4E34FB7EE1` | `void SET_SCENARIO_TYPE_ENABLED(char* scenarioType, BOOL toggle)` | build 1207

## SET_SEQUENCE_TO_REPEAT
`0x58C70CF3A41E4AE7` | `void SET_SEQUENCE_TO_REPEAT(int taskSequenceId, int repeatMode)` | build 1207
repeatMode: 0 = REPEAT_NOT; 1 = REPEAT_FOREVER

## SET_TASK_MOVE_NETWORK_SIGNAL_BOOL
`0xB0A6CFD2C69C1088` | `void SET_TASK_MOVE_NETWORK_SIGNAL_BOOL(Ped ped, char* signalName, BOOL value)` | build 1207

## SET_TASK_MOVE_NETWORK_SIGNAL_FLOAT
`0xD5BB4025AE449A4E` | `void SET_TASK_MOVE_NETWORK_SIGNAL_FLOAT(Ped ped, char* signalName, float value)` | build 1207

## SET_TEAM_CARRIABLE_ENTITY
`0x545BF19F86E80F11` | `void SET_TEAM_CARRIABLE_ENTITY(Any p0, Any p1, Any p2)` | build 1207

## SET_UP_SPEED_RESTRAIN_INFORMATION_FOR_PLAYER_FOLLOWER
`0xB5C51DD544F14F58` | `void SET_UP_SPEED_RESTRAIN_INFORMATION_FOR_PLAYER_FOLLOWER(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8)` | build 1207

## START_TASK_ITEM_INTERACTION
`0xAE72E7DF013AAA61` | `void START_TASK_ITEM_INTERACTION(Ped ped, Hash itemHash, Hash interactionAnimHash, int p3, int flag, float p5)` | build 1207
Params: p3 = 0, 1; p5 = 0.0f, -1.0f
https://github.com/femga/rdr3_discoveries/tree/master/tasks/TASK_ITEM_INTERACTION

## STOP_ANIM_PLAYBACK
`0xEE08C992D238C5D1` | `void STOP_ANIM_PLAYBACK(Ped ped, int p1, BOOL p2)` | build 1207

## STOP_ANIM_TASK
`0x97FF36A1D40EA00A` | `void STOP_ANIM_TASK(Ped ped, char* animDictionary, char* animationName, float p3)` | build 1207

## TASK_ACHIEVE_HEADING
`0x93B93A37987F1F3D` | `void TASK_ACHIEVE_HEADING(Ped ped, float heading, int timeout)` | build 1207
Makes the specified ped achieve the specified heading.

pedHandle: The handle of the ped to assign the task to.
heading: The desired heading.
timeout: The time, in milliseconds, to allow the task to complete. If the task times out, it is canceled, and the ped will stay at the heading it managed to reach in the time.

## TASK_AIM_AT_COORD
`0x4AF1D73861212F52` | `void TASK_AIM_AT_COORD(Ped ped, float x, float y, float z, int time, Any p5, Any p6)` | build 1207

## TASK_AIM_AT_ENTITY
`0xCF7569BD0FB480A0` | `void TASK_AIM_AT_ENTITY(Ped ped, Entity targetEntity, int time, Any p3, Any p4)` | build 1207

## TASK_AIM_GUN_AT_COORD
`0x6671F3EEC681BDA1` | `void TASK_AIM_GUN_AT_COORD(Ped ped, float x, float y, float z, int time, BOOL p5, BOOL p6)` | build 1207

## TASK_AIM_GUN_AT_ENTITY
`0x9B53BB6E8943AF53` | `void TASK_AIM_GUN_AT_ENTITY(Ped ped, Entity targetEntity, int duration, BOOL p3, int p4)` | build 1207
duration: the amount of time in milliseconds to do the task.  -1 will keep the task going until either another task is applied, or CLEAR_ALL_TASKS() is called with the ped

## TASK_AMBIENT_ANIMAL_HUNT
`0x4B39D8F9D0FE7749` | `void TASK_AMBIENT_ANIMAL_HUNT(Ped ped, Any p1, Any p2)` | build 1207

## TASK_AMBIENT_ANIMAL_STALK
`0x37C13863ABA1B4A3` | `void TASK_AMBIENT_ANIMAL_STALK(Ped ped, Any p1, Any p2)` | build 1207

## TASK_ANIMAL_ALERTED
`0x979D93372FC8C565` | `void TASK_ANIMAL_ALERTED(Ped ped, Any p1, Any p2)` | build 1207

## TASK_ANIMAL_FLEE
`0xA899B61C66F09134` | `void TASK_ANIMAL_FLEE(Ped ped, Ped targetPed, Any p2)` | build 1207

## TASK_ANIMAL_INTERACTION
`0xCD181A959CFDD7F4` | `void TASK_ANIMAL_INTERACTION(Ped ped, Ped targetPed, Hash interactionType, Hash interactionModel, BOOL skipIdleAnimationClip)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/tasks/TASK_ANIMAL_INTERACTION

## TASK_ANIMAL_UNALERTED
`0x21FDF9A25CFE1CE5` | `void TASK_ANIMAL_UNALERTED(Ped ped, Any p1, Any p2, Any p3, Any p4)` | build 1207

## TASK_ANIMAL_WRITHE
`0x8C038A39C4A4B6D6` | `void TASK_ANIMAL_WRITHE(Ped ped, Any p1, Any p2)` | build 1207

## TASK_ARREST_PED
`0xF3B9A78A178572B1` | `void TASK_ARREST_PED(Ped ped, Ped target)` | build 1207

## TASK_BARK
`0x83BFC1F836B2F3F2` | `void TASK_BARK(Ped ped, Ped barkAtTarget, Hash mood)` | build 1207

## TASK_BOAT_MISSION
`0x15C86013127CE63F` | `void TASK_BOAT_MISSION(Ped pedDriver, Vehicle boat, Any p2, Any p3, float x, float y, float z, Any p7, float maxSpeed, int drivingStyle, float p10, Any p11)` | build 1207

## TASK_BREAK_VEHICLE_DOOR_LOCK
`0xBB28D1BC9EA8A6A5` | `void TASK_BREAK_VEHICLE_DOOR_LOCK(Ped ped, Vehicle vehicle)` | build 1207

## TASK_CARRIABLE
`0xF0B4F759F35CC7F5` | `void TASK_CARRIABLE(Entity entity, Hash carryConfig, Ped carrier, int carriableSlot, int flags)` | build 1207
carriableSlot:
 7 > Back of a horse
 6 > Right side of a horse
 5 > Left side of a horse
flags:
 512: enables the prompt being the name of the item when using a generic item

## TASK_CLEAR_DEFENSIVE_AREA
`0x95A6C46A31D1917D` | `void TASK_CLEAR_DEFENSIVE_AREA(Ped ped)` | build 1207

## TASK_CLEAR_LOOK_AT
`0x0F804F1DB19B9689` | `void TASK_CLEAR_LOOK_AT(Ped ped)` | build 1207

## TASK_CLIMB
`0x89D9FCC2435112F1` | `void TASK_CLIMB(Ped ped, BOOL unused)` | build 1207
Climbs or vaults the nearest thing.

## TASK_CLIMB_LADDER
`0xB6C987F9285A3814` | `void TASK_CLIMB_LADDER(Ped ped, float p1, BOOL p2, BOOL p3)` | build 1207

## TASK_COMBAT_ANIMAL_CHARGE_PED
`0xEE3AA414CF99F368` | `void TASK_COMBAT_ANIMAL_CHARGE_PED(Ped ped, Ped targetPed, BOOL p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## TASK_COMBAT_ANIMAL_WARN
`0xF960F3D57B660E96` | `void TASK_COMBAT_ANIMAL_WARN(Ped ped, Any p1, Any p2)` | build 1207

## TASK_COMBAT_HATED_TARGETS
`0x8182B561A29BD597` | `void TASK_COMBAT_HATED_TARGETS(Ped ped, float radius)` | build 1207

## TASK_COMBAT_HATED_TARGETS_AROUND_PED
`0x7BF835BB9E2698C8` | `void TASK_COMBAT_HATED_TARGETS_AROUND_PED(Ped ped, float radius, int flags, Any p3)` | build 1207
Despite its name, it only attacks ONE hated target. The one closest hated target.

## TASK_COMBAT_HATED_TARGETS_AROUND_PED_TIMED
`0x2BBA30B854534A0C` | `void TASK_COMBAT_HATED_TARGETS_AROUND_PED_TIMED(Ped ped, float radius, int time, int flags)` | build 1207

## TASK_COMBAT_HATED_TARGETS_IN_AREA
`0x4CF5F55DAC3280A0` | `void TASK_COMBAT_HATED_TARGETS_IN_AREA(Ped ped, float x, float y, float z, float radius, int flags, Any p6)` | build 1207
Despite its name, it only attacks ONE hated target. The one closest to the specified position.

## TASK_COMBAT_HATED_TARGETS_NO_LOS_TEST
`0xB5BC69D9C4060BC3` | `void TASK_COMBAT_HATED_TARGETS_NO_LOS_TEST(Ped ped, float radius)` | build 1207

## TASK_COMBAT_PED
`0xF166E48407BAC484` | `void TASK_COMBAT_PED(Ped ped, Ped targetPed, int p2, int p3)` | build 1207

## TASK_COMBAT_PED_TIMED
`0x944F30DCB7096BDE` | `void TASK_COMBAT_PED_TIMED(Ped ped, Ped targetPed, int p2, Any p3)` | build 1207

## TASK_COMPANION_AMBIENT
`0xE017CF6E2527FE4F` | `void TASK_COMPANION_AMBIENT(Ped ped, Any p1)` | build 1207

## TASK_CONFRONT
`0x3A2A2071DF5CC569` | `BOOL TASK_CONFRONT(Ped ped, Ped targetPed, int p2)` | build 1207

## TASK_COWER
`0x3EB1FE9E8E908E15` | `void TASK_COWER(Ped ped, int duration, Ped pedToCowerFrom, char* p3)` | build 1207

## TASK_DISEMBARK_NEAREST_TRAIN_CARRIAGE
`0x0A11F3BDEC03ED5F` | `void TASK_DISEMBARK_NEAREST_TRAIN_CARRIAGE(Ped ped, float p1, int flags)` | build 1207
flags: See TASK_ENTER_VEHICLE

## TASK_DISMOUNT_ANIMAL
`0x48E92D3DDE23C23A` | `void TASK_DISMOUNT_ANIMAL(Ped rider, int taskFlag, Any p2, Any p3, Any p4, Ped targetPed)` | build 1207
Dismounts the ped from the animal it's mounted on. taskFlag affects what side the rider gets off. p2-p5 are almost always 0.
flags: See TASK_ENTER_VEHICLE

## TASK_DRIVE_BY
`0x2F8AF0E82773A171` | `void TASK_DRIVE_BY(Ped driverPed, Ped targetPed, Vehicle targetVehicle, float targetX, float targetY, float targetZ, float distanceToShoot, int pedAccuracy, BOOL p8, Hash firingPattern)` | build 1207

## TASK_DUCK
`0xA14B5FBF986BAC23` | `void TASK_DUCK(Ped ped, int time)` | build 1207

## TASK_DUEL
`0x5D5B0D5BC3626E5A` | `void TASK_DUEL(Ped ped, Any p1, float p2, Entity entity, float p4, int p5, float vPosOpponentX, float vPosOpponentY, float vPosOpponentZ, float fOpponentHead, int p10)` | build 1207
Params: p4 either 0.2f, 0.25f, 0.31f, 0.4f

## TASK_DUMP_CARRIABLE_FROM_PARENT
`0x17CA98707B15926A` | `void TASK_DUMP_CARRIABLE_FROM_PARENT(Ped ped, Ped ped2, Entity entity)` | build 1207

## TASK_EAT
`0xBD7949BD07299672` | `void TASK_EAT(Ped ped, Any p1, Any p2)` | build 1207

## TASK_ENTER_ANIM_SCENE
`0xC2329B0206426644` | `void TASK_ENTER_ANIM_SCENE(Ped ped, AnimScene animScene, char* entityName, char* playbackListName, float enterSpeed, BOOL bAutoStart, int flag, int p7, float p8)` | build 1207
flags:
MOVE_WHILST_WAITING_FOR_PATH = (1 << 0),
DO_NOT_STAND_STILL_AT_END_OF_PATH = (1 << 1),
SKIP_NAVIGATION = (1 << 2),
TEASF_AUTO_START_ANIM_SCENE = (1 << 3),
FORCE_STAND_STILL_AT_END_OF_PATH = (1 << 6),
ENTER_ANIM_SCENE_DONT_FOLLOW_NAVMESH = (1 << 7)

## TASK_ENTER_VEHICLE
`0xC20E50AA46D09CA8` | `void TASK_ENTER_VEHICLE(Ped ped, Vehicle vehicle, int timeout, int seat, float speed, int flag, Any p6)` | build 1207
flags: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eEnterExitVehicleFlags

## TASK_EVASIVE_ANIM
`0x5F22926E1BCE9B08` | `void TASK_EVASIVE_ANIM(Ped ped1, Ped ped2, int p2)` | build 1207
Params: p2 is returned by BUILTIN::SHIFT_LEFT

## TASK_EVERYONE_LEAVE_VEHICLE_IN_ORDER
`0x6F1C49F275BD25B3` | `void TASK_EVERYONE_LEAVE_VEHICLE_IN_ORDER(Vehicle vehicle, BOOL p1)` | build 1207

## TASK_EXTEND_ROUTE
`0x1E7889778264843A` | `void TASK_EXTEND_ROUTE(float x, float y, float z)` | build 1207
Adds a new point to the current point route. Call TASK_FLUSH_ROUTE before the first call to this. Call TASK_FOLLOW_POINT_ROUTE to make the Ped go the route.

A maximum of 8 points can be added.

## TASK_FLEE_COORD
`0x58428248BF4B64E4` | `void TASK_FLEE_COORD(Ped ped, float x, float y, float z, int fleeStyle, int p5, float p6, int duration, int p8)` | build 1207
Params: p5 = some flag?, p6 = -1.0f, p8 = 0 in R* Scripts
fleeStyle: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eFleeStyle

## TASK_FLEE_COORD_VIA
`0x390E0B697D25EAF5` | `void TASK_FLEE_COORD_VIA(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11)` | build 1207

## TASK_FLEE_PED
`0xFD45175A6DFD7CE9` | `void TASK_FLEE_PED(Ped ped, Ped fleeFromTarget, int fleeStyle, int flag, float p4, int p5, int p6)` | build 1207
Params: p4 = -1.0f, p5 = -1, p6 = 0 in R* Scripts
fleeStyle: see TASK_FLEE_COORD

## TASK_FLEE_PED_VIA
`0x5802E0F910E4CF1D` | `void TASK_FLEE_PED_VIA(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9)` | build 1207

## TASK_FLUSH_ROUTE
`0x841142A1376E9006` | `void TASK_FLUSH_ROUTE()` | build 1207
Clears the current point route. Call this before TASK_EXTEND_ROUTE and TASK_FOLLOW_POINT_ROUTE.

## TASK_FLYING_CIRCLE
`0x72997893BFB8ECCC` | `void TASK_FLYING_CIRCLE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## TASK_FLY_AWAY
`0xE86A537B5A3C297C` | `void TASK_FLY_AWAY(Ped ped, Ped fleeFromTarget)` | build 1207

## TASK_FLY_TO_COORD
`0xD6CFC2D59DA72042` | `void TASK_FLY_TO_COORD(Ped ped, float travelMbr, float x, float y, float z, BOOL p5, BOOL p6)` | build 1207

## TASK_FOLLOW_AND_CONVERSE_WITH_PED
`0x489FFCCCE7392B55` | `void TASK_FOLLOW_AND_CONVERSE_WITH_PED(Ped ped, Ped targetPed, Any p2, Any p3, float p4, float p5, int p6, Any p7, Any p8, float p9, float p10)` | build 1207

## TASK_FOLLOW_ENTITY_ALONG_WAYPOINT_RECORDING_AT_OFFSET
`0x4D2B787BAE9AB760` | `void TASK_FOLLOW_ENTITY_ALONG_WAYPOINT_RECORDING_AT_OFFSET(Ped ped0, Ped ped1, char* waypointRecording, float p3, float p4, int p5, int p6, int p7, BOOL p8)` | build 1207

## TASK_FOLLOW_ENTITY_WHILE_AIMING_AT_ENTITY
`0x2D532EAA142CF83F` | `void TASK_FOLLOW_ENTITY_WHILE_AIMING_AT_ENTITY(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## TASK_FOLLOW_NAV_MESH_TO_COORD
`0x15D3A79D4E44B913` | `void TASK_FOLLOW_NAV_MESH_TO_COORD(Ped ped, float x, float y, float z, float speedMultiplier, int timeout, float stoppingRange, int flags, float heading)` | build 1207
If no timeout, set timeout to -1.

## TASK_FOLLOW_NAV_MESH_TO_COORD_ADVANCED
`0x17F58B88D085DBAC` | `void TASK_FOLLOW_NAV_MESH_TO_COORD_ADVANCED(Ped ped, float x, float y, float z, float speedMultiplier, int timeout, float stoppingRange, int flags, float p8, float p9, float p10, Entity entity, float unk)` | build 1207

## TASK_FOLLOW_PAVEMENT_TO_COORD
`0x1B1475414E70DD8E` | `void TASK_FOLLOW_PAVEMENT_TO_COORD(Ped ped, Any args)` | build 1207

## TASK_FOLLOW_POINT_ROUTE
`0x0E14C5550DC3CD1D` | `void TASK_FOLLOW_POINT_ROUTE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## TASK_FOLLOW_TO_OFFSET_OF_COORD
`0x2E3676282C18A692` | `void TASK_FOLLOW_TO_OFFSET_OF_COORD(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14)` | build 1207

## TASK_FOLLOW_TO_OFFSET_OF_ENTITY
`0x304AE42E357B8C7E` | `void TASK_FOLLOW_TO_OFFSET_OF_ENTITY(Ped ped, Entity entity, float offsetX, float offsetY, float offsetZ, float movementSpeed, int timeout, float stoppingRange, BOOL persistFollowing, BOOL p9, BOOL walkOnly, BOOL p11, BOOL p12, BOOL p13)` | build 1207

## TASK_FOLLOW_WAYPOINT_RECORDING
`0x0759591819534F7B` | `void TASK_FOLLOW_WAYPOINT_RECORDING(Ped ped, char* waypointRecording, int startIndex, int flag, int endIndex, BOOL patrol, BOOL aimWeapon, int duration)` | build 1207
Orders ped to follow a waypoint recording with control over start/end node indices, optional patrol (back-and-forth) behavior,aiming stance, and total traversal duration
NOTES:The recording must be requested and loaded using `REQUEST_WAYPOINT_RECORDING`.
The indices (startIndex, endIndex) restrict which part of the route is used.
patrol controls whether the ped returns to the start after reaching the end.
aimWeapon only affects stance — no firing occurs.
duration determines total task time before snapping to the end node
https://www.youtube.com/watch?v=RIsXDJSmeGU

## TASK_FOLLOW_WAYPOINT_RECORDING_ADVANCED
`0x0CFC13EBC19BCA52` | `void TASK_FOLLOW_WAYPOINT_RECORDING_ADVANCED(Ped ped, Any p1)` | build 1207

## TASK_FOLLOW_WAYPOINT_RECORDING_AT_OFFSET
`0xBE9B0520BD7C445B` | `void TASK_FOLLOW_WAYPOINT_RECORDING_AT_OFFSET(Ped ped, char* waypointRecording, float p2, int p3, int p4, int p5, BOOL p6)` | build 1207

## TASK_FORCE_AIM_AT_COORD
`0x41323F4E0C4AE94B` | `void TASK_FORCE_AIM_AT_COORD(Ped ped, float x, float y, float z, int p4, BOOL p5, BOOL p6)` | build 1207
Force a ped that is already attacking to aim directly at the specified world coordinates

## TASK_FORCE_MOTION_STATE
`0x4F056E1AFFEF17AB` | `void TASK_FORCE_MOTION_STATE(Ped ped, Hash motionStateHash, BOOL p2)` | build 1207
motionStateHash: see FORCE_PED_MOTION_STATE

## TASK_GOTO_ENTITY_AIMING
`0xA9DA48FAB8A76C12` | `void TASK_GOTO_ENTITY_AIMING(Ped ped, Entity target, float distanceToStopAt, float StartAimingDist)` | build 1207
ped = Ped you want to perform this task.
target = the Entity they should aim at.
distanceToStopAt = distance from the target, where the ped should stop to aim.
StartAimingDist = distance where the ped should start to aim.

## TASK_GOTO_ENTITY_OFFSET
`0xE39B4FF4FDEBDE27` | `void TASK_GOTO_ENTITY_OFFSET(Ped ped, Entity entity, Any p2, float x, float y, float z, int duration)` | build 1207

## TASK_GOTO_ENTITY_OFFSET_XY
`0x338E7EF52B6095A9` | `void TASK_GOTO_ENTITY_OFFSET_XY(Ped ped, Entity entity, int duration, float targetRadius, float xOffset, float yOffset, float moveBlendRatio, int offsetFlags)` | build 1207

## TASK_GOTO_ENTITY_OFFSET_XYZ
`0xFA6DA9D151769392` | `void TASK_GOTO_ENTITY_OFFSET_XYZ(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8)` | build 1311

## TASK_GOTO_ENTITY_OFFSET_XYZ_AIMING
`0x41B0832CA96B5351` | `void TASK_GOTO_ENTITY_OFFSET_XYZ_AIMING(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9)` | build 1207

## TASK_GOTO_ENTITY_OFFSET_XY_AIMING
`0x901BD69984400F62` | `void TASK_GOTO_ENTITY_OFFSET_XY_AIMING(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8)` | build 1207

## TASK_GO_STRAIGHT_TO_COORD
`0xD76B57B44F1E6F8B` | `void TASK_GO_STRAIGHT_TO_COORD(Ped ped, float x, float y, float z, float moveBlendSpeedY, int timeBeforeTeleport, float finalHeading, float targetRadius, int p8)` | build 1207
Tells the ped to go to a coord, without using the navemesh. if timeBeforeTeleport is -1 the ped will never warp, p8 is always 0 or 1 still unknown

## TASK_GO_STRAIGHT_TO_COORD_RELATIVE_TO_ENTITY
`0x61E360B7E040D12E` | `void TASK_GO_STRAIGHT_TO_COORD_RELATIVE_TO_ENTITY(Ped ped, Entity entity, float xOffset, float Yoffset, float zOffset, int moveBlendRatio, int timeBeforeTeleport, int p7)` | build 1207
Tells the ped to go to an offset coord from an entity, without using the navmesh. if timeBeforeTeleport is -1 the ped will never warp, p7 is 1 or 0 still unknown param

## TASK_GO_TO_COORD_AND_AIM_AT_HATED_ENTITIES_NEAR_COORD
`0xA55547801EB331FC` | `void TASK_GO_TO_COORD_AND_AIM_AT_HATED_ENTITIES_NEAR_COORD(Ped ped, float goToLocationX, float goToLocationY, float goToLocationZ, float focusLocationX, float focusLocationY, float focusLocationZ, float speed, BOOL shootAtEnemies, float distanceToStopAt, float noRoadsDistance, BOOL unkTrue, int unkFlag, int aimingFlag, Hash firingPattern)` | build 1207

## TASK_GO_TO_COORD_AND_AIM_AT_HATED_ENTITIES_NEAR_COORD_USING_COMBAT_STYLE
`0x87BD711FC31EA273` | `void TASK_GO_TO_COORD_AND_AIM_AT_HATED_ENTITIES_NEAR_COORD_USING_COMBAT_STYLE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14)` | build 1207

## TASK_GO_TO_COORD_ANY_MEANS
`0x5BC448CB78FA3E88` | `void TASK_GO_TO_COORD_ANY_MEANS(Ped ped, float x, float y, float z, float speed, Entity entity, BOOL p6, int walkingStyle, float p8)` | build 1207

## TASK_GO_TO_COORD_ANY_MEANS_EXTRA_PARAMS
`0x1DD45F9ECFDB1BC9` | `void TASK_GO_TO_COORD_ANY_MEANS_EXTRA_PARAMS(Ped ped, float x, float y, float z, float speed, Any p5, BOOL p6, int walkingStyle, float p8, Any p9, Any p10, Any p11, Any p12)` | build 1207

## TASK_GO_TO_COORD_ANY_MEANS_EXTRA_PARAMS_WITH_CRUISE_SPEED
`0xB8ECD61F531A7B02` | `void TASK_GO_TO_COORD_ANY_MEANS_EXTRA_PARAMS_WITH_CRUISE_SPEED(Ped ped, Vector3* gotoCoords, float cruiseSpeed, Entity entity, int p4, int p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, float cruiseSpeed_2, Any p13, Any p14)` | build 1207
This native allows to control the cruise speed of where you want the ped to go
3rd param might be the entity ped is in? like boat or wagon, 12th param might be the cruiseSpeed of the entity ped is in?
EXAMPLE: TaskGoToCoordAnyMeansExtraParamsWithCruiseSpeed(PlayerPedId(), vector3(x, y, z), 3.0, entity, 1, 0, -1082130432, 0, 101004800, 520, 3.0, 1082130432, 0)

## TASK_GO_TO_COORD_WHILE_AIMING_AT_COORD
`0x11315AB3385B8AC0` | `void TASK_GO_TO_COORD_WHILE_AIMING_AT_COORD(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14, Any p15)` | build 1207

## TASK_GO_TO_COORD_WHILE_AIMING_AT_COORD_USING_COMBAT_STYLE
`0x639C0425A0B4E77E` | `void TASK_GO_TO_COORD_WHILE_AIMING_AT_COORD_USING_COMBAT_STYLE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14, Any p15)` | build 1207

## TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY
`0xB2A16444EAD9AE47` | `void TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Ped ped1, float x, float y, float z, Ped ped2, float p5, Any p6, float p7, float p8, Any p9, Any p10, Any p11, Hash firingPattern, int p13, Any p14)` | build 1207

## TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY_USING_COMBAT_STYLE
`0x78426D0982D083C9` | `void TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY_USING_COMBAT_STYLE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14)` | build 1207

## TASK_GO_TO_ENTITY
`0x6A071245EB0D1882` | `void TASK_GO_TO_ENTITY(Ped ped, Entity target, int duration, float distance, float speed, float p5, int p6)` | build 1207

## TASK_GO_TO_ENTITY_WHILE_AIMING_AT_ENTITY
`0x97465886D35210E9` | `void TASK_GO_TO_ENTITY_WHILE_AIMING_AT_ENTITY(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10)` | build 1207
shootatEntity:
If true, peds will shoot at Entity till it is dead.
If false, peds will just walk till they reach the entity and will cease shooting.

## TASK_GO_TO_ENTITY_WHILE_AIMING_AT_ENTITY_USING_COMBAT_STYLE
`0xCEF0117C233026AD` | `void TASK_GO_TO_ENTITY_WHILE_AIMING_AT_ENTITY_USING_COMBAT_STYLE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10)` | build 1207

## TASK_GO_TO_WHISTLE
`0xBAD6545608CECA6E` | `void TASK_GO_TO_WHISTLE(Ped ped, Ped p1, int whistleType)` | build 1207
enum eWhistleType
{
	WHISTLE_MAIN,
	WHISTLE_SECONDARY,
	WHISTLE_DOUBLE,
	WHISTLE_URGENT,
	WHISTLE_LONG
};

## TASK_GRAPPLE
`0x779A2FFACEFAEA7B` | `BOOL TASK_GRAPPLE(Ped ped, Ped targetPed, Hash grappleStyle, int p3, float p4, int p5, int p6)` | build 1207
grappleStyle: AR_GRAPPLE_MOUNT_STANDING_FROM_FRONT, AR_GRAPPLE_MOUNT_STANDING_FROM_RIGHT, AR_GRAPPLE_MOUNT_STANDING_FROM_BACK, AR_GRAPPLE_MOUNT_STANDING_FROM_LEFT, AR_GRAPPLE_MOUNT_FROM_FRONT, AR_WOLF_EXECUTION_ENTER_FROM_BACK, AR_GRAPPLE_DRAG_FRONT_ON_ASS, AR_GRAPPLE_FRONT_FROM_LEFT_FAR, AR_BEAR_CHALLENGE_FRONT, AR_GRAPPLE_FRONT_FROM_FRONT, AR_GRAPPLE_MOUNT_FACEUP_FROM_FRONT

## TASK_GUARD
`0xB9FB242EACCAF30F` | `void TASK_GUARD(Ped ped, Any p1, Any p2)` | build 1207

## TASK_GUARD_ASSIGNED_DEFENSIVE_AREA
`0xD2A207EEBDF9889B` | `void TASK_GUARD_ASSIGNED_DEFENSIVE_AREA(Ped ped, float p1, float p2, float p3, float p4, float p5, Any p6)` | build 1207

## TASK_GUARD_CURRENT_POSITION
`0x4A58A47A72E3FCB4` | `void TASK_GUARD_CURRENT_POSITION(Ped ped, float p1, float p2, BOOL p3)` | build 1207

## TASK_HANDS_UP
`0xF2EAB31979A7F910` | `void TASK_HANDS_UP(Ped ped, int duration, Ped facingPed, int timeToFacePed, int flags)` | build 1207
flags: 0 = HANDS_UP_NOTHING; 1 = HANDS_UP_STRAIGHT_TO_LOOP

## TASK_HITCH_ANIMAL
`0x9030AD4B6207BFE8` | `void TASK_HITCH_ANIMAL(Ped ped, int scenarioPoint, int flag)` | build 1207

## TASK_HOGTIEABLE
`0x6AFD8FE0D723328F` | `void TASK_HOGTIEABLE(Ped ped)` | build 1207

## TASK_HOGTIE_TARGET_PED
`0x27829AFD3E03AC1A` | `void TASK_HOGTIE_TARGET_PED(Ped ped, Ped targetPed)` | build 1207

## TASK_HORSE_ACTION
`0xA09CFD29100F06C3` | `void TASK_HORSE_ACTION(Ped ped, int action, Ped targetPed, Any p3)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/tasks/TASK_HORSE_ACTION
Params: p2, p3 are set to 0 in R* Scripts

## TASK_INVESTIGATE
`0x5C8514540D27FBFB` | `void TASK_INVESTIGATE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## TASK_JUMP
`0x0AE4086104E067B1` | `void TASK_JUMP(Ped ped, BOOL unused)` | build 1207

## TASK_KNOCKED_OUT
`0xF90427F00A495A28` | `void TASK_KNOCKED_OUT(Ped ped, float p1, BOOL permanently)` | build 1207
Puts the ped into a knocked out state for a specified duration. If 'permanently' is set to true, the ped will remain knocked out until mainually reset. Duration in seconds.

## TASK_KNOCKED_OUT_AND_HOGTIED
`0x42AC6401ABB8C7E5` | `void TASK_KNOCKED_OUT_AND_HOGTIED(Ped ped, float koTimeOffset, int flags)` | build 1207
koTimeOffset (seconds): offset applied to the knockout timer—positive delays recovery (longer KO), negative brings recovery sooner, 0.0 initializes with no extension (immediate baseline).
flags (bitmask): 1 = default variant (forwarded to the KO task ctor; R* commonly uses 1), 2 = sets an unk internal synced toggle for this task, 4 = sets another unk internal synced toggle.

## TASK_LASSO_PED
`0xC716EB2BD16370A3` | `void TASK_LASSO_PED(Ped ped, Ped targetPed)` | build 1207

## TASK_LEAD_AND_CONVERSE
`0xAA19711D33C6708C` | `void TASK_LEAD_AND_CONVERSE(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8)` | build 1207

## TASK_LEAD_HORSE
`0x9A7A4A54596FE09D` | `void TASK_LEAD_HORSE(Ped ped, Ped horse)` | build 1207

## TASK_LEAVE_ANY_VEHICLE
`0x504D54DF3F6F2247` | `void TASK_LEAVE_ANY_VEHICLE(Ped ped, int p1, int taskFlag)` | build 1207
flags: See TASK_ENTER_VEHICLE

## TASK_LEAVE_VEHICLE
`0xD3DBCE61A490BE02` | `void TASK_LEAVE_VEHICLE(Ped ped, Vehicle vehicle, int flags, Ped unkPed)` | build 1207
flags: See TASK_ENTER_VEHICLE

## TASK_LOOK_AT_COORD
`0x6FA46612594F7973` | `void TASK_LOOK_AT_COORD(Ped ped, float x, float y, float z, int duration, int flags, int p6, BOOL p7)` | build 1207

## TASK_LOOK_AT_ENTITY
`0x69F4BE8C8CC4796C` | `void TASK_LOOK_AT_ENTITY(Ped ped, Entity lookAtTarget, int duration, int p3, int p4, int p5)` | build 1207
param3: duration in ms, use -1 to look forever
param4: using 2048 is fine
param5: using 3 is fine

## TASK_LOOT_ENTITY
`0x48FAE038401A2888` | `void TASK_LOOT_ENTITY(Ped ped, Entity entity)` | build 1207

## TASK_LOOT_NEAREST_ENTITY
`0xCF1501CBC4059412` | `void TASK_LOOT_NEAREST_ENTITY(Ped ped, float x, float y, float z, int p4, float p5)` | build 1207

## TASK_MELEE
`0x482C99D0B38D1B0A` | `BOOL TASK_MELEE(Ped ped, Ped targetPed, Hash p2, Any p3, Any p4, float p5, Any p6, float p7)` | build 1207
Params: p2: AR_TAKEDOWN_FRONT, AR_EXECUTION_FRONT, 0 in R* Scripts

## TASK_MOUNT_ANIMAL
`0x92DB0739813C5186` | `void TASK_MOUNT_ANIMAL(Ped ped, Ped mount, int timer, int seatIndex, float pedSpeed, int mountStyle, Any p6, Any p7)` | build 1207
timer: in ms, if it reaches 0 it will auto warp the ped on the horse
mountStyle: See TASK_ENTER_VEHICLE
Flags will still apply to mountStyle

## TASK_MOVE_BE_IN_FORMATION
`0x4AA5AA97C65E4A2F` | `void TASK_MOVE_BE_IN_FORMATION(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## TASK_MOVE_FOLLOW_ROAD_USING_NAVMESH
`0x79482C12482A860D` | `void TASK_MOVE_FOLLOW_ROAD_USING_NAVMESH(Ped ped, float moveBlendRatio, float x, float y, float z, Any p5)` | build 1207
Params: moveBlendRatio commonly 1.25f, p5 is always 0 in R* Scripts

## TASK_MOVE_IN_TRAFFIC
`0x8AA1593AEC087A29` | `void TASK_MOVE_IN_TRAFFIC(Ped ped, Any p1, Any p2, Any p3)` | build 1207

## TASK_MOVE_IN_TRAFFIC_AWAY_FROM_ENTITY
`0x13DED0BC45600FE1` | `void TASK_MOVE_IN_TRAFFIC_AWAY_FROM_ENTITY(Ped ped, Any p1, Any p2, Any p3, Any p4)` | build 1207

## TASK_MOVE_IN_TRAFFIC_TO_DESTINATION
`0xDCA3A13F7A45338B` | `void TASK_MOVE_IN_TRAFFIC_TO_DESTINATION(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## TASK_MOVE_NETWORK_ADVANCED_BY_NAME_WITH_INIT_PARAMS
`0x7B6A04F98BBAFB2C` | `void TASK_MOVE_NETWORK_ADVANCED_BY_NAME_WITH_INIT_PARAMS(Ped ped, char* moveNetworkDefName, Any taskData, float xPos, float yPos, float zPos, float xRot, float yRot, float zRot, int p9, float p10, int p11, int p12, int flag, int p14)` | build 1207

## TASK_MOVE_NETWORK_ADVANCED_BY_NAME_WITH_INIT_PARAMS_ATTACHED
`0xF92171093BCABED4` | `void TASK_MOVE_NETWORK_ADVANCED_BY_NAME_WITH_INIT_PARAMS_ATTACHED(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14, Any p15, Any p16, Any p17)` | build 1207

## TASK_MOVE_NETWORK_BY_NAME
`0x2D537BA194896636` | `void TASK_MOVE_NETWORK_BY_NAME(Ped ped, char* task, float multiplier, BOOL p3, char* animDict, int flags)` | build 1207

## TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS
`0x139805C2A67C4795` | `void TASK_MOVE_NETWORK_BY_NAME_WITH_INIT_PARAMS(Ped ped, char* moveNetworkDefName, Any* taskData, float p3, BOOL p4, char* animDict, int flags)` | build 1207

## TASK_PATROL
`0xBDA5DF49D080FE4E` | `void TASK_PATROL(Ped ped, char* patrolRoute, Any p2, BOOL p3, BOOL p4)` | build 1207

## TASK_PAUSE
`0xE73A266DB0CA9042` | `void TASK_PAUSE(Ped ped, int ms)` | build 1207
This tasks the ped to do nothing for the specified amount of milliseconds.
This is useful if you want to add a delay between tasks when using a sequence task.

## TASK_PED_SLIDE_TO_COORD
`0xD04FE6765D990A06` | `void TASK_PED_SLIDE_TO_COORD(Ped ped, float x, float y, float z, float heading, float p5)` | build 1207

## TASK_PERFORM_SEQUENCE
`0x5ABA3986D90D8A3B` | `void TASK_PERFORM_SEQUENCE(Ped ped, int taskSequenceId)` | build 1207

## TASK_PERFORM_SEQUENCE_FROM_PROGRESS
`0x89221B16730234F0` | `void TASK_PERFORM_SEQUENCE_FROM_PROGRESS(Ped ped, Any p1, Any p2, Any p3)` | build 1207

## TASK_PERFORM_SEQUENCE_LOCALLY
`0x4FC0AF869D6E309D` | `void TASK_PERFORM_SEQUENCE_LOCALLY(Any p0, Any p1, Any p2, Any p3)` | build 1207
Old name: _TASK_PERFORM_SEQUENCE_2

## TASK_PERSISTENT_CHARACTER
`0x4391700CBD89C3D8` | `void TASK_PERSISTENT_CHARACTER(Ped ped)` | build 1207

## TASK_PICKUP_CARRIABLE_ENTITY
`0x502EC17B1BED4BFA` | `void TASK_PICKUP_CARRIABLE_ENTITY(Ped ped, Entity entity)` | build 1207

## TASK_PICK_UP_WEAPON
`0x55B0ECFD98596624` | `void TASK_PICK_UP_WEAPON(Ped ped, Any p1)` | build 1207

## TASK_PLACE_CARRIED_ENTITY_AT_COORD
`0xC7F0B43DCDC57E3D` | `void TASK_PLACE_CARRIED_ENTITY_AT_COORD(Ped ped, Entity entity, float x, float y, float z, float p5, int flags)` | build 1207

## TASK_PLACE_CARRIED_ENTITY_ON_MOUNT
`0x6D3D87C57B3D52C7` | `void TASK_PLACE_CARRIED_ENTITY_ON_MOUNT(Ped ped, Entity entity, Ped mount, float p3)` | build 1207

## TASK_PLANT_BOMB
`0x965FEC691D55E9BF` | `void TASK_PLANT_BOMB(Ped ped, float x, float y, float z, float heading)` | build 1207

## TASK_PLAY_ANIM
`0xEA47FE3719165B94` | `void TASK_PLAY_ANIM(Ped ped, char* animDict, char* animName, float speed, float speedMultiplier, int duration, int flags, float playbackRate, BOOL p8, int ikFlags, BOOL p10, char* taskFilter, BOOL p12)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/animations

flags: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eScriptedAnimFlags

ikFlags: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eIkControlFlags 

animFilters: https://pastebin.com/1sGhKVvS

## TASK_PLAY_ANIM_ADVANCED
`0x83CDB10EA29B370B` | `void TASK_PLAY_ANIM_ADVANCED(Ped ped, char* animDict, char* animName, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float speed, float speedMultiplier, int duration, int flags, float p13, int p14, int p15, int p16)` | build 1207
flags: see TASK_PLAY_ANIM
ikFlags: see TASK_PLAY_ANIM

## TASK_PLAY_EMOTE_WITH_HASH
`0xB31A277C1AC7B7FF` | `void TASK_PLAY_EMOTE_WITH_HASH(Ped ped, int emoteType, int playbackMode, Hash emote, BOOL isSecondaryTask, BOOL canBreakOut, BOOL disableEarlyOutAnimTag, BOOL ignoreInvalidMainTask, BOOL destroyProps)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/animations/kit_emotes_list.lua
emote: https://alloc8or.re/rdr3/doc/enums/eEmote.txt

enum eEmoteType
{
	EMOTE_TYPE_INVALID = -1,
	EMOTE_TYPE_REACT,
	EMOTE_TYPE_ACTION,
	EMOTE_TYPE_TAUNT,
	EMOTE_TYPE_GREET,
	EMOTE_TYPE_TWIRL_GUN,
	EMOTE_TYPE_DANCE_FLOOR
};

enum eEmotePlaybackMode
{
	EMOTE_PM_INVALID = -1,
	EMOTE_PM_UPPERBODY,
	EMOTE_PM_UPPERBODY_LOOP,
	EMOTE_PM_FULLBODY,
};

## TASK_PLAY_UPPER_ANIM_FACING_ENTITY
`0xAD67214236AB1CFE` | `void TASK_PLAY_UPPER_ANIM_FACING_ENTITY(Ped ped, char* animDict, char* animName, Entity entity, int p4, float p5, float p6, int p7, float p8, BOOL p9, BOOL p10, float p11, char* p12, int p13, float p14)` | build 1207

## TASK_POLICE
`0x87BE56724650408E` | `BOOL TASK_POLICE(Ped ped, BOOL p1)` | build 1207

## TASK_PUT_PED_DIRECTLY_INTO_COVER
`0x4172393E6BE1FECE` | `void TASK_PUT_PED_DIRECTLY_INTO_COVER(Ped ped, float x, float y, float z, int timeout, BOOL p5, float p6, Any p7, Any p8, ScrHandle coverpoint, BOOL p10, BOOL p11, Any p12)` | build 1207

## TASK_PUT_PED_DIRECTLY_INTO_GRAPPLE
`0xA05F3F20889D7A5B` | `void TASK_PUT_PED_DIRECTLY_INTO_GRAPPLE(Ped ped, Ped grappleTarget, Hash grappleStyle, float p3, float p4, BOOL p5, int p6)` | build 1207
grappleStyle: AR_GRAPPLE_STRUGGLE, AR_ALLIGATOR_LEG_GRAB_CHALLENGE_FAIL, AR_GRAPPLE_BACK_FROM_BACK, AR_GRAPPLE_BACK_DEFEND, AR_GRAPPLE_FRONT_FROM_FRONT

## TASK_PUT_PED_DIRECTLY_INTO_MELEE
`0x1C6CD14A876FFE39` | `void TASK_PUT_PED_DIRECTLY_INTO_MELEE(Ped ped, Ped meleeTarget, Hash meleeStyle, float p3, float animBlendRatio, BOOL p5, int p6)` | build 1207
meleeStyles: AR_GRAPPLE_BACK_FROM_BACK, AR_GRAPPLE_MOUNT_FACEDOWN_FROM_FRONT, AR_ALLIGATOR_LEAPKILL, AR_ALLIGATOR_WAIST_AUTOKILL_FRONT

## TASK_REACT
`0xC4C32C31920E1B70` | `void TASK_REACT(Ped ped, Entity reactingTo, float x, float y, float z, char* reactionName, float p6, float p7, int p8)` | build 1207
Makes a ped react to an entity.
Params: reactingTo Entity can be 0, p8 is always 4

## TASK_RELOAD_WEAPON
`0x62D2916F56B9CD2D` | `void TASK_RELOAD_WEAPON(Ped ped, BOOL unused)` | build 1207
ped can't reload and walk, setting ammo needs to be set after using this or it will not make the animation reload, wont work if you are in first person

## TASK_REVIVE_TARGET
`0x356088527D9EBAAD` | `void TASK_REVIVE_TARGET(Ped ped, Ped reviver, Hash tool)` | build 1207

## TASK_RIDE_TRAIN
`0x37FB1C870E2EC2C6` | `void TASK_RIDE_TRAIN(Ped ped, Vehicle train, int scenarioPoint, Hash scenarioHash)` | build 1207

## TASK_ROB_PED
`0x7BB967F85D8CCBDB` | `void TASK_ROB_PED(Ped ped, Any target, Any p2, int flag, Any p4)` | build 1207

## TASK_SCRIPTED_ANIMATION
`0x126EF75F1E17ABE5` | `void TASK_SCRIPTED_ANIMATION(Ped ped, Any* args)` | build 1207

## TASK_SEEK_CLEAR_LOS_TO_ENTITY
`0x8D7F2A63688C20A4` | `void TASK_SEEK_CLEAR_LOS_TO_ENTITY(Ped ped, Entity entity, float p2, float p3, float p4)` | build 1207

## TASK_SEEK_COVER_FROM_PED
`0x84D32B3BEC531324` | `void TASK_SEEK_COVER_FROM_PED(Ped ped, Ped fromPed, int duration, Any p3, Any p4, Any p5)` | build 1207

## TASK_SEEK_COVER_FROM_POS
`0x75AC2B60386D89F2` | `void TASK_SEEK_COVER_FROM_POS(Ped ped, float x, float y, float z, int duration, Any p5, Any p6, Any p7)` | build 1207

## TASK_SEEK_COVER_TO_COORDS
`0x39246A6958EF072C` | `void TASK_SEEK_COVER_TO_COORDS(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10)` | build 1207

## TASK_SEEK_COVER_TO_COVER_POINT
`0xD43D95C7A869447F` | `void TASK_SEEK_COVER_TO_COVER_POINT(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8)` | build 1207

## TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS
`0x90D2156198831D69` | `void TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Ped ped, BOOL toggle)` | build 1207

## TASK_SET_CROUCH_MOVEMENT
`0x17293C633C8AC019` | `void TASK_SET_CROUCH_MOVEMENT(Ped ped, BOOL p1, Any p2, BOOL p3)` | build 1207

## TASK_SET_SPHERE_DEFENSIVE_AREA
`0x933C06518B52A9A4` | `void TASK_SET_SPHERE_DEFENSIVE_AREA(Ped ped, float p1, float p2, float p3, float p4)` | build 1207

## TASK_SET_STEALTH_MOVEMENT
`0x4C3FA937B44A90FA` | `void TASK_SET_STEALTH_MOVEMENT(Ped ped, BOOL p1, Any p2, BOOL p3)` | build 1207

## TASK_SHOCKING_EVENT_REACT
`0x452419CBD838065B` | `void TASK_SHOCKING_EVENT_REACT(Ped ped, Any p1, Any p2)` | build 1207

## TASK_SHOOT_AT_COORD
`0x46A6CC01E0826106` | `void TASK_SHOOT_AT_COORD(Ped ped, float x, float y, float z, int duration, Hash firingPattern, Any p6)` | build 1207

## TASK_SHOOT_AT_ENTITY
`0x08DA95E8298AE772` | `void TASK_SHOOT_AT_ENTITY(Entity entity, Entity targetEntity, int duration, Hash firingPattern, BOOL affectCockedState)` | build 1207

## TASK_SHOOT_WITH_WEAPON
`0x08AA95E8298AE772` | `void TASK_SHOOT_WITH_WEAPON(Ped ped, Any* args)` | build 1207

## TASK_SHUFFLE_TO_NEXT_VEHICLE_SEAT
`0x7AA80209BDA643EB` | `void TASK_SHUFFLE_TO_NEXT_VEHICLE_SEAT(Ped ped, Vehicle vehicle)` | build 1207
Makes the specified ped shuffle to the next vehicle seat.
The ped MUST be in a vehicle and the vehicle parameter MUST be the ped's current vehicle.

## TASK_SMART_FLEE_COORD
`0x94587F17E9C365D5` | `void TASK_SMART_FLEE_COORD(Ped ped, float x, float y, float z, float distance, int time, int fleeType, float fleeSpeed)` | build 1207
Makes the specified ped flee the specified distance from the specified position.
fleeType: see TASK_FLEE_COORD

## TASK_SMART_FLEE_PED
`0x22B0D0E37CCB840D` | `void TASK_SMART_FLEE_PED(Ped ped, Ped fleeFromTarget, float fleeDistance, int fleeTime, int fleeType, float fleeSpeed, Ped targetPed)` | build 1207
Makes a ped run away from another ped (fleeFromTarget)

fleeDistance = ped will flee this distance
fleeTime = ped will flee for this amount of time, set to "-1" to flee forever
fleeType = see TASK_FLEE_COORD, can be 0, R* Scripts: fm_mission/race_controller: 66048; fme_escaped_convicts: 2260992, 2523136, 2359296; la_alligator/fox: 2097152; net_fetch: 17301536; net_stable_mount: 540928
fleeSpeed = mostly 3f, rarely 1f in R* Scripts

## TASK_STAND_GUARD
`0xAE032F8BBA959E90` | `void TASK_STAND_GUARD(Ped ped, float x, float y, float z, float heading, char* scenarioName)` | build 1207

## TASK_STAND_STILL
`0x919BE13EED931959` | `void TASK_STAND_STILL(Ped ped, int time)` | build 1207
Makes the specified ped stand still for (time) milliseconds.

## TASK_START_SCENARIO_AT_POSITION
`0x4D1F61FC34AF3CD1` | `void TASK_START_SCENARIO_AT_POSITION(Ped ped, Hash scenarioHash, float x, float y, float z, float heading, int duration, BOOL sittingScenario, BOOL teleport, char* p9, float p10, BOOL p11)` | build 1207

## TASK_START_SCENARIO_IN_PLACE_HASH
`0x524B54361229154F` | `void TASK_START_SCENARIO_IN_PLACE_HASH(Ped ped, Hash scenarioHash, int duration, BOOL playEnterAnim, Hash conditionalHash, float heading, BOOL idleForever)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/animations/scenarios
Params: duration in milliseconds

conditionalHash (optionally):
0 = play random conditional anim.
Every conditional anim has requirements to play it.
If requirements are not met, ped plays random allowed conditional anim or can be stuck.
For example, this scenario type has possible conditional anim WORLD_HUMAN_LEAN_BACK_WALL_SMOKING_MALE_D, but it can not be played by player, because condition is set to NOT be CAIConditionIsPlayer (check file amb_rest.meta and amb_rest_CA.meta with OPENIV to clarify requirements).

## TASK_STAY_IN_COVER
`0xE5DA8615A6180789` | `void TASK_STAY_IN_COVER(Ped ped)` | build 1207
Makes the ped run to take cover

## TASK_STOP_LEADING_HORSE
`0xED27560703F37258` | `void TASK_STOP_LEADING_HORSE(Ped ped)` | build 1207

## TASK_SWAP_FISHING_BAIT
`0x2C28AC30A72722DA` | `void TASK_SWAP_FISHING_BAIT(Ped ped, char* bait, BOOL withoutBuoy)` | build 1207
Baits: see 0x9B0C7FA063E67629

## TASK_SWAP_WEAPON
`0xA21C51255B205245` | `void TASK_SWAP_WEAPON(Ped ped, Any p1, Any p2, Any p3, Any p4)` | build 1207

## TASK_THROW_PROJECTILE
`0x7285951DBF6B5A51` | `void TASK_THROW_PROJECTILE(Ped ped, Any p1, Any p2, Any p3)` | build 1207

## TASK_TURN_PED_TO_FACE_COORD
`0x1DDA930A0AC38571` | `void TASK_TURN_PED_TO_FACE_COORD(Ped ped, float x, float y, float z, int duration)` | build 1207
duration in milliseconds

## TASK_TURN_PED_TO_FACE_ENTITY
`0x5AD23D40115353AC` | `void TASK_TURN_PED_TO_FACE_ENTITY(Ped ped, Entity targetEntity, int duration, float p3, float p4, float p5)` | build 1207
duration: the amount of time in milliseconds to do the task. -1 will keep the task going until either another task is applied, or CLEAR_ALL_TASKS() is called with the ped

## TASK_TURN_TO_FACE_CLOSEST_PED
`0x84179419DBDD36F2` | `void TASK_TURN_TO_FACE_CLOSEST_PED(Ped ped, float p1, float p2, int p3)` | build 1207

## TASK_USE_NEAREST_SCENARIO_CHAIN_TO_COORD
`0x9FDA1B3D7E7028B3` | `void TASK_USE_NEAREST_SCENARIO_CHAIN_TO_COORD(Ped ped, float x, float y, float z, float distance, BOOL p5, BOOL p6, BOOL p7, BOOL p8)` | build 1207

## TASK_USE_NEAREST_SCENARIO_CHAIN_TO_COORD_WARP
`0x97A28E63F0BA5631` | `void TASK_USE_NEAREST_SCENARIO_CHAIN_TO_COORD_WARP(Ped ped, float x, float y, float z, float distance, BOOL p5, BOOL p6, BOOL p7, BOOL p8)` | build 1207

## TASK_USE_NEAREST_SCENARIO_TO_COORD_WARP
`0x58E2E0F23F6B76C3` | `void TASK_USE_NEAREST_SCENARIO_TO_COORD_WARP(Ped ped, float x, float y, float z, float distance, int duration, BOOL p6, BOOL p7, BOOL p8, BOOL p9)` | build 1207

## TASK_USE_NEAREST_TRAIN_SCENARIO_TO_COORD_WARP
`0x3774B03456DD6106` | `void TASK_USE_NEAREST_TRAIN_SCENARIO_TO_COORD_WARP(Ped ped, float x, float y, float z, float distance)` | build 1207

## TASK_USE_RANDOM_SCENARIO_IN_GROUP
`0x14747F4A5971DE4E` | `void TASK_USE_RANDOM_SCENARIO_IN_GROUP(Ped ped, Any p1, Any p2, Any p3, Any p4)` | build 1207

## TASK_USE_SCENARIO_POINT
`0xCCDAE6324B6A821C` | `void TASK_USE_SCENARIO_POINT(Ped ped, int scenario, const char* conditionalAnim, int p3, BOOL p4, BOOL p5, Hash p6, BOOL p7, float p8, BOOL p9)` | build 1207

## TASK_VEHICLE_AIM_AT_COORD
`0x447C1E9EF844BC0F` | `void TASK_VEHICLE_AIM_AT_COORD(Ped ped, float x, float y, float z)` | build 1207

## TASK_VEHICLE_AIM_AT_PED
`0xE41885592B08B097` | `void TASK_VEHICLE_AIM_AT_PED(Ped ped, Ped target)` | build 1207

## TASK_VEHICLE_DRIVE_STRAIGHT_TO_POINT
`0x089FF2FB965F0A29` | `void TASK_VEHICLE_DRIVE_STRAIGHT_TO_POINT(Ped driver, Vehicle vehicle, float x, float y, float z, float p5, float p6, int flag)` | build 1207
Old name: _TASK_VEHICLE_DRIVE_TO_POINT
flag: 524419 and 0 in shop_horse_shop R* Script

## TASK_VEHICLE_DRIVE_TO_COORD
`0xE2A2AA2F659D77A7` | `void TASK_VEHICLE_DRIVE_TO_COORD(Ped ped, Vehicle vehicle, float x, float y, float z, float speed, Any style, Hash vehicleModel, int drivingMode, float stopRange, float straightLineDist)` | build 1207
stopRange: how close vehicle will get to destination before stopping, default 4.0
straightLineDist: distance at which AI switches to heading for target directly instead of following nodes, default -1

## TASK_VEHICLE_DRIVE_TO_DESTINATION
`0x7F241A0D14354583` | `void TASK_VEHICLE_DRIVE_TO_DESTINATION(Ped driver, Vehicle vehicle, float x, float y, float z, float speed, int drivingFlags, int p7, float stoppingRange1, float stoppingRange2, BOOL p10)` | build 1207
flags: 67108864, 2097152, 524564, 524675 (eDrivingFlags)
p7 = 6 or 3
p8 = x coordinate
p9 - 8.f
p10 = false

## TASK_VEHICLE_DRIVE_WANDER
`0x480142959D337D00` | `void TASK_VEHICLE_DRIVE_WANDER(Ped ped, Vehicle vehicle, float speed, int drivingStyle)` | build 1207

## TASK_VEHICLE_ESCORT
`0x0FA6E4B75F302400` | `void TASK_VEHICLE_ESCORT(Ped ped, Vehicle vehicle, Vehicle targetVehicle, int mode, float speed, int drivingStyle, float minDistance, int p7, float noRoadsDistance)` | build 1207

## TASK_VEHICLE_FOLLOW_WAYPOINT_RECORDING
`0x3123FAA6DB1CF7ED` | `void TASK_VEHICLE_FOLLOW_WAYPOINT_RECORDING(Ped ped, Vehicle vehicle, char* waypointRecording, int drivingMode, Any p4, int eWaypoint, int flag, float p7, BOOL p8, float stoppingDist, Any p10)` | build 1207

## TASK_VEHICLE_GOTO_NAVMESH
`0x195AEEB13CEFE2EE` | `void TASK_VEHICLE_GOTO_NAVMESH(Ped ped, Vehicle vehicle, float x, float y, float z, float speed, int behaviorFlag, float stoppingRange)` | build 1207

## TASK_VEHICLE_MISSION
`0x659427E0EF36BCDE` | `void TASK_VEHICLE_MISSION(Ped driver, Vehicle vehicle, Vehicle vehicleTarget, int missionType, float p4, Any p5, float p6, float p7, BOOL DriveAgainstTraffic)` | build 1207

## TASK_VEHICLE_MISSION_PED_TARGET
`0x9454528DF15D657A` | `void TASK_VEHICLE_MISSION_PED_TARGET(Ped ped, Vehicle vehicle, Ped pedTarget, int mode, float maxSpeed, int drivingStyle, float minDistance, float p7, BOOL DriveAgainstTraffic)` | build 1207
See TASK_VEHICLE_MISSION

## TASK_VEHICLE_SHOOT_AT_COORD
`0x5190796ED39C9B6D` | `void TASK_VEHICLE_SHOOT_AT_COORD(Ped ped, float x, float y, float z, float p4)` | build 1207

## TASK_VEHICLE_SHOOT_AT_PED
`0x10AB107B887214D8` | `void TASK_VEHICLE_SHOOT_AT_PED(Ped ped, Ped target, float p2)` | build 1207

## TASK_VEHICLE_TEMP_ACTION
`0xC429DCEEB339E129` | `void TASK_VEHICLE_TEMP_ACTION(Ped driver, Vehicle vehicle, int action, int time)` | build 1207
Documentation from GTA V, might be the same in RDR:

'1 - brake
'3 - brake + reverse
'4 - turn left 90 + braking
'5 - turn right 90 + braking
'6 - brake strong (handbrake?) until time ends
'7 - turn left + accelerate
'7 - turn right + accelerate
'9 - weak acceleration
'10 - turn left + restore wheel pos to center in the end
'11 - turn right + restore wheel pos to center in the end
'13 - turn left + go reverse
'14 - turn left + go reverse
'16 - crash the game after like 2 seconds :)
'17 - keep actual state, game crashed after few tries
'18 - game crash
'19 - strong brake + turn left/right
'20 - weak brake + turn left then turn right
'21 - weak brake + turn right then turn left
'22 - brake + reverse
'23 - accelerate fast
'24 - brake
'25 - brake turning left then when almost stopping it turns left more
'26 - brake turning right then when almost stopping it turns right more
'27 - brake until car stop or until time ends
'28 - brake + strong reverse acceleration
'30 - performs a burnout (brake until stop + brake and accelerate)
'31 - accelerate + handbrake
'32 - accelerate very strong

Seems to be this:
Works on NPCs, but overrides their current task. If inside a task sequence (and not being the last task), "time" will work, otherwise the task will be performed forever until tasked with something else

## TASK_WALK_AWAY
`0x04ACFAC71E6858F9` | `void TASK_WALK_AWAY(Ped ped, Entity entity)` | build 1207

## TASK_WANDER_AND_CONVERSE_WITH_PED
`0x8AC76D1408731732` | `void TASK_WANDER_AND_CONVERSE_WITH_PED(Ped ped, Any p1, Any p2, Any p3)` | build 1207

## TASK_WANDER_IN_AREA
`0xE054346CA3A0F315` | `void TASK_WANDER_IN_AREA(Ped ped, float x, float y, float z, float radius, float p5, float p6, int p7)` | build 1207

## TASK_WANDER_IN_VOLUME
`0x9FDA168777B28424` | `void TASK_WANDER_IN_VOLUME(Ped ped, Volume volume, float p2, float p3, int p4)` | build 1207

## TASK_WANDER_STANDARD
`0xBB9CE077274F6A1B` | `void TASK_WANDER_STANDARD(Ped ped, float p1, int p2)` | build 1207
Makes ped walk around the area the params p1 p2 seems to not affect anything but p2 is either 0 or 1 and p1 is mostly 1.0 or ped heading

## TASK_WANDER_SWIM
`0x527EA3DB8BC7F03B` | `void TASK_WANDER_SWIM(Ped ped, Any p1)` | build 1207

## TASK_WARP_PED_INTO_VEHICLE
`0x9A7D091411C5F684` | `void TASK_WARP_PED_INTO_VEHICLE(Ped ped, Vehicle vehicle, int seat)` | build 1207

## TASK_WEAPON
`0x7157B82D60E4BC46` | `void TASK_WEAPON(Ped ped)` | build 1207

## TASK_WHISTLE_ANIM
`0xD6401A1B2F63BED6` | `void TASK_WHISTLE_ANIM(Ped ped, Hash audPedWhistleType, Hash p2)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/AI/EVENTS/aud_ped_whistle_types.lua
p2: UNSPECIFIED

## UNCUFF_PED
`0x67406F2C8F87FC4F` | `void UNCUFF_PED(Ped ped)` | build 1207

## UNHOGTIE_PED
`0x79559BAD83CCD038` | `void UNHOGTIE_PED(Ped ped, int flags, Hash getupSetHash, char* p3, char* p4, float p5)` | build 1207
getupSetHash: see nm_blend_out_sets.meta

## UPDATE_TASK_HANDS_UP_DURATION
`0xA98FCAFD7893C834` | `void UPDATE_TASK_HANDS_UP_DURATION(Ped ped, int duration)` | build 1207

## USE_WAYPOINT_RECORDING_AS_ASSISTED_MOVEMENT_ROUTE
`0x5A353B8E6B1095B5` | `void USE_WAYPOINT_RECORDING_AS_ASSISTED_MOVEMENT_ROUTE(char* waypointRecording, BOOL p1, float p2, float p3, BOOL p4)` | build 1207

## VEHICLE_WAYPOINT_PLAYBACK_GET_IS_PAUSED
`0x4D6D30AB18B0B089` | `Any VEHICLE_WAYPOINT_PLAYBACK_GET_IS_PAUSED(Any p0)` | build 1207

## VEHICLE_WAYPOINT_PLAYBACK_OVERRIDE_SPEED
`0x121F0593E0A431D7` | `void VEHICLE_WAYPOINT_PLAYBACK_OVERRIDE_SPEED(Vehicle vehicle, float speed)` | build 1207

## VEHICLE_WAYPOINT_PLAYBACK_PAUSE
`0x8A4E6AC373666BC5` | `void VEHICLE_WAYPOINT_PLAYBACK_PAUSE(Vehicle vehicle)` | build 1207

## VEHICLE_WAYPOINT_PLAYBACK_RESUME
`0xDC04FCAA7839D492` | `void VEHICLE_WAYPOINT_PLAYBACK_RESUME(Vehicle vehicle)` | build 1207

## VEHICLE_WAYPOINT_PLAYBACK_USE_DEFAULT_SPEED
`0x5CEB25A7D2848963` | `void VEHICLE_WAYPOINT_PLAYBACK_USE_DEFAULT_SPEED(Vehicle vehicle)` | build 1207

## WAYPOINT_PLAYBACK_GET_IS_AIMING
`0xD73A5D1F0325C71C` | `BOOL WAYPOINT_PLAYBACK_GET_IS_AIMING(Ped ped)` | build 1207

## WAYPOINT_PLAYBACK_GET_IS_PAUSED
`0x701375A7D43F01CB` | `BOOL WAYPOINT_PLAYBACK_GET_IS_PAUSED(Ped ped)` | build 1207

## WAYPOINT_PLAYBACK_GET_IS_SHOOTING
`0xA5B94DF8AF058F46` | `BOOL WAYPOINT_PLAYBACK_GET_IS_SHOOTING(Ped ped)` | build 1207

## WAYPOINT_PLAYBACK_OVERRIDE_SPEED
`0x7D7D2B47FA788E85` | `void WAYPOINT_PLAYBACK_OVERRIDE_SPEED(Ped ped, float speed, Any p2, Any p3, Any p4)` | build 1207

## WAYPOINT_PLAYBACK_PAUSE
`0x0F342546AA06FED5` | `void WAYPOINT_PLAYBACK_PAUSE(Ped ped, Any p1, Any p2, Any p3)` | build 1207

## WAYPOINT_PLAYBACK_RESUME
`0x244F70C84C547D2D` | `void WAYPOINT_PLAYBACK_RESUME(Ped ped, BOOL p1, int p2, int p3)` | build 1207

## WAYPOINT_PLAYBACK_START_AIMING_AT_COORD
`0x8968400D900ED8B3` | `void WAYPOINT_PLAYBACK_START_AIMING_AT_COORD(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## WAYPOINT_PLAYBACK_START_AIMING_AT_ENTITY
`0x4F158205E0C74385` | `void WAYPOINT_PLAYBACK_START_AIMING_AT_ENTITY(Any p0, Any p1, Any p2, Any p3)` | build 1207

## WAYPOINT_PLAYBACK_START_AIMING_AT_PED
`0x20E330937C399D29` | `void WAYPOINT_PLAYBACK_START_AIMING_AT_PED(Any p0, Any p1, Any p2, Any p3)` | build 1207

## WAYPOINT_PLAYBACK_START_SHOOTING_AT_COORD
`0x057A25CFCC9DB671` | `void WAYPOINT_PLAYBACK_START_SHOOTING_AT_COORD(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## WAYPOINT_PLAYBACK_START_SHOOTING_AT_ENTITY
`0x4AF458F71C1196D2` | `void WAYPOINT_PLAYBACK_START_SHOOTING_AT_ENTITY(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## WAYPOINT_PLAYBACK_START_SHOOTING_AT_PED
`0xE70BA7B90F8390DC` | `void WAYPOINT_PLAYBACK_START_SHOOTING_AT_PED(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## WAYPOINT_PLAYBACK_STOP_AIMING_OR_SHOOTING
`0x47EFA040EBB8E2EA` | `void WAYPOINT_PLAYBACK_STOP_AIMING_OR_SHOOTING(Any p0)` | build 1207

## WAYPOINT_PLAYBACK_USE_DEFAULT_SPEED
`0x6599D834B12D0800` | `void WAYPOINT_PLAYBACK_USE_DEFAULT_SPEED(Ped ped)` | build 1207

## WAYPOINT_RECORDING_GET_CLOSEST_WAYPOINT
`0xB629A298081F876F` | `BOOL WAYPOINT_RECORDING_GET_CLOSEST_WAYPOINT(char* waypointRecording, float x, float y, float z, int point)` | build 1207

## WAYPOINT_RECORDING_GET_COORD
`0x2FB897405C90B361` | `BOOL WAYPOINT_RECORDING_GET_COORD(char* waypointRecording, int point, Vector3* coord)` | build 1207

## WAYPOINT_RECORDING_GET_NUM_POINTS
`0x5343532C01A07234` | `BOOL WAYPOINT_RECORDING_GET_NUM_POINTS(char* waypointRecording, int points)` | build 1207

## WAYPOINT_RECORDING_GET_SPEED_AT_POINT
`0x005622AEBC33ACA9` | `float WAYPOINT_RECORDING_GET_SPEED_AT_POINT(char* waypointRecording, int point)` | build 1207

## _0x0000A8ACDC2E1B6A
`0x0000A8ACDC2E1B6A` | `void _0x0000A8ACDC2E1B6A(Any p0, Any p1)` | build 1207

## _0x00FFE0F85253C572
`0x00FFE0F85253C572` | `Any _0x00FFE0F85253C572(Any p0)` | build 1207

## _0x0365000D8BF86531
`0x0365000D8BF86531` | `Any _0x0365000D8BF86531(Any p0)` | build 1207

## _0x098036CAB8373D36
`0x098036CAB8373D36` | `void _0x098036CAB8373D36(Any p0)` | build 1207

## _0x098CAA6DBE7D8D82
`0x098CAA6DBE7D8D82` | `void _0x098CAA6DBE7D8D82(Any p0, Any p1)` | build 1207

## _0x0A98A362C5A19A43
`0x0A98A362C5A19A43` | `Any _0x0A98A362C5A19A43(Any p0)` | build 1207

## _0x0D322AEF8878B8FE
`0x0D322AEF8878B8FE` | `void _0x0D322AEF8878B8FE(Any p0, Any p1)` | build 1207

## _0x0E184495B27BB57D
`0x0E184495B27BB57D` | `void _0x0E184495B27BB57D()` | build 1207

## _0x0F4F6C4CE471259D
`0x0F4F6C4CE471259D` | `void _0x0F4F6C4CE471259D(Any p0, Any p1)` | build 1207

## _0x10ADFDF07B7DFFBA
`0x10ADFDF07B7DFFBA` | `Any _0x10ADFDF07B7DFFBA(Any p0, Any p1, Any p2)` | build 1207

## _0x10C44F633E2D6D9E
`0x10C44F633E2D6D9E` | `void _0x10C44F633E2D6D9E(Any p0)` | build 1207

## _0x11C7CE1AE38911B5
`0x11C7CE1AE38911B5` | `Any _0x11C7CE1AE38911B5(Any p0)` | build 1207

## _0x152664AA3188B193
`0x152664AA3188B193` | `Any _0x152664AA3188B193(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0x1632EB9386CDBE64
`0x1632EB9386CDBE64` | `void _0x1632EB9386CDBE64(Any p0, Any p1)` | build 1207

## _0x19BC99C678FBA139
`0x19BC99C678FBA139` | `void _0x19BC99C678FBA139(Any p0, Any p1, Any p2)` | build 1207

## _0x1A7D63CB1B0BB223
`0x1A7D63CB1B0BB223` | `void _0x1A7D63CB1B0BB223(Any p0)` | build 1207

## _0x1AC5A8AB50CFAA33
`0x1AC5A8AB50CFAA33` | `Any _0x1AC5A8AB50CFAA33(Any p0)` | build 1207

## _0x1F298C7BD30D1240
`0x1F298C7BD30D1240` | `void _0x1F298C7BD30D1240(Ped ped)` | build 1207

## _0x1F7A9A9C38C13A56
`0x1F7A9A9C38C13A56` | `Any _0x1F7A9A9C38C13A56(Any p0)` | build 1207

## _0x2064B33F6E6B92D4
`0x2064B33F6E6B92D4` | `void _0x2064B33F6E6B92D4(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x22CD2C33ED4467A1
`0x22CD2C33ED4467A1` | `Any _0x22CD2C33ED4467A1(Any p0)` | build 1207

## _0x22CDBF317C40A122
`0x22CDBF317C40A122` | `void _0x22CDBF317C40A122(Ped ped)` | build 1207

## _0x23767D80C7EED7C6
`0x23767D80C7EED7C6` | `void _0x23767D80C7EED7C6(Any p0, Any p1)` | build 1311

## _0x28EF780BDEA8A639
`0x28EF780BDEA8A639` | `void _0x28EF780BDEA8A639(Ped ped, int p1)` | build 1207

## _0x2948235DB2058E99
`0x2948235DB2058E99` | `void _0x2948235DB2058E99(Any p0, Any p1)` | build 1207

## _0x2A10538D0A005E81
`0x2A10538D0A005E81` | `void _0x2A10538D0A005E81(Any p0, Any p1)` | build 1207

## _0x2B8AF29A78024BD3
`0x2B8AF29A78024BD3` | `void _0x2B8AF29A78024BD3(Any p0)` | build 1207

## _0x2C497BDEF897C6DF
`0x2C497BDEF897C6DF` | `Any _0x2C497BDEF897C6DF(Any p0)` | build 1207
_GET_ANIM_SCENE_FROM_PED_*

## _0x2D657B10F211C572
`0x2D657B10F211C572` | `Any _0x2D657B10F211C572(Ped ped, float p1)` | build 1207

## _0x2E1D6D87346BB7D2
`0x2E1D6D87346BB7D2` | `void _0x2E1D6D87346BB7D2(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x2EB977293923C723
`0x2EB977293923C723` | `void _0x2EB977293923C723(Any p0, Any p1)` | build 1207

## _0x30146C25686B7836
`0x30146C25686B7836` | `Any _0x30146C25686B7836(Any p0, Any p1)` | build 1207

## _0x30B391915538EBE2
`0x30B391915538EBE2` | `void _0x30B391915538EBE2(Any p0)` | build 1207

## _0x31BB338F64D5C861
`0x31BB338F64D5C861` | `void _0x31BB338F64D5C861(Ped ped, BOOL p1)` | build 1207

## _0x358A1A751B335A11
`0x358A1A751B335A11` | `void _0x358A1A751B335A11(Any p0)` | build 1207

## _0x370F57C47F68EBCA
`0x370F57C47F68EBCA` | `Any _0x370F57C47F68EBCA(Any p0)` | build 1207

## _0x3BBEECC5B8F35318
`0x3BBEECC5B8F35318` | `void _0x3BBEECC5B8F35318(Any p0, Any p1)` | build 1207

## _0x3F8387DB1B9F31B7
`0x3F8387DB1B9F31B7` | `BOOL _0x3F8387DB1B9F31B7(Any* scriptStruct, BOOL p1)` | build 1207
Used for HORSE_REVIVE

## _0x3FEB770D8ED9047A
`0x3FEB770D8ED9047A` | `Any _0x3FEB770D8ED9047A(Any p0)` | build 1207

## _0x41D1331AFAD5A091
`0x41D1331AFAD5A091` | `void _0x41D1331AFAD5A091(Ped ped, int p1, Any p2)` | build 1207
_SET_PED_*

## _0x450080DDEDB91258
`0x450080DDEDB91258` | `void _0x450080DDEDB91258(Any p0, Any p1)` | build 1207

## _0x4A7D73989F52EB37
`0x4A7D73989F52EB37` | `void _0x4A7D73989F52EB37(Any p0, Any p1)` | build 1207

## _0x4E806A395D43A458
`0x4E806A395D43A458` | `void _0x4E806A395D43A458(Any p0)` | build 1207

## _0x4F57397388E1DFF8
`0x4F57397388E1DFF8` | `void _0x4F57397388E1DFF8()` | build 1207

## _0x508F5053E3F6F0C4
`0x508F5053E3F6F0C4` | `BOOL _0x508F5053E3F6F0C4(Ped ped, float x, float y, float z, float p4)` | build 1207
Only used in R* SP Scripts
Params: p4 = 1.0f - 30.0f

## _0x50AA09A0DA64E73C
`0x50AA09A0DA64E73C` | `void _0x50AA09A0DA64E73C(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0x5217B7B6DB78E1F3
`0x5217B7B6DB78E1F3` | `void _0x5217B7B6DB78E1F3(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x59AE5CA4FFB4E378
`0x59AE5CA4FFB4E378` | `Any _0x59AE5CA4FFB4E378(Any p0, Any p1)` | build 1207

## _0x59AEA4DC640814B9
`0x59AEA4DC640814B9` | `void _0x59AEA4DC640814B9(Any p0, Any p1)` | build 1207

## _0x5B68D0007D9C92EB
`0x5B68D0007D9C92EB` | `void _0x5B68D0007D9C92EB(Any p0, Any p1)` | build 1207

## _0x5D9B0BAAF04CF65B
`0x5D9B0BAAF04CF65B` | `void _0x5D9B0BAAF04CF65B(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x5EA655F01D93667A
`0x5EA655F01D93667A` | `Any _0x5EA655F01D93667A(Any p0)` | build 1207

## _0x615DC4A82E90BB48
`0x615DC4A82E90BB48` | `void _0x615DC4A82E90BB48(Any p0, Any p1, Any p2)` | build 1207

## _0x643FD1556F621772
`0x643FD1556F621772` | `Any _0x643FD1556F621772(Any p0, Any p1, Any p2)` | build 1207

## _0x651F0530083C0E5A
`0x651F0530083C0E5A` | `void _0x651F0530083C0E5A(Any p0, Any p1)` | build 1207

## _0x65D281985F2BDFC2
`0x65D281985F2BDFC2` | `void _0x65D281985F2BDFC2(Any p0, Any p1)` | build 1207

## _0x673A8779D229BA5A
`0x673A8779D229BA5A` | `void _0x673A8779D229BA5A(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0x678D3226CF70B9C8
`0x678D3226CF70B9C8` | `Object _0x678D3226CF70B9C8(Ped ped, BOOL p1)` | build 1207
Only used in R* SP Script beat_washed_ashore
Returns Object prop for TASK::_TASK_ITEM_INTERACTION_2

## _0x6C269F673C47031E
`0x6C269F673C47031E` | `Any _0x6C269F673C47031E(Any p0)` | build 1207

## _0x6DAC799857EF3F11
`0x6DAC799857EF3F11` | `Any _0x6DAC799857EF3F11(Any p0, Any p1)` | build 1311

## _0x722D6A49200174FE
`0x722D6A49200174FE` | `void _0x722D6A49200174FE(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x748D5E0D2A1A4C61
`0x748D5E0D2A1A4C61` | `void _0x748D5E0D2A1A4C61(Any p0, Any p1, Any p2)` | build 1207

## _0x74F0209674864CBD
`0x74F0209674864CBD` | `Any _0x74F0209674864CBD()` | build 1207

## _0x764DB5A48390FBAD
`0x764DB5A48390FBAD` | `void _0x764DB5A48390FBAD(Any p0, Any p1)` | build 1207

## _0x76610D12A838EBDE
`0x76610D12A838EBDE` | `Any _0x76610D12A838EBDE(Any p0)` | build 1311

## _0x7FB78B2199C10E92
`0x7FB78B2199C10E92` | `void _0x7FB78B2199C10E92(Any p0)` | build 1207

## _0x801BD27403F3CBA0
`0x801BD27403F3CBA0` | `void _0x801BD27403F3CBA0(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x827A58CED9D4D5B4
`0x827A58CED9D4D5B4` | `void _0x827A58CED9D4D5B4(Any p0, Any p1)` | build 1207

## _0x82ED59F095056550
`0x82ED59F095056550` | `void _0x82ED59F095056550(Any p0, Any p1)` | build 1207

## _0x865732725536EE39
`0x865732725536EE39` | `Vector3 _0x865732725536EE39(Any p0)` | build 1207

## _0x8798CF6815B8FE0F
`0x8798CF6815B8FE0F` | `void _0x8798CF6815B8FE0F(Any p0, Any p1)` | build 1207

## _0x885D19AC2B6FBFF4
`0x885D19AC2B6FBFF4` | `void _0x885D19AC2B6FBFF4(Any p0, Any p1)` | build 1207

## _0x88FD60D846D9CD63
`0x88FD60D846D9CD63` | `void _0x88FD60D846D9CD63(Ped ped)` | build 1207

## _0x8E1DDE26D270CC5E
`0x8E1DDE26D270CC5E` | `void _0x8E1DDE26D270CC5E(Any p0, Any p1)` | build 1207

## _0x8F8C84363810691A
`0x8F8C84363810691A` | `void _0x8F8C84363810691A(Any p0, Any p1)` | build 1207

## _0x9050DF2C53801208
`0x9050DF2C53801208` | `void _0x9050DF2C53801208(Ped ped, float p1)` | build 1207

## _0x908BB14BCE85C80E
`0x908BB14BCE85C80E` | `Any _0x908BB14BCE85C80E(Any p0)` | build 1207

## _0x91CB5E431F579BA1
`0x91CB5E431F579BA1` | `Vector3 _0x91CB5E431F579BA1(Any p0)` | build 1207

## _0x920684BE432875B1
`0x920684BE432875B1` | `Any _0x920684BE432875B1(Any p0)` | build 1311

## _0x954451EA2D2120FB
`0x954451EA2D2120FB` | `void _0x954451EA2D2120FB(Any p0, Any p1)` | build 1207

## _0x9585FF23C4B8EDE0
`0x9585FF23C4B8EDE0` | `void _0x9585FF23C4B8EDE0(Any p0, Any p1)` | build 1207

## _0x9667CCE29BFA0780
`0x9667CCE29BFA0780` | `void _0x9667CCE29BFA0780(Any p0)` | build 1207

## _0x974DA3408DEC4E79
`0x974DA3408DEC4E79` | `Any _0x974DA3408DEC4E79(Any p0)` | build 1207

## _0x9B6A58FDB0024F12
`0x9B6A58FDB0024F12` | `void _0x9B6A58FDB0024F12(Any p0, Any p1)` | build 1207

## _0x9C8F42A5D1859DC1
`0x9C8F42A5D1859DC1` | `void _0x9C8F42A5D1859DC1(Any p0)` | build 1207

## _0xA052608A12559BBB
`0xA052608A12559BBB` | `void _0xA052608A12559BBB(Any p0, Any p1)` | build 1207

## _0xA263ADBBC8056214
`0xA263ADBBC8056214` | `void _0xA263ADBBC8056214(Any p0, Any p1)` | build 1207

## _0xA42DC7919159CCCF
`0xA42DC7919159CCCF` | `void _0xA42DC7919159CCCF(Any p0)` | build 1207

## _0xA6A76D666A281F2D
`0xA6A76D666A281F2D` | `void _0xA6A76D666A281F2D(Any p0, Hash item)` | build 1207

## _0xA7479FB665361EDB
`0xA7479FB665361EDB` | `void _0xA7479FB665361EDB(Any p0, Any p1)` | build 1207
_SET_SCENARIO_*

## _0xA9E7672F8C6C6F74
`0xA9E7672F8C6C6F74` | `Any _0xA9E7672F8C6C6F74(Any p0)` | build 1207

## _0xADC45010BC17AF0E
`0xADC45010BC17AF0E` | `void _0xADC45010BC17AF0E(Any p0, Any p1)` | build 1207
_SET_SCENARIO_POINT_*

## _0xB2D15D3551FE4FAE
`0xB2D15D3551FE4FAE` | `void _0xB2D15D3551FE4FAE(Any p0)` | build 1311

## _0xB2F47A1AFDFCC595
`0xB2F47A1AFDFCC595` | `void _0xB2F47A1AFDFCC595(Any p0, Any p1)` | build 1207

## _0xB79817DB31FF72B9
`0xB79817DB31FF72B9` | `void _0xB79817DB31FF72B9(Any p0, Any p1)` | build 1207

## _0xB8E3486D107F4194
`0xB8E3486D107F4194` | `void _0xB8E3486D107F4194(Any p0, Any p1)` | build 1207

## _0xBC3F847AE2C3DC65
`0xBC3F847AE2C3DC65` | `void _0xBC3F847AE2C3DC65(Any p0, Any p1)` | build 1207

## _0xBD70108D01875299
`0xBD70108D01875299` | `Any _0xBD70108D01875299(Any p0)` | build 1207

## _0xBEDBE39B5FD98FD6
`0xBEDBE39B5FD98FD6` | `BOOL _0xBEDBE39B5FD98FD6(Ped ped)` | build 1207

## _0xBEEFBB608D2AA68A
`0xBEEFBB608D2AA68A` | `void _0xBEEFBB608D2AA68A(Any p0)` | build 1207

## _0xCE4E669400E5F8AA
`0xCE4E669400E5F8AA` | `void _0xCE4E669400E5F8AA(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xD0ABC4EA3B5E21A0
`0xD0ABC4EA3B5E21A0` | `Any _0xD0ABC4EA3B5E21A0(Any p0, Any p1)` | build 1311

## _0xD999E379265A4501
`0xD999E379265A4501` | `void _0xD999E379265A4501(Any p0, Any p1, Any p2)` | build 1207

## _0xDE0C8B145EA466FF
`0xDE0C8B145EA466FF` | `void _0xDE0C8B145EA466FF(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0xDF56A2B50C04DEA4
`0xDF56A2B50C04DEA4` | `Any _0xDF56A2B50C04DEA4(Any p0, Any p1)` | build 1207

## _0xDF94844D474F31E5
`0xDF94844D474F31E5` | `void _0xDF94844D474F31E5(Ped ped)` | build 1207

## _0xE01C8DC8EDD28D31
`0xE01C8DC8EDD28D31` | `void _0xE01C8DC8EDD28D31(Any p0, Any p1)` | build 1207

## _0xE05A5D39BE6E93AF
`0xE05A5D39BE6E93AF` | `void _0xE05A5D39BE6E93AF(Any p0)` | build 1207

## _0xE116F6F2DA2D777E
`0xE116F6F2DA2D777E` | `Vector3 _0xE116F6F2DA2D777E(Any p0)` | build 1207

## _0xE1C105E6BBA48270
`0xE1C105E6BBA48270` | `Any _0xE1C105E6BBA48270()` | build 1207

## _0xE55478C5EDF70AC2
`0xE55478C5EDF70AC2` | `Any _0xE55478C5EDF70AC2(Any p0)` | build 1207

## _0xE5831AA1E2FD147C
`0xE5831AA1E2FD147C` | `void _0xE5831AA1E2FD147C(Any p0)` | build 1207

## _0xE69FDA40AAC3EFC0
`0xE69FDA40AAC3EFC0` | `void _0xE69FDA40AAC3EFC0(Any p0, Any p1)` | build 1207

## _0xE6A151364C600B24
`0xE6A151364C600B24` | `Any _0xE6A151364C600B24(Any p0)` | build 1207

## _0xE9225354FB7437A7
`0xE9225354FB7437A7` | `void _0xE9225354FB7437A7(Any p0, Any p1)` | build 1207

## _0xE9A6400D1A0E7A55
`0xE9A6400D1A0E7A55` | `Any _0xE9A6400D1A0E7A55(Any p0)` | build 1207

## _0xEAF87DA2BE78A15B
`0xEAF87DA2BE78A15B` | `void _0xEAF87DA2BE78A15B(Any p0, Any p1)` | build 1207

## _0xEBA2081E0A5F4D17
`0xEBA2081E0A5F4D17` | `void _0xEBA2081E0A5F4D17(Entity entity)` | build 1207
in the decompiles seems to always be paired with _CLEAR_VEHICLE_TASKS

## _0xEC516FE805D2CB2D
`0xEC516FE805D2CB2D` | `void _0xEC516FE805D2CB2D(Any p0)` | build 1207

## _0xEFD875C2791EBEFD
`0xEFD875C2791EBEFD` | `Any _0xEFD875C2791EBEFD(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xF718931A82EEB898
`0xF718931A82EEB898` | `void _0xF718931A82EEB898()` | build 1207

## _0xF948F4356F010F11
`0xF948F4356F010F11` | `void _0xF948F4356F010F11(Any p0, Any p1, Any p2)` | build 1207

## _0xF97F462779B31786
`0xF97F462779B31786` | `Any _0xF97F462779B31786(Any p0)` | build 1207

## _0xFA30E2254461ADEB
`0xFA30E2254461ADEB` | `void _0xFA30E2254461ADEB(Any p0, Any p1)` | build 1207

## _0xFDECCA06E8B81346
`0xFDECCA06E8B81346` | `Any _0xFDECCA06E8B81346(Ped ped)` | build 1207

## _0xFE5D28B9B7837CC1
`0xFE5D28B9B7837CC1` | `Any _0xFE5D28B9B7837CC1(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xFF8AFCA532B500D4
`0xFF8AFCA532B500D4` | `void _0xFF8AFCA532B500D4(Any p0, Any p1)` | build 1207

## _ADD_COVERPOINT_FOR_ENTITY
`0x59872EA4CBD11C56` | `int _ADD_COVERPOINT_FOR_ENTITY(Entity entity, float xOffset, float yOffset, float zOffset, float heading, int p5, int p6, int p7, int p8)` | build 1207
Returns the entity coverpoint with offset.

## _ADD_COVER_BLOCKING_VOLUME
`0xEB2ED1DC3AEC0654` | `void _ADD_COVER_BLOCKING_VOLUME(Volume volume, BOOL p1, BOOL p2, BOOL p3, BOOL p4)` | build 1207

## _ADD_FLEE_TARGET_COORDS
`0xE8F1A5B4CED3725A` | `void _ADD_FLEE_TARGET_COORDS(Ped ped, float x, float y, float z, float p4)` | build 1207

## _ASSOCIATE_PROP_WITH_SCENARIO
`0x8360C47380B6F351` | `BOOL _ASSOCIATE_PROP_WITH_SCENARIO(int scenario, Entity entity, char* propName, BOOL p3)` | build 1207

## _CALCULATE_WAYPOINT_DISTANCE_FROM_START
`0x3ACC128510142B9D` | `float _CALCULATE_WAYPOINT_DISTANCE_FROM_START(char* waypointRecording, float x, float y, float z)` | build 1207
Returns the signed distance along the waypoint recording from its start (first node) to the point on the recording that corresponds to coords
 need `REQUEST_WAYPOINT_RECORDING`

## _CANCEL_PED_HOGTIE
`0xE2CF104ADD49D4BF` | `void _CANCEL_PED_HOGTIE(Ped ped)` | build 1207
Cancels the hogtie state of a ped, releasing them from ropes or restraints.If the ped is currently hogtied on the ground, carried on a shoulder,lassoed, or tied to a horse, this native will clear the hogtie state andreturn the ped to free/normal behavior.

## _CLEAR_VEHICLE_TASKS
`0x141BC64C8D7C5529` | `void _CLEAR_VEHICLE_TASKS(Vehicle vehicle)` | build 1207
Clears all active tasks assigned to the specified vehicle This cancels ongoing behaviors such as TASK_VEHICLE_DRIVE_TO_DESTINATION_2, or even tasks triggered by horses pulling the vehicle when they start moving due to gunfire etc. in the decompiles seems to always be paired with `0xEBA2081E0A5F4D17`

## _CREATE_HERB_COMPOSITES
`0x5B4BBE80AD5972DC` | `int _CREATE_HERB_COMPOSITES(Hash asset, float x, float y, float z, float heading, int groundSetting, Any p6, int p7)` | build 1207
groundSetting: 0: spawn on ground, 2 (1?): do not spawn on ground
p7: -1 in R* Scripts
Returns compositeId

## _CREATE_WAYPOINT_PATH
`0x5C885E0978B6AD60` | `BOOL _CREATE_WAYPOINT_PATH(char* pathName, Any p1, int nodes, int p3)` | build 1207

## _CUFF_PED
`0x7981037A96E7D174` | `void _CUFF_PED(Ped ped)` | build 1207

## _DELETE_PATCH_OBJECTS_FROM_HERB_COMPOSITES
`0x5758B1EE0C3FD4AC` | `void _DELETE_PATCH_OBJECTS_FROM_HERB_COMPOSITES(int compositeId, BOOL p1)` | build 1207
Params: p1 is always false except in script nb_egg_protector

## _DELETE_SCENARIO_POINT
`0x81948DFE4F5A0283` | `void _DELETE_SCENARIO_POINT(int scenario)` | build 1207

## _DETACH_CARRIABLE_PED
`0x36D188AECB26094B` | `void _DETACH_CARRIABLE_PED(Ped ped)` | build 1207

## _DISASSOCIATE_PROP_FROM_SCENARIO
`0x6EF4E31B4D5D2DA0` | `BOOL _DISASSOCIATE_PROP_FROM_SCENARIO(int scenario, char* propName)` | build 1207

## _DOES_SCENARIO_GROUP_EXIST_HASH
`0x76E98B52369A289C` | `BOOL _DOES_SCENARIO_GROUP_EXIST_HASH(Hash scenarioGroup)` | build 1207

## _DOES_SCENARIO_POINT_HAVE_PROPS
`0xEA31F199A73801D3` | `BOOL _DOES_SCENARIO_POINT_HAVE_PROPS(int scenario)` | build 1207

## _EMIT_PED_CARRIABLE_STRUGGLE_DIRECTION
`0x1ECF56C040FD839C` | `void _EMIT_PED_CARRIABLE_STRUGGLE_DIRECTION(Ped ped, float direction)` | build 1207

## _EMIT_PED_CARRIABLE_STRUGGLE_INTENSITY
`0xBD1C3C0F271C39D3` | `void _EMIT_PED_CARRIABLE_STRUGGLE_INTENSITY(Ped ped, float intensity)` | build 1207

## _EVALUATE_PED_CARRIABLE_STRUGGLE_AVAILABLE
`0x6AFD84AEAA3EA538` | `BOOL _EVALUATE_PED_CARRIABLE_STRUGGLE_AVAILABLE(Ped ped)` | build 1207

## _FIND_MODEL_FOR_ITEM
`0xE47DD64B9F02677D` | `Hash _FIND_MODEL_FOR_ITEM(Hash item)` | build 1207

## _FIND_NEAREST_PED_AROUND_ANIMAL
`0x244430C13BA5258E` | `Ped _FIND_NEAREST_PED_AROUND_ANIMAL(Ped animalPed, BOOL aliveOnly, BOOL deadOnly, BOOL preferDeadPredators)` | build 1207
Finds the nearest ped around the specified originPed, with optional filters for life state and predator/fish behavior
(all false) returns the nearest ped regardless of alive/dead state

## _FIND_SCENARIO_ALL_POINTS_IN_VOLUME_OF_TYPE
`0xB8E213D02F37947D` | `int _FIND_SCENARIO_ALL_POINTS_IN_VOLUME_OF_TYPE(Volume volume, ItemSet itemset, Hash scenarioType, int p3, int p4, int p5, int p6)` | build 1207
Finds all scenario points of a given type that lie inside a Volume and writes them into an Itemset Typically used with `CREATE_ITEMSET` Iterate results with `GET_ITEMSET_SIZE` and `GET_INDEXED_SCENARIO_POINT_INDEX_IN_ITEMSET`

## _FIND_SCENARIO_AT_OBJECT_OF_TYPE
`0xD508FA229F1C4900` | `int _FIND_SCENARIO_AT_OBJECT_OF_TYPE(Object object, float x, float y, float z, Hash scenarioType, float radius)` | build 1207
Returns a scenario point handle of the given scenario type that is associated with / found near the specified object. Useful for attached scenarios (e.g., ransackable lockboxes on a prop)

## _FINISH_SCENARIO_TRANSITION
`0x90703A8F75EE4ABD` | `BOOL _FINISH_SCENARIO_TRANSITION(Ped ped, float phaseOrDelta)` | build 1207
Attempts to finish/advance a ped’s ongoing scenario transition (between scenario clips/anims). Returns true if the ped is in a scenario transition and the given value pushes it forward, otherwise returns false

## _FORCE_ANIMAL_SAMPLED
`0xF3C3503276F4A034` | `void _FORCE_ANIMAL_SAMPLED(Ped animal, BOOL toggle)` | build 1436
Forces the specified animal/ped to have (or not have) its sampled state flag set.Acts as the setter counterpart to:_HAS_PED_ANIMAL_SAMPLED

## _GET_DRIVING_SEAT
`0xE62754D09354F6CF` | `Any _GET_DRIVING_SEAT(Vehicle vehicle)` | build 1207
Returns the seat index currently set as the driving seat for the specified vehicle vehicle: The vehicle to query. Returns: Seat index (default = -1 for driver seat, custom index if changed with SET_DRIVING_SEAT)

## _GET_HERB_COMPOSITE_NUM_ENTITIES
`0x96C6ED22FB742C3E` | `int _GET_HERB_COMPOSITE_NUM_ENTITIES(int compositeId, Any* outEntities)` | build 1207
Flowers, Stalks or whatever the composite has

## _GET_HOGTIE_ESCAPE_TIMER
`0x4687E69D258BBE41` | `float _GET_HOGTIE_ESCAPE_TIMER(Ped ped)` | build 1207

## _GET_HOLD_TO_REEL_SETTING_ENABLED
`0x5952DFA38FA529FE` | `int _GET_HOLD_TO_REEL_SETTING_ENABLED()` | build 1232
returns an int in decompiles usually 0 or 1

## _GET_HORSE_IN_REVIVAL_STATE
`0x351F74ED6177EBE7` | `int _GET_HORSE_IN_REVIVAL_STATE()` | build 1207
Returns the horse entity currently in a revivable state and within the revive prompt range (if any)

## _GET_ITEM_INTERACTION_ENTITY_FROM_PED
`0x05A0100EA714DB68` | `Entity _GET_ITEM_INTERACTION_ENTITY_FROM_PED(Ped ped, Hash item)` | build 1207
item hashes: PRIMARYITEM, P_MUGCOFFEE01X_PH_R_HAND, P_BOTTLEBEER01X_PH_R_HAND
http://prntscr.com/1qtp3bz
https://github.com/femga/rdr3_discoveries/tree/master/tasks/TASK_ITEM_INTERACTION

## _GET_LED_HORSE_FROM_PED
`0xED1F514AF4732258` | `Ped _GET_LED_HORSE_FROM_PED(Ped ped)` | build 1207

## _GET_LINKED_SCENARIO_POINTS
`0xE7BBC4E56B989449` | `Any _GET_LINKED_SCENARIO_POINTS(Any scenarioPoint, Any outPoints, Any maxPoints)` | build 1207
Fills an output array with scenario points linked (chained) to a given parent scenario point. Returns the number of linked points found. Writes up to maxPoints and zeroes remaining entries. Useful for flows like chained put-down scenarios.

## _GET_PED_BREAK_FREE_PROGRESS
`0x03D741CB4052E26C` | `float _GET_PED_BREAK_FREE_PROGRESS(Ped ped)` | build 1232
Returns the current progress of the (Break Free) prompt when the specified ped is hogtied or knocked out.  The value increases as the player spams the prompt key until it reaches 1.0, at which point the ped breaks free.
```lua
local progress = Citizen.InvokeNative(0x03D741CB4052E26C, PlayerPedId(), Citizen.ResultAsFloat())
--progress will be between 0.0 and 1.0 depending on how far the break free action has advanced.
```

## _GET_PED_IS_IGNORING_DEAD_BODIES
`0x1948BBE561A2375A` | `BOOL _GET_PED_IS_IGNORING_DEAD_BODIES(Ped ped)` | build 1207

## _GET_PED_USING_SCENARIO_POINT
`0x5BA659955369B0E2` | `Ped _GET_PED_USING_SCENARIO_POINT(int scenario)` | build 1207

## _GET_SCENARIO_CONTAINER_NUM_COMPARTMENTS
`0x640A602946A8C972` | `int _GET_SCENARIO_CONTAINER_NUM_COMPARTMENTS(Entity entity)` | build 1207
returns the total number of compartments (drawers, lids, etc.) the specified scenario container entity has for example, a chest has 1 compartment, while a cabinet with 3 drawers returns 3.

## _GET_SCENARIO_CONTAINER_NUM_OPEN_COMPARTMENTS
`0x849791EBBDBA0362` | `int _GET_SCENARIO_CONTAINER_NUM_OPEN_COMPARTMENTS(Entity entity)` | build 1207
Returns the number of currently open compartments for the specified scenario container entity if the container has closeable compartments (like drawers), this will return how many of them are currently open  if the container is not closeable (like a chest or safe that cannot be closed again), it will return 0

## _GET_SCENARIO_CONTAINER_OPENING_STATE
`0xB219612B5568E9EC` | `BOOL _GET_SCENARIO_CONTAINER_OPENING_STATE(Entity entity)` | build 1207
Returns m_eContainerState

## _GET_SCENARIO_CONTAINER_REMAINING_LOOT_COUNT
`0x01AF8A3729231A43` | `int _GET_SCENARIO_CONTAINER_REMAINING_LOOT_COUNT(Entity entity)` | build 1207
Returns the total number of lootable items currently inside the specified scenario container entity.This value decreases as items are looted. Before opening, it may return 0 because contents are not always loaded until the container is opened

## _GET_SCENARIO_POINT_COORDS
`0xA8452DD321607029` | `Vector3 _GET_SCENARIO_POINT_COORDS(int scenario, BOOL p1)` | build 1207
Params: p1 is always true in R* Scripts

## _GET_SCENARIO_POINT_ENTITY
`0x7467165EE97D3C68` | `Entity _GET_SCENARIO_POINT_ENTITY(int scenario)` | build 1207
Note: The current name for this native is the old name of 0x295514F198EFD0CA
Old name for this native: _GET_ENTITY_SCENARIO_POINT_IS_ATTACHED_TO

## _GET_SCENARIO_POINT_HEADING
`0xB93EA7184BAA85C3` | `float _GET_SCENARIO_POINT_HEADING(int scenario, BOOL p1)` | build 1207
Params: p1 is always true in R* Scripts

## _GET_SCENARIO_POINT_PED_IS_USING
`0xDF7993356F52359A` | `int _GET_SCENARIO_POINT_PED_IS_USING(Ped ped, BOOL p1)` | build 1207

## _GET_SCENARIO_POINT_RADIUS
`0x6718F40313A2B5A6` | `float _GET_SCENARIO_POINT_RADIUS(int scenario)` | build 1207

## _GET_SCENARIO_POINT_TYPE
`0xA92450B5AE687AAF` | `Hash _GET_SCENARIO_POINT_TYPE(int scenario)` | build 1207

## _GET_SCENARIO_POINT_TYPE_PED_IS_USING
`0x2D0571BB55879DA2` | `int _GET_SCENARIO_POINT_TYPE_PED_IS_USING(Ped ped)` | build 1207

## _GET_SCRIPT_TASK_ACTION_TIME
`0xA710DC5D25F8B942` | `float _GET_SCRIPT_TASK_ACTION_TIME(Ped ped, Hash task)` | build 1207

## _GET_TASK_FISHING
`0xF3735ACD11ACD500` | `BOOL _GET_TASK_FISHING(Ped ped, Any* p1)` | build 1207
Fishing Research: https://pastebin.com/NmK5ZLVs
Only used in R* Scripts fishing_core and av_fishing_river

## _GET_TASK_MOVE_NETWORK_ID
`0xCACC2F9D994504B7` | `Hash _GET_TASK_MOVE_NETWORK_ID(Ped ped)` | build 1207
Returns hash of the underlying move network def, see move_networks.xml
https://alloc8or.re/rdr3/doc/misc/move_networks.txt

## _GET_TASK_MOVE_NETWORK_PHASE_FLOAT
`0x844CEEE428EA35B0` | `float _GET_TASK_MOVE_NETWORK_PHASE_FLOAT(Ped ped, char* phaseName)` | build 1207

## _GET_TASK_PED_MOUNT_LEAP_PROGRESS
`0x6BA606AB3A83BC4D` | `float _GET_TASK_PED_MOUNT_LEAP_PROGRESS(Ped ped)` | build 1207
Returns 0.0-1.0 progress for the current mount-leap task, or -1.0f if no leap is active.

## _GET_TASK_PED_MOUNT_LEAP_STATE
`0x9420FB11B8D77948` | `int _GET_TASK_PED_MOUNT_LEAP_STATE(Ped ped)` | build 1207
Returns a coarse state for the mount-leap task (jumping from your mount onto another mount/wagon/train).
-1 = no task; 0 = in-air/ongoing; 1 = boarded/mounted; 2 = boarded rear train trailer
Use with _GET_TASK_PED_MOUNT_LEAP_PROGRESS for timing

## _GET_WHISTLE_RANGE_MAX_FOR_BONDING_LEVEL
`0x78D8C1D4EB80C588` | `float _GET_WHISTLE_RANGE_MAX_FOR_BONDING_LEVEL(int bondingLevel)` | build 1207
Returns the maximum (target) whistle/call distance associated with the next horse bonding level.
Used together with the current level's minimum to derive an effective whistle range based on the horse's bonding progress toward the next rank

## _GET_WHISTLE_RANGE_MIN_FOR_BONDING_LEVEL
`0xEB67D4E056C85A81` | `float _GET_WHISTLE_RANGE_MIN_FOR_BONDING_LEVEL(int bondingLevel)` | build 1207
Returns the minimum (baseline) whistle/call distance for the given horse bonding level.
This value represents the lower bound used when computing whether a horse is considered near or far relative to the player, and is interpolated against the next level's max.

## _HAS_CARRIABLE_CONFIG_HASH_LOADED
`0xB8F52A3F84A7CC59` | `BOOL _HAS_CARRIABLE_CONFIG_HASH_LOADED(Hash carriableConfig)` | build 1207
list of carriable configs  https://gist.github.com/outsider31000/6272561fb992ccff80efbd130e0e9b9f

## _HAS_PED_ANIMAL_BEEN_SAMPLED
`0x7CB99FADDE73CD1B` | `BOOL _HAS_PED_ANIMAL_BEEN_SAMPLED(Ped animal)` | build 1311
Returns true if the specified ped (animal) has been flagged as sampled. This is presumed to read a boolean flag set by:`_FORCE_ANIMAL_SAMPLED`

## _HAS_PED_DIRECTED_TASK_ACTIVE
`0x9FF5F9B24E870748` | `BOOL _HAS_PED_DIRECTED_TASK_ACTIVE(Entity entity)` | build 1207
Returns true if the given entity currently has an active directed task that is, a task with a specific external objective (coordinate, entity, vehicle, or combat target)
Known to return true for:
TaskGoToCoordAnyMeans(ped, ...)
TaskGoToEntity(ped, target, ...)
TaskCombatPed(ped, targetPed, ...)
TaskWarpPedIntoVehicle(ped, vehicle)

## _IS_CARRIABLE_HAT_PICKUP_REQUEST_ACTIVE
`0x4ECCC2815CA79AE2` | `BOOL _IS_CARRIABLE_HAT_PICKUP_REQUEST_ACTIVE(Object object)` | build 1207
old name _IS_HAT_BEING_PICKED_UP_2
Returns whether a carriable hat equip request is currently active Usually becomes true right after `_REQUEST_CARRIABLE_HAT_EQUIP_TO_PED` is called

## _IS_ENTITY_REVIVABLE
`0x6C50B9DCCCA70023` | `BOOL _IS_ENTITY_REVIVABLE(Ped ped)` | build 1207

## _IS_HAT_BEING_PICKED_UP
`0x11CD066F54DA0133` | `BOOL _IS_HAT_BEING_PICKED_UP(Object hatObject)` | build 1207
new name _IS_CARRIABLE_HAT_PICKUP_AVAILABLE, Checks if a carriable hat object on the ground can currently be picked up

## _IS_PED_ARRESTING_ANY_PED
`0xA9CC7856D52DBD25` | `BOOL _IS_PED_ARRESTING_ANY_PED(Ped ped)` | build 1207

## _IS_PED_BEING_LED
`0xAC5045AB7F1A34FD` | `BOOL _IS_PED_BEING_LED(Entity mount)` | build 1207
returns true if the specified mount (horse) is currently being led by the player, otherwise false.

## _IS_PED_DUELLING
`0xC8B29D18022EA2B7` | `BOOL _IS_PED_DUELLING(Ped ped)` | build 1207

## _IS_PED_LEADING_HORSE
`0xEFC4303DDC6E60D3` | `BOOL _IS_PED_LEADING_HORSE(Ped ped)` | build 1207

## _IS_PED_WAITING_ON_FISH_TO_BITE
`0xB520DBDA7FCF573F` | `BOOL _IS_PED_WAITING_ON_FISH_TO_BITE(Ped ped)` | build 1207
Returns true while the ped has cast the fishing line and is waiting for a fish to bite Once the ped hooks a fish and enters the struggle/reeled-in phase, this returns false.

## _IS_REVIVE_HORSE_PROMPT_VISIBLE
`0x756C7B4C43DF0422` | `BOOL _IS_REVIVE_HORSE_PROMPT_VISIBLE(BOOL p0)` | build 1207
Returns true if a revivable horse prompt is currently visibled (i.e., visible and interactable) near the player.This indicates that there is a downed horse nearby which can be revived

## _IS_SCENARIO_GROUP_ENABLED_HASH
`0xDCC374913DE6AAA6` | `BOOL _IS_SCENARIO_GROUP_ENABLED_HASH(Hash scenarioGroup)` | build 1207

## _IS_SCENARIO_IN_USE
`0x1ACBC313966C21F3` | `BOOL _IS_SCENARIO_IN_USE(Hash scenarioHash)` | build 1436
Checks whether a specified scenario is currently being used (actively played) by any entity (player or ped). Returns true if the scenario is already occupied, otherwise false.

## _IS_SCENARIO_POINT_ACTIVE
`0x0CC36D4156006509` | `BOOL _IS_SCENARIO_POINT_ACTIVE(int scenario)` | build 1207

## _IS_SCENARIO_POINT_FLAG_SET
`0x8569C38D2FB80650` | `BOOL _IS_SCENARIO_POINT_FLAG_SET(int scenario, int flag)` | build 1207

## _LOAD_CARRIABLE_CONFIG_HASH
`0xFF745B0346E19E2C` | `void _LOAD_CARRIABLE_CONFIG_HASH(Hash hash)` | build 1207
https://gist.github.com/outsider31000/6272561fb992ccff80efbd130e0e9b9f carriable config list

## _MAKE_OBJECT_CARRIABLE
`0x78B4567E18B54480` | `void _MAKE_OBJECT_CARRIABLE(Object object)` | build 1207

## _PED_APPLY_FOLLOW_ROAD_SPEED_OVERRIDE
`0xBAAB791AA72C2821` | `void _PED_APPLY_FOLLOW_ROAD_SPEED_OVERRIDE(Ped ped, float speed)` | build 1207
Sets the AI travel speed for a mount (horse). Affects how fast the horse's AI will move when being controlled by AI logic (not player input), e.g. during escorts, flee, wander, or scripted tasks 
https://youtu.be/aupII2O9vT8

## _PED_FISHINGROD_HOOK_ENTITY
`0x1A52076D26E09004` | `void _PED_FISHINGROD_HOOK_ENTITY(Ped ped, Entity entity)` | build 1207

## _PED_FISHINGROD_HOOK_OBJECT
`0xCE71C2F9BAA3F975` | `void _PED_FISHINGROD_HOOK_OBJECT(Ped ped, Object object)` | build 1207
Used with 'P_BODYPARTARMFLOAT02X' model in fishing_core.c

## _PED_IS_IN_SCENARIO_BASE
`0x02EBBB3989B7E695` | `BOOL _PED_IS_IN_SCENARIO_BASE(Ped ped)` | build 1207

## _REMOVE_CARRIABLE_CONFIG
`0x6AFDA2264925BD11` | `void _REMOVE_CARRIABLE_CONFIG(Hash carriableConfig)` | build 1207

## _REMOVE_TASK_CARRIABLE
`0x9EBD34958AB6F824` | `void _REMOVE_TASK_CARRIABLE(Entity entity)` | build 1207
Removes the TaskCarriable association for the given entity. If a ped is currently carrying this entity, it will be **dropped** immediately. If it is not being carried, the carriable link/state created via TaskCarriable(...) is cleared

## _REQUEST_CARRIABLE_HAT_EQUIP_TO_PED
`0x9ADDBB9242179D56` | `void _REQUEST_CARRIABLE_HAT_EQUIP_TO_PED(Object object, Ped ped)` | build 1207
Requests that the given carriable hat be assigned for equip by the ped. After success, `_IS_CARRIABLE_HAT_PICKUP_REQUEST_ACTIVE` will return true

## _REQUEST_HERB_COMPOSITE_ASSET
`0x73F0D0327BFA0812` | `BOOL _REQUEST_HERB_COMPOSITE_ASSET(Hash asset)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/objects/composites

## _RESET_SCENARIO_FOR_ENTITY
`0x2E20878FD208A68E` | `void _RESET_SCENARIO_FOR_ENTITY(int scenario, Entity entity)` | build 1207

## _RESET_SCENARIO_POINTS_IN_AREA
`0x4161648394262FDF` | `void _RESET_SCENARIO_POINTS_IN_AREA(float x, float y, float z, float radius)` | build 1207
Resets/clears all scenario entities within the given spherical area

## _RESET_SCENARIO_SCRIPT
`0x5A40040BB5AE3EA2` | `void _RESET_SCENARIO_SCRIPT(int scenario)` | build 1207

## _SET_ABOARD_PED_BOAT_POSE
`0x517D01BF27B682D1` | `void _SET_ABOARD_PED_BOAT_POSE(Ped ped, Entity boat, float offsetX, float offsetY, float offsetZ, float heading, int flags)` | build 1207
Set a ped's boat-local offset and/or facing (degrees). Boats only. Flags: 0=apply both; 1=heading only (lock offset); 2=offset only (lock heading); 3=apply neither.

## _SET_CARRIABLE_CONFIG_PROMPT_ENABLED
`0x816A3ACD265E2297` | `void _SET_CARRIABLE_CONFIG_PROMPT_ENABLED(Hash carriableConfig, BOOL toggle)` | build 1207
Enables or disables the interaction prompt for a given carriable config (e.g. DEAD_CARRIABLE_HUMAN).

## _SET_CARRIABLE_PICKUP_PROMPT_ENABLED
`0xA21AA2F0C2180125` | `void _SET_CARRIABLE_PICKUP_PROMPT_ENABLED(Object object, BOOL enabled)` | build 1207
Enables or disables the contextual Pick Up prompt for a carriable entity
 object — A carriable entity (animal carcass, pelt bundle, sack/crate flagged as carriable, etc.)

## _SET_DRIVING_SEAT
`0x4BA972D0E5AD8122` | `void _SET_DRIVING_SEAT(Vehicle vehicle, int seatIndex)` | build 1207
Sets which seat index acts as the driver seat for driving tasks

## _SET_FISHING_BAIT
`0x9B0C7FA063E67629` | `void _SET_FISHING_BAIT(Ped ped, char* bait, BOOL withoutBuoy, BOOL instantly)` | build 1207
Baits: p_fishHook02x, p_baitBread01x, p_baitCorn01x, p_baitCheese01x, p_baitWorm01x, p_baitCricket01x, p_crawdad01x, p_finisheDragonfly01x, p_finisdFishlure01x, p_finishdCrawd01x, p_finisheDragonflyLegendary01x, p_finisdFishlureLegendary01x, p_finishdCrawdLegendary01x, p_lgoc_spinner_v4

## _SET_HOGTIE_ESCAPE_TIMER
`0xAB591AE6B48B913E` | `void _SET_HOGTIE_ESCAPE_TIMER(Ped ped, float time)` | build 1207
Sets the time it takes for a hogtied ped to escape
-1.0f for ped to never escape

## _SET_INTIMIDATED_FACING_ANGLE
`0x0FE797DD9F70DFA6` | `void _SET_INTIMIDATED_FACING_ANGLE(Ped ped, BOOL useLimits, float minAngle, float maxAngle)` | build 1207
Configures how an intimidated/hogtied ped faces the player If useLimits is false (0), the ped always fully faces the player.If useLimits is true (1), the ped’s facing is restricted within the given angle range [minAngle, maxAngle]
```lua
--Set ped interaction personality to scripted timid robbery
Citizen.InvokeNative(0x24C82EF607105FAA, ped, joaat("SCRIPTEDTIMIDROB"))
-- Start intimidated task with the player
Citizen.InvokeNative(0x933ACC1A1771A288, ped, PlayerPedId(), 1, 0, 0, 0, 0, 0, 83968)
-- Make the ped face within the range 0.0 to -360.0 degrees
Citizen.InvokeNative(0x0FE797DD9F70DFA6, ped, 1, 0.0, -360.0)
-- Force the ped to always face the player
Citizen.InvokeNative(0x0FE797DD9F70DFA6, ped, 0)
```

## _SET_ITEM_INTERACTION_STATE
`0xB35370D5353995CB` | `void _SET_ITEM_INTERACTION_STATE(Ped ped, Hash itemInteractionState, float p2)` | build 1207
All Interaction states
https://github.com/femga/rdr3_discoveries/tree/master/tasks/TASK_ITEM_INTERACTION#-4-item_interaction_state_name--item_interaction_propid--1

## _SET_PED_CLEAR_AIMING_IN_THE_AIR
`0x34C0010188D7C54A` | `void _SET_PED_CLEAR_AIMING_IN_THE_AIR(Ped ped, Any p1)` | build 1207

## _SET_PED_IGNORE_DEAD_BODIES
`0x013A7BA5015C1372` | `void _SET_PED_IGNORE_DEAD_BODIES(Ped ped, BOOL toggle)` | build 1207

## _SET_PED_PATH_AVOID_TRAFFIC
`0x7C015D8BCEC72CF4` | `void _SET_PED_PATH_AVOID_TRAFFIC(Ped ped, BOOL avoidTraffic)` | build 1207

## _SET_PED_PATH_LADDER_COST_MODIFIER
`0x70F7A1EAB1AE3AA8` | `void _SET_PED_PATH_LADDER_COST_MODIFIER(Ped ped, float modifier)` | build 1232
_SET_PED_PATH_P*

## _SET_PED_PATH_MAY_ENTER_DEEP_WATER
`0x9DE63896B176EA94` | `void _SET_PED_PATH_MAY_ENTER_DEEP_WATER(Ped ped, BOOL mayEnterDeepWater)` | build 1207

## _SET_PED_PATH_MAY_USE_SLIDING_SURFACES
`0x06ECF3925BC2ABAE` | `void _SET_PED_PATH_MAY_USE_SLIDING_SURFACES(Ped ped, BOOL useSlidingSurfaces)` | build 1311

## _SET_PED_PATH_NEVER_USE_INTERIORS
`0x42CFD8FD8CC8DC69` | `void _SET_PED_PATH_NEVER_USE_INTERIORS(Ped ped, BOOL neverUseInteriors)` | build 1207

## _SET_PED_PATH_PREFER_HORSE_WALKABLE
`0x216343750545A486` | `void _SET_PED_PATH_PREFER_HORSE_WALKABLE(Ped ped, BOOL preferHorseWalkable, float p2)` | build 1207

## _SET_PED_PATH_PREFER_STAY_IN_WATER
`0xC6170856E54557B2` | `void _SET_PED_PATH_PREFER_STAY_IN_WATER(Ped ped, BOOL preferStayInWater, float p2)` | build 1207

## _SET_PED_PATH_PREFER_TO_AVOID_FOLIAGE
`0x12990818C1D35886` | `void _SET_PED_PATH_PREFER_TO_AVOID_FOLIAGE(Ped ped, BOOL preferAvoidFoliage, float p2)` | build 1207

## _SET_PED_PATH_PREFER_TO_AVOID_MUD
`0x8BB283A7888AD1AD` | `void _SET_PED_PATH_PREFER_TO_AVOID_MUD(Ped ped, BOOL preferAvoidMud, float p2)` | build 1207

## _SET_SCENARIO_CONTAINER_OPENING_STATE
`0x188F8071F244B9B8` | `void _SET_SCENARIO_CONTAINER_OPENING_STATE(Entity entity, BOOL open)` | build 1207
Opens/closes containers: ChestDugUp

## _SET_SCENARIO_GROUP_ENABLED_HASH
`0x9925EDDB6EAB88CD` | `void _SET_SCENARIO_GROUP_ENABLED_HASH(Hash scenarioGroup, BOOL toggle)` | build 1207

## _SET_SCENARIO_POINT_ACTIVE
`0xEEE4829304F93EEE` | `void _SET_SCENARIO_POINT_ACTIVE(int scenario, BOOL active)` | build 1207

## _SET_SCENARIO_POINT_COORDS
`0x2056AB38DF06825C` | `void _SET_SCENARIO_POINT_COORDS(int scenario, float xPos, float yPos, float zPos, BOOL p4)` | build 1207

## _SET_SCENARIO_POINT_FLAG
`0x5AF19B6CC2115D34` | `void _SET_SCENARIO_POINT_FLAG(int scenario, int flag, BOOL value)` | build 1207
flag: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/CScenarioPointFlags__Flags

## _SET_SCENARIO_POINT_HEADING
`0xD3A0DA8F91612C6E` | `void _SET_SCENARIO_POINT_HEADING(int scenario, float heading, BOOL p2)` | build 1207

## _SET_SCENARIO_POINT_RADIUS
`0xC47D9080A9A8856A` | `void _SET_SCENARIO_POINT_RADIUS(int scenario, float radius)` | build 1207

## _SET_SCENARIO_TYPE_ENABLED_HASH
`0xD00E50E673802D71` | `void _SET_SCENARIO_TYPE_ENABLED_HASH(Hash scenarioType, BOOL toggle)` | build 1207

## _SET_TASK_FISHING
`0xF3735ACD11ACD501` | `BOOL _SET_TASK_FISHING(Ped ped, Any p1)` | build 1207
Only used in R* Scripts fishing_core and av_fishing_river

## _SET_TASK_MOVE_NETWORK_SIGNAL_FLOAT_2
`0x099D4A855D53B03B` | `void _SET_TASK_MOVE_NETWORK_SIGNAL_FLOAT_2(Ped ped, char* signalName, float value)` | build 1207

## _SET_TASK_MOVE_NETWORK_SIGNAL_VECTOR
`0x4662BFE01938D98D` | `void _SET_TASK_MOVE_NETWORK_SIGNAL_VECTOR(Ped ped, char* signalName, float x, float y, float z)` | build 1207

## _SWAP_REINS_FOR_PED
`0xFC7F71CF49F70B6B` | `void _SWAP_REINS_FOR_PED(Ped ped)` | build 1207
Swaps the horse drawn wagon/coach reings control between the ped and their adjacent front-seat partner

## _SWAP_REINS_FOR_VEHICLE
`0xE01F55B2896F6B37` | `void _SWAP_REINS_FOR_VEHICLE(Vehicle vehicle, BOOL instant)` | build 1207
Transfers the driving reins/control of a vehicle (e.g., wagon/coach) to another occupant when there is more than one ped inside. If instant is true, the handover happens instantly

## _TASK_ANIMAL_BLEED_OUT
`0x30A768C30D385EC5` | `void _TASK_ANIMAL_BLEED_OUT(Ped ped, Ped killer, BOOL flee, Hash weaponHash, int p4, int boneId)` | build 1207

## _TASK_BOARD_VEHICLE
`0xE53D17AD837CBF7C` | `void _TASK_BOARD_VEHICLE(Ped ped, Vehicle vehicle, Any p2, Any p3, float speed, int boardingFlags)` | build 1207

## _TASK_BOARD_VEHICLE_2
`0xE41A09C8DDFF7AA4` | `void _TASK_BOARD_VEHICLE_2(Ped ped, Any p1, Any p2, float speed, int boardingFlags)` | build 1207

## _TASK_CLIMB_2
`0xDF1D85BCAF60D537` | `void _TASK_CLIMB_2(Ped ped, float heading)` | build 1207

## _TASK_COMBAT_PED_AT_COORDS
`0xC624414FA748B9BA` | `void _TASK_COMBAT_PED_AT_COORDS(Ped ped, float x, float y, float z, int p4, int p5)` | build 1207
Coords: volume coords used in R* Script smuggler2
p4/p5 = 0 in R* Scripts previous name TASK_COMBAT_PED_3

## _TASK_CUT_FREE_HOGTIED_TARGET_PED
`0x81D16C4FF3A77ADF` | `void _TASK_CUT_FREE_HOGTIED_TARGET_PED(Ped ped, Ped targetPed)` | build 1207

## _TASK_CUT_FREE_HOGTIED_TARGET_PED_2
`0x525421A507216084` | `void _TASK_CUT_FREE_HOGTIED_TARGET_PED_2(Ped ped, Ped targetPed, float p2)` | build 1207

## _TASK_DISEMBARK_VEHICLE
`0xA7C6854BB5A4192A` | `void _TASK_DISEMBARK_VEHICLE(Any p0, Vehicle vehicle, int p2, Any p3, float p4, Any p5)` | build 1207

## _TASK_EMOTE_ACTION
`0x6A1AF481407BF6E9` | `BOOL _TASK_EMOTE_ACTION(Ped ped)` | build 1207
Triggers the 'action / flourish' sub-clip of the ped's currently playing emote.

## _TASK_EMOTE_OUTRO
`0xBDFEEB7600BCD938` | `void _TASK_EMOTE_OUTRO(Ped ped)` | build 1207

## _TASK_EQUIP_HAT
`0xAA0AF6025160243A` | `void _TASK_EQUIP_HAT(Object object, Ped ped)` | build 1207
Immediately applies the given hat to the ped’s head without any animation Directly equips the hat, skipping the pickup anim flow

## _TASK_FLEE_FROM_COORD
`0x6879FF208ED87F2A` | `void _TASK_FLEE_FROM_COORD(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11)` | build 1207
fleeType: see TASK_FLEE_COORD

## _TASK_FLEE_FROM_PED
`0x7B74D8EEDE9B5727` | `void _TASK_FLEE_FROM_PED(Ped ped, Ped fleeFromTarget, float x, float y, float z, float distance, int p6, int p7, float p8, Ped targetPed)` | build 1207
fleeType: see TASK_FLEE_COORD

## _TASK_FORCE_THROWABLE_AT_ENTITY_WHILE_AIMING
`0x2416EC2F31F75266` | `void _TASK_FORCE_THROWABLE_AT_ENTITY_WHILE_AIMING(Ped ped, Entity targetEntity, int duration, BOOL p3, BOOL p4)` | build 1207
Forces a ped to attack a target with throwable or projectile weapons (like bows, throwing knives, tomahawks, dynamite) for a specified duration while aiming
With a bow: the ped keeps firing arrows continuously until durationMs expires (as long as the aiming condition is maintained).With other throwables: throws are generally single-use (one per animation cycle).Excluded weapons: lasso and bolas

## _TASK_GUARD_ASSIGNED_DEFENSIVE_AREA_2
`0x1FC9B33976BACD6C` | `void _TASK_GUARD_ASSIGNED_DEFENSIVE_AREA_2(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## _TASK_INTIMIDATED
`0x648B75D44930D6BD` | `BOOL _TASK_INTIMIDATED(Any p0, Ped ped, Any p2, Any p3, Any p4)` | build 1207

## _TASK_INTIMIDATED_2
`0x933ACC1A1771A288` | `BOOL _TASK_INTIMIDATED_2(Ped victim, Ped attacker, int p2, BOOL p3, BOOL p4, BOOL everyFrame, BOOL p6, BOOL p7, int flag)` | build 1207

## _TASK_ITEM_INTERACTION_2
`0x72F52AA2D2B172CC` | `void _TASK_ITEM_INTERACTION_2(Ped ped, Hash propNameGxt, Object prop, Hash propId, Hash itemInteractionState, int p5, Any p6, float p7)` | build 1207

## _TASK_ITEM_INTERACTION_3
`0xD61D5E1AD9876DEB` | `void _TASK_ITEM_INTERACTION_3(Ped ped, Hash item, Any* guid, Any p3, Any p4, Any p5, float p6)` | build 1207
Params: p3, p4, p5, p6: 0, 0, 0, -1.0f in R* Scripts

## _TASK_JUMP_2
`0x91083103137D7254` | `void _TASK_JUMP_2(Ped ped, float x, float y, float z, Entity entity)` | build 1207

## _TASK_KNOCKED_OUT_SET_DURATION
`0xFFB520A3E16F7B7B` | `void _TASK_KNOCKED_OUT_SET_DURATION(Ped ped, float p1)` | build 1207
Sets the knockout timer for a ped that is currently knocked out (See Task_Knocked_Out or Task_Knocked_Out_And_Hogtied). p1 is the duration in seconds.

## _TASK_KNOCKED_OUT_SET_TUNING
`0x8B1FDF63C3193EDA` | `void _TASK_KNOCKED_OUT_SET_TUNING(Ped ped, float tuning)` | build 1207
Sets an unknown float tuning setting for a ped that is currently in the knocked-out state.

## _TASK_PATROL_2
`0x964B06C88E4C86DB` | `void _TASK_PATROL_2(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## _TASK_PLAY_EMOTE
`0x884E3436CC1F41DD` | `void _TASK_PLAY_EMOTE(Ped ped, int emoteType, int playbackMode, Hash emote, BOOL isSecondaryTask, BOOL canBreakOut, BOOL disableEarlyOutAnimTag, BOOL ignoreInvalidMainTask, BOOL destroyProps)` | build 1207
Similar to 0xB31A277C1AC7B7FF but checks if the ped's inventory contains the specified emote kit.

## _TASK_POINT_AT_ENTITY
`0xF40A109B4B79A848` | `void _TASK_POINT_AT_ENTITY(Ped ped, Entity targetEntity, int durationMs)` | build 1207
Orders the ped to point at the given entity (finger/upper-body point), similar to task point entity

## _TASK_PUT_PED_DIRECTLY_INTO_COVER_FROM_COORDS
`0xDF8A5855B9F9A97B` | `void _TASK_PUT_PED_DIRECTLY_INTO_COVER_FROM_COORDS(Ped ped, float x, float y, float z, float fromX, float fromY, float fromZ, int timeout, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14, Any p15, Any p16, Any p17)` | build 1207

## _TASK_START_SCENARIO_IN_PLACE_2
`0xA917E39F2CEFD215` | `void _TASK_START_SCENARIO_IN_PLACE_2(Ped ped, int scenarioPoint, char* p2, int p3, BOOL p4, float p5, BOOL idleForever)` | build 1207
Takes scenario point handle instead of hash

## _TASK_THROW_PROJECTILE_2
`0x7282356DFF6B5A51` | `void _TASK_THROW_PROJECTILE_2(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _TASK_USE_NEAREST_SCENARIO_TO_COORD
`0x322BFDEA666E2B0E` | `void _TASK_USE_NEAREST_SCENARIO_TO_COORD(Ped ped, float x, float y, float z, float distance, int duration, BOOL p6, BOOL p7, BOOL p8, BOOL p9)` | build 1207

## _TASK_USE_SCENARIO_POINT_2
`0x0F6641449DD86FBE` | `void _TASK_USE_SCENARIO_POINT_2(Ped ped, Ped ped2, Any p2, char* p3, int p4, Hash p5, float p6, BOOL p7)` | build 1207

## _TASK_VEHICLE_ADD_NEXT_DESTINATION
`0x1D125814EBC517EB` | `void _TASK_VEHICLE_ADD_NEXT_DESTINATION(Vehicle vehicle, float x, float y, float z)` | build 1207
Adds a waypoint to an AI vehicle's active drive-to-destination task; only the last 3 points are kept (ignored if no such task).

## _TASK_VEHICLE_DRIVE_TO_COORD_2
`0xF0108F01FB105DA2` | `void _TASK_VEHICLE_DRIVE_TO_COORD_2(Ped ped, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8)` | build 1207

## _TASK_VEHICLE_DRIVE_TO_DESTINATION_2
`0x391073B9D3CCE2BA` | `void _TASK_VEHICLE_DRIVE_TO_DESTINATION_2(Vehicle vehicle, float x, float y, float z, float speed, int p5, int p6, float p7, float p8)` | build 1207
Tasks vehicle towards owner

## _TASK_VEHICLE_DRIVE_TO_POINT_2
`0x6524A8981E8BE7C9` | `void _TASK_VEHICLE_DRIVE_TO_POINT_2(Vehicle vehicle, float x, float y, float z, float p4, float p5, Any p6)` | build 1207
Params: p4 = 3.f or 8.f, p5 = 0.25f, p6 = 0 in R* Scripts

## _TASK_VEHICLE_FLEE_ON_CLEANUP
`0x55CD5FDDD4335C1E` | `void _TASK_VEHICLE_FLEE_ON_CLEANUP(Vehicle vehicle, float p1, float p2, float p3, float speed, Hash type)` | build 1207
Vehicle Auto Drive (?)
p1/p2/p3: usually 1f, 1f, 0f or 0f, 0f, 0f
Speed: usually 8f
Types: 1148979456 (task with flee), 1148979587 (dismissing the vehicle)

## _TASK_VEHICLE_FOLLOW_WAYPOINT_RECORDING_2
`0x041D17A9E221AE30` | `void _TASK_VEHICLE_FOLLOW_WAYPOINT_RECORDING_2(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9)` | build 1207

## _TASK_VEHICLE_HAS_DESTINATION
`0x583AE9AF9CEE0958` | `BOOL _TASK_VEHICLE_HAS_DESTINATION(Vehicle vehicle, float x, float y, float z)` | build 1207
Returns true if the vehicle’s has a destination set previously set with `_TASK_VEHICLE_DRIVE_TO_DESTINATION_2` clear using `_CLEAR_VEHICLE_TASKS`

## _TRANSITION_SCENARIO_TO_CONDITIONAL_ANIM
`0x79197F7D2BB5E73A` | `BOOL _TRANSITION_SCENARIO_TO_CONDITIONAL_ANIM(Ped ped, int scenarioPoint, char* clipsetDict, char* clipsetName, char* fromConditionalAnim, int flags)` | build 1207
Smoothly transitions an active scenario actor (ped) into a specific conditional / clipset defined in the scenario's conditional-anim graph, breaking or restarting the scenario.
Returns `true` if the transition was successfully triggered, or `false` if it failed

## _UPDATE_TASK_GO_TO_COORD_WITH_OFFSET
`0x3FFCD7BBA074CC80` | `void _UPDATE_TASK_GO_TO_COORD_WITH_OFFSET(Ped ped, float targetX, float targetY, float targetZ, float offsetX, float offsetY, float offsetZ, float speed, float tolerance)` | build 1207
In-place update for a running follow-to-offset/go-to task: sets new target coords + local offset, with speed and arrival tolerance (foot or mount; no effect if no compatible task)

## _UPDATE_TASK_VEHICLE_SHOOT_AT_COORD
`0xAF2EF28CE3084505` | `void _UPDATE_TASK_VEHICLE_SHOOT_AT_COORD(Ped ped, float x, float y, float z)` | build 1207
Updates the target coordinate of an ongoing SCRIPT_TASK_VEHICLE_SHOOT_AT_COORD for the given ped This lets you retarget the shooting point in real time without restarting the task
Has effect only while the ped’s task status for `SCRIPT_TASK_VEHICLE_SHOOT_AT_COORD` is `TASK_STATUS_ONGOING` (commonly 1) If the task hasn’t started yet (status 0 or not running), use `TASK_VEHICLE_SHOOT_AT_COORD` first; after it becomes active, call this to update the aim point Compared to `TASK_VEHICLE_SHOOT_AT_COORD`: the latter starts (or re-queues) the task with an initial target; this native *only* updates the active task’s target coordinate.
