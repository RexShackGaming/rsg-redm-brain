# rsg-menubase

A lightweight menu framework for RedM, built for the RSG-Core ecosystem. It gives other resources a simple export/API for opening styled, keyboard-navigable menus (lists, sliders, and icon grids) without having to build their own NUI.

---

## Features

- **Simple Lua API** — open, update, and close menus with a single function call (`MenuData.Open`) from any resource.
- **Multiple element types** — plain list items, numeric or options-based sliders, and image/icon grid layouts (`isGrid`).
- **Full keyboard navigation** — Up/Down to navigate, Left/Right to adjust sliders, Enter to select, Backspace to cancel/go back.
- **Live menu updates** — change titles, add/remove elements, or update existing entries while a menu is still open (`menu.update`, `menu.setElement`, `menu.addNewElement`, `menu.removeElementByValue`, etc.).
- **Player state locking** — optionally freeze player movement (`disableMovement`) and/or block inventory access (`lockInventory`) while a menu is open; safely stacks across nested menus and releases automatically on close.
- **Pause menu aware** — automatically closes and re-opens active menus when the player opens/closes the RedM pause menu, so menus don't get stuck behind it.
- **Remembers last selection** — reopening the same menu restores the previously highlighted item for the current session.
- **Multi-menu support** — multiple menus can be tracked and focused independently via namespace/name pairs, enabling page flows and nested menus.
- **Sound feedback** — built-in navigation and selection sounds using RedM's native soundsets.
- **Built-in version checker** — checks against the official GitHub repo on resource start and warns in console if you're running an outdated build.
- **No config file required** — everything is driven by the data table you pass in when opening a menu.

---

## Installation

1. Download or clone this resource into your server's `resources` folder as `rsg-menubase`.
2. Add it to your `server.cfg`, **above** any resource that will call its exports:
   ```
   ensure rsg-menubase
   ```
3. Make sure `rsg-core` is installed and started before `rsg-menubase`.

**Requirements:**
- A RedM server (`rdr3`)
- [`rsg-core`](https://github.com/Rexshack-RedM) framework

---

## Configuration

`rsg-menubase` has no standalone config file — everything is configured per-menu through the `data` table passed to `MenuData.Open`. The main options available on that table:

| Option | Type | Description |
|---|---|---|
| `title` | string | Menu header title |
| `subtext` | string | Subtitle / description text shown under the title |
| `elements` | table | Array of menu items (see element types below) |
| `isGrid` | boolean | Render elements as an icon grid instead of a list |
| `disableMovement` | boolean | Freeze the player while this menu is open |
| `lockInventory` | boolean | Block inventory access while this menu is open |

### Element types

**Default (list item):**
```lua
{ label = "Item Name", value = "item_value", desc = "Description text" }
```

**Slider (numeric range):**
```lua
{ label = "Quantity", type = "slider", value = 1, min = 1, max = 10, hop = 1, desc = "Select quantity" }
```

**Slider (fixed options list):**
```lua
{ label = "Color", type = "slider", value = 0, options = { "Red", "Green", "Blue" } }
```

**Grid item (with icon):**
```lua
{ label = "Item", value = "item", image = "item_image" }
```

For full usage examples — including confirm dialogs, multi-page menus, live updates, and locking player state — see [`EXAMPLES.md`](EXAMPLES.md). For the complete API reference (all menu methods, utility functions, controls, and server integration notes), see [`GUIDE.md`](GUIDE.md).

---

## Quick Start

```lua
local MenuData = exports['rsg-menubase']:GetMenuData()

local menuData = {
    title = "Shop Menu",
    subtext = "Select an item to purchase",
    elements = {
        { label = "Bread",  value = "bread",  desc = "Fresh baked bread - $5" },
        { label = "Water",  value = "water",  desc = "Clean water - $2" },
    }
}

MenuData.Open("default", "myshop", "main", menuData,
    function(data, menu) -- submit
        print("Selected: " .. data.current.value)
        menu.close()
    end,
    function(data, menu) -- cancel
        print("Menu cancelled")
    end
)
```

---

## Controls

| Key | Action |
|---|---|
| Enter | Select item |
| Backspace | Cancel / go back / close menu |
| Up Arrow | Navigate up |
| Down Arrow | Navigate down |
| Left Arrow | Decrease slider value |
| Right Arrow | Increase slider value |

---

## Version Checking

On startup, `rsg-menubase` checks its current version (from `fxmanifest.lua`) against the latest release published to the [Rexshack-RedM version checkers repo](https://github.com/Rexshack-RedM/rsg-versioncheckers) and prints a warning to the server console if you're out of date.

---

## Support / Issues

Please report bugs or feature requests via the resource's GitHub repository issue tracker.

---

## License

Released under the GNU General Public License v3.0 — see [`LICENSE`](LICENSE) for details.



Modified from https://github.com/Rexshack-RedM/rsg-menubase, Aug 2025.
See the Git history for changes. Distributed under GNU GPLv3.