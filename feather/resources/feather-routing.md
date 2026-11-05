# feather-routing

Version 0.1.0. Authoritative routing-bucket service for the Feather Framework

Server-authoritative routing buckets for Feather Framework resources. Clients cannot create or join routes directly. A trusted server resource creates an opaque route and routes a validated player source through the server exports. Ownership is derived from the invoking resource; native bucket numbers never cross the public boundary. - `CreateRoute(spec)`

Source: https://github.com/FeatherFramework/feather-routing

## Exports (call as exports['feather-routing']:Name)

**server:** `CreateRoute(spec)`, `DeleteRoute(routeId)`, `GetCapabilities()`, `GetPlayerRoute(source)`, `GetRoute(routeId)`, `GetRoutePlayers(routeId)`, `JoinRoute(routeId, source)`, `LeaveRoute(source)`

## Commands (RegisterCommand)

**server:** `/RoutingContractSmokeTest`, `/RoutingLiveSmokeTest`

## Public (table) functions

**server/routing.lua:** `RoutingService.Create(owner, spec)`, `RoutingService.Join(owner, routeId, source)`, `RoutingService.Leave(owner, source)`, `RoutingService.GetPlayer(owner, source)`, `RoutingService.Get(owner, routeId)`, `RoutingService.GetPlayers(owner, routeId)`, `RoutingService.Delete(owner, routeId)`, `RoutingService.CleanupOwner(owner)`, `RoutingService.Disconnect(source)`, `RoutingService.Shutdown()`, `RoutingService.Capabilities()`

**shared/results.lua:** `RoutingResults.Ok(value, meta)`, `RoutingResults.Err(code, message, details)`
