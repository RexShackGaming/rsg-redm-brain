# Security rules

**Never trust the client.** Money and item changes happen only on the server, after full validation.

## Instant fail
- Any `AddMoney`, `RemoveMoney`, `AddItem` or `RemoveItem` on the client
- A server event that takes amount, item, money type, price, target or coords from the client and uses it without re-validating
- No `RSGCore.Functions.GetPlayer(source)` nil-check
- No permission, job or grade check on a privileged event
- No sanitizing of amounts (negative, zero, NaN, huge)
- No item existence check (`RSGCore.Shared.Items[item]`)
- No cooldown on reward events
- The client decides the final reward

## Checklist for every reward or purchase event
1. `local Player = RSGCore.Functions.GetPlayer(src)`, and return early if it's nil.
2. Validate every argument's type, range and existence. Work out prices and rewards **from config on the server**.
3. Check permission, job and grade where needed (`RSGCore.Functions.HasPermission(src, 'admin')`).
4. Check distance on the server with `#(GetEntityCoords(GetPlayerPed(src)) - Config.Location) < radius`.
5. Apply a cooldown or rate limit (per-src table with `os.time()`).
6. Call `CanAddItem` before `AddItem`, and check the return value of `RemoveMoney` before handing over goods.
7. Pass a clear `reason` string.

## Core protections
- Client `RSGCore:Server:SetMetaData` accepts only keys in `RSGConfig.ClientWritableMetadata` (hunger, thirst, cleanliness, stress, health, armor).
- Ban exploiters with `exports['rsg-core']:ExploitBan(src, 'reason')`.
- Use the CSRF token (`GenerateCSRFToken`) on sensitive net events.
- Validate every NUI callback on the server too. NUI is client-side and can be forged.

See `patterns/server-reward-event.lua` for the reference implementation.
