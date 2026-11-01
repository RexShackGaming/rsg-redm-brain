# PHYSICS natives (72)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ACTIVATE_PHYSICS
`0x710311ADF0E20730` | `void ACTIVATE_PHYSICS(Entity entity)` | build 1207

## ADD_ROPE
`0xE832D760399EB220` | `int ADD_ROPE(float x, float y, float z, float rotX, float rotY, float rotZ, float length, int ropeType, float maxLength, float minLength, float p10, BOOL p11, BOOL p12, BOOL rigid, float p14, BOOL breakWhenShot, Any* unkPtr, BOOL p17)` | build 1207
There are 19 types of rope, from type = 0 to type = 18
Rope definitions are stored in ropedata.xml
Rope types 0, 15 and 18 have proper physics for hanging objects (taut, do not sag, small to medium diameter, good aspect for a rope)

## ATTACH_ENTITIES_TO_ROPE
`0x3D95EC8B6D940AC3` | `void ATTACH_ENTITIES_TO_ROPE(int ropeId, Entity entity1, Entity entity2, float ent1X, float ent1Y, float ent1Z, float ent2X, float ent2Y, float ent2Z, float length, int alwaysZero1, int alwaysZero2, char* boneName1, char* boneName2, BOOL p14, int boneId1, int boneId2, int alwaysZero3, int alwaysZero4, BOOL p19, BOOL p20)` | build 1207
Attaches entity 1 to entity 2.
If you use a boneName (p12/p13) make sure boneId (p15/p16) is set to -1.

## BREAK_ENTITY_GLASS
`0x2E648D16F6E308F3` | `void BREAK_ENTITY_GLASS(Entity entity, float p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, Any p9, BOOL p10)` | build 1207

## DELETE_CHILD_ROPE
`0xAA5D6B1888E4DB20` | `void DELETE_CHILD_ROPE(int ropeId)` | build 1207

## DELETE_ROPE
`0x52B4829281364649` | `void DELETE_ROPE(int* ropeId)` | build 1207

## DETACH_ROPE_FROM_ENTITY
`0xBCF3026912A8647D` | `void DETACH_ROPE_FROM_ENTITY(int ropeId, Entity entity)` | build 1207

## DOES_ROPE_EXIST
`0xFD5448BE3111ED96` | `BOOL DOES_ROPE_EXIST(int ropeId)` | build 1207

## GET_ROPE_LAST_VERTEX_COORD
`0x21BB0FBD3E217C2D` | `Vector3 GET_ROPE_LAST_VERTEX_COORD(int ropeId)` | build 1207

## GET_ROPE_VERTEX_COORD
`0xEA61CA8E80F09E4D` | `Vector3 GET_ROPE_VERTEX_COORD(int ropeId, int vertex)` | build 1207

## GET_ROPE_VERTEX_COUNT
`0x3655F544CD30F0B5` | `int GET_ROPE_VERTEX_COUNT(int ropeId)` | build 1207

## ROPE_DRAW_SHADOW_ENABLED
`0xF159A63806BB5BA8` | `void ROPE_DRAW_SHADOW_ENABLED(int* ropeId, BOOL toggle)` | build 1207

## ROPE_FORCE_LENGTH
`0xD009F759A723DB1B` | `void ROPE_FORCE_LENGTH(int ropeId, float length)` | build 1207
Forces a rope to a certain length.

## ROPE_SET_UPDATE_ORDER
`0xDC57A637A20006ED` | `void ROPE_SET_UPDATE_ORDER(int ropeId, Any p1)` | build 1207

## SET_DAMPING
`0xEEA3B200A6FEB65B` | `void SET_DAMPING(Entity entity, int vertex, float value)` | build 1207

## SET_DISABLE_BREAKING
`0x5CEC1A84620E7D5B` | `void SET_DISABLE_BREAKING(Object object, BOOL toggle)` | build 1207

## SET_DISABLE_FRAG_DAMAGE
`0x01BA3AED21C16CFB` | `void SET_DISABLE_FRAG_DAMAGE(Object object, BOOL toggle)` | build 1207

## START_ROPE_UNWINDING_FRONT
`0x538D1179EC1AA9A9` | `void START_ROPE_UNWINDING_FRONT(int ropeId)` | build 1207

## START_ROPE_WINDING
`0x1461C72C889E343E` | `void START_ROPE_WINDING(int ropeId)` | build 1207

## STOP_ROPE_UNWINDING_FRONT
`0xFFF3A50779EFBBB3` | `void STOP_ROPE_UNWINDING_FRONT(int ropeId)` | build 1207

## STOP_ROPE_WINDING
`0xCB2D4AB84A19AA7C` | `void STOP_ROPE_WINDING(int ropeId)` | build 1207

## _0x0CB16D05E03FB525
`0x0CB16D05E03FB525` | `void _0x0CB16D05E03FB525(Any p0)` | build 1207

