# OBJECT natives (153)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ALLOW_DAMAGE_EVENTS_FOR_NON_NETWORKED_OBJECTS
`0xE2B3B852B537C398` | `void ALLOW_DAMAGE_EVENTS_FOR_NON_NETWORKED_OBJECTS(BOOL enabled)` | build 1207

## ATTACH_PORTABLE_PICKUP_TO_PED
`0x8DC39368BDD57755` | `void ATTACH_PORTABLE_PICKUP_TO_PED(Object pickupObject, Ped ped)` | build 1207

## BLOCK_PICKUP_FROM_PLAYER_COLLECTION
`0xB8F5062070BB6DBD` | `void BLOCK_PICKUP_FROM_PLAYER_COLLECTION(Any p0, Any p1)` | build 1207

## BREAK_ALL_OBJECT_FRAGMENT_BONES
`0x8462BE2341A55B6F` | `void BREAK_ALL_OBJECT_FRAGMENT_BONES(Object object)` | build 1207

## BREAK_OBJECT_FRAGMENT_CHILD
`0xE7E4C198B0185900` | `void BREAK_OBJECT_FRAGMENT_CHILD(Object object, Any p1, BOOL p2)` | build 1207

## CONVERT_OLD_PICKUP_TYPE_TO_NEW
`0x5EAAD83F8CFB4575` | `Hash CONVERT_OLD_PICKUP_TYPE_TO_NEW(Hash pickupHash)` | build 1207
Old name: _GET_PICKUP_HASH

## CREATE_AMBIENT_PICKUP
`0x673966A0C0FD7171` | `Object CREATE_AMBIENT_PICKUP(Hash pickupHash, float x, float y, float z, int flags, int amount, Hash modelHash, BOOL createAsScriptObject, BOOL scriptHostObject, int customAmmoType, float p10)` | build 1207
flags: see CREATE_PICKUP

## CREATE_OBJECT
`0x509D5878EB39E842` | `Object CREATE_OBJECT(Hash modelHash, float x, float y, float z, BOOL isNetwork, BOOL bScriptHostObj, BOOL dynamic, BOOL p7, BOOL p8)` | build 1207

## CREATE_OBJECT_NO_OFFSET
`0x9A294B2138ABB884` | `Object CREATE_OBJECT_NO_OFFSET(Hash modelHash, float x, float y, float z, BOOL isNetwork, BOOL bScriptHostObj, BOOL dynamic, BOOL p7)` | build 1207

## CREATE_OBJECT_SKELETON
`0xB6CBD40F8EA69E8A` | `BOOL CREATE_OBJECT_SKELETON(Object object)` | build 1207

## CREATE_PICKUP
`0xFBA08C503DD5FA58` | `Pickup CREATE_PICKUP(Hash pickupHash, float x, float y, float z, int flags, int p5, BOOL p6, Hash modelHash, int p8, float p9, Any p10)` | build 1207
https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/Placement%20Flags
https://github.com/femga/rdr3_discoveries/blob/master/objects/pickup_list.lua

## CREATE_PICKUP_ROTATE
`0x891804727E0A98B7` | `Pickup CREATE_PICKUP_ROTATE(Hash pickupHash, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, int flags, int p8, int p9, BOOL p10, Hash modelHash, int p12, float p13, Any p14)` | build 1207
flags: see CREATE_PICKUP

## CREATE_PORTABLE_PICKUP
`0x2EAF1FDB2FB55698` | `Object CREATE_PORTABLE_PICKUP(Hash pickupHash, float x, float y, float z, BOOL placeOnGround, Hash modelHash)` | build 1207

## DELETE_OBJECT
`0x931914268722C263` | `void DELETE_OBJECT(Object* object)` | build 1207
Deletes the specified object, then sets the handle pointed to by the pointer to NULL.

## DETACH_PORTABLE_PICKUP_FROM_PED
`0xCF463D1E9A0AECB1` | `void DETACH_PORTABLE_PICKUP_FROM_PED(Object pickupObject)` | build 1207

## DOES_OBJECT_OF_TYPE_EXIST_AT_COORDS
`0xBFA48E2FF417213F` | `BOOL DOES_OBJECT_OF_TYPE_EXIST_AT_COORDS(float x, float y, float z, float radius, Hash hash, BOOL p5)` | build 1207

## DOES_PICKUP_EXIST
`0xAFC1CA75AD4074D1` | `BOOL DOES_PICKUP_EXIST(Pickup pickup)` | build 1207

## DOES_PICKUP_OBJECT_EXIST
`0xD9EFB6DBF7DAAEA3` | `BOOL DOES_PICKUP_OBJECT_EXIST(Object pickupObject)` | build 1207

