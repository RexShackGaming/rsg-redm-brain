# GRAPHICS natives (267)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_DECAL
`0x57CB267624EF85C0` | `int ADD_DECAL(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6, Any p7, Any p8, Any p9, Any p10, Any p11, Any p12, Any p13, Any p14, Any p15, Any p16, Any p17, Any p18, Any p19, Any p20, Any p21)` | build 1207

## ADD_PETROL_TRAIL_DECAL_INFO
`0x73354FB6D03D2E8A` | `void ADD_PETROL_TRAIL_DECAL_INFO(float x, float y, float z, float p3)` | build 1207

## ADD_VEG_MODIFIER_SPHERE
`0xFA50F79257745E74` | `int ADD_VEG_MODIFIER_SPHERE(float x, float y, float z, float radius, int modType, int flags, int p6)` | build 1207
Returns veg modifier handle

## ALLOW_PICKUP_LIGHT_SYNC
`0x7C348310A6E2FB91` | `void ALLOW_PICKUP_LIGHT_SYNC(Object pickupObject, BOOL allow)` | build 1207

## ANIMPOSTFX_HAS_EVENT_TRIGGERED_BY_STACKHASH
`0x9AB192A9EF980EED` | `BOOL ANIMPOSTFX_HAS_EVENT_TRIGGERED_BY_STACKHASH(Hash effectNameHash, int eventType, BOOL peekOnly, BOOL* isRegistered)` | build 1207

## ANIMPOSTFX_IS_PRELOADING_BY_STACKHASH
`0x59EA80079B86D8C7` | `BOOL ANIMPOSTFX_IS_PRELOADING_BY_STACKHASH(Hash effectNameHash)` | build 1207

## ANIMPOSTFX_IS_RUNNING
`0x4A123E85D7C4CA0B` | `BOOL ANIMPOSTFX_IS_RUNNING(const char* effectName)` | build 1207

## ANIMPOSTFX_PLAY
`0x4102732DF6B4005F` | `void ANIMPOSTFX_PLAY(const char* effectName)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/graphics/animpostfx

## ANIMPOSTFX_STOP
`0xB4FD7446BAB2F394` | `void ANIMPOSTFX_STOP(const char* effectName)` | build 1207

## ANIMPOSTFX_STOP_ALL
`0x66560A0D4C64FD21` | `void ANIMPOSTFX_STOP_ALL()` | build 1207

## ATTACH_TV_AUDIO_TO_ENTITY
`0x40866A418EB8EFDE` | `void ATTACH_TV_AUDIO_TO_ENTITY(Entity entity)` | build 1207

## BEGIN_CREATE_LOW_QUALITY_COPY_OF_PHOTO
`0x494A9874F17A7D50` | `BOOL BEGIN_CREATE_LOW_QUALITY_COPY_OF_PHOTO(int p0)` | build 1207
Called together with FREE_MEMORY_FOR_LOW_QUALITY_PHOTO

## BEGIN_TAKE_HIGH_QUALITY_PHOTO
`0xA15BFFC0A01B34E1` | `BOOL BEGIN_TAKE_HIGH_QUALITY_PHOTO()` | build 1207

## BLOCK_PICKUP_PLACEMENT_LIGHT
`0x0552AA3FFC5B87AA` | `void BLOCK_PICKUP_PLACEMENT_LIGHT(Pickup pickup, BOOL toggle)` | build 1207

## CASCADE_SHADOWS_CLEAR_SHADOW_SAMPLE_TYPE
`0xF7C29D7C12C36F03` | `void CASCADE_SHADOWS_CLEAR_SHADOW_SAMPLE_TYPE()` | build 1207

## CASCADE_SHADOWS_ENABLE_ENTITY_TRACKER
`0x8FBFD2AEB196B369` | `void CASCADE_SHADOWS_ENABLE_ENTITY_TRACKER(BOOL toggle)` | build 1207
When this is set to ON, shadows only draw as you get nearer.

When OFF, they draw from a further distance.

## CASCADE_SHADOWS_SET_CASCADE_BOUNDS
`0xD9EDB2E4512D563E` | `void CASCADE_SHADOWS_SET_CASCADE_BOUNDS(Any p0, BOOL p1, float p2, float p3, float p4, float p5, BOOL p6, float p7)` | build 1207

## CASCADE_SHADOWS_SET_SHADOW_SAMPLE_TYPE
`0xCE4774E0F9AD48D1` | `void CASCADE_SHADOWS_SET_SHADOW_SAMPLE_TYPE(const char* type)` | build 1207
Possible values:
"CSM_ST_POINT"
"CSM_ST_LINEAR"
"CSM_ST_BOX3x3"
"CSM_ST_BOX4x4"
"CSM_ST_DITHER2_LINEAR"
"CSM_ST_CUBIC"
"CSM_ST_POISSON16"
"CSM_ST_SOFT8"
"CSM_ST_SOFT16"
"CSM_ST_SOFT32"
"CSM_ST_DITHER16_RPDB"
"CSM_ST_POISSON16_RPDB_GNORM"
"CSM_ST_HIGHRES_BOX4x4"
"CSM_ST_ESM"

## CLEAR_TIMECYCLE_MODIFIER
`0x0E3F4AF2D63491FB` | `void CLEAR_TIMECYCLE_MODIFIER()` | build 1207

## CREATE_CHECKPOINT_WITH_NAMEHASH
`0x175668836B44CBB0` | `int CREATE_CHECKPOINT_WITH_NAMEHASH(Hash typeHash, float posX1, float posY1, float posZ1, float posX2, float posY2, float posZ2, float radius, int red, int green, int blue, int alpha, int reserved)` | build 1207

## CREATE_TRACKED_POINT
`0xFB405CB357C69CB9` | `int CREATE_TRACKED_POINT()` | build 1207
Creates a tracked point, useful for checking the visibility of a 3D point on screen.

## DELETE_CHECKPOINT
`0x0DED5B0C8EBAAE12` | `void DELETE_CHECKPOINT(int checkpoint)` | build 1207

## DESTROY_TRACKED_POINT
`0x37A59922109F8F1C` | `void DESTROY_TRACKED_POINT(int point)` | build 1207

## DISABLE_ENTITYMASK
`0x5C9978A2A3DC3D0D` | `void DISABLE_ENTITYMASK()` | build 1207

## DISABLE_HDTEX_THIS_FRAME
`0x98A7CD5EA379A854` | `void DISABLE_HDTEX_THIS_FRAME()` | build 1207

## DOES_PARTICLE_FX_LOOPED_EXIST
`0x9DD5AFF561E88F2A` | `BOOL DOES_PARTICLE_FX_LOOPED_EXIST(int ptfxHandle)` | build 1207

## DRAW_LIGHT_WITH_RANGE
`0xD2D9E04C0DF927F4` | `void DRAW_LIGHT_WITH_RANGE(float posX, float posY, float posZ, int colorR, int colorG, int colorB, float range, float intensity)` | build 1207

## DRAW_LOW_QUALITY_PHOTO_TO_PHONE
`0xF1142E5D64B47802` | `void DRAW_LOW_QUALITY_PHOTO_TO_PHONE(BOOL p0, int photoRotation)` | build 1207
nullsub, doesn't do anything (GTA5 leftover, there is no phone in RDR3)

## DRAW_MARKER
`0x2A32FAA57B937173` | `void DRAW_MARKER(Hash type, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, float rotX, float rotY, float rotZ, float scaleX, float scaleY, float scaleZ, int red, int green, int blue, int alpha, BOOL bobUpAndDown, BOOL faceCamera, int p19, BOOL rotate, const char* textureDict, const char* textureName, BOOL drawOnEnts)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/graphics/markers/marker_types.lua
Old name: _DRAW_MARKER

## DRAW_RECT
`0x405224591DF02025` | `void DRAW_RECT(float x, float y, float width, float height, int red, int green, int blue, int alpha, BOOL p8, BOOL p9)` | build 1207
Draws a rectangle on the screen.

