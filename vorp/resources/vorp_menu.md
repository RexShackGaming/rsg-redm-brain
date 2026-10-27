# vorp_menu

Version 1.3. A tool to build RedM menus for your scripts

RedM menu API - `ensure vorp_menu` in the top of your resources/server.cfg https://github.com/user-attachments/assets/01808aae-41e9-42ab-87f6-a003a5bfe921

Source: https://github.com/VORPCORE/vorp_menu

Has NUI (`ui_page`).

## Exports (call as exports['vorp_menu']:Name)

**client:** `GetMenuData()`

## Event handlers

**client:** `menuapi:getData`, `vorp_menu:getData`

## Public (table) functions

**client/main.lua:** `MenuData.Open(menuType, namespace, name, data, submit, cancel, change, close)`, `MenuData.Close(type, namespace, name, showRadar, closeSound, trigeerCloseEvent)`, `MenuData.CloseAll(showRadar, closeSound, trigeerCloseEvent)`, `MenuData.GetOpened(type, namespace, name)`, `MenuData.GetOpenedMenus()`, `MenuData.IsOpen(type, namespace, name)`, `MenuData.ReOpen(oldMenu)`, `MenuData.IsInputActive()`, `MenuData.RegisterControls(controls, onPress)`, `MenuData.UnregisterControls()`
