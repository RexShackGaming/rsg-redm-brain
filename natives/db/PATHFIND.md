# PATHFIND natives (76)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_NAVMESH_BLOCKING_OBJECT
`0xFCD5C8E06E502F5A` | `Any ADD_NAVMESH_BLOCKING_OBJECT(float p0, float p1, float p2, float p3, float p4, float p5, float p6, BOOL p7, Any p8)` | build 1207

## ADD_NAVMESH_REQUIRED_REGION
`0x387EAD7EE42F6685` | `void ADD_NAVMESH_REQUIRED_REGION(float x, float y, float radius)` | build 1207

## ARE_NODES_LOADED_FOR_AREA
`0xF7B79A50B905A30D` | `BOOL ARE_NODES_LOADED_FOR_AREA(float x1, float y1, float x2, float y2)` | build 1207

## DOES_NAVMESH_BLOCKING_OBJECT_EXIST
`0x0EAEB0DB4B132399` | `BOOL DOES_NAVMESH_BLOCKING_OBJECT_EXIST(Any p0)` | build 1207

## GET_APPROX_FLOOR_FOR_POINT
`0x336511A34F2E5185` | `float GET_APPROX_FLOOR_FOR_POINT(float x, float y)` | build 1207
Returns CGameWorldHeightMap's minimum Z value at specified point (grid node).

## GET_CLOSEST_ROAD
`0x132F52BBA570FE92` | `Any GET_CLOSEST_ROAD(float x, float y, float z, float p3, int p4, Vector3* p5, Vector3* p6, Any* p7, Any* p8, float* p9, BOOL p10)` | build 1207

## GET_CLOSEST_VEHICLE_NODE
`0x240A18690AE96513` | `BOOL GET_CLOSEST_VEHICLE_NODE(float x, float y, float z, Vector3* outPosition, int nodeType, float p5, float p6)` | build 1207

## GET_CLOSEST_VEHICLE_NODE_WITH_HEADING
`0x23CFFD4CCB243354` | `BOOL GET_CLOSEST_VEHICLE_NODE_WITH_HEADING(float x, float y, float z, Vector3* outPosition, float* outHeading, int nodeType, float p6, float p7)` | build 1207

## GET_GPS_BLIP_ROUTE_FOUND
`0x869DAACBBE9FA006` | `BOOL GET_GPS_BLIP_ROUTE_FOUND()` | build 1207

## GET_GPS_BLIP_ROUTE_LENGTH
`0xBBB45C3CF5C8AA85` | `int GET_GPS_BLIP_ROUTE_LENGTH()` | build 1207

## GET_NTH_CLOSEST_VEHICLE_NODE
`0x5A6D8DF6FBC5D0C4` | `BOOL GET_NTH_CLOSEST_VEHICLE_NODE(float x, float y, float z, int nthClosest, Vector3* outPosition, int unknown1, float unknown2, Any unknown3)` | build 1207

## GET_NTH_CLOSEST_VEHICLE_NODE_FAVOUR_DIRECTION
`0x2FAC235A6062F14A` | `BOOL GET_NTH_CLOSEST_VEHICLE_NODE_FAVOUR_DIRECTION(float x, float y, float z, float desiredX, float desiredY, float desiredZ, int nthClosest, Vector3* outPosition, float* outHeading, int nodetype, Any p10, Any p11)` | build 1207

## GET_NTH_CLOSEST_VEHICLE_NODE_ID
`0x116443008E5CEFC3` | `int GET_NTH_CLOSEST_VEHICLE_NODE_ID(float x, float y, float z, int nth, int nodetype, float p5, float p6)` | build 1207

## GET_NTH_CLOSEST_VEHICLE_NODE_ID_WITH_HEADING
`0x4114EAA8A7F7766D` | `int GET_NTH_CLOSEST_VEHICLE_NODE_ID_WITH_HEADING(float x, float y, float z, int nthClosest, float* returnHeading, int* returnNumLanes, int nodeFlags, float zMeasureMult, float zTolerance)` | build 1207
Returns the nth closest vehicle node with a heading to a coord

## GET_NTH_CLOSEST_VEHICLE_NODE_WITH_HEADING
`0x591B40D4390DB54A` | `BOOL GET_NTH_CLOSEST_VEHICLE_NODE_WITH_HEADING(float x, float y, float z, int nthClosest, Vector3* outPosition, float* heading, Any* unknown1, int unknown2, float unknown3, float unknown4)` | build 1207

## GET_NUM_NAVMESHES_EXISTING_IN_AREA
`0x01708E8DD3FF8C65` | `int GET_NUM_NAVMESHES_EXISTING_IN_AREA(float p0, float p1, float p2, float p3, float p4, float p5)` | build 1207

