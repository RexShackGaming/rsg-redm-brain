# MAP natives (85)
Source: VORPCORE/RDR3natives `rdr3natives.json`. Grep by NAME or hash.

## ADD_POINT_TO_GPS_MULTI_ROUTE
`0x64C59DD6834FA942` | `void ADD_POINT_TO_GPS_MULTI_ROUTE(float x, float y, float z, BOOL p3)` | build 1207

## ALLOW_SONAR_BLIPS
`0x6E6E64788C07D2E0` | `void ALLOW_SONAR_BLIPS(BOOL toggle)` | build 1207

## BLIP_ADD_FOR_COORDS
`0x554D9D53F696D002` | `Blip BLIP_ADD_FOR_COORDS(Hash blipHash, float x, float y, float z)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/textures/blips
https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/textures/blips_mp

## BLIP_ADD_FOR_ENTITY
`0x23F74C2FDA6E7C61` | `Blip BLIP_ADD_FOR_ENTITY(Hash blipHash, Entity entity)` | build 1207

## BLIP_ADD_FOR_PICKUP_PLACEMENT
`0xA486008892065FB9` | `Blip BLIP_ADD_FOR_PICKUP_PLACEMENT(Hash blipHash, Pickup pickup)` | build 1207

## BLIP_ADD_FOR_RADIUS
`0x45F13B7E0A15C880` | `Blip BLIP_ADD_FOR_RADIUS(Hash blipHash, float x, float y, float z, float radius)` | build 1207

## BLIP_ADD_MODIFIER
`0x662D364ABF16DE2F` | `BOOL BLIP_ADD_MODIFIER(Blip blip, Hash modifierHash)` | build 1207
https://alloc8or.re/rdr3/doc/enums/eBlipModifier.txt
https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/blip_modifiers

Old name: _BLIP_SET_MODIFIER

## BLIP_REMOVE_MODIFIER
`0xB059D7BD3D78C16F` | `BOOL BLIP_REMOVE_MODIFIER(Blip blip, Hash modifierHash)` | build 1207
If modifierHash is 0, ALL modifiers will be removed.

## CLEAR_GPS_CUSTOM_ROUTE
`0x1EAA5674B4D181C5` | `void CLEAR_GPS_CUSTOM_ROUTE()` | build 1207

## CLEAR_GPS_FLAGS
`0x4D3771237C79FF41` | `void CLEAR_GPS_FLAGS()` | build 1207
Clears the GPS flags.

## CLEAR_GPS_MULTI_ROUTE
`0x9E0AB9AAEE87CE28` | `void CLEAR_GPS_MULTI_ROUTE()` | build 1207
Does the same as SET_GPS_MULTI_ROUTE_RENDER(false);

## CLEAR_GPS_PLAYER_WAYPOINT
`0x08FDC6F796E350D1` | `void CLEAR_GPS_PLAYER_WAYPOINT()` | build 1207

## DISPLAY_RADAR
`0x1B3DA717B9AFF828` | `void DISPLAY_RADAR(BOOL toggle)` | build 1207
If Minimap / Radar should be displayed.

## DOES_BLIP_EXIST
`0xCD82FA174080B3B1` | `BOOL DOES_BLIP_EXIST(Blip blip)` | build 1207

## FORCE_SONAR_BLIPS_THIS_FRAME
`0xEE1C7BA69BB74B08` | `Any FORCE_SONAR_BLIPS_THIS_FRAME()` | build 1207
Doesn't actually return anything.

## GET_BLIP_COORDS
`0x201C319797BDA603` | `Vector3 GET_BLIP_COORDS(Blip blip)` | build 1207

## GET_BLIP_FROM_ENTITY
`0x6D2C41A8BD6D6FD0` | `Blip GET_BLIP_FROM_ENTITY(Entity entity)` | build 1207
Returns the Blip handle of given Entity.

## GET_MAIN_PLAYER_BLIP_ID
`0x5CD2889B2B381D45` | `Blip GET_MAIN_PLAYER_BLIP_ID()` | build 1207

## IS_BLIP_ON_MINIMAP
`0x46534526B9CD2D17` | `BOOL IS_BLIP_ON_MINIMAP(Blip blip)` | build 1207

## IS_WAYPOINT_ACTIVE
`0x202B1BBFC6AB5EE4` | `BOOL IS_WAYPOINT_ACTIVE()` | build 1207

## LOCK_MINIMAP_ANGLE
`0x0BFD145EF819FB3A` | `void LOCK_MINIMAP_ANGLE(int angle)` | build 1207
Locks the minimap to the specified angle in integer degrees.

angle: The angle in whole degrees. If less than 0 or greater than 360, unlocks the angle.

## REMOVE_BLIP
`0xF2C3C9DA47AAA54A` | `void REMOVE_BLIP(Blip* blip)` | build 1207

## RESET_MINIMAP_FOW
`0xEB3CB3386C775D72` | `void RESET_MINIMAP_FOW(Hash hash)` | build 1207

## SET_BLIP_COORDS
`0x4FF674F5E23D49CE` | `void SET_BLIP_COORDS(Blip blip, float posX, float posY, float posZ)` | build 1207

## SET_BLIP_FLASHES
`0x0DF2B55F717DDB10` | `BOOL SET_BLIP_FLASHES(Blip blip, int* p1, Hash* p2)` | build 1207
_GET_BLIP_MAP_CARD_INFO this should be the name there is no flash timer for blips
```lua
local blipType, mapCardId = Citizen.InvokeNative(0x0DF2B55F717DDB10, intParameter, Citizen.PointerValueInt(), Citizen.PointerValueInt())
// will return whatever you passed in blipType as long is an int
```

## SET_BLIP_FLASH_TIMER
`0x02FF4CF43B7209D1` | `void SET_BLIP_FLASH_TIMER(Blip blip, int blipType, Hash mapCardId)` | build 1207
_SET_BLIP_MAP_CARD_INFO this should be the name there is no flash timer for blips
blipType can be any number, but you can use blipTypes
mapCardId joaat("SHOP_MOONSHINE_STILL") possibly to get the card info by this hash

## SET_BLIP_NAME_FROM_TEXT_FILE
`0x0A062D6D7C0B2C2C` | `void SET_BLIP_NAME_FROM_TEXT_FILE(Blip blip, char* textLabel)` | build 1207

## SET_BLIP_NAME_TO_PLAYER_NAME
`0x093DD5A31BC2B459` | `void SET_BLIP_NAME_TO_PLAYER_NAME(Blip blip, Player player)` | build 1207

## SET_BLIP_ROTATION
`0x6049966A94FBE706` | `void SET_BLIP_ROTATION(Blip blip, int rotation)` | build 1207

## SET_BLIP_SCALE
`0xD38744167B2FA257` | `void SET_BLIP_SCALE(Blip blip, float scale)` | build 1207
only works for BLIP_ADD_FOR_RADIUS AND BLIP_ADD_FOR_AREA, this native works as a radius not really a scale

## SET_BLIP_SPRITE
`0x74F74D3207ED525C` | `void SET_BLIP_SPRITE(Blip blip, Hash hash, BOOL p2)` | build 1207

## SET_GPS_CUSTOM_ROUTE_RENDER
`0xF6CEF599FC470B33` | `void SET_GPS_CUSTOM_ROUTE_RENDER(BOOL p0, int p1, int p2)` | build 1207

## SET_GPS_FLAGS
`0x5DE61C90DDECFA2D` | `void SET_GPS_FLAGS(int p0, float p1)` | build 1207
https://alloc8or.re/rdr3/doc/enums/rage__eGpsFlags.txt

## SET_GPS_MULTI_ROUTE_RENDER
`0x4426D65E029A4DC0` | `void SET_GPS_MULTI_ROUTE_RENDER(BOOL toggle)` | build 1207

## SET_MINIMAP_FOW_REVEAL_COORDINATE
`0x73348402566ECB6E` | `void SET_MINIMAP_FOW_REVEAL_COORDINATE(float x, float y, float z, Hash p3)` | build 1207
Up to eight coordinates may be revealed per frame

## SET_MINIMAP_FOW_REVEAL_VOLUME
`0x63CBBD6CA6F321F9` | `void SET_MINIMAP_FOW_REVEAL_VOLUME(Volume volume, Hash p1)` | build 1207

## SET_MINIMAP_HIDE_FOW
`0x4B8F743A4A6D2FF8` | `void SET_MINIMAP_HIDE_FOW(BOOL toggle)` | build 1207
Reveals the entire minimap (FOW = Fog of War)

## SET_RADAR_AS_EXTERIOR_THIS_FRAME
`0xA8EBBAE986FB5457` | `void SET_RADAR_AS_EXTERIOR_THIS_FRAME()` | build 1207

## SET_RADAR_ZOOM
`0xCAF6489DA2C8DD9E` | `void SET_RADAR_ZOOM(int zoomLevel)` | build 1207

## SET_WAYPOINT_OFF
`0xFA8C41E8020D3439` | `void SET_WAYPOINT_OFF()` | build 1207

## START_GPS_MULTI_ROUTE
`0x3D3D15AF7BCAAF83` | `void START_GPS_MULTI_ROUTE(Hash colorNameHash, BOOL onFoot, BOOL inVehicle)` | build 1207

## TRIGGER_SONAR_BLIP
`0x72DD432F3CDFC0EE` | `void TRIGGER_SONAR_BLIP(Hash typeHash, float x, float y, float z)` | build 1207

## UNLOCK_MINIMAP_ANGLE
`0x5373DE8E179BC2A0` | `void UNLOCK_MINIMAP_ANGLE()` | build 1207

## _0xD3F58E9316B7FC2A
`0xD3F58E9316B7FC2A` | `void _0xD3F58E9316B7FC2A(Any p0)` | build 1207

## _ABANDON_BLIP
`0xDEEDE7C41742E011` | `void _ABANDON_BLIP(Blip blip)` | build 1207
It's unclear what exactly this does, but I assume it marks the blip as "no longer needed"

## _ADD_PROP_TO_MINIMAP
`0x1392105DA88BBFFB` | `void _ADD_PROP_TO_MINIMAP(Hash minimapProp, float x, float y, float rotation, int variation)` | build 1207
list of minimap props: https://github.com/femga/rdr3_discoveries/tree/master/graphics/minimap/minimapObjects
variations parameter are the interior locations you see on the map like these bellow
variation 0 https://i.imgur.com/jkLhn3Z.png
variation 2  https://i.imgur.com/eKV0Tcm.png
variation 4 https://i.imgur.com/rjwOgEH.png
there are more and you can find them in the decompiles

## _BLIP_ADD_FOR_AREA
`0xEC174ADBCB611ECC` | `Blip _BLIP_ADD_FOR_AREA(Hash blipHash, float x, float y, float z, float scaleX, float scaleY, float scaleZ, int p7)` | build 1207

## _BLIP_ADD_FOR_STYLE
`0x3E593DF9C2962EC6` | `Blip _BLIP_ADD_FOR_STYLE(Hash styleHash)` | build 1207

## _BLIP_ADD_FOR_VOLUME
`0xA6EF0C54A3443E70` | `Blip _BLIP_ADD_FOR_VOLUME(Hash blipHash, Volume volume)` | build 1207

## _BLIP_ADD_STYLE
`0xBD62D98799A3DAF0` | `BOOL _BLIP_ADD_STYLE(Blip blip, Hash styleHash)` | build 1207

## _BLIP_DETACH_FROM_ENTITY
`0x250C75EB1728CC0D` | `void _BLIP_DETACH_FROM_ENTITY(Blip blip)` | build 1207
Not official native name
Removes the blip from an entity and makes it static on the map, try it on GetMainPlayerBlipId() for a demonstration

## _BLIP_SET_STYLE
`0xEDD964B7984AC291` | `BOOL _BLIP_SET_STYLE(Blip blip, Hash styleHash)` | build 1207
https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/blip_styles
Removes any existing modifiers and sets the style.

## _CLEAR_BLIP
`0x01B928CA2E198B01` | `Any _CLEAR_BLIP(Blip blip)` | build 1207
Clear blip data. It must be used before RemoveBlip I'm pretty sure that blips are handled internally with databinding. This function should then allow you to clear blip container and therefore free up memory?.

## _CLEAR_BLIP_ICON_FROM_LOCKON_ENTITY_PROMPT
`0x44813684F72B563C` | `void _CLEAR_BLIP_ICON_FROM_LOCKON_ENTITY_PROMPT(Entity entity, int blip)` | build 1207
will remove the blip icon from the entity lockon prompt,p1 = GET_BLIP_FROM_ENTITY

## _CLEAR_PAUSEMAP_COORDS
`0x7C9F4CDF402CA82A` | `void _CLEAR_PAUSEMAP_COORDS()` | build 1311
Clears the previously set coordinates for the pause map view, removing any specified focal point and radius that were set using `SetPausemapCoordsWithRadius - 0xE0884C184728C75B`

## _DOES_ENTITY_HAVE_BLIP
`0x9FA00E2FC134A9D0` | `BOOL _DOES_ENTITY_HAVE_BLIP(Entity entity)` | build 1207

## _FIND_CLOSEST_GPS_POSITION
`0x3FDA2B79AEEE351C` | `BOOL _FIND_CLOSEST_GPS_POSITION(float x, float y, float z, Vector3* outPosition)` | build 1207

## _GET_WAYPOINT_COORDS
`0x29B30D07C3F7873B` | `Vector3 _GET_WAYPOINT_COORDS()` | build 1207

## _GET_WAYPOINT_POSITION
`0xF08E42BFA46BDFF8` | `Any _GET_WAYPOINT_POSITION(float* x, float* y)` | build 1207
Unlike `GET_WAYPOINT_COORDS - 0x29B30D07C3F7873B`, which returns a single value, this native returns the x and y coordinates of the waypoint separately as floats from pointer. To retrieve each coordinate, `Citizen.PointerValueFloat()` must be used with this function.
```lua
local x,y = _GET_WAYPOINT_POSITION(Citizen.PointerValueFloat(),Citizen.PointerValueFloat())
```

## _HIDE_ACTIVE_POINTS_OF_INTEREST
`0xA1B4052C2A3DCC1E` | `void _HIDE_ACTIVE_POINTS_OF_INTEREST()` | build 1207

## _IS_BLIP_ATTACHED_TO_ANY_ENTITY
`0xE9F676788F8D5E1E` | `BOOL _IS_BLIP_ATTACHED_TO_ANY_ENTITY(Blip blip)` | build 1207

## _IS_BLIP_ICON_ON_LOCKON_ENTITY_PROMPT
`0x3CB8859F04763C78` | `BOOL _IS_BLIP_ICON_ON_LOCKON_ENTITY_PROMPT(Entity entity, int blip)` | build 1207
checks if the entity lockon prompt contains an icon

## _IS_GPS_ROUTE_ON_ROAD
`0xF47A1EB2A538A3A3` | `BOOL _IS_GPS_ROUTE_ON_ROAD()` | build 1207
Checks if the GPS route to the waypoint is navigable along a road. If a route exists but there is no valid road path, this function returns false.

## _MAP_DISABLE_REGION_BLIP
`0x6786D7AFAC3162B3` | `void _MAP_DISABLE_REGION_BLIP(Hash regionHash)` | build 1207

## _MAP_DISCOVERY_SET_ENABLED
`0xDA98246C7A3C2189` | `void _MAP_DISCOVERY_SET_ENABLED(Hash discoveryHash)` | build 1207

## _MAP_DISCOVER_REGION
`0xD8C7162AB2E2AF45` | `void _MAP_DISCOVER_REGION(Hash discoveryHash)` | build 1207

## _MAP_ENABLE_REGION_BLIP
`0x563FCB6620523917` | `void _MAP_ENABLE_REGION_BLIP(Hash regionHash, Hash styleHash)` | build 1207
regionHash: https://github.com/femga/rdr3_discoveries/tree/master/graphics/minimap/wanted_regions

## _MAP_IS_DISCOVERY_ACTIVE
`0x3F81EA4275D39D6F` | `BOOL _MAP_IS_DISCOVERY_ACTIVE(Hash discoveryHash)` | build 1207

## _MAP_IS_REGION_HIGHLIGHTED_WITH_STYLE
`0xE38450DBCBC70E3D` | `BOOL _MAP_IS_REGION_HIGHLIGHTED_WITH_STYLE(Hash regionHash, Hash styleHash)` | build 1207

## _REMOVE_BLIP_ICON_FROM_ENTITY_LOCKON_PROMPT
`0xBB68D4D3CA3DE402` | `void _REMOVE_BLIP_ICON_FROM_ENTITY_LOCKON_PROMPT(Entity entity, int p1)` | build 1207
in the decompiles this doesnt seem to ever be executed the param needed needs to be above 0 but its always passed as 0
 removes the icon from lockon prompt

## _REMOVE_PROP_FROM_MINIMAP
`0xE057FEA9A22EB3EE` | `void _REMOVE_PROP_FROM_MINIMAP(Hash minimapProp)` | build 1207

## _REVEAL_MINIMAP_FOW
`0xF8096DF9B87246E3` | `void _REVEAL_MINIMAP_FOW(Hash hash)` | build 1207

## _SET_BLIP_ICON_ON_ENTITY_ACTIVE_PROMPT
`0x1726963E6049DB53` | `void _SET_BLIP_ICON_ON_ENTITY_ACTIVE_PROMPT(Entity entity, Hash blipIcon)` | build 1207
It adds blip a icon to active prompts like from scenarios or pickups without the need to use lockon

## _SET_BLIP_ICON_TO_LOCKON_ENTITY_PROMPT
`0x7563CBCA99253D1A` | `void _SET_BLIP_ICON_TO_LOCKON_ENTITY_PROMPT(Entity entity, Hash blipIcon)` | build 1207
will add a blip icon to the entity lockon prompt that you specify

## _SET_BLIP_NAME
`0x9CB1A1623062F402` | `void _SET_BLIP_NAME(Blip blip, char* name)` | build 1207

## _SET_ENTITY_BLIP_ICON_TO_LOCKON_ENTITY_PROMPT
`0x97F6F158CC5B5CA2` | `void _SET_ENTITY_BLIP_ICON_TO_LOCKON_ENTITY_PROMPT(Entity entity, int blipId)` | build 1207
adds the entity blip icon to the entity lockon prompt if wrong param will remove the icon if had any

## _SET_FOW_UPDATE_PLAYER_OVERRIDE
`0x63E7279D04160477` | `void _SET_FOW_UPDATE_PLAYER_OVERRIDE(BOOL toggle, Hash p1)` | build 1207
Used for GUARMA MODE; Enabled: toggle = false, 0; Disabled: toggle = true, 0
Hash p1 seems to be unused, always 0

## _SET_MINIMAP_FOW_OVERRIDE_REVEAL_SCALE
`0xE5A7F70B7C0F3271` | `void _SET_MINIMAP_FOW_OVERRIDE_REVEAL_SCALE(float scale, Hash p1)` | build 1207

## _SET_MINIMAP_FOW_SHOULD_UPDATE
`0x632AA10BF7EA53D3` | `void _SET_MINIMAP_FOW_SHOULD_UPDATE(BOOL toggle, Hash p1)` | build 1207

## _SET_MINIMAP_ZONE
`0xA657EC9DBC6CC900` | `void _SET_MINIMAP_ZONE(Hash zone)` | build 1207
hash can be the hash of "guarma" or "world".

## _SET_PAUSEMAP_COORDS_WITH_RADIUS
`0xE0884C184728C75B` | `void _SET_PAUSEMAP_COORDS_WITH_RADIUS(float x, float y, float z, float radius)` | build 1207

## _SET_RADAR_CONFIG_TYPE
`0x9C113883487FD53C` | `void _SET_RADAR_CONFIG_TYPE(Hash configHash, Hash p1)` | build 1207
https://github.com/femga/rdr3_discoveries/blob/master/graphics/minimap/radar/radar_configs.lua
configHash: -1943724816, 347777538, -117986897, -789269373, -547506804, -1986542417, 2080113112
p1: usually 898171178 or 0 in R* scripts (doesn't seems to have any effect)

## _SHOW_ACTIVE_POINTS_OF_INTEREST
`0x3FBB838AEA30C1D8` | `void _SHOW_ACTIVE_POINTS_OF_INTEREST()` | build 1207

## _START_GPS_CUSTOM_ROUTE_FROM_WAYPOINT_RECORDING_ROUTE
`0x6B44F13D888F770D` | `void _START_GPS_CUSTOM_ROUTE_FROM_WAYPOINT_RECORDING_ROUTE(char* waypointRecording, int point, int numPoints, Hash colorNameHash, BOOL p4, BOOL p5)` | build 1207

## _TRIGGER_SONAR_BLIP_ON_ENTITY
`0x0C7A2289A5C4D7C9` | `void _TRIGGER_SONAR_BLIP_ON_ENTITY(Hash typeHash, Entity entity)` | build 1207
