# CAM natives (233)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_CAM_SPLINE_NODE
`0xF1F57F9D230F9CD1` | `void ADD_CAM_SPLINE_NODE(Cam camera, float x, float y, float z, float xRot, float yRot, float zRot, int length, int p8, int p9)` | build 1207
p7 (length) determines the length of the spline, affects camera path and duration of transition between previous node and this one

p8 big values ~100 will slow down the camera movement before reaching this node

p9 != 0 seems to override the rotation/pitch (bool?)

## ALLOW_MOTION_BLUR_DECAY
`0x42ED56B02E05D109` | `void ALLOW_MOTION_BLUR_DECAY(Cam cam, BOOL p1)` | build 1207

## ATTACH_CAM_TO_ENTITY
`0xFDC0DF7F6FB0A592` | `void ATTACH_CAM_TO_ENTITY(Cam cam, Entity entity, float xOffset, float yOffset, float zOffset, BOOL isRelative)` | build 1207
Last param determines if its relative to the Entity

## ATTACH_CAM_TO_PED_BONE
`0xDFC1E4A44C0324CA` | `void ATTACH_CAM_TO_PED_BONE(Cam cam, Ped ped, int boneIndex, float x, float y, float z, BOOL heading)` | build 1207
boneIndex: https://github.com/femga/rdr3_discoveries/tree/master/boneNames

## CINEMATIC_LOCATION_OVERRIDE_TARGET_ENTITY_THIS_UPDATE
`0x0B0F914459731F60` | `void CINEMATIC_LOCATION_OVERRIDE_TARGET_ENTITY_THIS_UPDATE(const char* name, Entity entity)` | build 1311
Only used in R* Script fm_mission_controller

## CINEMATIC_LOCATION_STOP_SCRIPTED_SHOT_EVENT
`0x6D4D25C2137FF511` | `void CINEMATIC_LOCATION_STOP_SCRIPTED_SHOT_EVENT(Any p0, Any p1, Any p2)` | build 1207

## CINEMATIC_LOCATION_TRIGGER_SCRIPTED_SHOT_EVENT
`0x02389579A53C3276` | `void CINEMATIC_LOCATION_TRIGGER_SCRIPTED_SHOT_EVENT(const char* dictionary, const char* shotName, const char* cameraName, Any p3)` | build 1207

## CREATE_CAM
`0xE72CDBA7F0A02DD6` | `Cam CREATE_CAM(const char* camName, BOOL p1)` | build 1207

## CREATE_CAMERA
`0x57CDF879EA466C46` | `Cam CREATE_CAMERA(Hash camHash, BOOL p1)` | build 1207

## CREATE_CAMERA_WITH_PARAMS
`0x98B99B9F27E2D60B` | `Cam CREATE_CAMERA_WITH_PARAMS(Hash camHash, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float fov, BOOL p8, Any p9)` | build 1207

## CREATE_CAM_WITH_PARAMS
`0x40C23491CE83708E` | `Cam CREATE_CAM_WITH_PARAMS(const char* camName, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float fov, BOOL p8, int p9)` | build 1207

## DESTROY_ALL_CAMS
`0x163600D6E136C9F8` | `void DESTROY_ALL_CAMS(BOOL p0)` | build 1207
BOOL param indicates whether the cam should be destroyed if it belongs to the calling script.

## DESTROY_CAM
`0x4E67E0B6D7FD5145` | `void DESTROY_CAM(Cam cam, BOOL p1)` | build 1207
BOOL param indicates whether the cam should be destroyed if it belongs to the calling script.

## DETACH_CAM
`0x05B41DDBEB559556` | `void DETACH_CAM(Cam cam)` | build 1207

## DISABLE_CAM_COLLISION_FOR_OBJECT
`0x7E3F546ACFE6C8D9` | `void DISABLE_CAM_COLLISION_FOR_OBJECT(Entity entity)` | build 1207

## DISABLE_CINEMATIC_BONNET_CAMERA_THIS_UPDATE
`0xA5929C2E57AC90D1` | `void DISABLE_CINEMATIC_BONNET_CAMERA_THIS_UPDATE()` | build 1207
Old name: _DISABLE_VEHICLE_FIRST_PERSON_CAM_THIS_FRAME

## DISABLE_FIRST_PERSON_FLASH_EFFECT_THIS_UPDATE
`0x77D65669A05D1A1A` | `void DISABLE_FIRST_PERSON_FLASH_EFFECT_THIS_UPDATE()` | build 1207
nullsub, doesn't do anything

## DISABLE_ON_FOOT_FIRST_PERSON_VIEW_THIS_UPDATE
`0x9C473089A934C930` | `void DISABLE_ON_FOOT_FIRST_PERSON_VIEW_THIS_UPDATE()` | build 1207
Old name: _DISABLE_FIRST_PERSON_CAM_THIS_FRAME

## DOES_CAM_EXIST
`0x153AD457764FD704` | `BOOL DOES_CAM_EXIST(Cam cam)` | build 1207
Returns whether or not the passed camera handle exists.

## DO_SCREEN_FADE_IN
`0x6A053CF596F67DF7` | `void DO_SCREEN_FADE_IN(int duration)` | build 1207
Fades the screen in.

duration: The time the fade should take, in milliseconds.

## DO_SCREEN_FADE_OUT
`0x40C719A5E410B9E4` | `void DO_SCREEN_FADE_OUT(int duration)` | build 1207
Fades the screen out.

duration: The time the fade should take, in milliseconds.

## FORCE_CINEMATIC_RENDERING_THIS_UPDATE
`0x702B75DC9D3EDE56` | `void FORCE_CINEMATIC_RENDERING_THIS_UPDATE(BOOL p0)` | build 1207

## GET_CAM_COORD
`0x6B12F11C2A9F0344` | `Vector3 GET_CAM_COORD(Cam cam)` | build 1207

## GET_CAM_FOV
`0x8101D32A0A6B0F60` | `float GET_CAM_FOV(Cam cam)` | build 1207

## GET_CAM_ROT
`0x9BF96B57254E7889` | `Vector3 GET_CAM_ROT(Cam cam, int rotationOrder)` | build 1207
rotationOrder: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eEulerRotationOrder

## GET_CAM_SPLINE_PHASE
`0x095EDCD24D90033A` | `float GET_CAM_SPLINE_PHASE(Cam cam)` | build 1207
Can use this with SET_CAM_SPLINE_PHASE to set the float it this native returns.

(returns 1.0f when no nodes has been added, reached end of non existing spline)

## GET_FINAL_RENDERED_CAM_COORD
`0x5352E025EC2B416F` | `Vector3 GET_FINAL_RENDERED_CAM_COORD()` | build 1207

