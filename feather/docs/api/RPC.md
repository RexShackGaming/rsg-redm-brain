---
title: RPC (Core)
---

# RPC

Feather Core owns the request/response transport. Register routes on the server and call them from the client.

```lua
exports['feather-core']:RegisterRPC(name, handler) -> Result
exports['feather-core']:RegisterContractRPC(name, handler, options?) -> Result
exports['feather-core']:GetRPCRoutes() -> Result
exports['feather-core']:NotifyRPC(name, params?, source?) -> Result
exports['feather-core']:CallRPC(name, params?, callback, source?, timeoutMs?) -> Result
exports['feather-core']:CallRPCAsync(name, params?, source?, timeoutMs?) -> Result
```

See the [Core resource reference](/api/resources/Core) for readiness, result envelopes, and related contracts.
