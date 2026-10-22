# WEAPON natives (222)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## GET_ALLOW_DUAL_WIELD
`0x918990BD9CE08582` | `BOOL GET_ALLOW_DUAL_WIELD(Ped ped)` | build 1207

## GET_AMMO_IN_CLIP
`0x2E1202248937775C` | `BOOL GET_AMMO_IN_CLIP(Ped ped, int* ammo, Hash weaponHash)` | build 1207

## GET_AMMO_IN_PED_WEAPON
`0x015A522136D7F951` | `int GET_AMMO_IN_PED_WEAPON(Ped ped, Hash weaponHash)` | build 1207

## GET_BEST_PED_SHORTARM_GUID
`0xF52BD94B47CCF736` | `void GET_BEST_PED_SHORTARM_GUID(Ped ped, Any* outGUID, BOOL p2, BOOL p3)` | build 1207

## GET_BEST_PED_WEAPON
`0x8483E98E8B888AE2` | `Hash GET_BEST_PED_WEAPON(Ped ped, BOOL p1, BOOL p2)` | build 1207

## GET_CURRENT_PED_VEHICLE_WEAPON
`0x1017582BCD3832DC` | `BOOL GET_CURRENT_PED_VEHICLE_WEAPON(Ped ped, Hash* weaponHash)` | build 1207

## GET_CURRENT_PED_WEAPON
`0x3A87E44BB9A01D54` | `BOOL GET_CURRENT_PED_WEAPON(Ped ped, Hash* weaponHash, BOOL p2, int attachPoint, BOOL p4)` | build 1207
attachPoint: see SET_CURRENT_PED_WEAPON

## GET_CURRENT_PED_WEAPON_ENTITY_INDEX
`0x3B390A939AF0B5FC` | `Entity GET_CURRENT_PED_WEAPON_ENTITY_INDEX(Ped ped, int attachPoint)` | build 1207
Returns weaponObject, attachPoint: see SET_CURRENT_PED_WEAPON

## GET_MAX_AMMO
`0xDC16122C7A20C933` | `BOOL GET_MAX_AMMO(Ped ped, int* ammo, Hash weaponHash)` | build 1207

## GET_MAX_AMMO_IN_CLIP
`0xA38DCFFCEA8962FA` | `int GET_MAX_AMMO_IN_CLIP(Ped ped, Hash weaponHash, BOOL p2)` | build 1207

## GET_PED_AMMO_BY_TYPE
`0x39D22031557946C1` | `int GET_PED_AMMO_BY_TYPE(Ped ped, Hash ammoType)` | build 1207

## GET_PED_AMMO_TYPE_FROM_WEAPON
`0x7FEAD38B326B9F74` | `Hash GET_PED_AMMO_TYPE_FROM_WEAPON(Ped ped, Hash weaponHash)` | build 1207
Returns the current ammo type of the specified ped's specified weapon.

## GET_PED_BACKUP_WEAPON
`0xC71FE230A513C30F` | `Hash GET_PED_BACKUP_WEAPON(Ped ped, BOOL p1)` | build 1207

## GET_PED_LAST_WEAPON_IMPACT_COORD
`0x6C4D0409BA1A2BC2` | `BOOL GET_PED_LAST_WEAPON_IMPACT_COORD(Ped ped, Vector3* coords)` | build 1207

## GET_PED_WEAPON_GUID_AT_ATTACH_POINT
`0x6929E22158E52265` | `BOOL GET_PED_WEAPON_GUID_AT_ATTACH_POINT(Ped ped, int attachPoint, Any* weaponGuid)` | build 1207

## GET_WEAPONTYPE_GROUP
`0xEDCA14CA5199FF25` | `Hash GET_WEAPONTYPE_GROUP(Hash weaponHash)` | build 1207

## GET_WEAPON_CLIP_SIZE
`0xD3750CCC00635FC2` | `int GET_WEAPON_CLIP_SIZE(Hash weaponHash)` | build 1207

## GET_WEAPON_DEGRADATION
`0x0D78E1097F89E637` | `float GET_WEAPON_DEGRADATION(Object weaponObject)` | build 1207
0.0: good condition, 1.0: poor condition

## GET_WEAPON_PERMANENT_DEGRADATION
`0xD56E5F336C675EFA` | `float GET_WEAPON_PERMANENT_DEGRADATION(Object weaponObject)` | build 1207
Related to rust of weapons

## GIVE_DELAYED_WEAPON_TO_PED
`0xB282DC6EBD803C75` | `void GIVE_DELAYED_WEAPON_TO_PED(Ped ped, Hash weaponHash, int ammoCount, BOOL p3, Hash addReason)` | build 1207
addReason: see _ADD_AMMO_TO_PED

## GIVE_WEAPON_TO_PED
`0x5E3BDDBCB83F3D84` | `Hash GIVE_WEAPON_TO_PED(Ped ped, Hash weaponHash, int ammoCount, BOOL bForceInHand, BOOL bForceInHolster, int attachPoint, BOOL bAllowMultipleCopies, float p7, float p8, Hash addReason, BOOL bIgnoreUnlocks, float permanentDegradation, BOOL p12)` | build 1207
Gives the ped the weapon.
List: https://github.com/femga/rdr3_discoveries/blob/master/weapons/weapons.lua

Params: p7 is 0.5f, and p8 is 1.0f. p11 and p12 are both 0 in R* Scripts
attachPoint: see SET_CURRENT_PED_WEAPON
addReason: see _ADD_AMMO_TO_PED
permanentDegradation: default 0.5, any higher than 0 it will automatically make the weapon worn, you can also adjust the value to change the weapons maximum cleanliness

## GIVE_WEAPON_TO_PED_WITH_OPTIONS
`0xBE7E42B07FD317AC` | `BOOL GIVE_WEAPON_TO_PED_WITH_OPTIONS(Ped ped, Any* data, Any* outData)` | build 1207

## HAS_PED_GOT_WEAPON
`0x8DECB02F88F428BC` | `BOOL HAS_PED_GOT_WEAPON(Ped ped, Hash weaponHash, int p2, BOOL onlyCheckPlayerInventory)` | build 1207
onlyCheckPlayerInventory: If true, it will only check the players current inventory. If false, it also checks your horse inventory

## HAS_WEAPON_GOT_WEAPON_COMPONENT
`0x76A18844E743BF91` | `BOOL HAS_WEAPON_GOT_WEAPON_COMPONENT(Object weapon, Hash addonHash)` | build 1207

## HIDE_PED_WEAPON_FOR_SCRIPTED_CUTSCENE
`0x6F6981D2253C208F` | `void HIDE_PED_WEAPON_FOR_SCRIPTED_CUTSCENE(Ped ped, BOOL toggle)` | build 1207
Hides the ped's weapon during a cutscene.

## IS_PED_ARMED
`0xCB690F680A3EA971` | `BOOL IS_PED_ARMED(Ped ped, int flags)` | build 1207

## IS_PED_CARRYING_WEAPON
`0xF29A186ED428B552` | `BOOL IS_PED_CARRYING_WEAPON(Ped ped, Hash weaponHash)` | build 1207

## IS_PED_WEAPON_READY_TO_SHOOT
`0xB80CA294F2F26749` | `BOOL IS_PED_WEAPON_READY_TO_SHOOT(Ped ped)` | build 1207

## IS_WEAPON_A_GUN
`0x705BE297EEBDB95D` | `BOOL IS_WEAPON_A_GUN(Hash weaponHash)` | build 1207
Returns true if CWeaponInfoFlags::Flags::Gun is set.

## IS_WEAPON_BOW
`0xC4DEC3CA8C365A5D` | `BOOL IS_WEAPON_BOW(Hash weaponHash)` | build 1207

## IS_WEAPON_MELEE_WEAPON
`0x959383DCD42040DA` | `BOOL IS_WEAPON_MELEE_WEAPON(Hash weaponHash)` | build 1207

## IS_WEAPON_PISTOL
`0xDDC64F5E31EEDAB6` | `BOOL IS_WEAPON_PISTOL(Hash weaponHash)` | build 1207

## IS_WEAPON_REPEATER
`0xDDB2578E95EF7138` | `BOOL IS_WEAPON_REPEATER(Hash weaponHash)` | build 1207