## GET_FINAL_RENDERED_CAM_FOV
`0x04AF77971E508F6A` | `float GET_FINAL_RENDERED_CAM_FOV()` | build 1207

## GET_FINAL_RENDERED_CAM_ROT
`0x602685BD85DD26CA` | `Vector3 GET_FINAL_RENDERED_CAM_ROT(int rotationOrder)` | build 1207

## GET_FIRST_PERSON_AIM_CAM_ZOOM_FACTOR
`0xB4132CA1B0EE1365` | `float GET_FIRST_PERSON_AIM_CAM_ZOOM_FACTOR()` | build 1207

## GET_GAMEPLAY_CAM_COORD
`0x595320200B98596E` | `Vector3 GET_GAMEPLAY_CAM_COORD()` | build 1207

## GET_GAMEPLAY_CAM_FOV
`0xF6A96E5ACEEC6E50` | `float GET_GAMEPLAY_CAM_FOV()` | build 1207

## GET_GAMEPLAY_CAM_RELATIVE_HEADING
`0xC4ABF536048998AA` | `float GET_GAMEPLAY_CAM_RELATIVE_HEADING()` | build 1207

## GET_GAMEPLAY_CAM_RELATIVE_PITCH
`0x99AADEBBA803F827` | `float GET_GAMEPLAY_CAM_RELATIVE_PITCH()` | build 1207

## GET_GAMEPLAY_CAM_ROT
`0x0252D2B5582957A6` | `Vector3 GET_GAMEPLAY_CAM_ROT(int rotationOrder)` | build 1207

## GET_LETTER_BOX_RATIO
`0xA2B1C7EF759A63CE` | `float GET_LETTER_BOX_RATIO()` | build 1207
More info: see HAS_LETTER_BOX

## GET_RENDERING_CAM
`0x03A8931ECC8015D6` | `Cam GET_RENDERING_CAM()` | build 1207

## HAS_LETTER_BOX
`0x81DCFD13CF39920E` | `BOOL HAS_LETTER_BOX()` | build 1207
More info: https://en.wikipedia.org/wiki/Letterboxing_(filming)

## INVALIDATE_CINEMATIC_VEHICLE_IDLE_MODE
`0x634F4A0562CF19B8` | `void INVALIDATE_CINEMATIC_VEHICLE_IDLE_MODE()` | build 1207
Old name: _INVALIDATE_VEHICLE_IDLE_CAM

## IS_AIM_CAM_ACTIVE
`0x698F456FB909E077` | `BOOL IS_AIM_CAM_ACTIVE()` | build 1232

## IS_CAM_ACTIVE
`0x63EFCC7E1810B8E6` | `BOOL IS_CAM_ACTIVE(Cam cam)` | build 1207
Returns whether or not the passed camera handle is active.

## IS_CAM_INTERPOLATING
`0x578F8F1CAA17BD2B` | `BOOL IS_CAM_INTERPOLATING(Cam cam)` | build 1207

## IS_CAM_RENDERING
`0x4415F8A6C536D39F` | `BOOL IS_CAM_RENDERING(Cam cam)` | build 1207

## IS_CAM_SHAKING
`0x2EEB402BD7320159` | `BOOL IS_CAM_SHAKING(Cam cam)` | build 1207

## IS_CINEMATIC_CAM_RENDERING
`0xBF7C780731AADBF8` | `BOOL IS_CINEMATIC_CAM_RENDERING()` | build 1207

## IS_DEATH_FAIL_CAMERA_RUNNING
`0x139EFB0A71DD9011` | `BOOL IS_DEATH_FAIL_CAMERA_RUNNING()` | build 1207

## IS_FIRST_PERSON_AIM_CAM_ACTIVE
`0xF63134C54B6EC212` | `BOOL IS_FIRST_PERSON_AIM_CAM_ACTIVE()` | build 1207

## IS_FIRST_PERSON_CAMERA_ACTIVE
`0xA24C1D341C6E0D53` | `BOOL IS_FIRST_PERSON_CAMERA_ACTIVE(Any p0, Any p1, Any p2)` | build 1207

## IS_FOLLOW_VEHICLE_CAM_ACTIVE
`0xA40C2F51FB589E9A` | `BOOL IS_FOLLOW_VEHICLE_CAM_ACTIVE()` | build 1207

## IS_GAMEPLAY_CAM_LOOKING_BEHIND
`0x8FE0D24FFD04D5A2` | `BOOL IS_GAMEPLAY_CAM_LOOKING_BEHIND()` | build 1207

## IS_GAMEPLAY_CAM_RENDERING
`0x8660EA714834E412` | `BOOL IS_GAMEPLAY_CAM_RENDERING()` | build 1207

## IS_GAMEPLAY_CAM_SHAKING
`0xEA4C5F4AA0A4DBEF` | `BOOL IS_GAMEPLAY_CAM_SHAKING()` | build 1207

## IS_GAMEPLAY_HINT_ACTIVE
`0x2E04AB5FEE042D4A` | `BOOL IS_GAMEPLAY_HINT_ACTIVE()` | build 1207

## IS_INTERPOLATING_FROM_SCRIPT_CAMS
`0x251241CAEC707106` | `BOOL IS_INTERPOLATING_FROM_SCRIPT_CAMS()` | build 1207

## IS_INTERPOLATING_TO_SCRIPT_CAMS
`0x43AB9D5A7D415478` | `BOOL IS_INTERPOLATING_TO_SCRIPT_CAMS()` | build 1207

## IS_SCREEN_FADED_IN
`0x37F9A426FBCF4AF2` | `BOOL IS_SCREEN_FADED_IN()` | build 1207

## IS_SCREEN_FADED_OUT
`0xF5472C80DF2FF847` | `BOOL IS_SCREEN_FADED_OUT()` | build 1207

## IS_SCREEN_FADING_IN
`0x0CECCC63FFA2EF24` | `BOOL IS_SCREEN_FADING_IN()` | build 1207

## IS_SCREEN_FADING_OUT
`0x02F39BEFE7B88D00` | `BOOL IS_SCREEN_FADING_OUT()` | build 1207

## IS_SPHERE_VISIBLE
`0x2E941B5FFA2989C6` | `BOOL IS_SPHERE_VISIBLE(float x, float y, float z, float radius)` | build 1207

## PLAY_CAM_ANIM
`0xA263DDF694D563F6` | `BOOL PLAY_CAM_ANIM(Cam cam, const char* animName, const char* animDictionary, float x, float y, float z, float xRot, float yRot, float zRot, int animFlags, int rotOrder)` | build 1207

