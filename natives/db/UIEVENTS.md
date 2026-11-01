# UIEVENTS natives (4)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## EVENTS_UI_GET_MESSAGE
`0xE24E957294241444` | `BOOL EVENTS_UI_GET_MESSAGE(Hash hash, Any* eventData)` | build 1207
eventData:
struct UI_SCRIPT_EVENT
{
	alignas(8) eUIScriptEventType eventType; // https://alloc8or.re/rdr3/doc/enums/eUIScriptEventType.txt
	alignas(8) int intParam;
	alignas(8) Hash hashParam;
	alignas(8) Hash datastoreParam;
};

Old name: _EVENT_MANAGER_GET_EVENT

## EVENTS_UI_IS_PENDING
`0x67ED5A7963F2F722` | `BOOL EVENTS_UI_IS_PENDING(Hash hash)` | build 1207
Old name: _EVENT_MANAGER_IS_EVENT_PENDING

## EVENTS_UI_PEEK_MESSAGE
`0x90237103F27F7937` | `BOOL EVENTS_UI_PEEK_MESSAGE(Hash hash, Any* eventData)` | build 1207
eventData: see EVENTS_UI_GET_MESSAGE

Old name: _EVENT_MANAGER_PEEK_EVENT

## EVENTS_UI_POP_MESSAGE
`0x8E8A2369F48EC839` | `void EVENTS_UI_POP_MESSAGE(Hash hash)` | build 1207
Old name: _EVENT_MANAGER_POP_EVENT
