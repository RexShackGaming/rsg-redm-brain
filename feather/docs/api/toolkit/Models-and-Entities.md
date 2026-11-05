---
title: Models and Entities
---

# Toolkit Models and Entities

## Signatures

```lua
exports['feather-toolkit']:LoadModel(model, timeoutMs?) -> Result
exports['feather-toolkit']:CreateObject(spec) -> Result<{ id, entity, kind }>
exports['feather-toolkit']:CreatePed(spec) -> Result<{ id, entity, kind }>
exports['feather-toolkit']:RemoveEntity(id) -> Result
```

## Object example

```lua
local object = exports['feather-toolkit']:CreateObject({
  model = 'p_crate03x',
  x = x, y = y, z = z,
  heading = 0.0,
  networked = true,
  frozen = true
})
```

## Ped and horse example

Toolkit does not expose the old `FeatherCore.Horse` or `FeatherCore.Ped` classes. A horse is a generic ped model:

```lua
local horse = exports['feather-toolkit']:CreatePed({
  model = 'a_c_horse_americanstandardbred_black',
  x = x, y = y, z = z,
  heading = heading,
  networked = true
})

if horse.ok then
  local entity = horse.value.entity
  FreezeEntityPosition(entity, false)
  SetEntityInvincible(entity, true)
  SetPedAsGroupMember(entity, GetPedGroupIndex(PlayerPedId()))
end
```

Toolkit owns only the spawned handle and cleanup. Stable ownership, statistics, tack, storage, persistence, and gameplay belong to a horse/stable resource. Use RedM natives for behavior not covered by the generic creation contract.

Object options are `model`, `timeoutMs`, `x`, `y`, `z`, `heading`, `networked`, `scriptHost`, `dynamic`, `p7`, `p8`, `placeOnGround`, and `frozen`. Ped options are `model`, `timeoutMs`, `x`, `y`, `z`, `heading`, `networked`, `scriptHost`, `p7`, and `p8`.
