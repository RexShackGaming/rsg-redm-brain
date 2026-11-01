# AITRANSPORT natives (24)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## GET_TRANSPORT_CONFIG_FLAG
`0xF382C92CCC1CCDBC` | `BOOL GET_TRANSPORT_CONFIG_FLAG(Entity transportEntity, int flagId, BOOL p2)` | build 1207
flagId: see SET_TRANSPORT_CONFIG_FLAG

## IS_PED_ENTERING_TRANSPORT
`0x619E63980BFC0096` | `BOOL IS_PED_ENTERING_TRANSPORT(Ped ped, Entity transportEntity, BOOL p2)` | build 1207

## IS_PED_EXITING_TRANSPORT
`0x660639BC60157048` | `BOOL IS_PED_EXITING_TRANSPORT(Ped ped, Entity transportEntity)` | build 1207

## SET_PED_OFF_TRANSPORT_SEAT
`0x8886D83A430537FD` | `void SET_PED_OFF_TRANSPORT_SEAT(Ped ped, int flags)` | build 1207

## SET_PED_ON_TRANSPORT_SEAT
`0xE588B5A8A005CB5E` | `void SET_PED_ON_TRANSPORT_SEAT(Ped ped, Entity transportEntity, int seat, int flags)` | build 1207
seat: see CREATE_PED_INSIDE_VEHICLE

## SET_TRANSPORT_ACCESSIBLE_SEAT_FLAGS
`0xDD0660C997DE94FD` | `void SET_TRANSPORT_ACCESSIBLE_SEAT_FLAGS(Entity transportEntity, int flags)` | build 1207

## SET_TRANSPORT_CONFIG_FLAG
`0xBA8818212633500A` | `void SET_TRANSPORT_CONFIG_FLAG(Entity transportEntity, int flagId, BOOL value)` | build 1207
flagId:
enum eTransportConfigFlags
{
	TCF_NotConsideredForEntryByLocalPlayer,
	TCF_0xB78D6624,
	TCF_0xA9700425,
	TCF_0x8D7E4641,
	TCF_0xF24BAA1F,
	TCF_0x63B77935,
	TCF_NotConsideredForEntryByAllPlayers,
	TCF_0xD17A2AFD,
	TCF_0xD4E4FDD5,
	TCF_0x8227C929,
	TCF_0x812C1070,
	TCF_0x0E1AB26F,
	TCF_0xBF4EC863,
	TCF_0x75660C36,
	TCF_0xA2539E20,
	TCF_0x9162C633,
	TCF_DisableHonorModifiers,
	TCF_0xF9E71CB6,
	TCF_0x933ECD3F,
	TCF_0x18513A34
};
https://github.com/femga/rdr3_discoveries/tree/master/AI/TRANSPORT_CONFIG_FLAGS

## TASK_ENTER_TRANSPORT
`0xAEE3ADD08829CB6F` | `void TASK_ENTER_TRANSPORT(Any* args)` | build 1207
```lua
struct args
{
  Any p0;
  Any p1;
  Any p2;
  Ped ped;
  Vehicle vehicle;
  int seatIndex;
  int timer;
  float pedSpeed;
  int flags;
}
```

## TASK_EXIT_TRANSPORT
`0xC273A5B8488F7838` | `void TASK_EXIT_TRANSPORT(Any* args)` | build 1207
```lua
struct args
{
  Any p0;
  Any p1;
  Any p2;
  Ped ped;
  Vehicle vehicle;
  float pedSpeed;
  int flags;
}
```

## _0x4B6C9A43F7D9109B
`0x4B6C9A43F7D9109B` | `void _0x4B6C9A43F7D9109B(Entity transportEntity, Any p1)` | build 1207
Used for ROWBOAT and ROWBOATSWAMP in R* Scripts

## _CLEAR_ALL_SEAT_PREFERENCE_SLOTS
`0x5639FBEA922788DA` | `void _CLEAR_ALL_SEAT_PREFERENCE_SLOTS(Entity transportEntity)` | build 1207

