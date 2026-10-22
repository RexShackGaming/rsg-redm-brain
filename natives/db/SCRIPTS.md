# SCRIPTS natives (94)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## AWARDS_GET_RESULT_ITEM
`0xAC8FAB22A914AE34` | `BOOL AWARDS_GET_RESULT_ITEM(Any* rpcGuid, Hash awardHash, int itemIndex, Any* outResultItem)` | build 1207

## BAIL_TO_LANDING_PAGE
`0xBC2C927F5C264243` | `void BAIL_TO_LANDING_PAGE(int bailCode)` | build 1207

## BAIL_WITH_PASS_THROUGH_PARAMS
`0xE98204D3C25AE14C` | `void BAIL_WITH_PASS_THROUGH_PARAMS(const char* params)` | build 1207

## BG_DOES_LAUNCH_PARAM_EXIST
`0x4AE1DFF337A86FDE` | `BOOL BG_DOES_LAUNCH_PARAM_EXIST(int scriptIndex, const char* p1)` | build 1207

## BG_END_CONTEXT
`0x3ABF7BA1C3E2C8CF` | `void BG_END_CONTEXT(const char* contextName)` | build 1207
Deletes the given context from the background scripts context map.

## BG_END_CONTEXT_HASH
`0x6D1431744182CDE8` | `void BG_END_CONTEXT_HASH(Hash contextHash)` | build 1207
Hashed version of BG_END_CONTEXT

## BG_GET_LAUNCH_PARAM_VALUE
`0x55C40B7592BAD213` | `int BG_GET_LAUNCH_PARAM_VALUE(int scriptIndex, const char* p1)` | build 1207

## BG_GET_SCRIPT_ID_FROM_NAME_HASH
`0x829CD22E043A2577` | `int BG_GET_SCRIPT_ID_FROM_NAME_HASH(Hash p0)` | build 1207

## BG_IS_EXITFLAG_SET
`0x2238EC3EC631AB1F` | `BOOL BG_IS_EXITFLAG_SET()` | build 1207
Returns true if GtaThread+0x77C is equal to 1.

Old name: _BG_EXITED_BECAUSE_BACKGROUND_THREAD_STOPPED

## BG_SET_EXITFLAG_RESPONSE
`0x4858148E3B8A75D0` | `void BG_SET_EXITFLAG_RESPONSE()` | build 1207
Sets bit 0 in GtaThread+0x784

## BG_START_CONTEXT
`0x49BA5678BA040CA7` | `void BG_START_CONTEXT(const char* contextName)` | build 1207
Inserts the given context into the background scripts context map.

## BG_START_CONTEXT_HASH
`0x2EB67D564DCC09D5` | `void BG_START_CONTEXT_HASH(Hash contextHash)` | build 1207
Hashed version of BG_START_CONTEXT

## COUNT_PARTICIPANT_BITS
`0x2F050A3FF8738245` | `int COUNT_PARTICIPANT_BITS(Any* value)` | build 1207

## COUNT_PLAYER_BITS
`0x462C687BEA254BD9` | `int COUNT_PLAYER_BITS(Any* value)` | build 1207

## DOES_SCRIPT_EXIST
`0x552B171E3F69E5AE` | `BOOL DOES_SCRIPT_EXIST(char* scriptName)` | build 1207

## DOES_SCRIPT_WITH_NAME_HASH_EXIST
`0xA34E89749F628284` | `BOOL DOES_SCRIPT_WITH_NAME_HASH_EXIST(Hash scriptHash)` | build 1207

## DOES_THREAD_EXIST
`0xFF975BC4435A0FA3` | `BOOL DOES_THREAD_EXIST(int threadId)` | build 1207

## GET_BLOCK_OF_PLAYER_BITS
`0xFA3B530A5CC693D5` | `int GET_BLOCK_OF_PLAYER_BITS(Any* value, int p1)` | build 1207