## DOES_PICKUP_OF_TYPE_EXIST_IN_AREA
`0xF9C36251F6E48E33` | `BOOL DOES_PICKUP_OF_TYPE_EXIST_IN_AREA(Hash pickupHash, float x, float y, float z, float radius)` | build 1207

## DOES_RAYFIRE_MAP_OBJECT_EXIST
`0x52AF537A0C5B8AAD` | `BOOL DOES_RAYFIRE_MAP_OBJECT_EXIST(Object object)` | build 1207

## DOOR_SYSTEM_GET_DOOR_STATE
`0x160AA1B32F6139B8` | `int DOOR_SYSTEM_GET_DOOR_STATE(Hash doorHash)` | build 1207

## DOOR_SYSTEM_GET_OPEN_RATIO
`0x65499865FCA6E5EC` | `float DOOR_SYSTEM_GET_OPEN_RATIO(Hash doorHash)` | build 1207

## DOOR_SYSTEM_SET_AUTOMATIC_DISTANCE
`0x9BA001CB45CBF627` | `void DOOR_SYSTEM_SET_AUTOMATIC_DISTANCE(Hash doorHash, float distance)` | build 1207

## DOOR_SYSTEM_SET_AUTOMATIC_RATE
`0x03C27E13B42A0E82` | `void DOOR_SYSTEM_SET_AUTOMATIC_RATE(Hash doorHash, float rate)` | build 1207

## DOOR_SYSTEM_SET_DOOR_STATE
`0x6BAB9442830C7F53` | `void DOOR_SYSTEM_SET_DOOR_STATE(Hash doorHash, int state)` | build 1207
Door lock states:
enum eDoorState
{
	DOORSTATE_INVALID = -1,
	DOORSTATE_UNLOCKED,
	DOORSTATE_LOCKED_UNBREAKABLE,
	DOORSTATE_LOCKED_BREAKABLE,
	DOORSTATE_HOLD_OPEN_POSITIVE,
	DOORSTATE_HOLD_OPEN_NEGATIVE
};

## DOOR_SYSTEM_SET_OPEN_RATIO
`0xB6E6FBA95C7324AC` | `void DOOR_SYSTEM_SET_OPEN_RATIO(Hash doorHash, float ajar, BOOL forceUpdate)` | build 1207
Sets the ajar angle of a door.
Ranges from -1.0 to 1.0, and 0.0 is closed / default.

## FIX_OBJECT_FRAGMENT
`0xF9C1681347C8BD15` | `void FIX_OBJECT_FRAGMENT(Object object)` | build 1207

## FORCE_PICKUP_REGENERATE
`0x758A5C1B3B1E1990` | `void FORCE_PICKUP_REGENERATE(Any p0)` | build 1207

## GET_CLOSEST_OBJECT_OF_TYPE
`0xE143FA2249364369` | `Object GET_CLOSEST_OBJECT_OF_TYPE(float x, float y, float z, float radius, Hash modelHash, BOOL missionScriptObject, BOOL scriptHostObject, BOOL networkObject)` | build 1207
Returns the closest object of a specified type within a given radius from a specified position

## GET_OBJECT_FRAGMENT_DAMAGE_HEALTH
`0xB6FBFD079B8D0596` | `float GET_OBJECT_FRAGMENT_DAMAGE_HEALTH(Any p0, BOOL p1)` | build 1207

## GET_OFFSET_FROM_COORD_AND_HEADING_IN_WORLD_COORDS
`0x163E252DE035A133` | `Vector3 GET_OFFSET_FROM_COORD_AND_HEADING_IN_WORLD_COORDS(float xPos, float yPos, float zPos, float heading, float xOffset, float yOffset, float zOffset)` | build 1207
Old name: _GET_OBJECT_OFFSET_FROM_COORDS

## GET_PICKUP_COORDS
`0x225B8B35C88029B3` | `Vector3 GET_PICKUP_COORDS(Pickup pickup)` | build 1207

## GET_PICKUP_OBJECT
`0x5099BC55630B25AE` | `Object GET_PICKUP_OBJECT(Pickup pickup)` | build 1207

## GET_RAYFIRE_MAP_OBJECT
`0xB48FCED898292E52` | `Object GET_RAYFIRE_MAP_OBJECT(float x, float y, float z, float radius, const char* name)` | build 1207

## GET_RAYFIRE_MAP_OBJECT_ANIM_PHASE
`0x260EE4FDBDF4DB01` | `float GET_RAYFIRE_MAP_OBJECT_ANIM_PHASE(Object object)` | build 1207

