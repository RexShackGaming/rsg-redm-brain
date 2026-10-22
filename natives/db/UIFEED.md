# UIFEED natives (27)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## UI_FEED_CLEAR_CHANNEL
`0xDD1232B332CBB9E7` | `void UI_FEED_CLEAR_CHANNEL(int feedChannel, BOOL p1, BOOL p2)` | build 1207
feedChannel: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eUIFeedChannel

## UI_FEED_GET_CURRENT_MESSAGE
`0xC17F69E1418CD11F` | `int UI_FEED_GET_CURRENT_MESSAGE(int feedChannel)` | build 1207
feedChannel: see UI_FEED_CLEAR_CHANNEL
Returns feedMessage

## _0x0FD07141AD048AAE
`0x0FD07141AD048AAE` | `int _0x0FD07141AD048AAE(Any* p0, BOOL p1)` | build 1207
Only used in R* SP Script beat_animal_attack
Returns feedMessage

## _0x4E88A65968A55C78
`0x4E88A65968A55C78` | `int _0x4E88A65968A55C78(Any* p0, BOOL p1)` | build 1207
Returns feedMessage

## _0x6D85126F6CCF02C9
`0x6D85126F6CCF02C9` | `void _0x6D85126F6CCF02C9(int feedChannel, int p1, BOOL p2)` | build 1207

## _0xB7223B91CD6B7E07
`0xB7223B91CD6B7E07` | `BOOL _0xB7223B91CD6B7E07(int feedChannel)` | build 1207

## _UI_FEED_CLEAR_ALL_CHANNELS
`0x6035E8FBCA32AC5E` | `void _UI_FEED_CLEAR_ALL_CHANNELS()` | build 1207
Hides Toast Notifications

## _UI_FEED_CLEAR_HELP_TEXT_FEED
`0x2F901291EF177B02` | `void _UI_FEED_CLEAR_HELP_TEXT_FEED(int feedMessage, BOOL p1)` | build 1207
Clears help text

## _UI_FEED_GET_MESSAGE_STATE
`0x59FA676177DBE4C9` | `int _UI_FEED_GET_MESSAGE_STATE(int feedMessage)` | build 1207
Returns messageState, see https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eUIMessageState

## _UI_FEED_POST_COLLECTOR_TOAST
`0xAFF5BE9BA496CE40` | `int _UI_FEED_POST_COLLECTOR_TOAST(Any* p0, Any* p1, BOOL p2, BOOL p3, Hash collectableCategory)` | build 1207
notification you need dataview

## _UI_FEED_POST_FEED_TICKER
`0xB2920B9760F0F36B` | `int _UI_FEED_POST_FEED_TICKER(Any* p0, Any* p1, BOOL p2)` | build 1207
Display text on right of the screen, Example : https://pastebin.com/n1YmNe25

## _UI_FEED_POST_GAME_UPDATE_SHARD
`0x8D1249BD28791878` | `int _UI_FEED_POST_GAME_UPDATE_SHARD(Any* p0, Any* p1, BOOL p2)` | build 1207

## _UI_FEED_POST_HELP_TEXT
`0x049D5C615BD38BAD` | `int _UI_FEED_POST_HELP_TEXT(Any* p0, Any* p1, BOOL p2)` | build 1207
Example : https://pastebin.com/GvdBp8Dh

## _UI_FEED_POST_INTERACTIVE_TOAST
`0x18D6869FBFFEC0F8` | `int _UI_FEED_POST_INTERACTIVE_TOAST(Any* p0, Any* p1, BOOL p2, BOOL p3)` | build 1207
notification you need dataview

## _UI_FEED_POST_LOCATION_SHARD
`0xD05590C1AB38F068` | `int _UI_FEED_POST_LOCATION_SHARD(Any* duration, Any* data, BOOL p2, BOOL p3)` | build 1207
Example : https://pastebin.com/h1YzycuR

## _UI_FEED_POST_MISSION_NAME
`0x2024F4F333095FB1` | `int _UI_FEED_POST_MISSION_NAME(Any* p0, Any* p1, BOOL p2)` | build 1207

## _UI_FEED_POST_OBJECTIVE
`0xCEDBF17EFCC0E4A4` | `int _UI_FEED_POST_OBJECTIVE(Any* p0, Any* p1, BOOL p2)` | build 1207
Example : https://pastebin.com/13tuRa63

## _UI_FEED_POST_ONE_TEXT_SHARD
`0x860DDFE97CC94DF0` | `int _UI_FEED_POST_ONE_TEXT_SHARD(Any* p0, Any* p1, BOOL p2)` | build 1207

## _UI_FEED_POST_RANKUP_TOAST
`0x3F9FDDBA79117C69` | `int _UI_FEED_POST_RANKUP_TOAST(Any* p0, Any* p1, int p2, int p3)` | build 1207

## _UI_FEED_POST_RETICLE_MESSAGE
`0x893128CDB4B81FBB` | `int _UI_FEED_POST_RETICLE_MESSAGE(Any* p0, Any* p1, BOOL p2)` | build 1207

## _UI_FEED_POST_SAMPLE_NOTIFICATION
`0xC927890AA64E9661` | `int _UI_FEED_POST_SAMPLE_NOTIFICATION(Any* p0, Any* p1, int p2, int p3)` | build 1207
Example : https://pastebin.com/kAtEMQTD

## _UI_FEED_POST_SAMPLE_TOAST
`0x26E87218390E6729` | `int _UI_FEED_POST_SAMPLE_TOAST(Any* p0, Any* p1, BOOL p2, BOOL p3)` | build 1207
Example : https://pastebin.com/YZMBkAmW

## _UI_FEED_POST_SAMPLE_TOAST_RIGHT
`0xB249EBCB30DD88E0` | `int _UI_FEED_POST_SAMPLE_TOAST_RIGHT(Any* p0, Any* p1, BOOL p2)` | build 1207

## _UI_FEED_POST_SAMPLE_TOAST_WITH_APP_LINK
`0x38838A646FB30AAE` | `int _UI_FEED_POST_SAMPLE_TOAST_WITH_APP_LINK(Any* p0, Any* p1, BOOL p2, BOOL p3, BOOL p4)` | build 1311

## _UI_FEED_POST_THREE_TEXT_SHARD
`0x02BCC0FE9EBA3529` | `int _UI_FEED_POST_THREE_TEXT_SHARD(Any* p0, Any* p1, BOOL p2, BOOL p3, BOOL p4)` | build 1207

## _UI_FEED_POST_TWO_TEXT_SHARD
`0xA6F4216AB10EB08E` | `int _UI_FEED_POST_TWO_TEXT_SHARD(Any* p0, Any* p1, BOOL p2, BOOL p3)` | build 1207

## _UI_FEED_POST_VOICE_CHAT_FEED
`0xC48152BC6B3E821C` | `int _UI_FEED_POST_VOICE_CHAT_FEED(Any* p0, Any* p1, BOOL p2)` | build 1207
