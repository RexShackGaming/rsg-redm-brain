# CFX natives (943)
Source: VORPCORE/RDR3natives `natives_cfx.json`. Grep by NAME or hash.

## ACTIVATE_TIMECYCLE_EDITOR
`0xEEB9B76A` | `void ACTIVATE_TIMECYCLE_EDITOR()`

## ADD_AUDIO_SUBMIX_OUTPUT
`0xAC6E290D` | `void ADD_AUDIO_SUBMIX_OUTPUT(int submixId, int outputSubmixId)`

## ADD_AUTHORIZED_PARACHUTE_MODEL
`0x8AC7AE9` | `void ADD_AUTHORIZED_PARACHUTE_MODEL(int modelNameHash)`

## ADD_AUTHORIZED_PARACHUTE_PACK_MODEL
`0x2E86DEA5` | `void ADD_AUTHORIZED_PARACHUTE_PACK_MODEL(int modelNameHash)`

## ADD_BLIP_FOR_COORD
`0xC6F43D0E` | `void ADD_BLIP_FOR_COORD(float x, float y, float z)`

## ADD_BLIP_FOR_ENTITY
`0x30822554` | `void ADD_BLIP_FOR_ENTITY(Entity entity)`

## ADD_BLIP_FOR_RADIUS
`0x4626756C` | `void ADD_BLIP_FOR_RADIUS(float posX, float posY, float posZ, float radius)`

## ADD_CONVAR_CHANGE_LISTENER
`0xAB7F7241` | `void ADD_CONVAR_CHANGE_LISTENER(char* conVarFilter, func handler)`
```js
// listen for all convar changes
AddConvarChangeListener(null, (conVarName, reserved) => {
    print(GetConvarInt(conVarName))
})

// listen to convars that start with "script:"
AddConvarChangeListener("script:*", (conVarName, reserved) => {
    print(GetConvarInt(conVarName))
})
```

## ADD_HEALTH_CONFIG
`0x9CBFD5C1` | `void ADD_HEALTH_CONFIG(char* configName, float defaultHealth, float defaultArmor, float defaultEndurance, float fatiguedHealthThreshold, float injuredHealthThreshold, float dyingHealthThreshold, float hurtHealthThreshold, float dogTakedownThreshold, float writheFromBulletThreshold, BOOL meleeCardinalFatalAttack, BOOL invincible)`

## ADD_MINIMAP_OVERLAY
`0x4AFD2499` | `void ADD_MINIMAP_OVERLAY(char* name)`

## ADD_MINIMAP_OVERLAY_WITH_DEPTH
`0xED0935B5` | `void ADD_MINIMAP_OVERLAY_WITH_DEPTH(char* name, int depth)`

## ADD_PED_DECORATION_FROM_HASHES
`0x70559AC7` | `void ADD_PED_DECORATION_FROM_HASHES(Ped ped, Hash collection, Hash overlay)`

## ADD_REPLACE_TEXTURE
`0xA66F8F75` | `void ADD_REPLACE_TEXTURE(char* origTxd, char* origTxn, char* newTxd, char* newTxn)`

## ADD_STATE_BAG_CHANGE_HANDLER
`0x5BA35AAF` | `void ADD_STATE_BAG_CHANGE_HANDLER(char* keyFilter, char* bagFilter, func handler)`
```js
AddStateBagChangeHandler("blockTasks", null, async (bagName, key, value /* boolean */) => {
    let entity = GetEntityFromStateBagName(bagName);
    // Whoops, we don't have a valid entity!
    if (entity === 0) return;
    // We don't want to freeze the entity position if the entity collision hasn't loaded yet
    while (!HasCollisionLoadedAroundEntity(entity)) {
        // The entity went out of our scope before the collision loaded
        if (!DoesEntityExist(entity)) return;
        await Delay(250);
    }
    SetEntityInvincible(entity, value)
    FreezeEntityPosition(entity, value)
    TaskSetBlockingOfNonTemporaryEvents(entity, value)
})
```
```lua
AddStateBagChangeHandler("blockTasks", nil, function(bagName, key, value) 
    local entity = GetEntityFromStateBagName(bagName)
    -- Whoops, we don't have a valid entity!
    if entity == 0 then return end
    -- We don't want to freeze the entity position if the entity collision hasn't loaded yet
    while not HasCollisionLoadedAroundEntity(entity) do
        -- The entity went out of our scope before the collision loaded
        if not DoesEntityExist(entity) then return end
        Wait(250)
    end
    SetEntityInvincible(entity, value)
    FreezeEntityPosition(entity, value)
    TaskSetBlockingOfNonTemporaryEvents(entity, value)
end)
```
```cs
AddStateBagChangeHandler("blockTasks", null,
    new Action<string, string, object, int, bool>
    (async (bagName, key, value, res, rep) =>
    {
        bool val = (bool)value;

        var entity = GetEntityFromStateBagName(bagName);
        //-- Whoops, we don't have a valid entity!
        if (entity == 0) return;
        //-- We don't want to freeze the entity position if the entity collision hasn't loaded yet
        while (!HasCollisionLoadedAroundEntity(entity))
        {
            //--The entity went out of our scope before the collision loaded
            if (!DoesEntityExist(entity)) return;

            await Delay(250);
        }
        SetEntityInvincible(entity, val);
        FreezeEntityPosition(entity, val);
        TaskSetBlockingOfNonTemporaryEvents(entity, val);
    }));
```

## ADD_TEXT_ENTRY
`0x32CA01C3` | `void ADD_TEXT_ENTRY(char* entryKey, char* entryText)`

## ADD_TEXT_ENTRY_BY_HASH
`0x289DA860` | `void ADD_TEXT_ENTRY_BY_HASH(Hash entryKey, char* entryText)`

## APPLY_FORCE_TO_ENTITY
`0xC1C0855A` | `void APPLY_FORCE_TO_ENTITY(Entity entity, int forceType, float x, float y, float z, float offX, float offY, float offZ, int nComponent, BOOL bLocalForce, BOOL bLocalOffset, BOOL bScaleByMass, BOOL bPlayAudio, BOOL bScaleByTimeWarp)`

## APPLY_WEATHER_CYCLES
`0x3422291C` | `void APPLY_WEATHER_CYCLES(int numEntries, int msPerCycle)`
```lua
-- Cycle between XMAS weather for 30 seconds (3 * 10000 milliseconds), and SMOG weather for 20 seconds (2 * 10000 milliseconds)
local success = SetWeatherCycleEntry(0, "XMAS", 3) and
                SetWeatherCycleEntry(1, "SMOG", 2) and
                ApplyWeatherCycles(2, 10000)
```

## BREAK_OFF_VEHICLE_WHEEL
`0xA274CADB` | `void BREAK_OFF_VEHICLE_WHEEL(Vehicle vehicle, int wheelIndex, BOOL leaveDebrisTrail, BOOL deleteWheel, BOOL unknownFlag, BOOL putOnFire)`
```lua
local vehicle = GetVehiclePedIsIn(PlayerPedId())

if DoesEntityExist(vehicle) then
  for i = 0, 3 do
    BreakOffVehicleWheel(vehicle, i, true, false, true, false)
  end
end
```

## CALL_MINIMAP_SCALEFORM_FUNCTION
`0x4C89C0ED` | `void CALL_MINIMAP_SCALEFORM_FUNCTION(int miniMap, char* fnName)`

## CANCEL_EVENT
`0xFA29D35D` | `void CANCEL_EVENT()`

## CAN_PLAYER_START_COMMERCE_SESSION
`0x429461C3` | `void CAN_PLAYER_START_COMMERCE_SESSION(char* playerSrc)`

## CLEAR_DRAW_ORIGIN
`0xDD76B263` | `void CLEAR_DRAW_ORIGIN()`

## CLEAR_PED_PROP
`0x2D23D743` | `void CLEAR_PED_PROP(Ped ped, int propId)`

## CLEAR_PED_SECONDARY_TASK
`0xA635F451` | `void CLEAR_PED_SECONDARY_TASK(Ped ped)`

## CLEAR_PED_TASKS
`0xDE3316AB` | `void CLEAR_PED_TASKS(Ped ped)`

## CLEAR_PED_TASKS_IMMEDIATELY
`0xBC045625` | `void CLEAR_PED_TASKS_IMMEDIATELY(Ped ped)`

## CLEAR_PLAYER_WANTED_LEVEL
`0x54EA5BCC` | `void CLEAR_PLAYER_WANTED_LEVEL(Player player)`

## CLEAR_VEHICLE_XENON_LIGHTS_CUSTOM_COLOR
`0x2867ED8C` | `void CLEAR_VEHICLE_XENON_LIGHTS_CUSTOM_COLOR(Vehicle vehicle)`

## CLONE_TIMECYCLE_MODIFIER
`0x54D636B3` | `void CLONE_TIMECYCLE_MODIFIER(char* sourceModifierName, char* clonedModifierName)`
```lua
local sourceName = "underwater"
local cloneName = "my_awesome_timecycle"

local clonedIndex = CloneTimecycleModifier(sourceName, cloneName)
if clonedIndex ~= -1 then
  SetTimecycleModifier(cloneName)
end
```

## COMMIT_RUNTIME_TEXTURE
`0x19D81F4E` | `void COMMIT_RUNTIME_TEXTURE(long tex)`

## CREATE_AUDIO_SUBMIX
`0x658D2BC8` | `void CREATE_AUDIO_SUBMIX(char* name)`

## CREATE_DRY_VOLUME
`0xEB1C6DD` | `void CREATE_DRY_VOLUME(float xMin, float yMin, float zMin, float xMax, float yMax, float zMax)`

## CREATE_DUI
`0x23EAF899` | `void CREATE_DUI(char* url, int width, int height)`

## CREATE_OBJECT
`0x2F7AA05C` | `void CREATE_OBJECT(Hash modelHash, float x, float y, float z, BOOL isNetwork, BOOL netMissionEntity, BOOL doorFlag)`

## CREATE_OBJECT_NO_OFFSET
`0x58040420` | `void CREATE_OBJECT_NO_OFFSET(Hash modelHash, float x, float y, float z, BOOL isNetwork, BOOL netMissionEntity, BOOL doorFlag)`

## CREATE_PED
`0x389EF71` | `void CREATE_PED(int pedType, Hash modelHash, float x, float y, float z, float heading, BOOL isNetwork, BOOL bScriptHostPed)`

## CREATE_PED_INSIDE_VEHICLE
`0x3000F092` | `void CREATE_PED_INSIDE_VEHICLE(Vehicle vehicle, int pedType, Hash modelHash, int seat, BOOL isNetwork, BOOL bScriptHostPed)`

## CREATE_RUNTIME_TEXTURE
`0xFEC3766D` | `void CREATE_RUNTIME_TEXTURE(long txd, char* txn, int width, int height)`

## CREATE_RUNTIME_TEXTURE_FROM_DUI_HANDLE
`0xB135472B` | `void CREATE_RUNTIME_TEXTURE_FROM_DUI_HANDLE(long txd, char* txn, char* duiHandle)`

## CREATE_RUNTIME_TEXTURE_FROM_IMAGE
`0x786D8BC3` | `void CREATE_RUNTIME_TEXTURE_FROM_IMAGE(long txd, char* txn, char* fileName)`

## CREATE_RUNTIME_TXD
`0x1F3AC778` | `void CREATE_RUNTIME_TXD(char* name)`

## CREATE_TIMECYCLE_MODIFIER
`0x70FA2AFA` | `void CREATE_TIMECYCLE_MODIFIER(char* modifierName)`
```lua
local modifierName = "my_awesome_timecycle"
local createdIndex = CreateTimecycleModifier(modifierName)

if createdIndex ~= -1 then
  SetTimecycleModifier(modifierName)
end
```

## CREATE_VEHICLE
`0xDD75460A` | `void CREATE_VEHICLE(Hash modelHash, float x, float y, float z, float heading, BOOL isNetwork, BOOL netMissionEntity)`

## CREATE_VEHICLE_SERVER_SETTER
`0x6AE51D4B` | `void CREATE_VEHICLE_SERVER_SETTER(Hash modelHash, char* type, float x, float y, float z, float heading)`
```lua
local heli = CreateVehicleServerSetter(`seasparrow`, 'heli', GetEntityCoords(GetPlayerPed(GetPlayers()[1])) + vector3(0, 0, 15), 0.0)
print(GetEntityCoords(heli)) -- should return correct coordinates
```

## DELETE_ENTITY
`0xFAA3D236` | `void DELETE_ENTITY(Entity entity)`

## DELETE_FUNCTION_REFERENCE
`0x1E86F206` | `void DELETE_FUNCTION_REFERENCE(char* referenceIdentity)`

## DELETE_RESOURCE_KVP
`0x7389B5DF` | `void DELETE_RESOURCE_KVP(char* key)`
```lua
DeleteResourceKvp('liberty_city')
```

## DELETE_RESOURCE_KVP_NO_SYNC
`0x4152C90` | `void DELETE_RESOURCE_KVP_NO_SYNC(char* key)`

## DELETE_TRAIN
`0x523BA3DA` | `void DELETE_TRAIN(Entity entity)`

## DESTROY_DUI
`0xA085CB10` | `void DESTROY_DUI(long duiObject)`

## DISABLE_EDITOR_RUNTIME
`0xB1622B17` | `void DISABLE_EDITOR_RUNTIME()`

## DISABLE_IDLE_CAMERA
`0x3D5AB7F0` | `void DISABLE_IDLE_CAMERA(BOOL state)`

## DISABLE_RAW_KEY_THIS_FRAME
`0x8BCF0014` | `void DISABLE_RAW_KEY_THIS_FRAME(int rawKeyIndex)`
```lua
local KEY_SPACE = 32
DisableRawKeyThisFrame(KEY_SPACE)
-- This will not get triggered this frame
if IsRawKeyDown(KEY_SPACE) then
	print("unreachable :(")
end
-- this will get triggered
if IsDisabledRawKeyDown(KEY_SPACE) then
    print("Spacebar is down")
end
```

## DISABLE_VEHICLE_PASSENGER_IDLE_CAMERA
`0x5C140555` | `void DISABLE_VEHICLE_PASSENGER_IDLE_CAMERA(BOOL state)`

## DISABLE_WORLDHORIZON_RENDERING
`0xA9C92CDC` | `void DISABLE_WORLDHORIZON_RENDERING(BOOL state)`

## DOES_BOAT_SINK_WHEN_WRECKED
`0x43F15989` | `void DOES_BOAT_SINK_WHEN_WRECKED(Vehicle vehicle)`

## DOES_ENTITY_EXIST
`0x3AC90869` | `void DOES_ENTITY_EXIST(Object entity)`

## DOES_PLAYER_EXIST
`0x12038599` | `void DOES_PLAYER_EXIST(char* playerSrc)`
```lua
local deferralMessages = { "Isn't this just magical!", "We can defer all day!", "You'll get in eventually", "You're totally not going to sit here forever", "The Fruit Tree is a lie" }
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()

    Wait(0)


    local messageIndex = 0

    repeat
        Wait(2000)
        if messageIndex >= #deferralMessages then
            deferrals.done()
        else
            messageIndex = messageIndex + 1
        end
        deferrals.update(deferralMessages[messageIndex])
    until not DoesPlayerExist(source)
end)
```

## DOES_PLAYER_OWN_SKU
`0x167ABA27` | `void DOES_PLAYER_OWN_SKU(char* playerSrc, int skuId)`

## DOES_PLAYER_OWN_SKU_EXT
`0xDEF0480B` | `void DOES_PLAYER_OWN_SKU_EXT(char* playerSrc, int skuId)`

## DOES_TEXTURE_EXIST
`0x8B25BC20` | `void DOES_TEXTURE_EXIST(int textureId)`

## DOES_TIMECYCLE_MODIFIER_HAS_VAR
`0xC53BB6D3` | `void DOES_TIMECYCLE_MODIFIER_HAS_VAR(char* modifierName, char* varName)`
```lua
local modifierName = "superDARK"
local varName = "postfx_noise"

if DoesTimecycleModifierHasVar(modifierName, varName) then
  local success, value1, value2 = GetTimecycleModifierVar(modifierName, varName)

  if success then
    print(string.format("[%s] removed var %s with values: %f %f", modifierName, varName, value1, value2))
    RemoveTimecycleModifierVar(modifierName, varName)
  end
else
    SetTimecycleModifierVar(modifierName, varName, 1.0, 1.0)
    print(string.format("[%s] created var %s", modifierName, varName))
end
```

## DOES_TRAIN_STOP_AT_STATIONS
`0x77CC80DC` | `void DOES_TRAIN_STOP_AT_STATIONS(Vehicle train)`

## DOES_VEHICLE_USE_FUEL
`0xEF30A696` | `void DOES_VEHICLE_USE_FUEL(Vehicle vehicle)`

## DOOR_SYSTEM_GET_ACTIVE
`0xF65BBA4B` | `void DOOR_SYSTEM_GET_ACTIVE()`

## DOOR_SYSTEM_GET_SIZE
`0x237613B3` | `void DOOR_SYSTEM_GET_SIZE()`

## DRAW_BOX
`0xCD4D9DD5` | `void DRAW_BOX(float x1, float y1, float z1, float x2, float y2, float z2, int red, int green, int blue, int alpha)`

## DRAW_CORONA
`0xFF44780E` | `void DRAW_CORONA(float posX, float posY, float posZ, float size, int alpha, int red, int green, int blue, float intensity, float zBias, float dirX, float dirY, float dirZ, float viewThreshold, float innerAngle, float outerAngle, int flags)`
```lua
local pedCoords = GetEntityCoords(PlayerPedId())
Citizen.CreateThread(function()
    while true do
        DrawCorona(pedCoords.x, pedCoords.y, pedCoords.z, 5.0, 255, 255, 255, 255, 4.0, 0.2, pedCoords.x, pedCoords.y, pedCoords.z, 1.0, 0.0, 90.0, 2)
        Wait(0)
    end
end)
```

## DRAW_GIZMO
`0xEB2EDCA2` | `void DRAW_GIZMO(long matrixPtr, char* id)`

## DRAW_GLOW_SPHERE
`0xBD25EC89` | `void DRAW_GLOW_SPHERE(float posX, float posY, float posZ, float radius, int colorR, int colorG, int colorB, float intensity, BOOL invert, BOOL marker)`

## DRAW_LIGHT
`0x374E5298` | `void DRAW_LIGHT()`

## DRAW_LINE
`0xB3426BCC` | `void DRAW_LINE(float x1, float y1, float z1, float x2, float y2, float z2, int red, int green, int blue, int alpha)`

## DRAW_LINE_2D
`0xB856A90` | `void DRAW_LINE_2D(float x1, float y1, float x2, float y2, float width, int r, int g, int b, int a)`

## DRAW_POLY
`0xABD19253` | `void DRAW_POLY(float x1, float y1, float z1, float x2, float y2, float z2, float x3, float y3, float z3, int red, int green, int blue, int alpha)`

## DRAW_RECT_ROTATED
`0xEC37C168` | `void DRAW_RECT_ROTATED(float x, float y, float width, float height, float rotation, int r, int g, int b, int a)`

## DROP_PLAYER
`0xBA0613E1` | `void DROP_PLAYER(char* playerSrc, char* reason)`

## DUPLICATE_FUNCTION_REFERENCE
`0xF4E2079D` | `void DUPLICATE_FUNCTION_REFERENCE(char* referenceIdentity)`

## ENABLE_EDITOR_RUNTIME
`0xC383871D` | `void ENABLE_EDITOR_RUNTIME()`

## ENABLE_ENHANCED_HOST_SUPPORT
`0xF97B1C93` | `void ENABLE_ENHANCED_HOST_SUPPORT(BOOL enabled)`

## END_FIND_KVP
`0xB3210203` | `void END_FIND_KVP(int handle)`

## END_FIND_OBJECT
`0xDEDA4E50` | `void END_FIND_OBJECT(int findHandle)`

## END_FIND_PED
`0x9615C2AD` | `void END_FIND_PED(int findHandle)`

## END_FIND_PICKUP
`0x3C407D53` | `void END_FIND_PICKUP(int findHandle)`

## END_FIND_VEHICLE
`0x9227415A` | `void END_FIND_VEHICLE(int findHandle)`

## ENSURE_ENTITY_STATE_BAG
`0x3BB78F05` | `void ENSURE_ENTITY_STATE_BAG(Entity entity)`

## ENTER_CURSOR_MODE
`0x780DA86` | `void ENTER_CURSOR_MODE()`

## EXECUTE_COMMAND
`0x561C060B` | `void EXECUTE_COMMAND(char* commandString)`
```lua
Citizen.CreateThread(function()
  -- stop the server after 1 minute
  Citizen.Wait(60000)
  ExecuteCommand("quit Shortlived")
end)
```

## EXPERIMENTAL_LOAD_CLONE_CREATE
`0xD2CB95A3` | `void EXPERIMENTAL_LOAD_CLONE_CREATE(char* data, int objectId, char* tree)`

## EXPERIMENTAL_LOAD_CLONE_SYNC
`0x6BC189AC` | `void EXPERIMENTAL_LOAD_CLONE_SYNC(Entity entity, char* data)`

## EXPERIMENTAL_SAVE_CLONE_CREATE
`0x9D65CAD2` | `void EXPERIMENTAL_SAVE_CLONE_CREATE(Entity entity)`

## EXPERIMENTAL_SAVE_CLONE_SYNC
`0x38D19210` | `void EXPERIMENTAL_SAVE_CLONE_SYNC(Entity entity)`

## FIND_FIRST_OBJECT
`0xFAA6CB5D` | `void FIND_FIRST_OBJECT(Entity* outEntity)`

## FIND_FIRST_PED
`0xFB012961` | `void FIND_FIRST_PED(Entity* outEntity)`

## FIND_FIRST_PICKUP
`0x3FF9D340` | `void FIND_FIRST_PICKUP(Entity* outEntity)`

## FIND_FIRST_VEHICLE
`0x15E55694` | `void FIND_FIRST_VEHICLE(Entity* outEntity)`

## FIND_KVP
`0xBD7BEBC5` | `void FIND_KVP(int handle)`

## FIND_NEXT_OBJECT
`0x4E129DBF` | `void FIND_NEXT_OBJECT(int findHandle, Entity* outEntity)`

## FIND_NEXT_PED
`0xAB09B548` | `void FIND_NEXT_PED(int findHandle, Entity* outEntity)`

## FIND_NEXT_PICKUP
`0x4107EF0F` | `void FIND_NEXT_PICKUP(int findHandle, Entity* outEntity)`

## FIND_NEXT_VEHICLE
`0x8839120D` | `void FIND_NEXT_VEHICLE(int findHandle, Entity* outEntity)`

## FLAG_SERVER_AS_PRIVATE
`0x13B6855D` | `void FLAG_SERVER_AS_PRIVATE(BOOL private_)`

## FLUSH_RESOURCE_KVP
`0xE27C97A0` | `void FLUSH_RESOURCE_KVP()`
```lua
-- Bulk write many <key, value> pairs to the resource KVP.
local key = "bug_%d"
local value = "unintended_feature_%d"
for i=1,10000 do
	SetResourceKvpNoSync(key:format(i), value:format(i))
end

-- Ensure all data is synchronized to the filesystem
FlushResourceKvp()
```

## FORCE_SNOW_PASS
`0xE6E16170` | `void FORCE_SNOW_PASS(BOOL enabled)`

## FORMAT_STACK_TRACE
`0xD70C3BCA` | `void FORMAT_STACK_TRACE(object traceData)`

## FREEZE_ENTITY_POSITION
`0x65C16D57` | `void FREEZE_ENTITY_POSITION(Entity entity, BOOL toggle)`

## GET_ACTIVE_PLAYERS
`0xCF143FB9` | `void GET_ACTIVE_PLAYERS()`

## GET_AIR_DRAG_MULTIPLIER_FOR_PLAYERS_VEHICLE
`0x62FC38D0` | `void GET_AIR_DRAG_MULTIPLIER_FOR_PLAYERS_VEHICLE(char* playerSrc)`

## GET_ALL_OBJECTS
`0x6886C3FE` | `void GET_ALL_OBJECTS()`

## GET_ALL_PEDS
`0xB8584FEF` | `void GET_ALL_PEDS()`
```lua
-- This example prints information of every ped that has an owner.

for i, ped in ipairs(GetAllPeds()) do
    local pedOwner = NetworkGetEntityOwner(ped)
    if pedOwner > 0 then
       local playerName = GetPlayerName(pedOwner)
       local pedModel = GetEntityModel(ped)
       local pedArmour = GetPedArmour(ped)
       print("Ped : "..ped.." | Owner name : "..playerName.." | Model : "..pedModel.." | Armour : "..pedArmour)
    end
end
```

## GET_ALL_ROPES
`0x760A2D67` | `void GET_ALL_ROPES()`

## GET_ALL_TRACK_JUNCTIONS
`0x81A08523` | `void GET_ALL_TRACK_JUNCTIONS()`

## GET_ALL_VEHICLES
`0x332169F5` | `void GET_ALL_VEHICLES()`

## GET_ALL_VEHICLE_MODELS
`0xD7531645` | `void GET_ALL_VEHICLE_MODELS()`
```lua
RegisterCommand("spawnrandomcar", function()
	local vehicles = GetAllVehicleModels()
	local veh = vehicles[math.random(1, #vehicles)]
	RequestModel(veh)
	repeat Wait(0) until HasModelLoaded(veh)
	local veh = CreateVehicle(veh, GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()), true, false)
	SetPedIntoVehicle(PlayerPedId(), veh, -1)
end)
```

## GET_AMBIENT_PED_RANGE_MULTIPLIER
`0xB550232D` | `void GET_AMBIENT_PED_RANGE_MULTIPLIER()`

## GET_AMBIENT_VEHICLE_RANGE_MULTIPLIER
`0x667EC929` | `void GET_AMBIENT_VEHICLE_RANGE_MULTIPLIER()`

## GET_ASPECT_RATIO
`0x2CA8F641` | `void GET_ASPECT_RATIO()`

## GET_CALMING_QUAD_AT_COORDS
`0x870E8B40` | `void GET_CALMING_QUAD_AT_COORDS(float x, float y)`
```lua
local currentPedPosition = GetEntityCoords(PlayerPedId())
local calmingQuadIndex = GetCalmingQuadAtCoords(currentPedPosition.x, currentPedPosition.y)
```

## GET_CALMING_QUAD_BOUNDS
`0xFF60E63` | `void GET_CALMING_QUAD_BOUNDS(int waterQuad, int* minX, int* minY, int* maxX, int* maxY)`
```lua
local success, minX, minY, maxX, maxY = GetCalmingQuadBounds(1)
```

## GET_CALMING_QUAD_COUNT
`0xCEBFC42` | `void GET_CALMING_QUAD_COUNT()`
```lua
local calmingQuadCount = GetCalmingQuadCount()
```