## _0x1D97DA8ACB5D2582
`0x1D97DA8ACB5D2582` | `void _0x1D97DA8ACB5D2582(int ropeId, int p1)` | build 1207

## _0x21D0890D88DFB0B0
`0x21D0890D88DFB0B0` | `void _0x21D0890D88DFB0B0(int ropeId, BOOL p1, float p2, float p3, float p4, float p5, float p6, float p7, float p8, float p9, int p10)` | build 1207

## _0x31160EC47E7C9549
`0x31160EC47E7C9549` | `void _0x31160EC47E7C9549(Any p0, Any p1)` | build 1207

## _0x32F4DBFDFCCCC735
`0x32F4DBFDFCCCC735` | `void _0x32F4DBFDFCCCC735(Any p0, Any p1, Any p2)` | build 1207

## _0x3900491C0D61ED4B
`0x3900491C0D61ED4B` | `void _0x3900491C0D61ED4B(Any p0, Any p1)` | build 1207

## _0x423C6B1F3786D28B
`0x423C6B1F3786D28B` | `void _0x423C6B1F3786D28B(Any p0, Any p1)` | build 1207

## _0x461FCBDEB4D06717
`0x461FCBDEB4D06717` | `void _0x461FCBDEB4D06717(int ropeId, BOOL p1)` | build 1207

## _0x483D4E917B0D35A9
`0x483D4E917B0D35A9` | `void _0x483D4E917B0D35A9(Any p0, Any p1)` | build 1207

## _0x522FA3F490E2F7AC
`0x522FA3F490E2F7AC` | `void _0x522FA3F490E2F7AC(int ropeId, Any p1, Any p2)` | build 1207

## _0x5A989B7EE3672A56
`0x5A989B7EE3672A56` | `void _0x5A989B7EE3672A56(Any p0, Any p1)` | build 1207

## _0x5BD7457221CC5FF4
`0x5BD7457221CC5FF4` | `void _0x5BD7457221CC5FF4(Any p0, Any p1)` | build 1207

## _0x5E981C764DF33117
`0x5E981C764DF33117` | `void _0x5E981C764DF33117(Any p0, Any p1)` | build 1207

