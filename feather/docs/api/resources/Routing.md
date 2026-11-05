---
title: Feather Routing
---

# Feather Routing

Feather Routing is the server-authoritative routing-bucket service. Route IDs are opaque; native bucket numbers never cross the public boundary.

## Settings

`Config.Buckets` reserves the native bucket range. `Config.Defaults` sets the default lockdown mode and population behavior.

## Server API

```lua
exports['feather-routing']:CreateRoute(spec)
exports['feather-routing']:JoinRoute(routeId, source)
exports['feather-routing']:LeaveRoute(source)
exports['feather-routing']:GetPlayerRoute(source)
exports['feather-routing']:GetRoute(routeId)
exports['feather-routing']:GetRoutePlayers(routeId)
exports['feather-routing']:DeleteRoute(routeId)
exports['feather-routing']:GetCapabilities()
```

```lua
local created = exports['feather-routing']:CreateRoute({
  key = ('character-create:%s'):format(characterUuid),
  mode = 'strict',
  populationEnabled = false
})

if created.ok then
  exports['feather-routing']:JoinRoute(created.value.routeId, source)
end
```

Routes belong to the invoking resource, clean up when that resource stops, and release players on disconnect. Clients cannot create or join routes directly.
