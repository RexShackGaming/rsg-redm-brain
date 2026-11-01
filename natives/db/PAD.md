# PAD natives (40)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## CLEAR_CONTROL_LIGHT_EFFECT
`0xCB0360EFEFB2580D` | `void CLEAR_CONTROL_LIGHT_EFFECT(int control)` | build 1207
nullsub, doesn't do anything

## CLEAR_CONTROL_SHAKE_SUPPRESSED_ID
`0xA0CEFCEA390AAB9B` | `void CLEAR_CONTROL_SHAKE_SUPPRESSED_ID(int control)` | build 1207
Old name: _CLEAR_SUPPRESSED_PAD_RUMBLE

## DISABLE_ALL_CONTROL_ACTIONS
`0x5F4B6931816E599B` | `void DISABLE_ALL_CONTROL_ACTIONS(int control)` | build 1207

## DISABLE_CONTROL_ACTION
`0xFE99B66D079CF6BC` | `void DISABLE_CONTROL_ACTION(int control, Hash action, BOOL disableRelatedActions)` | build 1207

## ENABLE_CONTROL_ACTION
`0x351220255D64C155` | `void ENABLE_CONTROL_ACTION(int control, Hash action, BOOL enableRelatedActions)` | build 1207

## GET_CONTROL_HOW_LONG_AGO
`0xD7D22F5592AED8BA` | `int GET_CONTROL_HOW_LONG_AGO(int control)` | build 1207
Returns time in ms since last input.

## GET_CONTROL_NORMAL
`0xEC3C9B8D5327B563` | `float GET_CONTROL_NORMAL(int control, Hash action)` | build 1207

## GET_CONTROL_UNBOUND_NORMAL
`0x5B84D09CEC5209C5` | `float GET_CONTROL_UNBOUND_NORMAL(int control, Hash action)` | build 1207

## GET_CONTROL_VALUE
`0xD95E79E8686D2C27` | `int GET_CONTROL_VALUE(int control, Hash action)` | build 1207

## GET_DISABLED_CONTROL_NORMAL
`0x11E65974A982637C` | `float GET_DISABLED_CONTROL_NORMAL(int control, Hash action)` | build 1207

## GET_DISABLED_CONTROL_UNBOUND_NORMAL
`0x4F8A26A890FD62FB` | `float GET_DISABLED_CONTROL_UNBOUND_NORMAL(int control, Hash action)` | build 1207

## HAVE_CONTROLS_CHANGED
`0x6CD79468A1E595C6` | `BOOL HAVE_CONTROLS_CHANGED(int control)` | build 1207

## IS_CONTROL_ENABLED
`0x1CEA6BFDF248E5D9` | `BOOL IS_CONTROL_ENABLED(int control, Hash action)` | build 1207

## IS_CONTROL_JUST_PRESSED
`0x580417101DDB492F` | `BOOL IS_CONTROL_JUST_PRESSED(int control, Hash action)` | build 1207

## IS_CONTROL_JUST_RELEASED
`0x50F940259D3841E6` | `BOOL IS_CONTROL_JUST_RELEASED(int control, Hash action)` | build 1207

## IS_CONTROL_PRESSED
`0xF3A21BCD95725A4A` | `BOOL IS_CONTROL_PRESSED(int control, Hash action)` | build 1207

## IS_CONTROL_RELEASED
`0x648EE3E7F38877DD` | `BOOL IS_CONTROL_RELEASED(int control, Hash action)` | build 1207

## IS_DISABLED_CONTROL_JUST_PRESSED
`0x91AEF906BCA88877` | `BOOL IS_DISABLED_CONTROL_JUST_PRESSED(int control, Hash action)` | build 1207

## IS_DISABLED_CONTROL_JUST_RELEASED
`0x305C8DCD79DA8B0F` | `BOOL IS_DISABLED_CONTROL_JUST_RELEASED(int control, Hash action)` | build 1207

## IS_DISABLED_CONTROL_PRESSED
`0xE2587F8CBBD87B1D` | `BOOL IS_DISABLED_CONTROL_PRESSED(int control, Hash action)` | build 1207

## IS_LOOK_INVERTED
`0x77B612531280010D` | `BOOL IS_LOOK_INVERTED()` | build 1207

## IS_USING_KEYBOARD_AND_MOUSE
`0xA571D46727E2B718` | `BOOL IS_USING_KEYBOARD_AND_MOUSE(int control)` | build 1207
padIndex is not used

