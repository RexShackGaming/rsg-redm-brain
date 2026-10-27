# vorp_weaponsv2

Version 2.3. A weapon handler with shops, crafting for vorp core framework

Weapon purchase, crafting, customization script made for VORP Core - Place `vorp_weaponsv2` into your `resources` folder - Run SQL File

Source: https://github.com/VORPCORE/vorp_weaponsv2

## Net events registered

**client:** `vorp:SelectedCharacter`, `vorp_weapons:applymods`, `vorp_weapons:givecomp`, `vorp_weapons:initalizing`, `vorp_weapons:itemcheckfailed`, `vorp_weapons:itemcheckpassed`, `vorp_weapons:itemcheckpassed2`, `vorp_weapons:nomods`, `vorp_weapons:wepcomp`

## Event handlers

**client:** `vorp:SelectedCharacter`, `vorp_weapons:applymods`, `vorp_weapons:initalizing`, `vorp_weapons:itemcheckfailed`, `vorp_weapons:nomods`, `vorp_weapons:wepcomp`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_weapons:getjob`

## Server events it triggers in other resources

**client:** `vorp_weapons:addcomp`, `vorp_weapons:checkmoney`, `vorp_weapons:itemscheck`, `vorp_weapons:itemscheck2`

## Public (table) functions

**client/warmenu.lua:** `WarMenu.CreateMenu(id, title)`, `WarMenu.CreateSubMenu(id, parent, subTitle)`, `WarMenu.CurrentMenu()`, `WarMenu.OpenMenu(id)`, `WarMenu.IsMenuOpened(id)`, `WarMenu.IsAnyMenuOpened()`, `WarMenu.IsMenuAboutToBeClosed()`, `WarMenu.CloseMenu()`, `WarMenu.Button(text, subText)`, `WarMenu.MenuButton(text, id)`, `WarMenu.CheckBox(text, checked, callback)`, `WarMenu.ComboBox(text, items, currentIndex, selectedIndex, callback)`, `WarMenu.Display()`, `WarMenu.SetMenuWidth(id, width)`, `WarMenu.SetMenuX(id, x)`, `WarMenu.SetMenuY(id, y)`, `WarMenu.SetMenuMaxOptionCountOnScreen(id, count)`, `WarMenu.SetTitle(id, title)`, `WarMenu.SetTitleColor(id, r, g, b, a)`, `WarMenu.SetTitleBackgroundColor(id, r, g, b, a)`, `WarMenu.SetTitleBackgroundSprite(id, textureDict, textureName)`, `WarMenu.SetSubTitle(id, text)`, `WarMenu.SetMenuBackgroundColor(id, r, g, b, a)`, `WarMenu.SetMenuTextColor(id, r, g, b, a)`, `WarMenu.SetMenuSubTextColor(id, r, g, b, a)`, `WarMenu.SetMenuFocusColor(id, r, g, b, a)`, `WarMenu.SetMenuButtonPressedSound(id, name, set)`
