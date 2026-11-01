# DECORATOR natives (15)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## DECOR_EXIST_ON
`0xD9D1CDBF3464DCDF` | `BOOL DECOR_EXIST_ON(Entity entity, const char* propertyName)` | build 1207
Returns whether or not the specified property is set for the entity.

## DECOR_GET_BOOL
`0xDEF3F1B071ABB197` | `BOOL DECOR_GET_BOOL(Entity entity, const char* propertyName)` | build 1207

## DECOR_GET_FLOAT
`0xE5FF70CD842CA9D4` | `float DECOR_GET_FLOAT(Entity entity, const char* propertyName)` | build 1207

## DECOR_GET_INT
`0x44DB62727762FD9B` | `int DECOR_GET_INT(Entity entity, const char* propertyName)` | build 1207

## DECOR_IS_REGISTERED_AS_TYPE
`0x72355278C069F272` | `BOOL DECOR_IS_REGISTERED_AS_TYPE(const char* propertyName, int type)` | build 1207
type: see DECOR_REGISTER

## DECOR_REGISTER
`0x0B253D644E3C36B3` | `void DECOR_REGISTER(const char* propertyName, int type)` | build 1207

## DECOR_REMOVE
`0x2BA7F5877A088A1D` | `BOOL DECOR_REMOVE(Entity entity, const char* propertyName)` | build 1207

## DECOR_REMOVE_ALL
`0x88942780E0ADEA42` | `BOOL DECOR_REMOVE_ALL(Entity entity)` | build 1207

## DECOR_SET_BOOL
`0xFE26E4609B1C3772` | `BOOL DECOR_SET_BOOL(Entity entity, const char* propertyName, BOOL value)` | build 1207
This function sets metadata of type bool to specified entity.

## DECOR_SET_FLOAT
`0x238F8B0C1C7FE834` | `BOOL DECOR_SET_FLOAT(Entity entity, const char* propertyName, float value)` | build 1207

## DECOR_SET_INT
`0xE88F4D7F52A6090F` | `BOOL DECOR_SET_INT(Entity entity, const char* propertyName, int value)` | build 1207
Sets property to int.

## DECOR_SET_STRING
`0x0671C1A3FF7AFDFC` | `BOOL DECOR_SET_STRING(Entity entity, const char* propertyName, const char* value)` | build 1207

## _DECOR_GET_PLAYER_INDEX
`0xB1682B2443F0540B` | `int _DECOR_GET_PLAYER_INDEX(Entity entity, char* propertyName)` | build 1207

## _DECOR_REGISTER_NETWORKED
`0x4587374F88B7F6C2` | `void _DECOR_REGISTER_NETWORKED(char* propertyName, int type, BOOL isNetworked)` | build 1207
Old Name: _DECOR_REGISTER_2

## _DECOR_SET_PLAYER_INDEX
`0x4BDC83150D43772D` | `BOOL _DECOR_SET_PLAYER_INDEX(Entity entity, char* propertyName, int value)` | build 1207
Old name: _DECOR_SET_UINT8
