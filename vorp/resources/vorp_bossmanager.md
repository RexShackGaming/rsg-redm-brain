# vorp_bossmanager


THIS SCRIPT DOES NOT WORK FOR VORP its modifying database directly when vorp deals with changes in cache resulting in the changes to be overwritten. wait for a rework

Source: https://github.com/VORPCORE/vorp_bossmanager

**Dependencies:** `vorp_core`

## Net events registered

**client:** `vorp_bossmanager:open`, `vorp_bossmanager:sendemployeelist`, `vorp_bossmanager:sendemployeename`, `vorp_bossmanager:sendgroup`

## Event handlers

**server:** `vorp_bossmanager:bossemployeelist`, `vorp_bossmanager:checkadmin`, `vorp_bossmanager:checkboss`, `vorp_bossmanager:findemployeename`, `vorp_bossmanager:givejob`, `vorp_bossmanager:givelicense`, `vorp_bossmanager:revokejob`, `vorp_bossmanager:revokelicense`

**client:** `vorp_bossmanager:open`, `vorp_bossmanager:sendemployeelist`, `vorp_bossmanager:sendemployeename`, `vorp_bossmanager:sendgroup`

## Commands (RegisterCommand)

**client:** `/givelicense`, `/revokelicense`

## Public (table) functions

**warmenu.lua:** `WarMenu.CreateMenu(id, title)`, `WarMenu.CreateSubMenu(id, parent, subTitle)`, `WarMenu.CurrentMenu()`, `WarMenu.OpenMenu(id)`, `WarMenu.IsMenuOpened(id)`, `WarMenu.IsAnyMenuOpened()`, `WarMenu.IsMenuAboutToBeClosed()`, `WarMenu.CloseMenu()`, `WarMenu.Button(text, subText)`, `WarMenu.MenuButton(text, id)`, `WarMenu.CheckBox(text, checked, callback)`, `WarMenu.ComboBox(text, items, currentIndex, selectedIndex, callback)`, `WarMenu.Display()`, `WarMenu.SetMenuWidth(id, width)`, `WarMenu.SetMenuX(id, x)`, `WarMenu.SetMenuY(id, y)`, `WarMenu.SetMenuMaxOptionCountOnScreen(id, count)`, `WarMenu.SetTitle(id, title)`, `WarMenu.SetTitleColor(id, r, g, b, a)`, `WarMenu.SetTitleBackgroundColor(id, r, g, b, a)`, `WarMenu.SetTitleBackgroundSprite(id, textureDict, textureName)`, `WarMenu.SetSubTitle(id, text)`, `WarMenu.SetMenuBackgroundColor(id, r, g, b, a)`, `WarMenu.SetMenuTextColor(id, r, g, b, a)`, `WarMenu.SetMenuSubTextColor(id, r, g, b, a)`, `WarMenu.SetMenuFocusColor(id, r, g, b, a)`, `WarMenu.SetMenuButtonPressedSound(id, name, set)`

## Database tables

`jobmanager`
