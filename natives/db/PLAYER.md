# PLAYER natives (395)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## BOOST_PLAYER_HORSE_SPEED_FOR_TIME
`0x09C28F828EE674FA` | `void BOOST_PLAYER_HORSE_SPEED_FOR_TIME(Player player, float speedBoost, int duration)` | build 1207

## CAN_PLAYER_START_MISSION
`0x2DF170B1185AF777` | `BOOL CAN_PLAYER_START_MISSION(Player player)` | build 1207

## CLEAR_PLAYER_HAS_DAMAGED_AT_LEAST_ONE_NON_ANIMAL_PED
`0x0361096D6CE4372C` | `void CLEAR_PLAYER_HAS_DAMAGED_AT_LEAST_ONE_NON_ANIMAL_PED(Player player)` | build 1207

## CLEAR_PLAYER_HAS_DAMAGED_AT_LEAST_ONE_PED
`0x270B63A641BE32F2` | `void CLEAR_PLAYER_HAS_DAMAGED_AT_LEAST_ONE_PED(Player player)` | build 1207

## CLEAR_PLAYER_WANTED_LEVEL
`0x4E4B996C928C7AA6` | `void CLEAR_PLAYER_WANTED_LEVEL(Player player)` | build 1207
nullsub, doesn't do anything

## DISABLE_PLAYER_FIRING
`0x2970929FD5F9FC89` | `void DISABLE_PLAYER_FIRING(Player player, BOOL toggle)` | build 1207
Inhibits the player from using any method of combat including melee and firearms.

NOTE: Only disables the firing for one frame

## EAGLE_EYE_SET_CUSTOM_ENTITY_TINT
`0x62ED71E133B6C9F1` | `void EAGLE_EYE_SET_CUSTOM_ENTITY_TINT(Entity entity, int red, int green, int blue)` | build 1207

## FORCE_CLEANUP
`0x768C017FB878E4F4` | `void FORCE_CLEANUP(int cleanupFlags)` | build 1207

## FORCE_CLEANUP_FOR_ALL_THREADS_WITH_THIS_NAME
`0xDAACAF8B687F2353` | `void FORCE_CLEANUP_FOR_ALL_THREADS_WITH_THIS_NAME(char* name, int cleanupFlags)` | build 1207

## FORCE_CLEANUP_FOR_THREAD_WITH_THIS_ID
`0xF4C9512A2F0A3031` | `void FORCE_CLEANUP_FOR_THREAD_WITH_THIS_ID(int id, int cleanupFlags)` | build 1207

## GET_CAUSE_OF_MOST_RECENT_FORCE_CLEANUP
`0x84E8E29EBD4A46D2` | `int GET_CAUSE_OF_MOST_RECENT_FORCE_CLEANUP()` | build 1207

## GET_DISCOVERABLE_NAME_HASH_AND_TYPE_FOR_ENTITY
`0x0139637A3BFF8B6D` | `Hash GET_DISCOVERABLE_NAME_HASH_AND_TYPE_FOR_ENTITY(Entity entity, Hash* type)` | build 1207
Returns name hash (name) and outHash includes the type.

## GET_ENTITY_PLAYER_IS_FREE_AIMING_AT
`0xA6817C110B830EAD` | `BOOL GET_ENTITY_PLAYER_IS_FREE_AIMING_AT(Player player, Entity* entity)` | build 1207

## GET_HAS_PLAYER_DISCOVERED_CHARACTER_NAME_MP
`0x354F689C4FFAAB37` | `BOOL GET_HAS_PLAYER_DISCOVERED_CHARACTER_NAME_MP(Hash discoveryHash)` | build 1207

## GET_IS_PLAYER_UI_PROMPT_ACTIVE
`0x51BEA356B1C60225` | `BOOL GET_IS_PLAYER_UI_PROMPT_ACTIVE(Player player, int p1)` | build 1207

## GET_MAX_WANTED_LEVEL
`0xD04CFAD1E2B7984A` | `int GET_MAX_WANTED_LEVEL()` | build 1207
Gets the maximum wanted level the player can get.
Ranges from 0 to 5.

## GET_MOUNT_OWNED_BY_PLAYER
`0xF49F14462F0AE27C` | `Ped GET_MOUNT_OWNED_BY_PLAYER(Player player)` | build 1207

## GET_PLAYERS_LAST_VEHICLE
`0x2F96E7720B0B19EA` | `Vehicle GET_PLAYERS_LAST_VEHICLE()` | build 1207

## GET_PLAYER_CURRENT_STEALTH_NOISE
`0xD7ECC25E176ECBA5` | `float GET_PLAYER_CURRENT_STEALTH_NOISE(Player player)` | build 1207

## GET_PLAYER_GROUP
`0x9BAB31815159ABCF` | `int GET_PLAYER_GROUP(Player player)` | build 1207
Returns the group ID the player is member of.

## GET_PLAYER_INDEX
`0x47E385B0D957C8D4` | `Player GET_PLAYER_INDEX()` | build 1207
Returns the same as PLAYER_ID and NETWORK_PLAYER_ID_TO_INT

## GET_PLAYER_INTERACTION_TARGET_ENTITY
`0x3EE1F7A8C32F24E1` | `BOOL GET_PLAYER_INTERACTION_TARGET_ENTITY(Player player, Entity* outEntity, BOOL p2, BOOL p3)` | build 1207

## GET_PLAYER_INVINCIBLE
`0x0CBBCB2CCFA7DC4E` | `BOOL GET_PLAYER_INVINCIBLE(Player player)` | build 1207
Returns the player's invincibility status.

## GET_PLAYER_NAME
`0x7124FD9AC0E01BA0` | `const char* GET_PLAYER_NAME(Player player)` | build 1207

## GET_PLAYER_PED
`0x275F255ED201B937` | `Ped GET_PLAYER_PED(Player player)` | build 1207

## GET_PLAYER_PED_SCRIPT_INDEX
`0x5C880F9056D784C8` | `Ped GET_PLAYER_PED_SCRIPT_INDEX(Player player)` | build 1207
Does the same like PLAYER::GET_PLAYER_PED

## GET_PLAYER_RECEIVED_BATTLE_EVENT_RECENTLY
`0xFB6EB8785F808551` | `BOOL GET_PLAYER_RECEIVED_BATTLE_EVENT_RECENTLY(Player player, int p1, BOOL p2)` | build 1207

## GET_PLAYER_TARGET_ENTITY
`0xAE663DDD99C8A670` | `BOOL GET_PLAYER_TARGET_ENTITY(Player player, Entity* entity)` | build 1207

## GET_PLAYER_TEAM
`0xB464EB6A40C7975B` | `int GET_PLAYER_TEAM(Player player)` | build 1207
Gets the player's team.
Returns -1 in singleplayer.

## GET_PLAYER_WANTED_LEVEL
`0xABC532F9098BFD9D` | `int GET_PLAYER_WANTED_LEVEL(Player player)` | build 1207

## GET_TARGET_CHARACTER_NAME_FOR_LOCAL_PLAYER
`0x36E3D8B5A6552FE8` | `Hash GET_TARGET_CHARACTER_NAME_FOR_LOCAL_PLAYER(Ped ped)` | build 1207

## GET_TARGET_CHARACTER_NAME_SCRIPT_OVERRIDE_HASH
`0x0335106F3ACABBED` | `Hash GET_TARGET_CHARACTER_NAME_SCRIPT_OVERRIDE_HASH(Ped ped)` | build 1207

## GET_TARGET_CHARACTER_NAME_SCRIPT_OVERRIDE_RAW_STRING
`0x755E08680F21EF30` | `const char* GET_TARGET_CHARACTER_NAME_SCRIPT_OVERRIDE_RAW_STRING(Ped ped)` | build 1207

## GET_WANTED_LEVEL_RADIUS
`0x80B00EB26D9521C7` | `float GET_WANTED_LEVEL_RADIUS(int wantedLevel)` | build 1207
level 0 60.0 level 1 75.0 level 2 90.0 max level is 5 200.0 radius

## GET_WANTED_LEVEL_THRESHOLD
`0x1B1A3B358F7D8F07` | `int GET_WANTED_LEVEL_THRESHOLD(int wantedLevel)` | build 1207

## HAS_FORCE_CLEANUP_OCCURRED
`0xC11469DCA6FC3BB5` | `BOOL HAS_FORCE_CLEANUP_OCCURRED(int cleanupFlags)` | build 1207

## HAS_PLAYER_BEEN_SPOTTED_IN_STOLEN_VEHICLE
`0xC932F57F31EA9152` | `BOOL HAS_PLAYER_BEEN_SPOTTED_IN_STOLEN_VEHICLE(Player player)` | build 1207

## HAS_PLAYER_DAMAGED_AT_LEAST_ONE_NON_ANIMAL_PED
`0x16C8D205DD5A2E90` | `BOOL HAS_PLAYER_DAMAGED_AT_LEAST_ONE_NON_ANIMAL_PED(Player player)` | build 1207

## HAS_PLAYER_DAMAGED_AT_LEAST_ONE_PED
`0xDA4A4B9B96E20092` | `BOOL HAS_PLAYER_DAMAGED_AT_LEAST_ONE_PED(Player player)` | build 1207

## INT_TO_PARTICIPANTINDEX
`0x58FF971FC8F2702C` | `int INT_TO_PARTICIPANTINDEX(int value)` | build 1207
Simply returns whatever is passed to it (Regardless of whether the handle is valid or not).

## INT_TO_PLAYERINDEX
`0x748B3A65C2604C33` | `Player INT_TO_PLAYERINDEX(int value)` | build 1207
Simply returns whatever is passed to it (Regardless of whether the handle is valid or not).

## IS_PLAYER_BEING_ARRESTED
`0xC8183AE963C58374` | `BOOL IS_PLAYER_BEING_ARRESTED(Player player, BOOL atArresting)` | build 1207
Return true while player is being arrested / busted.

If atArresting is set to 1, this function will return 1 when player is being arrested (while player is putting his hand up, but still have control)

If atArresting is set to 0, this function will return 1 only when the busted screen is shown.