## GET_CALMING_QUAD_DAMPENING
`0xB0E3A058` | `void GET_CALMING_QUAD_DAMPENING(int waterQuad, float* calmingQuadDampening)`
```lua
local success, dampening = GetCalmingQuadDampening(1)
```

## GET_CAM_MATRIX
`0x8F57A89D` | `void GET_CAM_MATRIX(Cam camera, Vector3* rightVector, Vector3* forwardVector, Vector3* upVector, Vector3* position)`

## GET_CLIENT_CONFIG_BOOL
`0xADA7DB9D` | `void GET_CLIENT_CONFIG_BOOL(int flagIndex)`

## GET_CLOSEST_TRACK_NODES
`0x59FC24A7` | `void GET_CLOSEST_TRACK_NODES(Vector3 position, float radius)`

## GET_CONSOLE_BUFFER
`0xE57429FA` | `void GET_CONSOLE_BUFFER()`

## GET_CONVAR
`0x6CCD2564` | `void GET_CONVAR(char* varName, char* default_)`
```lua
if GetConvar('voice_useNativeAudio', 'false') == 'true' then
    Citizen.Trace('Native Audio is enabled.')
end
```

## GET_CONVAR_BOOL
`0x7E8EBFE5` | `void GET_CONVAR_BOOL(char* varName, BOOL defaultValue)`
```lua
if GetConvarBool('dev_mode', false) then
    print("Dev Mode is eanbled, load dev mode menus")
end
```

## GET_CONVAR_FLOAT
`0x9E666D` | `void GET_CONVAR_FLOAT(char* varName, float defaultValue)`

## GET_CONVAR_INT
`0x935C0AB2` | `void GET_CONVAR_INT(char* varName, int default_)`
```lua
if GetConvarInt('remainingRounds', 0) < 900 then
    Citizen.Trace("Less than 900 rounds remaining...")
end
```

## GET_CURRENT_GAME_NAME
`0xACA18ECD` | `void GET_CURRENT_GAME_NAME()`

## GET_CURRENT_PED_WEAPON
`0xB0237302` | `void GET_CURRENT_PED_WEAPON(Ped ped)`

## GET_CURRENT_RESOURCE_NAME
`0xE5E9EBBB` | `void GET_CURRENT_RESOURCE_NAME()`

## GET_CURRENT_SCREEN_RESOLUTION
`0x337F0116` | `void GET_CURRENT_SCREEN_RESOLUTION(int* width, int* height)`

## GET_CURRENT_SERVER_ENDPOINT
`0xEA11BFBA` | `void GET_CURRENT_SERVER_ENDPOINT()`

## GET_DUI_HANDLE
`0x1655D41D` | `void GET_DUI_HANDLE(long duiObject)`

## GET_ENTITIES_IN_RADIUS
`0xDFFBA12F` | `void GET_ENTITIES_IN_RADIUS(float x, float y, float z, float radius, int entityType, BOOL sortByDistance, object models)`

## GET_ENTITY_ADDRESS
`0x9A3144BC` | `void GET_ENTITY_ADDRESS(Entity entity)`

## GET_ENTITY_ARCHETYPE_NAME
`0x47B870F5` | `void GET_ENTITY_ARCHETYPE_NAME(Entity entity)`

## GET_ENTITY_ATTACHED_TO
`0xFE1589F9` | `void GET_ENTITY_ATTACHED_TO(Entity entity)`

## GET_ENTITY_COLLISION_DISABLED
`0xE8C0C629` | `void GET_ENTITY_COLLISION_DISABLED(Entity entity)`

## GET_ENTITY_COORDS
`0x1647F1CB` | `void GET_ENTITY_COORDS(Entity entity)`
```lua
local function ShowCoordinates()
    local player = source
    local ped = GetPlayerPed(player)
    local playerCoords = GetEntityCoords(ped)

    print(playerCoords) -- vector3(...)
end

RegisterNetEvent("myCoordinates")
AddEventHandler("myCoordinates", ShowCoordinates)
```
```js
onNet('myCoordinates', () => {
  const player = global.source; // use (global as any).source for Typescript
  const ped = GetPlayerPed(player);
  const [playerX, playerY, playerZ] = GetEntityCoords(ped);

  console.log(`${playerX}, ${playerY}, ${playerZ}`);
});
```
```cs
using static CitizenFX.Core.Native.API;
// ...

// In class constructor
EventHandlers["myCoordinates"] += new Action<Player>(ShowCoordinates);

// Delegate method
private void ShowCoordinates([FromSource]Player player) {
    Vector3 playerCoords = GetEntityCoords(player.Character);

    // or the preferred use of C# wrapper
    Vector3 playerCoords = player.Character.Position;

    Debug.WriteLine($"{playerCoords}");
}

```

## GET_ENTITY_FROM_STATE_BAG_NAME
`0x4BDF1867` | `void GET_ENTITY_FROM_STATE_BAG_NAME(char* bagName)`
```js
AddStateBagChangeHandler("blockTasks", null, async (bagName, key, value /* boolean */) => {
    let entity = GetEntityFromStateBagName(bagName);
    // Whoops, we were don't have a valid entity!
    if (entity === 0) return;
    // We don't want to freeze the entity position if the entity collision hasn't loaded yet
    while (!HasCollisionLoadedAroundEntity(entity)) {
        // The entity went out of our scope before the collision loaded
        if (!DoesEntityExist(entity)) return;
        await Delay(250);
    }
    SetEntityInvincible(entity, value)
    FreezeEntityPosition(entity, value)
    TaskSetBlockingOfNonTemporaryEvents(entity, value)
})
```
```lua
AddStateBagChangeHandler("blockTasks", nil, function(bagName, key, value) 
    local entity = GetEntityFromStateBagName(bagName)
    -- Whoops, we don't have a valid entity!
    if entity == 0 then return end
    -- We don't want to freeze the entity position if the entity collision hasn't loaded yet
    while not HasCollisionLoadedAroundEntity(entity) do
        -- The entity went out of our scope before the collision loaded
        if not DoesEntityExist(entity) then return end
        Wait(250)
    end
    SetEntityInvincible(entity, value)
    FreezeEntityPosition(entity, value)
    TaskSetBlockingOfNonTemporaryEvents(entity, value)
end)
```

## GET_ENTITY_HEADING
`0x972CC383` | `void GET_ENTITY_HEADING(Entity entity)`

## GET_ENTITY_HEALTH
`0x8E3222B7` | `void GET_ENTITY_HEALTH(Entity entity)`

## GET_ENTITY_INDEX_FROM_MAPDATA
`0xEE43540D` | `void GET_ENTITY_INDEX_FROM_MAPDATA(int mapdata, int entity)`

## GET_ENTITY_MAPDATA_OWNER
`0xF6B815C5` | `void GET_ENTITY_MAPDATA_OWNER(Entity entity, int* mapdataHandle, int* entityHandle)`

## GET_ENTITY_MAX_HEALTH
`0xC7AE6AA1` | `void GET_ENTITY_MAX_HEALTH(Entity entity)`

## GET_ENTITY_MODEL
`0xDAFCB3EC` | `void GET_ENTITY_MODEL(Entity entity)`

## GET_ENTITY_ORPHAN_MODE
`0xD16EA02F` | `void GET_ENTITY_ORPHAN_MODE(Entity entity)`

## GET_ENTITY_POPULATION_TYPE
`0xFC30DDFF` | `void GET_ENTITY_POPULATION_TYPE(Entity entity)`

## GET_ENTITY_REMOTE_SYNCED_SCENES_ALLOWED
`0x91B38FB6` | `void GET_ENTITY_REMOTE_SYNCED_SCENES_ALLOWED(Entity entity)`

## GET_ENTITY_ROTATION
`0x8FF45B04` | `void GET_ENTITY_ROTATION(Entity entity)`

## GET_ENTITY_ROTATION_VELOCITY
`0x9BF8A73F` | `void GET_ENTITY_ROTATION_VELOCITY(Entity entity)`

## GET_ENTITY_ROUTING_BUCKET
`0xED4B0486` | `void GET_ENTITY_ROUTING_BUCKET(Entity entity)`

## GET_ENTITY_SCRIPT
`0xB7F70784` | `void GET_ENTITY_SCRIPT(Entity entity)`

## GET_ENTITY_SPEED
`0x9E1E4798` | `void GET_ENTITY_SPEED(Entity entity)`

## GET_ENTITY_TYPE
`0xB1BD08D` | `void GET_ENTITY_TYPE(Entity entity)`

## GET_ENTITY_VELOCITY
`0xC14C9B6B` | `void GET_ENTITY_VELOCITY(Entity entity)`

## GET_EXTERNAL_KVP_FLOAT
`0x3CC98B25` | `void GET_EXTERNAL_KVP_FLOAT(char* resource, char* key)`
```lua
local kvpValue = GetExternalKvpFloat('drugs', 'mollis') 
if kvpValue then
	-- do something!
end
```

## GET_EXTERNAL_KVP_INT
`0x12B8D689` | `void GET_EXTERNAL_KVP_INT(char* resource, char* key)`
```lua
local kvpValue = GetExternalKvpInt('food', 'bananabread') 
if kvpValue then
	-- do something!
end
```

## GET_EXTERNAL_KVP_STRING
`0x9080363A` | `void GET_EXTERNAL_KVP_STRING(char* resource, char* key)`
```lua
local kvpValue = GetExternalKvpString('food', 'codfish') 
if kvpValue then
	-- do something!
end
```

## GET_FALL_DAMAGE_LAND_ON_FOOT_MULTIPLIER
`0x2C048945` | `void GET_FALL_DAMAGE_LAND_ON_FOOT_MULTIPLIER()`

## GET_FALL_DAMAGE_MULTIPLIER
`0x7C46A6F0` | `void GET_FALL_DAMAGE_MULTIPLIER()`

## GET_FUEL_CONSUMPTION_RATE_MULTIPLIER
`0x5550BF9F` | `void GET_FUEL_CONSUMPTION_RATE_MULTIPLIER()`

## GET_FUEL_CONSUMPTION_STATE
`0xC66CD90C` | `void GET_FUEL_CONSUMPTION_STATE()`

## GET_GAME_BUILD_NUMBER
`0x804B9F7B` | `void GET_GAME_BUILD_NUMBER()`

## GET_GAME_NAME
`0xE8EAA18B` | `void GET_GAME_NAME()`

## GET_GAME_POOL
`0x2B9D4F50` | `void GET_GAME_POOL(char* poolName)`
```lua
local vehiclePool = GetGamePool('CVehicle') -- Get the list of vehicles (entities) from the pool
for i = 1, #vehiclePool do -- loop through each vehicle (entity)
    if GetPedInVehicleSeat(vehiclePool[i], -1) == 0 then
        DeleteEntity(vehiclePool[i]) -- Delete vehicles (entities) that don't have a driver
    end
end
```

## GET_GAME_TIMER
`0xA4EA0691` | `void GET_GAME_TIMER()`

## GET_GLOBAL_PASSENGER_MASS_MULTIPLIER
`0x78951816` | `void GET_GLOBAL_PASSENGER_MASS_MULTIPLIER()`

## GET_HASH_KEY
`0x98EFF6F1` | `void GET_HASH_KEY(char* model)`

## GET_HELI_BODY_HEALTH
`0xA886495D` | `void GET_HELI_BODY_HEALTH(Vehicle heli)`

## GET_HELI_DISABLE_EXPLODE_FROM_BODY_DAMAGE
`0x82AFC0A3` | `void GET_HELI_DISABLE_EXPLODE_FROM_BODY_DAMAGE(Vehicle heli)`

## GET_HELI_ENGINE_HEALTH
`0xA0FA0354` | `void GET_HELI_ENGINE_HEALTH(Vehicle heli)`

## GET_HELI_GAS_TANK_HEALTH
`0xD4EC7858` | `void GET_HELI_GAS_TANK_HEALTH(Vehicle heli)`

## GET_HELI_MAIN_ROTOR_DAMAGE_SCALE
`0xC37D668` | `void GET_HELI_MAIN_ROTOR_DAMAGE_SCALE(Vehicle heli)`

## GET_HELI_MAIN_ROTOR_HEALTH
`0xF01E2AAB` | `void GET_HELI_MAIN_ROTOR_HEALTH(Vehicle vehicle)`

## GET_HELI_PITCH_CONTROL
`0x1944AC95` | `void GET_HELI_PITCH_CONTROL(Vehicle heli)`

## GET_HELI_REAR_ROTOR_DAMAGE_SCALE
`0xC40161E2` | `void GET_HELI_REAR_ROTOR_DAMAGE_SCALE(Vehicle heli)`

## GET_HELI_REAR_ROTOR_HEALTH
`0x33EE6E2B` | `void GET_HELI_REAR_ROTOR_HEALTH(Vehicle vehicle)`

## GET_HELI_ROLL_CONTROL
`0x12948DE9` | `void GET_HELI_ROLL_CONTROL(Vehicle heli)`

## GET_HELI_TAIL_ROTOR_DAMAGE_SCALE
`0x22239130` | `void GET_HELI_TAIL_ROTOR_DAMAGE_SCALE(Vehicle heli)`

## GET_HELI_TAIL_ROTOR_HEALTH
`0xA41BC13D` | `void GET_HELI_TAIL_ROTOR_HEALTH(Vehicle vehicle)`

## GET_HELI_THROTTLE_CONTROL
`0x8E86238D` | `void GET_HELI_THROTTLE_CONTROL(Vehicle heli)`

## GET_HELI_YAW_CONTROL
`0x8FDC0768` | `void GET_HELI_YAW_CONTROL(Vehicle heli)`

## GET_HOST_ID
`0x5F70F5A3` | `void GET_HOST_ID()`

## GET_HUD_COMPONENT_ALIGN
`0xCD949E20` | `void GET_HUD_COMPONENT_ALIGN(int id, int* horizontalAlign, int* verticalAlign)`

## GET_HUD_COMPONENT_NAME
`0xA91866BC` | `void GET_HUD_COMPONENT_NAME(int id)`

## GET_HUD_COMPONENT_SIZE
`0x12217D33` | `void GET_HUD_COMPONENT_SIZE(int id)`

## GET_INSTANCE_ID
`0x9F1C4383` | `void GET_INSTANCE_ID()`

## GET_INTERIOR_ENTITIES_EXTENTS
`0x322B1192` | `void GET_INTERIOR_ENTITIES_EXTENTS(int interiorId, float* bbMinX, float* bbMinY, float* bbMinZ, float* bbMaxX, float* bbMaxY, float* bbMaxZ)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local minX, minY, minZ, maxX, maxY, maxZ = GetInteriorEntitiesExtents(interiorId, roomId)
  print("current entities extents is: " .. vec(minX, minY, minZ) .." / " .. vec(maxX, maxY, maxZ))
end
```

## GET_INTERIOR_PORTAL_CORNER_POSITION
`0xF772BB2C` | `void GET_INTERIOR_PORTAL_CORNER_POSITION(int interiorId, int portalIndex, int cornerIndex, float* posX, float* posY, float* posZ)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local portalIndex = 0
  local cornerIndex = 0

  local x, y, z = GetInteriorPortalCornerPosition(interiorId, portalIndex, cornerIndex)
  print("position of portal " .. portalIndex .. "corner index " .. cornerIndex .. " is: " .. vec(x, y, z))
end
```

## GET_INTERIOR_PORTAL_COUNT
`0xD05BB8B1` | `void GET_INTERIOR_PORTAL_COUNT(int interiorId)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local count = GetInteriorPortalCount(interiorId)
  print("interior " .. interiorId .. "has " .. count .. " portals")
end
```

## GET_INTERIOR_PORTAL_ENTITY_ARCHETYPE
`0x9A0E1700` | `void GET_INTERIOR_PORTAL_ENTITY_ARCHETYPE(int interiorId, int portalIndex, int entityIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local portalIndex = 0

if interiorId ~= 0 then
  local count = GetInteriorPortalEntityCount(interiorId, portalIndex)
  for i=0, count-1 do
    local archetype = GetInteriorPortalEntityArchetype(interiorId, portalIndex, i)
    print("portal " .. portalIndex .." entity " .. i .. " archetype is: " .. archetype)
  end
end
```

## GET_INTERIOR_PORTAL_ENTITY_COUNT
`0xC68021B` | `void GET_INTERIOR_PORTAL_ENTITY_COUNT(int interiorId, int portalIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local portalIndex = 0

if interiorId ~= 0 then
  local count = GetInteriorPortalEntityCount(interiorId, portalIndex)
  print("portal " .. portalIndex .." entity count is: " .. count)
end
```

## GET_INTERIOR_PORTAL_ENTITY_FLAG
`0x9DA2E811` | `void GET_INTERIOR_PORTAL_ENTITY_FLAG(int interiorId, int portalIndex, int entityIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local portalIndex = 0

if interiorId ~= 0 then
  local count = GetInteriorPortalEntityCount(interiorId, portalIndex)
  for i=0, count-1 do
    local flag = GetInteriorPortalEntityFlag(interiorId, portalIndex, i)
    print("portal " .. portalIndex .." entity " .. i .. " flag is: " .. flag)
  end
end
```

## GET_INTERIOR_PORTAL_ENTITY_POSITION
`0x9B7AB83C` | `void GET_INTERIOR_PORTAL_ENTITY_POSITION(int interiorId, int portalIndex, int entityIndex, float* posX, float* posY, float* posZ)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local portalIndex = 0

if interiorId ~= 0 then
  local count = GetInteriorPortalEntityCount(interiorId, portalIndex)
  for i=0, count-1 do
    local x, y, z = GetInteriorPortalEntityPosition(interiorId, portalIndex, i)
    print("portal " .. portalIndex .." entity " .. i .. " position is: " .. vec3(x, y, z))
  end
end
```

## GET_INTERIOR_PORTAL_ENTITY_ROTATION
`0x9F9CEB63` | `void GET_INTERIOR_PORTAL_ENTITY_ROTATION(int interiorId, int portalIndex, int entityIndex, float* rotX, float* rotY, float* rotZ, float* rotW)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local portalIndex = 0

if interiorId ~= 0 then
  local count = GetInteriorPortalEntityCount(interiorId, portalIndex)
  for i=0, count-1 do
    local x, y, z, w = GetInteriorPortalEntityRotation(interiorId, portalIndex, i)
    print("portal " .. portalIndex .." entity " .. i .. " rotation is: " .. vec4(x, y, z, w))
  end
end
```

## GET_INTERIOR_PORTAL_FLAG
`0xC74DA47C` | `void GET_INTERIOR_PORTAL_FLAG(int interiorId, int portalIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local portalFlag = GetInteriorPortalFlag(interiorId, 0)
  print("portal 0 flag is: " .. portalRoomFrom)
end
```

## GET_INTERIOR_PORTAL_ROOM_FROM
`0xAA9C141D` | `void GET_INTERIOR_PORTAL_ROOM_FROM(int interiorId, int portalIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local roomIndex = 0

  local portalRoomFrom = GetInteriorPortalRoomFrom(interiorId, 0)
  print("portal " .. roomIndex .. " room FROM is: " .. portalRoomFrom)
end
```

## GET_INTERIOR_PORTAL_ROOM_TO
`0x3F47F0E8` | `void GET_INTERIOR_PORTAL_ROOM_TO(int interiorId, int portalIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local roomIndex = 0

  local portalRoomTo = GetInteriorPortalRoomTo(interiorId, 0)
  print("portal " .. roomIndex .. " room TO is: " .. portalRoomTo)
end
```

## GET_INTERIOR_POSITION
`0x77A435B0` | `void GET_INTERIOR_POSITION(int interiorId, float* posX, float* posY, float* posZ)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local x, y, z = GetInteriorPosition(interiorId)
  print("current interior " .. interiorId .. " position is: " .. vec(x, y, z))
end
```

## GET_INTERIOR_ROOM_COUNT
`0xA2737C2C` | `void GET_INTERIOR_ROOM_COUNT(int interiorId)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local count = GetInteriorRoomCount(interiorId)
  print("interior " .. interiorId .. "has " .. count .. " rooms")
end
```

## GET_INTERIOR_ROOM_EXTENTS
`0xF9E795DD` | `void GET_INTERIOR_ROOM_EXTENTS(int interiorId, int roomIndex, float* bbMinX, float* bbMinY, float* bbMinZ, float* bbMaxX, float* bbMaxY, float* bbMaxZ)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local roomHash = GetRoomKeyFromEntity(playerPed)
local roomId = GetInteriorRoomIndexByHash(interiorId, roomHash)

if roomId ~= -1 then
  local minX, minY, minZ, maxX, maxY, maxZ = GetInteriorRoomExtents(interiorId, roomId)
  print("current room extents is: " .. vec(minX, minY, minZ) .." / " .. vec(maxX, maxY, maxZ))
end
```

## GET_INTERIOR_ROOM_FLAG
`0x6B7AF743` | `void GET_INTERIOR_ROOM_FLAG(int interiorId, int roomIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local roomHash = GetRoomKeyFromEntity(playerPed)
local roomId = GetInteriorRoomIndexByHash(interiorId, roomHash)

if roomId ~= -1 then
  local roomFlag = GetInteriorRoomFlag(interiorId, roomId)
  print("current room flag is: " .. roomFlag)
end
```

## GET_INTERIOR_ROOM_INDEX_BY_HASH
`0xE0EE05F8` | `void GET_INTERIOR_ROOM_INDEX_BY_HASH(int interiorId, int roomHash)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local roomHash = GetRoomKeyFromEntity(playerPed)
local roomId = GetInteriorRoomIndexByHash(interiorId, roomHash)

if roomId ~= -1 then
  print("current room index is: " .. roomId)
end
```

## GET_INTERIOR_ROOM_NAME
`0x11755DF2` | `void GET_INTERIOR_ROOM_NAME(int interiorId, int roomIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local roomHash = GetRoomKeyFromEntity(playerPed)
local roomId = GetInteriorRoomIndexByHash(interiorId, roomHash)

if roomId ~= -1 then
  local roomName = GetInteriorRoomName(interiorId, roomId)
  print("current room name is: " .. roomName)
end
```

## GET_INTERIOR_ROOM_TIMECYCLE
`0x82BA3F88` | `void GET_INTERIOR_ROOM_TIMECYCLE(int interiorId, int roomIndex)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local roomHash = GetRoomKeyFromEntity(playerPed)
local roomId = GetInteriorRoomIndexByHash(interiorId, roomHash)

if roomId ~= -1 then
  local roomTimecycle = GetInteriorRoomTimecycle(interiorId, roomId)
  print("current room timecycle hash is: " .. roomTimecycle)
end
```

## GET_INTERIOR_ROTATION
`0x5A039998` | `void GET_INTERIOR_ROTATION(int interiorId, float* rotx, float* rotY, float* rotZ, float* rotW)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local x, y, z, w = GetInteriorRotation(interiorId)
  print("current interior " .. interiorId .. " rotation is: " .. vec(x, y, z, w))
end
```

## GET_INVOKING_RESOURCE
`0x4D52FE5B` | `void GET_INVOKING_RESOURCE()`

## GET_IS_HELI_ENGINE_RUNNING
`0x3EFE38D1` | `void GET_IS_HELI_ENGINE_RUNNING(Vehicle heli)`

## GET_IS_VEHICLE_ENGINE_RUNNING
`0x7DC6D022` | `void GET_IS_VEHICLE_ENGINE_RUNNING(Vehicle vehicle)`

## GET_IS_VEHICLE_PRIMARY_COLOUR_CUSTOM
`0xD7EC8760` | `void GET_IS_VEHICLE_PRIMARY_COLOUR_CUSTOM(Vehicle vehicle)`

## GET_IS_VEHICLE_SECONDARY_COLOUR_CUSTOM
`0x288AD228` | `void GET_IS_VEHICLE_SECONDARY_COLOUR_CUSTOM(Vehicle vehicle)`

## GET_KILL_FALL_HEIGHT
`0x57888D4C` | `void GET_KILL_FALL_HEIGHT()`

## GET_LANDING_GEAR_STATE
`0xA6F02670` | `void GET_LANDING_GEAR_STATE(Vehicle vehicle)`

## GET_LAST_PED_IN_VEHICLE_SEAT
`0xF7C6792D` | `void GET_LAST_PED_IN_VEHICLE_SEAT(Vehicle vehicle, int seatIndex)`

## GET_MAPDATA_ENTITY_HANDLE
`0x30AA6911` | `void GET_MAPDATA_ENTITY_HANDLE(int mapDataHash, int entityInternalIdx, int* entityHandle)`

## GET_MAPDATA_ENTITY_MATRIX
`0x2C3CDA93` | `void GET_MAPDATA_ENTITY_MATRIX(int mapDataHash, int entityInternalIdx, long matrixPtr)`

## GET_MAPDATA_FROM_HASH_KEY
`0xD29D8EDD` | `void GET_MAPDATA_FROM_HASH_KEY(Hash mapdataHandle)`

## GET_MAP_ZOOM_DATA_LEVEL
`0x1363A998` | `void GET_MAP_ZOOM_DATA_LEVEL(int index, float* zoomScale, float* zoomSpeed, float* scrollSpeed, float* tilesX, float* tilesY)`

## GET_MINIMAP_TYPE
`0xA6FF71C9` | `void GET_MINIMAP_TYPE()`

## GET_MOUNT
`0xDD31EC4E` | `void GET_MOUNT(Ped ped)`

## GET_NETWORK_WALK_MODE
`0x2CAFD5E9` | `void GET_NETWORK_WALK_MODE()`

## GET_NET_TYPE_FROM_ENTITY
`0x23B2A641` | `void GET_NET_TYPE_FROM_ENTITY(Entity entity)`

## GET_NUI_CURSOR_POSITION
`0xBDBA226F` | `void GET_NUI_CURSOR_POSITION(int* x, int* y)`

## GET_NUMBER_OF_PED_COLLECTION_DRAWABLE_VARIATIONS
`0x310D0271` | `void GET_NUMBER_OF_PED_COLLECTION_DRAWABLE_VARIATIONS(Ped ped, int componentId, char* collection)`

## GET_NUMBER_OF_PED_COLLECTION_PROP_DRAWABLE_VARIATIONS
`0x3B6A13E1` | `void GET_NUMBER_OF_PED_COLLECTION_PROP_DRAWABLE_VARIATIONS(Ped ped, int anchorPoint, char* collection)`

## GET_NUMBER_OF_PED_COLLECTION_PROP_TEXTURE_VARIATIONS
`0x75CAF9CC` | `void GET_NUMBER_OF_PED_COLLECTION_PROP_TEXTURE_VARIATIONS(Ped ped, int anchorPoint, char* collection, int propIndex)`

## GET_NUMBER_OF_PED_COLLECTION_TEXTURE_VARIATIONS
`0xD2C15D7` | `void GET_NUMBER_OF_PED_COLLECTION_TEXTURE_VARIATIONS(Ped ped, int componentId, char* collection, int drawableId)`

## GET_NUM_PLAYER_IDENTIFIERS
`0xFF7F66AB` | `void GET_NUM_PLAYER_IDENTIFIERS(char* playerSrc)`

