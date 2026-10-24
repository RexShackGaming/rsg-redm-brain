# rsg-hunting

Version 3.0.0. Hunting, trapper and butcher script for RSG Framework

A hunting, trapper-vending, and butcher system for the RSG Framework (RedM). Players can hunt and skin animals for crafting materials, sell those materials to trapper vendors scattered across the map, or sell whole carcasses directly to butchers for cash and meat. 1. [Features](#features) 2. [Installation](#installation)

Source: https://github.com/Rexshack-RedM/rsg-hunting

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-hunting:server:giverewards`, `rsg-hunting:server:sellItem`

**client:** `rsg-hunting:client:butcher:mainmenu`, `rsg-hunting:client:butcher:sellanimal`

## Event handlers

**server:** `rsg-hunting:server:butcher:reward`

## Callbacks (lib.callback)

**server:** `rsg-hunting:server:getSellData`, `rsg-hunting:server:sellBasket`

## Commands (RegisterCommand)

**server:** `/resetvendorstock`