-x: The relative X point of the center of the rectangle. (0.0-1.0, 0.0 is the left edge of the screen, 1.0 is the right edge of the screen)

-y: The relative Y point of the center of the rectangle. (0.0-1.0, 0.0 is the top edge of the screen, 1.0 is the bottom edge of the screen)

-width: The relative width of the rectangle. (0.0-1.0, 1.0 means the whole screen width)

-height: The relative height of the rectangle. (0.0-1.0, 1.0 means the whole screen height)

-R: Red part of the color. (0-255)

-G: Green part of the color. (0-255)

-B: Blue part of the color. (0-255)

-A: Alpha part of the color. (0-255, 0 means totally transparent, 255 means totally opaque)

## DRAW_SPRITE
`0xC9884ECADE94CB34` | `void DRAW_SPRITE(const char* textureDict, const char* textureName, float screenX, float screenY, float width, float height, float heading, int red, int green, int blue, int alpha, BOOL p11)` | build 1207
Draws a 2D sprite on the screen.

Parameters:
textureDict - Name of texture dictionary to load texture from

textureName - Name of texture to load from texture dictionary

screenX/Y - Screen offset (0.5 = center)
scaleX/Y - Texture scaling. Negative values can be used to flip the texture on that axis. (0.5 = half)

heading - Texture rotation in degrees (default = 0.0) positive is clockwise, measured in degrees

red,green,blue - Sprite color (default = 255/255/255)

alpha - opacity level

https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/textures

## DRAW_TV_CHANNEL
`0xC0A145540254A840` | `void DRAW_TV_CHANNEL(float xPos, float yPos, float xScale, float yScale, float rotation, int red, int green, int blue, int alpha)` | build 1207

## ENABLE_ENTITYMASK
`0xFAAD23DE7A54FC14` | `void ENABLE_ENTITYMASK()` | build 1207

## ENABLE_MOON_CYCLE_OVERRIDE
`0x6FE93BCC7BF12B63` | `void ENABLE_MOON_CYCLE_OVERRIDE(float strength)` | build 1207
Old name: _ENABLE_EXTRA_TIMECYCLE_MODIFIER_STRENGTH

## ENABLE_MOVIE_SUBTITLES
`0x6FC9B065229C0787` | `void ENABLE_MOVIE_SUBTITLES(BOOL toggle)` | build 1207
nullsub, doesn't do anything

## END_PETROL_TRAIL_DECALS
`0x0E126AAE933F3B56` | `void END_PETROL_TRAIL_DECALS()` | build 1207

## FREE_MEMORY_FOR_HIGH_QUALITY_PHOTO
`0xD45547D8396F002A` | `void FREE_MEMORY_FOR_HIGH_QUALITY_PHOTO()` | build 1207

## FREE_MEMORY_FOR_LOW_QUALITY_PHOTO
`0x614682E715ADBAAC` | `void FREE_MEMORY_FOR_LOW_QUALITY_PHOTO()` | build 1207

## FREE_MEMORY_FOR_MISSION_CREATOR_PHOTO
`0x7DFF8F94937D2659` | `void FREE_MEMORY_FOR_MISSION_CREATOR_PHOTO()` | build 1207

## GET_SCREEN_COORD_FROM_WORLD_COORD
`0xCB50D7AFCC8B0EC6` | `BOOL GET_SCREEN_COORD_FROM_WORLD_COORD(float worldX, float worldY, float worldZ, float* screenX, float* screenY)` | build 1207

## GET_SCREEN_RESOLUTION
`0x66773C92835D0909` | `void GET_SCREEN_RESOLUTION(int* x, int* y)` | build 1207
Hardcoded to always set x to 1280 and y to 720.

## GET_STATUS_OF_CREATE_LOW_QUALITY_COPY_OF_PHOTO
`0x13430D3D5A45F14B` | `int GET_STATUS_OF_CREATE_LOW_QUALITY_COPY_OF_PHOTO(Any p0)` | build 1207
Old name: _GET_STATUS_OF_DRAW_LOW_QUALITY_PHOTO

## GET_STATUS_OF_LOAD_MISSION_CREATOR_PHOTO
`0xC71B50AE58D07369` | `int GET_STATUS_OF_LOAD_MISSION_CREATOR_PHOTO(const char* contentId)` | build 1207
contentId: returned by NETWORK::_UGC_QUERY_GET_CREATOR_PHOTO(uVar0, 0, sParam3)

## GET_STATUS_OF_SAVE_HIGH_QUALITY_PHOTO
`0xD6663EC374092383` | `int GET_STATUS_OF_SAVE_HIGH_QUALITY_PHOTO()` | build 1207
0 = succeeded
1 = getting status
2 = failed

## GET_STATUS_OF_SORTED_LIST_OPERATION
`0xB28894CD7408BD0C` | `int GET_STATUS_OF_SORTED_LIST_OPERATION()` | build 1207
0 = succeeded
1 = getting status
2 = failed

## GET_STATUS_OF_TAKE_HIGH_QUALITY_PHOTO
`0x4A3DA74C3CCB1725` | `int GET_STATUS_OF_TAKE_HIGH_QUALITY_PHOTO()` | build 1207

## GET_TIMECYCLE_MODIFIER_INDEX
`0xA705394293E2B3D3` | `int GET_TIMECYCLE_MODIFIER_INDEX()` | build 1207

## GET_TIMECYCLE_TRANSITION_MODIFIER_INDEX
`0x2DA67BA3C8A6755D` | `int GET_TIMECYCLE_TRANSITION_MODIFIER_INDEX()` | build 1207

## GET_TOGGLE_PAUSED_RENDERPHASES_STATUS
`0x86ED21BDB2791CE8` | `BOOL GET_TOGGLE_PAUSED_RENDERPHASES_STATUS()` | build 1207

## GET_TV_CHANNEL
`0xF90FBFD68F3C59AE` | `int GET_TV_CHANNEL()` | build 1207

## IS_DECAL_ALIVE
`0x3E4B4E5CF5D3EEB5` | `BOOL IS_DECAL_ALIVE(int decal)` | build 1207

## IS_PHOTO_FRAME
`0x86076AE35CBBE55F` | `BOOL IS_PHOTO_FRAME()` | build 1355

## IS_TRACKED_POINT_VISIBLE
`0xCBB056BA159FB48D` | `BOOL IS_TRACKED_POINT_VISIBLE(int point)` | build 1207

## IS_TVSHOW_CURRENTLY_PLAYING
`0x4D562223E0EB65F3` | `BOOL IS_TVSHOW_CURRENTLY_PLAYING(Hash videoCliphash)` | build 1207
Old name: _IS_TV_PLAYLIST_ITEM_PLAYING

## LOAD_MISSION_CREATOR_PHOTO
`0x84F0BA7462FF8D58` | `BOOL LOAD_MISSION_CREATOR_PHOTO(Any* p0, Any p1, Any p2, Any p3)` | build 1207

## PEDSHOT_IS_AVAILABLE
`0xAF6E67D073D2DCE2` | `BOOL PEDSHOT_IS_AVAILABLE()` | build 1207

## QUEUE_OPERATION_TO_CREATE_SORTED_LIST_OF_PHOTOS
`0xA42EDF1E88734A7E` | `Any QUEUE_OPERATION_TO_CREATE_SORTED_LIST_OF_PHOTOS()` | build 1207

## REMOVE_DECAL
`0x49A720552EB0BB88` | `void REMOVE_DECAL(int decal)` | build 1207

## REMOVE_DECALS_FROM_OBJECT
`0xFB8972BAE0013140` | `void REMOVE_DECALS_FROM_OBJECT(Object obj)` | build 1207

## REMOVE_DECALS_IN_RANGE
`0x86DE59FA02902B40` | `void REMOVE_DECALS_IN_RANGE(float x, float y, float z, float range)` | build 1207
Removes all decals in range from a position, it includes the bullet holes, blood pools, petrol...

## REMOVE_GRASS_CULL_SPHERE
`0xAE7BF7CA9E4BA48D` | `void REMOVE_GRASS_CULL_SPHERE(int handle)` | build 1207