## GET_NUM_PLAYER_INDICES
`0x63D13184` | `void GET_NUM_PLAYER_INDICES()`

## GET_NUM_PLAYER_TOKENS
`0x619E4A3D` | `void GET_NUM_PLAYER_TOKENS(char* playerSrc)`

## GET_NUM_RESOURCES
`0x863F27B` | `void GET_NUM_RESOURCES()`

## GET_NUM_RESOURCE_METADATA
`0x776E864` | `void GET_NUM_RESOURCE_METADATA(char* resourceName, char* metadataKey)`

## GET_PARKED_VEHICLE_DENSITY_MULTIPLIER
`0xFF72DF84` | `void GET_PARKED_VEHICLE_DENSITY_MULTIPLIER()`

## GET_PASSWORD_HASH
`0x23473EA4` | `void GET_PASSWORD_HASH(char* password)`

## GET_PAUSE_MAP_POINTER_WORLD_POSITION
`0xE5AF7A82` | `void GET_PAUSE_MAP_POINTER_WORLD_POSITION()`

## GET_PED_ARMOUR
`0x2CE311A7` | `void GET_PED_ARMOUR(Ped ped)`

## GET_PED_BONE_MATRIX
`0x9C5E7C9C` | `void GET_PED_BONE_MATRIX(Ped ped, int boneId, Vector3* forwardVector, Vector3* rightVector, Vector3* upVector, Vector3* position)`
```lua
local fowardVector, rightVector, upVector, position = GetPedBoneMatrix(PlayerPedId(),boneId)
```

## GET_PED_CAUSE_OF_DEATH
`0x63458C27` | `void GET_PED_CAUSE_OF_DEATH(Ped ped)`

## GET_PED_COLLECTIONS_COUNT
`0x45946359` | `void GET_PED_COLLECTIONS_COUNT(Ped ped)`
```lua
local ped = PlayerPedId()
local count = GetPedCollectionsCount(ped)
for i = 0, count - 1 do
  print(GetPedCollectionName(ped, i))
end
```

## GET_PED_COLLECTION_LOCAL_INDEX_FROM_DRAWABLE
`0x94EB1FE4` | `void GET_PED_COLLECTION_LOCAL_INDEX_FROM_DRAWABLE(Ped ped, int componentId, int drawableId)`
```lua
local ped = PlayerPedId()
-- Top for mp_f_freemode_01. From female_freemode_beach collection under index 1.
-- Global index is 17 because there is 16 top variations in the base game collection that goes before the female_freemode_beach collection.
local name = GetPedDrawableCollectionName(ped, 11, 17)
local index = GetPedDrawableCollectionLocalIndex(ped, 11, 17)
-- Equivalent to SetPedComponentVariation(ped, 11, 17, 0, 0)
SetPedCollectionComponentVariation(ped, 11, name, index, 0, 0)
```

## GET_PED_COLLECTION_LOCAL_INDEX_FROM_PROP
`0xFBDB885F` | `void GET_PED_COLLECTION_LOCAL_INDEX_FROM_PROP(Ped ped, int anchorPoint, int propIndex)`
```lua
local ped = PlayerPedId()
-- Hat for mp_f_freemode_01. From female_freemode_beach collection under index 1.
-- Global index is 21 because there is 20 head prop variations in the base game collection that goes before the female_freemode_beach collection.
local name = GetPedPropCollectionName(ped, 0, 21)
local index = GetPedPropCollectionLocalIndex(ped, 0, 21)
-- Equivalent to SetPedPropIndex(ped, 0, 21, 0, false)
SetPedCollectionPropIndex(ped, 0, name, index, 0, false)
```

## GET_PED_COLLECTION_NAME
`0xFED5D83A` | `void GET_PED_COLLECTION_NAME(Ped ped, int index)`
```lua
local ped = PlayerPedId()
local count = GetPedCollectionsCount(ped)
for i = 0, count - 1 do
  print(GetPedCollectionName(ped, i))
end
```

## GET_PED_COLLECTION_NAME_FROM_DRAWABLE
`0xD6BBA48B` | `void GET_PED_COLLECTION_NAME_FROM_DRAWABLE(Ped ped, int componentId, int drawableId)`
```lua
local ped = PlayerPedId()
-- Top for mp_f_freemode_01. From female_freemode_beach collection under index 1.
-- Global index is 17 because there is 16 top variations in the base game collection that goes before the female_freemode_beach collection.
local name = GetPedDrawableCollectionName(ped, 11, 17)
local index = GetPedDrawableCollectionLocalIndex(ped, 11, 17)
-- Equivalent to SetPedComponentVariation(ped, 11, 17, 0, 0)
SetPedCollectionComponentVariation(ped, 11, name, index, 0, 0)
```

## GET_PED_COLLECTION_NAME_FROM_PROP
`0x8ED0C17` | `void GET_PED_COLLECTION_NAME_FROM_PROP(Ped ped, int anchorPoint, int propIndex)`
```lua
local ped = PlayerPedId()
-- Hat for mp_f_freemode_01. From female_freemode_beach collection under index 1.
-- Global index is 21 because there is 20 head prop variations in the base game collection that goes before the female_freemode_beach collection.
local name = GetPedPropCollectionName(ped, 0, 21)
local index = GetPedPropCollectionLocalIndex(ped, 0, 21)
-- Equivalent to SetPedPropIndex(ped, 0, 21, 0, false)
SetPedCollectionPropIndex(ped, 0, name, index, 0, false)
```

## GET_PED_DECORATIONS
`0x7CCE1163` | `void GET_PED_DECORATIONS(Ped ped)`

## GET_PED_DENSITY_MULTIPLIER
`0xF5A904F9` | `void GET_PED_DENSITY_MULTIPLIER()`

## GET_PED_DESIRED_HEADING
`0xC182F76E` | `void GET_PED_DESIRED_HEADING(Ped ped)`

## GET_PED_DRAWABLE_GLOBAL_INDEX_FROM_COLLECTION
`0x280F1FC3` | `void GET_PED_DRAWABLE_GLOBAL_INDEX_FROM_COLLECTION(Ped ped, int componentId, char* collection, int drawableId)`

## GET_PED_DRAWABLE_VARIATION_COLLECTION_LOCAL_INDEX
`0x9970386F` | `void GET_PED_DRAWABLE_VARIATION_COLLECTION_LOCAL_INDEX(Ped ped, int componentId)`

## GET_PED_DRAWABLE_VARIATION_COLLECTION_NAME
`0xBCE0AB63` | `void GET_PED_DRAWABLE_VARIATION_COLLECTION_NAME(Ped ped, int componentId)`

## GET_PED_EYE_COLOR
`0xA47B860F` | `void GET_PED_EYE_COLOR(Ped ped)`
```lua
local pedEyeColour = GetPedEyeColor(PlayerPedId())
if pedEyeColour == 7 then
  print("Gray eyes!")
end
```

## GET_PED_FACE_FEATURE
`0xBA352ADD` | `void GET_PED_FACE_FEATURE(Ped ped, int index)`
```lua
local noseWidth = GetPedFaceFeature(PlayerPedId(), 0)
if noseWidth == 1.0 then
  print("You have big nose!")
end
```

## GET_PED_HAIR_COLOR
`0xA3EA2893` | `void GET_PED_HAIR_COLOR(Ped ped)`
```lua
local primaryColour = GetPedHairColor(PlayerPedId())
if primaryColour == 18 then
  print("You have red hair!")
end
```

## GET_PED_HAIR_HIGHLIGHT_COLOR
`0x4B087305` | `void GET_PED_HAIR_HIGHLIGHT_COLOR(Ped ped)`
```lua
local secondaryColour = GetPedHairHighlightColor(PlayerPedId())
if secondaryColour == 32 then
  print("You have pink hair highlight colour!")
end
```

## GET_PED_HEAD_OVERLAY_DATA
`0xC46EE605` | `void GET_PED_HEAD_OVERLAY_DATA(Ped ped, int index, int* overlayValue, int* colourType, int* firstColour, int* secondColour, float* overlayOpacity)`
```lua
-- getting beard overlay data
local success, overlayValue, colourType, firstColour, secondColour, overlayOpacity = GetPedHeadOverlayData(PlayerPedId(), 1)
if success then
  -- incrementing value
  SetPedHeadOverlay(PlayerPedId(), 1, overlayValue + 1, overlayOpacity)
end
```

## GET_PED_IN_VEHICLE_SEAT
`0x388FDE9A` | `void GET_PED_IN_VEHICLE_SEAT(Vehicle vehicle, int seatIndex)`

## GET_PED_MAX_HEALTH
`0xA45B6C8D` | `void GET_PED_MAX_HEALTH(Ped ped)`

## GET_PED_MODEL_HEALTH_CONFIG
`0xF71542F7` | `void GET_PED_MODEL_HEALTH_CONFIG(Hash modelHash)`
```lua
GetPedModelHealthConfig(`mp_f_freemode_01`)
```

## GET_PED_MODEL_PERSONALITY
`0xFE08CAD6` | `void GET_PED_MODEL_PERSONALITY(Hash modelHash)`

## GET_PED_MOVEMENT_CLIPSET
`0x69E81E3D` | `void GET_PED_MOVEMENT_CLIPSET(Ped ped)`

## GET_PED_PROP_COLLECTION_LOCAL_INDEX
`0xCD420AD1` | `void GET_PED_PROP_COLLECTION_LOCAL_INDEX(Ped ped, int anchorPoint)`

## GET_PED_PROP_COLLECTION_NAME
`0x6B5653E4` | `void GET_PED_PROP_COLLECTION_NAME(Ped ped, int anchorPoint)`

## GET_PED_PROP_GLOBAL_INDEX_FROM_COLLECTION
`0x2CB45CDC` | `void GET_PED_PROP_GLOBAL_INDEX_FROM_COLLECTION(Ped ped, int anchorPoint, char* collection, int propIndex)`

## GET_PED_RELATIONSHIP_GROUP_HASH
`0x354F283C` | `void GET_PED_RELATIONSHIP_GROUP_HASH(Ped ped)`

## GET_PED_SCALE
`0xA0F3B420` | `void GET_PED_SCALE(Ped ped)`

## GET_PED_SCRIPT_TASK_COMMAND
`0x84FE084` | `void GET_PED_SCRIPT_TASK_COMMAND(Ped ped)`

## GET_PED_SCRIPT_TASK_STAGE
`0x44B0E5E2` | `void GET_PED_SCRIPT_TASK_STAGE(Ped ped)`

## GET_PED_SOURCE_OF_DAMAGE
`0x535DB43F` | `void GET_PED_SOURCE_OF_DAMAGE(Ped ped)`

## GET_PED_SOURCE_OF_DEATH
`0x84ADF9EB` | `void GET_PED_SOURCE_OF_DEATH(Ped ped)`

## GET_PED_SPECIFIC_TASK_TYPE
`0x7F4563D3` | `void GET_PED_SPECIFIC_TASK_TYPE(Ped ped, int index)`

## GET_PED_STEALTH_MOVEMENT
`0x40321B83` | `void GET_PED_STEALTH_MOVEMENT(Ped ped)`

## GET_PED_SWEAT
`0x44B91E94` | `void GET_PED_SWEAT(Ped ped)`
```lua
local sweat = GetPedSweat(PlayerPedId())
```

## GET_PED_WETNESS
`0xF402C171` | `void GET_PED_WETNESS(Ped ped)`

## GET_PED_WETNESS_HEIGHT
`0x2545ADE0` | `void GET_PED_WETNESS_HEIGHT(Ped ped)`

## GET_PLAYER_CAMERA_ROTATION
`0x433C765D` | `void GET_PLAYER_CAMERA_ROTATION(char* playerSrc)`

## GET_PLAYER_ENDPOINT
`0xFEE404F9` | `void GET_PLAYER_ENDPOINT(char* playerSrc)`

## GET_PLAYER_FAKE_WANTED_LEVEL
`0x98D244` | `void GET_PLAYER_FAKE_WANTED_LEVEL(char* playerSrc)`

## GET_PLAYER_FOCUS_POS
`0x586F80FF` | `void GET_PLAYER_FOCUS_POS(char* playerSrc)`

## GET_PLAYER_FROM_INDEX
`0xC8A9CE08` | `void GET_PLAYER_FROM_INDEX(int index)`

## GET_PLAYER_FROM_SERVER_ID
`0x344EA166` | `void GET_PLAYER_FROM_SERVER_ID(int serverId)`
```lua
--We will assume the serverId is '4' in this scenario and that it's a valid serverId.

-- Passing invalid Player IDs such as 'nil' or IDs that don't exist will result in playerId being -1.

local playerId = GetPlayerFromServerId(serverId);

-- If the resulting playerId is not invalid (not equal to -1)
if playerId ~= -1 then
    -- Do our stuff on this player.
end

```