## POINT_CAM_AT_COORD
`0x948B39341C3A40C2` | `void POINT_CAM_AT_COORD(Cam cam, float x, float y, float z)` | build 1207

## POINT_CAM_AT_ENTITY
`0xFC2867E6074D3A61` | `void POINT_CAM_AT_ENTITY(Cam cam, Entity entity, float p2, float p3, float p4, BOOL p5)` | build 1207

## RENDER_SCRIPT_CAMS
`0x33281167E4942E4F` | `void RENDER_SCRIPT_CAMS(BOOL render, BOOL ease, int easeTime, BOOL p3, BOOL p4, int renderingFlags)` | build 1207
ease - smooth transition between the camera's positions
easeTime - Time in milliseconds for the transition to happen

If you have created a script (rendering) camera, and want to go back to the 
character (gameplay) camera, call this native with render set to FALSE.
Setting ease to TRUE will smooth the transition.

## SET_CAM_ACTIVE
`0x87295BCA613800C8` | `void SET_CAM_ACTIVE(Cam cam, BOOL active)` | build 1207
Set camera as active/inactive.

## SET_CAM_ACTIVE_WITH_INTERP
`0x8B15AE2987C1AC8F` | `void SET_CAM_ACTIVE_WITH_INTERP(Cam camTo, Cam camFrom, int duration, int easeLocation, int easeRotation)` | build 1207

## SET_CAM_AFFECTS_AIMING
`0x3CB9E8BDE5E76F33` | `void SET_CAM_AFFECTS_AIMING(Cam cam, BOOL toggle)` | build 1207
Allows you to aim and shoot at the direction the camera is facing.

## SET_CAM_CONTROLS_MINI_MAP_HEADING
`0x1B8F3CE5A6001298` | `void SET_CAM_CONTROLS_MINI_MAP_HEADING(Cam cam, BOOL p1)` | build 1207

## SET_CAM_COORD
`0xF9EE7D419EE49DE6` | `void SET_CAM_COORD(Cam cam, float posX, float posY, float posZ)` | build 1207
Sets the position of the cam.

## SET_CAM_FAR_CLIP
`0x5E32817BF6302111` | `void SET_CAM_FAR_CLIP(Cam cam, float farClip)` | build 1207

## SET_CAM_FOV
`0x27666E5988D9D429` | `void SET_CAM_FOV(Cam cam, float fieldOfView)` | build 1207
Sets the field of view of the cam.

Min: 1.0f
Max: 130.0f

## SET_CAM_MOTION_BLUR_STRENGTH
`0x45FD891364181F9E` | `void SET_CAM_MOTION_BLUR_STRENGTH(Cam cam, float strength)` | build 1207

## SET_CAM_NEAR_CLIP
`0xA924028272A61364` | `void SET_CAM_NEAR_CLIP(Cam cam, float nearClip)` | build 1207

## SET_CAM_PARAMS
`0xA47BBFFFB83D4D0A` | `void SET_CAM_PARAMS(Cam cam, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float fieldOfView, Any p8, int graphType1, int graphType2, int rotationOrder, Any p12, Any p13)` | build 1207

## SET_CAM_ROT
`0x63DFA6810AD78719` | `void SET_CAM_ROT(Cam cam, float rotX, float rotY, float rotZ, int rotationOrder)` | build 1207
Sets the rotation of the cam.

## SET_CAM_SPLINE_DURATION
`0xFF6311652CA91015` | `void SET_CAM_SPLINE_DURATION(Cam cam, int timeDuration)` | build 1207

## SET_CAM_SPLINE_PHASE
`0xF1898A68E7C15636` | `void SET_CAM_SPLINE_PHASE(Cam cam, float p1)` | build 1207

## SET_CAM_SPLINE_SMOOTHING_STYLE
`0x84B3645618E726B0` | `void SET_CAM_SPLINE_SMOOTHING_STYLE(Cam cam, int smoothingStyle)` | build 1207

## SET_CINEMATIC_BUTTON_ACTIVE
`0xB90411F480457A6C` | `void SET_CINEMATIC_BUTTON_ACTIVE(BOOL p0)` | build 1207

## SET_CINEMATIC_MODE_ACTIVE
`0xCE7A90B160F75046` | `void SET_CINEMATIC_MODE_ACTIVE(BOOL p0)` | build 1207

## SET_FIRST_PERSON_AIM_CAM_RELATIVE_HEADING_LIMITS_THIS_UPDATE
`0x05BD5E4088B30A66` | `void SET_FIRST_PERSON_AIM_CAM_RELATIVE_HEADING_LIMITS_THIS_UPDATE(float p0, float p1)` | build 1207

## SET_FIRST_PERSON_AIM_CAM_RELATIVE_PITCH_LIMITS_THIS_UPDATE
`0x715B7F5E8BED32A2` | `void SET_FIRST_PERSON_AIM_CAM_RELATIVE_PITCH_LIMITS_THIS_UPDATE(float p0, float p1)` | build 1207
Old name: _SET_FIRST_PERSON_CAM_PITCH_RANGE

## SET_GAMEPLAY_CAM_FOLLOW_PED_THIS_UPDATE
`0x82E41D6ADE924FCA` | `void SET_GAMEPLAY_CAM_FOLLOW_PED_THIS_UPDATE(Ped ped)` | build 1207
Forces gameplay cam to specified ped as if you were the ped or spectating it

## SET_GAMEPLAY_CAM_IGNORE_ENTITY_COLLISION_THIS_UPDATE
`0xD904F75DBD7AB865` | `void SET_GAMEPLAY_CAM_IGNORE_ENTITY_COLLISION_THIS_UPDATE(Entity entity)` | build 1207
Old name: _DISABLE_CAM_COLLISION_FOR_ENTITY

## SET_GAMEPLAY_CAM_MAX_MOTION_BLUR_STRENGTH_THIS_UPDATE
`0x8459B3E64257B21D` | `void SET_GAMEPLAY_CAM_MAX_MOTION_BLUR_STRENGTH_THIS_UPDATE(float p0)` | build 1207

## SET_GAMEPLAY_CAM_RELATIVE_HEADING
`0x5D1EB123EAC5D071` | `void SET_GAMEPLAY_CAM_RELATIVE_HEADING(float heading, float p1)` | build 1207
Sets the camera position relative to heading in float from -360 to +360.

Heading is always 0 in aiming camera.

## SET_GAMEPLAY_CAM_RELATIVE_PITCH
`0xFB760AF4F537B8BF` | `void SET_GAMEPLAY_CAM_RELATIVE_PITCH(float x, float Value2)` | build 1207
Sets the camera pitch.

