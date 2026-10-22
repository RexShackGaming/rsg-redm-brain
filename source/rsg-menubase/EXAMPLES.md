# rsg-menubase Examples

Copy-paste templates for common menu patterns. All examples assume `rsg-menubase` is started before your resource and use the exported `MenuData`.

```lua
local MenuData = exports['rsg-menubase']:GetMenuData()
```

---

## 1. Simple List Menu

A basic menu with plain options and a submit handler.

```lua
RegisterCommand('openshop', function()
    local menuData = {
        title = "General Store",
        subtext = "Select an item to purchase",
        elements = {
            { label = "Bread",  value = "bread",  desc = "Fresh baked bread - $5" },
            { label = "Water",  value = "water",  desc = "Clean water - $2" },
            { label = "Coffee", value = "coffee", desc = "Hot coffee - $3" },
        }
    }

    MenuData.Open("default", "myshop", "main", menuData,
        function(data, menu) -- submit
            print("Player bought: " .. data.current.value)
            menu.close()
        end,
        function(data, menu) -- cancel
            print("Shop menu closed without buying")
        end,
        function(data, menu) -- change
            -- fires every time the highlighted item changes
        end,
        function() -- close
            print("Shop menu closed")
        end
    )
end, false)
```

---

## 2. Confirm / Cancel Menu

A quick two-option confirmation dialog.

```lua
local function OpenConfirmMenu(promptText, onConfirm)
    local menuData = {
        title = "Are you sure?",
        subtext = promptText,
        elements = {
            { label = "Confirm", value = "confirm" },
            { label = "Cancel",  value = "cancel" },
        }
    }

    MenuData.Open("default", "myresource", "confirm", menuData,
        function(data, menu)
            menu.close()
            if data.current.value == "confirm" then
                onConfirm()
            end
        end,
        function(data, menu)
            -- cancelled with backspace
        end
    )
end

-- usage
OpenConfirmMenu("Sell your horse for $50?", function()
    print("Horse sold!")
end)
```

---

## 3. Slider Menu (Numeric Range)

Use `type = "slider"` with `min`/`max`/`hop` for numeric values like quantity.

```lua
local menuData = {
    title = "Buy Bread",
    subtext = "Choose a quantity",
    elements = {
        {
            label = "Quantity",
            type  = "slider",
            value = 1,
            min   = 1,
            max   = 20,
            hop   = 1,
            desc  = "How many loaves to buy"
        },
        { label = "Confirm", value = "confirm" },
    }
}

MenuData.Open("default", "myshop", "buy_bread", menuData,
    function(data, menu)
        if data.current.value == "confirm" then
            -- read the slider's current value from menu.data.elements
            local qty = menu.data.elements[1].value
            print("Buying " .. qty .. " bread")
            menu.close()
        end
    end
)
```

---

## 4. Slider Menu (Fixed Options List)

Use `options` instead of `min`/`max` to step through a fixed list of choices (e.g. colors, difficulty levels).

```lua
local menuData = {
    title = "Character Settings",
    elements = {
        {
            label   = "Shirt Color",
            type    = "slider",
            value   = 0, -- index into options
            options = { "Red", "Green", "Blue", "Black" },
            desc    = "Cycle through available colors"
        },
    }
}

MenuData.Open("default", "myresource", "settings", menuData,
    nil, -- no submit needed, just browsing
    nil,
    function(data, menu) -- change fires on every LEFT/RIGHT/UP/DOWN
        local elem = menu.data.elements[1]
        local chosenColor = elem.options[elem.value + 1] -- Lua is 1-indexed, value is 0-indexed
        print("Preview color: " .. chosenColor)
    end
)
```

---

## 5. Grid Menu (Icons/Images)

Set `isGrid = true` and give elements an `image` field to render an icon grid (e.g. an inventory-style picker).

```lua
local menuData = {
    title = "Select an Item",
    isGrid = true,
    elements = {
        { label = "Bread", value = "bread", image = "bread" },
        { label = "Water", value = "water", image = "water" },
        { label = "Meat",  value = "meat",  image = "meat" },
    }
}

MenuData.Open("default", "myresource", "grid_example", menuData,
    function(data, menu)
        print("Selected: " .. data.current.value)
        menu.close()
    end
)
```

> Images are loaded from `nui://ip-inventory/web/images/items/<image>.png` — the `image` value must match a file available at that path.

---

## 6. Multi-Page / Nested Menus

Open a second menu from within a `submit` handler to build simple page flows. Use `menu.close()` before opening the next page.

```lua
local function OpenMainMenu()
    local menuData = {
        title = "Main Menu",
        elements = {
            { label = "Shop",      value = "shop" },
            { label = "Inventory", value = "inventory" },
        }
    }

    MenuData.Open("default", "myresource", "main", menuData,
        function(data, menu)
            menu.close()
            if data.current.value == "shop" then
                OpenShopMenu()
            elseif data.current.value == "inventory" then
                OpenInventoryMenu()
            end
        end
    )
end

function OpenShopMenu()
    local menuData = {
        title = "Shop",
        elements = {
            { label = "Bread", value = "bread" },
            { label = "Back",  value = "back" },
        }
    }

    MenuData.Open("default", "myresource", "shop", menuData,
        function(data, menu)
            menu.close()
            if data.current.value == "back" then
                OpenMainMenu()
            else
                print("Bought " .. data.current.value)
            end
        end
    )
end

function OpenInventoryMenu()
    -- ...
end

RegisterCommand('mymenu', OpenMainMenu, false)
```

---

## 7. Updating a Menu While Open

Use `menu.update`, `menu.setElement`, `menu.addNewElement`, and `menu.removeElementByValue` to modify a menu without closing/reopening it.

```lua
local menuData = {
    title = "Live Counter",
    elements = {
        { label = "Count", value = "count", desc = "Click to increment" },
    }
}

local count = 0

local menu = MenuData.Open("default", "myresource", "counter", menuData,
    function(data, menu)
        count = count + 1
        menu.update({ value = "count" }, { desc = ("Clicked %d times"):format(count) })
        menu.refresh()
    end
)
```

---

## 8. Locking Player Movement / Inventory

Set `disableMovement` and/or `lockInventory` in the menu data to freeze the player and block inventory access while the menu is open. Both are released automatically when the menu closes.

```lua
local menuData = {
    title = "Crafting Station",
    disableMovement = true,
    lockInventory = true,
    elements = {
        { label = "Craft Bandage", value = "bandage" },
    }
}

MenuData.Open("default", "crafting", "station", menuData,
    function(data, menu)
        print("Crafting: " .. data.current.value)
        menu.close()
    end
)
```

---

## 9. Checking Menu State From Elsewhere

```lua
if MenuData.IsOpen("default", "myshop", "main") then
    local menu = MenuData.GetOpened("default", "myshop", "main")
    menu.setTitle("Store Closing Soon!")
    menu.refresh()
end

-- Force-close everything (e.g. on player death or resource stop)
AddEventHandler('rsg-core:client:onPlayerUnload', function()
    MenuData.CloseAll()
end)
```

---

For the full API reference (all menu methods, utility functions, and controls), see `GUIDE.md`.
