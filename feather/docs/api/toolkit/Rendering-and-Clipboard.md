---
title: Rendering and Clipboard
---

# Toolkit Rendering and Clipboard

```lua
exports['feather-toolkit']:DrawText2D(spec) -> Result
exports['feather-toolkit']:DrawText3D(spec) -> Result
exports['feather-toolkit']:CopyToClipboard(text) -> Result
```

```lua
exports['feather-toolkit']:DrawText3D({
  x = x, y = y, z = z,
  text = 'Wagon Storage',
  scale = 0.35,
  color = { r = 255, g = 255, b = 255, a = 255 },
  shadow = true
})
```

Rendering calls draw for the current frame and therefore belong inside an appropriate client loop. Clipboard access uses Toolkit’s bounded NUI bridge; run `ToolkitClipboardSmokeTest` in F8 to verify it.