Parameters:
x = pitches the camera on the x axis.
Value2 = always seems to be hex 0x3F800000 (1.000000 float).

## SET_GAMEPLAY_CAM_SHAKE_AMPLITUDE
`0x570E35F5C4A44838` | `void SET_GAMEPLAY_CAM_SHAKE_AMPLITUDE(float amplitude)` | build 1207
Sets the amplitude for the gameplay (i.e. 3rd or 1st) camera to shake.

## SET_GAMEPLAY_COORD_HINT
`0xFA33B8C69A4A6A0F` | `void SET_GAMEPLAY_COORD_HINT(float x, float y, float z, int duration, int blendOutDuration, int blendInDuration, Hash p6)` | build 1207
Hash used in finale1.ysc: 1726668277

## SET_GAMEPLAY_ENTITY_HINT
`0xD1F7F32640ADFD12` | `void SET_GAMEPLAY_ENTITY_HINT(Entity entity, float xOffset, float yOffset, float zOffset, BOOL p4, int p5, int p6, int p7, Any p8)` | build 1207
p6 & p7 - possibly length or time

## SET_GAMEPLAY_HINT_BASE_ORBIT_PITCH_OFFSET
`0x421192A2DA48FD01` | `void SET_GAMEPLAY_HINT_BASE_ORBIT_PITCH_OFFSET(float p0)` | build 1207

## SET_GAMEPLAY_HINT_CAMERA_RELATIVE_SIDE_OFFSET
`0xF86B6F93727C59C9` | `void SET_GAMEPLAY_HINT_CAMERA_RELATIVE_SIDE_OFFSET(float p0)` | build 1207
Old name: _SET_GAMEPLAY_HINT_ANIM_OFFSETX

## SET_GAMEPLAY_HINT_CAMERA_RELATIVE_VERTICAL_OFFSET
`0x29E74F819150CC32` | `void SET_GAMEPLAY_HINT_CAMERA_RELATIVE_VERTICAL_OFFSET(float p0)` | build 1207
Old name: _SET_GAMEPLAY_HINT_ANIM_OFFSETY

## SET_GAMEPLAY_HINT_FOLLOW_DISTANCE_SCALAR
`0xDDDC54181868F81F` | `void SET_GAMEPLAY_HINT_FOLLOW_DISTANCE_SCALAR(float p0)` | build 1207

## SET_GAMEPLAY_HINT_FOV
`0x661E58BC6F00A49A` | `void SET_GAMEPLAY_HINT_FOV(float FOV)` | build 1207

## SET_GAMEPLAY_OBJECT_HINT
`0xC40551D65F2BF297` | `void SET_GAMEPLAY_OBJECT_HINT(Any p0, float p1, float p2, float p3, BOOL p4, Any p5, Any p6, Any p7)` | build 1207

## SET_GAMEPLAY_PED_HINT
`0x90FB951648851733` | `void SET_GAMEPLAY_PED_HINT(Ped p0, float x1, float y1, float z1, BOOL p4, Any p5, Any p6, Any p7)` | build 1207

## SET_GAMEPLAY_VEHICLE_HINT
`0xE2B2BB7DAC280515` | `void SET_GAMEPLAY_VEHICLE_HINT(Any p0, float p1, float p2, float p3, BOOL p4, Any p5, Any p6, Any p7)` | build 1207

## SET_IN_VEHICLE_CAM_STATE_THIS_UPDATE
`0xFA1D5E8D1C3CCD67` | `void SET_IN_VEHICLE_CAM_STATE_THIS_UPDATE(Vehicle vehicle, int p1)` | build 1207
Forces gameplay cam to specified vehicle as if you were in it

## SET_SCRIPTED_CAMERA_IS_FIRST_PERSON_THIS_FRAME
`0x1DD95A8D6B24A0C9` | `void SET_SCRIPTED_CAMERA_IS_FIRST_PERSON_THIS_FRAME(BOOL p0)` | build 1207

## SET_THIRD_PERSON_CAM_ORBIT_DISTANCE_LIMITS_THIS_UPDATE
`0x2126C740A4AC370B` | `void SET_THIRD_PERSON_CAM_ORBIT_DISTANCE_LIMITS_THIS_UPDATE(float p0, float distance)` | build 1207
Old name: _ANIMATE_GAMEPLAY_CAM_ZOOM

## SET_THIRD_PERSON_CAM_RELATIVE_HEADING_LIMITS_THIS_UPDATE
`0x14F3947318CA8AD2` | `void SET_THIRD_PERSON_CAM_RELATIVE_HEADING_LIMITS_THIS_UPDATE(float minimum, float maximum)` | build 1207
minimum: Degrees between -180f and 180f.
maximum: Degrees between -180f and 180f.

Clamps the gameplay camera's current yaw.

Eg. _CLAMP_GAMEPLAY_CAM_YAW(0.0f, 0.0f) will set the horizontal angle directly behind the player.

Old name: _CLAMP_GAMEPLAY_CAM_YAW

## SET_THIRD_PERSON_CAM_RELATIVE_PITCH_LIMITS_THIS_UPDATE
`0x326C7AA308F3DF6A` | `void SET_THIRD_PERSON_CAM_RELATIVE_PITCH_LIMITS_THIS_UPDATE(float minimum, float maximum)` | build 1207
minimum: Degrees between -90f and 90f.
maximum: Degrees between -90f and 90f.

Clamps the gameplay camera's current pitch.

Eg. _CLAMP_GAMEPLAY_CAM_PITCH(0.0f, 0.0f) will set the vertical angle directly behind the player.

Old name: _CLAMP_GAMEPLAY_CAM_PITCH

## SET_WIDESCREEN_BORDERS
`0xD7F4D54CF80AFA34` | `void SET_WIDESCREEN_BORDERS(BOOL p0, int p1)` | build 1207

## SHAKE_CAM
`0xF9A7BCF5D050D4E7` | `void SHAKE_CAM(Cam cam, const char* type, float amplitude)` | build 1207

## SHAKE_GAMEPLAY_CAM
`0xD9B31B4650520529` | `void SHAKE_GAMEPLAY_CAM(const char* shakeName, float intensity)` | build 1207

## STOP_CAM_POINTING
`0xCA1B30A3357C71F1` | `void STOP_CAM_POINTING(Cam cam)` | build 1207

## STOP_CAM_SHAKING
`0xB78CC4B4706614B0` | `void STOP_CAM_SHAKING(Cam cam, BOOL p1)` | build 1207

## STOP_CODE_GAMEPLAY_HINT
`0x93759A83D0D844E7` | `void STOP_CODE_GAMEPLAY_HINT(BOOL p0)` | build 1207

