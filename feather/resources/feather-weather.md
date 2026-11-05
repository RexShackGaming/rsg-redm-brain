# feather-weather

Version 0.1.0. World time, weather, and climate synchronization for RedM

World time, weather, and climate synchronization for RedM. Version `0.1.0` (unreleased), Contract 1. A standalone service with no mandatory Core, database, Menu, or UI dependency. The initial baseline and Character integration have recorded user-reported live acceptance. Regional presentation is enabled by default following representative gameplay acceptance; custom policies and other server build

Source: https://github.com/FeatherFramework/feather-weather

## Exports (call as exports['feather-weather']:Name)

**server:** `GetCapabilities()`, `GetForecast(options)`, `GetState()`

**client:** `AcquireOverride(spec)`, `GetLocalState()`, `ReleaseOverride(handle)`, `UpdateOverride(handle, spec)`

## Net events registered

**server:** `feather-weather:bootstrap`

**client:** `feather-weather:bootstrapReply`, `feather-weather:operatorResult`, `feather-weather:snapshot`

## Commands (RegisterCommand)

**client:** `/fwregion`

## Public (table) functions

**client/native.lua:** `N.Apply(state)`, `N.Release()`

**client/overrides.lua:** `O.New(config, epoch)`, `O:Validate(owner, spec)`, `O:Expire(now)`, `O:Acquire(owner, spec, now)`, `O:Update(owner, handle, spec, now)`, `O:Release(owner, handle)`, `O:ReleaseOwner(owner)`, `O:Resolve(now)`

**client/regions.lua:** `R.Hash(value)`, `R.Observation(value)`, `R.New(policy, hashName)`, `R:Observe(observation, now)`, `R:Sample(now, probe)`, `R:Translate(name, snow)`, `R:Context(now)`, `R:TransitionFloor(now)`

**server/engine.lua:** `E.New(config, epoch, random)`, `E:ResetClimate()`, `E:ChooseWind()`, `E:AdvanceCalendar(simulationSeconds)`, `E:Next(name)`, `E:Rebuild()`, `E:Step(elapsed, wallSeconds)`, `E:Advance(elapsed,wallSeconds)`, `E:Snapshot()`, `E:Forecast(options)`, `E:Mutate(action, spec)`

**shared/contract.lua:** `W.Ok(value)`, `W.Err(code, message)`, `W.Number(value, low, high, integer)`, `W.Copy(value)`, `W.Fields(value, allowed)`, `W.Clock(value)`, `W.Weather(value)`, `W.Wind(value)`, `W.SeasonIndex(name)`, `W.WindControl(value)`, `W.WindProgression(value)`, `W.Seasons(value)`, `W.SeasonState(value)`, `W.ProjectWind(wind,target,elapsed,directionRate,speedRate)`, `W.WindMotion(value)`, `W.Pattern(pattern)`, `W.Merge(current, patch, validate)`, `W.RegionalPolicy(policy)`, `W.Config(config)`, `W.Rate(clock)`, `W.Elapsed(now, before)`, `W.TimeParts(seconds)`, `W.Snapshot(value)`