## REMOVE_PARTICLE_FX
`0x459598F579C98929` | `void REMOVE_PARTICLE_FX(int ptfxHandle, BOOL p1)` | build 1207

## REMOVE_PARTICLE_FX_FROM_ENTITY
`0x92884B4A49D81325` | `void REMOVE_PARTICLE_FX_FROM_ENTITY(Entity entity)` | build 1207

## REMOVE_PARTICLE_FX_IN_RANGE
`0x87B5905ECA623B68` | `void REMOVE_PARTICLE_FX_IN_RANGE(float X, float Y, float Z, float radius)` | build 1207

## REMOVE_VEG_MODIFIER_SPHERE
`0x9CF1836C03FB67A2` | `void REMOVE_VEG_MODIFIER_SPHERE(int vegModifierHandle, int p1)` | build 1207
only works by invoking and passing as pointer value Citizen.InvokeNative(0x9CF1836C03FB67A2, Citizen.PointerValueIntInitialized(vegModifierId),1) p1 is 1 or 0

## RESET_ADAPTATION
`0x297B72E2AF094742` | `void RESET_ADAPTATION(int unk)` | build 1207
Sets an unknown value related to timecycles.

## RESET_PARTICLE_FX_OVERRIDE
`0x274B3DABF7E72DEF` | `void RESET_PARTICLE_FX_OVERRIDE(const char* name)` | build 1207
Resets the effect of SET_PARTICLE_FX_OVERRIDE

## RESET_PAUSED_RENDERPHASES
`0xCCD9AAD85E1B559E` | `void RESET_PAUSED_RENDERPHASES()` | build 1207

## SAVE_HIGH_QUALITY_PHOTO
`0x57639FD876B68A91` | `BOOL SAVE_HIGH_QUALITY_PHOTO(int unused)` | build 1207

## SET_ARTIFICIAL_LIGHTS_STATE
`0xB2797619A7C7747B` | `void SET_ARTIFICIAL_LIGHTS_STATE(BOOL state)` | build 1207
Does not affect weapons, particles, fire/explosions, flashlights or the sun.
When set to true, all emissive textures (including ped components that have light effects), street lights, building lights, vehicle lights, etc will all be turned off.

state: True turns off all artificial light sources in the map: buildings, street lights, car lights, etc. False turns them back on.

## SET_CHECKPOINT_RGBA
`0xCAAFC225E33B1D15` | `void SET_CHECKPOINT_RGBA(int checkpoint, int red, int green, int blue, int alpha)` | build 1207
Sets the checkpoint color.

## SET_CHECKPOINT_RGBA2
`0x99AFF17222D4DEB4` | `void SET_CHECKPOINT_RGBA2(int checkpoint, int red, int green, int blue, int alpha)` | build 1207
Sets the checkpoint icon color.

## SET_DISABLE_PETROL_DECALS_IGNITING_THIS_FRAME
`0x53ED07BF368EDA59` | `void SET_DISABLE_PETROL_DECALS_IGNITING_THIS_FRAME()` | build 1232

## SET_GRASS_CULL_SPHERE
`0x27219300C36A8D40` | `int SET_GRASS_CULL_SPHERE(float x, float y, float z, float p3, int p4)` | build 1207
Returns handle to be used with REMOVE_GRASS_CULL_SPHERE

## SET_HIDOF_OVERRIDE
`0xCC23AA1A7CBFE840` | `void SET_HIDOF_OVERRIDE(BOOL p0, BOOL p1, float p2, float p3, float p4, float p5)` | build 1207
Old name: _SET_HIDOF_ENV_BLUR_PARAMS

## SET_PARTICLE_FX_AMBIENT_COLOUR
`0x3C61B52B00848C26` | `void SET_PARTICLE_FX_AMBIENT_COLOUR(Entity entity, const char* p1, float r, float g, float b)` | build 1207
Related to Campfires.
p1: AMB_BONFIRE_MP, AMB_CAMPFIRE_LRG_MP

## SET_PARTICLE_FX_BULLET_IMPACT_LODRANGE_SCALE
`0x8DCCC98DC0DBF9E4` | `void SET_PARTICLE_FX_BULLET_IMPACT_LODRANGE_SCALE(float p0)` | build 1207

## SET_PARTICLE_FX_BULLET_IMPACT_SCALE
`0xA53C8D7D0F8C74D0` | `void SET_PARTICLE_FX_BULLET_IMPACT_SCALE(float scale)` | build 1207

## SET_PARTICLE_FX_FOOT_LODRANGE_SCALE
`0x2A1625858887D4E6` | `void SET_PARTICLE_FX_FOOT_LODRANGE_SCALE(float p0)` | build 1207

## SET_PARTICLE_FX_LOOPED_ALPHA
`0x88786E76234F7054` | `void SET_PARTICLE_FX_LOOPED_ALPHA(int ptfxHandle, float alpha)` | build 1207

## SET_PARTICLE_FX_LOOPED_COLOUR
`0x239879FC61C610CC` | `void SET_PARTICLE_FX_LOOPED_COLOUR(int ptfxHandle, float r, float g, float b, BOOL p4)` | build 1207

## SET_PARTICLE_FX_LOOPED_EVOLUTION
`0x3674F389B0FACD80` | `void SET_PARTICLE_FX_LOOPED_EVOLUTION(int ptfxHandle, char* propertyName, float amount, BOOL noNetwork)` | build 1207

## SET_PARTICLE_FX_LOOPED_FAR_CLIP_DIST
`0x9B04D471DA0AD7AA` | `void SET_PARTICLE_FX_LOOPED_FAR_CLIP_DIST(int ptfxHandle, float range)` | build 1207

## SET_PARTICLE_FX_LOOPED_OFFSETS
`0xD3A4A95FC94FE83B` | `void SET_PARTICLE_FX_LOOPED_OFFSETS(int ptfxHandle, float x, float y, float z, float rotX, float rotY, float rotZ)` | build 1207

## SET_PARTICLE_FX_LOOPED_SCALE
`0x1A9E1C0D98D093B7` | `void SET_PARTICLE_FX_LOOPED_SCALE(int ptfxHandle, float scale)` | build 1207

## SET_PARTICLE_FX_NON_LOOPED_ALPHA
`0xE8A35938A7026CEA` | `void SET_PARTICLE_FX_NON_LOOPED_ALPHA(float alpha)` | build 1311

## SET_PARTICLE_FX_NON_LOOPED_COLOUR
`0x60B85BED6577A35B` | `void SET_PARTICLE_FX_NON_LOOPED_COLOUR(float r, float g, float b)` | build 1207

## SET_PARTICLE_FX_OVERRIDE
`0xBE711A169E9C7E95` | `void SET_PARTICLE_FX_OVERRIDE(const char* oldAsset, const char* newAsset)` | build 1207

## SET_PICKUP_LIGHT
`0x7DFB49BCDB73089A` | `void SET_PICKUP_LIGHT(Object object, BOOL toggle)` | build 1207
https://imgur.com/a/I2swSDJ

Old name: _SET_PICKUP_OBJECT_GLOW_ENABLED

## SET_SCRIPT_GFX_DRAW_BEHIND_PAUSEMENU
`0x906B86E6D7896B9E` | `void SET_SCRIPT_GFX_DRAW_BEHIND_PAUSEMENU(BOOL toggle)` | build 1207
Sets a flag defining whether or not script draw commands should continue being drawn behind the pause menu. This is usually used for draw commands that are used with a world render target.

## SET_SCRIPT_GFX_DRAW_ORDER
`0xCFCC78391C8B3814` | `void SET_SCRIPT_GFX_DRAW_ORDER(int drawOrder)` | build 1207
Sets the draw order for script draw commands.