## GET_EVENT_AT_INDEX
`0xA85E614430EFF816` | `Hash GET_EVENT_AT_INDEX(int eventGroup, int eventIndex)` | build 1207
eventGroup: 0 = SCRIPT_EVENT_QUEUE_AI (CEventGroupScriptAI), 1 = SCRIPT_EVENT_QUEUE_NETWORK (CEventGroupScriptNetwork), 2 = unk, 3 = unk, 4 = SCRIPT_EVENT_QUEUE_SCRIPT_ERRORS (CEventGroupScriptErrors)

Returns event name hash: https://alloc8or.re/rdr3/doc/enums/eEventType.txt

## GET_EVENT_DATA
`0x57EC5FA4D4D6AFCA` | `BOOL GET_EVENT_DATA(int eventGroup, int eventIndex, Any* eventData, int eventDataSize)` | build 1207
eventGroup: 0 = SCRIPT_EVENT_QUEUE_AI (CEventGroupScriptAI), 1 = SCRIPT_EVENT_QUEUE_NETWORK (CEventGroupScriptNetwork), 2 = unk, 3 = unk, 4 = SCRIPT_EVENT_QUEUE_SCRIPT_ERRORS (CEventGroupScriptErrors)

Note: eventDataSize is NOT the size in bytes, it is the size determined by the SIZE_OF operator (RAGE Script operator, not C/C++ sizeof). That is, the size in bytes divided by 8 (script variables are always 8-byte aligned!).

https://github.com/femga/rdr3_discoveries/tree/master/AI/EVENTS

## GET_EVENT_EXISTS
`0xC9F59C0A710ECD34` | `BOOL GET_EVENT_EXISTS(int eventGroup, Hash eventType)` | build 1207
eventGroup: 0 = SCRIPT_EVENT_QUEUE_AI (CEventGroupScriptAI), 1 = SCRIPT_EVENT_QUEUE_NETWORK (CEventGroupScriptNetwork), 2 = unk, 3 = unk, 4 = SCRIPT_EVENT_QUEUE_SCRIPT_ERRORS (CEventGroupScriptErrors)

## GET_HASH_OF_THIS_SCRIPT_NAME
`0xBC2C927F5C264960` | `Hash GET_HASH_OF_THIS_SCRIPT_NAME()` | build 1207

## GET_ID_OF_THIS_THREAD
`0x55525C346BEF6960` | `int GET_ID_OF_THIS_THREAD()` | build 1207

## GET_NO_LOADING_SCREEN
`0x323DAF00687E0F28` | `BOOL GET_NO_LOADING_SCREEN()` | build 1207

## GET_NUMBER_OF_EVENTS
`0x5CE8DE5909565748` | `int GET_NUMBER_OF_EVENTS(int eventGroup)` | build 1207
eventGroup: 0 = SCRIPT_EVENT_QUEUE_AI (CEventGroupScriptAI), 1 = SCRIPT_EVENT_QUEUE_NETWORK (CEventGroupScriptNetwork), 2 = unk, 3 = unk, 4 = SCRIPT_EVENT_QUEUE_ERRORS (CEventGroupScriptErrors)

## GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH
`0x8E34C953364A76DD` | `int GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Hash scriptHash)` | build 1207
Gets the number of instances of the specified script is currently running.

Actually returns numRefs - 1.
if (program)
	v3 = rage::scrProgram::GetNumRefs(program) - 1;
return v3;

Old name: _GET_NUMBER_OF_REFERENCES_OF_SCRIPT_WITH_NAME_HASH

## GET_THREAD_EXISTENCE_DETAILS
`0xD92FA81B64920E85` | `void GET_THREAD_EXISTENCE_DETAILS(int threadId, BOOL* threadExists, BOOL* hasScriptHandler)` | build 1207

## HAS_SCRIPT_LOADED
`0xE97BD36574F8B0A6` | `BOOL HAS_SCRIPT_LOADED(char* scriptName)` | build 1207
Returns if a script has been loaded into the game. Used to see if a script was loaded after requesting.

