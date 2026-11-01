# INTERACTION natives (6)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## SET_MOUSE_CURSOR_STYLE
`0x7F5858AAB5A58CCE` | `void SET_MOUSE_CURSOR_STYLE(int spriteId)` | build 1207
Changes the mouse cursor's sprite.

spriteId's: https://github.com/femga/rdr3_discoveries/tree/master/graphics/HUD/cursor_sprites#readme

Old name: _SET_MOUSE_CURSOR_SPRITE

## SET_MOUSE_CURSOR_THIS_FRAME
`0xF12E4CCAF249DC10` | `void SET_MOUSE_CURSOR_THIS_FRAME()` | build 1207
Shows the cursor on screen for one frame.

Old name: _SET_MOUSE_CURSOR_ACTIVE_THIS_FRAME

## _POINTER_IS_BEING_MOVED
`0x2B8B605F2A9E64BF` | `BOOL _POINTER_IS_BEING_MOVED()` | build 1311
Returns true if player is moving mouse while cursor is active
_PI* - _PO*

## _POINTER_IS_LEFT_BUTTON_HELD
`0x61CAE9D1FD055E44` | `BOOL _POINTER_IS_LEFT_BUTTON_HELD()` | build 1207
Returns true if player is holding LMB while cursor is active
_PI* - _PO*

## _POINTER_IS_LEFT_BUTTON_JUST_RELEASED
`0xF7F51A57349739F2` | `BOOL _POINTER_IS_LEFT_BUTTON_JUST_RELEASED()` | build 1207
Returns true if player releases LMB if cursor is active
_PI* - _PO*

## _SET_ALLOW_FIRST_PERSON_MOUSE_CAMERA_MOVEMENT
`0x0546B117BB17548B` | `void _SET_ALLOW_FIRST_PERSON_MOUSE_CAMERA_MOVEMENT()` | build 1232
Allows camera to be moved if middle mouse button is held while in first person
Must be called every frame
_SET*