## _CLEAR_TRANSPORT_EXIT_BLEND_RATIO
`0xF8C20282B237E3F7` | `void _CLEAR_TRANSPORT_EXIT_BLEND_RATIO(Ped ped)` | build 1207

## _GET_PED_IN_TRANSPORT_SEAT
`0xFFEC4B0A1A3ED515` | `Ped _GET_PED_IN_TRANSPORT_SEAT(Entity transportEntity, int seatIndex)` | build 1207
seatIndex: see CREATE_PED_INSIDE_VEHICLE

## _GET_TRANSPORT_USAGE_FLAGS
`0xE195C5A82156321D` | `Any _GET_TRANSPORT_USAGE_FLAGS(Entity transportEntity, int* flags)` | build 1207
See _SET_TRANSPORT_USAGE_FLAGS

## _IS_PED_ON_TRANSPORT_ENTITY
`0x159EF5B6EDCE00E8` | `BOOL _IS_PED_ON_TRANSPORT_ENTITY(Ped ped, Entity transportEntity)` | build 1207
Checks if ped is placed on target transportEntity

## _IS_PED_ON_TRANSPORT_SEAT
`0xDC44F405A6B98D03` | `BOOL _IS_PED_ON_TRANSPORT_SEAT(Ped ped, BOOL p1)` | build 1207

## _IS_TRANSPORT_SEAT_FREE
`0x43FF27FC1829C202` | `BOOL _IS_TRANSPORT_SEAT_FREE(Entity transportEntity, int seatIndex)` | build 1207
Called together with IS_VEHICLE_SEAT_FREE

## _IS_TRANSPORT_SEAT_OCCUPIED
`0x2E2E06023D07631E` | `BOOL _IS_TRANSPORT_SEAT_OCCUPIED(Entity transportEntity, int seatIndex)` | build 1207

## _SET_AI_CAN_USE_TRANSPORT
`0x67F7CEAC2391E114` | `void _SET_AI_CAN_USE_TRANSPORT(Entity transportEntity, BOOL state)` | build 1207

## _SET_PED_USE_TRANSPORT_SEAT_PREFERENCE
`0xB7079F4C72896756` | `void _SET_PED_USE_TRANSPORT_SEAT_PREFERENCE(Ped ped, Entity transportEntity, int preferenceSlot, int p3, int seatIndex)` | build 1207

## _SET_TRANSPORT_EXCLUSIVE_DRIVER
`0x4248AB2EEB3C75AD` | `void _SET_TRANSPORT_EXCLUSIVE_DRIVER(Entity transportEntity, Ped ped, BOOL seatIndex)` | build 1207

## _SET_TRANSPORT_EXIT_BLEND_RATIO
`0x8C8371EDFAF014A0` | `void _SET_TRANSPORT_EXIT_BLEND_RATIO(Ped ped, float ratio)` | build 1207

## _SET_TRANSPORT_PRIORITY_SEAT
`0x13F138225C202F66` | `void _SET_TRANSPORT_PRIORITY_SEAT(Entity transportEntity, int seatIndex)` | build 1207

## _SET_TRANSPORT_USAGE_FLAGS
`0xE2487779957FE897` | `void _SET_TRANSPORT_USAGE_FLAGS(Entity transportEntity, int flags)` | build 1207
enum eTransportUsageFlags
{
	TUF_INVALID = 0,
	TUF_ALLOW_DRIVER_ME = (1 << 0),
	TUF_ALLOW_DRIVER_GANG = (1 << 1),
	TUF_ALLOW_DRIVER_CREW = (1 << 2),
	TUF_ALLOW_DRIVER_FRIENDS = (1 << 3),
	TUF_ALLOW_DRIVER_ANYONE = (1 << 4),
	TUF_ALLOW_PASSENGER_ME = (1 << 5),
	TUF_ALLOW_PASSENGER_GANG = (1 << 6),
	TUF_ALLOW_PASSENGER_CREW = (1 << 7),
	TUF_ALLOW_PASSENGER_FRIENDS = (1 << 8),
	TUF_ALLOW_PASSENGER_ANYONE = (1 << 9),
	TUF_ALLOW_ACCESS_AI = (1 << 10)
};
