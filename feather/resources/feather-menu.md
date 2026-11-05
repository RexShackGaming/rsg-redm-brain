# feather-menu

Version 1.3.5. A RedM Standalone UI system

A standalone NUI menu system for RedM (RedM/FiveM, `rdr3`). Menus are defined entirely in Lua and rendered via a Vue 3 frontend. **Version:** 1.3.4 **Game:** RedM (`rdr3`)

Source: https://github.com/FeatherFramework/feather-menu

Has NUI (`ui_page`).

## Exports (call as exports['feather-menu']:Name)

**client:** `initiate()`

## Public (table) functions

**.luals/cfx-runtime.lua:** `Citizen.InvokeNative(hash, ...)`, `Citizen.CreateThread(cb)`, `Citizen.CreateThreadNow(cb)`, `Citizen.Wait(ms)`, `Citizen.Trace(msg)`, `json.encode(value)`, `json.decode(str)`

**client/main.lua:** `FeatherMenu:RegisterMenu(menuID, config, callbacks)`, `menuClass:UnRegister()`, `menuClass:Open(options)`, `menuClass:Close(options)`, `menuClass:RegisterPage(pageID)`, `pageClass:getElementClass(eid)`, `pageClass:UnRegister()`, `pageClass:RouteTo()`, `pageClass:RegisterElement(elemType, elemData, callback)`, `elemClass:update(newElemData)`, `elemClass:callback(changeData)`, `elemClass:UnRegister()`, `FeatherMenu:Notify(config, callback)`
