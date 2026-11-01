# VOLUME natives (80)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## CREATE_VOLUME_AGGREGATE
`0x59F6F5C1D129F106` | `Volume CREATE_VOLUME_AGGREGATE()` | build 1207

## CREATE_VOLUME_BOX
`0xDF85637F22706891` | `Volume CREATE_VOLUME_BOX(float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1207

## CREATE_VOLUME_CYLINDER
`0x0522D4774B82E3E6` | `Volume CREATE_VOLUME_CYLINDER(float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1207

## CREATE_VOLUME_SPHERE
`0xB3FB80A32BAE3065` | `Volume CREATE_VOLUME_SPHERE(float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1207

## DELETE_VOLUME
`0x43F867EF5C463A53` | `void DELETE_VOLUME(Volume volume)` | build 1207

## DOES_VOLUME_COLLIDE_WITH_ANY_VOLUME_LOCK
`0x397769175A7DBB30` | `BOOL DOES_VOLUME_COLLIDE_WITH_ANY_VOLUME_LOCK(float x, float y, float z, float radius, BOOL p4, int p5, int p6)` | build 1207

## DOES_VOLUME_EXIST
`0x92A78D0BEDB332A3` | `BOOL DOES_VOLUME_EXIST(Volume volume)` | build 1207

## GET_VOLUME_COORDS
`0xF70F00013A62F866` | `Vector3 GET_VOLUME_COORDS(Volume volume)` | build 1207

## GET_VOLUME_LOCK_REQUEST_STATUS
`0xB33A604345F58202` | `int GET_VOLUME_LOCK_REQUEST_STATUS(int volLockRequestId)` | build 1207
enum eVolumeLockRequestStatus
{
	VOLUME_LOCK_REQUEST_STATUS_INVALID,
	VOLUME_LOCK_REQUEST_STATUS_READY,
	VOLUME_LOCK_REQUEST_STATUS_IN_PROGRESS,
	VOLUME_LOCK_REQUEST_STATUS_SUCCEEDED,
	VOLUME_LOCK_REQUEST_STATUS_FAILED
};

## GET_VOLUME_ROTATION
`0x18675BC914891122` | `Vector3 GET_VOLUME_ROTATION(Volume volume)` | build 1207

## GET_VOLUME_SCALE
`0x3E2A25B2416DD67E` | `Vector3 GET_VOLUME_SCALE(Volume volume)` | build 1207

## IS_POINT_IN_VOLUME
`0xF256A75210C5C0EB` | `BOOL IS_POINT_IN_VOLUME(Volume volume, float x, float y, float z)` | build 1207
Old name: _IS_POSITION_INSIDE_VOLUME

## IS_VOLUME_LOCK_REQUEST_VALID
`0xA4A4359320345B34` | `BOOL IS_VOLUME_LOCK_REQUEST_VALID(int volLockRequestId)` | build 1207

## REQUEST_VOLUME_LOCK
`0xF14BCEF290F869E1` | `int REQUEST_VOLUME_LOCK(float x, float y, float z, float radius, int p4, int p5)` | build 1207

## REQUEST_VOLUME_LOCK_WITH_ARGS
`0x183C0B6CFEFFCAE4` | `int REQUEST_VOLUME_LOCK_WITH_ARGS(Any* args)` | build 1207

## SET_VOLUME_COORDS
`0x541B8576615C33DE` | `BOOL SET_VOLUME_COORDS(Volume volume, float posX, float posY, float posZ)` | build 1207

## SET_VOLUME_OWNER_PERSISTENT_CHARACTER
`0xE2BE6FFA4A13CBB0` | `void SET_VOLUME_OWNER_PERSISTENT_CHARACTER(Volume volume, PersChar persChar, BOOL p2)` | build 1207

## SET_VOLUME_ROTATION
`0xA07CF1B21B56F041` | `BOOL SET_VOLUME_ROTATION(Volume volume, float rotX, float rotY, float rotZ)` | build 1207

## SET_VOLUME_SCALE
`0xA46E98BDC407E23D` | `BOOL SET_VOLUME_SCALE(Volume volume, float scaleX, float scaleY, float scaleZ)` | build 1207

## _0x128FC3A893BF853A
`0x128FC3A893BF853A` | `void _0x128FC3A893BF853A(Any p0)` | build 1207
nullsub, doesn't do anything

## _0x351D71B8B72B858B
`0x351D71B8B72B858B` | `Any _0x351D71B8B72B858B(Any p0)` | build 1207

## _0x3EFABB21E14A6BD1
`0x3EFABB21E14A6BD1` | `void _0x3EFABB21E14A6BD1(Any p0, Any p1, Any p2)` | build 1207

## _0x40F769D31A00D5A0
`0x40F769D31A00D5A0` | `Any _0x40F769D31A00D5A0(Any p0, Any p1)` | build 1207

## _0x4A8FEFC43FD8AC9B
`0x4A8FEFC43FD8AC9B` | `void _0x4A8FEFC43FD8AC9B(Any p0, Any p1, Any p2)` | build 1207

## _0x51E52C9687FCDEEC
`0x51E52C9687FCDEEC` | `Any _0x51E52C9687FCDEEC(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0x52572B331E693AED
`0x52572B331E693AED` | `void _0x52572B331E693AED(Any p0, Any p1, Any p2)` | build 1207

## _0x53D05D60E5F5B40C
`0x53D05D60E5F5B40C` | `void _0x53D05D60E5F5B40C(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x695DAC2DB928F308
`0x695DAC2DB928F308` | `void _0x695DAC2DB928F308(Any p0, Any p1)` | build 1207

## _0x6D5F9E69BA1BE783
`0x6D5F9E69BA1BE783` | `void _0x6D5F9E69BA1BE783(Any p0)` | build 1207

## _0x748C5F51A18CB8F0
`0x748C5F51A18CB8F0` | `void _0x748C5F51A18CB8F0(BOOL p0)` | build 1207
nullsub, doesn't do anything

## _0x7FD78DFD0C5D7B9B
`0x7FD78DFD0C5D7B9B` | `Any _0x7FD78DFD0C5D7B9B(Any p0)` | build 1207

## _0x870E9981ED27C815
`0x870E9981ED27C815` | `Any _0x870E9981ED27C815(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0x998202B206872672
`0x998202B206872672` | `void _0x998202B206872672(Any p0)` | build 1207

## _0xAA9EE2AAFC717623
`0xAA9EE2AAFC717623` | `Any _0xAA9EE2AAFC717623(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0xAC355980681A7F89
`0xAC355980681A7F89` | `void _0xAC355980681A7F89(Any p0)` | build 1207

## _0xB440F4E35393FC39
`0xB440F4E35393FC39` | `void _0xB440F4E35393FC39(Volume volume, Any p1)` | build 1207

## _0xB469CFD9E065EB99
`0xB469CFD9E065EB99` | `void _0xB469CFD9E065EB99(Any p0, Any p1)` | build 1207

## _0xC4019CF9AE8E931A
`0xC4019CF9AE8E931A` | `Vector3 _0xC4019CF9AE8E931A(int volLockRequestId)` | build 1207

## _0xC61E2FD926DBB406
`0xC61E2FD926DBB406` | `void _0xC61E2FD926DBB406()` | build 1311

## _0xCA5C90D40665D5CE
`0xCA5C90D40665D5CE` | `Any _0xCA5C90D40665D5CE(Any p0, Any p1)` | build 1207

## _0xD460135C98940274
`0xD460135C98940274` | `void _0xD460135C98940274(Volume volume, Any p1)` | build 1207

## _0xD4FA73FE628FEC63
`0xD4FA73FE628FEC63` | `void _0xD4FA73FE628FEC63(Any p0, Any p1)` | build 1207

## _0xD52DF30355EA7C8E
`0xD52DF30355EA7C8E` | `void _0xD52DF30355EA7C8E(Any p0, Any p1, Any p2)` | build 1207

## _0xD882C5B3991575B7
`0xD882C5B3991575B7` | `Vector3 _0xD882C5B3991575B7(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xEBA87B9273835CF3
`0xEBA87B9273835CF3` | `void _0xEBA87B9273835CF3(Any p0, Any p1)` | build 1207

## _0xEE1D6FF54CAF7714
`0xEE1D6FF54CAF7714` | `Any _0xEE1D6FF54CAF7714(Any p0, Any p1)` | build 1207

## _0xF3A2FBA5985C8CD5
`0xF3A2FBA5985C8CD5` | `void _0xF3A2FBA5985C8CD5(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xF6CE6F9C3897804E
`0xF6CE6F9C3897804E` | `Any _0xF6CE6F9C3897804E(Any p0)` | build 1207

## _0xF6F5447D418DAA82
`0xF6F5447D418DAA82` | `Any _0xF6F5447D418DAA82(Any p0)` | build 1207

## _0xFA15C9A320E707B0
`0xFA15C9A320E707B0` | `void _0xFA15C9A320E707B0()` | build 1207
nullsub, doesn't do anything

## _ADD_BOUNDS_TO_AGGREGATE_VOLUME
`0x6E0D3C3F828DA773` | `void _ADD_BOUNDS_TO_AGGREGATE_VOLUME(Volume volume, Volume aggregate)` | build 1207
_ADD_R* - _ADD_V(OLUME?)*

## _ADD_BOX_VOLUME_TO_VOLUME_AGGREGATE
`0x39816F6F94F385AD` | `void _ADD_BOX_VOLUME_TO_VOLUME_AGGREGATE(Volume aggregate, float p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, float p9)` | build 1207

## _ADD_CYLINDER_VOLUME_TO_VOLUME_AGGREGATE
`0xBCE668AAF83608BE` | `void _ADD_CYLINDER_VOLUME_TO_VOLUME_AGGREGATE(Volume aggregate, float p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, float p9)` | build 1207

## _ADD_ENTRY_VOLUME_LOCK
`0x58D3803FA639A3BB` | `BOOL _ADD_ENTRY_VOLUME_LOCK(Any* args)` | build 1311

## _ADD_SPHERE_VOLUME_TO_VOLUME_AGGREGATE
`0x5B7D7BF36D2DE18B` | `void _ADD_SPHERE_VOLUME_TO_VOLUME_AGGREGATE(Volume aggregate, float p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, float p9)` | build 1207

## _ADD_VOLUME_TO_VOLUME_AGGREGATE
`0x12FCAA23F2320422` | `void _ADD_VOLUME_TO_VOLUME_AGGREGATE(Volume aggregate, Hash typeHash, float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1207

## _CREATE_ANTI_GRIEF_VOLUME
`0x0EB78C2B156635B1` | `Volume _CREATE_ANTI_GRIEF_VOLUME(Hash volumeType, float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1207

## _CREATE_SPEED_VOLUME
`0xBBE768E3AE76E07C` | `Volume _CREATE_SPEED_VOLUME(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14)` | build 1207

## _CREATE_VOLUME_AGGREGATE_WITH_CUSTOM_NAME
`0x5D580DE6398BB162` | `Volume _CREATE_VOLUME_AGGREGATE_WITH_CUSTOM_NAME(char* name)` | build 1207

## _CREATE_VOLUME_BOX_WITH_CUSTOM_NAME
`0xF68485C7495D848E` | `Volume _CREATE_VOLUME_BOX_WITH_CUSTOM_NAME(float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ, char* name)` | build 1207

## _CREATE_VOLUME_BY_HASH
`0x502022FA1AF9DC86` | `Volume _CREATE_VOLUME_BY_HASH(Hash volumeType, float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1207

## _CREATE_VOLUME_BY_HASH_WITH_CUSTOM_NAME
`0x1F85E4AC774A201E` | `Volume _CREATE_VOLUME_BY_HASH_WITH_CUSTOM_NAME(Hash volumeType, float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ, char* name)` | build 1207

## _CREATE_VOLUME_CYLINDER_WITH_CUSTOM_NAME
`0xDF1E350EDDF06E59` | `Volume _CREATE_VOLUME_CYLINDER_WITH_CUSTOM_NAME(float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ, char* name)` | build 1207

## _CREATE_VOLUME_LOCK
`0x00BBF7CEAE8C666A` | `Volume _CREATE_VOLUME_LOCK(float x, float y, float z, float radius, int flag, Any p5)` | build 1207
Params: p5 is always 0

## _CREATE_VOLUME_LOCK_ATTACHED_TO_ENTITY
`0xF383E96C4904DF0C` | `Volume _CREATE_VOLUME_LOCK_ATTACHED_TO_ENTITY(Entity entity, float radius, int flag, Any p3)` | build 1207
Params: p3 is always 0

## _CREATE_VOLUME_SPHERE_WITH_CUSTOM_NAME
`0x10157BC3247FF3BA` | `Volume _CREATE_VOLUME_SPHERE_WITH_CUSTOM_NAME(float x, float y, float z, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ, char* name)` | build 1207

## _CREATE_WALK_AND_TALK_VOLUME
`0xFD0E389CD44434B6` | `Volume _CREATE_WALK_AND_TALK_VOLUME(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12)` | build 1207

## _FIND_VOLUME_LOCK_REQUEST_ID_WITH_ARGS
`0x77A6E4AD0C496F81` | `int _FIND_VOLUME_LOCK_REQUEST_ID_WITH_ARGS(Any* args)` | build 1207

## _GET_VOLUME_AMOUNT_OF_INDEXED_ITEMS
`0x2B32B11520626229` | `int _GET_VOLUME_AMOUNT_OF_INDEXED_ITEMS(float x, float y, float z, float radius, ItemSet itemSet)` | build 1207
Indexes items (including entyties and peds) in a set volume
Counts up as its the return value of how many items it writes to given itemSet

## _GET_VOLUME_BOUNDS
`0x5737199AF2DC609F` | `void _GET_VOLUME_BOUNDS(Volume volume, Vector3* min, Vector3* max)` | build 1207

## _GET_VOLUME_RELATIONSHIP
`0x666C2F53ABEFC952` | `Hash _GET_VOLUME_RELATIONSHIP(Volume volume)` | build 1207
Returns relationshipGroup Hash

## _IS_AGGREGATE_VOLUME
`0xFEFF01B5725BCD22` | `BOOL _IS_AGGREGATE_VOLUME(Volume volume)` | build 1207

## _IS_POINT_NEAR_VOLUME_LOCK_CENTER
`0x769BB7626B8CDB06` | `BOOL _IS_POINT_NEAR_VOLUME_LOCK_CENTER(float x, float y, float z, float radius, int p4, int p5, int flags)` | build 1207

## _IS_VOLUME_LOCK_REQUEST_VALID_2
`0xF6A8A652A6B186CD` | `BOOL _IS_VOLUME_LOCK_REQUEST_VALID_2(int volLockRequestId)` | build 1207

## _MODIFY_VOLUME_LOCK_LOCATION
`0xEC43C2FFB70E3F30` | `void _MODIFY_VOLUME_LOCK_LOCATION(int volLock, float x, float y, float z)` | build 1207

## _RELEASE_LOCK_VOLUME
`0xFDFECC6EE4491E11` | `void _RELEASE_LOCK_VOLUME(int volLockRequestId)` | build 1207

## _REMOVE_BOUNDS_FROM_AGGREGATE_VOLUME
`0xF92FA8890DECECF6` | `void _REMOVE_BOUNDS_FROM_AGGREGATE_VOLUME(Volume volume, Volume aggregate)` | build 1207
_REMOVE_E* - _REMOVE_R*

## _SET_ANTI_GRIEF_VOLUME_BLOCKS_HORSE
`0xBE551C2CC421185D` | `void _SET_ANTI_GRIEF_VOLUME_BLOCKS_HORSE(Volume volume, BOOL toggle)` | build 1207

## _SET_ANTI_GRIEF_VOLUME_BLOCKS_PLAYER
`0x5B23DFF8E0948BB2` | `void _SET_ANTI_GRIEF_VOLUME_BLOCKS_PLAYER(Volume volume, BOOL toggle)` | build 1207

## _SET_VOLUME_RELATIONSHIP
`0xFD010A2154B40676` | `void _SET_VOLUME_RELATIONSHIP(Volume volume, Hash relationshipGroup)` | build 1207
