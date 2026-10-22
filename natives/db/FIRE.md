# FIRE natives (28)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_EXPLOSION
`0x7D6F58F69DA92530` | `void ADD_EXPLOSION(float x, float y, float z, int explosionType, float damageScale, BOOL isAudible, BOOL isInvisible, float cameraShake)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/graphics/explosions

explosionType:
enum eExplosionTag
{
	EXP_TAG_DONTCARE = -1,
	EXP_TAG_GRENADE,
	EXP_TAG_STICKYBOMB,
	EXP_TAG_MOLOTOV,
	EXP_TAG_MOLOTOV_VOLATILE,
	EXP_TAG_HI_OCTANE,
	EXP_TAG_CAR,
	EXP_TAG_PLANE,
	EXP_TAG_PETROL_PUMP,
	EXP_TAG_DIR_STEAM,
	EXP_TAG_DIR_FLAME,
	EXP_TAG_DIR_WATER_HYDRANT,
	EXP_TAG_BOAT,
	EXP_TAG_BULLET,
	EXP_TAG_SMOKEGRENADE,
	EXP_TAG_BZGAS,
	EXP_TAG_GAS_CANISTER,
	EXP_TAG_EXTINGUISHER,
	EXP_TAG_TRAIN,
	EXP_TAG_DIR_FLAME_EXPLODE,
	EXP_TAG_VEHICLE_BULLET,
	EXP_TAG_BIRD_CRAP,
	EXP_TAG_FIREWORK,
	EXP_TAG_TORPEDO,
	EXP_TAG_TORPEDO_UNDERWATER,
	EXP_TAG_LANTERN,
	EXP_TAG_DYNAMITE,
	EXP_TAG_DYNAMITESTACK,
	EXP_TAG_DYNAMITE_VOLATILE,
	EXP_TAG_RIVER_BLAST,
	EXP_TAG_PLACED_DYNAMITE,
	EXP_TAG_FIRE_ARROW,
	EXP_TAG_DYNAMITE_ARROW,
	EXP_TAG_PHOSPHOROUS_BULLET,
	EXP_TAG_LIGHTNING_STRIKE,
	EXP_TAG_TRACKING_ARROW,
	EXP_TAG_POISON_BOTTLE
};

## ADD_EXPLOSION_WITH_USER_VFX
`0x53BA259F3A67A99E` | `void ADD_EXPLOSION_WITH_USER_VFX(float x, float y, float z, int explosionType, Hash explosionFx, float damageScale, BOOL isAudible, BOOL isInvisible, float cameraShake)` | build 1207
explosionType: see ADD_EXPLOSION
Change explosionFx (Visual Effect) for specified explosionType

## ADD_OWNED_EXPLOSION
`0xD84A917A64D4D016` | `void ADD_OWNED_EXPLOSION(Ped ped, float x, float y, float z, int explosionType, float damageScale, BOOL isAudible, BOOL isInvisible, float cameraShake)` | build 1207
explosionType: see ADD_EXPLOSION

## GET_CLOSEST_FIRE_POS
`0xB646FB657F448261` | `BOOL GET_CLOSEST_FIRE_POS(Vector3* outPosition, float x, float y, float z)` | build 1207

## GET_NUMBER_OF_FIRES_IN_RANGE
`0xF9617BC6FAE61E08` | `int GET_NUMBER_OF_FIRES_IN_RANGE(float x, float y, float z, float radius)` | build 1207

## GET_OWNER_OF_EXPLOSION_IN_ANGLED_AREA
`0x8002DDAB58594D78` | `Entity GET_OWNER_OF_EXPLOSION_IN_ANGLED_AREA(int explosionType, float x1, float y1, float z1, float x2, float y2, float z2, float radius)` | build 1207
explosionType: see ADD_EXPLOSION

## IS_ENTITY_ON_FIRE
`0x1BD7C371CE257C3E` | `BOOL IS_ENTITY_ON_FIRE(Entity entity)` | build 1207

## IS_EXPLOSION_ACTIVE_IN_AREA
`0xD96E82AEBFFAAFF0` | `BOOL IS_EXPLOSION_ACTIVE_IN_AREA(int explosionType, float x1, float y1, float z1, float x2, float y2, float z2)` | build 1207
explosionType: see ADD_EXPLOSION

## IS_EXPLOSION_IN_ANGLED_AREA
`0x5AE661ECD18524C9` | `BOOL IS_EXPLOSION_IN_ANGLED_AREA(int explosionType, float x1, float y1, float z1, float x2, float y2, float z2, float angle)` | build 1207
explosionType: see ADD_EXPLOSION

## IS_EXPLOSION_IN_AREA
`0x8391BA4313A25AD3` | `BOOL IS_EXPLOSION_IN_AREA(int explosionType, float x1, float y1, float z1, float x2, float y2, float z2)` | build 1207
explosionType: see ADD_EXPLOSION

## IS_EXPLOSION_IN_SPHERE
`0xD62DD846D82CBB90` | `BOOL IS_EXPLOSION_IN_SPHERE(int explosionType, float x, float y, float z, float radius)` | build 1207
explosionType: see ADD_EXPLOSION

## REMOVE_SCRIPT_FIRE
`0x790125C36E194069` | `void REMOVE_SCRIPT_FIRE(FireId fireHandle)` | build 1207

## START_ENTITY_FIRE
`0xC4DC7418A44D6822` | `void START_ENTITY_FIRE(Entity entity, float intensity, int boneIndex, int fireFlags)` | build 1207

## START_SCRIPT_FIRE
`0x6B83617E04503888` | `FireId START_SCRIPT_FIRE(float x, float y, float z, int p3, float p4, BOOL p5, const char* soundsetName, float p7, int p8)` | build 1207
Starts a fire:

xyz: Location of fire
maxChildren: The max amount of times a fire can spread to other objects. Must be 25 or less, or the function will do nothing.
isGasFire: Whether or not the fire is powered by gasoline.

## STOP_ENTITY_FIRE
`0x8390751DC40C1E98` | `void STOP_ENTITY_FIRE(Any p0, Any p1)` | build 1207

## STOP_FIRE_IN_RANGE
`0xDB38F247BD421708` | `void STOP_FIRE_IN_RANGE(float x, float y, float z, float radius)` | build 1207

## _0x24DB6B9F2B719043
`0x24DB6B9F2B719043` | `void _0x24DB6B9F2B719043(float p0)` | build 1207
Only used in R* SP Related Camp Scripts

## _0x41B87A6495EE13DD
`0x41B87A6495EE13DD` | `Any _0x41B87A6495EE13DD(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9)` | build 1232

## _0x68F6A75FDF5A70D6
`0x68F6A75FDF5A70D6` | `void _0x68F6A75FDF5A70D6(float x, float y, float z, float p3)` | build 1207

## _0x754937C28271BC65
`0x754937C28271BC65` | `void _0x754937C28271BC65(Any p0)` | build 1207

## _ADD_EXPLOSION_WITH_DAMAGE_CAUSER
`0xB7DF150605EEDC9B` | `void _ADD_EXPLOSION_WITH_DAMAGE_CAUSER(Entity entity, int p1, float x, float y, float z, int explosionType, float damageScale, BOOL isAudible, BOOL isInvisible, float cameraShake)` | build 1207
Add explosion with and assign an entity as damage causer.
explosionType: https://github.com/femga/rdr3_discoveries/blob/master/graphics/explosions/README.md

## _ADD_EXPLOSION_WITH_USER_VFX_AND_DAMAGE_CAUSER
`0x34AE85C7CA4857AA` | `void _ADD_EXPLOSION_WITH_USER_VFX_AND_DAMAGE_CAUSER(Entity entity, BOOL p1, float x, float y, float z, int explosionType, Hash explosionFx, float damageScale, BOOL isAudible, BOOL isInvisible, float cameraShake)` | build 1207
Add explosion with vfx and assign an entity as damage causer.
explosionType: https://github.com/femga/rdr3_discoveries/blob/master/graphics/explosions/README.md
explosionFx: https://github.com/femga/rdr3_discoveries/blob/master/graphics/explosions/explosion_vfxTags.lua

## _GET_CLOSEST_FIRE_POS_IN_VOLUME
`0x559FC1D310813031` | `BOOL _GET_CLOSEST_FIRE_POS_IN_VOLUME(Vector3* outPosition, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1232

## _IS_ENTITY_CONSUMED_BY_FIRE
`0xCDC25355C0D65963` | `BOOL _IS_ENTITY_CONSUMED_BY_FIRE(Entity entity)` | build 1207

## _IS_ENTITY_DAMAGED_BY_FIRE
`0xA4454592DCF7C992` | `BOOL _IS_ENTITY_DAMAGED_BY_FIRE(Entity entity)` | build 1207
this natives only returns true if entity is damaged by fire , once damaged caused to entity by fire (like burned appearance) has cleared (they clear over time) then returns false

## _IS_EXPLOSION_IN_VOLUME
`0xE24822A4CFC9107A` | `BOOL _IS_EXPLOSION_IN_VOLUME(int explosionType, Volume volume)` | build 1207
explosionType: see ADD_EXPLOSION

## _IS_PED_SHOCKING_EVENT_ACTIVE
`0xAB7993BA61A4674F` | `BOOL _IS_PED_SHOCKING_EVENT_ACTIVE(Ped ped, int p1)` | build 1232
Tested with fire & dynamite. Only returns true using value p1 = 1 and when the ped is affected by fire.

## _STOP_FIRE_IN_BOX
`0xB7C7BDC375AEA9A4` | `void _STOP_FIRE_IN_BOX(float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ)` | build 1207
