# rsg-stables — Developer Docs

## Client exports

### GetActiveHorseNeeds
```lua
local needs = exports['rsg-stables']:GetActiveHorseNeeds()
-- needs = { entity = <ped handle>, hunger = 0-100, thirst = 0-100 }  or nil
```
Returns the live hunger/thirst of the player's currently active (spawned) horse, as tracked client-side and synced from the server session (`Config.HorseNeeds`). Returns `nil` when no horse is out. Compare `needs.entity` with `GetMount(PlayerPedId())` to check you're riding that horse — rsg-hud does this so borrowed or wild horses show nothing.

### GetHorseBonusInfo
Horse training bonus info (see `client/training.lua`).
