# ENTITY natives (268)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## APPLY_FORCE_TO_ENTITY
`0xF15E8F5D333F09C4` | `void APPLY_FORCE_TO_ENTITY(Entity entity, int forceFlags, float x, float y, float z, float offX, float offY, float offZ, int boneIndex, BOOL isDirectionRel, BOOL ignoreUpVec, BOOL isForceRel, BOOL p12, BOOL p13)` | build 1207

## APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS
`0x31DA7CEC5334DB37` | `void APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(Entity entity, int forceType, float x, float y, float z, int component, BOOL isDirectionRel, BOOL isForceRel, BOOL p8)` | build 1207
p6/relative - makes the xyz force not relative to world coords, but to something else
p7/highForce - setting false will make the force really low

## ATTACH_ENTITY_TO_ENTITY
`0x6B9BBD38AB0796DF` | `void ATTACH_ENTITY_TO_ENTITY(Entity entity1, Entity entity2, int boneIndex, float xPos, float yPos, float zPos, float xRot, float yRot, float zRot, BOOL p9, BOOL useSoftPinning, BOOL collision, BOOL isPed, int vertexIndex, BOOL fixedRot, BOOL p15, BOOL p16)` | build 1207
Attaches entity1 to bone (boneIndex) of entity2.

boneIndex - this is different to boneID, use GET_PED_BONE_INDEX to get the index from the ID. use the index for attaching to specific bones. entity1 will be attached to entity2's centre if bone index given doesn't correspond to bone indexes for that entity type.
https://github.com/femga/rdr3_discoveries/tree/master/boneNames

useSoftPinning - if set to false attached entity will not detach when fixed
collision - controls collision between the two entities (FALSE disables collision).
isPed - pitch doesn't work when false and roll will only work on negative numbers (only peds)
vertexIndex - position of vertex
fixedRot - if false it ignores entity vector

## ATTACH_ENTITY_TO_ENTITY_PHYSICALLY
`0xB629A43CA1643481` | `void ATTACH_ENTITY_TO_ENTITY_PHYSICALLY(Entity entity1, Entity entity2, int p2, int boneIndex, float offsetX, float offsetY, float offsetZ, float p7, float p8, float p9, float p10, float p11, float p12, float p13, BOOL p14, BOOL p15, BOOL p16, BOOL p17, int p18, BOOL p19, float p20, float p21)` | build 1207

## CLEAR_ENTITY_LAST_DAMAGE_ENTITY
`0xBB19AC7D4DCEFD0F` | `void CLEAR_ENTITY_LAST_DAMAGE_ENTITY(Entity entity)` | build 1207

## CREATE_FORCED_OBJECT
`0x0961A905AFBC34C7` | `void CREATE_FORCED_OBJECT(float x, float y, float z, Any p3, Hash modelHash, BOOL p5)` | build 1207

## CREATE_MODEL_HIDE
`0x069848B3FB3C4426` | `void CREATE_MODEL_HIDE(float x, float y, float z, float radius, Hash model, BOOL p5)` | build 1207

## CREATE_MODEL_HIDE_EXCLUDING_SCRIPT_OBJECTS
`0xD136090A9AAAB17D` | `void CREATE_MODEL_HIDE_EXCLUDING_SCRIPT_OBJECTS(float x, float y, float z, float radius, Hash model, BOOL p5)` | build 1207

## CREATE_MODEL_SWAP
`0x10B2218320B6F5AC` | `void CREATE_MODEL_SWAP(float x, float y, float z, float radius, Hash originalModel, Hash newModel, BOOL p6)` | build 1207
Only works with objects!

## DELETE_ENTITY
`0x4CD38C78BD19A497` | `void DELETE_ENTITY(Entity* entity)` | build 1207
Deletes the specified entity, then sets the handle pointed to by the pointer to NULL.

## DETACH_ENTITY
`0x64CDE9D6BF8ECAD3` | `void DETACH_ENTITY(Entity entity, BOOL p1, BOOL collision)` | build 1207

## DOES_ENTITY_BELONG_TO_THIS_SCRIPT
`0x622B1980CBE13332` | `BOOL DOES_ENTITY_BELONG_TO_THIS_SCRIPT(Entity entity, BOOL p1)` | build 1207

## DOES_ENTITY_EXIST
`0xD42BD6EB2E0F1677` | `BOOL DOES_ENTITY_EXIST(Entity entity)` | build 1207
Checks if the Entity exists

## DOES_ENTITY_HAVE_DRAWABLE
`0x20487F0DA9AF164A` | `BOOL DOES_ENTITY_HAVE_DRAWABLE(Entity entity)` | build 1207

## DOES_ENTITY_HAVE_PHYSICS
`0xA512B3F1B2A0B51C` | `BOOL DOES_ENTITY_HAVE_PHYSICS(Entity entity)` | build 1207

## FIND_ANIM_EVENT_PHASE
`0x42718CC559BD7776` | `BOOL FIND_ANIM_EVENT_PHASE(const char* animDictionary, const char* animName, const char* p2, Any* p3, Any* p4)` | build 1207

## FORCE_ENTITY_AI_AND_ANIMATION_UPDATE
`0x4C9E96473D4F1A88` | `void FORCE_ENTITY_AI_AND_ANIMATION_UPDATE(Entity entity, BOOL p1)` | build 1207

## FREEZE_ENTITY_POSITION
`0x7D9EFB7AD6B19754` | `void FREEZE_ENTITY_POSITION(Entity entity, BOOL toggle)` | build 1207

## GET_ANIM_DURATION
`0x9FFAF4940A54CC09` | `float GET_ANIM_DURATION(const char* animDict, const char* animName)` | build 1207

## GET_CARRIABLE_ENTITY_STATE
`0x61914209C36EFDDB` | `int GET_CARRIABLE_ENTITY_STATE(Entity entity)` | build 1207
enum eCarriableState
{
	CARRIABLE_STATE_NONE,
	CARRIABLE_STATE_TRANSITIONING_TO_HOGTIED,
	CARRIABLE_STATE_CARRIABLE_INTRO,
	CARRIABLE_STATE_CARRIABLE,
	CARRIABLE_STATE_BEING_PICKED_UP_FROM_GROUND,
	CARRIABLE_STATE_CARRIED_BY_HUMAN,
	CARRIABLE_STATE_BEING_PLACED_ON_GROUND,
	CARRIABLE_STATE_CARRIED_BY_MOUNT,
	CARRIABLE_STATE_BEING_PLACED_ON_MOUNT,
	CARRIABLE_STATE_BEING_PICKED_UP_FROM_MOUNT,
	CARRIABLE_STATE_BEING_CUT_FREE,
	CARRIABLE_STATE_BEING_PLACED_ON_GROUND_ESCAPE,
	CARRIABLE_STATE_BEING_PLACED_IN_VEHICLE
};

## GET_ENTITY_ALPHA
`0x1BB501624FAF2BEA` | `int GET_ENTITY_ALPHA(Entity entity)` | build 1207

## GET_ENTITY_ATTACHED_TO
`0x56D713888A566481` | `Entity GET_ENTITY_ATTACHED_TO(Entity entity)` | build 1207

## GET_ENTITY_BONE_INDEX_BY_NAME
`0xBACA8FE9C76C124E` | `int GET_ENTITY_BONE_INDEX_BY_NAME(Entity entity, const char* boneName)` | build 1207

## GET_ENTITY_CAN_BE_DAMAGED
`0x75DF9E73F2F005FD` | `BOOL GET_ENTITY_CAN_BE_DAMAGED(Entity entity)` | build 1207
Old name: _GET_ENTITY_CAN_BE_DAMAGED

## GET_ENTITY_COLLISION_DISABLED
`0xAA2FADD30F45A9DA` | `BOOL GET_ENTITY_COLLISION_DISABLED(Entity entity)` | build 1207

## GET_ENTITY_COORDS
`0xA86D5F069399F44D` | `Vector3 GET_ENTITY_COORDS(Entity entity, BOOL alive, BOOL realCoords)` | build 1207
Gets the current coordinates for a specified entity.
`entity` = The entity to get the coordinates from.
`alive` = Unused by the game, potentially used by debug builds in order to assert whether or not an entity was alive.

If entity is a ped and it's in a vehicle or on a mount the coords of that entity are returned. Set 'realCoords' to true when you need the true ped coords.

## GET_ENTITY_FORWARD_VECTOR
`0x2412D9C05BB09B97` | `Vector3 GET_ENTITY_FORWARD_VECTOR(Entity entity)` | build 1207
Gets the entity's forward vector in XY(Z) eulers.

## GET_ENTITY_FORWARD_X
`0xDB0954E9960F6457` | `float GET_ENTITY_FORWARD_X(Entity entity)` | build 1207
Gets the X-component of the entity's forward vector.