## HAS_SCRIPT_WITH_NAME_HASH_LOADED
`0xA5D8E0C2F3C7EEBC` | `BOOL HAS_SCRIPT_WITH_NAME_HASH_LOADED(Hash scriptHash)` | build 1207

## HAVE_ALL_CHILD_SCRIPTS_TERMINATED
`0x380FFA15B72408FB` | `BOOL HAVE_ALL_CHILD_SCRIPTS_TERMINATED(int p0)` | build 1207
Waiting for child scripts to terminate / waiting for collapse of child scripts

## IS_LOADING_SCREEN_VISIBLE
`0xB54ADBE65D528FCB` | `BOOL IS_LOADING_SCREEN_VISIBLE()` | build 1207
Same as GET_IS_LOADING_SCREEN_ACTIVE

## IS_THREAD_ACTIVE
`0x46E9AE36D8FA6417` | `BOOL IS_THREAD_ACTIVE(int threadId, BOOL ignoreKilledState)` | build 1207

## IS_THREAD_EXIT_REQUESTED
`0x9E4EF615E307FBBE` | `BOOL IS_THREAD_EXIT_REQUESTED()` | build 1207

## REQUEST_SCRIPT
`0x46ED607DDD40D7FE` | `void REQUEST_SCRIPT(char* scriptName)` | build 1207

## REQUEST_SCRIPT_WITH_NAME_HASH
`0xF6B9CE3F8D5B9B74` | `void REQUEST_SCRIPT_WITH_NAME_HASH(Hash scriptHash)` | build 1207

## SCRIPT_THREAD_ITERATOR_GET_NEXT_THREAD_ID
`0x3CE3FB167E837D7C` | `int SCRIPT_THREAD_ITERATOR_GET_NEXT_THREAD_ID()` | build 1207
If the function returns 0, the end of the iteration has been reached.

## SCRIPT_THREAD_ITERATOR_RESET
`0x39382EB8DCD8684D` | `void SCRIPT_THREAD_ITERATOR_RESET()` | build 1207
Starts a new iteration of the current threads.
Call this first, then SCRIPT_THREAD_ITERATOR_GET_NEXT_THREAD_ID (0x30B4FA1C82DD4B9F)

## SET_BLOCK_OF_PLAYER_BITS
`0xC6DFB8C04C86D5A5` | `void SET_BLOCK_OF_PLAYER_BITS(Any* value, int p1, int p2)` | build 1207

## SET_EVENT_FLAG_FOR_DELETION
`0x4768D5252EAEB76F` | `void SET_EVENT_FLAG_FOR_DELETION(int eventGroup, int eventIndex, BOOL p2)` | build 1207

## SET_NO_LOADING_SCREEN
`0x5CB83156AA038F95` | `void SET_NO_LOADING_SCREEN(BOOL toggle)` | build 1207

## SET_SCRIPT_AS_NO_LONGER_NEEDED
`0x0086D3067E1CFD1C` | `void SET_SCRIPT_AS_NO_LONGER_NEEDED(const char* scriptName)` | build 1207

## SET_SCRIPT_WITH_NAME_HASH_AS_NO_LONGER_NEEDED
`0x50723A1567C8361E` | `void SET_SCRIPT_WITH_NAME_HASH_AS_NO_LONGER_NEEDED(Hash scriptHash)` | build 1207

## SHUTDOWN_LOADING_SCREEN
`0xFC179D7E8886DADF` | `void SHUTDOWN_LOADING_SCREEN()` | build 1207

## START_NEW_SCRIPT
`0xE81651AD79516E48` | `int START_NEW_SCRIPT(const char* scriptName, int stackSize)` | build 1207

## START_NEW_SCRIPT_WITH_ARGS
`0xB8BA7F44DF1575E1` | `int START_NEW_SCRIPT_WITH_ARGS(const char* scriptName, Any* args, int argCount, int stackSize)` | build 1207
return : script thread id, 0 if failed
Pass pointer to struct of args in p1, size of struct goes into p2

