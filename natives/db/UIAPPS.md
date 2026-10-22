# UIAPPS natives (19)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## CAN_LAUNCH_UIAPP_BY_HASH
`0xE555EC27D65EDE80` | `BOOL CAN_LAUNCH_UIAPP_BY_HASH(Hash appNameHash)` | build 1207

## CAN_LAUNCH_UIAPP_BY_HASH_WITH_ENTRY
`0x16F47D434B6086BF` | `BOOL CAN_LAUNCH_UIAPP_BY_HASH_WITH_ENTRY(Hash appNameHash, Hash entryHash)` | build 1207

## IS_ANY_UIAPP_ACTIVE
`0xAC959AB99AAF3D9F` | `BOOL IS_ANY_UIAPP_ACTIVE()` | build 1207

## IS_ANY_UIAPP_RUNNING
`0xDB30BEC7A7A5CBD3` | `BOOL IS_ANY_UIAPP_RUNNING()` | build 1207

## IS_UIAPP_ACTIVE_BY_HASH
`0x25B7A0206BDFAC76` | `BOOL IS_UIAPP_ACTIVE_BY_HASH(Hash appNameHash)` | build 1207

## IS_UIAPP_RUNNING
`0xDE4A9B35D028979F` | `BOOL IS_UIAPP_RUNNING(char* appName)` | build 1232
Returns true if the Native UI Application is running.

## IS_UIAPP_RUNNING_BY_HASH
`0x4E511D093A86AD49` | `BOOL IS_UIAPP_RUNNING_BY_HASH(Hash appNameHash)` | build 1207
Checks to see if the specified UI app is currently running by its hash.
```lua
if IsUiappActiveByHash(`PAUSE_MENU`) then
   CloseUiappByHashImmediate(`PAUSE_MENU`)
end
```

## IS_UIAPP_TRANSITIONING_BY_HASH
`0x42095B886D30DE66` | `BOOL IS_UIAPP_TRANSITIONING_BY_HASH(Hash appNameHash)` | build 1232

## LAUNCH_UIAPP_BY_HASH
`0xC8FC7F4E4CF4F581` | `int LAUNCH_UIAPP_BY_HASH(Hash appNameHash)` | build 1207
Lauches the specified UI app by its hash.

## LAUNCH_UIAPP_BY_HASH_WITH_ENTRY
`0xC1BCF31E975B3195` | `int LAUNCH_UIAPP_BY_HASH_WITH_ENTRY(Hash appNameHash, Hash entryHash)` | build 1207

## LAUNCH_UIAPP_WITH_ENTRY
`0x7B2027BAC5C8EC89` | `int LAUNCH_UIAPP_WITH_ENTRY(char* appName, char* entry)` | build 1207

## REQUEST_UIAPP_TRANSITION_BY_HASH
`0x7689CD255655BFD7` | `BOOL REQUEST_UIAPP_TRANSITION_BY_HASH(Hash appNameHash, Hash transitionHash)` | build 1207

## _CLOSE_ALL_UIAPPS
`0xAD7B70F7230C5A12` | `void _CLOSE_ALL_UIAPPS()` | build 1207
Closes All UI Apps with transition

## _CLOSE_ALL_UIAPPS_IMMEDIATE
`0x12769EEB8DBD7A7B` | `void _CLOSE_ALL_UIAPPS_IMMEDIATE()` | build 1207
Immediately Closes all Native UI Apps

## _CLOSE_UIAPP
`0x818C6CA9B659E8EC` | `void _CLOSE_UIAPP(char* appName)` | build 1207

## _CLOSE_UIAPP_BY_HASH
`0x2FF10C9C3F92277E` | `void _CLOSE_UIAPP_BY_HASH(Hash appNameHash)` | build 1207
Closes Ui App by hash
```lua
if IsUiappActiveByHash(`abilities`) then
   CloseUiappByHash(`abilities`)
end
```

## _CLOSE_UIAPP_BY_HASH_IMMEDIATE
`0x04428420A248A354` | `void _CLOSE_UIAPP_BY_HASH_IMMEDIATE(Hash appNameHash)` | build 1207
Immediately closes the specified UI app by its hash.

## _CLOSE_UIAPP_IMMEDIATE
`0x3015635426D1B17C` | `void _CLOSE_UIAPP_IMMEDIATE(char* appName)` | build 1207

## _GET_UIAPP_CURRENT_ACTIVITY_BY_HASH
`0x96FD694FE5BE55DC` | `Hash _GET_UIAPP_CURRENT_ACTIVITY_BY_HASH(Hash appNameHash)` | build 1207