## GET_ENTITY_FORWARD_Y
`0x9A5C073ECBDA7EE7` | `float GET_ENTITY_FORWARD_Y(Entity entity)` | build 1207
Gets the Y-component of the entity's forward vector.

## GET_ENTITY_HEADING
`0xC230DD956E2F5507` | `float GET_ENTITY_HEADING(Entity entity)` | build 1207
Returns the heading of the entity in degrees. Also know as the "Yaw" of an entity.

## GET_ENTITY_HEALTH
`0x82368787EA73C0F7` | `int GET_ENTITY_HEALTH(Entity entity)` | build 1207

## GET_ENTITY_HEIGHT
`0x296DEBC84474B375` | `float GET_ENTITY_HEIGHT(Entity entity, float X, float Y, float Z, BOOL atTop, BOOL inWorldCoords)` | build 1207

## GET_ENTITY_HEIGHT_ABOVE_GROUND
`0x0D3B5BAEA08F63E9` | `float GET_ENTITY_HEIGHT_ABOVE_GROUND(Entity entity)` | build 1207

## GET_ENTITY_LOD_DIST
`0xDF240D0C2A948683` | `int GET_ENTITY_LOD_DIST(Entity entity)` | build 1207
Returns the LOD distance of an entity.

## GET_ENTITY_MATRIX
`0x3A9B1120AF13FBF2` | `void GET_ENTITY_MATRIX(Entity entity, Vector3* rightVector, Vector3* forwardVector, Vector3* upVector, Vector3* position)` | build 1207

## GET_ENTITY_MAX_HEALTH
`0x15D757606D170C3C` | `int GET_ENTITY_MAX_HEALTH(Entity entity, BOOL p1)` | build 1207

## GET_ENTITY_MODEL
`0xDA76A9F39210D365` | `Hash GET_ENTITY_MODEL(Entity entity)` | build 1207
Returns the model hash from the entity

## GET_ENTITY_PITCH
`0xEF355ABEFF7F5005` | `float GET_ENTITY_PITCH(Entity entity)` | build 1207

## GET_ENTITY_POPULATION_TYPE
`0xADE28862B6D7B85B` | `int GET_ENTITY_POPULATION_TYPE(Entity entity)` | build 1207

## GET_ENTITY_PROOFS
`0x6CF0DAD7FA1088EA` | `int GET_ENTITY_PROOFS(Entity entity)` | build 1207
Note: this native was removed in 1232 but added back in 1311
Old name: _GET_ENTITY_PROOFS

## GET_ENTITY_ROLL
`0xBF966536FA8B6879` | `float GET_ENTITY_ROLL(Entity entity)` | build 1207
Displays the current ROLL axis of the entity [-180.0000/180.0000+]
(Sideways Roll) such as a vehicle tipped on its side

## GET_ENTITY_ROTATION
`0xE09CAF86C32CB48F` | `Vector3 GET_ENTITY_ROTATION(Entity entity, int rotationOrder)` | build 1207

## GET_ENTITY_SPEED
`0xFB6BA510A533DF81` | `float GET_ENTITY_SPEED(Entity entity)` | build 1207
Result is in meters per second (m/s)

## GET_ENTITY_SPEED_VECTOR
`0xF2DB09816A419DC5` | `Vector3 GET_ENTITY_SPEED_VECTOR(Entity entity, BOOL relative)` | build 1207

## GET_ENTITY_SUBMERGED_LEVEL
`0x4A77C3F73FD9E831` | `float GET_ENTITY_SUBMERGED_LEVEL(Entity entity)` | build 1207
Get how much of the entity is submerged.  1.0f is whole entity.

## GET_ENTITY_TYPE
`0x97F696ACA466B4E0` | `int GET_ENTITY_TYPE(Entity entity)` | build 1207
Returns entityType: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eEntityType

## GET_ENTITY_UPRIGHT_VALUE
`0x56398BE65160C3BE` | `float GET_ENTITY_UPRIGHT_VALUE(Entity entity)` | build 1207

## GET_ENTITY_VELOCITY
`0x4805D2B1D8CF94A9` | `Vector3 GET_ENTITY_VELOCITY(Entity entity, int p1)` | build 1207

## GET_IS_ANIMAL
`0x9A100F1CF4546629` | `BOOL GET_IS_ANIMAL(Entity entity)` | build 1207

## GET_MATCHING_ENTITIES
`0x84CCF9A12942C83D` | `int GET_MATCHING_ENTITIES(Volume volume, ItemSet itemSet, int entityType, Any p3, Hash p4, const char* p5)` | build 1207

## GET_NEAREST_PARTICIPANT_TO_ENTITY
`0x6888A43C35A5F630` | `Player GET_NEAREST_PARTICIPANT_TO_ENTITY(Entity entity)` | build 1207

## GET_NEAREST_PLAYER_TO_ENTITY
`0x990E294FC387FB88` | `Player GET_NEAREST_PLAYER_TO_ENTITY(Entity entity, Ped playerPedToIgnore, int flags)` | build 1207

## GET_NEAREST_PLAYER_TO_ENTITY_ON_TEAM
`0xB2C30C3B4AFF718C` | `Player GET_NEAREST_PLAYER_TO_ENTITY_ON_TEAM(Entity entity, int team, Ped playerPedToIgnore, int flags)` | build 1207

## GET_OBJECT_INDEX_FROM_ENTITY_INDEX
`0x280BBE5601EAA983` | `Object GET_OBJECT_INDEX_FROM_ENTITY_INDEX(Entity entity)` | build 1207
Simply returns whatever is passed to it (Regardless of whether the handle is valid or not).

## GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS
`0x497C6B1A2C9AE69C` | `Vector3 GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(Entity entity, float posX, float posY, float posZ)` | build 1207

## GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS
`0x1899F328B0E12848` | `Vector3 GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Entity entity, float offsetX, float offsetY, float offsetZ)` | build 1207
Offset values are relative to the entity.

x = left/right
y = forward/backward
z = up/down

## GET_PED_INDEX_FROM_ENTITY_INDEX
`0x0F16D042BD640EA3` | `Ped GET_PED_INDEX_FROM_ENTITY_INDEX(Entity entity)` | build 1207
Simply returns whatever is passed to it (Regardless of whether the handle is valid or not).

## GET_VEHICLE_INDEX_FROM_ENTITY_INDEX
`0xDF1E5AAC561AFC59` | `Vehicle GET_VEHICLE_INDEX_FROM_ENTITY_INDEX(Entity entity)` | build 1207
Simply returns whatever is passed to it (Regardless of whether the handle is valid or not).

## GET_WORLD_POSITION_OF_ENTITY_BONE
`0x82CFA50E34681CA5` | `Vector3 GET_WORLD_POSITION_OF_ENTITY_BONE(Entity entity, int boneIndex)` | build 1207
Returns the coordinates of an entity-bone.
https://github.com/femga/rdr3_discoveries/tree/master/boneNames

## HAS_ANIM_EVENT_FIRED
`0x5851CC48405F4A07` | `BOOL HAS_ANIM_EVENT_FIRED(Entity entity, Hash actionHash)` | build 1207

## HAS_COLLISION_LOADED_AROUND_ENTITY
`0xBEB1600952B9CF5C` | `BOOL HAS_COLLISION_LOADED_AROUND_ENTITY(Entity entity)` | build 1207

## HAS_COLLISION_LOADED_AROUND_POSITION
`0x6BFBDC46139C45AB` | `BOOL HAS_COLLISION_LOADED_AROUND_POSITION(float xPos, float yPos, float zPos)` | build 1207
Old name: _HAS_COLLISION_LOADED_AT_COORDS

## HAS_ENTITY_ANIM_FINISHED
`0xAEB40615337EF1E3` | `BOOL HAS_ENTITY_ANIM_FINISHED(Entity entity, const char* animDict, const char* animName, int p3)` | build 1207

## HAS_ENTITY_BEEN_DAMAGED_BY_ANY_OBJECT
`0x73BB763880CD23A6` | `BOOL HAS_ENTITY_BEEN_DAMAGED_BY_ANY_OBJECT(Entity entity)` | build 1207

## HAS_ENTITY_BEEN_DAMAGED_BY_ANY_PED
`0x9934E9C42D52D87E` | `BOOL HAS_ENTITY_BEEN_DAMAGED_BY_ANY_PED(Entity entity)` | build 1207

## HAS_ENTITY_BEEN_DAMAGED_BY_ANY_VEHICLE
`0x695D7C26DE65C423` | `BOOL HAS_ENTITY_BEEN_DAMAGED_BY_ANY_VEHICLE(Entity entity)` | build 1207

