# feather-menu-v2

Version 2.0.0-alpha.9. A focused, reactive menu system for Feather Framework and standalone RedM resources

Build RedM menus from your resource's client-side Lua. Feather Menu v2 draws the menu, manages input and focus, and tells your code when the player changes something. Your resource decides what those changes mean. **Status:** Contract 1 alpha, with the required element set and accepted dropdown design implemented. See [release verification](docs/RELEASE_CHECKLIST.md) for the remaining live and rel

Source: https://github.com/FeatherFramework/feather-menu-v2

Has NUI (`ui_page`).

## Exports (call as exports['feather-menu-v2']:Name)

**client:** `AddElement(menuId, pageId, elementType, spec, callback)`, `ApplyPatch(menuId, operations)`, `AwaitReady(timeoutMs)`, `CloseMenu(menuId, options)`, `ConfigureNavigation(menuId, spec, callback)`, `CreateMenu(spec)`, `CreatePage(menuId, spec)`, `DestroyMenu(menuId)`, `DestroyOwnedMenus()`, `DestroyPage(menuId, pageId, fallbackPageId)`, `FocusElement(menuId, pageId, elementId)`, `GetCapabilities()`, `GetHealth()`, `GetMenuState(menuId)`, `IsInputCaptured()`, `NavigateToPage(menuId, pageId)`, `OpenMenu(menuId, options)`, `RegisterKeyAction(menuId, key, callback)`, `RegisterMenuLifecycle(menuId, callback)`, `RemoveElement(menuId, pageId, elementId)`, `RemoveKeyAction(menuId, key)`, `SetElementValue(menuId, pageId, elementId, value)`, `SetMenuFocus(menuId, options)`, `SyncMenu(menuId)`, `UpdateElement(menuId, pageId, elementId, changes)`, `UpdateMenu(menuId, changes)`, `UpdateNavigation(menuId, changes)`, `UpdatePage(menuId, pageId, changes)`

## Public (table) functions

**client/results.lua:** `MenuResults.Ok(value, meta)`, `MenuResults.Err(code, message, details)`

**client/validation.lua:** `MenuValidation.Id(value, path)`, `MenuValidation.ElementType(value)`, `MenuValidation.Handle(value, path)`, `MenuValidation.Table(value, path)`, `MenuValidation.Finite(value)`, `MenuValidation.Payload(value, path, limits)`, `MenuValidation.Menu(spec, path, requireKey)`, `MenuValidation.Page(spec, path, requireKey)`, `MenuValidation.Element(elementType, spec, path)`, `MenuValidation.ElementChanges(elementType, current, changes, path)`, `MenuValidation.Navigation(spec, path)`, `MenuValidation.Bytes(value, path, maximum)`, `MenuValidation.Sound(spec, path)`, `MenuValidation.Menu(spec, path, requireKey)`, `MenuValidation.Page(spec, path, requireKey)`, `MenuValidation.Element(elementType, spec, path)`, `MenuValidation.Navigation(spec, path)`, `MenuValidation.OpenOptions(spec, closeOnly)`, `MenuValidation.FocusOptions(spec)`, `MenuValidation.ElementAction(element, event)`