## GET_RANDOM_VEHICLE_NODE
`0x93E0DB8440B73A7D` | `BOOL GET_RANDOM_VEHICLE_NODE(float x, float y, float z, float radius, int minLanes, BOOL avoidDeadEnds, BOOL avoidHighways, Vector3* outPosition, int* nodeId)` | build 1207

## GET_SAFE_COORD_FOR_PED
`0xB61C8E878A4199CA` | `BOOL GET_SAFE_COORD_FOR_PED(float x, float y, float z, BOOL onGround, Vector3* outPosition, int flags)` | build 1207

## GET_VEHICLE_NODE_IS_SWITCHED_OFF
`0x28533DBDDF7C2C97` | `BOOL GET_VEHICLE_NODE_IS_SWITCHED_OFF(int nodeID)` | build 1207

## GET_VEHICLE_NODE_POSITION
`0x8E8D72FF24DEE1FB` | `void GET_VEHICLE_NODE_POSITION(int nodeId, Vector3* outPosition)` | build 1207

## IS_NAVMESH_LOADED_IN_AREA
`0xF813C7E63F9062A5` | `BOOL IS_NAVMESH_LOADED_IN_AREA(float x1, float y1, float z1, float x2, float y2, float z2)` | build 1207
Returns whether navmesh for the region is loaded.

## IS_POINT_ON_ROAD
`0x125BF4ABFC536B09` | `BOOL IS_POINT_ON_ROAD(float x, float y, float z, Vehicle vehicle)` | build 1207
Gets a value indicating whether the specified position is on a road.

## IS_VEHICLE_NODE_ID_VALID
`0x5829A02AF4F0B3CB` | `BOOL IS_VEHICLE_NODE_ID_VALID(int vehicleNodeId)` | build 1207
Returns true if the id is non zero.

## NAVMESH_REQUEST_PATH
`0x348F211CA2404039` | `int NAVMESH_REQUEST_PATH(Ped ped, float x1, float y1, float z1, float x2, float y2, float z2, int bitFlag)` | build 1207
Starts a nav mesh query for a path between coordinates with a given ped and returns a handle to be validated by _NAVMESH_REQUESTED_QUERY_STATUS and then _NAVMESH_REQUESTED_PATH_WAYPOINTS_FOUND

Only bit flag values used in scripts are 0, 23, and 29. 23 is used with dogs and horses. 29 with legendary animals.

## REMOVE_NAVMESH_BLOCKING_OBJECT
`0x46399A7895957C0E` | `void REMOVE_NAVMESH_BLOCKING_OBJECT(Any p0)` | build 1207

## REQUEST_PATH_NODES_IN_AREA_THIS_FRAME
`0x07FB139B592FA687` | `BOOL REQUEST_PATH_NODES_IN_AREA_THIS_FRAME(float x1, float y1, float x2, float y2)` | build 1207
Old name: REQUEST_PATHS_PREFER_ACCURATE_BOUNDINGSTRUCT

## RESET_ROADS_IN_VOLUME
`0xD17672447692478E` | `void RESET_ROADS_IN_VOLUME(Volume volume, BOOL p1)` | build 1207