## START_NEW_SCRIPT_WITH_NAME_HASH
`0xEB1C67C3A5333A92` | `int START_NEW_SCRIPT_WITH_NAME_HASH(Hash scriptHash, int stackSize)` | build 1207

## START_NEW_SCRIPT_WITH_NAME_HASH_AND_ARGS
`0xC4BB298BD441BE78` | `int START_NEW_SCRIPT_WITH_NAME_HASH_AND_ARGS(Hash scriptHash, Any* args, int argCount, int stackSize)` | build 1207

## STOP_DISPLAYING_MP_TRANSITION_LOADING_SCREENS
`0x778D4733E0F2F265` | `void STOP_DISPLAYING_MP_TRANSITION_LOADING_SCREENS(Any p0)` | build 1207

## TERMINATE_THIS_THREAD
`0x5E8B6D17FF91CD59` | `void TERMINATE_THIS_THREAD()` | build 1207

## TERMINATE_THREAD
`0x87ED52AE40EA1A52` | `void TERMINATE_THREAD(int threadId)` | build 1207

## TRIGGER_SCRIPT_EVENT
`0x5AE99C571D5BBE5D` | `void TRIGGER_SCRIPT_EVENT(int eventGroup, Any* eventData, int eventDataSize, int scriptMetadataIndex, int* playerBits)` | build 1207
eventGroup: 0 = SCRIPT_EVENT_QUEUE_AI (CEventGroupScriptAI), 1 = SCRIPT_EVENT_QUEUE_NETWORK (CEventGroupScriptNetwork), 2 = unk, 3 = unk, 4 = SCRIPT_EVENT_QUEUE_SCRIPT_ERRORS (CEventGroupScriptErrors)

Note: eventDataSize is NOT the size in bytes, it is the size determined by the SIZE_OF operator (RAGE Script operator, not C/C++ sizeof). That is, the size in bytes divided by 8 (script variables are always 8-byte aligned!).

playerBits (also known as playersToBroadcastTo) is a bitset that indicates which players this event should be sent to. In order to send the event to specific players only, use (1 << playerIndex). Set all bits if it should be broadcast to all players.

## _0x0A79C81C418F5D38
`0x0A79C81C418F5D38` | `Any _0x0A79C81C418F5D38(Any p0, Any p1)` | build 1207

## _0x11B0A0B282FA9B10
`0x11B0A0B282FA9B10` | `void _0x11B0A0B282FA9B10(BOOL p0)` | build 1207
Used in Script Function DISABLE_REGISTERED_WORLD_BRAINS

## _0x1BDB5A07307F6929
`0x1BDB5A07307F6929` | `void _0x1BDB5A07307F6929(Any p0, Any p1)` | build 1207

## _0x1C5EB3C27F7508CB
`0x1C5EB3C27F7508CB` | `void _0x1C5EB3C27F7508CB(Any p0, Any p1)` | build 1207

## _0x29FB4CE89472C3CB
`0x29FB4CE89472C3CB` | `void _0x29FB4CE89472C3CB(Any p0, Any p1, float p2, float p3, const char* p4, const char* p5, const char* p6, int p7)` | build 1207

## _0x42A429CDFED6D99D
`0x42A429CDFED6D99D` | `void _0x42A429CDFED6D99D(Any p0, Any p1, Any p2)` | build 1207

## _0x5827BE85A87B073D
`0x5827BE85A87B073D` | `void _0x5827BE85A87B073D(Any p0)` | build 1207

## _0x64F765D9A1F8F02C
`0x64F765D9A1F8F02C` | `void _0x64F765D9A1F8F02C(Any* p0, Any* p1, Any* p2)` | build 1207

## _0x6F700A4BF7C3331B
`0x6F700A4BF7C3331B` | `void _0x6F700A4BF7C3331B(BOOL p0)` | build 1207