## IS_WEAPON_REVOLVER
`0xC212F1D05A8232BB` | `BOOL IS_WEAPON_REVOLVER(Hash weaponHash)` | build 1207

## IS_WEAPON_RIFLE
`0x0A82317B7EBFC420` | `BOOL IS_WEAPON_RIFLE(Hash weaponHash)` | build 1207

## IS_WEAPON_SHOTGUN
`0xC75386174ECE95D5` | `BOOL IS_WEAPON_SHOTGUN(Hash weaponHash)` | build 1207

## IS_WEAPON_VALID
`0x937C71165CF334B3` | `BOOL IS_WEAPON_VALID(Hash weaponHash)` | build 1207

## MAKE_PED_DROP_WEAPON
`0xCEF4C65DE502D367` | `Entity MAKE_PED_DROP_WEAPON(Ped ped, BOOL p1, int attachPoint, BOOL p3, BOOL p4)` | build 1207
Old name: _DROP_CURRENT_PED_WEAPON

## REMOVE_ALL_PED_WEAPONS
`0xF25DF915FA38C5F3` | `void REMOVE_ALL_PED_WEAPONS(Ped ped, BOOL p1, BOOL p2)` | build 1207

## REMOVE_WEAPON_COMPONENT_FROM_WEAPON_OBJECT
`0xF7D82B0D66777611` | `void REMOVE_WEAPON_COMPONENT_FROM_WEAPON_OBJECT(Object weaponObject, Hash component)` | build 1207

## REMOVE_WEAPON_FROM_PED
`0x4899CB088EDF59B8` | `void REMOVE_WEAPON_FROM_PED(Ped ped, Hash weaponHash, BOOL p2, Hash removeReason)` | build 1207
removeReason:
enum eRemoveItemReason : Hash
{
	REMOVE_REASON_CLIENT_PURGED = 0x4A4E94DC,
	REMOVE_REASON_COALESCE = 0x2ABE393E,
	REMOVE_REASON_DEBUG = 0xA07362E6,
	REMOVE_REASON_DEFAULT = 0xF77DE93D,
	REMOVE_REASON_DELETE_CHARACTER = 0x20AFBDE9,
	REMOVE_REASON_DROPPED = 0xEC7FB5D5,
	REMOVE_REASON_DUPLICATE = 0x19047132,
	REMOVE_REASON_GIFTED_INCORRECTLY = 0x9C4E3829,
	REMOVE_REASON_GIVEN = 0xAD5377D4,
	REMOVE_REASON_INSUFFICIENT_INVENTORY = 0x518D1AAE,
	REMOVE_REASON_ITEM_DOES_NOT_EXIST = 0xEAD5D889,
	REMOVE_REASON_LOADOUT = 0x1B94E3BA,
	REMOVE_REASON_SET_AMOUNT = 0x19D5CFA5,
	REMOVE_REASON_SOLD = 0x76C4B482,
	REMOVE_REASON_USED = 0x2188E0A3,
	REMOVE_REASON_USE_FAILED = 0x671F9EAD
};

## SET_ALLOW_ANY_WEAPON_DROP
`0x78030C7867D8B9B6` | `void SET_ALLOW_ANY_WEAPON_DROP(Ped ped, BOOL toggle)` | build 1207

## SET_AMMO_IN_CLIP
`0xDCD2A934D65CB497` | `BOOL SET_AMMO_IN_CLIP(Ped ped, Hash weaponHash, int ammo)` | build 1207

## SET_CURRENT_PED_VEHICLE_WEAPON
`0x75C55983C2C39DAA` | `BOOL SET_CURRENT_PED_VEHICLE_WEAPON(Ped ped, Hash weaponHash)` | build 1207

## SET_CURRENT_PED_WEAPON
`0xADF692B254977C0C` | `void SET_CURRENT_PED_WEAPON(Ped ped, Hash weaponHash, BOOL equipNow, int attachPoint, BOOL p4, BOOL p5)` | build 1207
attachPoint:
enum eWeaponAttachPoint
{
	WEAPON_ATTACH_POINT_INVALID = -1,
	WEAPON_ATTACH_POINT_HAND_PRIMARY = 0,
	WEAPON_ATTACH_POINT_HAND_SECONDARY = 1,
	WEAPON_ATTACH_POINT_PISTOL_R = 2,
	MAX_HAND_WEAPON_ATTACH_POINTS = 2,
	WEAPON_ATTACH_POINT_PISTOL_L = 3,
	WEAPON_ATTACH_POINT_KNIFE = 4,
	WEAPON_ATTACH_POINT_LASSO = 5,
	WEAPON_ATTACH_POINT_THROWER = 6,
	WEAPON_ATTACH_POINT_BOW = 7,
	WEAPON_ATTACH_POINT_BOW_ALTERNATE = 8,
	WEAPON_ATTACH_POINT_RIFLE = 9,
	WEAPON_ATTACH_POINT_RIFLE_ALTERNATE = 10,
	WEAPON_ATTACH_POINT_LANTERN = 11,
	WEAPON_ATTACH_POINT_TEMP_LANTERN = 12,
	WEAPON_ATTACH_POINT_MELEE = 13,
	MAX_SYNCED_WEAPON_ATTACH_POINTS = 13,
	WEAPON_ATTACH_POINT_HIP = 14,
	WEAPON_ATTACH_POINT_BOOT = 15,
	WEAPON_ATTACH_POINT_BACK = 16,
	WEAPON_ATTACH_POINT_FRONT = 17,
	WEAPON_ATTACH_POINT_SHOULDERSLING = 18,
	WEAPON_ATTACH_POINT_LEFTBREAST = 19,
	WEAPON_ATTACH_POINT_RIGHTBREAST = 20,
	WEAPON_ATTACH_POINT_LEFTARMPIT = 21,
	WEAPON_ATTACH_POINT_RIGHTARMPIT = 22,
	WEAPON_ATTACH_POINT_LEFTARMPIT_RIFLE = 23,
	WEAPON_ATTACH_POINT_SATCHEL = 24,
	WEAPON_ATTACH_POINT_LEFTARMPIT_BOW = 25,
	WEAPON_ATTACH_POINT_RIGHT_HAND_EXTRA = 26,
	WEAPON_ATTACH_POINT_LEFT_HAND_EXTRA = 27,
	WEAPON_ATTACH_POINT_RIGHT_HAND_AUX = 28,
	MAX_WEAPON_ATTACH_POINTS = 29
};

## SET_CURRENT_PED_WEAPON_BY_GUID
`0x12FB95FE3D579238` | `void SET_CURRENT_PED_WEAPON_BY_GUID(Ped ped, Any* weaponUid, BOOL p2, BOOL p3, BOOL p4, BOOL p5)` | build 1207
Equips a weapon from a weaponItem, similar to GIVE_WEAPON_TO_PED

## SET_INSTANTLY_EQUIP_WEAPON_PICKUPS
`0x739B9C6D0E7F7F93` | `void SET_INSTANTLY_EQUIP_WEAPON_PICKUPS(Ped ped, BOOL toggle)` | build 1207

## SET_PED_AMMO
`0x14E56BC5B5DB6A19` | `void SET_PED_AMMO(Ped ped, Hash weaponHash, int ammo)` | build 1207

## SET_PED_AMMO_BY_TYPE
`0x5FD1E1F011E76D7E` | `void SET_PED_AMMO_BY_TYPE(Ped ped, Hash ammoType, int ammo)` | build 1207

## SET_PED_AMMO_TO_DROP
`0xA4EFEF9440A5B0EF` | `void SET_PED_AMMO_TO_DROP(Ped ped, int p1, int p2)` | build 1207

## SET_PED_CURRENT_WEAPON_VISIBLE
`0x0725A4CCFDED9A70` | `void SET_PED_CURRENT_WEAPON_VISIBLE(Ped ped, BOOL visible, BOOL deselectWeapon, BOOL p3, BOOL p4)` | build 1207

## SET_PED_DROPS_INVENTORY_WEAPON
`0x208A1888007FC0E6` | `void SET_PED_DROPS_INVENTORY_WEAPON(Ped ped, Hash weaponHash, float xOffset, float yOffset, float zOffset, int ammoCount)` | build 1207

## SET_PED_DROPS_WEAPONS_WHEN_DEAD
`0x476AE72C1D19D1A8` | `void SET_PED_DROPS_WEAPONS_WHEN_DEAD(Ped ped, BOOL toggle)` | build 1207

