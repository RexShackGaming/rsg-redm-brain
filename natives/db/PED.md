# PED natives (1010)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_ARMOUR_TO_PED
`0x5BA652A0CD14DF2F` | `void ADD_ARMOUR_TO_PED(Ped ped, int amount)` | build 1207
Same as SET_PED_ARMOUR, but ADDS 'amount' to the armor the Ped already has.

## ADD_CUSTOM_FORMATION_LOCATION
`0x4E23CD07BD161E06` | `void ADD_CUSTOM_FORMATION_LOCATION(int groupId, float x, float y, float z, int position)` | build 1207

## ADD_FORMATION_LOCATION
`0xB05945C1E9E60D91` | `BOOL ADD_FORMATION_LOCATION(int groupId, float p1, float p2, float p3)` | build 1207

## ADD_RELATIONSHIP_GROUP
`0xF372BC22FCB88606` | `BOOL ADD_RELATIONSHIP_GROUP(char* name, Hash groupHash)` | build 1207
The hash of the created relationship group is output in the second parameter.

## ADD_SCENARIO_BLOCKING_AREA
`0x1B5C85C612E5256E` | `int ADD_SCENARIO_BLOCKING_AREA(float x1, float y1, float z1, float x2, float y2, float z2, BOOL p6, int blockingFlags)` | build 1207
blockingFlags: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eScenarioBlockingFlags

## APPLY_DAMAGE_TO_PED
`0x697157CED63F18D4` | `void APPLY_DAMAGE_TO_PED(Ped ped, int damageAmount, BOOL damageArmour, int boneId, Ped pedKiller)` | build 1207
damages a ped with the given amount

## APPLY_PED_BLOOD_SPECIFIC
`0xEF0D582CBF2D9B0F` | `void APPLY_PED_BLOOD_SPECIFIC(Ped ped, Any p1, float p2, float p3, float p4, float p5, Any p6, float p7, Any* p8)` | build 1207

## APPLY_PED_DAMAGE_PACK
`0x46DF918788CB093F` | `void APPLY_PED_DAMAGE_PACK(Ped ped, char* damagePack, float damage, float mult)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/peds_customization/ped_decals.lua

## CAN_KNOCK_PED_OFF_VEHICLE
`0x51AC07A44D4F5B8A` | `BOOL CAN_KNOCK_PED_OFF_VEHICLE(Ped ped)` | build 1207

## CAN_PED_BE_MOUNTED
`0x2D64376CF437363E` | `BOOL CAN_PED_BE_MOUNTED(Ped ped)` | build 1207

## CAN_PED_IN_COMBAT_SEE_TARGET
`0xEAD42DE3610D0721` | `BOOL CAN_PED_IN_COMBAT_SEE_TARGET(Ped ped, Ped target)` | build 1207

## CAN_PED_RAGDOLL
`0x128F79EDCECE4FD5` | `BOOL CAN_PED_RAGDOLL(Ped ped)` | build 1207

## CAN_PED_SEE_ENTITY
`0x7F9B9791D4CB71F6` | `int CAN_PED_SEE_ENTITY(Ped ped, Entity targetEntity, BOOL p2, BOOL doFoliageCheck)` | build 1207
Returns:
0 - CTR_CANNOT_TARGET
1 - CTR_CAN_TARGET
2 - CTR_NOT_SURE_YET

## CAN_PED_SEE_PED_CACHED
`0x9D9473CB82D83A30` | `int CAN_PED_SEE_PED_CACHED(Ped ped, Ped targetPed, BOOL p2)` | build 1207

## CLEAR_FACIAL_IDLE_ANIM_OVERRIDE
`0x726256CC1EEB182F` | `void CLEAR_FACIAL_IDLE_ANIM_OVERRIDE(Ped ped)` | build 1207

## CLEAR_PED_BLOOD_DAMAGE
`0x8FE22675A5A45817` | `void CLEAR_PED_BLOOD_DAMAGE(Ped ped)` | build 1207

## CLEAR_PED_BLOOD_DAMAGE_BY_ZONE
`0x56E3B78C5408D9F4` | `void CLEAR_PED_BLOOD_DAMAGE_BY_ZONE(Ped ped, int p1)` | build 1207

## CLEAR_PED_DAMAGE_DECAL_BY_ZONE
`0x523C79AEEFCC4A2A` | `void CLEAR_PED_DAMAGE_DECAL_BY_ZONE(Ped ped, int p1, char* p2)` | build 1207

## CLEAR_PED_DECORATIONS
`0x0E5173C163976E38` | `void CLEAR_PED_DECORATIONS(Ped ped)` | build 1207

## CLEAR_PED_ENV_DIRT
`0x6585D955A68452A5` | `void CLEAR_PED_ENV_DIRT(Ped ped)` | build 1207

## CLEAR_PED_LAST_DAMAGE_BONE
`0x8EF6B7AC68E2F01B` | `void CLEAR_PED_LAST_DAMAGE_BONE(Ped ped)` | build 1207

## CLEAR_PED_NON_CREATION_AREA
`0x2E05208086BA0651` | `void CLEAR_PED_NON_CREATION_AREA()` | build 1207

## CLEAR_PED_WETNESS
`0x9C720776DAA43E7E` | `void CLEAR_PED_WETNESS(Ped ped)` | build 1207
It clears the wetness of the selected Ped/Player. Clothes have to be wet to notice the difference.

## CLEAR_RAGDOLL_BLOCKING_FLAGS
`0xD86D101FCFD00A4B` | `void CLEAR_RAGDOLL_BLOCKING_FLAGS(Ped ped, int flags)` | build 1207
flags: see SET_RAGDOLL_BLOCKING_FLAGS

## CLEAR_RELATIONSHIP_BETWEEN_GROUPS
`0x5E29243FB56FC6D4` | `void CLEAR_RELATIONSHIP_BETWEEN_GROUPS(int relationship, Hash group1, Hash group2)` | build 1207

## CLONE_PED
`0xEF29A16337FACADB` | `Ped CLONE_PED(Ped ped, BOOL isNetwork, BOOL bScriptHostPed, BOOL copyHeadBlendFlag)` | build 1207

## CLONE_PED_TO_TARGET
`0xE952D6431689AD9A` | `void CLONE_PED_TO_TARGET(Ped ped, Ped targetPed)` | build 1207
Copies ped's components and props to targetPed.
Can be used to clear anything from a ped by cloning it, including bullet holes.

## COMPUTE_SATCHEL_ITEM_FOR_PED_DAMAGE
`0x9E7738B291706746` | `BOOL COMPUTE_SATCHEL_ITEM_FOR_PED_DAMAGE(Any p0, Ped pedAttached, int damageCleanliness)` | build 1207

## COUNT_PEDS_IN_COMBAT_WITH_TARGET
`0x5407B7288D0478B7` | `int COUNT_PEDS_IN_COMBAT_WITH_TARGET(Ped ped, int flag)` | build 1207

## COUNT_PEDS_IN_COMBAT_WITH_TARGET_WITHIN_RADIUS
`0x336B3D200AB007CB` | `int COUNT_PEDS_IN_COMBAT_WITH_TARGET_WITHIN_RADIUS(Ped ped, float x, float y, float z, float radius, int flag)` | build 1207

## CREATE_GROUP
`0x90370EBE0FEE1A3D` | `int CREATE_GROUP(int taskAllocator)` | build 1207
Creates a new ped group.
Groups can contain up to 8 peds.

The parameter is unused.

Returns a handle to the created group, or 0 if a group couldn't be created.

## CREATE_PED
`0xD49F9B0955C367DE` | `Ped CREATE_PED(Hash modelHash, float x, float y, float z, float heading, BOOL isNetwork, BOOL bScriptHostPed, BOOL p7, BOOL p8)` | build 1207

## CREATE_PED_INSIDE_VEHICLE
`0x7DD959874C1FD534` | `Ped CREATE_PED_INSIDE_VEHICLE(Vehicle vehicle, Hash modelHash, int seatIndex, BOOL p3, BOOL p4, BOOL p5)` | build 1207
seatIndex:
enum eVehicleSeat
{
	VS_ANY_PASSENGER = -2,
	VS_DRIVER,
	VS_FRONT_RIGHT,
	VS_BACK_LEFT,
	VS_BACK_RIGHT,
	VS_EXTRA_LEFT_1,
	VS_EXTRA_RIGHT_1,
	VS_EXTRA_LEFT_2,
	VS_EXTRA_RIGHT_2,
	VS_EXTRA_LEFT_3,
	VS_EXTRA_RIGHT_3,
	VS_NUM_SEATS
};

## CREATE_PED_ON_MOUNT
`0xF89AA2BD01FC06B7` | `Ped CREATE_PED_ON_MOUNT(Ped mount, Hash modelHash, int index, BOOL p3, BOOL p4, BOOL p5, BOOL p6)` | build 1207

## DELETE_PED
`0xCC0EF140F99365C5` | `void DELETE_PED(Ped* ped)` | build 1207
Deletes the specified ped, then sets the handle pointed to by the pointer to NULL.

## DETACH_CARRIABLE_ENTITY
`0xED00D72F81CF7278` | `void DETACH_CARRIABLE_ENTITY(Entity entity, BOOL p1, BOOL p2)` | build 1207

## DISABLE_PED_INJURED_ON_GROUND_BEHAVIOUR
`0x733C87D4CE22BEA2` | `void DISABLE_PED_INJURED_ON_GROUND_BEHAVIOUR(Ped ped)` | build 1207

## DOES_GROUP_EXIST
`0x7C6B0C22F9F40BBE` | `BOOL DOES_GROUP_EXIST(int groupId)` | build 1207

## EXPLODE_PED_HEAD
`0x2D05CED3A38D0F3A` | `void EXPLODE_PED_HEAD(Ped ped, Hash weaponHash)` | build 1207
Forces the ped to fall back and kills it.

It doesn't really explode the ped's head but it kills the ped

## FADE_AND_DESTROY_PED
`0x7043D0681285BA2D` | `void FADE_AND_DESTROY_PED(Ped* ped)` | build 1207

## FIND_ALL_ATTACHED_CARRIABLE_ENTITIES
`0xB5ACE8B23A438EC0` | `void FIND_ALL_ATTACHED_CARRIABLE_ENTITIES(Ped ped, ItemSet itemset)` | build 1207

## FORCE_ALL_HEADING_VALUES_TO_ALIGN
`0xFF287323B0E2C69A` | `void FORCE_ALL_HEADING_VALUES_TO_ALIGN(Ped ped)` | build 1207
Old name: _FREEZE_PED_CAMERA_ROTATION

## FORCE_PED_AI_AND_ANIMATION_UPDATE
`0x2208438012482A1A` | `void FORCE_PED_AI_AND_ANIMATION_UPDATE(Ped ped, BOOL p1, BOOL p2)` | build 1207

## FORCE_PED_MOTION_STATE
`0xF28965D04F570DCA` | `BOOL FORCE_PED_MOTION_STATE(Ped ped, Hash motionStateHash, BOOL p2, int p3, BOOL p4)` | build 1207
motionStateHash: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/CPedMotionStates__eMotionState

## GET_ANIM_INITIAL_OFFSET_POSITION
`0xBE22B26DD764C040` | `Vector3 GET_ANIM_INITIAL_OFFSET_POSITION(char* animDict, char* animName, float x, float y, float z, float xRot, float yRot, float zRot, float p8, int p9)` | build 1207

## GET_ANIM_INITIAL_OFFSET_ROTATION
`0x4B805E6046EE9E47` | `Vector3 GET_ANIM_INITIAL_OFFSET_ROTATION(char* animDict, char* animName, float x, float y, float z, float xRot, float yRot, float zRot, float p8, int p9)` | build 1207

## GET_CLOSEST_PED
`0xC33AB876A77F8164` | `BOOL GET_CLOSEST_PED(float x, float y, float z, float radius, BOOL p4, BOOL p5, Ped* outPed, BOOL p7, BOOL p8, BOOL p9, int pedType)` | build 1207
Gets the closest ped in a radius.

## GET_COMBAT_FLOAT
`0x52DFF8A10508090A` | `float GET_COMBAT_FLOAT(Ped ped, int combatType)` | build 1207

## GET_CURRENT_TARGET_FOR_PED
`0xCD66FEA29400A0B5` | `Entity GET_CURRENT_TARGET_FOR_PED(Ped ped)` | build 1207

## GET_DEAD_PED_PICKUP_COORDS
`0xCD5003B097200F36` | `Vector3 GET_DEAD_PED_PICKUP_COORDS(Ped ped, float p1, float p2)` | build 1207

## GET_GROUP_SIZE
`0x8DE69FE35CA09A45` | `void GET_GROUP_SIZE(int groupId, BOOL* hasLeader, int* numberOfFollowers)` | build 1207

## GET_IS_PED_RESPONDING_TO_NEGATIVE_INTERACTION
`0xA454D234E45BB6E5` | `BOOL GET_IS_PED_RESPONDING_TO_NEGATIVE_INTERACTION(Ped ped, Player player)` | build 1207

## GET_IS_PED_RESPONDING_TO_POSITIVE_INTERACTION
`0x9337183FDA2E9035` | `BOOL GET_IS_PED_RESPONDING_TO_POSITIVE_INTERACTION(Ped ped, Player player)` | build 1207

## GET_JACK_TARGET
`0x5486A79D9FBD342D` | `Ped GET_JACK_TARGET(Ped ped)` | build 1207

## GET_LOOTING_PICKUP_TARGET_ENTITY
`0x14169FA823679E41` | `Entity GET_LOOTING_PICKUP_TARGET_ENTITY(Ped ped)` | build 1207

## GET_MELEE_TARGET_FOR_PED
`0x18A3E9EE1297FD39` | `Ped GET_MELEE_TARGET_FOR_PED(Ped ped)` | build 1207

## GET_META_PED_ASSET_GUIDS
`0xA9C28516A6DC9D56` | `BOOL GET_META_PED_ASSET_GUIDS(Ped ped, int index, Hash* drawable, Hash* albedo, Hash* normal, Hash* material)` | build 1207
This is a way to get what drawables a ped has equipped
Example: you are able to tell if the ped has the drawable PLAYER_ZERO_HAT_017 attached
Note: this works with non shop components, direct .ydd files.

## GET_META_PED_ASSET_TINT
`0xE7998FEC53A33BBE` | `BOOL GET_META_PED_ASSET_TINT(Ped ped, int index, Hash* pallete, int* tint0, int* tint1, int* tint2)` | build 1207

## GET_MOUNT
`0xE7E11B8DCBED1058` | `Ped GET_MOUNT(Ped ped)` | build 1207

## GET_NUM_META_PED_OUTFITS
`0x10C70A515BC03707` | `int GET_NUM_META_PED_OUTFITS(Ped ped)` | build 1207

## GET_PEDS_JACKER
`0x9B128DC36C1E04CF` | `Ped GET_PEDS_JACKER(Ped ped)` | build 1207

## GET_PED_ACCURACY
`0x37F4AD56ECBC0CD6` | `int GET_PED_ACCURACY(Ped ped)` | build 1207

## GET_PED_AS_GROUP_LEADER
`0x5CCE68DBD5FE93EC` | `Ped GET_PED_AS_GROUP_LEADER(int groupID)` | build 1207

## GET_PED_AS_GROUP_MEMBER
`0x51455483CF23ED97` | `Ped GET_PED_AS_GROUP_MEMBER(int groupID, int memberNumber)` | build 1207

## GET_PED_BLACKBOARD_SCRIPT_BOOL
`0x4912DFE492DB98CD` | `BOOL GET_PED_BLACKBOARD_SCRIPT_BOOL(Ped ped, char* variableName)` | build 1207

## GET_PED_BLACKBOARD_SCRIPT_FLOAT
`0xA29FD00D45311EB7` | `float GET_PED_BLACKBOARD_SCRIPT_FLOAT(Ped ped, char* variableName)` | build 1207

## GET_PED_BLACKBOARD_SCRIPT_INT
`0xB71B91B398F8F067` | `int GET_PED_BLACKBOARD_SCRIPT_INT(Ped ped, char* variableName)` | build 1207

## GET_PED_BONE_COORDS
`0x17C07FC640E86B4E` | `Vector3 GET_PED_BONE_COORDS(Ped ped, int boneId, float offsetX, float offsetY, float offsetZ)` | build 1207
Gets the position of the specified bone of the specified ped.

ped: The ped to get the position of a bone from.
boneId: The ID of the bone to get the position from. This is NOT the index.
offsetX: The X-component of the offset to add to the position relative to the bone's rotation.
offsetY: The Y-component of the offset to add to the position relative to the bone's rotation.
offsetZ: The Z-component of the offset to add to the position relative to the bone's rotation.

## GET_PED_BONE_INDEX
`0x3F428D08BE5AAE31` | `int GET_PED_BONE_INDEX(Ped ped, int boneId)` | build 1207
no bone = -1

## GET_PED_CAUSE_OF_DEATH
`0x16FFE42AB2D2DC59` | `Hash GET_PED_CAUSE_OF_DEATH(Ped ped)` | build 1207
Returns the hash of the weapon/model/object that killed the ped.

## GET_PED_COMBAT_MOVEMENT
`0xDEA92412FCAEB3F5` | `int GET_PED_COMBAT_MOVEMENT(Ped ped)` | build 1207

## GET_PED_CONFIG_FLAG
`0x7EE53118C892B513` | `BOOL GET_PED_CONFIG_FLAG(Ped ped, int flagId, BOOL p2)` | build 1207
flagId: see SET_PED_CONFIG_FLAG

## GET_PED_CROUCH_MOVEMENT
`0xD5FE956C70FF370B` | `BOOL GET_PED_CROUCH_MOVEMENT(Ped ped)` | build 1207

## GET_PED_CURRENT_MOVE_BLEND_RATIO
`0xF60165E1D2C5370B` | `BOOL GET_PED_CURRENT_MOVE_BLEND_RATIO(Ped ped, float* speedX, float* speedY)` | build 1207
Old name: _GET_PED_CURRENT_MOVEMENT_SPEED

## GET_PED_DEFENSIVE_AREA_POSITION
`0x3C06B8786DD94CD1` | `Vector3 GET_PED_DEFENSIVE_AREA_POSITION(Ped ped, BOOL p1)` | build 1207

## GET_PED_GRAPPLE_STATE
`0x2311F15D971AA680` | `int GET_PED_GRAPPLE_STATE(Ped ped)` | build 1207

## GET_PED_GROUP_INDEX
`0xF162E133B4E7A675` | `int GET_PED_GROUP_INDEX(Ped ped)` | build 1207
Returns the groupId of which the specified ped is a member of.

## GET_PED_IS_BEING_GRAPPLED
`0x3BDFCF25B58B0415` | `BOOL GET_PED_IS_BEING_GRAPPLED(Ped ped)` | build 1207

## GET_PED_IS_DOING_COMBAT_ROLL
`0xC48A9EB0D499B3E5` | `BOOL GET_PED_IS_DOING_COMBAT_ROLL(Ped ped)` | build 1207

## GET_PED_IS_GRAPPLING
`0x0E99E3BF11BB6367` | `BOOL GET_PED_IS_GRAPPLING(Ped ped)` | build 1207

## GET_PED_LAST_DAMAGE_BONE
`0xD75960F6BD9EA49C` | `BOOL GET_PED_LAST_DAMAGE_BONE(Ped ped, int* outBone)` | build 1207

## GET_PED_LOOT_STATUS_MP
`0xC737697C41628340` | `int GET_PED_LOOT_STATUS_MP(Ped ped)` | build 1311
enum ePedLootStatus
{
	PLS_NONE,
	PLS_PRE_LOOT,
	PLS_SAMPLING,
	PLS_SKINNING
};

## GET_PED_MAX_HEALTH
`0x4700A416E8324EF3` | `int GET_PED_MAX_HEALTH(Ped ped)` | build 1207

## GET_PED_MONEY
`0x3F69145BBA87BAE7` | `int GET_PED_MONEY(Ped ped)` | build 1207

## GET_PED_MOTION_FOCUS_ENTITY
`0x243E1B4607040057` | `Entity GET_PED_MOTION_FOCUS_ENTITY(Ped ped)` | build 1207

## GET_PED_NEARBY_PEDS
`0x23F8F5FC7E8C4A6B` | `int GET_PED_NEARBY_PEDS(Ped ped, Any* sizeAndPeds, int ignoredPedType, int p3)` | build 1207

## GET_PED_NEARBY_VEHICLES
`0xCFF869CBFA210D82` | `int GET_PED_NEARBY_VEHICLES(Ped ped, Any* sizeAndVehs)` | build 1207

## GET_PED_RELATIONSHIP_GROUP_DEFAULT_HASH
`0x42FDD0F017B1E38E` | `Hash GET_PED_RELATIONSHIP_GROUP_DEFAULT_HASH(Ped ped)` | build 1207

## GET_PED_RELATIONSHIP_GROUP_HASH
`0x7DBDD04862D95F04` | `Hash GET_PED_RELATIONSHIP_GROUP_HASH(Ped ped)` | build 1207

## GET_PED_RESET_FLAG
`0xAF9E59B1B1FBF2A0` | `BOOL GET_PED_RESET_FLAG(Ped ped, int flagId)` | build 1207

## GET_PED_SOURCE_OF_DEATH
`0x93C8B64DEB84728C` | `Entity GET_PED_SOURCE_OF_DEATH(Ped ped)` | build 1207
Returns the entity that killed the ped

It is best to check if the Ped is dead before asking for its killer.

## GET_PED_STEALTH_MOVEMENT
`0x7C2AC9CA66575FBF` | `BOOL GET_PED_STEALTH_MOVEMENT(Ped ped)` | build 1207
Returns whether the entity is in stealth mode

## GET_PED_TIME_OF_DEATH
`0x1E98817B311AE98A` | `int GET_PED_TIME_OF_DEATH(Ped ped)` | build 1207

## GET_PED_TO_PLAYER_WEAPON_DAMAGE_MODIFIER
`0x936E7CAD0AE2EE14` | `float GET_PED_TO_PLAYER_WEAPON_DAMAGE_MODIFIER(Ped ped)` | build 1207

## GET_PED_TYPE
`0xFF059E1E4C01E63C` | `int GET_PED_TYPE(Ped ped)` | build 1207

## GET_PLAYER_PED_IS_FOLLOWING
`0x6A3975DEA89F9A17` | `Player GET_PLAYER_PED_IS_FOLLOWING(Ped ped)` | build 1207

## GET_RELATIONSHIP_BETWEEN_GROUPS
`0x9E6B70061662AE5C` | `int GET_RELATIONSHIP_BETWEEN_GROUPS(Hash group1, Hash group2)` | build 1207

## GET_RELATIONSHIP_BETWEEN_PEDS
`0xEBA5AD3A0EAF7121` | `int GET_RELATIONSHIP_BETWEEN_PEDS(Ped ped1, Ped ped2)` | build 1207

## GET_SEAT_PED_IS_TRYING_TO_ENTER
`0x6F4C85ACD641BCD2` | `int GET_SEAT_PED_IS_TRYING_TO_ENTER(Ped ped)` | build 1207

## GET_SEAT_PED_IS_USING
`0x4E76CB57222A00E5` | `int GET_SEAT_PED_IS_USING(Ped ped)` | build 1207

## GET_TRACKED_PED_PIXELCOUNT
`0x511F1A683387C7E2` | `int GET_TRACKED_PED_PIXELCOUNT(Ped ped)` | build 1207

## GET_VEHICLE_PED_IS_ENTERING
`0xF92691AED837A5FC` | `Vehicle GET_VEHICLE_PED_IS_ENTERING(Ped ped)` | build 1207

## GET_VEHICLE_PED_IS_IN
`0x9A9112A0FE9A4713` | `Vehicle GET_VEHICLE_PED_IS_IN(Ped ped, BOOL lastVehicle)` | build 1207
Gets the vehicle the specified Ped is in.

If the Ped is not in a vehicle and includeLastVehicle is true, the vehicle they were last in is returned.

## GET_VEHICLE_PED_IS_USING
`0x6094AD011A2EA87D` | `Vehicle GET_VEHICLE_PED_IS_USING(Ped ped)` | build 1207

## GIVE_PED_HASH_SCENARIO_PROP
`0x2B02DB082258625F` | `BOOL GIVE_PED_HASH_SCENARIO_PROP(Ped ped, Object object, char* conditionalAnim, Hash scenarioType, Hash p4, BOOL p5)` | build 1207

## HAS_MOTION_TYPE_ASSET_LOADED
`0x854BC9B1A1CCD034` | `BOOL HAS_MOTION_TYPE_ASSET_LOADED(Hash nameHash, Ped ped)` | build 1207

## INIT_PED_DEFAULT_HEALTH
`0x7DD7FB3480D8083E` | `void INIT_PED_DEFAULT_HEALTH(Ped ped)` | build 1207

## INSTANTLY_FILL_PED_POPULATION
`0x4759CC730F947C81` | `void INSTANTLY_FILL_PED_POPULATION()` | build 1207

## IS_ANIMAL_INTERACTION_POSSIBLE
`0xD543D3A8FDE4F185` | `BOOL IS_ANIMAL_INTERACTION_POSSIBLE(Ped ped, Ped animal)` | build 1207

## IS_ANY_HOSTILE_PED_NEAR_POINT
`0x68772DB2B2526F9F` | `BOOL IS_ANY_HOSTILE_PED_NEAR_POINT(Ped ped, float x, float y, float z, float radius)` | build 1311

## IS_ANY_PED_NEAR_POINT
`0x083961498679DC9F` | `BOOL IS_ANY_PED_NEAR_POINT(float x, float y, float z, float radius)` | build 1207

## IS_ANY_PED_SHOOTING_IN_AREA
`0xA0D3D71EA1086C55` | `BOOL IS_ANY_PED_SHOOTING_IN_AREA(float x1, float y1, float z1, float x2, float y2, float z2, BOOL p6, BOOL p7)` | build 1207

## IS_EVENT_IN_QUEUE
`0xC8D523BF5BBD3808` | `BOOL IS_EVENT_IN_QUEUE(Ped ped, Hash eventType)` | build 1207

## IS_GROUP_LOCALLY_CONTROLLED
`0x909AD9E9A92A10DF` | `BOOL IS_GROUP_LOCALLY_CONTROLLED(int groupId)` | build 1207

## IS_INSTANTLY_FILL_PED_POPULATION_FINISHED
`0x0EE3F0D7FECCC54F` | `BOOL IS_INSTANTLY_FILL_PED_POPULATION_FINISHED()` | build 1207

## IS_LOCATION_SPAWN_SAFE
`0xFB1E7998B8595825` | `BOOL IS_LOCATION_SPAWN_SAFE(Ped ped, float p1)` | build 1207

## IS_PED_AIMING_FROM_COVER
`0x3998B1276A3300E5` | `BOOL IS_PED_AIMING_FROM_COVER(Ped ped)` | build 1207

## IS_PED_A_PLAYER
`0x12534C348C6CB68B` | `BOOL IS_PED_A_PLAYER(Ped ped)` | build 1207

## IS_PED_BEING_DRAGGED
`0xEF3A8772F085B4AA` | `BOOL IS_PED_BEING_DRAGGED(Ped ped)` | build 1207

## IS_PED_BEING_HOGTIED
`0xD453BB601D4A606E` | `BOOL IS_PED_BEING_HOGTIED(Ped ped)` | build 1207

## IS_PED_BEING_JACKED
`0x9A497FE2DF198913` | `BOOL IS_PED_BEING_JACKED(Ped ped)` | build 1207

## IS_PED_BEING_STEALTH_KILLED
`0x863B23EFDE9C5DF2` | `BOOL IS_PED_BEING_STEALTH_KILLED(Ped ped)` | build 1207

## IS_PED_BEING_STUNNED
`0x4FBACCE3B4138EE8` | `BOOL IS_PED_BEING_STUNNED(Ped ped, Hash weaponType)` | build 1207

## IS_PED_CARRYING_SOMETHING
`0xA911EE21EDF69DAF` | `BOOL IS_PED_CARRYING_SOMETHING(Ped ped)` | build 1207

## IS_PED_CLIMBING
`0x53E8CB4F48BFE623` | `BOOL IS_PED_CLIMBING(Ped ped)` | build 1207

## IS_PED_DEAD_OR_DYING
`0x3317DEDB88C95038` | `BOOL IS_PED_DEAD_OR_DYING(Ped ped, BOOL p1)` | build 1207

## IS_PED_DEFENSIVE_AREA_ACTIVE
`0xBA63D9FE45412247` | `BOOL IS_PED_DEFENSIVE_AREA_ACTIVE(Ped ped, BOOL p1)` | build 1207

## IS_PED_DIVING
`0x5527B8246FEF9B11` | `BOOL IS_PED_DIVING(Ped ped)` | build 1207

## IS_PED_ENTERING_ANY_TRANSPORT
`0x1D46B417F926D34D` | `BOOL IS_PED_ENTERING_ANY_TRANSPORT(Ped ped)` | build 1207

## IS_PED_EVASIVE_DIVING
`0x414641C26E105898` | `BOOL IS_PED_EVASIVE_DIVING(Ped ped, Entity* evadingEntity)` | build 1207
Presumably returns the Entity that the Ped is currently diving out of the way of.

## IS_PED_FACING_PED
`0xD71649DB0A545AA3` | `BOOL IS_PED_FACING_PED(Ped ped, Ped otherPed, float angle)` | build 1207
angle is ped's view cone

## IS_PED_FALLING
`0xFB92A102F1C4DFA3` | `BOOL IS_PED_FALLING(Ped ped)` | build 1207

## IS_PED_FALLING_OVER
`0x3E592D0486DEC0F6` | `BOOL IS_PED_FALLING_OVER(Ped ped)` | build 1207

## IS_PED_FATALLY_INJURED
`0xD839450756ED5A80` | `BOOL IS_PED_FATALLY_INJURED(Ped ped)` | build 1207
Gets a value indicating whether this ped's health is below its fatally injured threshold. The default threshold is 100.
If the handle is invalid, the function returns true.

## IS_PED_FLEEING
`0xBBCCE00B381F8482` | `BOOL IS_PED_FLEEING(Ped ped)` | build 1207

## IS_PED_FULLY_ON_MOUNT
`0x95CBC65780DE7EB1` | `BOOL IS_PED_FULLY_ON_MOUNT(Ped ped, BOOL p1)` | build 1207

## IS_PED_GETTING_INTO_A_VEHICLE
`0xBB062B2B5722478E` | `BOOL IS_PED_GETTING_INTO_A_VEHICLE(Ped ped)` | build 1207

## IS_PED_GOING_INTO_COVER
`0x9F65DBC537E59AD5` | `BOOL IS_PED_GOING_INTO_COVER(Ped ped)` | build 1207

## IS_PED_GROUP_LEADER
`0x878B68960C1C2A35` | `BOOL IS_PED_GROUP_LEADER(Ped ped, int groupId)` | build 1207

## IS_PED_GROUP_MEMBER
`0x9BB01E3834671191` | `BOOL IS_PED_GROUP_MEMBER(Ped ped, int groupId, BOOL p2)` | build 1207

## IS_PED_HANGING_ON_TO_VEHICLE
`0x1C86D8AEF8254B78` | `BOOL IS_PED_HANGING_ON_TO_VEHICLE(Ped ped)` | build 1207

## IS_PED_HEADING_TOWARDS_POSITION
`0xFCF37A457CB96DC0` | `BOOL IS_PED_HEADING_TOWARDS_POSITION(Ped ped, float x, float y, float z, float p4)` | build 1207

## IS_PED_HEADTRACKING_ENTITY
`0x813A0A7C9D2E831F` | `BOOL IS_PED_HEADTRACKING_ENTITY(Ped ped, Entity entity)` | build 1207

## IS_PED_HEADTRACKING_PED
`0x5CD3CB88A7F8850D` | `BOOL IS_PED_HEADTRACKING_PED(Ped ped1, Ped ped2)` | build 1207

## IS_PED_HOGTIED
`0x3AA24CCC0D451379` | `BOOL IS_PED_HOGTIED(Ped ped)` | build 1207

## IS_PED_HOGTYING
`0x42429C674B61238B` | `BOOL IS_PED_HOGTYING(Ped ped)` | build 1207

## IS_PED_HUMAN
`0xB980061DA992779D` | `BOOL IS_PED_HUMAN(Ped ped)` | build 1207
Returns true/false if the ped is/isn't humanoid.

## IS_PED_INCAPACITATED
`0xB655DB7582AEC805` | `BOOL IS_PED_INCAPACITATED(Ped ped)` | build 1207

## IS_PED_INJURED
`0x84A2DD9AC37C35C1` | `BOOL IS_PED_INJURED(Ped ped)` | build 1207
Gets a value indicating whether this ped's health is below its injured threshold.

The default threshold is 100.

## IS_PED_IN_ANY_BOAT
`0x2E0E1C2B4F6CB339` | `BOOL IS_PED_IN_ANY_BOAT(Ped ped)` | build 1207

## IS_PED_IN_ANY_HELI
`0x298B91AE825E5705` | `BOOL IS_PED_IN_ANY_HELI(Ped ped)` | build 1207

## IS_PED_IN_ANY_PLANE
`0x5FFF4CFC74D8FB80` | `BOOL IS_PED_IN_ANY_PLANE(Ped ped)` | build 1207

## IS_PED_IN_ANY_TAXI
`0x6E575D6A898AB852` | `BOOL IS_PED_IN_ANY_TAXI(Ped ped)` | build 1207

## IS_PED_IN_ANY_TRAIN
`0x6F972C1AB75A1ED0` | `BOOL IS_PED_IN_ANY_TRAIN(Ped ped)` | build 1207

## IS_PED_IN_ANY_VEHICLE
`0x997ABD671D25CA0B` | `BOOL IS_PED_IN_ANY_VEHICLE(Ped ped, BOOL atGetIn)` | build 1207
Gets a value indicating whether the specified ped is in any vehicle.

## IS_PED_IN_COMBAT
`0x4859F1FC66A6278E` | `BOOL IS_PED_IN_COMBAT(Ped ped, Ped target)` | build 1207

## IS_PED_IN_COVER
`0x60DFD0691A170B88` | `BOOL IS_PED_IN_COVER(Ped ped, BOOL p1, BOOL p2)` | build 1207

## IS_PED_IN_COVER_FACING_LEFT
`0x845333B3150583AB` | `BOOL IS_PED_IN_COVER_FACING_LEFT(Ped ped)` | build 1207

## IS_PED_IN_FLYING_VEHICLE
`0x9134873537FA419C` | `BOOL IS_PED_IN_FLYING_VEHICLE(Ped ped)` | build 1207

## IS_PED_IN_GROUP
`0x5891CAC5D4ACFF74` | `BOOL IS_PED_IN_GROUP(Ped ped)` | build 1207

## IS_PED_IN_MELEE_COMBAT
`0x4E209B2C1EAD5159` | `BOOL IS_PED_IN_MELEE_COMBAT(Ped ped)` | build 1207
Notes: The function only returns true while the ped is: 
A.) Swinging a random melee attack (including pistol-whipping)

B.) Reacting to being hit by a melee attack (including pistol-whipping)

C.) Is locked-on to an enemy (arms up, strafing/skipping in the default fighting-stance, ready to dodge+counter). 

You don't have to be holding the melee-targeting button to be in this stance; you stay in it by default for a few seconds after swinging at someone. If you do a sprinting punch, it returns true for the duration of the punch animation and then returns false again, even if you've punched and made-angry many peds

## IS_PED_IN_MODEL
`0x796D90EFB19AA332` | `BOOL IS_PED_IN_MODEL(Ped ped, Hash modelHash)` | build 1207

## IS_PED_IN_VEHICLE
`0xA3EE4A07279BB9DB` | `BOOL IS_PED_IN_VEHICLE(Ped ped, Vehicle vehicle, BOOL atGetIn)` | build 1207
Gets a value indicating whether the specified ped is in the specified vehicle.

## IS_PED_JACKING
`0x4AE4FF911DFB61DA` | `BOOL IS_PED_JACKING(Ped ped)` | build 1207

## IS_PED_JUMPING
`0xCEDABC5900A0BF97` | `BOOL IS_PED_JUMPING(Ped ped)` | build 1207

## IS_PED_LASSOED
`0x9682F850056C9ADE` | `BOOL IS_PED_LASSOED(Ped ped)` | build 1207

## IS_PED_MALE
`0x6D9F5FAA7488BA46` | `BOOL IS_PED_MALE(Ped ped)` | build 1207
Returns true/false if the ped is/isn't male.

## IS_PED_MODEL
`0xC9D55B1A358A5BF7` | `BOOL IS_PED_MODEL(Ped ped, Hash modelHash)` | build 1207

## IS_PED_ON_FOOT
`0x01FEE67DB37F59B2` | `BOOL IS_PED_ON_FOOT(Ped ped)` | build 1207

## IS_PED_ON_MOUNT
`0x460BC76A0E10655E` | `BOOL IS_PED_ON_MOUNT(Ped ped)` | build 1207

## IS_PED_ON_SPECIFIC_VEHICLE
`0xEC5F66E459AF3BB2` | `BOOL IS_PED_ON_SPECIFIC_VEHICLE(Ped ped, Vehicle vehicle)` | build 1207

## IS_PED_ON_VEHICLE
`0x67722AEB798E5FAB` | `BOOL IS_PED_ON_VEHICLE(Ped ped, BOOL p1)` | build 1207
Gets a value indicating whether the specified ped is on top of any vehicle.

Return 1 when ped is on vehicle.
Return 0 when ped is not on a vehicle.

## IS_PED_OPENING_DOOR
`0x26AF0E8E30BD2A2C` | `BOOL IS_PED_OPENING_DOOR(Ped ped)` | build 1207
Returns true if the ped is currently opening a door (CTaskOpenDoor).

Old name: _IS_PED_OPENING_A_DOOR

## IS_PED_PERFORMING_MELEE_ACTION
`0xDCCA191DF9980FD7` | `BOOL IS_PED_PERFORMING_MELEE_ACTION(Ped ped, int p1, Hash p2)` | build 1207

## IS_PED_PLANTING_BOMB
`0xC70B5FAE151982D8` | `BOOL IS_PED_PLANTING_BOMB(Ped ped)` | build 1207

## IS_PED_PRONE
`0xD6A86331A537A7B9` | `BOOL IS_PED_PRONE(Ped ped)` | build 1207

## IS_PED_RAGDOLL
`0x47E4E977581C5B55` | `BOOL IS_PED_RAGDOLL(Ped ped)` | build 1207
If the ped handle passed through the parenthesis is in a ragdoll state this will return true.

## IS_PED_READY_TO_RENDER
`0xA0BC8FAED8CFEB3C` | `BOOL IS_PED_READY_TO_RENDER(Ped ped)` | build 1207

## IS_PED_RELOADING
`0x24B100C68C645951` | `BOOL IS_PED_RELOADING(Ped ped)` | build 1207
Returns whether the specified ped is reloading.

## IS_PED_RESPONDING_TO_EVENT
`0x625B774D75C87068` | `BOOL IS_PED_RESPONDING_TO_EVENT(Ped ped, Hash eventType)` | build 1207
eventType: https://alloc8or.re/rdr3/doc/enums/eEventType.txt

## IS_PED_RESPONDING_TO_THREAT
`0x77525BBF433F2CD6` | `BOOL IS_PED_RESPONDING_TO_THREAT(Ped ped)` | build 1207

## IS_PED_RUNNING_MOBILE_PHONE_TASK
`0x2AFE52F782F25775` | `BOOL IS_PED_RUNNING_MOBILE_PHONE_TASK(Ped ped)` | build 1207

## IS_PED_RUNNING_RAGDOLL_TASK
`0xE3B6097CC25AA69E` | `BOOL IS_PED_RUNNING_RAGDOLL_TASK(Ped ped)` | build 1207

## IS_PED_SHOOTING
`0x34616828CD07F1A1` | `BOOL IS_PED_SHOOTING(Ped ped)` | build 1207
Returns whether the specified ped is shooting.

## IS_PED_SITTING
`0x84D0BF2B21862059` | `BOOL IS_PED_SITTING(Ped ped)` | build 1207

## IS_PED_SITTING_IN_ANY_VEHICLE
`0x826AA586EDB9FEF8` | `BOOL IS_PED_SITTING_IN_ANY_VEHICLE(Ped ped)` | build 1207
Detect if ped is in any vehicle
[True/False]

## IS_PED_SITTING_IN_VEHICLE
`0xA808AA1D79230FC2` | `BOOL IS_PED_SITTING_IN_VEHICLE(Ped ped, Vehicle vehicle)` | build 1207
Detect if ped is sitting in the specified vehicle
[True/False]

## IS_PED_STOPPED
`0x530944F6F4B8A214` | `BOOL IS_PED_STOPPED(Ped ped)` | build 1207

## IS_PED_SWIMMING
`0x9DE327631295B4C2` | `BOOL IS_PED_SWIMMING(Ped ped)` | build 1207

## IS_PED_SWIMMING_UNDER_WATER
`0xC024869A53992F34` | `BOOL IS_PED_SWIMMING_UNDER_WATER(Ped ped)` | build 1207

## IS_PED_USING_ACTION_MODE
`0x00E73468D085F745` | `BOOL IS_PED_USING_ACTION_MODE(Ped ped)` | build 1207

## IS_PED_USING_ANY_SCENARIO
`0x57AB4A3080F85143` | `BOOL IS_PED_USING_ANY_SCENARIO(Ped ped)` | build 1207

## IS_PED_USING_SCENARIO_HASH
`0x34D6AC1157C8226C` | `BOOL IS_PED_USING_SCENARIO_HASH(Ped ped, Hash scenarioHash)` | build 1207
Equivalent to IS_PED_USING_SCENARIO from V but takes a hash instead of a string.

## IS_PED_USING_THIS_SCENARIO
`0x9C54041BB66BCF9E` | `BOOL IS_PED_USING_THIS_SCENARIO(Ped ped, int scenario)` | build 1207

## IS_PED_VAULTING
`0x117C70D1F5730B5E` | `BOOL IS_PED_VAULTING(Ped ped)` | build 1207

## IS_TARGET_PED_IN_PERCEPTION_AREA
`0x06087579E7AA85A9` | `BOOL IS_TARGET_PED_IN_PERCEPTION_AREA(Ped ped, Ped targetPed, float p2, float customDistance, float p4, float p5)` | build 1207
Returns true if ped is in perception (focused and looking at target ped)
Most float params are -1.f in R* Scripts

## IS_TRACKED_PED_VISIBLE
`0x91C8E617F64188AC` | `BOOL IS_TRACKED_PED_VISIBLE(Ped ped)` | build 1207
Returns whether or not a ped is visible within your FOV, not this check auto's to false after a certain distance.
Target needs to be tracked first, won't work otherwise.

## KNOCK_OFF_PED_PROP
`0x6FD7816A36615F48` | `void KNOCK_OFF_PED_PROP(Ped ped, BOOL p1, BOOL p2, BOOL p3, BOOL p4)` | build 1207

## KNOCK_PED_OFF_VEHICLE
`0x45BBCBA77C29A841` | `void KNOCK_PED_OFF_VEHICLE(Ped ped)` | build 1207

## PED_COWER_IN_PLACE
`0xF6E1E9F47A7686F8` | `void PED_COWER_IN_PLACE(Ped ped, Ped ped2)` | build 1207

## PED_COWER_MOVE_TO_POINT
`0x1E4C940233FC0C6F` | `void PED_COWER_MOVE_TO_POINT(Ped ped, float p1, float p2, float p3, Ped ped2, float p5)` | build 1207

## REGISTER_HATED_TARGETS_AROUND_PED
`0x9222F300BF8354FE` | `void REGISTER_HATED_TARGETS_AROUND_PED(Ped ped, float radius)` | build 1207
Based on TASK_COMBAT_HATED_TARGETS_AROUND_PED, the parameters are likely similar (PedHandle, and area to attack in).

## REGISTER_TARGET
`0x2F25D9AEFA34FBA2` | `void REGISTER_TARGET(Ped ped, Ped targetPed, BOOL p2)` | build 1207

## RELEASE_PED_VISIBILITY_TRACKING
`0x3088634CF8C819CF` | `void RELEASE_PED_VISIBILITY_TRACKING(Ped ped)` | build 1207

## REMOVE_GROUP
`0x8EB2F69076AF7053` | `void REMOVE_GROUP(int groupId)` | build 1207

## REMOVE_PED_DEFENSIVE_AREA
`0x74D4E028107450A9` | `void REMOVE_PED_DEFENSIVE_AREA(Ped ped, BOOL toggle)` | build 1207
Ped will no longer get angry when you stay near him.

## REMOVE_PED_FROM_GROUP
`0xED74007FFB146BC2` | `void REMOVE_PED_FROM_GROUP(Ped ped)` | build 1207

## REMOVE_RELATIONSHIP_GROUP
`0xB6BA2444AB393DA2` | `void REMOVE_RELATIONSHIP_GROUP(Hash groupHash)` | build 1207

## REMOVE_SCENARIO_BLOCKING_AREA
`0x31D16B74C6E29D66` | `void REMOVE_SCENARIO_BLOCKING_AREA(Any p0, BOOL p1)` | build 1207

## REMOVE_SCENARIO_BLOCKING_AREAS
`0xD37401D78A929A49` | `void REMOVE_SCENARIO_BLOCKING_AREAS()` | build 1207

## REMOVE_SHOP_ITEM_FROM_PED_BY_CATEGORY
`0xDF631E4BCE1B1FC4` | `void REMOVE_SHOP_ITEM_FROM_PED_BY_CATEGORY(Ped ped, Hash componentCategory, int p2, BOOL p3)` | build 1207
Params: p2, p3 usually 0 in R* Scripts

## REMOVE_TAG_FROM_META_PED
`0xD710A5007C2AC539` | `void REMOVE_TAG_FROM_META_PED(Ped ped, Hash component, int p2)` | build 1207

## REQUEST_PED_USE_SMALL_BBOX_VISIBILITY_TRACKING
`0x75BA1CB3B7D40CAF` | `void REQUEST_PED_USE_SMALL_BBOX_VISIBILITY_TRACKING(Ped ped, BOOL p1)` | build 1207

## REQUEST_PED_VEHICLE_VISIBILITY_TRACKING
`0x2BC338A7B21F4608` | `void REQUEST_PED_VEHICLE_VISIBILITY_TRACKING(Ped ped, BOOL p1)` | build 1207

## REQUEST_PED_VISIBILITY_TRACKING
`0x7D7A2E43E74E2EB8` | `void REQUEST_PED_VISIBILITY_TRACKING(Ped ped)` | build 1207

## RESET_AI_WEAPON_DAMAGE_MODIFIER
`0xEA16670E7BA4743C` | `void RESET_AI_WEAPON_DAMAGE_MODIFIER()` | build 1207

## RESET_GROUP_FORMATION_DEFAULT_SPACING
`0x63DAB4CCB3273205` | `void RESET_GROUP_FORMATION_DEFAULT_SPACING(int groupId)` | build 1207

## RESET_HORSE_AVOIDANCE_LEVEL_TO_DEFAULT
`0x2A5AFD2B8381A6E1` | `void RESET_HORSE_AVOIDANCE_LEVEL_TO_DEFAULT(Ped horse)` | build 1207

## RESET_PED_IN_VEHICLE_CONTEXT
`0x22EF8FF8778030EB` | `void RESET_PED_IN_VEHICLE_CONTEXT(Ped ped)` | build 1207

## RESET_PED_LAST_VEHICLE
`0xBB8DE8CF6A8DD8BB` | `void RESET_PED_LAST_VEHICLE(Ped ped)` | build 1207
Resets the value for the last vehicle driven by the Ped.

## RESET_PED_RAGDOLL_TIMER
`0x9FA4664CF62E47E8` | `void RESET_PED_RAGDOLL_TIMER(Ped ped)` | build 1207

## RESET_PED_WEAPON_MOVEMENT_CLIPSET
`0x97B0DB5B4AA74E77` | `void RESET_PED_WEAPON_MOVEMENT_CLIPSET(Ped ped)` | build 1207

## RESURRECT_PED
`0x71BC8E838B9C6035` | `void RESURRECT_PED(Ped ped)` | build 1207
This function will simply bring the dead ped back to life.

Before calling this function, you may want to declare the position, where your Resurrected ped to be spawn at because theres a chance the ped will fall through the map

Also, disabling any assigned task immediately helped in the number of scenarios, where If you want peds to perform certain decided tasks.

## REVIVE_INJURED_PED
`0x8D8ACD8388CD99CE` | `void REVIVE_INJURED_PED(Ped ped)` | build 1207

## SET_AI_MELEE_WEAPON_DAMAGE_MODIFIER
`0x66460DEDDD417254` | `void SET_AI_MELEE_WEAPON_DAMAGE_MODIFIER(float modifier)` | build 1207

## SET_AI_WEAPON_DAMAGE_MODIFIER
`0x1B1E2A40A65B8521` | `void SET_AI_WEAPON_DAMAGE_MODIFIER(float value)` | build 1207

## SET_BLOCKING_OF_NON_TEMPORARY_EVENTS
`0x9F8AA94D6D97DBF4` | `void SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Ped ped, BOOL toggle)` | build 1207

## SET_BLOCKING_OF_NON_TEMPORARY_EVENTS_FOR_AMBIENT_PEDS_THIS_FRAME
`0x9911F4A24485F653` | `void SET_BLOCKING_OF_NON_TEMPORARY_EVENTS_FOR_AMBIENT_PEDS_THIS_FRAME(BOOL p0)` | build 1207

## SET_COMBAT_FLOAT
`0xFF41B4B141ED981C` | `void SET_COMBAT_FLOAT(Ped ped, int combatType, float newValue)` | build 1207
combatType can be between 0-14. See GET_COMBAT_FLOAT below for a list of possible parameters.
https://github.com/femga/rdr3_discoveries/tree/master/AI/COMBAT_FLOATS 
https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eCombatAttributeFloats

## SET_CREATE_RANDOM_COPS
`0x102E68B2024D536D` | `void SET_CREATE_RANDOM_COPS(BOOL toggle)` | build 1207

## SET_ENABLE_BOUND_ANKLES
`0xC52E0F855C58FC2E` | `void SET_ENABLE_BOUND_ANKLES(Ped ped, BOOL toggle)` | build 1207

## SET_ENABLE_HANDCUFFS
`0xDF1AF8B5D56542FA` | `void SET_ENABLE_HANDCUFFS(Ped ped, BOOL p1, BOOL p2)` | build 1207
Ped can not pull out a weapon when true

## SET_FACIAL_IDLE_ANIM_OVERRIDE
`0xFFC24B988B938B38` | `void SET_FACIAL_IDLE_ANIM_OVERRIDE(Ped ped, char* animName, char* animDict)` | build 1207

## SET_FORMATION_POSITIONS_TARGET_RADIUS
`0x7CC7D3B7AF7FB71F` | `BOOL SET_FORMATION_POSITIONS_TARGET_RADIUS(int groupId, float radius)` | build 1207

## SET_GROUP_FORMATION
`0xCE2F5FC3AF7E8C1E` | `void SET_GROUP_FORMATION(int groupId, int formationType)` | build 1207
eFormationType

0: Default
1: Circle Around Leader
2: Alternative Circle Around Leader
3: Line, with Leader at center

## SET_GROUP_FORMATION_SPACING
`0x1D9D45004C28C916` | `void SET_GROUP_FORMATION_SPACING(int groupId, float p1, float p2, float p3)` | build 1207

## SET_GROUP_SEPARATION_RANGE
`0x4102C7858CFEE4E4` | `void SET_GROUP_SEPARATION_RANGE(int groupId, float separationRange)` | build 1207
Sets the range at which members will automatically leave the group.

## SET_HORSE_AVOIDANCE_LEVEL
`0xDDCF6FEA5D7ACC17` | `void SET_HORSE_AVOIDANCE_LEVEL(Ped horse, int avoidanceLevel)` | build 1207
-1 - HORSE_ASSIST__NO_CHANGE
 0 - HORSE_ASSIST__MANUAL
 1 - HORSE_ASSIST__SEMIASSIST
 2 - HORSE_ASSIST__FULLASSIST

## SET_IK_TARGET
`0xC32779C16FCEECD9` | `void SET_IK_TARGET(Ped ped, int ikIndex, Entity entityLookAt, int boneLookAt, float offsetX, float offsetY, float offsetZ, Any p7, int blendInDuration, int blendOutDuration)` | build 1207

## SET_LOOTING_FLAG
`0x6569F31A01B4C097` | `void SET_LOOTING_FLAG(Ped ped, int lootFlag, BOOL enabled)` | build 1207
https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/CLootingFlags__Flags
https://github.com/femga/rdr3_discoveries/tree/master/AI/LOOTING_FLAGS

lootFlag:
enum eLootFlag
{
	LOOT_FLAG_IS_CRITICAL_LOOT_TARGET = 7,
	LOOT_FLAG_IGNORE_WATER_CHECKS = 8,
	LOOT_FLAG_ANIMAL_FLAGGED_FOR_TAGGING = 23,
};

## SET_PAUSE_PED_WRITHE_BLEEDOUT
`0x925A160133003AC6` | `void SET_PAUSE_PED_WRITHE_BLEEDOUT(Ped ped, BOOL toggle)` | build 1207

## SET_PED_ACCURACY
`0x7AEFB85C1D49DEB6` | `void SET_PED_ACCURACY(Ped ped, int accuracy)` | build 1207
accuracy = 0-100, 100 being perfectly accurate

## SET_PED_AS_COP
`0xBB03C38DD3FB7FFD` | `void SET_PED_AS_COP(Ped ped, BOOL toggle)` | build 1207
Turns the desired ped into a cop. If you use this on the player ped, you will become almost invisible to cops dispatched for you. You will also report your own crimes, get a generic cop voice, get a cop-vision-cone on the radar, and you will be unable to shoot at other cops. Toggling ped as "false" has no effect; you must change p0's ped model to disable the effect.
toggle = bSetRelGroup

## SET_PED_AS_GROUP_LEADER
`0x2A7819605465FBCE` | `void SET_PED_AS_GROUP_LEADER(Ped ped, int groupId, BOOL p2)` | build 1207

## SET_PED_AS_GROUP_MEMBER
`0x9F3480FE65DB31B5` | `void SET_PED_AS_GROUP_MEMBER(Ped ped, int groupId)` | build 1207

## SET_PED_CAN_ARM_IK
`0x6C3B4D6D13B4C841` | `void SET_PED_CAN_ARM_IK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_BE_INCAPACITATED
`0x5240864E847C691C` | `void SET_PED_CAN_BE_INCAPACITATED(Ped ped, BOOL toggle)` | build 1207
When set on a player ped, its just like when you die in RDO

## SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE
`0x7A6535691B477C48` | `void SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE(Ped ped, int state)` | build 1207
state:
enum eKnockOffVehicle
{
	KNOCKOFFVEHICLE_DEFAULT,
	KNOCKOFFVEHICLE_NEVER,
	KNOCKOFFVEHICLE_EASY,
	KNOCKOFFVEHICLE_HARD
};

## SET_PED_CAN_BE_TARGETTED
`0x63F58F7C80513AAD` | `void SET_PED_CAN_BE_TARGETTED(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_BE_TARGETTED_BY_PLAYER
`0x66B57B72E0836A76` | `void SET_PED_CAN_BE_TARGETTED_BY_PLAYER(Ped ped, Player player, BOOL toggle)` | build 1207

## SET_PED_CAN_BE_TARGETTED_BY_TEAM
`0xBF1CA77833E58F2C` | `void SET_PED_CAN_BE_TARGETTED_BY_TEAM(Ped ped, int team, BOOL toggle)` | build 1207

## SET_PED_CAN_BODY_RECOIL_IK
`0xEE9DF765990E8D1D` | `void SET_PED_CAN_BODY_RECOIL_IK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_HEAD_IK
`0xC11C18092C5530DC` | `void SET_PED_CAN_HEAD_IK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_LEG_IK
`0x73518ECE2485412B` | `void SET_PED_CAN_LEG_IK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_PLAY_AMBIENT_ANIMS
`0x6373D1349925A70E` | `void SET_PED_CAN_PLAY_AMBIENT_ANIMS(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_PLAY_AMBIENT_BASE_ANIMS
`0x0EB0585D15254740` | `void SET_PED_CAN_PLAY_AMBIENT_BASE_ANIMS(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_PLAY_GESTURE_ANIMS
`0xBAF20C5432058024` | `void SET_PED_CAN_PLAY_GESTURE_ANIMS(Ped ped, Any p1, Any p2)` | build 1207

## SET_PED_CAN_RAGDOLL
`0xB128377056A54E2A` | `void SET_PED_CAN_RAGDOLL(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_RAGDOLL_FROM_PLAYER_IMPACT
`0xDF993EE5E90ABA25` | `void SET_PED_CAN_RAGDOLL_FROM_PLAYER_IMPACT(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_TELEPORT_TO_GROUP_LEADER
`0x2E2F4240B3F24647` | `void SET_PED_CAN_TELEPORT_TO_GROUP_LEADER(Ped pedHandle, int groupId, BOOL toggle)` | build 1207
This only will teleport the ped to the group leader if the group leader teleports (sets coords).

Only works in singleplayer

## SET_PED_CAN_TORSO_IK
`0xF2B7106D37947CE0` | `void SET_PED_CAN_TORSO_IK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_TORSO_REACT_IK
`0xF5846EDB26A98A24` | `void SET_PED_CAN_TORSO_REACT_IK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_TORSO_VEHICLE_IK
`0x6647C5F6F5792496` | `void SET_PED_CAN_TORSO_VEHICLE_IK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAN_USE_AUTO_CONVERSATION_LOOKAT
`0xEC4686EC06434678` | `void SET_PED_CAN_USE_AUTO_CONVERSATION_LOOKAT(Ped ped, BOOL toggle)` | build 1207

## SET_PED_CAPSULE
`0x364DF566EC833DE2` | `void SET_PED_CAPSULE(Ped ped, float value)` | build 1207
Overrides the ped's collision capsule radius for the current tick.
Must be called every tick to be effective.

Setting this to 0.001 will allow warping through some objects.

## SET_PED_CLOTH_PIN_FRAMES
`0x78C4E9961DB3EB5B` | `void SET_PED_CLOTH_PIN_FRAMES(Ped ped, BOOL p1)` | build 1207
Old name: SET_PED_CLOTH_PACKAGE_INDEX

## SET_PED_COMBAT_ABILITY
`0xC7622C0D36B2FDA8` | `void SET_PED_COMBAT_ABILITY(Ped ped, int abilityLevel)` | build 1207
abilityLevel:
enum eCombatAbilityLevel
{
	CAL_POOR,
	CAL_AVERAGE,
	CAL_PROFESSIONAL
};

## SET_PED_COMBAT_ATTRIBUTES
`0x9F7794730795E019` | `void SET_PED_COMBAT_ATTRIBUTES(Ped ped, int attributeIndex, BOOL enabled)` | build 1207
attributeIndex: https://alloc8or.re/rdr3/doc/enums/eCombatAttribute.txt
https://github.com/femga/rdr3_discoveries/tree/master/AI/COMBAT_ATTRIBUTES

## SET_PED_COMBAT_MOVEMENT
`0x4D9CA1009AFBD057` | `void SET_PED_COMBAT_MOVEMENT(Ped ped, int combatMovement)` | build 1207
0 - Stationary (Will just stand in place)
1 - Defensive (Will try to find cover and very likely to blind fire)
2 - Offensive (Will attempt to charge at enemy but take cover as well)
3 - Suicidal Offensive (Will try to flank enemy in a suicidal attack)

## SET_PED_COMBAT_RANGE
`0x3C606747B23E497B` | `void SET_PED_COMBAT_RANGE(Ped ped, int range)` | build 1207
range:
enum eCombatRange
{
	CR_NEAR,
	CR_MEDIUM,
	CR_FAR,
	CR_VERY_FAR
};

## SET_PED_CONFIG_FLAG
`0x1913FE4CBF41C463` | `void SET_PED_CONFIG_FLAG(Ped ped, int flagId, BOOL value)` | build 1207
flagId: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ePedScriptConfigFlags
https://alloc8or.re/rdr3/doc/enums/ePedScriptConfigFlags.txt
https://github.com/femga/rdr3_discoveries/tree/master/AI/CPED_CONFIG_FLAGS

## SET_PED_DEFENSIVE_AREA_DIRECTION
`0x413C6C763A4AFFAD` | `void SET_PED_DEFENSIVE_AREA_DIRECTION(Ped ped, float p1, float p2, float p3, BOOL p4)` | build 1207

## SET_PED_DEFENSIVE_AREA_VOLUME
`0xFC3DB99C8144CD81` | `void SET_PED_DEFENSIVE_AREA_VOLUME(Ped ped, Volume volume, BOOL p2, BOOL p3, BOOL p4)` | build 1207

## SET_PED_DESIRED_HEADING
`0xAA5A7ECE2AA8FE70` | `void SET_PED_DESIRED_HEADING(Ped ped, float heading)` | build 1207

## SET_PED_FIRING_PATTERN
`0x9AC577F5A12AD8A9` | `void SET_PED_FIRING_PATTERN(Ped ped, Hash patternHash)` | build 1207
Used in various R* MP & SP Scripts

## SET_PED_FLEE_ATTRIBUTES
`0x70A2D1137C8ED7C9` | `void SET_PED_FLEE_ATTRIBUTES(Ped ped, int attributeFlags, BOOL enable)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/AI/FLEE_ATTRIBUTES

attributeFlags:
enum eFleeAttribute
{
	FA_FORCE_EXIT_VEHICLE = (1 << 16),
	FA_DISABLE_MOUNT_USAGE = (1 << 20),
	FA_DISABLE_ENTER_VEHICLES = (1 << 22),
};

## SET_PED_GESTURE_GROUP
`0xDDF803377F94AAA8` | `void SET_PED_GESTURE_GROUP(Ped ped, char* gesture, int p2)` | build 1207

## SET_PED_GRAVITY
`0x9FF447B6B6AD960A` | `void SET_PED_GRAVITY(Ped ped, BOOL toggle)` | build 1207

## SET_PED_GROUP_MEMBER_PASSENGER_INDEX
`0x0BDDB8D9EC6BCF3C` | `void SET_PED_GROUP_MEMBER_PASSENGER_INDEX(Ped ped, int index)` | build 1207

## SET_PED_HEARING_RANGE
`0x33A8F7F7D5F7F33C` | `void SET_PED_HEARING_RANGE(Ped ped, float value)` | build 1207

## SET_PED_HIGHLY_PERCEPTIVE
`0x52D59AB61DDC05DD` | `void SET_PED_HIGHLY_PERCEPTIVE(Ped ped, BOOL toggle)` | build 1207

## SET_PED_ID_RANGE
`0xF107E836A70DCE05` | `void SET_PED_ID_RANGE(Ped ped, float value)` | build 1207

## SET_PED_INJURED_ON_GROUND_BEHAVIOUR
`0xEC4B4B3B9908052A` | `void SET_PED_INJURED_ON_GROUND_BEHAVIOUR(Ped ped, float unk)` | build 1311

## SET_PED_INTO_VEHICLE
`0xF75B0D629E1C063D` | `void SET_PED_INTO_VEHICLE(Ped ped, Vehicle vehicle, int seatIndex)` | build 1207
Ped: The ped to warp.
vehicle: The vehicle to warp the ped into.
seatIndex: see CREATE_PED_INSIDE_VEHICLE

## SET_PED_KEEP_TASK
`0x971D38760FBC02EF` | `void SET_PED_KEEP_TASK(Ped ped, BOOL toggle)` | build 1207

## SET_PED_LASSO_HOGTIE_FLAG
`0xAE6004120C18DF97` | `void SET_PED_LASSO_HOGTIE_FLAG(Ped ped, int flagId, BOOL value)` | build 1207

## SET_PED_LEG_IK_MODE
`0xC396F5B86FF9FEBD` | `void SET_PED_LEG_IK_MODE(Ped ped, int mode)` | build 1207

## SET_PED_LOD_MULTIPLIER
`0xDC2C5C242AAC342B` | `void SET_PED_LOD_MULTIPLIER(Ped ped, float multiplier)` | build 1207

## SET_PED_MAX_HEALTH
`0xF5F6378C4F3419D3` | `void SET_PED_MAX_HEALTH(Ped ped, int value)` | build 1207
Sets the maximum health of a ped.

## SET_PED_MAX_MOVE_BLEND_RATIO
`0x433083750C5E064A` | `void SET_PED_MAX_MOVE_BLEND_RATIO(Ped ped, float value)` | build 1207

## SET_PED_MAX_TIME_IN_WATER
`0x43C851690662113D` | `void SET_PED_MAX_TIME_IN_WATER(Ped ped, float value)` | build 1207

## SET_PED_MAX_TIME_UNDERWATER
`0x6BA428C528D9E522` | `void SET_PED_MAX_TIME_UNDERWATER(Ped ped, float value)` | build 1207

## SET_PED_MIN_MOVE_BLEND_RATIO
`0x01A898D26E2333DD` | `void SET_PED_MIN_MOVE_BLEND_RATIO(Ped ped, float value)` | build 1207

## SET_PED_MODEL_IS_SUPPRESSED
`0xE163A4BCE4DE6F11` | `void SET_PED_MODEL_IS_SUPPRESSED(Hash model, BOOL toggle)` | build 1207

## SET_PED_MONEY
`0xA9C8960E8684C1B5` | `void SET_PED_MONEY(Ped ped, int amount)` | build 1207

## SET_PED_MOVE_ANIMS_BLEND_OUT
`0x9E8C908F41584ECD` | `void SET_PED_MOVE_ANIMS_BLEND_OUT(Ped ped)` | build 1207

## SET_PED_MOVE_RATE_OVERRIDE
`0x085BF80FA50A39D1` | `void SET_PED_MOVE_RATE_OVERRIDE(Ped ped, float value)` | build 1207
Min: 0.0f
Max: 1.15f

## SET_PED_NAME_DEBUG
`0x98EFA132A4117BE1` | `void SET_PED_NAME_DEBUG(Ped ped, char* name)` | build 1207
nullsub, doesn't do anything

## SET_PED_NON_CREATION_AREA
`0xEE01041D559983EA` | `void SET_PED_NON_CREATION_AREA(float x1, float y1, float z1, float x2, float y2, float z2)` | build 1207
The distance between these points, is the diagonal of a box (remember it's 3D).

## SET_PED_ONTO_MOUNT
`0x028F76B6E78246EB` | `void SET_PED_ONTO_MOUNT(Ped ped, Ped mount, int seatIndex, BOOL p3)` | build 1207

## SET_PED_OWNS_ANIMAL
`0x931B241409216C1F` | `void SET_PED_OWNS_ANIMAL(Ped ped, Ped animal, BOOL p2)` | build 1207
enables horse items wheel

## SET_PED_PANIC_EXIT_SCENARIO
`0xFE07FF6495D52E2A` | `BOOL SET_PED_PANIC_EXIT_SCENARIO(Ped ped, float x, float y, float z)` | build 1207

## SET_PED_RAGDOLL_FORCE_FALL
`0x01F6594B923B9251` | `void SET_PED_RAGDOLL_FORCE_FALL(Ped ped)` | build 1207

## SET_PED_RAGDOLL_ON_COLLISION
`0xF0A4F1BBF4FA7497` | `void SET_PED_RAGDOLL_ON_COLLISION(Ped ped, BOOL toggle, BOOL p2)` | build 1207
Causes Ped to ragdoll on collision with any object (e.g Running into trashcan). If applied to player you will sometimes trip on the sidewalk.

## SET_PED_RANDOM_COMPONENT_VARIATION
`0xC8A9481A01E63C28` | `void SET_PED_RANDOM_COMPONENT_VARIATION(Ped ped, int p1)` | build 1207

## SET_PED_RELATIONSHIP_GROUP_DEFAULT_HASH
`0xADB3F206518799E8` | `void SET_PED_RELATIONSHIP_GROUP_DEFAULT_HASH(Ped ped, Hash hash)` | build 1207

## SET_PED_RELATIONSHIP_GROUP_HASH
`0xC80A74AC829DDD92` | `void SET_PED_RELATIONSHIP_GROUP_HASH(Ped ped, Hash relationshipGroup)` | build 1207

## SET_PED_RESET_FLAG
`0xC1E8A365BF3B29F2` | `void SET_PED_RESET_FLAG(Ped ped, int flagId, BOOL doReset)` | build 1207
Needs to be called every frame

flagid:https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ePedScriptResetFlags
https://github.com/femga/rdr3_discoveries/tree/master/AI/CPED_RESET_FLAGS

## SET_PED_SEEING_RANGE
`0xF29CF591C4BF6CEE` | `void SET_PED_SEEING_RANGE(Ped ped, float value)` | build 1207

## SET_PED_SHOOT_RATE
`0x614DA022990752DC` | `void SET_PED_SHOOT_RATE(Ped ped, int shootRate)` | build 1207
Params: shootRate = 0 - 1000

## SET_PED_SHOULD_PLAY_COMBAT_SCENARIO_EXIT
`0x802092B07E3B1EEA` | `BOOL SET_PED_SHOULD_PLAY_COMBAT_SCENARIO_EXIT(Ped ped, float x, float y, float z, int lookIntensity)` | build 1207
lookIntensity: see SET_PED_SHOULD_PLAY_FLEE_SCENARIO_EXIT

## SET_PED_SHOULD_PLAY_DIRECTED_NORMAL_SCENARIO_EXIT
`0xEC6935EBE0847B90` | `BOOL SET_PED_SHOULD_PLAY_DIRECTED_NORMAL_SCENARIO_EXIT(Ped ped, float x, float y, float z)` | build 1207
Old name: _SET_PED_SHOULD_PLAY_DIRECTED_SCENARIO_EXIT

## SET_PED_SHOULD_PLAY_EMOTIONAL_SCENARIO_EXIT
`0x62FDAD5E01D2DD47` | `BOOL SET_PED_SHOULD_PLAY_EMOTIONAL_SCENARIO_EXIT(Ped ped, float x, float y, float z, int lookIntensity, BOOL p5)` | build 1207
lookIntensity: see SET_PED_SHOULD_PLAY_FLEE_SCENARIO_EXIT

## SET_PED_SHOULD_PLAY_FLEE_SCENARIO_EXIT
`0xEEED8FAFEC331A70` | `BOOL SET_PED_SHOULD_PLAY_FLEE_SCENARIO_EXIT(Ped ped, float x, float y, float z, int lookIntensity)` | build 1207
lookIntensity:
0 - REACT_LOOK_NONE
1 - REACT_LOOK_LOW
2 - REACT_LOOK_MEDIUM
3 - REACT_LOOK_HIGH

## SET_PED_SHOULD_PLAY_IMMEDIATE_SCENARIO_EXIT
`0xF1C03A5352243A30` | `void SET_PED_SHOULD_PLAY_IMMEDIATE_SCENARIO_EXIT(Ped ped)` | build 1207

## SET_PED_SHOULD_PLAY_NORMAL_SCENARIO_EXIT
`0xA3A9299C4F2ADB98` | `void SET_PED_SHOULD_PLAY_NORMAL_SCENARIO_EXIT(Ped ped)` | build 1207

## SET_PED_SHOULD_PLAY_QUICK_SCENARIO_EXIT
`0x463803429297117C` | `BOOL SET_PED_SHOULD_PLAY_QUICK_SCENARIO_EXIT(Ped ped, float x, float y, float z, int lookIntensity, BOOL p5)` | build 1207
lookIntensity: see SET_PED_SHOULD_PLAY_FLEE_SCENARIO_EXIT

## SET_PED_SPHERE_DEFENSIVE_AREA
`0x9D3151A373974804` | `void SET_PED_SPHERE_DEFENSIVE_AREA(Ped ped, float x, float y, float z, float radius, BOOL p5, BOOL p6, BOOL p7)` | build 1207

## SET_PED_STEALTH_MOVEMENT
`0x88CBB5CEB96B7BD2` | `void SET_PED_STEALTH_MOVEMENT(Ped ped, BOOL toggle, Any p2, Any p3)` | build 1207
Not implemented.

## SET_PED_SWEAT
`0x27B0405F59637D1F` | `void SET_PED_SWEAT(Ped ped, float sweat)` | build 1207

## SET_PED_TARGET_LOSS_RESPONSE
`0x0703B9079823DA4A` | `void SET_PED_TARGET_LOSS_RESPONSE(Ped ped, int responseType)` | build 1207
TLR_ExitTask = 0,
TLR_NeverLoseTarget,
TLR_SearchForTarget

## SET_PED_TO_INFORM_RESPECTED_FRIENDS
`0x112942C6E708F70B` | `void SET_PED_TO_INFORM_RESPECTED_FRIENDS(Ped ped, float radius, int maxFriends)` | build 1207

## SET_PED_TO_PLAYER_WEAPON_DAMAGE_MODIFIER
`0xD77AE48611B7B10A` | `void SET_PED_TO_PLAYER_WEAPON_DAMAGE_MODIFIER(Ped ped, float damageModifier)` | build 1207
Old name: _SET_PED_DAMAGE_MODIFIER

## SET_PED_TO_RAGDOLL
`0xAE99FB955581844A` | `BOOL SET_PED_TO_RAGDOLL(Ped ped, int timeMin, int timeMax, int ragdollType, BOOL abortIfInjured, BOOL abortIfDead, char* nmTaskMessageParameterName)` | build 1207
nmTaskMessageParameterName: See physicstasks.ymt. Search for DraggedByCart or 0xD00820D7 (Used in R* SP Script marston8)

## SET_PED_TO_RAGDOLL_WITH_FALL
`0xD76632D99E4966C8` | `BOOL SET_PED_TO_RAGDOLL_WITH_FALL(Ped ped, int timeMin, int timeMax, int ragdollType, float falldirX, float falldirY, float falldirZ, float p7, float p8, float p9, float p10, float p11, float p12, float p13)` | build 1207

## SET_PED_USING_ACTION_MODE
`0xD75ACCF5E0FB5367` | `void SET_PED_USING_ACTION_MODE(Ped ped, BOOL bActionModeEnabled, int p2, char* action)` | build 1207

## SET_PED_VISUAL_FIELD_CENTER_ANGLE
`0x3B6405E8AB34A907` | `void SET_PED_VISUAL_FIELD_CENTER_ANGLE(Ped ped, float angle)` | build 1207

## SET_PED_VISUAL_FIELD_MAX_ANGLE
`0x70793BDCA1E854D4` | `void SET_PED_VISUAL_FIELD_MAX_ANGLE(Ped ped, float value)` | build 1207

## SET_PED_VISUAL_FIELD_MIN_ANGLE
`0x2DB492222FB21E26` | `void SET_PED_VISUAL_FIELD_MIN_ANGLE(Ped ped, float value)` | build 1207

## SET_PED_VISUAL_FIELD_PERIPHERAL_RANGE
`0x9C74B0BC831B753A` | `void SET_PED_VISUAL_FIELD_PERIPHERAL_RANGE(Ped ped, float range)` | build 1207

## SET_PED_WETNESS_ENABLED_THIS_FRAME
`0xB5485E4907B53019` | `void SET_PED_WETNESS_ENABLED_THIS_FRAME(Ped ped)` | build 1207
combined with PED::SET_PED_WETNESS_HEIGHT(), this native makes the ped drenched in water up to the height specified in the other function

## SET_PED_WETNESS_HEIGHT
`0x44CB6447D2571AA0` | `void SET_PED_WETNESS_HEIGHT(Ped ped, float height)` | build 1207
It adds the wetness level to the player clothing/outfit. As if player just got out from water surface.

## SET_POP_CONTROL_SPHERE_THIS_FRAME
`0xD8C3BE3EE94CAF2D` | `void SET_POP_CONTROL_SPHERE_THIS_FRAME(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## SET_RAGDOLL_BLOCKING_FLAGS
`0x26695EC767728D84` | `void SET_RAGDOLL_BLOCKING_FLAGS(Ped ped, int flags)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/AI/RAGDOLL_BLOCKING_FLAGS

flags:
enum eRagdollBlockingFlags
{
	RBF_BULLET_IMPACT = (1 << 0),
	RBF_VEHICLE_IMPACT = (1 << 1),
	RBF_FIRE = (1 << 2),
	RBF_ELECTROCUTION = (1 << 3),
	RBF_PLAYER_IMPACT = (1 << 4),
	RBF_EXPLOSION = (1 << 5),
	RBF_IMPACT_OBJECT = (1 << 6),
	RBF_MELEE = (1 << 7),
	RBF_RUBBER_BULLET = (1 << 8),
	RBF_FALLING = (1 << 9),
	RBF_WATER_JET = (1 << 10),
	RBF_DROWNING = (1 << 11),
	RBF_0x9F52E2C4 = (1 << 12),
	RBF_PLAYER_BUMP = (1 << 13),
	RBF_PLAYER_RAGDOLL_BUMP = (1 << 14),
	RBF_PED_RAGDOLL_BUMP = (1 << 15),
	RBF_VEHICLE_GRAB = (1 << 16),
	RBF_SMOKE_GRENADE = (1 << 17),
	RBF_HORSE_BUMP = (1 << 18),
	RBF_ACTIVATE_ON_COLLISION = (1 << 19)
};

## SET_RELATIONSHIP_BETWEEN_GROUPS
`0xBF25EB89375A37AD` | `void SET_RELATIONSHIP_BETWEEN_GROUPS(int relationship, Hash group1, Hash group2)` | build 1207
enum eRelationType
{
	ACQUAINTANCE_TYPE_PED_NONE = 0,
	ACQUAINTANCE_TYPE_PED_RESPECT = 1,
	ACQUAINTANCE_TYPE_PED_LIKE = 2,
	ACQUAINTANCE_TYPE_PED_IGNORE = 3,
	ACQUAINTANCE_TYPE_PED_DISLIKE = 4,
	ACQUAINTANCE_TYPE_PED_WANTED = 5,
	ACQUAINTANCE_TYPE_PED_HATE = 6,
	ACQUAINTANCE_TYPE_PED_DEAD = 7,
	ACQUAINTANCE_TYPE_PED_DISGUISE = 8,
	ACQUAINTANCE_TYPE_PED_THIEF = 9,
}; 

 https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eRelationType

## SET_SCENARIO_PED_DENSITY_MULTIPLIER_THIS_FRAME
`0x7A556143A1C03898` | `void SET_SCENARIO_PED_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## SPAWNPOINTS_CANCEL_SEARCH
`0xFEE4A5459472A9F8` | `void SPAWNPOINTS_CANCEL_SEARCH()` | build 1207

## SPAWNPOINTS_GET_NUM_SEARCH_RESULTS
`0xA635C11B8C44AFC2` | `int SPAWNPOINTS_GET_NUM_SEARCH_RESULTS()` | build 1207

## SPAWNPOINTS_GET_SEARCH_RESULT
`0x280C7E3AC7F56E90` | `void SPAWNPOINTS_GET_SEARCH_RESULT(int randomInt, float* x, Any* y, float* z)` | build 1207

## SPAWNPOINTS_GET_SEARCH_RESULT_FLAGS
`0xB782F8238512BAD5` | `void SPAWNPOINTS_GET_SEARCH_RESULT_FLAGS(Any p0, Any* p1)` | build 1207

## SPAWNPOINTS_IS_SEARCH_ACTIVE
`0x3C67506996001F5E` | `BOOL SPAWNPOINTS_IS_SEARCH_ACTIVE()` | build 1207

## SPAWNPOINTS_IS_SEARCH_COMPLETE
`0xA586FBEB32A53DBB` | `BOOL SPAWNPOINTS_IS_SEARCH_COMPLETE()` | build 1207

## SPAWNPOINTS_IS_SEARCH_FAILED
`0xF445DE8DA80A1792` | `BOOL SPAWNPOINTS_IS_SEARCH_FAILED()` | build 1207

## SPAWNPOINTS_START_SEARCH
`0x2DF9038C90AD5264` | `void SPAWNPOINTS_START_SEARCH(float x, float y, float z, float width, float p4, int spawnpointsFlag, float p6, int duration, float p8)` | build 1207
Params: p4 = 35.f, duration = 5000 in R* Scripts

## SPAWNPOINTS_START_SEARCH_IN_ANGLED_AREA
`0xB2AFF10216DEFA2F` | `void SPAWNPOINTS_START_SEARCH_IN_ANGLED_AREA(float x1, float y1, float z1, float x2, float y2, float z2, float width, int spawnpointsFlag, float p8, int duration, float p10)` | build 1207
Searching area between coords 1 and 2

## SPECIAL_FUNCTION_DO_NOT_USE
`0xF9ACF4A08098EA25` | `void SPECIAL_FUNCTION_DO_NOT_USE(Ped ped, BOOL p1)` | build 1207

## TIME_SINCE_PED_LAST_SHOT
`0x285D36C5C72B0569` | `float TIME_SINCE_PED_LAST_SHOT(Ped ped)` | build 1207
Returns time since the specified ped last shot, in seconds. (fPlayerJustShotTime)

## TOGGLE_SCENARIO_PED_COWER_IN_PLACE
`0x9A77DFD295E29B09` | `void TOGGLE_SCENARIO_PED_COWER_IN_PLACE(Ped ped, BOOL toggle)` | build 1207
If toggle is true, when the ped is using a scenario he will stop it and become scared
If toggle is false, the ped will not be scared anymore and continue his scenario

Old name: _SET_PED_SCARED_WHEN_USING_SCENARIO

## WAS_PED_SKELETON_UPDATED
`0x11B499C1E0FF8559` | `BOOL WAS_PED_SKELETON_UPDATED(Ped ped)` | build 1207
Despite this function's name, it simply returns whether the specified handle is a Ped.

## _0x00B380FF2DF6AB7A
`0x00B380FF2DF6AB7A` | `void _0x00B380FF2DF6AB7A(Any p0, Any p1)` | build 1207

## _0x024EC9B649111915
`0x024EC9B649111915` | `void _0x024EC9B649111915(Ped ped, BOOL p1)` | build 1207

## _0x02E741E19E39628C
`0x02E741E19E39628C` | `void _0x02E741E19E39628C(Ped ped, float p1)` | build 1207
_SET_PLAYER_SN* - _SET_PLAYER_STAMINA*

## _0x0455546F23FF08E4
`0x0455546F23FF08E4` | `BOOL _0x0455546F23FF08E4(int groupId)` | build 1207
_DOES_GROUP_* - _DOES_N*

## _0x06A10B4D7F50B0C3
`0x06A10B4D7F50B0C3` | `BOOL _0x06A10B4D7F50B0C3(Ped ped)` | build 1207
_GET_PED_D*

## _0x070A3841406C43D5
`0x070A3841406C43D5` | `void _0x070A3841406C43D5(Any p0, Any p1)` | build 1207

## _0x07EA5B053FA60AC7
`0x07EA5B053FA60AC7` | `void _0x07EA5B053FA60AC7(int groupId, BOOL p1)` | build 1207

## _0x09171A6F8FDE5DC1
`0x09171A6F8FDE5DC1` | `void _0x09171A6F8FDE5DC1(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x095C2277FED731DB
`0x095C2277FED731DB` | `Any _0x095C2277FED731DB(Any p0)` | build 1207

## _0x09D7AFD3716DA8E1
`0x09D7AFD3716DA8E1` | `BOOL _0x09D7AFD3716DA8E1(Ped ped, int p1)` | build 1207

## _0x0A4618FFD517E24D
`0x0A4618FFD517E24D` | `void _0x0A4618FFD517E24D(Any p0, Any p1)` | build 1207

## _0x0ADA3EC589E1736E
`0x0ADA3EC589E1736E` | `void _0x0ADA3EC589E1736E()` | build 1207

## _0x0B787A37EEDD226F
`0x0B787A37EEDD226F` | `void _0x0B787A37EEDD226F(Any p0, Any p1)` | build 1311

## _0x0D3B1568917EBDA0
`0x0D3B1568917EBDA0` | `BOOL _0x0D3B1568917EBDA0(Ped ped, int p1)` | build 1207
_IS_PED_M*

## _0x0D497AA69059FE40
`0x0D497AA69059FE40` | `void _0x0D497AA69059FE40(Any p0, Any p1)` | build 1207

## _0x0EEF7A81C17679DB
`0x0EEF7A81C17679DB` | `BOOL _0x0EEF7A81C17679DB(Ped ped)` | build 1207
_IS_PED_L* - _IS_PED_M*

## _0x0F967019CC853BCC
`0x0F967019CC853BCC` | `void _0x0F967019CC853BCC(Any p0, Any p1)` | build 1207

## _0x0FB1BA7FF73B41E1
`0x0FB1BA7FF73B41E1` | `void _0x0FB1BA7FF73B41E1(Any p0, Any p1, Any p2)` | build 1207

## _0x0FFDF937E5C11382
`0x0FFDF937E5C11382` | `void _0x0FFDF937E5C11382(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0x101B45C5F56D970F
`0x101B45C5F56D970F` | `BOOL _0x101B45C5F56D970F(Any* p0, Ped ped, int damageCleanliness, int p3)` | build 1207

## _0x10F96086123B939F
`0x10F96086123B939F` | `void _0x10F96086123B939F(Ped legendaryPed, Ped preyPed, float p2)` | build 1207
NB_CUSTOM_CLIENT_ON_CREATE_COMPLETE - set legendary to not avoid prey

## _0x1148F706CF4EBDDA
`0x1148F706CF4EBDDA` | `BOOL _0x1148F706CF4EBDDA(Ped ped, Hash p1, int p2)` | build 1207
_CAN_PED_SEE* - _CAN_PED_USE_(SCENARIO_HASH?)*

## _0x1298B3D8E4C2409F
`0x1298B3D8E4C2409F` | `void _0x1298B3D8E4C2409F(Any p0)` | build 1207

## _0x12EB4E31F092C9B3
`0x12EB4E31F092C9B3` | `BOOL _0x12EB4E31F092C9B3(Ped ped)` | build 1207
_GET_IS_PED_(BLEEDING_OUT?)*

## _0x12F2D161BF4031FC
`0x12F2D161BF4031FC` | `void _0x12F2D161BF4031FC(Ped ped, float p1)` | build 1207
_SET_A* - _SET_B*

## _0x134775B093AD5C38
`0x134775B093AD5C38` | `float _0x134775B093AD5C38(Ped ped)` | build 1207
_GET_PED_M*

## _0x154B7E841AC7412F
`0x154B7E841AC7412F` | `void _0x154B7E841AC7412F(int groupId, BOOL p1)` | build 1207
_SET_SCENARIO_PED_* - _SET_SPAWNER_*

## _0x15F4732C357B1D6D
`0x15F4732C357B1D6D` | `void _0x15F4732C357B1D6D(Any p0, Any p1, Any p2)` | build 1207

## _0x16802C32B2FCA06B
`0x16802C32B2FCA06B` | `void _0x16802C32B2FCA06B(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x16F798A05BB9E3B5
`0x16F798A05BB9E3B5` | `void _0x16F798A05BB9E3B5(Ped ped)` | build 1207
_PED_COWER_M*

## _0x1D23D3F70606D788
`0x1D23D3F70606D788` | `void _0x1D23D3F70606D788(Any p0, Any p1)` | build 1207

## _0x1D4636C90BBEFACB
`0x1D4636C90BBEFACB` | `void _0x1D4636C90BBEFACB(Ped ped, int p1)` | build 1207
_SET_PED_CA* - _SET_PED_CO*

## _0x1F44B7E283C09EDE
`0x1F44B7E283C09EDE` | `void _0x1F44B7E283C09EDE(Ped ped, float p1, int p2)` | build 1207
Only used in SP R* Scripts
Params: p2 = same as p2 of 0x3C529A827998F9B3
_SET_PED_TA* - _SET_PED_TO_*

## _0x2371C39D4F91C288
`0x2371C39D4F91C288` | `void _0x2371C39D4F91C288(Ped ped)` | build 1207

## _0x23BDE06596A22CEC
`0x23BDE06596A22CEC` | `void _0x23BDE06596A22CEC(Ped ped, int p1, float p2, Any p3)` | build 1207

## _0x242EDF85D4E87B65
`0x242EDF85D4E87B65` | `Any _0x242EDF85D4E87B65(Any p0)` | build 1207

## _0x256EDD55C6BE1482
`0x256EDD55C6BE1482` | `BOOL _0x256EDD55C6BE1482(Ped ped)` | build 1207
_IS_PED_FL* - _IS_PED_FU*

## _0x273915CE30780986
`0x273915CE30780986` | `Any _0x273915CE30780986(Any p0, Any p1)` | build 1207

## _0x27E8A84C12B0B7D1
`0x27E8A84C12B0B7D1` | `Any _0x27E8A84C12B0B7D1(Any p0, Any p1, Any p2)` | build 1207

## _0x28508173C6A7CC18
`0x28508173C6A7CC18` | `void _0x28508173C6A7CC18(Any p0)` | build 1311

## _0x290B2E6CCDE532E1
`0x290B2E6CCDE532E1` | `BOOL _0x290B2E6CCDE532E1(Ped ped)` | build 1207
_IS_PED_L* - _IS_PED_M*

## _0x29924EB8EE9DB926
`0x29924EB8EE9DB926` | `void _0x29924EB8EE9DB926(Ped ped, float p1)` | build 1207
_SET_PED_K* or _SET_PED_L*

## _0x29F3539189D3E277
`0x29F3539189D3E277` | `void _0x29F3539189D3E277(Any p0, Any p1)` | build 1207

## _0x2D976DBDC731DF80
`0x2D976DBDC731DF80` | `void _0x2D976DBDC731DF80(Ped ped)` | build 1207

## _0x2DC0E8DCBD3546E9
`0x2DC0E8DCBD3546E9` | `BOOL _0x2DC0E8DCBD3546E9(Ped ped)` | build 1207
_IS_PED_D*

## _0x2DD4E0E26DFAD97D
`0x2DD4E0E26DFAD97D` | `BOOL _0x2DD4E0E26DFAD97D(Ped ped1, Ped ped2, float p2)` | build 1207
_IS_PED_M* - _IS_PED_O*

## _0x2E5B5D1F1453E08E
`0x2E5B5D1F1453E08E` | `void _0x2E5B5D1F1453E08E(Ped ped, int p1)` | build 1207

## _0x2FA568BFA725F8D6
`0x2FA568BFA725F8D6` | `void _0x2FA568BFA725F8D6(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x31B2E7F2E3C58B89
`0x31B2E7F2E3C58B89` | `int _0x31B2E7F2E3C58B89(Hash componentHash, Hash p1, int metapedType, BOOL isMP)` | build 1207
_GET_SHOP_ITEM_NUM_*? returns a number of ? p1 seems to be always joaat("base")

## _0x32417CB860A3BDC4
`0x32417CB860A3BDC4` | `Any _0x32417CB860A3BDC4(Any p0, Any p1)` | build 1207

## _0x326F7951EF0D7F75
`0x326F7951EF0D7F75` | `Any _0x326F7951EF0D7F75(Ped ped, Hash eventType)` | build 1207
Only used in R* SP Script short_update
_GET_TARGET_* - _GET_TRACKED*

## _0x329772C47DBB2FBC
`0x329772C47DBB2FBC` | `void _0x329772C47DBB2FBC(Ped ped)` | build 1207
_SET_PED_P* - _SET_PED_R*

## _0x32CCAD8A981B53D3
`0x32CCAD8A981B53D3` | `void _0x32CCAD8A981B53D3(Ped ped)` | build 1207
_STOP_(?)*

## _0x32CEDA9A0AB4CEF7
`0x32CEDA9A0AB4CEF7` | `void _0x32CEDA9A0AB4CEF7(Ped ped, Hash p1, BOOL p2)` | build 1207

## _0x34B5CEAC180A5D6E
`0x34B5CEAC180A5D6E` | `void _0x34B5CEAC180A5D6E(Ped ped, Hash p1, BOOL p2)` | build 1207

## _0x34C11114887150FD
`0x34C11114887150FD` | `void _0x34C11114887150FD(Any p0, Any p1)` | build 1207

## _0x34EDDD59364AD74A
`0x34EDDD59364AD74A` | `void _0x34EDDD59364AD74A(Ped ped, Any* p1)` | build 1207

## _0x354CA4DDDEEC397A
`0x354CA4DDDEEC397A` | `int _0x354CA4DDDEEC397A(Ped ped)` | build 1207

## _0x370A973252741AC4
`0x370A973252741AC4` | `void _0x370A973252741AC4(Ped ped, BOOL p1)` | build 1207
_RESET_PED_*

## _0x3A5697B80FED5EBE
`0x3A5697B80FED5EBE` | `void _0x3A5697B80FED5EBE(Ped ped, float p1, float p2, float p3, float p4)` | build 1207
_SET_PED_MO*

## _0x3ACCE14DFA6BA8C2
`0x3ACCE14DFA6BA8C2` | `int _0x3ACCE14DFA6BA8C2(Ped ped, int p1, float x, float y, float z, float p5, ItemSet itemset)` | build 1207
Used in R* Script net_fetch (NET_FETCH_UPDATE_RECIPIENT_PROP_ILO_IN_COMBAT) and various SP Scripts
Params: p1 = 4/5/6, p5 = 40.f/100.f, coords = Player ped
Perhaps returns some distance (Clearing that the local player is able to use ILO while in combat because they are near the recipient but also near hated peds)
_GET_NUM_M* - _GET_PEDS_J*

## _0x3AEC4A410ECAF30D
`0x3AEC4A410ECAF30D` | `BOOL _0x3AEC4A410ECAF30D(Ped ped)` | build 1207
_IS_PED_R*

## _0x3C529A827998F9B3
`0x3C529A827998F9B3` | `void _0x3C529A827998F9B3(Ped ped, int p1, int p2)` | build 1207
_SET_PED_TA* - _SET_PED_TO_*

## _0x3EFED081B4834BA1
`0x3EFED081B4834BA1` | `void _0x3EFED081B4834BA1(Any p0)` | build 1232

## _0x3FCBB5FCFD968698
`0x3FCBB5FCFD968698` | `int _0x3FCBB5FCFD968698(Hash drawable, Hash albedo, Hash normal, Hash material, Any p4)` | build 1207
Used for script function PROCESS_PLAYER_HAT_EVENT
Returns requestId to be used with 0x13E7320C762F0477

## _0x3FDBB99EFD8CE4AF
`0x3FDBB99EFD8CE4AF` | `void _0x3FDBB99EFD8CE4AF(Any p0, Any p1, Any p2)` | build 1207

## _0x3FDCC1F8C17E303E
`0x3FDCC1F8C17E303E` | `void _0x3FDCC1F8C17E303E(Ped ped, int p1, float p2)` | build 1207
Changes health bar around heart core icon
INITIALISE_NEW_ROLE - Applying Super Jump buffs: p1 = 10, p2 = 0.0f
INITIALISE_NEW_ROLE - Clearing up Super Jump buffs: p1 = 10, p2 = 1.0f
_SET_D*

## _0x405180B14DA5A935
`0x405180B14DA5A935` | `void _0x405180B14DA5A935(Ped ped, BOOL p1)` | build 1207
_SET_PED_A*

## _0x40C3524D4ED83554
`0x40C3524D4ED83554` | `void _0x40C3524D4ED83554(int groupId, BOOL p1)` | build 1207
_SET_SCENARIO_PED_* - _SET_SPAWNER_*

## _0x40C9155AF8BC13F3
`0x40C9155AF8BC13F3` | `BOOL _0x40C9155AF8BC13F3(Ped ped)` | build 1207
_IS_PED_RE*

## _0x413697EC260AABBF
`0x413697EC260AABBF` | `void _0x413697EC260AABBF(Any p0, Any p1, Any p2)` | build 1207

## _0x41C23A8E6B344867
`0x41C23A8E6B344867` | `void _0x41C23A8E6B344867(Ped ped, const char* p1)` | build 1207
_SET_PED_IN*

## _0x45FEA6D5539BD474
`0x45FEA6D5539BD474` | `void _0x45FEA6D5539BD474(Ped ped, const char* p1)` | build 1207
_SET_PED_IN*

## _0x49DADFC4CD808B0A
`0x49DADFC4CD808B0A` | `void _0x49DADFC4CD808B0A(Any p0, Any p1, Any p2)` | build 1207

## _0x4B19F171450E0D4F
`0x4B19F171450E0D4F` | `Ped _0x4B19F171450E0D4F(Ped ped)` | build 1207

## _0x4E68C7EF706DF35D
`0x4E68C7EF706DF35D` | `void _0x4E68C7EF706DF35D(Ped ped, float x, float y, float z, float p4, Hash relationshipGroup)` | build 1207

## _0x4EC4EA2F72B36358
`0x4EC4EA2F72B36358` | `void _0x4EC4EA2F72B36358(Ped ped, BOOL p1)` | build 1207
_SET_PED_A*

## _0x4F27603E44A8E4C0
`0x4F27603E44A8E4C0` | `void _0x4F27603E44A8E4C0(Ped ped, int p1, BOOL p2)` | build 1207

## _0x4F63433CE3C08230
`0x4F63433CE3C08230` | `void _0x4F63433CE3C08230(Ped ped, BOOL p1)` | build 1311
Only used in R* Script shop_harriet
_SET_PED_F*

## _0x5203038FF8BAE577
`0x5203038FF8BAE577` | `BOOL _0x5203038FF8BAE577(Ped ped, int p1, int p2)` | build 1207

## _0x52250B92EA70BE3D
`0x52250B92EA70BE3D` | `Any _0x52250B92EA70BE3D(Any p0)` | build 1207

## _0x52A24D8A1DA89658
`0x52A24D8A1DA89658` | `void _0x52A24D8A1DA89658(Ped ped, int p1, BOOL p2)` | build 1207

## _0x53BA7D96B9A421D9
`0x53BA7D96B9A421D9` | `void _0x53BA7D96B9A421D9(Any p0, Any p1)` | build 1207

## _0x54D3CD482742C482
`0x54D3CD482742C482` | `void _0x54D3CD482742C482(Ped animal, float p2)` | build 1355

## _0x550CB89DD7F4FA3D
`0x550CB89DD7F4FA3D` | `BOOL _0x550CB89DD7F4FA3D(Ped ped1, Ped ped2)` | build 1207
_HAS_PED_*

## _0x55546004A244302A
`0x55546004A244302A` | `void _0x55546004A244302A(Any p0, Any p1)` | build 1207

## _0x56076667E7C2DCD6
`0x56076667E7C2DCD6` | `void _0x56076667E7C2DCD6(Any p0, Any p1)` | build 1311

## _0x56E4BAD93D33453C
`0x56E4BAD93D33453C` | `Any _0x56E4BAD93D33453C(Any p0, Any p1)` | build 1207

## _0x577C60BA06D0EA64
`0x577C60BA06D0EA64` | `BOOL _0x577C60BA06D0EA64(Ped ped)` | build 1207
_IS_PED_C* - _IS_PED_D*

## _0x57F35552E771BE9D
`0x57F35552E771BE9D` | `void _0x57F35552E771BE9D(Ped ped, int p1)` | build 1207
_SET_PED_M*

## _0x5A1A929C8B729B4A
`0x5A1A929C8B729B4A` | `void _0x5A1A929C8B729B4A(Ped ped)` | build 1207
_C*

## _0x5AF24CA9C974E51A
`0x5AF24CA9C974E51A` | `void _0x5AF24CA9C974E51A(Ped ped1, Ped ped2)` | build 1207
_SET_C*

## _0x5B73975B4F12F7F3
`0x5B73975B4F12F7F3` | `void _0x5B73975B4F12F7F3(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x5BB04BC74A474B47
`0x5BB04BC74A474B47` | `void _0x5BB04BC74A474B47(Any p0, Any p1)` | build 1207

## _0x5BF0B9D9A8E227A0
`0x5BF0B9D9A8E227A0` | `BOOL _0x5BF0B9D9A8E227A0(Ped ped)` | build 1207
_IS_PED_B* - _IS_PED_C*

## _0x5C6C7C70CA302801
`0x5C6C7C70CA302801` | `BOOL _0x5C6C7C70CA302801(Ped ped)` | build 1207
_IS_PED_IN*

## _0x5C90E20C25E6D83C
`0x5C90E20C25E6D83C` | `void _0x5C90E20C25E6D83C(Any p0)` | build 1207

## _0x5CA20FBE49891BBD
`0x5CA20FBE49891BBD` | `void _0x5CA20FBE49891BBD(Ped ped, int p1)` | build 1207
Used in Script Function MP_MAIN_OFFLINE__INITIALIZE_FLOW & PROCESS_GENERIC_PLAYER_INITIALIZATION

## _0x5CB2EBB467BE3ED6
`0x5CB2EBB467BE3ED6` | `void _0x5CB2EBB467BE3ED6(Ped animal, float p2)` | build 1355

## _0x5D4CD22A8C82A81A
`0x5D4CD22A8C82A81A` | `void _0x5D4CD22A8C82A81A(Ped ped, BOOL p1)` | build 1207
Related to ped hat
_SET_PED_LA* - _SET_PED_LE*

## _0x5DA36CCCB63C0895
`0x5DA36CCCB63C0895` | `Any _0x5DA36CCCB63C0895(Any p0, Any p1, Any p2)` | build 1207

## _0x5E9FAF6C513347B4
`0x5E9FAF6C513347B4` | `Entity _0x5E9FAF6C513347B4(Ped ped, Hash eventType)` | build 1207
Only used in R* SP Scripts
_GET_PED_IN*

## _0x5EFA8A3D8A60D662
`0x5EFA8A3D8A60D662` | `Any _0x5EFA8A3D8A60D662(Any p0, Any p1)` | build 1207

## _0x5FCF25D584065BFD
`0x5FCF25D584065BFD` | `void _0x5FCF25D584065BFD(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x600BBDD29820370C
`0x600BBDD29820370C` | `void _0x600BBDD29820370C(Ped ped)` | build 1207
Not implemented.

## _0x604E1010E3162E86
`0x604E1010E3162E86` | `void _0x604E1010E3162E86(Any p0, Any p1, Any p2)` | build 1207

## _0x606D529DADA3C940
`0x606D529DADA3C940` | `void _0x606D529DADA3C940(Ped ped, Any p1)` | build 1207
Not implemented.

## _0x633F83B301C87994
`0x633F83B301C87994` | `void _0x633F83B301C87994(Any p0, Any p1)` | build 1207

## _0x642720D8D69328B6
`0x642720D8D69328B6` | `void _0x642720D8D69328B6(Ped ped, Hash p1)` | build 1207
_SET_PED_M*

## _0x6507AC3BD7C99009
`0x6507AC3BD7C99009` | `BOOL _0x6507AC3BD7C99009(float x, float y, float z, float p3)` | build 1207
_IS_N* - _IS_P*

## _0x6734F0A6A52C371C
`0x6734F0A6A52C371C` | `void _0x6734F0A6A52C371C(Player player, int horseSlot)` | build 1207

## _0x6A190B94C2541A99
`0x6A190B94C2541A99` | `void _0x6A190B94C2541A99(Any p0)` | build 1207

## _0x6A489892E813951A
`0x6A489892E813951A` | `void _0x6A489892E813951A(Any p0)` | build 1207

## _0x6E8B87139854022D
`0x6E8B87139854022D` | `void _0x6E8B87139854022D(Ped ped, char* clipset)` | build 1207
Only used in SP R* Script train_robbery3: p1 = CLIPSET@VEH_TRAIN@HANDCART@BASE_PANIC & CLIPSET@VEH_TRAIN@HANDCART@BASE_PANIC_JOHN

## _0x6F46F8ACB44C4FC1
`0x6F46F8ACB44C4FC1` | `Any _0x6F46F8ACB44C4FC1(Any p0)` | build 1207

## _0x7020839C7302D8AC
`0x7020839C7302D8AC` | `BOOL _0x7020839C7302D8AC(Ped ped)` | build 1207
_HAS_*

## _0x704C908E9C405136
`0x704C908E9C405136` | `void _0x704C908E9C405136(Ped ped)` | build 1207
_CLEAR*

## _0x712B2C2B2471B493
`0x712B2C2B2471B493` | `void _0x712B2C2B2471B493(Ped ped, Hash p1)` | build 1207
_SET_PED_MO*

## _0x735662994E60A710
`0x735662994E60A710` | `void _0x735662994E60A710(Ped ped, BOOL p1)` | build 1207
_SET_PED_F*

## _0x7406C71F4AC2FFCC
`0x7406C71F4AC2FFCC` | `void _0x7406C71F4AC2FFCC(Any p0)` | build 1207

## _0x758F081DB204DDDE
`0x758F081DB204DDDE` | `BOOL _0x758F081DB204DDDE(Ped ped)` | build 1207

## _0x75A082563B4452E5
`0x75A082563B4452E5` | `void _0x75A082563B4452E5(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x75D3333409CD33CE
`0x75D3333409CD33CE` | `void _0x75D3333409CD33CE(Any p0, Any p1, Any p2)` | build 1207

## _0x763FA8A9D76EE3A7
`0x763FA8A9D76EE3A7` | `float _0x763FA8A9D76EE3A7(Ped ped)` | build 1311
Used in Script Function NB_EVENT_OVERRIDE__HANDLE__EVENT_DAMAGE_ENTITY

## _0x77243ED4F7CAAA55
`0x77243ED4F7CAAA55` | `BOOL _0x77243ED4F7CAAA55(Ped ped)` | build 1207
_IS_I* - _IS_L*

## _0x7ABBD9E449E0DB00
`0x7ABBD9E449E0DB00` | `void _0x7ABBD9E449E0DB00(Ped ped, BOOL p1)` | build 1207

## _0x7B5C293238EE4F20
`0x7B5C293238EE4F20` | `Any _0x7B5C293238EE4F20(Any p0)` | build 1207

## _0x7BB810E8B343AC7B
`0x7BB810E8B343AC7B` | `Any _0x7BB810E8B343AC7B(Any p0)` | build 1207

## _0x7C08E7CB8D951B70
`0x7C08E7CB8D951B70` | `void _0x7C08E7CB8D951B70(Ped ped, float p1)` | build 1207
Only used in SP
_SET_REMOVE_PED*

## _0x7C10221CE718AA72
`0x7C10221CE718AA72` | `void _0x7C10221CE718AA72(Ped ped, int p1)` | build 1207
_CLEAR_PED_M*

## _0x7E5185B979706210
`0x7E5185B979706210` | `void _0x7E5185B979706210(int groupId, int p1)` | build 1207
_SET_FORMATION_P*

## _0x7E8F9949B7AABBF0
`0x7E8F9949B7AABBF0` | `void _0x7E8F9949B7AABBF0(Any p0, Any p1, Any p2)` | build 1207

## _0x7EDB3C766B0D073F
`0x7EDB3C766B0D073F` | `void _0x7EDB3C766B0D073F(Ped ped)` | build 1232
Only used in R* Script net_moonshine_property
_A* - _B*

## _0x7EE3A8660F38797E
`0x7EE3A8660F38797E` | `BOOL _0x7EE3A8660F38797E(Ped ped)` | build 1207
_IS_PED_H* - _IS_PED_I*

## _0x7F090958AE95B61B
`0x7F090958AE95B61B` | `BOOL _0x7F090958AE95B61B(Ped ped, int p1)` | build 1207

## _0x8101BA1C0B462412
`0x8101BA1C0B462412` | `void _0x8101BA1C0B462412(Ped ped, int ropeId)` | build 1207
_ATTACH_*

## _0x815C0074A1BC0D93
`0x815C0074A1BC0D93` | `void _0x815C0074A1BC0D93(Ped ped, int p1)` | build 1207
_SET_PED_COMBAT_R - _SET_PED_C*

## _0x82CB0F3F0C7785E5
`0x82CB0F3F0C7785E5` | `Any _0x82CB0F3F0C7785E5(Any p0)` | build 1207

## _0x851966E1E35AF491
`0x851966E1E35AF491` | `void _0x851966E1E35AF491(Any p0, Any p1)` | build 1207

## _0x85F500F4E24CA43E
`0x85F500F4E24CA43E` | `void _0x85F500F4E24CA43E(Ped ped, float p1)` | build 1207
Used in Script Function SKCS_PLAYER_ROBBING
_SET_PED_A*

## _0x86F0B6730C32AC14
`0x86F0B6730C32AC14` | `void _0x86F0B6730C32AC14(Ped ped, BOOL p1)` | build 1207
_SET_PED_*

## _0x86FAFC18E3D4380C
`0x86FAFC18E3D4380C` | `void _0x86FAFC18E3D4380C(int groupId, BOOL p1)` | build 1207

## _0x878E8104FA27CDAE
`0x878E8104FA27CDAE` | `void _0x878E8104FA27CDAE(Vehicle vehicle, Hash p1)` | build 1207

## _0x87C2724A56F66020
`0x87C2724A56F66020` | `void _0x87C2724A56F66020(Ped ped)` | build 1207
_CLEAR_PED_E* - _CLEAR_PED_L*

## _0x8822F124788B8D0A
`0x8822F124788B8D0A` | `void _0x8822F124788B8D0A(Ped ped, BOOL p1)` | build 1207
Only used in R* Script train_robbery4
_SET_PED_D*

## _0x8822F139408B8D0A
`0x8822F139408B8D0A` | `BOOL _0x8822F139408B8D0A(Ped ped)` | build 1207
If returned true, SET_ENABLE_BOUND_ANKLES is called in R* Script guama2
_GET_D* - _GET_E*

## _0x88A95BB640FC186F
`0x88A95BB640FC186F` | `void _0x88A95BB640FC186F(Ped ped)` | build 1207
Used in R* Script generic_weight_control_item
_CLEAR_PED_E* - CLEAR_PED_(G?)L*

## _0x88B2026A3B0BE33D
`0x88B2026A3B0BE33D` | `void _0x88B2026A3B0BE33D(Ped ped, float p1)` | build 1207

## _0x897934E868EDDD6C
`0x897934E868EDDD6C` | `void _0x897934E868EDDD6C(Ped ped, int p1, float p2, float p3, float p4)` | build 1207

## _0x89816B58C3466262
`0x89816B58C3466262` | `Any _0x89816B58C3466262(Ped ped)` | build 1207
_GET_PED_B* - _GET_PED_C*

## _0x899DFA0009AC93DE
`0x899DFA0009AC93DE` | `void _0x899DFA0009AC93DE(Ped ped, float p1)` | build 1207
_SET_PED_O*

## _0x89E59DBD15E21177
`0x89E59DBD15E21177` | `void _0x89E59DBD15E21177(int groupId, int p1)` | build 1207
_SET_C*

## _0x8AF46E5159A5B620
`0x8AF46E5159A5B620` | `void _0x8AF46E5159A5B620(Ped ped, Hash speechParams)` | build 1207
_SET_PED_IN*

## _0x8AF8E647D6B2A649
`0x8AF8E647D6B2A649` | `int _0x8AF8E647D6B2A649(int groupId, Ped ped)` | build 1207
Returns offset (0 < 32) to be used with MISC::SET_BIT
_GET_PED_CR*

## _0x8AFCCC0F18D70018
`0x8AFCCC0F18D70018` | `void _0x8AFCCC0F18D70018(int groupId, BOOL p1)` | build 1207
_SET_FORMATION_*

## _0x8BA0C65AC15A7D33
`0x8BA0C65AC15A7D33` | `void _0x8BA0C65AC15A7D33(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x8BE24D74D74C6E9B
`0x8BE24D74D74C6E9B` | `Ped _0x8BE24D74D74C6E9B(Ped ped)` | build 1207
Used in Script Function NET_CAMP_DOG_CLIENT_HANDLE_ANIMAL_INTERACTION

## _0x8CB2553C559102C1
`0x8CB2553C559102C1` | `void _0x8CB2553C559102C1(Ped ped, int p1, BOOL p2)` | build 1207
_SET_PED_T* - SET_PED_U*

## _0x8D9DB115FBA8E23D
`0x8D9DB115FBA8E23D` | `void _0x8D9DB115FBA8E23D(Any p0)` | build 1207

## _0x9078FB0557364099
`0x9078FB0557364099` | `void _0x9078FB0557364099(Any p0)` | build 1207

## _0x913D04A5176F84C9
`0x913D04A5176F84C9` | `BOOL _0x913D04A5176F84C9(Ped ped)` | build 1207
_IS_PED_S* - _IS_PED_U*

## _0x9184788BFF1EDAD7
`0x9184788BFF1EDAD7` | `void _0x9184788BFF1EDAD7(Any p0, Any p1)` | build 1207

## _0x91BAB9E064F036CD
`0x91BAB9E064F036CD` | `void _0x91BAB9E064F036CD(Any p0, Any p1)` | build 1207

## _0x92A1B55A59720395
`0x92A1B55A59720395` | `void _0x92A1B55A59720395(Any p0, Any p1)` | build 1207

## _0x94132D7C8D3575C4
`0x94132D7C8D3575C4` | `BOOL _0x94132D7C8D3575C4(Ped ped)` | build 1207
_GET_IS_PED_*

## _0x9629FAF6460D35CB
`0x9629FAF6460D35CB` | `void _0x9629FAF6460D35CB(Hash group, BOOL p1)` | build 1207

## _0x96595B36D6A2279B
`0x96595B36D6A2279B` | `void _0x96595B36D6A2279B(Ped animal, BOOL toggle)` | build 1207
Only used in R* Script mob4 combined with SET_ANIMAL_TUNING_BOOL_PARAM
_SET_PED_S* - _SET_PED_TARGET_*

## _0x966DE09688A1DE39
`0x966DE09688A1DE39` | `void _0x966DE09688A1DE39(int groupId, float p1, float p2, float p3, float p4)` | build 1207
_SET_FORMATION_P*

## _0x96C7B659854DE629
`0x96C7B659854DE629` | `void _0x96C7B659854DE629(Any p0, Any p1)` | build 1207

## _0x97A38B65EBDA3D50
`0x97A38B65EBDA3D50` | `void _0x97A38B65EBDA3D50(Ped ped, BOOL p1)` | build 1207
_SET_PED_D*

## _0x97B06669AC569003
`0x97B06669AC569003` | `void _0x97B06669AC569003(Ped ped1, Ped ped2)` | build 1207
_CLEAR*

## _0x97C475212B327666
`0x97C475212B327666` | `void _0x97C475212B327666(int groupId, BOOL p1)` | build 1207
_SET_SCENARIO_PED_* - _SET_SPAWNER_*

## _0x9851DE7AEC10B4E1
`0x9851DE7AEC10B4E1` | `void _0x9851DE7AEC10B4E1(float x, float y, float z, float p3, int p4, Any p5)` | build 1207

## _0x992187D975635DF5
`0x992187D975635DF5` | `void _0x992187D975635DF5(Any p0, Any p1)` | build 1311

## _0x99DF2639DA76C1DC
`0x99DF2639DA76C1DC` | `BOOL _0x99DF2639DA76C1DC(Ped ped1, Ped ped2, int p2)` | build 1232
_CAN_PED_*

## _0x9A4AC116CC1EEE14
`0x9A4AC116CC1EEE14` | `void _0x9A4AC116CC1EEE14(Any p0)` | build 1207

## _0x9AB33CB5834885B3
`0x9AB33CB5834885B3` | `void _0x9AB33CB5834885B3(Ped ped, float p1, float p2, float p3, float p4)` | build 1207
_SET_PED_M*

## _0x9B65444C07B782BF
`0x9B65444C07B782BF` | `void _0x9B65444C07B782BF(Ped ped, const char* p1)` | build 1207
Only used in SP R* Script winter1: p1 = Winter1Mount

## _0x9B9B9FA0EA283E3D
`0x9B9B9FA0EA283E3D` | `void _0x9B9B9FA0EA283E3D(Ped ped, float p1)` | build 1207
Used in Script Function SKCS_PLAYER_ROBBING
_SET_PED_SHOULD_PLAY_* - _SET_PED_SW*

## _0x9BBEAF8B0C007F1E
`0x9BBEAF8B0C007F1E` | `void _0x9BBEAF8B0C007F1E(Ped ped, BOOL p1)` | build 1207
_SET_PLAYER_CAN_B* - _SET_PLAYER_CAN_U*

## _0x9D8DFE2DE9CB4DFC
`0x9D8DFE2DE9CB4DFC` | `void _0x9D8DFE2DE9CB4DFC(Ped ped)` | build 1207
_RESET_PED_*

## _0x9E66708B2B41F14A
`0x9E66708B2B41F14A` | `void _0x9E66708B2B41F14A(Any p0, Any p1)` | build 1207

## _0x9F0F28B42C4EE80A
`0x9F0F28B42C4EE80A` | `void _0x9F0F28B42C4EE80A(Ped animal, float p2)` | build 1355

## _0x9F933E0985E12C51
`0x9F933E0985E12C51` | `void _0x9F933E0985E12C51(Ped ped, float p1, float p2, float p3)` | build 1207

## _0xA064BBABB064446F
`0xA064BBABB064446F` | `void _0xA064BBABB064446F(Any p0)` | build 1207

## _0xA180FBD502A03125
`0xA180FBD502A03125` | `Any _0xA180FBD502A03125(Any p0, Any p1, Any p2)` | build 1207

## _0xA1FBAC56D38563E2
`0xA1FBAC56D38563E2` | `BOOL _0xA1FBAC56D38563E2(Volume volume)` | build 1207

## _0xA2116C1E4ED85C24
`0xA2116C1E4ED85C24` | `void _0xA2116C1E4ED85C24(Ped ped, BOOL inverted)` | build 1207
_SET_PED_*

## _0xA218D2BBCAA7388C
`0xA218D2BBCAA7388C` | `Any _0xA218D2BBCAA7388C(Any p0, Any p1)` | build 1207

## _0xA274F51EF7E34B95
`0xA274F51EF7E34B95` | `Any _0xA274F51EF7E34B95(Any p0, Any p1)` | build 1207

## _0xA2B8E47442C76CEC
`0xA2B8E47442C76CEC` | `void _0xA2B8E47442C76CEC(Any p0, Any p1)` | build 1207

## _0xA2F8B3B5FEDFC100
`0xA2F8B3B5FEDFC100` | `void _0xA2F8B3B5FEDFC100(Any p0, Any p1)` | build 1207

## _0xA31D350D66FA1855
`0xA31D350D66FA1855` | `Any _0xA31D350D66FA1855(Any p0)` | build 1207

## _0xA405BF9F01960C16
`0xA405BF9F01960C16` | `void _0xA405BF9F01960C16(Any p0)` | build 1207

## _0xA4AC05B1A364EBC5
`0xA4AC05B1A364EBC5` | `Any _0xA4AC05B1A364EBC5(Any p0, Any p1, Any p2)` | build 1207

## _0xA4B6432E3880F2F9
`0xA4B6432E3880F2F9` | `BOOL _0xA4B6432E3880F2F9(Ped ped)` | build 1311

## _0xA6D6F03095C88F59
`0xA6D6F03095C88F59` | `void _0xA6D6F03095C88F59(Ped ped)` | build 1207
_DELETE_*

## _0xA7A806677F8DE138
`0xA7A806677F8DE138` | `void _0xA7A806677F8DE138(Ped ped)` | build 1207
Washing player's face/hands now
_CLEAR_PED_E* - _CLEAR_PED_L*

## _0xA7DC9266ED6A4E51
`0xA7DC9266ED6A4E51` | `void _0xA7DC9266ED6A4E51(Ped ped)` | build 1207
_CLEAR_PED_B* - _CLEAR_PED_C*

## _0xA8A95CECB1906EA2
`0xA8A95CECB1906EA2` | `void _0xA8A95CECB1906EA2(int groupId, BOOL p1)` | build 1207
_SET_ENABLE_B* - _SET_ENABLE_H*

## _0xA90684ED185CCB4B
`0xA90684ED185CCB4B` | `void _0xA90684ED185CCB4B(Ped animal, BOOL p1, float p2, float p3)` | build 1207
Only used in R* Script mob4 and rcm_mason4
_SET_PED_DEFENSIVE_* - _SET_PED_DESIRED_*

## _0xA967D6A8ED2D713B
`0xA967D6A8ED2D713B` | `void _0xA967D6A8ED2D713B(Ped ped, BOOL p1)` | build 1207
_SET_PED_P* - _SET_PED_R*

## _0xAA6C49AE90A32299
`0xAA6C49AE90A32299` | `void _0xAA6C49AE90A32299(Ped ped, Hash p1)` | build 1207

## _0xAAC0EE3B4999ABB5
`0xAAC0EE3B4999ABB5` | `void _0xAAC0EE3B4999ABB5(Ped ped, Ped targetPed)` | build 1207

## _0xAD3330E3C3E98007
`0xAD3330E3C3E98007` | `void _0xAD3330E3C3E98007(Any p0, Any p1)` | build 1207

## _0xAE6B68A83ABBE7C0
`0xAE6B68A83ABBE7C0` | `void _0xAE6B68A83ABBE7C0(Any p0)` | build 1207

## _0xAF041C10756C30FB
`0xAF041C10756C30FB` | `void _0xAF041C10756C30FB(Ped ped, BOOL p1, BOOL p2, BOOL p3)` | build 1207
_CLEAR_PED_D*

## _0xB05CC690CDE8A4A9
`0xB05CC690CDE8A4A9` | `BOOL _0xB05CC690CDE8A4A9(int groupId, float p1)` | build 1207
Used to set up bad guy groups in nb_kidnapped R* Script (MP_RE_KIDNAPPED): p1 = 4.f
_SET_FORMATION_*

## _0xB06F5F1DEF417216
`0xB06F5F1DEF417216` | `void _0xB06F5F1DEF417216(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xB29C553BA582D09E
`0xB29C553BA582D09E` | `Any _0xB29C553BA582D09E(Any* p0, Hash model, int damageCleanliness, int p3)` | build 1207
Used in Script Function SATCHEL_COUNT_BREAKDOWN_COMPONENTS

## _0xB4B7C92FCE7347B7
`0xB4B7C92FCE7347B7` | `void _0xB4B7C92FCE7347B7(Ped ped)` | build 1207
_RESET_PED_C*

## _0xB65927F861E7AE39
`0xB65927F861E7AE39` | `BOOL _0xB65927F861E7AE39(Ped ped, int p1)` | build 1207

## _0xB8E2D655E1D5BD39
`0xB8E2D655E1D5BD39` | `Any _0xB8E2D655E1D5BD39(Any p0)` | build 1207

## _0xB91AB3BE7F655D49
`0xB91AB3BE7F655D49` | `BOOL _0xB91AB3BE7F655D49(Ped ped)` | build 1207
_IS_PED_J* - _IS_PED_L*

## _0xB9BDFAE609DFB7C5
`0xB9BDFAE609DFB7C5` | `void _0xB9BDFAE609DFB7C5(Any p0, Any p1, Any p2)` | build 1207

## _0xBB3E5370EBB6BE28
`0xBB3E5370EBB6BE28` | `Any _0xBB3E5370EBB6BE28(Any p0, Any p1)` | build 1207

## _0xBC1DC48270468444
`0xBC1DC48270468444` | `void _0xBC1DC48270468444(Any p0)` | build 1207

## _0xBD0E4F52F6D95242
`0xBD0E4F52F6D95242` | `BOOL _0xBD0E4F52F6D95242(Ped ped)` | build 1207
_IS_PED_M* - _IS_PED_O*

## _0xBF567DF2BEF211A6
`0xBF567DF2BEF211A6` | `void _0xBF567DF2BEF211A6(Any p0, Any p1)` | build 1207

## _0xBFA6B7731C3BAF02
`0xBFA6B7731C3BAF02` | `void _0xBFA6B7731C3BAF02()` | build 1207
Only used in R* Script tg_p (CLIENT__AMBIENT_POPULATION - Player starts the populate in region)

## _0xC2722B252C79E641
`0xC2722B252C79E641` | `void _0xC2722B252C79E641(Ped ped, Any p1, Any p2, BOOL p3)` | build 1232
_FORCE_PED_*

## _0xC2EF407645BEECDC
`0xC2EF407645BEECDC` | `Any _0xC2EF407645BEECDC(Any p0)` | build 1207

## _0xC5B78E41DCF8227C
`0xC5B78E41DCF8227C` | `void _0xC5B78E41DCF8227C(Ped ped, BOOL p1)` | build 1207
_SET_H* - _SET_I*

## _0xC6136B40FFFB778B
`0xC6136B40FFFB778B` | `void _0xC6136B40FFFB778B(BOOL p0)` | build 1207

## _0xC6981AFF6D2A71C2
`0xC6981AFF6D2A71C2` | `void _0xC6981AFF6D2A71C2(Any p0)` | build 1207

## _0xC6C4E15CF7D52FEA
`0xC6C4E15CF7D52FEA` | `void _0xC6C4E15CF7D52FEA(Any p0, Any p1)` | build 1207

## _0xC9151483CC06A414
`0xC9151483CC06A414` | `void _0xC9151483CC06A414(Ped ped)` | build 1207

## _0xC991EF46FE323867
`0xC991EF46FE323867` | `void _0xC991EF46FE323867(Ped ped, Any p1)` | build 1207
Not implemented.

## _0xC99F104BDF8C7F5A
`0xC99F104BDF8C7F5A` | `void _0xC99F104BDF8C7F5A(Ped ped, BOOL p1)` | build 1207
_SET_PLAYER_N* - _SET_PLAYER_S*

## _0xCA95C156C14B2054
`0xCA95C156C14B2054` | `void _0xCA95C156C14B2054(Any p0, Any p1)` | build 1207

## _0xCB1A3864C524F784
`0xCB1A3864C524F784` | `void _0xCB1A3864C524F784(Any p0, Any p1)` | build 1207

## _0xCB86D3E3E3708901
`0xCB86D3E3E3708901` | `Any _0xCB86D3E3E3708901(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xCB8F4C9343EBE240
`0xCB8F4C9343EBE240` | `BOOL _0xCB8F4C9343EBE240(Ped ped, Hash eventType, Vector3* coords)` | build 1207
Only used in R* SP Scripts
_GET_PLAYER_W* - _GET_RANDOM_*

## _0xCBDE59C48F2B06F5
`0xCBDE59C48F2B06F5` | `void _0xCBDE59C48F2B06F5(Any p0, Any p1, Any p2)` | build 1207

## _0xCD9E5F94A2F38683
`0xCD9E5F94A2F38683` | `void _0xCD9E5F94A2F38683(Ped ped, BOOL p1)` | build 1207
_SET_PED_R* - _SET_PED_S*

## _0xCDFB8C04D4C95D9B
`0xCDFB8C04D4C95D9B` | `void _0xCDFB8C04D4C95D9B(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xCF0B19806473D324
`0xCF0B19806473D324` | `void _0xCF0B19806473D324(Ped ped, float x, float y, float z)` | build 1207
_SET_PED_COMBAT_*

## _0xD049920CD29F6CC8
`0xD049920CD29F6CC8` | `void _0xD049920CD29F6CC8(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xD049FDAF089FDDB0
`0xD049FDAF089FDDB0` | `void _0xD049FDAF089FDDB0(Ped ped, Hash p1, float p2)` | build 1207

## _0xD103F6DBB5442BE8
`0xD103F6DBB5442BE8` | `void _0xD103F6DBB5442BE8(Ped ped, int p1)` | build 1207
Params: p1 either a 1 or 0, so perhaps BOOL
_SET_PED_A*

## _0xD2F0FE8805D91647
`0xD2F0FE8805D91647` | `void _0xD2F0FE8805D91647(Any p0, Any p1)` | build 1207

## _0xD355E2F1BB41087E
`0xD355E2F1BB41087E` | `BOOL _0xD355E2F1BB41087E(Ped ped, float p1)` | build 1207

## _0xD4D403EA031F351C
`0xD4D403EA031F351C` | `BOOL _0xD4D403EA031F351C(Ped ped)` | build 1207

## _0xD55DB4466D00A258
`0xD55DB4466D00A258` | `BOOL _0xD55DB4466D00A258(Ped legendaryAnimal)` | build 1207
Used in Script Function LA_CHECK_ALERTED
_GET_IS_PED_*

## _0xD5BD1B5318A81994
`0xD5BD1B5318A81994` | `void _0xD5BD1B5318A81994(int groupId, BOOL p1)` | build 1207
_SET_FORMATION_*

## _0xD61FCF9FCFD515B7
`0xD61FCF9FCFD515B7` | `void _0xD61FCF9FCFD515B7(Any p0, Any p1, Any p2)` | build 1207

## _0xD7D2F45C56A4F4DF
`0xD7D2F45C56A4F4DF` | `void _0xD7D2F45C56A4F4DF(Any p0, Any p1, Any p2)` | build 1207

## _0xD8544F6260F5F01E
`0xD8544F6260F5F01E` | `void _0xD8544F6260F5F01E(Ped ped, int p1)` | build 1232
METAPED_PLAYER_COMPONENTS_SET_META_TYPE_TO_BE_BYPASSED: Setting visibility
p1 is mostly 10
_CLEAR_PED_N* - _CLEAR_PED_W*

## _0xD8CEEED54C672B5D
`0xD8CEEED54C672B5D` | `void _0xD8CEEED54C672B5D(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0xD97BC27AC039F681
`0xD97BC27AC039F681` | `Any _0xD97BC27AC039F681(Any p0, Any p1, Any p2, Any p3)` | build 1311

## _0xDDFAD4DEAA7FA362
`0xDDFAD4DEAA7FA362` | `void _0xDDFAD4DEAA7FA362(int groupId, float p1, float p2, float p3, float p4)` | build 1207
_SET_FORMATION_P*

## _0xDEDBED3020DA49DC
`0xDEDBED3020DA49DC` | `void _0xDEDBED3020DA49DC(Any p0)` | build 1207

## _0xDEE8D30AA5C2E28D
`0xDEE8D30AA5C2E28D` | `void _0xDEE8D30AA5C2E28D(Ped ped, Hash p1, BOOL p2)` | build 1207

## _0xE0FE107AB174D64A
`0xE0FE107AB174D64A` | `void _0xE0FE107AB174D64A(Any p0, Any p1)` | build 1207

## _0xE1103300F3456DE7
`0xE1103300F3456DE7` | `void _0xE1103300F3456DE7(int groupId, float p1, float p2)` | build 1207
_SET_FORMATION_P*

## _0xE1AADD0055D76603
`0xE1AADD0055D76603` | `void _0xE1AADD0055D76603(Ped ped, Entity entity, int boneIndex1, int boneIndex2, float x, float y, float z, float p7, BOOL p8, BOOL p9, int p10)` | build 1207
_C*

## _0xE1B3BE07D3AADDED
`0xE1B3BE07D3AADDED` | `void _0xE1B3BE07D3AADDED(Ped ped, int p1, BOOL p2)` | build 1207

## _0xE20027B414BFE6C7
`0xE20027B414BFE6C7` | `void _0xE20027B414BFE6C7(Any p0, Any p1)` | build 1207

## _0xE29D8CD66553DBAA
`0xE29D8CD66553DBAA` | `void _0xE29D8CD66553DBAA(Ped horse)` | build 1207
_SET_PED_R* -_SET_PED_S*

## _0xE37ACEE15AC50C7E
`0xE37ACEE15AC50C7E` | `void _0xE37ACEE15AC50C7E(Ped ped, const char* p1)` | build 1207
_SET_PED_IN*

## _0xE4C95E0AE31C6512
`0xE4C95E0AE31C6512` | `void _0xE4C95E0AE31C6512(Ped ped, Any p1)` | build 1207

## _0xE4EF4382E22C780C
`0xE4EF4382E22C780C` | `void _0xE4EF4382E22C780C(Any p0)` | build 1207

## _0xE50C9816B3F22D8B
`0xE50C9816B3F22D8B` | `void _0xE50C9816B3F22D8B(Ped ped, Hash p1, float p2)` | build 1311
_SET_D*

## _0xE6CB36F43A95D75F
`0xE6CB36F43A95D75F` | `void _0xE6CB36F43A95D75F(Any p0)` | build 1207

## _0xE735A7DA22E88359
`0xE735A7DA22E88359` | `void _0xE735A7DA22E88359(Any p0)` | build 1207

## _0xE737D5F14304A2EC
`0xE737D5F14304A2EC` | `void _0xE737D5F14304A2EC(Ped ped, Player player, int p2)` | build 1207
Only used in R* Script nb_animal_attack: p2 = 120000
_SET_PED_SH* - _SET_PED_SP*

## _0xE8ABE3B73FC7FE17
`0xE8ABE3B73FC7FE17` | `void _0xE8ABE3B73FC7FE17(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xE9E06EA514A69061
`0xE9E06EA514A69061` | `void _0xE9E06EA514A69061(Any p0, Any p1)` | build 1207

## _0xEA8763E505AFD49A
`0xEA8763E505AFD49A` | `void _0xEA8763E505AFD49A(Any p0, Any p1, Any p2)` | build 1207

## _0xEB8886E1065654CD
`0xEB8886E1065654CD` | `void _0xEB8886E1065654CD(Ped ped, int p1, const char* p2, float p3)` | build 1207
Washing player's face/hands now
_FA* - _FI*

## _0xEBAAC9A750E7563B
`0xEBAAC9A750E7563B` | `BOOL _0xEBAAC9A750E7563B(Ped ped)` | build 1207
If returned true: PROCESS_RESIZING_TRACKING_BOUNDS_VOLUME - Scaling UP the bounds due to tracking
If returned false: PROCESS_RESIZING_TRACKING_BOUNDS_VOLUME - Scaling DOWN the bounds due to tracking
_IS_PED_T* - _IS_PED_U*

## _0xEBD49472BCCF7642
`0xEBD49472BCCF7642` | `void _0xEBD49472BCCF7642(Any p0, Any p1)` | build 1207

## _0xEC60D1D225BC50AA
`0xEC60D1D225BC50AA` | `void _0xEC60D1D225BC50AA(Ped ped, float p1)` | build 1207
_SET_C*

## _0xED1C764997A86D5A
`0xED1C764997A86D5A` | `void _0xED1C764997A86D5A(Ped ped, int mount)` | build 1207
Only used in R* Script nb_stalking_hunter

## _0xEEDC9B29314B2733
`0xEEDC9B29314B2733` | `void _0xEEDC9B29314B2733(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9)` | build 1207

## _0xEF371232BC6053E1
`0xEF371232BC6053E1` | `void _0xEF371232BC6053E1(Ped ped)` | build 1207
_ADD_*

## _0xF47D54B986F0A346
`0xF47D54B986F0A346` | `void _0xF47D54B986F0A346(Ped ped, int danceIntensity)` | build 1232
Used in Script Function MOONSHINE_BAND_CLIENT_PATRON_UPDATE

## _0xF634E2892220EF34
`0xF634E2892220EF34` | `void _0xF634E2892220EF34(Ped ped, Any p1)` | build 1207

## _0xF6A8C4B4A11AE89C
`0xF6A8C4B4A11AE89C` | `Any _0xF6A8C4B4A11AE89C(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0xF7327ACC7A89AEF1
`0xF7327ACC7A89AEF1` | `Any _0xF7327ACC7A89AEF1(Any p0, Any p1, Any p2)` | build 1207

## _0xF917F92BF22ECBAB
`0xF917F92BF22ECBAB` | `void _0xF917F92BF22ECBAB(Any p0)` | build 1207

## _0xF9331B3A314EB49D
`0xF9331B3A314EB49D` | `BOOL _0xF9331B3A314EB49D(Ped ped)` | build 1207

## _0xF9CBD46433E36713
`0xF9CBD46433E36713` | `void _0xF9CBD46433E36713(Ped ped, Entity targetEntity, float p2, float p3, float p4, float p5, float p6, float p7, float p8, const char* p9)` | build 1207
Used in Script Function PLAYER_HEAD_TRACKING_MAINTAIN

## _0xFA0D206B489A6846
`0xFA0D206B489A6846` | `void _0xFA0D206B489A6846(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xFA742B82D093D848
`0xFA742B82D093D848` | `void _0xFA742B82D093D848(Any p0, Any p1, Any p2)` | build 1207

## _0xFC23348F0F4E245F
`0xFC23348F0F4E245F` | `void _0xFC23348F0F4E245F(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xFD3C31A2E45671E7
`0xFD3C31A2E45671E7` | `void _0xFD3C31A2E45671E7(Ped ped, int p1)` | build 1207
_DISABLE_A* - _DISABLE_C*

## _0xFD8E853F0BC2E942
`0xFD8E853F0BC2E942` | `void _0xFD8E853F0BC2E942(Any p0, Any p1)` | build 1207

## _0xFEA6126C34DF2532
`0xFEA6126C34DF2532` | `void _0xFEA6126C34DF2532(Ped ped, BOOL p1)` | build 1207
METAPED_PLAYER_COMPONENTS_SET_META_TYPE_TO_BE_BYPASSED: Setting visibility
_SET_M* - _SET_P*

## _0xFFDE295662405B25
`0xFFDE295662405B25` | `int _0xFFDE295662405B25(Ped ped)` | build 1207
_GET_PED_COMBAT_M* - _GET_PED_C*

## _ADD_PED_STAY_OUT_VOLUME
`0xE9B168527B337BF0` | `BOOL _ADD_PED_STAY_OUT_VOLUME(Ped ped, Volume volume)` | build 1207

## _ADD_PED_SUBSCRIBE_TO_LEGENDARY_BLIPS
`0xE37287EE358939C3` | `BOOL _ADD_PED_SUBSCRIBE_TO_LEGENDARY_BLIPS(Ped ped)` | build 1311

## _ADD_SCENARIO_BLOCKING_VOLUME
`0x4C39C95AE5DB1329` | `Any _ADD_SCENARIO_BLOCKING_VOLUME(Volume volume, BOOL p1, int flag)` | build 1207
flag: see ADD_SCENARIO_BLOCKING_AREA

## _ADD_SCENARIO_TRANSITION
`0x6D07B371E9439019` | `void _ADD_SCENARIO_TRANSITION(Ped ped)` | build 1207
Forces transition now, called together with 0xD65FDC686A031C83

## _ADD_TEXTURE_LAYER
`0x86BB5FF45F193A02` | `int _ADD_TEXTURE_LAYER(int textureId, Hash albedoHash, Hash normalHash, Hash materialHash, int blendType, float texAlpha, int sheetGridIndex)` | build 1207
Creates ped overlay in texture override data and returns it's index.
This index are used for further overlay editing.

albedoHash: a hash of overlay's albedo texture
colorType: a color type(from 0 to 2). 0 is used for overlays with RGB colors usually.

## _APPLY_COLD_TO_PED
`0x1F8215D0E446F593` | `void _APPLY_COLD_TO_PED(Ped ped, float intensity, int p2)` | build 1207
Apply cold intensity to ped from 0.0 to 1.0

## _APPLY_PED_DAMAGE_PACK_TO_BONE
`0x58D32261AE0F0843` | `void _APPLY_PED_DAMAGE_PACK_TO_BONE(Ped ped, int boneId, float xOffset, float yOffset, float zOffset, float xRot, float yRot, float zRot, const char* damagePack)` | build 1207
seems to only work with PD_Vomit ?

## _APPLY_PED_META_PED_OUTFIT
`0x74F512E29CB717E2` | `BOOL _APPLY_PED_META_PED_OUTFIT(int requestId, Ped ped, BOOL p2, BOOL p3)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/clothes/metaped_outfits.lua

## _APPLY_SHOP_ITEM_TO_PED
`0xD3A7B003ED343FD9` | `void _APPLY_SHOP_ITEM_TO_PED(Ped ped, Hash componentHash, BOOL immediately, BOOL isMp, BOOL p4)` | build 1207

## _APPLY_TEXTURE_ON_PED
`0x0B46E25761519058` | `void _APPLY_TEXTURE_ON_PED(Ped ped, Hash componentHash, int textureId)` | build 1207

## _ARE_ALL_AMBIENT_PED_RESERVATIONS_READY
`0x5E420FF293EE5472` | `BOOL _ARE_ALL_AMBIENT_PED_RESERVATIONS_READY()` | build 1207

## _ATTACH_VOLUME_TO_ENTITY
`0x7C00CFC48A782DC0` | `void _ATTACH_VOLUME_TO_ENTITY(Volume volume, Entity entity, float offsetX, float offsetY, float offsetZ, float rotX, float rotY, float rotZ, int p8, BOOL p9)` | build 1207

## _CAN_PED_HEAR_TARGET_PED
`0x0EA9EACBA3B01601` | `float _CAN_PED_HEAR_TARGET_PED(Ped source, Ped listener, BOOL includeNoiseBoost)` | build 1207
Returns true if `listener` can hear `source`.
If `includeNoiseBoost` is true, the source's noise radius is applied (easier to hear).
It treats the source as louder—its current noise expands the effective hearing range (by subtracting noiseRadius² from dist²), while false uses the baseline distance-only check (stealth).

## _CAN_PED_USE_SCENARIO_POINT
`0xAB643407D0B26F07` | `BOOL _CAN_PED_USE_SCENARIO_POINT(Ped ped, int scenario, Any p2, Any p3, Any p4)` | build 1207
p2 is always 0, p3 is always 0, p4 is always 1

## _CHANGE_PED_STAMINA
`0xC3D4B754C0E86B9E` | `BOOL _CHANGE_PED_STAMINA(Ped ped, float amount)` | build 1207
Alters entity's stamina by 'amount'. Can be negative (to drain stamina). float amount: -1000.0 - 1000.0

## _CLEAR_ACTIVE_ANIMAL_OWNER
`0xBCC76708E5677E1D` | `void _CLEAR_ACTIVE_ANIMAL_OWNER(Ped horse, BOOL clear)` | build 1207
Used in Script Functions PLAYER_HORSE_RELEASE_HORSE_TO_AMBIENT_WORLD (p1 = true), HORSE_SETUP_PLAYER_HORSE_ATTRIBUTES (p1 = false)
Set to false for player horse in scripts and seems it's only true when releasing/changing a player horse? Cannot determine what effect it has, but it doesn't seem to affect _GET_HORSE_TAMING_STATE

## _CLEAR_PED_ACTION_DISABLE_FLAG
`0x949B2F9ED2917F5D` | `void _CLEAR_PED_ACTION_DISABLE_FLAG(Ped ped, int actionDisableFlag)` | build 1207

## _CLEAR_PED_BLOOD_DAMAGE_FACIAL
`0x7F5D88333EE8A86F` | `void _CLEAR_PED_BLOOD_DAMAGE_FACIAL(Ped ped, int p1)` | build 1207

## _CLEAR_PED_COMBAT_STYLE
`0x78815FC52832B690` | `void _CLEAR_PED_COMBAT_STYLE(Ped ped, int p1)` | build 1207
Params: p1 = 1 in R* Scripts

## _CLEAR_PED_COMBAT_STYLE_MOD
`0x1FA132CBCD7CB239` | `void _CLEAR_PED_COMBAT_STYLE_MOD(Ped ped, Hash combatStyleModHash)` | build 1207
_CLEAR_PED_COMBAT_*

## _CLEAR_PED_DESIRED_LOCO_FOR_MODEL
`0x4FD80C3DD84B817B` | `void _CLEAR_PED_DESIRED_LOCO_FOR_MODEL(Ped ped)` | build 1207
Clears locomotion archetype

## _CLEAR_PED_DESIRED_LOCO_MOTION_TYPE
`0x58F7DB5BD8FA2288` | `void _CLEAR_PED_DESIRED_LOCO_MOTION_TYPE(Ped ped)` | build 1207

## _CLEAR_PED_GRAPPLE_FLAG
`0xEAE3B5B019C8D23F` | `void _CLEAR_PED_GRAPPLE_FLAG(Ped ped, int flag)` | build 1207

## _CLEAR_PED_TARGET_ACTION_DISABLE_FLAG
`0xBBF6D1D07C02D00A` | `void _CLEAR_PED_TARGET_ACTION_DISABLE_FLAG(Ped ped, int actionDisableFlag)` | build 1207

## _CLEAR_PED_TEXTURE
`0xB63B9178D0F58D82` | `void _CLEAR_PED_TEXTURE(int textureId)` | build 1207
Removes every texture layer
Old Name: _RESET_PED_TEXTURE_2

## _CLEAR_PELT_FROM_HORSE
`0x627F7F3A0C4C51FF` | `void _CLEAR_PELT_FROM_HORSE(Ped horse, int peltId)` | build 1207

## _COMPUTE_PED_MOVE_BLEND_RATIO_FOR_MAX_SPEED
`0x46BF2A810679D6E6` | `float _COMPUTE_PED_MOVE_BLEND_RATIO_FOR_MAX_SPEED(Ped ped, float maxMoveBlendRatio)` | build 1207
Returns vehicle (desired) speed
_COMPUTE_(VEHICLE_SPEED_USING_BLEND_RATIO?)*

## _COMPUTE_SATCHEL_ITEM_FOR_PED_CARCASS
`0x6B89FAA36FC909A3` | `int _COMPUTE_SATCHEL_ITEM_FOR_PED_CARCASS(Any* outInventoryItemArray, Ped ped, int damageCleanliness, int skinningQuality)` | build 1207
Related to dead animals items/loots
Notice: skinningQuality is partially calculated using pedQuality

## _COMPUTE_SPEED_FOR_PED_MOVE_BLEND_RATIO
`0xCA95924C893A0C91` | `float _COMPUTE_SPEED_FOR_PED_MOVE_BLEND_RATIO(Ped ped, float speed)` | build 1207
Returns vehicle speed

## _COUNT_PEDS_AWARE_OF_EVENT
`0xF4860514AD354226` | `int _COUNT_PEDS_AWARE_OF_EVENT(ScrHandle shockingEvent, float x, float y, float z, float radius, int* entities)` | build 1207
Only used in SP Scripts
counts how many peds that the ADD_SHOCKING_EVENT_FOR_ENTITY were add to based on position and radius, p0 is handleId from ADD_SHOCKING_EVENT_FOR_ENTITY
p3 is a collection of entities where max is 15 (in source code), its using itemSet to get them from a volume
this count seems to be used to add a task reactions etc to these peds

## _CREATE_GRAVITY_WELL
`0x4F5EBE70081E5A20` | `int _CREATE_GRAVITY_WELL(float xPos, float yPos, float zPos, float heading, float radius, float p5, float p6, float p7, BOOL stopAtDestination)` | build 1207
Creates a handle to an instance of "CScriptResource_GravityWell", this system forces local ped to target specified position when moving, however player still can interrupt this.
Can be useful to "point" player at some specific position.
Only works while on-foot.

_CREATE_[P-Z]

## _CREATE_META_PED
`0x0BCD4091C8EABA42` | `Ped _CREATE_META_PED(int requestId, float x, float y, float z, float heading, BOOL p5, BOOL p6, BOOL p7, BOOL p8, BOOL p9)` | build 1207
Only used in SP scripts, for example odriscolls1: BOOLS: true, true, true, false, false

## _CREATE_META_PED_ASSET
`0x9641A9A20310F6B8` | `Entity _CREATE_META_PED_ASSET(Hash asset, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, BOOL p7, BOOL p8, BOOL p9)` | build 1207
Creates prop from metaped asset bundle
https://github.com/femga/rdr3_discoveries/blob/master/objects/metaped_asset_bundles_list.lua
Creates a pickup-able metaped component. asset doesn't seems to be related to component hashes. Hash example : 0xD20354AB (https ://i.imgur.com/dzHkcDb.png)

## _CREATE_META_PED_OUTFIT_PED
`0xEAF682A14F8E5F53` | `Ped _CREATE_META_PED_OUTFIT_PED(int requestId, float x, float y, float z, float heading, BOOL p5, BOOL p6, BOOL p7, BOOL p8)` | build 1207
Creates metaped from ped outfit requestId. See _REQUEST_METAPED_OUTFIT

## _DETACH_VOLUME_FROM_ENTITY
`0x19C975B81BE53C28` | `void _DETACH_VOLUME_FROM_ENTITY(Volume volume, Entity entity)` | build 1207

## _DISABLE_ALL_LOOK_AT_REQUESTS
`0xE1965A380342BE1F` | `void _DISABLE_ALL_LOOK_AT_REQUESTS(Ped ped, int p1)` | build 1355

## _DISABLE_AMBIENT_LOOK_AT_REQUESTS
`0x80038740C96AD17F` | `void _DISABLE_AMBIENT_LOOK_AT_REQUESTS(Any p0, Any p1)` | build 1207

## _DOES_META_PED_OUTFIT_EXIST_FOR_PED_MODEL
`0xC0E880B7A441164D` | `BOOL _DOES_META_PED_OUTFIT_EXIST_FOR_PED_MODEL(Hash outfit, Hash model)` | build 1207

## _DOES_META_PED_SUBOUTFIT_EXIST_FOR_PED_MODEL
`0x4FF3C2B4E6A196C1` | `BOOL _DOES_META_PED_SUBOUTFIT_EXIST_FOR_PED_MODEL(Hash outfit, Hash suboutfit, Hash model)` | build 1207

## _EQUIP_META_PED_OUTFIT
`0x1902C4CFCC5BE57C` | `void _EQUIP_META_PED_OUTFIT(Ped ped, Hash hash)` | build 1207
Note: you have to update your ped's variation after calling (using 0xCC8CA3E88256E58F)

Body Types:
MPCREATOR_NEUTRAL
MPCREATOR_SKINNY
MPCREATOR_SKINNY_MUSCULAR
MPCREATOR_HEAVY
MPCREATOR_HEAVY_MUSCULAR

eBodyWeightOutfit (pedattributes.ymt):
-2045421226 (smallest)
-1745814259
-325933489
-1065791927
-844699484
-1273449080
927185840
149872391
399015098
-644349862
1745919061 (default)
1004225511
1278600348
502499352
-2093198664
-1837436619
1736416063
2040610690
-1173634986
-867801909
1960266524 (biggest)

https://github.com/femga/rdr3_discoveries/blob/master/peds_customization/ped_outfits.lua

Alt name: _EQUIP_META_PED_OUTFIT_COMPONENT

## _EQUIP_META_PED_OUTFIT_EXTRA
`0xA5BAE410B03E7371` | `void _EQUIP_META_PED_OUTFIT_EXTRA(Ped ped, int component, Any p2, Any p3)` | build 1207
Changes Multiplayer ped face and body type components, they can be stacked
Params: p3 = 1
Body shape for mp_male from 124 - 128, 110 - 115 for mp_female
Face shape for mp_male from 110 - 123, 96 - 109 for mp_female
Cloth type for mp_male from 0 - 109, 0 - 95 for mp_female

## _EQUIP_META_PED_OUTFIT_PRESET
`0x77FF8D35EEC6BBC4` | `void _EQUIP_META_PED_OUTFIT_PRESET(Ped ped, int presetId, BOOL p2)` | build 1207
Sets the outfit preset for the ped. The presetId is an index which determines its preset outfit. p2 is always false in the scripts.
If p2 is true as player, then certain components like facial hair and hair will not be removed.
Old name: _SET_PED_OUTFIT_PRESET

## _EQUIP_META_PED_SUBOUTFIT
`0x66FF395445A88A6E` | `void _EQUIP_META_PED_SUBOUTFIT(Ped ped, Hash suboutfit, int p2)` | build 1207

## _FAKE_SET_PED_LOCO_INJURED
`0x8B3CB08158E98481` | `void _FAKE_SET_PED_LOCO_INJURED(Ped ped, BOOL enabled)` | build 1207

## _FORCE_PED_DEATH
`0x1CE875505D45338A` | `void _FORCE_PED_DEATH(Ped ped, Ped pedKiller, Hash weapon)` | build 1207

## _GET_ACCURACY_AGAINST_LOCAL_PLAYER_MODIFIER
`0xDC9273D95976BA22` | `float _GET_ACCURACY_AGAINST_LOCAL_PLAYER_MODIFIER(Ped ped)` | build 1207

## _GET_ACTIVE_ANIMAL_OWNER
`0xF103823FFE72BB49` | `Ped _GET_ACTIVE_ANIMAL_OWNER(Ped animal)` | build 1207

## _GET_ACTIVE_DYNAMIC_SCENARIO
`0x569F1E1237508DEB` | `Hash _GET_ACTIVE_DYNAMIC_SCENARIO(Ped ped)` | build 1207
Returns kneeling, sitting, squating, and sleeping scenario hashes

## _GET_ACTIVE_DYNAMIC_SCENARIO_2
`0xC22AA08A8ADB87D4` | `Hash _GET_ACTIVE_DYNAMIC_SCENARIO_2(Ped ped)` | build 1207
Returns kneeling, sitting, squating, and sleeping scenario hashes

## _GET_BLOCKING_OF_NON_TEMPORARY_EVENTS
`0x268B3AEBF032A88D` | `BOOL _GET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Ped ped)` | build 1207

## _GET_CARRIED_ATTACHED_INFO_FOR_SLOT
`0x608BC6A6AACD5036` | `BOOL _GET_CARRIED_ATTACHED_INFO_FOR_SLOT(Any* outData, Ped ped, int carriableSlot, int p3)` | build 1207
Outputs carriable infos for selected ped carriable slot.

Parameters:
- outData: Any* — A structure of 4 explained below
- ped: Ped to check
- carriableSlot: int See TASK_CARRIABLE for available slots
- p3: int always 0 in R* scripts
```lua
struct outData
{
  Hash model;
  Hash carryConfig;
  Hash carriableSlot;
  Entity entityCarried;
}
```

## _GET_CARRIED_PELT_SKINS
`0x6F43C351A5D51E2F` | `int _GET_CARRIED_PELT_SKINS(Ped mount, Any* outData)` | build 1207

## _GET_CARRIER_AS_HUMAN
`0x79443D56C8DF45EE` | `Ped _GET_CARRIER_AS_HUMAN(Entity entity)` | build 1207

## _GET_CARRIER_AS_MOUNT
`0xA033D7E4BBF9844D` | `Ped _GET_CARRIER_AS_MOUNT(Entity entity)` | build 1207

## _GET_CARRIER_AS_PED
`0x09B83E68DE004CD4` | `Ped _GET_CARRIER_AS_PED(Entity entity)` | build 1207

## _GET_CATEGORY_OF_COMPONENT_AT_INDEX
`0x9B90842304C938A7` | `Hash _GET_CATEGORY_OF_COMPONENT_AT_INDEX(Ped ped, int componentIndex, Any p2)` | build 1207

## _GET_CHAR_EXPRESSION
`0xFD1BA1EEF7985BB8` | `float _GET_CHAR_EXPRESSION(Ped ped, int index)` | build 1207
Gets MetaPedExpression at index specified

For index, see: _SET_CHAR_EXPRESSION

Old name: _GET_PED_FACE_FEATURE

## _GET_DEFAULT_RELATIONSHIP_GROUP_HASH
`0x3CC4A718C258BDD0` | `Hash _GET_DEFAULT_RELATIONSHIP_GROUP_HASH(Hash modelHash)` | build 1207

## _GET_FIRST_ENTITY_PED_IS_CARRYING
`0xD806CD2A4F2C2996` | `Entity _GET_FIRST_ENTITY_PED_IS_CARRYING(Ped ped)` | build 1207

## _GET_GROUP_FORMATION
`0x13A1B061007C906B` | `int _GET_GROUP_FORMATION(int groupId)` | build 1207

## _GET_HEALTH_RECHARGE_MULTIPLIER
`0x95B8E397B8F4360F` | `float _GET_HEALTH_RECHARGE_MULTIPLIER(Ped ped)` | build 1207

## _GET_HORSE_TAMING_STATE
`0x454AD4DA6C41B5BD` | `int _GET_HORSE_TAMING_STATE(Ped horse)` | build 1207
Returns an int based on enum eTamingState

enum eTamingState
{
	ATS_INVALID = 0,
	ATS_INACTIVE,
	ATS_TARGET_DETECTED,
	ATS_CALLED_OUT,
	ATS_MOUNTABLE,
	ATS_BEING_PATTED,
	ATS_BREAKING_ACTIVE,
	ATS_SPOOKED,
	ATS_RETREATING,
	ATS_FLEEING
};

## _GET_INCAPACITATION_TIME_REMAINING
`0x88D9D76D78065487` | `int _GET_INCAPACITATION_TIME_REMAINING(Ped ped)` | build 1207

## _GET_IS_PED_BEING_ROBBED
`0xE33F98BD76490ABC` | `BOOL _GET_IS_PED_BEING_ROBBED(Ped ped, Player player, BOOL trueUntilPlayerPocketsItem)` | build 1207
If p2 is false, then this native will return true until the interaction is complete. If true, the native will return true until player pockets robbery item.
_GET_IS_PED_[M-R]*

## _GET_IS_PED_COMMAND_HASH_PRESENT
`0x68821369A2CEADD5` | `BOOL _GET_IS_PED_COMMAND_HASH_PRESENT(Ped ped, Hash commandHash)` | build 1207

## _GET_IS_PED_IN_DISPUTE_WITH_PED
`0x331550B212014B92` | `BOOL _GET_IS_PED_IN_DISPUTE_WITH_PED(Ped ped, Ped pedInDisputeWith)` | build 1207
Returns true if ped is in a dispute another ped (pedInDisputeWith can also be 0)

## _GET_IS_PED_MOTIVATION_STATE_ENABLED
`0x33FA048675821DA7` | `BOOL _GET_IS_PED_MOTIVATION_STATE_ENABLED(Ped ped, int motivationState)` | build 1207
motivationState: see _SET_PED_MOTIVATION

## _GET_LASSOED_LASSOER
`0x0C31C51168E80365` | `Ped _GET_LASSOED_LASSOER(Ped ped)` | build 1207

## _GET_LASSOER_OF_PED
`0x833F0053340EF413` | `Entity _GET_LASSOER_OF_PED(Ped ped)` | build 1207
_IS_PED_S* - _IS_PED_U*

## _GET_LASSO_TARGET
`0xB65A4DAB460A19BD` | `Entity _GET_LASSO_TARGET(Ped ped)` | build 1207

## _GET_LAST_LED_MOUNT
`0x693126B5D0457D0D` | `Ped _GET_LAST_LED_MOUNT(Ped ped)` | build 1232
Returns last horse the ped was leading

## _GET_LAST_MOUNT
`0x4C8B59171957BCF7` | `Ped _GET_LAST_MOUNT(Ped ped)` | build 1207

## _GET_LAST_VEHICLE_DRAFT_HORSE_WAS_ATTACHED_TO
`0x5064DB5083C29921` | `Vehicle _GET_LAST_VEHICLE_DRAFT_HORSE_WAS_ATTACHED_TO(Ped horse)` | build 1207

## _GET_LOOTING_FLAG
`0xE4C11F104620DDCE` | `BOOL _GET_LOOTING_FLAG(Ped ped, int lootFlag)` | build 1207
lootFlag: see SET_LOOTING_FLAG

## _GET_METAPED_OUTFIT_BY_INDEX
`0x62FDF4E678E40CC6` | `int _GET_METAPED_OUTFIT_BY_INDEX(Entity entity, int index)` | build 1207
Returns p1 value for 0x8E84119A23C16623,  get index outfit using GET_NUM_META_PED_OUTFITS

## _GET_META_PED_RACE
`0xB292203008EBBAAC` | `Hash _GET_META_PED_RACE(Ped ped)` | build 1207

## _GET_META_PED_TYPE
`0xEC9A1261BF0CE510` | `int _GET_META_PED_TYPE(Ped ped)` | build 1207
enum eMetaPedType
{
	MPT_MALE,
	MPT_FEMALE,
	MPT_TEEN,
	MPT_ANIMAL,
	MPT_NONE
};

## _GET_NUM_COMPONENTS_IN_PED
`0x90403E8107B60E81` | `int _GET_NUM_COMPONENTS_IN_PED(Ped ped)` | build 1207

## _GET_NUM_COMPONENT_CATEGORIES_IN_PED
`0xA622E66EEE92A08D` | `int _GET_NUM_COMPONENT_CATEGORIES_IN_PED(Ped ped)` | build 1207
Works similar to 0x90403E8107B60E81 (_GET_NUM_COMPONENTS_IN_PED) but is used to get category hashes instead

## _GET_NUM_FREE_SLOTS_IN_PED_POOL
`0x313778EDCA9158E2` | `int _GET_NUM_FREE_SLOTS_IN_PED_POOL()` | build 1207

## _GET_NUM_RESERVED_AMBIENT_PEDS_DESIRED
`0x62DE46F061CAA468` | `int _GET_NUM_RESERVED_AMBIENT_PEDS_DESIRED()` | build 1207

## _GET_NUM_RESERVED_AMBIENT_PEDS_READY
`0x5C16855277819BBF` | `int _GET_NUM_RESERVED_AMBIENT_PEDS_READY()` | build 1207

## _GET_NUM_RESERVED_HEALTH
`0x16F2C8C084AB2092` | `Any _GET_NUM_RESERVED_HEALTH(Ped ped)` | build 1207

## _GET_NUM_RESERVED_STAMINA
`0xFC3B580C4380B5B7` | `int _GET_NUM_RESERVED_STAMINA(Ped ped)` | build 1207
returns the number of reserved stamina similar to _GET_NUM_RESERVED_HEALTH

## _GET_PEDS_IN_COMBAT_WITH_TARGET
`0x7BE607DAFF382FD2` | `int _GET_PEDS_IN_COMBAT_WITH_TARGET(Ped ped, ItemSet itemset, int flag)` | build 1207

## _GET_PED_ATTITUDE
`0x7CC2186C32D3540A` | `int _GET_PED_ATTITUDE(Ped ped, Player player)` | build 1207
AI_ATTITUDE_NEUTRAL = 0,
AI_ATTITUDE_FRIENDLY,
AI_ATTITUDE_WARY,
AI_ATTITUDE_COMBATIVE,
AI_ATTITUDE_NEVER_MET

## _GET_PED_BLACKBOARD_BOOL
`0x498F2E77982D6945` | `BOOL _GET_PED_BLACKBOARD_BOOL(Ped ped, const char* variableName)` | build 1207
Can be used to get a peds foliage active status: variableName = FoliageActive

## _GET_PED_BLACKBOARD_FLOAT
`0x56E58D4D118FB45E` | `float _GET_PED_BLACKBOARD_FLOAT(Ped ped, const char* variableName)` | build 1207
Can be used to get a peds foliage raw height: variableName = FoliageHeight

## _GET_PED_BLACKBOARD_HASH
`0xBF5E791BBBF90A3C` | `Hash _GET_PED_BLACKBOARD_HASH(Ped ped, const char* variableName)` | build 1207

## _GET_PED_BRAWLING_STYLE
`0xEC6B59BE445FEC51` | `Hash _GET_PED_BRAWLING_STYLE(Ped ped)` | build 1207

## _GET_PED_CAN_BE_INCAPACITATED_THIS_FRAME
`0x7A4E00364B5D727B` | `BOOL _GET_PED_CAN_BE_INCAPACITATED_THIS_FRAME(Ped ped)` | build 1207

## _GET_PED_COMBAT_ATTRIBUTE
`0xCC2B20596E29E4E3` | `BOOL _GET_PED_COMBAT_ATTRIBUTE(Ped ped, int attributeIndex)` | build 1207

## _GET_PED_COMPONENT_CATEGORY_BY_INDEX
`0xCCB97B51893C662F` | `Hash _GET_PED_COMPONENT_CATEGORY_BY_INDEX(Ped ped, int index)` | build 1207
Returns category hash that each ped component has. Hash examples: MASKS, HATS, HEADS, HORSE_MANES

## _GET_PED_DAMAGED
`0x6CFC373008A1EDAF` | `BOOL _GET_PED_DAMAGED(Ped ped)` | build 1207
Returns true if _GET_PED_DAMAGE_CLEANLINESS was ever lower than 2

## _GET_PED_DAMAGE_CLEANLINESS
`0x88EFFED5FE8B0B4A` | `int _GET_PED_DAMAGE_CLEANLINESS(Ped ped)` | build 1207
enum ePedDamageCleanliness
{
	PED_DAMAGE_CLEANLINESS_POOR,
	PED_DAMAGE_CLEANLINESS_GOOD,
	PED_DAMAGE_CLEANLINESS_PERFECT
};

## _GET_PED_DEFENSIVE_VOLUME
`0xEF2E6F870783369B` | `Volume _GET_PED_DEFENSIVE_VOLUME(Ped ped, Any p1)` | build 1207

## _GET_PED_DIRT_LEVEL
`0x0105FEE8F9091255` | `float _GET_PED_DIRT_LEVEL(Ped ped, BOOL useCompositeLayer)` | build 1207
Return the dirt level of the ped (0.0 - 1.0). p1 is always set to 1.
The second parameter is treated as a boolean selector (0 or 1). Internally it indexes a 2-slot graphics/appearance bank (base + 0xB8 * index + 0xE4); Rockstar scripts pass 1.

## _GET_PED_DRUNKNESS
`0x6FB76442469ABD68` | `float _GET_PED_DRUNKNESS(Ped ped)` | build 1207
Returns ped drunk level
_H* or _I*

## _GET_PED_GRAPPLER
`0xD0B7AEB56229D317` | `Ped _GET_PED_GRAPPLER(Ped ped)` | build 1207

## _GET_PED_GRAPPLE_FLAG
`0xF3C873ED0C595109` | `int _GET_PED_GRAPPLE_FLAG(Ped ped)` | build 1207

## _GET_PED_GRAPPLE_STYLE
`0x753B15AD0FD6F3E3` | `Hash _GET_PED_GRAPPLE_STYLE(Ped ped)` | build 1207

## _GET_PED_HAS_SIMPLE_PLAYER_MEMORY_CHANGED
`0xC3995D396F1D97B6` | `BOOL _GET_PED_HAS_SIMPLE_PLAYER_MEMORY_CHANGED(Ped ped, int memoryType, int ms)` | build 1207

## _GET_PED_HEARING_RANGE
`0x900CA00CE703E1E2` | `float _GET_PED_HEARING_RANGE(Ped ped)` | build 1207
Returns the hearing range of a ped. To use with SET_PED_HEARING_RANGE

## _GET_PED_HEIGHT
`0x1D491CCF7211FB74` | `float _GET_PED_HEIGHT(Ped ped)` | build 1207

## _GET_PED_ID_RANGE
`0x31167ED4324B758D` | `float _GET_PED_ID_RANGE(Ped ped)` | build 1207

## _GET_PED_INCAPACITATION_HEALTH
`0x89BFDF6D53145545` | `int _GET_PED_INCAPACITATION_HEALTH(Ped ped)` | build 1207

## _GET_PED_INDEX_FROM_PERSCHAR_HASH
`0xE76687023D8C8505` | `Entity _GET_PED_INDEX_FROM_PERSCHAR_HASH(Hash perscharModel, int p1)` | build 1207
Used for AUDIO / ANIMSCENE (REFERENCE_REGIONAL_CHARACTER)
Params: p1 = 0
_GET_PED_IN*

## _GET_PED_INTERACTION_PERSONALITY
`0xD7AD3C7EBAF88C92` | `Hash _GET_PED_INTERACTION_PERSONALITY(Ped ped)` | build 1207

## _GET_PED_LASSO_HOGTIE_FLAG
`0x2C76FA0E01681F8D` | `BOOL _GET_PED_LASSO_HOGTIE_FLAG(Ped ped, int flagId)` | build 1207
https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/Lasso%20Hogtie%20Flags
https://github.com/femga/rdr3_discoveries/tree/master/AI/LASSO_HOGTIE_FLAG

## _GET_PED_LAST_DROPPED_HAT
`0x1F714E7A9DADFC42` | `Object _GET_PED_LAST_DROPPED_HAT(Ped ped)` | build 1207

## _GET_PED_LOD_MULTIPLIER
`0x1B710E6F4AB69341` | `float _GET_PED_LOD_MULTIPLIER(Ped ped)` | build 1355

## _GET_PED_MAX_STAMINA
`0xCB42AFE2B613EE55` | `float _GET_PED_MAX_STAMINA(Ped ped)` | build 1207

## _GET_PED_MELEE_ACTION_PHASE
`0x6127F25ED21C533C` | `float _GET_PED_MELEE_ACTION_PHASE(Ped ped)` | build 1207

## _GET_PED_META_OUTFIT_HASH
`0x30569F348D126A5A` | `Hash _GET_PED_META_OUTFIT_HASH(Ped ped)` | build 1207

## _GET_PED_MODEL_SIZE_FROM_HASH
`0xA65AA1ACE81E5A77` | `int _GET_PED_MODEL_SIZE_FROM_HASH(Hash modelHash)` | build 1311
PS_SMALL = 0,
PS_MEDIUM,
PS_MEDIUM_LARGE,
PS_LARGE,
PS_EXTRA_LARGE

## _GET_PED_MOTIVATION
`0x42688E94E96FD9B4` | `float _GET_PED_MOTIVATION(Ped ped, int motivationState, Ped targetPed)` | build 1207
If targetPed is set to 0 the ped motivationState affects everyone

## _GET_PED_QUALITY
`0x7BCC6087D130312A` | `int _GET_PED_QUALITY(Ped ped)` | build 1207
Returns Ped Quality to be used to calculate Skinning Quality

enum ePedQuality
{
	PQ_INVALID = -1,
	PQ_LOW,
	PQ_MEDIUM,
	PQ_HIGH,
	PQ_MAX
};

## _GET_PED_RAGDOLL_BONE_INDEX
`0xC5303F460A40D21D` | `int _GET_PED_RAGDOLL_BONE_INDEX(Ped ped, int boneId)` | build 1207
Returns boneIndex

## _GET_PED_REGISTER_PROP
`0x4D0D2E3D8BC000EB` | `Entity _GET_PED_REGISTER_PROP(Ped ped, const char* propName, BOOL detachProp)` | build 1207
Gets a registered/attached prop entity for a particular ped. Second parameter will detach the prop entity from the ped if true. Props primarily appear to come from scenarios, such as a broom or hay bale.

Known props: https://pastebin.com/ap2NEJqB

## _GET_PED_REMAINING_REVIVAL_TIME
`0xEBE89623EB861271` | `float _GET_PED_REMAINING_REVIVAL_TIME(Ped ped, BOOL normalized)` | build 1207
normalized / non normalized
0.0        / 1000.0         STARTED IN WRITHE STAGE
1.0        / 0.0            END OF WRITHE, DEAD
-1.0                        DEAD

Returns some value from AI task 562 (unknown).

## _GET_PED_SEEING_RANGE
`0x2BA9D7BF629F920C` | `float _GET_PED_SEEING_RANGE(Ped ped)` | build 1207
Returns the seeing range of a ped. To use with SET_PED_SEEING_RANGE

## _GET_PED_SPEECH_RELATIONSHIP
`0x7C8AA850617651D9` | `Any _GET_PED_SPEECH_RELATIONSHIP(Ped ped, Hash p1)` | build 1207
Returns wether `0x1E017404784AA6A3` was applied on the ped.
 some hashs MAR2_RIDE1, MAR2_RIDE1, RBCH1_RIDE1, SAD5_RIDE1

## _GET_PED_STAMINA
`0x775A1CA7893AA8B5` | `float _GET_PED_STAMINA(Ped ped)` | build 1207

## _GET_PED_STAMINA_NORMALIZED
`0x22F2A386D43048A9` | `float _GET_PED_STAMINA_NORMALIZED(Ped ped)` | build 1207
Returns stamina normalizedValue / normalizedUnlockedMax

## _GET_PED_TRANQUILIZER
`0x65C75FDCCAC86464` | `Ped _GET_PED_TRANQUILIZER(Ped ped)` | build 1355

## _GET_PED_WHO_HOGITIED_THIS_PED
`0x3D9F958834AB9C30` | `Ped _GET_PED_WHO_HOGITIED_THIS_PED(Ped ped)` | build 1207

## _GET_PELT_FROM_HORSE
`0x0CEEB6F4780B1F2F` | `int _GET_PELT_FROM_HORSE(Ped horse, int index)` | build 1207
Returns peltId

## _GET_PLAYER_CURRENT_ANIMAL_DAMAGE_MODIFIER
`0xEE2D5C819A65BF26` | `float _GET_PLAYER_CURRENT_ANIMAL_DAMAGE_MODIFIER(Player player)` | build 1311
Returns animal skin quality modifier

## _GET_PLAYER_DISMOUNT_TIMESTAMP
`0xE8D1CCB9375C101B` | `int _GET_PLAYER_DISMOUNT_TIMESTAMP(Ped mount, Player player)` | build 1207
Returns dismounted timestamp

## _GET_PLAYER_PED_WATER_DEPTH
`0x2942457417A5FD24` | `float _GET_PLAYER_PED_WATER_DEPTH(Ped ped)` | build 1207
Returns how deep the water is below the ped (if in water)
-1.0f = Not in water
10.0f = Max water depth

## _GET_RIDER_OF_MOUNT
`0xB676EFDA03DADA52` | `Ped _GET_RIDER_OF_MOUNT(Ped mount, BOOL p1)` | build 1207

## _GET_SHOP_ITEM_BASE_LAYERS
`0x63342C50EC115CE8` | `BOOL _GET_SHOP_ITEM_BASE_LAYERS(Hash shopItem, Any p1, Ped ped, int metapedType, BOOL p4, Hash* drawable, Hash* albedo, Hash* normal, Hash* material, Hash* p9, Hash* p10, Hash* p11, Hash* p12)` | build 1207

## _GET_SHOP_ITEM_COMPONENT_AT_INDEX
`0x77BA37622E22023B` | `Hash _GET_SHOP_ITEM_COMPONENT_AT_INDEX(Ped ped, int index, BOOL p2, Any* argStruct, Hash* wearableState)` | build 1207
Returns the current shop item component at index and it's wearable state
```lua
local ped = PlayerPedId()
local numComponent = GetNumComponentsInPed(ped)
for index = 0, numComponent -1 do
	local componentHash,_,wearableState = GetShopItemComponentAtIndex(ped, index, true, Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
	print('Index:',index,'Hash:',componentHash,'wearable state:', wearableState)
end
```

## _GET_SHOP_ITEM_COMPONENT_CATEGORY
`0x5FF9A878C3D115B8` | `Hash _GET_SHOP_ITEM_COMPONENT_CATEGORY(Hash componentHash, int metapedType, BOOL isMP)` | build 1207

## _GET_SHOP_ITEM_HAT_COMPONENT
`0x7E02E4218D916B94` | `Any _GET_SHOP_ITEM_HAT_COMPONENT(Ped ped, int metapedType, BOOL p2)` | build 1207

## _GET_SHOP_ITEM_NUM_WEARABLE_STATES
`0xFFCC2DB2D9953401` | `int _GET_SHOP_ITEM_NUM_WEARABLE_STATES(Hash componentHash, BOOL isMpFemale, BOOL p2)` | build 1207
Returns the number of wearable states available for a shop item / component. p2 seems to be true in scripts.

For use with 0x6243635AF2F1B826 (_GET_SHOP_ITEM_AVAILABLE_WEARABLE_STATE_BY_INDEX)

## _GET_SHOP_ITEM_WEARABLE_STATE_BY_INDEX
`0x6243635AF2F1B826` | `Hash _GET_SHOP_ITEM_WEARABLE_STATE_BY_INDEX(Hash componentHash, int wearableStateIndex, BOOL isMpFemale, BOOL p3)` | build 1207
Gets an available wearable state by index for a shop item / component - it does not retreive what the current state is. p3 seems to be true in scripts.

Use 0xFFCC2DB2D9953401 (_GET_SHOP_ITEM_NUM_WEARABLE_STATES) to get the number of available wearable states

## _GET_STAMINA_DEPLETION_MULTIPLIER
`0x825F6DD559A0895B` | `float _GET_STAMINA_DEPLETION_MULTIPLIER(Ped ped)` | build 1207

## _GET_STAMINA_RECHARGE_MULTIPLIER
`0xE7687EB2F634ABF0` | `float _GET_STAMINA_RECHARGE_MULTIPLIER(Ped ped)` | build 1207

## _GET_TOTAL_PED_DAMAGE_FROM_AI
`0x92C8EACA29F6BED6` | `float _GET_TOTAL_PED_DAMAGE_FROM_AI(Ped ped)` | build 1207
_GET_WA*

## _GET_TRANSPORT_PED_IS_SEATED_ON
`0x849BD6C6314793D0` | `Entity _GET_TRANSPORT_PED_IS_SEATED_ON(Ped ped)` | build 1207

## _GET_VEHICLE_DRAFT_HORSE_IS_ATTACHED_TO
`0xE4770DA1B8FF4FD1` | `Vehicle _GET_VEHICLE_DRAFT_HORSE_IS_ATTACHED_TO(Ped horse)` | build 1207

## _GIVE_PED_HASH_COMMAND
`0xD65FDC686A031C83` | `void _GIVE_PED_HASH_COMMAND(Ped ped, Hash commandHash, float activationDuration)` | build 1207
Ped Command Hash are special commands, that can be activated to change conditional anim variations or trigger transitions between conditional anims.
https://github.com/femga/rdr3_discoveries/blob/master/animations/scenarios

## _GIVE_PED_SCENARIO_PROP
`0x3BBDD6143FF16F98` | `BOOL _GIVE_PED_SCENARIO_PROP(Ped ped, Object object, const char* conditionalAnim, const char* p3, const char* p4, BOOL p5)` | build 1207

## _GIVE_PED_SCENARIO_PROP_DYNAMIC
`0xA0774E388CE4A679` | `BOOL _GIVE_PED_SCENARIO_PROP_DYNAMIC(Ped ped, Object object, const char* p2, const char* p3, BOOL p4)` | build 1207
Only used in SP R* Script rcm_jack2

## _HAS_META_PED_ASSET_LOADED
`0xB0B2C6D170B0E8E5` | `BOOL _HAS_META_PED_ASSET_LOADED(int requestId)` | build 1207

## _HAS_META_PED_OUTFIT_LOADED
`0x610438375E5D1801` | `BOOL _HAS_META_PED_OUTFIT_LOADED(int requestId)` | build 1207

## _HAS_META_PED_REQUEST_LOADED
`0xC0940AC858C1E126` | `BOOL _HAS_META_PED_REQUEST_LOADED(int requestId)` | build 1207

## _HAS_PED_BEEN_SHOT_BY_PLAYER_RECENTLY
`0x9C81338B2E62CE0A` | `BOOL _HAS_PED_BEEN_SHOT_BY_PLAYER_RECENTLY(Player player, Ped ped, int duration)` | build 1207
this native checks if player has shot a specific ped for the duration passed p2 is in milliseconds

## _HAS_PED_BEEN_SHOVED_RECENTLY
`0x29FCE825613FEFCA` | `BOOL _HAS_PED_BEEN_SHOVED_RECENTLY(Ped ped, int ms)` | build 1207

## _HAS_PED_EMOTIONAL_PRESET_LOADED
`0xDE3904B22695D9F9` | `BOOL _HAS_PED_EMOTIONAL_PRESET_LOADED(Ped ped, const char* name)` | build 1207
See _REQUEST_PED_EMOTIONAL_PRESET

## _HAS_PED_INTERACTED_WITH_PLAYER_RECENTLY
`0x947E43F544B6AB34` | `BOOL _HAS_PED_INTERACTED_WITH_PLAYER_RECENTLY(Ped ped, Player player, int flag, int ms)` | build 1207
Returns whether a ped has interacted with a player recently.
flags: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/0x947E43F544B6AB34

## _HAS_PED_KNOCKED_ON_DOOR
`0xFA8C10DCE0706D43` | `BOOL _HAS_PED_KNOCKED_ON_DOOR(Ped ped)` | build 1207
Checks whether the specified ped has performed a door knocking interaction
This is typically used together with SET_DOOR_KNOCKING_WHEN_LOCKED.
If a door is configured to use knocking behavior when locked, and the player interacts
with it, this native returns true AFTER the knocking interaction/animation has completed

## _HAS_PED_SHOT_RECENTLY
`0xB7DBB2986B87E230` | `BOOL _HAS_PED_SHOT_RECENTLY(Ped ped, float seconds)` | build 1207

## _HAS_PED_TAKEN_GORE_DAMAGE
`0xBA208A8D6399A3AC` | `BOOL _HAS_PED_TAKEN_GORE_DAMAGE(Ped ped, int limb)` | build 1207
limb: 3 = Left Hand, 4 = Left Arm, 6 = Right Hand, 7 = Right Arm, 9 = Left Foot, 10 = Left Leg, 12 = Right Foot, 13 = Right Leg, 37 = Head

## _HIDE_MOUNT_REINS
`0xCAC43D060099EA72` | `void _HIDE_MOUNT_REINS(Ped mount)` | build 1207
Hides the reins of the mount

## _HORSE_AGITATE
`0xBAE08F00021BFFB2` | `void _HORSE_AGITATE(Ped mount, BOOL kickOffRider)` | build 1207
_H* - _I*

## _INCAPACITATED_REVIVE
`0xF6262491C7704A63` | `void _INCAPACITATED_REVIVE(Ped ped, Ped ped2)` | build 1207

## _IS_ANIMAL_CONTROLLED_BY_A_PLAYER
`0x0E2F43516F998269` | `BOOL _IS_ANIMAL_CONTROLLED_BY_A_PLAYER(Ped ped)` | build 1311
Returns true only if it's a player ped and an animal as well.
_IS_ANY_* - _IS_CONTROL_*

## _IS_ANIMAL_INTERACTION_RUNNING
`0x7FC84E85D98F063D` | `BOOL _IS_ANIMAL_INTERACTION_RUNNING(Ped ped)` | build 1207

## _IS_ANIMAL_SKINNED
`0x88A5564B19C15391` | `BOOL _IS_ANIMAL_SKINNED(Ped ped)` | build 1207

## _IS_META_PED_ASSET_VALID
`0x93FFD92F05EC32FD` | `BOOL _IS_META_PED_ASSET_VALID(int requestId)` | build 1207

## _IS_META_PED_FISH
`0x118D476A6F1A13F1` | `BOOL _IS_META_PED_FISH(Ped ped)` | build 1207
Returns true if given ped is a fish.
_IS_ME* - _IS_MO*

## _IS_META_PED_OUTFIT_EQUIPPED
`0x98082246107A6ACF` | `BOOL _IS_META_PED_OUTFIT_EQUIPPED(Ped ped, Hash outfit)` | build 1207
Used in script function HORSE_IS_META_PED_OUTFIT_SADDLE_EQUIPPED

## _IS_META_PED_OUTFIT_REQUEST_VALID
`0xB25E57FC8E37114D` | `BOOL _IS_META_PED_OUTFIT_REQUEST_VALID(int requestId)` | build 1207

## _IS_META_PED_REQUEST_VALID
`0x43E4DA469541A9C9` | `BOOL _IS_META_PED_REQUEST_VALID(int requestId)` | build 1207

## _IS_META_PED_USING_COMPONENT_CATEGORY
`0xFB4891BD7578CDC1` | `BOOL _IS_META_PED_USING_COMPONENT_CATEGORY(Ped ped, Hash componentCategory)` | build 1207
checks if a ped is using a component category
see component category hashes here https://raw.githubusercontent.com/femga/rdr3_discoveries/refs/heads/master/clothes/cloth_hash_names.lua
Old name: _IS_META_PED_USING_COMPONENT

## _IS_MOUNT_SEAT_FREE
`0xAAB0FE202E9FC9F0` | `BOOL _IS_MOUNT_SEAT_FREE(Ped mount, int seat)` | build 1207

## _IS_PED_ACTION_DISABLE_FLAG_ENABLED
`0xB346C85D49CC998E` | `BOOL _IS_PED_ACTION_DISABLE_FLAG_ENABLED(Ped ped, int actionDisableFlag)` | build 1207

## _IS_PED_AFLOAT
`0xDC88D06719070C39` | `BOOL _IS_PED_AFLOAT(Ped ped)` | build 1207
detects if ped is afloat in water like swimming or in a boat (driving or standing on it)

## _IS_PED_CHILD
`0x137772000DAF42C5` | `BOOL _IS_PED_CHILD(Ped ped)` | build 1207

## _IS_PED_CLIMBING_LADDER
`0x59643424B68D52B5` | `BOOL _IS_PED_CLIMBING_LADDER(Ped ped)` | build 1207

## _IS_PED_COWERING
`0xB086C8C0F5701D14` | `BOOL _IS_PED_COWERING(Ped ped)` | build 1207

## _IS_PED_DOING_SCENARIO_TRANSITION
`0xC488B8C0E52560D8` | `BOOL _IS_PED_DOING_SCENARIO_TRANSITION(Ped ped)` | build 1207

## _IS_PED_DRAGGING
`0x226CF9B159E38F42` | `BOOL _IS_PED_DRAGGING(Ped ped)` | build 1207

## _IS_PED_DRUNK
`0x50F124E6EF188B22` | `BOOL _IS_PED_DRUNK(Ped ped)` | build 1207

## _IS_PED_INTIMIDATED
`0x57779B55B83E2BEA` | `BOOL _IS_PED_INTIMIDATED(Ped ped)` | build 1207

## _IS_PED_INVESTIGATING
`0x7583A9D35248B83F` | `BOOL _IS_PED_INVESTIGATING(Ped ped)` | build 1207
_IS_PED_IN*

## _IS_PED_IN_POINT
`0x078076AB50FB117F` | `BOOL _IS_PED_IN_POINT(Ped ped, float x, float y, float z, float radius, BOOL p5)` | build 1207
If returned true: There are enemy peds near friendly turn in ped. Going to aggro.
If returned false: Moving back to idle as there aren't any remaining enemy peds near ped
_IS_PED_IN_*

## _IS_PED_LEADING_ANY_GROUP
`0x917760CFE7A0E0F1` | `BOOL _IS_PED_LEADING_ANY_GROUP(Ped ped)` | build 1207
_IS_PED_L* - _IS_PED_M*

## _IS_PED_MODEL_SUPPRESSED
`0xAA9F048DCF69B6DC` | `BOOL _IS_PED_MODEL_SUPPRESSED(Hash model)` | build 1207

## _IS_PED_QUEUED_FOR_DELETION
`0x8D9BFCE3352DE47F` | `BOOL _IS_PED_QUEUED_FOR_DELETION(Ped ped)` | build 1207

## _IS_PED_SLIDING
`0xD6740E14E4CEFC0B` | `BOOL _IS_PED_SLIDING(Ped ped)` | build 1207

## _IS_PED_TARGET_ACTION_DISABLE_FLAG_ENABLED
`0x02AA2096FE00F3E1` | `BOOL _IS_PED_TARGET_ACTION_DISABLE_FLAG_ENABLED(Ped ped, int actionDisableFlag)` | build 1207

## _IS_PED_USING_ACTION_MODE_2
`0xEBB208D6AE712C03` | `BOOL _IS_PED_USING_ACTION_MODE_2(Ped ped)` | build 1207

## _IS_PED_VISIBILITY_TRACKED
`0x5102307CE88798EB` | `BOOL _IS_PED_VISIBILITY_TRACKED(Ped ped)` | build 1207

## _IS_SCENARIO_BLOCKING_AREA_VALID
`0x91A5F9CBEBB9D936` | `BOOL _IS_SCENARIO_BLOCKING_AREA_VALID(Any p0)` | build 1207

## _IS_TARGET
`0x6E5CBCB3941D7D08` | `BOOL _IS_TARGET(Ped ped, Ped targetPed)` | build 1207

## _IS_TEXTURE_VALID
`0x31DC8D3F216D8509` | `BOOL _IS_TEXTURE_VALID(int textureId)` | build 1207

## _IS_THIS_MODEL_A_HORSE
`0x772A1969F649E902` | `BOOL _IS_THIS_MODEL_A_HORSE(Hash model)` | build 1207

## _IS_TRACKED_PED_VISIBILITY_PERCENTAGE_NOT_LESS_THAN
`0x164CECC59E70DF86` | `BOOL _IS_TRACKED_PED_VISIBILITY_PERCENTAGE_NOT_LESS_THAN(Ped ped, float percent)` | build 1207

## _IS_USING_SLIPSTREAM
`0xAF61B3CD8C3B82C3` | `BOOL _IS_USING_SLIPSTREAM(Ped ped)` | build 1207
_IS_TRACKED_* - IS_V*

## _PED_APPLY_SPEECH_RELATIONSHIP
`0x1E017404784AA6A3` | `BOOL _PED_APPLY_SPEECH_RELATIONSHIP(Ped ped, Hash p1)` | build 1207
something to do with speech lines? 
 some hashs MAR2_RIDE1, MAR2_RIDE1, RBCH1_RIDE1, SAD5_RIDE1

## _PED_CLEAR_LOCO_MOTION
`0x935CF6E42BAF7F4D` | `void _PED_CLEAR_LOCO_MOTION(Ped ped)` | build 1207

## _PED_DUELING_DID_PLAYER_HEADSHOT_OPPONENT
`0xBD6B242B8BD5543A` | `BOOL _PED_DUELING_DID_PLAYER_HEADSHOT_OPPONENT(Ped ped)` | build 1207

## _PED_EMOTIONAL_PRESET_LOCO_MOTION
`0xAAB050DA48B57978` | `void _PED_EMOTIONAL_PRESET_LOCO_MOTION(Ped ped, const char* presetName, Ped targetPed, int duration, int flag)` | build 1207
target: 0 affects everyone
duration: -1 indefinite
flag: always 4 in R* Scripts

## _PED_REMOVE_SPEECH_RELATIONSHIP
`0x2B4CE170DE09F346` | `void _PED_REMOVE_SPEECH_RELATIONSHIP(Ped ped, Hash p1)` | build 1207

## _PED_SET_SIMPLE_PLAYER_MEMORY
`0xC494C76A34266E82` | `void _PED_SET_SIMPLE_PLAYER_MEMORY(Ped ped, int memoryType)` | build 1207
memoryType: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/_PED_SET_SIMPLE_PLAYER_MEMORY

## _PED_WAS_KILLED_BY_HEADSHOT
`0x06FA94C835787C64` | `BOOL _PED_WAS_KILLED_BY_HEADSHOT(Ped ped)` | build 1207

## _PLAY_CONDITIONAL_ANIM_WITH_PROPITEM
`0xCE7A6C1D5CDE1F9D` | `void _PLAY_CONDITIONAL_ANIM_WITH_PROPITEM(Ped ped, Object object, char* propItemName, char* conditionalAnimName)` | build 1207
Plays a conditional locomotion animation with an attached prop item,commonly used for LOCO attachment interactions (e.g., attaching/carrying a crate) ex conditionalAnimName: LOCO_ATTACH_CRATE_TNT

## _REFRESH_CARRIED_PED_FOR_PED
`0x6B67320E0D57856A` | `void _REFRESH_CARRIED_PED_FOR_PED(Ped ped, Any* carriedPed, int p2, BOOL p3)` | build 1207
Retruns the carried ped
```lua
local carriedPed = Citizen.InvokeNative(0x6B67320E0D57856A, PlayerPedId(), Citizen.PointerValueInt(), 2,false)
```

## _REFRESH_LOOT_STATE_FOR_PED
`0x5463C962BC7777C3` | `int _REFRESH_LOOT_STATE_FOR_PED(Ped ped, int p1, Ped* lootTarget, int p3, int p4)` | build 1207
Returns loot state
enum eLootState
{
	LAP_NONE,
	LAP_RESUMING,
	LAP_GETTING_ON_FOOT,
	LAP_DISTANT_NAV,
	LAP_CHOOSING_ACTION,
	LAP_APPROACHING,
	LAP_ENTERING,
	LAP_LOOTING,
	LAP_EXITING
};

_POSSE_* - _REGISTER_HATED*

## _REFRESH_META_PED_SHOP_ITEMS
`0x59BD177A1A48600A` | `void _REFRESH_META_PED_SHOP_ITEMS(Ped ped, int p1)` | build 1207
p1 is always 1

## _REGISTER_HATED_TARGETS_IN_AREA
`0xD8736EFDA38EDC5C` | `void _REGISTER_HATED_TARGETS_IN_AREA(Ped ped, float x, float y, float z, float radius)` | build 1207

## _RELEASE_META_PED_ASSET_REQUEST
`0x13E7320C762F0477` | `void _RELEASE_META_PED_ASSET_REQUEST(int requestId)` | build 1207

## _RELEASE_META_PED_OUTFIT_REQUEST
`0x4592B8B9B0EF5F48` | `void _RELEASE_META_PED_OUTFIT_REQUEST(int requestId)` | build 1207

## _RELEASE_META_PED_REQUEST
`0x3972F78A78B5D9DF` | `void _RELEASE_META_PED_REQUEST(int requestId)` | build 1207

## _RELEASE_TEXTURE
`0x6BEFAA907B076859` | `void _RELEASE_TEXTURE(int textureId)` | build 1207
Removes a texture created by 0xC5E7204F322E49EB.

## _REMOVE_GRAVITY_WELL
`0x87247BC60B60BED8` | `void _REMOVE_GRAVITY_WELL(int handle)` | build 1207
Removes gravity well by handle returned from 0x4F5EBE70081E5A20

## _REMOVE_MOTION_TYPE_ASSET
`0xDE7B2B4144906CDF` | `void _REMOVE_MOTION_TYPE_ASSET(Hash nameHash, Ped ped)` | build 1207

## _REMOVE_PED_BLACKBOARD_BOOL
`0xA6F67BEC53379A32` | `void _REMOVE_PED_BLACKBOARD_BOOL(Ped ped, const char* variableName)` | build 1207

## _REMOVE_PED_BLACKBOARD_FLOAT
`0x411189E51B8020BA` | `void _REMOVE_PED_BLACKBOARD_FLOAT(Ped ped, const char* variableName)` | build 1207

## _REMOVE_PED_BLACKBOARD_HASH
`0x0E17378642156790` | `void _REMOVE_PED_BLACKBOARD_HASH(Ped ped, const char* variableName)` | build 1207

## _REMOVE_PED_BLACKBOARD_INT
`0x81B75428A7813E67` | `void _REMOVE_PED_BLACKBOARD_INT(Ped ped, const char* variableName)` | build 1207

## _REMOVE_PED_EMOTIONAL_PRESET
`0xFC3BAB1801A8255A` | `void _REMOVE_PED_EMOTIONAL_PRESET(Ped ped, const char* name)` | build 1207
See _REQUEST_PED_EMOTIONAL_PRESET

## _REMOVE_PED_FROM_MOUNT
`0x5337B721C51883A9` | `void _REMOVE_PED_FROM_MOUNT(Ped ped, BOOL p1, BOOL p2)` | build 1207

## _REMOVE_PED_OVERLAY
`0x96C349DE04C49011` | `void _REMOVE_PED_OVERLAY(int textureId, int overlayId)` | build 1207

## _REMOVE_PED_PROPITEM_CONDITONAL_ANIM
`0x3A50753042B6891B` | `void _REMOVE_PED_PROPITEM_CONDITONAL_ANIM(Ped ped, char* propItemName)` | build 1207
Stops and clears a running conditional locomotion animation previously started by _PLAY_CONDITIONAL_ANIM_WITH_PROPITEM ex: P_CS_CRATETNT01X_PH_R_HAND
This does not remove the physical prop entity itself, but rather ends the active locomotion/conditional animation associated with it.

## _REMOVE_PED_STAY_OUT_VOLUME
`0x0CAB404CD2DB41F5` | `BOOL _REMOVE_PED_STAY_OUT_VOLUME(Ped ped, Volume volume)` | build 1207

## _REMOVE_PED_SUBSCRIBE_TO_LEGENDARY_BLIPS
`0x011A42FD923D41CA` | `BOOL _REMOVE_PED_SUBSCRIBE_TO_LEGENDARY_BLIPS(Ped ped)` | build 1311

## _REMOVE_SHOP_ITEM_FROM_PED
`0x0D7FFA1B2F69ED82` | `void _REMOVE_SHOP_ITEM_FROM_PED(Ped ped, Hash componentHash, int p2, BOOL p3)` | build 1355
Directly removes a shop item component from a ped
Params: p2 and p3 are always 0

## _REMOVE_TARGET
`0x4707E9C23D8CA3FE` | `void _REMOVE_TARGET(Ped ped, Ped targetPed)` | build 1207

## _REQUEST_META_PED
`0xF97C34C33487D569` | `int _REQUEST_META_PED(Hash model, int p1)` | build 1207
Returns requestId
Params: p1 = 1 in R* Scripts (Used in SP only)

## _REQUEST_META_PED_ASSET_BUNDLE
`0x91FE941F9FCFB702` | `int _REQUEST_META_PED_ASSET_BUNDLE(Hash asset, int p1)` | build 1207
Returns requestId
Params: p1 = 1 in R* Scripts

## _REQUEST_META_PED_COMPONENT
`0xF6D9E1F3560CBF8E` | `Any _REQUEST_META_PED_COMPONENT(int metaPedType, Any p1, int p2, int p3, int p4)` | build 1207

## _REQUEST_META_PED_OUTFIT
`0x13154A76CE0CF9AB` | `int _REQUEST_META_PED_OUTFIT(Hash model, Hash outfit)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/clothes/metaped_outfits.lua
Returns requestId, to be used with 0x74F512E29CB717E2

## _REQUEST_MOTION_TYPE_ASSET
`0xF7EA250B9A919E03` | `void _REQUEST_MOTION_TYPE_ASSET(Hash nameHash, Ped ped)` | build 1207

## _REQUEST_PED_CARRYING_STATE
`0x4642182A298187D0` | `int _REQUEST_PED_CARRYING_STATE(Ped ped, int carryingType, int* outEntities, int outEntsCount, int filterFlags)` | build 1207
Return the status of the wanted carrying action of a ped. unk3 is usually 4.You can also get the entity being carried and the entity it was taken from with a buffer.

Status:
`INVALID = 0,
STARTING = 1,
PROGRESSING = 2,
FINISHING = 3`
CARRYING TYPES:
`UNK_0 = -1,
UNK_1 = 0,
UNK_2 = 1,
UNK_3 = 2,
UNK_4 = 3,
CARRYING_FROM_GROUND = 4,
CARRYING_FROM_MOUNT = 5,
PUTTING_DOWN_GROUND = 6,
PUTTING_DOWN_MOUNT = 7,
UNK_9 = 8,
UNK_10 = 9,
UNK_11 = 10`
Filters:
`ENTITY_ONLY = 0,
NOTHING = 1,
ENTITY_AND_TAKEN_FROM_ENTITY = 2`
```lua
local retval, entity = Citizen.InvokeNative(0x4642182A298187D0, PlayerPedId(), 1, Citizen.PointerValueInt(), 4, 0, Citizen.ResultAsInteger())
local struct = DataView.ArrayBuffer(2*8)
local retval = Citizen.InvokeNative(0x4642182A298187D0, PlayerPedId(), 5, struct:Buffer(), 4, 2, Citizen.ResultAsInteger())
if retval ~= 0 then
local entity = struct:GetInt32(0*8)
local fromEntity = struct:GetInt32(1*8)
end
```

## _REQUEST_PED_EMOTIONAL_PRESET
`0x5C3C55EAAD19915F` | `void _REQUEST_PED_EMOTIONAL_PRESET(Ped ped, const char* name)` | build 1207
For more information, see common:/data/emotional_presets.meta

## _REQUEST_PED_FACIAL_MOOD_THIS_FRAME
`0x8B3B71C80A29A4BB` | `void _REQUEST_PED_FACIAL_MOOD_THIS_FRAME(Ped ped, Hash mood, int p2)` | build 1207
mood: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/fwFacialAnimRequest__Mood
Params: p2 = 6 in R* Scripts

## _REQUEST_PED_FOR_SCENARIO_TYPE
`0xBDED916A9F9B0604` | `Any _REQUEST_PED_FOR_SCENARIO_TYPE(Ped ped, Object object, const char* p2, Hash scenarioType, const char* p4, BOOL p5)` | build 1207

## _REQUEST_PED_GETUP_ANIMATION
`0xEAA8242C8479C27D` | `void _REQUEST_PED_GETUP_ANIMATION(Ped ped, const char* getUpType)` | build 1207
Known get up animation types: REAR, FRONT

## _REQUEST_PROP_SCENARIO_PED
`0xBEC65C6049B3219D` | `Any _REQUEST_PROP_SCENARIO_PED(Ped ped, Object object, char* p2, char* p3, char* p4, BOOL p5)` | build 1207

## _REQUEST_TEXTURE
`0xC5E7204F322E49EB` | `int _REQUEST_TEXTURE(Hash albedoHash, Hash normalHash, Hash materialHash)` | build 1207
Creates a texture override data for ped and returns it's index.
So you can replace any texture of any ped's component.
Also, you can add overlays on it, such as aging, lipstick and more.
Textures can be reused by multiple peds at once.
You can keep only 32 textures at once(including other peds).

https://github.com/femga/rdr3_discoveries/blob/master/clothes/change_overlays_script.lua
materialHash: https://github.com/femga/rdr3_discoveries/blob/master/clothes/cloth_drawable_albedo_normal_material_TEMPORARY.lua

## _RESERVE_AMBIENT_PEDS
`0xED9582B3DA8F02B4` | `void _RESERVE_AMBIENT_PEDS(int numPeds)` | build 1207

## _RESERVE_AMBIENT_PEDS_TOTAL
`0xF008E0BA1FE1D644` | `void _RESERVE_AMBIENT_PEDS_TOTAL(int numPeds)` | build 1207

## _RESET_PED_COMPONENTS
`0x0BFA1BD465CDFEFD` | `void _RESET_PED_COMPONENTS(Ped ped)` | build 1207

## _RESET_PED_INCAPACITATION_BLEED_OUT_DURATION
`0x4B9668DB91DC39B8` | `void _RESET_PED_INCAPACITATION_BLEED_OUT_DURATION(Ped ped)` | build 1207

## _RESET_PED_LADDER_MOVEMENT_SPEED_MODIFIER
`0x801917E7D7BCE418` | `void _RESET_PED_LADDER_MOVEMENT_SPEED_MODIFIER(Ped ped)` | build 1207

## _RESET_PED_STAMINA
`0x36513AFFC703C60D` | `void _RESET_PED_STAMINA(Ped ped)` | build 1207
Seems to set the peds stamina to 30%

## _RESET_PED_TEXTURE
`0x8472A1789478F82F` | `void _RESET_PED_TEXTURE(int textureId)` | build 1207
Removes every texture layer but the base layer
Clearing texture's data: setting params to default values, but keep overlays.

## _RESTORE_PED_STAMINA
`0x675680D089BFA21F` | `void _RESTORE_PED_STAMINA(Ped ped, float stamina)` | build 1207
0.0 <= stamina <= 100.0

## _SET_ACCURACY_AGAINST_LOCAL_PLAYER_MODIFIER
`0xC2266AA617668AD3` | `void _SET_ACCURACY_AGAINST_LOCAL_PLAYER_MODIFIER(Ped ped, float modifier)` | build 1207

## _SET_ACTIVE_META_PED_COMPONENTS_UPDATED
`0xAAB86462966168CE` | `Any _SET_ACTIVE_META_PED_COMPONENTS_UPDATED(Ped ped, BOOL isMP)` | build 1207
Related to _0x704C908E9C405136 for component loading
Can be used to fix missing outfit changes, always paired with _UPDATE_PED_VARIATION
_S*
Doesn't actually return anything.

## _SET_AMBIENT_ANIMAL_DENSITY_MULTIPLIER_THIS_FRAME
`0xC0258742B034DFAF` | `void _SET_AMBIENT_ANIMAL_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## _SET_AMBIENT_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME
`0xBA0980B5C0A11924` | `void _SET_AMBIENT_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## _SET_AMBIENT_PED_DENSITY_MULTIPLIER_THIS_FRAME
`0xAB0D553FE20A6E25` | `void _SET_AMBIENT_PED_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## _SET_CHAR_EXPRESSION
`0x5653AB26C82938CF` | `void _SET_CHAR_EXPRESSION(Ped ped, int index, float value)` | build 1207
Sets MetaPedExpression at index specified. Morphs components, such as changing body size or facial features.

Note: You have to update the ped's variation (using 0xCC8CA3E88256E58F) after calling this native

index = MetaPedExpression IDs
List of face features: https://pastebin.com/9jb88FXW
Full list of MetaPedExpressions: https://pastebin.com/Ld76cAn7
value: -1.0 to 1.0 (values beyond this likely won't sync to other clients)

This native also allows you to change a horse's gender.

Old name: _SET_PED_FACE_FEATURE

## _SET_CURRENT_DEFENSE_AGAINST_PLAYERS_MODIFIER
`0x069EDDF1FD4DEB0A` | `void _SET_CURRENT_DEFENSE_AGAINST_PLAYERS_MODIFIER(Ped horse, float modifier)` | build 1207

## _SET_DEFENSE_MODIFIER_FOR_PED
`0x9B6808EC46BE849B` | `void _SET_DEFENSE_MODIFIER_FOR_PED(Ped ped, float modifier)` | build 1207

## _SET_FORMATION_AUTO_ASSIGN_POSITION
`0x478F6B9920446CE2` | `void _SET_FORMATION_AUTO_ASSIGN_POSITION(int groupId, BOOL toggle)` | build 1207

## _SET_HEALTH_RECHARGE_MULTIPLIER
`0xDE1B1907A83A1550` | `void _SET_HEALTH_RECHARGE_MULTIPLIER(Ped ped, int multiplier)` | build 1207

## _SET_HORSE_SCRIPTED_FLAG
`0xB8AB265426CFE6DD` | `void _SET_HORSE_SCRIPTED_FLAG(Ped ped, BOOL toggle)` | build 1207
Sets some flag on a horse

## _SET_INTERACTION_LOCKON_FLAG
`0xFECA2081F61ED2CD` | `void _SET_INTERACTION_LOCKON_FLAG(Ped ped, Player player, int flag, BOOL enable)` | build 1207

## _SET_META_PED_TAG
`0xBC6DF00D7A4A6819` | `void _SET_META_PED_TAG(Ped ped, Hash drawable, Hash albedo, Hash normal, Hash material, Hash palette, int tint0, int tint1, int tint2)` | build 1207
Use to apply metaped player components
Replaces asset, alternatively you can remove assets using REMOVE_TAG_FROM_META_PED

## _SET_META_PED_WEARINESS
`0x314C5465195F3B30` | `void _SET_META_PED_WEARINESS(Ped ped, float weariness)` | build 1207
Sets ped eye redness, weariness: 0.f to 1.f

## _SET_MIN_PED_HEALTH_THRESHOLD
`0x7883AA809DF43D98` | `void _SET_MIN_PED_HEALTH_THRESHOLD(Ped ped, float healthAmount)` | build 1355

## _SET_MOUNT_BONDING_LEVEL
`0xA69899995997A63B` | `void _SET_MOUNT_BONDING_LEVEL(Ped ped, int bondingLevel)` | build 1207

## _SET_MOUNT_SECURITY_ENABLED
`0x11E6B9629C46D6EC` | `void _SET_MOUNT_SECURITY_ENABLED(Ped ped, BOOL toggle)` | build 1232
Note: this native was added in build 1232.40

## _SET_PED_ACTION_DISABLE_FLAG
`0xB8DE69D9473B7593` | `void _SET_PED_ACTION_DISABLE_FLAG(Ped ped, int actionDisableFlag)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/AI/COMBAT_ACTION_DISABLE_FLAGS

## _SET_PED_ACTIVATE_WOUND_EFFECT
`0xFFD54D9FE71B966A` | `void _SET_PED_ACTIVATE_WOUND_EFFECT(Ped ped, int p1, int boneId, float moveWoundLeftRight, float bloodFountainPressure, float yaw, float bloodFountainDirection, float bloodFountainPulse, float p8, float p9)` | build 1207
bloodFountainPressure: visible effect from 0.0 till 20.0
yaw: visible effect from -3.0 till 3.0
bloodFountainDirection: 1.0 left side, -1.0 right side
bloodFountainPulse: from 0.1 (low) till 1.0 (fast)
make blood fountain from your stomach: _SET_PED_ACTIVATE_WOUND_EFFECT(ped, unk, 2, 14411, 0.0, 0.1, 0.0, 0.0, 3.0, -1.0, 1.0)

## _SET_PED_ACTIVE_PLAYER_TYPE
`0xB285AD0EC870B2DF` | `void _SET_PED_ACTIVE_PLAYER_TYPE(Ped ped, Hash playerType)` | build 1207
Params: hash - ARTHUR or JOHN
_SET_PED_(A-D)*

## _SET_PED_ANIMAL_DETECTION_MODIFIER
`0x43CA928E892CFDB8` | `void _SET_PED_ANIMAL_DETECTION_MODIFIER(Ped ped, float modifier)` | build 1311

## _SET_PED_BEAT_MULTIPLIER
`0x6DBF2D78709AD70B` | `void _SET_PED_BEAT_MULTIPLIER(Ped ped, float p1)` | build 1207
NET_FETCH_CLIENT_UPDATE_PED_FIGHT_PROFICIENCY: Changing parry multiplier for ped

## _SET_PED_BLACKBOARD_BOOL
`0xCB9401F918CB0F75` | `void _SET_PED_BLACKBOARD_BOOL(Ped ped, char* variableName, BOOL value, int removeTimer)` | build 1207

## _SET_PED_BLACKBOARD_FLOAT
`0x437C08DB4FEBE2BD` | `void _SET_PED_BLACKBOARD_FLOAT(Ped ped, char* variableName, float value, int removeTimer)` | build 1207

## _SET_PED_BLACKBOARD_HASH
`0xA762C9D6CF165E0D` | `void _SET_PED_BLACKBOARD_HASH(Ped ped, char* variableName, char* value, int removeTimer)` | build 1207
p1:
BodyPartChained
OverloadMostInjuredBodyPart

p2:
LeftLeg
Legs
RightArm

## _SET_PED_BLACKBOARD_INT
`0x5F53010C4C3F6BAF` | `void _SET_PED_BLACKBOARD_INT(Ped ped, char* variableName, int value, int removeTimer)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/AI/BLACKBOARDS
Blackboard natives allow you to apply and check certain data to/for peds.
Blackboard bools, floats and strings are subdivided into 6 sections: "all", "animation", "any", "code", "global" and "script"
Most changes are only visible for "script" blackboards, some "script" blackboards change ped motions
"removeTimer" is self-removal timer, can be "-1" so your data will not be removed by the game (forever); 100 = 1 second

## _SET_PED_BLEEDOUT_PROFILE
`0x66C047719B0E80E1` | `void _SET_PED_BLEEDOUT_PROFILE(Ped ped, Hash bleedoutProfile)` | build 1207
Bleedout profiles:
Animal_FastBleedout
Animal_Generic
Human_FastBleedout
Human_Generic
Human_Mission

For more information, see common/data/ai/peddamageinfo.meta

## _SET_PED_BRAWLING_STYLE
`0x8BA83CC4288CD56D` | `void _SET_PED_BRAWLING_STYLE(Ped ped, Hash brawlingStyle)` | build 1207
brawlingStyle:
enum eBrawlingStyle : Hash
{
	BS_AI = 0x802C604D,
	BS_AI_BARBRAWL = 0x4FF5F0C7,
	BS_AI_DEFENSIVE = 0xD888F2FD,
	BS_AI_MOONSHINE_BARBRAWL = 0xA01B433A,
	BS_ALLIGATOR = 0x7A5548ED,
	BS_ALLIGATOR_LARGE = 0x368EC7CB,
	BS_ALLY = 0x69C76C14,
	BS_ANIMAL = 0xD777C754,
	BS_BADGER = 0x7E7C3F53,
	BS_BEAR = 0x0BC66E35,
	BS_BEAVER = 0x4E313783,
	BS_BOAR = 0x176A5831,
	BS_BOUNTY_HUNTER = 0x3900654C,
	BS_BRUISER = 0x4514DB61,
	BS_BULL = 0x4E50C5D2,
	BS_COUGAR = 0x9DAA7CCB,
	BS_COW = 0xB0E91295,
	BS_COYOTE = 0xA448EB69,
	BS_DEER = 0xA781E6B3,
	BS_DOG = 0x5A4155C4,
	BS_ELK = 0x408697F0,
	BS_FEMALE = 0x6A3BB2C2,
	BS_FEMALE_STRONG = 0x4DAFDD84,
	BS_GANGUP = 0xD0CECFF2,
	BS_GOAT = 0x078E649F,
	BS_HORSE = 0xF6B775F3,
	BS_MICAH_FINALE = 0x1F0BB27A,
	BS_MOOSE = 0x968917AB,
	BS_MUSKRAT = 0x1EDC33AC,
	BS_NO_MELEE = 0x25B5F931,
	BS_PIG = 0x22EAD110,
	BS_PLAYER = 0x78BAEF07,
	BS_PLAYER_FINALE = 0xF9E77D2D,
	BS_PLAYER_MOONSHINER = 0x687BF19F,
	BS_PLAYER_WINTER1 = 0x3C6A802F,
	BS_QUICK = 0xC4CABB1B,
	BS_RACCOON = 0x505F8917,
	BS_SHEEP = 0x6827CCCF,
	BS_SNAKE = 0x82BEBC4B,
	BS_TIMID = 0x431AEF77,
	BS_WOLF = 0xA8F023D4
};

## _SET_PED_CAN_BE_LASSOED
`0xFD6943B6DF77E449` | `void _SET_PED_CAN_BE_LASSOED(Ped ped, BOOL toggle)` | build 1207
SET_PED_CAN_*

## _SET_PED_COMBAT_ATTRIBUTE_HASH
`0xBD75500141E4725C` | `void _SET_PED_COMBAT_ATTRIBUTE_HASH(Ped ped, Hash p1)` | build 1207
Hashes: GUARD, COMBAT_ANIMAL, LAW, LAW_SHERIFF
_SET_PED_COMBAT_A* - _SET_PED_COMBAT_M*

## _SET_PED_COMBAT_BEHAVIOUR
`0x9238A3D970BBB0A9` | `void _SET_PED_COMBAT_BEHAVIOUR(Ped ped, Hash behaviour)` | build 1207

## _SET_PED_COMBAT_STYLE
`0x8ACC0506743A8A5C` | `void _SET_PED_COMBAT_STYLE(Ped ped, Hash combatStyleHash, int p2, float duration)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/AI/COMBAT_STYLES
Params: p2 is usually 1, sometimes 0 or 2
duration in seconds, -1.0 = forever

## _SET_PED_COMBAT_STYLE_MOD
`0x8B1E8E35A6E814EA` | `void _SET_PED_COMBAT_STYLE_MOD(Ped ped, Hash combatStyleModHash, float duration)` | build 1207
duration in seconds, -1.0 = forever

## _SET_PED_CROUCH_MOVEMENT
`0x7DE9692C6F64CFE8` | `void _SET_PED_CROUCH_MOVEMENT(Ped ped, BOOL state, int p2, BOOL immediately)` | build 1207

## _SET_PED_CULL_RANGE
`0x8AC1D721B2097B6E` | `void _SET_PED_CULL_RANGE(Ped ped, float p1, float p2)` | build 1207
The higher the multiplier the less the engine renders culls (https://docs.unity3d.com/Manual/OcclusionCulling.html)

## _SET_PED_DAMAGED
`0xDACE03C65C6666DB` | `void _SET_PED_DAMAGED(Ped ped, BOOL damaged)` | build 1207

## _SET_PED_DAMAGE_CLEANLINESS
`0x7528720101A807A5` | `void _SET_PED_DAMAGE_CLEANLINESS(Ped ped, int damageCleanliness)` | build 1207
damageCleanliness: see _GET_PED_DAMAGE_CLEANLINESS

## _SET_PED_DEFENSIVE_AREA_TO_ANGLED_AREA
`0xEB2BFE5D009F0331` | `void _SET_PED_DEFENSIVE_AREA_TO_ANGLED_AREA(Ped ped, float x1, float y1, float z1, float x2, float y2, float z2, Any p7, BOOL p8, BOOL p9, Entity entity, BOOL p11)` | build 1232
_SET_PED_(A?)*

## _SET_PED_DEFENSIVE_SPHERE_ATTACHED_TO_ENTITY
`0x1854217C640B39EC` | `void _SET_PED_DEFENSIVE_SPHERE_ATTACHED_TO_ENTITY(Ped ped, Entity entity, float x, float y, float z, float radius, int p6, BOOL p7)` | build 1207

## _SET_PED_DESIRED_LOCO_FOR_MODEL
`0x923583741DC87BCE` | `void _SET_PED_DESIRED_LOCO_FOR_MODEL(Ped ped, const char* locomotionArchetype)` | build 1207
Seems to set the ped's loco type.
Values used in the scripts:
algie
angry_female
arthur_healthy
cowboy
cowboy_f
default
default_female
free_slave_01
free_slave_02
gold_panner
guard_lantern
injured_general
john_marston
lilly_millet
lone_prisoner
lost_man
mp_ova_hunter
mp_ova_hunter_female
murfree
old_female
primate
rally
waiter
war_veteran

## _SET_PED_DESIRED_LOCO_MOTION_TYPE
`0x89F5E7ADECCCB49C` | `void _SET_PED_DESIRED_LOCO_MOTION_TYPE(Ped ped, char* locoMotionType)` | build 1207
Sets peds motion type

## _SET_PED_DESIRES_GROUP
`0xBAD2A311667A50D7` | `void _SET_PED_DESIRES_GROUP(Ped ped, BOOL toggle)` | build 1207

## _SET_PED_DIRT_CLEANED
`0xE3144B932DFDFF65` | `void _SET_PED_DIRT_CLEANED(Ped ped, float p1, int p2, BOOL p3, BOOL p4)` | build 1207
Params: ped, 0f, -1, true, true in R* MP Scripts
_SET_PED_DE* - _SET_PED_F*

## _SET_PED_DISABLE_KICK_MOVE
`0xADD31A5C7A5FAA73` | `void _SET_PED_DISABLE_KICK_MOVE(Ped ped, BOOL disable)` | build 1207
Disables being able to kick move ped.

## _SET_PED_DRUNKNESS
`0x406CCF555B04FAD3` | `void _SET_PED_DRUNKNESS(Ped ped, BOOL enabled, float drunknessLevel)` | build 1207
SOBER = 0.0f, SLIGHTLY_DRUNK = 0.25f, MODERATELY_DRUNK = 0.5f, VERY_DRUNK = 1.0f

## _SET_PED_FIRING_PATTERN_2
`0x20E54854DEF6A54A` | `void _SET_PED_FIRING_PATTERN_2(Ped ped, Hash patternHash)` | build 1207
Used in R* MP Script fm_mission_controller and various R* SP Scripts for ambush*

## _SET_PED_FIRING_PATTERN_3
`0x244E8C282188E40F` | `void _SET_PED_FIRING_PATTERN_3(Ped ped, Hash patternHash)` | build 1207
Only used in R* MP Script fm_mission_controller

## _SET_PED_FORMATION_POSITION
`0x0E9E95FDEDCC9D35` | `void _SET_PED_FORMATION_POSITION(Ped ped, int position, BOOL toggle)` | build 1207

## _SET_PED_GETUP_ANIMATION
`0x3AE3552E7C207CC5` | `void _SET_PED_GETUP_ANIMATION(Ped ped, char* animName, BOOL p2)` | build 1207

## _SET_PED_GRAPPLE_ACTION
`0x8301D87B1B89E219` | `void _SET_PED_GRAPPLE_ACTION(Ped ped, Hash grappleAction)` | build 1207

## _SET_PED_GRAPPLE_ANIMATION
`0x56E9C26CD29D1ED6` | `void _SET_PED_GRAPPLE_ANIMATION(Ped ped, Hash grappleAnim)` | build 1207

## _SET_PED_GRAPPLE_EFFECT_MULTIPLIER
`0x99A6E246C315BF60` | `Any _SET_PED_GRAPPLE_EFFECT_MULTIPLIER(Ped ped, float multiplier)` | build 1207

## _SET_PED_GRAPPLE_FLAG
`0x789DABD18E9024DB` | `void _SET_PED_GRAPPLE_FLAG(Ped ped, int flag, BOOL enable)` | build 1207

## _SET_PED_GRAPPLE_SEQUENCE
`0x604190F0CF0DF158` | `void _SET_PED_GRAPPLE_SEQUENCE(Ped ped, char* grappleSequence)` | build 1207

## _SET_PED_GRAPPLE_STYLE
`0x630E7B01F091A197` | `Any _SET_PED_GRAPPLE_STYLE(Ped ped, Hash style)` | build 1207
Hashes: GS_DRAGGING, GS_FACE_TO_BACK, GS_FACE_TO_FACE, GS_FACE_TO_FACE_WALL, GS_MOUNTED

## _SET_PED_HEADSHOT_DAMAGE_MULTIPLIER
`0x2BA918C823B8BA56` | `void _SET_PED_HEADSHOT_DAMAGE_MULTIPLIER(Ped ped, float multiplier)` | build 1207

## _SET_PED_HEALTH_CONFIG
`0xF6B82FCE03B43A37` | `void _SET_PED_HEALTH_CONFIG(Ped ped, Hash configHash)` | build 1207
configHash: see pedhealth.meta

## _SET_PED_IMMERSION_FLAG
`0x7FB0088E8769CDDB` | `void _SET_PED_IMMERSION_FLAG(Ped ped, BOOL toggle)` | build 1207
Only used in R* Script beat_sharp_shooter
Blocks ped from swimming underwater

## _SET_PED_INCAPACITATION_FLAGS
`0xD67B6F3BCF81BA47` | `void _SET_PED_INCAPACITATION_FLAGS(Ped ped, int flags)` | build 1207

## _SET_PED_INCAPACITATION_MODIFIERS
`0x39ED303390DDEAC7` | `void _SET_PED_INCAPACITATION_MODIFIERS(Ped ped, BOOL canBeIncapacitated, int threshold, int bleedoutTime, int p4)` | build 1207

## _SET_PED_INCAPACITATION_TOTAL_BLEED_OUT_DURATION
`0x2890418B39BC8FFF` | `void _SET_PED_INCAPACITATION_TOTAL_BLEED_OUT_DURATION(Ped ped, float duration)` | build 1207

## _SET_PED_INTERACTION_NEGATIVE_RESPONSE
`0xA3C53CDE922BC78B` | `void _SET_PED_INTERACTION_NEGATIVE_RESPONSE(Ped ped, char* speech)` | build 1207

## _SET_PED_INTERACTION_PERSONALITY
`0x24C82EF607105FAA` | `void _SET_PED_INTERACTION_PERSONALITY(Ped ped, Hash personality)` | build 1207
personality (script_mp_rel): NONE, AGGRESSIVE, TIMID (non-aggressive), CRIPPS, SCRIPTEDINTIMIDATION, MAGGIE, MARCEL, SCRIPTEDSALOON
personality (script_rel): AVOID, SCRIPTEDOUTLAW, TIMIDGUARDDOG, SCRIPTEDTIMIDROB, AGGRESSIVECAMPER, LAZYDOG, KIERANTIEDUP, SCRIPTEDGALA

## _SET_PED_INTERACTION_POSITIVE_RESPONSE
`0x20C5459379D75C1C` | `void _SET_PED_INTERACTION_POSITIVE_RESPONSE(Ped ped, char* speech)` | build 1207

## _SET_PED_KNOCKED_BY_ONE_HIT
`0x5BCF0B79D4F5DBA3` | `void _SET_PED_KNOCKED_BY_ONE_HIT(Ped ped, float p1)` | build 1207

## _SET_PED_LADDER_MOVEMENT_SPEED_MODIFIER
`0x05CE6AF4DF071D23` | `void _SET_PED_LADDER_MOVEMENT_SPEED_MODIFIER(Ped ped, float p1)` | build 1207

## _SET_PED_LIGHTS
`0x13A210949FCBD92B` | `void _SET_PED_LIGHTS(Ped ped, BOOL toggle)` | build 1207

## _SET_PED_MELEE_FORCED_DURATION
`0x6DB875AFC584FA32` | `Any _SET_PED_MELEE_FORCED_DURATION(Ped ped, int durationMs)` | build 1207

## _SET_PED_MOTIVATION
`0x06D26A96CA1BCA75` | `void _SET_PED_MOTIVATION(Ped ped, int motivationState, float threshold, Ped targetPed)` | build 1207
enum eMotivationState
{
	TOILET_STATE,
	FEAR_STATE,
	ANGRY_STATE,
	AGITATION_STATE,
	HUNGRY_STATE,
	TIRED_STATE,
	SAD_STATE,
	BRAVE_STATE,
	OFFER_ITEM_STATE,
	SUSPICION,
	DRUNK_STATE
};

If targetPed is set to 0 the ped motivationState affects everyone

## _SET_PED_MOTIVATION_MODIFIER
`0xA1EB5D029E0191D3` | `void _SET_PED_MOTIVATION_MODIFIER(Ped ped, int motivationState, float modifier)` | build 1207
The higher the modifier, the slower the motivationState value will decrease

## _SET_PED_MOTIVATION_STATE_OVERRIDE
`0x2EB75FB86C41F026` | `void _SET_PED_MOTIVATION_STATE_OVERRIDE(Ped ped, int motivationState, BOOL enabled)` | build 1207
motivationState: see _SET_PED_MOTIVATION

## _SET_PED_NEXT_MELEE_ATTACK
`0xC48AF420371C7407` | `Any _SET_PED_NEXT_MELEE_ATTACK(Ped ped, Hash actionHash)` | build 1207
Sets the next melee attack of a ped eg AR_ATTACK_HAYMAKER_TO_HEAD_RIGHT_HAND_DIST_MED_V01 AR_GRAPPLE_MOUNT_FACEDOWN_FROM_FRONT

## _SET_PED_OUTFIT_PRESET
`0xFFA1594703ED27CA` | `void _SET_PED_OUTFIT_PRESET(Ped ped, int index)` | build 1207
doesnt seem to work on story characters possibly need to uese the metaped natives for those

## _SET_PED_PERSONALITY
`0xB8B6430EAD2D2437` | `void _SET_PED_PERSONALITY(Ped ped, Hash personality)` | build 1207
Hashes: STANDARD_PED_AGRO_GUARD, BOUNTY_HUNTER, PLAYER_HORSE, LAW_POLICE, GUARD_DOG, ATTACK_DOG
Personalities can also be found in common:/data/ai/interactionpersonalities

## _SET_PED_PROMPT_NAME
`0x4A48B6E03BABB4AC` | `void _SET_PED_PROMPT_NAME(Ped ped, char* name)` | build 1207

## _SET_PED_PROMPT_NAME_2
`0x19B14E04B009E28B` | `void _SET_PED_PROMPT_NAME_2(Ped ped, char* name)` | build 1207

## _SET_PED_PROMPT_NAME_FROM_GXT_ENTRY
`0xFCA8FB9E15FA80D3` | `void _SET_PED_PROMPT_NAME_FROM_GXT_ENTRY(Ped ped, Hash gxtEntryHash)` | build 1207

## _SET_PED_PROMPT_NAME_FROM_GXT_ENTRY_2
`0xC2745D9261664901` | `void _SET_PED_PROMPT_NAME_FROM_GXT_ENTRY_2(Ped ped, Hash gxtEntryHash)` | build 1207

## _SET_PED_QUALITY
`0xCE6B874286D640BB` | `void _SET_PED_QUALITY(Ped ped, int quality)` | build 1207
quality: see _GET_PED_QUALITY

## _SET_PED_RAGDOLL_BONE_SCALE
`0xC17A94CC8FC3C61A` | `void _SET_PED_RAGDOLL_BONE_SCALE(Entity entity, int boneId, float p2, float p3, float p4)` | build 1207
seems to modify the size/scale of the collision capsule (hitbox) for a specific ped bone

## _SET_PED_SCALE
`0x25ACFC650B65C538` | `void _SET_PED_SCALE(Ped ped, float scale)` | build 1207

## _SET_PED_SCENT
`0x01B21B81865E2A1F` | `void _SET_PED_SCENT(Ped ped, float scent)` | build 1207
0.0 - 1.0
Modifies the "scent line" on the ped's body when using Eagle Eye.

## _SET_PED_TARGET_ACTION_DISABLE_FLAG
`0xC163DAC52AC975D3` | `void _SET_PED_TARGET_ACTION_DISABLE_FLAG(Ped ped, int actionDisableFlag)` | build 1207

## _SET_PED_TORCH_VFX_COLOR
`0xDD9540E7B1C9714F` | `void _SET_PED_TORCH_VFX_COLOR(Ped ped, Hash vfxNodeHash, float r, float g, float b)` | build 1207
The native WILL NOT WORK if the specific component containing the VFX node is not equipped on the ped (e.g., the torch outfit -368114487 must be equipped first via _EQUIP_META_PED_OUTFIT).
It only colors the smoke/volumetrics, leaving the core fire sprites untouched.
Values greater than 1.0f are clamped to 1.0f by the engine. To achieve specific RGB shades, you MUST normalize 0-255 values by dividing them by 255.0f (e.g., 128 becomes 0.5f)
```lua
RegisterCommand("testcolor", function()
  
        local playerPed = PlayerPedId()
        local horse = GetMount(playerPed)

        if  horse ~= 0 then
            local outfitHash = -368114487
            Citizen.InvokeNative(0x1902C4CFCC5BE57C, horse, outfitHash)
            Citizen.InvokeNative(0x704C908E9C405136, horse)

            Wait(500)

            local componentHash = -929362906
            local r, g, b = 1.0, 0.0, 0.0

            Citizen.InvokeNative(0xDD9540E7B1C9714F, horse, componentHash, r, g, b)
        end
end, false)
```

## _SET_PED_TO_BE_REMOVED
`0x36E4B61DC56DE77C` | `void _SET_PED_TO_BE_REMOVED(Ped ped, float p1, float p2, int p3, Any p4)` | build 1207

## _SET_PED_TO_DISABLE_RAGDOLL
`0x221F4D9912B7FE86` | `void _SET_PED_TO_DISABLE_RAGDOLL(Ped ped, BOOL toggle)` | build 1207

## _SET_PED_TRAIL_EFFECT
`0xA5950E16B8F31052` | `void _SET_PED_TRAIL_EFFECT(Ped ped, BOOL p1, float duration)` | build 1207
duration in seconds

## _SET_PED_USE_HORSE_MAP_COLLISION
`0xEB72453B6F5B45B0` | `Any _SET_PED_USE_HORSE_MAP_COLLISION(Ped ped, BOOL toggle)` | build 1232
Doesn't actually return anything.

## _SET_PED_VOICE_VOLUME
`0xD05AD61F242C626B` | `void _SET_PED_VOICE_VOLUME(Ped ped, float volume)` | build 1207
_SET_PED_S* - _SET_PED_T*

## _SET_PED_WETNESS_AMOUNT
`0xF9CFF5BB70E8A2CB` | `void _SET_PED_WETNESS_AMOUNT(Ped ped, float amount)` | build 1207
only works when you use SET_PED_WETNESS_HEIGHT first , if you do 0.0 (it resets) you need to apply again with SET_PED_WETNESS_HEIGHT to see the wetness effects again

## _SET_PED_WRITHING_DURATION
`0x4DB9D03AC4E1FA84` | `void _SET_PED_WRITHING_DURATION(Ped ped, float writhingDuration1, float writhingDuration2, int p3)` | build 1207

## _SET_PELT_FOR_HORSE
`0xA73F50E8796150D5` | `void _SET_PELT_FOR_HORSE(Ped horse, int peltId)` | build 1207

## _SET_PELT_FOR_HORSE_BY_INVENTORY_ITEM
`0xC412AA1C73111FE0` | `void _SET_PELT_FOR_HORSE_BY_INVENTORY_ITEM(Ped horse, Hash inventoryItem, Hash albedoHash, Hash normalHash, BOOL p4)` | build 1207
Set the pelt of the animal to the back of the horse
EXAMPLE:
local mount = GetMountOwnedByPlayer(PlayerId())
Citizen.InvokeNative(0xC412AA1C73111FE0,mount,GetHashKey('PROVISION_DEER_HIDE_POOR'),GetHashKey('a_c_deer_01_uppr_000_c0_001_ab'),0,0)

## _SET_PLAYER_ANTAGONIZE_DISABLED_FOR_PED
`0x5708EDD71B50C008` | `void _SET_PLAYER_ANTAGONIZE_DISABLED_FOR_PED(Ped ped, Player player, int duration)` | build 1207

## _SET_PLAYER_CURRENT_ANIMAL_DAMAGE_MODIFIER
`0x9EFF3C91DF38304F` | `Any _SET_PLAYER_CURRENT_ANIMAL_DAMAGE_MODIFIER(Player player, float modifier, int p2, int p3)` | build 1311
Animal Skin Quality Modifier
Params: p2 = 2, p3 = 3 in R* Scripts

## _SET_PLAYER_DISMOUNT_TIMESTAMP
`0xA691C10054275290` | `void _SET_PLAYER_DISMOUNT_TIMESTAMP(Ped mount, Player player, int dismountedTimestamp)` | build 1207
dismountTimer gets called with the data from `_GET_PLAYER_DISMOUNT_TIMESTAMP`
```lua
local size = 15
local struct = DataView.ArrayBuffer(size * 8)
struct:SetInt32(0, size)
local numLoot = Citizen.InvokeNative(0xB29C553BA582D09E, struct:Buffer(), `a_c_cow`, 0, 2, Citizen.ResultAsInteger())
if (numLoot > 0) then
for i = 1, numLoot do
local hash = struct:GetInt32(i * 8)
print(("i: %d: loot: %d"):format(i, hash))
end
end
```

## _SET_PLAYER_GREET_DISABLED_FOR_PED
`0x19173C3F15367B54` | `void _SET_PLAYER_GREET_DISABLED_FOR_PED(Ped ped, Player player, int duration)` | build 1207

## _SET_RANDOM_OUTFIT_VARIATION
`0x283978A15512B2FE` | `void _SET_RANDOM_OUTFIT_VARIATION(Ped ped, BOOL p1)` | build 1207

## _SET_RELATIONSHIP_GROUP_SCRIPT_REGISTERED
`0xDC91F22F09BC6C2F` | `void _SET_RELATIONSHIP_GROUP_SCRIPT_REGISTERED(Hash group, BOOL unregister)` | build 1207
Used in Script Function MP_MAIN_OFFLINE__INITIALIZE_GAME
_SET_RELATIONSHIP_*

## _SET_REMOVE_PED_NETWORKED
`0x39A2FC5AF55A52B1` | `void _SET_REMOVE_PED_NETWORKED(Ped ped, int p1)` | build 1207

## _SET_SCENARIO_ANIMAL_DENSITY_MULTIPLIER_THIS_FRAME
`0xDB48E99F8E064E56` | `void _SET_SCENARIO_ANIMAL_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## _SET_SCENARIO_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME
`0x28CB6391ACEDD9DB` | `void _SET_SCENARIO_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## _SET_SCENARIO_PED_DENSITY_THIS_FRAME
`0x95423627A9CA598E` | `void _SET_SCENARIO_PED_DENSITY_THIS_FRAME(Hash configHash)` | build 1207
Sets the scenario ped density to the given config.

Valid configs:
- BLACKWATER
- DEFAULT
- NEWBORDEAUX
- RHODES
- STRAWBERRY
- TUMBLEWEED
- VALENTINE
- VANHORN

See common/data/ai/densityscoringconfigs.meta for more information.

## _SET_SCENARIO_PED_RANGE_MULTIPLIER_THIS_FRAME
`0xA77FA7BE9312F8C0` | `void _SET_SCENARIO_PED_RANGE_MULTIPLIER_THIS_FRAME(float multiplier)` | build 1207

## _SET_SCENARIO_PED_VOLUME_REFERENCE
`0x9E3842E5DAD69F80` | `void _SET_SCENARIO_PED_VOLUME_REFERENCE(Volume volume)` | build 1207
Only used in SP R* Script loanshark_hunter

## _SET_STAGED_PED_FLAG
`0x028E7B3BBA0BD2FC` | `void _SET_STAGED_PED_FLAG(Ped ped)` | build 1207
_SET_ST* - _SET_SW* Sets a ped config flag for the specified ped

## _SET_STAMINA_DEPLETION_MULTIPLIER
`0xEF5A3D2285D8924B` | `void _SET_STAMINA_DEPLETION_MULTIPLIER(Ped ped, int multiplier)` | build 1207

## _SET_STAMINA_RECHARGE_MULTIPLIER
`0x345C9F993A8AB4A4` | `void _SET_STAMINA_RECHARGE_MULTIPLIER(Ped ped, int multiplier)` | build 1207

## _SET_TANK_ATTRIBUTE_SIZE
`0x7FF72DE061DF55E2` | `void _SET_TANK_ATTRIBUTE_SIZE(Ped ped, int attributeIndex, float size)` | build 1207
Size will be permanent

## _SET_TEXTURE_LAYER_ALPHA
`0x6C76BC24F8BB709A` | `void _SET_TEXTURE_LAYER_ALPHA(int textureId, int layerId, float texAlpha)` | build 1207

## _SET_TEXTURE_LAYER_MOD
`0xF2EA041F1146D75B` | `void _SET_TEXTURE_LAYER_MOD(int textureId, int layerId, Hash modTextureHash, float modAlpha, int modChannel)` | build 1207

## _SET_TEXTURE_LAYER_PALLETE
`0x1ED8588524AC9BE1` | `void _SET_TEXTURE_LAYER_PALLETE(int textureId, int layerId, Hash paletteHash)` | build 1207
paletteHash: https://raw.githubusercontent.com/femga/rdr3_discoveries/master/clothes/cloth_color_palletes.lua

## _SET_TEXTURE_LAYER_ROUGHNESS
`0x057C4F092E2298BE` | `void _SET_TEXTURE_LAYER_ROUGHNESS(int textureId, int layerId, float texRough)` | build 1207

## _SET_TEXTURE_LAYER_SHEET_GRID_INDEX
`0x3329AAE2882FC8E4` | `void _SET_TEXTURE_LAYER_SHEET_GRID_INDEX(int textureId, int layerId, int sheetGridIndex)` | build 1207

## _SET_TEXTURE_LAYER_TEXTURE_MAP
`0x253A63B5BADBC398` | `void _SET_TEXTURE_LAYER_TEXTURE_MAP(int textureId, int layerId, Hash albedoHash, Hash normalHash, Hash materialHash)` | build 1207

## _SET_TEXTURE_LAYER_TINT
`0x2DF59FFE6FFD6044` | `void _SET_TEXTURE_LAYER_TINT(int textureId, int layerId, int tint0, int tint1, int tint2)` | build 1207
Seem color is not RGB or HSV

## _SET_TEXTURE_OUTFIT_TINTS
`0x4EFC1F8FF1AD94DE` | `void _SET_TEXTURE_OUTFIT_TINTS(Ped ped, Hash componentCategory, Hash palette, int tint0, int tint1, int tint2)` | build 1207
Used in script function METAPED_CLOTHING__XML__APPLY_OUTFIT_TINTS_TO_PED

## _SET_TOTAL_PED_DAMAGE_FALLOFF_BONUS
`0x932786CE3C76477C` | `void _SET_TOTAL_PED_DAMAGE_FALLOFF_BONUS(Ped ped, float bonus)` | build 1207
_SET_W(EAPON?)*

## _SET_TOTAL_PED_DAMAGE_FROM_AI
`0x73B6F907B913C860` | `void _SET_TOTAL_PED_DAMAGE_FROM_AI(Ped ped, float totalDamage)` | build 1207
_SET_W(EAPON?)*

## _SHOOT_TRIGGER_AT_COORDS
`0x4C57F27D1554E6B0` | `Any _SHOOT_TRIGGER_AT_COORDS(Ped ped, float x, float y, float z, int p4, float p5, int p6, float p7)` | build 1207
Triggers a gunshot
Params: p5 = -1 in R* Scripts

## _SPAWNPOINTS_START_SEARCH_WITH_VOLUME
`0x83ED1FC9DF3411F5` | `void _SPAWNPOINTS_START_SEARCH_WITH_VOLUME(Volume volume, int spawnpointsFlag, float p2, int duration, float p4)` | build 1311

## _TOGGLE_PLAYER_PED_FLINCH
`0x09E378C52B1433B5` | `void _TOGGLE_PLAYER_PED_FLINCH(Ped ped, float x, float y, float z, float scale)` | build 1207
_TOGGLE_S* - _UPDATE_*

## _UNRESERVE_AMBIENT_PEDS
`0x7D4E70A67A651C71` | `void _UNRESERVE_AMBIENT_PEDS(int numPeds)` | build 1207

## _UPDATE_ANIMAL_DAMAGE_MODIFIER
`0x0F9E754EBE8FDBFA` | `void _UPDATE_ANIMAL_DAMAGE_MODIFIER(Player player)` | build 1311

## _UPDATE_PED_TEXTURE
`0x92DAABA2C1C10B0E` | `void _UPDATE_PED_TEXTURE(int textureId)` | build 1207
Should be called at least once for any new texture override.
Otherwise component textures will be just black.
Also needs to be called for updating any ped overlays to apply the changes.

## _UPDATE_PED_VARIATION
`0xCC8CA3E88256E58F` | `void _UPDATE_PED_VARIATION(Ped ped, BOOL p1, BOOL p2, BOOL p3, BOOL p4, BOOL p5)` | build 1207
Update variation on ped, needed after first creation, or when component or texture/overlay is changed

## _UPDATE_PED_WOUND_EFFECT
`0x66B1CB778D911F49` | `void _UPDATE_PED_WOUND_EFFECT(Ped ped, float value)` | build 1207
Params: 0.0f to remove wound effects

## _UPDATE_SHOP_ITEM_WEARABLE_STATE
`0x66B957AAC2EAAEAB` | `void _UPDATE_SHOP_ITEM_WEARABLE_STATE(Ped ped, Hash componentHash, Hash wearableState, int p3, BOOL isMp, int p5)` | build 1207

## _WARP_PED_OUT_OF_VEHICLE
`0xE0B61ED8BB37712F` | `void _WARP_PED_OUT_OF_VEHICLE(Ped ped)` | build 1207
