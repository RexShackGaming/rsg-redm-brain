# rsg-menubase – Docs (v1.1.6)

## Contents
1. Files
2. How it works
3. Menu data
4. Exports
5. Controls
6. Examples
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest and NUI files |
| `client/main.lua` | `MenuData` API, focus, pause-menu handling, `GetMenuData` export |
| `client/scale.lua` | `SetScale` export |
| `server/server.lua`, `server/versionchecker.lua` | Version check |
| `html/ui.html`, `html/css/app.css`, `html/js/app.js`, `html/js/mustache.min.js` | NUI menu |
| `EXAMPLES.md` | Full usage examples |

There is no config file; everything is driven by the table passed to `MenuData.Open`.

## 2. How it works
Other resources call `exports['rsg-menubase']:GetMenuData()` and open styled, keyboard-navigable menus (lists, sliders, icon grids). Menus are tracked by namespace and name, so several can be open and nested. Menus close and reopen around the pause menu. The last highlighted item is remembered for the session. Optional movement and inventory locks stack across nested menus and release when the last one closes.

## 3. Menu data
| Option | Type | Meaning |
|---|---|---|
| `title` | string | Header |
| `subtext` | string | Subtitle |
| `elements` | table | Menu items |
| `isGrid` | boolean | Icon grid instead of list |
| `disableMovement` | boolean | Freeze the player while open |
| `lockInventory` | boolean | Block inventory while open |

Elements:
```lua
{ label = 'Item Name', value = 'item_value', desc = 'Description' }                        -- list item
{ label = 'Quantity', type = 'slider', value = 1, min = 1, max = 10, hop = 1 }              -- numeric slider
{ label = 'Color', type = 'slider', value = 0, options = { 'Red', 'Green', 'Blue' } }       -- options slider
{ label = 'Item', value = 'item', image = 'item_image' }                                    -- grid item
```

Menu methods available on the `menu` argument include `close`, `update`, `setElement`, `addNewElement` and `removeElementByValue`; see `EXAMPLES.md`.

## 4. Exports
| Export | Side | Notes |
|---|---|---|
| `GetMenuData()` | client | Returns the `MenuData` object |
| `SetScale(scale)` | client | Scale the menu UI |

```lua
local MenuData = exports['rsg-menubase']:GetMenuData()

MenuData.Open('default', GetCurrentResourceName(), 'main', {
    title = 'Shop Menu',
    subtext = 'Select an item',
    elements = {
        { label = 'Bread', value = 'bread', desc = 'Fresh baked bread' },
    }
},
function(data, menu)      -- submit
    print(data.current.value)
    menu.close()
end,
function(data, menu)      -- cancel
    menu.close()
end)
```

## 5. Controls
| Key | Action |
|---|---|
| Enter | Select |
| Backspace | Cancel / back |
| Up / Down | Navigate |
| Left / Right | Adjust slider |

## 6. Examples
`EXAMPLES.md` covers confirm dialogs, multi-page menus, live updates and locking player state.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| `GetMenuData` export missing | Start rsg-menubase before the resource that uses it |
| Menu vanishes behind the pause menu | Expected; it reopens when the pause menu closes |
| Player stuck frozen | A menu with `disableMovement` was not closed; call `menu.close()` on cancel |

Support the Project : https://rexshack.tebex.store/