## STOP_GAMEPLAY_CAM_SHAKING
`0xE0DE43D290FB65F9` | `void STOP_GAMEPLAY_CAM_SHAKING(BOOL p0)` | build 1207

## STOP_GAMEPLAY_HINT
`0x1BCEC33D54CFCA8A` | `void STOP_GAMEPLAY_HINT(BOOL p0)` | build 1207

## STOP_RENDERING_SCRIPT_CAMS_USING_CATCH_UP
`0x8C7C7FF7CF0E5153` | `void STOP_RENDERING_SCRIPT_CAMS_USING_CATCH_UP(BOOL render, float distance, int blendBackSmoothingType, BOOL p3, BOOL p4, BOOL p5)` | build 1207
This native makes the gameplay camera zoom into first person/third person with a special effect.
blendBackSmoothingType: https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/eBlendBackSmoothing

## _0x0060B31968E60E41
`0x0060B31968E60E41` | `BOOL _0x0060B31968E60E41(char* shakeName)` | build 1207
shakeNames in script_rel: CORRECTOR_SHAKE, MINIGAME_BOUNTY_SHAKE, POV_DRUNK_SHAKE, DRUNK_SHAKE, MINIGAME_TRAIN_SHAKE
_IS_GAMEPLAY_*

## _0x04084490CC302CFB
`0x04084490CC302CFB` | `void _0x04084490CC302CFB()` | build 1207

## _0x06557F6D96C86881
`0x06557F6D96C86881` | `void _0x06557F6D96C86881()` | build 1207

## _0x0961B089947BA6D0
`0x0961B089947BA6D0` | `void _0x0961B089947BA6D0(Any p0)` | build 1207

## _0x0F1FFEF5D54AE832
`0x0F1FFEF5D54AE832` | `void _0x0F1FFEF5D54AE832()` | build 1207
NPLOI_UPDATE__GUN_SPINNING_PREVIEW - Adjusting Camera / Ped Reset Flags This Frame
_DISABLE_*

## _0x0FF7125F07DEB84F
`0x0FF7125F07DEB84F` | `void _0x0FF7125F07DEB84F(Any p0, Any p1)` | build 1207

## _0x1204EB53A5FBC63D
`0x1204EB53A5FBC63D` | `BOOL _0x1204EB53A5FBC63D()` | build 1207
Used for DUELING_LOCK_CAMERA_CONTROLS_THIS_FRAME: Disabling look/aim controls
_IS_SC(REEN_)* (?)

## _0x14C4A49E36C29E49
`0x14C4A49E36C29E49` | `Any _0x14C4A49E36C29E49()` | build 1207

## _0x16E9ABDD34DDD931
`0x16E9ABDD34DDD931` | `void _0x16E9ABDD34DDD931()` | build 1207

## _0x1811A02277A9E49D
`0x1811A02277A9E49D` | `BOOL _0x1811A02277A9E49D()` | build 1207

## _0x18C3DFAC458783BB
`0x18C3DFAC458783BB` | `void _0x18C3DFAC458783BB()` | build 1207

## _0x190F7DA1AC09A8EF
`0x190F7DA1AC09A8EF` | `Any _0x190F7DA1AC09A8EF()` | build 1207

## _0x1D931B7CC0EE3956
`0x1D931B7CC0EE3956` | `BOOL _0x1D931B7CC0EE3956(char* dictionary, char* shotName, char* cameraName)` | build 1436

## _0x1D9F72DD4FD9A9D7
`0x1D9F72DD4FD9A9D7` | `void _0x1D9F72DD4FD9A9D7(Any p0)` | build 1207

## _0x1F6EBD94680252CE
`0x1F6EBD94680252CE` | `void _0x1F6EBD94680252CE(Any p0, Any p1)` | build 1207

## _0x1FC6C727D30FFDDE
`0x1FC6C727D30FFDDE` | `void _0x1FC6C727D30FFDDE(Any p0)` | build 1207

## _0x29E6655DF3590B0D
`0x29E6655DF3590B0D` | `void _0x29E6655DF3590B0D(Any p0)` | build 1207

## _0x2AB7C81B3F70570C
`0x2AB7C81B3F70570C` | `Any _0x2AB7C81B3F70570C()` | build 1207

## _0x2DD3149DC34A3F4C
`0x2DD3149DC34A3F4C` | `void _0x2DD3149DC34A3F4C(Any p0)` | build 1207

## _0x39073DA4EDDBC91D
`0x39073DA4EDDBC91D` | `void _0x39073DA4EDDBC91D(Any p0)` | build 1207

## _0x3B8E3AD9677CE12B
`0x3B8E3AD9677CE12B` | `void _0x3B8E3AD9677CE12B(Any p0, Any p1, Any p2)` | build 1207

## _0x3C486E334520579D
`0x3C486E334520579D` | `void _0x3C486E334520579D()` | build 1207

## _0x3C8F74E8FE751614
`0x3C8F74E8FE751614` | `void _0x3C8F74E8FE751614()` | build 1207

## _0x4138EE36BC3DC0A7
`0x4138EE36BC3DC0A7` | `Any _0x4138EE36BC3DC0A7(Any p0, Any p1)` | build 1207

## _0x41E452A3C580D1A7
`0x41E452A3C580D1A7` | `void _0x41E452A3C580D1A7()` | build 1207

## _0x450769C833D58844
`0x450769C833D58844` | `Any _0x450769C833D58844()` | build 1207

## _0x465F04F68AD38197
`0x465F04F68AD38197` | `Any _0x465F04F68AD38197(char* dictionary, char* shotName, int duration)` | build 1207

## _0x4D2F46D1B28D90FB
`0x4D2F46D1B28D90FB` | `void _0x4D2F46D1B28D90FB(Any p0, Any p1)` | build 1207

## _0x5060FA977CEA4455
`0x5060FA977CEA4455` | `Any _0x5060FA977CEA4455()` | build 1207

## _0x5B637D6F3B67716A
`0x5B637D6F3B67716A` | `void _0x5B637D6F3B67716A(Any p0)` | build 1207

## _0x6072B7420A83A03F
`0x6072B7420A83A03F` | `Any _0x6072B7420A83A03F()` | build 1207

## _0x632BE8D84846FA56
`0x632BE8D84846FA56` | `void _0x632BE8D84846FA56()` | build 1207
Zooms in the gameplay camera to the next zoom level?
USE_* - WAS_*

## _0x63E5841A9264D016
`0x63E5841A9264D016` | `void _0x63E5841A9264D016(BOOL toggle)` | build 1207
Maintains the death camera after respawn

