# Feather Routing

Server-authoritative routing buckets for Feather Framework resources.

Clients cannot create or join routes directly. A trusted server resource creates an opaque route and routes a validated player source through the server exports. Ownership is derived from the invoking resource; native bucket numbers never cross the public boundary.

## Exports

- `CreateRoute(spec)`
- `JoinRoute(routeId, source)`
- `LeaveRoute(source)`
- `GetPlayerRoute(source)`
- `GetRoute(routeId)`
- `GetRoutePlayers(routeId)`
- `DeleteRoute(routeId)`
- `GetCapabilities()`

All operations return a standard result envelope. Routes are released when their owner stops, and player membership is released on disconnect.

Run `RoutingContractSmokeTest` from the server console after startup.

The complete ownership, envelope, lifecycle, error, and cleanup contract is documented in [Contract 1](docs/contract-1.md). For native membership verification, run `RoutingLiveSmokeTest <connected source>` while that player is not inside another managed route.
