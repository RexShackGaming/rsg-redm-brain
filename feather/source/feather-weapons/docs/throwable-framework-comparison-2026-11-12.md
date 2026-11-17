# VORP / RSG throwable comparison — 2026-11-12

Focused review of public main branches; not a security audit or live test. Reference
code is held outside the resource in C:/coding/research/throwable-framework-comparison.
No third-party code copied into Feather runtime.

## VORP inventory v2

- client/services/ammoService.lua: EVENT_PLAYER_COLLECTED_AMBIENT_PICKUP checks
  collector player index, reads weapon/ammo type and asks server to recover by
  weapon name. Some paths clear the native picked-up weapon/ammo before recovery.
- server/services/inventoryService.lua DROP_THROWABLE_WEAPON tracks weaponId in
  THROWN_WEAPONS, marks recoverable weapons dropped, deletes nonrecoverable types,
  and schedules a three-minute expiry. PICK_UP_THROWABLE_WEAPON iterates that map
  for matching weaponName, checks dropped state, clears the entry and adds that
  weapon to the collector. This path does not bind the request to an exact world
  projectile ID. Map removal is an in-memory duplicate guard, not evidence of a
  durable exactly-once transaction across restart/lost reply.
- client/services/PickupsService.lua is a SEPARATE ordinary inventory-drop flow:
  local visual objects, shared pickup records, proximity, configurable hold prompt,
  and server pickup request. Do not describe it as their thrown-Tomahawk route.

Sources:
https://github.com/VORPCORE/vorp_inventory-v2/blob/main/client/services/ammoService.lua
https://github.com/VORPCORE/vorp_inventory-v2/blob/main/server/services/inventoryService.lua
https://github.com/VORPCORE/vorp_inventory-v2/blob/main/client/services/PickupsService.lua

## RSG

- rsg-weapons client UseThrownWeapon requests consumeItem before giving the weapon
  if absent and adding configured native ammo. Server whitelists consumables and
  removes exactly one item before acknowledging.
- rsg-ammo client saveAmmo periodically reports changed native ammo totals and
  restores saved totals on load. This includes throwable ammo definitions.
- No dedicated exact-item shared thrown recovery route was found in the reviewed
  rsg-weapons client/server, rsg-ammo client or rsg-inventory server files. This is
  a bounded search finding, not proof that every RSG addon lacks such a route.
- Native pickup may change a saved ammo total; that is not recovery of the exact
  serialized paid Inventory item with original metadata.

Sources:
https://github.com/Rexshack-RedM/rsg-weapons/blob/main/client/client.lua
https://github.com/Rexshack-RedM/rsg-weapons/blob/main/server/server.lua
https://github.com/Rexshack-RedM/rsg-ammo/blob/main/client/client.lua
https://github.com/Rexshack-RedM/rsg-inventory/blob/main/server/main.lua

## Feather recommendation / status

User leans toward framework-controlled prompt, pending this comparison. Recommend
that direction: reuse the UX pattern, keep Feather's paid item identity and atomic
claim receipts. Neither reviewed implementation resolves our transient projectile
network lifetime by supplying a durable exact projectile-to-paid-item binding.
Do not copy name-only recovery or treat native ammo increases as ownership proof.
Placement/origin admission, native automatic-pickup suppression, wall/body throws,
restart/expiry and simultaneous collectors still need implementation and testing.
No runtime/config/database/deployment changes from this review.