## _0x69C810B72291D831
`0x69C810B72291D831` | `void _0x69C810B72291D831(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0x6EA0E93CFFA472CC
`0x6EA0E93CFFA472CC` | `void _0x6EA0E93CFFA472CC(Any p0)` | build 1207

## _0x751DF00EEFF122E3
`0x751DF00EEFF122E3` | `void _0x751DF00EEFF122E3(Any p0)` | build 1207

## _0x76BAD9D538BCA1AA
`0x76BAD9D538BCA1AA` | `void _0x76BAD9D538BCA1AA(int ropeId, float p1)` | build 1207

## _0x814D453FCFDF119F
`0x814D453FCFDF119F` | `void _0x814D453FCFDF119F(Any p0, Any p1, Any p2)` | build 1207

## _0x8D59079C37C21D78
`0x8D59079C37C21D78` | `void _0x8D59079C37C21D78(int ropeId, float p1)` | build 1207
_ROPE_SET_*

## _0x8EEDFD8921389928
`0x8EEDFD8921389928` | `void _0x8EEDFD8921389928(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9)` | build 1207

## _0x9C24846D0A4A2776
`0x9C24846D0A4A2776` | `void _0x9C24846D0A4A2776(Any p0)` | build 1207

## _0xB40EA9E0D2E2F7F3
`0xB40EA9E0D2E2F7F3` | `void _0xB40EA9E0D2E2F7F3(int ropeId, float p1)` | build 1207

## _0xB7469CB9AC3C0FD4
`0xB7469CB9AC3C0FD4` | `void _0xB7469CB9AC3C0FD4(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## _0xBB3E9B073E66C3C9
`0xBB3E9B073E66C3C9` | `void _0xBB3E9B073E66C3C9(int ropeId, BOOL p1, BOOL p2, BOOL p3, BOOL p4)` | build 1207

## _0xBDDA142759307528
`0xBDDA142759307528` | `void _0xBDDA142759307528(Any p0)` | build 1207

## _0xC64E7A62632AD2FE
`0xC64E7A62632AD2FE` | `void _0xC64E7A62632AD2FE(int ropeId, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7)` | build 1207

## _0xC89E7410A93AC19A
`0xC89E7410A93AC19A` | `void _0xC89E7410A93AC19A(int ropeId, float p1)` | build 1207

## _0xD699E688B49C0FD2
`0xD699E688B49C0FD2` | `void _0xD699E688B49C0FD2(int ropeId, float p1, float p2, float p3, BOOL p4)` | build 1207

## _0xDEDE679ED29DD4E7
`0xDEDE679ED29DD4E7` | `void _0xDEDE679ED29DD4E7(int ropeId, BOOL p1)` | build 1207

## _0xE54BF2CE6C7D23A9
`0xE54BF2CE6C7D23A9` | `void _0xE54BF2CE6C7D23A9(int ropeId, int p1, float x, float y, float z)` | build 1207

## _0xEAF529446488EB18
`0xEAF529446488EB18` | `void _0xEAF529446488EB18(Any p0)` | build 1207

## _0xF1EA2A881EB7F2CD
`0xF1EA2A881EB7F2CD` | `void _0xF1EA2A881EB7F2CD(int ropeId, BOOL p1)` | build 1207

## _0xF27F1A8DE4F50A1B
`0xF27F1A8DE4F50A1B` | `void _0xF27F1A8DE4F50A1B(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0xF8CA39D5C0D1D9A1
`0xF8CA39D5C0D1D9A1` | `void _0xF8CA39D5C0D1D9A1(Any p0, Any p1)` | build 1207

## _0xFB9153A54AC713E8
`0xFB9153A54AC713E8` | `void _0xFB9153A54AC713E8(int ropeId, BOOL p1)` | build 1207

## _ADD_ROPE_2
`0xE9C59F6809373A99` | `int _ADD_ROPE_2(float x, float y, float z, float rotX, float rotY, float rotZ, float length, int ropeType, BOOL isNetworked, int p9, float p10)` | build 1207

## _ATTACH_ENTITES_TO_ROPE_3
`0xE9CD9A67834985A7` | `void _ATTACH_ENTITES_TO_ROPE_3(int ropeId, Entity entity1, Entity entity2, float p3, float p4, float p5, float p6, float p7, float p8, Any p9, Any p10)` | build 1207

## _ATTACH_ENTITIES_TO_ROPE_2
`0x462FF2A432733A44` | `void _ATTACH_ENTITIES_TO_ROPE_2(int ropeId, Entity entity1, Entity entity2, float ent1X, float ent1Y, float ent1Z, float ent2X, float ent2Y, float ent2Z, char* boneName1, char* boneName2)` | build 1207
Attaches a rope to two entities: binds two bones from two entities; one entity can be an object, i.e. a suspension point, the other an NPC bone

## _BREAK_ROPE
`0x4CFA2B7FAE115ECB` | `void _BREAK_ROPE(int* ropeId, int* ropeTop, int* ropeBottom, float offsetX, float offsetY, float offsetZ, int p6)` | build 1207
ropeTop returns top half of rope, ropeBottom returns bottom half of rope

## _CREATE_ROPE_WINDING_ABILITY
`0x3C6490D940FF5D0B` | `void _CREATE_ROPE_WINDING_ABILITY(int ropeId, char* p1, char* ropeModelType, float length, BOOL p4)` | build 1207
Combining this with ADD_ROPE enables winding
p1: mostly empty (0)
ropeModelType: RB_L_Wrist02, RB_R_Wrist02, ropeAttach, noose01x_Rope_03, SKEL_Neck0, SKEL_L_FOOT, SKEL_Neck1, Root_s_meatbit_Chunck_Xlarge01x
_CREATE_*

## _HITCH_HORSE
`0x06AADE17334F7A40` | `void _HITCH_HORSE(Ped horse, float x, float y, float z)` | build 1207

## _IS_ROPE_ATTACHED_TO_ENTITY
`0x9B4F7E3E4F9C77B3` | `BOOL _IS_ROPE_ATTACHED_TO_ENTITY(int ropeId, Entity entity)` | build 1207

## _IS_ROPE_BROKEN
`0x79C2BEC82CFD7F7F` | `BOOL _IS_ROPE_BROKEN(int ropeId)` | build 1207

## _RELEASE_ROPE
`0x6076213101A47B3B` | `void _RELEASE_ROPE(int ropeId)` | build 1207

## _ROPE_CHANGE_VISIBILITY
`0x7A54D82227A139DB` | `void _ROPE_CHANGE_VISIBILITY(int* ropeId, BOOL visible)` | build 1207

## _ROPE_FORCE_LENGHT
`0x1FC92BDBA1106BD2` | `void _ROPE_FORCE_LENGHT(int ropeId, float length)` | build 1207

## _ROPE_GET_BREAKER_OF_ROPE
`0xEE360CFC80C8B2BC` | `Player _ROPE_GET_BREAKER_OF_ROPE(int ropeId)` | build 1311

## _ROPE_GET_FORCED_LENGTH
`0x3D69537039F8D824` | `float _ROPE_GET_FORCED_LENGTH(int ropeId)` | build 1207

## _START_ROPE_UNWINDING_BACK
`0x00F611A794A3C36E` | `void _START_ROPE_UNWINDING_BACK(int ropeId)` | build 1207

## _STOP_ROPE_UNWINDING_BACK
`0x10DAA76CB8A201A1` | `void _STOP_ROPE_UNWINDING_BACK(int ropeId)` | build 1207

## _UNHITCH_HORSE
`0x0348469DAA17576C` | `void _UNHITCH_HORSE(Ped horse)` | build 1207