## _0x76CBCD9EADC00955
`0x76CBCD9EADC00955` | `void _0x76CBCD9EADC00955()` | build 1207

## _0xA88E1D7FA1E20080
`0xA88E1D7FA1E20080` | `Any _0xA88E1D7FA1E20080(Any p0)` | build 1207

## _0xE4ABE20DCE7C7CFE
`0xE4ABE20DCE7C7CFE` | `void _0xE4ABE20DCE7C7CFE(Any p0, Any p1, Any p2)` | build 1207

## _0xE7282390542F570D
`0xE7282390542F570D` | `Any _0xE7282390542F570D(Any p0)` | build 1207

## _0xF9E951A1E5517C06
`0xF9E951A1E5517C06` | `void _0xF9E951A1E5517C06()` | build 1207

## _0xFFDDF802279BE128
`0xFFDDF802279BE128` | `void _0xFFDDF802279BE128(Any p0, Any p1, Any p2)` | build 1207

## _ACTIVATE_GOAL_CONTEXT
`0x7D654266025E921B` | `void _ACTIVATE_GOAL_CONTEXT(Hash goalContext)` | build 1207
goalContext: see <availableContexts> in common/data/stats_and_challenges/goals_*.meta

## _AWARDS_GET_UNLOCK_CLAIM_DATA
`0xB9467E41DAB1CF2C` | `BOOL _AWARDS_GET_UNLOCK_CLAIM_DATA(Any* rpcGuid, Hash awardHash, int dataIndex, Any* outUnlockData)` | build 1207

## _BG_RELOAD_ALL_BACKGROUND_SCRIPTS
`0xBE7D814CFA181B56` | `void _BG_RELOAD_ALL_BACKGROUND_SCRIPTS()` | build 1207

## _CLEAR_ALL_PLAYER_BITS
`0xDE544B7EC0C187CC` | `void _CLEAR_ALL_PLAYER_BITS(Any* value)` | build 1207

## _CLEAR_PLAYER_BIT_AT_INDEX
`0xD426E2E3288469D6` | `void _CLEAR_PLAYER_BIT_AT_INDEX(Any* value, int bitIndex)` | build 1207

## _DEACTIVATE_GOAL_CONTEXT
`0x50B72A754EE64A71` | `void _DEACTIVATE_GOAL_CONTEXT(Hash goalContext)` | build 1207
goalContext: see _ACTIVATE_GOAL_CONTEXT

## _DISPLAY_LOADING_SCREENS
`0x1E5B70E53DB661E5` | `void _DISPLAY_LOADING_SCREENS(Hash p0, Hash p1, Hash p2, const char* gamemodeName, const char* title, const char* subtitle)` | build 1207

## _DOES_COMPRESSED_GLOBAL_BLOCK_BUFFER_EXIST
`0x66EE5B93C308F734` | `BOOL _DOES_COMPRESSED_GLOBAL_BLOCK_BUFFER_EXIST(int index)` | build 1207

## _GET_GLOBAL_BLOCK_CAN_BE_ACCESSED
`0x42A7EB5C814C2DE0` | `BOOL _GET_GLOBAL_BLOCK_CAN_BE_ACCESSED(int index)` | build 1207

## _GET_HASH_OF_THREAD
`0x724CB89D35B283D0` | `Hash _GET_HASH_OF_THREAD(int threadId)` | build 1207

## _GET_THREAD_EXIT_REASON
`0x54AE4FDEEFEAB77E` | `int _GET_THREAD_EXIT_REASON()` | build 1207
enum eThreadExitReason
{
	THREAD_EXIT_REASON_NONE,
	THREAD_EXIT_REASON_BACKGROUND_THREAD_STOPPED,
	THREAD_EXIT_REASON_SESSION_MERGE,
	THREAD_EXIT_REASON_SCENARIO_OUT_OF_SCOPE,
	THREAD_EXIT_REASON_REQUESTED_BY_SCRIPT
};

