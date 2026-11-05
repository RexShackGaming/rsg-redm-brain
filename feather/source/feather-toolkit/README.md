# Feather Toolkit

Reusable, client-side utility contracts for future Feather resources. Toolkit uses named exports, result envelopes, bounded model loading, per-resource ownership, and automatic cleanup.

Contract 1 includes models, bounded animation-dictionary loading, objects, peds, blips, named control resolution, key listeners, prompts, 2D/3D text, clipboard access, and queued progress UI. Teleport, horses, and wagons remain domain-owned. All stateful handles belong to the resource that created them; cross-resource mutation is rejected and owned handles are released when that resource stops.

Start the resource with `ensure feather-toolkit`. Run `ToolkitServerContractSmokeTest` in the server console and `ToolkitContractSmokeTest` in F8 after startup. Run `ToolkitClipboardSmokeTest optional text` in F8 and paste elsewhere to verify clipboard delivery. Run `ToolkitProgressSmokeTest` in F8 to verify two queued progress requests complete in order.

Consumers should call the named exports directly and inspect every result envelope. Toolkit intentionally does not expose an initiate object or compatibility bridge.

Start progress from a client script with a bounded specification and optional completion callback:

```lua
local started = exports['feather-toolkit']:StartProgress({
    message = 'Preparing supplies',
    durationMs = 5000,
    theme = 'linear',
    color = '#7c2d2d',
    widthPercent = 20
}, function(result)
    if result.ok then print(result.value.outcome) end
end)
```

Supported themes are `linear`, `circle`, and `innercircle`. Use `GetProgress(id)` to inspect an owned request and `CancelProgress(id)` to cancel it. Requests execute through a bounded FIFO queue. Cancellation, inspection, callbacks, and resource-stop cleanup are owner-scoped.

Key listeners default to edge-triggered `just_pressed` behavior. Pass `pressed` only when a callback is intentionally expected every frame while the control is held.