## GET_SAFE_PICKUP_COORDS
`0x6E16BC2503FF1FF0` | `Vector3 GET_SAFE_PICKUP_COORDS(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## GET_STATE_OF_RAYFIRE_MAP_OBJECT
`0x899BA936634A322E` | `int GET_STATE_OF_RAYFIRE_MAP_OBJECT(Object object)` | build 1207

## GET_WEAPON_TYPE_FROM_PICKUP_TYPE
`0x08F96CA6C551AD51` | `Hash GET_WEAPON_TYPE_FROM_PICKUP_TYPE(Hash pickupHash)` | build 1207

## HAS_CLOSEST_OBJECT_OF_TYPE_BEEN_BROKEN
`0x761B0E69AC4D007E` | `BOOL HAS_CLOSEST_OBJECT_OF_TYPE_BEEN_BROKEN(float p0, float p1, float p2, float p3, Hash modelHash, Any p5)` | build 1207

## HAS_OBJECT_BEEN_BROKEN
`0x8ABFB70C49CC43E2` | `BOOL HAS_OBJECT_BEEN_BROKEN(Any p0)` | build 1207

## HAS_PICKUP_BEEN_COLLECTED
`0x80EC48E6679313F9` | `BOOL HAS_PICKUP_BEEN_COLLECTED(Pickup pickup)` | build 1207

## IS_DOOR_CLOSED
`0xC531EE8A1145A149` | `BOOL IS_DOOR_CLOSED(Hash doorHash)` | build 1207

## IS_DOOR_REGISTERED_WITH_SYSTEM
`0xC153C43EA202C8C1` | `BOOL IS_DOOR_REGISTERED_WITH_SYSTEM(Hash doorHash)` | build 1207

## IS_OBJECT_A_PORTABLE_PICKUP
`0x0378C08504160D0D` | `BOOL IS_OBJECT_A_PORTABLE_PICKUP(Object object)` | build 1207

## IS_OBJECT_VISIBLE
`0x8B32ACE6326A7546` | `BOOL IS_OBJECT_VISIBLE(Object object)` | build 1207

## IS_POINT_IN_ANGLED_AREA
`0x2A70BAE8883E4C81` | `BOOL IS_POINT_IN_ANGLED_AREA(float p0, float p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, float p9, BOOL p10, BOOL p11)` | build 1207

## ONLY_CLEAN_UP_OBJECT_WHEN_OUT_OF_RANGE
`0xADBE4809F19F927A` | `void ONLY_CLEAN_UP_OBJECT_WHEN_OUT_OF_RANGE(Object object)` | build 1207
Old name: _MARK_OBJECT_FOR_DELETION

## PLACE_OBJECT_ON_GROUND_PROPERLY
`0x58A850EAEE20FAA3` | `BOOL PLACE_OBJECT_ON_GROUND_PROPERLY(Object object, BOOL p1)` | build 1207

## PREVENT_COLLECTION_OF_PORTABLE_PICKUP
`0x92AEFB5F6E294023` | `void PREVENT_COLLECTION_OF_PORTABLE_PICKUP(Object object, BOOL p1, BOOL p2)` | build 1207

## REMOVE_ALL_PICKUPS_OF_TYPE
`0x27F9D613092159CF` | `void REMOVE_ALL_PICKUPS_OF_TYPE(Hash pickupHash)` | build 1207

## REMOVE_DOOR_FROM_SYSTEM
`0x464D8E1427156FE4` | `void REMOVE_DOOR_FROM_SYSTEM(Hash doorHash)` | build 1207

## REMOVE_PICKUP
`0x3288D8ACAECD2AB2` | `void REMOVE_PICKUP(Pickup pickup)` | build 1207

## SET_ACTIVATE_OBJECT_PHYSICS_AS_SOON_AS_IT_IS_UNFROZEN
`0x406137F8EF90EAF5` | `void SET_ACTIVATE_OBJECT_PHYSICS_AS_SOON_AS_IT_IS_UNFROZEN(Object object, BOOL toggle)` | build 1207

## SET_CUSTOM_TEXTURES_ON_OBJECT
`0xE124889AE0521FCF` | `void SET_CUSTOM_TEXTURES_ON_OBJECT(Object object, Hash txdHash, Any p2, Any p3)` | build 1207

## SET_FORCE_OBJECT_THIS_FRAME
`0xF538081986E49E9D` | `void SET_FORCE_OBJECT_THIS_FRAME(float x, float y, float z, float p3)` | build 1207

## SET_LOCAL_PLAYER_CAN_COLLECT_PORTABLE_PICKUPS
`0x78857FC65CADB909` | `void SET_LOCAL_PLAYER_CAN_COLLECT_PORTABLE_PICKUPS(BOOL toggle)` | build 1207

## SET_LOCAL_PLAYER_PERMITTED_TO_COLLECT_PICKUPS_WITH_MODEL
`0x88EAEC617CD26926` | `void SET_LOCAL_PLAYER_PERMITTED_TO_COLLECT_PICKUPS_WITH_MODEL(Hash modelHash, BOOL toggle)` | build 1207
Maximum amount of pickup models that can be disallowed is 10.

Old name: _SET_LOCAL_PLAYER_CAN_USE_PICKUPS_WITH_THIS_MODEL

## SET_MAX_NUM_PORTABLE_PICKUPS_CARRIED_BY_PLAYER
`0x0BF3B3BD47D79C08` | `void SET_MAX_NUM_PORTABLE_PICKUPS_CARRIED_BY_PLAYER(Hash modelHash, int p1)` | build 1207

## SET_OBJECT_ALLOW_LOW_LOD_BUOYANCY
`0x4D89D607CB3DD1D2` | `void SET_OBJECT_ALLOW_LOW_LOD_BUOYANCY(Object object, BOOL toggle)` | build 1207

## SET_OBJECT_PHYSICS_PARAMS
`0xF6DF6E90DE7DF90F` | `void SET_OBJECT_PHYSICS_PARAMS(Object object, float weight, float p2, float p3, float p4, float p5, float gravity, float p7, float p8, float p9, float p10, float buoyancy)` | build 1207
Adjust the physics parameters of a prop, or otherwise known as "object". This is useful for simulated gravity.

Other parameters seem to be unknown.

p2: seems to be weight and gravity related. Higher value makes the obj fall faster. Very sensitive?
p3: seems similar to p2
p4: makes obj fall slower the higher the value
p5: similar to p4

## SET_OBJECT_TAKES_DAMAGE_FROM_COLLIDING_WITH_BUILDINGS
`0xEB6F1A9B5510A5D2` | `void SET_OBJECT_TAKES_DAMAGE_FROM_COLLIDING_WITH_BUILDINGS(Object object, BOOL enabled)` | build 1207

## SET_OBJECT_TARGETTABLE
`0x8A7391690F5AFD81` | `void SET_OBJECT_TARGETTABLE(Object object, BOOL targettable)` | build 1207

## SET_OBJECT_TINT_INDEX
`0x971DA0055324D033` | `void SET_OBJECT_TINT_INDEX(Object object, int textureVariation)` | build 1207
Alt name: _SET_OBJECT_TINT

Old name: _SET_OBJECT_TEXTURE_VARIATION

## SET_PICKUP_DO_NOT_AUTO_PLACE_ON_GROUND
`0x634C19521485AB25` | `void SET_PICKUP_DO_NOT_AUTO_PLACE_ON_GROUND(Object pickupObject)` | build 1207

## SET_PICKUP_GENERATION_RANGE_MULTIPLIER
`0x318516E02DE3ECE2` | `void SET_PICKUP_GENERATION_RANGE_MULTIPLIER(float multiplier)` | build 1207

## SET_PICKUP_HIDDEN_WHEN_UNCOLLECTABLE
`0x81218CE01B672219` | `void SET_PICKUP_HIDDEN_WHEN_UNCOLLECTABLE(Any p0, Any p1)` | build 1207

## SET_PICKUP_NOT_LOOTABLE
`0x92E87F60F21A0C3A` | `void SET_PICKUP_NOT_LOOTABLE(Any p0, Any p1)` | build 1207

## SET_PICKUP_PARTICLE_FX_HIGHLIGHT
`0x1607C7D9B3021DF5` | `void SET_PICKUP_PARTICLE_FX_HIGHLIGHT(Any p0, Any p1)` | build 1207

## SET_PICKUP_PARTICLE_FX_SPAWN
`0xEB9740A38FD6D634` | `void SET_PICKUP_PARTICLE_FX_SPAWN(Any p0, Any p1)` | build 1207

## SET_PICKUP_REGENERATION_TIME
`0x78015C9B4B3ECC9D` | `void SET_PICKUP_REGENERATION_TIME(Pickup pickup, int duration)` | build 1207

## SET_PICKUP_UNCOLLECTABLE
`0x4A8CB328CD6F1C9B` | `void SET_PICKUP_UNCOLLECTABLE(Any p0, Any p1)` | build 1207

## SET_STATE_OF_RAYFIRE_MAP_OBJECT
`0x5C29F698D404C5E1` | `void SET_STATE_OF_RAYFIRE_MAP_OBJECT(Object object, int state)` | build 1207

## SET_TEAM_PICKUP_OBJECT
`0x53E0DF1A2A3CF0CA` | `void SET_TEAM_PICKUP_OBJECT(Object object, Any p1, BOOL p2)` | build 1207

## SLIDE_OBJECT
`0x2FDFF4107B8C1147` | `BOOL SLIDE_OBJECT(Object object, float toX, float toY, float toZ, float speedX, float speedY, float speedZ, BOOL collision)` | build 1207

## SUPPRESS_PICKUP_REWARD_TYPE
`0xF92099527DB8E2A7` | `void SUPPRESS_PICKUP_REWARD_TYPE(int rewardType, BOOL suppress)` | build 1207

## TRACK_OBJECT_VISIBILITY
`0xB252BC036B525623` | `void TRACK_OBJECT_VISIBILITY(Object object)` | build 1207

## _0x08C5825A2932EA7B
`0x08C5825A2932EA7B` | `Any _0x08C5825A2932EA7B(Any p0)` | build 1207

## _0x0C0A373D181BF900
`0x0C0A373D181BF900` | `void _0x0C0A373D181BF900(Hash doorHash)` | build 1207
something to do with doors lockdown when navmesh is swapping?UPDATE_WORLD_STATE  seems to be for unlocking something

## _0x1F5E07E14A86FAFC
`0x1F5E07E14A86FAFC` | `void _0x1F5E07E14A86FAFC(BOOL p0)` | build 1207
_SET_A(MBIENT_PICKUP_?)*

## _0x22031584496CFB70
`0x22031584496CFB70` | `void _0x22031584496CFB70(Any p0, Any p1)` | build 1207

## _0x235C863DA77BD88D
`0x235C863DA77BD88D` | `Any _0x235C863DA77BD88D(Any p0, Any p1, Any p2)` | build 1207

## _0x250EBB11E81A10BE
`0x250EBB11E81A10BE` | `Any _0x250EBB11E81A10BE(Any p0)` | build 1207

## _0x2BF1953C0C21AC88
`0x2BF1953C0C21AC88` | `Any _0x2BF1953C0C21AC88(Any p0)` | build 1207

## _0x3A77DAE8B4FD7586
`0x3A77DAE8B4FD7586` | `void _0x3A77DAE8B4FD7586(Any p0, Any p1)` | build 1207

## _0x3DF1A0A58498E209
`0x3DF1A0A58498E209` | `void _0x3DF1A0A58498E209(Object object, Any p1)` | build 1436

## _0x3E2616E7EA539480
`0x3E2616E7EA539480` | `Any _0x3E2616E7EA539480(Any p0)` | build 1207

## _0x46CBCF0E98A4E156
`0x46CBCF0E98A4E156` | `void _0x46CBCF0E98A4E156(Any p0, Any p1)` | build 1207

## _0x491439AEF410A2FC
`0x491439AEF410A2FC` | `void _0x491439AEF410A2FC(Any p0)` | build 1207

## _0x4AE07EBA3462C5D5
`0x4AE07EBA3462C5D5` | `void _0x4AE07EBA3462C5D5(Any p0, Any p1)` | build 1207

## _0x57C242543B7B8FB9
`0x57C242543B7B8FB9` | `void _0x57C242543B7B8FB9(Any p0, Any p1)` | build 1207

## _0x614D0B4533F842D3
`0x614D0B4533F842D3` | `Any _0x614D0B4533F842D3(Any p0)` | build 1207

## _0x6579860A5558524A
`0x6579860A5558524A` | `void _0x6579860A5558524A(Any p0, Any p1)` | build 1207

## _0x7D4411D6736CD295
`0x7D4411D6736CD295` | `Any _0x7D4411D6736CD295(Any p0, Any p1)` | build 1207

## _0x7F458B543006C8FE
`0x7F458B543006C8FE` | `void _0x7F458B543006C8FE(Hash doorHash, int p1)` | build 1207
something to do with doors lockdown when navmesh is swapping? UPDATE_WORLD_STATE, seems to be for locking something

## _0x9A74A9CADFA8A598
`0x9A74A9CADFA8A598` | `void _0x9A74A9CADFA8A598(Any p0)` | build 1207

## _0xACD4F9831DFAD7F5
`0xACD4F9831DFAD7F5` | `Any _0xACD4F9831DFAD7F5(Any p0)` | build 1207

## _0xCBFBD38F2E0A263B
`0xCBFBD38F2E0A263B` | `void _0xCBFBD38F2E0A263B(Any p0, Any p1)` | build 1207

## _0xCEAB54F4632C6EF6
`0xCEAB54F4632C6EF6` | `void _0xCEAB54F4632C6EF6(Any p0, Any p1)` | build 1207

## _0xD91E55B6C005EB09
`0xD91E55B6C005EB09` | `Any _0xD91E55B6C005EB09(Any p0, Any p1)` | build 1207

## _0xDE116ECFFDD4B997
`0xDE116ECFFDD4B997` | `void _0xDE116ECFFDD4B997(Any p0, Any p1)` | build 1207

## _0xDFA1237F5228263F
`0xDFA1237F5228263F` | `void _0xDFA1237F5228263F(Any p0, Any p1)` | build 1207

## _0xF65EDE5D02A7A760
`0xF65EDE5D02A7A760` | `void _0xF65EDE5D02A7A760(Any p0, Any p1)` | build 1207

## _0xF6E88489B4E6EBE5
`0xF6E88489B4E6EBE5` | `void _0xF6E88489B4E6EBE5(Any p0, Any p1)` | build 1207

## _0xFA99E8E575F2FEF8
`0xFA99E8E575F2FEF8` | `Any _0xFA99E8E575F2FEF8(Any p0)` | build 1436

## _ADD_DOOR_TO_SYSTEM_NEW
`0xD99229FE93B46286` | `void _ADD_DOOR_TO_SYSTEM_NEW(Hash doorHash, BOOL p1, BOOL p2, BOOL p3, int threadId, int p5, BOOL p6)` | build 1207
Registers a door, hashes: https://github.com/femga/rdr3_discoveries/tree/master/doorHashes

## _CHECK_DOOR_ACTION_FLAG
`0x0943113E02322164` | `Any _CHECK_DOOR_ACTION_FLAG(Object object, int p1)` | build 1207
Checks whether a specific door-related action/state flag is active for the given door object.
Observed behavior:
- flag 32: returns true when the door is being kicked (kick action event)
- flag 23: returns true if the door has been previously opened by kicking (post-kick state)
- flag 8:  returns true when attempting to open the door while it is locked

## _DAMAGE_BONE_ON_PROP
`0xE4EFB315BCD2A838` | `void _DAMAGE_BONE_ON_PROP(Object object, int bone)` | build 1207

## _DAMAGE_OBJECT_FRAGMENT_BY_INDEX
`0xAAACF33CBF9B990A` | `void _DAMAGE_OBJECT_FRAGMENT_BY_INDEX(Object object, int fragmentIndex)` | build 1207
Damages or breaks a specific predefined fragment/section of an object using the provided fragment index.
Unlike generic damage systems, this native appears to directly target one of the object's internal fracture sections. The index parameter determines which part of the object is damaged or broken.
Different index values cause different fragments of the object to detach or break.

## _DOOR_SYSTEM_CHANGE_SCRIPT_OWNER
`0x985767F5FA45BC44` | `void _DOOR_SYSTEM_CHANGE_SCRIPT_OWNER(Hash doorHash)` | build 1207

## _DOOR_SYSTEM_CHECK_ACTION_FLAG
`0x6E2AA80BB0C03728` | `BOOL _DOOR_SYSTEM_CHECK_ACTION_FLAG(Hash doorHash, int flag)` | build 1207
Checks whether a specific door action/state flag is active for the given door hash.
- flag 32: returns true while the door is being kicked
- flag 23: returns true after the door has been opened by kicking
- flag 8:  returns true when trying to open a locked door

## _DOOR_SYSTEM_CLEAR_FORCED_OPEN_PLAYER
`0x5230BF34EB0EC645` | `void _DOOR_SYSTEM_CLEAR_FORCED_OPEN_PLAYER(Hash doorHash)` | build 1207
Clears the stored player ID for a door that was force-opened via physical interaction
(e.g. kick or shoulder bash).
This resets the value returned by:_DOOR_SYSTEM_GET_FORCED_OPEN_PLAYER

## _DOOR_SYSTEM_FORCE_SHUT
`0x276AAF0F1C7F2494` | `void _DOOR_SYSTEM_FORCE_SHUT(Hash doorHash, BOOL p1)` | build 1207

## _DOOR_SYSTEM_GET_AUTOMATIC_RATE
`0x8433E1954BE323FC` | `float _DOOR_SYSTEM_GET_AUTOMATIC_RATE(Hash doorHash)` | build 1207

## _DOOR_SYSTEM_GET_FORCED_OPEN_PLAYER
`0xEBA314768FB35D58` | `int _DOOR_SYSTEM_GET_FORCED_OPEN_PLAYER(Hash doorHash)` | build 1207
Returns the player who forced the specified door open using physical interaction
(e.g. kicking or shoulder bashing).
If a player breaks or forces the door open, this native returns the Player ID directly.

## _DOOR_SYSTEM_SET_ABLE_TO_CHANGE_OPEN_RATIO_WHILE_LOCKED
`0x1F1FABFE9B2A1254` | `void _DOOR_SYSTEM_SET_ABLE_TO_CHANGE_OPEN_RATIO_WHILE_LOCKED(Hash doorHash, BOOL p1)` | build 1207

## _DOOR_SYSTEM_SET_AUTOMATIC_STATE
`0x1BC47A9DEDC8DF5D` | `void _DOOR_SYSTEM_SET_AUTOMATIC_STATE(Hash doorHash, BOOL disable)` | build 1207
_ALLOW_* - _ATTACH_*

## _DOOR_SYSTEM_SWING_OPEN
`0xB3B1546D23DF8DE1` | `void _DOOR_SYSTEM_SWING_OPEN(Hash doorHash, float dirX, float dirY, float dirZ, BOOL reverse)` | build 1207
swing door open between 2 points
Requires DOOR_SYSTEM_SET_DOOR_STATE(hash, 0) beforehand
- If door is locked (state=1), the impulse is ignored

## _GET_AMMO_TYPE_FROM_PICKUP_TYPE
`0x44B09A23D728045A` | `Hash _GET_AMMO_TYPE_FROM_PICKUP_TYPE(Hash pickupHash)` | build 1207

## _GET_DOOR_KNOCKING_WHEN_LOCKED
`0x4D8611DFE1126478` | `BOOL _GET_DOOR_KNOCKING_WHEN_LOCKED(Hash doorHash)` | build 1207
Checks whether the specified door has the "knocking when locked" interaction enabled

## _GET_LIGHT_INTENSITY_FROM_OBJECT
`0xFA3B61EC249B4674` | `float _GET_LIGHT_INTENSITY_FROM_OBJECT(Object object)` | build 1207

## _GET_OBJECT_FRAGMENT_COUNT
`0x58DE624FA7FB0E7F` | `int _GET_OBJECT_FRAGMENT_COUNT(Object object)` | build 1207
Returns the number of breakable fragments (indexed sections) defined for the specified object.
These fragments can be triggered individually using natives that target object fracture indices. eg: a box of bottles can have multiple fragments that can be broken individually.

## _GET_OBJECT_LIGHT_INTENSITY
`0x3397CD4E0353DFBA` | `float _GET_OBJECT_LIGHT_INTENSITY(Object object)` | build 1207
Returns float value to be used with _SET_LIGHT_INTENSITY_FOR_OBJECT

## _HIDE_PICKUP_OBJECT
`0x2777150CC7D9365E` | `void _HIDE_PICKUP_OBJECT(Object pickupObject, BOOL toggle)` | build 1207

## _IS_DOOR_REGISTERED_WITH_NETWORK
`0xB5DED7B65C604FDF` | `BOOL _IS_DOOR_REGISTERED_WITH_NETWORK(Hash doorHash)` | build 1207

## _IS_DOOR_REGISTERED_WITH_OWNER
`0x4F89DAD4156BA145` | `BOOL _IS_DOOR_REGISTERED_WITH_OWNER(Hash doorHash)` | build 1207
Returns true if door is alredy registered with owner

## _IS_MODEL_A_PORTABLE_PICKUP
`0x20135AF9C10D2A3D` | `BOOL _IS_MODEL_A_PORTABLE_PICKUP(Hash modelHash)` | build 1207
returns true if the model hash is a portable pickup its used before creating a portable pick up for example

## _IS_PICKUP_PICKABLE_FOR_TEAM
`0x9F52AD67D1A91BAD` | `BOOL _IS_PICKUP_PICKABLE_FOR_TEAM(Object pickupObject, int teamId)` | build 1207

## _IS_PICKUP_TYPE_VALID
`0x007BD043587F7C82` | `BOOL _IS_PICKUP_TYPE_VALID(Hash pickupHash)` | build 1207

## _MAKE_ITEM_CARRIABLE
`0x1461DF6DB886BE3F` | `void _MAKE_ITEM_CARRIABLE(Object object)` | build 1207
_PRE* or _Q* or _RE*

## _RESET_OBJECT_VELOCITY
`0xF40AB58D83C35027` | `void _RESET_OBJECT_VELOCITY(Object object)` | build 1207

## _SET_AMBIENT_PICKUP_LIFETIME
`0xAC9AE68F0A463752` | `void _SET_AMBIENT_PICKUP_LIFETIME(int lifetime)` | build 1207

## _SET_AUTO_JUMPABLE_BY_HORSE
`0x98D2D9C053A1F449` | `void _SET_AUTO_JUMPABLE_BY_HORSE(Object object, BOOL p1)` | build 1207
Sets object as auto-jumpable by horse.

## _SET_DOOR_ENABLE_KICK_PROMPT
`0xC07B91B996C1DE89` | `void _SET_DOOR_ENABLE_KICK_PROMPT(Hash doorHash, BOOL enable)` | build 1207
Enables the kick prompt for a door

## _SET_DOOR_KNOCKING_WHEN_LOCKED
`0xA93F925F1942E434` | `void _SET_DOOR_KNOCKING_WHEN_LOCKED(Hash doorHash, BOOL enable)` | build 1207
Changes the interaction behavior for a locked door.
Normally, when interacting with a locked door, the character tries the handle. When this native is enabled, that behavior is replaced with a knocking/tapping interaction for the specified door.
With toggle enabled:
- pressing the interact button on a locked door makes the character knock/tap on the door instead of trying the handle
- this does not unlock the door
- if the door is in a breakable/force-open state, it may still be opened by physically forcing it (e.g. sprinting into it), but normal interaction still uses the knocking behavior

## _SET_LIGHT_INTENSITY_FOR_OBJECT
`0xF49574E2332A8F06` | `void _SET_LIGHT_INTENSITY_FOR_OBJECT(Object object, float lightIntensity)` | build 1207

## _SET_LIGHT_SCATTERING_DISABLED_FOR_OBJECT
`0x04D1D4E411CE52D0` | `void _SET_LIGHT_SCATTERING_DISABLED_FOR_OBJECT(Object object, BOOL disable)` | build 1207

## _SET_LIGHT_TRANSLUCENCY_FOR_OBJECT
`0x63E39F09310F481F` | `void _SET_LIGHT_TRANSLUCENCY_FOR_OBJECT(Object object, float value)` | build 1207
Params: value = 0.0 - 586.67 (?)

## _SET_NETWORK_PICKUP_USABLE_FOR_PLAYER
`0x94F3D956BFAEAE18` | `void _SET_NETWORK_PICKUP_USABLE_FOR_PLAYER(Player player, Hash pickupHash, BOOL isUsable)` | build 1207
Params: p2 controls whether to make pickups usable/collectable or not in networked games

## _SET_NOT_JUMPABLE_BY_HORSE
`0xE1C708BA4885796B` | `void _SET_NOT_JUMPABLE_BY_HORSE(Object object, BOOL p1)` | build 1207
Sets object as not jumpable by horse.

## _SET_OBJECT_BREAK_SCALE
`0xFFB99FFD17F65889` | `void _SET_OBJECT_BREAK_SCALE(Object object, float scale)` | build 1207

## _SET_OBJECT_BURN_INTENSITY
`0xC8E21C1677DC5E6F` | `void _SET_OBJECT_BURN_INTENSITY(Object object, float intensity)` | build 1207

## _SET_OBJECT_BURN_LEVEL
`0x2797C633DCDBBAC5` | `void _SET_OBJECT_BURN_LEVEL(Object object, float burnLevel, BOOL affectAsh)` | build 1207
Seems to mostly have effect on wood-made objects https://imgur.com/a/32oQvOn

## _SET_OBJECT_BURN_OPACITY
`0x7D7285EFEAB5AF15` | `void _SET_OBJECT_BURN_OPACITY(Object object, float opacity)` | build 1207

## _SET_OBJECT_BURN_SPEED
`0x646564A3B7DF68F8` | `void _SET_OBJECT_BURN_SPEED(Object object, float speed, float p2)` | build 1207
p2 is usually the same as speed parameter

## _SET_OBJECT_CAN_BE_TAGGED
`0xE157A8A336C7F04A` | `void _SET_OBJECT_CAN_BE_TAGGED(Object object, BOOL canBeTagged)` | build 1207
Sets if the object can be tagged while using Dead Eye

## _SET_OBJECT_INTERACTION_PRESET
`0xCAAF2BCCFEF37F77` | `void _SET_OBJECT_INTERACTION_PRESET(Object object, int presetFlags)` | build 1207

## _SET_OBJECT_KICKABLE
`0xB7017DA4D498269F` | `void _SET_OBJECT_KICKABLE(Object object, BOOL kickable)` | build 1207

## _SET_OBJECT_LANTERN_DISABLE_LIGHT
`0x7FCD49388BC9B775` | `void _SET_OBJECT_LANTERN_DISABLE_LIGHT(Object object, BOOL disable)` | build 1207
Primarily used on lantern weapon entities after they have been dropped.
This native does NOT affect lanterns while they are being held by a ped

## _SET_OBJECT_PROMPT_NAME
`0xAEE6C800E124CFE1` | `void _SET_OBJECT_PROMPT_NAME(Object object, const char* name)` | build 1207
Not official native name

## _SET_OBJECT_PROMPT_NAME_FROM_GXT_ENTRY
`0xD503D6F0986D58BC` | `void _SET_OBJECT_PROMPT_NAME_FROM_GXT_ENTRY(Object object, Hash gxtEntryHash)` | build 1207
Not official native name

## _SET_OBJECT_TARGETTABLE_2
`0x581EDBE56E8D62C9` | `void _SET_OBJECT_TARGETTABLE_2(Object object, BOOL targettable)` | build 1207

## _SET_OBJECT_TARGETTABLE_FOCUS
`0xA22712E8471AA08E` | `void _SET_OBJECT_TARGETTABLE_FOCUS(Object object, BOOL toggle, BOOL weaponLock)` | build 1207
focus on objects like focus on peds, p1 is to enable/disable p2 is to enable/disable focus when you have a weapon out

## _SET_PICKUP_COLLECTABLE_ON_MOUNT
`0x00EE08603EADEE92` | `void _SET_PICKUP_COLLECTABLE_ON_MOUNT(Object object)` | build 1207