## HAS_ENTITY_BEEN_DAMAGED_BY_ENTITY
`0x7B6E7BEC1143AC86` | `BOOL HAS_ENTITY_BEEN_DAMAGED_BY_ENTITY(Entity entity1, Entity entity2, BOOL p2, BOOL p3)` | build 1207

## HAS_ENTITY_CLEAR_LOS_TO_COORD
`0x0C9DBF48C6BA6E4C` | `BOOL HAS_ENTITY_CLEAR_LOS_TO_COORD(Entity entity, float x, float y, float z, int flags)` | build 1207

## HAS_ENTITY_CLEAR_LOS_TO_ENTITY
`0xFCDFF7B72D23A1AC` | `BOOL HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Entity entity1, Entity entity2, int traceType)` | build 1207

## HAS_ENTITY_CLEAR_LOS_TO_ENTITY_IN_FRONT
`0xE88F19660651D566` | `BOOL HAS_ENTITY_CLEAR_LOS_TO_ENTITY_IN_FRONT(Entity entity1, Entity entity2, int traceType)` | build 1207
Has the entity1 got a clear line of sight to the other entity2 from the direction entity1 is facing.

## HAS_ENTITY_COLLIDED_WITH_ANYTHING
`0xDF18751EC74F90FF` | `BOOL HAS_ENTITY_COLLIDED_WITH_ANYTHING(Entity entity)` | build 1207

## IS_AN_ENTITY
`0x27CFF3E5A286D3DF` | `BOOL IS_AN_ENTITY(ScrHandle handle)` | build 1207

## IS_ENTITY_AN_OBJECT
`0x0A27A546A375FDEF` | `BOOL IS_ENTITY_AN_OBJECT(Entity entity)` | build 1207

## IS_ENTITY_ATTACHED
`0xEE6AD63ABF59C0B7` | `BOOL IS_ENTITY_ATTACHED(Entity entity)` | build 1207

## IS_ENTITY_ATTACHED_TO_ANY_OBJECT
`0x306C1F6178F01AB3` | `BOOL IS_ENTITY_ATTACHED_TO_ANY_OBJECT(Entity entity)` | build 1207

## IS_ENTITY_ATTACHED_TO_ANY_PED
`0xC841153DED2CA89A` | `BOOL IS_ENTITY_ATTACHED_TO_ANY_PED(Entity entity)` | build 1207

## IS_ENTITY_ATTACHED_TO_ANY_VEHICLE
`0x12DF6E0D2E736749` | `BOOL IS_ENTITY_ATTACHED_TO_ANY_VEHICLE(Entity entity)` | build 1207

## IS_ENTITY_ATTACHED_TO_ENTITY
`0x154A3C529497053E` | `BOOL IS_ENTITY_ATTACHED_TO_ENTITY(Entity from, Entity to)` | build 1207

## IS_ENTITY_AT_COORD
`0x5E58342602E94718` | `BOOL IS_ENTITY_AT_COORD(Entity entity, float xPos, float yPos, float zPos, float xSize, float ySize, float zSize, BOOL p7, BOOL p8, int p9)` | build 1207
Checks if entity is within x/y/zSize distance of x/y/z. 

Last three are unknown ints, almost always p7 = 0, p8 = 1, p9 = 0

## IS_ENTITY_AT_ENTITY
`0xC057F02B837A27F6` | `BOOL IS_ENTITY_AT_ENTITY(Entity entity1, Entity entity2, float xSize, float ySize, float zSize, BOOL p5, BOOL p6, int p7)` | build 1207
Checks if entity1 is within the box defined by x/y/zSize of entity2.

Last three parameters are almost always p5 = 0, p6 = 1, p7 = 0

## IS_ENTITY_A_MISSION_ENTITY
`0x138190F64DB4BBD1` | `BOOL IS_ENTITY_A_MISSION_ENTITY(Entity entity)` | build 1207

## IS_ENTITY_A_PED
`0xCF8176912DDA4EA5` | `BOOL IS_ENTITY_A_PED(Entity entity)` | build 1207

## IS_ENTITY_A_VEHICLE
`0xC3D96AF45FCCEC4C` | `BOOL IS_ENTITY_A_VEHICLE(Entity entity)` | build 1207

## IS_ENTITY_DEAD
`0x7D5B1F88E7504BBA` | `BOOL IS_ENTITY_DEAD(Entity entity)` | build 1207

## IS_ENTITY_IN_AIR
`0x886E37EC497200B6` | `BOOL IS_ENTITY_IN_AIR(Entity entity, Any p1)` | build 1207

## IS_ENTITY_IN_ANGLED_AREA
`0xD3151E53134595E5` | `BOOL IS_ENTITY_IN_ANGLED_AREA(Entity entity, float originX, float originY, float originZ, float edgeX, float edgeY, float edgeZ, float angle, BOOL p8, BOOL p9, Any p10)` | build 1207
Creates a spherical cone at origin that extends to surface with the angle specified. Then returns true if the entity is inside the spherical cone

Angle is measured in degrees.

## IS_ENTITY_IN_AREA
`0x0C2634C40A16193E` | `BOOL IS_ENTITY_IN_AREA(Entity entity, float x1, float y1, float z1, float x2, float y2, float z2, BOOL p7, BOOL p8, Any p9)` | build 1207

## IS_ENTITY_IN_VOLUME
`0x5A5526BC09C06623` | `BOOL IS_ENTITY_IN_VOLUME(Entity entity, ScrHandle volume, BOOL p2, int p3)` | build 1207

## IS_ENTITY_IN_WATER
`0xDDE5C125AC446723` | `BOOL IS_ENTITY_IN_WATER(Entity entity)` | build 1207

## IS_ENTITY_OCCLUDED
`0x140188E884645624` | `BOOL IS_ENTITY_OCCLUDED(Entity entity)` | build 1207

## IS_ENTITY_ON_SCREEN
`0x613C15D5D8DB781F` | `BOOL IS_ENTITY_ON_SCREEN(Entity entity)` | build 1207

## IS_ENTITY_PLAYING_ANIM
`0xDEE49D5CA6C49148` | `BOOL IS_ENTITY_PLAYING_ANIM(Entity entity, char* animDict, char* animName, int animType)` | build 1207

## IS_ENTITY_STATIC
`0x86468ADFA0F6B861` | `BOOL IS_ENTITY_STATIC(Entity entity)` | build 1207

## IS_ENTITY_TOUCHING_ENTITY
`0x9A2304A64C3C8423` | `BOOL IS_ENTITY_TOUCHING_ENTITY(Entity entity, Entity targetEntity)` | build 1207

## IS_ENTITY_TOUCHING_MODEL
`0x2AE3EBC8DEB9768B` | `BOOL IS_ENTITY_TOUCHING_MODEL(Entity entity, Hash modelHash)` | build 1207

## IS_ENTITY_UPRIGHT
`0xF6F6AFD8D4FB2658` | `BOOL IS_ENTITY_UPRIGHT(Entity entity, float angle)` | build 1207

## IS_ENTITY_UPSIDEDOWN
`0x109DE3DA41AAD94A` | `BOOL IS_ENTITY_UPSIDEDOWN(Entity entity)` | build 1207

## IS_ENTITY_VISIBLE
`0xFFC96ECB7FA404CA` | `BOOL IS_ENTITY_VISIBLE(Entity entity)` | build 1207

## IS_ENTITY_VISIBLE_TO_SCRIPT
`0xF213C724E77F321A` | `BOOL IS_ENTITY_VISIBLE_TO_SCRIPT(Entity entity)` | build 1207

## IS_ENTITY_WAITING_FOR_WORLD_COLLISION
`0x5E1CC2E8DC3111DD` | `BOOL IS_ENTITY_WAITING_FOR_WORLD_COLLISION(Entity entity)` | build 1207

## IS_MAP_ENTITY_PINNED
`0x1FF441D7954F8709` | `BOOL IS_MAP_ENTITY_PINNED(Any p0)` | build 1207

## PIN_CLOSEST_MAP_ENTITY
`0x6F3068258A499E52` | `Any PIN_CLOSEST_MAP_ENTITY(Hash modelHash, float x, float y, float z, int flags)` | build 1207

## PLACE_ENTITY_ON_GROUND_PROPERLY
`0x9587913B9E772D29` | `BOOL PLACE_ENTITY_ON_GROUND_PROPERLY(Entity entity, BOOL p1)` | build 1207