## IS_PLAYER_CLIMBING
`0xB8A70C22FD48197A` | `BOOL IS_PLAYER_CLIMBING(Player player)` | build 1207
Returns TRUE if the player ('s ped) is climbing at the moment.

## IS_PLAYER_CONTROL_ON
`0x7964097FCE4C244B` | `BOOL IS_PLAYER_CONTROL_ON(Player player)` | build 1207
Returns whether the player can control himself.

## IS_PLAYER_DEAD
`0x2E9C3FCB6798F397` | `BOOL IS_PLAYER_DEAD(Player player)` | build 1207

## IS_PLAYER_FREE_AIMING
`0x936F967D4BE1CE9D` | `BOOL IS_PLAYER_FREE_AIMING(Player player)` | build 1207
Gets a value indicating whether the specified player is currently aiming freely.

## IS_PLAYER_FREE_AIMING_AT_ENTITY
`0x8C67C11C68713D25` | `BOOL IS_PLAYER_FREE_AIMING_AT_ENTITY(Player player, Entity entity)` | build 1207
Gets a value indicating whether the specified player is currently aiming freely at the specified entity.

## IS_PLAYER_PLAYING
`0xBFFB35986CAAE58C` | `BOOL IS_PLAYER_PLAYING(Player player)` | build 1207
Checks whether the specified player has a Ped, the Ped is not dead, is not injured and is not arrested.

## IS_PLAYER_READY_FOR_CUTSCENE
`0xAA67BCB0097F2FA3` | `BOOL IS_PLAYER_READY_FOR_CUTSCENE(Player player)` | build 1207

## IS_PLAYER_RIDING_TRAIN
`0x2FB0ACADA6A238DD` | `BOOL IS_PLAYER_RIDING_TRAIN(Player player)` | build 1207
Returns true if the player is riding a train.

## IS_PLAYER_SCRIPT_CONTROL_ON
`0xB78350754157C00F` | `BOOL IS_PLAYER_SCRIPT_CONTROL_ON(Player player)` | build 1207

## IS_PLAYER_TARGETTING_ANYTHING
`0x4605C66E0F935F83` | `BOOL IS_PLAYER_TARGETTING_ANYTHING(Player player)` | build 1207

## IS_PLAYER_TARGETTING_ENTITY
`0x27F89FDC16688A7A` | `BOOL IS_PLAYER_TARGETTING_ENTITY(Player player, Entity entity, BOOL withWeapon)` | build 1207
p2 will return true if player is targetting entity with a weapon if false will return true if player is targetting entity without a weapon

## IS_PLAYER_TELEPORT_ACTIVE
`0x085EEAEB8783FEB5` | `BOOL IS_PLAYER_TELEPORT_ACTIVE()` | build 1207

## IS_PLAYER_WANTED_LEVEL_GREATER
`0xE1C0AD4C24324C36` | `BOOL IS_PLAYER_WANTED_LEVEL_GREATER(Player player, int wantedLevel)` | build 1207

## IS_SYSTEM_UI_BEING_DISPLAYED
`0x908258B6209E71F7` | `BOOL IS_SYSTEM_UI_BEING_DISPLAYED()` | build 1207

## NETWORK_PLAYER_ID_TO_INT
`0x8A9386F0749A17FA` | `int NETWORK_PLAYER_ID_TO_INT()` | build 1207
Does exactly the same thing as PLAYER_ID()

## PLAYER_ID
`0x217E9DC48139933D` | `Player PLAYER_ID()` | build 1207
This returns YOUR 'identity' as a Player type.

Always returns 0 in story mode.

## PLAYER_PED_ID
`0x096275889B8E0EE0` | `Ped PLAYER_PED_ID()` | build 1207
Returns current player ped

## REPORT_POLICE_SPOTTED_PLAYER
`0xCBCCF73FFA69CC6B` | `void REPORT_POLICE_SPOTTED_PLAYER(Player player)` | build 1207

## RESET_LAW_RESPONSE_DELAY_OVERRIDE
`0x5CE5CACC01D0F985` | `void RESET_LAW_RESPONSE_DELAY_OVERRIDE()` | build 1207

## RESET_PLAYER_ARREST_STATE
`0x12917931C31F1750` | `void RESET_PLAYER_ARREST_STATE(Player player)` | build 1207

## RESET_PLAYER_INPUT_GAIT
`0x61A2EECAB274829B` | `void RESET_PLAYER_INPUT_GAIT(Player player)` | build 1207

## RESET_WANTED_LEVEL_DIFFICULTY
`0x062D14F18E8B0CAE` | `void RESET_WANTED_LEVEL_DIFFICULTY(Player player)` | build 1207

## RESTORE_PLAYER_STAMINA
`0xC41F4B6E23FE6A4A` | `void RESTORE_PLAYER_STAMINA(Player player, float p1)` | build 1207

## SET_AIR_DRAG_MULTIPLIER_FOR_PLAYERS_VEHICLE
`0x5DA6500FE849DA16` | `void SET_AIR_DRAG_MULTIPLIER_FOR_PLAYERS_VEHICLE(Player player, float multiplier)` | build 1207
This can be between 1.0f - 50.0f

## SET_ALL_NEUTRAL_RANDOM_PEDS_FLEE_THIS_FRAME
`0x16752DAA7E6D3F72` | `void SET_ALL_NEUTRAL_RANDOM_PEDS_FLEE_THIS_FRAME(Player player)` | build 1207

## SET_ALL_RANDOM_PEDS_FLEE
`0xE705309B8C6445A4` | `void SET_ALL_RANDOM_PEDS_FLEE(Player player, BOOL toggle)` | build 1207
Sets whether all random peds will run away from player if they are agitated (threatened) (bool=true), or some peds can stand up for themselves (bool=false).

## SET_ALL_RANDOM_PEDS_FLEE_THIS_FRAME
`0xD5C198A62F1DEB0A` | `void SET_ALL_RANDOM_PEDS_FLEE_THIS_FRAME(Player player)` | build 1207

## SET_EVERYONE_IGNORE_PLAYER
`0x34630A768925B852` | `void SET_EVERYONE_IGNORE_PLAYER(Player player, BOOL toggle)` | build 1207

## SET_LAW_RESPONSE_DELAY_OVERRIDE
`0xD2DFC9CCA5596A11` | `void SET_LAW_RESPONSE_DELAY_OVERRIDE(float p0)` | build 1207

## SET_LOCKON_TO_FRIENDLY_PLAYERS
`0x4A056257802DD3E5` | `void SET_LOCKON_TO_FRIENDLY_PLAYERS(Player player, BOOL toggle)` | build 1207

## SET_MAX_WANTED_LEVEL
`0x28A4BD2CEE236E19` | `void SET_MAX_WANTED_LEVEL(int maxWantedLevel)` | build 1207

## SET_MIN_TIME_BEFORE_HORSE_BUCKING
`0x506CE71FB6E8CF5E` | `void SET_MIN_TIME_BEFORE_HORSE_BUCKING(Ped mount, int iMinBuckTime)` | build 1207

## SET_PED_AS_TEMP_PLAYER_HORSE
`0x227B06324234FB09` | `BOOL SET_PED_AS_TEMP_PLAYER_HORSE(Player player, Ped horse)` | build 1207

## SET_PLAYER_CAN_BE_HASSLED_BY_GANGS
`0xC7FE774412046825` | `void SET_PLAYER_CAN_BE_HASSLED_BY_GANGS(Player player, BOOL toggle)` | build 1207
Sets whether this player can be hassled by gangs.

## SET_PLAYER_CAN_USE_COVER
`0x5EDA520F7A3BAF4E` | `void SET_PLAYER_CAN_USE_COVER(Player player, BOOL toggle)` | build 1207
Sets whether this player can take cover.

## SET_PLAYER_CLOTH_PIN_FRAMES
`0xD0D9317DFEEF9A66` | `void SET_PLAYER_CLOTH_PIN_FRAMES(Ped ped, int p1)` | build 1207

## SET_PLAYER_CONTROL
`0x4D51E59243281D80` | `void SET_PLAYER_CONTROL(Player player, BOOL toggle, int flags, BOOL bPreventHeadingChange)` | build 1207
flags: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eSetPlayerControlFlags

## SET_PLAYER_FORCED_AIM
`0xD5FCC166AEB2FD0F` | `void SET_PLAYER_FORCED_AIM(Player player, BOOL toggle, Ped ped, int p3, BOOL p4)` | build 1207

## SET_PLAYER_HEALTH_RECHARGE_MULTIPLIER
`0x8899C244EBCF70DE` | `void SET_PLAYER_HEALTH_RECHARGE_MULTIPLIER(Player player, float regenRate)` | build 1207

## SET_PLAYER_INVINCIBLE
`0xFEBEEBC9CBDF4B12` | `void SET_PLAYER_INVINCIBLE(Player player, BOOL toggle)` | build 1207
Simply sets you as invincible (Health will not deplete).

## SET_PLAYER_LOCKON
`0x462AA1973CBBA75E` | `void SET_PLAYER_LOCKON(Player player, BOOL toggle)` | build 1207

## SET_PLAYER_LOCKON_RANGE_OVERRIDE
`0x3A3CD06597388322` | `void SET_PLAYER_LOCKON_RANGE_OVERRIDE(Player player, float range)` | build 1207
Affects the range of auto aim target.

## SET_PLAYER_MAY_NOT_ENTER_ANY_VEHICLE
`0xBEC463B3A11C909E` | `void SET_PLAYER_MAY_NOT_ENTER_ANY_VEHICLE(Player player)` | build 1207

## SET_PLAYER_MAY_ONLY_ENTER_THIS_VEHICLE
`0xDA35A134038557EC` | `void SET_PLAYER_MAY_ONLY_ENTER_THIS_VEHICLE(Player player, Vehicle vehicle)` | build 1207

## SET_PLAYER_MELEE_WEAPON_DAMAGE_MODIFIER
`0xE4CB5A3F18170381` | `void SET_PLAYER_MELEE_WEAPON_DAMAGE_MODIFIER(Player player, float modifier)` | build 1207

## SET_PLAYER_MODEL
`0xED40380076A31506` | `void SET_PLAYER_MODEL(Player player, Hash modelHash, BOOL p2)` | build 1207
Make sure to request the model first and wait until it has loaded.

## SET_PLAYER_NOISE_MULTIPLIER
`0xB5EC6BDAEBCA454C` | `void SET_PLAYER_NOISE_MULTIPLIER(Player player, float multiplier)` | build 1207

## SET_PLAYER_SIMULATE_AIMING
`0xE0447DEF81CCDFD2` | `void SET_PLAYER_SIMULATE_AIMING(Player player, BOOL toggle)` | build 1207

## SET_PLAYER_SNEAKING_NOISE_MULTIPLIER
`0x4DE44FA389DCA565` | `void SET_PLAYER_SNEAKING_NOISE_MULTIPLIER(Player player, float multiplier)` | build 1207

## SET_PLAYER_STAMINA_RECHARGE_MULTIPLIER
`0xFECA17CF3343694B` | `void SET_PLAYER_STAMINA_RECHARGE_MULTIPLIER(Player player, float multiplier)` | build 1207

## SET_PLAYER_TARGETING_MODE
`0xD66A941F401E7302` | `void SET_PLAYER_TARGETING_MODE(int targetMode)` | build 1207
Sets your targeting mode for when you're on foot.
enum eTargetingMode
{
	TARGETING_MODE_INVALID = -1,
	TARGETING_MODE_CAUSAL, (Wide)
	TARGETING_MODE_NORMAL,
	TARGETING_MODE_HARD, (Narrow)
	TARGETING_MODE_EXPERT (Free Aim)
};

## SET_PLAYER_TEAM
`0xE8DD8536F01DE600` | `void SET_PLAYER_TEAM(Player player, int team, BOOL bRestrictToThisScript)` | build 1207
Sets the player's team.

## SET_PLAYER_WANTED_LEVEL
`0x384D4765395E006C` | `void SET_PLAYER_WANTED_LEVEL(Player player, int wantedLevel, BOOL disableNoMission)` | build 1207
nullsub, doesn't do anything

## SET_PLAYER_WEAPON_DAMAGE_MODIFIER
`0x94D529F7B73D7A85` | `void SET_PLAYER_WEAPON_DAMAGE_MODIFIER(Player player, float modifier)` | build 1207
This modifies the damage value of your weapon. Whether it is a multiplier or base damage is unknown.

## SET_PLAYER_WEAPON_DEFENSE_MODIFIER
`0xD15CC2D493160BE3` | `void SET_PLAYER_WEAPON_DEFENSE_MODIFIER(Player player, float modifier)` | build 1207

## SET_PLAYER_WEAPON_TYPE_DAMAGE_MODIFIER
`0xD04AD186CE8BB129` | `void SET_PLAYER_WEAPON_TYPE_DAMAGE_MODIFIER(Player player, Hash weaponHash, float damageModifier)` | build 1207

## SET_POLICE_RADAR_BLIPS
`0x6FD7DD6B63F2820E` | `void SET_POLICE_RADAR_BLIPS(BOOL toggle)` | build 1207
If toggle is set to false:
 The police won't be shown on the (mini)map

If toggle is set to true:
 The police will be shown on the (mini)map

## SET_SWIM_MULTIPLIER_FOR_PLAYER
`0xBFCEABDE34DA5085` | `void SET_SWIM_MULTIPLIER_FOR_PLAYER(Player player, float multiplier)` | build 1207
Swim speed multiplier.
Multiplier goes up to 1.49f

## SET_WANTED_LEVEL_MULTIPLIER
`0xD7FA719CB54866C2` | `void SET_WANTED_LEVEL_MULTIPLIER(float multiplier)` | build 1207

## SIMULATE_PLAYER_INPUT_GAIT
`0xFA0C063C422C4355` | `void SIMULATE_PLAYER_INPUT_GAIT(Player player, float speed, int duration, float heading, BOOL p4, BOOL p5)` | build 1207

## START_PLAYER_TELEPORT
`0xDF8822C55EDDA65B` | `void START_PLAYER_TELEPORT(Player player, float x, float y, float z, float heading, BOOL p5, BOOL p6, BOOL p7, BOOL p8)` | build 1207

## STOP_PLAYER_TELEPORT
`0x0858B86146601BE8` | `void STOP_PLAYER_TELEPORT()` | build 1207
Disables the player's teleportation

## SUPPRESS_WITNESSES_CALLING_POLICE_THIS_FRAME
`0x96722257E5381E00` | `void SUPPRESS_WITNESSES_CALLING_POLICE_THIS_FRAME(Player player)` | build 1207

## UPDATE_PLAYER_TELEPORT
`0xC39DCE4672CBFBC1` | `BOOL UPDATE_PLAYER_TELEPORT(Player player)` | build 1207

## UPDATE_WANTED_POSITION_THIS_FRAME
`0xD0B0B044112BF424` | `void UPDATE_WANTED_POSITION_THIS_FRAME(Player player)` | build 1207

## _0x00B156AFEBCC5AE0
`0x00B156AFEBCC5AE0` | `void _0x00B156AFEBCC5AE0(Any p0)` | build 1207

## _0x03B4B759A8990505
`0x03B4B759A8990505` | `Any _0x03B4B759A8990505(Any p0)` | build 1207

## _0x06E1FB78B1E59CA5
`0x06E1FB78B1E59CA5` | `void _0x06E1FB78B1E59CA5(Ped ped, BOOL p1)` | build 1207

## _0x086549F3B0381CB1
`0x086549F3B0381CB1` | `void _0x086549F3B0381CB1(Any p0, Any p1)` | build 1207

## _0x0869D499A7848309
`0x0869D499A7848309` | `void _0x0869D499A7848309(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## _0x08E22898A6AF4905
`0x08E22898A6AF4905` | `void _0x08E22898A6AF4905(Player player, float p1)` | build 1207
_SET_PLAYER_*? some multiplier or modifier for health or statmina ?

## _0x0B7803F6F7BB43E0
`0x0B7803F6F7BB43E0` | `Any _0x0B7803F6F7BB43E0()` | build 1207
Hardcoded to return zero/false.

## _0x0F4EAF69DA41AF43
`0x0F4EAF69DA41AF43` | `Any _0x0F4EAF69DA41AF43(Any p0)` | build 1207

## _0x0F9CF06986300875
`0x0F9CF06986300875` | `void _0x0F9CF06986300875(Any p0)` | build 1207

## _0x107F2A66E1C4C83A
`0x107F2A66E1C4C83A` | `void _0x107F2A66E1C4C83A(Any p0)` | build 1207

## _0x113EF458AB6CDA67
`0x113EF458AB6CDA67` | `void _0x113EF458AB6CDA67(Any p0, Any p1)` | build 1207

## _0x12E09E278C6C29B7
`0x12E09E278C6C29B7` | `void _0x12E09E278C6C29B7(Any p0)` | build 1207

## _0x14E57F88BA0A07FC
`0x14E57F88BA0A07FC` | `void _0x14E57F88BA0A07FC(Hash location)` | build 1207

## _0x19B2C7A6C34FAD54
`0x19B2C7A6C34FAD54` | `Any _0x19B2C7A6C34FAD54(Any p0, Any p1)` | build 1207

## _0x1AD8AD999C27F44A
`0x1AD8AD999C27F44A` | `void _0x1AD8AD999C27F44A(Any p0)` | build 1311

## _0x1D256EED194F5B58
`0x1D256EED194F5B58` | `void _0x1D256EED194F5B58(Any p0)` | build 1207

## _0x1E8099F449ABB0BA
`0x1E8099F449ABB0BA` | `Any _0x1E8099F449ABB0BA(Any p0)` | build 1207

## _0x1F488807BC8E0630
`0x1F488807BC8E0630` | `void _0x1F488807BC8E0630(Player player)` | build 1207
_RESET_PLAYER_A* - _RESET_PLAYER_I*

## _0x1FDA57E8908F2609
`0x1FDA57E8908F2609` | `void _0x1FDA57E8908F2609(Player player, Ped ped, BOOL useSteerassist)` | build 1207

## _0x21091B4BEB6376EE
`0x21091B4BEB6376EE` | `Any _0x21091B4BEB6376EE(Any p0)` | build 1207

## _0x216BC0D3D2E413D2
`0x216BC0D3D2E413D2` | `void _0x216BC0D3D2E413D2(Player player, Any p1)` | build 1207

## _0x22B3CABEDDB538B2
`0x22B3CABEDDB538B2` | `void _0x22B3CABEDDB538B2(Player player, float p1)` | build 1207

## _0x263D69767F76059C
`0x263D69767F76059C` | `void _0x263D69767F76059C(Player player, int p1)` | build 1207

## _0x2BB8D58E88777499
`0x2BB8D58E88777499` | `void _0x2BB8D58E88777499(Any p0)` | build 1207

## _0x2BEED53B912537D0
`0x2BEED53B912537D0` | `void _0x2BEED53B912537D0(Any p0, Any p1, Any p2)` | build 1207

## _0x2C2D287748E8E9B7
`0x2C2D287748E8E9B7` | `void _0x2C2D287748E8E9B7(BOOL p0)` | build 1207

## _0x2E1ABE627C95ED9B
`0x2E1ABE627C95ED9B` | `Any _0x2E1ABE627C95ED9B()` | build 1207

## _0x2E67707BEC52CA4B
`0x2E67707BEC52CA4B` | `void _0x2E67707BEC52CA4B(Any p0)` | build 1207

## _0x310CE349E0C0EC4B
`0x310CE349E0C0EC4B` | `void _0x310CE349E0C0EC4B(Player player, Ped ped, int p2)` | build 1207

## _0x325434C68358D282
`0x325434C68358D282` | `void _0x325434C68358D282(BOOL toggle)` | build 1207
Only used in script function UPDATE_PLAYER_JUST_DIED_STATE

## _0x35A33783EC3C3448
`0x35A33783EC3C3448` | `void _0x35A33783EC3C3448(Any p0)` | build 1311

## _0x3A8611BD7BDE84F7
`0x3A8611BD7BDE84F7` | `void _0x3A8611BD7BDE84F7(Any p0, Any p1)` | build 1207

## _0x3ACAC8832E77BC93
`0x3ACAC8832E77BC93` | `void _0x3ACAC8832E77BC93(Player player, BOOL p1)` | build 1207
Used in script function INIT_DEADEYE_SLOWDOWN

## _0x3AD212429E095EFB
`0x3AD212429E095EFB` | `void _0x3AD212429E095EFB(Any p0, Any p1)` | build 1207

## _0x3B296934DB026873
`0x3B296934DB026873` | `void _0x3B296934DB026873(Any p0, Any p1)` | build 1207
nullsub, doesn't do anything

## _0x3BB84F812E052C90
`0x3BB84F812E052C90` | `void _0x3BB84F812E052C90(Any p0)` | build 1207

## _0x3C4AE8506638C7E2
`0x3C4AE8506638C7E2` | `void _0x3C4AE8506638C7E2(Any p0, Any p1)` | build 1207

## _0x3D9DA5C9EFD20D88
`0x3D9DA5C9EFD20D88` | `void _0x3D9DA5C9EFD20D88(Any p0, Any p1)` | build 1207

## _0x3DAABE78A23694BC
`0x3DAABE78A23694BC` | `void _0x3DAABE78A23694BC(Any p0, Any p1)` | build 1207

## _0x45EF176B532CA851
`0x45EF176B532CA851` | `void _0x45EF176B532CA851(Any p0, Any p1)` | build 1207

## _0x497A18F8F88AA9D8
`0x497A18F8F88AA9D8` | `void _0x497A18F8F88AA9D8()` | build 1207

## _0x4D1699543B1C023C
`0x4D1699543B1C023C` | `void _0x4D1699543B1C023C(Player player, float p1)` | build 1207
_SET_SPECIAL_ABILITY_*

## _0x4DBC4873707E8FD6
`0x4DBC4873707E8FD6` | `void _0x4DBC4873707E8FD6(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0x4EC8BE63B8A5D4EF
`0x4EC8BE63B8A5D4EF` | `void _0x4EC8BE63B8A5D4EF(Player player, int p1)` | build 1207

## _0x4F0D2256AAE94EDA
`0x4F0D2256AAE94EDA` | `void _0x4F0D2256AAE94EDA(int p0)` | build 1207

## _0x51139D8C17B16FBC
`0x51139D8C17B16FBC` | `Any _0x51139D8C17B16FBC(Any p0)` | build 1207

## _0x57028FD99886F6F9
`0x57028FD99886F6F9` | `BOOL _0x57028FD99886F6F9()` | build 1232
_IS_PLAYER_D* - _IS_PLAYER_F*

## _0x570A13A4CA2799BB
`0x570A13A4CA2799BB` | `void _0x570A13A4CA2799BB(Player player, BOOL p1)` | build 1207
Used in script function INIT_DEADEYE_SLOWDOWN

## _0x57D9991DC1334151
`0x57D9991DC1334151` | `Any _0x57D9991DC1334151(Any p0)` | build 1207

## _0x585CE159DB46FADB
`0x585CE159DB46FADB` | `void _0x585CE159DB46FADB(Any p0, Any p1)` | build 1207

## _0x5B7B97E99F84138B
`0x5B7B97E99F84138B` | `Any _0x5B7B97E99F84138B(Any p0)` | build 1207

## _0x5C2E5E3CAEEB1F58
`0x5C2E5E3CAEEB1F58` | `void _0x5C2E5E3CAEEB1F58(Any p0, Any p1, Any p2)` | build 1207

## _0x621D1B289CAF5978
`0x621D1B289CAF5978` | `BOOL _0x621D1B289CAF5978(Player player)` | build 1207
_IS_PLAYER_S* - _IS_PLAYER_T*

## _0x628E742FE1F79C4A
`0x628E742FE1F79C4A` | `void _0x628E742FE1F79C4A(Any p0, Any p1)` | build 1207

## _0x65887EAC535A0B0C
`0x65887EAC535A0B0C` | `void _0x65887EAC535A0B0C(Any p0)` | build 1207

## _0x67659A8F248E0141
`0x67659A8F248E0141` | `void _0x67659A8F248E0141(Any p0, Any p1)` | build 1207

## _0x6852288340B43239
`0x6852288340B43239` | `Any _0x6852288340B43239(Any p0, Any p1)` | build 1207

## _0x694FFA4308060CD1
`0x694FFA4308060CD1` | `void _0x694FFA4308060CD1(Any p0, Any p1)` | build 1207

## _0x6C54E69516CC56BD
`0x6C54E69516CC56BD` | `Any _0x6C54E69516CC56BD(Any p0)` | build 1207

## _0x6EDB5D08CB03E763
`0x6EDB5D08CB03E763` | `void _0x6EDB5D08CB03E763(Any p0, Any p1)` | build 1207

## _0x73EB2EF2E92D23BF
`0x73EB2EF2E92D23BF` | `BOOL _0x73EB2EF2E92D23BF()` | build 1207

## _0x747257807B8721CE
`0x747257807B8721CE` | `Any _0x747257807B8721CE(Any p0, Any p1)` | build 1207

## _0x76F7E1BCD623A429
`0x76F7E1BCD623A429` | `void _0x76F7E1BCD623A429(Any p0)` | build 1207

## _0x77B0B6D17A3AC9AA
`0x77B0B6D17A3AC9AA` | `void _0x77B0B6D17A3AC9AA(Any p0, Any p1)` | build 1207
nullsub, doesn't do anything

## _0x77E83C315A3B31CA
`0x77E83C315A3B31CA` | `void _0x77E83C315A3B31CA(Any p0)` | build 1207

## _0x7AE93C45EC14A166
`0x7AE93C45EC14A166` | `BOOL _0x7AE93C45EC14A166(Player player, Ped* ped)` | build 1207
Only used in script function PROCESS_PED_INTERRUPT_DIALOGUE
_GET_PLAYER_*

## _0x818241B3EDA84191
`0x818241B3EDA84191` | `void _0x818241B3EDA84191(Player player, BOOL p1)` | build 1207
_SET_PLAYER_DAMAGE_* - _SET_PLAYER_DEFENSE_*

## _0x83C989D5B5B5B466
`0x83C989D5B5B5B466` | `void _0x83C989D5B5B5B466(Any p0, Any p1)` | build 1207

## _0x84481018E668E1B8
`0x84481018E668E1B8` | `void _0x84481018E668E1B8(Player player, Ped ped, Any p2)` | build 1207

## _0x8591EE69CC3ED257
`0x8591EE69CC3ED257` | `void _0x8591EE69CC3ED257(Player player, BOOL toggle)` | build 1207
SET_PLAYER_S/T*

## _0x8702D9150D9FBB3D
`0x8702D9150D9FBB3D` | `Any _0x8702D9150D9FBB3D(Any p0, Any p1)` | build 1207

## _0x8F44EBB3BA8F6D44
`0x8F44EBB3BA8F6D44` | `void _0x8F44EBB3BA8F6D44(Any p0, Any p1)` | build 1207

## _0x9044835BE9D9DBFE
`0x9044835BE9D9DBFE` | `void _0x9044835BE9D9DBFE(Any p0, Any p1)` | build 1207

## _0x9073EC5456651A90
`0x9073EC5456651A90` | `void _0x9073EC5456651A90(Any p0, Any p1)` | build 1207

## _0x908D4B72854C8F62
`0x908D4B72854C8F62` | `void _0x908D4B72854C8F62(Any p0)` | build 1207

## _0x927861B2C08DBEA5
`0x927861B2C08DBEA5` | `BOOL _0x927861B2C08DBEA5(Player player)` | build 1207
_GET_A* - _GET_C*

## _0x929DDD5538F3DF1F
`0x929DDD5538F3DF1F` | `void _0x929DDD5538F3DF1F(Any p0, Any p1)` | build 1232

## _0x93624B36E8851B42
`0x93624B36E8851B42` | `void _0x93624B36E8851B42(Player player)` | build 1207

## _0x9422743A5BA50E10
`0x9422743A5BA50E10` | `Any _0x9422743A5BA50E10(Any p0)` | build 1207

## _0x9461A8FAB0378E5B
`0x9461A8FAB0378E5B` | `void _0x9461A8FAB0378E5B(Any p0, Any p1)` | build 1207

## _0x9AFCF9FE1884BF62
`0x9AFCF9FE1884BF62` | `void _0x9AFCF9FE1884BF62(Any p0, Any p1)` | build 1207

## _0x9FC5A003FB76EDBD
`0x9FC5A003FB76EDBD` | `void _0x9FC5A003FB76EDBD(Any p0, Any p1)` | build 1207

## _0xA28056CD1B04B250
`0xA28056CD1B04B250` | `void _0xA28056CD1B04B250(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10)` | build 1232

## _0xA342495F93B7B838
`0xA342495F93B7B838` | `void _0xA342495F93B7B838(Any p0, Any p1)` | build 1207

## _0xA54000D4BFD90BDE
`0xA54000D4BFD90BDE` | `Any _0xA54000D4BFD90BDE(Any p0)` | build 1207

## _0xAAED694CE814817F
`0xAAED694CE814817F` | `Any _0xAAED694CE814817F(Any p0)` | build 1207

## _0xB15CD2F9932C9AB5
`0xB15CD2F9932C9AB5` | `Any _0xB15CD2F9932C9AB5(Any p0)` | build 1207

## _0xB331D8A73F9D2BDF
`0xB331D8A73F9D2BDF` | `BOOL _0xB331D8A73F9D2BDF(Player player, Any* p1)` | build 1207
_IS_PLAYER_I* - _IS_PLAYER_P*

## _0xBA5CA1FEB5DE0DF6
`0xBA5CA1FEB5DE0DF6` | `void _0xBA5CA1FEB5DE0DF6(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5)` | build 1207

## _0xBB6EA5D59E926095
`0xBB6EA5D59E926095` | `void _0xBB6EA5D59E926095(int category, Hash emote)` | build 1207
NPEW__ENUM__EMOTE_CATEGORY_INVALID = -1
NPEW__ENUM__EMOTE_CATEGORY_ACTIONS
NPEW__ENUM__EMOTE_CATEGORY_ANTAGONIZE
NPEW__ENUM__EMOTE_CATEGORY_REACTIONS
NPEW__ENUM__EMOTE_CATEGORY_GREET
NPEW__ENUM__NUM_EMOTE_CATEGORIES
NPEW__ENUM__NUM_DISPLAY_TEXTURES

## _0xBD96185264DDAAEA
`0xBD96185264DDAAEA` | `void _0xBD96185264DDAAEA(Any p0, Any p1)` | build 1207

## _0xBEA3A6E5F5F79A6F
`0xBEA3A6E5F5F79A6F` | `Any _0xBEA3A6E5F5F79A6F(Any p0, Any p1)` | build 1207
_GET_PLAYER_I*

## _0xBED386157F65942C
`0xBED386157F65942C` | `void _0xBED386157F65942C(Any p0, Any p1)` | build 1207

## _0xBEFED69CE8317F91
`0xBEFED69CE8317F91` | `Any _0xBEFED69CE8317F91(Any p0)` | build 1207

## _0xC177C827CEFC0AA4
`0xC177C827CEFC0AA4` | `void _0xC177C827CEFC0AA4(Any p0, Any p1)` | build 1207

## _0xC4873B053054C04B
`0xC4873B053054C04B` | `void _0xC4873B053054C04B(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## _0xC58CE6824E604DEC
`0xC58CE6824E604DEC` | `void _0xC58CE6824E604DEC(Any p0)` | build 1207

## _0xC71D07C96946E263
`0xC71D07C96946E263` | `void _0xC71D07C96946E263(Any p0, Any p1)` | build 1207

## _0xC74EB3F2EC169F6B
`0xC74EB3F2EC169F6B` | `Any _0xC74EB3F2EC169F6B(Any p0)` | build 1232
Hardcoded to return zero/false.

## _0xC900A465364A85D6
`0xC900A465364A85D6` | `void _0xC900A465364A85D6(Player player)` | build 1207

## _0xC93A9A45430D484E
`0xC93A9A45430D484E` | `Any _0xC93A9A45430D484E(Any p0)` | build 1207

## _0xCA59808E51FD67C4
`0xCA59808E51FD67C4` | `void _0xCA59808E51FD67C4(Any p0, Any p1)` | build 1207

## _0xCB0B9506BC91E441
`0xCB0B9506BC91E441` | `void _0xCB0B9506BC91E441(Any p0, Any p1)` | build 1207

## _0xCB61A63AA53D7D22
`0xCB61A63AA53D7D22` | `void _0xCB61A63AA53D7D22(Any p0, Any p1)` | build 1207

## _0xCD7CA3013FD12749
`0xCD7CA3013FD12749` | `void _0xCD7CA3013FD12749(Any p0, Any p1)` | build 1232

## _0xCDDD4B74660E2335
`0xCDDD4B74660E2335` | `void _0xCDDD4B74660E2335(Any p0, Any p1, Any p2)` | build 1207

## _0xCEDC16930526F728
`0xCEDC16930526F728` | `void _0xCEDC16930526F728(Any p0)` | build 1207

## _0xCFB2EED4FCB7BD77
`0xCFB2EED4FCB7BD77` | `void _0xCFB2EED4FCB7BD77(Any p0, Any p1, Any p2)` | build 1207

## _0xD1F6B912785BFD35
`0xD1F6B912785BFD35` | `Any _0xD1F6B912785BFD35(Any p0)` | build 1207

## _0xD288E02E364972D2
`0xD288E02E364972D2` | `void _0xD288E02E364972D2(Any p0, Any p1, Any p2)` | build 1311

## _0xDA9D7BE231FE865F
`0xDA9D7BE231FE865F` | `Any _0xDA9D7BE231FE865F(Any p0, Any p1, Any p2)` | build 1207

## _0xDAB6A2FC56B7DE65
`0xDAB6A2FC56B7DE65` | `Any _0xDAB6A2FC56B7DE65(Any p0)` | build 1207

## _0xDD33A82352C4652F
`0xDD33A82352C4652F` | `void _0xDD33A82352C4652F(Player player, Ped ped, int p2)` | build 1207

## _0xE1D356F5A66D0FFA
`0xE1D356F5A66D0FFA` | `BOOL _0xE1D356F5A66D0FFA(Hash emote)` | build 1232

## _0xE50A67C33514A390
`0xE50A67C33514A390` | `Any _0xE50A67C33514A390(Any p0, Any p1)` | build 1207

## _0xE7F8707269544B29
`0xE7F8707269544B29` | `BOOL _0xE7F8707269544B29(Player player, Ped ped)` | build 1207
_IS_PLAYER_A* - _IS_PLAYER_BE*

## _0xE956C2340A76272E
`0xE956C2340A76272E` | `Any _0xE956C2340A76272E(Any p0)` | build 1207

## _0xEACEBAAE0A33FB3F
`0xEACEBAAE0A33FB3F` | `void _0xEACEBAAE0A33FB3F(Any p0)` | build 1207

## _0xEBB6E27AC2FF32DA
`0xEBB6E27AC2FF32DA` | `void _0xEBB6E27AC2FF32DA(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xEBFF94328FF7A18A
`0xEBFF94328FF7A18A` | `void _0xEBFF94328FF7A18A(Any p0, Any p1)` | build 1207

## _0xF21C7A3F3FFBA629
`0xF21C7A3F3FFBA629` | `void _0xF21C7A3F3FFBA629(Player player)` | build 1207
_CLEAR_FACIAL_* - _CLEAR_PED_BLOOD*

## _0xF4CB347D7B5EB0FD
`0xF4CB347D7B5EB0FD` | `Any _0xF4CB347D7B5EB0FD()` | build 1207

## _0xF993373285053D77
`0xF993373285053D77` | `void _0xF993373285053D77(Any p0, Any p1, Any p2)` | build 1207

## _0xFA437FA0738C370C
`0xFA437FA0738C370C` | `void _0xFA437FA0738C370C(Player player, float p1, int p2, int p3, int p4)` | build 1207
Params: p1, p2, p3, p4 = 1.f, 0, 0, 0 in R* Scripts
_SPECIAL_ABILITY*

## _0xFA7DAAE3959E6C7B
`0xFA7DAAE3959E6C7B` | `void _0xFA7DAAE3959E6C7B(Any p0, Any p1)` | build 1207

## _ADD_AMBIENT_PLAYER_INTERACTIVE_FOCUS_PRESET
`0x3946FC742AC305CD` | `void _ADD_AMBIENT_PLAYER_INTERACTIVE_FOCUS_PRESET(Player player, Ped ped, char* preset, float x, float y, float z, Entity targetEntity, char* name)` | build 1207
Associates a specific interactive focus mode preset between a player and a ped, with a specified location and target entity.
To access all available presets, refer to the file located at: `/update_1.rpf/common/data/interactive_focus_mode_presets.meta`

## _ADD_AMBIENT_PLAYER_INTERACTIVE_FOCUS_PRESET_AT_COORDS
`0xD48227263E3D06AE` | `void _ADD_AMBIENT_PLAYER_INTERACTIVE_FOCUS_PRESET_AT_COORDS(Player player, Vector3* p1, char* preset, float x, float y, float z, Entity targetEntity, char* name)` | build 1232
Adds an interactive focus mode preset between a player and a specific set of coordinates with a target entity.
To access all available presets, refer to the file located at:update_1.rpf.common.data.interactive_focus_mode_presets.meta
```lua
AddPlayerInteractiveFocusPresetAtCoords(PlayerId(),GetEntityCoords(PlayerPedId()),'ForcedILONoIcon',0.0,0.0,0.0,PlayerPedId(),'text')
```

## _ADD_PLAYER_AS_FOLLOW_TARGET
`0xAC22AA6DF4D1C1DE` | `void _ADD_PLAYER_AS_FOLLOW_TARGET(Player player, Ped ped, float p2, float p3, int followMode, int followPriority, BOOL p6)` | build 1207
Used in script function: NET_AUTO_FOLLOW_UPDATE_LEADER_VALUES
followMode:
HORSEFOLLOWMODE_AUTO = 0,
HORSEFOLLOWMODE_SIDE_ONLY,
HORSEFOLLOWMODE_BEHIND_ONLY,
HORSEFOLLOWMODE_BEHIND_AND_SIDE,
HORSEFOLLOWMODE_BEHIND_CLOSE
followPriority:
HORSEFOLLOWPRIORITY_STEER_ASSIST = 0,
HORSEFOLLOWPRIORITY_AMBIENT,
HORSEFOLLOWPRIORITY_NORMAL,
HORSEFOLLOWPRIORITY_HIGH

## _CLEAR_BOUNTY_TARGET
`0x8F2A81C09DA9124A` | `void _CLEAR_BOUNTY_TARGET(Player player)` | build 1207

## _CLEAR_DEADEYE_AURA_INTENSITY
`0x0E9057A9DA78D0F8` | `void _CLEAR_DEADEYE_AURA_INTENSITY(Player player, int bitflag)` | build 1207
Clears the intensity of aura effects applied to entities for a specific player in Deadeye mode based on a flag parameter. This function is used to reset any intensity modifications set by `_SET_DEADEYE_ENTITY_AURA_INTENSITY_WITH_FLAG - 0x131E294EF60160DF`, restoring affected entities' aura intensity to their default state.

## _DISABLE_PLAYER_INTERACTIVE_FOCUS_PRESET
`0xC67A4910425F11F1` | `void _DISABLE_PLAYER_INTERACTIVE_FOCUS_PRESET(Player player, char* name)` | build 1207
Disables the previously set interactive focus mode preset for a given player. see `_SET_PLAYER_INTERACTIVE_FOCUS_PRESET - 0x3C1B1807C7A415D6`

## _EAGLEEYE_SET_SPRINT_BEHAVIOR
`0xCE285A4413B00B7F` | `void _EAGLEEYE_SET_SPRINT_BEHAVIOR(Player player, BOOL disabled)` | build 1207
Sets the behavior of sprinting while the Eagleeye feature is active, determining whether sprinting cancels the effect based on the specified parameter.
 old name was _EAGLE_EYE_SET_PLUS_FLAG_DISABLED this native can still be used as its declared.

## _EAGLE_EYE_ADD_PARTICLE_EFFECT_TO_ENTITY
`0x6ECFC621A168424C` | `void _EAGLE_EYE_ADD_PARTICLE_EFFECT_TO_ENTITY(Entity entity1, Entity entity2, int p2, int heading)` | build 1207
Add a yellow particle to the entity.
entity: entity to apply yellow particle
entity2: same entity as entit
p2: always 
p3: always 0

## _EAGLE_EYE_ARE_ALL_TRAILS_HIDDEN
`0xA62BBAAE67A05BB0` | `BOOL _EAGLE_EYE_ARE_ALL_TRAILS_HIDDEN(Player player)` | build 1207
Retrieves whether all trails are currently hidden during Eagle Eye mode for the specified player.

## _EAGLE_EYE_CAN_PLAYER_FOCUS_ON_TRACK
`0x1DA5C5B0923E1B85` | `BOOL _EAGLE_EYE_CAN_PLAYER_FOCUS_ON_TRACK(Player player)` | build 1207
Checks if the player can focus on tracks while in Eagle Eye mode. Returns true if the player is able to focus on a track, otherwise false.

## _EAGLE_EYE_CLEAR_REGISTERED_TRAILS
`0xE5D3EB37ABC1EB03` | `void _EAGLE_EYE_CLEAR_REGISTERED_TRAILS(Player player)` | build 1207
Clears all Eagle Eye trails that were registered for entities associated with the specified player.

## _EAGLE_EYE_DISABLE_TRACKING_TRAIL
`0x40AB73092C95B5F5` | `void _EAGLE_EYE_DISABLE_TRACKING_TRAIL(Entity entity, char* trail, Any p2, Any p3)` | build 1207

## _EAGLE_EYE_GET_TRACKED_PED_ID
`0x3813E11A378958A5` | `int _EAGLE_EYE_GET_TRACKED_PED_ID(Player player)` | build 1207
Retrieves the ID of the ped that the specified player is currently tracking while in Eagle Eye mode.

## _EAGLE_EYE_REMOVE_PARTICLE_EFFECT_FROM_ENTITY
`0xDC5E09D012D759C4` | `void _EAGLE_EYE_REMOVE_PARTICLE_EFFECT_FROM_ENTITY(Entity entity1, Entity entity2, int p2)` | build 1207
Remove yellow particle from the entity when it was set using `0x6ECFC621A168424C` 
entity: entity to remove yellow particles
entity2: same entity as entity
p2: always 0

## _EAGLE_EYE_SET_COLOR
`0x2C41D93F550D5E37` | `void _EAGLE_EYE_SET_COLOR(Player player, BOOL p1, Any* p2)` | build 1207
false: default eagleeye color
true: green eagleeye color

## _EAGLE_EYE_SET_CUSTOM_DISTANCE
`0x907B16B3834C69E2` | `void _EAGLE_EYE_SET_CUSTOM_DISTANCE(Entity entity, float distance)` | build 1207

## _EAGLE_EYE_SET_DRAIN_RATE_MODIFIER
`0xE0D6C2A146A5C993` | `void _EAGLE_EYE_SET_DRAIN_RATE_MODIFIER(Player player, float modifier)` | build 1207

## _EAGLE_EYE_SET_FOCUS_ON_ASSOCIATED_CLUE_TRAIL
`0x2AF423D6ECB2C485` | `void _EAGLE_EYE_SET_FOCUS_ON_ASSOCIATED_CLUE_TRAIL(Player player, Entity linkedWaypointPed)` | build 1207

## _EAGLE_EYE_SET_HIDE_ALL_TRAILS
`0x330CA55A3647FA1C` | `void _EAGLE_EYE_SET_HIDE_ALL_TRAILS(Player player, BOOL hide)` | build 1207
Sets whether all trails are hidden during Eagle Eye mode.

## _EAGLE_EYE_SET_RANGE
`0x22C8B10802301381` | `void _EAGLE_EYE_SET_RANGE(Player player, float range)` | build 1207

## _EAGLE_EYE_SET_REGISTERED_ENTITY_GLOW
`0xBC02B3D151D3859F` | `void _EAGLE_EYE_SET_REGISTERED_ENTITY_GLOW(Entity entity, BOOL enable)` | build 1207
Enable/disable a color on the entity in eagle eye mode.

## _EAGLE_EYE_SET_TRACKING_UPGRADE
`0xDFC85C5199045026` | `void _EAGLE_EYE_SET_TRACKING_UPGRADE(Player player, float p1)` | build 1207

## _EAGLE_EYE_SET_TRACKING_UPGRADE_2
`0x6FA957D1B55941C1` | `void _EAGLE_EYE_SET_TRACKING_UPGRADE_2(Player player, float p1)` | build 1311

## _ENABLE_CUSTOM_DEADEYE_ABILITY
`0x95EE1DEE1DCD9070` | `void _ENABLE_CUSTOM_DEADEYE_ABILITY(Player player, BOOL enable)` | build 1207

## _ENABLE_EAGLEEYE
`0xA63FCAD3A6FEC6D2` | `void _ENABLE_EAGLEEYE(Player player, BOOL enable)` | build 1207
(Un)lock Eagle Eye functionality

## _FORCE_REST_SCENARIO
`0xE5A3DD2FF84E1A4B` | `void _FORCE_REST_SCENARIO(BOOL toggle)` | build 1232

## _FORMAT_PLAYER_NAME_STRING
`0x5B6193813E03E4E9` | `const char* _FORMAT_PLAYER_NAME_STRING(char* string)` | build 1207

## _GET_ACTIVE_HORSE_FOR_PLAYER
`0x46FA0AE18F4C7FA9` | `Ped _GET_ACTIVE_HORSE_FOR_PLAYER(Player player)` | build 1207

## _GET_AI_PLAYER_DEFENSE_MODIFIER_AGAINST_AI
`0x2E78D822208E740A` | `float _GET_AI_PLAYER_DEFENSE_MODIFIER_AGAINST_AI(Player player)` | build 1207

## _GET_CONSTRUCTED_DISCOVERED_CHARACTER_NAME
`0x8E84119A23C16623` | `Hash _GET_CONSTRUCTED_DISCOVERED_CHARACTER_NAME(Hash p0, BOOL model, BOOL outfit)` | build 1207
p0: mostly Ped Hashes

## _GET_DEADEYE_ABILITY_DEPLETION_DELAY
`0xE92261BD28C0878F` | `float _GET_DEADEYE_ABILITY_DEPLETION_DELAY(Player player)` | build 1207
Returns the depletion delay value for the Deadeye ability that was previously set using `SetDeadeyeAbilityDepletionDelay - 0x870634493CB4372C`

## _GET_DEADEYE_ABILITY_LEVEL
`0xCCE7C695C164C35F` | `int _GET_DEADEYE_ABILITY_LEVEL(Player player)` | build 1207

## _GET_HAS_PLAYER_DISCOVERED_CHARACTER_NAME_SP
`0x0772F87D7B07719A` | `BOOL _GET_HAS_PLAYER_DISCOVERED_CHARACTER_NAME_SP(Player player, int p1, Hash discoveryHash)` | build 1207

## _GET_IS_DEADEYE_TAGGING_ENABLED
`0x32348719DCED2969` | `BOOL _GET_IS_DEADEYE_TAGGING_ENABLED(Player player)` | build 1207

## _GET_NUM_DEADEYE_MARKS_ON_PED
`0x27AD7162D3FED01E` | `int _GET_NUM_DEADEYE_MARKS_ON_PED(Player player, Ped ped)` | build 1207
Retrieves the number of marks placed on a PED when Deadeye mode is active for the specified player.

## _GET_NUM_MARKED_DEADEYE_TARGETS
`0xCCD9B77F70D31C9D` | `int _GET_NUM_MARKED_DEADEYE_TARGETS(Player player)` | build 1207

## _GET_PEDS_DAMAGED_BY_PLAYER_RECENTLY
`0x1A6E84F13C952094` | `BOOL _GET_PEDS_DAMAGED_BY_PLAYER_RECENTLY(Player player, int duration, Any* struct)` | build 1207
it is used to check for that period of time if player damaged any peds only returns the last 3 hits with the entity ids so if you hit the same entity 3 times it will return the same entity id 3 times, if you hit 4 different entities within that time it will return the last 3 entity ids
 only stores the last 3 hits in the data view buffer
duration is in miliseconds
you need dataview
```lua
Citizen.InvokeNative(0x1A6E84F13C952094, PlayerId(), 10000, dataView:Buffer())
local entity = dataView:GetInt32(8 * 1)
local entity2 = dataView:GetInt32(8 * 2)
local entity3 = dataView:GetInt32(8 * 3)
print(entity, entity2, entity3)
```

## _GET_PLAYER_CACHED_DEAD_EYE_AMOUNT
`0xDF66A37936D5F3D9` | `float _GET_PLAYER_CACHED_DEAD_EYE_AMOUNT(Player player)` | build 1207

## _GET_PLAYER_DEAD_EYE
`0xA81D24AE0AF99A5E` | `float _GET_PLAYER_DEAD_EYE(Player player)` | build 1207

## _GET_PLAYER_DEAD_EYE_METER_LEVEL
`0x3A6AE4EEE30370FE` | `float _GET_PLAYER_DEAD_EYE_METER_LEVEL(Player player, BOOL p1)` | build 1207

## _GET_PLAYER_HEALTH
`0x0317C947D062854E` | `float _GET_PLAYER_HEALTH(Player player)` | build 1207

## _GET_PLAYER_HEALTH_RECHARGE_MULTIPLIER
`0x22CD23BB0C45E0CD` | `float _GET_PLAYER_HEALTH_RECHARGE_MULTIPLIER(Player player)` | build 1207

## _GET_PLAYER_HUNTING_WAGON
`0x5CA6BBD4A7D8145E` | `Vehicle _GET_PLAYER_HUNTING_WAGON(Player player)` | build 1207

## _GET_PLAYER_MAX_DEAD_EYE
`0x592F58BC4D2A2CF3` | `float _GET_PLAYER_MAX_DEAD_EYE(Player player, Any p1)` | build 1207

## _GET_PLAYER_MOOD
`0x054473164C012699` | `int _GET_PLAYER_MOOD(Player player)` | build 1207
See _SET_PLAYER_MOOD

## _GET_PLAYER_OWNER_OF_MOUNT
`0xAD03B03737CE6810` | `Player _GET_PLAYER_OWNER_OF_MOUNT(Ped mount)` | build 1207

## _GET_PLAYER_OWNER_OF_VEHICLE
`0x7C803BDC8343228D` | `Player _GET_PLAYER_OWNER_OF_VEHICLE(Vehicle vehicle)` | build 1207

## _GET_PLAYER_PED_2
`0x5EBE38A20BC51C27` | `Ped _GET_PLAYER_PED_2(Player player)` | build 1207

## _GET_PLAYER_REQUIRED_DEAD_EYE_AMOUNT
`0x811A748B1BE231BA` | `float _GET_PLAYER_REQUIRED_DEAD_EYE_AMOUNT(Player player)` | build 1207
If player has less Dead Eye than required, Dead Eye cant be triggered.

## _GET_PLAYER_RESET_FLAG
`0xFE691E89C08937B6` | `BOOL _GET_PLAYER_RESET_FLAG(Player player, int playerResetFlag)` | build 1207
playerResetFlag: See 0x9F9A829C6751F3C7

## _GET_PLAYER_SPECIAL_ABILITY_MULTIPLIER
`0xAB3773E7AA1E9DCC` | `float _GET_PLAYER_SPECIAL_ABILITY_MULTIPLIER(Player player)` | build 1207

## _GET_PLAYER_STAMINA
`0x0FF421E467373FCF` | `float _GET_PLAYER_STAMINA(Player player)` | build 1207

## _GET_PLAYER_STAMINA_DEPLETION_MULTIPLIER
`0x68A0389E0718AC8F` | `float _GET_PLAYER_STAMINA_DEPLETION_MULTIPLIER(Player player)` | build 1207

## _GET_PLAYER_STAMINA_RECHARGE_MULTIPLIER
`0x617D3494AD58200F` | `float _GET_PLAYER_STAMINA_RECHARGE_MULTIPLIER(Player player)` | build 1207

## _GET_PLAYER_UI_PROMPT_FOR_PED_IS_ENABLED
`0xEA8F168A76A0B9BC` | `BOOL _GET_PLAYER_UI_PROMPT_FOR_PED_IS_ENABLED(Player player, Ped ped, int promptType, int promptMode)` | build 1207
Returns true if PromptType is enabled for ped (mount)
Params: See 0x0751D461F06E41CE

## _GET_PLAYER_UI_PROMPT_IS_DISABLED
`0x6614F9039BD31931` | `BOOL _GET_PLAYER_UI_PROMPT_IS_DISABLED(Player player, int promptType, int promptMode)` | build 1207
Returns false if PromptType is enabled
Params: See 0x0751D461F06E41CE

## _GET_PLAYER_WEAPON_DAMAGE
`0xFE0304050261442C` | `float _GET_PLAYER_WEAPON_DAMAGE(Player player, Hash weaponHash)` | build 1207

## _GET_SADDLE_HORSE_FOR_PLAYER
`0xB48050D326E9A2F3` | `Ped _GET_SADDLE_HORSE_FOR_PLAYER(Player player)` | build 1207

## _GET_TEMP_PLAYER_HORSE
`0xD3F7445CEA2E5035` | `Ped _GET_TEMP_PLAYER_HORSE(Player player)` | build 1207

## _GET_VEHICLE_OWNED_BY_PLAYER
`0xB9050A97594C8832` | `Vehicle _GET_VEHICLE_OWNED_BY_PLAYER(Player player)` | build 1207

## _GET_WANTED_LEVEL_MULTIPLIER
`0xA82964B9D8D6A983` | `float _GET_WANTED_LEVEL_MULTIPLIER()` | build 1207
Returns -1.0f if no multiplier has been set

## _HAS_PLAYER_DAMAGED_ANY_PED_RECENTLY
`0x72AD59F7B7FB6E24` | `BOOL _HAS_PLAYER_DAMAGED_ANY_PED_RECENTLY(Player player, int duration)` | build 1207
this native checks if the player has damaged or killed any ped human/animal recently within the duration passed, either by shooting or even using melee
duration is in miliseconds

## _IS_DEADEYE_ABILITY_LOCKED
`0x8A0643B0B4CA276B` | `BOOL _IS_DEADEYE_ABILITY_LOCKED(Player player, int abilityType)` | build 1207

## _IS_EAGLE_EYE_REGISTERED_FOR_ENTITY
`0x0E6846476906C9DD` | `BOOL _IS_EAGLE_EYE_REGISTERED_FOR_ENTITY(Player player, Entity entity)` | build 1207

## _IS_PLAYER_FOLLOWING_TARGET
`0xE24C64D9ADED2EF5` | `BOOL _IS_PLAYER_FOLLOWING_TARGET(Player player, Ped ped)` | build 1207

## _IS_PLAYER_FREE_FOCUSING
`0x1A51BFE60708E482` | `BOOL _IS_PLAYER_FREE_FOCUSING(Player player)` | build 1207
Checks if player is focused on any entity

## _IS_PLAYER_IN_SCOPE
`0x04D7F33640662FA2` | `BOOL _IS_PLAYER_IN_SCOPE(Player player)` | build 1207

## _IS_PLAYER_MOUNT_ON_ROAD
`0xE631EAF35828FA67` | `BOOL _IS_PLAYER_MOUNT_ON_ROAD(Player player)` | build 1207
returns true if the player is on a road while riding a horse but at a certain speed, if you go off road then it returns false or if you go too slow like walking state it also returns false

## _IS_PLAYER_ON_MOUNT_LOCKON_ENTITY
`0x2009F8AB7A5E9D6D` | `BOOL _IS_PLAYER_ON_MOUNT_LOCKON_ENTITY(Player player)` | build 1207
This native is used to determine if the player has an active lockon an entity while riding a horse.

## _IS_SECONDARY_SPECIAL_ABILITY_ACTIVE
`0x45AB66D02B601FA7` | `BOOL _IS_SECONDARY_SPECIAL_ABILITY_ACTIVE(Player player)` | build 1207

## _IS_SECONDARY_SPECIAL_ABILITY_ENABLED
`0xE022CC1B545F1D9F` | `BOOL _IS_SECONDARY_SPECIAL_ABILITY_ENABLED(Player player)` | build 1207
Returns true if eagle eye is enabled for the player

## _IS_SPECIAL_ABILITY_ACTIVE
`0xB16223CB7DA965F0` | `BOOL _IS_SPECIAL_ABILITY_ACTIVE(Player player)` | build 1207

## _IS_SPECIAL_ABILITY_ENABLED
`0xDE6C85975F9D4894` | `BOOL _IS_SPECIAL_ABILITY_ENABLED(Player player)` | build 1207
Checks if the player's Deadeye ability is enabled.

## _MODIFY_INFINITE_TRAIL_VISION
`0x28A13BF6B05C3D83` | `void _MODIFY_INFINITE_TRAIL_VISION(Player player, BOOL toggle)` | build 1207
Toggle handles wether Deadeye and Eagleeye are infinite or not.

## _MODIFY_PLAYER_DISCOVERED_CHARACTER_NAME_MP_SET_UNDISCOVERED
`0xFB0E622B401884D3` | `void _MODIFY_PLAYER_DISCOVERED_CHARACTER_NAME_MP_SET_UNDISCOVERED(Hash discoveryHash)` | build 1207

## _MODIFY_PLAYER_UI_PROMPT
`0x0751D461F06E41CE` | `void _MODIFY_PLAYER_UI_PROMPT(Player player, int promptType, int promptMode, BOOL disabled)` | build 1207
Params: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ePromptType
promptType is mostly 34 (PP_TRACK_ANIMAL), promptMode = 0 (PP_MODE_BLOCK) in R* Scripts

## _MODIFY_PLAYER_UI_PROMPT_FOR_PED
`0xA3DB37EDF9A74635` | `void _MODIFY_PLAYER_UI_PROMPT_FOR_PED(Player player, Ped ped, int promptType, int promptMode, BOOL enabled)` | build 1207
Params: See 0x0751D461F06E41CE

## _NETWORK_HAS_PLAYER_VALID_PED
`0x0760D6F70EBCC05C` | `BOOL _NETWORK_HAS_PLAYER_VALID_PED(Player player)` | build 1207
Returns true if the given player has a valid ped.

## _REGISTER_EAGLE_EYE_FOR_ENTITY
`0x543DFE14BE720027` | `void _REGISTER_EAGLE_EYE_FOR_ENTITY(Player player, Entity entity, BOOL p2)` | build 1207
Used for setting up eagle eye for entity
Params: p2 = re-register or not?

## _REGISTER_EAGLE_EYE_TRAILS_FOR_ENTITY
`0xAC67098A1E54ABB0` | `void _REGISTER_EAGLE_EYE_TRAILS_FOR_ENTITY(Player player, Entity entity, Any p2)` | build 1207

## _REMOVE_PLAYER_AS_FOLLOW_TARGET
`0x0C6B89876262A99D` | `void _REMOVE_PLAYER_AS_FOLLOW_TARGET(Player player, Ped ped)` | build 1207

## _RESET_DEADEYE_AURA_EFFECT
`0xE910932F4B30BE23` | `void _RESET_DEADEYE_AURA_EFFECT(Player player)` | build 1207
Resets any aura effects applied to entities for a specific player in Deadeye mode, returning all aura-related visuals to their default state. This function is primarily used to remove any highlighting or aura effects set by `_SET_DEADEYE_ENTITY_AURA - 0x2B12B6FC8B8772AB` and `_SET_DEADEYE_ENTITY_AURA_INTENSITY - 0x131E294EF60160DF`

## _SECONDARY_SPECIAL_ABILITY_SET_ACTIVE
`0x1710BC33CFB83634` | `void _SECONDARY_SPECIAL_ABILITY_SET_ACTIVE(Player player)` | build 1207
Activates EagleEye, called together with 0x28A13BF6B05C3D83

## _SECONDARY_SPECIAL_ABILITY_SET_DISABLED
`0x64FF4BF9AF59E139` | `void _SECONDARY_SPECIAL_ABILITY_SET_DISABLED(Player player, BOOL disabled)` | build 1207
Deactivates EagleEye, called together with 0xC0B21F235C02139C

## _SET_AI_PLAYER_DEFENSE_MODIFIER_AGAINST_AI
`0x914071FF93AF2692` | `void _SET_AI_PLAYER_DEFENSE_MODIFIER_AGAINST_AI(Player player, float modifier)` | build 1207
Sets Player's Defense against AI modifier

## _SET_BOUNTY_TARGET
`0x6ADF821FBF21920E` | `void _SET_BOUNTY_TARGET(Player player, Player target)` | build 1207

## _SET_BOW_DRAW_REDUCTION_TIME_IN_DEADEYE
`0xBE0C524970892D41` | `void _SET_BOW_DRAW_REDUCTION_TIME_IN_DEADEYE(Player player, float drawReductionTime)` | build 1207

## _SET_BOW_STAMINA_DRAIN_SPEED
`0xFE7C9CF376D23342` | `void _SET_BOW_STAMINA_DRAIN_SPEED(Player player, float staminaDrain)` | build 1207
Decreases Stamina bar drain speed by % when drawing a bow.

## _SET_DAMAGE_CLOSE_DISTANCE_BONUS
`0x7761A30432C91297` | `void _SET_DAMAGE_CLOSE_DISTANCE_BONUS(Player player, float closeRangeLowerBound, float closeRangeUpperBound)` | build 1207

## _SET_DAMAGE_CLOSE_DISTANCE_BONUS_TOTAL
`0x5006C36652D6EC56` | `void _SET_DAMAGE_CLOSE_DISTANCE_BONUS_TOTAL(Player player, float closeDamageBonus)` | build 1207

## _SET_DAMAGE_FAR_DISTANCE_BONUS
`0xED591CB17C8BA216` | `void _SET_DAMAGE_FAR_DISTANCE_BONUS(Player player, float farRangeLowerBound, float farRangeUpperBound)` | build 1207

## _SET_DAMAGE_FAR_DISTANCE_BONUS_TOTAL
`0x1F0E3A4434565F8F` | `void _SET_DAMAGE_FAR_DISTANCE_BONUS_TOTAL(Player player, float farDamageBonus)` | build 1207

## _SET_DEADEYE_ABILITY_DEPLETION_DELAY
`0x870634493CB4372C` | `void _SET_DEADEYE_ABILITY_DEPLETION_DELAY(Player player, float delay)` | build 1207
Only used in R* SP Script short_update

## _SET_DEADEYE_ABILITY_LEVEL
`0xF0FE8E790BFEB5BB` | `void _SET_DEADEYE_ABILITY_LEVEL(Player player, int level)` | build 1207
Max level is 5.

## _SET_DEADEYE_ABILITY_LOCKED
`0x2797B8D66DD0EBB8` | `void _SET_DEADEYE_ABILITY_LOCKED(Player player, int abilityType, BOOL toggle)` | build 1207

## _SET_DEADEYE_ENTITY_AURA
`0x2B12B6FC8B8772AB` | `void _SET_DEADEYE_ENTITY_AURA(Player player, int flag)` | build 1207
Applies a aura effect to nearby entities when Deadeye is active, based on a flag parameter. This includes humans, animals, vehicles, and horses pulling those vehicles. Additionally, depending on the flag value, the player's appearance may change (e.g., turning gray).
- flag (int): A flag that determines the behavior of the aura effect. 2 means people 4 means animal etc.

## _SET_DEADEYE_ENTITY_AURA_INTENSITY_WITH_FLAG
`0x131E294EF60160DF` | `void _SET_DEADEYE_ENTITY_AURA_INTENSITY_WITH_FLAG(Player player, float p1, float p2, float p3, float intensity, int flag)` | build 1207
Applies a customizable aura effect to nearby entities when Deadeye is active, with control over aura intensity and additional behavior based on a flag parameter.
- flag (int): A flag that determines the behavior of the aura effect and which entities are affected. 2: Applies aura to humans. 4: Applies aura to animals.

## _SET_DEADEYE_TAGGING_ENABLED
`0x6B5DDFB967E5073D` | `void _SET_DEADEYE_TAGGING_ENABLED(Player player, BOOL toggle)` | build 1207

## _SET_DISABLE_PLAYER_WANTED_LEVEL
`0x8674D138391FFB1B` | `void _SET_DISABLE_PLAYER_WANTED_LEVEL(Player player, BOOL disable)` | build 1207
Disables the players ability to be wanted by lawmen

## _SET_LOCAL_PLAYER_PERSONA_ABILITY_FLAG
`0x7146CF430965927C` | `void _SET_LOCAL_PLAYER_PERSONA_ABILITY_FLAG(int flagId, BOOL toggle)` | build 1207
see personaabilities.meta
enum ePersonaAbilityFlag
{
	PERSONA_CAN_AUTOESCAPE_FROM_LASSO,
	PERSONA_HAT_BLOCKS_FIRST_HEADSHOT,
	PERSONA_FULL_AUTO_FOR_ALL_WEAPONS,
	PERSONA_MIGHT_LIVE_AFTER_DEADLY_DAMAGE,
	PERSONA_IGNORE_AIM_BEFORE_FIRING_RESTRICTIONS,
	PERSONA_DEADEYE_INSTANT_RELOAD,
	PERSONA_USE_PHOSPHOROUS_ROUNDS,
	PERSONA_CONT_DEADEYE_ON_TAKING_COVER,
	PERSONA_CONT_DEADEYE_ON_RELOAD,
	PERSONA_CONT_DEADEYE_ON_SHOOTING,
	PERSONA_CONT_DEADEYE_ON_EXITING_AIM,
	PERSONA_DISABLE_PLAYER_CANCELLING_DEADEYE,
	PERSONA_CONT_DEADEYE_ON_RAGDOLL,
	PERSONA_USE_EXPLOSIVE_ROUNDS,
	PERSONA_EXIT_DEADEYE_ON_TAKING_DAMAGE,
	PERSONA_CARRY_TWO_MONEYBAGS,
	PERSONA_ABILITY_LONG_PICK_HERBS,
	PERSONA_ABILITY_UNBREAKABLE_LASSO,
	PERSONA_CONT_DEADEYE_ON_SPRINTING,
	PERSONA_CANT_DEAL_HEADSHOTS,
	PERSONA_HANGMAN,
	PERSONA_ALLOW_DEADEYE_WITH_MELEE_WEAPONS,
	PERSONA_ALLOW_DEADEYE_WHILE_UNARMED,
	PERSONA_DISABLE_DEADEYE_PERFECT_ACCURACY,
	PERSONA_CANT_DEAL_HEADSHOTS_TO_PLAYERS,
	PERSONA_CANT_DEAL_CRITICAL_DAMAGE,
	PERSONA_CANT_DEAL_CRITICAL_DAMAGE_TO_PLAYERS,
	PERSONA_ALLOW_EAGLEEYE_IN_COMBAT,
	PERSONA_CONT_EAGLEEYE_ON_SPRINT,
	PERSONA_SUPPRESS_LENGENDARY_EAGLEEYE_TRAIL_COLOR
};

## _SET_LOCKON_FOCUS_FIRE_VFX
`0x5F8E0303C229C84B` | `void _SET_LOCKON_FOCUS_FIRE_VFX(Player player, char* p1)` | build 1207
Focus Fire VFX start for player: p1 = focusfire

## _SET_MAX_WANTED_LEVEL_2
`0xEA6DE0CD15AECBE2` | `void _SET_MAX_WANTED_LEVEL_2(int maxWantedLevel)` | build 1207

## _SET_MOUNT_PROMPT_DISABLED
`0x5B9813ECF7633FE8` | `void _SET_MOUNT_PROMPT_DISABLED(BOOL disabled)` | build 1207

## _SET_PED_ACTIVE_PLAYER_HORSE
`0x8FBF9EDB378CCB8C` | `void _SET_PED_ACTIVE_PLAYER_HORSE(Player player, Ped horse)` | build 1207
Seems to work similar to 0xD2CB0FB0FDCB473D

## _SET_PED_AS_SADDLE_HORSE_FOR_PLAYER
`0xD2CB0FB0FDCB473D` | `void _SET_PED_AS_SADDLE_HORSE_FOR_PLAYER(Player player, Ped mount)` | build 1207

## _SET_PLAYER_AIM_WEAPON
`0xCFFC3ECCD7A5CCEB` | `void _SET_PLAYER_AIM_WEAPON(Player player, Hash weapon, int weaponDrawOrder)` | build 1207
Sets the weapon that the specified player will aim with. The weapon must already be assigned to the PED. This also determines the weapon order, specifying which weapon the player will automatically switch to when the current weapon runs out of ammo.

## _SET_PLAYER_CAN_MERCY_KILL
`0x39363DFD04E91496` | `void _SET_PLAYER_CAN_MERCY_KILL(Player player, BOOL toggle)` | build 1311

## _SET_PLAYER_CAN_PICKUP_HAT
`0xACA45DDCEF6071C4` | `void _SET_PLAYER_CAN_PICKUP_HAT(Player player, BOOL canPickup)` | build 1207
Enables or disables the Pick Up prompt for a hat on the ground for the specified player. When set to true, the player will see a prompt to pick up the hat if they are near it.

## _SET_PLAYER_COOPERATE_PROMPT_THIS_FRAME
`0xCBB54CC7FFFFAB86` | `void _SET_PLAYER_COOPERATE_PROMPT_THIS_FRAME(Player player, Ped targetPed, int promptOrder, BOOL p3)` | build 1207
Activates the Surrender prompt for the specified player in the current frame.
```lua
// Calm targetPed
Citizen.InvokeNative(0x3A2A2071DF5CC569,targetPed,PlayerPedId(),2)
//Register lockon prompt to targetPed
Citizen.InvokeNative(0x870708A6E147A9AD,targetPed,"",10.1,10.1, 0, 0.0, 0.0, 0, false, -1)

// Activate the surrender prompt for the current player towards the targetPed
while true do 
  Wait(0)
  Citizen.InvokeNative(0xCBB54CC7FFFFAB86,PlayerId(),targetPed,1, false)
  //_SET_PLAYER_SURRENDER_PROMPT_THIS_FRAME(PlayerId(), targetPed, 1, false);
end
```

## _SET_PLAYER_DAMAGE_INFO_OVERRIDE
`0x78B3D19AF6391A55` | `void _SET_PLAYER_DAMAGE_INFO_OVERRIDE(Player player, char* damageInfo)` | build 1207
damageInfo: STANDARD_PED_DAMAGE, STANDARD_FEMALE_PED_DAMAGE, STANDARD_PLAYER_PED_DAMAGE_MP, STANDARD_FEMALE_PLAYER_PED_DAMAGE_MP

## _SET_PLAYER_DEADEYE_TAGGING_CONFIG
`0x83FCD6921FC8FD05` | `void _SET_PLAYER_DEADEYE_TAGGING_CONFIG(Player player, int filter)` | build 1207
old name _SET_DEADEYE_TAGGING_CONFIG 
FILTER_RESTRICTED = 6, Dead Eye Tagging is currently restricted to AI and Animals only...
FILTER_UNRESTRICTED = 7, Dead Eye Tagging is enabled and not restricted...

## _SET_PLAYER_DEAD_EYE_AURA_BY_HASH
`0x768E81AE285A4B67` | `void _SET_PLAYER_DEAD_EYE_AURA_BY_HASH(Player player, Hash auraColorHash)` | build 1207
Sets the aura color for entities that the player can target in Deadeye mode, based on a specific hash value. This Native was previously named `SetPlayerStatFlagHash`, but it has been re-evaluated and renamed to better reflect its function in controlling the Deadeye aura color for targeted entities
some colors
0: Default aura
1014693585
1936842089
1979474018

## _SET_PLAYER_DEFENSE_MODIFIER
`0x497A6539BB0E8787` | `void _SET_PLAYER_DEFENSE_MODIFIER(Player player, float weaponDefenseMod, float meleeDefenseMod)` | build 1207
Sets stamina core drains peed using ranged damage scale and melee damage scale

## _SET_PLAYER_DEFENSE_TYPE_MODIFIER
`0x93F499CAE53FCD05` | `void _SET_PLAYER_DEFENSE_TYPE_MODIFIER(Player player, int type, float defenseModifier)` | build 1207
bullet damage modifier: type = 4
explosive damage Defense mod: type = 7
fire damage Defense mod: type = 8, 15

## _SET_PLAYER_EXPLOSIVE_WEAPON_DAMAGE_MODIFIER
`0x2D3ACE3DE0A2B622` | `void _SET_PLAYER_EXPLOSIVE_WEAPON_DAMAGE_MODIFIER(Player player, float modifier)` | build 1207

## _SET_PLAYER_HAS_DISCOVERED_CHARACTER_NAME_MP
`0x7C32191D9FB2BDEA` | `void _SET_PLAYER_HAS_DISCOVERED_CHARACTER_NAME_MP(Hash discoveryHash)` | build 1207

## _SET_PLAYER_HAS_DISCOVERED_CHARACTER_NAME_SP
`0x946D46CD6DFB9742` | `void _SET_PLAYER_HAS_DISCOVERED_CHARACTER_NAME_SP(Player player, int p1, Hash discoveryHash)` | build 1207

## _SET_PLAYER_HAT_ACCESS
`0xA0C683284DF027C7` | `void _SET_PLAYER_HAT_ACCESS(Player player, int flag, BOOL allow)` | build 1207
Sets the player's ability to wear hats based on the specified flag. The flag value determines whether the player can wear all hats or only the ones they own.
If the flag is set to 15 and `allow` is true, the player can wear all available hats. However, if you want to restrict the player to wearing only their owned hats (flag 1), you **must first** disable flag 15 by setting it to false, and then set flag 1 to true.

## _SET_PLAYER_HEALTH_RECHARGE_TIME_MODIFIER
`0x535ED4605F89AB6E` | `void _SET_PLAYER_HEALTH_RECHARGE_TIME_MODIFIER(Player player, float modifier)` | build 1207
Setting player's Health recharge time to zero forces immediate health regen

## _SET_PLAYER_HUNTING_WAGON
`0x6A4404BDFA62CE2C` | `void _SET_PLAYER_HUNTING_WAGON(Player player, Vehicle wagon)` | build 1207
Only applies to HUNTERCART01

## _SET_PLAYER_INTERACTION_NEGATIVE_RESPONSE
`0x98CD760DE43B612E` | `void _SET_PLAYER_INTERACTION_NEGATIVE_RESPONSE(Player player, char* speech)` | build 1207

## _SET_PLAYER_INTERACTION_POSITIVE_RESPONSE
`0xC6366A585659D15C` | `void _SET_PLAYER_INTERACTION_POSITIVE_RESPONSE(Player player, char* speech)` | build 1207

## _SET_PLAYER_IN_VEHICLE_TARGETING_MODE
`0x19B4F71703902238` | `void _SET_PLAYER_IN_VEHICLE_TARGETING_MODE(int targetMode)` | build 1207
Sets your targeting mode for when you're in a vehicle (perhaps a mount/horse).
see SET_PLAYER_TARGETING_MODE for eTargetingMode

## _SET_PLAYER_LASSO_DAMAGE_PER_SECOND
`0x43F50A7CD2482156` | `void _SET_PLAYER_LASSO_DAMAGE_PER_SECOND(Player player, float damage)` | build 1207
_SET_PLAYER_A* - _SET_PLAYER_C*

## _SET_PLAYER_LOCAL_ACCURACY_FLOOR_MODIFIER
`0x4EA69188FBCE6A7D` | `void _SET_PLAYER_LOCAL_ACCURACY_FLOOR_MODIFIER(Player player, float accuracy)` | build 1207

## _SET_PLAYER_MANAGE_BUFF_SUPER_JUMP
`0x292F0B6EDC82E3A4` | `void _SET_PLAYER_MANAGE_BUFF_SUPER_JUMP(Player player, float p1)` | build 1207

## _SET_PLAYER_MAX_AMMO_OVERRIDE_FOR_AMMO_TYPE
`0xE133C1EC5300F740` | `void _SET_PLAYER_MAX_AMMO_OVERRIDE_FOR_AMMO_TYPE(Player player, Hash ammoType, int amount)` | build 1207

## _SET_PLAYER_MELEE_PROMPT_TEXT
`0x0FAF95D71ED67ADE` | `void _SET_PLAYER_MELEE_PROMPT_TEXT(Player player, char* label)` | build 1207
Sets the melee combat prompt for a specific player using a predefined text entry. use game string or 
AddTextEntry("custom_text", "Throw a punch") and use custom_text in the native

## _SET_PLAYER_MOOD
`0x39BED552DB46FFA9` | `void _SET_PLAYER_MOOD(Player player, int mood)` | build 1207
mood: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ePedMood

## _SET_PLAYER_MOUNT_STATE_ACTIVE
`0xDF93973251FB2CA5` | `void _SET_PLAYER_MOUNT_STATE_ACTIVE(Player player, BOOL active)` | build 1207
Name could potentially be inaccurate.
Used in Script Function HORSE_SETUP_PLAYER_HORSE_ATTRIBUTES (p1 = true)
_SET_PLAYER_L* - _SET_PLAYER_M*

## _SET_PLAYER_OWNS_MOUNT
`0xE6D4E435B56D5BD0` | `void _SET_PLAYER_OWNS_MOUNT(Player player, Ped mount)` | build 1207
Seems to enable active horse equipment prompt when being near it and enables the control that opens the inventory as well

## _SET_PLAYER_OWNS_VEHICLE
`0xD0E02AA618020D17` | `void _SET_PLAYER_OWNS_VEHICLE(Player player, Vehicle vehicle)` | build 1207

## _SET_PLAYER_PICKUP_PROMPT_VISIBLE
`0xD1A70C1E8D1031FE` | `void _SET_PLAYER_PICKUP_PROMPT_VISIBLE(Player player, BOOL enable)` | build 1207
Shows or hides all Pick Up prompts for the specified player, including the prompt for picking up hats from the ground. When set to true, the player will see Pick Up prompts for all nearby items. If set to false, all Pick Up prompts will be hidden.

## _SET_PLAYER_PROMPT_LEAVE_TEXT
`0x06C3DB00B69D5435` | `void _SET_PLAYER_PROMPT_LEAVE_TEXT(Player player, char* promptTextKey)` | build 1232
Sets the stand prompt for a specific player using a predefined text entry. use AddTextEntry for promptTextKey for custom names

## _SET_PLAYER_REMOTE_ACCURACY_FLOOR_MODIFIER
`0xDEE80FEDFDD43C9B` | `void _SET_PLAYER_REMOTE_ACCURACY_FLOOR_MODIFIER(Player player, float accuracy)` | build 1207

## _SET_PLAYER_RESET_FLAG
`0x9F9A829C6751F3C7` | `void _SET_PLAYER_RESET_FLAG(Player player, int playerResetFlag, BOOL p2)` | build 1207
https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ePlayerResetFlags
https://github.com/femga/rdr3_discoveries/tree/master/AI/PLAYER_RESET_FLAGS

## _SET_PLAYER_SIT_PROMPT_TEXT
`0x988C9045531B9FCE` | `void _SET_PLAYER_SIT_PROMPT_TEXT(Player player, char* label)` | build 1232
Sets the sit prompt for a specific player using a predefined text entry. use game strings like PLAYER_SIT or use custom with
AddTextEntry("sit_custom", "Take a seat")
this native must be invoked
https://imgur.com/gallery/0x988c9045531b9fce-9bTHgkv

## _SET_PLAYER_STAMINA_SPRINT_DEPLETION_MULTIPLIER
`0xBBADFB5E5E5766FB` | `void _SET_PLAYER_STAMINA_SPRINT_DEPLETION_MULTIPLIER(Player player, float multiplier)` | build 1207

## _SET_PLAYER_TOTAL_ACCURACY_MODIFIER
`0x967FF5BC0CFE6D26` | `void _SET_PLAYER_TOTAL_ACCURACY_MODIFIER(Player player, float accuracy)` | build 1207

## _SET_PLAYER_TRAMPLE_DAMAGE_MODIFIER
`0xAF341032E97FB061` | `void _SET_PLAYER_TRAMPLE_DAMAGE_MODIFIER(Player player, float modifier)` | build 1207

## _SET_PLAYER_WANTED_COOLDOWN
`0x39D8D7082BC34B72` | `void _SET_PLAYER_WANTED_COOLDOWN(Player player, int cooldown)` | build 1311
sets the player evasion cooldown timer 10000 short 35000 long

## _SET_PLAYER_WEAPON_DRAW_SPEED
`0x00EB5A760638DB55` | `void _SET_PLAYER_WEAPON_DRAW_SPEED(Player player, Hash weapon, float speed)` | build 1207

## _SET_PLAYER_WEAPON_GROUP_AS_INSTANT_KILL
`0x59F0AFF3E0A1B019` | `void _SET_PLAYER_WEAPON_GROUP_AS_INSTANT_KILL(Player player, Hash weaponGroup, BOOL toggle)` | build 1207

## _SET_PLAYER_WEAPON_GROUP_DAMAGE_MODIFIER
`0xFC79DCC94D0A5897` | `void _SET_PLAYER_WEAPON_GROUP_DAMAGE_MODIFIER(Player player, Hash weaponGroup, float modifier)` | build 1207

## _SET_RECEIVED_DAMAGE_TAKEN_ON_HORSEBACK_MODIFIER
`0xB427911EA6DFFEF3` | `void _SET_RECEIVED_DAMAGE_TAKEN_ON_HORSEBACK_MODIFIER(Player player, float damageDecrease)` | build 1207
Decreases the damage the player receives while on horseback
Previous name: _SET_RECEIVED_HORSEBACK_DAMAGE_DECREASE

## _SET_SHOW_INFO_CARD
`0xDC68829BB3F37023` | `void _SET_SHOW_INFO_CARD(Player player, BOOL showingInfoCard)` | build 1207

## _SET_SPECIAL_ABILITY_ACTIVATION_COST
`0xAE4BCC79C587EBBF` | `void _SET_SPECIAL_ABILITY_ACTIVATION_COST(Player player, float activationCost, int p2)` | build 1207

## _SET_SPECIAL_ABILITY_DISABLE_TIMER
`0xC0B1C05B313693D1` | `void _SET_SPECIAL_ABILITY_DISABLE_TIMER(Player player, float timer)` | build 1207
Only used in R* SP Script short_update

## _SET_SPECIAL_ABILITY_DURATION_COST
`0xB783F75940B23014` | `void _SET_SPECIAL_ABILITY_DURATION_COST(Player player, float durationCost)` | build 1207
durationCost: per second

## _SET_SPECIAL_ABILITY_MULTIPLIER
`0x5A498FCA232F71E1` | `void _SET_SPECIAL_ABILITY_MULTIPLIER(Player player, float multiplier)` | build 1207

## _SET_SPECIAL_ABILITY_TYPE
`0x00BA333DA05ADC23` | `void _SET_SPECIAL_ABILITY_TYPE(Player player, int type)` | build 1207
SPECIAL_ABILITY_NONE = -1,
SPECIAL_ABILITY_CAR_SLOWDOWN,
SPECIAL_ABILITY_RAGE,
SPECIAL_ABILITY_BULLET_TIME,
SPECIAL_ABILITY_SNAPSHOT,
SPECIAL_ABILITY_INSULT,
SPECIAL_ABILITY_DEADEYE,
SPECIAL_ABILITY_REVIVE

## _SET_USED_ITEM_EFFECT
`0x0E1DB1F8F5B561DC` | `void _SET_USED_ITEM_EFFECT(float health, float stamina, float deadeye, int healthCore, int staminaCore, int deadeyeCore)` | build 1207

## _SET_WEAPON_DEGRADATION_MODIFIER
`0x11A7FF918EF6BC66` | `void _SET_WEAPON_DEGRADATION_MODIFIER(Player player, float modifier)` | build 1207

## _SPECIAL_ABILITY_DRAIN_BY_AMOUNT
`0x200114E99552462B` | `void _SPECIAL_ABILITY_DRAIN_BY_AMOUNT(Player player, float amount, Any p2)` | build 1207
Drains Deadeye by given amount.

## _SPECIAL_ABILITY_GET_AMOUNT_CACHED
`0x029884FB65821B07` | `float _SPECIAL_ABILITY_GET_AMOUNT_CACHED(Player player)` | build 1207
Returns Deadeye value from player

## _SPECIAL_ABILITY_RESTORE_BY_AMOUNT
`0x51345AE20F22C261` | `void _SPECIAL_ABILITY_RESTORE_BY_AMOUNT(Player player, float amount, int p2, int p3, int p4)` | build 1207
Restores Deadeye by given amount.
Params: p2, p3, p4 = 0, 0, 1 in R* Scripts

## _SPECIAL_ABILITY_RESTORE_OUTER_RING
`0x2498035289B5688F` | `void _SPECIAL_ABILITY_RESTORE_OUTER_RING(Player player, float amount)` | build 1207
Only used in R* SP Script short_update
Restores Deadeye Outer Ring

## _SPECIAL_ABILITY_SET_ACTIVATE
`0xBBA140062B15A8AC` | `void _SPECIAL_ABILITY_SET_ACTIVATE(Player player)` | build 1207
Activates the special ability for the specified player.

## _SPECIAL_ABILITY_SET_DISABLED
`0xAE637BB8EF017875` | `void _SPECIAL_ABILITY_SET_DISABLED(Player player, BOOL disabled)` | build 1207

## _SPECIAL_ABILITY_SET_EAGLE_EYE_DISABLED
`0xC0B21F235C02139C` | `void _SPECIAL_ABILITY_SET_EAGLE_EYE_DISABLED(Player player)` | build 1207

## _SPECIAL_ABILITY_START_RESTORE
`0x1D77B47AFA584E90` | `void _SPECIAL_ABILITY_START_RESTORE(Player player, int abilityType, BOOL p2)` | build 1207
Params: p1 = -1 in R* Scripts

## _UNREGISTER_EAGLE_EYE_FOR_ENTITY
`0x9DAE1380CC5C6451` | `void _UNREGISTER_EAGLE_EYE_FOR_ENTITY(Player player, Entity entity)` | build 1207

## _UNREGISTER_EAGLE_EYE_TRAILS_FOR_ENTITY
`0x9A957912CE2EABD1` | `void _UNREGISTER_EAGLE_EYE_TRAILS_FOR_ENTITY(Player player, Entity entity, Any p2)` | build 1207
