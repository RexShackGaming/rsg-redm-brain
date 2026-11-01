# rsg-menubase

Version 1.1.6. rsg-menubase

A lightweight menu framework for RedM, built for the RSG-Core ecosystem. It gives other resources a simple export/API for opening styled, keyboard-navigable menus (lists, sliders, and icon grids) without having to build their own NUI. - **Simple Lua API** — open, update, and close menus with a single function call (`MenuData.Open`) from any resource. - **Multiple element types** — plain list items

Source: https://github.com/Rexshack-RedM/rsg-menubase

Has NUI (`ui_page`).

## Exports (call as exports['rsg-menubase']:Name)

**client:** `GetMenuData()`, `SetScale(scale)`

## Event handlers

**client:** `rsg-menubase:getData`

## Public (table) functions

**client/main.lua:** `MenuData.Open(type, namespace, name, data, submit, cancel, change, close)`, `MenuData.Close(type, namespace, name)`, `MenuData.CloseAll()`, `MenuData.GetOpened(type, namespace, name)`, `MenuData.GetOpenedMenus()`, `MenuData.IsOpen(type, namespace, name)`, `MenuData.ReOpen(oldMenu)`

**client/scale.lua:** `MenuData.SetScale(scale)`