## PLAY_ENTITY_ANIM
`0xDC6D22FAB76D4874` | `BOOL PLAY_ENTITY_ANIM(Entity entity, char* animName, char* animDict, float p3, BOOL loop, BOOL stayInAnim, BOOL p6, float delta, Any bitset)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/animations

## REMOVE_FORCED_OBJECT
`0x553FA683F2BCD814` | `void REMOVE_FORCED_OBJECT(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## REMOVE_MODEL_HIDE
`0x3F38A98576F6213A` | `void REMOVE_MODEL_HIDE(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## REMOVE_MODEL_SWAP
`0x824E1C26A14CB817` | `void REMOVE_MODEL_SWAP(float x, float y, float z, float radius, Hash originalModel, Hash newModel, BOOL p6)` | build 1207

## RESET_ENTITY_ALPHA
`0x744B9EF44779D9AB` | `void RESET_ENTITY_ALPHA(Entity entity)` | build 1207

## SCRIPT_OVERRIDE_ENTITY_LOOT_TABLE_PERMANENT
`0x8C03CD6B5E0E85E8` | `BOOL SCRIPT_OVERRIDE_ENTITY_LOOT_TABLE_PERMANENT(Entity entity, Hash lootTable)` | build 1207
Sets the loot table an entity will carry. Returns true if loot table has been successfully set. Returns false if entity is not a ped or object.
https://github.com/femga/rdr3_discoveries/blob/master/AI/EVENTS/loot_rewards.lua

## SET_CAN_AUTO_VAULT_ON_ENTITY
`0x80646744FA88F9D7` | `void SET_CAN_AUTO_VAULT_ON_ENTITY(Entity entity, BOOL toggle)` | build 1207

## SET_CAN_CLIMB_ON_ENTITY
`0x24AED2A608F93C4C` | `void SET_CAN_CLIMB_ON_ENTITY(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_ALPHA
`0x0DF7692B1D9E7BA7` | `void SET_ENTITY_ALPHA(Entity entity, int alphaLevel, BOOL skin)` | build 1207
skin - everything alpha except skin
Set entity alpha level. Ranging from 0 to 255 but changes occur after every 20 percent (after every 51).

## SET_ENTITY_ALWAYS_PRERENDER
`0xACAD101E1FB66689` | `void SET_ENTITY_ALWAYS_PRERENDER(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_AS_MISSION_ENTITY
`0xDC19C288082E586E` | `void SET_ENTITY_AS_MISSION_ENTITY(Entity entity, BOOL scriptHostObject, BOOL grabFromOtherScript)` | build 1207
Makes the specified entity (ped, vehicle or object) persistent. Persistent entities will not automatically be removed by the engine.

## SET_ENTITY_AS_NO_LONGER_NEEDED
`0x4971D2F8162B9674` | `void SET_ENTITY_AS_NO_LONGER_NEEDED(Entity* entity)` | build 1207
Marks the specified entity (ped, vehicle or object) as no longer needed.
Entities marked as no longer needed, will be deleted as the engine sees fit.

## SET_ENTITY_CAN_BE_DAMAGED
`0x0D06D522B90E861F` | `void SET_ENTITY_CAN_BE_DAMAGED(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_CAN_BE_DAMAGED_BY_RELATIONSHIP_GROUP
`0x0EF1AFB18649E015` | `void SET_ENTITY_CAN_BE_DAMAGED_BY_RELATIONSHIP_GROUP(Entity entity, BOOL bCanBeDamaged, Hash relGroup)` | build 1207

## SET_ENTITY_CAN_BE_TARGETED_WITHOUT_LOS
`0x6D09F32E284D0FB7` | `void SET_ENTITY_CAN_BE_TARGETED_WITHOUT_LOS(Entity entity, BOOL toggle)` | build 1207
Sets whether the entity can be targeted without being in line-of-sight.

## SET_ENTITY_CAN_ONLY_BE_DAMAGED_BY_SCRIPT_PARTICIPANTS
`0xFF83AF534156B399` | `void SET_ENTITY_CAN_ONLY_BE_DAMAGED_BY_SCRIPT_PARTICIPANTS(Entity EntityIndex, BOOL bOnlyDamagedWhenRunningScript)` | build 1207

## SET_ENTITY_COLLISION
`0xF66F820909453B8C` | `void SET_ENTITY_COLLISION(Entity entity, BOOL toggle, BOOL keepPhysics)` | build 1207

## SET_ENTITY_COMPLETELY_DISABLE_COLLISION
`0xE0580EC84813875A` | `void SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Entity entity, BOOL toggle, BOOL keepPhysics)` | build 1207

## SET_ENTITY_COORDS
`0x06843DA7060A026B` | `void SET_ENTITY_COORDS(Entity entity, float xPos, float yPos, float zPos, BOOL xAxis, BOOL yAxis, BOOL zAxis, BOOL clearArea)` | build 1207

## SET_ENTITY_COORDS_NO_OFFSET
`0x239A3351AC1DA385` | `void SET_ENTITY_COORDS_NO_OFFSET(Entity entity, float xPos, float yPos, float zPos, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207
Axis - Invert Axis Flags

## SET_ENTITY_DYNAMIC
`0xFBFC4473F66CE344` | `void SET_ENTITY_DYNAMIC(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_HAS_GRAVITY
`0x0CEDB728A1083FA7` | `void SET_ENTITY_HAS_GRAVITY(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_HEADING
`0xCF2B9C0645C4651B` | `void SET_ENTITY_HEADING(Entity entity, float heading)` | build 1207

## SET_ENTITY_HEALTH
`0xAC2767ED8BDFAB15` | `void SET_ENTITY_HEALTH(Entity entity, int healthAmount, Entity entityKilledBy)` | build 1207
Sets the entity's health. healthAmount sets the health value to that, and sets the maximum health core value. Setting healthAmount to 0 will kill the entity. entityKilledBy parameter can also be 0

## SET_ENTITY_INVINCIBLE
`0xA5C38736C426FCB8` | `void SET_ENTITY_INVINCIBLE(Entity entity, BOOL toggle)` | build 1207
Sets a ped or an object totally invincible. It doesn't take any kind of damage. Peds will not ragdoll on explosions.

## SET_ENTITY_IS_TARGET_PRIORITY
`0x0A5D170C44CB2189` | `void SET_ENTITY_IS_TARGET_PRIORITY(Entity entity, BOOL p1, float p2)` | build 1207

## SET_ENTITY_LOAD_COLLISION_FLAG
`0x9B9EE31AED48072E` | `void SET_ENTITY_LOAD_COLLISION_FLAG(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_LOD_DIST
`0x5FB407F0A7C877BF` | `void SET_ENTITY_LOD_DIST(Entity entity, int value)` | build 1207
LOD distance can be 0 to 0xFFFF (higher values will result in 0xFFFF) as it is actually stored as a 16-bit value (aka uint16_t).

## SET_ENTITY_MAX_HEALTH
`0x166E7CF68597D8B5` | `void SET_ENTITY_MAX_HEALTH(Entity entity, int value)` | build 1207

## SET_ENTITY_MOTION_BLUR
`0x516C6ABD18322B63` | `void SET_ENTITY_MOTION_BLUR(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_NOWEAPONDECALS
`0xC64E597783BE9A1D` | `void SET_ENTITY_NOWEAPONDECALS(Entity entity, BOOL toggle)` | build 1207
Old name: _SET_ENTITY_DECALS_DISABLED

## SET_ENTITY_NO_COLLISION_ENTITY
`0xE037BF068223C38D` | `void SET_ENTITY_NO_COLLISION_ENTITY(Entity entity1, Entity entity2, BOOL thisFrameOnly)` | build 1207

## SET_ENTITY_ONLY_DAMAGED_BY_PLAYER
`0x473598683095D430` | `void SET_ENTITY_ONLY_DAMAGED_BY_PLAYER(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_ONLY_DAMAGED_BY_RELATIONSHIP_GROUP
`0x6C1F6AA2F0ADD104` | `void SET_ENTITY_ONLY_DAMAGED_BY_RELATIONSHIP_GROUP(Entity entity, BOOL p1, Hash relationshipGroup)` | build 1207

## SET_ENTITY_PROOFS
`0xFAEE099C6F890BB8` | `void SET_ENTITY_PROOFS(Entity entity, int proofsBitset, BOOL specialFlag)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/AI/ENTITY_PROOFS
BOOL p2: handles an additional special proofs flag, so it simply indicates whether it should be enabled or disabled, not sure what exactly it proofs the entity from though

## SET_ENTITY_QUATERNION
`0x100E7007D13E3687` | `void SET_ENTITY_QUATERNION(Entity entity, float x, float y, float z, float w)` | build 1207

## SET_ENTITY_RENDER_SCORCHED
`0x85B8A7534E44BC23` | `void SET_ENTITY_RENDER_SCORCHED(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_REQUIRES_MORE_EXPENSIVE_RIVER_CHECK
`0x850C940EE3E7B8B5` | `void SET_ENTITY_REQUIRES_MORE_EXPENSIVE_RIVER_CHECK(Entity entity, BOOL toggle)` | build 1207

## SET_ENTITY_ROTATION
`0x9CC8314DFEDE441E` | `void SET_ENTITY_ROTATION(Entity entity, float pitch, float roll, float yaw, int rotationOrder, BOOL p5)` | build 1207

## SET_ENTITY_SHOULD_FREEZE_WAITING_ON_COLLISION
`0x740CB4F3F602C9F4` | `void SET_ENTITY_SHOULD_FREEZE_WAITING_ON_COLLISION(Entity entity, BOOL toggle)` | build 1207
Old name: _SET_ENTITY_CLEANUP_BY_ENGINE

## SET_ENTITY_VELOCITY
`0x1C99BB7B6E96D16F` | `void SET_ENTITY_VELOCITY(Entity entity, float x, float y, float z)` | build 1207
Note that the third parameter(denoted as z) is "up and down" with positive numbers encouraging upwards movement.

## SET_ENTITY_VISIBLE
`0x1794B4FCC84D812F` | `void SET_ENTITY_VISIBLE(Entity entity, BOOL toggle)` | build 1207

## SET_OBJECT_AS_NO_LONGER_NEEDED
`0x3AE22DEB5BA5A3E6` | `void SET_OBJECT_AS_NO_LONGER_NEEDED(Object* object)` | build 1207
This is an alias of SET_ENTITY_AS_NO_LONGER_NEEDED.

## SET_PED_AS_NO_LONGER_NEEDED
`0x2595DD4236549CE3` | `void SET_PED_AS_NO_LONGER_NEEDED(Ped* ped)` | build 1207
This is an alias of SET_ENTITY_AS_NO_LONGER_NEEDED.

## SET_VEHICLE_AS_NO_LONGER_NEEDED
`0x629BFA74418D6239` | `void SET_VEHICLE_AS_NO_LONGER_NEEDED(Vehicle* vehicle)` | build 1207
This is an alias of SET_ENTITY_AS_NO_LONGER_NEEDED.

## STOP_ENTITY_ANIM
`0x786591D986DE9159` | `Any STOP_ENTITY_ANIM(Entity entity, const char* animation, const char* animGroup, float p3)` | build 1207

## WOULD_ENTITY_BE_OCCLUDED
`0x3546FAB293FF2981` | `BOOL WOULD_ENTITY_BE_OCCLUDED(Hash entityModelHash, float x, float y, float z, BOOL p4)` | build 1207

## _0x002AAC783ED323ED
`0x002AAC783ED323ED` | `void _0x002AAC783ED323ED(Any p0, Any p1)` | build 1207

## _0x007AAC783ED323ED
`0x007AAC783ED323ED` | `void _0x007AAC783ED323ED(Any p0, Any p1, Any p2)` | build 1207

## _0x0939E773925C4719
`0x0939E773925C4719` | `void _0x0939E773925C4719()` | build 1207

## _0x0CCEFC6C2C95DA2A
`0x0CCEFC6C2C95DA2A` | `Any _0x0CCEFC6C2C95DA2A(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x0DB41D59E0F1502B
`0x0DB41D59E0F1502B` | `void _0x0DB41D59E0F1502B(Any p0)` | build 1207

## _0x0FD7D7C232876E72
`0x0FD7D7C232876E72` | `void _0x0FD7D7C232876E72(Any p0)` | build 1207

## _0x188736456D1DEDE6
`0x188736456D1DEDE6` | `Any _0x188736456D1DEDE6(Any p0, Any p1)` | build 1207

## _0x20FAEE47427A4497
`0x20FAEE47427A4497` | `void _0x20FAEE47427A4497()` | build 1207

## _0x350E9211074955AF
`0x350E9211074955AF` | `Any _0x350E9211074955AF(Any p0, Any p1)` | build 1207

## _0x371D179701D9C082
`0x371D179701D9C082` | `void _0x371D179701D9C082(Entity entity)` | build 1436
Called if entity is in water and submerged level is larger than 1f. If CARRYING_FLAG_FORCE_ALLOW_WARP_TO_SAFE_GROUND_LOCATION is true, it gets disabled as well.

## _0x37B01666BAE8F7EF
`0x37B01666BAE8F7EF` | `Any _0x37B01666BAE8F7EF(Entity entity)` | build 1207
Seems to return true if entity is burned / scorched
_GET_ENTITY_*

## _0x383F64263F946E45
`0x383F64263F946E45` | `BOOL _0x383F64263F946E45(int* p0, Entity entity, int p2, Ped ped, Any p4, int p5)` | build 1207
Used when checking if ped is in water

## _0x3EC28DA1FFAC9DDD
`0x3EC28DA1FFAC9DDD` | `BOOL _0x3EC28DA1FFAC9DDD(Entity entity1, Entity entity2, Any p2, Any p3)` | build 1207
Used in Script Function DUELING_DID_PLAYER_DISARM_OPPONENT

## _0x5826EFD6D73C4DE5
`0x5826EFD6D73C4DE5` | `void _0x5826EFD6D73C4DE5(Entity entity)` | build 1207
_REMOVE_DECALS_* - _REMOVE_FORCED*

## _0x582F73ACFE969571
`0x582F73ACFE969571` | `Any _0x582F73ACFE969571(Any p0, Any p1, Any p2)` | build 1207

## _0x7A49D40DE437BC8D
`0x7A49D40DE437BC8D` | `void _0x7A49D40DE437BC8D(Any p0, Any p1)` | build 1207

## _0x7F20092547B4DDEA
`0x7F20092547B4DDEA` | `void _0x7F20092547B4DDEA(Any p0)` | build 1207

## _0x80FDEB3A9E9AA578
`0x80FDEB3A9E9AA578` | `void _0x80FDEB3A9E9AA578(Entity entity, BOOL p1)` | build 1207

## _0x898586729DB5221D
`0x898586729DB5221D` | `void _0x898586729DB5221D(Ped ped)` | build 1207

## _0x8E10DF0FFA63FB65
`0x8E10DF0FFA63FB65` | `Any _0x8E10DF0FFA63FB65(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x8E46E18AA828334F
`0x8E46E18AA828334F` | `float _0x8E46E18AA828334F(Entity entity, const char* animDict, const char* animClip)` | build 1207
Used in Script Function GENERIC_ITEM_HAS_ANIM_COMPLETED
_GET_ENTITY_*

## _0x978AA2323ED32209
`0x978AA2323ED32209` | `void _0x978AA2323ED32209(Any p0, Any p1)` | build 1207

## _0x9C6906EF8CB20C5F
`0x9C6906EF8CB20C5F` | `void _0x9C6906EF8CB20C5F(Entity entity)` | build 1436

## _0xA9E6D8F2DDFC4DB9
`0xA9E6D8F2DDFC4DB9` | `void _0xA9E6D8F2DDFC4DB9(Any p0, Any p1)` | build 1207

## _0xB16C780C51E51E2B
`0xB16C780C51E51E2B` | `Any _0xB16C780C51E51E2B(Any p0)` | build 1207

## _0xB38A29CCD5447783
`0xB38A29CCD5447783` | `void _0xB38A29CCD5447783(Any p0, Any p1, Any p2)` | build 1207

## _0xBA2A089E60ED1163
`0xBA2A089E60ED1163` | `Any _0xBA2A089E60ED1163(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xC3ABCFBC7D74AFA5
`0xC3ABCFBC7D74AFA5` | `void _0xC3ABCFBC7D74AFA5(Ped ped, int p1, BOOL p2)` | build 1207
Returns BOOL in ida

## _0xC6A1A3D63F122DE7
`0xC6A1A3D63F122DE7` | `void _0xC6A1A3D63F122DE7(Any p0, Any p1)` | build 1311

## _0xC76E94A78127412B
`0xC76E94A78127412B` | `void _0xC76E94A78127412B(Any p0, Any p1, Any p2)` | build 1207

## _0xCDB682BB47C02F0A
`0xCDB682BB47C02F0A` | `void _0xCDB682BB47C02F0A(Entity entity, Hash p1)` | build 1207

## _0xD21C7418C590BB40
`0xD21C7418C590BB40` | `Any _0xD21C7418C590BB40(Any p0)` | build 1207

## _0xD46BF94C4C66FAB0
`0xD46BF94C4C66FAB0` | `Any _0xD46BF94C4C66FAB0(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xDF8E49EA89A01DB1
`0xDF8E49EA89A01DB1` | `Any _0xDF8E49EA89A01DB1(Any p0, Any p1, Any p2)` | build 1207
Hardcoded to return zero/false.

## _0xE19035EB65AB2932
`0xE19035EB65AB2932` | `void _0xE19035EB65AB2932(Any p0, Any p1)` | build 1207

## _0xE31FC20319874CB3
`0xE31FC20319874CB3` | `Any _0xE31FC20319874CB3(Any p0, Any p1, Any p2)` | build 1207

## _0xE75EEA8DB59A9F39
`0xE75EEA8DB59A9F39` | `void _0xE75EEA8DB59A9F39(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0xE9E7A0BAC7F57746
`0xE9E7A0BAC7F57746` | `void _0xE9E7A0BAC7F57746(Any p0, Any p1)` | build 1207

## _0xEF259AA1E097E0AD
`0xEF259AA1E097E0AD` | `void _0xEF259AA1E097E0AD(Entity entity, Any p1)` | build 1207

## _0xF41E2979D5BC5370
`0xF41E2979D5BC5370` | `void _0xF41E2979D5BC5370(Any p0)` | build 1207

## _0xF59FDE7B4D31A630
`0xF59FDE7B4D31A630` | `Any _0xF59FDE7B4D31A630(Any p0)` | build 1207

## _0xFF9965C47FA404DA
`0xFF9965C47FA404DA` | `void _0xFF9965C47FA404DA(Entity entity, BOOL toggle)` | build 1207
SET_ENTITY_LO*

## _ADD_ENTITY_TRACKING_TRAILS
`0x1AD922AB5038DEF3` | `void _ADD_ENTITY_TRACKING_TRAILS(Entity entity)` | build 1207

## _ATTACH_ENTITY_TO_COORDS_PHYSICALLY
`0x445D7D8EA66E373E` | `void _ATTACH_ENTITY_TO_COORDS_PHYSICALLY(Entity entity, float x, float y, float z, float offsetx, float offsety, float offsetz, float timer, BOOL p8, int p9, int p10, int p11, int p12, int p13, int p14)` | build 1207
Attach an entity to coordinates physically better name may be perfered? seems to be used with boats `p_skiff02x` ? The last 6 params are always 0 everywhere in the base code. p7 = 500.0 some kind of time? p8 =1

## _CHANGE_ENTITY_HEALTH
`0x835F131E7DC8F97A` | `BOOL _CHANGE_ENTITY_HEALTH(Entity entity, float amount, Entity entity2, Hash weaponHash)` | build 1207
Alters entity's health by 'amount'. Can be negative (to drain health).
In the scripts entity2 and weaponHash are unused (zero).

## _CREATE_FOOTPATH_TRAIL
`0x29BA9F78321E5A6C` | `Any _CREATE_FOOTPATH_TRAIL(Any p0, const char* waypointRecord, BOOL bUseSnowOffset, float p3, float p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, BOOL bInit)` | build 1207

## _DELETE_CARRIABLE
`0x0D0DB2B6AF19A987` | `void _DELETE_CARRIABLE(Entity* entity)` | build 1207

## _DELETE_ENTITY_2
`0x5E94EA09E7207C16` | `void _DELETE_ENTITY_2(Entity* entity)` | build 1207
Must be called from a background script, otherwise it will do nothing.

## _DISABLE_STAIRS_STEP_FOR_VOLUME
`0x37CEB637BA3B1A47` | `void _DISABLE_STAIRS_STEP_FOR_VOLUME(int volumeId)` | build 1207
Disables stair stepping behavior within the specified volume.
When active, entities (typically peds/players) can still move up stairs, but their stepping animation and foot placement become irregular, causing them to skip steps or slide slightly instead of properly stepping each stair.

## _DOES_THREAD_OWN_THIS_ENTITY
`0x88AD6CC10D8D35B2` | `BOOL _DOES_THREAD_OWN_THIS_ENTITY(Entity entity)` | build 1207
Returns true if calling script owns specified entity

## _ENABLE_STAIRS_STEP_FOR_VOLUME
`0xEAB3D91D30A344F1` | `void _ENABLE_STAIRS_STEP_FOR_VOLUME(int volumeId)` | build 1207
Re-enables normal stair stepping behavior within the specified volume.
This restores proper step-by-step movement and foot placement for entities that was previously altered by _DISABLE_STAIRS_STEP_FOR_VOLUME

## _FORCE_TRAIN_WAGON_POPULATION
`0x119A5714578F4E05` | `void _FORCE_TRAIN_WAGON_POPULATION(Entity carriage, BOOL force)` | build 1207
Enables or disables automatic passenger population on a specific train wagon (carriage).

When toggle == true, the game keeps this wagon filled with ambient passengers.
If a passenger ped is deleted or removed from the wagon, a new ped is spawned almost
immediately to occupy that seat.

When toggle == false, the engine stops auto-filling this wagon. After you delete or
remove the existing passengers, no new peds will spawn for that wagon until you enable
it again with true.

## _GET_CARRIABLE_FROM_ENTITY
`0x31FEF6A20F00B963` | `Hash _GET_CARRIABLE_FROM_ENTITY(Entity entity)` | build 1207
Returns a hash of an entity's name. (Alternative Name: _GET_ENTITY_PROMPT_NAME_HASH)

## _GET_COLLISION_INTENSITY
`0x6D58167F62238284` | `float _GET_COLLISION_INTENSITY(Vehicle vehicle)` | build 1207
Returns the collision intensity currently registered on the specified entity.
Used after HAS_ENTITY_COLLIDED_WITH_ANYTHING to measure how strong the impact was. Higher values indicate a stronger collision/impact

## _GET_ENTITIES_IN_VOLUME
`0x886171A12F400B89` | `int _GET_ENTITIES_IN_VOLUME(Volume volume, ItemSet itemSet, int entityType)` | build 1207

## _GET_ENTITIES_NEAR_POINT
`0x59B57C4B06531E1E` | `int _GET_ENTITIES_NEAR_POINT(float x, float y, float z, float radius, ItemSet itemSet, int p5)` | build 1207

## _GET_ENTITY_ALBEDO
`0x120376C23F019C6C` | `BOOL _GET_ENTITY_ALBEDO(Entity entity, Any* albedoHash)` | build 1207
returns the albedo hash by carriable hash, use Citizen.pointerValueInt() as last parameter 
this native writes an albedo-related hash to the output pointer and returns whether the entity already has a valid albedo/material entry assigned if not it loads it and applies it using 0xDD03FC2089AD093C

## _GET_ENTITY_ANIM_CURRENT_TIME
`0x627520389E288A73` | `float _GET_ENTITY_ANIM_CURRENT_TIME(Entity entity, char* animDict, char* animName)` | build 1207
Returns a normalized value between 0.0f and 1.0f. You can get the actual anim time by multiplying this by GET_ANIM_DURATION

## _GET_ENTITY_BY_DOORHASH
`0xF7424890E4A094C0` | `Entity _GET_ENTITY_BY_DOORHASH(Hash doorHash, int p1)` | build 1207
Params: p1 = 0 in R* Scripts (GET_DOOR_ENTITY_FROM_ID)
https://github.com/femga/rdr3_discoveries/blob/master/doorHashes/doorhashes.lua

## _GET_ENTITY_CARRYING_FLAG
`0x808077647856DE62` | `BOOL _GET_ENTITY_CARRYING_FLAG(Entity entity, int flagId)` | build 1207
flagId: see _SET_ENTITY_CARRYING_FLAG

## _GET_ENTITY_CARRY_CONFIG
`0x0FD25587BB306C86` | `Hash _GET_ENTITY_CARRY_CONFIG(Entity entity)` | build 1207
Returns zero if the entity is not a carriable

## _GET_ENTITY_COLLISION_INTENSITY
`0xDFC2B226D56D85F6` | `float _GET_ENTITY_COLLISION_INTENSITY(Entity entity, Entity entiy2)` | build 1207
Returns a float that appears to represent the collision impact intensity between two entities.

Based on observed usage, this value becomes large when entity1 hits entity2 with enough force. In the example below, if the returned value is greater than 500.0f, the first entity is moving, the second entity is nearly stationary, and the second entity is not already ragdolled, then SET_PED_TO_RAGDOLL is triggered.

## _GET_ENTITY_FORWARD_VECTOR_YX
`0x935A30AA88FB1014` | `Vector3 _GET_ENTITY_FORWARD_VECTOR_YX(Entity entity)` | build 1207
Gets the entity's forward vector in YX(Z) eulers. Similar to GET_ENTITY_FORWARD_VECTOR

## _GET_ENTITY_FROM_PELT
`0x2A77EF9BEC8518F4` | `int _GET_ENTITY_FROM_PELT(Entity pelt)` | build 1207
Returns the original animal (carcass) entity from which a pelt entity was obtained if it still exists

## _GET_ENTITY_HEALTH_FLOAT
`0x96C638784DB4C815` | `float _GET_ENTITY_HEALTH_FLOAT(Entity entity)` | build 1207
Returns (CUR_HEALTH / MAX_HEALTH)

## _GET_ENTITY_LOOTING_PED
`0xEF2D9ED7CE684F08` | `Entity _GET_ENTITY_LOOTING_PED(Entity entity)` | build 1207
Returns the entity that is looting a ped but only while the looting is active

## _GET_ENTITY_SCRIPT
`0x2A08A32B6D49906F` | `Hash _GET_ENTITY_SCRIPT(Entity entity, Any* argStruct)` | build 1207

## _GET_ENTITY_THREAT_TIER
`0xE12F56CB25D9CE23` | `int _GET_ENTITY_THREAT_TIER(Entity entity)` | build 1207

## _GET_ENTITY_WORLD_POSITION_OF_DIMENSIONS
`0xF3FDA9A617A15145` | `void _GET_ENTITY_WORLD_POSITION_OF_DIMENSIONS(Entity entity, Vector3* minimum, Vector3* maximum)` | build 1207

## _GET_HEADING_OF_ENTITY_BONE
`0x3AB3A77672F6473F` | `Vector3 _GET_HEADING_OF_ENTITY_BONE(Entity entity, int boneIndex, int p2, int p3)` | build 1207
Returns the rotation/heading of a specific bone on an entity as a Vector3.

## _GET_IS_BIRD
`0xC346A546612C49A9` | `BOOL _GET_IS_BIRD(Entity entity)` | build 1207

## _GET_IS_CARRIABLE_PELT
`0x255B6DB4E3AD3C3E` | `BOOL _GET_IS_CARRIABLE_PELT(Entity entity)` | build 1207

## _GET_IS_PREDATOR
`0x5594AFE9DE0C01B7` | `BOOL _GET_IS_PREDATOR(Entity entity)` | build 1207

## _GET_LAST_ENTITY_TO_DAMAGE_ENTITY
`0xAF72EC7E1B54539B` | `int _GET_LAST_ENTITY_TO_DAMAGE_ENTITY(Entity entity)` | build 1311
Returns the last entity that dealt any damage to the specified entity.
This native appears to retrieve the attacker responsible for the most recent damage event on the given entity.

## _GET_OFFSET_FROM_ENTITY_BONE
`0x5E214112806591EA` | `Vector3 _GET_OFFSET_FROM_ENTITY_BONE(Entity entity, int boneIndex)` | build 1207
Return the offset from the entity for the selected bone index

## _GET_OPTIMAL_CARRY_CONFIG
`0x34F008A7E48C496B` | `Hash _GET_OPTIMAL_CARRY_CONFIG(Entity entity, int index)` | build 1207
Valid indices: 0 - 3
Index 1 always returns a `hogtied` config, doesn't matter the entity.
It's for humans only and the ped must be resurrected first if it's dead.

## _GET_PED_ANIMAL_TYPE
`0x964000D355219FC0` | `Hash _GET_PED_ANIMAL_TYPE(Ped ped)` | build 1207
Returns the ped's animal type hash: https://alloc8or.re/rdr3/doc/enums/eAnimalType.txt
Combine this with GET_STRING_FROM_HASH_KEY to display localized entity names

## _GET_PELT_TEXTURE
`0x5744562E973E33CD` | `BOOL _GET_PELT_TEXTURE(Hash albedoHash, Any txdAlbedoDV, Any txdNormalMapDV, Any txdMaterialDV, int p4)` | build 1207
Get the pelt TXDs by the animal albedo hash, returns: normal map hash, material hash and albedo hash, this native needs dataview to be passed in, then use it to get the pelt TXDs

## _GET_PINNED_MAP_ENTITY
`0x4735E2A4BB83D9DA` | `Entity _GET_PINNED_MAP_ENTITY(Any p0)` | build 1207

## _GET_SCRIPT_OVERRIDE_ENTITY_LOOT_TABLE_PERMANENT
`0x1E804EA9B12030A4` | `BOOL _GET_SCRIPT_OVERRIDE_ENTITY_LOOT_TABLE_PERMANENT(Entity entity, Hash* lootTable)` | build 1207
Returns false if entity is not a ped or object.

## _IS_CARRIABLE_MODEL
`0x5AFFA9DDC87846F8` | `BOOL _IS_CARRIABLE_MODEL(Hash model)` | build 1207

## _IS_ENTITY_FROZEN
`0x083D497D57B7400F` | `BOOL _IS_ENTITY_FROZEN(Entity entity)` | build 1207
Getter for FREEZE_ENTITY_POSITION

## _IS_ENTITY_FULLY_LOOTED
`0x8DE41E9902E85756` | `BOOL _IS_ENTITY_FULLY_LOOTED(Entity entity)` | build 1207

## _IS_ENTITY_ON_TRAIN_TRACK
`0x857ACB0AB4BD0D55` | `BOOL _IS_ENTITY_ON_TRAIN_TRACK(Entity entity)` | build 1207

## _IS_ENTITY_OWNED_BY_PERSISTENCE_SYSTEM
`0xA7E51B53309EAC97` | `BOOL _IS_ENTITY_OWNED_BY_PERSISTENCE_SYSTEM(Entity entity)` | build 1207

## _IS_ENTITY_PLAYING_ANY_ANIM
`0x0B7CB1300CBFE19C` | `BOOL _IS_ENTITY_PLAYING_ANY_ANIM(Entity entity, int p1)` | build 1207
Params: p1 (probably animType) = 1, 0

## _IS_ENTITY_UNDERWATER
`0xD4E5C1E93C466127` | `BOOL _IS_ENTITY_UNDERWATER(Entity entity, BOOL p1)` | build 1207

## _IS_MODEL_IN_NEED_OF_VEG_MODIFIER
`0xD4636C2EDB0DEA8A` | `BOOL _IS_MODEL_IN_NEED_OF_VEG_MODIFIER(Hash modelHash)` | build 1207
Checks whether the specified model can be handled through the vegetation modifier path.
This is not limited strictly to foliage. Testing shows many natural world
models can return TRUE, including rocks, trees, bushes, grass, crops, branches, roots, logs, debris, and similar environment assets.

## _IS_TRACKED_ENTITY_VISIBLE
`0xC8CCDB712FBCBA92` | `BOOL _IS_TRACKED_ENTITY_VISIBLE(Entity entity)` | build 1207

## _IS_TRAIN_INTERIOR_LOADED
`0xC2E71D7E0A7B4C89` | `BOOL _IS_TRAIN_INTERIOR_LOADED(Entity entity)` | build 1207
Checks whether the entity's interior is currently loaded by the game engine.
This is mainly used for train carriages. When the player is far away or not standing on the train, the game unloads interiors of distant carriages as an optimization. If the interior of the entity is currently loaded, this native returns true

## _PAUSE_ENTITY_TRACKING
`0x36EB4D34D4A092C5` | `void _PAUSE_ENTITY_TRACKING(Entity entity, BOOL pause)` | build 1207

## _PIN_MAP_ENTITY
`0xAAACB74442C1BED3` | `int _PIN_MAP_ENTITY(Entity entity)` | build 1207

## _PRELOAD_ENTITY_INTERIOR
`0x6C31B06E91518269` | `void _PRELOAD_ENTITY_INTERIOR(Entity entity, BOOL enabled)` | build 1207
This native can enable interiors for train carriages that the game engine has disabled due to distance-based optimization.

## _REQUEST_ENTITY_LOOT_LIST
`0xA88E215CEB0435C0` | `BOOL _REQUEST_ENTITY_LOOT_LIST(Ped mount, Any* argStruct, Hash visiblelootslotrequestType, int flag, int p4, BOOL p5)` | build 1207

## _REQUEST_ENTITY_VISIBILITY_TRACKING
`0x3F08C6163A4AB1D6` | `void _REQUEST_ENTITY_VISIBILITY_TRACKING(Entity entity)` | build 1207
Enables visibility tracking for the specified entity
For peds, calling this makes PED::_IS_PED_VISIBILITY_TRACKED(ped) return true.
For vehicles, calling this makes VEHICLE::IS_VEHICLE_VISIBLE(vehicle) return true in the tracked/visible state context observed from scripts

## _SEARCH_BUILDING_POOL_FOR_ENTITY_WITH_THIS_MODEL
`0x66B2B83B94B22458` | `Entity _SEARCH_BUILDING_POOL_FOR_ENTITY_WITH_THIS_MODEL(Hash modelHash)` | build 1207
Alternative Name: _GET_ENTITY_FROM_MAP_OBJECT; You can get existing objects and manipulate them using this native.

## _SET_AUTO_PICKUP
`0xBD94CECFB2D65119` | `void _SET_AUTO_PICKUP(Entity entity, BOOL noPickupAnim, float range, float p3, float p4, BOOL enablePickupPrompt)` | build 1207
Configures automatic pickup behavior for a carriable entity.
This native is typically used after TASK_CARRIABLE and enables auto-pickup functionality with configurable parameters such as pickup animation behavior, pickup range, and pickup prompt state

## _SET_CARRIABLE_PICKUP_LIGHT
`0xA48E4801DEBDF7E4` | `void _SET_CARRIABLE_PICKUP_LIGHT(Entity entity, BOOL enabled)` | build 1207
Enables or disables the pickup light effect for carriable/interactable entities
This native specifically works on entities that are carriable and can be interacted with (e.g. after TASK::_MAKE_OBJECT_CARRIABLE).
- Unlike SET_PICKUP_LIGHT, this does NOT apply a generic light effect to all objects.
  Instead, it only highlights entities that the player can interact with (pickup context)

## _SET_ENTITY_ANIM_CURRENT_TIME
`0x11CDABDC7783B2BC` | `void _SET_ENTITY_ANIM_CURRENT_TIME(Entity entity, char* animDict, char* animName, float time)` | build 1207

## _SET_ENTITY_ANIM_SPEED
`0xEAA885BA3CEA4E4A` | `void _SET_ENTITY_ANIM_SPEED(Entity entity, char* animDict, char* animName, float speedMultiplier)` | build 1207

## _SET_ENTITY_ATTACHED_OFFSET
`0x16908E859C3AB698` | `void _SET_ENTITY_ATTACHED_OFFSET(Entity entity, BOOL horizontalMode, float offsetX, float offsetY, float offsetZ)` | build 1207
Applies and updates the positional offset of an entity relative to the entity it is attached to, while also controlling whether the offset is interpreted horizontally or vertically
This native is typically used after ATTACH_ENTITY_TO_ENTITY

## _SET_ENTITY_CARCASS_TYPE
`0x399657ED871B3A6C` | `void _SET_ENTITY_CARCASS_TYPE(Entity entity, Hash type)` | build 1207
Changes type and quality of skins
type hashes: https://pastebin.com/C1WvQjCy

## _SET_ENTITY_CARRYING_FLAG
`0x18FF3110CF47115D` | `void _SET_ENTITY_CARRYING_FLAG(Entity entity, int flagId, BOOL value)` | build 1207
flagId: https://github.com/femga/rdr3_discoveries/tree/master/AI/CARRYING_FLAGS
https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/CCarryingFlags__Flags

enum eCarryingFlag
{
	CARRYING_FLAG_CAN_BE_CUT_FREE = 1,
	CARRYING_FLAG_CAN_BE_CARRIED_ON_FOOT = 2,
	CARRYING_FLAG_CAN_BE_DROPPED = 4,
	CARRYING_FLAG_CAN_BE_CARRIED_WHEN_DEAD = 7,
	CARRYING_FLAG_CAN_CARRY_ANYTHING = 9,
	CARRYING_FLAG_DISABLE_PROMPT_LOS_CHECKS = 19,
	CARRYING_FLAG_FORCE_ALLOW_WARP_TO_SAFE_GROUND_LOCATION = 23,
	CARRYING_FLAG_PICKUPS_IGNORE_HEIGHT_RESTRICTIONS = 26,
	CARRYING_FLAG_CLEAN_UP_WHEN_NOT_CARRIED = 27,
	CARRYING_FLAG_BLOCK_KNOCK_OFF_PED_VARIATIONS_FROM_CARRIABLE_INTERACTIONS = 29,
	CARRYING_FLAG_HIT_WHEN_CARRIABLE = 31,
	CARRYING_FLAG_DISABLE_CARRIABLE_INTERACTIONS_ON_THIS_MOUNT = 34,
	CARRYING_FLAG_FORCE_HIDE_PROMPT_GROUP = 37,
};

## _SET_ENTITY_COORDS_AND_HEADING
`0x203BEFFDBE12E96A` | `void _SET_ENTITY_COORDS_AND_HEADING(Entity entity, float xPos, float yPos, float zPos, float heading, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207

## _SET_ENTITY_COORDS_AND_HEADING_NO_OFFSET
`0x0918E3565C20F03C` | `void _SET_ENTITY_COORDS_AND_HEADING_NO_OFFSET(Entity entity, float xPos, float yPos, float zPos, float heading, BOOL p5, BOOL p6)` | build 1207

## _SET_ENTITY_CUSTOM_PICKUP_RADIUS
`0x482D17E45665DA44` | `void _SET_ENTITY_CUSTOM_PICKUP_RADIUS(Entity entity, float radius)` | build 1207

## _SET_ENTITY_DISABLE_FLAME
`0x56E0735D6273B227` | `void _SET_ENTITY_DISABLE_FLAME(Entity entity, BOOL enabled)` | build 1207
disables the flames only of fires like campfires

## _SET_ENTITY_FADE_IN
`0xA91E6CF94404E8C9` | `void _SET_ENTITY_FADE_IN(Entity entity)` | build 1207

## _SET_ENTITY_FLAME_INTENSITY
`0xC0EDEF16D90661EE` | `void _SET_ENTITY_FLAME_INTENSITY(Entity entity, float intensity)` | build 1207
Sets the intensity of the flames for a torch

## _SET_ENTITY_FULLY_LOOTED
`0x6BCF5F3D8FFE988D` | `void _SET_ENTITY_FULLY_LOOTED(Entity entity, BOOL looted)` | build 1207

## _SET_ENTITY_LIGHTS_DISABLED
`0x2D40BCBFE9305DEA` | `void _SET_ENTITY_LIGHTS_DISABLED(Entity entity, BOOL disabled)` | build 1207
Controls a forced "lights off" state for entities that have built-in light sources.
This native does not enable lights, instead it overrides the light state by forcing them off.

## _SET_ENTITY_LIGHTS_ENABLED
`0xEBDC12861D079ABA` | `void _SET_ENTITY_LIGHTS_ENABLED(Entity entity, BOOL enabled)` | build 1207
Forces entity lights to stay enabled regardless of environmental conditions (day/night cycle)
This native overrides the default behavior where lights typically only activate at night
true  = lights are always enabled (day and night)
false = original behavior is restored

## _SET_ENTITY_LOCKON_POINT_OFFSET
`0xAF7F3099B9FEB535` | `void _SET_ENTITY_LOCKON_POINT_OFFSET(Entity entity, float offsetX, float offsetY, float offsetZ)` | build 1207
Sets an offset for the entity's lock-on / target focus point.

## _SET_ENTITY_PELT_TEXTURE
`0xDD03FC2089AD093C` | `void _SET_ENTITY_PELT_TEXTURE(Entity entity, Hash inventoryItem, Hash albedo, int p3)` | build 1207
Set the pelt texture to the entity, by albedo hash and inventory item hash
Examples: object: P_CS_PELT_MEDLARGE  albedo: a_c_boar_01_head_000_c0_000_ab, inventoryItem: PROVISION_BOAR_HIDE_POOR

## _SET_ENTITY_ROTATION_PARALLEL_TO_LINE
`0xD45BB89B53FC0CFD` | `void _SET_ENTITY_ROTATION_PARALLEL_TO_LINE(Entity entity, float coords1X, float coords1Y, float coords1Z, float coords2X, float coords2Y, float coords2Z, int p7)` | build 1207
Sets the entity's rotation so that it becomes parallel to the direction defined by the line between coords1 and coords2, without moving the entity from its current position.

This native does NOT make the entity face coords1 or coords2. Instead, it keeps the entity at its current world position and adjusts its orientation so that it is aligned parallel to the direction derived from the two coordinates

## _SET_ENTITY_THREAT_TIER
`0x4B436BAC8CBE9B07` | `void _SET_ENTITY_THREAT_TIER(Entity entity, int tier, BOOL p2)` | build 1207
tier: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eEntityThreatTier

## _SET_MATERIAL_FILL_LEVEL_FOR_ENTITY
`0x669655FFB29EF1A9` | `void _SET_MATERIAL_FILL_LEVEL_FOR_ENTITY(Entity entity, int expressionType, char* dofName, float fillState)` | build 1207
sets the fill in state for some objects like for the stew, coffee mug ,poker chips, jugs ? P1 is either 0 or 2 p2 seems to be a label/name p3 is the fill in state, max seems to be for some 3.0 (most is 1.0) - 0.0
heres some of the labels/names found 
tumbler_fill, Canvas, Stew_Fill, from Chip01_Ctrl to Chip10_Ctrl, from empty_jug01_Ctrl to empty_jug20_Ctrl, from full_jug01_Ctrl to full_jug20_Ctrl, CTRL_cupFill, Food_DOF_Fill, from WhiteChip_Ctrl_0 to WhiteChip_Ctrl_10, from BlueChip_Ctrl_0 to BlueChip_Ctrl_10, from BlackChip_Ctrl_0 to BlackChip_Ctrl_10, from RedChip_Ctrl_0 to RedChip_Ctrl_10,

## _UNPIN_MAP_ENTITY
`0xD2B9C78537ED5759` | `void _UNPIN_MAP_ENTITY(int pinId)` | build 1207