## _0x641092322A8852AB
`0x641092322A8852AB` | `void _0x641092322A8852AB()` | build 1207

## _0x6519238858AF5479
`0x6519238858AF5479` | `void _0x6519238858AF5479(Any p0)` | build 1207

## _0x6CAB0BA160B168D2
`0x6CAB0BA160B168D2` | `void _0x6CAB0BA160B168D2()` | build 1207

## _0x6DFD37E586D4F44F
`0x6DFD37E586D4F44F` | `Any _0x6DFD37E586D4F44F()` | build 1207

## _0x70A6658D476C6187
`0x70A6658D476C6187` | `void _0x70A6658D476C6187()` | build 1207

## _0x71D71E08A7ED5BD7
`0x71D71E08A7ED5BD7` | `void _0x71D71E08A7ED5BD7(BOOL toggle)` | build 1207
Zooms in the third person camera closer to ground level.
Must be called every frame to interpolate.
Pass false to reset.

## _0x728491FB3DFFEF99
`0x728491FB3DFFEF99` | `void _0x728491FB3DFFEF99(Any p0)` | build 1207

## _0x73FF6BE63DC18819
`0x73FF6BE63DC18819` | `Any _0x73FF6BE63DC18819()` | build 1207

## _0x796085220ADCC847
`0x796085220ADCC847` | `Any _0x796085220ADCC847()` | build 1207

## _0x7CE9DC58E3E4755F
`0x7CE9DC58E3E4755F` | `Any _0x7CE9DC58E3E4755F()` | build 1207

## _0x7E40A01B11398FCB
`0x7E40A01B11398FCB` | `void _0x7E40A01B11398FCB()` | build 1207

## _0x80D7A3E39B120BC4
`0x80D7A3E39B120BC4` | `Any _0x80D7A3E39B120BC4()` | build 1207

## _0x8505E05FC8822843
`0x8505E05FC8822843` | `void _0x8505E05FC8822843(Any p0)` | build 1207

## _0x88544C0E3291DCAE
`0x88544C0E3291DCAE` | `void _0x88544C0E3291DCAE(BOOL p0)` | build 1207
UPDATE_PLAYER_PLAYING_STATE - Releasing Lasso Hint Cam
Return type char in ida
_SET_GAMEPLAY_HINT_*

## _0x8B1A5FE7E41E52B2
`0x8B1A5FE7E41E52B2` | `Any _0x8B1A5FE7E41E52B2()` | build 1311

## _0x8E036B41C37D0E5F
`0x8E036B41C37D0E5F` | `void _0x8E036B41C37D0E5F(Any p0)` | build 1207

## _0x975F6EBB62632FE3
`0x975F6EBB62632FE3` | `BOOL _0x975F6EBB62632FE3()` | build 1207
_IS_SCRIPTED_S*

## _0x9AC65A36D3C0C189
`0x9AC65A36D3C0C189` | `void _0x9AC65A36D3C0C189(Any p0)` | build 1207

## _0xA54D643D0773EB65
`0xA54D643D0773EB65` | `void _0xA54D643D0773EB65(char* dictionary, char* shotName, int duration)` | build 1207

## _0xA8BA2E0204D8486F
`0xA8BA2E0204D8486F` | `void _0xA8BA2E0204D8486F()` | build 1355
NPLOI_UPDATE__GUN_SPINNING_PREVIEW - Adjusting Camera / Ped Reset Flags This Frame
_DISABLE_*

## _0xAC77757C05DE9E5A
`0xAC77757C05DE9E5A` | `void _0xAC77757C05DE9E5A(const char* cameraDictionary)` | build 1207

## _0xB6A80E1E3A5444F1
`0xB6A80E1E3A5444F1` | `Any _0xB6A80E1E3A5444F1()` | build 1311

## _0xB85C13E0BF1F2A1C
`0xB85C13E0BF1F2A1C` | `void _0xB85C13E0BF1F2A1C(Any p0)` | build 1207

## _0xC205B3C54C6A4E37
`0xC205B3C54C6A4E37` | `void _0xC205B3C54C6A4E37(Any p0)` | build 1207

## _0xC252C0CC969AF79A
`0xC252C0CC969AF79A` | `void _0xC252C0CC969AF79A(Any p0)` | build 1207

## _0xC285FD21294A1C49
`0xC285FD21294A1C49` | `BOOL _0xC285FD21294A1C49(const char* cameraDictionary)` | build 1207

## _0xC3742F1FDF0A6824
`0xC3742F1FDF0A6824` | `void _0xC3742F1FDF0A6824()` | build 1355
Camera will be or is running

## _0xC3AEBB276825A359
`0xC3AEBB276825A359` | `BOOL _0xC3AEBB276825A359(const char* dictionary, const char* shotName, int duration)` | build 1436

## _0xCF69EA05CD9C33C9
`0xCF69EA05CD9C33C9` | `void _0xCF69EA05CD9C33C9()` | build 1207

## _0xDB382FE20C2DA222
`0xDB382FE20C2DA222` | `void _0xDB382FE20C2DA222(Any p0)` | build 1207

## _0xDC62CD70658E7A02
`0xDC62CD70658E7A02` | `Any _0xDC62CD70658E7A02()` | build 1207

## _0xDF7F5BE9150E47E4
`0xDF7F5BE9150E47E4` | `void _0xDF7F5BE9150E47E4(Any p0)` | build 1207

## _0xE28F73212A813E82
`0xE28F73212A813E82` | `void _0xE28F73212A813E82(Any p0, Any p1, Any p2, Any p3)` | build 1207

## _0xE2BB2D6A9FE2ECDE
`0xE2BB2D6A9FE2ECDE` | `void _0xE2BB2D6A9FE2ECDE(Any p0)` | build 1207

## _0xE6F364DE6C2FDEFE
`0xE6F364DE6C2FDEFE` | `void _0xE6F364DE6C2FDEFE()` | build 1207

## _0xEA113BF9B0C0C5D7
`0xEA113BF9B0C0C5D7` | `Any _0xEA113BF9B0C0C5D7(const char* dictionary, const char* shotName, int duration)` | build 1207

## _0xEF9A3132A0AA6B19
`0xEF9A3132A0AA6B19` | `Any _0xEF9A3132A0AA6B19()` | build 1207

## _0xF1A6FEEDF3776EF9
`0xF1A6FEEDF3776EF9` | `void _0xF1A6FEEDF3776EF9()` | build 1207

## _0xF48664E9C83825E3
`0xF48664E9C83825E3` | `void _0xF48664E9C83825E3(Any p0, Any p1)` | build 1207