## _IS_ANY_PLAYER_BIT_SET
`0x179A6F0EE2E79026` | `BOOL _IS_ANY_PLAYER_BIT_SET(int* playerBits)` | build 1207

## _IS_BACKGROUND_SCRIPT
`0x20B7F69B40C6B755` | `BOOL _IS_BACKGROUND_SCRIPT(int threadId)` | build 1207

## _IS_GOAL_CONTEXT_ACTIVE
`0x7409669C5ED50144` | `BOOL _IS_GOAL_CONTEXT_ACTIVE(Hash goalContext)` | build 1207
goalContext: see _ACTIVATE_GOAL_CONTEXT

## _IS_PLAYER_BIT_SET_AT_INDEX
`0x72B2E00C9BAC6789` | `BOOL _IS_PLAYER_BIT_SET_AT_INDEX(Any* value, int bitIndex)` | build 1207

## _IS_THREAD_EXIT_REQUESTED_FOR_THREAD_WITH_THIS_ID
`0x30BED53646C86D11` | `BOOL _IS_THREAD_EXIT_REQUESTED_FOR_THREAD_WITH_THIS_ID(int threadId)` | build 1207

## _LOOT_GET_LOOT_CLAIM_DATA
`0xF1E9045F5AA9E428` | `BOOL _LOOT_GET_LOOT_CLAIM_DATA(Any* rpcGuid, int dataIndex, Any* outLootData)` | build 1311

## _LOOT_GET_RESULT_ITEM
`0x4293B44A855F82CC` | `BOOL _LOOT_GET_RESULT_ITEM(Any* rpcGuid, int itemIndex, Any* outResultItem)` | build 1207

## _NET_RPC_GUID_TO_STRING
`0xAC9FF854BD4BA9B5` | `const char* _NET_RPC_GUID_TO_STRING(Any* netRpcGuid)` | build 1311
Returns "INVALID_NET_RPC_GUID" if netRpcGuid is invalid.

## _REQUEST_THREAD_EXIT
`0x7DE4643157AD646C` | `void _REQUEST_THREAD_EXIT(int threadId)` | build 1207

## _REQUEST_THREAD_EXIT_FOR_ALL_THREADS_WITH_THIS_NAME
`0x7423F7835770F619` | `void _REQUEST_THREAD_EXIT_FOR_ALL_THREADS_WITH_THIS_NAME(Hash nameHash)` | build 1207

## _RESTORE_GLOBAL_BLOCK
`0xDC3914A99B4A5FDF` | `BOOL _RESTORE_GLOBAL_BLOCK(int index)` | build 1207

## _SET_ALL_GLOBAL_BLOCKS_HAVE_BEEN_LOADED
`0x11986B05885564D2` | `void _SET_ALL_GLOBAL_BLOCKS_HAVE_BEEN_LOADED(BOOL toggle)` | build 1207

## _SET_ALL_PLAYER_BITS
`0x20F4CB76689ACDBC` | `void _SET_ALL_PLAYER_BITS(Any* value)` | build 1207

## _SET_GLOBAL_BLOCK_CAN_BE_ACCESSED
`0xE66F392BFCE734AF` | `void _SET_GLOBAL_BLOCK_CAN_BE_ACCESSED(int index, BOOL toggle)` | build 1207

## _SET_PLAYER_BIT_AT_INDEX
`0x31010318BA9897AC` | `void _SET_PLAYER_BIT_AT_INDEX(Any* value, int bitIndex)` | build 1207

## _STORE_GLOBAL_BLOCK
`0xB952A3AC41D58F2F` | `BOOL _STORE_GLOBAL_BLOCK(int index)` | build 1207

## _TRIGGER_SCRIPT_EVENT_2
`0x8B61C950A148FFA2` | `void _TRIGGER_SCRIPT_EVENT_2(Any* eventData, int eventDataSize, int scriptMetadataIndex, int threadId)` | build 1207
