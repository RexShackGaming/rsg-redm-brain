---
title: Blips
---

# Toolkit Blips

```lua
exports['feather-toolkit']:CreateBlip(spec) -> Result<{ id, handle }>
exports['feather-toolkit']:RemoveBlip(id) -> Result
```

```lua
local blip = exports['feather-toolkit']:CreateBlip({
  name = 'General Store',
  sprite = joaat('blip_shop_store'),
  style = 1664425300,
  x = x, y = y, z = z
})

if blip.ok then
  exports['feather-toolkit']:RemoveBlip(blip.value.id)
end
```

Blips belong to the invoking resource. Cross-resource removal is rejected and owned blips are removed when their owner stops.