## SET_AMBIENT_PED_RANGE_MULTIPLIER_THIS_FRAME
`0x0B919E1FB47CC4E0` | `void SET_AMBIENT_PED_RANGE_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## SET_IGNORE_NO_GPS_FLAG
`0x72751156E7678833` | `void SET_IGNORE_NO_GPS_FLAG(BOOL toggle)` | build 1207
nullsub, doesn't do anything

## SET_PED_PATHS_BACK_TO_ORIGINAL
`0xE04B48F2CC926253` | `void SET_PED_PATHS_BACK_TO_ORIGINAL(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## SET_PED_PATHS_IN_AREA
`0x34F060F4BF92E018` | `void SET_PED_PATHS_IN_AREA(float x1, float y1, float z1, float x2, float y2, float z2, BOOL unknown, Any p7)` | build 1207

## SET_ROADS_BACK_TO_ORIGINAL
`0x1EE7063B80FFC77C` | `void SET_ROADS_BACK_TO_ORIGINAL(float xMin, float yMin, float zMin, float xMax, float yMax, float zMax, Any p6, Any p7)` | build 1207

## SET_ROADS_BACK_TO_ORIGINAL_IN_ANGLED_AREA
`0x0027501B9F3B407E` | `void SET_ROADS_BACK_TO_ORIGINAL_IN_ANGLED_AREA(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8)` | build 1207

## SET_ROADS_IN_ANGLED_AREA
`0x1A5AA1208AF5DB59` | `void SET_ROADS_IN_ANGLED_AREA(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10)` | build 1207

## SET_ROADS_IN_AREA
`0xBF1A602B5BA52FEE` | `void SET_ROADS_IN_AREA(float xMin, float yMin, float zMin, float xMax, float yMax, float zMax, Any p6, Any p7, Any p8)` | build 1207

## SET_ROADS_IN_VOLUME
`0xC1799FAFD2FDF52B` | `void SET_ROADS_IN_VOLUME(Volume volume, BOOL p1, BOOL p2, BOOL p3)` | build 1207

## SIMULATED_ROUTE_GET_ETA
`0x2DD5F78D73B24172` | `float SIMULATED_ROUTE_GET_ETA(Any p0)` | build 1207

## SIMULATED_ROUTE_IS_LOADED
`0x240915043CB799D7` | `BOOL SIMULATED_ROUTE_IS_LOADED(Any p0)` | build 1207

## SIMULATED_ROUTE_TRAVEL_TO_POINT
`0xA1A3DE1C215C7394` | `void SIMULATED_ROUTE_TRAVEL_TO_POINT(Any p0, float p1, float p2)` | build 1207

## _0x264E9A5CD78C338F
`0x264E9A5CD78C338F` | `void _0x264E9A5CD78C338F(Any p0)` | build 1207

## _0x34C9AF25649172D0
`0x34C9AF25649172D0` | `void _0x34C9AF25649172D0(Any p0)` | build 1207

## _0x4358BCF14C91761C
`0x4358BCF14C91761C` | `void _0x4358BCF14C91761C(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9)` | build 1207

## _0x4BDEBEA5702B97A9
`0x4BDEBEA5702B97A9` | `void _0x4BDEBEA5702B97A9(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0x54F4D7B6670FBB5A
`0x54F4D7B6670FBB5A` | `Any _0x54F4D7B6670FBB5A(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x5A3B54ADDF5472A3
`0x5A3B54ADDF5472A3` | `int _0x5A3B54ADDF5472A3(const char* p0)` | build 1207

## _0x5A4E1A41E3A02AD0
`0x5A4E1A41E3A02AD0` | `void _0x5A4E1A41E3A02AD0(Any p0, Any p1, Any p2)` | build 1207

## _0x665B21666351CB37
`0x665B21666351CB37` | `Any _0x665B21666351CB37(Any p0, Any p1, Any p2)` | build 1207

## _0x6C3F12ECEB6D2E2A
`0x6C3F12ECEB6D2E2A` | `void _0x6C3F12ECEB6D2E2A(float xMin, float yMin, float zMin, float xMax, float yMax, float zMax, Any p6, Any p7)` | build 1207

## _0x6DAD6630AE4A74CB
`0x6DAD6630AE4A74CB` | `void _0x6DAD6630AE4A74CB(Any p0, Any p1)` | build 1207

## _0x869A7015BD4606E9
`0x869A7015BD4606E9` | `void _0x869A7015BD4606E9(Any p0)` | build 1207

## _0xA33914B00CA55756
`0xA33914B00CA55756` | `Any* _0xA33914B00CA55756(const char* p0, int p1)` | build 1207

## _0xAFE2AE66F6251C66
`0xAFE2AE66F6251C66` | `void _0xAFE2AE66F6251C66(float xMin, float yMin, float zMin, float xMax, float yMax, float zMax, int p6, Any p7)` | build 1207

## _0xB03944057FD735BA
`0xB03944057FD735BA` | `void _0xB03944057FD735BA(Any p0, Any p1, Any p2)` | build 1207

## _0xCA27A86CAA4E98ED
`0xCA27A86CAA4E98ED` | `Any _0xCA27A86CAA4E98ED(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0xCF213A5FC3ABFC08
`0xCF213A5FC3ABFC08` | `void _0xCF213A5FC3ABFC08(Any p0, Any p1, Any p2)` | build 1207

## _0xE5EF9DE716FF737E
`0xE5EF9DE716FF737E` | `void _0xE5EF9DE716FF737E(Any p0, Any p1, Any p2)` | build 1207

## _0xEFC535C9FAF563B3
`0xEFC535C9FAF563B3` | `Any _0xEFC535C9FAF563B3(Any p0)` | build 1207

## _0xF2A2177AC848B3A8
`0xF2A2177AC848B3A8` | `void _0xF2A2177AC848B3A8(Volume volume, int p1, int p2)` | build 1207
GPS disabled zone: p1 = 0
Clearing GPS disabled zone: p1 = 1

## _ADD_NAVMESH_BLOCKING_VOLUME
`0x19C7567D2F2287D6` | `BOOL _ADD_NAVMESH_BLOCKING_VOLUME(Volume volume, int flags)` | build 1207

## _DOES_NAVMESH_BLOCKING_VOLUME_EXIST
`0xDE0EA444735C1368` | `BOOL _DOES_NAVMESH_BLOCKING_VOLUME_EXIST(Volume volume)` | build 1207

## _GET_SPAWN_DATA_FOR_ROAD_NODE
`0xA3791B915B8B84C6` | `void _GET_SPAWN_DATA_FOR_ROAD_NODE(int nodeId, float x, float y, float z, Vector3* outCoords, float* heading)` | build 1207

## _NAVMESH_ACTIVATE_SWAP
`0x7C334FF4D9215912` | `BOOL _NAVMESH_ACTIVATE_SWAP(const char* name)` | build 1207

## _NAVMESH_ASSIGN_NAVMESH_TO_VEHICLE
`0x44026E3DB3CED602` | `BOOL _NAVMESH_ASSIGN_NAVMESH_TO_VEHICLE(Vehicle vehicle, const char* navMeshName)` | build 1207

## _NAVMESH_CLEAR_REQUESTED_PATH
`0x661BB1E1FF77742D` | `BOOL _NAVMESH_CLEAR_REQUESTED_PATH(int path)` | build 1207
Called in scripts after finished with requested pathes. Immediately resets all values connected to the path handle except query status, which changes from 1 to 2 before eventually becoming fully invalidated to 0.

## _NAVMESH_DEACTIVATE_SWAP
`0x527B97C203BB8606` | `BOOL _NAVMESH_DEACTIVATE_SWAP(char* name)` | build 1207

## _NAVMESH_DOES_SWAP_EXIST
`0x495CFAB2924237C7` | `BOOL _NAVMESH_DOES_SWAP_EXIST(char* name)` | build 1207

## _NAVMESH_IS_SWAP_ACTIVE
`0x5AC0944C156E5F44` | `BOOL _NAVMESH_IS_SWAP_ACTIVE(char* name)` | build 1207

## _NAVMESH_REQUESTED_PATH_NUM_WAYPOINTS
`0xD470725E0703D22F` | `int _NAVMESH_REQUESTED_PATH_NUM_WAYPOINTS(int path)` | build 1207
Returns the number of waypoints for a requested path (NAVMESH_REQUEST_PATH) if the query is completed (_NAVMESH_REQUESTED_QUERY_STATUS). For use with _NAVMESH_REQUESTED_PATH_WAYPOINT_BY_INDEX

## _NAVMESH_REQUESTED_PATH_WAYPOINTS_FOUND
`0x8800776E410EB669` | `BOOL _NAVMESH_REQUESTED_PATH_WAYPOINTS_FOUND(int path)` | build 1207
Returns true if a path of waypoints was found. Waypoints can be retrieved with _NAVMESH_REQUESTED_PATH_NUM_WAYPOINTS and _NAVMESH_REQUESTED_PATH_WAYPOINT_BY_INDEX

## _NAVMESH_REQUESTED_PATH_WAYPOINTS_TERRAIN
`0xF61CFEDEAB627BFA` | `int _NAVMESH_REQUESTED_PATH_WAYPOINTS_TERRAIN(int path)` | build 1207
Returns a bit flag for seemingly terrain within the waypoints in the path. Checked against bit value 2 to match water in the path, seems to always contain at least 1 though regardless of location/ped.

## _NAVMESH_REQUESTED_PATH_WAYPOINT_BY_INDEX
`0x430F8319AE56C8A9` | `Vector3 _NAVMESH_REQUESTED_PATH_WAYPOINT_BY_INDEX(int path, int waypointIndex)` | build 1207
Returns a vector3 waypoint at the specified index for a path. Use _NAVMESH_REQUESTED_PATH_NUM_WAYPOINTS to get available indexes.

## _NAVMESH_REQUESTED_QUERY_STATUS
`0x3A0F82F6EE2291C8` | `int _NAVMESH_REQUESTED_QUERY_STATUS(int path)` | build 1207
Returns eNavMeshQueryStatus
enum eNavMeshQueryStatus
{
	QS_NOT_FOUND,
	QS_COMPLETE,
	QS_PENDING
};

It appears that the pending state of 2 is at least also used when cleaning up a request (_NAVMESH_CLEAR_REQUESTED_PATH) or if a request never completes. Eventually queries are invalidated and return 0.

Old name: _NAVMESH_QUERY_STATUS

## _REMOVE_NAVMESH_BLOCKING_VOLUME
`0x2C87C3E1C7B96EE2` | `void _REMOVE_NAVMESH_BLOCKING_VOLUME(Volume volume)` | build 1207

## _SIMULATED_ROUTE_CREATE
`0xFD5BB35AAB83FD48` | `Any _SIMULATED_ROUTE_CREATE(float x1, float y1, float z1, float x2, float y2, float z2, int p6)` | build 1207

## _SIMULATED_ROUTE_DELETE
`0x4907D0E4FB26EE65` | `void _SIMULATED_ROUTE_DELETE(Any p0)` | build 1207

## _SIMULATED_ROUTE_EXISTS
`0x65A8196B8D7F5E0B` | `BOOL _SIMULATED_ROUTE_EXISTS(Any p0)` | build 1207
