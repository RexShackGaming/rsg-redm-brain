# EVENT natives (38)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_SHOCKING_EVENT_AT_POSITION
`0xD9F8455409B525E9` | `ScrHandle ADD_SHOCKING_EVENT_AT_POSITION(Hash eventType, float x, float y, float z, float p4, float p5, float p6, float p7, float p8, int p9, int p10)` | build 1207
eventType: https://alloc8or.re/rdr3/doc/enums/eEventType.txt
https://github.com/femga/rdr3_discoveries/blob/master/AI/EVENTS

## ADD_SHOCKING_EVENT_FOR_ENTITY
`0x7FD8F3BE76F89422` | `ScrHandle ADD_SHOCKING_EVENT_FOR_ENTITY(Hash eventType, Entity entity, float p2, float p3, float p4, float p5, float p6, float p7, BOOL p8, BOOL p9, int p10, int p11)` | build 1207
eventType: https://alloc8or.re/rdr3/doc/enums/eEventType.txt

## IS_SHOCKING_EVENT_IN_SPHERE
`0x9DB47E16060D6354` | `BOOL IS_SHOCKING_EVENT_IN_SPHERE(Hash eventType, float x, float y, float z, float radius)` | build 1207
eventType: https://alloc8or.re/rdr3/doc/enums/eEventType.txt

## REMOVE_ALL_SHOCKING_EVENTS
`0xD47A168C2AB90DC4` | `void REMOVE_ALL_SHOCKING_EVENTS(BOOL p0)` | build 1207

## REMOVE_ALL_SHOCKING_EVENTS_OF_TYPE
`0x118873DD538490B4` | `void REMOVE_ALL_SHOCKING_EVENTS_OF_TYPE(Hash eventType, BOOL scriptCreatedOnly)` | build 1207
eventType: https://alloc8or.re/rdr3/doc/enums/eEventType.txt

## REMOVE_SHOCKING_EVENT
`0xE8BB3CC253A34559` | `BOOL REMOVE_SHOCKING_EVENT(ScrHandle event)` | build 1207

## REMOVE_SHOCKING_EVENT_SPAWN_BLOCKING_AREAS
`0xDB249021652420C5` | `void REMOVE_SHOCKING_EVENT_SPAWN_BLOCKING_AREAS()` | build 1207

## SET_DECISION_MAKER
`0x8AE2F981CDDB8FA4` | `void SET_DECISION_MAKER(Ped ped, Hash name)` | build 1207

## SET_DECISION_MAKER_TO_DEFAULT
`0x6B9C5C38838FB6E6` | `void SET_DECISION_MAKER_TO_DEFAULT(Ped ped)` | build 1207

## SUPPRESS_SHOCKING_EVENTS_NEXT_FRAME
`0x84994FAD4E4E4E69` | `void SUPPRESS_SHOCKING_EVENTS_NEXT_FRAME()` | build 1207

## _0x18E93EBFC1FCFA48
`0x18E93EBFC1FCFA48` | `Any _0x18E93EBFC1FCFA48(Volume volume, BOOL p1, BOOL p2)` | build 1207
Only used in R* SP Script beat_rat_infestation and homeinvasion

## _0x1A5C5D350068A673
`0x1A5C5D350068A673` | `void _0x1A5C5D350068A673(Ped ped, int p1)` | build 1207
AGGRO_CHECK_PROPERTY_DAMAGE: Property damage found with event

## _0x1D1B448D719415AB
`0x1D1B448D719415AB` | `Any _0x1D1B448D719415AB(Ped ped)` | build 1207
_GET*

## _0x26054EB81AC0893B
`0x26054EB81AC0893B` | `BOOL _0x26054EB81AC0893B(Object object)` | build 1207

## _0x2DD42FAD06E6F19E
`0x2DD42FAD06E6F19E` | `Any _0x2DD42FAD06E6F19E(Object object, BOOL p1, BOOL p2)` | build 1207

## _0x36D0F2BA2C0D9BDE
`0x36D0F2BA2C0D9BDE` | `Any _0x36D0F2BA2C0D9BDE(Entity entity, int p1)` | build 1207
_ADD* (_ADD_SHOCKING_EVENT_* ?)

## _0x4465C3D1475BD3FD
`0x4465C3D1475BD3FD` | `void _0x4465C3D1475BD3FD(Hash model)` | build 1207

## _0x4B2B1A891D437CA7
`0x4B2B1A891D437CA7` | `void _0x4B2B1A891D437CA7(float p0)` | build 1207
Only used in R* SP Script coachrobberies
_SET_S*

## _0x56B3410626A473E7
`0x56B3410626A473E7` | `void _0x56B3410626A473E7(Any p0)` | build 1207
Only used in R* SP Script beat_rat_infestation
Params: p0 = value returned by 0x18E93EBFC1FCFA48

