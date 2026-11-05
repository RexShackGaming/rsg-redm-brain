---
title: REVIEW — Math
---

# Math API

## Get Distance Between coords

| Parameter | Description                                         |
| --------- | --------------------------------------------------- |
| first | coords in vector3               |
| second  | coords in vector3 |

`FeatherCore.misc.GetDistanceBetween(first, second)`

Example Usage:

```lua
-- Client
CreateThread(function()
    FeatherCore.Math.GetDistanceBetween(vector3(0, 0, 0), vector3(1, 1, 1))
end)
```