## SET_PED_INFINITE_AMMO
`0x3EDCB0505123623B` | `void SET_PED_INFINITE_AMMO(Ped ped, BOOL toggle, Hash weaponHash)` | build 1207

## SET_PLAYER_PED_QUICK_SWAP_WEAPON_BY_GUID
`0xEC1F85DA51D3D6C4` | `void SET_PLAYER_PED_QUICK_SWAP_WEAPON_BY_GUID(Ped ped, Any* guidPrimary, Any* guidSecondary)` | build 1232

## SET_VEHICLE_WEAPON_HEADING
`0x194D877FC5597B7D` | `void SET_VEHICLE_WEAPON_HEADING(Vehicle vehicle, int seatIndex, float heading, BOOL p3)` | build 1207

## SHOULD_WEAPON_BE_DISCARDED_WHEN_SWAPPED
`0x2C83212A7AA51D3D` | `BOOL SHOULD_WEAPON_BE_DISCARDED_WHEN_SWAPPED(Hash weaponHash)` | build 1207

## _0x000FA7A4A8443AF7
`0x000FA7A4A8443AF7` | `void _0x000FA7A4A8443AF7(Any p0)` | build 1207

## _0x16D9841A85FA627E
`0x16D9841A85FA627E` | `void _0x16D9841A85FA627E(Ped ped, BOOL toggle)` | build 1207

## _0x183CE355115B6E75
`0x183CE355115B6E75` | `void _0x183CE355115B6E75(Any p0, Any p1)` | build 1207

## _0x431240A58484D5D0
`0x431240A58484D5D0` | `void _0x431240A58484D5D0(Ped ped, BOOL toggle)` | build 1207

## _0x457B16951AD77C1B
`0x457B16951AD77C1B` | `void _0x457B16951AD77C1B(Any p0)` | build 1436

## _0x45E57FDD531C9477
`0x45E57FDD531C9477` | `void _0x45E57FDD531C9477(Ped ped, BOOL toggle)` | build 1207

## _0x63B83A526329AFBC
`0x63B83A526329AFBC` | `void _0x63B83A526329AFBC(Any p0)` | build 1207
Only used in R* Script fme_escaped_convicts, p0 = 0

## _0x641351E9AD103890
`0x641351E9AD103890` | `void _0x641351E9AD103890(Any p0, Any p1)` | build 1207

## _0x74C2365FDD1BB48F
`0x74C2365FDD1BB48F` | `void _0x74C2365FDD1BB48F(Any p0, Any p1)` | build 1207

## _0x9409C62504A8F9E9
`0x9409C62504A8F9E9` | `void _0x9409C62504A8F9E9(Vehicle vehicle, BOOL p1)` | build 1207
Only used in R* SP Script guama3

## _0x9CCA3131E6B53C68
`0x9CCA3131E6B53C68` | `Any _0x9CCA3131E6B53C68(Any p0, Any p1, Any p2)` | build 1207

## _0xA2091482ED42EF85
`0xA2091482ED42EF85` | `Any _0xA2091482ED42EF85(Any p0, Any p1)` | build 1207

## _0xA3716A77DCF17424
`0xA3716A77DCF17424` | `void _0xA3716A77DCF17424(Any p0, Any p1, Any p2)` | build 1207

## _0xA769D753922B031B
`0xA769D753922B031B` | `void _0xA769D753922B031B(Any p0, Any p1, Any p2)` | build 1207

## _0xB0FB9B196A3D13F0
`0xB0FB9B196A3D13F0` | `void _0xB0FB9B196A3D13F0(Any p0, Any p1, Any p2)` | build 1207

## _0xC5899C4CD2E2495D
`0xC5899C4CD2E2495D` | `void _0xC5899C4CD2E2495D(Any p0)` | build 1207

## _0xD53846B9C931C181
`0xD53846B9C931C181` | `void _0xD53846B9C931C181(Any p0, Any p1, Any p2)` | build 1207

## _0xE9B3FEC825668291
`0xE9B3FEC825668291` | `void _0xE9B3FEC825668291(Any p0, Any p1, Any p2)` | build 1207

## _0xECBB26529A737EF6
`0xECBB26529A737EF6` | `void _0xECBB26529A737EF6(Any p0)` | build 1207

## _0xF08D8FEB455F2C8C
`0xF08D8FEB455F2C8C` | `void _0xF08D8FEB455F2C8C(Ped ped, BOOL toggle)` | build 1207

## _0xF252A85B8F3F8C58
`0xF252A85B8F3F8C58` | `BOOL _0xF252A85B8F3F8C58(Hash weaponCollection, Hash dualwieldVariant)` | build 1207

## _0xF2F585411E748B9C
`0xF2F585411E748B9C` | `Any _0xF2F585411E748B9C(Any p0, Any p1)` | build 1207

## _0xF8204EF17410BF43
`0xF8204EF17410BF43` | `Hash _0xF8204EF17410BF43(Hash weaponGroupHash, float p1, float p2, Any p3)` | build 1207
Returns weaponHash

## _ADD_AMMO_TO_PED
`0xB190BCA3F4042F95` | `void _ADD_AMMO_TO_PED(Ped ped, Hash weaponHash, int amount, Hash addReason)` | build 1207
addReason:
enum eAddItemReason : Hash
{
	ADD_REASON_AWARDS = 0xB784AD1E,
	ADD_REASON_CREATE_CHARACTER = 0xE2C4FF71,
	ADD_REASON_DEBUG = 0x5C05C64D,
	ADD_REASON_DEFAULT = 0x2CD419DC,
	ADD_REASON_GET_INVENTORY = 0xD8188685,
	ADD_REASON_INCENTIVE = 0x8ADC2E95,
	ADD_REASON_LOADOUT = 0xCA3454E6,
	ADD_REASON_LOAD_SAVEGAME = 0x56212906,
	ADD_REASON_LOOTED = 0xCA806A55,
	ADD_REASON_MELEE = 0x7B9BDCE7,
	ADD_REASON_MP_MISSION = 0xEC0E0194,
	ADD_REASON_NOTIFICATION = 0xC56292D2,
	ADD_REASON_PICKUP = 0x1A770E22,
	ADD_REASON_PURCHASED = 0x4A6726C9,
	ADD_REASON_SET_AMOUNT = 0x4504731E,
	ADD_REASON_SYNCING = 0x8D4B4FF4,
	ADD_REASON_USE_FAILED = 0xD385B670
};

## _ADD_AMMO_TO_PED_BY_TYPE
`0x106A811C6D3035F3` | `void _ADD_AMMO_TO_PED_BY_TYPE(Ped ped, Hash ammoType, int amount, Hash addReason)` | build 1207
addReason: see _ADD_AMMO_TO_PED

## _ATTACH_WEAPON_TO_HORSE_HOLSTER
`0x14FF0C2545527F9B` | `void _ATTACH_WEAPON_TO_HORSE_HOLSTER(Ped horse, Hash weaponHash, Ped horseOwner)` | build 1207
Puts the gun visibly in your horse's holster without having to be close to the horse. Use 0xE9BD19F8121ADE3E before using this native
Notes:
- Must call _SEND_WEAPON_TO_INVENTORY (0xE9BD19F8121ADE3E) beforehand to move the weapon into the horse inventory. That native makes it accessible from the weapon wheel but not visible; this native makes it visible on the horse.
- Works at a distance; proximity to the horse is not required.

## _CAN_PED_ACCESS_MOUNT_WEAPONS
`0x23BF601A42F329A0` | `BOOL _CAN_PED_ACCESS_MOUNT_WEAPONS(Ped ped)` | build 1207
Returns true if the given ped is in a valid state to stow or retrieve weapons from their *owned* mount.
This typically means the ped is either on their horse or close enough to it for saddle weapon interactions.
Notes:
- The ped does **not** need to currently hold a weapon. This check simply determines if saddle stowing/retrieval actions are allowed.
- Commonly used to enable weapon wheel or stow prompts near the player’s own horse.
- Will return false if the ped is near a non-owned horse or too far from their own.

## _CLEAR_PED_LAST_WEAPON_DAMAGE
`0x087D8F4BC65F68E4` | `void _CLEAR_PED_LAST_WEAPON_DAMAGE(Ped ped)` | build 1207