## SET_TIMECYCLE_MODIFIER
`0xFA08722A5EA82DA7` | `void SET_TIMECYCLE_MODIFIER(const char* modifierName)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/graphics/timecycles

## SET_TIMECYCLE_MODIFIER_STRENGTH
`0xFDB74C9CC54C3F37` | `void SET_TIMECYCLE_MODIFIER_STRENGTH(float strength)` | build 1207

## SET_TRACKED_POINT_INFO
`0xF6FDA3D4404D4F2C` | `void SET_TRACKED_POINT_INFO(int point, float x, float y, float z, float radius)` | build 1207

## SET_TRANSITION_OUT_OF_TIMECYCLE_MODIFIER
`0xBB6C707F20D955D4` | `void SET_TRANSITION_OUT_OF_TIMECYCLE_MODIFIER(float strength)` | build 1207

## SET_TRANSITION_TIMECYCLE_MODIFIER
`0xFF927A09F481D80C` | `void SET_TRANSITION_TIMECYCLE_MODIFIER(const char* modifierName, float transitionBlend)` | build 1207

## SET_TV_AUDIO_FRONTEND
`0x64437C98FCC5F291` | `void SET_TV_AUDIO_FRONTEND(BOOL toggle)` | build 1207
Probably changes tvs from being a 3d audio to being "global" audio

## SET_TV_CHANNEL
`0x593FAF7FC9401A56` | `void SET_TV_CHANNEL(int channel)` | build 1207

## SET_TV_CHANNEL_PLAYLIST
`0xDEC6B25F5DC8925B` | `void SET_TV_CHANNEL_PLAYLIST(int tvChannel, const char* playlistName, BOOL restart)` | build 1207

## SET_TV_VOLUME
`0x73A97068787D7231` | `void SET_TV_VOLUME(float volume)` | build 1207

## START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY
`0x8F90AB32E1944BDE` | `int START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY(char* effectName, Entity entity, float xOffset, float yOffset, float zOffset, float xRot, float yRot, float zRot, float scale, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207

## START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE
`0x9C56621462FFE7A6` | `int START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE(char* effectName, Entity entity, float xOffset, float yOffset, float zOffset, float xRot, float yRot, float zRot, int boneIndex, float scale, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207

## START_NETWORKED_PARTICLE_FX_NON_LOOPED_AT_COORD
`0xFB97618457994A62` | `BOOL START_NETWORKED_PARTICLE_FX_NON_LOOPED_AT_COORD(char* effectName, float xPos, float yPos, float zPos, float xRot, float yRot, float zRot, float scale, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207

## START_NETWORKED_PARTICLE_FX_NON_LOOPED_ON_ENTITY
`0xE6CFE43937061143` | `BOOL START_NETWORKED_PARTICLE_FX_NON_LOOPED_ON_ENTITY(char* effectName, Entity entity, float offsetX, float offsetY, float offsetZ, float rotX, float rotY, float rotZ, float scale, BOOL axisX, BOOL axisY, BOOL axisZ)` | build 1207

## START_PARTICLE_FX_LOOPED_AT_COORD
`0xBA32867E86125D3A` | `int START_PARTICLE_FX_LOOPED_AT_COORD(char* effectName, float x, float y, float z, float xRot, float yRot, float zRot, float scale, BOOL xAxis, BOOL yAxis, BOOL zAxis, BOOL p11)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/graphics/ptfx/ptfx_assets_looped.lua

## START_PARTICLE_FX_LOOPED_ON_ENTITY
`0xBD41E1440CE39800` | `int START_PARTICLE_FX_LOOPED_ON_ENTITY(char* effectName, Entity entity, float xOffset, float yOffset, float zOffset, float xRot, float yRot, float zRot, float scale, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207

## START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE
`0xD3BA6EC7F2FBD5E9` | `int START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE(char* effectName, Entity entity, float xOffset, float yOffset, float zOffset, float xRot, float yRot, float zRot, int boneIndex, float scale, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207

## START_PARTICLE_FX_LOOPED_ON_PED_BONE
`0xE689C1B1432BB8AF` | `int START_PARTICLE_FX_LOOPED_ON_PED_BONE(char* effectName, Ped ped, float xOffset, float yOffset, float zOffset, float xRot, float yRot, float zRot, int boneIndex, float scale, BOOL xAxis, BOOL yAxis, BOOL zAxis)` | build 1207

## START_PARTICLE_FX_NON_LOOPED_AT_COORD
`0x2E80BF72EF7C87AC` | `BOOL START_PARTICLE_FX_NON_LOOPED_AT_COORD(char* effectName, float xPos, float yPos, float zPos, float xRot, float yRot, float zRot, float scale, int xAxis, BOOL yAxis, BOOL zAxis)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/graphics/ptfx/ptfx_assets_non_looped.lua

## START_PARTICLE_FX_NON_LOOPED_ON_ENTITY
`0xFF4C64C513388C12` | `BOOL START_PARTICLE_FX_NON_LOOPED_ON_ENTITY(char* effectName, Entity entity, float offsetX, float offsetY, float offsetZ, float rotX, float rotY, float rotZ, float scale, BOOL axisX, BOOL axisY, BOOL axisZ)` | build 1207

## START_PARTICLE_FX_NON_LOOPED_ON_PED_BONE
`0x3FAA72BD940C3AC0` | `BOOL START_PARTICLE_FX_NON_LOOPED_ON_PED_BONE(char* effectName, Ped ped, float offsetX, float offsetY, float offsetZ, float rotX, float rotY, float rotZ, int boneIndex, float scale, BOOL axisX, BOOL axisY, BOOL axisZ)` | build 1207

## START_PETROL_TRAIL_DECALS
`0x46F246D6504F0031` | `void START_PETROL_TRAIL_DECALS(Any p0, Any p1)` | build 1207

## STOP_PARTICLE_FX_LOOPED
`0x22970F3A088B133B` | `void STOP_PARTICLE_FX_LOOPED(int ptfxHandle, BOOL p1)` | build 1207

## TOGGLE_PAUSED_RENDERPHASES
`0xEF9E1C45732F55FA` | `void TOGGLE_PAUSED_RENDERPHASES(BOOL toggle)` | build 1207

## UPDATE_LIGHTS_ON_ENTITY
`0xBDBACB52A03CC760` | `void UPDATE_LIGHTS_ON_ENTITY(Entity entity)` | build 1207

## USE_PARTICLE_FX_ASSET
`0xA10DB07FC234DD12` | `void USE_PARTICLE_FX_ASSET(const char* fxName)` | build 1207
fxName: see data_0/data/effects/ptfx/fxlists/

## _0x085C5B61A0114F32
`0x085C5B61A0114F32` | `void _0x085C5B61A0114F32(Any p0, Any p1)` | build 1207

## _0x0D5B19C34068FEE7
`0x0D5B19C34068FEE7` | `void _0x0D5B19C34068FEE7(Any p0)` | build 1311
Gets set to 1 when GET_STATUS_OF_TAKE_HIGH_QUALITY_PHOTO = PHOTO_OPERATION_SUCCEEDED

## _0x1460B644397453EB
`0x1460B644397453EB` | `void _0x1460B644397453EB()` | build 1207
_RESET_*

## _0x171C18E994C1A395
`0x171C18E994C1A395` | `void _0x171C18E994C1A395(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0x1A9F09AB458D49C6
`0x1A9F09AB458D49C6` | `void _0x1A9F09AB458D49C6(BOOL p0)` | build 1207
Used in shop scripts for CATALOG_BOOK
false = Normal -> [CATALOG_BOOK_SHUTDOWN]
true = Trees flickering? -> [CATALOG_BOOK_OPEN]

## _0x1C6306E5BC25C29C
`0x1C6306E5BC25C29C` | `void _0x1C6306E5BC25C29C()` | build 1207

## _0x1FF8731BE1DFC0C0
`0x1FF8731BE1DFC0C0` | `void _0x1FF8731BE1DFC0C0(Any p0, Any p1)` | build 1207

## _0x26DD2FB0A88CC412
`0x26DD2FB0A88CC412` | `void _0x26DD2FB0A88CC412(const char* effectName, const char* effectName2, Any p2, Any p3)` | build 1207
effectName2, p2 and p3 are unused

ANIMPOSTFX_*

## _0x285438C26C732F9D
`0x285438C26C732F9D` | `Any _0x285438C26C732F9D()` | build 1207

## _0x32DE2BFFDA43E62A
`0x32DE2BFFDA43E62A` | `void _0x32DE2BFFDA43E62A()` | build 1207

## _0x38D9D50F2085E9B3
`0x38D9D50F2085E9B3` | `void _0x38D9D50F2085E9B3(Hash effectNameHash)` | build 1207
ANIMPOSTFX_*

## _0x3DA7A10583A4BEC0
`0x3DA7A10583A4BEC0` | `BOOL _0x3DA7A10583A4BEC0()` | build 1207
ANIMPOSTFX_*

## _0x402E1A61D2587FCD
`0x402E1A61D2587FCD` | `BOOL _0x402E1A61D2587FCD(Any p0, float x, float y, float z, float p4, float p5, float heading)` | build 1207
Only used in R* SP Script spd_agnesdown1

## _0x4046493D2EEACA0E
`0x4046493D2EEACA0E` | `void _0x4046493D2EEACA0E()` | build 1207
_DISABLE_*

## _0x41F88A85A579A61D
`0x41F88A85A579A61D` | `void _0x41F88A85A579A61D(float p0)` | build 1207
Used in CREATE_BEZIER_BLOOD_TRAIL_OF_TYPE

## _0x453D16D41FC51D3E
`0x453D16D41FC51D3E` | `void _0x453D16D41FC51D3E(BOOL p0)` | build 1207

## _0x48FE0DB54045B975
`0x48FE0DB54045B975` | `void _0x48FE0DB54045B975(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1311

## _0x4BD66B4E3427689B
`0x4BD66B4E3427689B` | `void _0x4BD66B4E3427689B(const char* p0)` | build 1207
Used in CREATE_BEZIER_BLOOD_TRAIL_OF_TYPE

## _0x4FB67D172C4476F3
`0x4FB67D172C4476F3` | `void _0x4FB67D172C4476F3(Entity entity, const char* p1, const char* p2, float p3)` | build 1207
p1: AMB_ANN_COAL_CHUTE_DIVE, AMB_ANN_COAL_CHUTE
p2: EMIT
p3: either 0.0f or 1.0f

## _0x503941F65DBA24EC
`0x503941F65DBA24EC` | `void _0x503941F65DBA24EC(Any p0)` | build 1207

## _0x519928DF02EB5101
`0x519928DF02EB5101` | `void _0x519928DF02EB5101(Any p0)` | build 1355

## _0x5C674EB487891F6B
`0x5C674EB487891F6B` | `Any _0x5C674EB487891F6B()` | build 1207

## _0x5C9C3A466B3296A8
`0x5C9C3A466B3296A8` | `Any _0x5C9C3A466B3296A8(Any p0)` | build 1207
Only used in R* SP Script spd_agnesdown1

## _0x67B0778C62E74423
`0x67B0778C62E74423` | `void _0x67B0778C62E74423(Any p0)` | build 1207

## _0x6C03118E9E5C1A14
`0x6C03118E9E5C1A14` | `void _0x6C03118E9E5C1A14(Any p0)` | build 1207

## _0x71845905BCCDE781
`0x71845905BCCDE781` | `void _0x71845905BCCDE781(Hash effectNameHash)` | build 1207
ANIMPOSTFX_*

## _0x735762E8D7573E42
`0x735762E8D7573E42` | `void _0x735762E8D7573E42(Any p0, Any p1, Any p2)` | build 1207

## _0x812C1563185C6FB2
`0x812C1563185C6FB2` | `void _0x812C1563185C6FB2()` | build 1207
Used in CREATE_BEZIER_BLOOD_TRAIL_OF_TYPE
_ENABLE_*

## _0x815653A42C5ABE76
`0x815653A42C5ABE76` | `void _0x815653A42C5ABE76()` | build 1207

## _0x8996FA6AD9FE4E90
`0x8996FA6AD9FE4E90` | `void _0x8996FA6AD9FE4E90(Any p0)` | build 1207

## _0x910E260AEAD855DE
`0x910E260AEAD855DE` | `void _0x910E260AEAD855DE()` | build 1207

## _0x94B261F1F35293E1
`0x94B261F1F35293E1` | `void _0x94B261F1F35293E1(Any p0)` | build 1207
nullsub, doesn't do anything

## _0x981C7D863980FA51
`0x981C7D863980FA51` | `void _0x981C7D863980FA51()` | build 1207

## _0x9D1B0B5066205692
`0x9D1B0B5066205692` | `void _0x9D1B0B5066205692()` | build 1207

## _0x9F158A49B0D84C3C
`0x9F158A49B0D84C3C` | `void _0x9F158A49B0D84C3C(Any p0)` | build 1207

## _0x9F6D859C80708B26
`0x9F6D859C80708B26` | `void _0x9F6D859C80708B26(BOOL p0, BOOL p1)` | build 1311

## _0xA04EF43030593ABC
`0xA04EF43030593ABC` | `void _0xA04EF43030593ABC(Any p0, Any p1)` | build 1207

## _0xA0F4D12D6042F6D5
`0xA0F4D12D6042F6D5` | `void _0xA0F4D12D6042F6D5(Any p0, Any p1)` | build 1207

## _0xA15CCAB8AD038291
`0xA15CCAB8AD038291` | `Any _0xA15CCAB8AD038291(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xA1A86055792FB249
`0xA1A86055792FB249` | `void _0xA1A86055792FB249(int personaPhotoLocalCacheType)` | build 1207

## _0xA201A3D0AC087C37
`0xA201A3D0AC087C37` | `void _0xA201A3D0AC087C37(const char* effectName)` | build 1207
ANIMPOSTFX_*

## _0xA21AF60C9F99CCC5
`0xA21AF60C9F99CCC5` | `void _0xA21AF60C9F99CCC5()` | build 1207

## _0xB032C085D9A03907
`0xB032C085D9A03907` | `void _0xB032C085D9A03907()` | build 1207
_SET_D* or _SET_E*

## _0xB958D97A0DFAA0C2
`0xB958D97A0DFAA0C2` | `BOOL _0xB958D97A0DFAA0C2(const char* effectName)` | build 1207
ANIMPOSTFX_*

## _0xC06F2F45A73EABCD
`0xC06F2F45A73EABCD` | `void _0xC06F2F45A73EABCD(Entity entity)` | build 1311
Used in NET_CAMP_SPIRIT_ANIMAL_CLEAR_ANIMAL_VISIBILITY

## _0xC28F62AC9774FC1B
`0xC28F62AC9774FC1B` | `Any _0xC28F62AC9774FC1B()` | build 1207

## _0xC37792A3F9C90771
`0xC37792A3F9C90771` | `Any _0xC37792A3F9C90771()` | build 1207
Doesn't actually return anything.

ANIMPOSTFX_*

## _0xC489FE31AC726512
`0xC489FE31AC726512` | `void _0xC489FE31AC726512(Any p0, Any p1)` | build 1207

## _0xC76FC4C2FC5F4405
`0xC76FC4C2FC5F4405` | `void _0xC76FC4C2FC5F4405(Hash effectNameHash)` | build 1207
ANIMPOSTFX_*

## _0xCC3B787E73E64160
`0xCC3B787E73E64160` | `void _0xCC3B787E73E64160(Any p0, Any p1, Any p2, Any p3, Any p4)` | build 1207

## _0xD1472AFF30C103D6
`0xD1472AFF30C103D6` | `void _0xD1472AFF30C103D6(float p0)` | build 1311
Only used in R* Script nb_stalking_hunter

## _0xD543487A1F12828F
`0xD543487A1F12828F` | `void _0xD543487A1F12828F(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xD9BC98B55BCFAA9B
`0xD9BC98B55BCFAA9B` | `void _0xD9BC98B55BCFAA9B(Any p0)` | build 1207

## _0xE63D68F455CA0B47
`0xE63D68F455CA0B47` | `Any _0xE63D68F455CA0B47(Any p0, Any p1, Any p2, Any p3, Any p4, Any p5, Any p6)` | build 1207

## _0xE75CDDEBF618C8FF
`0xE75CDDEBF618C8FF` | `BOOL _0xE75CDDEBF618C8FF(Hash effectNameHash)` | build 1207
ANIMPOSTFX_*

## _0xEB48CE48EEC41FD4
`0xEB48CE48EEC41FD4` | `void _0xEB48CE48EEC41FD4(Any p0)` | build 1207

## _0xEC3D8C228FE553D7
`0xEC3D8C228FE553D7` | `BOOL _0xEC3D8C228FE553D7(BOOL p0)` | build 1207

## _0xEC3F7F24EEEB3BA3
`0xEC3F7F24EEEB3BA3` | `void _0xEC3F7F24EEEB3BA3()` | build 1207

## _0xF2F543D48F319A3A
`0xF2F543D48F319A3A` | `void _0xF2F543D48F319A3A()` | build 1207

## _0xF5793BB386E1FF9C
`0xF5793BB386E1FF9C` | `void _0xF5793BB386E1FF9C(Any p0)` | build 1207

## _0xFB680A9B33D0EDBE
`0xFB680A9B33D0EDBE` | `void _0xFB680A9B33D0EDBE(BOOL p0)` | build 1207
_DISABLE_*

## _0xFC9B53C072F418E0
`0xFC9B53C072F418E0` | `Any _0xFC9B53C072F418E0()` | build 1207

## _0xFD05B1DDE83749FA
`0xFD05B1DDE83749FA` | `BOOL _0xFD05B1DDE83749FA(const char* p0)` | build 1207
R* Script spd_agnesdow1: p0 = SPD_AGNES_DOWD_01

## _0xFF584F097C17FA8F
`0xFF584F097C17FA8F` | `BOOL _0xFF584F097C17FA8F()` | build 1207
Returns whether the 'killFX' setting is enabled.

ANIMPOSTFX_*

## _0xFF8018C778349234
`0xFF8018C778349234` | `void _0xFF8018C778349234(Any p0)` | build 1207

## _ADD_BLOOD_POOL
`0xFA2ECC78A6014D4F` | `void _ADD_BLOOD_POOL(float x, float y, float z, BOOL unused)` | build 1207
https://i.imgur.com/ULQU9US.jpg
More rounded and small puddle

## _ADD_BLOOD_POOLS_FOR_PED
`0xDFCE8CE9F3EBE93F` | `void _ADD_BLOOD_POOLS_FOR_PED(Ped ped)` | build 1207
Creates blood pools for the given ped in some interval for a few seconds.

## _ADD_BLOOD_POOLS_FOR_PED_WITH_PARAMS
`0xC349EE1E6EFA494B` | `void _ADD_BLOOD_POOLS_FOR_PED_WITH_PARAMS(Ped ped, float p1, float size, float p3)` | build 1207

## _ADD_BLOOD_POOL_2
`0xF708298675ABDC6A` | `void _ADD_BLOOD_POOL_2(float x, float y, float z, float p3, float size, float p5, BOOL permanent, float p7, BOOL p8)` | build 1207
https://i.imgur.com/rPITUCV.jpg
More customizable and more like quadrants

## _ADD_BLOOD_TRAIL_POINT
`0xDD9DC1AB63D513CE` | `void _ADD_BLOOD_TRAIL_POINT(float x, float y, float z)` | build 1207

## _ADD_BLOOD_TRAIL_SPLAT
`0xF5E45CB1CF965D2D` | `void _ADD_BLOOD_TRAIL_SPLAT(float x, float y, float z)` | build 1207

## _ADD_ENTITY_TO_ENTITY_MASK
`0xC6F81FCD15350323` | `void _ADD_ENTITY_TO_ENTITY_MASK(Entity entity, int mask)` | build 1207

## _ADD_ENTITY_TO_ENTITY_MASK_WITH_INTENSITY
`0x958DEBD9353C0935` | `void _ADD_ENTITY_TO_ENTITY_MASK_WITH_INTENSITY(Entity entity, int mask, float intensity)` | build 1207

## _ADD_VEG_MODIFIER_ZONE
`0xBD3324281E8B9933` | `int _ADD_VEG_MODIFIER_ZONE(Volume volume, int p1, int flags, int p3)` | build 1207
Adds Vegetation Blocking Zone, Added Snow Flattening veg mod Zone
Returns veg modifier handle

## _ANIMPOSTFX_CLEAR_EFFECT
`0xC5CB91D65852ED7E` | `void _ANIMPOSTFX_CLEAR_EFFECT(const char* effectName)` | build 1207

## _ANIMPOSTFX_GET_STACKHASH
`0x842CCC9491FFCD9B` | `Hash _ANIMPOSTFX_GET_STACKHASH(const char* effectName)` | build 1207
Known effects: MP_Trans_SceneToPhoto
MP_Trans_WinLose
SpectateFilter
MP_CharacterCreatorPhoto
MP_Trans_PhotoToScene
InterrogationHit

## _ANIMPOSTFX_HAS_EVENT_TRIGGERED
`0xFBF161FCFEC8589E` | `BOOL _ANIMPOSTFX_HAS_EVENT_TRIGGERED(char* effectName, int eventType, BOOL peekOnly, BOOL* isRegistered)` | build 1207
Return true if the event have just been triggered. Literaly the same system of ANIMPOSTFX_HAS_EVENT_TRIGGERED_BY_STACKHASH, but works with a string.
```lua
CreateThread(function()
    AnimpostfxPlay("ChapterTitle_IntroCh01")
    while true do
        local hasEventTriggered1, isRegistered1 = AnimpostfxHasEventTriggered("ChapterTitle_IntroCh01", 1, false)
        local hasEventTriggered2, isRegistered2 = AnimpostfxHasEventTriggered("ChapterTitle_IntroCh01", 2, false)
        if (hasEventTriggered1) then
            print("AnimpostfxHasEventTriggered('ChapterTitle_IntroCh01', 1, false)", hasEventTriggered1)
        end
        if (hasEventTriggered2) then
            print("AnimpostfxHasEventTriggered('ChapterTitle_IntroCh01', 2, false)", hasEventTriggered2)
        end
        Wait(0)
    end
end)
```

## _ANIMPOSTFX_HAS_LOADED
`0xBF2DD155B2ADCD0A` | `BOOL _ANIMPOSTFX_HAS_LOADED(const char* effectName)` | build 1207

## _ANIMPOSTFX_IS_STACKHASH_PLAYING
`0xEEF83A759AE06A27` | `BOOL _ANIMPOSTFX_IS_STACKHASH_PLAYING(Hash effectNameHash)` | build 1207

## _ANIMPOSTFX_IS_TAG_PLAYING
`0x2D4F9C852CE8A253` | `BOOL _ANIMPOSTFX_IS_TAG_PLAYING(const char* effectName)` | build 1207

## _ANIMPOSTFX_PLAY_TAG
`0x9B8D5D4CB8AF58B3` | `void _ANIMPOSTFX_PLAY_TAG(Hash effectNameHash)` | build 1207

## _ANIMPOSTFX_PLAY_TIMED
`0x3A9A281FF71249E9` | `void _ANIMPOSTFX_PLAY_TIMED(const char* effectName, int duration)` | build 1207

## _ANIMPOSTFX_PRELOAD_POSTFX
`0x5199405EABFBD7F0` | `void _ANIMPOSTFX_PRELOAD_POSTFX(const char* effectName)` | build 1207

## _ANIMPOSTFX_PRELOAD_POSTFX_BY_STACKHASH
`0xF3E039322BFBD4D8` | `void _ANIMPOSTFX_PRELOAD_POSTFX_BY_STACKHASH(Hash effectNameHash)` | build 1207

## _ANIMPOSTFX_SET_POSTFX_COLOR
`0x63011D0C7C6519E0` | `void _ANIMPOSTFX_SET_POSTFX_COLOR(const char* effectName, int p1, int red, int green, int blue, int alpha)` | build 1311

## _ANIMPOSTFX_SET_POTENCY
`0xF972F0AB16DC5260` | `void _ANIMPOSTFX_SET_POTENCY(const char* effectName, int p1, float potency)` | build 1207
Health Core Effect Filter Potency: p1 = 1
Stamina Core Effect Filter Potency: p1 = 2
Multiple Core Effect Filter Potency: p1 = 3

## _ANIMPOSTFX_SET_STRENGTH
`0xCAB4DD2D5B2B7246` | `void _ANIMPOSTFX_SET_STRENGTH(const char* effectName, float strength)` | build 1207
must be called after ANIMPOSTFX_PLAY, strength 0.0f - 1.0f

## _ANIMPOSTFX_SET_TO_UNLOAD
`0x37D7BDBA89F13959` | `void _ANIMPOSTFX_SET_TO_UNLOAD(const char* effectName)` | build 1207

## _ANIMPOSTFX_STOP_STACKHASH_POSTFX
`0xEDA5CBECF56E1386` | `void _ANIMPOSTFX_STOP_STACKHASH_POSTFX(Hash effectNameHash)` | build 1207

## _ANIMPOSTFX_STOP_TAG
`0xAD74C22A541AB987` | `void _ANIMPOSTFX_STOP_TAG(const char* effectName)` | build 1207

## _BLOCK_PICKUP_OBJECT_LIGHT
`0x50C14328119E1DD1` | `void _BLOCK_PICKUP_OBJECT_LIGHT(Object pickupObject, BOOL toggle)` | build 1207

## _BLOOD_TRAIL_FOR_WAYPOINT
`0xB9C92616929CC25D` | `void _BLOOD_TRAIL_FOR_WAYPOINT(const char* waypointRecording, float p1)` | build 1207
p1: 0.3f in R* Scripts

## _CHANGE_PHOTO_MODE_CONTRAST
`0x62B9F9A1272AED80` | `void _CHANGE_PHOTO_MODE_CONTRAST(float value)` | build 1207

## _CHANGE_PHOTO_MODE_EXPOSURE
`0xC8D0611D9A0CF5D3` | `void _CHANGE_PHOTO_MODE_EXPOSURE(float value)` | build 1207

## _CREATE_SWATCH_TEXTURE_DICT
`0x3D084D5568FB4028` | `BOOL _CREATE_SWATCH_TEXTURE_DICT(int slots)` | build 1207

## _DESTROY_SWATCH_TEXTURE_DICT
`0xDAD7FB8402651654` | `void _DESTROY_SWATCH_TEXTURE_DICT()` | build 1207

## _DISABLE_FAR_ARTIFICIAL_LIGHTS
`0xCD284E2F6AC27EE9` | `void _DISABLE_FAR_ARTIFICIAL_LIGHTS(BOOL disable)` | build 1207
Only used in guama1 R* Script
Disables lod/distant lights when BOOL is set to true

## _DISABLE_STATIC_VEG_MODIFIER
`0xDD0BC0EDCB2162F6` | `void _DISABLE_STATIC_VEG_MODIFIER(Hash p0)` | build 1207

## _DOES_CHECKPOINT_HAVE_FX
`0x4C11CCACB7C02B6E` | `BOOL _DOES_CHECKPOINT_HAVE_FX(int checkpoint)` | build 1207

## _ENABLE_STATIC_VEG_MODIFIER
`0xDFEA23EC90113657` | `void _ENABLE_STATIC_VEG_MODIFIER(Hash p0)` | build 1207

## _GENERATE_SWATCH_TEXTURE
`0x160921255327C591` | `void _GENERATE_SWATCH_TEXTURE(int slotId, Hash componentHash, int metapedType, BOOL p3)` | build 1207
Example:
local hash = GetHashKey("CLOTHING_ITEM_M_EYES_001_TINT_001")
_GENERATE_SWATCH_TEXTURE(0, hash, 0, true)
metapedType: see 0xEC9A1261BF0CE510

## _GENERATE_SWATCH_TEXTURE_DIRECTLY
`0x646ED1A1D28487DF` | `void _GENERATE_SWATCH_TEXTURE_DIRECTLY(int slot, Any p1)` | build 1207
Example: https://pastebin.com/tTgpER9A

## _GET_CURRENT_NUMBER_OF_LOCAL_PHOTOS
`0x78C56B8A7B1D000C` | `int _GET_CURRENT_NUMBER_OF_LOCAL_PHOTOS()` | build 1207

## _GET_ENTITY_MASK_LAYERS
`0xE8A8378BF651079C` | `BOOL _GET_ENTITY_MASK_LAYERS(Entity entity, float* layer0, float* layer1, float* layer2, float* layer3)` | build 1207

## _GET_MAX_NUMBER_OF_LOCAL_PHOTOS
`0x8E587FCD30E05592` | `int _GET_MAX_NUMBER_OF_LOCAL_PHOTOS()` | build 1207
Always returns 200.

## _GET_MODIFIED_VISIBILITY_DISTANCE
`0x25CA89B2A39DCC69` | `float _GET_MODIFIED_VISIBILITY_DISTANCE()` | build 1207
_GET_C* - _GET_E*

## _GET_PHOTO_MODE_CONTRAST
`0x98F4154989B81EC6` | `float _GET_PHOTO_MODE_CONTRAST()` | build 1207

## _GET_PHOTO_MODE_EXPOSURE
`0x06C0D8BB6B04A709` | `float _GET_PHOTO_MODE_EXPOSURE()` | build 1207

## _GET_PROXY_INTERIOR_INDEX
`0x5D1C5D8E62E8EE1C` | `int _GET_PROXY_INTERIOR_INDEX(int interiorId)` | build 1207
Returns proxyInteriorIndex

## _IS_PROXY_INTERIOR_INDEX_ARTIFICIAL_LIGHTS_ENABLED
`0x113857D66A9CABE6` | `BOOL _IS_PROXY_INTERIOR_INDEX_ARTIFICIAL_LIGHTS_ENABLED(int proxyInteriorIndex)` | build 1207

## _IS_STATIC_VEG_MODIFIER_ENABLED
`0xDE9BAD3292AA6D5E` | `BOOL _IS_STATIC_VEG_MODIFIER_ENABLED(Hash p0)` | build 1207

## _IS_TEXTURE_IN_DICT
`0xA2A51869BDED733B` | `BOOL _IS_TEXTURE_IN_DICT(Hash txdHash, Hash dict)` | build 1207

## _IS_TRACKED_POINT_VALID
`0xF2FDDCC8C6BAE1B3` | `BOOL _IS_TRACKED_POINT_VALID(int point)` | build 1207

## _NUM_PIXELS_VISIBLE_AT_TRACKED_POINT
`0xDFE332A5DA6FE7C9` | `int _NUM_PIXELS_VISIBLE_AT_TRACKED_POINT(int iTrackedPoint)` | build 1207
Returns iNumPixels, iPixelsVisible

## _PEDSHOT_FINISH_CLEANUP_DATA
`0xC2B8164C3BE871A4` | `void _PEDSHOT_FINISH_CLEANUP_DATA()` | build 1207

## _PEDSHOT_GENERATE_PERSONA_PHOTO
`0xD9C24F53631F2372` | `BOOL _PEDSHOT_GENERATE_PERSONA_PHOTO(const char* texture, Ped ped, int playerSlot)` | build 1207

## _PEDSHOT_INIT_CLEANUP_DATA
`0x55285F885F662169` | `void _PEDSHOT_INIT_CLEANUP_DATA()` | build 1207

## _PEDSHOT_PREVIOUS_PERSONA_PHOTO_DATA_CLEANUP
`0x3E2FDDBE435A8787` | `void _PEDSHOT_PREVIOUS_PERSONA_PHOTO_DATA_CLEANUP()` | build 1207

## _PEDSHOT_SET_PERSONA_PHOTO_TYPE
`0x196D3ACBEBA4A44B` | `void _PEDSHOT_SET_PERSONA_PHOTO_TYPE(int personaPhotoLocalCacheType)` | build 1207

## _REMOVE_ENTITY_FROM_ENTITY_MASK
`0x56A786E87FF53478` | `void _REMOVE_ENTITY_FROM_ENTITY_MASK(Entity entity)` | build 1207

## _REMOVE_MASK_OVERLAY
`0x5AC6E0FA028369DE` | `void _REMOVE_MASK_OVERLAY()` | build 1207
Removes the mask overlay that was set with SET_MASK_OVERLAY

## _RESET_ENTITY_AURA
`0xAF4D239B8903FCBE` | `void _RESET_ENTITY_AURA()` | build 1207
Used for script function RPG_GLOBAL_STATS__PRIVATE__DEACTIVATE_STAT_FLAG - Inspiration Aura unequip

## _SET_CLOUD_HEIGHT
`0xC332C91388F5580B` | `void _SET_CLOUD_HEIGHT(float height)` | build 1207

## _SET_CLOUD_LAYER
`0xB8C984C0D47F4F07` | `void _SET_CLOUD_LAYER(float x, float y, int p2)` | build 1207

## _SET_CLOUD_NOISE
`0xFE7966DF01452F32` | `void _SET_CLOUD_NOISE(float x, float y, float z)` | build 1207

## _SET_CLOUD_POSITION
`0x10C1767B93257480` | `void _SET_CLOUD_POSITION(float x, float y, float z)` | build 1207
Only used in finale2, smuggler2, winter4
_SET_CLOUD_A* - _SET_CLOUD_H*

## _SET_DISTRICT_PHOTO_TAKEN_STAT
`0x9937FACBBF267244` | `void _SET_DISTRICT_PHOTO_TAKEN_STAT(const char* p0)` | build 1207

## _SET_ENTITY_AURA
`0x249CD6B7285536F2` | `void _SET_ENTITY_AURA(float p0, float p1, float p2)` | build 1207
Used for script function RPG_GLOBAL_STATS__PRIVATE__ACTIVATE_STAT_FLAG - Quite and Inspiration Aura equip
Params: 0f, 2f, 2f

## _SET_ENTITY_MASK_LAYERS
`0xE92012611461A42A` | `void _SET_ENTITY_MASK_LAYERS(Entity entity, float* layer0, float* layer1, float* layer2, float* layer3)` | build 1207

## _SET_ENTITY_RENDER_GUARMA_SHIP
`0xC38B4952B728397A` | `void _SET_ENTITY_RENDER_GUARMA_SHIP(Vehicle vehicle, BOOL toggle)` | build 1207
Only used in guama1 R* SP Script while spawning the ship
_SET_ENTITY_QUATERNION_* - SET_ENTITY_RENDER_*

## _SET_LIGHTS_COLOR_FOR_ENTITY
`0x6EC2A67962296F49` | `void _SET_LIGHTS_COLOR_FOR_ENTITY(Entity entity, int red, int green, int blue)` | build 1207
https://gfycat.com/meagerfaireyra

## _SET_LIGHTS_INTENSITY_FOR_ENTITY
`0x07C0F87AAC57F2E4` | `void _SET_LIGHTS_INTENSITY_FOR_ENTITY(Entity entity, float intensity)` | build 1207

## _SET_LIGHTS_TYPE_FOR_ENTITY
`0xAB72C67163DC4DB4` | `void _SET_LIGHTS_TYPE_FOR_ENTITY(Entity entity, int type)` | build 1207
type must be less than or equal to 20

## _SET_MASK_OVERLAY
`0x21F00E08CBB5F37B` | `void _SET_MASK_OVERLAY(char* overlay)` | build 1207
Params: COMPONENT_BINOCULARS_SCOPE01

## _SET_PARTICLE_FX_LOOPED_UPDATE_DISTANT_SMOKE
`0x9DDC222D85D5AF2A` | `void _SET_PARTICLE_FX_LOOPED_UPDATE_DISTANT_SMOKE(int ptfxHandle, float scalar)` | build 1207
_SET_PARTICLE_FX_LOOPED_FA* - _SET_PARTICLE_FX_LOOPED_OF*

## _SET_PARTICLE_FX_NON_LOOPED_EMITTER_SCALE
`0x56C392C2BD78B024` | `void _SET_PARTICLE_FX_NON_LOOPED_EMITTER_SCALE(float p0, float p1, float p2)` | build 1311

## _SET_PEARLESCENT_FX_ENABLED
`0x72E30372E7CC4415` | `void _SET_PEARLESCENT_FX_ENABLED(Object object, BOOL toggle)` | build 1207
Enables/disables a kind of 'shiny' effect on metals.

## _SET_PHOTO_IN_PHOTOMODE_STAT
`0xFA91736933AB3D93` | `void _SET_PHOTO_IN_PHOTOMODE_STAT(BOOL p0)` | build 1207

## _SET_PHOTO_MODE_EXPOSURE_LOCKED
`0x5CD6A2CCE5087161` | `void _SET_PHOTO_MODE_EXPOSURE_LOCKED(BOOL lock)` | build 1311

## _SET_PHOTO_OVERLAY_EFFECT_STAT
`0x8B3296278328B5EB` | `void _SET_PHOTO_OVERLAY_EFFECT_STAT(int p0)` | build 1207

## _SET_PHOTO_SELF_STAT
`0x2705D18C11B61046` | `void _SET_PHOTO_SELF_STAT(BOOL p0)` | build 1207

## _SET_PHOTO_STUDIO_STAT
`0x8E6AFF353C09652E` | `void _SET_PHOTO_STUDIO_STAT(int p0)` | build 1207

## _SET_PLAYER_APPEAR_IN_PHOTO
`0x75D568607909333E` | `void _SET_PLAYER_APPEAR_IN_PHOTO(Player player)` | build 1232

## _SET_POSSE_ID_FOR_PHOTO
`0x564837D4A9EDE296` | `void _SET_POSSE_ID_FOR_PHOTO(Any posseId)` | build 1207

## _SET_PROXY_INTERIOR_INDEX_ARTIFICIAL_LIGHTS_STATE
`0xBFCB17895BB99E4E` | `void _SET_PROXY_INTERIOR_INDEX_ARTIFICIAL_LIGHTS_STATE(int proxyInteriorIndex, BOOL state)` | build 1207
state: false disables artificial interior light sources for specific proxyInteriorIndex

## _SET_REGION_PHOTO_TAKEN_STAT
`0xD1031B83AC093BC7` | `void _SET_REGION_PHOTO_TAKEN_STAT(const char* p0)` | build 1207

## _SET_SNIPER_GLINTS_ENABLED
`0x6E8EB45A4F4460EB` | `void _SET_SNIPER_GLINTS_ENABLED(BOOL enabled)` | build 1207

## _SET_SNOW_COVERAGE_TYPE
`0xF02A9C330BBFC5C7` | `void _SET_SNOW_COVERAGE_TYPE(int type)` | build 1207
enum class eSnowCoverageType
{
	Primary,
	Secondary,
	Xmas,
	XmasSecondary // since b1232
};

## _SET_STATE_PHOTO_TAKEN_STAT
`0x8952E857696B8A79` | `void _SET_STATE_PHOTO_TAKEN_STAT(const char* p0)` | build 1207

## _START_PARTICLE_FX_NON_LOOPED_ON_PED_BONE_2
`0xC695870B8A149B96` | `BOOL _START_PARTICLE_FX_NON_LOOPED_ON_PED_BONE_2(char* effectName, Ped ped, float offsetX, float offsetY, float offsetZ, float rotX, float rotY, float rotZ, int boneIndex, float scale, BOOL axisX, BOOL axisY, BOOL axisZ)` | build 1207

## _UPDATE_PHOTO_MODE_EXPOSURE
`0x9229ED770975BD9E` | `void _UPDATE_PHOTO_MODE_EXPOSURE()` | build 1311
Resets the exposure to the value when exposure lock was enabled
