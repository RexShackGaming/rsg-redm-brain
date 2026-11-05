# Feather Routing Contract 1

## Boundary

Routing is a server-only authority over Cfx routing buckets. Clients submit intent to their domain server resource; only that trusted resource calls Routing. Public route IDs are opaque handles and never contain or expose the native bucket number.

Ownership is derived from `GetInvokingResource()`. It cannot be supplied in a payload. A resource may inspect, join, leave, or delete only routes it owns. Joining a player who is already assigned to another resource's managed route fails closed.

## Capability

`GetCapabilities()` returns Contract 1 with these features:

- `routes = 1`
- `ownership = 1`
- `cleanup = 1`
- `opaqueHandles = 1`

## Exports

All exports return `{ ok = true, value = ... }` or `{ ok = false, code, message, details? }`.

### `CreateRoute(spec)`

`spec` accepts only:

- `key`: required caller-owned logical key, 1–128 characters;
- `mode`: `strict`, `relaxed`, or `inactive`;
- `populationEnabled`: boolean.

Repeating the same owner/key/settings returns the same route with `meta.idempotent = true`. Reusing a key with different settings returns `conflict`.

### `JoinRoute(routeId, source)`

Moves a connected player into an owned route. It is idempotent when the player is already in that route. It refuses to take a player from a route owned by another resource.

### `LeaveRoute(source)`

Moves a player from the caller's route to bucket 0. A player with no managed route is an idempotent success.

### `GetPlayerRoute(source)`

Returns the caller-owned public route snapshot for a player, `nil` when unmanaged, or `forbidden` when another resource owns the route. A mismatch between internal membership and the native bucket returns `route_desynchronized`.

### `GetRoute(routeId)` and `GetRoutePlayers(routeId)`

Return copied snapshots for caller-owned routes. Mutable membership tables and native bucket numbers are never returned.

### `DeleteRoute(routeId)`

Moves current members to bucket 0, invalidates the handle, and releases the internal bucket.

## Completed lifecycle facts

Server-local events:

- `routing.route.created.v1`
- `routing.route.deleted.v1`
- `routing.player.joined.v1`
- `routing.player.left.v1`
- `routing.ready.v1`

These events describe completed state changes. They are not mutation commands.
`routing.ready.v1` is emitted after the resource has reached CFX `started`
state and its export host has left the startup call stack; consumers use it to
recreate stale in-memory routes after a Routing restart.

## Error codes

- `invalid_input`
- `unauthenticated`
- `not_found`
- `forbidden`
- `conflict`
- `route_limit`
- `route_desynchronized`

## Cleanup

- Disconnect removes the player's membership.
- Owner resource stop returns its players to bucket 0 and deletes its routes.
- Routing stop returns every Routing-managed player to bucket 0 and invalidates all handles.
- Consumers recreate logical routes after restart; old handles are stale by design.
- Consumers that maintain an active user flow are responsible for rejoining those validated players after recreating the route.

## Tests

- `RoutingContractSmokeTest`
- `RoutingLiveSmokeTest <connected source>`

The live test temporarily routes the player and restores them to bucket 0. Run it when the player is not intentionally inside another route.