Old name: _IS_USING_KEYBOARD

## SET_CONTROL_LIGHT_EFFECT_COLOR
`0x8290252FFF36ACB5` | `void SET_CONTROL_LIGHT_EFFECT_COLOR(int control, int red, int green, int blue)` | build 1207
nullsub, doesn't do anything

Old name: _SET_CONTROL_GROUP_COLOR

## SET_CONTROL_LIGHT_EFFECT_FLASHING_COLOR
`0xA45884DB10EC7EE3` | `void SET_CONTROL_LIGHT_EFFECT_FLASHING_COLOR(int control, int red, int green, int blue)` | build 1207
nullsub, doesn't do anything

## SET_CONTROL_SHAKE
`0x48B3886C1358D0D5` | `void SET_CONTROL_SHAKE(int control, int duration, int frequency)` | build 1207
Old name: SET_PAD_SHAKE

## SET_CONTROL_SHAKE_SUPPRESSED_ID
`0xF239400E16C23E08` | `void SET_CONTROL_SHAKE_SUPPRESSED_ID(int control, int uniqueId)` | build 1207
Old name: SET_PAD_SHAKE_SUPPRESSED_ID

## SET_CONTROL_TRIGGER_SHAKE
`0x14D29BB12D47F68C` | `void SET_CONTROL_TRIGGER_SHAKE(int control, int leftDuration, int leftFrequency, int rightDuration, int rightFrequency)` | build 1207
nullsub, doesn't do anything

## SET_CONTROL_VALUE_NEXT_FRAME
`0xE8A25867FBA3B05E` | `BOOL SET_CONTROL_VALUE_NEXT_FRAME(int control, Hash action, float value)` | build 1207
This is for simulating player input.
value is a float value from 0 - 1

control: see IS_CONTROL_ENABLED

Old name: _SET_CONTROL_NORMAL

## SET_INPUT_EXCLUSIVE
`0xEDE476E5EE29EDB1` | `void SET_INPUT_EXCLUSIVE(int control, Hash action)` | build 1207

## STOP_CONTROL_SHAKE
`0x38C16A305E8CDC8D` | `void STOP_CONTROL_SHAKE(int control)` | build 1207
Old name: STOP_PAD_SHAKE

## _0x1252C029FC8EBB4D
`0x1252C029FC8EBB4D` | `BOOL _0x1252C029FC8EBB4D()` | build 1207
_IS_R* - _IS_S*

## _0x43F35DDB2905D945
`0x43F35DDB2905D945` | `Any _0x43F35DDB2905D945(Any p0, Any p1)` | build 1207

## _0x52C68E92D6E23ADD
`0x52C68E92D6E23ADD` | `void _0x52C68E92D6E23ADD(Any p0)` | build 1311

## _0x5F217BC1190503D8
`0x5F217BC1190503D8` | `void _0x5F217BC1190503D8(char* rumbleCurve, float p1)` | build 1207
rumbleCurve: common_0/data/rumblecurves.meta

## _0x709BA8C08C5C008D
`0x709BA8C08C5C008D` | `void _0x709BA8C08C5C008D()` | build 1207

## _0xBD629C1C4F501C80
`0xBD629C1C4F501C80` | `Any _0xBD629C1C4F501C80(Any p0)` | build 1207

## _GET_CURRENT_CONTROL_CONTEXT
`0xDDCEB0F26C89C00F` | `Hash _GET_CURRENT_CONTROL_CONTEXT(int control)` | build 1207
Gets the current control context. See: _SET_CONTROL_CONTEXT

## _GET_DISABLED_CONTROL_HOW_LONG_AGO
`0x771DFCB24D19C2F6` | `int _GET_DISABLED_CONTROL_HOW_LONG_AGO(int control)` | build 1207

## _IS_CONTROL_ACTION_VALID
`0xBC0884BC590951C7` | `BOOL _IS_CONTROL_ACTION_VALID(Hash action, int control)` | build 1207

## _SET_CONTROL_CONTEXT
`0x2804658EB7D8A50B` | `void _SET_CONTROL_CONTEXT(int control, Hash context)` | build 1207
Sets the current control context. Must be called every frame.

context: https://alloc8or.re/rdr3/doc/misc/input_contexts.txt
For more information, see common:/data/control/settings.meta
https://github.com/femga/rdr3_discoveries/tree/master/Controls