## _CREATE_WEAPON_OBJECT
`0x9888652B8BA77F73` | `Object _CREATE_WEAPON_OBJECT(Hash weaponHash, int ammoCount, float x, float y, float z, BOOL showWorldModel, float scale)` | build 1207

## _DELETE_WEAPON_OBJECT_FROM_MOUNT
`0xD4C6E24D955FF061` | `void _DELETE_WEAPON_OBJECT_FROM_MOUNT(Ped horse)` | build 1311
Deletes the weapon object on the specified mount where its holstered.
Deletes all visible weapon PROP objects attached to the mount's holsters.
This ONLY removes objects; the weapons remain in inventory and are still accessible.

## _DISABLE_ALL_SPECIAL_AMMO_FOR_PED
`0xD63B4BA3A02A99E0` | `void _DISABLE_ALL_SPECIAL_AMMO_FOR_PED(Ped ped, Hash weaponHash)` | build 1207
Disables all special ammo types for the specified weapon on the given ped, forcing the weapon to use only its basic/regular ammunition.
- After calling this native, the weapon on that ped becomes restricted to regular ammo only.
- Works as a higher-level override compared to _DISABLE_AMMO_TYPE_FOR_PED and _DISABLE_AMMO_TYPE_FOR_PED_WEAPON, which target individual ammo types.
- Useful when ensuring a weapon cannot use any special ammo variants such as high velocity, express, explosive, or split point.

## _DISABLE_AMMO_TYPE_FOR_PED
`0xAA5A52204E077883` | `void _DISABLE_AMMO_TYPE_FOR_PED(Ped ped, Hash ammoHash)` | build 1207

## _DISABLE_AMMO_TYPE_FOR_PED_WEAPON
`0xF0D728EEA3C99775` | `void _DISABLE_AMMO_TYPE_FOR_PED_WEAPON(Ped ped, Hash weaponHash, Hash ammoHash)` | build 1207

## _DOES_PED_HAVE_PISTOL
`0xBFCA7AFABF9D7967` | `BOOL _DOES_PED_HAVE_PISTOL(Ped ped, int p1)` | build 1207
Returns whether the ped has a pistol p1: 0 or 1

## _DOES_PED_HAVE_REPEATER
`0x495A04CAEC263AF8` | `BOOL _DOES_PED_HAVE_REPEATER(Ped ped, int p1)` | build 1207
Returns whether the ped has a repeater p1: 0 or 1

## _DOES_PED_HAVE_REVOLVER
`0x5B235F24472F2C3B` | `BOOL _DOES_PED_HAVE_REVOLVER(Ped ped, int p1)` | build 1207
Returns whether the ped has a revolver p1: 0 or 1

## _DOES_PED_HAVE_RIFLE
`0x95CA12E2C68043E5` | `BOOL _DOES_PED_HAVE_RIFLE(Ped ped, int p1)` | build 1207
Returns whether the ped has a rifle p1: 0 or 1

## _DOES_PED_HAVE_SHOTGUN
`0xABC18A28BAD4B46F` | `BOOL _DOES_PED_HAVE_SHOTGUN(Ped ped, int p1)` | build 1207
Returns whether the ped has a shotgun p1: 0 or 1

## _DOES_PED_HAVE_SNIPER
`0x80BB243789008A82` | `BOOL _DOES_PED_HAVE_SNIPER(Ped ped, int p1)` | build 1207
Returns whether the ped has a sniper p1: 0 or 1

## _ENABLE_ALL_SPECIAL_AMMO_FOR_PED
`0x404514D231DB27A0` | `void _ENABLE_ALL_SPECIAL_AMMO_FOR_PED(Ped ped, Hash weaponHash)` | build 1207
Enables all special ammo types for the specified weapon on the given ped.
This is the inverse of _DISABLE_ALL_SPECIAL_AMMO_FOR_PED, restoring the ped’s ability to use any special ammo variants available for that weapon.
Restores full access to special ammo categories such as express, high velocity, split point, explosive, etc.

## _ENABLE_AMMO_TYPE_FOR_PED
`0x3B7B7908B7ADFB4B` | `void _ENABLE_AMMO_TYPE_FOR_PED(Ped ped, Hash weaponHash)` | build 1207

## _ENABLE_AMMO_TYPE_FOR_PED_WEAPON
`0x23FB9FACA28779C1` | `void _ENABLE_AMMO_TYPE_FOR_PED_WEAPON(Ped ped, Hash weaponHash, Hash ammoHash)` | build 1207

## _ENABLE_WEAPON_RESTORE
`0xC395355843BE134B` | `BOOL _ENABLE_WEAPON_RESTORE(Ped ped)` | build 1207

## _EXPLODE_PED_AMMO_TYPE
`0x44C8F4908F1B2622` | `void _EXPLODE_PED_AMMO_TYPE(Ped ped, Hash ammoHash)` | build 1207
Forces the detonation or effect of a throwable ammo type owned or placed by the specified ped.
Commonly used for remotely exploding dynamite that belong to the ped.
ammoHashes:
- joaat("AMMO_DYNAMITE")
- joaat("AMMO_MOLOTOV")
- joaat("AMMO_POISONBOTTLE")

## _GET_AMMO_IN_CLIP_BY_INVENTORY_UID
`0x678F00858980F516` | `BOOL _GET_AMMO_IN_CLIP_BY_INVENTORY_UID(Ped ped, int* ammo, Any* inventoryUid)` | build 1207

## _GET_AMMO_RECOMMENDED_TYPE_FOR_WEAPON
`0xEC97101A8F311282` | `Hash _GET_AMMO_RECOMMENDED_TYPE_FOR_WEAPON(Hash weaponHash)` | build 1207

## _GET_AMMO_TYPE_FOR_WEAPON
`0x5C2EA6C44F515F34` | `Hash _GET_AMMO_TYPE_FOR_WEAPON(Hash weaponHash)` | build 1207

## _GET_BEST_PED_WEAPON_IN_GROUP
`0x9F67929D98E7C6E8` | `Hash _GET_BEST_PED_WEAPON_IN_GROUP(Ped ped, Hash weaponGroup, BOOL p2, BOOL p3)` | build 1207
If near your horse when called, weapons stored on your horse will be considered
Returns weaponHash

## _GET_BEST_PED_WEAPON_IN_INVENTORY
`0x7B98500614C8E8B8` | `Any _GET_BEST_PED_WEAPON_IN_INVENTORY(Ped ped, Any p1, Any* guidPrimary)` | build 1232

## _GET_CAN_TWIRL_WEAPON
`0x6554ECCE226F2A2A` | `BOOL _GET_CAN_TWIRL_WEAPON(Hash weaponHash)` | build 1207

## _GET_CORRECT_KIT_EMOTE_TWIRL_GUN
`0xCD356B42C57BFE01` | `BOOL _GET_CORRECT_KIT_EMOTE_TWIRL_GUN(Ped ped, Any* weaponGuid)` | build 1355
_GET_BEST_* - _GET_CLOSEST_*

## _GET_CURRENT_AMMO_TYPE_FROM_GUID
`0xAF9D167A5656D6A6` | `Hash _GET_CURRENT_AMMO_TYPE_FROM_GUID(Ped ped, Any* weaponGuid)` | build 1207
Returns ammoHash

## _GET_CURRENT_PED_WEAPON_AMMO_TYPE
`0x7E7B19A4355FEE13` | `Hash _GET_CURRENT_PED_WEAPON_AMMO_TYPE(Ped ped, Object weaponObject)` | build 1207
Returns ammoHash from weaponObject (Returned by 0x6CA484C9A7377E4F)

## _GET_DEFAULT_PED_WEAPON_COLLECTION
`0xD42514C182121C23` | `Hash _GET_DEFAULT_PED_WEAPON_COLLECTION(Hash pedModel)` | build 1207
Returns weaponCollection Hash
Example: RE_POLICECHASE_MALES_01: Carbine Repeater + Knife, LO_AGRO_PED

## _GET_DEFAULT_UNARMED_WEAPON_HASH
`0x08FF1099ED2E6E21` | `Hash _GET_DEFAULT_UNARMED_WEAPON_HASH(Ped ped)` | build 1207
Returns the ped's default unarmed weapon hash as defined in CPedModelInfo (DefaultUnarmedWeapon).
Falls back to WEAPON_UNARMED if the ped doesn't have a valid model info pointer, or 0 if the ped doesn't exist.

