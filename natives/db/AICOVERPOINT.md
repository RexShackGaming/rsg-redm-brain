# AICOVERPOINT natives (17)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## TASK_ENTER_COVER
`0x4972A022AE6DAFA1` | `void TASK_ENTER_COVER(Ped ped)` | build 1207

## TASK_EXIT_COVER
`0x2BC4A6D92D140112` | `void TASK_EXIT_COVER(Ped ped)` | build 1207

## _0x3C7A9C2C953128FE
`0x3C7A9C2C953128FE` | `void _0x3C7A9C2C953128FE(Ped ped)` | build 1207

## _0x53E4D0C079CA6855
`0x53E4D0C079CA6855` | `Entity _0x53E4D0C079CA6855(ScrHandle handle)` | build 1207

## _0xEBA51A294C73292E
`0xEBA51A294C73292E` | `void _0xEBA51A294C73292E(Any* args)` | build 1207

## _ACTIVATE_COVER_LAYER
`0x64340DC208D671D5` | `void _ACTIVATE_COVER_LAYER(char* coverLayer)` | build 1207
activates a cover layer, these seem to be for specifc scenes in SP for example where a table is flipped using "grand_korr_poker_table_flipped" see more in levels\rdr3\coverlayers.rpf

## _ADD_COVER_BLOCKING_AREA
`0x733077295AB51304` | `void _ADD_COVER_BLOCKING_AREA(Any* args)` | build 1207
args: f_0 = Volume Handle
f_1 = integer (?) (only the number 1 is ever used here, or is not used at all)
f_2 = integer (-1 to 32 in R* Scripts)

## _ADD_SCRIPTED_COVER_POINT
`0x975BD6351648935F` | `ScrHandle _ADD_SCRIPTED_COVER_POINT(Any* data)` | build 1207

## _ARE_LOAD_COVER_ANIMS_LOADED
`0x8CBE916CFC64AD5C` | `BOOL _ARE_LOAD_COVER_ANIMS_LOADED(Ped ped)` | build 1207

## _DEACTIVATE_COVER_LAYER
`0x7A1FDCF35EAA140F` | `void _DEACTIVATE_COVER_LAYER(char* coverLayer)` | build 1207
deactivates a cover layer activated with 0x64340DC208D671D5 coverLayer: see levels_0/levels/rdr3/coverlayers

## _DOES_COVER_POINT_EXIST
`0xC276FE69DDA22BAD` | `BOOL _DOES_COVER_POINT_EXIST(ScrHandle handle)` | build 1207

## _GET_COVER_POINT_STATE_FROM_PED
`0x5F5B1B7E8E8F94C6` | `int _GET_COVER_POINT_STATE_FROM_PED(Ped ped)` | build 1207
1 = In cover while crouched
2 = In cover while standing
3 = Not in cover

## _GET_PED_COVER_POINT_TRANSITION_STATE
`0x957D7E750216D74B` | `int _GET_PED_COVER_POINT_TRANSITION_STATE(Ped ped)` | build 1207
returns the active transition state of a cover point for about 2 seconds unless its peeking
 1 - transition from pointing a gun to not pointing a gun
2 - transition to pointing a gun
3 - broke the window 
4 - when opening a door while in cover (a prompt will show and once pressed state is changed to 4)
5 - cover transition like from one corner of a house to the other corner
6 - changing cover to cover like crossing from one side of the door to the other
7 - when the ped is facing foward with the camera, might be to detect when going from left to right
8 - when the ped is peeking through a door window etc (this will return 8 while is in peek)
9 - when a ped is aiming in crouch and enters cover (it doesnt always trigger)
10 - enters cover
12 - leaves cover
16 - changed to crouch or to standing up position

## _GET_PED_FROM_COVER_POINT
`0x140B3CB1D424A945` | `Ped _GET_PED_FROM_COVER_POINT(ScrHandle coverpoint)` | build 1207
returns the ped that is using this cover point created by ADD_COVER_POINT and adding the ped using tasks like `TASK_PUT_PED_DIRECTLY_(*`

## _REQUEST_FLINCH_COVER_ANIM
`0x2A31D13C5F021D0D` | `void _REQUEST_FLINCH_COVER_ANIM(Ped ped)` | build 1207
Makes ped flinch (if in cover) like they have been shot at

## _STOP_RUNNING_COVER_ANIMS
`0x1A7A802B2301EDC0` | `void _STOP_RUNNING_COVER_ANIMS(Ped ped)` | build 1207
Stops running cover anims and releases them
_STOP_RENDERING_* - _STOP_SCRIPTED*

## _TASK_AI_SEEK_COVER_TO_COVER_POINT
`0x89783FDDF079C88D` | `void _TASK_AI_SEEK_COVER_TO_COVER_POINT(Any* args)` | build 1207