## _0xF824530B612FE0CE
`0xF824530B612FE0CE` | `Any _0xF824530B612FE0CE()` | build 1207

## _0xFC3F638BE2B6BB02
`0xFC3F638BE2B6BB02` | `void _0xFC3F638BE2B6BB02()` | build 1207

## _0xFEB8646818294C75
`0xFEB8646818294C75` | `void _0xFEB8646818294C75(Any p0, Any p1)` | build 1207

## _0xFEFDDC6E8FDF8A75
`0xFEFDDC6E8FDF8A75` | `void _0xFEFDDC6E8FDF8A75(const char* shakeName, float intensity)` | build 1207
_SET_GAMEPLAY_P* - _SET_GAMEPLAY_V*

## _CAM_CREATE
`0xB8B207C34285E978` | `void _CAM_CREATE(const char* cameraDictionary)` | build 1207

## _CAM_CREATE_2
`0x7B0279170961A73F` | `void _CAM_CREATE_2(const char* cameraDictionary)` | build 1207

## _CAM_DESTROY
`0x0A5A4F1979ABB40E` | `void _CAM_DESTROY(const char* cameraDictionary)` | build 1207

## _CINEMATIC_LOCATION_SET_LOCATION_AND_ROTATION
`0x0E94C95EC3185FA9` | `void _CINEMATIC_LOCATION_SET_LOCATION_AND_ROTATION(const char* name, float x, float y, float z, float rotX, float rotY, float rotZ)` | build 1207

## _CINEMATIC_LOCATION_TRIGGER_SCRIPTED_SHOT_EVENT_2
`0xBC016635D6A73B31` | `void _CINEMATIC_LOCATION_TRIGGER_SCRIPTED_SHOT_EVENT_2(const char* dictionary, const char* shotName, int duration)` | build 1207

## _CREATE_KILL_CAM
`0x2F994CC29CAA9D22` | `void _CREATE_KILL_CAM(Ped ped)` | build 1207
Creates Kill Cam for specified Ped Handle

## _DISABLE_CINEMATIC_MODE_THIS_FRAME
`0x8910C24B7E0046EC` | `void _DISABLE_CINEMATIC_MODE_THIS_FRAME()` | build 1207

## _DISABLE_ON_FOOT_FIRST_PERSON_VIEW_THIS_UPDATE_2
`0x05AB44D906738426` | `void _DISABLE_ON_FOOT_FIRST_PERSON_VIEW_THIS_UPDATE_2()` | build 1207
Does the same as 0x9C473089A934C930 (DISABLE_ON_FOOT_FIRST_PERSON_VIEW_THIS_UPDATE)

## _FORCE_CINEMATIC_DEATH_CAM_ON_PED
`0xE3639DB78B3B5400` | `void _FORCE_CINEMATIC_DEATH_CAM_ON_PED(Ped targetPed)` | build 1207
Used for DUELING_MANAGE_DEATH_CAMERA - Initializing death camera
Params: targetPed = death cam focuses on it

## _FORCE_FIRST_PERSON_CAM_THIS_FRAME
`0x90DA5BA5C2635416` | `BOOL _FORCE_FIRST_PERSON_CAM_THIS_FRAME()` | build 1207
Returns true if first person camera is active in saloon1.ysc

## _FORCE_LETTER_BOX_THIS_UPDATE
`0xC64ABC0676AF262B` | `void _FORCE_LETTER_BOX_THIS_UPDATE()` | build 1207

## _FORCE_THIRD_PERSON_CAM_FAR_THIS_FRAME
`0x1CFB749AD4317BDE` | `void _FORCE_THIRD_PERSON_CAM_FAR_THIS_FRAME()` | build 1207
Forces camera position to furthest 3rd person

## _FORCE_THIRD_PERSON_CAM_THIS_FRAME
`0x8370D34BD2E60B73` | `void _FORCE_THIRD_PERSON_CAM_THIS_FRAME()` | build 1207
Forces camera position to second furthest 3rd person

## _FORCE_THIRD_PERSON_CLOSE_THIS_FRAME
`0x718C6ECF5E8CBDD4` | `void _FORCE_THIRD_PERSON_CLOSE_THIS_FRAME()` | build 1207
Forces camera position to closest 3rd person

## _FREEZE_GAMEPLAY_CAM_THIS_FRAME
`0x027CAB2C3AF27010` | `void _FREEZE_GAMEPLAY_CAM_THIS_FRAME()` | build 1207

## _GET_PHOTO_MODE_DOF
`0x4653A741D17F2CD0` | `float _GET_PHOTO_MODE_DOF()` | build 1207

## _GET_PHOTO_MODE_FOCAL_LENGTH
`0x2533BAFFBE737E54` | `float _GET_PHOTO_MODE_FOCAL_LENGTH()` | build 1207

## _GET_PHOTO_MODE_FOCUS_DISTANCE
`0x18FC740FFDCD7454` | `float _GET_PHOTO_MODE_FOCUS_DISTANCE()` | build 1207

## _IS_ANIM_SCENE_CAM_ACTIVE
`0x20389408F0E93B9A` | `BOOL _IS_ANIM_SCENE_CAM_ACTIVE()` | build 1207
Only used in R* Script camera_photomode

## _IS_CAMERA_AVAILABLE
`0x927B810E43E99932` | `BOOL _IS_CAMERA_AVAILABLE(const char* cameraDictionary)` | build 1207

## _IS_CAM_DATA_DICT_LOADED
`0xDD0B7C5AE58F721D` | `BOOL _IS_CAM_DATA_DICT_LOADED(const char* cameraDictionary)` | build 1207

## _IS_CAM_PHOTOFX_RUNNING
`0xA14D5FE82BCB1D9E` | `BOOL _IS_CAM_PHOTOFX_RUNNING()` | build 1207

## _IS_CINEMATIC_CAM_LOCATION_LOADED
`0xAA235E2F2C09E952` | `BOOL _IS_CINEMATIC_CAM_LOCATION_LOADED(const char* sLocationDictName)` | build 1207

## _IS_CINEMATIC_CAM_LOCATION_LOADED_2
`0x595550376B7EA230` | `BOOL _IS_CINEMATIC_CAM_LOCATION_LOADED_2(const char* locationDictName)` | build 1207
Checks data related to Cinematic Cam Locations, if the check fails, the location is being loaded using 0x1B3C2D961F5FC0E1.

## _IS_IN_CINEMATIC_MODE
`0x74F1D22EFA71FAB8` | `BOOL _IS_IN_CINEMATIC_MODE()` | build 1207

## _IS_IN_FULL_FIRST_PERSON_MODE
`0xD1BA66940E94C547` | `BOOL _IS_IN_FULL_FIRST_PERSON_MODE()` | build 1207
Returns true if player is in first person

