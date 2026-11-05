---
title: Controls and Keys
---

# Toolkit Controls and Keys

```lua
exports['feather-toolkit']:ResolveControl(nameOrHash) -> Result<number>
exports['feather-toolkit']:RegisterKeyListener(control, callback, mode?) -> Result<{ id }>
exports['feather-toolkit']:RemoveKeyListener(id) -> Result
```

```lua
local listener = exports['feather-toolkit']:RegisterKeyListener('PGDN', function()
  print('Page Down pressed')
end)
```

The default mode is edge-triggered `just_pressed`. Use `pressed` only when the callback must run every frame while held. Listeners are resource-owned and automatically cleaned up.
