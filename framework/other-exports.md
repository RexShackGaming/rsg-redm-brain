# Other commonly used exports
- `rsg-hud`: `GetNeed/GetNeeds/SetNeed/AddNeed`, `GainStress`, `RelieveStress`, `SetHudVisible`, `IsHudVisible`, `GetCurrentTemperature`, `GetOutlawStatus`.
- `rsg-multijob`: `GetJobs`, `AddJob`, `RemoveJob`.
- `rsg-weapons`: `weaponInHands`, `EquippedWeapons`, `UsedWeapons`.
- `rsg-wardrobe`, `rsg-character` (`ApplySkin`, `GetClothesCache`), `rsg-animations:PlayAnimation`, `rsg-radialmenu:AddOption/RemoveOption`, `rsg-menubase:GetMenuData`.

- rsg-multijob: jobs are stored in the DB. Don't read or write RSGCore.Shared.Jobs for job definitions.
- rsg-weather replaces weathersync. rsg-stables replaces rsg-horses.
