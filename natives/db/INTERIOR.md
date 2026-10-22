# INTERIOR natives (30)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ACTIVATE_INTERIOR_ENTITY_SET
`0x174D0AAB11CED739` | `void ACTIVATE_INTERIOR_ENTITY_SET(Interior interior, const char* entitySetName, int p2)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/interiors/interior_sets

## CLEAR_ROOM_FOR_ENTITY
`0xA1762D5BBFCA13A8` | `void CLEAR_ROOM_FOR_ENTITY(Entity entity)` | build 1207

## CLEAR_ROOM_FOR_GAME_VIEWPORT
`0x951A049765E0D450` | `void CLEAR_ROOM_FOR_GAME_VIEWPORT()` | build 1207

## DEACTIVATE_INTERIOR_ENTITY_SET
`0x33B81A2C07A51FFF` | `void DEACTIVATE_INTERIOR_ENTITY_SET(Interior interior, const char* entitySetName, BOOL p2)` | build 1207

## DISABLE_INTERIOR
`0x3C2B92A1A07D4FCE` | `void DISABLE_INTERIOR(Interior interior, BOOL toggle)` | build 1207

## FORCE_ROOM_FOR_ENTITY
`0xBC29A9894C976945` | `void FORCE_ROOM_FOR_ENTITY(Entity entity, Interior interior, Hash roomHashKey)` | build 1207

## FORCE_ROOM_FOR_GAME_VIEWPORT
`0x115B4AA8FB28AB43` | `void FORCE_ROOM_FOR_GAME_VIEWPORT(int interiorID, Hash roomHashKey)` | build 1207

## GET_INTERIOR_AT_COORDS
`0xCDD36C9E5C469070` | `Interior GET_INTERIOR_AT_COORDS(float x, float y, float z)` | build 1207

## GET_INTERIOR_AT_COORDS_WITH_TYPE
`0xAAD6170AA33B13C0` | `Interior GET_INTERIOR_AT_COORDS_WITH_TYPE(float x, float y, float z, const char* interiorType)` | build 1207

## GET_INTERIOR_AT_COORDS_WITH_TYPEHASH
`0x3543AEA1816D1D2B` | `Interior GET_INTERIOR_AT_COORDS_WITH_TYPEHASH(float x, float y, float z, Hash typeHash)` | build 1207
Hashed version of GET_INTERIOR_AT_COORDS_WITH_TYPE

## GET_INTERIOR_FROM_COLLISION
`0x5054D1A5218FA696` | `int GET_INTERIOR_FROM_COLLISION(float x, float y, float z)` | build 1207

## GET_INTERIOR_FROM_ENTITY
`0xB417689857646F61` | `Interior GET_INTERIOR_FROM_ENTITY(Entity entity)` | build 1207
Returns the handle of the interior that the entity is in. Returns 0 if outside.

## GET_INTERIOR_FROM_PRIMARY_VIEW
`0xBC8A281FF125C655` | `Interior GET_INTERIOR_FROM_PRIMARY_VIEW()` | build 1207

## GET_INTERIOR_LOCATION_AND_NAMEHASH
`0x8451E87D3C2B0286` | `void GET_INTERIOR_LOCATION_AND_NAMEHASH(Interior interior, Vector3* position, Hash* nameHash)` | build 1207

## GET_KEY_FOR_ENTITY_IN_ROOM
`0x27D7B6F79E1F4603` | `Hash GET_KEY_FOR_ENTITY_IN_ROOM(Entity entity)` | build 1207
Seems to do the exact same as INTERIOR::GET_ROOM_KEY_FROM_ENTITY

## GET_ROOM_KEY_FROM_ENTITY
`0x076E46E0EB52AFC6` | `Hash GET_ROOM_KEY_FROM_ENTITY(Entity entity)` | build 1207
Gets the room hash key from the room that the specified entity is in. Each room in every interior has a unique key. Returns 0 if the entity is outside.

## IS_COLLISION_MARKED_OUTSIDE
`0xF291396B517E25B2` | `BOOL IS_COLLISION_MARKED_OUTSIDE(float x, float y, float z)` | build 1207
Returns true if the collision at the specified coords is marked as being outside (false if there's an interior)

## IS_INTERIOR_ENTITY_SET_ACTIVE
`0x32810CA2125F5842` | `BOOL IS_INTERIOR_ENTITY_SET_ACTIVE(Interior interior, const char* entitySetName)` | build 1207

## IS_INTERIOR_READY
`0x941560D2D45DBFC8` | `BOOL IS_INTERIOR_READY(Interior interior)` | build 1207

## IS_INTERIOR_SCENE
`0x4200F14D6F840A9A` | `BOOL IS_INTERIOR_SCENE()` | build 1207

## IS_VALID_INTERIOR
`0x017C1B3159F79F6C` | `BOOL IS_VALID_INTERIOR(Interior interior)` | build 1207

## PIN_INTERIOR_IN_MEMORY
`0xBD3D33EABF680168` | `void PIN_INTERIOR_IN_MEMORY(Interior interior)` | build 1207

## RETAIN_ENTITY_IN_INTERIOR
`0x5BD616735F16BF5C` | `void RETAIN_ENTITY_IN_INTERIOR(Entity entity, Interior interior)` | build 1207

## SET_INTERIOR_IN_USE
`0xB5EF6FEF2DC9EBED` | `BOOL SET_INTERIOR_IN_USE(Interior interior)` | build 1207
Actually returns void in IDA but the script header defines a BOOL return type

## UNPIN_INTERIOR
`0x07FD1A0B814F6055` | `void UNPIN_INTERIOR(Interior interior)` | build 1207
Does something similar to INTERIOR::DISABLE_INTERIOR.

You don't fall through the floor but everything is invisible inside and looks the same as when INTERIOR::DISABLE_INTERIOR is used. Peds behaves normally inside.

## _0x2533F2AB0EB9C6F9
`0x2533F2AB0EB9C6F9` | `void _0x2533F2AB0EB9C6F9(Any p0, Any p1)` | build 1207

## _0xFE2B3D5500B1B2E4
`0xFE2B3D5500B1B2E4` | `void _0xFE2B3D5500B1B2E4(Any p0, Any p1)` | build 1207

## _GET_INTERIOR_MINIMAP_HASH
`0x3039BE60B3749716` | `Hash _GET_INTERIOR_MINIMAP_HASH(Interior interior)` | build 1207

## _GET_INTERIOR_POSITION
`0x2C9746D0CA15BE1C` | `Vector3 _GET_INTERIOR_POSITION(Interior interior)` | build 1207

## _IS_INTERIOR_ENTITY_SET_VALID
`0xD56FF170710FC826` | `BOOL _IS_INTERIOR_ENTITY_SET_VALID(Interior interior, const char* entitySetName)` | build 1207
