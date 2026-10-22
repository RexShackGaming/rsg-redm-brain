# BRAIN natives (11)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## DISABLE_SCRIPT_BRAIN_SET
`0x3F44EA613A5B2676` | `void DISABLE_SCRIPT_BRAIN_SET(int brainSet)` | build 1207

## ENABLE_SCRIPT_BRAIN_SET
`0x1CF6E5C6750EADBD` | `void ENABLE_SCRIPT_BRAIN_SET(int brainSet)` | build 1207

## REACTIVATE_ALL_OBJECT_BRAINS_THAT_ARE_WAITING_TILL_OUT_OF_RANGE
`0xA32B0B05EFF75730` | `void REACTIVATE_ALL_OBJECT_BRAINS_THAT_ARE_WAITING_TILL_OUT_OF_RANGE()` | build 1207
Called before starting a new thread_monitor script thread in startup_mp/startup_tlg
Alternative name _REGISTER_SCRIPT_BRAIN

Old name: _PREPARE_SCRIPT_BRAIN

## REACTIVATE_NAMED_OBJECT_BRAINS_WAITING_TILL_OUT_OF_RANGE
`0x74C333E34DF74E8A` | `void REACTIVATE_NAMED_OBJECT_BRAINS_WAITING_TILL_OUT_OF_RANGE(char* scriptName)` | build 1207

## REGISTER_OBJECT_SCRIPT_BRAIN
`0x16AF9B4EEAC3B305` | `void REGISTER_OBJECT_SCRIPT_BRAIN(char* scriptName, Hash modelHash, int p2, float activationRange, int p4, int p5)` | build 1207
Registers a script for any object with a specific model hash.

## _0x4AA5EA1EDFB25786
`0x4AA5EA1EDFB25786` | `void _0x4AA5EA1EDFB25786(int flag)` | build 1207
Called with flag 0 before 0xA6AC35DB4A7957A8 in net_entity_brain
_SET_SCRIPT_BRAIN*

## _0xA6AC35DB4A7957A8
`0xA6AC35DB4A7957A8` | `void _0xA6AC35DB4A7957A8(int flag)` | build 1207
Common flags: 250, 99999
_SET_SCRIPT_BRAIN*

## _GET_SCRIPT_BRAIN_ENTITY
`0x6818D1A194E29983` | `Entity _GET_SCRIPT_BRAIN_ENTITY()` | build 1207

## _REMOVE_SCRIPT_BRAIN_ENTITY
`0x38F1E09224EECA09` | `void _REMOVE_SCRIPT_BRAIN_ENTITY(Entity entity)` | build 1311

## _START_PRELOADED_SCRIPT_BRAIN
`0x4E4507CC5E4DB869` | `int _START_PRELOADED_SCRIPT_BRAIN(Entity entity, char* scriptName, int scriptStackSize, BOOL p3)` | build 1207
Returns threadId

## _START_SCRIPT_BRAIN
`0x6F62FAE266DCFC81` | `int _START_SCRIPT_BRAIN(Entity entity, char* scriptName, int p2, Any* p3, int p4, BOOL p5)` | build 1207
Returns threadId
