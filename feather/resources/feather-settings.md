# feather-settings

Version 0.1.8. Player settings presentation for Feather Framework

Version: **0.1.8**. Owns the player settings menu and its PGUP input. It consumes the framework-agnostic `feather-menu-v2` Contract 1 API. Locale persistence remains a minimal Core account primitive, while PVP state is provided by `feather-pvp`. Start Core, Menu v2, PVP, and Character before Settings; these are its declared

Source: https://github.com/FeatherFramework/feather-settings

**Dependencies:** `feather-core`, `feather-menu-v2`, `feather-pvp`, `feather-character`

## Exports (call as exports['feather-settings']:Name)

**client:** `RegisterChoice(spec)`, `UnregisterChoice(id, ownerResource)`

## Event handlers

**client:** `feather-core:locale:changed`

## Commands (RegisterCommand)

**client:** `/SettingsClientSmokeTest`

## Public (table) functions

**client/providers.lua:** `SettingsProviders.ValidValue(spec, value)`, `SettingsProviders.Groups(visible)`

**tests/behavior.lua:** `menu:AwaitReady()`, `menu:CreateMenu()`, `menu:CreatePage(_, spec)`, `menu:DestroyPage(_, page, fallback)`, `menu:FocusElement(_, page, id)`, `menu:AddElement(_, page, kind, spec, callback)`, `menu:RemoveElement(_, _, id)`, `menu:UpdateElement(_, _, id, changes)`, `menu:ApplyPatch(_, operations)`, `menu:DestroyMenu()`, `menu:GetMenuState()`, `menu:OpenMenu()`, `menu:CloseMenu()`, `menu:NavigateToPage(_, page)`, `menu:IsInputCaptured()`
