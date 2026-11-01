# vorp_crafting

Version 1.8. A crafting script for vorpcore framework

> A RedM crafting system for [Vorp Core](http://docs.vorpcore.com:3000/) Join the [VORP Community Discord](https://discord.gg/23MPbQ6) 1. Config Recipes of any length

Source: https://github.com/VORPCORE/vorp_crafting

**Dependencies:** `vorp_progressbar`

Has NUI (`ui_page`).

## Net events registered

**server:** `vorp:openInv`, `vorp:startcrafting`

**client:** `vorp:campfire`, `vorp:crafting`

## Event handlers

**client:** `vorp:campfire`, `vorp:crafting`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_crafting:GetJob`

## Commands (RegisterCommand)

**client:** `/campfire`, `/extinguish`

## Server events it triggers in other resources

**client:** `vorp:openInv`, `vorp:startcrafting`