## _0x7C511E91738A0828
`0x7C511E91738A0828` | `void _0x7C511E91738A0828(Ped ped1, Ped ped2, int p2, Hash p3)` | build 1207
Only used in R* SP Scripts
Hash only used in R* Script mob3.ysc: ROBBERY
_ADD_PED*

## _0x83D43F0FD5276E4D
`0x83D43F0FD5276E4D` | `Any _0x83D43F0FD5276E4D(Entity entity, int p1)` | build 1207
_GET*

## _0x9520175B35E2268D
`0x9520175B35E2268D` | `void _0x9520175B35E2268D(Ped ped, BOOL p1)` | build 1207
_SET_P*

## _0xA86B0EE9B39D15D6
`0xA86B0EE9B39D15D6` | `void _0xA86B0EE9B39D15D6(Object object)` | build 1207

## _0xAD17A18215DD23D6
`0xAD17A18215DD23D6` | `int _0xAD17A18215DD23D6(Entity entity, int p1, int p2)` | build 1207
Might return time since some (?) event.

## _0xB6F4825153920582
`0xB6F4825153920582` | `void _0xB6F4825153920582()` | build 1207
_S* (_SUPPRESS_EVENTS_NEXT_FRAME?)

## _0xE28D7FC9FD32ABEB
`0xE28D7FC9FD32ABEB` | `void _0xE28D7FC9FD32ABEB(Entity entity, Hash eventType, int p2)` | build 1311
HAS_ACTOR_RECEIVED_TRACKED_EVENT_THAT_SHOULD_ALERT - iTimeSinceEvent >= iTimeLimitMS

## _0xE2C2FBB7825FFC66
`0xE2C2FBB7825FFC66` | `void _0xE2C2FBB7825FFC66()` | build 1207

## _ADD_MODEL_TO_EVENT_MONITOR
`0x608AD36A644A97FE` | `void _ADD_MODEL_TO_EVENT_MONITOR(Hash model, BOOL p1, BOOL p2)` | build 1207
Models used in the scripts: P_REGISTER05X, P_REGISTER06X, P_REGISTER03X, PLAYER_ZERO, PLAYER_THREE, A_C_HORSE_MORGAN_FLAXENCHESTNUT

## _CREATE_SHOCKING_EVENT
`0xCA1315C33B9A2847` | `ScrHandle _CREATE_SHOCKING_EVENT(Any* args)` | build 1207

## _EVENT_FLUSH_ALL_EVENT_TRACKERS
`0xAD8F2424C6E1E3A8` | `void _EVENT_FLUSH_ALL_EVENT_TRACKERS(Ped ped)` | build 1207

## _EVENT_GET_RECENT_EVENT
`0x796EECFF0C6D39BE` | `Hash _EVENT_GET_RECENT_EVENT(Entity entity, int p1, int p2)` | build 1207
Returns eventType

## _EVENT_GET_SOURCE_ENTITY_FROM_EVENT
`0x822A001BCEA5BD81` | `Entity _EVENT_GET_SOURCE_ENTITY_FROM_EVENT(Entity entity, Hash eventType, int p2, int p3)` | build 1207

## _EVENT_GET_TARGET_ENTITY_FROM_EVENT
`0x38497F139981C5C9` | `Entity _EVENT_GET_TARGET_ENTITY_FROM_EVENT(Entity entity, Hash eventType, int p2, int p3)` | build 1207

## _EVENT_GET_TIME_SINCE_EVENT
`0xC6A7DC546E94FED5` | `int _EVENT_GET_TIME_SINCE_EVENT(Entity entity, Hash eventType, int p2, int p3)` | build 1207

## _IS_EVENT_TRACKER_ACTIVE
`0x797B3D4D92E56094` | `BOOL _IS_EVENT_TRACKER_ACTIVE(const char* eventName, Hash shockingEvent)` | build 1207

## _REMOVE_ALL_SHOCKING_EVENTS_IN_AREA
`0xB4C71BA9CAB097BD` | `void _REMOVE_ALL_SHOCKING_EVENTS_IN_AREA(float x, float y, float z, float radius, BOOL p4)` | build 1207

## _REMOVE_ALL_SHOCKING_EVENTS_OF_TYPE_IN_AREA
`0x6A648D42BF271DC7` | `void _REMOVE_ALL_SHOCKING_EVENTS_OF_TYPE_IN_AREA(Hash eventType, float x, float y, float z, float radius, BOOL p5)` | build 1207
eventType: https://alloc8or.re/rdr3/doc/enums/eEventType.txt

## _SET_EVENT_TRACKER_FOR_PED
`0xBB1E41DD3D3C6250` | `void _SET_EVENT_TRACKER_FOR_PED(Ped ped, const char* eventName, int p2)` | build 1207
