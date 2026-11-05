---
title: "Legacy: Menu v1"
---

# Legacy: Feather Menu v1

`feather-menu` is a standalone Lua-defined NUI menu system for RedM. It has no Feather Core dependency.

::: warning Legacy compatibility resource
**Feather Menu v1 (`feather-menu`) is Legacy.** Keep using it for existing RedM resources that depend on `exports['feather-menu']:initiate()` and the menu/page object API documented below.

[Feather Menu v2 (`feather-menu-v2`)](/api/resources/Menuv2) is the **official Feather Framework menu system for new development**. It uses named exports and is not a drop-in replacement for v1. Installing v2 alone will not make an existing v1 resource work.

Both resources can be installed together. Keep each original folder name and start the version each consuming resource requires. Migrate the consuming code before removing Legacy. Some existing Feather resources still require v1; check the resource's manifest and installation instructions rather than assuming all resources have migrated.
:::

## Setup

1. Put `feather-menu` in your server's resources directory.
2. Add `ensure feather-menu` to `server.cfg`.
3. Ensure it before resources that create menus.

## API

```lua
exports['feather-menu']:initiate() -> FeatherMenu

FeatherMenu:RegisterMenu(menuId, config, callbacks?) -> Menu
FeatherMenu:Notify(options, callback?)

Menu:RegisterPage(pageId) -> Page
Menu:Open(options?)
Menu:Close(options?)
Menu:UnRegister()

Page:RegisterElement(type, data, callback?) -> Element
Page:UnRegister()

Element:update(data)
Element:UnRegister()
```

## Example

```lua
local FeatherMenu = exports['feather-menu']:initiate()

local menu = FeatherMenu:RegisterMenu('my_menu', {
  top = '50%',
  left = '50%',
  draggable = true,
  canclose = true
}, {})

local page = menu:RegisterPage('main')
page:RegisterElement('button', {
  label = 'Continue',
  slot = 'content'
}, function()
  menu:Close()
end)

menu:Open({ startupPage = page })
```

Available element types are `header`, `subheader`, `line`, `bottomline`, `button`, `input`, `textarea`, `slider`, `arrows`, `toggle`, `checkbox`, `dropdown`, `gridslider`, `imagebox`, `imageboxcontainer`, `html`, `pagearrows`, and `textdisplay`.

Opening a menu closes the active menu by default. Set `overrideMenu = false` in the open options when opening should fail instead.
