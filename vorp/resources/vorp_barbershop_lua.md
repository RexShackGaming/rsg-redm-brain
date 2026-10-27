# vorp_barbershop_lua

Version 1.0. A barber shop for vorp core framework

barbershop script written in lua for VORP *  ensure `vorp_barbershop`  in your resources.cfg * vorp_menu

Source: https://github.com/VORPCORE/vorp_barbershop_lua

## Net events registered

**client:** `vorp_barbershop:recinfo`

## Event handlers

**server:** `vorp_barbershop:getinfo`

**client:** `vorp_barbershop:recinfo`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_barbershop:payforservice`

## Server events it triggers in other resources

**client:** `vorp_barbershop:getinfo`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`
