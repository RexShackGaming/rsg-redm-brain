# PROPSET natives (37)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## CREATE_PROP_SET_INSTANCE_ATTACHED_TO_ENTITY
`0x9609DBDDE18FAD8C` | `PropSet CREATE_PROP_SET_INSTANCE_ATTACHED_TO_ENTITY(Hash hash, float x, float y, float z, Entity entity, float p5, BOOL p6, int p7, BOOL p8)` | build 1207

## DOES_PROP_SET_EXIST
`0x7DDDCF815E650FF5` | `BOOL DOES_PROP_SET_EXIST(PropSet propSet)` | build 1207

## IS_PROP_SET_FULLY_LOADED
`0xF42DB680A8B2A4D9` | `BOOL IS_PROP_SET_FULLY_LOADED(PropSet propSet)` | build 1207

## _0x58E0B01D45CA7357
`0x58E0B01D45CA7357` | `void _0x58E0B01D45CA7357(Any p0)` | build 1207

## _ADD_ADDITIONAL_PROP_SET_FOR_VEHICLE
`0x75F90E4051CC084C` | `void _ADD_ADDITIONAL_PROP_SET_FOR_VEHICLE(Vehicle vehicle, Hash propset)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/vehicles/vehicle_modding/vehicle_propsets.lua

## _ADD_LIGHT_PROP_SET_TO_VEHICLE
`0xC0F0417A90402742` | `void _ADD_LIGHT_PROP_SET_TO_VEHICLE(Vehicle vehicle, Hash lightPropset)` | build 1207
To remove propsets either parse a zero as hash or call 0xE31C0CB1C3186D40
0xA6A9712955F53D9C returns lightPropset Hashes
https://github.com/femga/rdr3_discoveries/blob/master/vehicles/vehicle_modding/vehicle_lantern_propsets.lua

## _ADD_PROP_SET_FOR_VEHICLE
`0xD80FAF919A2E56EA` | `void _ADD_PROP_SET_FOR_VEHICLE(Vehicle vehicle, Hash propset)` | build 1207
List of vehicle propsets (wagons & trains): https://pastebin.com/1CsnvGLu / https://pastebin.com/v7TtqTgE

## _CREATE_PROP_SET
`0xE65C5CBA95F0E510` | `PropSet _CREATE_PROP_SET(Hash propsetType, float x, float y, float z, int placementType, float heading, float zProbe, BOOL p7, BOOL useVegMod)` | build 1207
propsetType: https://github.com/femga/rdr3_discoveries/blob/master/objects/propsets_list.lua
placementType: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/PlacementType

## _CREATE_PROP_SET_2
`0x899C97A1CCE7D483` | `PropSet _CREATE_PROP_SET_2(Hash propsetType, float x, float y, float z, int placementType, float heading, float zProbe, BOOL p7, BOOL useVegMod)` | build 1207
Same as _CREATE_PROP_SET

## _CREATE_PROP_SET_INSTANCE_ATTACHED_TO_ENTITY_2
`0xACA7FB30269096D4` | `PropSet _CREATE_PROP_SET_INSTANCE_ATTACHED_TO_ENTITY_2(Hash hash, float x, float y, float z, Entity entity, float p5, BOOL p6, int p7, BOOL p8)` | build 1207
Same as CREATE_PROP_SET_INSTANCE_ATTACHED_TO_ENTITY

## _DELETE_PROP_SET
`0x58AC173A55D9D7B4` | `void _DELETE_PROP_SET(PropSet propSet, BOOL p1, BOOL p2)` | build 1207

## _DOES_PROP_SET_OF_TYPE_EXIST_NEAR_COORDS
`0x72068021F498E6E3` | `BOOL _DOES_PROP_SET_OF_TYPE_EXIST_NEAR_COORDS(Hash propsetHash, float x, float y, float z)` | build 1207

## _DOES_VEHICLE_HAVE_ANY_LIGHT_PROP_SET
`0xC9B4B3A36F81FD75` | `BOOL _DOES_VEHICLE_HAVE_ANY_LIGHT_PROP_SET(Vehicle vehicle)` | build 1207

## _DOES_VEHICLE_HAVE_ANY_PROP_SET
`0x53784CEA0159439B` | `BOOL _DOES_VEHICLE_HAVE_ANY_PROP_SET(Vehicle vehicle)` | build 1207

## _GET_ENTITIES_FROM_PROP_SET
`0x738271B660FE0695` | `int _GET_ENTITIES_FROM_PROP_SET(PropSet propSet, ItemSet itemSet, Hash model, BOOL p3, BOOL p4)` | build 1207

## _GET_PROP_SET_AT_COORDS
`0xC061E50F8D299F95` | `PropSet _GET_PROP_SET_AT_COORDS(Hash propsetHash, float x, float y, float z)` | build 1207

## _GET_PROP_SET_MODEL
`0xA6A9712955F53D9C` | `Hash _GET_PROP_SET_MODEL(PropSet propSet)` | build 1207

## _GET_TRAIN_CARRIAGE_PROP_SET
`0xCFC0BD09BB1B73FF` | `PropSet _GET_TRAIN_CARRIAGE_PROP_SET(Entity trainCarriage)` | build 1207
Example before/after deleting a train carriage's propset: https://imgur.com/a/qRNrIrK

## _GET_VEHICLE_LIGHT_PROP_SET
`0xA079300AF757FB1A` | `PropSet _GET_VEHICLE_LIGHT_PROP_SET(Vehicle vehicle)` | build 1207
Returns PropSet handle to be used with _GET_PROP_SET_MODEL

## _GET_VEHICLE_PROP_SET
`0xCE2ACD6F602803E5` | `PropSet _GET_VEHICLE_PROP_SET(Vehicle vehicle)` | build 1207

## _GET_VEHICLE_PROP_SET_HASH
`0x36F69E7A22655653` | `Hash _GET_VEHICLE_PROP_SET_HASH(Vehicle vehicle)` | build 1207

## _HAS_PROP_SET_LOADED
`0x48A88FC684C55FDC` | `BOOL _HAS_PROP_SET_LOADED(Hash hash)` | build 1207

## _HAS_PROP_SET_LOADED_2
`0xD090ABEF4D6A7D96` | `BOOL _HAS_PROP_SET_LOADED_2(Hash hash)` | build 1207
Same as _HAS_PROP_SET_LOADED

## _HAS_VEHICLE_TRAILER_PROP_SET_LOADED
`0x8F3333F0A6900B3C` | `BOOL _HAS_VEHICLE_TRAILER_PROP_SET_LOADED(Vehicle vehicle, int wagonIndex)` | build 1207

## _IS_PROP_SET_VISIBLE
`0x0CE8AAFE9E433A23` | `BOOL _IS_PROP_SET_VISIBLE(PropSet propSet)` | build 1207

## _IS_VEHICLE_LIGHT_PROP_SET_LOADED
`0x0790473EEE1977D3` | `BOOL _IS_VEHICLE_LIGHT_PROP_SET_LOADED(Vehicle vehicle)` | build 1207

## _IS_VEHICLE_PROP_SET_LOADED
`0x155B2FBE72D7D1D0` | `BOOL _IS_VEHICLE_PROP_SET_LOADED(Vehicle vehicle)` | build 1207

## _IS_VEHICLE_PROP_SET_LOADED_ADDITIONAL
`0x7264F9CA87A9830B` | `BOOL _IS_VEHICLE_PROP_SET_LOADED_ADDITIONAL(Vehicle vehicle)` | build 1207

## _MOVE_PROPSET_COORDS_AND_HEADING
`0xC4B67EF3FD65622D` | `void _MOVE_PROPSET_COORDS_AND_HEADING(int propset, float posX, float posY, float posZ, BOOL onGroundProperly, float heading)` | build 1207
Relocates an existing prop set to specified coordinates and adjusts its heading (rotation) without affecting the prop set's internal layout or structure. The `propSet` parameter identifies the prop set to move. The parameters (`coordsX`, `coordsY`, `coordsZ`) set the new central position of the prop set, while `heading` specifies its rotation around the Z-axis (in degrees). When `onGroundProperly` is true, the prop set automatically aligns accurately with the terrain

## _RELEASE_PROP_SET
`0xB1964A83B345B4AB` | `BOOL _RELEASE_PROP_SET(Hash hash)` | build 1207

## _REMOVE_VEHICLE_LIGHT_PROP_SETS
`0xE31C0CB1C3186D40` | `void _REMOVE_VEHICLE_LIGHT_PROP_SETS(Vehicle vehicle)` | build 1207

## _REMOVE_VEHICLE_PROP_SETS
`0x3BCF32FF37EA9F1D` | `void _REMOVE_VEHICLE_PROP_SETS(Vehicle vehicle)` | build 1207

## _REQUEST_PROP_SET
`0xF3DE57A46D5585E9` | `BOOL _REQUEST_PROP_SET(Hash hash)` | build 1207

## _REQUEST_PROP_SET_2
`0xE72F591958F3ACAB` | `BOOL _REQUEST_PROP_SET_2(Hash hash)` | build 1207
Same as _REQUEST_PROP_SET

## _SET_PROP_SET_AS_NO_LONGER_NEEDED
`0x909E3C7FAE539FB1` | `void _SET_PROP_SET_AS_NO_LONGER_NEEDED(PropSet propSet)` | build 1207

## _SET_PROP_SET_FLAG
`0xC1AB7EEFD3E6EE49` | `void _SET_PROP_SET_FLAG(PropSet propSet, int flag)` | build 1207

## _SET_PROP_SET_VISIBLE
`0x9D096A5BD02F953E` | `void _SET_PROP_SET_VISIBLE(PropSet propSet, BOOL toggle)` | build 1207