## _GET_DEFAULT_WEAPON_ATTACH_POINT
`0x65DC4AC5B96614CB` | `int _GET_DEFAULT_WEAPON_ATTACH_POINT(Hash weaponHash)` | build 1311
Returns the attachpoint for a weapon hash. (returns -1 for melee as they can't be attached)

## _GET_IGNITED_PROJECTILE_IN_VOLUME
`0x74C8000FDD1BB111` | `Any _GET_IGNITED_PROJECTILE_IN_VOLUME(Volume volume, Any* outProjectile)` | build 1207
Returns the first ignited (lit/fused) explosive projectile entity found within the specified Volume.
Similar to WEAPON::_GET_FIRST_PROJECTILE_IN_VOLUME (0x74C8000FDD1BB222), but only returns projectiles that are currently ignited (e.g., a lit dynamite about to explode).

## _GET_LOCKON_RANGE_CURRENT_WEAPON
`0x3799EFCC3C8CD5E1` | `float _GET_LOCKON_RANGE_CURRENT_WEAPON(Ped ped)` | build 1207
Returns the effective lock-on or targeting range for the ped’s current weapon.
This value reflects the weapon’s maximum aim assist or targeting distance, used for systems like auto-aim and lock-on overrides.

## _GET_LONGARM_STORE_ON_DISMOUNT_STATE
`0x5A695BD328586B44` | `BOOL _GET_LONGARM_STORE_ON_DISMOUNT_STATE(Ped ped, int p1)` | build 1207
Returns the current state of longarm storage on dismount for the specified ped.

## _GET_MAX_LOCKON_DISTANCE_OF_CURRENT_PED_WEAPON
`0x79B1A6E780266DB0` | `float _GET_MAX_LOCKON_DISTANCE_OF_CURRENT_PED_WEAPON(Ped ped)` | build 1207

## _GET_NUM_PEDS_RESTRAINED_FROM_WEAPON_BOLAS
`0x46D42883E873C1D7` | `int _GET_NUM_PEDS_RESTRAINED_FROM_WEAPON_BOLAS(Ped ped)` | build 1232
returns the amount of peds that were restrained with the weapon thrown bolas

## _GET_PED_CAN_SWITCH_WEAPON
`0xBC9444F2FF94A9C0` | `BOOL _GET_PED_CAN_SWITCH_WEAPON(Ped ped)` | build 1355
Returns true if the ped can switch of weapon.

## _GET_PED_CURRENT_HELD_WEAPON
`0x8425C5F057012DAB` | `Hash _GET_PED_CURRENT_HELD_WEAPON(Ped ped)` | build 1207
Returns eCurrentHeldWeapon
_GET_R* - _GET_T*

## _GET_PED_GUN_SPINNING_EQUIPPED_KIT_EMOTE_TWIRL
`0x2C4FEC3D0EFA9FC0` | `Hash _GET_PED_GUN_SPINNING_EQUIPPED_KIT_EMOTE_TWIRL(Ped ped)` | build 1355
Returns emote Hash

## _GET_PED_GUN_SPINNING_HASH_FROM_WEAPON_EMOTE_VARIATION
`0xF3B1620B920D1708` | `Hash _GET_PED_GUN_SPINNING_HASH_FROM_WEAPON_EMOTE_VARIATION(Ped ped, int weaponEmoteVariation)` | build 1355
Returns iSpinHash / iVariationSpin

## _GET_PED_HOGTIE_WEAPON
`0x90EB1CB189923587` | `Hash _GET_PED_HOGTIE_WEAPON(Ped ped)` | build 1207

## _GET_PED_WEAPON_AMMO_FROM_GUID
`0x4823F13A21F51964` | `int _GET_PED_WEAPON_AMMO_FROM_GUID(Ped ped, Any* itemGuid)` | build 1207
returns the full amount of ammo that the ped has for the weapon by guid
```lua
local function inventoryGetGuidFromItemid(item, pGuid, slotId)
    local outGuid = DataView.ArrayBuffer(8 * 13)
    local result = Citizen.InvokeNative(0x886DFD3E185C8A89, 1, pGuid, item, slotId, outGuid:Buffer(), Citizen.ResultAsInteger());
    if result ~= 1 then return nil end
    return outGuid:Buffer();
end

RegisterCommand("getammo", function()
    local characterGuid = inventoryGetGuidFromItemid(`CHARACTER`, 0, `SLOTID_NONE`)
    if not characterGuid then return end

    local weaponGuid = inventoryGetGuidFromItemid(`CARRIED_WEAPONS`, characterGuid, `SLOTID_CARRIED_WEAPONS`)
    if not weaponGuid then return end

    local itemGuid = inventoryGetGuidFromItemid(`WEAPON_SNIPERRIFLE_CARCANO`, weaponGuid, `SLOTID_WEAPON_0`)
    if not itemGuid then return end

    local ammo = Citizen.InvokeNative(0x4823F13A21F51964, PlayerPedId(), itemGuid)
    print("ammo: " .. ammo)
end, false)
```

## _GET_PED_WEAPON_IN_SLOT
`0xDBC4B552B2AE9A83` | `Hash _GET_PED_WEAPON_IN_SLOT(Ped ped, Hash slotHash)` | build 1207
slotHash is usually just the weaponHash name, but WEAPON_* is replaced with SLOT_*

## _GET_PED_WEAPON_OBJECT
`0x6CA484C9A7377E4F` | `Object _GET_PED_WEAPON_OBJECT(Ped ped, BOOL p1)` | build 1207
_GET_M* - _GET_PED_A*

## _GET_PED_WORST_WEAPON
`0xDA37A053C1522F5D` | `Hash _GET_PED_WORST_WEAPON(Ped ped, BOOL p1, BOOL p2, BOOL p3)` | build 1207

## _GET_PLAYER_PED_QUICK_SWAP_WEAPON_BY_GUID
`0xB7E52A058B07C7E2` | `void _GET_PLAYER_PED_QUICK_SWAP_WEAPON_BY_GUID(Ped ped, Any* guidPrimary, Any* guidSecondary)` | build 1232
Outputs cached guids

## _GET_PROJECTILE_IN_VOLUME
`0x74C8000FDD1BB222` | `Any _GET_PROJECTILE_IN_VOLUME(Volume volume, Any* outProjectile)` | build 1207

## _GET_WEAPONTYPE_MODEL
`0xF70825EB340E7D15` | `Hash _GET_WEAPONTYPE_MODEL(Hash weaponHash)` | build 1207
Gets the model hash from the weapon hash.

## _GET_WEAPONTYPE_SLOT
`0x46F032B8DDF46CDE` | `Hash _GET_WEAPONTYPE_SLOT(Hash weaponHash)` | build 1207
Returns hash where WEAPON_ is replaced with SLOT_

## _GET_WEAPON_ATTACH_POINT
`0xCAD4FE9398820D24` | `int _GET_WEAPON_ATTACH_POINT(Ped ped, int attachPoint)` | build 1207
Returns WeaponAttachPoint

## _GET_WEAPON_COMPONENT_TYPE_MODEL
`0x59DE03442B6C9598` | `Hash _GET_WEAPON_COMPONENT_TYPE_MODEL(Hash componentHash)` | build 1207

## _GET_WEAPON_DAMAGE
`0x904103D5D2333977` | `float _GET_WEAPON_DAMAGE(Object weaponObject)` | build 1207
Related to weapon visual damage, not actual damage.

## _GET_WEAPON_DIRT
`0x810E8AE9AFEA7E54` | `float _GET_WEAPON_DIRT(Object weaponObject)` | build 1207

## _GET_WEAPON_EMOTE_VARIATION
`0x86147D05FA831D3A` | `int _GET_WEAPON_EMOTE_VARIATION(Ped ped, int variation)` | build 1355
Returns weaponEmoteVariation

WEAPON_EMOTE_VARIATION_INVALID = -2,
WEAPON_EMOTE_VARIATION_BASE,
WEAPON_EMOTE_VARIATION_A,
WEAPON_EMOTE_VARIATION_B,
WEAPON_EMOTE_VARIATION_C,
WEAPON_EMOTE_VARIATION_D,
WEAPON_EMOTE_VARIATION_PREVIEW,
WEAPON_EMOTE_NUM_VARIATIONS

## _GET_WEAPON_FROM_DEFAULT_PED_WEAPON_COLLECTION
`0x9EEFD670F10656D7` | `Hash _GET_WEAPON_FROM_DEFAULT_PED_WEAPON_COLLECTION(Hash weaponCollection, Hash weaponGroup)` | build 1207
this native gets the weapon hash from the default ped weapon collection (see GetDefaultPedWeaponCollection for more info) will randomly return one of it's weapons
```lua
local pedWeaponCollectionHash = GetDefaultPedWeaponCollection(joaat("mp_u_m_m_interrogator_01"))
local hash = Citizen.InvokeNative(0x9EEFD670F10656D7, pedWeaponCollectionHash, joaat("GROUP_REVOLVER"))
if hash and IsWeaponValid(hash) then
local name = GetWeaponName(hash)
local label = GetLabelText_2(name)
print(name, label)
end
```

## _GET_WEAPON_FROM_MOUNT
`0xAFFD0CCF31F469B8` | `Hash _GET_WEAPON_FROM_MOUNT(Ped mount)` | build 1207
Returns the weapon hash stored in the first holster slot of the specified mount.
returns 0 if no weapon or invalid

## _GET_WEAPON_GUN_SPINNING_WEAPON_EMOTE_TRICK_TYPE_HASH
`0xF4601C1203B1A78D` | `Hash _GET_WEAPON_GUN_SPINNING_WEAPON_EMOTE_TRICK_TYPE_HASH(Hash emote, int weaponEmoteTrickType)` | build 1207
Returns iSpinHash

## _GET_WEAPON_HAS_MULTIPLE_AMMO_TYPES
`0x58425FCA3D3A2D15` | `BOOL _GET_WEAPON_HAS_MULTIPLE_AMMO_TYPES(Hash weaponHash)` | build 1207
Returns whether the weapon has multiple ammo types or not.

## _GET_WEAPON_LAST_GIVEN
`0x9F0E1892C7F228A8` | `Any _GET_WEAPON_LAST_GIVEN(BOOL p0)` | build 1207
gets the last weapon given to ped , if you give a weapon_lasso to ped and then give another it returns the weapon_lasso other wise 0,p0 usually is 1 is unknown, it does not work for all weapons.

## _GET_WEAPON_NAME
`0x89CF5FF3D363311E` | `const char* _GET_WEAPON_NAME(Hash weaponHash)` | build 1207
Returns "WNS_INVALID" if the weapon is invalid/doesn't exist.

## _GET_WEAPON_NAME_2
`0x6D3AC61694A791C5` | `const char* _GET_WEAPON_NAME_2(Hash weaponHash)` | build 1207

## _GET_WEAPON_NAME_WITH_PERMANENT_DEGRADATION
`0x7A56D66C78D8EF8E` | `const char* _GET_WEAPON_NAME_WITH_PERMANENT_DEGRADATION(Hash weaponHash, float permanentDegradationLevel)` | build 1207

## _GET_WEAPON_OBJECT_FROM_PED
`0xC6A6789BB405D11C` | `Object _GET_WEAPON_OBJECT_FROM_PED(Ped ped, BOOL p1)` | build 1207
Detaches the weapon from the ped and actually removes the ped's weapon

## _GET_WEAPON_SCALE
`0x22084CA699219624` | `float _GET_WEAPON_SCALE(Object weaponObject)` | build 1207

## _GET_WEAPON_SOOT
`0x4BF66F8878F67663` | `float _GET_WEAPON_SOOT(Object weaponObject)` | build 1207

## _GET_WEAPON_STAT_ID
`0x8EC44AE8DECFF841` | `Hash _GET_WEAPON_STAT_ID(Hash weaponHash)` | build 1207

## _GET_WEAPON_TYPE_FROM_AMMO_TYPE
`0x7AA043F6C41D151E` | `Hash _GET_WEAPON_TYPE_FROM_AMMO_TYPE(Hash ammoType)` | build 1207

## _GET_WEAPON_UNLOCK
`0x865F36299079FB75` | `Hash _GET_WEAPON_UNLOCK(Hash weaponHash)` | build 1207

## _GIVE_WEAPON_COLLECTION_TO_PED
`0x899A04AFCC725D04` | `void _GIVE_WEAPON_COLLECTION_TO_PED(Ped ped, Hash weaponCollection)` | build 1207

## _GIVE_WEAPON_COMPONENT_TO_ENTITY
`0x74C9090FDD1BB48E` | `void _GIVE_WEAPON_COMPONENT_TO_ENTITY(Entity entity, Hash componentHash, Hash weaponHash, BOOL p3)` | build 1207
entity can be a ped or weapon object.

## _GIVE_WEAPON_COMPONENT_TO_WEAPON_OBJECT
`0x1A47699E8D533E8F` | `void _GIVE_WEAPON_COMPONENT_TO_WEAPON_OBJECT(Object* weaponObject, Ped ped, Hash componentHash, BOOL p3)` | build 1207

## _HAS_ENTITY_BEEN_DAMAGED_BY_WEAPON
`0xDCF06D0CDFF68424` | `BOOL _HAS_ENTITY_BEEN_DAMAGED_BY_WEAPON(Entity entity, Hash weaponName, int weaponType)` | build 1207

## _HAS_ENTITY_BEEN_DAMAGED_BY_WEAPON_RECENTLY
`0x9E2D5D6BC97A5F1E` | `BOOL _HAS_ENTITY_BEEN_DAMAGED_BY_WEAPON_RECENTLY(Entity entity, Hash weaponHash, int ms)` | build 1207

## _HAS_PED_GOT_WEAPON_COMPONENT
`0xBBC67A6F965C688A` | `BOOL _HAS_PED_GOT_WEAPON_COMPONENT(Ped ped, Hash componentHash, Hash weaponHash)` | build 1207

## _HAS_WEAPON_ASSET_LOADED
`0xFF07CF465F48B830` | `BOOL _HAS_WEAPON_ASSET_LOADED(Hash weaponHash)` | build 1207

## _HIDE_PED_WEAPONS
`0xFCCC886EDE3C63EC` | `void _HIDE_PED_WEAPONS(Ped ped, int p0, BOOL immediately)` | build 1207
Unequip current weapon and set current weapon to WEAPON_UNARMED.
p0 usually 2 in R* scripts. Doesn't seem to have any effect if changed....
immediately: if true it will instantly switch to unarmed

## _HOLSTER_PED_WEAPONS
`0x94A3C1B804D291EC` | `void _HOLSTER_PED_WEAPONS(Ped ped, BOOL p1, BOOL p2, BOOL p3, BOOL immediately)` | build 1207

## _IS_AMMO_SILENT
`0xD2866CBA797E872E` | `BOOL _IS_AMMO_SILENT(Hash ammoHash)` | build 1232

## _IS_AMMO_SILENT_2
`0x7EFACC589B98C488` | `BOOL _IS_AMMO_SILENT_2(Hash ammoHash)` | build 1207

## _IS_AMMO_TYPE_VALID_FOR_WEAPON
`0xC570B881754DF609` | `BOOL _IS_AMMO_TYPE_VALID_FOR_WEAPON(Hash weaponHash, Hash ammoHash)` | build 1207

## _IS_AMMO_VALID
`0x1F7977C9101F807F` | `BOOL _IS_AMMO_VALID(Hash ammoHash)` | build 1207

## _IS_PED_CARRYING_BACKUP_WEAPON
`0x486C96A0DCD2BC92` | `BOOL _IS_PED_CARRYING_BACKUP_WEAPON(Ped ped, int attachPoint)` | build 1232
true if there is a back up ped weapon get it using GET_PED_BACKUP_WEAPON

## _IS_PED_CARRYING_WEAPON_SNIPER_AT_ATTACH_POINT
`0xD2209866B0CB72EA` | `BOOL _IS_PED_CARRYING_WEAPON_SNIPER_AT_ATTACH_POINT(Ped ped, int attachPoint)` | build 1207
Returns true if the ped has a sniper-type weapon equipped or stored in the specified attach point (slot).

## _IS_PED_CURRENT_WEAPON_HOLSTERED
`0xBDD9C235D8D1052E` | `BOOL _IS_PED_CURRENT_WEAPON_HOLSTERED(Ped ped)` | build 1207

## _IS_PED_HOLDING_WEAPON
`0x07E1C35F0078C3F9` | `BOOL _IS_PED_HOLDING_WEAPON(Ped ped, Hash weapon)` | build 1207
Returns whether the specified ped is holding a weapon with the given hash.
only these weapons below return true
 WEAPON_BOW, WEAPON_KIT_METAL_DETECTOR, WEAPON_MELEE_CLEAVER, WEAPON_MELEE_DAVY_LANTERN, WEAPON_MELEE_HATCHET, WEAPON_MELEE_HATCHET_HUNTER, WEAPON_MELEE_KNIFE_JAWBONE, WEAPON_MELEE_LANTERN WEAPON_MELEE_TORCH, WEAPON_MOONSHINEJUG_MP, WEAPON_RIFLE_BOLTACTION, WEAPON_SHOTGUN_PUMP, WEAPON_THROWN_BOLAS, WEAPON_THROWN_MOLOTOV

## _IS_PED_TAKING_POISON_GAS_DAMAGE
`0x0DE0944ECCB3DF5D` | `BOOL _IS_PED_TAKING_POISON_GAS_DAMAGE(Ped ped)` | build 1232
Checks whether the given ped is currently taking damage from poisonous gas/fog volumes (e.g., toxic moonshine cloud, scripted poison fog).

## _IS_TARGET_PED_CONSTRAINED_BY_PED_USING_BOLAS
`0x8D50F43298AB9545` | `BOOL _IS_TARGET_PED_CONSTRAINED_BY_PED_USING_BOLAS(Ped ped, Ped targetPed)` | build 1232

## _IS_WEAPON_BINOCULARS
`0xC853230E76A152DF` | `BOOL _IS_WEAPON_BINOCULARS(Hash weaponHash)` | build 1207

## _IS_WEAPON_CLOSE_RANGE
`0xEA522F991E120D45` | `BOOL _IS_WEAPON_CLOSE_RANGE(Hash weaponHash)` | build 1207
_IS_WEAPON_CLOSE_RANGE?
returns true when it's lassos , melee, thrown weapons (matchetes and unarmed return false)
all guns ,bows and animal weapons return false

## _IS_WEAPON_HOLSTER_STATE_CHANGING
`0x2387D6E9C6B478AA` | `BOOL _IS_WEAPON_HOLSTER_STATE_CHANGING(Ped ped)` | build 1207
Returns true if the ped is currently holstering or unholstering a weapon

## _IS_WEAPON_KIT
`0x6ABAD7B0A854F8FB` | `BOOL _IS_WEAPON_KIT(Hash weaponHash)` | build 1207
Returns true when the weapon passed is either a lasso, the camera or the binoculars
_IS_WEAPON_M* - _IS_WEAPON_P*

## _IS_WEAPON_KIT_2
`0x49E40483948AF062` | `BOOL _IS_WEAPON_KIT_2(Hash weaponHash)` | build 1207
Returns true when the weapon passed is either the fishingrod, a lasso, the camera or the binoculars
_IS_WEAPON_M* - _IS_WEAPON_P*

## _IS_WEAPON_KNIFE
`0x792E3EF76C911959` | `BOOL _IS_WEAPON_KNIFE(Hash weaponHash)` | build 1207

## _IS_WEAPON_LANTERN
`0x79407D33328286C6` | `BOOL _IS_WEAPON_LANTERN(Hash weaponHash)` | build 1207

## _IS_WEAPON_LASSO
`0x6E4E1A82081EABED` | `BOOL _IS_WEAPON_LASSO(Hash weaponHash)` | build 1207

## _IS_WEAPON_ONE_HANDED
`0xD955FEE4B87AFA07` | `BOOL _IS_WEAPON_ONE_HANDED(Hash weaponHash)` | build 1207

## _IS_WEAPON_SILENT
`0x5809DBCA0A37C82B` | `BOOL _IS_WEAPON_SILENT(Hash weaponHash)` | build 1207

## _IS_WEAPON_SNIPER
`0x6AD66548840472E5` | `BOOL _IS_WEAPON_SNIPER(Hash weaponHash)` | build 1207

## _IS_WEAPON_THROWABLE
`0x30E7C16B12DA8211` | `BOOL _IS_WEAPON_THROWABLE(Hash weaponHash)` | build 1207

## _IS_WEAPON_TORCH
`0x506F1DE1BFC75304` | `BOOL _IS_WEAPON_TORCH(Hash weaponHash)` | build 1207

## _IS_WEAPON_TWO_HANDED
`0x0556E9D2ECF39D01` | `BOOL _IS_WEAPON_TWO_HANDED(Hash weaponHash)` | build 1207

## _LISTEN_PROJECTILE_HIT_EVENTS
`0xDA5D3F2C6DD5B5D4` | `void _LISTEN_PROJECTILE_HIT_EVENTS(BOOL listen)` | build 1207

## _MAKE_PED_RELOAD
`0x79E1E511FF7EFB13` | `Any _MAKE_PED_RELOAD(Ped ped)` | build 1207
only works if there is ammo in the reserve, can reload while sprinting/walking/running

## _REFILL_AMMO_IN_CLIP
`0xDF4A3404D022ADDE` | `Any _REFILL_AMMO_IN_CLIP(Ped ped, Any* clipInventoryUid, int p2)` | build 1207

## _REFILL_AMMO_IN_CURRENT_PED_WEAPON
`0x0A2AB7B7ABC055F4` | `Any _REFILL_AMMO_IN_CURRENT_PED_WEAPON(Ped ped)` | build 1207

## _REGISTER_WEAPON_OBJECT_FOR_IGNITION
`0x74C90AAACC1DD48F` | `void _REGISTER_WEAPON_OBJECT_FOR_IGNITION(Entity weaponObject)` | build 1207
Marks a created weapon object (e.g., a dynamite weapon object) as ignitable so it can be lit and detonate.
Use this after CreateWeaponObject for thrown explosives to enable fuse/ignition behavior.
weaponObject: Weapon object entity created via CreateWeaponObject (e.g., WEAPON_THROWN_DYNAMITE)

## _REMOVE_ALL_PED_AMMO
`0x1B83C0DEEBCBB214` | `void _REMOVE_ALL_PED_AMMO(Ped ped)` | build 1207

## _REMOVE_AMMO_FROM_PED
`0xF4823C813CB8277D` | `void _REMOVE_AMMO_FROM_PED(Ped ped, Hash weaponHash, int amount, Hash removeReason)` | build 1207
removeReason must be REMOVE_REASON_USED, REMOVE_REASON_GIVEN, REMOVE_REASON_DROPPED or REMOVE_REASON_DEBUG, unless amount is -1

removeReason: see REMOVE_WEAPON_FROM_PED

## _REMOVE_AMMO_FROM_PED_BY_TYPE
`0xB6CFEC32E3742779` | `void _REMOVE_AMMO_FROM_PED_BY_TYPE(Ped ped, Hash ammoHash, int amount, Hash removeReason)` | build 1207
removeReason must be REMOVE_REASON_USED, REMOVE_REASON_GIVEN, REMOVE_REASON_DROPPED or REMOVE_REASON_DEBUG, unless amount is -1

removeReason: see REMOVE_WEAPON_FROM_PED

## _REMOVE_WEAPON_ASSET
`0xC3896D03E2852236` | `void _REMOVE_WEAPON_ASSET(Hash weaponHash)` | build 1207

## _REMOVE_WEAPON_COMPONENT_FROM_PED
`0x19F70C4D80494FF8` | `void _REMOVE_WEAPON_COMPONENT_FROM_PED(Ped ped, Hash componentHash, Hash weaponHash)` | build 1207

## _REMOVE_WEAPON_FROM_PED_BY_GUID
`0x51C3B71591811485` | `void _REMOVE_WEAPON_FROM_PED_BY_GUID(Ped ped, Any* weaponGuid, Hash removeReason)` | build 1311

## _REQUEST_WEAPON_ASSET
`0x72D4CB5DB927009C` | `void _REQUEST_WEAPON_ASSET(Hash weaponHash, int p1, BOOL p2)` | build 1207

## _SEND_WEAPON_TO_INVENTORY
`0xE9BD19F8121ADE3E` | `void _SEND_WEAPON_TO_INVENTORY(Ped ped, Hash weaponHash)` | build 1207
Appears to just send specified weapon to your horse holster without having to be close
However, the weapon is not visible on the horse holster, but you can reach the weapon on the weapon wheel

## _SET_ACTIVE_GUN_SPINNING_EQUIP_KIT_EMOTE_TWIRL
`0xCBCFFF805F1B4596` | `void _SET_ACTIVE_GUN_SPINNING_EQUIP_KIT_EMOTE_TWIRL(Ped ped, Hash emote)` | build 1311
emote hashes: KIT_EMOTE_TWIRL_GUN, KIT_EMOTE_TWIRL_GUN_LEFT_HOLSTER, KIT_EMOTE_TWIRL_GUN_DUAL, 0 (to unequip)

## _SET_ACTIVE_GUN_SPINNING_KIT_EMOTE_TWIRL
`0x01F661BB9C71B465` | `void _SET_ACTIVE_GUN_SPINNING_KIT_EMOTE_TWIRL(Ped ped, int weaponEmoteTrickType, Hash spin)` | build 1207
spinHash can be -1, 0 to disable

## _SET_ALLOW_DUAL_WIELD
`0x83B8D50EB9446BBA` | `void _SET_ALLOW_DUAL_WIELD(Ped ped, BOOL allow)` | build 1207

## _SET_AMMO_IN_TURRET
`0xBDDA0C290C228159` | `void _SET_AMMO_IN_TURRET(Vehicle vehicle, Hash turretHash, int ammo)` | build 1207
turretHash: WEAPON_TURRET_MAXIUM, WEAPON_TURRET_GATLING, WEAPON_TURRET_CANNON, WEAPON_TURRET_REVOLVING_CANNON

## _SET_AMMO_TYPE_FOR_PED_WEAPON
`0xCC9C4393523833E2` | `void _SET_AMMO_TYPE_FOR_PED_WEAPON(Ped ped, Hash weaponHash, Hash ammoHash)` | build 1207

## _SET_AMMO_TYPE_FOR_PED_WEAPON_INVENTORY
`0xEBE46B501BC3FBCF` | `void _SET_AMMO_TYPE_FOR_PED_WEAPON_INVENTORY(Ped ped, Any* weaponInventoryUid, Hash ammoHash)` | build 1207

## _SET_ARROW_TRAIL_FX
`0x2EBF70E1D8C06683` | `void _SET_ARROW_TRAIL_FX(Ped ped, Hash trailHash)` | build 1207
Sets the visual trail FX for arrows fired from a Bow by the given ped

## _SET_FORCE_AUTO_EQUIP
`0xBE711B14A159E84F` | `void _SET_FORCE_AUTO_EQUIP(Ped ped, BOOL toggle)` | build 1207

## _SET_FORCE_CURRENT_WEAPON_INTO_COCKED_STATE
`0x5230D3F6EE56CFE6` | `void _SET_FORCE_CURRENT_WEAPON_INTO_COCKED_STATE(Ped ped, int attachPoint)` | build 1207

## _SET_GUN_SPINNING_INVENTORY_SLOT_ID_ACTIVATE
`0x408CF580C5E96D49` | `void _SET_GUN_SPINNING_INVENTORY_SLOT_ID_ACTIVATE(Ped ped, int emoteType)` | build 1355
_STOP_* - _TEST_*

## _SET_INSTANTLY_STORE_LONGARMS_ON_DISMOUNT
`0xB832F1A686B9B810` | `void _SET_INSTANTLY_STORE_LONGARMS_ON_DISMOUNT(Ped ped, BOOL storeLongarms, int p2)` | build 1207
Stores longarms to your horse on dismount
Params: p2 = 0
SET_[I - M]*

## _SET_PED_ALL_WEAPONS_VISIBILITY
`0x4F806A6CFED89468` | `void _SET_PED_ALL_WEAPONS_VISIBILITY(Ped ped, BOOL visible)` | build 1207

## _SET_PED_INFINITE_AMMO_CLIP
`0xFBAA1E06B6BCA741` | `void _SET_PED_INFINITE_AMMO_CLIP(Ped ped, BOOL toggle)` | build 1207

## _SET_PED_WEAPON_ATTACH_POINT_VISIBILITY
`0x67E21ACC5C0C970C` | `void _SET_PED_WEAPON_ATTACH_POINT_VISIBILITY(Ped ped, int attachPoint, BOOL visible)` | build 1207
attachPoint: see SET_CURRENT_PED_WEAPON

## _SET_PED_WEAPON_ON_BACK
`0x4820A6939D7CEF28` | `void _SET_PED_WEAPON_ON_BACK(Ped ped, BOOL disableAnim)` | build 1207
Holster the holded shoulder weapon. Precisions: 0 means with anim while 1 means direct holster

## _SET_PROJECTILE_EFFECT_RADIUS
`0x74C9080FDD1BB48F` | `void _SET_PROJECTILE_EFFECT_RADIUS(Entity projectile, float radius)` | build 1207
Sets the explosion or impact effect radius of a projectile entity (e.g., thrown dynamite or similar explosives).
Notes:
- Must be called before the projectile explodes; changing the radius afterward has no effect.
- Commonly used after retrieving the projectile entity with MISC::GET_PROJECTILE_OF_PROJECTILE_TYPE_WITHIN_DISTANCE.
- This does not trigger an explosion; it only defines how large the explosion’s area of effect will be.
- Compared to MISC::ADD_EXPLOSION, which spawns a new explosion at a location, this modifies an existing projectile’s explosion properties.

## _SET_PROJECTILE_FUSE_TIME
`0x74C9080FDD1BB48E` | `void _SET_PROJECTILE_FUSE_TIME(Entity projectile, float fuseTime)` | build 1207
Sets the remaining fuse time (in seconds) for an ignited explosive projectile entity, such as a thrown dynamite.
 Must be called on an already ignited projectile; calling before ignition has no effect.

## _SET_VEHICLE_WEAPON_HEADING_LIMITS
`0x56CB3B4305A4F7CE` | `void _SET_VEHICLE_WEAPON_HEADING_LIMITS(Vehicle vehicle, int p1, float minHeading, float maxHeading)` | build 1207

## _SET_VEHICLE_WEAPON_HEADING_LIMITS_2
`0xBF5987E1CDE63501` | `Any _SET_VEHICLE_WEAPON_HEADING_LIMITS_2(Vehicle vehicle, int p1, float minHeading, float maxHeading)` | build 1207

## _SET_VEHICLE_WEAPON_RELOAD_MODE
`0x8A779706DA5CA3DD` | `void _SET_VEHICLE_WEAPON_RELOAD_MODE(Vehicle vehicle, BOOL noReload, int p2)` | build 1207
Enables/disables reload behavior for vehicle-mounted **cannons**.
When noReload is true, the cannon fires without requiring a reload; when false, it must reload after shots.
Supported vehicles only:**breach_cannon** and **hotchkiss_cannon**

## _SET_WEAPON_DAMAGE
`0xE22060121602493B` | `void _SET_WEAPON_DAMAGE(Object weaponObject, float level, BOOL p2)` | build 1207
Related to weapon visual damage, not actual damage.

## _SET_WEAPON_DEGRADATION
`0xA7A57E89E965D839` | `void _SET_WEAPON_DEGRADATION(Object weaponObject, float level)` | build 1207

## _SET_WEAPON_DIRT
`0x812CE61DEBCAB948` | `void _SET_WEAPON_DIRT(Object weaponObject, float level, BOOL p2)` | build 1207

## _SET_WEAPON_LEVEL_THRESHOLD
`0xD4071EFC83794B2F` | `void _SET_WEAPON_LEVEL_THRESHOLD(Object weaponObject, float threshold)` | build 1207
every other level will have the max value of (brokeLevel - threshold)

## _SET_WEAPON_SCALE
`0xC3544AD0522E69B4` | `void _SET_WEAPON_SCALE(Object weaponObject, float scale)` | build 1207

## _SET_WEAPON_SOOT
`0xA9EF4AD10BDDDB57` | `void _SET_WEAPON_SOOT(Object weaponObject, float level, BOOL p2)` | build 1207
