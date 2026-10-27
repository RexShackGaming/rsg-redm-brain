# vorp_lib

Version 0.4. A library to use for RedM scripts

VORP Lib is a modular scripting library for RedM that simplifies game development by providing reusable, instance-based components with automatic cleanup. Designed specifically for VORP Core Framework, it helps developers write cleaner, more efficient scripts while eliminating common issues like memory leaks and global variable pollution. - **Modular imports** - Import only what you need from the 

Source: https://github.com/VORPCORE/vorp_lib

Has NUI (`ui_page`).

## Exports (call as exports['vorp_lib']:Name)

**server:** `RemoveTemporayDensityMultipliers(source, name)`, `SetDefaultDensityMultipliers(source, name, value, enable)`, `SetTemporaryDensityMultipliers(source, name, value, timer)`

**client:** `GetAllEntities()`, `GetAllObjects()`, `GetAllPeds()`, `GetAllVehicles()`, `GetDensityMultipliers(name)`, `Select(options)`, `StartGizmo(handle, alpha, placeOnGround, deleteOnStop, createCam, data)`, `StopGizmo()`, `TrackEntity(entity)`, `UntrackEntity(entity)`, `copyToClipBoard(text)`, `progressCancel()`, `progressStart(data, onComplete)`

## Net events registered

**server:** `setPedDensity`, `vorp_library:Server:DeleteEntity`

**client:** `vorp:SelectedCharacter`, `vorp_lib:Client:RemoveTemporaryDensityMultiplier`, `vorp_lib:Client:SetDefaultDensityMultiplier`, `vorp_lib:Client:SetTemporaryDensityMultiplier`, `vorp_lib:Internal:SetDefaultDensityMultiplier`

## Event handlers

**server:** `vorp:SelectedCharacter`

**client:** `vorp_menu:closemenu`, `vorp_menu:openmenu`

## Commands (RegisterCommand)

**client:** `/cancel`, `/select`

## Public (table) functions

**client/modules/blips.lua:** `Blip:Create(blipType, params)`

**client/modules/commands.lua:** `Command:Register(name, params, state)`

**client/modules/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`, `DataStream.New(view)`

**client/modules/entities.lua:** `Ped:Create(data)`, `Object:Create(data)`, `Vehicle:Create(data)`

**client/modules/events.lua:** `Events:Register(name, group, callback, state)`

**client/modules/inputs.lua:** `Inputs:Register(inputParams, callback, state)`

**client/modules/points.lua:** `Points:Register(data, state)`

**client/modules/polyzones.lua:** `PolyZones:Register(data, state)`, `PolyZones:Destroy(instance)`

**client/modules/prompts.lua:** `Prompts:Register(data, callback, state)`

**client/modules/streaming.lua:** `Streaming.LoadModel(model, timeout)`, `Streaming.LoadTextureDict(dict, timeout)`, `Streaming.LoadParticleFx(dict, timeout)`, `Streaming.LoadAnimDict(dict, timeout)`, `Streaming.LoadWeaponAsset(weapon, p1, p2, timeout)`, `Streaming.RequestCollisionAtCoord(coords)`, `Streaming.RequestCollisionForModel(model)`, `Streaming.RequestIpl(ipl)`, `Streaming.LoadMoveNetworkDef(netDef, timeout)`, `Streaming.LoadClipSet(clipSet, timeout)`, `Streaming.LoadScene(pos, offset, radius, p7)`

**import.lua:** `importModules:GetPath(file)`, `importModules:Normalize(value)`, `importModules:LoadModule(resource, path)`, `importModules:GetModules(value)`, `importModules:New(moduels)`

**server/modules/commands.lua:** `Command:Register(commandName, params, state)`

**shared/class.lua:** `class:Create(base, className)`, `cls:New(...)`, `cls:super(...)`

**types/types.lua:** `exports.vorp_lib:copyToClipBoard(text)`