## _LOAD_CAMERA_DATA_DICT
`0x6A4D224FC7643941` | `void _LOAD_CAMERA_DATA_DICT(const char* cameraDictionary)` | build 1207

## _LOAD_CINEMATIC_CAM_LOCATION
`0x1B3C2D961F5FC0E1` | `void _LOAD_CINEMATIC_CAM_LOCATION(const char* locationDictName)` | build 1207

## _PAUSE_CAMERA_FOCUS
`0x9F97E85EC142255E` | `void _PAUSE_CAMERA_FOCUS(Cam cam, BOOL pause)` | build 1207

## _REACTIVATE_PED_HEADSHOT_EXECUTE_SLOWCAM
`0x986F7A51EE3E1F92` | `void _REACTIVATE_PED_HEADSHOT_EXECUTE_SLOWCAM(Ped ped, int p1)` | build 1207
Used to enable headshot kill replay when you headshot set ped.
Params: p1 seems to be 0 or 1 in R* Scripts

## _REQUEST_LETTER_BOX_NOW
`0x69D65E89FFD72313` | `void _REQUEST_LETTER_BOX_NOW(BOOL state, int transitionTime)` | build 1207
Creates Cinematic Black Bars (at top and bottom)

## _REQUEST_LETTER_BOX_OVERTIME
`0xE296208C273BD7F0` | `void _REQUEST_LETTER_BOX_OVERTIME(int startTransitionTime, int endTransitionTime, BOOL p2, int p3, BOOL p4, BOOL p5)` | build 1207
Creates Cinematic Black Bars (at top and bottom) (this frame)
```lua
CreateThread(function()
    local inLetterBoxFrom = GetGameTimer()
    while GetGameTimer() - inLetterBoxFrom >= 10000 do
        Wait(0)
        RequestLetterBoxOvertime(1000, 1000)
    end
end)
```

## _SET_CAM_DOF_PARAMS
`0xE4B7945EF4F1BFB2` | `void _SET_CAM_DOF_PARAMS(Cam cam, Any* outCamDofParams)` | build 1207
Set cam DOF and focal settings
```lua
local struct = DataView.ArrayBuffer(10*8)
struct:SetFloat32(0*8, 5.0)
struct:SetFloat32(1*8, 2.0)
struct:SetFloat32(2*8, 128.0)
struct:SetFloat32(3*8, 25.0)
struct:SetFloat32(4*8, 25.0)
struct:SetFloat32(5*8, 60.0)
struct:SetInt32(6*8, 1)
struct:SetInt32(7*8, 0)
struct:SetInt32(8*8, 1)
struct:SetInt32(9*8, 1)
Citizen.InvokeNative(0xE4B7945EF4F1BFB2, cam, struct:Buffer())
```

## _SET_CAM_FOCUS_DISTANCE
`0x11F32BB61B756732` | `void _SET_CAM_FOCUS_DISTANCE(Cam cam, float distance)` | build 1207

## _SET_GAMEPLAY_CAM_INITIAL_HEADING
`0x6C1053C433A573CF` | `void _SET_GAMEPLAY_CAM_INITIAL_HEADING(float camInitialHeading)` | build 1207

## _SET_GAMEPLAY_CAM_INITIAL_PITCH
`0x449995EA846D3FC2` | `void _SET_GAMEPLAY_CAM_INITIAL_PITCH(float camInitialPitch)` | build 1207

## _SET_GAMEPLAY_CAM_INITIAL_ZOOM
`0xBCDA0BA8762FACB9` | `void _SET_GAMEPLAY_CAM_INITIAL_ZOOM(float camInitialZoom)` | build 1207
Used in Script Function SHOP_CAMERA_SUPPORT_START_NEW_ORBIT

## _SET_GAMEPLAY_CAM_PARAMS_THIS_UPDATE
`0x066167C63111D8CF` | `void _SET_GAMEPLAY_CAM_PARAMS_THIS_UPDATE(float camSpeed, BOOL enableSlide, float slideOffset, BOOL enableZoom, float zoomOffset)` | build 1207
Not official name
This native allows to move the gameplay cam with the given speed, enableSlide will allow to move the cam to the slideOffset, enableZoom will allow to move the cam to the zoomOffset. 

EXAMPLE:
Citizen.InvokeNative(0x066167c63111d8cf,1.0, true, -1.0, true, 2.0)

## _SET_START_CINEMATIC_DEATH_CAM
`0x6E969927CF632608` | `void _SET_START_CINEMATIC_DEATH_CAM(BOOL p0)` | build 1207
Used for DUELING_MANAGE_DEATH_CAMERA - Initializing death camera
_SET_P* - _SET_S*

## _SHAKE_GAMEPLAY_CAM_WITH_NAME
`0xC3E9E5D4F413B773` | `void _SHAKE_GAMEPLAY_CAM_WITH_NAME(char* shakeName, float intensity)` | build 1207
shakeName: REINFORCED_LASSO_STRUGGLE_SHAKE
_RES*

## _START_CAMERA_ORBIT
`0x65B205BF30C13DDB` | `void _START_CAMERA_ORBIT(Any* p0)` | build 1207
[SHOP_CAMERA_SUPPORT_START_NEW_ORBIT]
p0: struct<32> /*256*/

## _STOP_GAMEPLAY_CAM_SHAKING_WITH_NAME
`0x4285804FD65D8066` | `void _STOP_GAMEPLAY_CAM_SHAKING_WITH_NAME(const char* shakeName, BOOL p1)` | build 1207
script_rel: DRUNK_SHAKE, REINFORCED_LASSO_STRUGGLE_SHAKE, CORRECTOR_SHAKE, MINIGAME_BOUNTY_SHAKE, HAND_SHAKE, MINIGAME_TRAIN_SHAKE
script_mp_rel: DRUNK_SHAKE, REINFORCED_LASSO_STRUGGLE_SHAKE
_STOP_GAMEPLAY_CAM* - _STOP_I*

## _TRIGGER_MISSION_FAILED_CAM
`0x9A92C06ACBAF9731` | `void _TRIGGER_MISSION_FAILED_CAM()` | build 1207

## _UNLOAD_CAMERA_DATA_DICT
`0x798BE43C9393632B` | `void _UNLOAD_CAMERA_DATA_DICT(const char* cameraDictionary)` | build 1207

## _UNLOAD_CINEMATIC_CAMERA_LOCATION
`0x2412216FCC7B4E3E` | `void _UNLOAD_CINEMATIC_CAMERA_LOCATION(const char* dictionaryName)` | build 1207