## GET_PLAYER_FROM_STATE_BAG_NAME
`0xA56135E0` | `void GET_PLAYER_FROM_STATE_BAG_NAME(char* bagName)`
```js
AddStateBagChangeHandler("isDead", null, async (bagName, key, value /* boolean */) => {
    const ply = GetPlayerFromStateBagName(bagName);
    // The player doesn't exist!
    if (ply === 0) return;
    console.log(`Player: ${GetPlayerName(ply)} ${value ? 'died!' : 'is alive!'`)
})
```
```lua
AddStateBagChangeHandler("isDead", nil, function(bagName, key, value) 
    local ply = GetPlayerFromStateBagName(bagName)
    -- The player doesn't exist!
    if ply == 0 then return end
    print("Player: " .. GetPlayerName(ply) .. value and 'died!' or 'is alive!')
end)
```

## GET_PLAYER_GUID
`0xE52D9680` | `void GET_PLAYER_GUID(char* playerSrc)`

## GET_PLAYER_IDENTIFIER
`0x7302DBCF` | `void GET_PLAYER_IDENTIFIER(char* playerSrc, int identiferIndex)`

## GET_PLAYER_IDENTIFIER_BY_TYPE
`0xA61C8FC6` | `void GET_PLAYER_IDENTIFIER_BY_TYPE(char* playerSrc, char* identifierType)`
```lua
local playerLicenses = {}

AddEventHandler('playerJoining', function()
    playerLicenses[source] = GetPlayerIdentifierByType(source, 'license')
end)
```
```js
let playerLicenses = {};

on('playerJoining', () => {
    playerLicenses[source] = GetPlayerIdentifierByType(source, 'license');
});
```
```cs
using System.Collections.Generic;
using static CitizenFX.Core.Native.API;
// ...

// In class
private Dictionary<int, string> PlayerLicenses = new Dictionary<int, string>();

// In class constructor
EventHandlers["playerJoining"] += new Action<Player>(SetLicense);

// Delegate method
private void SetLicense([FromSource]Player player) {
    PlayerLicenses.Add(player.Handle, GetPlayerIdentifierByType(player.Handle, "license"));
}
```

## GET_PLAYER_INVINCIBLE
`0x680C90EE` | `void GET_PLAYER_INVINCIBLE(char* playerSrc)`

## GET_PLAYER_INVINCIBLE_2
`0xF2E3912B` | `void GET_PLAYER_INVINCIBLE_2(Player player)`

## GET_PLAYER_KILL_FALL_HEIGHT
`0xBFB2990C` | `void GET_PLAYER_KILL_FALL_HEIGHT()`

## GET_PLAYER_LAST_MSG
`0x427E8E6A` | `void GET_PLAYER_LAST_MSG(char* playerSrc)`

## GET_PLAYER_MAX_ARMOUR
`0x2A50657` | `void GET_PLAYER_MAX_ARMOUR(char* playerSrc)`

## GET_PLAYER_MAX_HEALTH
`0x8154E470` | `void GET_PLAYER_MAX_HEALTH(char* playerSrc)`

## GET_PLAYER_MAX_STAMINA
`0xD014AB79` | `void GET_PLAYER_MAX_STAMINA(Player playerId)`

## GET_PLAYER_MELEE_WEAPON_DAMAGE_MODIFIER
`0x8689A825` | `void GET_PLAYER_MELEE_WEAPON_DAMAGE_MODIFIER(Player playerId)`

## GET_PLAYER_MELEE_WEAPON_DEFENSE_MODIFIER
`0x27E94EF8` | `void GET_PLAYER_MELEE_WEAPON_DEFENSE_MODIFIER(Player playerId)`

## GET_PLAYER_NAME
`0x406B4B20` | `void GET_PLAYER_NAME(char* playerSrc)`

## GET_PLAYER_PED
`0x6E31E993` | `void GET_PLAYER_PED(char* playerSrc)`
```lua
-- Let's assume source is a valid ID
local pedId = GetPlayerPed(source);

-- If pedId is valid (not equal to 0)
if pedId ~= 0 then
    -- Do something with this ped!
end
```

## GET_PLAYER_PEER_STATISTICS
`0x9A928294` | `void GET_PLAYER_PEER_STATISTICS(char* playerSrc, int peerStatistic)`
```js

setInterval(() => {
	const ENET_PACKET_LOSS_SCALE = 65536;

	const PLAYER_SERVER_ID = 1;

	const packetLoss = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 0 /* PacketLoss */);
	const packetLossVariance = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 1 /* PacketLossVariance */);
	const packetLossEpoch = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 2 /* PacketLossEpoch */)
	const rtt = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 3 /* RoundTripTime */);
	const rttVariance = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 4 /* RoundTripTimeVariance */);
	const lastRtt = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 5 /* LastRoundTripTime */);
	const lastRttVariance = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 6 /* LastRoundTripTimeVariance */);
	const packetThrottleEpoch = GetPlayerPeerStatistics(PLAYER_SERVER_ID, 7 /* PacketThrottleEpoch */);

	console.log(`packetLoss: ${packetLoss}`);
	console.log(`packetLossVariance: ${packetLossVariance}`);
	console.log(`packetLossEpch: ${packetLossEpoch}`);

	console.log(`packetLossScaled: ${packetLoss / ENET_PACKET_LOSS_SCALE}`);
	console.log(`packetLossVarianceScaled: ${packetLossVariance / ENET_PACKET_LOSS_SCALE}`);

	console.log(`rtt: ${rtt}`);
	console.log(`rttVariance: ${rttVariance}`);

	console.log(`lastRtt: ${lastRtt}`);
	console.log(`lastRttVariance: ${lastRttVariance}`);
	console.log(`packetThrottleEpoch: ${packetThrottleEpoch}`);
}, 10000)
```

## GET_PLAYER_PING
`0xFF1290D4` | `void GET_PLAYER_PING(char* playerSrc)`

## GET_PLAYER_ROUTING_BUCKET
`0x52441C34` | `void GET_PLAYER_ROUTING_BUCKET(char* playerSrc)`

## GET_PLAYER_SERVER_ID
`0x4D97BCC7` | `void GET_PLAYER_SERVER_ID(Player player)`

## GET_PLAYER_STAMINA
`0xE415EC5C` | `void GET_PLAYER_STAMINA(Player playerId)`

## GET_PLAYER_TEAM
`0x9873E404` | `void GET_PLAYER_TEAM(char* playerSrc)`

## GET_PLAYER_TIME_IN_PURSUIT
`0x7ADE63E1` | `void GET_PLAYER_TIME_IN_PURSUIT(char* playerSrc, BOOL lastPursuit)`

## GET_PLAYER_TIME_ONLINE
`0x67D2E605` | `void GET_PLAYER_TIME_ONLINE(char* playerSrc)`
```lua
local function ShowTimeOnline()
    local player = source
    local secondsTotalOnline = GetPlayerTimeOnline(player)

    print(("Time online : %f H %f min %f"):format(
        (secondsTotalOnline / 3600),
        ((secondsTotalOnline / 60) % 60),
        (secondsTotalOnline % 60)
    ))
end

RegisterNetEvent("myTimeOnline", ShowTimeOnline)
```

## GET_PLAYER_TOKEN
`0x54C06897` | `void GET_PLAYER_TOKEN(char* playerSrc, int index)`

## GET_PLAYER_VEHICLE_DAMAGE_MODIFIER
`0x78F27B1F` | `void GET_PLAYER_VEHICLE_DAMAGE_MODIFIER(Player playerId)`

## GET_PLAYER_VEHICLE_DEFENSE_MODIFIER
`0x8326E7CD` | `void GET_PLAYER_VEHICLE_DEFENSE_MODIFIER(Player playerId)`

## GET_PLAYER_WANTED_CENTRE_POSITION
`0x821F2D2C` | `void GET_PLAYER_WANTED_CENTRE_POSITION(char* playerSrc)`

## GET_PLAYER_WANTED_LEVEL
`0xBDCDD163` | `void GET_PLAYER_WANTED_LEVEL(char* playerSrc)`

## GET_PLAYER_WEAPON_DAMAGE_MODIFIER
`0x2A3D7CDA` | `void GET_PLAYER_WEAPON_DAMAGE_MODIFIER(Player playerId)`

## GET_PLAYER_WEAPON_DEFENSE_MODIFIER
`0xF1543251` | `void GET_PLAYER_WEAPON_DEFENSE_MODIFIER(Player playerId)`

## GET_PLAYER_WEAPON_DEFENSE_MODIFIER_2
`0x986B65FF` | `void GET_PLAYER_WEAPON_DEFENSE_MODIFIER_2(Player playerId)`

## GET_RANDOM_VEHICLE_DENSITY_MULTIPLIER
`0x7B0D00C5` | `void GET_RANDOM_VEHICLE_DENSITY_MULTIPLIER()`

## GET_REGISTERED_COMMANDS
`0xD4BEF069` | `void GET_REGISTERED_COMMANDS()`

## GET_RESOURCE_BY_FIND_INDEX
`0x387246B7` | `void GET_RESOURCE_BY_FIND_INDEX(int findIndex)`
```lua
local resourceList = {}
for i = 0, GetNumResources(), 1 do
  local resource_name = GetResourceByFindIndex(i)
  if resource_name and GetResourceState(resource_name) == "started" then
    table.insert(resourceList, resource_name)
  end
end
print(table.unpack(resourceList))
```

## GET_RESOURCE_COMMANDS
`0x97628584` | `void GET_RESOURCE_COMMANDS(char* resource)`

## GET_RESOURCE_KVP_FLOAT
`0x35BDCEEA` | `void GET_RESOURCE_KVP_FLOAT(char* key)`
```lua
local kvpValue = GetResourceKvpFloat('mollis')
if kvpValue ~= 0.0 then
	-- do something!
end
```

## GET_RESOURCE_KVP_INT
`0x557B586A` | `void GET_RESOURCE_KVP_INT(char* key)`
```lua
local kvpValue = GetResourceKvpInt('bananabread') 
if kvpValue ~= 0 then
	-- do something!
end
```

## GET_RESOURCE_KVP_STRING
`0x5240DA5A` | `void GET_RESOURCE_KVP_STRING(char* key)`
```lua
local kvpValue = GetResourceKvpString('codfish') 
if kvpValue then
	-- do something!
end
```

## GET_RESOURCE_METADATA
`0x964BAB1D` | `void GET_RESOURCE_METADATA(char* resourceName, char* metadataKey, int index)`

## GET_RESOURCE_PATH
`0x61DCF017` | `void GET_RESOURCE_PATH(char* resourceName)`

## GET_RESOURCE_STATE
`0x4039B485` | `void GET_RESOURCE_STATE(char* resourceName)`

## GET_ROPE_FLAGS
`0xA80FFE99` | `void GET_ROPE_FLAGS(int rope)`

## GET_ROPE_LENGTH_CHANGE_RATE
`0x66D70EA3` | `void GET_ROPE_LENGTH_CHANGE_RATE(int rope)`

## GET_ROPE_TIME_MULTIPLIER
`0xF341E6CA` | `void GET_ROPE_TIME_MULTIPLIER(int rope)`

## GET_ROPE_UPDATE_ORDER
`0x2AB2E0F6` | `void GET_ROPE_UPDATE_ORDER(int rope)`

## GET_RUNTIME_TEXTURE_HEIGHT
`0x3574AACE` | `void GET_RUNTIME_TEXTURE_HEIGHT(long tex)`

## GET_RUNTIME_TEXTURE_PITCH
`0xCA0A085F` | `void GET_RUNTIME_TEXTURE_PITCH(long tex)`

## GET_RUNTIME_TEXTURE_WIDTH
`0xC9F55558` | `void GET_RUNTIME_TEXTURE_WIDTH(long tex)`

## GET_SCENARIO_PED_DENSITY_MULTIPLIER
`0x77C598B2` | `void GET_SCENARIO_PED_DENSITY_MULTIPLIER()`

## GET_SEAT_PED_IS_USING
`0x57B78C17` | `void GET_SEAT_PED_IS_USING(Ped ped)`

## GET_SELECTED_PED_WEAPON
`0xD240123E` | `void GET_SELECTED_PED_WEAPON(Ped ped)`

## GET_SHAPE_TEST_RESULT_INCLUDING_MATERIAL
`0x4301E10C` | `void GET_SHAPE_TEST_RESULT_INCLUDING_MATERIAL(int shapeTestHandle, BOOL* hit, Vector3* endCoords, Vector3* surfaceNormal, Hash* materialHash, Entity* entityHit)`

## GET_STATE_BAG_KEYS
`0x78D864C7` | `void GET_STATE_BAG_KEYS(char* bagName)`

## GET_STATE_BAG_VALUE
`0x637F4C75` | `void GET_STATE_BAG_VALUE(char* bagName, char* key)`

## GET_THRUSTER_SIDE_RCS_THROTTLE
`0x1C939E87` | `void GET_THRUSTER_SIDE_RCS_THROTTLE(Vehicle jetpack)`

## GET_THRUSTER_THROTTLE
`0x94E24C96` | `void GET_THRUSTER_THROTTLE(Vehicle jetpack)`

## GET_TIMECYCLE_MODIFIER_COUNT
`0xFE2A1D4D` | `void GET_TIMECYCLE_MODIFIER_COUNT()`
```lua
local count = GetTimecycleModifierCount()
print("we have  " .. count .. "timecycle modifiers loaded")
```

## GET_TIMECYCLE_MODIFIER_INDEX_BY_NAME
`0x5F4CD0E2` | `void GET_TIMECYCLE_MODIFIER_INDEX_BY_NAME(char* modifierName)`
```lua
local modifierIndex = GetTimecycleModifierIndexByName("underwater")
local currentIndex = GetTimecycleModifierIndex()

if currentIndex ~= -1 and currentIndex == modifierIndex then
  print("we're actually using 'underwater' timecycle!")
end
```

## GET_TIMECYCLE_MODIFIER_NAME_BY_INDEX
`0x28CB8608` | `void GET_TIMECYCLE_MODIFIER_NAME_BY_INDEX(int modifierIndex)`
```lua
local modifierIndex = GetTimecycleModifierIndex()

if modifierIndex ~= -1 then
  local modifierName = GetTimecycleModifierNameByIndex(modifierIndex)
  print("current timecycle name is " .. modifierName)
end
```

## GET_TIMECYCLE_MODIFIER_STRENGTH
`0xBE54124A` | `void GET_TIMECYCLE_MODIFIER_STRENGTH()`

## GET_TIMECYCLE_MODIFIER_VAR
`0xA7109E12` | `void GET_TIMECYCLE_MODIFIER_VAR(char* modifierName, char* varName, float* value1, float* value2)`
```lua
local modifierName = "superDARK"
local varName = "postfx_noise"

if DoesTimecycleModifierHasVar(modifierName, varName) then
  local success, value1, value2 = GetTimecycleModifierVar(modifierName, varName)

  if success then
    print(string.format("[%s] removed var %s with values: %f %f", modifierName, varName, value1, value2))
    RemoveTimecycleModifierVar(modifierName, varName)
  end
else
    SetTimecycleModifierVar(modifierName, varName, 1.0, 1.0)
    print(string.format("[%s] created var %s", modifierName, varName))
end
```

## GET_TIMECYCLE_MODIFIER_VAR_COUNT
`0x60FB60FE` | `void GET_TIMECYCLE_MODIFIER_VAR_COUNT(char* modifierName)`
```lua
local varCount = GetTimecycleModifierVarCount("underwater")

if varCount ~= 0 then
  for index = 0, varCount - 1 do
    local varName = GetTimecycleModifierVarNameByIndex(index)

    print(string.format("[%d] %s", index, varName))
  end
end
```

## GET_TIMECYCLE_MODIFIER_VAR_NAME_BY_INDEX
`0xE874AB1D` | `void GET_TIMECYCLE_MODIFIER_VAR_NAME_BY_INDEX(char* modifierName, int modifierVarIndex)`
```lua
local varCount = GetTimecycleModifierVarCount("underwater")

if varCount ~= 0 then
  for index = 0, varCount - 1 do
    local varName = GetTimecycleModifierVarNameByIndex(index)

    print(string.format("[%d] %s", index, varName))
  end
end
```

## GET_TIMECYCLE_VAR_COUNT
`0x838B34D8` | `void GET_TIMECYCLE_VAR_COUNT()`
```lua
local varCount = GetTimecycleVarCount()

if varCount ~= 0 then
  for index = 0, varCount - 1 do
    local varName = GetTimecycleVarNameByIndex(index)
    local varDefault = GetTimecycleVarDefaultValueByIndex(index)

    print(string.format("[%d] %s (%f)", index, varName, varDefault))
  end
end
```

## GET_TIMECYCLE_VAR_DEFAULT_VALUE_BY_INDEX
`0x3B90238` | `void GET_TIMECYCLE_VAR_DEFAULT_VALUE_BY_INDEX(int varIndex)`
```lua
local varCount = GetTimecycleVarCount()

if varCount ~= 0 then
  for index = 0, varCount - 1 do
    local varName = GetTimecycleVarNameByIndex(index)
    local varDefault = GetTimecycleVarDefaultValueByIndex(index)

    print(string.format("[%d] %s (%f)", index, varName, varDefault))
  end
end
```

## GET_TIMECYCLE_VAR_NAME_BY_INDEX
`0xC6C55AAF` | `void GET_TIMECYCLE_VAR_NAME_BY_INDEX(int varIndex)`
```lua
local varCount = GetTimecycleVarCount()

if varCount ~= 0 then
  for index = 0, varCount - 1 do
    local varName = GetTimecycleVarNameByIndex(index)
    local varDefault = GetTimecycleVarDefaultValueByIndex(index)

    print(string.format("[%d] %s (%f)", index, varName, varDefault))
  end
end
```

## GET_TRACK_BRAKING_DISTANCE
`0xBF482A5E` | `void GET_TRACK_BRAKING_DISTANCE(int track)`

## GET_TRACK_MAX_SPEED
`0x34EE2BF3` | `void GET_TRACK_MAX_SPEED(int track)`

## GET_TRACK_NODE_COORDS
`0x1628548E` | `void GET_TRACK_NODE_COORDS(int trackIndex, int trackNode, Vector3* coords)`

## GET_TRACK_NODE_COUNT
`0x896A0C11` | `void GET_TRACK_NODE_COUNT(int trackIndex)`

## GET_TRAIN_BACKWARD_CARRIAGE
`0x456E34A` | `void GET_TRAIN_BACKWARD_CARRIAGE(Vehicle train)`

## GET_TRAIN_CARRIAGE_ENGINE
`0x95070FA` | `void GET_TRAIN_CARRIAGE_ENGINE(Vehicle train)`

## GET_TRAIN_CARRIAGE_INDEX
`0x4B8285CF` | `void GET_TRAIN_CARRIAGE_INDEX(Vehicle train)`

## GET_TRAIN_CRUISE_SPEED
`0xA4921EF5` | `void GET_TRAIN_CRUISE_SPEED(Vehicle train)`

## GET_TRAIN_CURRENT_TRACK_NODE
`0xE015E854` | `void GET_TRAIN_CURRENT_TRACK_NODE(Vehicle train)`

## GET_TRAIN_DIRECTION
`0x8DAF79B6` | `void GET_TRAIN_DIRECTION(Vehicle train)`

## GET_TRAIN_DOOR_COUNT
`0x99974721` | `void GET_TRAIN_DOOR_COUNT(Vehicle train)`

## GET_TRAIN_DOOR_OPEN_RATIO
`0x40B16551` | `void GET_TRAIN_DOOR_OPEN_RATIO(Vehicle train, int doorIndex)`
```lua
local doorCount = GetTrainDoorCount(train)
for doorIndex = 0, doorCount - 1 do
    local ratio = GetTrainDoorOpenRatio(train, doorIndex)
    print("Door " .. tostring(doorIndex) .. " is open by a ratio of " .. tostring(ratio))
end
```
```cs
int doorCount = API.GetTrainDoorCount(train);
for (int doorIndex = 0; doorIndex < doorCount; doorIndex++)
{
    float ratio = API.GetTrainDoorOpenRatio(train, doorIndex);
    Debug.WriteLine($"Door {doorIndex} is open by a ratio of {ratio}");
}
```

## GET_TRAIN_FORWARD_CARRIAGE
`0x24DC88D9` | `void GET_TRAIN_FORWARD_CARRIAGE(Vehicle train)`

## GET_TRAIN_SPEED
`0x428668B7` | `void GET_TRAIN_SPEED(Vehicle train)`

## GET_TRAIN_STATE
`0x81B50033` | `void GET_TRAIN_STATE(Vehicle train)`

## GET_TRAIN_TRACK_INDEX
`0x9AA339D` | `void GET_TRAIN_TRACK_INDEX(Vehicle train)`

## GET_VEHICLE_ALARM_TIME_LEFT
`0xC62AAC98` | `void GET_VEHICLE_ALARM_TIME_LEFT(Vehicle vehicle)`

## GET_VEHICLE_BODY_HEALTH
`0x2B2FCC28` | `void GET_VEHICLE_BODY_HEALTH(Vehicle vehicle)`

## GET_VEHICLE_CHEAT_POWER_INCREASE
`0xC3C93F28` | `void GET_VEHICLE_CHEAT_POWER_INCREASE(Vehicle vehicle)`

## GET_VEHICLE_CLUTCH
`0x1DAD4583` | `void GET_VEHICLE_CLUTCH(Vehicle vehicle)`

## GET_VEHICLE_COLOURS
`0x40D82D88` | `void GET_VEHICLE_COLOURS(Vehicle vehicle, int* colorPrimary, int* colorSecondary)`

## GET_VEHICLE_CURRENT_GEAR
`0xB4F4E566` | `void GET_VEHICLE_CURRENT_GEAR(Vehicle vehicle)`

## GET_VEHICLE_CURRENT_RPM
`0xE7B12B54` | `void GET_VEHICLE_CURRENT_RPM(Vehicle vehicle)`

## GET_VEHICLE_CUSTOM_PRIMARY_COLOUR
`0x1C2B9FEF` | `void GET_VEHICLE_CUSTOM_PRIMARY_COLOUR(Vehicle vehicle, int* r, int* g, int* b)`

## GET_VEHICLE_CUSTOM_SECONDARY_COLOUR
`0x3FF247A2` | `void GET_VEHICLE_CUSTOM_SECONDARY_COLOUR(Vehicle vehicle, int* r, int* g, int* b)`

## GET_VEHICLE_DASHBOARD_BOOST
`0xDFFABA2A` | `void GET_VEHICLE_DASHBOARD_BOOST()`

## GET_VEHICLE_DASHBOARD_COLOUR
`0xA0DBD08D` | `void GET_VEHICLE_DASHBOARD_COLOUR(Vehicle vehicle, int* color)`

## GET_VEHICLE_DASHBOARD_CURRENT_GEAR
`0x435C86F4` | `void GET_VEHICLE_DASHBOARD_CURRENT_GEAR()`

## GET_VEHICLE_DASHBOARD_FUEL
`0x19B0B2CE` | `void GET_VEHICLE_DASHBOARD_FUEL()`

## GET_VEHICLE_DASHBOARD_LIGHTS
`0x500FFE9D` | `void GET_VEHICLE_DASHBOARD_LIGHTS()`

## GET_VEHICLE_DASHBOARD_OIL_PRESSURE
`0x3856D767` | `void GET_VEHICLE_DASHBOARD_OIL_PRESSURE()`

## GET_VEHICLE_DASHBOARD_OIL_TEMP
`0x1F5996AA` | `void GET_VEHICLE_DASHBOARD_OIL_TEMP()`

## GET_VEHICLE_DASHBOARD_RPM
`0xF9716A11` | `void GET_VEHICLE_DASHBOARD_RPM()`

## GET_VEHICLE_DASHBOARD_SPEED
`0x9AAD420E` | `void GET_VEHICLE_DASHBOARD_SPEED(Vehicle vehicle)`

## GET_VEHICLE_DASHBOARD_TEMP
`0x6B6ADAFA` | `void GET_VEHICLE_DASHBOARD_TEMP()`

## GET_VEHICLE_DASHBOARD_VACUUM
`0xFABE67A9` | `void GET_VEHICLE_DASHBOARD_VACUUM()`

## GET_VEHICLE_DENSITY_MULTIPLIER
`0xEF7C6538` | `void GET_VEHICLE_DENSITY_MULTIPLIER()`

## GET_VEHICLE_DIRT_LEVEL
`0xFD15C065` | `void GET_VEHICLE_DIRT_LEVEL(Vehicle vehicle)`

## GET_VEHICLE_DOORS_LOCKED_FOR_PLAYER
`0x1DC50247` | `void GET_VEHICLE_DOORS_LOCKED_FOR_PLAYER(Vehicle vehicle)`

## GET_VEHICLE_DOOR_LOCK_STATUS
`0xD72CEF2` | `void GET_VEHICLE_DOOR_LOCK_STATUS(Vehicle vehicle)`

## GET_VEHICLE_DOOR_STATUS
`0x6E35C49C` | `void GET_VEHICLE_DOOR_STATUS(Vehicle vehicle, int doorIndex)`

## GET_VEHICLE_DRAWN_WHEEL_ANGLE_MULT
`0x21C1DA8E` | `void GET_VEHICLE_DRAWN_WHEEL_ANGLE_MULT(Vehicle vehicle)`

## GET_VEHICLE_ENGINE_HEALTH
`0x8880038A` | `void GET_VEHICLE_ENGINE_HEALTH(Vehicle vehicle)`

## GET_VEHICLE_ENGINE_TEMPERATURE
`0xF4F495CB` | `void GET_VEHICLE_ENGINE_TEMPERATURE(Vehicle vehicle)`

## GET_VEHICLE_EXTRA_COLOURS
`0x80E4659B` | `void GET_VEHICLE_EXTRA_COLOURS(Vehicle vehicle, int* pearlescentColor, int* wheelColor)`

## GET_VEHICLE_FLIGHT_NOZZLE_POSITION
`0xAD40AD55` | `void GET_VEHICLE_FLIGHT_NOZZLE_POSITION(Vehicle vehicle)`

## GET_VEHICLE_FUEL_LEVEL
`0x5F739BB8` | `void GET_VEHICLE_FUEL_LEVEL(Vehicle vehicle)`

## GET_VEHICLE_GEAR_RATIO
`0x82E794B7` | `void GET_VEHICLE_GEAR_RATIO(Vehicle vehicle, int gear)`
```lua
local vehicle = GetVehiclePedIsIn(PlayerPedId(-1))
local currentGear = GetVehicleCurrentGear(Vehicle)

print(GetVehicleGearRatio(vehicle, currentGear)) -- will print current vehicle gear to console
```
```js
const vehicle = GetVehiclePedIsIn(PlayerPedId(-1));
const currentGear = GetVehicleCurrentGear(Vehicle);

console.log(GetVehicleGearRatio(vehicle, currentGear)); // will print current vehicle gear to console
```
```cs
using static CitizenFX.Core.API;

Vehicle vehicle = Game.PlayerPed.CurrentVehicle;
int currentGear = GetVehicleCurrentGear(vehicle.Handle);

Debug.WriteLine($"{GetVehicleGearRatio(vehicle.Handle, currentGear)}");
```

## GET_VEHICLE_GRAVITY_AMOUNT
`0xB48A1292` | `void GET_VEHICLE_GRAVITY_AMOUNT(Vehicle vehicle)`

## GET_VEHICLE_HANDBRAKE
`0x483B013C` | `void GET_VEHICLE_HANDBRAKE(Vehicle vehicle)`

## GET_VEHICLE_HANDLING_FLOAT
`0x642FC12F` | `void GET_VEHICLE_HANDLING_FLOAT(Vehicle vehicle, char* class_, char* fieldName)`

## GET_VEHICLE_HANDLING_INT
`0x27396C75` | `void GET_VEHICLE_HANDLING_INT(Vehicle vehicle, char* class_, char* fieldName)`

## GET_VEHICLE_HANDLING_VECTOR
`0xFB341304` | `void GET_VEHICLE_HANDLING_VECTOR(Vehicle vehicle, char* class_, char* fieldName)`

## GET_VEHICLE_HAS_FLAG
`0xD85C9F57` | `void GET_VEHICLE_HAS_FLAG(Vehicle vehicle, int flagIndex)`

## GET_VEHICLE_HEADLIGHTS_COLOUR
`0xD7147656` | `void GET_VEHICLE_HEADLIGHTS_COLOUR(Vehicle vehicle)`

## GET_VEHICLE_HIGH_GEAR
`0xF1D1D689` | `void GET_VEHICLE_HIGH_GEAR(Vehicle vehicle)`

## GET_VEHICLE_HOMING_LOCKON_STATE
`0xFBDE9FD8` | `void GET_VEHICLE_HOMING_LOCKON_STATE(Vehicle vehicle)`

## GET_VEHICLE_HORN_TYPE
`0xDEA49773` | `void GET_VEHICLE_HORN_TYPE(Vehicle vehicle)`

## GET_VEHICLE_INDICATOR_LIGHTS
`0x83070354` | `void GET_VEHICLE_INDICATOR_LIGHTS(Vehicle vehicle)`

## GET_VEHICLE_INTERIOR_COLOUR
`0xCCFF3B6E` | `void GET_VEHICLE_INTERIOR_COLOUR(Vehicle vehicle, int* color)`

## GET_VEHICLE_LIGHTS_STATE
`0x7C278621` | `void GET_VEHICLE_LIGHTS_STATE(Vehicle vehicle, BOOL* lightsOn, BOOL* highbeamsOn)`

## GET_VEHICLE_LIGHT_MULTIPLIER
`0x7E6E219C` | `void GET_VEHICLE_LIGHT_MULTIPLIER(Vehicle vehicle)`

## GET_VEHICLE_LIVERY
`0xEC82A51D` | `void GET_VEHICLE_LIVERY(Vehicle vehicle)`

## GET_VEHICLE_LOCK_ON_TARGET
`0x4A557117` | `void GET_VEHICLE_LOCK_ON_TARGET(Vehicle vehicle)`

## GET_VEHICLE_NEON_COLOUR
`0xD9319DCB` | `void GET_VEHICLE_NEON_COLOUR(Vehicle vehicle, int* red, int* green, int* blue)`
```lua
local vehicle = GetVehiclePedIsIn(GetPlayerPed(1), false) -- 1 is the source here
local red, green, blue = GetVehicleNeonColour(vehicle)
print(red, green, blue)
```
```js
const vehicle = GetVehiclePedIsIn(GetPlayerPed(1), false); // 1 is the source here
const [red, green, blue] = GetVehicleNeonColour(vehicle);
console.log(red, green, blue);
```
```cs
using static CitizenFX.Core.Native.API;

int vehicle = GetVehiclePedIsIn(GetPlayerPed(1), false); // 1 is the source here
int red, green, blue;
GetVehicleNeonColour(vehicle, out red, out green, out blue);
Debug.WriteLine($"{red}, {green}, {blue}");
```

## GET_VEHICLE_NEON_ENABLED
`0x684BDBF2` | `void GET_VEHICLE_NEON_ENABLED(Vehicle vehicle, int neonIndex)`
```lua
local vehicle = GetVehiclePedIsIn(GetPlayerPed(1), false) -- 1 is the source here
local isRightNeonOn = GetVehicleNeonEnabled(vehicle, 1)
print(isRightNeonOn)
```
```js
const vehicle = GetVehiclePedIsIn(GetPlayerPed(1), false); // 1 is the source here
const isRightNeonOn = GetVehicleNeonEnabled(vehicle, 1);
console.log(isRightNeonOn);
```
```cs
using static CitizenFX.Core.Native.API;

int vehicle = GetVehiclePedIsIn(GetPlayerPed(1), false); // 1 is the source here
bool isRightNeonOn = GetVehicleNeonEnabled(vehicle, 1);
Debug.WriteLine($"{isRightNeonOn}");
```

## GET_VEHICLE_NEXT_GEAR
`0xDDB298AE` | `void GET_VEHICLE_NEXT_GEAR(Vehicle vehicle)`

## GET_VEHICLE_NUMBER_OF_WHEELS
`0xEDF4B0FC` | `void GET_VEHICLE_NUMBER_OF_WHEELS(Vehicle vehicle)`

## GET_VEHICLE_NUMBER_PLATE_TEXT
`0xE8522D58` | `void GET_VEHICLE_NUMBER_PLATE_TEXT(Vehicle vehicle)`

## GET_VEHICLE_NUMBER_PLATE_TEXT_INDEX
`0x499747B6` | `void GET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(Vehicle vehicle)`

## GET_VEHICLE_OIL_LEVEL
`0xFC7F8EF4` | `void GET_VEHICLE_OIL_LEVEL(Vehicle vehicle)`

## GET_VEHICLE_PED_IS_IN
`0xAFE92319` | `void GET_VEHICLE_PED_IS_IN(Ped ped, BOOL lastVehicle)`

## GET_VEHICLE_PETROL_TANK_HEALTH
`0xE41595CE` | `void GET_VEHICLE_PETROL_TANK_HEALTH(Vehicle vehicle)`

## GET_VEHICLE_RADIO_STATION_INDEX
`0x57037960` | `void GET_VEHICLE_RADIO_STATION_INDEX(Vehicle vehicle)`

## GET_VEHICLE_ROOF_LIVERY
`0x872CF42` | `void GET_VEHICLE_ROOF_LIVERY(Vehicle vehicle)`

## GET_VEHICLE_STEERING_ANGLE
`0x1382FCEA` | `void GET_VEHICLE_STEERING_ANGLE(Vehicle vehicle)`

## GET_VEHICLE_STEERING_SCALE
`0x954465DE` | `void GET_VEHICLE_STEERING_SCALE(Vehicle vehicle)`

## GET_VEHICLE_THROTTLE_OFFSET
`0xD1D07351` | `void GET_VEHICLE_THROTTLE_OFFSET(Vehicle vehicle)`

## GET_VEHICLE_TOP_SPEED_MODIFIER
`0x998B7FEE` | `void GET_VEHICLE_TOP_SPEED_MODIFIER(Vehicle vehicle)`

## GET_VEHICLE_TOTAL_REPAIRS
`0x9963D5F9` | `void GET_VEHICLE_TOTAL_REPAIRS(Vehicle vehicle)`

## GET_VEHICLE_TURBO_PRESSURE
`0xE02B51D7` | `void GET_VEHICLE_TURBO_PRESSURE(Vehicle vehicle)`

## GET_VEHICLE_TYPE
`0xA273060E` | `void GET_VEHICLE_TYPE(Vehicle vehicle)`

## GET_VEHICLE_TYPE_RAW
`0xDE73BC10` | `void GET_VEHICLE_TYPE_RAW(Vehicle vehicle)`

## GET_VEHICLE_TYRE_SMOKE_COLOR
`0x75280015` | `void GET_VEHICLE_TYRE_SMOKE_COLOR(Vehicle vehicle, int* r, int* g, int* b)`

## GET_VEHICLE_WHEELIE_STATE
`0x137260D1` | `void GET_VEHICLE_WHEELIE_STATE(Vehicle vehicle)`
```lua
Citizen.CreateThread(function()
  while true do
    Wait(1)

    local veh = GetVehiclePedIsUsing(PlayerPedId())
    if veh ~= 0 then
      local wheelieState = GetVehicleWheelieState(veh)
      if wheelieState == 1 then
        print("Nothing")
      elseif wheelieState == 65 then
        print("Ready to wheelie!")
      elseif wheelieState == 129 then
        print("Doing wheelie!")
      end
    end
  end
end)
```

## GET_VEHICLE_WHEEL_BRAKE_PRESSURE
`0x70FE2EFF` | `void GET_VEHICLE_WHEEL_BRAKE_PRESSURE(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_FLAGS
`0xC70FA0C7` | `void GET_VEHICLE_WHEEL_FLAGS(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_HEALTH
`0x54A677F5` | `void GET_VEHICLE_WHEEL_HEALTH(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_IS_POWERED
`0x3CCF1B49` | `void GET_VEHICLE_WHEEL_IS_POWERED(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_POWER
`0xD203287` | `void GET_VEHICLE_WHEEL_POWER(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_RIM_COLLIDER_SIZE
`0xCEE21AB2` | `void GET_VEHICLE_WHEEL_RIM_COLLIDER_SIZE(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_ROTATION_SPEED
`0xEA1859E5` | `void GET_VEHICLE_WHEEL_ROTATION_SPEED(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_SIZE
`0x4046B66` | `void GET_VEHICLE_WHEEL_SIZE(Vehicle vehicle)`

## GET_VEHICLE_WHEEL_SPEED
`0x149C9DA0` | `void GET_VEHICLE_WHEEL_SPEED(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_STEERING_ANGLE
`0xA0867448` | `void GET_VEHICLE_WHEEL_STEERING_ANGLE(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_SURFACE_MATERIAL
`0xA7F04022` | `void GET_VEHICLE_WHEEL_SURFACE_MATERIAL(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_SUSPENSION_COMPRESSION
`0x2B48175B` | `void GET_VEHICLE_WHEEL_SUSPENSION_COMPRESSION(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_TIRE_COLLIDER_SIZE
`0xE0BA9FE6` | `void GET_VEHICLE_WHEEL_TIRE_COLLIDER_SIZE(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_TIRE_COLLIDER_WIDTH
`0xEF65929C` | `void GET_VEHICLE_WHEEL_TIRE_COLLIDER_WIDTH(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_TRACTION_VECTOR_LENGTH
`0x3BCFEE14` | `void GET_VEHICLE_WHEEL_TRACTION_VECTOR_LENGTH(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_TYPE
`0xDA58D7AE` | `void GET_VEHICLE_WHEEL_TYPE(Vehicle vehicle)`

## GET_VEHICLE_WHEEL_WIDTH
`0x9C7B59F9` | `void GET_VEHICLE_WHEEL_WIDTH(Vehicle vehicle)`

## GET_VEHICLE_WHEEL_X_OFFSET
`0xCC90CBCA` | `void GET_VEHICLE_WHEEL_X_OFFSET(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WHEEL_Y_ROTATION
`0x2EA4AFFE` | `void GET_VEHICLE_WHEEL_Y_ROTATION(Vehicle vehicle, int wheelIndex)`

## GET_VEHICLE_WINDOW_TINT
`0x13D53892` | `void GET_VEHICLE_WINDOW_TINT(Vehicle vehicle)`

## GET_VEHICLE_XENON_LIGHTS_CUSTOM_COLOR
`0xC715F730` | `void GET_VEHICLE_XENON_LIGHTS_CUSTOM_COLOR(Vehicle vehicle, int* red, int* green, int* blue)`

## GET_VEHICLE_XMAS_SNOW_FACTOR
`0x16605B30` | `void GET_VEHICLE_XMAS_SNOW_FACTOR()`

## GET_VISUAL_SETTING_FLOAT
`0x15346B4D` | `void GET_VISUAL_SETTING_FLOAT(char* name)`

## GET_WATER_QUAD_ALPHA
`0x14088095` | `void GET_WATER_QUAD_ALPHA(int waterQuad, int* a0, int* a1, int* a2, int* a3)`
```lua
local success, a0, a1, a2, a3 = GetWaterQuadAlpha(0)
```

## GET_WATER_QUAD_AT_COORDS
`0x17321452` | `void GET_WATER_QUAD_AT_COORDS(float x, float y)`
```lua
local currentPedPosition = GetEntityCoords(PlayerPedId())
local waterQuadIndex = GetWaterQuadAtCoords(currentPedPosition.x, currentPedPosition.y)
```

## GET_WATER_QUAD_AT_COORDS_3D
`0xF8E03DB8` | `void GET_WATER_QUAD_AT_COORDS_3D(float x, float y, float z)`
```lua
local currentPedPosition = GetEntityCoords(PlayerPedId())
local waterQuadIndex = GetWaterQuadAtCoords(currentPedPosition.x, currentPedPosition.y, currentPedPosition.z)
```

## GET_WATER_QUAD_BOUNDS
`0x42E9A06A` | `void GET_WATER_QUAD_BOUNDS(int waterQuad, int* minX, int* minY, int* maxX, int* maxY)`
```lua
local success, minX, minY, maxX, maxY = GetWaterQuadBounds(1)
```

## GET_WATER_QUAD_COUNT
`0xB1884159` | `void GET_WATER_QUAD_COUNT()`
```lua
local waterQuadCount = GetWaterQuadCount()
```

## GET_WATER_QUAD_HAS_LIMITED_DEPTH
`0x22EA3BD8` | `void GET_WATER_QUAD_HAS_LIMITED_DEPTH(int waterQuad, int* hasLimitedDepth)`
```lua
local success, hasLimitedDepth = GetWaterQuadHasLimitedDepth(0)
```

## GET_WATER_QUAD_IS_INVISIBLE
`0x1DEDBD77` | `void GET_WATER_QUAD_IS_INVISIBLE(int waterQuad, int* isInvisible)`
```lua
local success, isInvisible = GetWaterQuadIsInvisible(0)
```

## GET_WATER_QUAD_LEVEL
`0x6523816B` | `void GET_WATER_QUAD_LEVEL(int waterQuad, float* waterQuadLevel)`
```lua
local success, waterQuadLevel = GetWaterQuadLevel(0)
```

## GET_WATER_QUAD_NO_STENCIL
`0x6F4ACBA` | `void GET_WATER_QUAD_NO_STENCIL(int waterQuad, int* noStencil)`
```lua
local success, noStencil = GetWaterQuadNoStencil(0)
```

## GET_WATER_QUAD_TYPE
`0xE2501B8B` | `void GET_WATER_QUAD_TYPE(int waterQuad, int* waterType)`
```lua
local success, type = GetWaterQuadType(0)
```

## GET_WAVE_QUAD_AMPLITUDE
`0x865139A3` | `void GET_WAVE_QUAD_AMPLITUDE(int waveQuad, float* waveQuadAmplitude)`
```lua
local success, amplitude = GetWaveQuadAmplitude(1)
```

## GET_WAVE_QUAD_AT_COORDS
`0x3F5A61A7` | `void GET_WAVE_QUAD_AT_COORDS(float x, float y)`
```lua
local currentPedPosition = GetEntityCoords(PlayerPedId())
local waveQuadIndex = GetWaveQuadAtCoords(currentPedPosition.x, currentPedPosition.y)
```

## GET_WAVE_QUAD_BOUNDS
`0xF86136DB` | `void GET_WAVE_QUAD_BOUNDS(int waveQuad, int* minX, int* minY, int* maxX, int* maxY)`
```lua
local success, minX, minY, maxX, maxY = GetWaveQuadBounds(1)
```

## GET_WAVE_QUAD_COUNT
`0x9250C76` | `void GET_WAVE_QUAD_COUNT()`
```lua
local waveQuadCount = GetWaveQuadCount()
```

## GET_WAVE_QUAD_DIRECTION
`0xCCE49A1C` | `void GET_WAVE_QUAD_DIRECTION(int waveQuad, float* directionX, float* directionY)`
```lua
local success, directionX, directionY = GetWaveQuadDirection(1)
```

## GET_WEAPON_ACCURACY_SPREAD
`0x5343721` | `void GET_WEAPON_ACCURACY_SPREAD(Hash weaponHash)`

## GET_WEAPON_ANIMATION_OVERRIDE
`0x63ED2E7` | `void GET_WEAPON_ANIMATION_OVERRIDE(Ped ped)`
```lua
local weaponAnimation = GetWeaponAnimationOverride(PlayerPedId())
```

## GET_WEAPON_COMPONENT_ACCURACY_MODIFIER
`0xC693E278` | `void GET_WEAPON_COMPONENT_ACCURACY_MODIFIER(Hash componentHash)`

## GET_WEAPON_COMPONENT_CAMERA_HASH
`0xACB7E68F` | `void GET_WEAPON_COMPONENT_CAMERA_HASH(Hash componentHash)`

## GET_WEAPON_COMPONENT_CLIP_SIZE
`0xE14CF665` | `void GET_WEAPON_COMPONENT_CLIP_SIZE(Hash componentHash)`

## GET_WEAPON_COMPONENT_DAMAGE_MODIFIER
`0x4A0E3855` | `void GET_WEAPON_COMPONENT_DAMAGE_MODIFIER(Hash componentHash)`

## GET_WEAPON_COMPONENT_RANGE_DAMAGE_MODIFIER
`0xE134FB8D` | `void GET_WEAPON_COMPONENT_RANGE_DAMAGE_MODIFIER(Hash componentHash)`

## GET_WEAPON_COMPONENT_RANGE_MODIFIER
`0x2FD0BC1B` | `void GET_WEAPON_COMPONENT_RANGE_MODIFIER(Hash componentHash)`

## GET_WEAPON_COMPONENT_RETICULE_HASH
`0xF9AB9297` | `void GET_WEAPON_COMPONENT_RETICULE_HASH(Hash componentHash)`

## GET_WEAPON_DAMAGE_MODIFIER
`0xD979143` | `void GET_WEAPON_DAMAGE_MODIFIER(Hash weaponHash)`

## GET_WEAPON_RECOIL_SHAKE_AMPLITUDE
`0x5E1AF5F` | `void GET_WEAPON_RECOIL_SHAKE_AMPLITUDE(Hash weaponHash)`

## GET_WORLD_COORD_FROM_SCREEN_COORD
`0xC81D0659` | `void GET_WORLD_COORD_FROM_SCREEN_COORD(float screenX, float screenY, Vector3* worldVector, Vector3* normalVector)`
```lua
CreateThread(function()
  while true do
    local screenX = GetDisabledControlNormal(0, 239)
    local screenY = GetDisabledControlNormal(0, 240)

    local world, normal = GetWorldCoordFromScreenCoord(screenX, screenY)

    local depth = 10

    local target = world + normal * depth

    DrawSphere(target.x, target.y, target.z, 0.5, 255, 0, 0, 0.5)

    Wait(0)
  end
end)
```

## GIVE_WEAPON_COMPONENT_TO_PED
`0x3E1E286D` | `void GIVE_WEAPON_COMPONENT_TO_PED(Ped ped, Hash weaponHash, Hash componentHash)`

## GIVE_WEAPON_TO_PED
`0xC4D88A85` | `void GIVE_WEAPON_TO_PED(Ped ped, Hash weaponHash, int ammoCount, BOOL isHidden, BOOL bForceInHand)`

## HAS_ENTITY_BEEN_MARKED_AS_NO_LONGER_NEEDED
`0x9C9A3BE0` | `void HAS_ENTITY_BEEN_MARKED_AS_NO_LONGER_NEEDED(Vehicle vehicle)`

## HAS_MINIMAP_OVERLAY_LOADED
`0xF7535F32` | `void HAS_MINIMAP_OVERLAY_LOADED(int id)`

## HAS_VEHICLE_BEEN_DAMAGED_BY_BULLETS
`0xB8AF3137` | `void HAS_VEHICLE_BEEN_DAMAGED_BY_BULLETS(Vehicle vehicle)`

## HAS_VEHICLE_BEEN_OWNED_BY_PLAYER
`0xE4E83A5B` | `void HAS_VEHICLE_BEEN_OWNED_BY_PLAYER(Vehicle vehicle)`

## IS_ACE_ALLOWED
`0x7EBB9929` | `void IS_ACE_ALLOWED(char* object)`

## IS_BIGMAP_ACTIVE
`0xFFF65C63` | `void IS_BIGMAP_ACTIVE()`
```lua
local expanded = IsBigmapActive()
local fullMap = IsBigmapFull()
print("The minimap is currently " .. (expanded and "expanded" or "normal size") .. " and the full map is currently " .. (fullMap and "revealed" or "not revealed") .. ".")
```
```cs
bool expanded = IsBigmapActive();
bool fullMap = IsBigmapFull();

Debug.WriteLine($"The minimap is currently {(expanded ? "expanded" : "normal size")} and the full map is currently {(fullMap ? "revealed" : "not revealed")}.");
```

## IS_BIGMAP_FULL
`0x66EE14B2` | `void IS_BIGMAP_FULL()`
```lua
local expanded = IsBigmapActive()
local fullMap = IsBigmapFull()
print("The minimap is currently " .. (expanded and "expanded" or "normal size") .. " and the full map is currently " .. (fullMap and "revealed" or "not revealed") .. ".")
```
```cs
bool expanded = IsBigmapActive();
bool fullMap = IsBigmapFull();

Debug.WriteLine($"The minimap is currently {(expanded ? "expanded" : "normal size")} and the full map is currently {(fullMap ? "revealed" : "not revealed")}.");
```

## IS_BOAT_ANCHORED_AND_FROZEN
`0xD5C39EE6` | `void IS_BOAT_ANCHORED_AND_FROZEN(Vehicle vehicle)`

## IS_BOAT_WRECKED
`0x9049DB44` | `void IS_BOAT_WRECKED(Vehicle vehicle)`

## IS_DISABLED_RAW_KEY_DOWN
`0x36366EC3` | `void IS_DISABLED_RAW_KEY_DOWN(int rawKeyIndex)`
```lua
if IsDisabledRawKeyDown(32) then -- KEY_SPACE
    print("Spacebar is down")
end
```

## IS_DISABLED_RAW_KEY_PRESSED
`0x1F7CBBAA` | `void IS_DISABLED_RAW_KEY_PRESSED(int rawKeyIndex)`
```lua
if IsDisabledRawKeyPressed(32) then -- KEY_SPACE
    print("Spacebar pressed")
end
```

## IS_DISABLED_RAW_KEY_RELEASED
`0x72B66C09` | `void IS_DISABLED_RAW_KEY_RELEASED(int rawKeyIndex)`
```lua
if IsDisabledRawKeyReleased(32) then -- KEY_SPACE
    print("Spacebar released")
end
```

## IS_DISABLED_RAW_KEY_UP
`0x2C033875` | `void IS_DISABLED_RAW_KEY_UP(int rawKeyIndex)`
```lua
if IsDisabledRawKeyUp(32) then -- KEY_SPACE
    print("Spacebar is up")
end
```

## IS_DUI_AVAILABLE
`0x7AAC3B4C` | `void IS_DUI_AVAILABLE(long duiObject)`

## IS_DUPLICITY_VERSION
`0xCF24C52E` | `void IS_DUPLICITY_VERSION()`

## IS_ENTITY_POSITION_FROZEN
`0xEDBE6ADD` | `void IS_ENTITY_POSITION_FROZEN(Entity entity)`
```lua
local isFrozen = IsEntityPositionFrozen(PlayerPedId())
```
```js
const isFrozen = IsEntityPositionFrozen(PlayerPedId());
```

## IS_ENTITY_VISIBLE
`0x120B4ED5` | `void IS_ENTITY_VISIBLE(Entity entity)`

## IS_FLASH_LIGHT_ON
`0x76876154` | `void IS_FLASH_LIGHT_ON(Ped ped)`

## IS_GAME_ENHANCED_VERSION
`0x4DD998F6` | `void IS_GAME_ENHANCED_VERSION()`

## IS_HELI_TAIL_BOOM_BREAKABLE
`0x23E46BD7` | `void IS_HELI_TAIL_BOOM_BREAKABLE(Vehicle heli)`

## IS_HELI_TAIL_BOOM_BROKEN
`0x2C59F987` | `void IS_HELI_TAIL_BOOM_BROKEN(Vehicle heli)`

## IS_NUI_FOCUSED
`0x98545E6D` | `void IS_NUI_FOCUSED()`

## IS_NUI_FOCUS_KEEPING_INPUT
`0x39C9DC92` | `void IS_NUI_FOCUS_KEEPING_INPUT()`

## IS_PED_A_PLAYER
`0x404794CA` | `void IS_PED_A_PLAYER(Ped ped)`

## IS_PED_COLLECTION_COMPONENT_VARIATION_GEN9_EXCLUSIVE
`0x33B2AFA2` | `void IS_PED_COLLECTION_COMPONENT_VARIATION_GEN9_EXCLUSIVE(Ped ped, int componentId, char* collection, int drawableId)`

## IS_PED_COLLECTION_COMPONENT_VARIATION_VALID
`0xCA63A52A` | `void IS_PED_COLLECTION_COMPONENT_VARIATION_VALID(Ped ped, int componentId, char* collection, int drawableId, int textureId)`

## IS_PED_COMPONENT_VARIATION_GEN9_EXCLUSIVE
`0xC767B581` | `void IS_PED_COMPONENT_VARIATION_GEN9_EXCLUSIVE(Ped ped, int componentId, int drawableId)`
```lua
local ped = PlayerPedId()

for component = 0, 12 do
  local count = GetNumberOfPedDrawableVariations(ped, component)

  for drawable = 0, count - 1 do
    if IsPedComponentVariationGen9Exclusive(ped, component, drawable) then
      print("Component " .. component .. " drawable " .. drawable .. " is a gen9 exclusive, skip!")
    end
  end
end
```

## IS_PED_HANDCUFFED
`0x25865633` | `void IS_PED_HANDCUFFED(Ped ped)`

## IS_PED_IN_ANY_VEHICLE
`0x3B0171EE` | `void IS_PED_IN_ANY_VEHICLE(Ped ped)`

## IS_PED_IN_VEHICLE
`0x7DA6BC83` | `void IS_PED_IN_VEHICLE(Ped ped, Vehicle vehicle)`

## IS_PED_ON_MOUNT
`0x43103006` | `void IS_PED_ON_MOUNT(Ped ped)`

## IS_PED_RAGDOLL
`0xC833BBE1` | `void IS_PED_RAGDOLL(Ped ped)`

## IS_PED_STRAFING
`0xEFEED13C` | `void IS_PED_STRAFING(Ped ped)`

## IS_PED_USING_ACTION_MODE
`0x5AE7EDA2` | `void IS_PED_USING_ACTION_MODE(Ped ped)`

## IS_PLAYER_ACE_ALLOWED
`0xDEDAE23D` | `void IS_PLAYER_ACE_ALLOWED(char* playerSrc, char* object)`

## IS_PLAYER_COMMERCE_INFO_LOADED
`0xBEFE93F4` | `void IS_PLAYER_COMMERCE_INFO_LOADED(char* playerSrc)`

## IS_PLAYER_COMMERCE_INFO_LOADED_EXT
`0x1D14F4FE` | `void IS_PLAYER_COMMERCE_INFO_LOADED_EXT(char* playerSrc)`

## IS_PLAYER_EVADING_WANTED_LEVEL
`0x89A3881A` | `void IS_PLAYER_EVADING_WANTED_LEVEL(char* playerSrc)`

## IS_PLAYER_IN_FREE_CAM_MODE
`0x1F14F2AC` | `void IS_PLAYER_IN_FREE_CAM_MODE(char* playerSrc)`

## IS_PLAYER_USING_SUPER_JUMP
`0xC7D2C20C` | `void IS_PLAYER_USING_SUPER_JUMP(char* playerSrc)`

## IS_PRINCIPAL_ACE_ALLOWED
`0x37CF52CE` | `void IS_PRINCIPAL_ACE_ALLOWED(char* principal, char* object)`

## IS_RAW_KEY_DOWN
`0xD95A7387` | `void IS_RAW_KEY_DOWN(int rawKeyIndex)`
```lua
if IsRawKeyDown(32) then -- KEY_SPACE
    print("Spacebar is down")
end
```

## IS_RAW_KEY_PRESSED
`0x69F7C29E` | `void IS_RAW_KEY_PRESSED(int rawKeyIndex)`
```lua
if IsRawKeyPressed(32) then -- KEY_SPACE
    print("Spacebar pressed")
end
```

## IS_RAW_KEY_RELEASED
`0xEAA50861` | `void IS_RAW_KEY_RELEASED(int rawKeyIndex)`
```lua
if IsRawKeyReleased(32) then -- KEY_SPACE
    print("Spacebar released")
end
```

## IS_RAW_KEY_UP
`0x36F4E505` | `void IS_RAW_KEY_UP(int rawKeyIndex)`
```lua
if IsRawKeyUp(32) then -- KEY_SPACE
    print("Spacebar is up")
end
```

## IS_STREAMING_FILE_READY
`0xA194934D` | `void IS_STREAMING_FILE_READY(char* registerAs)`

## IS_TRACK_ENABLED
`0x31E695CB` | `void IS_TRACK_ENABLED(int track)`

## IS_TRACK_SWITCHED_OFF
`0xE0C53765` | `void IS_TRACK_SWITCHED_OFF(int track)`

## IS_TRAIN_CABOOSE
`0xFA9336E5` | `void IS_TRAIN_CABOOSE(Vehicle train)`

## IS_VEHICLE_ALARM_SET
`0xDC921211` | `void IS_VEHICLE_ALARM_SET(Vehicle vehicle)`

## IS_VEHICLE_ENGINE_STARTING
`0xBB340D04` | `void IS_VEHICLE_ENGINE_STARTING(Vehicle vehicle)`

## IS_VEHICLE_EXTRA_TURNED_ON
`0x42098B5` | `void IS_VEHICLE_EXTRA_TURNED_ON(Vehicle vehicle, int extraId)`

## IS_VEHICLE_INTERIOR_LIGHT_ON
`0xA411F72C` | `void IS_VEHICLE_INTERIOR_LIGHT_ON(Vehicle vehicle)`

## IS_VEHICLE_NEEDS_TO_BE_HOTWIRED
`0xF9933BF4` | `void IS_VEHICLE_NEEDS_TO_BE_HOTWIRED(Vehicle vehicle)`

## IS_VEHICLE_PREVIOUSLY_OWNED_BY_PLAYER
`0xF849ED67` | `void IS_VEHICLE_PREVIOUSLY_OWNED_BY_PLAYER(Vehicle vehicle)`

## IS_VEHICLE_SIREN_ON
`0x25EB5873` | `void IS_VEHICLE_SIREN_ON(Vehicle vehicle)`

## IS_VEHICLE_TYRE_BURST
`0x48C80210` | `void IS_VEHICLE_TYRE_BURST(Vehicle vehicle, int wheelID, BOOL completely)`

## IS_VEHICLE_WANTED
`0xA7DAF7C` | `void IS_VEHICLE_WANTED(Vehicle vehicle)`

## IS_VEHICLE_WHEEL_BROKEN_OFF
`0xCF1BC668` | `void IS_VEHICLE_WHEEL_BROKEN_OFF(Vehicle vehicle, int wheelIndex)`
```lua
local vehicle = GetVehiclePedIsIn(PlayerPedId())

if DoesEntityExist(vehicle) then
  local isWheelBroken = IsVehicleWheelBrokenOff(vehicle, 1)
  print("Is wheel 1 broken? ", isWheelBroken)
end
```

## IS_VEHICLE_WINDOW_INTACT
`0xAC4EF23D` | `void IS_VEHICLE_WINDOW_INTACT(Vehicle vehicle, int windowIndex)`

## LEAVE_CURSOR_MODE
`0xADECF19E` | `void LEAVE_CURSOR_MODE()`

## LOAD_PLAYER_COMMERCE_DATA
`0xA8F63EAB` | `void LOAD_PLAYER_COMMERCE_DATA(char* playerSrc)`

## LOAD_PLAYER_COMMERCE_DATA_EXT
`0x7995539E` | `void LOAD_PLAYER_COMMERCE_DATA_EXT(char* playerSrc)`
```lua
RegisterNetEvent("doesOwnPackage", function(packageIdSku)
	-- source isn't valid across waits, so we localize it
	local source = source

	-- input isn't right
	if type(packageIdSku) ~= "number" then
		return
	end

	-- The native will cache the results
	LoadPlayerCommerceDataExt(source)
	-- Wait for the players data to load
	while not IsPlayerCommerceInfoLoadedExt(source) do
		Wait(0)
	end

	-- Tell the client if they own the package or not
	TriggerClientEvent("doesOwnPackage", source, DoesPlayerOwnSkuExt(source, packageIdSku))
end)
```

## LOAD_RESOURCE_FILE
`0x76A9EE1F` | `void LOAD_RESOURCE_FILE(char* resourceName, char* fileName)`

## LOAD_WATER_FROM_PATH
`0xF5102568` | `void LOAD_WATER_FROM_PATH(char* resourceName, char* fileName)`
```lua
local success = LoadWaterFromPath('my-resource-name', 'water-all-over-the-place.xml')
```

## MUMBLE_ADD_VOICE_CHANNEL_LISTEN
`0xC79F44BF` | `void MUMBLE_ADD_VOICE_CHANNEL_LISTEN(int channel)`

## MUMBLE_ADD_VOICE_TARGET_CHANNEL
`0x4D386C9E` | `void MUMBLE_ADD_VOICE_TARGET_CHANNEL(int targetId, int channel)`

## MUMBLE_ADD_VOICE_TARGET_PLAYER
`0x32C5355A` | `void MUMBLE_ADD_VOICE_TARGET_PLAYER(int targetId, Player player)`

## MUMBLE_ADD_VOICE_TARGET_PLAYER_BY_SERVER_ID
`0x25F2B65F` | `void MUMBLE_ADD_VOICE_TARGET_PLAYER_BY_SERVER_ID(int targetId, int serverId)`

## MUMBLE_CLEAR_VOICE_CHANNEL
`0xBF847807` | `void MUMBLE_CLEAR_VOICE_CHANNEL()`

## MUMBLE_CLEAR_VOICE_TARGET
`0x8555DCBA` | `void MUMBLE_CLEAR_VOICE_TARGET(int targetId)`

## MUMBLE_CLEAR_VOICE_TARGET_CHANNELS
`0x5EA72E76` | `void MUMBLE_CLEAR_VOICE_TARGET_CHANNELS(int targetId)`

## MUMBLE_CLEAR_VOICE_TARGET_PLAYERS
`0x912E21DA` | `void MUMBLE_CLEAR_VOICE_TARGET_PLAYERS(int targetId)`

## MUMBLE_CREATE_CHANNEL
`0x262663C5` | `void MUMBLE_CREATE_CHANNEL(int id)`

## MUMBLE_DOES_CHANNEL_EXIST
`0xCC8CA25` | `void MUMBLE_DOES_CHANNEL_EXIST(int channel)`

## MUMBLE_GET_TALKER_PROXIMITY
`0x84E02A32` | `void MUMBLE_GET_TALKER_PROXIMITY()`

## MUMBLE_GET_VOICE_CHANNEL_FROM_SERVER_ID
`0x221C09F1` | `void MUMBLE_GET_VOICE_CHANNEL_FROM_SERVER_ID(int serverId)`

## MUMBLE_IS_ACTIVE
`0xE820BC10` | `void MUMBLE_IS_ACTIVE()`

## MUMBLE_IS_CONNECTED
`0xB816370A` | `void MUMBLE_IS_CONNECTED()`

## MUMBLE_IS_PLAYER_MUTED
`0x1D5D50C2` | `void MUMBLE_IS_PLAYER_MUTED(int playerSrc)`

## MUMBLE_IS_PLAYER_TALKING
`0x33EEF97F` | `void MUMBLE_IS_PLAYER_TALKING(Player player)`

## MUMBLE_REMOVE_VOICE_CHANNEL_LISTEN
`0x231523B7` | `void MUMBLE_REMOVE_VOICE_CHANNEL_LISTEN(int channel)`

## MUMBLE_REMOVE_VOICE_TARGET_CHANNEL
`0x268DB867` | `void MUMBLE_REMOVE_VOICE_TARGET_CHANNEL(int targetId, int channel)`

## MUMBLE_REMOVE_VOICE_TARGET_PLAYER
`0x88CD646F` | `void MUMBLE_REMOVE_VOICE_TARGET_PLAYER(int targetId, Player player)`

## MUMBLE_REMOVE_VOICE_TARGET_PLAYER_BY_SERVER_ID
`0x930BD34B` | `void MUMBLE_REMOVE_VOICE_TARGET_PLAYER_BY_SERVER_ID(int targetId, int serverId)`

## MUMBLE_SET_ACTIVE
`0xD932A3F3` | `void MUMBLE_SET_ACTIVE(BOOL state)`

## MUMBLE_SET_AUDIO_INPUT_DISTANCE
`0x1B1052E2` | `void MUMBLE_SET_AUDIO_INPUT_DISTANCE(float distance)`

## MUMBLE_SET_AUDIO_INPUT_INTENT
`0x6383526B` | `void MUMBLE_SET_AUDIO_INPUT_INTENT(Hash intentHash)`
```lua
-- disable noise suppression and high pass filter
MumbleSetAudioInputIntent(`music`)

-- set the default intent (enable noise suppression and high pass filter)
MumbleSetAudioInputIntent(`speech`)
```

## MUMBLE_SET_AUDIO_OUTPUT_DISTANCE
`0x74C597D9` | `void MUMBLE_SET_AUDIO_OUTPUT_DISTANCE(float distance)`

## MUMBLE_SET_PLAYER_MUTED
`0xCC6C2EB1` | `void MUMBLE_SET_PLAYER_MUTED(int playerSrc, bool toggle)`

## MUMBLE_SET_SERVER_ADDRESS
`0xE6EB2CD8` | `void MUMBLE_SET_SERVER_ADDRESS(char* address, int port)`

## MUMBLE_SET_SUBMIX_FOR_SERVER_ID
`0xFE3A3054` | `void MUMBLE_SET_SUBMIX_FOR_SERVER_ID(int serverId, int submixId)`

## MUMBLE_SET_TALKER_PROXIMITY
`0x74E927B0` | `void MUMBLE_SET_TALKER_PROXIMITY(float value)`

## MUMBLE_SET_VOICE_CHANNEL
`0x8737EEE8` | `void MUMBLE_SET_VOICE_CHANNEL(int channel)`

## MUMBLE_SET_VOICE_TARGET
`0x960A4A95` | `void MUMBLE_SET_VOICE_TARGET(int targetId)`

## MUMBLE_SET_VOLUME_OVERRIDE
`0x61C309E3` | `void MUMBLE_SET_VOLUME_OVERRIDE(Player player, float volume)`

## MUMBLE_SET_VOLUME_OVERRIDE_BY_SERVER_ID
`0xCE8E25B4` | `void MUMBLE_SET_VOLUME_OVERRIDE_BY_SERVER_ID(int serverId, float volume)`

## NETWORK_DOES_ENTITY_EXIST_WITH_NETWORK_ID
`0x1E2E3177` | `void NETWORK_DOES_ENTITY_EXIST_WITH_NETWORK_ID(int netId)`

## NETWORK_GET_ENTITY_FROM_NETWORK_ID
`0x5B912C3F` | `void NETWORK_GET_ENTITY_FROM_NETWORK_ID(int netId)`

## NETWORK_GET_ENTITY_OWNER
`0x526FEE31` | `void NETWORK_GET_ENTITY_OWNER(Entity entity)`

## NETWORK_GET_FIRST_ENTITY_OWNER
`0x1E546224` | `void NETWORK_GET_FIRST_ENTITY_OWNER(Entity entity)`

## NETWORK_GET_NETWORK_ID_FROM_ENTITY
`0x9E35DAB6` | `void NETWORK_GET_NETWORK_ID_FROM_ENTITY(Entity entity)`

## NETWORK_GET_VOICE_PROXIMITY_OVERRIDE_FOR_PLAYER
`0xFFEEF513` | `void NETWORK_GET_VOICE_PROXIMITY_OVERRIDE_FOR_PLAYER(char* playerSrc)`

## ONESYNC_ENABLE_REMOTE_ATTACHMENT_SANITIZATION
`0x30CE39D8` | `void ONESYNC_ENABLE_REMOTE_ATTACHMENT_SANITIZATION(BOOL enable)`

## OVERRIDE_PEDS_CAN_STAND_ON_TOP_FLAG
`0x90A9E0B2` | `void OVERRIDE_PEDS_CAN_STAND_ON_TOP_FLAG(BOOL flag)`

## OVERRIDE_PEDS_USE_DEFAULT_DRIVE_BY_CLIPSET
`0xB14F8EAD` | `void OVERRIDE_PEDS_USE_DEFAULT_DRIVE_BY_CLIPSET(BOOL flag)`

## OVERRIDE_POP_GROUPS
`0xD3BC438F` | `void OVERRIDE_POP_GROUPS(char* path)`
```lua
-- fxmanifest.lua:
file 'popgroups_dlc.xml'

-- client.lua:
OverridePopGroups('popgroups_dlc.xml')

-- restore the original after five minutes
Wait(1000 * 60 * 5)
OverridePopGroups(nil)
```

## OVERRIDE_REACTION_TO_VEHICLE_SIREN
`0x3F3EB3F7` | `void OVERRIDE_REACTION_TO_VEHICLE_SIREN(BOOL state, int reaction)`

## OVERRIDE_VEHICLE_PEDS_CAN_STAND_ON_TOP_FLAG
`0x7FA03E76` | `void OVERRIDE_VEHICLE_PEDS_CAN_STAND_ON_TOP_FLAG(Vehicle vehicle, BOOL can)`

## PERFORM_HTTP_REQUEST_INTERNAL
`0x8E8CC653` | `void PERFORM_HTTP_REQUEST_INTERNAL(char* requestData, int requestDataLength)`

## PERFORM_HTTP_REQUEST_INTERNAL_EX
`0x6B171E87` | `void PERFORM_HTTP_REQUEST_INTERNAL_EX(object requestData)`

## PREPARE_LIGHT
`0x584B4C99` | `void PREPARE_LIGHT(int lightType, int flags, float x, float y, float z, int r, int g, int b, float intensity)`

## PRINT_STRUCTURED_TRACE
`0x90892DED` | `void PRINT_STRUCTURED_TRACE(char* jsonString)`

## PROFILER_ENTER_SCOPE
`0xC795A4A9` | `void PROFILER_ENTER_SCOPE(char* scopeName)`

## PROFILER_EXIT_SCOPE
`0xB39CA35C` | `void PROFILER_EXIT_SCOPE()`

## PROFILER_IS_RECORDING
`0xF8B7D7BB` | `void PROFILER_IS_RECORDING()`

## REGISTER_ARCHETYPES
`0x3C2F9037` | `void REGISTER_ARCHETYPES(func factory)`
```lua
RegisterArchetypes(function()
	return {
		{
			flags = 32,
			bbMin = vector3(-39.99570000, -8.00155600, -2.56818800),
			bbMax = vector3(40.00439000, 7.99858000, 1.44575100),
			bsCentre = vector3(0.00434110, -0.00148870, -0.56121830),
			bsRadius = 40.84160000,
			name = 'my_asset',
			textureDictionary = 'my_asset',
			physicsDictionary = 'my_asset',
			assetName = 'my_asset',
			assetType = 'ASSET_TYPE_DRAWABLE',
			lodDist = 450.45,
			specialAttribute = 0
		}
	}
end)
```

## REGISTER_COMMAND
`0x5FA79B0F` | `void REGISTER_COMMAND(char* commandName, func handler, BOOL restricted)`
```lua
-- (server side script)
-- Registers a command named 'ping'.
RegisterCommand("ping", function(source, args, rawCommand)
    -- If the source is > 0, then that means it must be a player.
    if (source > 0) then
    
        -- result (using the default GTA:O chat theme) https://i.imgur.com/TaCnG09.png
        TriggerClientEvent("chat:addMessage", -1, {
            args = {
                GetPlayerName(source),
                "PONG!"
            },
            color = { 5, 255, 255 }
        })
    
    -- If it's not a player, then it must be RCON, a resource, or the server console directly.
    else
        print("This command was executed by the server console, RCON client, or a resource.")
    end
end, false --[[this command is not restricted, everyone can use this.]])
```
```cs
RegisterCommand("ping", new Action<int, List<object>, string>((source, args, rawCommand) =>
{
    if (source > 0) // it's a player.
    {
        // Create a message object.
        dynamic messageObject = new ExpandoObject();
        // Set the message object args (message author, message content)
        messageObject.args = new string[] { GetPlayerName(source.ToString()), "PONG!" };
        // Set the message color (r, g, b)
        messageObject.color = new int[] { 5, 255, 255 };

        // Trigger the client event with the message object on all clients.
        TriggerClientEvent("chat:addMessage", messageObject);
    }
    // It's not a player, so it's the server console, a RCON client, or a resource.
    else
    {
        Debug.WriteLine("This command was executed by the server console, RCON client, or a resource.");
    }
}), false /*This command is also not restricted, anyone can use it.*/ );
```

## REGISTER_CONSOLE_LISTENER
`0x281B5448` | `void REGISTER_CONSOLE_LISTENER(func listener)`

## REGISTER_FONT_FILE
`0x1B3A363` | `void REGISTER_FONT_FILE(char* fileName)`

## REGISTER_FONT_ID
`0xACF6D8EE` | `void REGISTER_FONT_ID(char* fontName)`

## REGISTER_KEY_MAPPING
`0xD7664FD1` | `void REGISTER_KEY_MAPPING(char* commandString, char* description, char* defaultMapper, char* defaultParameter)`
```lua
local handsUp = false
CreateThread(function()
    while true do
        Wait(0)
        if handsUp then
            TaskHandsUp(PlayerPedId(), 250, PlayerPedId(), -1, true)
        end
    end
end)
RegisterCommand('+handsup', function()
    handsUp = true
end, false)
RegisterCommand('-handsup', function()
    handsUp = false
end, false)

RegisterKeyMapping('+handsup', 'Hands Up', 'keyboard', 'i')

-- Alternate keybinding syntax
RegisterKeyMapping('~!+handsup', 'Hands Up - Alternate Key', 'keyboard', 'o')
```

## REGISTER_NUI_CALLBACK
`0xC59B980C` | `void REGISTER_NUI_CALLBACK(char* callbackType, func callback)`

## REGISTER_NUI_CALLBACK_TYPE
`0xCD03CDA9` | `void REGISTER_NUI_CALLBACK_TYPE(char* callbackType)`

## REGISTER_RAW_KEYMAP
`0x49C1F6DC` | `void REGISTER_RAW_KEYMAP(char* keymapName, func onKeyDown, func onKeyUp, int rawKeyIndex, BOOL canBeDisabled)`
```lua
function on_key_up()
	print("key no longer pressed")
end

function on_key_down()
	print("key is pressed")
end

local KEY_E = 69
local canBeDisabled = false


RegisterRawKeymap("our_keymap", on_key_up, on_key_down, KEY_E, canBeDisabled)
```

## REGISTER_RAW_NUI_CALLBACK
`0xA8AE9C2F` | `void REGISTER_RAW_NUI_CALLBACK(char* callbackType, func callback)`

## REGISTER_RESOURCE_ASSET
`0x9862B266` | `void REGISTER_RESOURCE_ASSET(char* resourceName, char* fileName)`

## REGISTER_RESOURCE_AS_EVENT_HANDLER
`0xD233A168` | `void REGISTER_RESOURCE_AS_EVENT_HANDLER(char* eventName)`

## REGISTER_RESOURCE_BUILD_TASK_FACTORY
`0x285B43CA` | `void REGISTER_RESOURCE_BUILD_TASK_FACTORY(char* factoryId, func factoryFn)`

## REGISTER_ROPE_DATA
`0xF213AE8D` | `void REGISTER_ROPE_DATA(int numSections, float radius, char* diffuseTextureName, char* normalMapName, float distanceMappingScale, float uvScaleX, float uvScaleY, float specularFresnel, float specularFalloff, float specularIntensity, float bumpiness, int color)`
```lua
-- Create a thick steel cable rope above the players head
local ropeType = RegisterRopeData(6, 0.15, "steel_cable", "steel_cable_n", 1.0, 1.0, 8.775, 0.97, 30.0, 0.25, 1.775, 0x00FFFF00)
if ropeType ~= -1 then
    local coords = GetEntityCoords(PlayerPedId()) + vector3(0.0, 0.0, 5.0)
	AddRope(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 25.0, ropeType, 10.0, 0.0, 1.0, false, false, false, 1.0, false, 0)
    RopeLoadTextures()
end
```

## REGISTER_STREAMING_FILE_FROM_CACHE
`0xCEAD2D4B` | `void REGISTER_STREAMING_FILE_FROM_CACHE(char* resourceName, char* fileName, char* cacheString)`

## REGISTER_STREAMING_FILE_FROM_KVS
`0x1493DCC1` | `void REGISTER_STREAMING_FILE_FROM_KVS(char* kvsKey)`

## REGISTER_STREAMING_FILE_FROM_URL
`0xF44BFB95` | `void REGISTER_STREAMING_FILE_FROM_URL(char* registerAs, char* url)`

## REGISTER_TRACK_JUNCTION
`0x35F743B5` | `void REGISTER_TRACK_JUNCTION(int trackIndex, int trackNode, int newIndex, int newNode, bool direction)`

## REMAP_RAW_KEYMAP
`0x6E38C1B9` | `void REMAP_RAW_KEYMAP(char* keymapName, int newRawKeyIndex)`
```lua

function on_key_up()
	print("key no longer pressed")
end

function on_key_down()
	print("key is pressed")
end

local KEY_SPACE = 32
local canBeDisabled = false

local KEY_E = 69

RegisterRawKeymap("our_keymap", on_key_up, on_key_down, KEY_SPACE, canBeDisabled)

RemapRawKeymap("our_keymap", KEY_E)
```

## REMOVE_ALL_PED_WEAPONS
`0xA44CE817` | `void REMOVE_ALL_PED_WEAPONS(Ped ped, BOOL p1)`

## REMOVE_BLIP
`0xD8C3C1CD` | `void REMOVE_BLIP(Blip* blip)`

## REMOVE_CONVAR_CHANGE_LISTENER
`0xEAC49841` | `void REMOVE_CONVAR_CHANGE_LISTENER(int cookie)`

## REMOVE_DRY_VOLUME
`0x7BCAA6E7` | `void REMOVE_DRY_VOLUME(int handle)`

## REMOVE_HEALTH_CONFIG
`0xE0ED5FB` | `void REMOVE_HEALTH_CONFIG(char* configName)`

## REMOVE_REPLACE_TEXTURE
`0xA896B20A` | `void REMOVE_REPLACE_TEXTURE(char* origTxd, char* origTxn)`

## REMOVE_STATE_BAG_CHANGE_HANDLER
`0xD36BE661` | `void REMOVE_STATE_BAG_CHANGE_HANDLER(int cookie)`

## REMOVE_TEXTURE
`0x1582C7F2` | `void REMOVE_TEXTURE(int textureId)`

## REMOVE_TIMECYCLE_MODIFIER
`0x36DF8612` | `void REMOVE_TIMECYCLE_MODIFIER(char* modifierName)`
```lua
local modifierName = "my_awesome_timecycle"
RemoveTimecycleModifier(modifierName)
```

## REMOVE_TIMECYCLE_MODIFIER_VAR
`0x5A5E0D05` | `void REMOVE_TIMECYCLE_MODIFIER_VAR(char* modifierName, char* varName)`
```lua
local modifierName = "superDARK"
local varName = "postfx_noise"

if DoesTimecycleModifierHasVar(modifierName, varName) then
  local success, value1, value2 = GetTimecycleModifierVar(modifierName, varName)

  if success then
    print(string.format("[%s] removed var %s with values: %f %f", modifierName, varName, value1, value2))
    RemoveTimecycleModifierVar(modifierName, varName)
  end
else
    SetTimecycleModifierVar(modifierName, varName, 1.0, 1.0)
    print(string.format("[%s] created var %s", modifierName, varName))
end
```

## REMOVE_TRACK_JUNCTION
`0x4F3D2B2A` | `void REMOVE_TRACK_JUNCTION(int junctionIndex)`

## REMOVE_WEAPON_COMPONENT_FROM_PED
`0x412AA00D` | `void REMOVE_WEAPON_COMPONENT_FROM_PED(Ped ped, Hash weaponHash, Hash componentHash)`

## REMOVE_WEAPON_FROM_PED
`0x9C37F220` | `void REMOVE_WEAPON_FROM_PED(Ped ped, Hash weaponHash)`

## REQUEST_PLAYER_COMMERCE_SESSION
`0x96F93CCE` | `void REQUEST_PLAYER_COMMERCE_SESSION(char* playerSrc, int skuId)`

## REQUEST_RESOURCE_FILE_SET
`0xE7490533` | `void REQUEST_RESOURCE_FILE_SET(char* setName)`
```lua
-- fxmanifest.lua
file_set 'dummies' {
    'dummy/**.txt',
    'potato.txt',
}

-- main script
local function PrintTest()
    local tests = { 'potato.txt', 'dummy/1.txt', 'dummy/b/2.txt' }

    for _, v in ipairs(tests) do
        local data = LoadResourceFile(GetCurrentResourceName(), v)
        print(v, data)
    end
end

RegisterCommand('fileset', function()
    PrintTest()

    while not RequestResourceFileSet('dummies') do
        Wait(100)
    end

    PrintTest()
end)
```

## RESET_ENTITY_DRAW_OUTLINE_RENDER_TECHNIQUE
`0x8EB6EC38` | `void RESET_ENTITY_DRAW_OUTLINE_RENDER_TECHNIQUE()`

## RESET_FLY_THROUGH_WINDSCREEN_PARAMS
`0x6D712937` | `void RESET_FLY_THROUGH_WINDSCREEN_PARAMS()`

## RESET_MAPDATA_ENTITY_MATRIX
`0x8143FA4F` | `void RESET_MAPDATA_ENTITY_MATRIX(int mapDataHash, int entityInternalIdx)`

## RESET_MAP_ZOOM_DATA_LEVEL
`0x11A5B7ED` | `void RESET_MAP_ZOOM_DATA_LEVEL(int index)`

## RESET_PED_MODEL_PERSONALITY
`0x79A12861` | `void RESET_PED_MODEL_PERSONALITY(Hash modelHash)`

## RESET_VEHICLE_PEDS_CAN_STAND_ON_TOP_FLAG
`0xDF62CFE2` | `void RESET_VEHICLE_PEDS_CAN_STAND_ON_TOP_FLAG(Vehicle vehicle)`

## RESET_WATER
`0x1DA4791` | `void RESET_WATER()`
```lua
ResetWater()
```

## SAVE_RESOURCE_FILE
`0xA09E7E7B` | `void SAVE_RESOURCE_FILE(char* resourceName, char* fileName, char* data, int dataLength)`

## SCAN_RESOURCE_ROOT
`0x636F097F` | `void SCAN_RESOURCE_ROOT(char* rootPath, func callback)`

## SCHEDULE_RESOURCE_TICK
`0xB88A73AD` | `void SCHEDULE_RESOURCE_TICK(char* resourceName)`

## SELECT_ENTITY_AT_CURSOR
`0x3DD8130F` | `void SELECT_ENTITY_AT_CURSOR(int hitFlags, BOOL precise)`

## SELECT_ENTITY_AT_POS
`0xAFE8D405` | `void SELECT_ENTITY_AT_POS(float fracX, float fracY, int hitFlags, BOOL precise)`

## SEND_DUI_MESSAGE
`0xCD380DA9` | `void SEND_DUI_MESSAGE(long duiObject, char* jsonString)`

## SEND_DUI_MOUSE_DOWN
`0x5D01F191` | `void SEND_DUI_MOUSE_DOWN(long duiObject, char* button)`

## SEND_DUI_MOUSE_MOVE
`0xD9D7A0AA` | `void SEND_DUI_MOUSE_MOVE(long duiObject, int x, int y)`

## SEND_DUI_MOUSE_UP
`0x1D735B93` | `void SEND_DUI_MOUSE_UP(long duiObject, char* button)`

## SEND_DUI_MOUSE_WHEEL
`0x2D62133A` | `void SEND_DUI_MOUSE_WHEEL(long duiObject, int deltaY, int deltaX)`

## SEND_LOADING_SCREEN_MESSAGE
`0x8BBE6CC0` | `void SEND_LOADING_SCREEN_MESSAGE(char* jsonString)`

## SEND_NUI_MESSAGE
`0x78608ACB` | `void SEND_NUI_MESSAGE(char* jsonString)`

## SET_AIM_COOLDOWN
`0xA42A3DBF` | `void SET_AIM_COOLDOWN(int value)`

## SET_AUDIO_SUBMIX_EFFECT_PARAM_FLOAT
`0x9A209B3C` | `void SET_AUDIO_SUBMIX_EFFECT_PARAM_FLOAT(int submixId, int effectSlot, int paramIndex, float paramValue)`

## SET_AUDIO_SUBMIX_EFFECT_PARAM_INT
`0x77FAE2B8` | `void SET_AUDIO_SUBMIX_EFFECT_PARAM_INT(int submixId, int effectSlot, int paramIndex, int paramValue)`

## SET_AUDIO_SUBMIX_EFFECT_RADIO_FX
`0xAAA94D53` | `void SET_AUDIO_SUBMIX_EFFECT_RADIO_FX(int submixId, int effectSlot)`
```lua
-- we want to change the master output
local submix = 0

-- add a RadioFX effect to slot 0
SetAudioSubmixEffectRadioFx(submix, 0)

-- set the default values
SetAudioSubmixEffectParamInt(submix, 0, `default`, 1)
```

## SET_AUDIO_SUBMIX_OUTPUT_VOLUMES
`0x825DC0D1` | `void SET_AUDIO_SUBMIX_OUTPUT_VOLUMES(int submixId, int outputSlot, float frontLeftVolume, float frontRightVolume, float rearLeftVolume, float rearRightVolume, float channel5Volume, float channel6Volume)`

## SET_BACKFACECULLING
`0xC44C2F44` | `void SET_BACKFACECULLING(BOOL toggle)`

## SET_BLIP_SPRITE
`0x8DBBB0B9` | `void SET_BLIP_SPRITE(Blip blip, int spriteId)`

## SET_CALMING_QUAD_BOUNDS
`0xC5945BD9` | `void SET_CALMING_QUAD_BOUNDS(int waterQuad, int minX, int minY, int maxX, int maxY)`
```lua
local success = SetCalmingQuadBounds(1, -500, -500, 500, 500)
```

## SET_CALMING_QUAD_DAMPENING
`0x67977501` | `void SET_CALMING_QUAD_DAMPENING(int calmingQuad, float dampening)`
```lua
local success = SetCalmingQuadDampening(0, 1.0)
```

## SET_CLIENT_CONFIG_BOOL
`0xD174EF7E` | `void SET_CLIENT_CONFIG_BOOL(int flagIndex, BOOL enabled)`

## SET_CONVAR
`0x341B16D2` | `void SET_CONVAR(char* varName, char* value)`

## SET_CONVAR_REPLICATED
`0xF292858C` | `void SET_CONVAR_REPLICATED(char* varName, char* value)`
```lua
SetConvarReplicated('voice_useNativeAudio', 'true')
```

## SET_CONVAR_SERVER_INFO
`0x9338D547` | `void SET_CONVAR_SERVER_INFO(char* varName, char* value)`

## SET_CURRENT_PED_WEAPON
`0xB8278882` | `void SET_CURRENT_PED_WEAPON(Ped ped, Hash weaponHash, BOOL bForceInHand)`

## SET_CURSOR_LOCATION
`0x8A7A8DAC` | `void SET_CURSOR_LOCATION(float x, float y)`

## SET_DEFAULT_VEHICLE_NUMBER_PLATE_TEXT_PATTERN
`0x79780FD2` | `void SET_DEFAULT_VEHICLE_NUMBER_PLATE_TEXT_PATTERN(int plateIndex, char* pattern)`
```lua
SetDefaultVehicleNumberPlateTextPattern(-1, ' AAA111 ')
SetDefaultVehicleNumberPlateTextPattern(4 , ' AAAAAA ')

-- fixed characters: plate will be FAYUM69C for example
SetDefaultVehicleNumberPlateTextPattern(-1, 'F^AYUM11A')
```

## SET_DISCORD_APP_ID
`0x6A02254D` | `void SET_DISCORD_APP_ID(char* appId)`

## SET_DISCORD_RICH_PRESENCE_ACTION
`0xCBBC3FAC` | `void SET_DISCORD_RICH_PRESENCE_ACTION(int index, char* label, char* url)`

## SET_DISCORD_RICH_PRESENCE_ASSET
`0x53DFD530` | `void SET_DISCORD_RICH_PRESENCE_ASSET(char* assetName)`

## SET_DISCORD_RICH_PRESENCE_ASSET_SMALL
`0xF61D04C4` | `void SET_DISCORD_RICH_PRESENCE_ASSET_SMALL(char* assetName)`

## SET_DISCORD_RICH_PRESENCE_ASSET_SMALL_TEXT
`0x35E62B6A` | `void SET_DISCORD_RICH_PRESENCE_ASSET_SMALL_TEXT(char* text)`

## SET_DISCORD_RICH_PRESENCE_ASSET_TEXT
`0xB029D2FA` | `void SET_DISCORD_RICH_PRESENCE_ASSET_TEXT(char* text)`

## SET_DRAW_ORIGIN
`0xE10198D5` | `void SET_DRAW_ORIGIN(float x, float y, float z, BOOL is2d)`

## SET_DUI_URL
`0xF761D9F3` | `void SET_DUI_URL(long duiObject, char* url)`

## SET_EMITTER_PROBE_LENGTH
`0x8AA1F3C2` | `void SET_EMITTER_PROBE_LENGTH(float probeLength)`
```lua
RegisterCommand("setEmitterProbeLength", function(src, args, raw)
    local probeLength = (tonumber(args[1]) + 0.0)

    print("Extending emitter probes to: ", probeLength)
    SetEmitterProbeLength(probeLength)
end)

RegisterCommand("resetEmitterProbeLength", function()
    print("Resetting emitter probes to default settings")
    SetEmitterProbeLength(20.0)
end)
```

## SET_ENTITY_COORDS
`0xDF70B41B` | `void SET_ENTITY_COORDS(Entity entity, float xPos, float yPos, float zPos, BOOL alive, BOOL deadFlag, BOOL ragdollFlag, BOOL clearArea)`

## SET_ENTITY_DISTANCE_CULLING_RADIUS
`0xD3A183A3` | `void SET_ENTITY_DISTANCE_CULLING_RADIUS(Entity entity, float radius)`

## SET_ENTITY_DRAW_OUTLINE
`0x76180407` | `void SET_ENTITY_DRAW_OUTLINE(Entity entity, BOOL enabled)`

## SET_ENTITY_DRAW_OUTLINE_COLOR
`0xB41A56C2` | `void SET_ENTITY_DRAW_OUTLINE_COLOR(int red, int green, int blue, int alpha)`

## SET_ENTITY_DRAW_OUTLINE_RENDER_TECHNIQUE
`0x68DFF2DD` | `void SET_ENTITY_DRAW_OUTLINE_RENDER_TECHNIQUE(char* techniqueGroup)`

## SET_ENTITY_DRAW_OUTLINE_SHADER
`0x5261A01A` | `void SET_ENTITY_DRAW_OUTLINE_SHADER(int shader)`

## SET_ENTITY_HEADING
`0xE0FF064D` | `void SET_ENTITY_HEADING(Entity entity, float heading)`

## SET_ENTITY_IGNORE_REQUEST_CONTROL_FILTER
`0x9F7F8D36` | `void SET_ENTITY_IGNORE_REQUEST_CONTROL_FILTER(Entity entity, bool ignore)`

## SET_ENTITY_MATRIX
`0xFB0639B` | `void SET_ENTITY_MATRIX(Entity entity, float forwardX, float forwardY, float forwardZ, float rightX, float rightY, float rightZ, float upX, float upY, float upZ, float atX, float atY, float atZ)`

## SET_ENTITY_ORPHAN_MODE
`0x489E9162` | `void SET_ENTITY_ORPHAN_MODE(Entity entity, int orphanMode)`

## SET_ENTITY_REMOTE_SYNCED_SCENES_ALLOWED
`0xD3FC9D88` | `void SET_ENTITY_REMOTE_SYNCED_SCENES_ALLOWED(Entity entity, bool allow)`

## SET_ENTITY_ROTATION
`0xA345EFE` | `void SET_ENTITY_ROTATION(Entity entity, float pitch, float roll, float yaw, int rotationOrder, BOOL bDeadCheck)`

## SET_ENTITY_ROUTING_BUCKET
`0x635E5289` | `void SET_ENTITY_ROUTING_BUCKET(Entity entity, int bucket)`

## SET_ENTITY_VELOCITY
`0xFF5A1988` | `void SET_ENTITY_VELOCITY(Entity entity, float x, float y, float z)`

## SET_FALL_DAMAGE_LAND_ON_FOOT_MULTIPLIER
`0xA9EC9A79` | `void SET_FALL_DAMAGE_LAND_ON_FOOT_MULTIPLIER(float multiplier)`

## SET_FALL_DAMAGE_MULTIPLIER
`0xB43B621B` | `void SET_FALL_DAMAGE_MULTIPLIER(float multiplier)`

## SET_FLASH_LIGHT_KEEP_ON_WHILE_MOVING
`0x7635B349` | `void SET_FLASH_LIGHT_KEEP_ON_WHILE_MOVING(BOOL state)`

## SET_FLY_THROUGH_WINDSCREEN_PARAMS
`0x4D3118ED` | `void SET_FLY_THROUGH_WINDSCREEN_PARAMS(float vehMinSpeed, float unkMinSpeed, float unkModifier, float minDamage)`

## SET_FOG_VOLUME_RENDER_DISABLED
`0xFBC64DA3` | `void SET_FOG_VOLUME_RENDER_DISABLED(BOOL state)`

## SET_FUEL_CONSUMPTION_RATE_MULTIPLIER
`0x845F3E5C` | `void SET_FUEL_CONSUMPTION_RATE_MULTIPLIER(float multiplier)`

## SET_FUEL_CONSUMPTION_STATE
`0x81DAD03E` | `void SET_FUEL_CONSUMPTION_STATE(BOOL state)`

## SET_GAME_TYPE
`0xF90B7469` | `void SET_GAME_TYPE(char* gametypeName)`

## SET_GLOBAL_PASSENGER_MASS_MULTIPLIER
`0x1C47F6AC` | `void SET_GLOBAL_PASSENGER_MASS_MULTIPLIER(float massMul)`

## SET_HANDLING_FIELD
`0xFE8064E3` | `void SET_HANDLING_FIELD(char* vehicle, char* class_, char* fieldName, Any value)`

## SET_HANDLING_FLOAT
`0x90DD01C` | `void SET_HANDLING_FLOAT(char* vehicle, char* class_, char* fieldName, float value)`

## SET_HANDLING_INT
`0x8AB3F46C` | `void SET_HANDLING_INT(char* vehicle, char* class_, char* fieldName, int value)`

## SET_HANDLING_VECTOR
`0x7F9D543` | `void SET_HANDLING_VECTOR(char* vehicle, char* class_, char* fieldName, Vector3 value)`

## SET_HEALTH_CONFIG_DEFAULT_ARMOR
`0x20A1E6A2` | `void SET_HEALTH_CONFIG_DEFAULT_ARMOR(char* configName, float newValue)`

## SET_HEALTH_CONFIG_DEFAULT_ENDURANCE
`0x60F20B81` | `void SET_HEALTH_CONFIG_DEFAULT_ENDURANCE(char* configName, float newValue)`

## SET_HEALTH_CONFIG_DEFAULT_HEALTH
`0xC705C778` | `void SET_HEALTH_CONFIG_DEFAULT_HEALTH(char* configName, float newValue)`

## SET_HEALTH_CONFIG_DOG_TAKEDOWN_THRESHOLD
`0x9A995E96` | `void SET_HEALTH_CONFIG_DOG_TAKEDOWN_THRESHOLD(char* configName, float newValue)`

## SET_HEALTH_CONFIG_DYING_THRESHOLD
`0x9B00FD77` | `void SET_HEALTH_CONFIG_DYING_THRESHOLD(char* configName, float newValue)`

## SET_HEALTH_CONFIG_FATIGUED_THRESHOLD
`0xC58953FD` | `void SET_HEALTH_CONFIG_FATIGUED_THRESHOLD(char* configName, float newValue)`

## SET_HEALTH_CONFIG_HURT_THRESHOLD
`0x98DF1A83` | `void SET_HEALTH_CONFIG_HURT_THRESHOLD(char* configName, float newValue)`

## SET_HEALTH_CONFIG_INJURED_THRESHOLD
`0xF9D9B647` | `void SET_HEALTH_CONFIG_INJURED_THRESHOLD(char* configName, float newValue)`

## SET_HEALTH_CONFIG_INVINCIBLE
`0x4A9EEDE6` | `void SET_HEALTH_CONFIG_INVINCIBLE(char* configName, BOOL newValue)`

## SET_HEALTH_CONFIG_MELEE_FATAL_ATTACK
`0xDD443E53` | `void SET_HEALTH_CONFIG_MELEE_FATAL_ATTACK(char* configName, BOOL newValue)`

## SET_HEALTH_CONFIG_WRITHE_FROM_BULLET_THRESHOLD
`0xE97633CB` | `void SET_HEALTH_CONFIG_WRITHE_FROM_BULLET_THRESHOLD(char* configName, float newValue)`

## SET_HTTP_HANDLER
`0xF5C6330C` | `void SET_HTTP_HANDLER(func handler)`
```lua
SetHttpHandler(function(request, response)
  if request.method == 'GET' and request.path == '/ping' then -- if a GET request was sent to the `/ping` path
      response.writeHead(200, { ['Content-Type'] = 'text/plain' }) -- set the response status code to `200 OK` and the body content type to plain text
      response.send('pong') -- respond to the request with `pong`
  else -- otherwise
      response.writeHead(404) -- set the response status code to `404 Not Found`
      response.send() -- respond to the request with no data
  end
end)
```

## SET_HUD_COMPONENT_ALIGN
`0xEED219F2` | `void SET_HUD_COMPONENT_ALIGN(int id, int horizontalAlign, int verticalAlign)`

## SET_HUD_COMPONENT_SIZE
`0x7644A9FA` | `void SET_HUD_COMPONENT_SIZE(int id, float x, float y)`

## SET_IGNORE_VEHICLE_OWNERSHIP_FOR_STOWING
`0x85A10FFD` | `void SET_IGNORE_VEHICLE_OWNERSHIP_FOR_STOWING(BOOL ignore)`

## SET_INTERIOR_PORTAL_CORNER_POSITION
`0x87F43553` | `void SET_INTERIOR_PORTAL_CORNER_POSITION(int interiorId, int portalIndex, int cornerIndex, float posX, float posY, float posZ)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local portalCount = GetInteriorPortalCount(interiorId)

  -- rip portals
  for portalIndex = 0, portalCount - 1 do
    for cornerIndex = 0, 3 do -- 4 corners
      SetInteriorPortalCornerPosition(interiorId, portalIndex, cornerIndex, 0.0, 0.0, 0.0)
    end
  end
  
  RefreshInterior(interiorId)
end
```

## SET_INTERIOR_PORTAL_ENTITY_FLAG
`0x8349CD76` | `void SET_INTERIOR_PORTAL_ENTITY_FLAG(int interiorId, int portalIndex, int entityIndex, int flag)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local portalIndex = 0

if interiorId ~= 0 then
  local count = GetInteriorPortalEntityCount(interiorId, portalIndex)
  for i=0, count-1 do
    SetInteriorPortalEntityFlag(interiorId, portalIndex, i, 0)
  end
  RefreshInterior(interiorId)
end
```

## SET_INTERIOR_PORTAL_FLAG
`0x88B2355E` | `void SET_INTERIOR_PORTAL_FLAG(int interiorId, int portalIndex, int flag)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local portalIndex = 0

  SetInteriorPortalFlag(interiorId, portalIndex, 1)
  RefreshInterior(interiorId)
end
```

## SET_INTERIOR_PORTAL_ROOM_FROM
`0x298FC783` | `void SET_INTERIOR_PORTAL_ROOM_FROM(int interiorId, int portalIndex, int roomFrom)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local portalIndex = 0

  SetInteriorPortalRoomFrom(interiorId, portalIndex, 0)
  RefreshInterior(interiorId)
end
```

## SET_INTERIOR_PORTAL_ROOM_TO
`0x58982680` | `void SET_INTERIOR_PORTAL_ROOM_TO(int interiorId, int portalIndex, int roomTo)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  local portalIndex = 0

  SetInteriorPortalRoomTo(interiorId, portalIndex, 0)
  RefreshInterior(interiorId)
end
```

## SET_INTERIOR_PROBE_LENGTH
`0x423F7E39` | `void SET_INTERIOR_PROBE_LENGTH(float probeLength)`
```lua
RegisterCommand("setInteriorProbeLength", function(src, args, raw)
    local probeLength = (tonumber(args[1]) + 0.0)

    print("Extending interior detection probes to: ", probeLength)
    SetInteriorProbeLength(probeLength)
end)

RegisterCommand("resetInteriorProbeLength", function()
    print("Resetting interior detection probes to default settings")
    SetInteriorProbeLength(0.0)
end)
```

## SET_INTERIOR_ROOM_EXTENTS
`0x4FDCF51E` | `void SET_INTERIOR_ROOM_EXTENTS(int interiorId, int roomIndex, float bbMinX, float bbMinY, float bbMinZ, float bbMaxX, float bbMaxY, float bbMaxZ)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)

if interiorId ~= 0 then
  SetInteriorRoomExtents(interiorId, 0, -999.0, -999.0, -100.0, 999.0, 999.0, 100.0) -- 0 is a limbo usually
  RefreshInterior(interiorId)
end
```

## SET_INTERIOR_ROOM_FLAG
`0x5518D60B` | `void SET_INTERIOR_ROOM_FLAG(int interiorId, int roomIndex, int flag)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local roomHash = GetRoomKeyFromEntity(playerPed)
local roomId = GetInteriorRoomIndexByHash(interiorId, roomHash)

if roomId ~= -1 then
  SetInteriorRoomFlag(interiorId, roomId, 64)
  RefreshInterior(interiorId)
end
```

## SET_INTERIOR_ROOM_TIMECYCLE
`0x31C9A848` | `void SET_INTERIOR_ROOM_TIMECYCLE(int interiorId, int roomIndex, int timecycleHash)`
```lua
local playerPed = PlayerPedId()
local interiorId = GetInteriorFromEntity(playerPed)
local roomHash = GetRoomKeyFromEntity(playerPed)
local roomId = GetInteriorRoomIndexByHash(interiorId, roomHash)

if roomId ~= -1 then
  local timecycleHash = GetHashKey("scanline_cam")
  SetInteriorRoomTimecycle(interiorId, roomId, timecycleHash)
  RefreshInterior(interiorId)
end
```

## SET_KEY_MAPPING_HIDE_RESOURCES
`0xCB0241B5` | `void SET_KEY_MAPPING_HIDE_RESOURCES(bool hide)`

## SET_KILL_FALL_HEIGHT
`0x24091E09` | `void SET_KILL_FALL_HEIGHT(float height)`

## SET_LIGHT_ALPHA
`0xC0EBC38` | `void SET_LIGHT_ALPHA(float alpha)`

## SET_LIGHT_AO
`0xE155B53B` | `void SET_LIGHT_AO(float intensity, float radius, float bias, float intensity2)`

## SET_LIGHT_CAPSULE_SIZE
`0xA3881271` | `void SET_LIGHT_CAPSULE_SIZE(float size)`

## SET_LIGHT_CLIP_RECT
`0xD9DD0717` | `void SET_LIGHT_CLIP_RECT(int x, int y, int width, int height)`

## SET_LIGHT_COLOR
`0x65FE5132` | `void SET_LIGHT_COLOR(int r, int g, int b)`

## SET_LIGHT_CONE
`0x9FE89EF5` | `void SET_LIGHT_CONE(float innerConeAngle, float outerConeAngle)`

## SET_LIGHT_COORDS
`0x8950BD08` | `void SET_LIGHT_COORDS(float x, float y, float z)`

## SET_LIGHT_DIRECTION
`0xA6FE1977` | `void SET_LIGHT_DIRECTION(float xDir, float yDir, float zDir, float xTanDir, float yTanDir, float zTanDir)`

## SET_LIGHT_EXTRAFLAGS
`0xB2D37E97` | `void SET_LIGHT_EXTRAFLAGS(int extraFlags)`

## SET_LIGHT_FADE_DISTANCE
`0xFA46714D` | `void SET_LIGHT_FADE_DISTANCE(int fadeDistance)`

## SET_LIGHT_FALLOFF
`0x4D7F6E03` | `void SET_LIGHT_FALLOFF(float falloff)`

## SET_LIGHT_FLAGS
`0x28B22733` | `void SET_LIGHT_FLAGS(int flags)`

## SET_LIGHT_HEADLIGHT
`0xFF44D502` | `void SET_LIGHT_HEADLIGHT(float intensity, float range)`

## SET_LIGHT_INTENSITY
`0x2CC9A71C` | `void SET_LIGHT_INTENSITY(float intensity)`

## SET_LIGHT_INTERIOR
`0x1CC72443` | `void SET_LIGHT_INTERIOR(int interiorId, bool isPortal, int roomIndex)`

## SET_LIGHT_PLANE
`0xE46E0CDF` | `void SET_LIGHT_PLANE(float x, float y, float z, float w)`

## SET_LIGHT_RADIUS
`0x4A4B5CBE` | `void SET_LIGHT_RADIUS(float radius)`

## SET_LIGHT_SHADOW_DETAILS
`0xA40EAC1A` | `void SET_LIGHT_SHADOW_DETAILS(int shadowFlags, float shadowDistance, float shadowFade, float shadowDepthBiasScale)`

## SET_LIGHT_SHADOW_FADE_DISTANCE
`0x3C54C2A8` | `void SET_LIGHT_SHADOW_FADE_DISTANCE(int fadeDistance)`

## SET_LIGHT_SPECULAR_FADE_DISTANCE
`0xC3A35A50` | `void SET_LIGHT_SPECULAR_FADE_DISTANCE(int fadeDistance)`

## SET_LIGHT_TEXTURE
`0x55A50736` | `void SET_LIGHT_TEXTURE(char* textureDict, int textureHash)`

## SET_LIGHT_TYPE
`0xCB58679D` | `void SET_LIGHT_TYPE(int lightType)`

## SET_LIGHT_VOLUMETRIC_FADE_DISTANCE
`0xE1F41605` | `void SET_LIGHT_VOLUMETRIC_FADE_DISTANCE(int volumetricFadeDistance)`

## SET_LIGHT_VOLUME_DETAILS
`0x2F731AE7` | `void SET_LIGHT_VOLUME_DETAILS(float volIntensity, float volSizeScale, float r, float g, float b, float i, float outerExponent)`

## SET_MANUAL_SHUTDOWN_LOADING_SCREEN_NUI
`0x1722C938` | `void SET_MANUAL_SHUTDOWN_LOADING_SCREEN_NUI(BOOL manualShutdown)`

## SET_MAP_NAME
`0xB7BA82DC` | `void SET_MAP_NAME(char* mapName)`

## SET_MAP_ZOOM_DATA_LEVEL
`0x447C718E` | `void SET_MAP_ZOOM_DATA_LEVEL(int index, float zoomScale, float zoomSpeed, float scrollSpeed, float tilesX, float tilesY)`

## SET_MILLISECONDS_PER_GAME_MINUTE
`0x36CA2554` | `void SET_MILLISECONDS_PER_GAME_MINUTE(int value)`

## SET_MINIMAP_CLIP_TYPE
`0xB8B4490C` | `void SET_MINIMAP_CLIP_TYPE(int type)`

## SET_MINIMAP_COMPONENT_POSITION
`0x3E882B23` | `void SET_MINIMAP_COMPONENT_POSITION(char* name, char* alignX, char* alignY, float posX, float posY, float sizeX, float sizeY)`

## SET_MINIMAP_OVERLAY_DISPLAY
`0x6A48B3CA` | `void SET_MINIMAP_OVERLAY_DISPLAY(int miniMap, float x, float y, float xScale, float yScale, float alpha)`

## SET_MINIMAP_TYPE
`0x5FB53015` | `void SET_MINIMAP_TYPE(int type)`

## SET_MODEL_HEADLIGHT_CONFIGURATION
`0x7F6B8D75` | `void SET_MODEL_HEADLIGHT_CONFIGURATION(Hash modelHash, float ratePerSecond, float headlightRotation, BOOL invertRotation)`

## SET_MP_GAMER_TAGS_USE_VEHICLE_BEHAVIOR
`0x7A27BC93` | `void SET_MP_GAMER_TAGS_USE_VEHICLE_BEHAVIOR(bool enabled)`

## SET_MP_GAMER_TAGS_VISIBLE_DISTANCE
`0xD61676B3` | `void SET_MP_GAMER_TAGS_VISIBLE_DISTANCE(float distance)`

## SET_NETWORK_WALK_MODE
`0x55188D2D` | `void SET_NETWORK_WALK_MODE(bool enabled)`

## SET_NUI_FOCUS
`0x5B98AE30` | `void SET_NUI_FOCUS(BOOL hasFocus, BOOL hasCursor)`

## SET_NUI_FOCUS_KEEP_INPUT
`0x3FF5E5F8` | `void SET_NUI_FOCUS_KEEP_INPUT(BOOL keepInput)`

## SET_NUI_ZINDEX
`0x3734AAFF` | `void SET_NUI_ZINDEX(int zIndex)`

## SET_PED_AMMO
`0xBF90DF1A` | `void SET_PED_AMMO(Ped ped, Hash weaponHash, int ammo)`

## SET_PED_ARMOUR
`0x4E3A0CC4` | `void SET_PED_ARMOUR(Ped ped, int amount)`

## SET_PED_CAN_RAGDOLL
`0xCF1384C4` | `void SET_PED_CAN_RAGDOLL(Ped ped, BOOL toggle)`

## SET_PED_COLLECTION_COMPONENT_VARIATION
`0x88711BBA` | `void SET_PED_COLLECTION_COMPONENT_VARIATION(Ped ped, int componentId, char* collection, int drawableId, int textureId, int paletteId)`

## SET_PED_COLLECTION_PRELOAD_PROP_DATA
`0x14B5BBE0` | `void SET_PED_COLLECTION_PRELOAD_PROP_DATA(Ped ped, int anchorPoint, char* collection, int propIndex, int textureId)`

## SET_PED_COLLECTION_PRELOAD_VARIATION_DATA
`0x3EC75558` | `void SET_PED_COLLECTION_PRELOAD_VARIATION_DATA(Ped ped, int componentId, char* collection, int drawableId, int textureId)`

## SET_PED_COLLECTION_PROP_INDEX
`0x75240BCB` | `void SET_PED_COLLECTION_PROP_INDEX(Ped ped, int anchorPoint, char* collection, int propIndex, int textureId, BOOL attach)`

## SET_PED_COMPONENT_VARIATION
`0xD4F7B05C` | `void SET_PED_COMPONENT_VARIATION(Ped ped, int componentId, int drawableId, int textureId, int paletteId)`

## SET_PED_CONFIG_FLAG
`0x9CFBE10D` | `void SET_PED_CONFIG_FLAG(Ped ped, int flagId, BOOL value)`

## SET_PED_DEFAULT_COMPONENT_VARIATION
`0xC866A984` | `void SET_PED_DEFAULT_COMPONENT_VARIATION(Ped ped)`

## SET_PED_HAIR_TINT
`0xA23FE32C` | `void SET_PED_HAIR_TINT(Ped ped, int colorID, int highlightColorID)`

## SET_PED_HEAD_BLEND_DATA
`0x60746B88` | `void SET_PED_HEAD_BLEND_DATA(Ped ped, int shapeFirstID, int shapeSecondID, int shapeThirdID, int skinFirstID, int skinSecondID, int skinThirdID, float shapeMix, float skinMix, float thirdMix, BOOL isParent)`

## SET_PED_HEAD_OVERLAY
`0xD28DBA90` | `void SET_PED_HEAD_OVERLAY(Ped ped, int overlayID, int index, float opacity)`

## SET_PED_INTO_VEHICLE
`0x7500C79` | `void SET_PED_INTO_VEHICLE(Ped ped, Vehicle vehicle, int seatIndex)`

## SET_PED_MELEE_COMBAT_LIMITS
`0x8E51EC29` | `void SET_PED_MELEE_COMBAT_LIMITS(int primaryCount, int secondaryCount, int populationPedCount)`

## SET_PED_MODEL_HEALTH_CONFIG
`0xAF12A05D` | `void SET_PED_MODEL_HEALTH_CONFIG(Hash modelHash, char* configName)`
```lua
local pedModel = `mp_f_freemode_01`
SetPedModelHealthConfig(pedModel, "Strong")

SetPlayerModel(PlayerId(), pedModel)
SetPedDefaultComponentVariation(PlayerPedId())

```

## SET_PED_MODEL_PERSONALITY
`0x46F6B38B` | `void SET_PED_MODEL_PERSONALITY(Hash modelHash, Hash personalityHash)`

## SET_PED_PROP_INDEX
`0x829F2E2` | `void SET_PED_PROP_INDEX(Ped ped, int componentId, int drawableId, int textureId, BOOL attach)`

## SET_PED_RANDOM_COMPONENT_VARIATION
`0x4111BA46` | `void SET_PED_RANDOM_COMPONENT_VARIATION(Ped ped, int p1)`

## SET_PED_RANDOM_PROPS
`0xE3318E0E` | `void SET_PED_RANDOM_PROPS(Ped ped)`

## SET_PED_RESET_FLAG
`0xCFF6FF66` | `void SET_PED_RESET_FLAG(Ped ped, int flagId, BOOL doReset)`

## SET_PED_TO_RAGDOLL
`0x83CB5052` | `void SET_PED_TO_RAGDOLL(Ped ped, int minTime, int maxTime, int ragdollType, BOOL bAbortIfInjured, BOOL bAbortIfDead, BOOL bForceScriptControl)`

## SET_PED_TO_RAGDOLL_WITH_FALL
`0xFA12E286` | `void SET_PED_TO_RAGDOLL_WITH_FALL(Ped ped, int minTime, int maxTime, int nFallType, float dirX, float dirY, float dirZ, float fGroundHeight, float grab1X, float grab1Y, float grab1Z, float grab2X, float grab2Y, float grab2Z)`

## SET_PED_TURNING_THRESHOLDS
`0xB300F03` | `void SET_PED_TURNING_THRESHOLDS(float min, float max)`

## SET_PLAYER_CONTROL
`0xD17AFCD8` | `void SET_PLAYER_CONTROL(Player player, BOOL bHasControl, int flags)`

## SET_PLAYER_CULLING_RADIUS
`0x8A2FBAD4` | `void SET_PLAYER_CULLING_RADIUS(char* playerSrc, float radius)`

## SET_PLAYER_INVINCIBLE
`0xDFB9A2A2` | `void SET_PLAYER_INVINCIBLE(Player player, BOOL bInvincible)`

## SET_PLAYER_KILL_FALL_HEIGHT
`0x86BD5722` | `void SET_PLAYER_KILL_FALL_HEIGHT(float height)`

## SET_PLAYER_MAX_STAMINA
`0x35594F67` | `void SET_PLAYER_MAX_STAMINA(Player playerId, float maxStamina)`

## SET_PLAYER_MODEL
`0x774A4C54` | `void SET_PLAYER_MODEL(Player player, Hash model)`

## SET_PLAYER_ROUTING_BUCKET
`0x6504EB38` | `void SET_PLAYER_ROUTING_BUCKET(char* playerSrc, int bucket)`

## SET_PLAYER_STAMINA
`0xA9EC16C7` | `void SET_PLAYER_STAMINA(Player playerId, float stamina)`

## SET_PLAYER_TALKING_OVERRIDE
`0xFC02CAF6` | `void SET_PLAYER_TALKING_OVERRIDE(Player player, BOOL state)`

## SET_PLAYER_WANTED_LEVEL
`0xB7A0914B` | `void SET_PLAYER_WANTED_LEVEL(Player player, int wantedLevel, BOOL delayedResponse)`

## SET_REACTION_TO_VEHICLE_SIREN_DISABLED
`0x8C3EC64F` | `void SET_REACTION_TO_VEHICLE_SIREN_DISABLED(BOOL state)`

## SET_RESOURCE_KVP
`0x21C7A35B` | `void SET_RESOURCE_KVP(char* key, char* value)`
```lua
SetResourceKvp('mollis', 'vesuvius citrate')
```

## SET_RESOURCE_KVP_FLOAT
`0x9ADD2938` | `void SET_RESOURCE_KVP_FLOAT(char* key, float value)`
```lua
local lickMy = 42.5
SetResourceKvpFloat('bananabread', lickMy)
```

## SET_RESOURCE_KVP_FLOAT_NO_SYNC
`0x3517BFBE` | `void SET_RESOURCE_KVP_FLOAT_NO_SYNC(char* key, float value)`

## SET_RESOURCE_KVP_INT
`0x6A2B1E8` | `void SET_RESOURCE_KVP_INT(char* key, int value)`
```lua
local lickMy = 42
SetResourceKvp('bananabread', lickMy)
```

## SET_RESOURCE_KVP_INT_NO_SYNC
`0x26AEB707` | `void SET_RESOURCE_KVP_INT_NO_SYNC(char* key, int value)`

## SET_RESOURCE_KVP_NO_SYNC
`0xCF9A2FF` | `void SET_RESOURCE_KVP_NO_SYNC(char* key, char* value)`

## SET_RICH_PRESENCE
`0x7BDCBD45` | `void SET_RICH_PRESENCE(char* presenceState)`

## SET_ROPES_CREATE_NETWORK_WORLD_STATE
`0xE62FC73` | `void SET_ROPES_CREATE_NETWORK_WORLD_STATE(BOOL shouldCreate)`

## SET_ROPE_LENGTH_CHANGE_RATE
`0x69B680A7` | `void SET_ROPE_LENGTH_CHANGE_RATE(int rope, float lengthChangeRate)`

## SET_ROUTING_BUCKET_ENTITY_LOCKDOWN_MODE
`0xA0F2201F` | `void SET_ROUTING_BUCKET_ENTITY_LOCKDOWN_MODE(int bucketId, char* mode)`

## SET_ROUTING_BUCKET_POPULATION_ENABLED
`0xCE51AC2C` | `void SET_ROUTING_BUCKET_POPULATION_ENABLED(int bucketId, BOOL mode)`

## SET_RUNTIME_TEXTURE_ARGB_DATA
`0x3963D527` | `void SET_RUNTIME_TEXTURE_ARGB_DATA(long tex, char* buffer, int length)`

## SET_RUNTIME_TEXTURE_IMAGE
`0x28FC4ECB` | `void SET_RUNTIME_TEXTURE_IMAGE(long tex, char* fileName)`

## SET_RUNTIME_TEXTURE_PIXEL
`0xAB65ACEE` | `void SET_RUNTIME_TEXTURE_PIXEL(long tex, int x, int y, int r, int g, int b, int a)`

## SET_SNAKEOIL_FOR_ENTRY
`0xA7DD3209` | `void SET_SNAKEOIL_FOR_ENTRY(char* name, char* path, char* data)`

## SET_STATE_BAG_VALUE
`0x8D50E33A` | `void SET_STATE_BAG_VALUE(char* bagName, char* keyName, char* valueData, int valueLength, BOOL replicated)`

## SET_TEXT_CHAT_ENABLED
`0x97B2F9F8` | `void SET_TEXT_CHAT_ENABLED(BOOL enabled)`

## SET_TEXT_FONT_FOR_CURRENT_COMMAND
`0xADA9255D` | `void SET_TEXT_FONT_FOR_CURRENT_COMMAND(int fontId)`

## SET_TEXT_JUSTIFICATION
`0x68CDFA60` | `void SET_TEXT_JUSTIFICATION(int justifyType)`

## SET_TEXT_WRAP
`0x6F60AB54` | `void SET_TEXT_WRAP(float start, float end)`

## SET_TIMECYCLE_MODIFIER_VAR
`0x6E0A422B` | `void SET_TIMECYCLE_MODIFIER_VAR(char* modifierName, char* varName, float value1, float value2)`
```lua
local modifierName = "superDARK"
local varName = "postfx_noise"

if DoesTimecycleModifierHasVar(modifierName, varName) then
  local success, value1, value2 = GetTimecycleModifierVar(modifierName, varName)

  if success then
    print(string.format("[%s] removed var %s with values: %f %f", modifierName, varName, value1, value2))
    RemoveTimecycleModifierVar(modifierName, varName)
  end
else
    SetTimecycleModifierVar(modifierName, varName, 1.0, 1.0)
    print(string.format("[%s] created var %s", modifierName, varName))
end
```

## SET_TRACK_BRAKING_DISTANCE
`0x77EB78D0` | `void SET_TRACK_BRAKING_DISTANCE(int track, float brakingDistance)`

## SET_TRACK_ENABLED
`0x4B41E84C` | `void SET_TRACK_ENABLED(int track, bool enabled)`

## SET_TRACK_JUNCTION_ACTIVE
`0x537B449D` | `void SET_TRACK_JUNCTION_ACTIVE(int junctionIndex, bool state)`

## SET_TRACK_MAX_SPEED
`0x37BFC732` | `void SET_TRACK_MAX_SPEED(int track, int newSpeed)`

## SET_TRAINS_FORCE_DOORS_OPEN
`0xD4D1BA63` | `void SET_TRAINS_FORCE_DOORS_OPEN(bool forceOpen)`

## SET_TRAIN_DOOR_OPEN_RATIO
`0x2468DBE8` | `void SET_TRAIN_DOOR_OPEN_RATIO(Vehicle train, int doorIndex, float ratio)`
```lua
-- open all doors on a train
local doorCount = GetTrainDoorCount(train)
for doorIndex = 0, doorCount - 1 do
    SetTrainDoorOpenRatio(train, doorIndex, 1.0)
end
```
```cs
// open all doors on a train
int doorCount = API.GetTrainDoorCount(train);
for (int doorIndex = 0; doorIndex < doorCount; doorIndex++)
{
    API.SetTrainDoorOpenRatio(train, doorIndex, 1.0f);
}
```

## SET_TRAIN_STATE
`0x61CB74A0` | `void SET_TRAIN_STATE(Vehicle train, int state)`

## SET_TRAIN_STOP_AT_STATIONS
`0xECB8B577` | `void SET_TRAIN_STOP_AT_STATIONS(Vehicle train, BOOL state)`

## SET_VEHICLE_ALARM
`0x24877D84` | `void SET_VEHICLE_ALARM(Vehicle vehicle, BOOL state)`

## SET_VEHICLE_ALARM_TIME_LEFT
`0xC108EE6F` | `void SET_VEHICLE_ALARM_TIME_LEFT(Vehicle vehicle, int time)`

## SET_VEHICLE_AUTO_REPAIR_DISABLED
`0x5F3A3574` | `void SET_VEHICLE_AUTO_REPAIR_DISABLED(Vehicle vehicle, BOOL value)`

## SET_VEHICLE_BODY_HEALTH
`0x920C2517` | `void SET_VEHICLE_BODY_HEALTH(Vehicle vehicle, float value)`

## SET_VEHICLE_CLUTCH
`0x2F70ACED` | `void SET_VEHICLE_CLUTCH(Vehicle vehicle, float clutch)`

## SET_VEHICLE_COLOURS
`0x57F24253` | `void SET_VEHICLE_COLOURS(Vehicle vehicle, int colorPrimary, int colorSecondary)`

## SET_VEHICLE_COLOUR_COMBINATION
`0xA557AEAD` | `void SET_VEHICLE_COLOUR_COMBINATION(Vehicle vehicle, int colorCombination)`

## SET_VEHICLE_CURRENT_GEAR
`0x8923DD42` | `void SET_VEHICLE_CURRENT_GEAR(Vehicle vehicle, int gear)`

## SET_VEHICLE_CURRENT_RPM
`0x2A01A8FC` | `void SET_VEHICLE_CURRENT_RPM(Vehicle vehicle, float rpm)`

## SET_VEHICLE_CUSTOM_PRIMARY_COLOUR
`0x8DF9F9BC` | `void SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(Vehicle vehicle, int r, int g, int b)`

## SET_VEHICLE_CUSTOM_SECONDARY_COLOUR
`0x9D77259E` | `void SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(Vehicle vehicle, int r, int g, int b)`

## SET_VEHICLE_DIRT_LEVEL
`0x2B39128B` | `void SET_VEHICLE_DIRT_LEVEL(Vehicle vehicle, float dirtLevel)`

## SET_VEHICLE_DOORS_LOCKED
`0x4CDD35D0` | `void SET_VEHICLE_DOORS_LOCKED(Vehicle vehicle, int doorLockStatus)`

## SET_VEHICLE_DOOR_BROKEN
`0x8147FEA7` | `void SET_VEHICLE_DOOR_BROKEN(Vehicle vehicle, int doorIndex, BOOL deleteDoor)`

## SET_VEHICLE_ENGINE_TEMPERATURE
`0x6C93C4A9` | `void SET_VEHICLE_ENGINE_TEMPERATURE(Vehicle vehicle, float temperature)`

## SET_VEHICLE_FLAG
`0x63AE1A34` | `void SET_VEHICLE_FLAG(Vehicle vehicle, int flagIndex, bool value)`

## SET_VEHICLE_FUEL_LEVEL
`0xBA970511` | `void SET_VEHICLE_FUEL_LEVEL(Vehicle vehicle, float level)`

## SET_VEHICLE_GEAR_RATIO
`0x496EF2F2` | `void SET_VEHICLE_GEAR_RATIO(Vehicle vehicle, int gear, float ratio)`
```lua
local function Set8SpeedVehicleGears(Vehicle)
    SetVehicleGearRatio(Vehicle, 0, -3.32)  -- reverse gear at -3.21:1
    SetVehicleGearRatio(Vehicle, 1, 4.71)   -- 1st gear at 4.71:1
    SetVehicleGearRatio(Vehicle, 2, 3.14)   -- 2nd gear at 3.14:1
    SetVehicleGearRatio(Vehicle, 3, 2.11)   -- 3rd gear at 2.11:1
    SetVehicleGearRatio(Vehicle, 4, 1.67)   -- 4th gear at 1.67:1
    SetVehicleGearRatio(Vehicle, 5, 1.29)   -- 5th gear at 1.29:1
    SetVehicleGearRatio(Vehicle, 6, 1.0)    -- 6th gear at 1.0:1
    SetVehicleGearRatio(Vehicle, 7, 0.84)   -- 7th gear at 0.84:1
    SetVehicleGearRatio(Vehicle, 8, 0.67)   -- 8th gear at 0.67:1
end
```
```js
function Set8SpeedVehicleGears(Vehicle) {
    SetVehicleGearRatio(Vehicle, 0, -3.32);  // reverse gear at -3.21:1
    SetVehicleGearRatio(Vehicle, 1, 4.71);   // 1st gear at 4.71:1
    SetVehicleGearRatio(Vehicle, 2, 3.14);   // 2nd gear at 3.14:1
    SetVehicleGearRatio(Vehicle, 3, 2.11);   // 3rd gear at 2.11:1
    SetVehicleGearRatio(Vehicle, 4, 1.67);   // 4th gear at 1.67:1
    SetVehicleGearRatio(Vehicle, 5, 1.29);   // 5th gear at 1.29:1
    SetVehicleGearRatio(Vehicle, 6, 1.0);    // 6th gear at 1.0:1
    SetVehicleGearRatio(Vehicle, 7, 0.84);   // 7th gear at 0.84:1
    SetVehicleGearRatio(Vehicle, 8, 0.67);   // 8th gear at 0.67:1
}
```
```cs
using static CitizenFX.Core.API;

public static void Set8SpeedVehicleGears(int Vehicle)
{
    SetVehicleGearRatio(Vehicle, 0, -3.32);  // reverse gear at -3.21:1
    SetVehicleGearRatio(Vehicle, 1, 4.71);   // 1st gear at 4.71:1
    SetVehicleGearRatio(Vehicle, 2, 3.14);   // 2nd gear at 3.14:1
    SetVehicleGearRatio(Vehicle, 3, 2.11);   // 3rd gear at 2.11:1
    SetVehicleGearRatio(Vehicle, 4, 1.67);   // 4th gear at 1.67:1
    SetVehicleGearRatio(Vehicle, 5, 1.29);   // 5th gear at 1.29:1
    SetVehicleGearRatio(Vehicle, 6, 1.0);    // 6th gear at 1.0:1
    SetVehicleGearRatio(Vehicle, 7, 0.84);   // 7th gear at 0.84:1
    SetVehicleGearRatio(Vehicle, 8, 0.67);   // 8th gear at 0.67:1
}
```

## SET_VEHICLE_GRAVITY_AMOUNT
`0x1A963E58` | `void SET_VEHICLE_GRAVITY_AMOUNT(Vehicle vehicle, float gravity)`

## SET_VEHICLE_HANDLING_FIELD
`0x2BA40795` | `void SET_VEHICLE_HANDLING_FIELD(Vehicle vehicle, char* class_, char* fieldName, Any value)`

## SET_VEHICLE_HANDLING_FLOAT
`0x488C86D2` | `void SET_VEHICLE_HANDLING_FLOAT(Vehicle vehicle, char* class_, char* fieldName, float value)`

## SET_VEHICLE_HANDLING_INT
`0xC37F4CF9` | `void SET_VEHICLE_HANDLING_INT(Vehicle vehicle, char* class_, char* fieldName, int value)`

## SET_VEHICLE_HANDLING_VECTOR
`0x12497890` | `void SET_VEHICLE_HANDLING_VECTOR(Vehicle vehicle, char* class_, char* fieldName, Vector3 value)`

## SET_VEHICLE_HIGH_GEAR
`0x20B1B3E6` | `void SET_VEHICLE_HIGH_GEAR(Vehicle vehicle, int gear)`

## SET_VEHICLE_NEXT_GEAR
`0x3A4566F4` | `void SET_VEHICLE_NEXT_GEAR(Vehicle vehicle, int nextGear)`

## SET_VEHICLE_NITRO_PTFX_RANGE
`0xA40CB822` | `void SET_VEHICLE_NITRO_PTFX_RANGE(float range)`

## SET_VEHICLE_NUMBER_PLATE_TEXT
`0x400F9556` | `void SET_VEHICLE_NUMBER_PLATE_TEXT(Vehicle vehicle, char* plateText)`

## SET_VEHICLE_OIL_LEVEL
`0x90D1CAD1` | `void SET_VEHICLE_OIL_LEVEL(Vehicle vehicle, float level)`

## SET_VEHICLE_PITCH_BIAS
`0x2A6CC9F2` | `void SET_VEHICLE_PITCH_BIAS(Vehicle vehicle, float value)`

## SET_VEHICLE_ROLL_BIAS
`0x264B45DE` | `void SET_VEHICLE_ROLL_BIAS(Vehicle vehicle, float value)`

## SET_VEHICLE_STEERING_ANGLE
`0xFFCCC2EA` | `void SET_VEHICLE_STEERING_ANGLE(Vehicle vehicle, float angle)`

## SET_VEHICLE_STEERING_SCALE
`0xEB46596F` | `void SET_VEHICLE_STEERING_SCALE(Vehicle vehicle, float scale)`

## SET_VEHICLE_SUSPENSION_HEIGHT
`0xB3439A01` | `void SET_VEHICLE_SUSPENSION_HEIGHT(Vehicle vehicle, float newHeight)`

## SET_VEHICLE_TURBO_PRESSURE
`0x6485615E` | `void SET_VEHICLE_TURBO_PRESSURE(Vehicle vehicle, float pressure)`

## SET_VEHICLE_WHEELIE_STATE
`0xEAB8DB65` | `void SET_VEHICLE_WHEELIE_STATE(Vehicle vehicle, int state)`
```lua
Citizen.CreateThread(function()
  while true do
    Wait(1)

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsUsing(ped)

    if veh ~= 0 then
      -- is vehicle a musclecar
      if GetVehicleClass(veh) == 4 then
        -- is ped a driver
        if GetPedInVehicleSeat(veh, -1) == ped then
          -- don't let vehicle to do wheelie
          SetVehicleWheelieState(veh, 1)
        end
      end
    end
  end
end)
```

## SET_VEHICLE_WHEEL_BRAKE_PRESSURE
`0xE80F4E31` | `void SET_VEHICLE_WHEEL_BRAKE_PRESSURE(Vehicle vehicle, int wheelIndex, float pressure)`

## SET_VEHICLE_WHEEL_FLAGS
`0xD2B9E90D` | `void SET_VEHICLE_WHEEL_FLAGS(Vehicle vehicle, int wheelIndex, int flags)`

## SET_VEHICLE_WHEEL_HEALTH
`0xB22ECEFD` | `void SET_VEHICLE_WHEEL_HEALTH(Vehicle vehicle, int wheelIndex, float health)`

## SET_VEHICLE_WHEEL_IS_POWERED
`0xBD5291A0` | `void SET_VEHICLE_WHEEL_IS_POWERED(Vehicle vehicle, int wheelIndex, BOOL powered)`
```lua
SetVehicleWheelIsPowered(vehicle, 0, true);
```
```js
SetVehicleWheelIsPowered(vehicle, 0, true);
```
```cs
using static CitizenFX.Core.API;
// ...
// The elusive Left Wheel Drive
Vehicle veh = Game.PlayerPed.CurrentVehicle;
for(int i = 0; i < veh.Wheels.Count; i++){
    SetVehicleWheelIsPowered(veh.Handle, i, i % 2 == 0);
}
```

## SET_VEHICLE_WHEEL_POWER
`0xC6146043` | `void SET_VEHICLE_WHEEL_POWER(Vehicle vehicle, int wheelIndex, float power)`

## SET_VEHICLE_WHEEL_RIM_COLLIDER_SIZE
`0xF380E184` | `void SET_VEHICLE_WHEEL_RIM_COLLIDER_SIZE(Vehicle vehicle, int wheelIndex, float value)`

## SET_VEHICLE_WHEEL_ROTATION_SPEED
`0x35ED100D` | `void SET_VEHICLE_WHEEL_ROTATION_SPEED(Vehicle vehicle, int wheelIndex, float speed)`

## SET_VEHICLE_WHEEL_SIZE
`0x53AB5C35` | `void SET_VEHICLE_WHEEL_SIZE(Vehicle vehicle, float size)`

## SET_VEHICLE_WHEEL_TIRE_COLLIDER_SIZE
`0xB962D05C` | `void SET_VEHICLE_WHEEL_TIRE_COLLIDER_SIZE(Vehicle vehicle, int wheelIndex, float value)`

## SET_VEHICLE_WHEEL_TIRE_COLLIDER_WIDTH
`0x47BD0270` | `void SET_VEHICLE_WHEEL_TIRE_COLLIDER_WIDTH(Vehicle vehicle, int wheelIndex, float value)`

## SET_VEHICLE_WHEEL_TRACTION_VECTOR_LENGTH
`0x85C85A3A` | `void SET_VEHICLE_WHEEL_TRACTION_VECTOR_LENGTH(Vehicle vehicle, int wheelIndex, float length)`

## SET_VEHICLE_WHEEL_WIDTH
`0x64C3F1C0` | `void SET_VEHICLE_WHEEL_WIDTH(Vehicle vehicle, float width)`

## SET_VEHICLE_WHEEL_X_OFFSET
`0xBD6357D` | `void SET_VEHICLE_WHEEL_X_OFFSET(Vehicle vehicle, int wheelIndex, float offset)`

## SET_VEHICLE_WHEEL_Y_ROTATION
`0xC6C2171F` | `void SET_VEHICLE_WHEEL_Y_ROTATION(Vehicle vehicle, int wheelIndex, float value)`

## SET_VEHICLE_XENON_LIGHTS_CUSTOM_COLOR
`0x1683E7F0` | `void SET_VEHICLE_XENON_LIGHTS_CUSTOM_COLOR(Vehicle vehicle, int red, int green, int blue)`
```lua
local vehicle = GetVehiclePedIsUsing(PlayerPedId())
if DoesEntityExist(vehicle) then
  -- Toggle xenon lights mod.
  ToggleVehicleMod(vehicle, 22, true)

  -- Set pink lights color.
  SetVehicleXenonLightsCustomColor(vehicle, 244, 5, 82)
end
```

## SET_VEHICLE_XMAS_SNOW_FACTOR
`0x80CC4C9E` | `void SET_VEHICLE_XMAS_SNOW_FACTOR(float gripFactor)`

## SET_VISUAL_SETTING_FLOAT
`0xD1D31681` | `void SET_VISUAL_SETTING_FLOAT(char* name, float value)`

## SET_WATER_AREA_CLIP_RECT
`0x9FCD2EE6` | `void SET_WATER_AREA_CLIP_RECT(int minX, int minY, int maxX, int maxY)`
```lua
SetWaterAreaClipRect(-4000, -4000, 4500, 8000)
```

## SET_WATER_QUAD_ALPHA
`0xF49797EB` | `void SET_WATER_QUAD_ALPHA(int waterQuad, int a0, int a1, int a2, int a3)`
```lua
local success = SetWaterQuadAlpha(0, 5, 5, 5, 5)
```

## SET_WATER_QUAD_BOUNDS
`0x80AD144C` | `void SET_WATER_QUAD_BOUNDS(int waterQuad, int minX, int minY, int maxX, int maxY)`
```lua
local success = SetWaterQuadBounds(0, -5000.0, -5000.0, 5000.0, 5000.0)
```

## SET_WATER_QUAD_HAS_LIMITED_DEPTH
`0xD1FDCFC1` | `void SET_WATER_QUAD_HAS_LIMITED_DEPTH(int waterQuad, BOOL hasLimitedDepth)`
```lua
local success = SetWaterQuadHasLimitedDepth(0, true)
```

## SET_WATER_QUAD_IS_INVISIBLE
`0xA387D917` | `void SET_WATER_QUAD_IS_INVISIBLE(int waterQuad, BOOL isInvisible)`
```lua
local success = SetWaterQuadIsInvisible(0, true)
```

## SET_WATER_QUAD_LEVEL
`0x6292F7A8` | `void SET_WATER_QUAD_LEVEL(int waterQuad, float level)`
```lua
local success = SetWaterQuadLevel(0, 55.0)
```

## SET_WATER_QUAD_NO_STENCIL
`0xC3FF42FF` | `void SET_WATER_QUAD_NO_STENCIL(int waterQuad, bool noStencil)`
```lua
local success = SetWaterQuadNoStencil(0, true)
```

## SET_WATER_QUAD_TYPE
`0x50131EB2` | `void SET_WATER_QUAD_TYPE(int waterQuad, int type)`
```lua
local success = SetWaterQuadType(0, 0)
```

## SET_WAVE_QUAD_AMPLITUDE
`0xE4174B7B` | `void SET_WAVE_QUAD_AMPLITUDE(int waveQuad, float amplitude)`
```lua
local success = SetWaveQuadAmplitude(0, 1.0)
```

## SET_WAVE_QUAD_BOUNDS
`0x1FCC1FAF` | `void SET_WAVE_QUAD_BOUNDS(int waveQuad, int minX, int minY, int maxX, int maxY)`
```lua
local success = SetWaveQuadBounds(0, -5000, -5000, 5000, 5000)
```

## SET_WAVE_QUAD_DIRECTION
`0xFC9341A3` | `void SET_WAVE_QUAD_DIRECTION(int waveQuad, float directionX, float directionY)`
```lua
local success = SetWaveQuadDirection(0, 0.3, 0.1)
```

## SET_WEAPONS_NO_AIM_BLOCKING
`0xDFD8F6DE` | `void SET_WEAPONS_NO_AIM_BLOCKING(BOOL state)`

## SET_WEAPONS_NO_AUTORELOAD
`0x311150E5` | `void SET_WEAPONS_NO_AUTORELOAD(BOOL state)`

## SET_WEAPONS_NO_AUTOSWAP
`0x2A7B50E` | `void SET_WEAPONS_NO_AUTOSWAP(BOOL state)`

## SET_WEAPON_ACCURACY_SPREAD
`0x598DD6AE` | `void SET_WEAPON_ACCURACY_SPREAD(Hash weaponHash, float spread)`

## SET_WEAPON_RECOIL_SHAKE_AMPLITUDE
`0x9864312F` | `void SET_WEAPON_RECOIL_SHAKE_AMPLITUDE(Hash weaponHash, float amplitude)`

## SET_WEATHER_CYCLE_ENTRY
`0xD264D4E1` | `void SET_WEATHER_CYCLE_ENTRY(int index, char* typeName, int timeMult)`

## SET_WEATHER_OWNED_BY_NETWORK
`0x2703D582` | `void SET_WEATHER_OWNED_BY_NETWORK(BOOL network)`

## SET_WET_CLOTH_PIN_RADIUS_SCALE
`0xF1BD2CEF` | `void SET_WET_CLOTH_PIN_RADIUS_SCALE(float scale)`
```lua
SetWetClothPinRadiusScale(1.0)
```

## SHUTDOWN_LOADING_SCREEN_NUI
`0xB9234AFB` | `void SHUTDOWN_LOADING_SCREEN_NUI()`

## START_FIND_EXTERNAL_KVP
`0x8F2EECC3` | `void START_FIND_EXTERNAL_KVP(char* resourceName, char* prefix)`
```lua
local kvpHandle = StartFindExternalKvp('drugs', 'mollis:')

if kvpHandle ~= -1 then 
	local key
	
	repeat
		key = FindKvp(kvpHandle)

		if key then
			print(('%s: %s'):format(key, GetResourceKvpString(key)))
		end
	until not key

	EndFindKvp(kvpHandle)
else
	print('No KVPs found')
end
```

## START_FIND_KVP
`0xDD379006` | `void START_FIND_KVP(char* prefix)`
```lua
SetResourceKvp('mollis:2', 'should be taken with alcohol')
SetResourceKvp('mollis:1', 'vesuvius citrate')
SetResourceKvp('mollis:manufacturer', 'Betta Pharmaceuticals')

local kvpHandle = StartFindKvp('mollis:')

if kvpHandle ~= -1 then 
	local key
	
	repeat
		key = FindKvp(kvpHandle)

		if key then
			print(('%s: %s'):format(key, GetResourceKvpString(key)))
		end
	until not key

	EndFindKvp(kvpHandle)
else
	print('No KVPs found')
end
```

## START_RESOURCE
`0x29B440DC` | `void START_RESOURCE(char* resourceName)`

## STATE_BAG_HAS_KEY
`0x12A330` | `void STATE_BAG_HAS_KEY(char* bagName, char* key)`

## STOP_RESOURCE
`0x21783161` | `void STOP_RESOURCE(char* resourceName)`

## TASK_COMBAT_PED
`0xCB0D8932` | `void TASK_COMBAT_PED(Ped ped, Ped targetPed, int p2, int p3)`

## TASK_DRIVE_BY
`0x2B84D1C4` | `void TASK_DRIVE_BY(Ped driverPed, Ped targetPed, Vehicle targetVehicle, float targetX, float targetY, float targetZ, float distanceToShoot, int pedAccuracy, BOOL p8, Hash firingPattern)`

## TASK_ENTER_VEHICLE
`0xB8689B4E` | `void TASK_ENTER_VEHICLE(Ped ped, Vehicle vehicle, int timeout, int seatIndex, float speed, int flag, Any p6)`

## TASK_EVERYONE_LEAVE_VEHICLE
`0xC1971F30` | `void TASK_EVERYONE_LEAVE_VEHICLE(Vehicle vehicle)`

## TASK_GO_STRAIGHT_TO_COORD
`0x80A9E7A7` | `void TASK_GO_STRAIGHT_TO_COORD(Ped ped, float x, float y, float z, float speed, int timeout, float targetHeading, float distanceToSlide)`

## TASK_GO_TO_COORD_ANY_MEANS
`0xF91DF93B` | `void TASK_GO_TO_COORD_ANY_MEANS(Ped ped, float x, float y, float z, float fMoveBlendRatio, Vehicle vehicle, BOOL bUseLongRangeVehiclePathing, int drivingFlags, float fMaxRangeToShootTargets)`

## TASK_GO_TO_ENTITY
`0x374827C2` | `void TASK_GO_TO_ENTITY(Entity entity, Entity target, int duration, float distance, float speed, float p5, int p6)`

## TASK_HANDS_UP
`0x8DCC19C5` | `void TASK_HANDS_UP(Ped ped, int duration, Ped facingPed, int p3, BOOL p4)`

## TASK_LEAVE_ANY_VEHICLE
`0xDBDD79FA` | `void TASK_LEAVE_ANY_VEHICLE(Ped ped, int p1, int flags)`

## TASK_LEAVE_VEHICLE
`0x7B1141C6` | `void TASK_LEAVE_VEHICLE(Ped ped, Vehicle vehicle, int flags)`

## TASK_PLAY_ANIM
`0x5AB552C6` | `void TASK_PLAY_ANIM(Ped ped, char* animDictionary, char* animationName, float blendInSpeed, float blendOutSpeed, int duration, int flag, float playbackRate, BOOL lockX, BOOL lockY, BOOL lockZ)`

## TASK_PLAY_ANIM_ADVANCED
`0x3DDEB0E6` | `void TASK_PLAY_ANIM_ADVANCED(Ped ped, char* animDictionary, char* animationName, float posX, float posY, float posZ, float rotX, float rotY, float rotZ, float blendInSpeed, float blendOutSpeed, int duration, Any flag, float animTime, Any p14, Any p15)`

## TASK_REACT_AND_FLEE_PED
`0x8A632BD8` | `void TASK_REACT_AND_FLEE_PED(Ped ped, Ped fleeTarget)`

## TASK_SHOOT_AT_COORD
`0x601C22E3` | `void TASK_SHOOT_AT_COORD(Ped ped, float x, float y, float z, int duration, Hash firingPattern)`

## TASK_SHOOT_AT_ENTITY
`0xAC0631C9` | `void TASK_SHOOT_AT_ENTITY(Entity entity, Entity target, int duration, Hash firingPattern)`

## TASK_WARP_PED_INTO_VEHICLE
`0x65D4A35D` | `void TASK_WARP_PED_INTO_VEHICLE(Ped ped, Vehicle vehicle, int seatIndex)`

## TEMP_BAN_PLAYER
`0x1E35DBBA` | `void TEMP_BAN_PLAYER(char* playerSrc, char* reason)`

## TRIGGER_CLIENT_EVENT_INTERNAL
`0x2F7A49E6` | `void TRIGGER_CLIENT_EVENT_INTERNAL(char* eventName, char* eventTarget, char* eventPayload, int payloadLength)`

## TRIGGER_EVENT_INTERNAL
`0x91310870` | `void TRIGGER_EVENT_INTERNAL(char* eventName, char* eventPayload, int payloadLength)`

## TRIGGER_LATENT_CLIENT_EVENT_INTERNAL
`0x70B35890` | `void TRIGGER_LATENT_CLIENT_EVENT_INTERNAL(char* eventName, char* eventTarget, char* eventPayload, int payloadLength, int bps)`

## TRIGGER_LATENT_SERVER_EVENT_INTERNAL
`0x128737EA` | `void TRIGGER_LATENT_SERVER_EVENT_INTERNAL(char* eventName, char* eventPayload, int payloadLength, int bps)`

## TRIGGER_SERVER_EVENT_INTERNAL
`0x7FDD1128` | `void TRIGGER_SERVER_EVENT_INTERNAL(char* eventName, char* eventPayload, int payloadLength)`

## UNREGISTER_RAW_NUI_CALLBACK
`0x7FB46432` | `void UNREGISTER_RAW_NUI_CALLBACK(char* callbackType)`

## UPDATE_MAPDATA_ENTITY
`0xFC52CB91` | `void UPDATE_MAPDATA_ENTITY(int mapdata, int entity, object entityDef)`

## VERIFY_PASSWORD_HASH
`0x2E310ACD` | `void VERIFY_PASSWORD_HASH(char* password, char* hash)`

## WAS_EVENT_CANCELED
`0x58382A19` | `void WAS_EVENT_CANCELED()`

## _ADD_BLIP_FOR_AREA
`0x6228F159` | `void _ADD_BLIP_FOR_AREA(float x, float y, float z, float width, float height)`

## _SET_PED_EYE_COLOR
`0xEC09DB1B` | `void _SET_PED_EYE_COLOR(Ped ped, int index)`

## _SET_PED_FACE_FEATURE
`0x6C8D4458` | `void _SET_PED_FACE_FEATURE(Ped ped, int index, float scale)`

## _SET_PED_HEAD_OVERLAY_COLOR
`0x78935A27` | `void _SET_PED_HEAD_OVERLAY_COLOR(Ped ped, int overlayID, int colorType, int colorID, int secondColorID)`
