# feather-world

Version 0.2.0. World population and map compatibility runtime for Feather Framework

Feather World owns shared RedM world behavior for Feather Framework: - population density; - curated interiors and IMAP states;

Source: https://github.com/FeatherFramework/feather-world

## Exports (call as exports['feather-world']:Name)

**server:** `GetCapabilities()`, `GetDensityMultipliers()`

**client:** `DisplayWorldRadar(visible)`, `SetFogOfWar(hidden)`, `StartGpsRoute(startCoords, finishCoords)`, `StopGpsRoute()`

## Commands (RegisterCommand)

**server:** `/WorldContractSmokeTest`

**client:** `/WorldClientSmokeTest`, `/WorldInteriorInspect`

## Public (table) functions

**client/runtime/dataview.lua:** `WorldEventBuffer.Create(fieldCount)`

**client/runtime/events.lua:** `WorldEvents.Register(eventName, callback)`, `WorldEvents.Remove(handle)`

**client/services/map.lua:** `MapAPI.SetFogOfWar(hidden)`, `MapAPI.DisplayRadar(visible)`, `MapAPI.StartGps(startCoords, finishCoords)`, `MapAPI.StopGps()`

**server/services/population.lua:** `WorldPopulation.ValidateDensityMultipliers(input)`, `WorldPopulation.GetDensityMultipliers()`
